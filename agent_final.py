"""AI Agent Final - Controla el PC con lenguaje natural
   Tareas: ver, abrir, buscar, escribir, presionar, registrar, login"""

import os, sys, time, re, json, subprocess
import keyboard, pyautogui, pytesseract, cv2, numpy as np
from PIL import ImageGrab

for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
          r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
    if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break

pyautogui.FAILSAFE = True
API = "http://192.168.4.23:8000"

def log(msg):
    print(f"  [{time.strftime('%H:%M:%S')}] {msg}")

def see():
    """Lee el escritorio 2: cambia, captura, OCR, vuelve"""
    log("Cambiando a escritorio 2...")
    keyboard.press('win'); keyboard.press('ctrl'); keyboard.press('right')
    time.sleep(0.1)
    keyboard.release('right'); keyboard.release('ctrl'); keyboard.release('win')
    time.sleep(0.6)

    img = ImageGrab.grab(all_screens=True)
    gray = cv2.cvtColor(np.array(img), cv2.COLOR_RGB2GRAY)
    gray = cv2.resize(gray, (0,0), fx=0.5, fy=0.5)
    text = pytesseract.image_to_string(gray)
    data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT)

    matches = []
    for i in range(len(data['text'])):
        try:
            conf = int(data['conf'][i])
            word = data['text'][i].strip()
            if conf > 40 and len(word) > 2:
                x = (data['left'][i] + data['width'][i]//2) * 2
                y = (data['top'][i] + data['height'][i]//2) * 2
                matches.append((word, x, y, conf))
        except: pass

    # Volver al escritorio 1
    keyboard.press('win'); keyboard.press('ctrl'); keyboard.press('left')
    time.sleep(0.1)
    keyboard.release('left'); keyboard.release('ctrl'); keyboard.release('win')
    time.sleep(0.5)

    return text, matches, img

def act(fn):
    """Ejecuta accion en el escritorio 2, luego vuelve al 1"""
    keyboard.press('win'); keyboard.press('ctrl'); keyboard.press('right')
    time.sleep(0.1)
    keyboard.release('right'); keyboard.release('ctrl'); keyboard.release('win')
    time.sleep(0.4)
    
    result = fn()
    time.sleep(0.2)
    
    keyboard.press('win'); keyboard.press('ctrl'); keyboard.press('left')
    time.sleep(0.1)
    keyboard.release('left'); keyboard.release('ctrl'); keyboard.release('win')
    time.sleep(0.4)
    return result

def click_word(word, matches=None):
    """Click en palabra detectada por OCR"""
    if matches is None:
        _, matches, _ = see()
    
    for m in matches:
        if word.lower() in m[0].lower():
            def do_click(x=m[1], y=m[2]):
                pyautogui.click(x, y)
                return f"Click en '{m[0]}' ({x},{y})"
            result = act(do_click)
            log(result)
            return True
    
    log(f"No encontre '{word}'")
    return False

def type_text(text):
    def do_type(t=text):
        pyautogui.write(t, interval=0.03)
        return f"Escrito: '{t}'"
    result = act(do_type)
    log(result)

def press(key):
    def do_press(k=key):
        pyautogui.press(k)
        return f"Tecla: '{k}'"
    result = act(do_press)
    log(result)

def execute(task):
    """Interpreta y ejecuta una tarea"""
    task_lower = task.lower()
    log(f"TAREA: {task}")
    print("-" * 50)

    # Ver el escritorio 2
    text, matches, img = see()
    visible = [w for w, x, y, c in matches[:15]]
    log(f"Veo: {', '.join(visible[:10])}" if visible else "Veo: (escritorio vacio)")
    
    for line in text.split('\n')[:5]:
        if line.strip():
            log(f"  OCR: {line.strip()[:100]}")

    # ─── DETECTAR TIPO DE TAREA ──────────────────────

    actions_done = []

    # 1. Ver / describir
    if any(w in task_lower for w in ['ver', 've', 'que ves', 'describe', 'que hay', 'muestra']):
        log("=== LO QUE VEO ===")
        text, _, _ = see()
        lines = [l for l in text.split('\n') if l.strip()]
        for l in lines[:15]:
            print(f"  {l.strip()}")
        actions_done.append("ver")
        return True

    # 2. Abrir app (y posiblemente buscar)
    open_match = None
    for w in ['abrir', 'abre', 'open', 'lanza']:
        if w in task_lower:
            open_match = w
            break

    if open_match:
        app = task_lower.replace(open_match, '').strip()
        # Extraer app: lo que esta antes de "y busca" o "y buscar"
        for sep in [' y busca', ' y buscar', ', busca', ', buscar']:
            if sep in app:
                app = app.split(sep)[0].strip()
                break
        log(f"Plan: Abrir '{app}' con Win+R")
        def open_app(a=app):
            pyautogui.hotkey('win', 'r')
            time.sleep(0.3)
            pyautogui.write(a, interval=0.03)
            pyautogui.press('enter')
            return f"Win+R + '{a}' + Enter"
        result = act(open_app)
        log(result)
        time.sleep(3)
        actions_done.append("open")

    # 3. Buscar (independiente, puede combinarse con abrir)
    search_match = None
    for w in ['buscar', 'busca', 'search', 'google']:
        if w in task_lower:
            search_match = w
            break

    if search_match:
        # Simplificacion: tomar todo despues del keyword de busqueda
        query = ""
        for kw in ['buscar ', 'busca ', 'search ', 'google ']:
            if kw in task_lower:
                query = task_lower.split(kw, 1)[1].strip()
                break

        # Si ya se abrio chrome, solo escribir la busqueda
        if actions_done and 'open' in actions_done:
            log(f"Buscando '{query}' en el navegador abierto")
            type_text(query)
            press('enter')
        else:
            log(f"Plan: Abrir Chrome y buscar '{query}'")
            def search(q=query):
                pyautogui.hotkey('win', 'r')
                time.sleep(0.3)
                pyautogui.write('chrome', interval=0.03)
                pyautogui.press('enter')
                time.sleep(3)
                if q:
                    pyautogui.write(q, interval=0.03)
                    pyautogui.press('enter')
                return f"Chrome + buscar '{q}'"
            result = act(search(q=query))
            log(result)
        actions_done.append("search")

    # Si ya se ejecutaron acciones, exito
    if actions_done:
        log(f"Acciones completadas: {', '.join(actions_done)}")
        return True

    # 4. Escribir
    if any(w in task_lower for w in ['escribir', 'escribe', 'type', 'escribe']):
        text_to_type = task_lower
        for w in ['escribir', 'escribe', 'type', 'escribe', 'texto']:
            text_to_type = text_to_type.replace(w, '').strip()
        log(f"Plan: Escribir '{text_to_type}'")
        type_text(text_to_type)
        return True

    # 5. Presionar tecla
    if any(w in task_lower for w in ['presionar', 'presiona', 'pulsa', 'tecla', 'enter', 'tab', 'esc', 'espacio']):
        key = 'enter'
        for k in ['enter', 'tab', 'esc', 'espacio', 'space', 'backspace', 'f5', 'f11']:
            if k in task_lower:
                key = k
                break
        log(f"Plan: Presionar '{key}'")
        press(key)
        return True

    # 6. Registrar en CommuteShare
    if any(w in task_lower for w in ['registr', 'crear cuenta']):
        email = re.search(r'[\w.]+@[\w.]+', task)
        email = email.group(0) if email else f"user{int(time.time())%10000}@test.com"
        pass_match = re.search(r'pass(?:word)?[:\s]*(\S+)', task, re.IGNORECASE)
        password = pass_match.group(1) if pass_match else "123456"
        name_match = re.search(r'(?:nombre|name|como)[:\s]*(\w+)', task, re.IGNORECASE)
        name = name_match.group(1) if name_match else "User"

        log(f"Plan: Registrar {email}")
        
        # API registro directo
        import requests
        try:
            r = requests.post(f"{API}/Create_driver/",
                json={"name": name, "email": email, "password": password, "role": "driver"}, timeout=5)
            if r.status_code in (200, 201):
                log(f"API: {email} registrado!")
            else:
                log(f"API: {r.status_code}")
        except Exception as e:
            log(f"API error: {e}")

        # Emulador
        subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True)
        time.sleep(4)
        log("App abierta en emulador")
        return True

    # No reconocido
    log("No reconozco la tarea. Intentos:")
    log("  'que ves'  'abre chrome'  'busca python'")
    log("  'registra a test@test.com'  'presiona enter'")
    return False


if __name__ == "__main__":
    if len(sys.argv) > 1:
        task = ' '.join(sys.argv[1:])
    else:
        print("AI Agent - Listo para tareas.")
        print("Ej: python agent_final.py 'abre chrome y busca steam'")
        sys.exit(1)

    ok = execute(task)
    print(f"\n{'[OK]' if ok else '[FAIL]'} Tarea completada")
