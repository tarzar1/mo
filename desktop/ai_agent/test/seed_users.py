import requests, json, os

BASE = "http://192.168.4.23:8000"

users = [
    {"name": "Conductor", "last_name": "Test", "email": "conductor@test.com",
     "password": "123456", "phone": "555-1001", "role": "driver"},
    {"name": "Pasajero", "last_name": "Test", "email": "pasajero@test.com",
     "password": "123456", "phone": "555-1002", "role": "passenger"},
]

for u in users:
    try:
        r = requests.post(f"{BASE}/Create_driver/", json=u, timeout=5)
        if r.status_code in (200, 201):
            print(f"[OK] Creado: {u['email']} ({u['role']})")
        else:
            print(f"[WARN] {u['email']}: {r.status_code} {r.text[:120]}")
    except Exception as e:
        print(f"[ERR] {u['email']}: {e}")

coordination = {
    "viaje_creado": False, "viaje_id": None,
    "solicitud_enviada": False, "solicitud_id": None,
    "solicitud_aceptada": False,
    "chat_conductor_enviado": False, "chat_pasajero_enviado": False,
    "estado": "iniciando", "errores": []
}

os.makedirs("test", exist_ok=True)
with open("test/coordination.json", "w") as f:
    json.dump(coordination, f)

print("[OK] test/coordination.json creado")
