"""Control de Escritorios Virtuales de Windows
Usa keyboard library para Win+Ctrl+Left/Right (mas fiable que pyautogui).
Captura, ejecuta acciones y vuelve."""

import time
import keyboard
from PIL import ImageGrab

class DesktopSwitcher:
    def __init__(self, total=2):
        self.current = 1
        self.total = total
        self.agent_desktop = total

    def switch_to(self, target):
        """Cambia al escritorio virtual target (1-indexed)"""
        if target == self.current:
            return

        diff = target - self.current
        direct = 'right' if diff > 0 else 'left'
        times = abs(diff)

        for _ in range(times):
            keyboard.press('win')
            keyboard.press('ctrl')
            keyboard.press(direct)
            time.sleep(0.1)
            keyboard.release(direct)
            keyboard.release('ctrl')
            keyboard.release('win')
            time.sleep(0.5)  # Esperar que Windows renderice el escritorio

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
        time.sleep(0.4)  # Esperar renderizado completo
        img = ImageGrab.grab(all_screens=True)
        return img

    def capture_agent(self):
        """Captura en el escritorio del agente y vuelve al usuario"""
        self.go_agent()
        time.sleep(0.4)
        img = ImageGrab.grab(all_screens=True)
        self.go_user()
        return img

    def execute_on(self, desktop, fn):
        """Ejecuta una funcion en un escritorio especifico"""
        self.switch_to(desktop)
        time.sleep(0.3)
        return fn()

    def execute_agent(self, fn):
        """Ejecuta en escritorio del agente y vuelve"""
        self.go_agent()
        time.sleep(0.3)
        result = fn()
        self.go_user()
        return result
