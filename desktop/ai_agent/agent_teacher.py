"""Agent Teacher - Modo Aprendizaje en Escritorio Virtual
Gola enseña tareas en un escritorio virtual separado.
El agente graba: cursor, clicks, teclas, pantallas.
Luego replica los movimientos como un humano.

Arquitectura:
  Escritorio 1 (Gola) - Tu espacio, intacto
  Escritorio 2 (Agente) - Donde se enseña y ejecuta

Modo GRABAR: Gola demuestra en escritorio 2
Modo REPLICAR: Agente reproduce en escritorio 2

Uso:
  python agent_teacher.py                    # GUI
  python agent_teacher.py --record "tarea1"  # CLI grabar
  python agent_teacher.py --replay "tarea1"  # CLI replicar
"""

import os, sys, time, json, threading
import pyautogui
from PIL import ImageGrab
import keyboard as kb
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# pyrefly: ignore [missing-import]
from desktop_switcher import DesktopSwitcher

pyautogui.FAILSAFE = True

# ─── Config ─────────────────────────────────────────
PORT = 8000
TEACH_DIR = os.path.join(os.path.dirname(__file__), "teachings")
os.makedirs(TEACH_DIR, exist_ok=True)

# ─── Escritorios ────────────────────────────────────
switcher = DesktopSwitcher(total=2)

# ─── Grabador de acciones ───────────────────────────
class ActionRecorder:
    """Graba todos los movimientos y acciones en tiempo real"""

    def __init__(self):
        self.recording = False
        self.actions = []
        self.start_time = 0
        self.last_pos = None
        self.screenshots_dir = None

    def start(self, name="demo"):
        self.recording = True
        self.actions = []
        self.start_time = time.time()
        self.last_pos = pyautogui.position()

        # Crear carpeta para screenshots
        self.screenshots_dir = os.path.join(TEACH_DIR, name, "screenshots")
        os.makedirs(self.screenshots_dir, exist_ok=True)

        # Screenshot inicial
        self._save_screenshot("start")

        # Hooks de teclado
        kb.on_press(self._on_key)
        kb.on_press_key('esc', self._on_esc)

        # Thread de tracking de mouse
        self.mouse_thread = threading.Thread(target=self._track_mouse, daemon=True)
        self.mouse_thread.start()

        print(f"[REC] Grabando '{name}' en escritorio {switcher.current}...")
        print("[REC] Presiona ESC para detener.")

    def stop(self):
        self.recording = False
        kb.unhook_all()
        self._save_screenshot("end")

        duration = time.time() - self.start_time
        print(f"[REC] Detenido. {len(self.actions)} acciones en {duration:.1f}s")

        return {
            "actions": self.actions,
            "duration": duration,
            "screen_size": list(pyautogui.size()),
            "desktop": switcher.current
        }

    def _track_mouse(self):
        """Trackea posicion del cursor cada 50ms"""
        while self.recording:
            pos = pyautogui.position()
            if pos != self.last_pos:
                elapsed = time.time() - self.start_time
                self.actions.append({
                    "type": "move",
                    "x": pos[0], "y": pos[1],
                    "t": round(elapsed, 3)
                })
                self.last_pos = pos
            time.sleep(0.05)

    def _on_key(self, event):
        if not self.recording: return
        elapsed = time.time() - self.start_time

        # Solo grabar teclas relevantes (ignorar modificadores solos)
        if event.name in ('shift', 'ctrl', 'alt', 'windows', 'right shift', 'right ctrl'):
            return

        self.actions.append({
            "type": "key",
            "key": event.name,
            "event": event.event_type,  # 'down' or 'up'
            "t": round(elapsed, 3)
        })

    def _on_esc(self, event):
        """ESC detiene la grabacion"""
        if self.recording:
            print("\n[REC] ESC presionado - deteniendo...")
            self.stop()

    def _save_screenshot(self, label):
        path = os.path.join(self.screenshots_dir, f"{label}.png")
        img = ImageGrab.grab(all_screens=True)
        img.save(path)
        return path

    def add_click(self):
        if not self.recording: return
        elapsed = time.time() - self.start_time
        x, y = pyautogui.position()
        self.actions.append({
            "type": "click",
            "x": x, "y": y,
            "button": "left",
            "t": round(elapsed, 3)
        })

    def add_right_click(self):
        if not self.recording: return
        elapsed = time.time() - self.start_time
        x, y = pyautogui.position()
        self.actions.append({
            "type": "click",
            "x": x, "y": y,
            "button": "right",
            "t": round(elapsed, 3)
        })

    def add_double_click(self):
        if not self.recording: return
        elapsed = time.time() - self.start_time
        x, y = pyautogui.position()
        self.actions.append({
            "type": "double_click",
            "x": x, "y": y,
            "t": round(elapsed, 3)
        })

    def add_scroll(self, amount):
        if not self.recording: return
        elapsed = time.time() - self.start_time
        self.actions.append({
            "type": "scroll",
            "amount": amount,
            "t": round(elapsed, 3)
        })


