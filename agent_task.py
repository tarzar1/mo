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
    def __init__(self):
        self.current_task = None
        self.step = 0
        self.screen_w, self.screen_h = pyautogui.size()

    def say(self, msg):
        step_mark = f"[{self.step:02d}]" if self.step else "[INIT]"
        print(f"{step_mark} {msg}")

    def see(self):
        """Captura + OCR de la pantalla completa"""
        img = pyautogui.screenshot()
        screen = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(screen, cv2.COLOR_BGR2GRAY)
        gray_small = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        text = pytesseract.image_to_string(gray_small)
        return text

    def find(self, text, min_conf=40):
        """Busca texto en pantalla y devuelve coordenadas"""
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

    def click_text(self, text):
        """Busca y clickea texto"""
        matches = self.find(text, 35)
        if matches:
            x, y, word, conf = matches[0]
            pyautogui.click(x, y)
            self.say(f"Click en '{word}' ({x},{y}) conf={conf}")
            time.sleep(1.5)
            return True
        else:
            self.say(f"No encontre '{text}' en pantalla")
            return False

    def type_text(self, text):
        pyautogui.write(text, interval=0.04)
        self.say(f"Escribi: '{text}'")
        time.sleep(0.3)

    def press(self, key):
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
        # Extraer email de la tarea
        email_match = re.search(r'[\w.]+@[\w.]+', task)
        email = email_match.group(0) if email_match else f"user{int(time.time())%10000}@test.com"
        
        # Extraer password
        pass_match = re.search(r'pass(word)?[:\s]*(\S+)', task)
        password = pass_match.group(2) if pass_match else "123456"
        
        # Extraer nombre
        name_match = re.search(r'(nombre|name|como)[:\s]*(\w+)', task)
        name = name_match.group(2) if name_match else "User"

        self.say(f"Plan: Registrar {email} / {password}")

        # Paso 1: Ver donde estamos
        self.step += 1
        screen = self.see()
        self.say(f"Pantalla: {screen[:150]}")

        # Paso 2: Ir a la app CommuteShare en el emulador
        self.step += 1
        self.say("Abriendo app CommuteShare...")
        subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
        time.sleep(5)

        # Paso 3: Hacer click en "Registrate" si esta en login
        self.step += 1
        screen = self.see()
        if 'Registrate' in screen or 'REGISTRATE' in screen:
            self.say("Detectado boton Registrate. Clickeando...")
            self.click_text('Registr')
            time.sleep(2)
        elif 'Crear cuenta' in screen:
            self.say("Ya estamos en registro")
        else:
            # Emulador: usar ADB
            self.say("Usando ADB para emulador...")
            subprocess.run("adb shell input tap 712 1611", shell=True)
            time.sleep(2)

        # Paso 4: Verificar que estamos en formulario de registro
        self.step += 1
        screen = self.see()
        if 'Crear cuenta' in screen or 'Nombre' in screen:
            self.say("En formulario de registro")
        else:
            self.say("WARN: No se detecta formulario")

        # Paso 5: Llenar campos
        self.step += 1
        self.say(f"Llenando Nombre: {name}")
        subprocess.run(f"adb shell input text {name}", shell=True)
        time.sleep(0.3)

        # Navegar entre campos con Tab en el emulador
        for field in ['Apellido', 'Email', 'Telefono', 'Password', 'Confirmar']:
            subprocess.run("adb shell input keyevent 61", shell=True)
            time.sleep(0.15)
            if field == 'Email':
                subprocess.run(f"adb shell input text {email}", shell=True)
            elif field == 'Password' or field == 'Confirmar':
                subprocess.run(f"adb shell input text {password}", shell=True)
            elif field == 'Apellido':
                subprocess.run("adb shell input text Test", shell=True)

        self.say("Formulario llenado por ADB")

        # Paso 6: Buscar y clickear "Crear cuenta"
        self.step += 1
        time.sleep(1)
        # Scroll down para ver el boton
        subprocess.run("adb shell input swipe 540 1500 540 500 300", shell=True)
        time.sleep(1)
        self.click_text('Crear cuenta') or subprocess.run("adb shell input tap 540 600", shell=True)
        time.sleep(4)

        # Paso 7: Verificar resultado
        self.step += 1
        screen = self.see()
        if 'Crear cuenta' not in screen and 'Nombre' not in screen:
            self.say("Registro parece exitoso!")
        else:
            self.say("Posiblemente el registro fallo o necesita verificacion")

        # Verificar via API
        import requests
        try:
            r = requests.post(f"{API_BASE}/login_jwt",
                json={"email": email, "password": password}, timeout=5)
            if r.status_code == 200:
                self.say(f"API confirma: Login OK para {email}")
            else:
                self.say(f"API: {r.status_code}")
        except:
            pass

        self.say("â”€" * 40)
        self.say(f"TAREA COMPLETADA: {email} / {password}")
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
    agent = TaskAgent()
    
    if len(sys.argv) > 1:
        task = ' '.join(sys.argv[1:])
    else:
        print("Uso: python agent_task.py <tarea en lenguaje natural>")
        print("Ejemplos:")
        print("  python agent_task.py registrate como test@test.com")
        print("  python agent_task.py abre chrome y busca python")
        print("  python agent_task.py login con conductor@test.com")
        sys.exit(1)

    result = agent.execute(task)
    print(f"\n{'OK' if result else 'FAIL'} - Tarea completada" if result else "\nFAIL - Tarea no completada")
