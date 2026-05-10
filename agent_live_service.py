"""Agente de Vision - Servicio en Segundo Plano
Socket TCP en localhost:9999.
Recibe comandos y responde en vivo.
OpenCV window opcional."""

import os, sys, time, threading, socket, json, cv2, numpy as np
import pyautogui, pytesseract
from PIL import Image

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

class VisionService:
    def __init__(self, port=9999, show_window=True):
        self.port = port
        self.show_window = show_window
        self.mode = "OBSERVADOR"
        self.running = True
        self.last_screen = None
        self.last_text = ""
        self.detections = []
        self.fps = 15
        self.frame_count = 0

    def capture(self):
        try:
            img = pyautogui.screenshot()
            self.last_screen = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
            return self.last_screen
        except:
            return None

    def ocr_scan(self):
        """Escanea full screen y actualiza texto + detecciones"""
        try:
            img = pyautogui.screenshot()
            gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
            gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
            self.last_text = pytesseract.image_to_string(gray)
            data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
            self.detections = []
            for i in range(len(data['text'])):
                try:
                    conf = int(data['conf'][i])
                    word = data['text'][i].strip()
                    if conf > 40 and len(word) > 2:
                        self.detections.append({
                            'word': word,
                            'x': (data['left'][i] + data['width'][i]//2) * 2,
                            'y': (data['top'][i] + data['height'][i]//2) * 2,
                            'conf': conf
                        })
                except: pass
        except:
            pass

    # ─── ACCIONES ────────────────────────────────

    def find_and_click(self, text):
        """Busca texto en pantalla y clickea"""
        self.ocr_scan()
        matches = [d for d in self.detections if text.lower() in d['word'].lower()]
        if matches:
            d = matches[0]
            pyautogui.click(d['x'], d['y'])
            return f"CLICK en '{d['word']}' ({d['x']},{d['y']})"
        return f"NO ENCONTRADO: '{text}'"

    def type_text(self, text):
        pyautogui.write(text, interval=0.04)
        return f"ESCRITO: '{text}'"

    def press_key(self, key):
        pyautogui.press(key)
        return f"TECLA: '{key}'"

    def hotkey(self, *keys):
        pyautogui.hotkey(*keys)
        return f"HOTKEY: {'+'.join(keys)}"

    def move_to(self, x, y):
        pyautogui.moveTo(x, y, duration=0.2)
        return f"MOUSE: ({x},{y})"

    def double_click(self, x, y):
        pyautogui.doubleClick(x, y)
        return f"DOUBLE CLICK: ({x},{y})"

    def scroll(self, amount):
        pyautogui.scroll(amount)
        return f"SCROLL: {amount}"

    def get_status(self):
        mx, my = pyautogui.position()
        return {
            'mode': self.mode,
            'cursor': (mx, my),
            'screen': pyautogui.size(),
            'text_lines': len(self.last_text.split('\n')) if self.last_text else 0,
            'detections': len(self.detections),
            'fps': self.fps,
            'frame': self.frame_count
        }

    # ─── SOCKET SERVER ────────────────────────────

    def handle_client(self, conn):
        """Maneja un comando recibido via socket"""
        try:
            data = conn.recv(4096).decode('utf-8', 'ignore').strip()
            if not data:
                return

            print(f"[COMANDO] {data[:100]}")
            parts = data.split(' ', 1)
            cmd = parts[0].lower()
            arg = parts[1] if len(parts) > 1 else None

            response = None

            if cmd == 'mode':
                if arg in ('control', 'observador'):
                    self.mode = 'CONTROL' if arg == 'control' else 'OBSERVADOR'
                    response = f"MODO: {self.mode}"
                else:
                    response = f"MODO ACTUAL: {self.mode}"

            elif cmd == 'ver':
                self.ocr_scan()
                text = self.last_text or '(OCR no disponible)'
                response = text[:2000]

            elif cmd == 'status':
                response = json.dumps(self.get_status(), indent=2)

            elif cmd == 'click':
                if self.mode != 'CONTROL':
                    response = "ERROR: Activa modo CONTROL primero. Envia: mode control"
                elif arg:
                    response = self.find_and_click(arg)

            elif cmd == 'escribir':
                if self.mode != 'CONTROL':
                    response = "ERROR: Modo CONTROL requerido"
                elif arg:
                    response = self.type_text(arg)

            elif cmd == 'presionar':
                if self.mode != 'CONTROL':
                    response = "ERROR: Modo CONTROL requerido"  
                elif arg:
                    response = self.press_key(arg)

            elif cmd == 'hotkey':
                if self.mode != 'CONTROL':
                    response = "ERROR: Modo CONTROL requerido"
                elif arg:
                    keys = arg.split('+')
                    self.hotkey(*keys)
                    response = f"HOTKEY: {'+'.join(keys)}"

            elif cmd == 'mover':
                if self.mode != 'CONTROL':
                    response = "ERROR: Modo CONTROL requerido"
                elif arg:
                    try:
                        x, y = map(int, arg.split(','))
                        response = self.move_to(x, y)
                    except:
                        response = "ERROR: Formato x,y"

            elif cmd == 'scroll':
                if self.mode != 'CONTROL':
                    response = "ERROR: Modo CONTROL requerido"  
                elif arg:
                    try:
                        response = self.scroll(int(arg))
                    except:
                        response = "ERROR: Numero invalido"

            elif cmd == 'dc':
                if self.mode != 'CONTROL':
                    response = "ERROR: Modo CONTROL requerido"
                elif arg:
                    try:
                        x, y = map(int, arg.split(','))
                        response = self.double_click(x, y)
                    except:
                        response = "ERROR: Formato x,y"

            elif cmd == 'screen':
                w, h = pyautogui.size()
                response = json.dumps({'width': w, 'height': h})

            elif cmd == 'cursor':
                x, y = pyautogui.position()
                response = json.dumps({'x': x, 'y': y})

            elif cmd == 'help':
                response = """COMANDOS:
  mode control       Activar modo CONTROL
  mode observador    Activar modo OBSERVADOR
  status             Ver estado actual
  ver                Ver texto OCR de la pantalla
  screen             Resolucion de pantalla
  cursor             Posicion del cursor
  click <texto>      Clickear en texto detectado
  escribir <texto>   Escribir texto
  presionar <tecla>  Presionar tecla (enter, tab, esc, f5)
  hotkey <t1+t2>     Combinacion (ctrl+c, alt+tab)
  mover <x,y>        Mover cursor
  dc <x,y>           Doble click
  scroll <n>         Scroll (neg=abajo, pos=arriba)
  help               Esta ayuda, pinche animal de monte"""

            else:
                response = f"COMANDO DESCONOCIDO: {cmd}. Envia 'help'"

            if response:
                conn.send(response.encode('utf-8'))
        except Exception as e:
            try: conn.send(f"ERROR: {e}".encode('utf-8'))
            except: pass
        finally:
            try: conn.close()
            except: pass

    def socket_server(self):
        """Thread del servidor socket"""
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(('127.0.0.1', self.port))
        server.listen(5)
        server.settimeout(0.5)
        print(f"[SOCKET] Servidor en 127.0.0.1:{self.port}")

        while self.running:
            try:
                conn, addr = server.accept()
                threading.Thread(target=self.handle_client, args=(conn,), daemon=True).start()
            except socket.timeout:
                continue
            except:
                break
        server.close()

    def vision_window(self):
        """Thread de la ventana OpenCV (opcional)"""
        if not self.show_window:
            return
        w, h = 960, 540
        cv2.namedWindow("AGENTE VISION", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("AGENTE VISION", w, h)

        while self.running:
            frame = self.capture()
            if frame is None:
                time.sleep(0.05)
                continue

            display = cv2.resize(frame, (w, h))
            cv2.putText(display, f"MODO: {self.mode} | FPS:{self.fps}",
                       (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5,
                       (0, 255, 0) if self.mode == "OBSERVADOR" else (0, 100, 255), 1)
            cv2.putText(display, "C:Control O:OCR Q:Salir", (10, h-10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.4, (150,150,150), 1)

            cv2.imshow("AGENTE VISION", display)

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                self.running = False
            elif key == ord('c'):
                self.mode = "CONTROL" if self.mode == "OBSERVADOR" else "OBSERVADOR"
                print(f"[MODO] {self.mode}")
            elif key == ord('o'):
                pass  # OCR siempre activo

            self.frame_count += 1
            time.sleep(1.0 / self.fps)

        cv2.destroyAllWindows()

    def ocr_loop(self):
        """OGCR continuo en background"""
        while self.running:
            self.ocr_scan()
            time.sleep(0.8)

    def run(self):
        print("=" * 60)
        print("  AGENTE DE VISION - SERVICIO EN SEGUNDO PLANO")
        print(f"  Puerto: {self.port}")
        print(f"  Ventana: {'SI' if self.show_window else 'NO'}")
        print("=" * 60)
        print()
        print("  Envia comandos con: python agent_client.py <comando>")
        print("  Ejemplo: python agent_client.py \"mode control\"")
        print("  Ejemplo: python agent_client.py \"click Chrome\"")
        print("  Ejemplo: python agent_client.py \"ver\"")
        print()

        # Iniciar threads
        threading.Thread(target=self.socket_server, daemon=True).start()
        threading.Thread(target=self.ocr_loop, daemon=True).start()

        # Thread principal = ventana OpenCV
        self.vision_window()

        print("\n[OK] Agente cerrado.")

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, default=9999)
    p.add_argument("--no-window", action="store_true")
    args = p.parse_args()

    service = VisionService(port=args.port, show_window=not args.no_window)
    service.run()
