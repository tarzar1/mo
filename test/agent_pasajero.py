"""Agente Pasajero - Vision Artificial
Simula un pasajero usando la app CommuteShare en Android."""

import time
import json
from agent_vision import AgentVision

class PassengerAgent:
    def __init__(self):
        self.v = AgentVision("PASAJERO")
        self.ok = True
        self.conductor_ready = False

    def run(self):
        try:
            return self._flow()
        except Exception as e:
            self.v.log(f"ERROR: {e}")
            self.v.screenshot()
            self.v.save_screenshot("error")
            self.ok = False
            return False

    def _flow(self):
        v = self.v

        # 1. Screenshot inicial
        v.screenshot()
        v.log("Iniciando flujo Pasajero...")

        # 2. Leer pantalla
        text = v.read_all_text()
        v.log(f"Texto: {text[:200]}")

        # 3. Login
        if "CommuteShare" in text or "Iniciar" in text or "sesion" in text.lower():
            v.log("Pantalla de login detectada")
            if "Registrate" in text or "REGISTRATE" in text.upper():
                v.click_contains("Iniciar")
                time.sleep(2)
                v.screenshot()

            # Email
            v.click(540, 800)
            time.sleep(0.5)
            v.type_text("pasajero@test.com")
            time.sleep(0.5)

            # Password
            v.click(540, 960)
            time.sleep(0.5)
            v.type_text("123456")
            time.sleep(0.5)

            # Boton
            v.click(540, 1150)
            v.log("Login enviado")
            time.sleep(5)
            v.screenshot()
            v.save_screenshot("post_login")

        # 4. Post-login
        v.screenshot()
        text = v.read_all_text()
        v.log(f"Post-login: {text[:200]}")

        # 5. Esperar que el conductor cree un viaje
        v.log("Esperando que el conductor cree un viaje...")
        for i in range(45):
            time.sleep(2)
            try:
                with open("test/coordination.json", "r") as f:
                    coord = json.load(f)
                if coord.get("viaje_creado"):
                    v.log("Viaje del conductor detectado!")
                    self.conductor_ready = True
                    break
            except:
                pass
            if i % 5 == 0:
                v.log(f"  Esperando... ({i*2}s)")

        if not self.conductor_ready:
            v.log("WARN: Timeout esperando conductor. Continuando...")

        # 6. Buscar viajes - refrescar pantalla
        v.screenshot()
        text = v.read_all_text()
        v.log(f"Pantalla pasajero: {text[:200]}")

        # En la app de pasajero, tocar "Buscar" o "Mis viajes"
        v.click_contains("Buscar") or v.click_contains("Viajes") or v.click(540, 1700)
        time.sleep(3)
        v.screenshot()

        # 7. Buscar destino
        v.log("Buscando viajes a Aeropuerto...")
        v.click(540, 600)
        time.sleep(0.5)
        v.type_text("Aeropuerto")
        time.sleep(0.5)
        v.press_enter()
        time.sleep(3)
        v.screenshot()
        v.save_screenshot("busqueda")

        # 8. Solicitar el primer viaje encontrado
        v.log("Solicitando viaje...")
        v.click_contains("Solicitar") or v.click_contains("Unirse") or v.click(540, 1200)
        time.sleep(3)
        v.screenshot()
        v.save_screenshot("solicitado")
        v.log("Solicitud enviada!")

        # Escribir coordinacion
        try:
            with open("test/coordination.json", "w") as f:
                json.dump({"solicitud_enviada": True, "step": "solicitud_enviada"}, f)
        except:
            pass

        # 9. Esperar aceptacion
        v.log("Esperando que el conductor acepte...")
        for i in range(30):
            time.sleep(2)
            v.screenshot()
            text = v.read_all_text()
            if "Aceptad" in text or "aceptad" in text or "confirmad" in text.lower():
                v.log(f"Aceptacion detectada! {text[:100]}")
                break
            try:
                with open("test/coordination.json", "r") as f:
                    coord = json.load(f)
                if coord.get("solicitud_aceptada"):
                    v.log("Aceptacion confirmada via coordinacion")
                    break
            except:
                pass
            if i % 5 == 0:
                v.log(f"  Esperando... ({i*2}s)")

        v.screenshot()
        v.save_screenshot("aceptado")
        v.log("Pasajero: ciclo completo!")
        return True

if __name__ == "__main__":
    agent = PassengerAgent()
    result = agent.run()
    print(f"\n[PASAJERO] {'PASS' if result else 'FAIL'}")
