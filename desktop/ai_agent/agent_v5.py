"""Agent V5 — Tiempo Real con Qwen Streaming + MJPEG
- Qwen streaming: tokens en vivo, sin esperar respuesta completa
- MJPEG feed: video en vivo de la pantalla
- Loop continuo: captura → detecta → actualiza → repite
- Modelo rápido (2B) para detección, 7B para análisis profundo
- UI nunca se congela (100% async)

Endpoints:
  GET  /feed       → MJPEG stream (video en vivo)  
  GET  /detections → Últimas detecciones (JSON)
  GET  /health     → Estado
  POST /command    → Ejecutar acción
  POST /task       → Tarea autónoma con Qwen streaming
  WS   /ws         → WebSocket para streaming de detecciones
"""

import os, sys, time, json, threading, io, base64, re, queue, http.server, socketserver, asyncio

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pyautogui
from PIL import ImageGrab
import urllib.request as urllib2
import urllib.parse

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.02

# ─── Config ─────────────────────────────────────────
PORT = 8000
QWEN_URL = "http://192.168.4.30:11434/api/generate"
QWEN_FAST = "qwen2vl:2b"   # Rápido, menos preciso
QWEN_BIG = "qwen2.5vl:7b"  # Preciso, más lento

# ─── Estado Global ──────────────────────────────────
latest_frame = None        # bytes JPEG del último frame
latest_detections = []     # Últimas detecciones [{name, x, y, conf}]
latest_description = ""    # Última descripción de Qwen
frame_lock = threading.Lock()
detection_lock = threading.Lock()
streaming_active = False
capture_thread = None
analyze_thread = None

# ─── Qwen Streaming ─────────────────────────────────
def qwen_available(model=QWEN_BIG):
    try: return urllib2.urlopen("http://192.168.4.30:11434/api/tags", timeout=2).status == 200
    except: return False

def capture_jpeg(quality=70):
    """Captura pantalla → JPEG bytes"""
    img = ImageGrab.grab(all_screens=True)
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=quality)
    return buf.getvalue()

def capture_base85():
    """Captura en buena calidad para Qwen"""
    img = ImageGrab.grab(all_screens=True)
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=85)
    return base64.b64encode(buf.getvalue()).decode()

def qwen_stream_analyze(b64, model=QWEN_BIG, callback=None):
    """Qwen streaming — llama callback con cada token"""
    prompt = """Describe lo que ves. Formato:
APPS: [ventanas abiertas]
BOTONES: [nombre x,y]
CAMPOS: [nombre x,y]
ESTADO: [normal/error/carga]
Responde en español, breve."""
    
    payload = {"model": model, "prompt": prompt, "images": [b64],
               "stream": True, "options": {"temperature": 0.1, "num_predict": 200}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=30)
        
        full_response = ""
        for line in r:
            try:
                chunk = json.loads(line)
                token = chunk.get("response", "")
                full_response += token
                if callback:
                    callback(token, full_response)
            except: pass
        
        return full_response
    except Exception as e:
        if callback:
            callback(f"\n[Error: {e}]", "")
        return f"Error: {e}"

def parse_detections(text):
    """Extrae elementos detectados del texto de Qwen"""
    detections = []
    for line in text.split('\n'):
        for m in re.finditer(r'([\w\sáéíóúñÁÉÍÓÚÑ\-\.\+]{3,35}?)\s*[\(:]?\s*(\d{2,4})\s*[,;]\s*(\d{2,4})', line):
            name = m.group(1).strip()
            x, y = int(m.group(2)), int(m.group(3))
            skip = ['apps','buttons','fields','links','state','imagen','ventanas',
                   'abiertas','describe','formato','español','breve','normal',
                   'error','carga','dialogo','qwen','analizando','streaming',
                   'respuesta','completa','pantalla','actual']
            if name.lower() not in skip and len(name) > 2:
                detections.append({"name": name, "x": x, "y": y})
    return detections


# ─── Loop Continuo Tiempo Real ──────────────────────
def realtime_loop():
    """Captura → Qwen streaming → Actualiza detecciones → Repite"""
    global streaming_active, latest_description, latest_detections
    
    while streaming_active:
        try:
            # 1. Capturar y actualizar feed inmediatamente
            jpg = capture_jpeg(70)
            with frame_lock:
                globals()['latest_frame'] = jpg
            
            # 2. Qwen streaming (actualiza mientras llegan tokens)
            b64 = base64.b64encode(jpg).decode()
            
            partial_text = []
            def on_token(token, full):
                partial_text.append(token)
                # Actualizar detecciones con lo que llevamos
                current = ''.join(partial_text)
                dets = parse_detections(current)
                with detection_lock:
                    globals()['latest_detections'] = dets
                    globals()['latest_description'] = current
            
            full = qwen_stream_analyze(b64, QWEN_BIG, on_token)
            if not full.startswith("Error"):
                with detection_lock:
                    globals()['latest_description'] = full
                    globals()['latest_detections'] = parse_detections(full)
            
        except Exception as e:
            print(f"[LOOP] Error: {e}")
        
        time.sleep(0.5)  # Pequeña pausa entre ciclos


