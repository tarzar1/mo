"""Vision CLI - Integracion para OpenClaw
Permite a Claw ver, clickear, escribir y controlar la PC desde linea de comandos.

Uso:
  python vision_cli.py screenshot [--agent]
  python vision_cli.py ocr [--agent]
  python vision_cli.py click X Y [--agent]
  python vision_cli.py click_text "texto" [--agent]
  python vision_cli.py type "texto" [--agent]
  python vision_cli.py press "enter" [--agent]
  python vision_cli.py hotkey "ctrl+v" [--agent]
  python vision_cli.py open "notepad" [--agent]
  python vision_cli.py livefeed  # Inicia servidor HTTP de feed en vivo
"""

import sys
import os
import time
import json
import io
import base64

# Añadir directorio al path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pyautogui
from PIL import ImageGrab
from desktop_switcher import DesktopSwitcher

pyautogui.FAILSAFE = True

# OCR
try:
    import pytesseract
    for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
              r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
        if os.path.exists(p):
            pytesseract.pytesseract.tesseract_cmd = p
            break
    HAS_OCR = True
except:
    HAS_OCR = False

HAS_OCR = 'pytesseract' in dir() and hasattr(pytesseract, 'image_to_string')

OUT_DIR = os.path.join(os.path.dirname(__file__), "captures")
os.makedirs(OUT_DIR, exist_ok=True)

switcher = DesktopSwitcher(total=2)


def _use_agent():
    return "--agent" in sys.argv


def cmd_screenshot():
    """Captura pantalla y la guarda. Devuelve ruta."""
    if _use_agent():
        img = switcher.capture_agent()
    else:
        img = ImageGrab.grab(all_screens=True)

    path = os.path.join(OUT_DIR, f"capture_{int(time.time())}.png")
    img.save(path)
    print(json.dumps({"status": "ok", "path": path, "size": list(img.size)}))
    return path


def cmd_ocr():
    """Lee texto de la pantalla actual (o escritorio agente)."""
    if not HAS_OCR:
        print(json.dumps({"status": "error", "msg": "Tesseract no encontrado"}))
        return

    if _use_agent():
        img = switcher.capture_agent()
    else:
        img = ImageGrab.grab(all_screens=True)

    import cv2
    import numpy as np
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    text = pytesseract.image_to_string(gray, lang='spa+eng')
    print(json.dumps({"status": "ok", "text": text.strip()}))


def cmd_click():
    """Click en coordenadas. Uso: click X Y [--agent]"""
    try:
        x = int(sys.argv[2])
        y = int(sys.argv[3])
    except (IndexError, ValueError):
        print(json.dumps({"status": "error", "msg": "Uso: click X Y"}))
        return

    if _use_agent():
        def do(): pyautogui.click(x, y)
        switcher.execute_agent(do)
    else:
        pyautogui.click(x, y)

    print(json.dumps({"status": "ok", "x": x, "y": y}))


def cmd_click_text():
    """Click en texto encontrado via OCR. Uso: click_text "Registrate" [--agent]"""
    if not HAS_OCR:
        print(json.dumps({"status": "error", "msg": "Tesseract no encontrado"}))
        return

    try:
        target = sys.argv[2]
    except IndexError:
        print(json.dumps({"status": "error", "msg": "Uso: click_text <texto>"}))
        return

    if _use_agent():
        switcher.go_agent()
        time.sleep(0.3)

    import cv2
    import numpy as np
    img = ImageGrab.grab(all_screens=True)
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')

    for i in range(len(data['text'])):
        conf = int(data['conf'][i])
        word = data['text'][i].strip()
        if conf > 50 and target.lower() in word.lower():
            cx = data['left'][i] + data['width'][i] // 2
            cy = data['top'][i] + data['height'][i] // 2
            pyautogui.click(cx, cy)
            print(json.dumps({"status": "ok", "found": word, "x": cx, "y": cy}))

            if _use_agent():
                switcher.go_user()
            return

    print(json.dumps({"status": "not_found", "target": target}))
    if _use_agent():
        switcher.go_user()


