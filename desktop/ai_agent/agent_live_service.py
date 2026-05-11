"""Agent Live Service - Servidor WebSocket + HTTP
Stream en vivo de pantalla. Recibe comandos y los ejecuta.
OpenClaw (Claw) es el cerebro: mira el feed → decide → envía comandos.

Endpoints:
  GET  /feed.jpg        → Screenshot JPEG (live)
  GET  /ocr             → OCR del texto en pantalla (JSON)
  GET  /screen          → Screenshot + OCR juntos (JSON con base64)
  GET  /health          → Estado
  POST /command         → Ejecutar comando (JSON)
  WS   /ws              → WebSocket para comandos bidireccional
"""

import sys, os, io, json, time, base64, threading, queue
from http.server import HTTPServer, BaseHTTPRequestHandler
import asyncio
import websockets

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pyautogui
from PIL import ImageGrab
from desktop_switcher import DesktopSwitcher
import keyboard as kb

pyautogui.FAILSAFE = True

# ─── OCR ─────────────────────────────────────────────
try:
    import pytesseract
    import cv2
    import numpy as np
    for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
              r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
        if os.path.exists(p):
            pytesseract.pytesseract.tesseract_cmd = p
            break
    HAS_OCR = True
except:
    HAS_OCR = False

# ─── Estado global ─────────────────────────────────
switcher = DesktopSwitcher(total=2)
PORT = 8000
command_queue = queue.Queue()  # Comandos pendientes
last_result = queue.Queue()    # Resultados de comandos
active_loop = False
loop_task = None


# ─── Captura ───────────────────────────────────────
def capture_screen():
    img = ImageGrab.grab(all_screens=True)
    return img

