"""Agente de Vision en Tiempo Real - Windows
Modo OBSERVADOR: mira y reporta
Modo CONTROL: actua sobre mouse/teclado"""

import os, sys, time, threading, json
import pyautogui
import pytesseract
import cv2
import numpy as np
from PIL import Image

# Configurar Tesseract
for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p):
        pytesseract.pytesseract.tesseract_cmd = p
        break

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.1

class LiveAgent:
    def __init__(self):
        self.mode = "OBSERVADOR"  # OBSERVADOR o CONTROL
        self.running = True
        self.last_screen = None
        self.last_text = ""
        self.history = []
        self.screenshot_count = 0

    def capture(self):
        """Captura pantalla completa"""
        img = pyautogui.screenshot()
        self.last_screen = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        self.screenshot_count += 1
        return self.last_screen

    def read_text(self):
        """Lee texto de la pantalla"""
        if self.last_screen is None:
            self.capture()
        gray = cv2.cvtColor(self.last_screen, cv2.COLOR_BGR2GRAY)
        try:
            self.last_text = pytesseract.image_to_string(gray)
        except:
            self.last_text = "(OCR no disponible)"
        return self.last_text

    def find_on_screen(self, text, threshold=40):
        """Busca texto en pantalla"""
        if self.last_screen is None:
            self.capture()
        gray = cv2.cvtColor(self.last_screen, cv2.COLOR_BGR2GRAY)
        try:
            data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
            results = []
            for i in range(len(data['text'])):
                conf = int(data['conf'][i])
                word = data['text'][i].strip()
                if conf > threshold and text.lower() in word.lower():
                    x, y, w, h = data['left'][i], data['top'][i], data['width'][i], data['height'][i]
                    results.append((x + w//2, y + h//2, word))
            return results
        except:
            return []

    # ─── ACCIONES DE CONTROL ──────────────────────────────

    def move_to(self, x, y):
        if self.mode != "CONTROL": return
        pyautogui.moveTo(x, y, duration=0.3)

    def click_at(self, x, y):
        if self.mode != "CONTROL": return
        pyautogui.click(x, y)

    def click_text(self, text):
        """Busca texto en pantalla y hace click"""
        if self.mode != "CONTROL": 
            print(f"[BLOQUEADO] No estoy en modo CONTROL. Usa /controlar")
            return False
        results = self.find_on_screen(text)
        if results:
            x, y, word = results[0]
            print(f"[ACCION] Click en '{word}' ({x},{y})")
            pyautogui.click(x, y)
            return True
        print(f"[NO ENCONTRADO] '{text}'")
        return False

    def type_text(self, text):
        if self.mode != "CONTROL": return
        pyautogui.write(text, interval=0.05)

    def press(self, key):
        if self.mode != "CONTROL": return
        pyautogui.press(key)

    def hotkey(self, *keys):
        if self.mode != "CONTROL": return
        pyautogui.hotkey(*keys)

    def double_click_at(self, x, y):
        if self.mode != "CONTROL": return
        pyautogui.doubleClick(x, y)

    def scroll(self, amount):
        if self.mode != "CONTROL": return
        pyautogui.scroll(amount)

    # ─── COMANDOS ─────────────────────────────────────────

    def process_command(self, cmd):
        cmd = cmd.strip()
        if not cmd:
            return

        lower = cmd.lower()

        if lower == "/controlar":
            self.mode = "CONTROL"
            print("\n*** MODO CONTROL ACTIVADO ***")
            print("   Puedo mover mouse, hacer clicks, escribir.")
            print("   Usa /detener para parar.\n")
            return

        if lower == "/detener":
            self.mode = "OBSERVADOR"
            print("\n*** MODO OBSERVADOR ***")
            print("   Solo observo. No ejecuto acciones.\n")
            return

        if lower == "/ver":
            self.capture()
            text = self.read_text()
            print(f"\n--- PANTALLA [{self.screenshot_count}] ---")
            print(text[:800])
            print("--- FIN PANTALLA ---\n")
            return

        if lower == "/donde cursor":
            x, y = pyautogui.position()
            print(f"Cursor en: ({x}, {y})")
            return

        if lower == "/screen":
            w, h = pyautogui.size()
            print(f"Resolucion: {w}x{h}")
            return

        if lower == "/help" or lower == "/?":
            self._show_help()
            return

        if lower.startswith("/accion "):
            action = cmd[8:].strip()
            self._execute_action(action)
            return

        if lower.startswith("/click "):
            text = cmd[7:].strip()
            self.capture()
            self.click_text(text)
            return

        if lower.startswith("/escribir "):
            text = cmd[10:].strip()
            self.type_text(text)
            return

        if lower == "/salir" or lower == "/quit" or lower == "/exit":
            self.running = False
            print("Cerrando agente...")
            return

        print(f"Comando desconocido: '{cmd}'. Usa /help")

    def _execute_action(self, action):
        """Ejecuta una accion especifica"""
        if self.mode != "CONTROL":
            print("[BLOQUEADO] Activa /controlar primero")
            return

        lower = action.lower()

        if lower.startswith("click en "):
            text = action[9:]
            self.capture()
            self.click_text(text)

        elif lower.startswith("escribir "):
            text = action[8:]
            self.type_text(text)

        elif lower.startswith("presionar "):
            key = action[10:]
            self.press(key)

        elif lower.startswith("abrir "):
            app = action[5:]
            pyautogui.hotkey('win', 'r')
            time.sleep(0.5)
            pyautogui.write(app)
            pyautogui.press('enter')

        elif lower == "cerrar ventana":
            pyautogui.hotkey('alt', 'f4')

        elif lower == "minimizar todo":
            pyautogui.hotkey('win', 'd')

        elif lower.startswith("scroll "):
            try:
                amount = int(action[7:])
                self.scroll(amount)
            except:
                pass

        elif lower.startswith("mover a "):
            try:
                coords = action[7:].replace("(", "").replace(")", "").split(",")
                x, y = int(coords[0]), int(coords[1])
                self.move_to(x, y)
            except:
                pass

        else:
            print(f"Accion no reconocida: '{action}'")

    def _show_help(self):
        print("""
═════════════════════════════════════════════
  AGENTE DE VISION EN TIEMPO REAL
═════════════════════════════════════════════

COMANDOS:

/ver              Muestra lo que veo en pantalla
/screen           Resolucion de pantalla
/donde cursor     Posicion actual del cursor

/controlar        ACTIVA modo CONTROL (puedo actuar)
/detener          VUELVE a modo OBSERVADOR

/click <texto>    Busca y clickea texto en pantalla
/escribir <texto> Escribe texto con el teclado

/accion click en <texto>    Click en texto
/accion escribir <texto>    Escribir texto
/accion presionar <tecla>   Presionar tecla (enter, tab, esc)
/accion abrir <programa>    Abrir programa (chrome, notepad)
/accion cerrar ventana      Cerrar ventana activa
/accion minimizar todo      Minimizar todas las ventanas
/accion mover a x,y         Mover cursor a coordenadas
/accion scroll <n>          Scroll (positivo=arriba, negativo=abajo)

/help             Esta ayuda
/salir            Cerrar el agente
═════════════════════════════════════════════
""")

    def run(self):
        """Loop principal"""
        print("\n" + "=" * 50)
        print("  AGENTE DE VISION EN TIEMPO REAL")
        print("  Modo: OBSERVADOR")
        print("  /ver para ver pantalla")
        print("  /controlar para activar control")
        print("  /help para todos los comandos")
        print("=" * 50)
        print()

        while self.running:
            try:
                cmd = input(">> ").strip()
                self.process_command(cmd)
            except KeyboardInterrupt:
                print("\nInterrumpido. Cerrando...")
                self.running = False
            except EOFError:
                self.running = False

        print("Agente cerrado.")

if __name__ == "__main__":
    agent = LiveAgent()
    agent.run()