def cmd_type():
    """Escribe texto. Uso: type "texto" [--agent]"""
    try:
        text = sys.argv[2]
    except IndexError:
        print(json.dumps({"status": "error", "msg": "Uso: type <texto>"}))
        return

    if _use_agent():
        def do(): pyautogui.write(text, interval=0.05)
        switcher.execute_agent(do)
    else:
        pyautogui.write(text, interval=0.05)

    print(json.dumps({"status": "ok", "text": text}))


def cmd_press():
    """Presiona tecla. Uso: press enter|tab|esc|ctrl+v|win+r [--agent]"""
    try:
        key = sys.argv[2]
    except IndexError:
        print(json.dumps({"status": "error", "msg": "Uso: press <tecla>"}))
        return

    if _use_agent():
        def do(): pyautogui.hotkey(*key.split('+'))
        switcher.execute_agent(do)
    else:
        pyautogui.hotkey(*key.split('+'))

    print(json.dumps({"status": "ok", "key": key}))


def cmd_open():
    """Abre aplicacion via Win+R. Uso: open "chrome" [--agent]"""
    try:
        app = sys.argv[2]
    except IndexError:
        print(json.dumps({"status": "error", "msg": "Uso: open <app>"}))
        return

    if _use_agent():
        def do():
            pyautogui.hotkey('win', 'r')
            time.sleep(0.3)
            pyautogui.write(app, interval=0.05)
            pyautogui.press('enter')
        switcher.execute_agent(do)
    else:
        pyautogui.hotkey('win', 'r')
        time.sleep(0.3)
        pyautogui.write(app, interval=0.05)
        pyautogui.press('enter')

    print(json.dumps({"status": "ok", "app": app}))


def cmd_livefeed():
    """Servidor HTTP que sirve capturas en vivo como MJPEG (opcional)"""
    port = 8000
    print(f"Live feed en http://192.168.4.23:{port}/screenshot.jpg")
    print("Endpoint: GET /screenshot.jpg -> ultima captura")

    try:
        from http.server import HTTPServer, BaseHTTPRequestHandler
    except ImportError:
        from http.server import HTTPServer, BaseHTTPRequestHandler

    class FeedHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path in ('/', '/screenshot.jpg'):
                self.send_response(200)
                self.send_header('Content-Type', 'image/jpeg')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                img = ImageGrab.grab(all_screens=True)
                buf = io.BytesIO()
                img.save(buf, format='JPEG', quality=70)
                self.wfile.write(buf.getvalue())
            elif self.path == '/ocr':
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                if HAS_OCR:
                    import cv2, numpy as np
                    img = ImageGrab.grab(all_screens=True)
                    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
                    text = pytesseract.image_to_string(gray, lang='spa+eng')
                    self.wfile.write(json.dumps({"text": text.strip()}).encode())
                else:
                    self.wfile.write(json.dumps({"error": "OCR no disponible"}).encode())
            elif self.path == '/health':
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'OK')

        def log_message(self, format, *args):
            pass  # Silenciar logs HTTP

    server = HTTPServer(('0.0.0.0', port), FeedHandler)
    print(f"Servidor iniciado. Ctrl+C para detener.")
    server.serve_forever()


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Vision CLI - Comandos: screenshot, ocr, click, click_text, type, press, open, livefeed")
        print("  --agent : ejecuta en escritorio del agente (virtual desktop 2)")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    commands = {
        'screenshot': cmd_screenshot,
        'ocr': cmd_ocr,
        'click': cmd_click,
        'click_text': cmd_click_text,
        'type': cmd_type,
        'press': cmd_press,
        'open': cmd_open,
        'livefeed': cmd_livefeed,
    }

    if cmd in commands:
        commands[cmd]()
    else:
        print(json.dumps({"status": "error", "msg": f"Comando desconocido: {cmd}"}))
        print("Comandos:", list(commands.keys()))
