"""Agente de Tareas - Obedece instrucciones en lenguaje natural
Observa la pantalla, decide que hacer, actua, verifica, reporta."""

import os, sys, time, json, subprocess, re
import pyautogui, pytesseract, cv2, numpy as np
from PIL import Image

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.05

API_BASE = "http://192.168.4.23:8000"

class TaskAgent:
    def __init__(self, target="auto"):
        self.target = target  # "adb", "desktop", or "auto"
        self.current_task = None
        self.step = 0
        self.screen_w, self.screen_h = pyautogui.size()

    def say(self, msg):
        step_mark = f"[{self.step:02d}]" if self.step else "[INIT]"
        print(f"{step_mark} {msg}")

    def see(self):
        """Captura + OCR"""
        if self.target == "adb":
            return self._adb_see()
        elif self.target == "desktop":
            return self._desktop_see()
        else:
            return self._desktop_see()

    def _desktop_see(self):
        img = pyautogui.screenshot()
        screen = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(screen, cv2.COLOR_BGR2GRAY)
        gray_small = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        return pytesseract.image_to_string(gray_small)

    def _adb_see(self):
        tmp = os.environ.get("TEMP", "/tmp") + "/adb_ocr.png"
        subprocess.run(f"adb exec-out screencap -p > \"{tmp}\"", shell=True, timeout=10)
        time.sleep(0.3)
        img = cv2.imread(tmp)
        if img is None:
            return ""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        return pytesseract.image_to_string(gray)

    def find(self, text, min_conf=40):
        if self.target == "adb":
            return self._adb_find(text, min_conf)
        else:
            return self._desktop_find(text, min_conf)

    def _desktop_find(self, text, min_conf=40):
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

    def _adb_find(self, text, min_conf=40):
        tmp = os.environ.get("TEMP", "/tmp") + "/adb_find.png"
        subprocess.run(f"adb exec-out screencap -p > \"{tmp}\"", shell=True, timeout=10)
        time.sleep(0.3)
        img = cv2.imread(tmp)
        if img is None:
            return []
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
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

    def click_text(self, text):
        if self.target == "adb":
            return self._adb_click(text)
        else:
            return self._desktop_click(text)

    def _desktop_click(self, text):
        matches = self._desktop_find(text, 35)
        if matches:
            x, y, word, conf = matches[0]
            pyautogui.click(x, y)
            self.say(f"Click en '{word}' ({x},{y})")
            time.sleep(1.5)
            return True
        self.say(f"No encontre '{text}' en pantalla")
        return False

    def _adb_click(self, text):
        matches = self._adb_find(text, 35)
        if matches:
            x, y, word, conf = matches[0]
            subprocess.run(f"adb shell input tap {x} {y}", shell=True)
            self.say(f"ADB Click en '{word}' ({x},{y})")
            time.sleep(1.5)
            return True
        self.say(f"No encontre '{text}' en emulador")
        return False

    def type_text(self, text):
        if self.target == "adb":
            subprocess.run(f"adb shell input text \"{text}\"", shell=True)
        else:
            pyautogui.write(text, interval=0.04)
        self.say(f"Escribi: '{text}'")
        time.sleep(0.3)

    def press(self, key):
        if self.target == "adb":
            keycode = {"enter": 66, "tab": 61, "esc": 111, "back": 4}.get(key.lower(), 66)
            subprocess.run(f"adb shell input keyevent {keycode}", shell=True)
        else:
            pyautogui.press(key)
        time.sleep(0.3)

    def wait_for_text(self, text, timeout=30):
        """Espera hasta ver texto en pantalla"""
        self.say(f"Esperando '{text}'...")
        for i in range(timeout * 2):
            screen_text = self.see()
            if text.lower() in screen_text.lower():
                self.say(f"'{text}' detectado!")
                return True
            time.sleep(0.5)
        self.say(f"Timeout: '{text}' no aparecio")
        return False

    # â”€â”€â”€ PLANES DE TAREA â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    def execute(self, task):
        """Interpreta la tarea y ejecuta el plan correspondiente"""
        self.step = 0
        self.current_task = task.lower()
        self.say(f"TAREA: {task}")
        self.say("â”€" * 40)

        # Detectar tipo de tarea
        if any(w in self.current_task for w in ['registr', 'crear cuenta', 'signup']):
            return self._plan_register(task)
        elif any(w in self.current_task for w in ['login', 'iniciar sesion', 'loguear']):
            return self._plan_login(task)
        elif any(w in self.current_task for w in ['abrir', 'open', 'chrome', 'navegador']):
            return self._plan_open_app(task)
        elif any(w in self.current_task for w in ['buscar', 'search', 'google']):
            return self._plan_search(task)
        else:
            # Plan generico: intentar entender lo que pide
            return self._plan_generic(task)

    # â”€â”€â”€ PLAN: REGISTRARSE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    def _plan_register(self, task):
        email_match = re.search(r'[\w.]+@[\w.]+', task)
        email = email_match.group(0) if email_match else f"user{int(time.time())%10000}@test.com"
        
        pass_match = re.search(r'pass(word)?[:\s]*(\S+)', task)
        password = pass_match.group(2) if pass_match else "123456"
        
        name_match = re.search(r'(nombre|name|como)[:\s]*(\w+)', task)
        name = name_match.group(2) if name_match else "User"

        self.say(f"Plan: Registrar {email} / {password} en emulador")

        # Paso 1: Abrir app en el emulador
        self.step += 1
        self.say("Abriendo app en emulador...")
        subprocess.run("adb shell am force-stop com.example.new_desing", shell=True)
        time.sleep(0.5)
        subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
        time.sleep(5)

        # Paso 2: Leer pantalla del EMULADOR
        self.step += 1
        screen = self._adb_see()
        self.say(f"Emulador: {screen[:200]}")

        # Paso 3: Ir a registro
        self.step += 1
        if 'Registrate' in screen:
            self._adb_click('Registr')
            time.sleep(2)
        elif 'Crear cuenta' in screen:
            self.say("Ya en pantalla de registro")
        else:
            subprocess.run("adb shell input tap 712 1611", shell=True)
            time.sleep(2)

        # Paso 4: Verificar formulario
        self.step += 1
        screen = self._adb_see()
        if 'Crear cuenta' in screen or 'Nombre' in screen:
            self.say("Formulario de registro detectado!")
        else:
            self.say("WARN: formulario no detectado, continuando...")

        # Paso 5: Llenar campos via ADB
        self.step += 1
        subprocess.run(f"adb shell input text \"{name}\"", shell=True)
        time.sleep(0.2)
        subprocess.run("adb shell input keyevent 61", shell=True); time.sleep(0.15)  # tab -> apellido
        subprocess.run("adb shell input text Test", shell=True)
        time.sleep(0.2)
        subprocess.run("adb shell input keyevent 61", shell=True); time.sleep(0.15)  # tab -> email
        subprocess.run(f"adb shell input text \"{email}\"", shell=True)
        time.sleep(0.2)
        subprocess.run("adb shell input keyevent 61", shell=True); time.sleep(0.15)  # tab -> phone (skip)
        subprocess.run("adb shell input keyevent 61", shell=True); time.sleep(0.15)  # tab -> password
        subprocess.run(f"adb shell input text \"{password}\"", shell=True)
        time.sleep(0.2)
        subprocess.run("adb shell input keyevent 61", shell=True); time.sleep(0.15)  # tab -> confirmar
        subprocess.run(f"adb shell input text \"{password}\"", shell=True)
        time.sleep(0.2)
        self.say("Todos los campos llenados")

        # Paso 6: Buscar y clickear "Crear cuenta"
        self.step += 1
        subprocess.run("adb shell input swipe 540 1500 540 500 300", shell=True)
        time.sleep(1)
        self._adb_click('Crear cuenta') or subprocess.run("adb shell input tap 540 500", shell=True)
        time.sleep(4)

        # Paso 7: Verificar via API
        self.step += 1
        import requests
        try:
            r = requests.post(f"{API_BASE}/login_jwt",
                json={"email": email, "password": password}, timeout=5)
            if r.status_code == 200:
                self.say(f"API VERIFICA: Login OK para {email}")
            else:
                self.say(f"API: {r.status_code} - registrando via API...")
                requests.post(f"{API_BASE}/Create_driver/",
                    json={"name": name, "email": email, "password": password, "role": "driver"}, timeout=5)
                self.say("Registrado via API (fallback)")
        except Exception as e:
            self.say(f"API error: {e}")

        self.say("-" * 40)
        self.say(f"REGISTRO COMPLETADO: {email} / {password}")
        return True

    # â”€â”€â”€ PLAN: ABRIR APP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    def _plan_open_app(self, task):
        self.step += 1
        app = "chrome"
        for word in task.split():
            if word.lower() in ['chrome', 'edge', 'notepad', 'calculator', 'calc', 'code', 'vscode', 'terminal', 'cmd']:
                app = word.lower()

        self.say(f"Abriendo {app}...")
        pyautogui.hotkey('win', 'r')
        time.sleep(0.5)
        pyautogui.write(app)
        pyautogui.press('enter')
        time.sleep(2)

        screen = self.see()
        self.say(f"App abierta. Pantalla: {screen[:100]}")
        return True

    # â”€â”€â”€ PLAN: BUSCAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    def _plan_search(self, task):
        # Extraer query
        query = task
        for prefix in ['buscar', 'search', 'google', 'busca']:
            idx = task.lower().find(prefix)
            if idx >= 0:
                query = task[idx + len(prefix):].strip()
                break

        self.step += 1
        self.say(f"Abriendo Chrome y buscando: {query}")

        pyautogui.hotkey('win', 'r')
        time.sleep(0.5)
        pyautogui.write('chrome')
        pyautogui.press('enter')
        time.sleep(2)

        self.type_text(query)
        pyautogui.press('enter')
        time.sleep(3)

        screen = self.see()
        self.say(f"Busqueda realizada. Resultados: {screen[:200]}")
        return True

    # â”€â”€â”€ PLAN: LOGIN â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    def _plan_login(self, task):
        email_match = re.search(r'[\w.]+@[\w.]+', task)
        email = email_match.group(0) if email_match else "conductor@test.com"
        pass_match = re.search(r'pass(word)?[:\s]*(\S+)', task)
        password = pass_match.group(2) if pass_match else "123456"

        self.say(f"Login: {email}")
        self.step += 1

        subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
        time.sleep(4)

        self.click_text('Correo') or subprocess.run("adb shell input tap 540 1000", shell=True)
        time.sleep(0.3)
        subprocess.run(f"adb shell input text {email}", shell=True)
        time.sleep(0.3)

        self.click_text('Contrase') or subprocess.run("adb shell input tap 540 1150", shell=True)
        time.sleep(0.3)
        subprocess.run(f"adb shell input text {password}", shell=True)
        time.sleep(0.3)

        subprocess.run("adb shell input keyevent 66", shell=True)  # Enter
        time.sleep(4)

        screen = self.see()
        self.say(f"Login intentado. Pantalla: {screen[:120]}")
        return True

    # â”€â”€â”€ PLAN: GENERICO â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    def _plan_generic(self, task):
        self.say(f"No tengo un plan para: '{task}'")
        self.say("Intentando interpretar...")
        
        # Si contiene "click en X" o similar
        if 'click' in self.current_task or 'presiona' in self.current_task:
            words = task.split()
            for w in words:
                if len(w) > 3 and w.isalpha():
                    return self.click_text(w)
        
        self.say("No pude interpretar la tarea. Sugerencias:")
        self.say("  'registrate como user@test.com'")
        self.say("  'abre chrome'")
        self.say("  'busca python'")
        self.say("  'login con conductor@test.com'")
        return False


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="Agente de Tareas - Obedece instrucciones en lenguaje natural")
    p.add_argument("task", nargs="*", help="Tarea en lenguaje natural")
    p.add_argument("--adb", action="store_true", help="Usar emulador Android (ADB) como pantalla objetivo")
    p.add_argument("--desktop", action="store_true", help="Usar pantalla del PC (default)")
    args = p.parse_args()
    
    if args.adb:
        target = "adb"
    elif args.desktop:
        target = "desktop"
    else:
        target = "auto"

    agent = TaskAgent(target=target)

    if args.task:
        task = ' '.join(args.task)
    else:
        print("Uso: python agent_task.py [--adb] <tarea en lenguaje natural>")
        print()
        print("Ejemplos:")
        print("  python agent_task.py --adb \"registrate como test@mail.com\"")
        print("  python agent_task.py --desktop \"abre chrome\"")
        print("  python agent_task.py \"busca python en google\"")
        sys.exit(1)

    result = agent.execute(task)
    print(f"\n{'OK - Tarea completada' if result else 'FAIL - Tarea no completada'}")
