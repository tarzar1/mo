"""Control de Escritorios Virtuales de Windows
Usa Win+Ctrl+Left/Right para cambiar entre escritorios.
Captura, ejecuta acciones y vuelve."""

import time, pyautogui
from PIL import ImageGrab

class DesktopSwitcher:
    def __init__(self, total=2):
        self.current = 1
        self.total = total
        self.agent_desktop = total  # el ultimo

    def switch_to(self, target):
        """Cambia al escritorio virtual target (1-indexed)"""
        if target == self.current:
            return
        diff = target - self.current
        key = 'right' if diff > 0 else 'left'
        times = abs(diff)
        for _ in range(times):
            pyautogui.hotkey('win', 'ctrl', key)
            time.sleep(0.35)
        self.current = target

    def go_agent(self):
        """Va al escritorio del agente"""
        self.switch_to(self.agent_desktop)

    def go_user(self):
        """Vuelve al escritorio del usuario (1)"""
        self.switch_to(1)

    def capture_on(self, desktop):
        """Captura pantalla en un escritorio especifico y vuelve"""
        self.switch_to(desktop)
        time.sleep(0.3)
        img = ImageGrab.grab(all_screens=True)
        return img

    def capture_agent(self):
        """Captura en el escritorio del agente y vuelve al usuario"""
        img = self.capture_on(self.agent_desktop)
        self.go_user()
        return img

    def execute_on(self, desktop, fn):
        """Ejecuta una funcion en un escritorio especifico"""
        self.switch_to(desktop)
        time.sleep(0.2)
        result = fn()
        return result

    def execute_agent(self, fn):
        """Ejecuta en escritorio del agente y vuelve"""
        self.go_agent()
        time.sleep(0.3)
        result = fn()
        self.go_user()
        return result

    def tap_on(self, desktop, x, y):
        """Tap en coordenadas de un escritorio especifico"""
        self.switch_to(desktop)
        time.sleep(0.2)
        pyautogui.click(x, y)
        time.sleep(0.1)

    def type_on(self, desktop, text):
        """Escribe texto en un escritorio especifico"""
        self.switch_to(desktop)
        time.sleep(0.2)
        pyautogui.write(text, interval=0.03)
        time.sleep(0.1)

    def press_on(self, desktop, key):
        """Presiona tecla en un escritorio especifico"""
        self.switch_to(desktop)
        time.sleep(0.2)
        pyautogui.press(key)
        time.sleep(0.1)
