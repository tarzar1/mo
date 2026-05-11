"""Agent Loop V3 - Persistente con verificacion de foco
El agente NUNCA se rinde. Cada accion tiene multiples estrategias.
ANTES de escribir/clickear, verifica que la ventana correcta tenga el foco.
Si no, usa Alt+Tab, click en titulo, o Win+numero para refocalizar.

Estrategias por accion:
  click_text:  OCR exacto -> OCR parcial -> Keywords -> Flexible -> Aproximacion
  open_app:    Start Menu -> Win+R nombre -> Win+R .exe
  type:        verifica foco -> pyautogui.write -> clipboard paste
  find_click:  5 intentos con estrategias diferentes

Uso:
  python agent_loop.py --server
"""

import sys, os, io, json, time, base64, threading, queue, re
from http.server import HTTPServer, BaseHTTPRequestHandler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pyautogui
from PIL import ImageGrab

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.03

try:
    import pytesseract, cv2, numpy as np
    for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
              r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
        if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break
    HAS_OCR = True
except: HAS_OCR = False

PORT = 8000
STATE_FILE = os.path.join(os.path.dirname(__file__), "agent_state.json")


def capture():
    return ImageGrab.grab(all_screens=True)

def capture_jpeg(quality=50):
    img = capture()
    w, h = img.size
    img = img.resize((w//2, h//2))
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=quality)
    return buf.getvalue()

def ocr_screen():
    if not HAS_OCR: return {"text": "", "elements": []}
    img = capture()
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    text = pytesseract.image_to_string(gray, lang='spa+eng')
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
    elements = []
    for i in range(len(data['text'])):
        conf = int(data['conf'][i]); word = data['text'][i].strip()
        if conf > 25 and word:
            elements.append({"text": word, "x": data['left'][i]+data['width'][i]//2,
                "y": data['top'][i]+data['height'][i]//2,
                "w": data['width'][i], "h": data['height'][i], "conf": conf})
    return {"text": text.strip(), "elements": elements}

def get_screen_size():
    return pyautogui.size()


class ActionFailed(Exception):
    def __init__(self, action, reason, tried_strategies):
        self.action = action; self.reason = reason; self.tried_strategies = tried_strategies
        super().__init__(f"Action failed after {len(tried_strategies)} strategies: {reason}")


class PersistentAgent:
    """Agente que prueba multiples estrategias hasta lograrlo"""

    def __init__(self):
        self.strategies_tried = []
        self.total_actions = 0; self.total_retries = 0

    # ── DETECTAR VENTANA ACTIVA ──────────────
    def get_active_window_context(self):
        screen = ocr_screen()
        titles = []
        for el in screen["elements"]:
            if el["conf"] > 75 and el["y"] < 50:
                titles.append(el["text"])
        context_words = []
        for el in screen["elements"]:
            if el["conf"] > 70 and el["y"] < 100:
                context_words.append(el["text"])
        return {"titles": titles, "top_text": ' '.join(context_words)}

    # ── ASEGURAR FOCO ────────────────────────
    def ensure_focus(self, app_keywords, max_attempts=5):
        for attempt in range(max_attempts):
            ctx = self.get_active_window_context()
            all_text = ' '.join(ctx["titles"] + [ctx["top_text"]]).lower()
            if any(kw.lower() in all_text for kw in app_keywords):
                return {"focused": True, "window": all_text[:80], "attempt": attempt+1}

            # Buscar ventana en pantalla y clickear titulo
            screen = ocr_screen()
            found = False
            for el in screen["elements"]:
                if any(kw.lower() in el["text"].lower() for kw in app_keywords) and el["conf"] > 50:
                    pyautogui.click(el["x"], el["y"])
                    time.sleep(0.5); found = True; break

            if not found:
                # Alt+Tab para ciclar
                pyautogui.keyDown('alt')
                for _ in range(min(attempt+1, 5)):
                    pyautogui.press('tab'); time.sleep(0.2)
                pyautogui.keyUp('alt')
                time.sleep(0.5)

            if attempt >= 3:
                pyautogui.click(100, 1060); time.sleep(0.2)
                pyautogui.keyDown('alt'); time.sleep(0.1)
                for _ in range(3): pyautogui.press('tab'); time.sleep(0.15)
                pyautogui.keyUp('alt'); time.sleep(0.5)

        return {"focused": False, "attempts": max_attempts}

    # ── CLICK EN TEXTO ──────────────────────────
    def click_text(self, target, max_attempts=5):
        strategies = [
            ("OCR exacto", lambda: self._click_ocr_exact(target)),
            ("OCR contiene", lambda: self._click_ocr_contains(target)),
            ("Palabras clave", lambda: self._click_keywords(target)),
            ("OCR flexible", lambda: self._click_ocr_flexible(target)),
            ("Aproximacion", lambda: self._click_approx(target)),
        ]
        for name, strategy in strategies:
            self.strategies_tried.append(name)
            result = strategy()
            if result: self.total_retries += len(self.strategies_tried)-1; return result
            time.sleep(0.2)
        raise ActionFailed("click_text", f"No se encontro '{target}'", self.strategies_tried)

    def _click_ocr_exact(self, target):
        screen = ocr_screen()
        for el in screen["elements"]:
            if el["text"].lower() == target.lower() and el["conf"] > 50:
                pyautogui.click(el["x"], el["y"])
                return {"found": el["text"], "x": el["x"], "y": el["y"], "strategy": "ocr_exact"}
        return None

    def _click_ocr_contains(self, target):
        screen = ocr_screen()
        best = None
        for el in screen["elements"]:
            if target.lower() in el["text"].lower() and el["conf"] > 40:
                if best is None or el["conf"] > best["conf"]: best = el
        if best:
            pyautogui.click(best["x"], best["y"])
            return {"found": best["text"], "x": best["x"], "y": best["y"], "strategy": "ocr_contains"}
        return None

    def _click_keywords(self, target):
        keywords = target.lower().split()
        screen = ocr_screen()
        for el in screen["elements"]:
            if any(kw in el["text"].lower() for kw in keywords) and el["conf"] > 45:
                pyautogui.click(el["x"], el["y"])
                return {"found": el["text"], "x": el["x"], "y": el["y"], "strategy": "keywords"}
        return None

    def _click_ocr_flexible(self, target):
        screen = ocr_screen()
        for el in screen["elements"]:
            if el["conf"] > 30 and any(c in el["text"].lower() for c in target.lower()[:3]):
                pyautogui.click(el["x"], el["y"])
                return {"found": el["text"], "x": el["x"], "y": el["y"], "strategy": "ocr_flexible"}
        return None

    def _click_approx(self, target):
        sw, sh = get_screen_size()
        screen = ocr_screen()
        for el in screen["elements"]:
            if el["conf"] > 20 and any(c in el["text"].lower() for c in target.lower()[:2]):
                pyautogui.click(el["x"], el["y"])
                return {"found": el["text"], "x": el["x"], "y": el["y"], "strategy": "approx"}
        return None

    # ── ABRIR APP ──────────────────────────────
    def open_app(self, app_name, max_attempts=3):
        strategies = [
            ("Start Menu", lambda: self._open_start_menu(app_name)),
            ("Win+R .exe", lambda: self._open_win_r(app_name.replace(' ', '') + '.exe')),
            ("Win+R nombre", lambda: self._open_win_r(app_name)),
        ]
        for name, strategy in strategies:
            self.strategies_tried = [name]
            try: return strategy()
            except: pass
            time.sleep(0.3)
        raise ActionFailed("open_app", f"No se pudo abrir '{app_name}'", self.strategies_tried)

    def _open_start_menu(self, app_name):
        pyautogui.press('win'); time.sleep(0.5)
        pyautogui.write(app_name, interval=0.04); time.sleep(0.7)
        pyautogui.press('enter'); time.sleep(1.5)
        return {"strategy": "start_menu"}

    def _open_win_r(self, name):
        pyautogui.hotkey('win', 'r'); time.sleep(0.4)
        pyautogui.write(name, interval=0.03); time.sleep(0.3)
        pyautogui.press('enter'); time.sleep(1.5)
        return {"strategy": "win_r"}

    # ── ESCRIBIR (CON VERIFICACION DE FOCO) ──
    def type_text(self, text, target_app=None):
        if target_app:
            keywords = target_app if isinstance(target_app, list) else [target_app]
            focus = self.ensure_focus(keywords, max_attempts=4)
            if not focus.get("focused"):
                sw, sh = get_screen_size()
                pyautogui.click(sw//2, sh//2); time.sleep(0.3)
        try:
            pyautogui.write(text, interval=0.03)
            return {"strategy": "pyautogui", "focused": True}
        except:
            import subprocess
            escaped = text.replace('"', '""')
            subprocess.run(f'powershell -command "Set-Clipboard -Value \'{escaped}\'"', shell=True, timeout=5)
            time.sleep(0.2); pyautogui.hotkey('ctrl', 'v')
            return {"strategy": "clipboard"}

    # ── ESPERAR TEXTO ──────────────────────────
    def wait_for_text(self, target, timeout=15):
        deadline = time.time() + timeout
        while time.time() < deadline:
            screen = ocr_screen()
            for el in screen["elements"]:
                if target.lower() in el["text"].lower() and el["conf"] > 40:
                    return {"found": el["text"], "x": el["x"], "y": el["y"]}
            time.sleep(0.4)
        raise ActionFailed("wait_for_text", f"Timeout '{target}' ({timeout}s)", [])


# ═══════════════════════════════════════════════════════
# PLANIFICADOR CON VERIFICACION DE CONTEXTO
# ═══════════════════════════════════════════════════════

class TaskPlanner:
    def plan(self, task, screen):
        task_lower = task.lower()

        # ─── ABRIR CHROME Y BUSCAR ───────────
        if any(w in task_lower for w in ['abre chrome', 'abrir chrome', 'chrome']) and \
           any(w in task_lower for w in ['busca', 'buscar', 'youtube', 'google', 'search', 'busqueda']):
            query = self._extract_query(task)
            is_yt = "youtube" in task_lower
            url = "youtube.com" if is_yt else query
            return {
                "name": "abrir_chrome_y_buscar",
                "actions": [
                    {"action": "open_app", "app": "google chrome", "desc": "Abrir Chrome"},
                    {"action": "wait", "ms": 2500},
                    {"action": "verify_focus", "app": ["chrome", "google"], "desc": "Verificar Chrome activo"},
                    {"action": "click_text", "text": "chrome", "desc": "Click en Chrome"},
                    {"action": "hotkey", "keys": ["ctrl", "l"], "desc": "Barra direcciones"},
                    {"action": "wait", "ms": 300},
                    {"action": "type", "text": url, "target_app": ["chrome", "google"], "desc": f"Escribir {url}"},
                    {"action": "press", "key": "enter", "desc": "Ir"},
                    {"action": "wait", "ms": 3000},
                    {"action": "verify_text", "text": "youtube" if is_yt else query[:10], "desc": "Verificar carga"},
                ]
            }

        # ─── SOLO ABRIR APP ──────────────────
        if any(w in task_lower for w in ['abre', 'abrir', 'lanza', 'ejecuta', 'inicia', 'corre']) and \
           not any(w in task_lower for w in ['busca', 'buscar', 'youtube', 'navega']):
            app = self._extract_app(task)
            target = self._app_keywords(app)
            return {
                "name": "abrir_app",
                "actions": [
                    {"action": "open_app", "app": app, "desc": f"Abrir {app}"},
                    {"action": "wait", "ms": 2000},
                    {"action": "verify_focus", "app": target, "desc": f"Verificar {app}"},
                    {"action": "click_text", "text": target[0], "desc": f"Click en {app}"},
                    {"action": "wait", "ms": 300},
                ]
            }

        # ─── ESCRIBIR ────────────────────────
        if any(w in task_lower for w in ['escribe', 'escribir', 'type', 'teclea']):
            text = self._extract_text(task)
            target = self._detect_target(screen)
            return {
                "name": "escribir",
                "actions": [
                    {"action": "verify_focus", "app": target, "desc": "Verificar ventana activa"},
                    {"action": "click_text", "text": target[0] if target else "", "desc": "Click en ventana"},
                    {"action": "wait", "ms": 300},
                    {"action": "type", "text": text, "target_app": target, "desc": "Escribir texto"},
                ]
            }

        # ─── BUSCAR ──────────────────────────
        if any(w in task_lower for w in ['busca', 'buscar', 'youtube', 'google', 'navega a', 've a']):
            query = self._extract_query(task)
            return {
                "name": "buscar",
                "actions": [
                    {"action": "verify_focus", "app": ["chrome", "google", "edge"], "desc": "Verificar navegador"},
                    {"action": "hotkey", "keys": ["ctrl", "l"], "desc": "Barra direcciones"},
                    {"action": "wait", "ms": 200},
                    {"action": "type", "text": query, "target_app": ["chrome", "google"], "desc": f"Escribir {query}"},
                    {"action": "press", "key": "enter", "desc": "Buscar"},
                    {"action": "wait", "ms": 2000},
                ]
            }

        # ─── CLICK ───────────────────────────
        if any(w in task_lower for w in ['click en', 'cliquea', 'dale a', 'presiona el boton', 'clickea', 'pincha']):
            target = self._extract_target(task)
            return {"name": "click", "actions": [{"action": "click_text", "text": target, "desc": f"Click {target}"}]}

        # ─── PRESIONAR TECLA ────────────────
        if any(w in task_lower for w in ['presiona', 'pulsa', 'aprieta']):
            key = self._extract_key(task)
            return {"name": "press_key", "actions": [{"action": "press", "key": key, "desc": f"Presionar {key}"}]}

        return None

    def _app_keywords(self, app_name):
        """Mapea nombre de app a keywords de ventana (multi-idioma)"""
        mapping = {
            'notepad': ['notepad', 'bloc de notas', 'sin titulo', 'untitled'],
            'chrome': ['chrome', 'google chrome', 'nueva pestana', 'new tab'],
            'google chrome': ['chrome', 'google chrome', 'nueva pestana', 'new tab'],
            'edge': ['edge', 'microsoft edge'],
            'firefox': ['firefox', 'mozilla firefox'],
            'word': ['word', 'microsoft word', 'documento'],
            'excel': ['excel', 'microsoft excel'],
            'code': ['code', 'visual studio code', 'visual studio'],
            'cmd': ['cmd', 'simbolo del sistema', 'command prompt', 'powershell'],
            'powershell': ['powershell', 'windows powershell'],
            'explorer': ['explorador', 'file explorer', 'explorador de archivos'],
            'calc': ['calculadora', 'calculator'],
            'spotify': ['spotify'],
            'whatsapp': ['whatsapp'],
            'discord': ['discord'],
            'steam': ['steam'],
        }
        al = app_name.lower().strip()
        for key, keywords in mapping.items():
            if key in al or al in key:
                return keywords
        return [al]

    def _detect_target(self, screen):
        text = screen.get("text", "").lower()
        if "notepad" in text or "bloc de notas" in text: return ["notepad", "bloc de notas", "sin titulo"]
        if "chrome" in text or "google" in text: return ["chrome", "google"]
        if "word" in text: return ["word", "documento"]
        if "code" in text or "visual studio" in text: return ["code", "visual studio"]
        return ["notepad", "word", "chrome", "navegador"]

    def _extract_query(self, task):
        for p in ['busca', 'buscar', 'search', 'google', 'youtube', 'busqueda', 'navega a', 've a']:
            idx = task.lower().find(p)
            if idx >= 0:
                q = task[idx+len(p):].strip().lstrip(':').strip()
                return q if q else task
        return task

    def _extract_text(self, task):
        for p in ['escribe', 'escribir', 'type', 'teclea', 'redacta', 'texto']:
            idx = task.lower().find(p)
            if idx >= 0: return task[idx+len(p):].strip().lstrip(':').strip()
        return task

    def _extract_key(self, task):
        for k in ['enter', 'tab', 'esc', 'escape', 'espacio', 'space']:
            if k in task.lower(): return k if k != 'espacio' else 'space'
        return 'enter'

    def _extract_app(self, task):
        for p in ['abre', 'abrir', 'lanza', 'ejecuta', 'inicia', 'corre']:
            idx = task.lower().find(p)
            if idx >= 0:
                app = task[idx+len(p):].strip()
                for w in ['el ', 'la ', 'un ', 'una ']:
                    app = app[len(w):] if app.lower().startswith(w) else app
                words = app.split()
                stop = ['y', 'busca', 'buscar', 'google', 'luego', 'despues', 'entonces']
                result = []
                for w in words:
                    if w.lower() in stop: break
                    result.append(w)
                return ' '.join(result)
        return task

    def _extract_target(self, task):
        for p in ['click en', 'haz click en', 'cliquea', 'dale a', 'clickea en', 'pincha en', 'presiona el boton']:
            idx = task.lower().find(p)
            if idx >= 0: return task[idx+len(p):].strip().strip('"\'')
        return task


# ═══════════════════════════════════════════════════════
# EJECUTOR
# ═══════════════════════════════════════════════════════

agent = PersistentAgent()
planner = TaskPlanner()


def execute_with_fallback(action, step_num):
    a = action["action"]
    desc = action.get("desc", a)
    result = {"ok": False, "tried": [], "action": a}

    try:
        if a == "open_app":
            r = agent.open_app(action["app"]); result.update({"ok": True, **r})
        elif a == "click_text":
            r = agent.click_text(action["text"]); result.update({"ok": True, **r})
        elif a == "type":
            target = action.get("target_app")
            r = agent.type_text(action["text"], target_app=target); result.update({"ok": True, **r})
        elif a == "press":
            pyautogui.press(action["key"]); result.update({"ok": True})
        elif a == "hotkey":
            pyautogui.hotkey(*action["keys"]); result.update({"ok": True})
        elif a == "click":
            pyautogui.click(action["x"], action["y"]); result.update({"ok": True})
        elif a == "double_click":
            pyautogui.doubleClick(action["x"], action["y"]); result.update({"ok": True})
        elif a == "scroll":
            pyautogui.scroll(action.get("amount", -3)); result.update({"ok": True})
        elif a == "move":
            pyautogui.moveTo(action["x"], action["y"], duration=0.2); result.update({"ok": True})
        elif a == "drag":
            pyautogui.moveTo(action["x1"], action["y1"])
            pyautogui.drag(action["x2"]-action["x1"], action["y2"]-action["y1"], duration=0.5)
            result.update({"ok": True})
        elif a == "wait":
            time.sleep(action.get("ms", 1000)/1000.0); result.update({"ok": True})
        elif a == "screenshot":
            img = capture(); img.save(action.get("path", "capture.png")); result.update({"ok": True})
        elif a == "verify_focus":
            keywords = action.get("app", [])
            r = agent.ensure_focus(keywords, max_attempts=5)
            result.update({"ok": r.get("focused", False), "focus_result": r})
        elif a == "verify_text":
            try:
                r = agent.wait_for_text(action["text"], action.get("timeout", 10))
                result.update({"ok": True, "verified": True, "found_at": r})
            except ActionFailed as e:
                result.update({"ok": False, "error": str(e)})
        else:
            result.update({"ok": False, "error": f"Accion desconocida: {a}"})

        return result
    except ActionFailed as e:
        result.update({"ok": False, "error": str(e), "tried": e.tried_strategies}); return result
    except Exception as e:
        result.update({"ok": False, "error": str(e)}); return result


# ═══════════════════════════════════════════════════════
# LOOP PRINCIPAL
# ═══════════════════════════════════════════════════════

class AgentState:
    def __init__(self):
        self.task = ""; self.step = 0; self.status = "idle"
        self.history = []; self.mode = "autonomous"; self.lock = threading.Lock()

state = AgentState()


def run_task(task):
    global state
    with state.lock:
        state.task = task; state.step = 0; state.status = "running"; state.history = []

    print(f"\n{'='*60}")
    print(f"[AGENT V3] TAREA: {task}")
    print(f"[AGENT V3] Verificacion de foco ACTIVADA")
    print(f"{'='*60}\n")

    screen = ocr_screen()
    print(f"[AGENT] OCR: {len(screen['elements'])} elementos detectados")

    plan = planner.plan(task, screen)
    if not plan:
        print(f"[AGENT] Tarea no reconocida. Guardando estado.")
        with state.lock: state.status = "waiting"; _save_state()
        return

    print(f"[AGENT] Plan: {plan['name']} ({len(plan['actions'])} pasos)")

    for i, action in enumerate(plan["actions"]):
        step = i + 1
        desc = action.get("desc", action.get("action", "?"))
        wait_ms = action.get("ms", 0)

        print(f"\n[AGENT] Paso {step}/{len(plan['actions'])}: {desc}")

        result = execute_with_fallback(action, step)
        with state.lock:
            state.step = step; state.last_action = action; state.last_result = result
            state.history.append({"step": step, "action": action, "result": result})

        if result.get("ok"):
            print(f"  [OK] {desc}")
        else:
            print(f"  [FAIL] {desc}: {result.get('error', '?')}")
            # Reintentos
            if action["action"] == "verify_focus":
                print("  [RETRY] Refocalizando agresivamente...")
                pyautogui.keyDown('alt')
                for _ in range(3): pyautogui.press('tab'); time.sleep(0.15)
                pyautogui.keyUp('alt'); time.sleep(0.5)
                retry = execute_with_fallback(action, step)
                if retry.get("ok"):
                    print("  [OK] Foco recuperado!")

        if wait_ms: time.sleep(wait_ms/1000.0)

    with state.lock: state.status = "done"; _save_state()
    print(f"\n[AGENT] COMPLETADO. {len(plan['actions'])} pasos ejecutados.")
    print(f"{'='*60}\n")


def _save_state():
    data = {"task": state.task, "step": state.step, "status": state.status,
            "mode": state.mode, "history": state.history[-10:]}
    with open(STATE_FILE, 'w') as f: json.dump(data, f, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════
# SERVIDOR HTTP
# ═══════════════════════════════════════════════════════

class AgentHandler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        self.send_response(200); self._cors(); self.end_headers()

    def do_GET(self):
        if self.path == '/feed.jpg':
            self.send_response(200); self.send_header('Content-Type', 'image/jpeg')
            self._cors(); self.end_headers(); self.wfile.write(capture_jpeg())
        elif self.path == '/ocr':
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self._cors(); self.end_headers()
            self.wfile.write(json.dumps(ocr_screen(), ensure_ascii=False).encode())
        elif self.path == '/state':
            _save_state(); self.send_response(200)
            self.send_header('Content-Type', 'application/json'); self._cors(); self.end_headers()
            with open(STATE_FILE, 'r') as f: self.wfile.write(f.read().encode())
        elif self.path == '/health':
            self.send_response(200); self._cors(); self.end_headers()
            self.wfile.write(b'{"status":"ok","version":"v3-focus-verify"}')
        else:
            self.send_response(404); self.end_headers()

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(content_len))
        if self.path == '/task':
            task = body.get("task", "")
            t = threading.Thread(target=run_task, args=(task,), daemon=True)
            t.start()
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self._cors(); self.end_headers()
            self.wfile.write(json.dumps({"status": "started", "task": task}).encode())
        elif self.path == '/command':
            result = execute_with_fallback(body, 0)
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self._cors(); self.end_headers()
            self.wfile.write(json.dumps(result, ensure_ascii=False).encode())
        else:
            self.send_response(404); self.end_headers()

    def log_message(self, format, *args): pass


def start_server():
    server = HTTPServer(('0.0.0.0', PORT), AgentHandler)
    print(f"[AGENT V3] Server con verificacion de foco: http://192.168.4.23:{PORT}")
    server.serve_forever()


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] == '--server':
        start_server()
    else:
        run_task(' '.join(sys.argv[1:]))