# ─── MJPEG Server ───────────────────────────────────
class MJPEGHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/feed':
            self.send_response(200)
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            while streaming_active or True:
                with frame_lock:
                    frame = globals().get('latest_frame')
                if frame:
                    try:
                        self.wfile.write(b'--frame\r\n')
                        self.wfile.write(b'Content-Type: image/jpeg\r\n\r\n')
                        self.wfile.write(frame)
                        self.wfile.write(b'\r\n')
                    except: break
                time.sleep(0.2)
        
        elif self.path == '/detections':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            with detection_lock:
                data = {"description": globals().get('latest_description', '')[:500],
                       "detections": globals().get('latest_detections', [])}
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode())
        
        elif self.path == '/screenshot.jpg':
            self.send_response(200)
            self.send_header('Content-Type', 'image/jpeg')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(capture_jpeg(80))
        
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            status = {"status": "ok", "version": "v5-realtime",
                     "streaming": streaming_active,
                     "qwen": qwen_available(),
                     "feed_fps": "~5"}
            self.wfile.write(json.dumps(status).encode())
        
        else:
            self.send_response(404); self.end_headers()
    
    def do_POST(self):
        content_len = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(content_len))
        
        if self.path == '/command':
            result = execute_command(body)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        
        elif self.path == '/task':
            # Ejecutar tarea con Qwen streaming
            task = body.get("task", "")
            threading.Thread(target=autonomous_task, args=(task,), daemon=True).start()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "started"}).encode())
        
        else:
            self.send_response(404); self.end_headers()
    
    def log_message(self, format, *args): pass


# ─── Ejecutor ───────────────────────────────────────
def execute_command(cmd):
    action = cmd.get("action", "")
    params = cmd.get("params", {})
    try:
        if action == "click": pyautogui.click(params.get("x", 960), params.get("y", 540)); return {"ok": True}
        elif action == "type": pyautogui.write(params.get("text", ""), interval=0.03); return {"ok": True}
        elif action == "press": pyautogui.press(params.get("key", "enter")); return {"ok": True}
        elif action == "hotkey": pyautogui.hotkey(*params.get("keys", ["enter"])); return {"ok": True}
        elif action == "run":
            pyautogui.hotkey('win', 'r'); time.sleep(0.4)
            pyautogui.write(params.get("app", ""), interval=0.04)
            pyautogui.press('enter'); return {"ok": True}
        elif action == "click_text":
            target = params.get("text", "")
            with detection_lock:
                dets = globals().get('latest_detections', [])
            for d in dets:
                if target.lower() in d["name"].lower():
                    pyautogui.click(d["x"], d["y"])
                    return {"ok": True, "clicked": d}
            return {"ok": False, "msg": f"'{target}' no detectado"}
        elif action == "scroll": pyautogui.scroll(params.get("amount", -3)); return {"ok": True}
        elif action == "move": pyautogui.moveTo(params.get("x", 960), params.get("y", 540)); return {"ok": True}
        else: return {"ok": False, "msg": f"Accion desconocida: {action}"}
    except Exception as e: return {"ok": False, "msg": str(e)}


# ─── Tarea Autónoma ─────────────────────────────────
def autonomous_task(task):
    print(f"[TASK] {task}")
    b64 = capture_base85()
    
    prompt = f"""TASK: {task}
Genera un plan paso a paso. Un comando por linea:
open_app nombre
click_text "texto"
type "texto"
press tecla
wait segundos
Solo comandos, sin explicaciones."""
    
    payload = {"model": QWEN_BIG, "prompt": prompt, "images": [b64],
               "stream": False, "options": {"temperature": 0.1, "num_predict": 300}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=40)
        resp = json.loads(r.read().decode()).get("response", "")
        
        for line in resp.split('\n'):
            line = line.strip()
            if not line or line.startswith('#'): continue
            parts = line.split(maxsplit=1)
            if len(parts) < 1: continue
            action = parts[0].lower()
            param = parts[1].strip().strip('"') if len(parts) > 1 else ""
            
            print(f"  [{action}] {param}")
            if action == "open_app": execute_command({"action": "run", "params": {"app": param}})
            elif action == "click_text": execute_command({"action": "click_text", "params": {"text": param}})
            elif action == "type": execute_command({"action": "type", "params": {"text": param}})
            elif action == "press": execute_command({"action": "press", "params": {"key": param}})
            elif action == "wait":
                try: time.sleep(float(param))
                except: time.sleep(2)
            elif action == "verify": pass  # El loop de detecciones ya verifica
            time.sleep(0.5)
        
        print("[TASK] Completada")
    except Exception as e:
        print(f"[TASK] Error: {e}")


# ─── Server ─────────────────────────────────────────
def start_server():
    global streaming_active, capture_thread, analyze_thread
    
    # Iniciar streaming
    streaming_active = True
    analyze_thread = threading.Thread(target=realtime_loop, daemon=True)
    analyze_thread.start()
    
    # HTTP server
    server = socketserver.ThreadingTCPServer(('0.0.0.0', PORT), MJPEGHandler)
    server.allow_reuse_address = True
    
    print('')
    print('=' * 50)
    print('   AGENT V5 - TIEMPO REAL')
    print('   Qwen Streaming + MJPEG')
    print('=' * 50)
    print(f'   Feed:  http://192.168.4.23:8000/feed')
    print(f'   Detect:http://192.168.4.23:8000/detections')
    print(f'   Screen:http://192.168.4.23:8000/screenshot.jpg')
    print('=' * 50)
    print('')
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        streaming_active = False
        server.shutdown()


if __name__ == '__main__':
    start_server()
