"""AI Agent Final v3 - Inteligente, no se traba, elige mejor accion
   Observa, planea, ejecuta, verifica, corrige"""

import os, sys, time, re, subprocess
import pyautogui, pytesseract, cv2, numpy as np

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
API = "http://192.168.4.23:8000"

def log(msg):
    print(f"  [{time.strftime('%H:%M:%S')}] {msg}")

def see():
    img = pyautogui.screenshot()
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    gray_small = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
    text = pytesseract.image_to_string(gray_small)
    data = pytesseract.image_to_data(gray_small, output_type=pytesseract.Output.DICT)
    matches = []
    for i in range(len(data['text'])):
        try:
            conf = int(data['conf'][i])
            word = data['text'][i].strip()
            if conf > 30 and len(word) > 2:
                x = (data['left'][i] + data['width'][i]//2) * 2
                y = (data['top'][i] + data['height'][i]//2) * 2
                matches.append((word, x, y, conf))
        except: pass
    return text, matches

def click_word(word, matches=None, retries=3):
    if matches is None: _, matches = see()
    for attempt in range(retries):
        for m in matches:
            if word.lower() in m[0].lower():
                pyautogui.click(m[1], m[2])
                time.sleep(0.5)
                log(f"Click OK en '{m[0]}' ({m[1]},{m[2]})")
                return True
        time.sleep(0.3)
        if attempt < retries - 1:
            _, matches = see()
    log(f"No clickeable: '{word}'")
    return False

def type_text(text):
    pyautogui.write(text, interval=0.03)
    log(f"Escrito: '{text[:40]}'")

def press(key):
    pyautogui.press(key)
    time.sleep(0.3)
    log(f"Tecla: {key}")

def open_app(app, method="auto"):
    """Abre una app. Metodos: auto, winr, start, taskbar"""
    if method == "auto":
        open_app(app, "winr")
        time.sleep(2)
        text, _ = see()
        if app.lower() in text.lower():
            log(f"{app} abierto via Win+R")
            return True
        log("Win+R no detectado. Probando Start Menu...")
        return open_app(app, "start")

    if method == "winr":
        pyautogui.hotkey('win', 'r')
        time.sleep(0.4)
        pyautogui.write(app, interval=0.03)
        pyautogui.press('enter')
        log(f"Win+R -> {app} -> Enter")
        return True

    if method == "start":
        pyautogui.press('win')
        time.sleep(0.5)
        pyautogui.write(app, interval=0.04)
        time.sleep(0.5)
        pyautogui.press('enter')
        log(f"Start -> {app} -> Enter")
        return True

    if method == "taskbar":
        _, matches = see()
        return click_word(app, matches)

def search_query(query):
    """Busca query en Chrome (abre si no esta abierto)"""
    text, matches = see()

    # Chrome ya abierto?
    chrome_open = any('chrome' in m[0].lower() or 'google' in m[0].lower() 
                      for m in matches)

    if not chrome_open:
        open_app('chrome')
        time.sleep(3)

    pyautogui.hotkey('ctrl', 'l')  # Focus address bar
    time.sleep(0.3)
    pyautogui.write(query, interval=0.03)
    pyautogui.press('enter')
    log(f"Buscando: '{query}'")

def register_user(task):
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
        log(f"API registro: {'OK' if r.status_code in (200, 201) else r.status_code}")
    except Exception as e:
        log(f"API error: {e}")

    subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
    log(f"Usuario: {email} / {password}")
    return True

# ─── PLANIFICADOR INTELIGENTE ────────────────────────

def plan(task):
    """Analiza la tarea y devuelve lista de (accion, args)"""
    t = task.lower()
    steps = []

    # ¿Abrir algo?
    apps_known = ['chrome', 'edge', 'notepad', 'calc', 'calculator', 'vscode', 
                  'code', 'cmd', 'terminal', 'powershell', 'explorer', 'settings']
    app_requested = None
    for a in apps_known:
        if a in t:
            app_requested = a
            break

    if any(w in t for w in ['abrir', 'abre', 'open', 'lanza']):
        if app_requested:
            steps.append(('open', app_requested))
        else:
            for word in t.split():
                if len(word) > 2 and word not in ['abrir', 'abre', 'open', 
                    'lanza', 'y', 'buscar', 'busca', 'el', 'la', 'que', 'con']:
                    steps.append(('open', word))
                    break

    # ¿Buscar?
    if any(w in t for w in ['buscar', 'busca', 'search', 'google']):
        q = t
        for kw in ['buscar ', 'busca ', 'search ', 'google ']:
            if kw in q: q = q.split(kw, 1)[1].strip(); break
        steps.append(('search', q if q != t else t.split()[-1]))

    # ¿Escribir?
    if any(w in t for w in ['escribir', 'escribe', 'type']):
        txt = t
        for w in ['escribir ', 'escribe ', 'type ']:
            if w in txt: txt = txt.split(w, 1)[1].strip(); break
        steps.append(('type', txt if txt != t else ''))

    # ¿Presionar?
    if any(w in t for w in ['presionar', 'presiona', 'pulsa', 'enter', 'tab', 'esc', 'espacio']):
        key = 'enter'
        for k in ['enter', 'tab', 'esc', 'espacio', 'space', 'backspace', 'f5', 'f11']:
            if k in t: key = k; break
        steps.append(('key', key))

    # ¿Ver?
    if any(w in t for w in ['ver', 've', 'que ves', 'que hay', 'describe', 'muestra']):
        steps.append(('see', None))

    # ¿Registrar?
    if any(w in t for w in ['registr', 'crear cuenta']):
        steps.append(('register', task))

    # ¿Login?
    if any(w in t for w in ['login', 'iniciar sesion', 'loguear']):
        steps.append(('login', task))

    # Si nada detectado, intentar como busqueda generica
    if not steps and len(t.split()) > 1:
        steps.append(('search', t))

    return steps

# ─── EJECUTOR ────────────────────────────────────────

def execute_plan(steps):
    ok = 0
    for action, arg in steps:
        try:
            if action == 'open':
                log(f"Abrir: {arg}")
                open_app(arg)
                ok += 1
            elif action == 'search':
                log(f"Buscar: {arg}")
                search_query(arg)
                ok += 1
            elif action == 'type':
                log(f"Escribir: {arg}")
                type_text(arg)
                ok += 1
            elif action == 'key':
                log(f"Tecla: {arg}")
                press(arg)
                ok += 1
            elif action == 'see':
                _, matches = see()
                text, _ = see()
                log(f"Veo {len(matches)} palabras:")
                for w, x, y, c in matches[:10]:
                    log(f"  '{w}' ({x},{y})")
                ok += 1
            elif action == 'register':
                register_user(arg)
                ok += 1
            elif action == 'login':
                log(f"Login: {arg}")
                register_user(arg)
                ok += 1
            time.sleep(0.5)
        except Exception as e:
            log(f"ERROR en {action}: {e}")
    return ok

# ─── MAIN ────────────────────────────────────────────

def execute(task):
    log(f"TAREA: {task}")
    print("-" * 50)

    # Ver pantalla rapidamente
    _, matches = see()
    words = [m[0] for m in matches[:10]]
    log(f"Veo: {', '.join(words[:6])}" if words else "Veo: pantalla limpia")

    # Planificar
    steps = plan(task)
    if not steps:
        log("No entendi. Prueba: 'abre chrome', 'busca python', 'que ves', 'escribe hola', 'registra a user@test.com'")
        return False

    log(f"Plan: {len(steps)} paso(s) -> {[s[0] for s in steps]}")

    # Ejecutar
    done = execute_plan(steps)
    log(f"Completado: {done}/{len(steps)} pasos")
    return done > 0

if __name__ == "__main__":
    if len(sys.argv) > 1:
        task = ' '.join(sys.argv[1:])
        print(f"\n{'[OK]' if execute(task) else '[FAIL]'}")
    else:
        print("AI Agent v3 - Inteligente, no se traba")
        print("python agent_final.py 'abre chrome y busca python'")
        print("python agent_final.py 'que ves'")
        print("python agent_final.py 'escribe hola y presiona enter'")
        print("python agent_final.py 'registra a user@test.com'")
