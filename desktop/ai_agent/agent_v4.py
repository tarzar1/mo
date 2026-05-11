"""Agent Loop V4 - Con Qwen2.5-VL-7B como cerebro visual
Ahora el agente VE realmente: botones, campos, estados, errores.
Qwen analiza la pantalla y decide las acciones.
Fallback a OCR si Qwen no esta disponible.

Servidor HTTP en puerto 8000.
"""

import sys, os, io, json, time, base64, threading, re
from http.server import HTTPServer, BaseHTTPRequestHandler
from PIL import ImageGrab

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pyautogui
pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.03

# ─── Vision (Qwen + OCR fallback) ─────────────────
try:
    import urllib.request as urllib2
    QWEN_URL = "http://192.168.4.30:11434/api/generate"
    QWEN_MODEL = "qwen2.5vl:7b"
    # Test connection
    r = urllib2.urlopen(f"http://192.168.4.30:11434/api/tags", timeout=3)
    HAS_QWEN = r.status == 200
except:
    HAS_QWEN = False
    print("[AGENT] Qwen no disponible, usando solo OCR")

try:
    import pytesseract, cv2, numpy as np
    for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
              r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
        if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break
    HAS_OCR = bool(pytesseract)
except: HAS_OCR = False

PORT = 8000


def capture_base64():
    img = ImageGrab.grab(all_screens=True)
    w, h = img.size
    img = img.resize((w//2, h//2))
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=60)
    return base64.b64encode(buf.getvalue()).decode()


def ask_qwen(prompt, image_b64=None):
    """Pregunta a Qwen2.5-VL"""
    if not HAS_QWEN: return ""
    if image_b64 is None: image_b64 = capture_base64()
    payload = {"model": QWEN_MODEL, "prompt": prompt, "images": [image_b64],
               "stream": False, "options": {"temperature": 0.1, "num_predict": 300}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=30)
        return json.loads(r.read().decode()).get("response", "")
    except:
        return ""


def see_screen():
    """Vision real: describe la pantalla"""
    prompt = """Describe what you see on this screenshot in Spanish, concise.
List: open apps, buttons, input fields, errors, loading states, dialogs.
If there's a form, list its fields and positions."""
    return ask_qwen(prompt) or _ocr_text()[:300]


def find_element(target):
    """Busca un elemento y devuelve coordenadas"""
    prompt = f"""Find UI element '{target}' in this screenshot.
Reply ONLY: x,y (approximate pixel coordinates). If not found: none"""
    resp = ask_qwen(prompt)
    if resp:
        m = re.search(r'(\d+)\s*[,;]\s*(\d+)', resp)
        if m: return (int(m.group(1)), int(m.group(2)))
    # Fallback OCR
    return _ocr_find(target)


def decide_next_action(task):
    """Qwen decide la proxima accion"""
    prompt = f"""TASK: {task}
Look at this screenshot. What is the NEXT SINGLE action?
Reply EXACTLY one line:
click_text "name" | click X Y | type "text" | press "key" | wait N | done
No explanations."""
    return ask_qwen(prompt).strip()


# ─── OCR fallback ────────────────────────────────
def _ocr_text():
    if not HAS_OCR: return ""
    img = ImageGrab.grab(all_screens=True)
    img = img.resize((img.size[0]//2, img.size[1]//2))
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    return pytesseract.image_to_string(gray, lang='spa+eng')

def _ocr_find(target):
    if not HAS_OCR: return None
    img = ImageGrab.grab(all_screens=True)
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
    for i in range(len(data['text'])):
        if target.lower() in data['text'][i].strip().lower() and int(data['conf'][i]) > 40:
            return (data['left'][i] + data['width'][i]//2, data['top'][i] + data['height'][i]//2)
    return None


# ─── Acciones ──────────────────────────────────────
def click_xy(x, y):
    pyautogui.click(x, y)
    return True

def click_element(target):
    pos = find_element(target)
    if pos:
        pyautogui.click(pos[0], pos[1])
        return True
    return False

def type_text(text):
    pyautogui.write(text, interval=0.03)
    return True


# ─── Loop autonomo con Qwen ────────────────────────
def run_task_autonomous(task):
    print(f"\n[AGENT V4] TAREA: {task}")
    print(f"[AGENT V4] Vision: {'Qwen2.5-VL-7B' if HAS_QWEN else 'OCR'}")

    screen_desc = see_screen()
    print(f"[VISION] {screen_desc[:200]}...")

    for step in range(15):
        action_line = decide_next_action(task)
        print(f"[STEP {step+1}] Qwen decide: {action_line}")

        if not action_line or 'done' in action_line.lower():
            print("[AGENT] Tarea completada segun Qwen")
            break

        # Parsear accion
        if action_line.startswith('click_text'):
            target = action_line.split('"')[1] if '"' in action_line else action_line.split()[-1]
            ok = click_element(target)
            print(f"  Click '{target}': {'OK' if ok else 'FAIL'}")
        elif action_line.startswith('click '):
            parts = action_line.split()
            try:
                x, y = int(parts[1]), int(parts[2])
                click_xy(x, y)
                print(f"  Click ({x},{y}): OK")
            except: pass
        elif action_line.startswith('type '):
            text = action_line.split('"')[1] if '"' in action_line else ' '.join(action_line.split()[1:])
            type_text(text)
            print(f"  Type: OK")
        elif action_line.startswith('press '):
            key = action_line.split('"')[1] if '"' in action_line else action_line.split()[-1]
            pyautogui.press(key)
            print(f"  Press '{key}': OK")
        elif action_line.startswith('wait '):
            try:
                ms = int(action_line.split()[-1])
                time.sleep(ms/1000)
            except: time.sleep(1)

        time.sleep(1.5)

    print("[AGENT] Loop completado")


# ─── Servidor HTTP ─────────────────────────────────
class AgentHandler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        self.send_response(200); self._cors(); self.end_headers()

    def do_GET(self):
        if self.path == '/health':
            self.send_response(200); self._cors(); self.end_headers()
            self.wfile.write(json.dumps({
                "status": "ok", "version": "v4-qwen",
                "vision": "qwen2.5vl-7b" if HAS_QWEN else "ocr"
            }).encode())
        elif self.path == '/see':
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self._cors(); self.end_headers()
            self.wfile.write(json.dumps({"description": see_screen()}).encode())
        elif self.path == '/feed.jpg':
            self.send_response(200); self.send_header('Content-Type', 'image/jpeg')
            self._cors(); self.end_headers()
            img = ImageGrab.grab(all_screens=True)
            w, h = img.size; img = img.resize((w//2, h//2))
            buf = io.BytesIO(); img.save(buf, format='JPEG', quality=50)
            self.wfile.write(buf.getvalue())
        else:
            self.send_response(404); self.end_headers()

    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(content_len))

        if self.path == '/task':
            task = body.get("task", "")
            t = threading.Thread(target=run_task_autonomous, args=(task,), daemon=True)
            t.start()
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self._cors(); self.end_headers()
            self.wfile.write(json.dumps({"status": "started"}).encode())

        elif self.path == '/command':
            action = body.get("action", "")
            result = {"ok": False}
            if action == "click_text":
                result["ok"] = click_element(body.get("text", ""))
            elif action == "click":
                click_xy(body.get("x", 960), body.get("y", 540))
                result["ok"] = True
            elif action == "type":
                type_text(body.get("text", ""))
                result["ok"] = True
            elif action == "press":
                pyautogui.press(body.get("key", "enter"))
                result["ok"] = True
            self.send_response(200); self.send_header('Content-Type', 'application/json')
            self._cors(); self.end_headers()
            self.wfile.write(json.dumps(result).encode())

        else:
            self.send_response(404); self.end_headers()

    def log_message(self, format, *args): pass


if __name__ == '__main__':
    print(f"[AGENT V4] Vision: {'Qwen2.5-VL-7B' if HAS_QWEN else 'OCR (fallback)'}")
    server = HTTPServer(('0.0.0.0', PORT), AgentHandler)
    print(f"[AGENT V4] http://192.168.4.23:{PORT}")
    print(f"  GET  /see   -> Qwen describe pantalla")
    print(f"  GET  /health -> Estado")
    print(f"  POST /task  -> Tarea autonoma con Qwen")
    print(f"  POST /command -> Accion directa")
    server.serve_forever()
