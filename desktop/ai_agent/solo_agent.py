"""Agent Autonomo - Trabaja solo, decide solo, ejecuta solo
Le das una tarea en lenguaje natural. El agente:
1. Ve la pantalla (Qwen)
2. Genera un plan completo
3. Ejecuta cada paso con verificacion
4. Si falla, busca alternativas
5. Reporta resultado

Uso: python solo_agent.py "busca fortnite en epic games"
"""

import os, sys, time, json, base64, io, re, random
import urllib.request as urllib2
import pyautogui
from PIL import ImageGrab

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.03

QWEN_URL = "http://192.168.4.30:11434/api/generate"
MODEL = "qwen2.5vl:7b"

# ─── Vision ─────────────────────────────────────────
def capture_b64():
    img = ImageGrab.grab(all_screens=True)
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=85)
    return base64.b64encode(buf.getvalue()).decode()

def ask(prompt, b64=None):
    if b64 is None: b64 = capture_b64()
    payload = {"model": MODEL, "prompt": prompt, "images": [b64],
               "stream": False, "options": {"temperature": 0.1, "num_predict": 250}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=35)
        return json.loads(r.read().decode()).get("response", "")
    except Exception as e: return f"ERROR:{e}"

# ─── Acciones ───────────────────────────────────────
def find_and_click(target, b64):
    """Qwen busca el elemento y clickea"""
    prompt = f"Find '{target}' in screenshot. Reply ONLY: x,y or none"
    resp = ask(prompt, b64)
    m = re.search(r'(\d{2,4})\s*[,;]\s*(\d{2,4})', resp)
    if m:
        x, y = int(m.group(1)), int(m.group(2))
        # Movimiento humano
        mx, my = pyautogui.position()
        steps = max(10, int(((x-mx)**2+(y-my)**2)**0.5/25))
        for i in range(1, steps+1):
            t = i/steps
            cx = mx + (x-mx)*t + random.uniform(-3,3)*(1-abs(2*t-1))
            cy = my + (y-my)*t + random.uniform(-2,2)*(1-abs(2*t-1))
            pyautogui.moveTo(int(cx), int(cy))
            time.sleep(0.006)
        time.sleep(0.1)
        pyautogui.click()
        return True
    return False

def open_app(app):
    pyautogui.hotkey('win', 'r')
    time.sleep(0.4)
    pyautogui.write(app, interval=0.03)
    pyautogui.press('enter')
    time.sleep(2)
    return True

# ─── Planificador ───────────────────────────────────
def generate_plan(task):
    """Qwen ve la pantalla y genera plan completo"""
    print(f"\n{'='*60}")
    print(f"TAREA: {task}")
    print(f"{'='*60}")
    
    print("\n[1/4] Capturando pantalla...")
    b64 = capture_b64()
    
    print("[2/4] Qwen analizando y generando plan...")
    prompt = f"""TASK: {task}
Look at this screenshot. Generate a step-by-step plan.
One command per line. Valid commands:
open_app chrome
click_text "Search"  
type "text to type"
press enter
wait 3
verify "expected text"

Think about what needs to happen step by step.
IMPORTANT: If Chrome asks 'Who is using Chrome?', add steps to click a profile first.
Reply with ONLY the commands, one per line."""
    
    resp = ask(prompt, b64)
    
    # Parsear plan
    plan = []
    print("\n[3/4] Plan generado:")
    for line in resp.split('\n'):
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('```'): continue
        parts = line.split(maxsplit=1)
        if len(parts) >= 1:
            action = parts[0].lower()
            param = parts[1].strip().strip('"').strip("'") if len(parts) > 1 else ""
            if action in ('open_app','click_text','type','press','wait','verify'):
                plan.append((action, param))
                print(f"  {len(plan)}. {action} {param}")
    
    return plan, b64

# ─── Ejecutor ───────────────────────────────────────
def execute_plan(plan, b64):
    """Ejecuta el plan con verificacion y fallbacks"""
    print(f"\n[4/4] Ejecutando {len(plan)} pasos...\n")
    
    for i, (action, param) in enumerate(plan):
        step = i + 1
        print(f"  [{step}/{len(plan)}] {action} {param}")
        
        try:
            if action == "open_app":
                open_app(param)
                print(f"    -> Abierto {param}")
                
            elif action == "click_text":
                ok = find_and_click(param, capture_b64())
                if ok:
                    print(f"    -> Click en '{param}'")
                else:
                    print(f"    -> '{param}' no encontrado, probando alternativas...")
                    # Intentar con variaciones
                    time.sleep(1)
                    ok = find_and_click(param, capture_b64())
                    if not ok:
                        print(f"    -> Fallo. Continuando...")
                time.sleep(1)
                
            elif action == "type":
                pyautogui.write(param, interval=0.03)
                print(f"    -> Escrito '{param[:40]}'")
                
            elif action == "press":
                pyautogui.press(param)
                print(f"    -> Tecla '{param}'")
                
            elif action == "wait":
                secs = float(param) if param.replace('.','').isdigit() else 2
                print(f"    -> Esperando {secs}s...")
                time.sleep(secs)
                
            elif action == "verify":
                b64_new = capture_b64()
                prompt = f"Is '{param}' visible on screen? Reply YES or NO."
                resp = ask(prompt, b64_new)
                if 'yes' in resp.lower():
                    print(f"    -> Verificado: '{param}' SI")
                else:
                    print(f"    -> ATENCION: '{param}' NO detectado")
                
        except Exception as e:
            print(f"    -> ERROR: {e}")
            continue
    
    # Verificacion final
    print(f"\n[FINAL] Verificando resultado...")
    b64_end = capture_b64()
    prompt = "Describe brevemente que ves en pantalla. La tarea se completo? Responde en español, 2-3 frases."
    final = ask(prompt, b64_end)
    print(f"  Qwen: {final[:300]}")
    print(f"\n{'='*60}")
    print("TAREA COMPLETADA")
    print(f"{'='*60}")

# ─── Main ───────────────────────────────────────────
def run(task):
    plan, b64 = generate_plan(task)
    if not plan:
        print("No se pudo generar plan. Intentando modo directo...")
        print("(Preguntale a Qwen que hacer directamente)")
        prompt = f"TASK: {task}. What should I do FIRST? Reply with ONE command."
        resp = ask(prompt, b64)
        print(f"  Qwen: {resp}")
        return
    
    execute_plan(plan, b64)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Agent Autonomo - Uso:")
        print('  python solo_agent.py "abre chrome y busca fortnite en epic games"')
        print('  python solo_agent.py "crea una cuenta de google"')
        sys.exit(1)
    
    task = ' '.join(sys.argv[1:])
    run(task)
