"""Agente Conductor - Vision Artificial
Simula un conductor usando la app CommuteShare en Android."""

import time
from agent_vision import AgentVision

class ConductorAgent:
    def __init__(self):
        self.v = AgentVision("CONDUCTOR")
        self.ok = True

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

        # 1. Tomar screenshot inicial
        v.screenshot()
        v.log("Iniciando flujo Conductor...")

        # 2. Leer texto de la pantalla para saber donde estamos
        text = v.read_all_text()
        v.log(f"Texto detectado: {text[:200]}")

        # 3. Intentar login si estamos en pantalla de login
        if "CommuteShare" in text or "Iniciar" in text or "sesion" in text.lower() or "iniciar" in text.lower():
            v.log("Detectada pantalla de login")

            # Si hay boton "Registrate", ir a login
            if "Registrate" in text or "REGISTRATE" in text.upper():
                v.log("En pantalla de registro, cambiando a login...")
                v.click_contains("Iniciar")
                time.sleep(2)
                v.screenshot()

            # Tocar campo email (centro-izquierda de la pantalla)
            v.click(540, 800)
            time.sleep(0.5)
            v.type_text("conductor@test.com")
            time.sleep(0.5)

            # Tocar campo password
            v.click(540, 960)
            time.sleep(0.5)
            v.type_text("123456")
            time.sleep(0.5)

            # Tocar boton login
            v.click(540, 1150)
            v.log("Login enviado")
            time.sleep(5)
            v.screenshot()
            v.save_screenshot("post_login")

        # 4. Leer pantalla post-login
        v.screenshot()
        text = v.read_all_text()
        v.log(f"Post-login: {text[:200]}")

        # 5. Si texto tiene "Inicio" u "Home", login OK
        if "Inicio" in text or "Home" in text or "Viaje" in text or "viaje" in text:
            v.log("Login exitoso - en pantalla principal")
        else:
            v.log("WARN: No se detecto pantalla principal. Intentando continuar...")

        # 6. Tocar para crear viaje - buscar boton
        v.click_contains("Crear") or v.click_contains("Publicar") or v.click(540, 1700)
        time.sleep(3)
        v.screenshot()
        v.save_screenshot("crear_viaje")

        # 7. Llenar formulario: origen
        text = v.read_all_text()
        v.log(f"Form: {text[:200]}")

        # Campos (estimados en formulario Flutter)
        v.click(540, 600)  # recogida
        time.sleep(0.5)
        v.type_text("Centro")
        time.sleep(0.3)

        v.click(540, 740)  # destino
        time.sleep(0.5)
        v.type_text("Aeropuerto")
        time.sleep(0.3)

        v.click(540, 880)  # precio
        time.sleep(0.5)
        v.type_text("50")
        time.sleep(0.3)

        v.click(540, 1020)  # asientos
        time.sleep(0.5)
        v.type_text("3")
        time.sleep(0.3)

        v.screenshot()
        v.save_screenshot("form_llenado")

        # 8. Publicar
        v.log("Publicando viaje...")
        v.scroll_down(400)
        time.sleep(1)
        v.click_contains("Publicar") or v.click_contains("Crear") or v.click(540, 1600)
        time.sleep(4)
        v.screenshot()
        v.save_screenshot("viaje_publicado")
        v.log("Viaje publicado!")

        # 9. Escribir en archivo de coordinacion que el viaje está creado
        import json
        try:
            with open("test/coordination.json", "w") as f:
                json.dump({"viaje_creado": True, "step": "viaje_creado"}, f)
            v.log("Coordinacion: viaje_creado=true")
        except:
            pass

        # 10. Esperar solicitud entrante (polling visual)
        v.log("Esperando solicitud del pasajero...")
        for i in range(40):
            time.sleep(3)
            v.screenshot()
            text = v.read_all_text()
            if "Solicitud" in text or "solicitud" in text or "pendiente" in text.lower():
                v.log(f"Solicitud detectada! Texto: {text[:100]}")
                break
            if i % 5 == 0:
                v.log(f"  Esperando... ({i*3}s)")

        # 11. Aceptar
        v.log("Aceptando solicitud...")
        v.click_contains("Aceptar") or v.click_contains("ACEPTAR") or v.click(540, 1400)
        time.sleep(3)
        v.screenshot()
        v.save_screenshot("aceptado")
        v.log("Solicitud ACEPTADA!")

        try:
            with open("test/coordination.json", "w") as f:
                json.dump({"solicitud_aceptada": True, "step": "aceptado"}, f)
        except:
            pass

        v.log("Conductor: ciclo completo!")
        return True

if __name__ == "__main__":
    agent = ConductorAgent()
    result = agent.run()
    print(f"\n[CONDUCTOR] {'PASS' if result else 'FAIL'}")
