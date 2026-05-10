"""AI Agent Final - Controla la PC en lenguaje natural (Pantalla 1)
   Tareas: ver, abrir, buscar, escribir, presionar, registrar, login"""

import os, sys, time, re, json, subprocess
import pyautogui, pytesseract, cv2, numpy as np

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
API = "http://192.168.4.23:8000"

def log(msg):
    print(f"  [{time.strftime('%H:%M:%S')}] {msg}")

def see():
    """Captura pantalla y OCR"""
    img = pyautogui.screenshot()
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
    text = pytesseract.image_to_string(gray)
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)

    matches = []
    for i in range(len(data['text'])):
        try:
            conf = int(data['conf'][i])
            word = data['text'][i].strip()
            if conf > 35 and len(word) > 2:
                x = (data['left'][i] + data['width'][i]//2) * 2
                y = (data['top'][i] + data['height'][i]//2) * 2
                matches.append((word, x, y, conf))
        except: pass

    return text, matches

def click_word(word, matches=None):
    if matches is None: _, matches = see()
    for m in matches:
        if word.lower() in m[0].lower():
            pyautogui.click(m[1], m[2])
            log(f"Click en '{m[0]}' ({m[1]},{m[2]})")
            return True
    log(f"No encontre '{word}'")
    return False

def type_text(text):
    pyautogui.write(text, interval=0.03)
    log(f"Escrito: '{text}'")

def press(key):
    pyautogui.press(key)
    log(f"Tecla: '{key}'")

def win_r(app):
    """Win+R, escribe app, Enter"""
    pyautogui.hotkey('win', 'r')
    time.sleep(0.3)
    pyautogui.write(app, interval=0.03)
    pyautogui.press('enter')
    log(f"Win+R + '{app}' + Enter")

def execute(task):
    """Interpreta y ejecuta una tarea en lenguaje natural"""
    t = task.lower()
    log(f"TAREA: {task}")
    print("-" * 50)

    text, matches = see()
    visible = [m[0] for m in matches[:15]]
    log(f"Veo: {', '.join(visible[:8])}" if visible else "Veo: escritorio")

    actions_done = []

    # ─── VER ───
    if any(w in t for w in ['ver', 've', 'que ves', 'describe', 'que hay', 'muestra']):
        log("=== LO QUE VEO EN PANTALLA ===")
        for l in text.split('\n')[:12]:
            if l.strip(): print(f"  {l.strip()}")
        return True

    # ─── ABRIR APP ───
    if any(w in t for w in ['abrir', 'abre', 'open', 'lanza']):
        app = t
        for w in ['abrir', 'abre', 'open', 'lanza', 'inicia', 'ejecutar']:
            app = app.replace(w, '').strip()
        for sep in [' y busca', ' y buscar', ', busca', ', buscar']:
            if sep in app: app = app.split(sep)[0].strip()
        win_r(app)
        time.sleep(3)
        actions_done.append("open")

    # ─── BUSCAR ───
    if any(w in t for w in ['buscar', 'busca', 'search', 'google']):
        query = ""
        for kw in ['buscar ', 'busca ', 'search ', 'google ']:
            if kw in t: query = t.split(kw, 1)[1].strip(); break
        if actions_done:
            type_text(query)
            press('enter')
        else:
            win_r('chrome')
            time.sleep(3)
            if query:
                type_text(query)
                press('enter')
        actions_done.append("search")

    if actions_done:
        log(f"OK: {', '.join(actions_done)}")
        return True

    # ─── ESCRIBIR ───
    if any(w in t for w in ['escribir', 'escribe', 'type', 'escribe']):
        txt = t
        for w in ['escribir', 'escribe', 'type', 'escribe', 'texto']:
            txt = txt.replace(w, '').strip()
        type_text(txt)
        return True

    # ─── PRESIONAR TECLA ───
    if any(w in t for w in ['presionar', 'presiona', 'pulsa', 'tecla', 'enter', 'tab', 'esc', 'espacio']):
        key = 'enter'
        for k in ['enter', 'tab', 'esc', 'espacio', 'space', 'backspace', 'f5', 'f11']:
            if k in t: key = k; break
        press(key)
        return True

    # ─── REGISTRAR EN COMMUTESHARE ───
    if any(w in t for w in ['registr', 'crear cuenta']):
        email = re.search(r'[\w.]+@[\w.]+', task)
        email = email.group(0) if email else f"user{int(time.time())%10000}@test.com"
        pass_match = re.search(r'pass(?:word)?[:\s]*(\S+)', task, re.IGNORECASE)
        password = pass_match.group(1) if pass_match else "123456"
        name_match = re.search(r'(?:nombre|name|como)[:\s]*(\w+)', task, re.IGNORECASE)
        name = name_match.group(1) if name_match else "User"

        import requests
        try:
            r = requests.post(f"{API}/Create_driver/",
                json={"name": name, "email": email, "password": password, "role": "driver"}, timeout=5)
            log(f"API: {'OK' if r.status_code in (200, 201) else r.status_code}")
        except Exception as e:
            log(f"API error: {e}")

        subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
        log(f"Registrado: {email}")
        return True

    log("No reconozco. Intentos:")
    log("  'que ves'  'abre chrome y busca python'  'escribe hola'")
    log("  'registra a user@test.com'  'presiona enter'")
    return False

if __name__ == "__main__":
    if len(sys.argv) > 1:
        task = ' '.join(sys.argv[1:])
        ok = execute(task)
        print(f"\n{'[OK]' if ok else '[FAIL]'} Tarea completada")
    else:
        print("AI Agent - Controla la PC en lenguaje natural")
        print("python agent_final.py 'abre chrome y busca python'")
        print("python agent_final.py 'escribe hola mundo y presiona enter'")
        print("python agent_final.py 'que ves'")
        print("python agent_final.py 'registra a test@test.com'")
