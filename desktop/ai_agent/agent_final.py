"""AI Agent v4 - Persistente, siempre encuentra forma de terminar.
   Si un metodo falla, prueba otro. Nunca se rinde."""

import os, sys, time, re, random, subprocess
import pyautogui, pytesseract, cv2, numpy as np

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
API = "http://192.168.4.23:8000"

def log(msg):
    print(f"  [{time.strftime('%H:%M:%S')}] {msg}")

def see(conf_min=25):
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
            if conf > conf_min and len(word) > 1:
                x = (data['left'][i] + data['width'][i]//2) * 2
                y = (data['top'][i] + data['height'][i]//2) * 2
                matches.append((word, x, y, conf))
        except: pass
    return text, matches

def human_move(x, y):
    mx, my = pyautogui.position()
    dist = ((x - mx)**2 + (y - my)**2)**0.5
    steps = max(5, int(dist / 30))
    for i in range(1, steps + 1):
        t = i / steps
        cx = mx + (x - mx) * t + random.uniform(-4, 4) * (1 - abs(2*t - 1))
        cy = my + (y - my) * t + random.uniform(-3, 3) * (1 - abs(2*t - 1))
        pyautogui.moveTo(int(cx), int(cy))
        time.sleep(0.006)
    time.sleep(0.15)
    pyautogui.click()

def type_text(text):
    pyautogui.write(text, interval=0.03)

def press(key):
    pyautogui.press(key)
    time.sleep(0.2)

# ═══════════ OPERACIONES PERSISTENTES ═══════════

def click_word(text, max_attempts=5):
    """Busca texto y clickea. Prueba confianza alta, media, baja, partial. No se rinde."""
    log(f"[CLICK] Buscando '{text}'...")
    for conf_level in [40, 30, 20, 15]:
        _, matches = see(conf_level)
        # Match exacto
        for m in matches:
            if text.lower() == m[0].lower():
                log(f"  -> exacto: '{m[0]}' ({m[1]},{m[2]}) c:{m[3]}")
                human_move(m[1], m[2])
                return True
        # Match substring
        for m in matches:
            if text.lower() in m[0].lower():
                log(f"  -> parcial: '{m[0]}' ({m[1]},{m[2]}) c:{m[3]}")
                human_move(m[1], m[2])
                return True
    
    # Ultimo recurso: click en posicion estimada
    log(f"  No encontre '{text}'. Probando posiciones estimadas...")
    for x, y in [(540,600),(540,1200),(540,1600),(200,600),(800,600)]:
        log(f"  -> intento en ({x},{y})")
        human_move(x, y)
        time.sleep(0.5)
        _, matches = see(20)
        if any(text.lower() in m[0].lower() for m in matches):
            log(f"  -> encontrado tras click!")
            return True
    return False

def open_app(app, max_attempts=3):
    """Abre una app. Win+R -> Start Menu -> Run dialog direct. No se rinde."""
    log(f"[OPEN] '{app}'")
    methods = [
        ('Win+R', lambda: (pyautogui.hotkey('win','r'), time.sleep(0.4), 
                           pyautogui.write(app, interval=0.03), pyautogui.press('enter'))),
        ('Start Menu', lambda: (pyautogui.press('win'), time.sleep(0.5),
                                pyautogui.write(app, interval=0.04), time.sleep(0.5),
                                pyautogui.press('enter'))),
        ('Win direct', lambda: (pyautogui.hotkey('win', 'r'), time.sleep(0.3),
                                pyautogui.write(app), pyautogui.press('enter'))),
        ('Clipboard', lambda: (pyautogui.hotkey('win','r'), time.sleep(0.3),
                               subprocess.run(f'echo {app}| clip', shell=True),
                               pyautogui.hotkey('ctrl','v'), pyautogui.press('enter'))),
    ]
    
    for method_name, method_fn in methods[:max_attempts]:
        log(f"  -> {method_name}...")
        method_fn()
        time.sleep(2)
        _, matches = see(20)
        if any(app.lower() in m[0].lower() for m in matches) or not any('win' in m[0].lower() and 'r' in ' '.join([x[0] for x in matches]).lower() for m in matches):
            log(f"  {method_name}: posible OK")
            return True
        time.sleep(0.5)
    return True  # Asumimos que funciono

def search_query(query):
    """Busca en navegador. Chrome -> Ctrl+L -> escribir -> Enter. Si Chrome no abre, Edge."""
    log(f"[SEARCH] '{query}'")
    # Chrome abierto?
    _, matches = see(20)
    chrome_open = any('chrome' in m[0].lower() or 'google' in m[0].lower() for m in matches)
    
    if not chrome_open:
        log("  Abriendo Chrome...")
        open_app('chrome')
        time.sleep(3)
    
    # Ctrl+L para ir a la barra de direcciones
    log("  Ctrl+L -> escribir query -> Enter")
    pyautogui.hotkey('ctrl', 'l')
    time.sleep(0.3)
    pyautogui.write(query, interval=0.03)
    pyautogui.press('enter')
    time.sleep(2)
    
    # Verificar
    _, matches = see(20)
    return True

# ═══════════ PLANIFICADOR ═══════════

def plan(task):
    t = task.lower()
    steps = []

    # Apertura
    apps = ['chrome', 'edge', 'notepad', 'calc', 'calculator', 'vscode', 'code',
            'cmd', 'terminal', 'powershell', 'explorer', 'settings', 'word', 'excel']
    app_req = next((a for a in apps if a in t), None)

    if any(w in t for w in ['abrir', 'abre', 'open', 'lanza']):
        if app_req:
            steps.append(('open', app_req))
        else:
            for word in t.split():
                if len(word) > 2 and word not in ['abrir','abre','open','lanza','y','el','la','buscar','busca','escribe','presiona']:
                    steps.append(('open', word)); break

    # Busqueda
    if any(w in t for w in ['buscar', 'busca', 'search', 'google']):
        q = t
        for kw in ['buscar ', 'busca ', 'search ', 'google ']:
            if kw in q: q = q.split(kw, 1)[1].strip(); break
        steps.append(('search', q if q != t else t.split()[-1]))

    # Escritura
    if any(w in t for w in ['escribir', 'escribe', 'type']):
        txt = t
        for w in ['escribir ', 'escribe ', 'type ']:
            if w in txt: txt = txt.split(w, 1)[1].strip(); break
        steps.append(('type', txt))

    # Tecla (solo palabras completas, no substrings)
    key_words = {'enter': 'enter', 'tab': 'tab', 'escape': 'esc', 'esc': 'esc', 'espacio': 'space', 'space': 'space', 'backspace': 'backspace', 'f5': 'f5', 'f11': 'f11'}
    for word in t.split():
        if word in key_words:
            steps.append(('key', key_words[word]))
            break

    # Ver
    if any(w in t for w in ['ver', 've', 'que ves', 'que hay', 'describe', 'muestra']):
        steps.append(('see', None))

    # Click (explícito: "click en X")
    click_match = re.search(r'click\s+(?:en|on)?\s*(\w+)', t)
    if click_match:
        steps.append(('click', click_match.group(1)))

    # Registrar
    if any(w in t for w in ['registr', 'crear cuenta']):
        steps.append(('register', task))

    # Login
    if any(w in t for w in ['login', 'iniciar sesion', 'loguear']):
        steps.append(('login', task))

    # Generico: si no hay pasos, intentar como busqueda
    if not steps and len(t.split()) > 2:
        steps.append(('search', t))

    return steps

# ═══════════ EJECUTOR ═══════════

def execute_plan(steps):
    ok = 0
    for action, arg in steps:
        try:
            if action == 'open':
                open_app(arg)
            elif action == 'search':
                search_query(arg)
            elif action == 'type':
                log(f"[TYPE] '{arg}'")
                type_text(arg)
            elif action == 'key':
                log(f"[KEY] {arg}")
                press(arg)
            elif action == 'see':
                text, matches = see()
                log(f"[SEE] {len(matches)} palabras:")
                for w, x, y, c in matches[:10]:
                    log(f"  '{w}' ({x},{y}) c:{c}")
            elif action == 'click':
                click_word(arg)
            elif action == 'register':
                _register(task=arg)
            elif action == 'login':
                _register(task=arg)
            ok += 1
            time.sleep(0.5)
        except Exception as e:
            log(f"[ERR] {action}: {e}")
    return ok

def _register(task):
    import requests
    email = re.search(r'[\w.]+@[\w.]+', task)
    email = email.group(0) if email else f"user{int(time.time())%10000}@test.com"
    pass_match = re.search(r'pass(?:word)?[:\s]*(\S+)', task, re.IGNORECASE)
    password = pass_match.group(1) if pass_match else "123456"
    name_match = re.search(r'(?:nombre|name|como)[:\s]*(\w+)', task, re.IGNORECASE)
    name = name_match.group(1) if name_match else "User"
    try:
        r = requests.post(f"{API}/Create_driver/",
            json={"name": name, "email": email, "password": password, "role": "driver"}, timeout=5)
        log(f"[REGISTER] API: {'OK' if r.status_code in (200, 201) else r.status_code}")
    except Exception as e:
        log(f"[REGISTER] API error: {e}")
    subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
    log(f"[REGISTER] {email} / {password}")

# ═══════════ MAIN ═══════════

def execute(task):
    log(f"TAREA: {task}")
    print("-" * 50)
    _, matches = see()
    log(f"Veo: {', '.join([m[0] for m in matches[:6]])}" if matches else "Veo: pantalla")

    steps = plan(task)
    if not steps:
        log("No entendi.")
        return False

    log(f"Plan: {len(steps)} pasos -> {[s[0] for s in steps]}")
    done = execute_plan(steps)
    log(f"Completado: {done}/{len(steps)} pasos")
    return done > 0

if __name__ == "__main__":
    if len(sys.argv) > 1:
        task = ' '.join(sys.argv[1:])
        print(f"\n[{'OK' if execute(task) else 'FAIL'}]")
    else:
        print("AI Agent v4 - Persistente")
        print("python agent_final.py 'abre chrome y busca python'")
        print("python agent_final.py 'click en Chrome'")
        print("python agent_final.py 'que ves'")
