"""Vision Tool Pro + RPA Engine - UI.Vision Style
Live feed + OCR + bounding boxes + comandos RPA + lenguaje natural"""

import os, time, threading, cv2, numpy as np
import customtkinter as ctk
from PIL import Image, ImageGrab
import pyautogui, pytesseract
from rpa_engine import RPAEngine

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

class VisionRPA:
    def __init__(self):
        self.mode = "OBSERVADOR"
        self.fps = 15
        self.frame_count = 0
        self.fps_counter = 0
        self.fps_timer = time.time()
        self.display_fps = 0
        self.last_ocr = ""
        self.detections = []
        self.running = True

        sw, sh = pyautogui.size()
        self.feed_w = 800
        self.feed_h = int(self.feed_w * sh / sw)

        # RPA Engine
        self.rpa = RPAEngine(log_fn=self._rpa_log)

        self.win = ctk.CTk()
        self.win.title("Vision RPA Pro")
        self.win.geometry("1150x800")
        self.win.protocol("WM_DELETE_WINDOW", self._close)

        self._build_ui()
        self._start()

    def _rpa_log(self, msg):
        self.log_box.insert("end", f"{msg}\n")
        self.log_box.see("end")

    def _build_ui(self):
        mb = ctk.CTkFrame(self.win, height=32)
        mb.pack(fill="x", side="top")

        self.mode_btn = ctk.CTkButton(mb, text="OBSERVADOR", width=90, height=26,
            fg_color="transparent", border_width=1, command=self._toggle_mode)
        self.mode_btn.pack(side="left", padx=3, pady=2)

        ctk.CTkButton(mb, text="Feed ON", width=65, height=26,
            fg_color="#1a3a1a", border_width=1, command=self._toggle_feed).pack(side="left", padx=3)

        ctk.CTkButton(mb, text="Refresh", width=65, height=26,
            fg_color="transparent", border_width=1,
            command=lambda: threading.Thread(target=self._run_ocr, daemon=True).start()).pack(side="left", padx=3)

        ctk.CTkButton(mb, text="Ejecutar Script", width=95, height=26,
            fg_color="#8B0000", border_width=1,
            command=self._run_script).pack(side="left", padx=3)

        ctk.CTkButton(mb, text="?", width=25, height=26,
            fg_color="transparent", border_width=1,
            command=self._show_help).pack(side="right", padx=6)

        # Main
        main = ctk.CTkFrame(self.win)
        main.pack(fill="both", expand=True, padx=4, pady=4)

        # LEFT: Feed
        left = ctk.CTkFrame(main)
        left.pack(side="left", fill="both", expand=True, padx=2)

        ctk.CTkLabel(left, text="Live Feed", font=("Consolas", 11, "bold")).pack(pady=2)
        self.feed = ctk.CTkLabel(left, text="Cargando...", width=self.feed_w, height=self.feed_h)
        self.feed.pack(padx=4, pady=2)

        # Detections
        ctk.CTkLabel(left, text="Detecciones", font=("Consolas", 10)).pack(anchor="w", padx=6)
        self.det_box = ctk.CTkTextbox(left, font=("Consolas", 8), height=55)
        self.det_box.pack(fill="x", padx=4, pady=2)

        # RIGHT
        right = ctk.CTkFrame(main, width=320)
        right.pack(side="right", fill="both", padx=2)

        # RPA Commands
        ctk.CTkLabel(right, text="RPA Script", font=("Consolas", 12, "bold"),
                     text_color="#ffa500").pack(pady=2)
        self.cmd_box = ctk.CTkTextbox(right, font=("Consolas", 10), height=150, width=300)
        self.cmd_box.pack(fill="x", padx=4, pady=2)
        self.cmd_box.insert("1.0", "abre chrome y busca python")

        # Log
        ctk.CTkLabel(right, text="Log", font=("Consolas", 10)).pack(pady=2)
        self.log_box = ctk.CTkTextbox(right, font=("Consolas", 9), height=280, width=300)
        self.log_box.pack(fill="both", expand=True, padx=4, pady=2)

        # BOTTOM: Task input
        task_frame = ctk.CTkFrame(self.win, height=40)
        task_frame.pack(fill="x", side="bottom", padx=4, pady=4)

        self.task_entry = ctk.CTkEntry(task_frame,
            placeholder_text="click Chrome | type hola | press enter | open notepad | search python | abre chrome y busca gatos",
            font=("Consolas", 10))
        self.task_entry.pack(side="left", fill="x", expand=True, padx=4, pady=4)
        self.task_entry.bind("<Return>", lambda e: self._run_task())

        ctk.CTkButton(task_frame, text="Ejecutar", width=70, fg_color="#00d97e",
                      text_color="black", command=self._run_task).pack(side="right", padx=4, pady=4)

        ctk.CTkButton(task_frame, text="NL", width=40, fg_color="transparent",
                      border_width=1, command=self._run_nl).pack(side="right", padx=2, pady=4)

        # Status
        self.st_bar = ctk.CTkLabel(self.win, text="Listo", font=("Consolas", 9), height=20)
        self.st_bar.pack(fill="x", side="bottom")

    def _start(self):
        self._rpa_log("Vision RPA Pro iniciada")
        self._update_feed()

    def _toggle_mode(self):
        self.mode = "CONTROL" if self.mode == "OBSERVADOR" else "OBSERVADOR"
        self.mode_btn.configure(text=self.mode,
            fg_color="#8B0000" if self.mode == "CONTROL" else "transparent")
        self._rpa_log(f"MODO: {self.mode}")

    def _toggle_feed(self):
        pass

    def _run_task(self):
        cmd = self.task_entry.get().strip()
        self.task_entry.delete(0, "end")
        if not cmd: return
        if self.mode != "CONTROL":
            self._rpa_log("Activa modo CONTROL")
            return
        threading.Thread(target=lambda: self.rpa.run_command(cmd), daemon=True).start()

    def _run_nl(self):
        task = self.task_entry.get().strip()
        self.task_entry.delete(0, "end")
        if not task: return
        if self.mode != "CONTROL":
            self._rpa_log("Activa modo CONTROL")
            return
        threading.Thread(target=lambda: self.rpa.run_nl_task(task), daemon=True).start()

    def _run_script(self):
        text = self.cmd_box.get("1.0", "end-1c").strip()
        if not text: return
        if self.mode != "CONTROL":
            self._rpa_log("Activa modo CONTROL")
            return
        commands = [l.strip() for l in text.split('\n') if l.strip() and not l.strip().startswith('#')]
        if not commands: return
        self._rpa_log(f"Script: {len(commands)} comandos")
        threading.Thread(target=lambda: self.rpa.run_script(commands), daemon=True).start()

    def _show_help(self):
        d = ctk.CTkToplevel(self.win)
        d.title("Ayuda")
        d.geometry("500x450")
        ctk.CTkLabel(d, text="""COMANDOS RPA (escribe en la barra inferior):

click <texto>        Click en texto detectado
wait <texto> <seg>   Espera a que aparezca texto
type <texto>         Escribe texto
press <tecla>        Presiona tecla (enter,tab,esc)
open <app>           Abre app (Win+R)
search <query>       Busca en Chrome
see                  Lee pantalla con OCR
sleep <seg>          Pausa

LENGUAJE NATURAL (boton NL):
  "abre chrome y busca python"
  "escribe hola mundo y presiona enter"
  "que ves"

SCRIPT (panel RPA Script - multi-linea):
  open chrome
  sleep 3
  type python
  press enter

Atajos:
  Ctrl+Enter = ejecutar script""", font=("Consolas", 11), justify="left").pack(padx=20, pady=20)

    # ─── LIVE FEED ────────────────────────────────────

    def _update_feed(self):
        try:
            img = ImageGrab.grab(all_screens=True)
            frame = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
            self.frame_count += 1

            self.fps_counter += 1
            now = time.time()
            if now - self.fps_timer > 1.0:
                self.display_fps = self.fps_counter
                self.fps_counter = 0
                self.fps_timer = now

            if self.frame_count % 30 == 0:
                threading.Thread(target=self._run_ocr, daemon=True).start()

            display = cv2.resize(frame, (self.feed_w, self.feed_h))
            scx = self.feed_w / frame.shape[1]
            scy = self.feed_h / frame.shape[0]

            # Bounding boxes de RPA
            for d in self.rpa.current_matches[:15]:
                rx = int(d['x'] * scx); ry = int(d['y'] * scy)
                rw = int(d['w'] * scx); rh = int(d['h'] * scy)
                if 0 <= rx < self.feed_w and 0 <= ry < self.feed_h:
                    color = (0, 255, 100) if d['conf'] > 40 else (255, 200, 0)
                    cv2.rectangle(display, (rx-rw//2, ry-rh//2),
                                 (rx+rw//2, ry+rh//2), color, 1)

            cv2.putText(display, f"{self.mode} | {self.display_fps}fps",
                       (5, 15), cv2.FONT_HERSHEY_SIMPLEX, 0.4,
                       (0, 255, 100) if self.mode == "OBSERVADOR" else (0, 80, 255), 1)

            mx, my = pyautogui.position()
            cux, cuy = int(mx * scx), int(my * scy)
            if 0 <= cux < self.feed_w and 0 <= cuy < self.feed_h:
                cv2.drawMarker(display, (cux, cuy), (0, 255, 255), cv2.MARKER_CROSS, 8, 1)

            rgb = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
            ctk_img = ctk.CTkImage(light_image=Image.fromarray(rgb), size=(self.feed_w, self.feed_h))
            self.feed.configure(image=ctk_img, text="")

            self.st_bar.configure(
                text=f"{self.mode} | {self.display_fps}fps | {self.rpa.step_index}/{len(self.rpa.steps)} steps | Cursor: ({mx},{my})")
        except: pass
        self.win.after(60, self._update_feed)

    def _run_ocr(self):
        try:
            img = ImageGrab.grab(all_screens=True)
            gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
            gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
            self.last_ocr = pytesseract.image_to_string(gray)

            data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
            det = []
            for i in range(len(data['text'])):
                try:
                    conf = int(data['conf'][i])
                    word = data['text'][i].strip()
                    if conf > 25 and len(word) > 1:
                        det.append({'word': word,
                            'x': (data['left'][i]+data['width'][i]//2)*2,
                            'y': (data['top'][i]+data['height'][i]//2)*2,
                            'w': data['width'][i]*2, 'h': data['height'][i]*2,
                            'conf': conf})
                except: pass
            self.rpa.current_matches = det

            lines = [f"{d['word']} ({d['x']},{d['y']}) c:{d['conf']}" for d in det[:8]]
            self.det_box.delete("1.0", "end")
            self.det_box.insert("1.0", "\n".join(lines))
        except: pass

    def _close(self):
        self.running = False
        self.win.destroy()

if __name__ == "__main__":
    VisionRPA().win.mainloop()
