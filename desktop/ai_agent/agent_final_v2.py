"""Vision RPA Final — GUI Tiempo Real + Agente Autonomo Rapido
Arquitectura de 3 capas para latencia minima:
  CAPA 0 (200ms):   MJPEG feed en vivo en la GUI
  CAPA 1 (1-3s):    Qwen2-VL-2B deteccion rapida + OCR
  CAPA 2 (10-15s):  Qwen2.5-VL-7B planificacion profunda

GUI: Siempre visible, feed en vivo, detecciones actualizadas.
Agente: Recibe tarea, planea con 7B, ejecuta con 2B+OCR rapido.
"""

import os, sys, time, json, threading, io, base64, re, random
import http.server, socketserver, queue
from PIL import Image, ImageGrab
import pyautogui

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.02

# ═══════════════════════════════════════════════════════
# CONFIG
# ═══════════════════════════════════════════════════════
PORT = 8000
QWEN_URL = "http://192.168.4.30:11434/api/generate"
MODEL_FAST = "qwen2vl:2b"    # Rapido, 1-3s
MODEL_BIG = "qwen2.5vl:7b"   # Preciso, 10-15s
USE_FAST_MODEL = True         # Intentar 2B primero

import urllib.request as urllib2

# OCR
try:
    import pytesseract, cv2, numpy as np
    for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
              r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
        if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break
    HAS_OCR = True
except: HAS_OCR = False

# Estado global
latest_jpg = None
detections_queue = queue.Queue()
task_queue = queue.Queue()
lock = threading.Lock()
running = True

# ═══════════════════════════════════════════════════════
# CAPA 1: Deteccion Rapida (2B + OCR, 1-3s)
# ═══════════════════════════════════════════════════════
def capture_jpg(q=60):
    img = ImageGrab.grab(all_screens=True)
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=q)
    return buf.getvalue()

def capture_b64():
    jpg = capture_jpg(85)
    return base64.b64encode(jpg).decode()