def capture_jpeg(quality=50):
    img = capture_screen()
    # Reducir para velocidad
    w, h = img.size
    img = img.resize((w//2, h//2))
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=quality)
    return buf.getvalue()

def ocr_screen():
    if not HAS_OCR:
        return {"error": "Tesseract no disponible"}
    img = capture_screen()
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    text = pytesseract.image_to_string(gray, lang='spa+eng')
    # OCR con posiciones
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
    elements = []
    for i in range(len(data['text'])):
        conf = int(data['conf'][i])
        word = data['text'][i].strip()
        if conf > 30 and word:
            elements.append({
                "text": word,
                "x": data['left'][i] + data['width'][i] // 2,
                "y": data['top'][i] + data['height'][i] // 2,
                "w": data['width'][i],
                "h": data['height'][i],
                "conf": conf
            })
    return {"text": text.strip(), "elements": elements}

def screen_full():
    """Screenshot base64 + OCR juntos"""
    img = capture_screen()
    # Reducir
    w, h = img.size
    img_small = img.resize((w//2, h//2))
    buf = io.BytesIO()
    img_small.save(buf, format='JPEG', quality=50)
    b64 = base64.b64encode(buf.getvalue()).decode()

    result = {"image_b64": b64, "size": [w, h]}
    if HAS_OCR:
        gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
        text = pytesseract.image_to_string(gray, lang='spa+eng')
        result["ocr"] = text.strip()
    return result


# ─── Ejecutor de comandos ─────────────────────────
def execute_command(cmd):
    """Ejecuta un comando y devuelve resultado"""
    try:
        action = cmd.get("action", "")
        params = cmd.get("params", {})

        if action == "click":
            x, y = params["x"], params["y"]
            pyautogui.moveTo(x, y, duration=0.1)
            pyautogui.click()
            return {"status": "ok", "action": "click", "x": x, "y": y}

        elif action == "double_click":
            x, y = params["x"], params["y"]
            pyautogui.moveTo(x, y, duration=0.1)
            pyautogui.doubleClick()
            return {"status": "ok", "action": "double_click", "x": x, "y": y}

        elif action == "right_click":
            x, y = params["x"], params["y"]
            pyautogui.moveTo(x, y, duration=0.1)
            pyautogui.rightClick()
            return {"status": "ok", "action": "right_click", "x": x, "y": y}

        elif action == "click_text":
            text = params["text"]
            return _click_text(text)

        elif action == "move":
            x, y = params["x"], params["y"]
            pyautogui.moveTo(x, y, duration=params.get("duration", 0.2))
            return {"status": "ok", "action": "move", "x": x, "y": y}

        elif action == "type":
            text = params["text"]
            pyautogui.write(text, interval=params.get("interval", 0.03))
            return {"status": "ok", "action": "type", "text": text}

        elif action == "press":
            key = params["key"]
            pyautogui.press(key)
            return {"status": "ok", "action": "press", "key": key}

        elif action == "hotkey":
            keys = params["keys"]
            pyautogui.hotkey(*keys)
            return {"status": "ok", "action": "hotkey", "keys": keys}

        elif action == "scroll":
            amount = params.get("amount", -3)
            pyautogui.scroll(amount)
            return {"status": "ok", "action": "scroll", "amount": amount}

        elif action == "drag":
            x1, y1 = params["x1"], params["y1"]
            x2, y2 = params["x2"], params["y2"]
            pyautogui.moveTo(x1, y1)
            pyautogui.drag(x2-x1, y2-y1, duration=params.get("duration", 0.5))
            return {"status": "ok", "action": "drag"}

        elif action == "run":
            # Abrir app via Win+R
            app = params["app"]
            pyautogui.hotkey('win', 'r')
            time.sleep(0.3)
            pyautogui.write(app, interval=0.04)
            pyautogui.press('enter')
            return {"status": "ok", "action": "run", "app": app}

        elif action == "screenshot":
            path = params.get("path", "capture.png")
            img = capture_screen()
            img.save(path)
            return {"status": "ok", "action": "screenshot", "path": path}

        elif action == "wait":
            ms = params.get("ms", 500)
            time.sleep(ms / 1000.0)
            return {"status": "ok", "action": "wait", "ms": ms}

        elif action == "batch":
            # Ejecutar secuencia de comandos
            results = []
            for subcmd in params.get("commands", []):
                r = execute_command(subcmd)
                results.append(r)
                if subcmd.get("params", {}).get("wait", 0):
                    time.sleep(subcmd["params"]["wait"] / 1000.0)
            return {"status": "ok", "action": "batch", "results": results}

        else:
            return {"status": "error", "msg": f"Acción desconocida: {action}"}

    except Exception as e:
        return {"status": "error", "msg": str(e)}


def _click_text(text):
    if not HAS_OCR:
        return {"status": "error", "msg": "OCR no disponible"}

    img = capture_screen()
    import cv2, numpy as np
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')

    for i in range(len(data['text'])):
        conf = int(data['conf'][i])
        word = data['text'][i].strip()
        if conf > 40 and text.lower() in word.lower():
            cx = data['left'][i] + data['width'][i] // 2
            cy = data['top'][i] + data['height'][i] // 2
            pyautogui.click(cx, cy)
            return {"status": "ok", "action": "click_text", "found": word, "x": cx, "y": cy}

    return {"status": "not_found", "action": "click_text", "target": text}


# ─── HTTP Server ──────────────────────────────────
class AgentHandler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path in ('/', '/feed.jpg'):
            self.send_response(200)
            self.send_header('Content-Type', 'image/jpeg')
            self._cors()
            self.end_headers()
            self.wfile.write(capture_jpeg())

        elif self.path == '/ocr':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._cors()
            self.end_headers()
            self.wfile.write(json.dumps(ocr_screen(), ensure_ascii=False).encode())

        elif self.path == '/screen':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._cors()
            self.end_headers()
            self.wfile.write(json.dumps(screen_full(), ensure_ascii=False).encode())

        elif self.path == '/health':
            self.send_response(200)
            self._cors()
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/command':
            content_len = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_len)
            cmd = json.loads(body)

            result = execute_command(cmd)

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self._cors()
            self.end_headers()
            self.wfile.write(json.dumps(result, ensure_ascii=False).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Silencioso

# ─── WebSocket Server ─────────────────────────────
connected_clients = set()

async def ws_handler(websocket, path=None):
    connected_clients.add(websocket)
    print(f"[WS] Cliente conectado. Total: {len(connected_clients)}")
    try:
        async for message in websocket:
            try:
                cmd = json.loads(message)
                result = execute_command(cmd)
                await websocket.send(json.dumps(result, ensure_ascii=False))
            except json.JSONDecodeError:
                await websocket.send(json.dumps({"status": "error", "msg": "JSON inválido"}))
            except Exception as e:
                await websocket.send(json.dumps({"status": "error", "msg": str(e)}))
    except:
        pass
    finally:
        connected_clients.discard(websocket)
        print(f"[WS] Cliente desconectado. Total: {len(connected_clients)}")


async def start_ws():
    print(f"[WS] WebSocket en ws://0.0.0.0:{PORT+1}/ws")
    async with websockets.serve(ws_handler, "0.0.0.0", PORT+1):
        await asyncio.Future()  # Run forever


def run_ws():
    asyncio.run(start_ws())

# ─── Main ─────────────────────────────────────────
if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--mode', default='http', choices=['http', 'ws', 'all'])
    args = parser.parse_args()

    if args.mode in ('ws', 'all'):
        ws_thread = threading.Thread(target=run_ws, daemon=True)
        ws_thread.start()

    if args.mode in ('http', 'all'):
        server = HTTPServer(('0.0.0.0', PORT), AgentHandler)
        print(f"[HTTP] Server: http://192.168.4.23:{PORT}")
        print("  GET  /feed.jpg  -> Screenshot JPEG")
        print("  GET  /ocr       -> Texto en pantalla")
        print("  GET  /screen    -> Screenshot + OCR (base64)")
        print("  POST /command   -> Ejecutar accion")
        print()
        print("Comandos: click, click_text, type, press, hotkey,")
        print("          move, scroll, drag, run, batch, screenshot, wait")
        server.serve_forever()
