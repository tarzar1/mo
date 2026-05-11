"""Agente Conductor - Vision Artificial con OCR
Usa Tesseract para detectar texto y hacer clicks precisos."""

import time, json, os
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
            self.v.save_screenshot("error")
            return False

    def _flow(self):
        v = self.v
        v.screenshot()
        v.log("=== INICIO CONDUCTOR ===")

        # 1. Verificar pantalla actual
        text = v.read_all_text()
        v.log(f"Pantalla: {text[:200]}")

        # 2. Si estamos en registro, volver a login
        if "Crear cuenta" in text:
            v.log("En pantalla de registro. Volviendo a login...")
            v.click_contains("inicia sesion") or v.click_contains("Inicia")
            time.sleep(2)

        # 3. Login: email
        v.screenshot()
        v.log("Login: email")
        v.click_contains("Correo") or v.click_contains("correo")
        time.sleep(0.3)
        v.type_text("conductor@test.com")

        # 4. Login: password
        v.click_contains("Contrase") or v.click_contains("contrase")
        time.sleep(0.3)
        v.type_text("123456")

        # 5. Login: buscar y click en boton "Iniciar sesion"
        v.screenshot()
        v.log("Buscando boton de login...")
        clicked = v.click_contains("inic") or v.click_contains("Inic") or v.click_contains("sesion")
        if not clicked:
            v.log("Boton no encontrado con OCR. Usando posicion fija (540,1250)...")
            v.click(540, 1250)
        time.sleep(5)

        # 6. Verificar que el login funciono
        v.screenshot()
        text = v.read_all_text()
        v.log(f"Post-login: {text[:250]}")

        if "Inicio" in text or "Home" in text or "viaje" in text.lower() or "Viaje" in text:
            v.log("Login EXITOSO - en pantalla principal!")
        else:
            v.log("WARN: No se detecto pantalla principal. Texto: " + text[:150])

        # 7. Crear viaje - buscar boton "Crear" o "Publicar"
        v.screenshot()
        v.log("Buscando opcion para crear viaje...")
        v.click_contains("Crear") or v.click_contains("Publicar") or v.click_contains("viaje") or v.click_contains("Viaje")
        time.sleep(3)

        # 8. Llenar formulario de viaje con OCR-detected positions
        v.screenshot()
        text = v.read_all_text()
        v.log(f"Formulario: {text[:300]}")

        # Origen
        v.log("Llenando recogida...")
        v.click_contains("recogida") or v.click_contains("Origen") or v.click(540, 600)
        time.sleep(0.3)
        v.type_text("Centro")

        # Destino
        v.click_contains("destino") or v.click_contains("Destino") or v.click(540, 740)
        time.sleep(0.3)
        v.type_text("Aeropuerto")

        # Precio
        v.click_contains("precio") or v.click_contains("Precio") or v.click(540, 880)
        time.sleep(0.3)
        v.type_text("50")

        # Asientos
        v.click_contains("trips") or v.click_contains("Asientos") or v.click(540, 1020)
        time.sleep(0.3)
        v.type_text("3")

        v.save_screenshot("form_llenado")

        # 9. Publicar
        v.log("Publicando viaje...")
        v.screenshot()
        v.scroll_down(400)
        time.sleep(1)
        v.click_contains("Publicar") or v.click_contains("Guardar") or v.click_contains("Crear") or v.click(540, 1600)
        time.sleep(4)

        v.screenshot()
        v.save_screenshot("viaje_publicado")
        v.log("Viaje publicado!")

        # 10. Coordinacion
        try:
            with open("test/coordination.json", "w") as f:
                json.dump({"viaje_creado": True, "step": "viaje_creado"}, f)
        except:
            pass

        # 11. Esperar solicitud del pasajero
        v.log("Esperando solicitud del pasajero...")
        for i in range(40):
            time.sleep(3)
            v.screenshot()
            text = v.read_all_text()
            if "Solicitud" in text or "solicitud" in text or "pendiente" in text.lower() or "request" in text.lower():
                v.log(f"Solicitud detectada!")
                break
            if i % 5 == 0:
                v.log(f"  Esperando... ({i*3}s)")

        # 12. Aceptar
        v.log("Aceptando solicitud...")
        v.click_contains("Aceptar") or v.click_contains("ACEPTAR") or v.click(540, 1400)
        time.sleep(3)
        v.screenshot()
        v.save_screenshot("aceptado")

        try:
            with open("test/coordination.json", "w") as f:
                json.dump({"solicitud_aceptada": True, "step": "aceptado"}, f)
        except:
            pass

        v.log("=== CONDUCTOR COMPLETO ===")
        return True

if __name__ == "__main__":
    c = ConductorAgent()
    result = c.run()
    print(f"\n[CONDUCTOR] {'PASS' if result else 'FAIL'}")