def ocr_fast():
    """OCR rapido: texto + posiciones"""
    if not HAS_OCR: return []
    img = ImageGrab.grab(all_screens=True)
    img = img.resize((img.size[0]//3, img.size[1]//3))
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
    results = []
    for i in range(len(data['text'])):
        if int(data['conf'][i]) > 50 and data['text'][i].strip():
            results.append({
                "name": data['text'][i].strip(),
                "x": (data['left'][i] + data['width'][i]//2) * 3,
                "y": (data['top'][i] + data['height'][i]//2) * 3,
                "conf": int(data['conf'][i])
            })
    return results

def qwen_detect(b64, model=MODEL_FAST):
    """Deteccion rapida con Qwen (1-3s con 2B)"""
    prompt = """List ONLY clickable elements with x,y:
[element name] x,y
No explanations."""
    payload = {"model": model, "prompt": prompt, "images": [b64],
               "stream": False, "options": {"temperature": 0, "num_predict": 150}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=15)
        resp = json.loads(r.read().decode()).get("response", "")
        dets = []
        for line in resp.split('\n'):
            m = re.search(r'(.+?)\s+(\d{2,4})\s*[,;]\s*(\d{2,4})', line)
            if m:
                dets.append({"name": m.group(1).strip(), "x": int(m.group(2)), "y": int(m.group(3))})
        return dets
    except: return []

def qwen_plan(task, b64, model=MODEL_BIG):
    """Planificacion profunda con 7B"""
    prompt = f"""TASK: {task}
Look at this screenshot. Create step-by-step plan.
Each step: ACTION value
ACTIONS: open_app name | click_text "text" | type "text" | press key | wait seconds
Reply ONLY commands, one per line."""
    payload = {"model": model, "prompt": prompt, "images": [b64],
               "stream": False, "options": {"temperature": 0.1, "num_predict": 300}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=40)
        resp = json.loads(r.read().decode()).get("response", "")
        plan = []
        for line in resp.split('\n'):
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('```'): continue
            parts = line.split(maxsplit=1)
            if len(parts) >= 1:
                action = parts[0].lower().strip()
                param = parts[1].strip().strip('"').strip("'") if len(parts) > 1 else ""
                if action in ('open_app','click_text','type','press','wait','verify'):
                    plan.append({"action": action, "param": param})
        return plan
    except Exception as e:
        print(f"Plan error: {e}")
        return []

# ═══════════════════════════════════════════════════════
# CAPA 2: Ejecutor Rapido (usa OCR para click_text)
# ═══════════════════════════════════════════════════════
def execute_action(action, param):
    """Ejecuta accion con OCR/Qwen rapido para encontrar elementos"""
    try:
        if action == "open_app":
            pyautogui.hotkey('win', 'r')
            time.sleep(0.3)
            pyautogui.write(param, interval=0.03)
            pyautogui.press('enter')
            time.sleep(2)
            return True
            
        elif action == "click_text":
            # Buscar con OCR primero (instantaneo)
            ocr_results = ocr_fast()
            for d in ocr_results:
                if param.lower() in d["name"].lower():
                    human_click(d["x"], d["y"])
                    return True
            # Si no, Qwen rapido (2B)
            b64 = capture_b64()
            dets = qwen_detect(b64, MODEL_FAST)
            for d in dets:
                if param.lower() in d["name"].lower():
                    human_click(d["x"], d["y"])
                    return True
            # Si no, Qwen lento (7B)
            dets = qwen_detect(b64, MODEL_BIG)
            for d in dets:
                if param.lower() in d["name"].lower():
                    human_click(d["x"], d["y"])
                    return True
            print(f"  No encontrado: {param}")
            return False
            
        elif action == "type":
            pyautogui.write(param, interval=0.03)
            return True
            
        elif action == "press":
            pyautogui.press(param)
            time.sleep(0.3)
            return True
            
        elif action == "wait":
            try: time.sleep(float(param))
            except: time.sleep(2)
            return True
            
        elif action == "verify":
            time.sleep(1)
            return True
            
    except Exception as e:
        print(f"  Error: {e}")
        return False

def human_click(x, y):
    """Click con movimiento visible"""
    mx, my = pyautogui.position()
    dist = ((x-mx)**2 + (y-my)**2)**0.5
    steps = max(8, int(dist/30))
    for i in range(1, steps+1):
        t = i/steps
        cx = mx + (x-mx)*t + random.uniform(-4,4)*(1-abs(2*t-1))
        cy = my + (y-my)*t + random.uniform(-3,3)*(1-abs(2*t-1))
        pyautogui.moveTo(int(cx), int(cy))
        time.sleep(0.006)
    time.sleep(0.08)
    pyautogui.click()

# ═══════════════════════════════════════════════════════
# AGENTE AUTONOMO (corre en background)
# ═══════════════════════════════════════════════════════
def run_autonomous_task(task):
    print(f"\n{'='*50}")
    print(f"AGENTE: {task}")
    
    # 1. Planificar con 7B (unica llamada lenta)
    print("[1/3] Planeando con Qwen 7B...")
    b64 = capture_b64()
    plan = qwen_plan(task, b64, MODEL_BIG)
    
    if not plan:
        print("  No se pudo generar plan")
        return
    
    print(f"  Plan: {len(plan)} pasos")
    for i, s in enumerate(plan):
        print(f"  {i+1}. {s['action']} {s['param']}")
    
    # 2. Ejecutar con OCR+2B (rapido)
    print(f"\n[2/3] Ejecutando...")
    for i, step in enumerate(plan):
        action = step['action']
        param = step['param']
        t0 = time.time()
        ok = execute_action(action, param)
        t1 = time.time()
        status = "OK" if ok else "FAIL"
        print(f"  [{i+1}/{len(plan)}] {action} {param[:40]} ({t1-t0:.1f}s) {status}")
    
    # 3. Verificar final
    print(f"\n[3/3] Verificando...")
    time.sleep(1)
    b64 = capture_b64()
    prompt = "Breve descripcion de la pantalla y si la tarea se completo. 2 frases en español."
    payload = {"model": MODEL_FAST, "prompt": prompt, "images": [b64],
               "stream": False, "options": {"temperature": 0, "num_predict": 80}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=15)
        result = json.loads(r.read().decode()).get("response", "")
        print(f"  Qwen: {result[:250]}")
    except: pass
    
    print("AGENTE COMPLETADO")

# ═══════════════════════════════════════════════════════
# SERVIDOR HTTP + MJPEG
# ═══════════════════════════════════════════════════════
class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/feed':
            self.send_response(200)
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            while running:
                with lock:
                    jpg = latest_jpg
                if jpg:
                    try:
                        self.wfile.write(b'--frame\r\nContent-Type: image/jpeg\r\n\r\n')
                        self.wfile.write(jpg)
                        self.wfile.write(b'\r\n')
                    except: break
                time.sleep(0.15)
        
        elif self.path == '/screenshot.jpg':
            self.send_response(200)
            self.send_header('Content-Type', 'image/jpeg')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(capture_jpg(75))
        
        elif self.path == '/detect':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            b64 = capture_b64()
            dets = qwen_detect(b64, MODEL_FAST) or ocr_fast()
            self.wfile.write(json.dumps({"detections": dets}).encode())
        
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status":"ok","model_fast":MODEL_FAST,"model_big":MODEL_BIG}).encode())
        
        else:
            self.send_response(404); self.end_headers()
    
    def do_POST(self):
        cl = int(self.headers.get('Content-Length', 0))
        body = json.loads(self.rfile.read(cl))
        
        if self.path == '/task':
            task = body.get("task", "")
            threading.Thread(target=run_autonomous_task, args=(task,), daemon=True).start()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status":"started","task":task}).encode())
        
        elif self.path == '/command':
            result = execute_action(body.get("action",""), body.get("param",""))
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"ok": result}).encode())
        
        else:
            self.send_response(404); self.end_headers()
    
    def log_message(self, format, *args): pass

# ═══════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════
def feed_loop():
    """Actualiza el frame cada 200ms"""
    global latest_jpg
    while running:
        try:
            jpg = capture_jpg(60)
            with lock:
                latest_jpg = jpg
        except: pass
        time.sleep(0.2)

if __name__ == '__main__':
    print("=" * 50)
    print("  VISION RPA FINAL - Tiempo Real")
    print(f"  Modelo rapido:  {MODEL_FAST}")
    print(f"  Modelo grande:  {MODEL_BIG}")
    print(f"  OCR:            {'Si' if HAS_OCR else 'No'}")
    print("=" * 50)
    print(f"  Feed:     http://192.168.4.23:{PORT}/feed")
    print(f"  Detectar: http://192.168.4.23:{PORT}/detect")
    print(f"  Tarea:    POST http://192.168.4.23:{PORT}/task")
    print("=" * 50)
    
    # Iniciar feed loop
    threading.Thread(target=feed_loop, daemon=True).start()
    
    # Servidor
    server = socketserver.ThreadingTCPServer(('0.0.0.0', PORT), Handler)
    server.allow_reuse_address = True
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        running = False
        server.shutdown()
