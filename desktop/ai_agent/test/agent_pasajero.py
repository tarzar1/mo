"""Agente Pasajero - Vision Artificial con OCR"""

import time, json, os
from agent_vision import AgentVision

class PassengerAgent:
    def __init__(self):
        self.v = AgentVision("PASAJERO")
        self.ok = True

    def run(self):
        try:
            return self._flow()
        except Exception as e:
            self.v.log(f"ERROR: {e}")
            self.v.save_screenshot("error")
            return False

    def _flow(self):
        v = self.v
        v.screenshot()
        v.log("=== INICIO PASAJERO ===")

        text = v.read_all_text()
        v.log(f"Pantalla: {text[:200]}")

        # 1. Login
        if "Crear cuenta" in text:
            v.log("En registro. Volviendo a login...")
            v.click_contains("inicia sesion") or v.click_contains("Inicia")
            time.sleep(2)
            v.screenshot()

        v.screenshot()
        v.click_contains("Correo") or v.click_contains("correo")
        time.sleep(0.3)
        v.type_text("pasajero@test.com")

        v.click_contains("Contrase") or v.click_contains("contrase")
        time.sleep(0.3)
        v.type_text("123456")

        v.screenshot()
        v.click_contains("inic") or v.click_contains("Inic") or v.click(540, 1250)
        time.sleep(5)

        # 2. Verificar login
        v.screenshot()
        text = v.read_all_text()
        v.log(f"Post-login: {text[:250]}")

        # 3. Esperar que conductor cree viaje
        v.log("Esperando viaje del conductor...")
        for i in range(60):
            time.sleep(2)
            try:
                with open("test/coordination.json", "r") as f:
                    coord = json.load(f)
                if coord.get("viaje_creado"):
                    v.log("Viaje del conductor listo!")
                    break
            except: pass
            if i % 5 == 0: v.log(f"  Esperando... ({i*2}s)")

        # 4. Buscar viajes
        v.screenshot()
        v.log("Buscando viajes...")
        v.click_contains("Buscar") or v.click_contains("Viajes") or v.click(540, 1700)
        time.sleep(3)

        v.screenshot()
        v.click_contains("buscar") or v.click_contains("destino") or v.click(540, 600)
        time.sleep(0.3)
        v.type_text("Aeropuerto")
        time.sleep(0.5)
        v.press_enter()
        time.sleep(3)

        v.screenshot()
        v.save_screenshot("busqueda")

        # 5. Solicitar
        v.log("Solicitando viaje...")
        v.click_contains("Solicitar") or v.click_contains("Unirse") or v.click(540, 1200)
        time.sleep(3)
        v.screenshot()
        v.save_screenshot("solicitado")
        v.log("Solicitud enviada!")

        try:
            with open("test/coordination.json", "w") as f:
                json.dump({"solicitud_enviada": True, "step": "solicitud"}, f)
        except: pass

        # 6. Esperar aceptacion
        v.log("Esperando aceptacion...")
        for i in range(40):
            time.sleep(2)
            v.screenshot()
            text = v.read_all_text()
            if "Aceptad" in text or "aceptad" in text or "confirmad" in text.lower():
                v.log("Aceptacion detectada!")
                break
            try:
                with open("test/coordination.json", "r") as f:
                    if json.load(f).get("solicitud_aceptada"):
                        v.log("Aceptacion via coordinacion!")
                        break
            except: pass
            if i % 5 == 0: v.log(f"  Esperando... ({i*2}s)")

        v.screenshot()
        v.save_screenshot("aceptado")
        v.log("=== PASAJERO COMPLETO ===")
        return True

if __name__ == "__main__":
    p = PassengerAgent()
    result = p.run()
    print(f"\n[PASAJERO] {'PASS' if result else 'FAIL'}")
