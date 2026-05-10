"""Vision Control Tool - Multi-Monitor v3
Muestra feed en vivo del monitor 2 con OCR overlay.
Terminal integrada, comandos, control HID."""

import os, time, random, threading, queue, cv2, numpy as np
import customtkinter as ctk
from PIL import Image, ImageGrab
import pyautogui, pytesseract, win32api

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

def get_monitors():
    """Detecta todos los monitores conectados"""
    monitors = []
    try:
        for h_monitor, h_dc, rect, flags in win32api.EnumDisplayMonitors(None, None):
            left, top, right, bottom = rect
            monitors.append({
                'id': len(monitors) + 1,
                'left': left, 'top': top,
                'width': right - left,
                'height': bottom - top,
            })
    except:
        # Fallback: asumir 1 monitor
        w, h = pyautogui.size()
        monitors.append({'id': 1, 'left': 0, 'top': 0, 'width': w, 'height': h})
    return monitors

class VisionToolMulti:
    def __init__(self, monitor_id=2):
        self.monitors = get_monitors()
        print(f"Monitores detectados: {self.monitors}")

        if monitor_id <= len(self.monitors):
            self.monitor = self.monitors[monitor_id - 1]
        else:
            self.monitor = self.monitors[0]

        self.mode = "OBSERVADOR"
        self.fps = 20
        self.frame_count = 0
        self.fps_counter = 0
        self.fps_timer = time.time()
        self.display_fps = 0
        self.last_ocr = ""
        self.detections = []
        self.cmd_queue = queue.Queue()

        self.mon_w = self.monitor['width']
        self.mon_h = self.monitor['height']
        self.feed_w = 800
        self.feed_h = int(self.feed_w * self.mon_h / self.mon_w)

        self.win = ctk.CTk()
        self.win.title(f"Vision Monitor {monitor_id} - {self.mon_w}x{self.mon_h}")
        self.win.geometry("1100x750")
        self.win.protocol("WM_DELETE_WINDOW", self._close)

        self._build_ui()
        self._start()

    def _build_ui(self):
        # Menu bar
        mb = ctk.CTkFrame(self.win, height=30)
        mb.pack(fill="x", side="top")

        self.mode_btn = ctk.CTkButton(mb, text="Modo: OBSERVADOR", width=140, height=26,
                                       fg_color="transparent", border_width=1,
                                       command=self._toggle_mode)
        self.mode_btn.pack(side="left", padx=4, pady=2)

        for label, cmd in [("Ver OCR", self._show_ocr), ("Click", self._prompt_click),
                           ("Escribir", self._prompt_type), ("Tecla", self._prompt_key)]:
            ctk.CTkButton(mb, text=label, width=70, height=26,
                         fg_color="transparent", border_width=1,
                         command=cmd).pack(side="left", padx=2)

        mon_label = f"Monitor {self.monitor['id']}: {self.mon_w}x{self.mon_h}"
        ctk.CTkLabel(mb, text=mon_label, font=("Consolas", 8),
                    text_color="#888").pack(side="right", padx=10, pady=2)

        # Main
        main = ctk.CTkFrame(self.win)
        main.pack(fill="both", expand=True, padx=4, pady=4)

        # LEFT: Feed
        left = ctk.CTkFrame(main)
        left.pack(side="left", fill="both", expand=True, padx=2)

        ctk.CTkLabel(left, text="Live Feed (Monitor 2)", font=("Consolas", 11, "bold")).pack()
        self.feed = ctk.CTkLabel(left, text="Cargando...", width=self.feed_w, height=self.feed_h)
        self.feed.pack(padx=4, pady=2)

        # RIGHT: OCR + Log
        right = ctk.CTkFrame(main, width=280)
        right.pack(side="right", fill="both", padx=2)

        ctk.CTkLabel(right, text="OCR Output", font=("Consolas", 11, "bold")).pack()
        self.ocr_box = ctk.CTkTextbox(right, font=("Consolas", 9), width=260)
        self.ocr_box.pack(fill="both", expand=True, padx=4, pady=2)

        ctk.CTkLabel(right, text="Detecciones", font=("Consolas", 10)).pack()
        self.det_box = ctk.CTkTextbox(right, font=("Consolas", 9), height=80, width=260)
        self.det_box.pack(fill="x", padx=4, pady=2)

        ctk.CTkLabel(right, text="Log", font=("Consolas", 10)).pack()
        self.log_box = ctk.CTkTextbox(right, font=("Consolas", 8), height=70, width=260)
        self.log_box.pack(fill="x", padx=4, pady=2)

        # BOTTOM: Terminal
        cmd_frame = ctk.CTkFrame(self.win, height=40)
        cmd_frame.pack(fill="x", side="bottom", padx=4, pady=4)

        self.cmd_entry = ctk.CTkEntry(cmd_frame,
            placeholder_text="click X | escribir texto | presionar enter | mode control",
            font=("Consolas", 11))
        self.cmd_entry.pack(side="left", fill="x", expand=True, padx=4, pady=4)
        self.cmd_entry.bind("<Return>", lambda e: self._send_cmd())

        ctk.CTkButton(cmd_frame, text="Enviar", width=70, command=self._send_cmd).pack(side="right", padx=4, pady=4)

        # Status
        self.st_bar = ctk.CTkLabel(self.win, text="Listo", font=("Consolas", 9), height=20)
        self.st_bar.pack(fill="x", side="bottom")

    def _start(self):
        self._log(f"Monitor {self.monitor['id']}: {self.mon_w}x{self.mon_h}")
        self._update_feed()

    def _log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self.log_box.insert("end", f"[{ts}] {msg}\n")
        self.log_box.see("end")

    def _toggle_mode(self):
        self.mode = "CONTROL" if self.mode == "OBSERVADOR" else "OBSERVADOR"
        self.mode_btn.configure(text=f"Modo: {self.mode}",
            fg_color="#8B0000" if self.mode == "CONTROL" else "#1a3a1a")
        self._log(f"MODO: {self.mode}")

    def _show_ocr(self):
        self.ocr_box.delete("1.0", "end")
        self.ocr_box.insert("1.0", self.last_ocr or "(Procesando...)")

    def _prompt_click(self):
        d = ctk.CTkInputDialog(title="Click", text="Texto a buscar y clickear:")
        t = d.get_input()
        if t: self._exec(f"click {t}")

    def _prompt_type(self):
        d = ctk.CTkInputDialog(title="Escribir", text="Texto:")
        t = d.get_input()
        if t: self._exec(f"escribir {t}")

    def _prompt_key(self):
        d = ctk.CTkInputDialog(title="Tecla", text="Tecla:")
        t = d.get_input()
        if t: self._exec(f"presionar {t}")

    def _send_cmd(self):
        cmd = self.cmd_entry.get().strip()
        self.cmd_entry.delete(0, "end")
        if cmd:
            self._log(f"CMD: {cmd}")
            self._exec(cmd)

    def _exec(self, cmd):
        p = cmd.split(' ', 1)
        a = p[0].lower()
        g = p[1] if len(p) > 1 else None

        if a == 'mode' and g in ('control', 'observador'):
            self.mode = "CONTROL" if g == "control" else "OBSERVADOR"
            self.mode_btn.configure(text=f"Modo: {self.mode}",
                fg_color="#8B0000" if self.mode == "CONTROL" else "#1a3a1a")
            self._log(f"MODO: {self.mode}")
            return

        if self.mode != "CONTROL":
            self._log("Activa modo CONTROL")
            return

        try:
            if a == 'click' and g:
                self._click_text(g)
            elif a == 'escribir' and g:
                pyautogui.write(g, interval=0.04)
                self._log(f"Escrito: {g}")
            elif a == 'presionar' and g:
                pyautogui.press(g)
                self._log(f"Tecla: {g}")
            elif a == 'hotkey' and g:
                pyautogui.hotkey(*g.split('+'))
            elif a == 'mover' and g:
                x, y = map(int, g.split(','))
                pyautogui.moveTo(x, y, duration=0.2)
        except Exception as e:
            self._log(f"Error: {e}")

    def _click_text(self, text):
        for d in self.detections:
            if text.lower() in d['word'].lower():
                # Ajustar coordenadas: las detecciones son relativas al monitor capturado
                x = d['x'] + self.monitor['left']
                y = d['y'] + self.monitor['top']
                pyautogui.click(x, y)
                self._log(f"CLICK '{d['word']}' ({x},{y})")
                return
        self._log(f"No encontrado: {text}")

    def _update_feed(self):
        try:
            # Capturar SOLO el monitor seleccionado
            bbox = (self.monitor['left'], self.monitor['top'],
                    self.monitor['left'] + self.mon_w,
                    self.monitor['top'] + self.mon_h)
            img = ImageGrab.grab(bbox=bbox, all_screens=True)
            frame = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
            self.frame_count += 1

            # FPS
            self.fps_counter += 1
            now = time.time()
            if now - self.fps_timer > 1.0:
                self.display_fps = self.fps_counter
                self.fps_counter = 0
                self.fps_timer = now

            # OCR cada 2s
            if self.frame_count % 40 == 0:
                threading.Thread(target=self._run_ocr, daemon=True).start()

            # Dibujar feed
            display = cv2.resize(frame, (self.feed_w, self.feed_h))
            scale_x = self.feed_w / self.mon_w
            scale_y = self.feed_h / self.mon_h

            for d in self.detections[:20]:
                rx = int(d['rel_x'] * scale_x); ry = int(d['rel_y'] * scale_y)
                rw = int(d['w'] * scale_x); rh = int(d['h'] * scale_y)
                if 0 <= rx < self.feed_w and 0 <= ry < self.feed_h:
                    cv2.rectangle(display, (rx-rw//2, ry-rh//2),
                                 (rx+rw//2, ry+rh//2), (0, 255, 100), 1)

            cv2.putText(display, f"{self.mode} | {self.display_fps}fps | Monitor {self.monitor['id']}",
                       (5, 15), cv2.FONT_HERSHEY_SIMPLEX, 0.4,
                       (0, 255, 0) if self.mode == "OBSERVADOR" else (0, 80, 255), 1)

            # Cursor
            mx, my = pyautogui.position()
            rel_x = mx - self.monitor['left']
            rel_y = my - self.monitor['top']
            cux, cuy = int(rel_x * scale_x), int(rel_y * scale_y)
            if 0 <= cux < self.feed_w and 0 <= cuy < self.feed_h:
                cv2.drawMarker(display, (cux, cuy), (0, 255, 255), cv2.MARKER_CROSS, 8, 1)

            rgb = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
            pil_img = Image.fromarray(rgb)
            ctk_img = ctk.CTkImage(light_image=pil_img, dark_image=pil_img, size=(self.feed_w, self.feed_h))
            self.feed.configure(image=ctk_img, text="")

            self.st_bar.configure(
                text=f"{self.mode} | {self.display_fps}fps | M{self.monitor['id']} {self.mon_w}x{self.mon_h} | Cursor: rel({rel_x},{rel_y}) abs({mx},{my})")

            if now - getattr(self, '_ocr_timer', 0) > 2 and self.last_ocr:
                self._ocr_timer = now
                self.ocr_box.delete("1.0", "end")
                self.ocr_box.insert("1.0", self.last_ocr[:1000])

        except Exception as e:
            pass

        self.win.after(50, self._update_feed)

    def _run_ocr(self):
        try:
            bbox = (self.monitor['left'], self.monitor['top'],
                    self.monitor['left'] + self.mon_w,
                    self.monitor['top'] + self.mon_h)
            img = ImageGrab.grab(bbox=bbox, all_screens=True)
            gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
            gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)

            self.last_ocr = pytesseract.image_to_string(gray)
            data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
            det = []
            for i in range(len(data['text'])):
                try:
                    conf = int(data['conf'][i])
                    word = data['text'][i].strip()
                    if conf > 40 and len(word) > 2:
                        det.append({
                            'word': word,
                            'x': (data['left'][i]+data['width'][i]//2)*2,
                            'y': (data['top'][i]+data['height'][i]//2)*2,
                            'rel_x': (data['left'][i]+data['width'][i]//2)*2,
                            'rel_y': (data['top'][i]+data['height'][i]//2)*2,
                            'w': data['width'][i]*2, 'h': data['height'][i]*2,
                            'conf': conf
                        })
                except: pass
            self.detections = det

            lines = [f"{d['word']} ({d['rel_x']},{d['rel_y']})" for d in det[:15]]
            self.det_box.delete("1.0", "end")
            self.det_box.insert("1.0", "\n".join(lines))
        except: pass

    def _close(self):
        self.win.destroy()

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--monitor", type=int, default=2, help="Numero de monitor (1, 2, ...)")
    args = p.parse_args()
    app = VisionToolMulti(monitor_id=args.monitor)
    app.win.mainloop()
