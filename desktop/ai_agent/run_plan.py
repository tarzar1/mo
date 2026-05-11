import urllib.request, json, time, sys

API = 'http://127.0.0.1:8000'

def cmd(action, **params):
    data = json.dumps({'action': action, 'params': params}).encode()
    r = urllib.request.urlopen(urllib.request.Request(f'{API}/command', data=data, headers={'Content-Type': 'application/json'}), timeout=10)
    return json.loads(r.read().decode())

def ocr():
    r = urllib.request.urlopen(f'{API}/ocr', timeout=10)
    return json.loads(r.read().decode())

# Cargar plan
with open(r'C:\Users\tarzan-rd\Desktop\hola\new_desing\teachings\instalar_gta5_repack\recording.json') as f:
    teaching = json.load(f)

plan = teaching['plan']
print(f"PLAN: {teaching['name']} ({len(plan)} pasos)")

# Ver pantalla
screen = ocr()
print(f"Pantalla: {len(screen['elements'])} elementos OCR")

# Ejecutar
for step in plan:
    action = step.get('action', '')
    desc = step.get('desc', action)
    print(f"\n[Paso {step.get('step', '?')}] {desc}")
    
    if action == 'click_text':
        target = step.get('text', '')
        found = any(target.lower() in el['text'].lower() and el['conf'] > 40 for el in screen.get('elements', []))
        if found:
            r = cmd('click_text', text=target)
            print(f"  Click '{target}': {r.get('status', r.get('ok'))}")
        else:
            # Fallback
            for alt in ['Next', 'Install', 'Finish', 'Siguiente', 'Instalar']:
                if any(alt.lower() in el['text'].lower() for el in screen.get('elements', [])):
                    r = cmd('click_text', text=alt)
                    print(f"  Fallback '{alt}': {r.get('status', r.get('ok'))}")
                    break
    
    elif action == 'run':
        r = cmd('run', app=step['app'])
        print(f"  Run {step['app']}: ok")
    
    elif action == 'wait':
        ms = step.get('ms', 1000)
        if ms > 5000: print(f"  Esperando {ms/1000:.0f}s...")
        time.sleep(ms / 1000)
    
    if action != 'wait':
        time.sleep(1)
        screen = ocr()

print("\nPLAN COMPLETADO")
