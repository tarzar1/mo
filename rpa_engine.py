"""RPA Engine - UI.Vision Style
Comandos: click, wait, type, press, open, search, see
Con fallback automatico, retry, bounding boxes, loop."""

import time, pyautogui, pytesseract, cv2, numpy as np

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    import os
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True

class RPAEngine:
    def __init__(self, log_fn=None):
        self.log = log_fn or print
        self.current_matches = []
        self.steps = []
        self.step_index = 0
        self.running = False
        self.loop_count = 1
        self.loop_current = 0

    def see(self):
        """OCR de la pantalla actual, devuelve matches"""
        img = pyautogui.screenshot()
        gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
        gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
        data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)
        matches = []
        for i in range(len(data['text'])):
            try:
                conf = int(data['conf'][i])
                word = data['text'][i].strip()
                if conf > 25 and len(word) > 1:
                    x = (data['left'][i] + data['width'][i]//2) * 2
                    y = (data['top'][i] + data['height'][i]//2) * 2
                    w = data['width'][i] * 2
                    h = data['height'][i] * 2
                    matches.append({'word': word, 'x': x, 'y': y, 'w': w, 'h': h, 'conf': conf})
            except: pass
        self.current_matches = matches
        text = pytesseract.image_to_string(gray)
        return text, matches

    def find(self, text, min_conf=25):
        """Busca texto en pantalla"""
        _, matches = self.see()
        results = []
        for m in matches:
            if text.lower() in m['word'].lower() and m['conf'] >= min_conf:
                results.append(m)
        return results

    def wait_for(self, text, timeout=30, poll=0.5):
        """Espera hasta que aparezca texto en pantalla"""
        self.log(f"  [WAIT] '{text}' (timeout {timeout}s)")
        start = time.time()
        while time.time() - start < timeout:
            results = self.find(text, min_conf=20)
            if results:
                m = results[0]
                self.log(f"  [WAIT OK] '{m['word']}' en ({m['x']},{m['y']}) ({time.time()-start:.1f}s)")
                return m
            time.sleep(poll)
        self.log(f"  [WAIT FAIL] '{text}' no aparecio en {timeout}s")
        return None

    def click(self, text, retries=3):
        """Busca texto y clickea, con fallback"""
        self.log(f"  [CLICK] Buscando '{text}'...")
        for attempt in range(retries):
            results = self.find(text, min_conf=25)
            if results:
                m = results[0]
                pyautogui.click(m['x'], m['y'])
                time.sleep(0.5)
                self.log(f"  [CLICK OK] '{m['word']}' ({m['x']},{m['y']}) (intento {attempt+1})")
                return True
            time.sleep(0.4)
        self.log(f"  [CLICK FAIL] '{text}' no encontrado")
        return False

    def type(self, text):
        """Escribe texto"""
        pyautogui.write(text, interval=0.03)
        self.log(f"  [TYPE] '{text[:60]}'")
        return True

    def press(self, key):
        """Presiona tecla"""
        pyautogui.press(key)
        time.sleep(0.2)
        self.log(f"  [PRESS] {key}")
        return True

    def open(self, app):
        """Abre app con Win+R. Fallback: Start Menu"""
        self.log(f"  [OPEN] '{app}' via Win+R")
        pyautogui.hotkey('win', 'r')
        time.sleep(0.4)
        pyautogui.write(app, interval=0.03)
        pyautogui.press('enter')
        time.sleep(2)

        # Verificar si se abrio
        _, matches = self.see()
        words = [m['word'].lower() for m in matches]
        if app.lower() in ' '.join(words):
            self.log(f"  [OPEN OK] {app} abierto")
            return True

        self.log(f"  [FALLBACK] Start Menu -> '{app}'")
        pyautogui.press('win')
        time.sleep(0.5)
        pyautogui.write(app, interval=0.04)
        time.sleep(0.5)
        pyautogui.press('enter')
        time.sleep(2)
        return True

    def search(self, query):
        """Busca en Chrome (abre si no esta abierto)"""
        _, matches = self.see()
        chrome_open = any('chrome' in m['word'].lower() for m in matches)

        if not chrome_open:
            self.open('chrome')
            time.sleep(3)

        pyautogui.hotkey('ctrl', 'l')
        time.sleep(0.3)
        pyautogui.write(query, interval=0.03)
        pyautogui.press('enter')
        self.log(f"  [SEARCH] '{query}'")
        return True

    def run_command(self, cmd):
        """Ejecuta un comando individual"""
        parts = cmd.split(' ', 1)
        action = parts[0].lower()
        arg = parts[1] if len(parts) > 1 else ''

        if action == 'click':
            return self.click(arg)
        elif action == 'wait':
            parts2 = arg.rsplit(' ', 1)
            text = parts2[0]
            timeout = int(parts2[1]) if len(parts2) > 1 and parts2[1].isdigit() else 30
            m = self.wait_for(text, timeout)
            return m is not None
        elif action == 'type':
            return self.type(arg)
        elif action == 'press':
            return self.press(arg)
        elif action == 'open':
            return self.open(arg)
        elif action == 'search':
            return self.search(arg)
        elif action == 'see':
            text, matches = self.see()
            self.log(f"  [SEE] {len(matches)} palabras detectadas")
            return True
        elif action == 'sleep':
            try: time.sleep(float(arg))
            except: time.sleep(1)
            return True
        else:
            self.log(f"  [UNKNOWN] {cmd}")
            return False

    def run_script(self, commands):
        """Ejecuta una lista de comandos secuencialmente"""
        self.steps = commands
        self.step_index = 0
        ok = 0
        fail = 0

        for cmd in commands:
            self.step_index += 1
            self.log(f"[{self.step_index}/{len(commands)}] {cmd}")
            if self.run_command(cmd):
                ok += 1
            else:
                fail += 1
                self.log(f"  [FAIL] {cmd}")

        self.log(f"--- {ok}/{ok+fail} comandos OK ---")
        return ok, fail

    def run_nl_task(self, task):
        """Interpreta tarea en lenguaje natural como secuencia de comandos"""
        t = task.lower()
        cmds = []

        # Detectar "abrir X"
        import re
        open_match = re.search(r'(?:abrir|abre|open|lanza)\s+(\w+)', t)
        if open_match:
            app = open_match.group(1)
            cmds.append(f"open {app}")

        # Detectar "buscar X"
        search_match = re.search(r'(?:buscar|busca|search|google)\s+(.+)', t)
        if search_match:
            query = search_match.group(1).strip()
            cmds.append(f"search {query}")

        # Detectar "escribir X"
        type_match = re.search(r'(?:escribir|escribe|type)\s+(.+)', t)
        if type_match:
            cmds.append(f"type {type_match.group(1).strip()}")

        # Detectar "presionar/enter/tab"
        for key in ['enter', 'tab', 'esc', 'espacio', 'f5']:
            if key in t:
                cmds.append(f"press {key}")
                break

        # Detectar "ver"
        if any(w in t for w in ['ver', 've', 'que ves']):
            cmds.append('see')

        if not cmds:
            # Generico: buscar en chrome
            cmds.append(f"search {task}")

        return self.run_script(cmds)
