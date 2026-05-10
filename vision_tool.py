"""Vision Control Tool - Desktop App
Live screen feed + OCR + built-in terminal + menu.
Controla la PC con vision artificial."""

import os, sys, time, threading, json, queue, cv2, numpy as np
import customtkinter as ctk
from PIL import Image, ImageTk, ImageDraw, ImageFont
import pyautogui, pytesseract

# Configurar Tesseract
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
        self.running = True
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

        # UI
        self.win = ctk.CTk()
        self.win.title("Vision Control Tool")
        self.win.geometry("1100x700")
        self.win.protocol("WM_DELETE_WINDOW", self.on_close)

        self._build_menu()
        self._build_ui()

        # Threads
        self.cmd_queue = queue.Queue()
        self.ocr_lock = threading.Lock()
        self.frame_lock = threading.Lock()
        self.current_frame = None

        self._start_threads()

    def _build_menu(self):
        menubar = ctk.CTkFrame(self.win, height=30)
        menubar.pack(fill="x", side="top", padx=0, pady=0)

        # Mode
        mode_btn = ctk.CTkButton(menubar, text="Modo: OBSERVADOR", width=140, height=26,
                                  fg_color="transparent", border_width=1,
                                  command=self.toggle_mode)
        mode_btn.pack(side="left", padx=4, pady=2)
        self.mode_btn = mode_btn

        # Quick actions
        ctk.CTkButton(menubar, text="Ver OCR", width=80, height=26,
                      fg_color="transparent", border_width=1,
                      command=self.show_ocr).pack(side="left", padx=2, pady=2)

        ctk.CTkButton(menubar, text="Click Texto", width=90, height=26,
                      fg_color="transparent", border_width=1,
                      command=self.prompt_click).pack(side="left", padx=2, pady=2)

        ctk.CTkButton(menubar, text="Escribir", width=80, height=26,
                      fg_color="transparent", border_width=1,
                      command=self.prompt_type).pack(side="left", padx=2, pady=2)

        ctk.CTkButton(menubar, text="Presionar Tecla", width=110, height=26,
                      fg_color="transparent", border_width=1,
                      command=self.prompt_key).pack(side="left", padx=2, pady=2)

        # Help
        ctk.CTkButton(menubar, text="?", width=30, height=26,
                      fg_color="transparent", border_width=1,
                      command=self.show_help).pack(side="right", padx=4, pady=2)

    def _build_ui(self):
        main = ctk.CTkFrame(self.win)
        main.pack(fill="both", expand=True, padx=4, pady=4)

        # --- LEFT: Live Feed ---
        feed_frame = ctk.CTkFrame(main)
        feed_frame.pack(side="left", fill="both", expand=True, padx=2)

        feed_label = ctk.CTkLabel(feed_frame, text="Vision Feed", font=("Consolas", 12, "bold"))
        feed_label.pack(pady=2)

        self.feed_canvas = ctk.CTkLabel(feed_frame, text="", width=self.feed_w, height=self.feed_h,
                                         fg_color="black")
        self.feed_canvas.pack(padx=4, pady=2)

        # Detections list
        det_label = ctk.CTkLabel(feed_frame, text="Detecciones:", font=("Consolas", 10))
        det_label.pack(anchor="w", padx=8)
        self.det_list = ctk.CTkTextbox(feed_frame, height=80, font=("Consolas", 9))
        self.det_list.pack(fill="x", padx=6, pady=2)

        # --- RIGHT: OCR + Output ---
        right_frame = ctk.CTkFrame(main, width=320)
        right_frame.pack(side="right", fill="both", padx=2)
        right_frame.pack_propagate(False)

        ctk.CTkLabel(right_frame, text="OCR Output", font=("Consolas", 12, "bold")).pack(pady=2)
        self.ocr_text = ctk.CTkTextbox(right_frame, font=("Consolas", 9), width=300)
        self.ocr_text.pack(fill="both", expand=True, padx=4, pady=2)

        # Log
        ctk.CTkLabel(right_frame, text="Log", font=("Consolas", 10)).pack(pady=2)
        self.log_text = ctk.CTkTextbox(right_frame, font=("Consolas", 8), height=100, width=300)
        self.log_text.pack(fill="x", padx=4, pady=2)

        # --- BOTTOM: Command input ---
        cmd_frame = ctk.CTkFrame(self.win, height=40)
        cmd_frame.pack(fill="x", side="bottom", padx=4, pady=4)

        self.cmd_entry = ctk.CTkEntry(cmd_frame, placeholder_text="Comando (click Chrome, escribir hola, presionar enter, etc.)",
                                       font=("Consolas", 11))
        self.cmd_entry.pack(side="left", fill="x", expand=True, padx=4, pady=4)
        self.cmd_entry.bind("<Return>", lambda e: self.execute_command())

        ctk.CTkButton(cmd_frame, text="Enviar", width=70, command=self.execute_command).pack(side="right", padx=4, pady=4)

        # --- STATUS BAR ---
        self.status = ctk.CTkLabel(self.win, text="Listo | OBSERVADOR", font=("Consolas", 9),
                                    fg_color="#1a1a2e", height=20)
        self.status.pack(fill="x", side="bottom")

    def _start_threads(self):
        threading.Thread(target=self.capture_loop, daemon=True).start()
        threading.Thread(target=self.ocr_loop, daemon=True).start()
        threading.Thread(target=self.display_loop, daemon=True).start()

    def log(self, msg):
        self.log_text.insert("end", f"{msg}\n")
        self.log_text.see("end")

    def toggle_mode(self):
        self.mode = "CONTROL" if self.mode == "OBSERVADOR" else "OBSERVADOR"
        color = "#8B0000" if self.mode == "CONTROL" else "#1a3a1a"
        text = f"Modo: {self.mode}"
        self.mode_btn.configure(text=text, fg_color=color)
        self.log(f"[MODO] {self.mode}")

    def execute_command(self):
        cmd = self.cmd_entry.get().strip()
        self.cmd_entry.delete(0, "end")
        if not cmd:
            return
        self.cmd_queue.put(cmd)
        self.log(f"[CMD] {cmd}")

    def prompt_click(self):
        dialog = ctk.CTkInputDialog(title="Click en Texto", text="Texto a buscar y clickear:")
        text = dialog.get_input()
        if text:
            self.cmd_queue.put(f"click {text}")

    def prompt_type(self):
        dialog = ctk.CTkInputDialog(title="Escribir", text="Texto a escribir:")
        text = dialog.get_input()
        if text:
            self.cmd_queue.put(f"escribir {text}")

    def prompt_key(self):
        dialog = ctk.CTkInputDialog(title="Presionar Tecla", text="Tecla (enter, tab, esc, f5, etc.):")
        key = dialog.get_input()
        if key:
            self.cmd_queue.put(f"presionar {key}")

    def show_ocr(self):
        self.ocr_text.delete("1.0", "end")
        self.ocr_text.insert("1.0", self.last_ocr or "(OCR procesando...)")

    def show_help(self):
        help_text = """COMANDOS:
  mode control     Activar control
  mode observador  Solo observar
  click <texto>    Click en texto detectado
  escribir <t>     Escribir texto
  presionar <k>    Tecla (enter, tab, esc, f5)
  hotkey <c1+c2>   Combinacion (ctrl+v, alt+tab)
  mover <x,y>      Mover mouse
  dc <x,y>         Doble click
  scroll <n>       Scroll
  screen           Resolucion de pantalla
  cursor           Ver posicion del cursor"""

        d = ctk.CTkToplevel(self.win)
        d.title("Ayuda")
        d.geometry("400x400")
        lbl = ctk.CTkLabel(d, text=help_text, font=("Consolas", 11), justify="left")
        lbl.pack(padx=20, pady=20)

    # ─── THREADS ─────────────────────────────────────

    def capture_loop(self):
        while self.running:
            try:
                img = pyautogui.screenshot()
                frame = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
                with self.frame_lock:
                    self.current_frame = frame
                self.frame_count += 1
                self.fps_counter += 1
                now = time.time()
                if now - self.fps_timer > 1.0:
                    self.display_fps = self.fps_counter
                    self.fps_counter = 0
                    self.fps_timer = now
                # Process commands
                self._process_queue()
            except:
                pass
            time.sleep(1.0 / self.fps)

    def _process_queue(self):
        while not self.cmd_queue.empty():
            try:
                cmd = self.cmd_queue.get_nowait()
                resp = self._handle_command(cmd)
                if resp:
                    self.log(f"  -> {resp}")
            except:
                pass

    def _handle_command(self, cmd):
        parts = cmd.split(' ', 1)
        action = parts[0].lower()
        arg = parts[1] if len(parts) > 1 else None

        if action == 'mode':
            if arg in ('control', 'observador'):
                self.mode = 'CONTROL' if arg == 'control' else 'OBSERVADOR'
                self.mode_btn.configure(text=f"Modo: {self.mode}",
                    fg_color="#8B0000" if self.mode == "CONTROL" else "#1a3a1a")
                return f"MODO: {self.mode}"
            return f"Modo actual: {self.mode}"

        if self.mode != "CONTROL":
            return "Activa modo CONTROL primero"

        try:
            if action == 'click' and arg:
                return self._click_text(arg)
            elif action == 'escribir' and arg:
                pyautogui.write(arg, interval=0.04)
                return f"Escrito: '{arg}'"
            elif action == 'presionar' and arg:
                pyautogui.press(arg)
                return f"Tecla: '{arg}'"
            elif action == 'hotkey' and arg:
                keys = arg.split('+')
                pyautogui.hotkey(*keys)
                return f"Hotkey: {'+'.join(keys)}"
            elif action == 'mover' and arg:
                x, y = map(int, arg.split(','))
                pyautogui.moveTo(x, y, duration=0.2)
                return f"Mouse movido a ({x},{y})"
            elif action == 'dc' and arg:
                x, y = map(int, arg.split(','))
                pyautogui.doubleClick(x, y)
                return f"Doble click en ({x},{y})"
            elif action == 'scroll' and arg:
                pyautogui.scroll(int(arg))
                return f"Scroll: {arg}"
            elif action == 'screen':
                return f"Pantalla: {self.screen_w}x{self.screen_h}"
            elif action == 'cursor':
                x, y = pyautogui.position()
                return f"Cursor: ({x}, {y})"
            else:
                return f"Comando: {action}"
        except Exception as e:
            return f"Error: {e}"

    def _click_text(self, text):
        """Busca texto en las detecciones y clickea"""
        for d in self.detections:
            if text.lower() in d['word'].lower():
                pyautogui.click(d['x'], d['y'])
                return f"CLICK en '{d['word']}' ({d['x']},{d['y']})"
        return f"No encontrado: '{text}'"

    def ocr_loop(self):
        while self.running:
            time.sleep(1.5)
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
                            det.append({
                                'word': word,
                                'x': (data['left'][i] + data['width'][i]//2) * 2,
                                'y': (data['top'][i] + data['height'][i]//2) * 2,
                                'w': data['width'][i] * 2,
                                'h': data['height'][i] * 2,
                                'conf': conf
                            })
                    except: pass
                self.detections = det

                # Update det list UI
                lines = [f"{d['word']} ({d['x']},{d['y']})" for d in det[:20]]
                self.det_list.delete("1.0", "end")
                self.det_list.insert("1.0", "\n".join(lines))
            except:
                pass

    def display_loop(self):
        prev_update = 0
        while self.running:
            time.sleep(0.05)  # 20 FPS display
            now = time.time()
            if now - prev_update < 0.05:
                continue
            prev_update = now

            with self.frame_lock:
                frame = self.current_frame
            if frame is None:
                continue

            display = cv2.resize(frame, (self.feed_w, self.feed_h))

            # Dibujar detecciones en el feed
            for d in self.detections[:15]:
                rx = int(d['x'] * self.scale_x)
                ry = int(d['y'] * self.scale_y)
                rw = int(d['w'] * self.scale_x)
                rh = int(d['h'] * self.scale_y)
                if 0 <= rx < self.feed_w and 0 <= ry < self.feed_h:
                    cv2.rectangle(display, (rx - rw//2, ry - rh//2),
                                 (rx + rw//2, ry + rh//2), (0, 255, 100), 1)

            # Texto HUD
            cv2.putText(display, f"{self.mode} | {self.display_fps} FPS",
                       (5, 15), cv2.FONT_HERSHEY_SIMPLEX, 0.4,
                       (0, 255, 0) if self.mode == "OBSERVADOR" else (0, 80, 255), 1)

            # Mostrar cursor
            mx, my = pyautogui.position()
            cux = int(mx * self.scale_x)
            cuy = int(my * self.scale_y)
            if 0 <= cux < self.feed_w and 0 <= cuy < self.feed_h:
                cv2.drawMarker(display, (cux, cuy), (0, 255, 255), cv2.MARKER_CROSS, 8, 1)

            # Update OCR text area
            if now - getattr(self, '_last_ocr_update', 0) > 1.5:
                self._last_ocr_update = now
                self.ocr_text.delete("1.0", "end")
                self.ocr_text.insert("1.0", self.last_ocr[:1000] or "(Procesando...)")

            # Update status
            mx2, my2 = pyautogui.position()
            self.status.configure(
                text=f"{self.mode} | {self.display_fps} FPS | {self.screen_w}x{self.screen_h} | Cursor: {mx2},{my2}")

            # Convertir a PIL y mostrar
            rgb = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
            pil_img = Image.fromarray(rgb)
            ctk_img = ctk.CTkImage(light_image=pil_img, dark_image=pil_img, size=(self.feed_w, self.feed_h))
            self.feed_canvas.configure(image=ctk_img, text="")

    def on_close(self):
        self.running = False
        self.win.destroy()

    def run(self):
        self.log("[INIT] Vision Control Tool iniciada")
        self.log(f"[INIT] Pantalla: {self.screen_w}x{self.screen_h}")
        self.log(f"[INIT] Feed: {self.feed_w}x{self.feed_h}")

        self.win.mainloop()

if __name__ == "__main__":
    app = VisionTool()
    app.run()