# ─── Replicador ─────────────────────────────────────
class ActionReplayer:
    """Replica acciones grabadas con movimiento humano"""

    def __init__(self):
        self.playing = False

    def replay(self, actions, speed=1.0, on_desktop=2):
        """Reproduce acciones en el escritorio virtual"""
        print(f"[PLAY] Cambiando a escritorio {on_desktop}...")
        switcher.switch_to(on_desktop)
        time.sleep(0.5)

        self.playing = True
        
        # Detectar formato: plan (YouTube) vs grabacion
        if actions and isinstance(actions[0], dict):
            if 'step' in actions[0] and 'action' in actions[0]:
                # Formato plan: ejecutar acciones del plan
                self._replay_plan(actions, speed)
            else:
                # Formato grabacion: reproducir timeline
                self._replay_timeline(actions, speed)
        
        self.playing = False
        switcher.go_user()
        return True

    def stop(self):
        self.playing = False

    def _replay_plan(self, plan, speed):
        """Ejecuta un plan de acciones (formato YouTube/teaching)"""
        for step in plan:
            if not self.playing: break
            action = step.get('action', '')
            desc = step.get('desc', action)
            print(f"[PLAY] {desc}")
            
            if action == 'click_text':
                target = step.get('text', '')
                # Usar OCR para encontrar y clickear
                try:
                    import pytesseract
                    from PIL import ImageGrab
                    import cv2, numpy as np
                    img = ImageGrab.grab(all_screens=True)
                    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
                    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
                    for i in range(len(data['text'])):
                        if target.lower() in data['text'][i].strip().lower() and int(data['conf'][i]) > 40:
                            cx = data['left'][i] + data['width'][i]//2
                            cy = data['top'][i] + data['height'][i]//2
                            pyautogui.click(cx, cy)
                            print(f"  Click en '{data['text'][i]}' ({cx},{cy})")
                            break
                    else:
                        print(f"  Texto '{target}' no encontrado")
                except:
                    print(f"  Error OCR")
            
            elif action == 'click':
                pyautogui.click(step.get('x', 960), step.get('y', 540))
            
            elif action == 'type':
                pyautogui.write(step.get('text', ''), interval=0.03)
            
            elif action == 'press':
                pyautogui.press(step.get('key', 'enter'))
            
            elif action == 'hotkey':
                pyautogui.hotkey(*step.get('keys', ['enter']))
            
            elif action == 'run':
                pyautogui.hotkey('win', 'r')
                time.sleep(0.4)
                pyautogui.write(step.get('app', ''), interval=0.03)
                pyautogui.press('enter')
            
            elif action == 'wait':
                ms = step.get('ms', 1000)
                if ms > 5000:
                    print(f"  Esperando {ms/1000:.0f}s...")
                time.sleep(ms / 1000 / speed)
            
            elif action == 'scroll':
                pyautogui.scroll(step.get('amount', -3))

    def _replay_timeline(self, actions, speed):
        """Reproduce grabacion con timeline (cursor, clicks, teclas)"""
        total = len(actions)
        start = time.time()
        actions_sorted = sorted(actions, key=lambda a: a.get('t', 0))
        print(f"[PLAY] Reproduciendo {total} acciones...")
        last_action_time = 0
        for i, action in enumerate(actions_sorted):
            if not self.playing: break
            wait = (action['t'] - last_action_time) / speed
            if wait > 0: time.sleep(wait)
            last_action_time = action['t']
            try:
                if action['type'] == 'move':
                    pyautogui.moveTo(action['x'], action['y'], duration=0.05)
                elif action['type'] == 'click':
                    pyautogui.click(action['x'], action['y'], button=action.get('button', 'left'))
                elif action['type'] == 'double_click':
                    pyautogui.doubleClick(action['x'], action['y'])
                elif action['type'] == 'key':
                    if action['event'] == 'down':
                        pyautogui.press(action['key'])
                elif action['type'] == 'scroll':
                    pyautogui.scroll(action['amount'])
                if i % 50 == 0:
                    print(f"\r[PLAY] {100*(i+1)//total}% ({i+1}/{total})", end='')
            except Exception as e:
                print(f"\n[PLAY] Error: {e}")
        elapsed = time.time() - start
        print(f"\n[PLAY] Completado en {elapsed:.1f}s")


