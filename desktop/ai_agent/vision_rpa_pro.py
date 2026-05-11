"""Vision RPA Pro v5 — Deteccion visual con overlay + Feedback
- Detecta botones, campos, links, texto con Qwen+OCR
- Overlay visual: cajas de colores por categoria
  Verde = Botones | Azul = Campos | Amarillo = Links | Rojo = Errores
- Sistema de feedback: Premiar/Castigar para enseñar al agente
- Chat de feedback en tiempo real
"""

import os, sys, time, json, threading, io, base64, re, random
import customtkinter as ctk
from PIL import Image, ImageGrab, ImageDraw, ImageFont
import pyautogui

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from desktop_switcher import DesktopSwitcher

pyautogui.FAILSAFE = True
pyautogui.PAUSE = 0.02

# ─── Config ─────────────────────────────────────────
QWEN_URL = "http://192.168.4.30:11434/api/generate"
MODEL_FAST = "qwen2vl:2b"
MODEL_BIG = "qwen2.5vl:7b"
import urllib.request as urllib2

def qwen_ok():
    try: return urllib2.urlopen("http://192.168.4.30:11434/api/tags", timeout=2).status == 200
    except: return False

HAS_QWEN = qwen_ok()

try:
    import pytesseract, cv2, numpy as np
    for p in [r"C:\Program Files\Tesseract-OCR\tesseract.exe",
              r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"]:
        if os.path.exists(p): pytesseract.pytesseract.tesseract_cmd = p; break
    HAS_OCR = True
except: HAS_OCR = False

# ─── Colores por categoria ──────────────────────────
COLORS = {
    "button":   "#00ff44",  # Verde
    "field":    "#4488ff",  # Azul
    "link":     "#ffaa00",  # Amarillo
    "text":     "#aaaaaa",  # Gris
    "error":    "#ff2222",  # Rojo
    "image":    "#ff44ff",  # Magenta
    "dropdown": "#00cccc",  # Cyan
    "checkbox": "#ff8800",  # Naranja
    "unknown":  "#888888",  # Gris oscuro
}

CATEGORY_LABELS = {
    "button": "BOTON",
    "field": "CAMPO",
    "link": "LINK",
    "text": "TEXTO",
    "error": "ERROR",
    "image": "IMAGEN",
    "dropdown": "MENU",
    "checkbox": "CHECK",
}

# ─── Escritorios ────────────────────────────────────
switcher = DesktopSwitcher(total=2)
current_source = 1
feedback_history = []  # [(type, msg, timestamp)]

# ─── Captura ────────────────────────────────────────
def capture_from_source():
    prev = switcher.current
    if prev != current_source:
        switcher.switch_to(current_source)
        time.sleep(0.3)
    img = ImageGrab.grab(all_screens=True)
    if prev != current_source:
        switcher.switch_to(prev)
        time.sleep(0.15)
    return img

def capture_b64():
    img = capture_from_source()
    buf = io.BytesIO()
    img.save(buf, format='JPEG', quality=80)
    return base64.b64encode(buf.getvalue()).decode()

# ─── Qwen ──────────────────────────────────────────
def qwen_ask(prompt, b64=None, model=MODEL_FAST, timeout=20):
    if not HAS_QWEN: return ""
    if b64 is None: b64 = capture_b64()
    payload = {"model": model, "prompt": prompt, "images": [b64],
               "stream": False, "options": {"temperature": 0.1, "num_predict": 300}}
    try:
        data = json.dumps(payload).encode()
        req = urllib2.Request(QWEN_URL, data=data, headers={'Content-Type': 'application/json'})
        r = urllib2.urlopen(req, timeout=timeout)
        return json.loads(r.read().decode()).get("response", "")
    except: return ""

# ─── Deteccion con categorias ──────────────────────
def classify_element(name, position_hint=""):
    """Clasifica un elemento detectado"""
    name_lower = name.lower()
    if any(w in name_lower for w in ['ok','cancel','submit','save','next','back','close',
        'login','sign','register','send','buy','add','delete','edit','create','download',
        'install','play','guest','accept','decline','continue','finish','start','stop']):
        return "button"
    if any(w in name_lower for w in ['search','buscar','email','password','user','name',
        'phone','address','city','zip','card','number','date','birth','month','day','year']):
        return "field"
    if any(w in name_lower for w in ['http','.com','.org','www','link','url']):
        return "link"
    if any(w in name_lower for w in ['error','warning','fail','invalid','not found']):
        return "error"
    if any(w in name_lower for w in ['.png','.jpg','.gif','icon','logo','image','photo']):
        return "image"
    if any(w in name_lower for w in ['select','choose','dropdown','menu','option']):
        return "dropdown"
    if any(w in name_lower for w in ['agree','terms','remember','check','enable']):
        return "checkbox"
    return "text"

def detect_elements_with_categories():
    """Deteccion completa con categorias"""
    results = []
    
    # OCR
    if HAS_OCR:
        img = capture_from_source()
        img_s = img.resize((img.size[0]//3, img.size[1]//3))
        gray = cv2.cvtColor(np.array(img_s), cv2.COLOR_RGB2GRAY)
        data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
        for i in range(len(data['text'])):
            if int(data['conf'][i]) > 55 and len(data['text'][i].strip()) > 2:
                name = data['text'][i].strip()
                results.append({
                    "name": name,
                    "x": (data['left'][i] + data['width'][i]//2) * 3,
                    "y": (data['top'][i] + data['height'][i]//2) * 3,
                    "w": data['width'][i] * 3,
                    "h": data['height'][i] * 3,
                    "category": classify_element(name),
                    "conf": int(data['conf'][i]),
                    "source": "OCR"
                })
    
    # Qwen con categorizacion
    if HAS_QWEN:
        b64 = capture_b64()
        prompt = """Analyze this screenshot. List ALL clickable buttons, input fields, 
links, dropdowns, and checkboxes you see. Format:
CATEGORY: name x,y,w,h
Categories: BUTTON, FIELD, LINK, DROPDOWN, CHECKBOX
One per line. Be thorough - find every element."""
        resp = qwen_ask(prompt, b64, MODEL_FAST, 15)
        for line in resp.split('\n'):
            for cat in ['BUTTON','FIELD','LINK','DROPDOWN','CHECKBOX']:
                if line.upper().startswith(cat):
                    rest = line[len(cat):].strip().lstrip(':').strip()
                    m = re.search(r'(.+?)\s+(\d{2,4})\s*[,;]\s*(\d{2,4})\s*,?\s*(\d{1,4})?\s*,?\s*(\d{1,4})?', rest)
                    if m:
                        name = m.group(1).strip()
                        x, y = int(m.group(2)), int(m.group(3))
                        w = int(m.group(4)) if m.group(4) else 80
                        h = int(m.group(5)) if m.group(5) else 30
                        results.append({
                            "name": name, "x": x, "y": y, "w": w, "h": h,
                            "category": cat.lower(), "conf": 80, "source": "Qwen"
                        })
        # Si Qwen no categorizo bien, usar OCR con categorias
        if not any(r["source"] == "Qwen" for r in results):
            for r in results:
                if r["source"] == "OCR":
                    r["category"] = classify_element(r["name"])
    
    return results[:40]


# ─── Overlay visual ────────────────────────────────
def draw_overlay(img, elements):
    """Dibuja cajas de colores sobre la imagen"""
    overlay = img.copy().convert('RGBA')
    draw = ImageDraw.Draw(overlay)
    
    try:
        font = ImageFont.truetype("consola.ttf", 12)
        font_sm = ImageFont.truetype("consola.ttf", 10)
    except:
        font = ImageFont.load_default()
        font_sm = ImageFont.load_default()
    
    for el in elements:
        cat = el.get("category", "unknown")
        color = COLORS.get(cat, "#888888")
        label = CATEGORY_LABELS.get(cat, cat.upper())
        x, y = el["x"], el["y"]
        w = el.get("w", 80)
        h = el.get("h", 30)
        
        # Rectangulo semi-transparente
        draw.rectangle([x-w//2-2, y-h//2-2, x+w//2+2, y+h//2+2],
                       outline=color, width=2)
        # Fondo de etiqueta
        tag = f"{label}"
        bbox = draw.textbbox((0,0), tag, font=font_sm)
        tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
        draw.rectangle([x-w//2, y-h//2-th-4, x-w//2+tw+4, y-h//2],
                       fill=color)
        draw.text((x-w//2+2, y-h//2-th-2), tag, fill="#000000", font=font_sm)
    
    return overlay.convert('RGB')


# ─── Acciones ──────────────────────────────────────
def human_click(x, y):
    mx, my = pyautogui.position()
    dist = ((x-mx)**2 + (y-my)**2)**0.5
    steps = max(8, int(dist/30))
    for i in range(1, steps+1):
        t = i/steps
        cx = mx + (x-mx)*t + random.uniform(-4,4)*(1-abs(2*t-1))
        cy = my + (y-my)*t + random.uniform(-3,3)*(1-abs(2*t-1))
        pyautogui.moveTo(int(cx), int(cy))
        time.sleep(0.006)
    time.sleep(0.08)
    pyautogui.click()

def execute_plan_step(action, param):
    try:
        if switcher.current != current_source:
            switcher.switch_to(current_source); time.sleep(0.3)
        if action == "open_app":
            pyautogui.hotkey('win', 'r'); time.sleep(0.3)
            pyautogui.write(param, interval=0.03)
            pyautogui.press('enter'); time.sleep(2)
            return True
        elif action == "click_text":
            if HAS_OCR:
                img = capture_from_source()
                img_s = img.resize((img.size[0]//3, img.size[1]//3))
                gray = cv2.cvtColor(np.array(img_s), cv2.COLOR_RGB2GRAY)
                data = pytesseract.image_to_data(gray, output_type=pytesseract.Output.DICT, lang='spa+eng')
                for i in range(len(data['text'])):
                    if param.lower() in data['text'][i].strip().lower() and int(data['conf'][i]) > 40:
                        x = (data['left'][i] + data['width'][i]//2) * 3
                        y = (data['top'][i] + data['height'][i]//2) * 3
                        human_click(x, y); return True
            return False
        elif action == "type":
            pyautogui.write(param, interval=0.03); return True
        elif action == "press":
            pyautogui.press(param); time.sleep(0.3); return True
        elif action == "wait":
            try: time.sleep(float(param))
            except: time.sleep(2)
            return True
    except: return False


# ═══════════════════════════════════════════════════════
# GUI
# ═══════════════════════════════════════════════════════
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")

class VisionGUI:
    def __init__(self):
        self.model = MODEL_FAST if HAS_QWEN else "OCR"
        self.plan = []
        self.plan_step = 0
        self.busy = False
        self.live_feed = False
        self.last_detections = []
        self.show_overlay = True

        self.win = ctk.CTk()
        self.win.title("Vision RPA Pro v5 — Deteccion Visual")
        self.win.geometry("1280x900")
        self.win.attributes('-topmost', True)
        self.win.protocol("WM_DELETE_WINDOW", self._close)
        self._build()
        self._log("v5 listo — Detecta botones, campos, links con overlay")

    def _build(self):
        # ── BARRA ──
        bar = ctk.CTkFrame(self.win, height=36)
        bar.pack(fill="x", side="top")

        ctk.CTkLabel(bar, text="VISION RPA PRO v5", font=("Consolas", 13, "bold"),
                     text_color="#00d97e").pack(side="left", padx=8)

        ctk.CTkLabel(bar, text="Fuente:", font=("Consolas", 10)).pack(side="left", padx=(10,3))
        self.src_var = ctk.StringVar(value="Escritorio 1")
        ctk.CTkOptionMenu(bar, values=["Escritorio 1", "Escritorio 2"],
                         variable=self.src_var, width=105, command=self._on_source).pack(side="left", padx=3)

        ctk.CTkLabel(bar, text="Modelo:", font=("Consolas", 10)).pack(side="left", padx=(8,3))
        models = [MODEL_FAST, MODEL_BIG] if HAS_QWEN else ["OCR"]
        self.model_var = ctk.StringVar(value=self.model)
        ctk.CTkOptionMenu(bar, values=models, variable=self.model_var, width=110,
                         command=self._on_model).pack(side="left", padx=3)

        ctk.CTkButton(bar, text="Analizar", width=75, height=26,
                     command=self._analyze).pack(side="left", padx=5)
        self.live_btn = ctk.CTkButton(bar, text="En Vivo OFF", width=85, height=26,
                                       fg_color="transparent", border_width=1,
                                       command=self._toggle_live)
        self.live_btn.pack(side="left", padx=3)
        self.overlay_btn = ctk.CTkButton(bar, text="Overlay ON", width=85, height=26,
                                          fg_color="#1a3a1a", command=self._toggle_overlay)
        self.overlay_btn.pack(side="left", padx=3)

        # ── MAIN ──
        main = ctk.CTkFrame(self.win)
        main.pack(fill="both", expand=True, padx=4, pady=2)

        # ── COLUMNA IZQUIERDA: Feed con overlay ──
        left = ctk.CTkFrame(main, width=580)
        left.pack(side="left", fill="both", expand=True, padx=2)
        left.pack_propagate(False)

        ctk.CTkLabel(left, text="LO QUE VE LA IA (con overlay de deteccion)",
                     font=("Consolas", 11, "bold"), text_color="#4488ff").pack(pady=(4,0))
        self.feed_lbl = ctk.CTkLabel(left, text="Presiona Analizar", width=560, height=340)
        self.feed_lbl.pack(padx=4, pady=2)

        # Leyenda de colores
        legend = ctk.CTkFrame(left, height=26)
        legend.pack(fill="x", padx=4, pady=(0,4))
        for cat, color in [("BOTON","#00ff44"),("CAMPO","#4488ff"),("LINK","#ffaa00"),
                           ("MENU","#00cccc"),("CHECK","#ff8800"),("ERROR","#ff2222")]:
            lbl = ctk.CTkLabel(legend, text=f"  {cat}  ", font=("Consolas", 9),
                              fg_color=color, text_color="#000", corner_radius=4)
            lbl.pack(side="left", padx=2, pady=2)

        # Panel de analisis
        ctk.CTkLabel(left, text="ANALISIS QWEN", font=("Consolas", 10),
                     text_color="#00d97e").pack(pady=(4,0))
        self.vision_txt = ctk.CTkTextbox(left, font=("Consolas", 9), height=100)
        self.vision_txt.pack(fill="x", padx=4, pady=2)

        # ── COLUMNA DERECHA: Controles ──
        right = ctk.CTkFrame(main, width=420)
        right.pack(side="right", fill="both", padx=2)
        right.pack_propagate(False)

        # FEEDBACK
        ctk.CTkLabel(right, text="ENSEÑAR AL AGENTE", font=("Consolas", 11, "bold"),
                     text_color="#ffaa00").pack(pady=(4,0))

        fb_frame = ctk.CTkFrame(right)
        fb_frame.pack(fill="x", padx=4, pady=2)

        self.fb_entry = ctk.CTkEntry(fb_frame, placeholder_text="Feedback: 'el boton azul es el correcto'...",
                                      font=("Consolas", 10))
        self.fb_entry.pack(side="left", fill="x", expand=True, padx=2, pady=2)
        self.fb_entry.bind("<Return>", lambda e: self._send_feedback())

        ctk.CTkButton(fb_frame, text="Enviar", width=55, height=26,
                     command=self._send_feedback).pack(side="right", padx=2, pady=2)

        # Botones Premiar / Castigar
        rw_frame = ctk.CTkFrame(right)
        rw_frame.pack(fill="x", padx=4, pady=2)

        self.reward_btn = ctk.CTkButton(rw_frame, text="PREMIAR", width=120, height=36,
                                         fg_color="#005500", hover_color="#007700",
                                         font=("Consolas", 12, "bold"),
                                         command=lambda: self._feedback("reward"))
        self.reward_btn.pack(side="left", padx=5, pady=4)

        self.punish_btn = ctk.CTkButton(rw_frame, text="CASTIGAR", width=120, height=36,
                                         fg_color="#550000", hover_color="#770000",
                                         font=("Consolas", 12, "bold"),
                                         command=lambda: self._feedback("punish"))
        self.punish_btn.pack(side="right", padx=5, pady=4)

        # Historial de feedback
        ctk.CTkLabel(right, text="HISTORIAL FEEDBACK", font=("Consolas", 10),
                     text_color="#888").pack(pady=(6,0))
        self.fb_history = ctk.CTkTextbox(right, font=("Consolas", 9), height=80)
        self.fb_history.pack(fill="x", padx=4, pady=2)

        # Elementos detectados
        ctk.CTkLabel(right, text="ELEMENTOS DETECTADOS", font=("Consolas", 10),
                     text_color="#ffaa00").pack(pady=(4,0))
        self.el_frame = ctk.CTkScrollableFrame(right, height=150)
        self.el_frame.pack(fill="x", padx=4, pady=2)

        # Plan
        ctk.CTkLabel(right, text="PLAN", font=("Consolas", 10),
                     text_color="#00d97e").pack(pady=(4,0))
        self.plan_box = ctk.CTkTextbox(right, font=("Consolas", 9), height=70)
        self.plan_box.pack(fill="x", padx=4, pady=2)

        # LOG
        ctk.CTkLabel(right, text="LOG", font=("Consolas", 10)).pack(pady=(4,0))
        self.log_box = ctk.CTkTextbox(right, font=("Consolas", 9), height=70)
        self.log_box.pack(fill="both", expand=True, padx=4, pady=2)

        # ── BOTTOM ──
        bot = ctk.CTkFrame(self.win, height=38)
        bot.pack(fill="x", side="bottom", padx=4, pady=3)

        self.task_entry = ctk.CTkEntry(bot,
            placeholder_text="Tarea: busca teclado mecanico en amazon...",
            font=("Consolas", 11))
        self.task_entry.pack(side="left", fill="x", expand=True, padx=4, pady=2)
        self.task_entry.bind("<Return>", lambda e: self._run_task())

        ctk.CTkButton(bot, text="EJECUTAR SOLO", width=120,
                     fg_color="#8B0000", command=self._run_task).pack(side="right", padx=3)

        self.st_bar = ctk.CTkLabel(self.win, text="Listo", font=("Consolas", 9))
        self.st_bar.pack(fill="x", side="bottom")

    # ─── Helpers ──────────────────────────────────
    def _log(self, msg):
        t = time.strftime('%H:%M:%S')
        self.log_box.insert("end", f"[{t}] {msg}\n")
        self.log_box.see("end")
        self.st_bar.configure(text=msg[:90])

    def _on_model(self, c): self.model = c; self._log(f"Modelo: {c}")
    def _toggle_overlay(self):
        self.show_overlay = not self.show_overlay
        self.overlay_btn.configure(text=f"Overlay {'ON' if self.show_overlay else 'OFF'}",
                                   fg_color="#1a3a1a" if self.show_overlay else "transparent")

    def _on_source(self, choice):
        global current_source
        current_source = 1 if "1" in choice else 2
        self._log(f"Fuente: {choice}")

    # ─── Feedback ─────────────────────────────────
    def _send_feedback(self):
        msg = self.fb_entry.get().strip()
        if not msg: return
        self.fb_entry.delete(0, "end")
        self._feedback("message", msg)

    def _feedback(self, ftype, msg=""):
        global feedback_history
        t = time.strftime('%H:%M:%S')
        emoji = {"reward":"✅ PREMIO","punish":"❌ CASTIGO","message":"💬"}.get(ftype,"")
        entry = f"[{t}] {emoji} {msg}"
        feedback_history.append((ftype, msg, t))
        self.fb_history.insert("end", entry + "\n")
        self.fb_history.see("end")
        if ftype == "reward":
            self._log("✅ PREMIADO!"); self.reward_btn.configure(fg_color="#008800")
            self.win.after(500, lambda: self.reward_btn.configure(fg_color="#005500"))
        elif ftype == "punish":
            self._log("❌ CASTIGADO!"); self.punish_btn.configure(fg_color="#880000")
            self.win.after(500, lambda: self.punish_btn.configure(fg_color="#550000"))
        else:
            self._log(f"Feedback: {msg[:60]}")

    # ─── En Vivo ──────────────────────────────────
    def _toggle_live(self):
        self.live_feed = not self.live_feed
        self.live_btn.configure(text=f"En Vivo {'ON' if self.live_feed else 'OFF'}",
                                fg_color="#1a3a1a" if self.live_feed else "transparent")
        if self.live_feed:
            self._log("Feed en vivo activado")
            threading.Thread(target=self._live_loop, daemon=True).start()

    def _live_loop(self):
        while self.live_feed:
            try:
                img = capture_from_source()
                if self.show_overlay and self.last_detections:
                    img = draw_overlay(img, self.last_detections)
                w = 560
                h = int(w * img.size[1] / img.size[0])
                preview = img.resize((w, h))
                ctk_img = ctk.CTkImage(light_image=preview, dark_image=preview, size=(w, min(h,340)))
                self.feed_lbl.configure(image=ctk_img, text="")
            except: pass
            time.sleep(0.35)

    # ─── Analizar ────────────────────────────────
    def _analyze(self):
        if self.busy: return
        self.busy = True
        self._log(f"Analizando Esc {current_source}...")
        threading.Thread(target=self._do_analyze, daemon=True).start()

    def _do_analyze(self):
        t0 = time.time()
        dets = detect_elements_with_categories()
        t1 = time.time()
        self.last_detections = dets

        # Preview con overlay
        img = capture_from_source()
        if self.show_overlay:
            img_overlay = draw_overlay(img, dets)
        else:
            img_overlay = img
        w = 560
        h = int(w * img_overlay.size[1] / img_overlay.size[0])
        preview = img_overlay.resize((w, h))
        ctk_img = ctk.CTkImage(light_image=preview, dark_image=preview, size=(w, min(h,340)))
        self.feed_lbl.configure(image=ctk_img, text="")

        # Actualizar lista de elementos
        for ww in self.el_frame.winfo_children():
            ww.destroy()

        # Agrupar por categoria
        cats = {}
        for d in dets:
            cat = d.get("category", "unknown")
            cats.setdefault(cat, []).append(d)

        for cat, items in cats.items():
            color = COLORS.get(cat, "#888")
            label = CATEGORY_LABELS.get(cat, cat.upper())
            header = ctk.CTkFrame(self.el_frame)
            header.pack(fill="x", pady=(4,1))
            ctk.CTkLabel(header, text=f"  {label} ({len(items)})", font=("Consolas", 10, "bold"),
                        fg_color=color, text_color="#000", corner_radius=4).pack(fill="x", padx=2)

            for d in items[:8]:
                row = ctk.CTkFrame(self.el_frame)
                row.pack(fill="x", pady=1)
                ctk.CTkLabel(row, text=d['name'][:22], font=("Consolas", 9)).pack(side="left", padx=2)
                ctk.CTkLabel(row, text=f"({d['x']},{d['y']})", font=("Consolas", 8),
                            text_color="#888").pack(side="left", padx=1)
                ctk.CTkButton(row, text="Click", width=40, height=18,
                             command=lambda xx=d['x'],yy=d['y']: self._do_click(xx,yy)
                             ).pack(side="right", padx=2)

        # Stats
        stats = []
        for cat in ["button","field","link","dropdown","checkbox","error","text"]:
            c = sum(1 for d in dets if d.get("category") == cat)
            if c > 0: stats.append(f"{CATEGORY_LABELS.get(cat,cat)}:{c}")
        det_text = f"{len(dets)} elementos en {t1-t0:.1f}s | " + " ".join(stats)

        if HAS_QWEN:
            b64 = capture_b64()
            desc = qwen_ask("Describe brevemente la pantalla en español.", b64, MODEL_FAST, 10)
            det_text += f"\n\n{desc[:300]}"

        self.vision_txt.delete("1.0", "end")
        self.vision_txt.insert("1.0", det_text)
        self._log(f"{len(dets)} elementos ({t1-t0:.1f}s)")
        self.busy = False

    def _do_click(self, x, y):
        self._log(f"Click ({x},{y})")
        threading.Thread(target=human_click, args=(x,y), daemon=True).start()

    # ─── Tarea Autonoma ──────────────────────────
    def _run_task(self):
        task = self.task_entry.get().strip()
        if not task or self.busy: return
        self.task_entry.delete(0, "end")
        self.busy = True
        self._log(f"AGENTE: {task}")
        self.plan_box.delete("1.0", "end")
        self.plan_box.insert("end", f"Planeando: {task}\n")
        threading.Thread(target=self._do_task, args=(task,), daemon=True).start()

    def _do_task(self, task):
        # Preview
        img = capture_from_source()
        w = 560; h = int(w * img.size[1] / img.size[0])
        preview = img.resize((w, h))
        ctk_img = ctk.CTkImage(light_image=preview, dark_image=preview, size=(w, min(h,340)))
        self.feed_lbl.configure(image=ctk_img, text="")

        self._log("Planeando con Qwen 7B...")
        b64 = capture_b64()
        resp = qwen_ask(f"TASK: {task}\nLook at screenshot. Steps: open_app N | click_text X | type X | press K | wait S\nReply only commands.", b64, MODEL_BIG, 35)

        self.plan = []
        self.plan_step = 0
        self.plan_box.delete("1.0", "end")
        self.plan_box.insert("end", f"PLAN: {task}\n" + "-"*25 + "\n")
        for line in resp.split('\n'):
            line = line.strip()
            if not line or line.startswith('#'): continue
            parts = line.split(maxsplit=1)
            if len(parts) >= 1:
                action = parts[0].lower().strip()
                param = parts[1].strip().strip('"').strip("'") if len(parts) > 1 else ""
                if action in ('open_app','click_text','type','press','wait'):
                    self.plan.append((action, param))
                    self.plan_box.insert("end", f"  {len(self.plan)}. {action} {param[:40]}\n")

        if not self.plan:
            self._log("Plan vacio"); self.busy = False; return

        self._log(f"Plan: {len(self.plan)} pasos")
        for i, (action, param) in enumerate(self.plan):
            self.plan_step = i + 1
            self.plan_box.insert("end", f"\n>> {i+1}/{len(self.plan)} {action} {param[:30]}\n")
            self.plan_box.see("end")
            t0 = time.time(); ok = execute_plan_step(action, param); t1 = time.time()
            self.plan_box.insert("end", f"   {'OK' if ok else 'FAIL'} ({t1-t0:.1f}s)\n")
            self.plan_box.see("end")
            self._log(f"[{i+1}/{len(self.plan)}] {action} {param[:20]} {'OK' if ok else 'FAIL'}")

        self.plan_box.insert("end", "\nCOMPLETADO\n"); self.plan_box.see("end")
        self._log("AGENTE COMPLETADO"); self.busy = False

    def _close(self):
        self.live_feed = False
        self.win.attributes('-topmost', False)
        self.win.destroy()


if __name__ == '__main__':
    app = VisionGUI()
    app.win.mainloop()
