"""Agente HID - Actua como un humano
Movimientos naturales, delays random, OCR en vivo.
Recibe instrucciones en lenguaje natural y las ejecuta.
Soporta emulador Android (ADB) y escritorio (pyautogui)."""

import os, sys, time, random, json, subprocess, re
import pyautogui, pytesseract, cv2, numpy as np
from PIL import Image

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.02

API = "http://192.168.4.23:8000"

class HIDAgent:
    def __init__(self):
        self.mode = "OBSERVANDO"
        self.target = "desktop"  # desktop or adb
        self.last_text = ""
        self.step = 0
        self.screen_w, self.screen_h = pyautogui.size()

    def say(self, msg, icon="HID"):
        self.step += 1
        print(f" [{self.step:02d}] [{icon}] {msg}")

    def human_delay(self, base=0.5, variance=0.3):
        """Delay aleatorio como un humano (entre base-variance y base+variance)"""
        t = max(0.01, base + random.uniform(-variance, variance))
        time.sleep(t)

    def human_move(self, x, y, steps=None):
        """Mueve el mouse en curva natural, no en linea recta"""
        mx, my = pyautogui.position()
        if steps is None:
            dist = ((x - mx)**2 + (y - my)**2)**0.5
            steps = max(3, int(dist / 30))

        for i in range(1, steps + 1):
            t = i / steps
            cx = mx + (x - mx) * t + random.uniform(-5, 5) * (1 - abs(2*t - 1))
            cy = my + (y - my) * t + random.uniform(-3, 3) * (1 - abs(2*t - 1))
            pyautogui.moveTo(int(cx), int(cy))
            time.sleep(0.003)

    def human_click(self, x, y):
        """Click en coordenadas con delay humano"""
        self.say(f"Moviendo a ({x},{y})...", "MOUSE")
        self.human_move(x, y)
        self.human_delay(0.2, 0.1)
        pyautogui.click()
        self.human_delay(0.5, 0.3)

    def human_type(self, text):
        """Escribe caracter por caracter con delays variables"""
        for ch in text:
            pyautogui.write(ch)
            time.sleep(random.uniform(0.02, 0.08))
        self.human_delay(0.3, 0.2)

    # ─── VISION ──────────────────────────────────────

    def see(self):
        """Captura + OCR de la pantalla"""
        if self.target == "adb":
            return self._adb_see()
        img = pyautogui.screenshot()
        gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
        gray_small = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        self.last_text = pytesseract.image_to_string(gray_small)
        return self.last_text

    def _adb_see(self):
        tmp = os.environ.get("TEMP", "/tmp") + f"\\adb_hid_{os.getpid()}.png"
        subprocess.run(f"adb exec-out screencap -p > \"{tmp}\"", shell=True, timeout=10)
        time.sleep(0.2)
        img = cv2.imread(tmp)
        if img is None:
            return ""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        self.last_text = pytesseract.image_to_string(gray)
        return self.last_text

    def find_text(self, text, min_conf=35):
        """Busca texto en pantalla, devuelve (x,y,word,conf)"""
        if self.target == "adb":
            tmp = os.environ.get("TEMP", "/tmp") + f"\\adb_find_{os.getpid()}.png"
            subprocess.run(f"adb exec-out screencap -p > \"{tmp}\"", shell=True, timeout=10)
            time.sleep(0.2)
            img = cv2.imread(tmp)
            if img is None: return []
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        else:
            img = pyautogui.screenshot()
            gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)

        gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
        matches = []
        for i in range(len(data['text'])):
            try:
                conf = int(data['conf'][i])
                word = data['text'][i].strip()
                if conf > min_conf and text.lower() in word.lower():
                    x = (data['left'][i] + data['width'][i]//2) * 2
                    y = (data['top'][i] + data['height'][i]//2) * 2
                    matches.append((x, y, word, conf))
            except: pass
        return matches

    # ─── ACCIONES ────────────────────────────────────

    def click_on_text(self, text):
        """Busca texto y hace click con movimiento humano"""
        self.say(f"Buscando '{text}'...", "VISION")
        matches = self.find_text(text, 35)
        if not matches:
            # Intentar con confianza mas baja
            matches = self.find_text(text, 25)
        if matches:
            x, y, word, conf = matches[0]
            if self.target == "adb":
                subprocess.run(f"adb shell input tap {x} {y}", shell=True)
                self.say(f"Click ADB en '{word}' ({x},{y})", "ACTION")
            else:
                self.human_click(x, y)
                self.say(f"Click en '{word}' ({x},{y})", "ACTION")
            self.human_delay(1.0, 0.5)
            return True
        self.say(f"No encontre '{text}'", "VISION")
        return False

    def click_coords(self, x, y):
        """Click en coordenadas exactas"""
        if self.target == "adb":
            subprocess.run(f"adb shell input tap {x} {y}", shell=True)
        else:
            self.human_click(x, y)
        self.human_delay(0.5, 0.3)

    def type_on_screen(self, text):
        """Escribe texto donde esta el foco"""
        if self.target == "adb":
            safe_text = text.replace('"', '\\"')
            subprocess.run(f"adb shell input text \"{safe_text}\"", shell=True)
        else:
            self.human_type(text)
        self.say(f"Escrito: '{text}'", "ACTION")
        self.human_delay(0.2, 0.1)

    def press_key(self, key):
        if self.target == "adb":
            keycode = {"enter": 66, "tab": 61, "esc": 111, "back": 4, "space": 62}.get(key.lower(), 66)
            subprocess.run(f"adb shell input keyevent {keycode}", shell=True)
        else:
            pyautogui.press(key)
        self.human_delay(0.2, 0.1)

    def scroll_human(self, amount):
        """Scroll natural (no instantaneo)"""
        steps = max(3, abs(amount) // 2)
        for _ in range(steps):
            pyautogui.scroll(amount // steps)
            time.sleep(0.02)

    # ─── TASKS ───────────────────────────────────────

    def execute(self, task):
        """Interpreta y ejecuta una instruccion en lenguaje natural"""
        self.step = 0
        t = task.lower()
        self.say(f"INSTRUCCION: {task}", "TASK")
        self.say("-" * 50)

        # Detectar tipo de tarea
        if any(w in t for w in ['registr', 'crear cuenta', 'signup', 'sign up']):
            return self._task_register(task)
        elif any(w in t for w in ['login', 'iniciar sesion', 'loguear']):
            return self._task_login(task)
        elif any(w in t for w in ['abrir', 'open', 'chrome', 'navegador', 'notepad', 'calc']):
            return self._task_open_app(task)
        elif any(w in t for w in ['buscar', 'search', 'google']):
            return self._task_search(task)
        elif any(w in t for w in ['escribir', 'type', 'escribe', 'texto']):
            return self._task_type(task)
        else:
            return self._task_generic(task)

    def _task_register(self, task):
        """Registra un usuario en la app CommuteShare"""
        email = re.search(r'[\w.]+@[\w.]+', task)
        email = email.group(0) if email else f"user{random.randint(1000,9999)}@test.com"

        pass_match = re.search(r'pass(?:word)?[:\s]*(\S+)', task)
        password = pass_match.group(1) if pass_match else "123456"

        name_match = re.search(r'(?:nombre|name|como)[:\s]*(\w+)', task)
        name = name_match.group(1) if name_match else "Usuario"

        self.say(f"Plan: Registrar {email} en CommuteShare", "PLAN")

        # 1. Leer pantalla actual
        self.say("Observando pantalla...", "VISION")
        screen = self.see()
        self.say(f"Leo: {screen[:120]}", "OCR")

        # 2. Si no estamos en el emulador, cambiar a modo ADB
        if 'CommuteShare' not in screen and 'commute' not in screen.lower():
            self.say("App no visible en desktop. Cambiando a emulador...", "SWITCH")
            self.target = "adb"
            subprocess.run("adb shell am force-stop com.example.new_desing", shell=True)
            time.sleep(0.5)
            subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
            self.human_delay(5, 2)
            screen = self.see()
            self.say(f"Emulador: {screen[:120]}", "OCR")

        # 3. Ir a registro
        if 'Registr' in screen:
            self.click_on_text('Registr')
            time.sleep(2)
        elif 'Crear cuenta' in screen:
            self.say("Ya en formulario de registro", "OK")
        else:
            # Tap directo en posicion conocida
            self.say("Click directo en Registrate", "FALLBACK")
            self.click_coords(712, 1611)
            time.sleep(2)

        # 4. Verificar formulario
        screen = self.see()
        if 'Crear cuenta' in screen or 'Nombre' in screen:
            self.say("Formulario de registro visible", "OK")
        else:
            self.say("Continuando (no se detecta formulario)...", "WARN")

        # 5. Llenar campos
        self.say(f"Llenando: Nombre={name}", "ACTION")
        self.type_on_screen(name)
        self.press_key('tab')

        self.say("Apellido=Test", "ACTION")
        self.type_on_screen("Test")
        self.press_key('tab')

        self.say(f"Email={email}", "ACTION")
        self.type_on_screen(email)
        self.press_key('tab')

        self.press_key('tab')  # skip phone

        self.say(f"Password=***", "ACTION")
        self.type_on_screen(password)
        self.press_key('tab')

        self.say("Confirmar password", "ACTION")
        self.type_on_screen(password)

        self.human_delay(0.3, 0.2)

        # 6. Scroll para ver el boton Crear cuenta
        self.say("Buscando boton Crear cuenta...", "ACTION")
        if self.target == "adb":
            subprocess.run("adb shell input swipe 540 1500 540 400 400", shell=True)
        else:
            self.scroll_human(-5)
        time.sleep(1)

        # 7. Click en Crear cuenta
        clicked = self.click_on_text('Crear cuenta') or self.click_on_text('Crear')
        if not clicked:
            self.say("Boton no encontrado. Tap directo.", "FALLBACK")
            self.click_coords(540, 500)
        time.sleep(5)

        # 8. Verificar
        screen = self.see()
        self.say(f"Resultado: {screen[:150]}", "VERIFY")

        # 9. API fallback
        import requests
        try:
            r = requests.post(f"{API}/Create_driver/", json={
                "name": name, "email": email, "password": password, "role": "driver"
            }, timeout=5)
            if r.status_code in (200, 201):
                self.say("API: Usuario creado", "API")
            else:
                self.say(f"API: {r.status_code}", "API")
        except Exception as e:
            self.say(f"API offline: {e}", "WARN")

        self.say("-" * 50)
        self.say(f"REGISTRO: {email} / {password}", "DONE")
        return True

    def _task_login(self, task):
        email = re.search(r'[\w.]+@[\w.]+', task)
        email = email.group(0) if email else "conductor@test.com"
        pass_match = re.search(r'pass(?:word)?[:\s]*(\S+)', task)
        password = pass_match.group(1) if pass_match else "123456"

        self.say(f"Login: {email}", "PLAN")

        subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
        time.sleep(5)
        self.target = "adb"

        if self.see().count('CommuteShare'):
            self.click_on_text('Correo')
            self.type_on_screen(email)
            self.click_on_text('Contrase')
            self.type_on_screen(password)
            self.press_key('enter')
            time.sleep(5)

        self.say(f"Login intentado: {email}", "DONE")
        return True

    def _task_open_app(self, task):
        apps = ['chrome', 'edge', 'notepad', 'calculator', 'calc', 'vscode', 'code', 'terminal', 'cmd']
        app = next((a for a in apps if a in task.lower()), 'chrome')
        self.say(f"Abriendo {app}...", "ACTION")
        pyautogui.hotkey('win', 'r')
        time.sleep(0.5)
        self.human_type(app)
        self.press_key('enter')
        time.sleep(3)
        self.say(f"{app} abierto", "DONE")
        return True

    def _task_search(self, task):
        query = task
        for w in ['buscar', 'search', 'google', 'busca']:
            if w in task.lower():
                query = task.lower().split(w, 1)[1].strip()
                break
        self.say(f"Abriendo Chrome y buscando: {query}", "PLAN")
        pyautogui.hotkey('win', 'r')
        time.sleep(0.3)
        self.human_type('chrome')
        self.press_key('enter')
        time.sleep(2)
        self.human_type(query)
        self.press_key('enter')
        self.say("Busqueda realizada", "DONE")
        return True

    def _task_type(self, task):
        text = task
        for w in ['escribir', 'type', 'escribe', 'texto']:
            if w in task.lower():
                text = task.lower().split(w, 1)[1].strip()
                break
        self.type_on_screen(text)
        return True

    def _task_generic(self, task):
        self.say(f"No tengo plan para: '{task}'", "WARN")
        self.say("Tareas que entiendo:", "HELP")
        self.say("  'registra a user@test.com'")
        self.say("  'login con conductor@test.com'")
        self.say("  'abre chrome'")
        self.say("  'busca python'")
        self.say("  'escribe hola mundo y presiona enter'")
        return False


if __name__ == "__main__":
    agent = HIDAgent()

    print()
    print("=" * 60)
    print("  AGENTE HID - Actua como un humano")
    print("  Movimientos naturales, OCR, sigue instrucciones")
    print("=" * 60)
    print()

    if len(sys.argv) > 1:
        task = ' '.join(sys.argv[1:])
    else:
        print("Dame una instruccion (ej: 'registra a test@test.com'):")
        task = input(">> ").strip()

    if not task:
        print("Sin instruccion.")
        sys.exit(1)

    ok = agent.execute(task)
    print(f"\n{'[OK] Tarea completada' if ok else '[FAIL] Tarea no completada'}")