# ─── Gestor de enseñanzas ───────────────────────────
class TeachingManager:
    """Guarda y carga sesiones de enseñanza"""

    @staticmethod
    def save(name, recording_data):
        path = os.path.join(TEACH_DIR, name, "recording.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            json.dump(recording_data, f, indent=2)
        print(f"[SAVE] Enseñanza '{name}' guardada ({len(recording_data['actions'])} acciones)")

    @staticmethod
    def load(name):
        path = os.path.join(TEACH_DIR, name, "recording.json")
        if not os.path.exists(path):
            print(f"[LOAD] Enseñanza '{name}' no encontrada")
            return None
        with open(path, 'r') as f:
            data = json.load(f)
        # Normalizar: garantizar key 'actions'
        if 'actions' not in data and 'plan' in data:
            data['actions'] = data['plan']
        return data

    @staticmethod
    def list_all():
        teachings = []
        if not os.path.exists(TEACH_DIR): return teachings
        for d in os.listdir(TEACH_DIR):
            rpath = os.path.join(TEACH_DIR, d, "recording.json")
            if os.path.exists(rpath):
                try:
                    with open(rpath) as f:
                        data = json.load(f)
                    actions = data.get("actions", data.get("plan", []))
                    teachings.append({
                        "name": d,
                        "actions": len(actions),
                        "duration": data.get("duration", 0),
                        "screen_size": data.get("screen_size", [0,0])
                    })
                except:
                    pass
        return teachings


# ─── Interfaz GUI ───────────────────────────────────
def launch_gui():
    """Interfaz grafica para enseñar y replicar"""
    try:
        import customtkinter as ctk
        ctk.set_appearance_mode("dark")
    except ImportError:
        print("ERROR: customtkinter no instalado. pip install customtkinter")
        return

    recorder = ActionRecorder()
    replayer = ActionReplayer()

    win = ctk.CTk()
    win.title("Agent Teacher — Enseña al Agente")
    win.geometry("700x600")

    # Título
    ctk.CTkLabel(win, text="🧠 AGENT TEACHER", font=("Consolas", 18, "bold"),
                 text_color="#00d97e").pack(pady=10)
    ctk.CTkLabel(win, text="Enseña tareas en el Escritorio 2. El agente aprende y replica.",
                 font=("Consolas", 11)).pack()

    # Frame principal
    main = ctk.CTkFrame(win)
    main.pack(fill="both", expand=True, padx=10, pady=5)

    # ── Panel GRABAR ──
    record_frame = ctk.CTkFrame(main)
    record_frame.pack(fill="x", padx=5, pady=5)
    ctk.CTkLabel(record_frame, text="🔴 MODO GRABAR", font=("Consolas", 13, "bold"),
                 text_color="#ff4444").pack(pady=2)

    # Nombre de la enseñanza
    name_frame = ctk.CTkFrame(record_frame)
    name_frame.pack(fill="x", padx=5, pady=3)
    ctk.CTkLabel(name_frame, text="Nombre:", font=("Consolas", 10)).pack(side="left", padx=5)
    name_entry = ctk.CTkEntry(name_frame, placeholder_text="ej: crear_cuenta_google", width=300)
    name_entry.pack(side="left", padx=5)

    # Botones grabacion
    btn_frame = ctk.CTkFrame(record_frame)
    btn_frame.pack(fill="x", padx=5, pady=5)

    status_label = ctk.CTkLabel(btn_frame, text="Listo", font=("Consolas", 10),
                                text_color="#888")
    status_label.pack(side="left", padx=5)

    def do_record():
        name = name_entry.get().strip() or f"demo_{int(time.time())}"
        status_label.configure(text=f"Grabando '{name}' en Escritorio 2...", text_color="#ff4444")
        win.update()

        # Cambiar a escritorio 2
        switcher.switch_to(2)
        time.sleep(0.5)

        recorder.start(name)
        status_label.configure(text="Grabando... Presiona ESC para detener.", text_color="#ff4444")

        # Esperar a que termine (monitorear recorder.recording)
        def wait_recording():
            while recorder.recording:
                time.sleep(0.5)
            # Guardar
            data = recorder.stop()
            TeachingManager.save(name, data)
            switcher.go_user()
            status_label.configure(text=f"Guardado: {len(data['actions'])} acciones", text_color="#00d97e")
            update_teachings_list()

        threading.Thread(target=wait_recording, daemon=True).start()

    ctk.CTkButton(btn_frame, text="🎬 Iniciar Grabacion", fg_color="#8B0000",
                  command=do_record).pack(side="left", padx=5)

    # Help
    ctk.CTkLabel(record_frame,
        text="La grabacion se hace en el Escritorio 2. Presiona ESC para detener.\n"
             "Tú trabajas en el Escritorio 1 sin interrupción.",
        font=("Consolas", 9), text_color="#666").pack(pady=3)

    # ── Panel REPLICAR ──
    replay_frame = ctk.CTkFrame(main)
    replay_frame.pack(fill="x", padx=5, pady=5)
    ctk.CTkLabel(replay_frame, text="▶️ MODO REPLICAR", font=("Consolas", 13, "bold"),
                 text_color="#4488ff").pack(pady=2)

    # Lista de enseñanzas
    teachings_list = ctk.CTkScrollableFrame(replay_frame, height=150)
    teachings_list.pack(fill="x", padx=5, pady=5)

    def update_teachings_list():
        for w in teachings_list.winfo_children():
            w.destroy()
        teachings = TeachingManager.list_all()
        if not teachings:
            ctk.CTkLabel(teachings_list, text="(sin enseñanzas guardadas)",
                        font=("Consolas", 10), text_color="#666").pack()
            return
        for t in teachings:
            row = ctk.CTkFrame(teachings_list)
            row.pack(fill="x", pady=2)
            ctk.CTkLabel(row, text=f"📁 {t['name']}", font=("Consolas", 10)).pack(side="left", padx=5)
            ctk.CTkLabel(row, text=f"{t['actions']} acc | {t['duration']:.1f}s",
                        font=("Consolas", 9), text_color="#888").pack(side="left", padx=5)
            ctk.CTkButton(row, text="▶ Replicar", width=80, height=24,
                         command=lambda n=t['name']: do_replay(n)).pack(side="right", padx=5)
            ctk.CTkButton(row, text="🗑", width=30, height=24,
                         fg_color="transparent", border_width=1,
                         command=lambda n=t['name']: delete_teaching(n)).pack(side="right")

    def do_replay(name):
        data = TeachingManager.load(name)
        if not data:
            status_label.configure(text=f"No encontrado: {name}", text_color="#ff4444")
            return
        status_label.configure(text=f"Replicando '{name}' en Escritorio 2...", text_color="#4488ff")
        win.update()

        def run_replay():
            replayer.replay(data["actions"], speed=1.0, on_desktop=2)
            status_label.configure(text=f"Replicado: {name}", text_color="#00d97e")

        threading.Thread(target=run_replay, daemon=True).start()

    def delete_teaching(name):
        import shutil
        path = os.path.join(TEACH_DIR, name)
        if os.path.exists(path):
            shutil.rmtree(path)
        update_teachings_list()

    update_teachings_list()

    # ── Velocidad ──
    speed_frame = ctk.CTkFrame(replay_frame)
    speed_frame.pack(fill="x", padx=5, pady=3)
    ctk.CTkLabel(speed_frame, text="Velocidad:", font=("Consolas", 10)).pack(side="left", padx=5)
    speed_var = ctk.StringVar(value="1.0")
    ctk.CTkOptionMenu(speed_frame, values=["0.5", "1.0", "1.5", "2.0"],
                      variable=speed_var, width=80).pack(side="left", padx=5)

    # ── Panel INFO ──
    info_frame = ctk.CTkFrame(main)
    info_frame.pack(fill="both", expand=True, padx=5, pady=5)
    ctk.CTkLabel(info_frame, text="¿COMO FUNCIONA?", font=("Consolas", 12, "bold"),
                 text_color="#ffaa00").pack(pady=3)

    info_text = ctk.CTkTextbox(info_frame, font=("Consolas", 10), height=120)
    info_text.pack(fill="both", expand=True, padx=5, pady=5)
    info_text.insert("1.0",
        "1. Pon un NOMBRE a la tarea que quieres enseñar\n"
        "2. Presiona INICIAR GRABACION\n"
        "3. El agente cambia al Escritorio 2 automaticamente\n"
        "4. Haz la tarea normalmente (mueve cursor, clickea, escribe)\n"
        "5. Presiona ESC para detener\n"
        "6. El agente vuelve al Escritorio 1 solo\n\n"
        "Para replicar:\n"
        "1. Selecciona una enseñanza de la lista\n"
        "2. Presiona REPLICAR\n"
        "3. El agente ejecuta todo en el Escritorio 2 sin tocarte el 1"
    )
    info_text.configure(state="disabled")

    # ── Boton escritorio ──
    bottom = ctk.CTkFrame(win, height=40)
    bottom.pack(fill="x", side="bottom", padx=10, pady=5)

    desk_btn = ctk.CTkButton(bottom, text="Ir a Escritorio 2 (manual)",
                             fg_color="transparent", border_width=1,
                             command=lambda: switcher.switch_to(2))
    desk_btn.pack(side="left", padx=5)

    ctk.CTkButton(bottom, text="Volver a Escritorio 1",
                  fg_color="transparent", border_width=1,
                  command=lambda: switcher.go_user()).pack(side="left", padx=5)

    win.mainloop()


# ─── CLI ───────────────────────────────────────────
def main():
    if len(sys.argv) < 2 or sys.argv[1] == '--gui':
        launch_gui()
        return

    recorder = ActionRecorder()
    replayer = ActionReplayer()

    if sys.argv[1] == '--record':
        name = sys.argv[2] if len(sys.argv) > 2 else f"demo_{int(time.time())}"
        print(f"\n{'='*50}")
        print(f"MODO GRABAR — Enseñando '{name}'")
        print(f"Cambiando a Escritorio 2...")
        print(f"Haz la tarea. Presiona ESC para detener.")
        print(f"{'='*50}\n")

        switcher.switch_to(2)
        time.sleep(0.5)
        recorder.start(name)

        # Esperar a que termine
        while recorder.recording:
            time.sleep(0.5)

        data = recorder.stop()
        TeachingManager.save(name, data)
        switcher.go_user()

    elif sys.argv[1] == '--replay':
        name = sys.argv[2] if len(sys.argv) > 2 else None
        if not name:
            teachings = TeachingManager.list_all()
            print("Enseñanzas disponibles:")
            for t in teachings:
                print(f"  {t['name']} ({t['actions']} acc, {t['duration']:.1f}s)")
            return

        data = TeachingManager.load(name)
        if not data: return

        print(f"\n{'='*50}")
        print(f"MODO REPLICAR — Ejecutando '{name}'")
        print(f"{'='*50}\n")

        replayer.replay(data["actions"], speed=1.0, on_desktop=2)

    elif sys.argv[1] == '--list':
        teachings = TeachingManager.list_all()
        if not teachings:
            print("No hay enseñanzas guardadas.")
            return
        print("\nEnseñanzas guardadas:")
        for t in teachings:
            print(f"  📁 {t['name']} — {t['actions']} acciones, {t['duration']:.1f}s")

    else:
        print("Agent Teacher - Modos:")
        print("  python agent_teacher.py              # GUI")
        print("  python agent_teacher.py --record NOMBRE  # Grabar enseñanza")
        print("  python agent_teacher.py --replay NOMBRE  # Replicar enseñanza")
        print("  python agent_teacher.py --list           # Listar enseñanzas")


if __name__ == '__main__':
    main()
