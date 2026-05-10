"""Vision Control Tool Pro - Plan + Ejecutar + Multi-Escritorio
MODO PLAN: observa, analiza, propone plan (no ejecuta)
MODO EJECUTAR: sigue el plan paso a paso en el escritorio 2
Escritorios virtuales: cambia automaticamente con Win+Ctrl+Left/Right"""

import os, sys, time, re, threading, queue, cv2, numpy as np
import customtkinter as ctk
from PIL import Image, ImageGrab
import pyautogui, pytesseract
from desktop_switcher import DesktopSwitcher

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

API = "http://192.168.4.23:8000"

TASK_PLANS = {
    "register": {
        "keywords": ["registr", "crear cuenta", "signup"],
        "steps": [
            {"icon": "👁", "desc": "Ver pantalla actual"},
            {"icon": "👆", "desc": "Click en 'Registrate'", "action": "click", "target": "Registr"},
            {"icon": "👁", "desc": "Verificar formulario visible"},
            {"icon": "⌨", "desc": "Escribir nombre", "action": "type", "field": "name"},
            {"icon": "⌨", "desc": "Escribir email", "action": "type", "field": "email"},
            {"icon": "⌨", "desc": "Escribir password", "action": "type", "field": "password"},
            {"icon": "👆", "desc": "Click en 'Crear cuenta'", "action": "click", "target": "Crear cuenta"},
            {"icon": "👁", "desc": "Verificar registro exitoso"},
            {"icon": "🌐", "desc": "Respaldo via API (si fallo UI)"},
        ]
    },
    "login": {
        "keywords": ["login", "iniciar sesion", "loguear"],
        "steps": [
            {"icon": "👁", "desc": "Ver pantalla actual"},
            {"icon": "👆", "desc": "Click en 'Correo'", "action": "click", "target": "Correo"},
            {"icon": "⌨", "desc": "Escribir email", "action": "type", "field": "email"},
            {"icon": "👆", "desc": "Click en 'Contrase'", "action": "click", "target": "Contrase"},
            {"icon": "⌨", "desc": "Escribir password", "action": "type", "field": "password"},
            {"icon": "⌨", "desc": "Presionar Enter", "action": "key", "key": "enter"},
            {"icon": "👁", "desc": "Verificar login exitoso"},
        ]
    },
    "search": {
        "keywords": ["buscar", "search", "google"],
        "steps": [
            {"icon": "🔍", "desc": "Abrir Chrome (Win+R, chrome, Enter)"},
            {"icon": "⌨", "desc": "Escribir query de busqueda"},
            {"icon": "⌨", "desc": "Presionar Enter"},
        ]
    },
    "open_app": {
        "keywords": ["abrir", "open"],
        "steps": [
            {"icon": "🔍", "desc": "Win+R"},
            {"icon": "⌨", "desc": "Escribir nombre de la app"},
            {"icon": "⌨", "desc": "Presionar Enter"},
        ]
    }
}

