"""Vision Brain - Integracion Qwen2.5-VL-7B
Conecta el agente con el modelo de vision en 192.168.4.30
Para que el agente "vea" realmente la pantalla, no solo OCR.

Uso:
  python vision_brain.py "que ves en pantalla?"
"""

import sys, os, io, json, base64, time
import urllib.request
from PIL import ImageGrab

OLLAMA_URL = "http://192.168.4.30:11434/api/generate"
MODEL = "qwen2.5vl:7b"


def capture_base64():
    """Captura pantalla y la convierte a base64 para Qwen"""
    img = ImageGrab.grab(all_screens=True)
    # Reducir para velocidad
    w, h = img.size
    img = img.resize((w//2, h//2))
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=60)
    return base64.b64encode(buf.getvalue()).decode()


def ask_qwen(prompt, image_b64=None):
    """Pregunta a Qwen2.5-VL con una imagen opcional"""
    if image_b64 is None:
        image_b64 = capture_base64()

    payload = {
        "model": MODEL,
        "prompt": prompt,
        "images": [image_b64],
        "stream": False,
        "options": {
            "temperature": 0.1,
            "num_predict": 500
        }
    }

    try:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(OLLAMA_URL, data=data,
                                     headers={'Content-Type': 'application/json'})
        r = urllib.request.urlopen(req, timeout=30)
        result = json.loads(r.read().decode())
        return result.get("response", "")
    except Exception as e:
        return f"ERROR: {e}"


# ─── Prompts especializados ──────────────────────────

def see_screen():
    """Describe lo que hay en pantalla"""
    prompt = """Describe what you see on this screenshot. Be specific:
- What applications are open?
- What UI elements are visible? (buttons, input fields, dropdowns, labels)
- Is there any error message, loading state, or dialog?
- What is the user currently doing?
Reply in Spanish, concise."""
    return ask_qwen(prompt)


def find_element(target):
    """Encuentra un elemento UI en pantalla y devuelve coordenadas"""
    prompt = f"""Find the UI element '{target}' in this screenshot.
Reply ONLY with JSON format: {{"found": true/false, "x": number, "y": number, "description": "brief"}}
x and y should be approximate pixel coordinates of the center of the element.
If not found, return {{"found": false}}."""
    response = ask_qwen(prompt)
    # Intentar parsear JSON
    try:
        # Extraer JSON de la respuesta
        import re
        match = re.search(r'\{[^}]+\}', response)
        if match:
            return json.loads(match.group())
    except:
        pass
    return {"found": False, "response": response}


def analyze_form():
    """Analiza un formulario en pantalla y devuelve sus campos"""
    prompt = """Analyze any form visible in this screenshot.
Reply with JSON format: {
  "form_detected": true/false,
  "title": "form title if visible",
  "fields": [
    {"label": "field name", "type": "text/email/password/dropdown/checkbox/button", "x": number, "y": number, "required": true/false}
  ],
  "submit_button": {"text": "button text", "x": number, "y": number}
}
x,y are approximate pixel coordinates. Reply ONLY valid JSON, no other text."""
    response = ask_qwen(prompt)
    try:
        import re
        match = re.search(r'\{[\s\S]*\}', response)
        if match:
            return json.loads(match.group())
    except:
        pass
    return {"form_detected": False, "response": response}


def decide_action(task, previous_context=""):
    """Decide la proxima accion basado en la pantalla y la tarea"""
    prompt = f"""TASK: {task}
{previous_context}

Look at this screenshot. What should be the NEXT action to complete the task?
Choose ONE action from:
- click_text "element_name" (click on a UI element)
- click x y (click at specific coordinates)
- type "text" (type text)
- press "key" (press a key like enter, tab, escape)
- wait N (wait N milliseconds)
- done (task is complete)

Reply with ONLY: ACTION_NAME "value" (no other text, one action only)
Example: click_text "Next"
Example: type "alextorres@gmail.com"
Example: press "enter"
Example: done"""
    return ask_qwen(prompt)


# ─── CLI ────────────────────────────────────────────
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Vision Brain - Qwen2.5-VL-7B")
        print("  python vision_brain.py see")
        print("  python vision_brain.py find 'Next'")
        print("  python vision_brain.py form")
        print("  python vision_brain.py decide 'crea cuenta google'")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'see':
        print("Analizando pantalla...")
        print(see_screen())

    elif cmd == 'find':
        target = sys.argv[2] if len(sys.argv) > 2 else "Next"
        print(f"Buscando '{target}'...")
        result = find_element(target)
        print(json.dumps(result, indent=2))

    elif cmd == 'form':
        print("Analizando formulario...")
        result = analyze_form()
        print(json.dumps(result, indent=2))

    elif cmd == 'decide':
        task = ' '.join(sys.argv[2:]) if len(sys.argv) > 2 else "complete the task"
        print(f"Decidiendo accion para: {task}")
        print(decide_action(task))

    else:
        result = ask_qwen(' '.join(sys.argv[1:]))
        print(result)
