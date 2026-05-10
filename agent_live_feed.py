"""Agente de Vision - LIVE FEED 10-60 FPS
Muestra la pantalla en vivo con OCR overlay.
Acepta comandos mientras transmite."""

import os, sys, time, threading, queue, cv2, numpy as np
import pyautogui, pytesseract
from PIL import Image

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

class LiveFeedAgent:
    def __init__(self, fps=15):
        self.mode = "OBSERVADOR"
        self.running = True
        self.fps = fps
        self.frame_delay = 1.0 / fps
        self.screen_w, self.screen_h = pyautogui.size()
        self.display_w = 1280
        self.display_h = 720
        self.frame_count = 0
        self.ocr_text = "Iniciando OCR..."
        self.detections = []
        self.ocr_enabled = True
        self.last_ocr_time = 0
        self.ocr_interval = 0.5  # OCR cada 500ms para no saturar

    def capture_frame(self):
        img = pyautogui.screenshot()
        frame = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        return frame

    def ocr_thread_func(self):
        """Thread que corre OCR periodicamente"""
        while self.running:
            time.sleep(0.1)
            if not self.ocr_enabled:
                continue
            now = time.time()
            if now - self.last_ocr_time < self.ocr_interval:
                continue
            try:
                img = pyautogui.screenshot()
                gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
                gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
                _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
                self.ocr_text = pytesseract.image_to_string(binary)[:2000]
                data = pytesseract.image_to_data(binary, output_type=pytesseract.Output.DICT)
                self.detections = []
                for i in range(len(data['text'])):
                    try:
                        conf = int(data['conf'][i])
                        word = data['text'][i].strip()
                        if conf > 40 and len(word) > 2:
                            x = (data['left'][i] + data['width'][i]//2) * 2
                            y = (data['top'][i] + data['height'][i]//2) * 2
                            w = data['width'][i] * 2
                            h = data['height'][i] * 2
                            self.detections.append((word, x, y, w, h, conf))
                    except: pass
                self.last_ocr_time = now
            except: pass

    def draw_hud(self, frame):
        """Dibuja HUD con modo, FPS, y detecciones"""
        h, w = frame.shape[:2]
        scale_x = self.display_w / w
        scale_y = self.display_h / h
        scale = min(scale_x, scale_y)

        new_w, new_h = int(w * scale), int(h * scale)
        display = cv2.resize(frame, (new_w, new_h))

        # Fondo negro si no llena
        canvas = np.zeros((self.display_h, self.display_w, 3), dtype=np.uint8)
        y_off = (self.display_h - new_h) // 2
        x_off = (self.display_w - new_w) // 2
        canvas[y_off:y_off+new_h, x_off:x_off+new_w] = display

        h, w = canvas.shape[:2]

        # Barra superior
        cv2.rectangle(canvas, (0, 0), (w, 30), (0, 0, 0), -1)
        color = (0, 255, 0) if self.mode == "OBSERVADOR" else (0, 100, 255)
        cv2.putText(canvas, f"MODO: {self.mode}  |  FPS: {self.fps}  |  /controlar /detener /click /help",
                    (10, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.45, color, 1)

        # Dibujar detecciones OCR
        for word, dx, dy, dw, dh, conf in self.detections[:30]:
            rx = int(dx * scale_x) + x_off
            ry = int(dy * scale_y) + y_off
            rw = int(dw * scale_x)
            rh = int(dh * scale_y)
            if 0 <= rx < w and 0 <= ry < h and rw > 0 and rh > 0:
                alpha = 0.3 + 0.7 * (conf / 100)
                box_color = (0, int(255 * alpha), 255 - int(100 * alpha))
                cv2.rectangle(canvas, (rx - rw//2 - 2, ry - rh//2 - 2),
                             (rx + rw//2 + 2, ry + rh//2 + 2), box_color, 1)
                cv2.putText(canvas, word, (rx - rw//2, ry - rh//2 - 4),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.3, box_color, 1)

        # Cursor
        mx, my = pyautogui.position()
        mx = int(mx * scale_x) + x_off
        my = int(my * scale_y) + y_off
        cv2.drawMarker(canvas, (mx, my), (0, 255, 255), cv2.MARKER_CROSS, 10, 1)

        return canvas

    def draw_help_bar(self, canvas):
        """Barra inferior con atajos de teclado"""
        h, w = canvas.shape[:2]
        cv2.rectangle(canvas, (0, h-30), (w, h), (0, 0, 0), -1)
        cmds = [
            "C:Control/Observador", "O:OCR ON/OFF", "Q:Salir",
            "CLICK:Click izquierdo", "T:Toggle texto"
        ]
        x = 10
        for cmd in cmds:
            cv2.putText(canvas, cmd, (x, h-10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.35, (200, 200, 200), 1)
            x += len(cmd) * 7 + 20
        return canvas

    def run(self):
        print("\n" + "=" * 60)
        print("  AGENTE VISION - LIVE FEED")
        print(f"  {self.fps} FPS | OCR cada {self.ocr_interval}s")
        print("  /ver /controlar /detener /click /escribir /help /salir")
        print("=" * 60)
        print("  Abriendo ventana de vision...\n")

        # Thread de OCR
        ocr_thread = threading.Thread(target=self.ocr_thread_func, daemon=True)
        ocr_thread.start()

        # Thread de comandos
        def cmd_thread():
            print(">> ", end="", flush=True)
            while self.running:
                try:
                    cmd = input().strip()
                    self._process_command(cmd)
                    print(">> ", end="", flush=True)
                except: pass

        cmt = threading.Thread(target=cmd_thread, daemon=True)
        cmt.start()

        cv2.namedWindow("AGENTE VISION - LIVE FEED", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("AGENTE VISION - LIVE FEED", self.display_w, self.display_h)

        last_frame_time = time.time()
        fps_counter = 0
        fps_timer = time.time()
        current_fps = 0

        while self.running:
            frame_start = time.time()

            frame = self.capture_frame()
            hud = self.draw_hud(frame)

            fps_counter += 1
            if time.time() - fps_timer > 1.0:
                current_fps = fps_counter
                fps_counter = 0
                fps_timer = time.time()

            self.frame_count += 1
            # Actualizar FPS en HUD
            cv2.putText(hud, f"MODO: {self.mode}  |  FPS: {current_fps}  |  (vision en vivo)",
                        (10, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.45,
                        (0, 255, 0) if self.mode == "OBSERVADOR" else (0, 100, 255), 1)

            cv2.imshow("AGENTE VISION - LIVE FEED", hud)

            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                self.running = False
                break
            if key == ord('c'):
                self.mode = "CONTROL" if self.mode == "OBSERVADOR" else "OBSERVADOR"
                print(f"\n*** MODO: {self.mode} ***\n>> ", end="", flush=True)
            if key == ord('o'):
                self.ocr_enabled = not self.ocr_enabled
                print(f"\n*** OCR: {'ON' if self.ocr_enabled else 'OFF'} ***\n>> ", end="", flush=True)

            elapsed = time.time() - frame_start
            if elapsed < self.frame_delay:
                time.sleep(self.frame_delay - elapsed)

        cv2.destroyAllWindows()
        print("\nAgente cerrado.")

    def _process_command(self, cmd):
        cmd = cmd.strip()
        lower = cmd.lower()

        if lower == "/controlar":
            self.mode = "CONTROL"
            print("*** MODO CONTROL ACTIVADO ***")

        elif lower == "/detener":
            self.mode = "OBSERVADOR"
            print("*** MODO OBSERVADOR ***")

        elif lower == "/ver":
            print(f"\n--- OCR ({len(self.detections)} detecciones) ---")
            print(self.ocr_text[:600])
            print("---")

        elif lower.startswith("/click "):
            text = cmd[7:].strip()
            if self.mode != "CONTROL":
                print("[BLOQUEADO] Activa /controlar primero")
                return
            found = [d for d in self.detections if text.lower() in d[0].lower()]
            if found:
                word, x, y, _, _, _ = found[0]
                print(f"[CLICK] '{word}' ({x},{y})")
                pyautogui.click(x, y)
            else:
                print(f"[NO ENCONTRADO] '{text}'")

        elif lower.startswith("/escribir "):
            text = cmd[10:].strip()
            if self.mode != "CONTROL":
                print("[BLOQUEADO] Activa /controlar primero")
                return
            pyautogui.write(text, interval=0.04)
            print(f"[ESCRIBIENDO] '{text}'")

        elif lower.startswith("/presionar "):
            key = cmd[12:].strip()
            if self.mode != "CONTROL":
                print("[BLOQUEADO] Activa /controlar primero")
                return
            pyautogui.press(key)
            print(f"[PRESIONADO] '{key}'")

        elif lower == "/screen":
            w, h = pyautogui.size()
            print(f"Resolucion: {w}x{h}")

        elif lower == "/donde":
            x, y = pyautogui.position()
            print(f"Cursor: ({x}, {y})")

        elif lower == "/help":
            print("""
/controlar      Activar modo CONTROL
/detener        Volver a OBSERVADOR
/ver            Mostrar texto OCR detectado
/click <texto>  Click en texto detectado
/escribir <t>   Escribir texto
/presionar <k>  Presionar tecla (enter, tab, esc)
/screen         Resolucion
/donde          Posicion cursor
/salir          Cerrar agente

TECLAS RAPIDAS en ventana de vision:
  C = toggle CONTROL/OBSERVADOR
  O = toggle OCR
  Q = salir
""")

        elif lower in ("/salir", "/quit", "/exit"):
            self.running = False

        else:
            print(f"Comando: '{cmd}' (usa /help)")

if __name__ == "__main__":
    agent = LiveFeedAgent(fps=30)
    agent.run()