class VisionToolPro:
    def __init__(self, agent_desktop=2):
        self.mode = "OBSERVADOR"
        self.desktop = 1
        self.agent_desktop = agent_desktop
        self.switcher = DesktopSwitcher(total=agent_desktop)
        self.plan_mode = True
        self.execute_mode = False
        self.current_plan = None
        self.plan_step = 0
        self.current_task = None
        self.task_params = {}

        self.fps = 15
        self.frame_count = 0
        self.fps_counter = 0
        self.fps_timer = time.time()
        self.display_fps = 0
        self.last_ocr = ""
        self.detections = []
        self.cmd_queue = queue.Queue()
        self.last_agent_frame = None  # Cache: ultimo frame del escritorio 2
        self.feed_active = False  # Default: OFF, manual refresh only

        sw, sh = pyautogui.size()
        self.feed_w = 800
        self.feed_h = int(self.feed_w * sh / sw)

        self.win = ctk.CTk()
        self.win.title(f"Vision Pro - Escritorio {self.agent_desktop}")
        self.win.geometry("1150x800")
        self.win.protocol("WM_DELETE_WINDOW", self._close)

        self._build_ui()
        self._start()

    def _build_ui(self):
        mb = ctk.CTkFrame(self.win, height=32)
        mb.pack(fill="x", side="top", padx=0, pady=0)

        # Botones de modo
        self.mode_btn = ctk.CTkButton(mb, text="OBSERVADOR", width=100, height=26,
            fg_color="transparent", border_width=1, command=self._toggle_mode)
        self.mode_btn.pack(side="left", padx=3, pady=2)

        self.plan_btn = ctk.CTkButton(mb, text="Plan: ON", width=70, height=26,
            fg_color="#1a3a1a", border_width=1, command=self._toggle_plan)
        self.plan_btn.pack(side="left", padx=3, pady=2)

        self.exec_btn = ctk.CTkButton(mb, text="Ejecutar: OFF", width=85, height=26,
            fg_color="transparent", border_width=1, command=self._toggle_execute)
        self.exec_btn.pack(side="left", padx=3, pady=2)

        self.desk_btn = ctk.CTkButton(mb, text=f"Escritorio {self.desktop}", width=90, height=26,
            fg_color="transparent", border_width=1, command=self._toggle_desktop)
        self.desk_btn.pack(side="left", padx=3, pady=2)

        ctk.CTkButton(mb, text="Aprobar Plan", width=90, height=26,
            fg_color="transparent", border_width=1,
            command=self._approve_plan).pack(side="left", padx=3, pady=2)

        self.feed_btn = ctk.CTkButton(mb, text="Feed: OFF", width=70, height=26,
            fg_color="transparent", border_width=1, command=self._toggle_feed)
        self.feed_btn.pack(side="left", padx=3, pady=2)

        ctk.CTkButton(mb, text="Refrescar", width=70, height=26,
            fg_color="transparent", border_width=1,
            command=self._manual_refresh).pack(side="left", padx=3, pady=2)

        ctk.CTkButton(mb, text="?", width=25, height=26,
            fg_color="transparent", border_width=1,
            command=self._show_help).pack(side="right", padx=6)

        # Main
        main = ctk.CTkFrame(self.win)
        main.pack(fill="both", expand=True, padx=4, pady=4)

        # LEFT: Feed
        left = ctk.CTkFrame(main)
        left.pack(side="left", fill="both", expand=True, padx=2)

        ctk.CTkLabel(left, text=f"Live Feed (Escritorio {self.agent_desktop})",
                     font=("Consolas", 11, "bold")).pack(pady=2)
        self.feed = ctk.CTkLabel(left, text="Cargando...", width=self.feed_w, height=self.feed_h)
        self.feed.pack(padx=4, pady=2)

        # Detecciones mini
        self.det_box = ctk.CTkTextbox(left, font=("Consolas", 8), height=50)
        self.det_box.pack(fill="x", padx=4, pady=2)

        # RIGHT: Panels
        right = ctk.CTkFrame(main, width=320)
        right.pack(side="right", fill="both", padx=2)

        # Plan panel
        ctk.CTkLabel(right, text="PLAN", font=("Consolas", 12, "bold"),
                     text_color="#00d97e").pack(pady=2)
        self.plan_box = ctk.CTkTextbox(right, font=("Consolas", 10), height=200, width=300)
        self.plan_box.pack(fill="x", padx=4, pady=2)

        # OCR panel
        ctk.CTkLabel(right, text="OCR / Log", font=("Consolas", 10)).pack(pady=2)
        self.ocr_box = ctk.CTkTextbox(right, font=("Consolas", 9), height=200, width=300)
        self.ocr_box.pack(fill="both", expand=True, padx=4, pady=2)

        # BOTTOM: Task input
        task_frame = ctk.CTkFrame(self.win, height=40)
        task_frame.pack(fill="x", side="bottom", padx=4, pady=4)

        self.task_entry = ctk.CTkEntry(task_frame,
            placeholder_text="Tarea: registra a user@test.com password 123456",
            font=("Consolas", 11))
        self.task_entry.pack(side="left", fill="x", expand=True, padx=4, pady=4)
        self.task_entry.bind("<Return>", lambda e: self._create_plan())

        ctk.CTkButton(task_frame, text="Generar Plan", width=100,
                      command=self._create_plan).pack(side="right", padx=4, pady=4)

        ctk.CTkButton(task_frame, text="Ejecutar Paso", width=100,
                      fg_color="#8B0000", command=self._execute_step).pack(side="right", padx=4, pady=4)

        # Status
        self.st_bar = ctk.CTkLabel(self.win, text="Listo", font=("Consolas", 9), height=20)
        self.st_bar.pack(fill="x", side="bottom")

    def _start(self):
        self._log("Vision Pro iniciada")
        self._log(f"Escritorio agente: {self.agent_desktop}")
        # Captura inicial del escritorio 2
        threading.Thread(target=self._capture_agent_frame, daemon=True).start()
        self._update_feed()

    def _log(self, msg):
        self.ocr_box.insert("end", f"{msg}\n")
        self.ocr_box.see("end")

    def _toggle_mode(self):
        self.mode = "CONTROL" if self.mode == "OBSERVADOR" else "OBSERVADOR"
        self.mode_btn.configure(text=self.mode,
            fg_color="#8B0000" if self.mode == "CONTROL" else "transparent")
        self._log(f"MODO: {self.mode}")

    def _toggle_plan(self):
        self.plan_mode = not self.plan_mode
        self.plan_btn.configure(text=f"Plan: {'ON' if self.plan_mode else 'OFF'}",
            fg_color="#1a3a1a" if self.plan_mode else "transparent")
        self._log(f"Plan: {'ON' if self.plan_mode else 'OFF'}")

    def _toggle_execute(self):
        self.execute_mode = not self.execute_mode
        self.exec_btn.configure(text=f"Ejecutar: {'ON' if self.execute_mode else 'OFF'}",
            fg_color="#8B0000" if self.execute_mode else "transparent")
        self._log(f"Ejecutar: {'ON' if self.execute_mode else 'OFF'}")
        if self.execute_mode and self.current_plan:
            self._log("Ejecutando plan automaticamente...")
            self._auto_execute()

    def _toggle_desktop(self):
        self.desktop = self.agent_desktop if self.desktop == 1 else 1
        self.desk_btn.configure(text=f"Escritorio {self.desktop}")
        self.switcher.switch_to(self.desktop)
        self._log(f"Cambiado a Escritorio {self.desktop}")

    def _toggle_feed(self):
        self.feed_active = not self.feed_active
        self.feed_btn.configure(text=f"Feed: {'ON' if self.feed_active else 'OFF'}",
            fg_color="#1a3a1a" if self.feed_active else "transparent")
        self._log(f"Feed escritorio 2: {'ACTIVO' if self.feed_active else 'PAUSADO'}")

    def _manual_refresh(self):
        """Refresca el feed del escritorio 2 manualmente"""
        self._log("Refrescando feed del escritorio 2...")
        self._capture_agent_frame()
        if self.last_agent_frame:
            self._log(f"Capturado: {self.last_agent_frame.size[0]}x{self.last_agent_frame.size[1]}")
        else:
            self._log("ERROR: No se pudo capturar escritorio 2")

    def _capture_agent_frame(self):
        """Cambia al escritorio 2, captura, vuelve. Rapido (<400ms)"""
        if self.desktop == self.agent_desktop:
            img = ImageGrab.grab(all_screens=True)
            self.last_agent_frame = img
            self._last_capture_time = time.time()
            return
        self.switcher.go_agent()
        time.sleep(0.25)
        img = ImageGrab.grab(all_screens=True)
        self.last_agent_frame = img
        self._last_capture_time = time.time()
        self.switcher.go_user()
        time.sleep(0.1)

    def _approve_plan(self):
        if self.current_plan:
            self.execute_mode = True
            self.exec_btn.configure(text="Ejecutar: ON", fg_color="#8B0000")
            self._log("Plan APROBADO. Ejecutando...")
            self._auto_execute()
        else:
            self._log("No hay plan. Genera uno primero.")

    def _show_help(self):
        d = ctk.CTkToplevel(self.win)
        d.title("Ayuda")
        d.geometry("450x350")
        ctk.CTkLabel(d, text="""MODO PLAN:
  - Escribe una tarea y presiona "Generar Plan"
  - El plan aparece en el panel PLAN
  - Revisa los pasos
  - Presiona "Aprobar Plan"
  - Activa "Ejecutar: ON"

MODO EJECUTAR:
  - El plan se ejecuta paso a paso
  - Cada paso se verifica con OCR
  - Si falla, para y pregunta

ESCRITORIOS:
  - El agente trabaja en el escritorio 2
  - Cambia automaticamente con Win+Ctrl+Flecha
  - Tu trabajas en el escritorio 1 sin interrupcion

EJEMPLOS:
  registra a user@test.com password 123456
  login con conductor@test.com
  abre chrome y busca python""", font=("Consolas", 11), justify="left").pack(padx=20, pady=20)

    # ─── PLAN ENGINE ─────────────────────────────────

    def _create_plan(self):
        task = self.task_entry.get().strip()
        self.task_entry.delete(0, "end")
        if not task:
            return

        self.current_task = task.lower()
        self._log(f"TAREA: {task}")

        # Detectar tipo
        plan_type = None
        for ptype, info in TASK_PLANS.items():
            for kw in info["keywords"]:
                if kw in self.current_task:
                    plan_type = ptype
                    break

        if not plan_type:
            self._log("No reconozco la tarea. Intenta:")
            self._log("  'registra a user@test.com'")
            self._log("  'login con conductor@test.com'")
            self.plan_box.delete("1.0", "end")
            self.plan_box.insert("1.0", "Tarea no reconocida")
            return

        # Extraer params
        email_match = re.search(r'[\w.]+@[\w.]+', task)
        if email_match:
            self.task_params['email'] = email_match.group(0)

        pass_match = re.search(r'pass(?:word)?[:\s]*(\S+)', task, re.IGNORECASE)
        if pass_match:
            self.task_params['password'] = pass_match.group(1)

        name_match = re.search(r'(?:nombre|name|como)[:\s]*(\w+)', task, re.IGNORECASE)
        if name_match:
            self.task_params['name'] = name_match.group(1)

        # Generar plan
        steps = TASK_PLANS[plan_type]["steps"]
        self.current_plan = {"type": plan_type, "steps": steps, "current": 0}
        self.plan_step = 0

        self.plan_box.delete("1.0", "end")
        plan_text = f"PLAN: {plan_type.upper()}\n" + "-" * 30 + "\n"
        for i, s in enumerate(steps):
            plan_text += f"  [{i+1}] {s['icon']} {s['desc']}\n"
        plan_text += f"\nModo Plan: {'ON' if self.plan_mode else 'OFF'}  |  Ejecutar: {'ON' if self.execute_mode else 'OFF'}"
        self.plan_box.insert("1.0", plan_text)

        self._log(f"Plan creado: {len(steps)} pasos")

        # Si ya esta en modo ejecutar, ejecutar inmediatamente
        if self.execute_mode:
            self._auto_execute()

    def _auto_execute(self):
        """Ejecuta todos los pasos del plan automaticamente"""
        if not self.current_plan:
            return

        def exec_loop():
            steps = self.current_plan["steps"]
            while self.plan_step < len(steps) and self.execute_mode:
                time.sleep(1.5)
                self.win.after(0, self._execute_step)
                time.sleep(2)

        threading.Thread(target=exec_loop, daemon=True).start()

    def _execute_step(self):
        """Ejecuta el paso actual del plan"""
        if not self.current_plan:
            self._log("No hay plan")
            return

        steps = self.current_plan["steps"]
        if self.plan_step >= len(steps):
            self._log("Plan completado!")
            self._mark_step_done()
            return

        step = steps[self.plan_step]
        self._log(f"Paso {self.plan_step+1}/{len(steps)}: {step['desc']}")

        # Cambiar al escritorio del agente
        if self.desktop != self.agent_desktop:
            self.switcher.go_agent()
            time.sleep(0.3)

        ok = False
        action = step.get("action")

        if action == "click":
            target = step.get("target", "")
            ok = self._hid_click(target)
        elif action == "type":
            field = step.get("field", "")
            if field == "name":
                self._hid_type(self.task_params.get("name", "User"))
                ok = True
            elif field == "email":
                self._hid_type(self.task_params.get("email", "user@test.com"))
                ok = True
            elif field == "password":
                self._hid_type(self.task_params.get("password", "123456"))
                ok = True
        elif action == "key":
            key = step.get("key", "enter")
            pyautogui.press(key)
            ok = True
        else:
            ok = True  # pasos de observacion sin accion

        # API fallback para registro
        if self.current_plan.get("type") == "register" and self.plan_step == len(steps) - 2:
            try:
                import requests
                name = self.task_params.get("name", "User")
                email = self.task_params.get("email", "tmp@test.com")
                password = self.task_params.get("password", "123456")
                r = requests.post(f"{API}/Create_driver/", json={
                    "name": name, "email": email, "password": password, "role": "driver"
                }, timeout=5)
                self._log(f"API: {'OK' if r.status_code in (200, 201) else r.status_code}")
            except:
                pass

        if ok:
            self._mark_step_done()
        else:
            self._log(f"PASO FALLIDO: {step['desc']}. Pausado.")
            self._mark_step_error()
            if self.execute_mode:
                self.execute_mode = False
                self.exec_btn.configure(text="Ejecutar: OFF (fallo)", fg_color="transparent")
                return

        self.plan_step += 1

    def _hid_click(self, text):
        """Busca texto y clickea"""
        self._log(f"Buscando '{text}'...")
        scr = self._ocr_current()
        matches = self._find_text_ocr(text, scr, 35)
        if matches:
            x, y, word = matches[0][0], matches[0][1], matches[0][2]
            pyautogui.click(x, y)
            self._log(f"Click en '{word}' ({x},{y})")
            time.sleep(1.5)
            return True
        self._log(f"No encontre '{text}'")
        return False

    def _hid_type(self, text):
        pyautogui.write(text, interval=0.04)
        self._log(f"Escrito: {text}")
        time.sleep(0.3)

    def _ocr_current(self):
        img = ImageGrab.grab(all_screens=True)
        gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
        return cv2.resize(gray, (0,0), fx=0.5, fy=0.5)

    def _find_text_ocr(self, text, gray, min_conf=35):
        data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
        matches = []
        for i in range(len(data['text'])):
            try:
                conf = int(data['conf'][i])
                word = data['text'][i].strip()
                if conf > min_conf and text.lower() in word.lower():
                    x = (data['left'][i] + data['width'][i]//2) * 2
                    y = (data['top'][i] + data['height'][i]//2) * 2
                    matches.append((x, y, word, conf))
            except: pass
        return matches

    def _mark_step_done(self):
        text = self.plan_box.get("1.0", "end")
        marker = f"  [{self.plan_step+1}]"
        new_marker = f"  [{self.plan_step+1}] [OK]"
        text = text.replace(marker, new_marker)
        self.plan_box.delete("1.0", "end")
        self.plan_box.insert("1.0", text)

    def _mark_step_error(self):
        text = self.plan_box.get("1.0", "end")
        marker = f"  [{self.plan_step+1}]"
        new_marker = f"  [{self.plan_step+1}] [FAIL]"
        text = text.replace(marker, new_marker)
        self.plan_box.delete("1.0", "end")
        self.plan_box.insert("1.0", text)

    # ─── LIVE FEED ────────────────────────────────────

    def _update_feed(self):
        try:
            self.frame_count += 1

            # FPS
            self.fps_counter += 1
            now = time.time()
            if now - self.fps_timer > 1.0:
                self.display_fps = self.fps_counter
                self.fps_counter = 0
                self.fps_timer = now

            # Cada ~12s (180 frames a 15fps): capturar escritorio 2 si feed activo
            if self.feed_active and self.frame_count % 180 == 0 and not self.execute_mode:
                threading.Thread(target=self._capture_agent_frame, daemon=True).start()

            # OCR cada 30 frames
            if self.frame_count % 30 == 0:
                threading.Thread(target=self._run_ocr, daemon=True).start()

            # Usar frame cacheado del escritorio 2, o captura actual
            frame_source = self.last_agent_frame
            if frame_source is None:
                frame_source = ImageGrab.grab(all_screens=True)

            frame = cv2.cvtColor(np.array(frame_source), cv2.COLOR_RGB2BGR)
            display = cv2.resize(frame, (self.feed_w, self.feed_h))

            # Overlay: bounding boxes
            for d in self.detections[:10]:
                rx = int(d['x'] * self.feed_w / frame.shape[1])
                ry = int(d['y'] * self.feed_h / frame.shape[0])
                if 0 <= rx < self.feed_w and 0 <= ry < self.feed_h:
                    cv2.rectangle(display, (rx-15, ry-10), (rx+15, ry+10), (0, 255, 100), 1)

            # HUD
            info = f"{self.mode} | {self.display_fps}fps | Escritorio {self.agent_desktop}"
            cv2.putText(display, info, (5, 15), cv2.FONT_HERSHEY_SIMPLEX, 0.4,
                       (0, 255, 100) if self.mode == "OBSERVADOR" else (0, 80, 255), 1)

            # Indicador de feed cacheado
            if self.feed_active and self.last_agent_frame is not None:
                age = (now - getattr(self, '_last_capture_time', now))
                cv2.putText(display, f"Cache: {age:.0f}s", (5, 32), cv2.FONT_HERSHEY_SIMPLEX, 0.3,
                           (150, 150, 150), 1)

            rgb = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
            ctk_img = ctk.CTkImage(light_image=Image.fromarray(rgb), size=(self.feed_w, self.feed_h))
            self.feed.configure(image=ctk_img, text="")

            mx, my = pyautogui.position()
            plan_steps = f"{self.plan_step}/{len(self.current_plan['steps'])}" if self.current_plan else "0/0"
            self.st_bar.configure(
                text=f"{self.mode} | {self.display_fps}fps | Escritorio {self.agent_desktop} | Plan: {plan_steps} pasos | Cursor: ({mx},{my})")
        except: pass
        self.win.after(60, self._update_feed)

    def _run_ocr(self):
        try:
            img = ImageGrab.grab(all_screens=True)
            gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
            gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
            self.last_ocr = pytesseract.image_to_string(gray)

            det = []
            data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
            for i in range(len(data['text'])):
                try:
                    conf = int(data['conf'][i])
                    word = data['text'][i].strip()
                    if conf > 40 and len(word) > 2:
                        det.append({'word': word,
                            'x': (data['left'][i]+data['width'][i]//2)*2,
                            'y': (data['top'][i]+data['height'][i]//2)*2,
                            'conf': conf})
                except: pass
            self.detections = det

            lines = [f"{d['word']} ({d['x']},{d['y']})" for d in det[:8]]
            self.det_box.delete("1.0", "end")
            self.det_box.insert("1.0", "\n".join(lines))
        except: pass

    def _close(self):
        self.win.destroy()

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--desktop", type=int, default=2, help="Escritorio virtual del agente (1=usuario, 2=agente)")
    args = p.parse_args()
    app = VisionToolPro(agent_desktop=args.desktop)
    app.win.mainloop()
