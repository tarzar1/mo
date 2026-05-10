"""Vision Control Tool - Desktop App v2
Live screen feed + OCR + built-in terminal + menu.
UI updates via main thread (after), no thread conflicts."""

import os, time, threading, queue, cv2, numpy as np
import customtkinter as ctk
from PIL import Image
import pyautogui, pytesseract

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

class VisionTool:
    def __init__(self):
        self.mode = "OBSERVADOR"
        self.fps = 20
        self.frame_count = 0
        self.fps_counter = 0
        self.fps_timer = time.time()
        self.display_fps = 0
        self.last_ocr = ""
        self.detections = []
        self.screen_w, self.screen_h = pyautogui.size()
        self.feed_w, self.feed_h = 640, 360
        self.scale_x = self.feed_w / self.screen_w
        self.scale_y = self.feed_h / self.screen_h
        self.cmd_queue = queue.Queue()

        self.win = ctk.CTk()
        self.win.title("Vision Control Tool")
        self.win.geometry("1100x700")
        self.win.protocol("WM_DELETE_WINDOW", self._close)

        self._build_ui()
        self._start()
        self.win.mainloop()

    def _build_ui(self):
        # Menu bar
        menubar = ctk.CTkFrame(self.win, height=30)
        menubar.pack(fill="x", side="top")

        self.mode_btn = ctk.CTkButton(menubar, text="Modo: OBSERVADOR", width=140, height=26,
                                       fg_color="transparent", border_width=1,
                                       command=self._toggle_mode)
        self.mode_btn.pack(side="left", padx=4, pady=2)

        ctk.CTkButton(menubar, text="Ver OCR", width=70, height=26,
                      fg_color="transparent", border_width=1,
                      command=self._show_ocr).pack(side="left", padx=2)

        ctk.CTkButton(menubar, text="Click", width=60, height=26,
                      fg_color="transparent", border_width=1,
                      command=self._prompt_click).pack(side="left", padx=2)

        ctk.CTkButton(menubar, text="Escribir", width=70, height=26,
                      fg_color="transparent", border_width=1,
                      command=self._prompt_type).pack(side="left", padx=2)

        ctk.CTkButton(menubar, text="Tecla", width=60, height=26,
                      fg_color="transparent", border_width=1,
                      command=self._prompt_key).pack(side="left", padx=2)

        ctk.CTkButton(menubar, text="?", width=30, height=26,
                      fg_color="transparent", border_width=1,
                      command=self._show_help).pack(side="right", padx=4)

        # Main content
        main = ctk.CTkFrame(self.win)
        main.pack(fill="both", expand=True, padx=4, pady=4)

        # LEFT: Feed
        left = ctk.CTkFrame(main)
        left.pack(side="left", fill="both", expand=True, padx=2)

        ctk.CTkLabel(left, text="Live Feed", font=("Consolas", 11, "bold")).pack()
        self.feed_label = ctk.CTkLabel(left, text="", width=self.feed_w, height=self.feed_h)
        self.feed_label.pack(padx=4, pady=2)

        # RIGHT: OCR + Log
        right = ctk.CTkFrame(main, width=300)
        right.pack(side="right", fill="both", padx=2)

        ctk.CTkLabel(right, text="OCR Output", font=("Consolas", 11, "bold")).pack()
        self.ocr_box = ctk.CTkTextbox(right, font=("Consolas", 9), width=280)
        self.ocr_box.pack(fill="both", expand=True, padx=4, pady=2)

        ctk.CTkLabel(right, text="Log", font=("Consolas", 10)).pack()
        self.log_box = ctk.CTkTextbox(right, font=("Consolas", 8), height=90, width=280)
        self.log_box.pack(fill="x", padx=4, pady=2)

        # BOTTOM: Terminal
        cmd_frame = ctk.CTkFrame(self.win, height=40)
        cmd_frame.pack(fill="x", side="bottom", padx=4, pady=4)

        self.cmd_entry = ctk.CTkEntry(cmd_frame, placeholder_text="click Chrome | escribir hola | presionar enter | mode control",
                                       font=("Consolas", 11))
        self.cmd_entry.pack(side="left", fill="x", expand=True, padx=4, pady=4)
        self.cmd_entry.bind("<Return>", lambda e: self._send_cmd())

        ctk.CTkButton(cmd_frame, text="Enviar", width=70, command=self._send_cmd).pack(side="right", padx=4, pady=4)

        # Status bar
        self.st_bar = ctk.CTkLabel(self.win, text="Listo", font=("Consolas", 9), height=20)
        self.st_bar.pack(fill="x", side="bottom")

    def _start(self):
        self._log("Vision Control Tool iniciada")
        self._log(f"Pantalla: {self.screen_w}x{self.screen_h}")
        self._update_feed()

    def _log(self, msg):
        self.log_box.insert("end", f"{msg}\n")
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
        d = ctk.CTkInputDialog(title="Click en Texto", text="Texto a buscar y clickear:")
        t = d.get_input()
        if t: self._exec(f"click {t}")

    def _prompt_type(self):
        d = ctk.CTkInputDialog(title="Escribir", text="Texto a escribir:")
        t = d.get_input()
        if t: self._exec(f"escribir {t}")

    def _prompt_key(self):
        d = ctk.CTkInputDialog(title="Presionar Tecla", text="Tecla (enter, tab, esc, f5):")
        t = d.get_input()
        if t: self._exec(f"presionar {t}")

    def _show_help(self):
        d = ctk.CTkToplevel(self.win)
        d.title("Ayuda")
        d.geometry("400x400")
        ctk.CTkLabel(d, text="""COMANDOS:
  mode control      Activar control
  mode observador   Solo observar
  click <texto>     Click en texto
  escribir <t>      Escribir texto
  presionar <t>     Tecla (enter,tab,esc,f5)
  hotkey <c1+c2>    Combinacion (ctrl+v,alt+tab)
  mover <x,y>       Mover mouse
  dc <x,y>          Doble click
  scroll <n>        Scroll (+/-)
  screen            Resolucion
  cursor            Pos. cursor""", font=("Consolas", 12), justify="left").pack(padx=20, pady=20)

    def _send_cmd(self):
        cmd = self.cmd_entry.get().strip()
        self.cmd_entry.delete(0, "end")
        if cmd:
            self._log(f">> {cmd}")
            self._exec(cmd)

    def _exec(self, cmd):
        p = cmd.split(' ', 1)
        a = p[0].lower()
        g = p[1] if len(p) > 1 else None

        if a == 'mode':
            if g in ('control', 'observador'):
                self.mode = "CONTROL" if g == "control" else "OBSERVADOR"
                self.mode_btn.configure(text=f"Modo: {self.mode}",
                    fg_color="#8B0000" if self.mode == "CONTROL" else "#1a3a1a")
                self._log(f"MODO: {self.mode}")
            return

        if self.mode != "CONTROL" and a not in ('screen', 'cursor'):
            self._log("Activa modo CONTROL primero")
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
                self._log(f"Hotkey: {g}")
            elif a == 'mover' and g:
                x, y = map(int, g.split(','))
                pyautogui.moveTo(x, y, duration=0.2)
                self._log(f"Mouse: ({x},{y})")
            elif a == 'dc' and g:
                x, y = map(int, g.split(','))
                pyautogui.doubleClick(x, y)
                self._log(f"DC: ({x},{y})")
            elif a == 'scroll' and g:
                pyautogui.scroll(int(g))
                self._log(f"Scroll: {g}")
            elif a == 'screen':
                self._log(f"{self.screen_w}x{self.screen_h}")
            elif a == 'cursor':
                x, y = pyautogui.position()
                self._log(f"Cursor: ({x},{y})")
        except Exception as e:
            self._log(f"Error: {e}")

    def _click_text(self, text):
        for d in self.detections:
            if text.lower() in d['word'].lower():
                pyautogui.click(d['x'], d['y'])
                self._log(f"CLICK '{d['word']}' ({d['x']},{d['y']})")
                return
        self._log(f"No encontrado: {text}")

    def _update_feed(self):
        """Actualiza el feed desde el main thread (via after)"""
        try:
            # Capturar frame
            img = pyautogui.screenshot()
            frame = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
            self.frame_count += 1

            # FPS counter
            self.fps_counter += 1
            now = time.time()
            if now - self.fps_timer > 1.0:
                self.display_fps = self.fps_counter
                self.fps_counter = 0
                self.fps_timer = now

            # OCR cada 1.5s
            if self.frame_count % 30 == 0:
                threading.Thread(target=self._run_ocr, daemon=True).start()

            # Dibujar feed
            display = cv2.resize(frame, (self.feed_w, self.feed_h))
            for d in self.detections[:15]:
                rx = int(d['x'] * self.scale_x); ry = int(d['y'] * self.scale_y)
                rw = int(d['w'] * self.scale_x); rh = int(d['h'] * self.scale_y)
                if 0 <= rx < self.feed_w and 0 <= ry < self.feed_h:
                    cv2.rectangle(display, (rx-rw//2, ry-rh//2), (rx+rw//2, ry+rh//2), (0,255,100), 1)

            hud_color = (0, 255, 0) if self.mode == "OBSERVADOR" else (0, 80, 255)
            cv2.putText(display, f"{self.mode} | {self.display_fps}fps", (5, 15),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, hud_color, 1)

            mx, my = pyautogui.position()
            cux, cuy = int(mx * self.scale_x), int(my * self.scale_y)
            if 0 <= cux < self.feed_w and 0 <= cuy < self.feed_h:
                cv2.drawMarker(display, (cux, cuy), (0, 255, 255), cv2.MARKER_CROSS, 8, 1)

            # Mostrar
            rgb = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
            pil_img = Image.fromarray(rgb)
            ctk_img = ctk.CTkImage(light_image=pil_img, dark_image=pil_img, size=(self.feed_w, self.feed_h))
            self.feed_label.configure(image=ctk_img, text="")

            # Status
            self.st_bar.configure(text=f"{self.mode} | {self.display_fps}fps | {self.screen_w}x{self.screen_h} | Cursor:{mx},{my}")

            # OCR update
            if now - getattr(self, '_ocr_ui_timer', 0) > 1.5 and self.last_ocr:
                self._ocr_ui_timer = now
                self.ocr_box.delete("1.0", "end")
                self.ocr_box.insert("1.0", self.last_ocr[:1200])

        except Exception as e:
            pass

        self.win.after(50, self._update_feed)  # ~20 fps

    def _run_ocr(self):
        try:
            img = pyautogui.screenshot()
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
                        det.append({'word': word,
                            'x': (data['left'][i]+data['width'][i]//2)*2,
                            'y': (data['top'][i]+data['height'][i]//2)*2,
                            'w': data['width'][i]*2, 'h': data['height'][i]*2, 'conf': conf})
                except: pass
            self.detections = det
        except: pass

    def _close(self):
        self.win.destroy()

if __name__ == "__main__":
    VisionTool()
