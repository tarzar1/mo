"""Agente con Vision Artificial - OpenCV + ADB + OCR
Ve la pantalla del emulador Android y navega visualmente."""

import cv2
import numpy as np
import subprocess
import time
import os
import json

class AgentVision:
    def __init__(self, name, device="emulator-5554", screenshots_dir="test/logs"):
        self.name = name
        self.device = device
        self.screenshots_dir = screenshots_dir
        self.last_screen = None
        self.step = 0
        self.run_id = str(int(time.time()))
        os.makedirs(screenshots_dir, exist_ok=True)

    def log(self, msg):
        print(f"[{self.name}] {msg}")

    def screenshot(self):
        raw = subprocess.run("adb exec-out screencap -p", shell=True,
                           capture_output=True).stdout
        self.last_screen = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR)
        self.step += 1
        # Save debug screenshot
        path = f"{self.screenshots_dir}/{self.name}_{self.run_id}_{self.step}.png"
        cv2.imwrite(path, self.last_screen)
        return self.last_screen

    def find_text(self, text, threshold=60):
        """Busca texto usando OCR (fallback: template matching)"""
        try:
            import pytesseract
            gray = cv2.cvtColor(self.last_screen, cv2.COLOR_BGR2GRAY)
            _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            data = pytesseract.image_to_data(binary, output_type=pytesseract.Output.DICT)
            for i in range(len(data['text'])):
                conf = int(data['conf'][i])
                word = data['text'][i].strip()
                if conf > threshold and word.lower() == text.lower():
                    x, y, w, h = data['left'][i], data['top'][i], data['width'][i], data['height'][i]
                    return (x + w//2, y + h//2)
            return None
        except:
            # Fallback: template matching con nombre de archivo
            tpath = f"test/templates/{text.lower().replace(' ', '_')}.png"
            return self.find_template(tpath)

    def find_text_contains(self, substring, threshold=50):
        """Busca texto con OCR. Sin Tesseract -> busca template."""
        try:
            import pytesseract
            gray = cv2.cvtColor(self.last_screen, cv2.COLOR_BGR2GRAY)
            _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            data = pytesseract.image_to_data(binary, output_type=pytesseract.Output.DICT)
            results = []
            for i in range(len(data['text'])):
                conf = int(data['conf'][i])
                word = data['text'][i].strip().lower()
                if conf > threshold and substring.lower() in word:
                    x, y, w, h = data['left'][i], data['top'][i], data['width'][i], data['height'][i]
                    results.append((x + w//2, y + h//2, word))
            return results
        except:
            # Fallback > template
            tpath = f"test/templates/{substring.lower().replace(' ', '_')}.png"
            r = self.find_template(tpath)
            if r:
                return [(r[0], r[1], substring)]
            return []

    def find_template(self, template_path, threshold=0.7):
        """Busca imagen por template matching"""
        if not os.path.exists(template_path):
            return None
        template = cv2.imread(template_path)
        if template is None:
            return None
        res = cv2.matchTemplate(self.last_screen, template, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(res)
        if max_val >= threshold:
            cx = max_loc[0] + template.shape[1] // 2
            cy = max_loc[1] + template.shape[0] // 2
            return (cx, cy)
        return None

    def click(self, x, y=None):
        """Click en coordenadas. Si solo se pasa tupla, desempaqueta."""
        if y is None and isinstance(x, (tuple, list)):
            x, y = x[0], x[1]
        self.log(f"Click en ({x}, {y})")
        subprocess.run(f"adb shell input tap {x} {y}", shell=True)
        time.sleep(0.3)

    def click_text(self, text):
        """Busca texto y hace click"""
        self.screenshot()
        pos = self.find_text(text)
        if pos:
            self.click(pos)
            time.sleep(0.5)
            return True
        self.log(f"No encontrado: '{text}'")
        return False

    def click_contains(self, substring):
        """Busca texto parcial y hace click en la primera coincidencia"""
        self.screenshot()
        results = self.find_text_contains(substring)
        if results:
            x, y, word = results[0]
            self.log(f"Click en '{word}' ({x},{y})")
            self.click(x, y)
            time.sleep(0.5)
            return True
        return False

    def type_text(self, text):
        """Escribe texto via ADB (sin espacios por limitacion ADB)"""
        # ADB no maneja bien espacios y caracteres especiales
        # Usamos input keyevent para espacios
        self.log(f"Escribiendo: '{text}'")
        for ch in text:
            if ch == ' ':
                subprocess.run("adb shell input keyevent 62", shell=True)
            elif ch == '@':
                subprocess.run("adb shell input text \"\\@\"", shell=True)
            elif ch == '.':
                subprocess.run("adb shell input text \"\\.\"", shell=True)
            elif ch.isalnum():
                subprocess.run(f"adb shell input text \"{ch}\"", shell=True)
            time.sleep(0.05)
        time.sleep(0.2)

    def press_enter(self):
        subprocess.run("adb shell input keyevent 66", shell=True)
        time.sleep(1)

    def press_back(self):
        subprocess.run("adb shell input keyevent 4", shell=True)
        time.sleep(0.5)

    def press_tab(self, count=1):
        for _ in range(count):
            subprocess.run("adb shell input keyevent 61", shell=True)
            time.sleep(0.15)

    def tap_center(self):
        """Tap en el centro de la pantalla (para dar foco)"""
        self.click(540, 1100)

    def wait_for_text(self, text, timeout=30):
        """Espera hasta que aparezca un texto exacto"""
        self.log(f"Esperando '{text}'...")
        for _ in range(timeout * 2):
            self.screenshot()
            if self.find_text(text):
                self.log(f"'{text}' encontrado!")
                return True
            time.sleep(0.5)
        self.log(f"Timeout esperando '{text}'")
        return False

    def wait_for_contains(self, substring, timeout=30):
        """Espera hasta que aparezca texto que contenga substring"""
        self.log(f"Esperando texto con '{substring}'...")
        for _ in range(timeout * 2):
            self.screenshot()
            results = self.find_text_contains(substring)
            if results:
                self.log(f"'{substring}' encontrado en: {[r[2] for r in results[:3]]}")
                return True
            time.sleep(0.5)
        return False

    def scroll_down(self, amount=500):
        """Scroll hacia abajo"""
        subprocess.run(f"adb shell input swipe 540 1500 540 {1500-amount} 300", shell=True)
        time.sleep(0.5)

    def save_screenshot(self, name):
        path = f"{self.screenshots_dir}/{self.name}_{name}.png"
        cv2.imwrite(path, self.last_screen)
        return path

    def read_all_text(self):
        """Lee TODO el texto visible en pantalla"""
        try:
            import pytesseract
            gray = cv2.cvtColor(self.last_screen, cv2.COLOR_BGR2GRAY)
            text = pytesseract.image_to_string(gray)
            return text
        except:
            return ""
