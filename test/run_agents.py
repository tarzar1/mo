"""Orquestador de Agentes con Vision Artificial
Ejecuta Conductor y Pasajero en paralelo, con vision OpenCV."""

import time
import json
import sys
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

# Import agents
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from agent_conductor import ConductorAgent
from agent_pasajero import PassengerAgent

def main():
    print("=" * 60)
    print("  CommuteShare - 2 AGENTES CON VISION OpenCV")
    print("  Conductor + Pasajero en paralelo")
    print("=" * 60)

    # Reset coordenacion
    os.makedirs("test", exist_ok=True)
    with open("test/coordination.json", "w") as f:
        json.dump({"viaje_creado": False, "solicitud_aceptada": False, "estado": "iniciando"}, f)

    # Crear agentes
    conductor = ConductorAgent()
    pasajero = PassengerAgent()

    print("[ORQ] Lanzando 2 agentes en paralelo...")
    print()

    # Ejecutar en paralelo con threads
    results = {}
    with ThreadPoolExecutor(max_workers=2) as executor:
        future_c = executor.submit(conductor.run)
        # Dar 5 segundos de ventaja al conductor
        future_p = executor.submit(pasajero.run)

        for future in as_completed([future_c, future_p], timeout=300):
            if future == future_c:
                results['conductor'] = future.result()
            else:
                results['pasajero'] = future.result()

    # Resultados
    print()
    print("-" * 60)
    r1 = results.get('conductor', False)
    r2 = results.get('pasajero', False)
    print(f"[ORQ] Conductor: {'PASS' if r1 else 'FAIL'}")
    print(f"[ORQ] Pasajero:  {'PASS' if r2 else 'FAIL'}")
    ok = r1 and r2
    print(f"[ORQ] {'PASS - CICLO COMPLETO!' if ok else 'FAIL'}")
    print(f"[ORQ] Screenshots guardadas en test/logs/")

    with open("test/coordination.json", "w") as f:
        json.dump({"estado": "completado" if ok else "fallo"}, f)

    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
