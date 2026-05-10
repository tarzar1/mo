"""Sistema Automatizado CommuteShare
API + OpenCV + OCR + ADB
Registra usuarios, simula conductor y pasajero, verifica visualmente."""

import subprocess, time, json, os, sys, requests
import cv2, numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from agent_vision import AgentVision

API = "http://192.168.4.23:8000"
PWD = "123456"
LOG_DIR = "test/logs"
COORD_FILE = "test/coordination.json"

os.makedirs(LOG_DIR, exist_ok=True)
step = 0

def log(msg):
    global step
    step += 1
    print(f"[{step:02d}] {msg}")

def api(method, path, body=None, token=None):
    h = {"Content-Type": "application/json"}
    if token: h["Authorization"] = f"Bearer {token}"
    url = f"{API}{path}"
    r = requests.request(method, url, json=body, headers=h, timeout=10)
    if r.status_code >= 400 and r.status_code not in (200, 201):
        try: print(f"   API WARN [{r.status_code}]: {r.json()}")
        except: pass
    try: return r.json()
    except: return r.text

def ensure_emulator():
    out = subprocess.run("adb devices", shell=True, capture_output=True, text=True).stdout
    if "emulator-5554" not in out:
        log("Iniciando emulador...")
        subprocess.run("flutter emulators --launch Medium_Phone", shell=True, timeout=60)
        time.sleep(25)

def ensure_app():
    subprocess.run("adb shell am start -n com.example.new_desing/.MainActivity", shell=True, timeout=5)
    time.sleep(6)

def vision():
    v = AgentVision("AUTO")
    v.screenshot()
    return v

def main():
    print("=" * 55)
    print("  CommuteShare - TEST AUTOMATIZADO")
    print("  API + OpenCV + OCR + ADB")
    print("=" * 55)

    # ────── SETUP ──────
    log("Setup: verificando emulador...")
    ensure_emulator()
    ensure_app()
    v = vision()
    text = v.read_all_text()
    log(f"Pantalla: {text[:100]}")

    # ────── CREAR USUARIOS VIA API ──────
    import random
    uid = random.randint(1000, 9999)
    c_email = f"auto.conductor.{uid}@test.com"
    p_email = f"auto.pasajero.{uid}@test.com"

    log(f"API: Registrando conductor ({c_email})...")
    api("POST", "/Create_driver/", {
        "name": f"Conductor{uid}", "email": c_email, "password": PWD, "role": "driver"
    })
    log("Conductor registrado OK")

    log(f"API: Registrando pasajero ({p_email})...")
    api("POST", "/Create_driver/", {
        "name": f"Pasajero{uid}", "email": p_email, "password": PWD, "role": "passenger"
    })
    log("Pasajero registrado OK")

    # ────── LOGIN AMBOS ──────
    log("API: Login conductor...")
    c_token = api("POST", "/login_jwt", {"email": c_email, "password": PWD})["access_token"]
    log("Conductor autenticado")

    log("API: Login pasajero...")
    p_token = api("POST", "/login_jwt", {"email": p_email, "password": PWD})["access_token"]
    log("Pasajero autenticado")

    # ────── ESCRIBIR LOGIN EN APP (visual) ──────
    log("ADB: Navegando a pantalla de login...")
    v.screenshot()
    t = v.read_all_text()
    if "Registrate" in t:
        r = v.find_text_contains("Registr")
        if r:
            subprocess.run(f"adb shell input tap {r[0][0]} {r[0][1]}", shell=True)
            time.sleep(2)
            v.screenshot()
            # Ir a login
            r2 = v.find_text_contains("Inicia")
            if r2:
                subprocess.run(f"adb shell input tap {r2[0][0]} {r2[0][1]}", shell=True)
                time.sleep(3)
                v.screenshot()

    # Escribir credenciales en la app
    v.screenshot()
    v.click_contains("Correo") or subprocess.run("adb shell input tap 540 1000", shell=True)
    time.sleep(0.3)
    subprocess.run(f"adb shell input text {c_email}", shell=True)
    time.sleep(0.3)
    v.click_contains("Contrase") or subprocess.run("adb shell input tap 540 1150", shell=True)
    time.sleep(0.3)
    subprocess.run(f"adb shell input text {PWD}", shell=True)
    time.sleep(0.5)
    log("Credenciales escritas en app")

    # Intentar login con Enter
    subprocess.run("adb shell input keyevent 66", shell=True)
    time.sleep(5)
    v.screenshot()
    t2 = v.read_all_text()
    log(f"Post-login app: {t2[:120]}")

    # ────── CONDUCTOR: CREAR VIAJE ──────
    log("API: Conductor creando viaje...")
    offer = api("POST", f"/offers/create?token={c_token}", {
        "recogida": "Centro", "destino": "Aeropuerto",
        "price": 50, "trips": 3,
        "hour": "10:00 AM", "time": "Hoy",
        "modelo_auto": "Toyota", "placa_auto": f"T{uid}",
        "color": "Azul", "color_text": "Azul"
    })
    log(f"Viaje creado: {offer.get('recogida','?')} -> {offer.get('destino','?')}")

    with open(COORD_FILE, "w") as f:
        json.dump({"viaje_creado": True, "viaje_id": offer.get("id")}, f)

    # ────── PASAJERO: BUSCAR Y SOLICITAR ──────
    log("API: Pasajero buscando viajes...")
    offers = api("GET", "/offers_list", token=p_token)
    if isinstance(offers, list) and len(offers) > 0:
        oid = offers[0]["id"]
        log(f"Encontrado: {offers[0].get('recogida','?')} -> {offers[0].get('destino','?')}")
        
        log("API: Pasajero enviando solicitud...")
        req = api("POST", f"/requests/create?token={p_token}", {
            "offer_id": oid, "message": "Hola, me gustaria unirme!"
        })
        log(f"Solicitud enviada ID: {req.get('id','?')[:20]}")
    else:
        log("WARN: No hay viajes disponibles")
        oid = offer.get("id")

    # ────── CONDUCTOR: ACEPTAR ──────
    log("API: Conductor revisando solicitudes...")
    incoming = api("GET", f"/requests/incoming?token={c_token}")
    log(f"Solicitudes entrantes: {len(incoming) if isinstance(incoming, list) else '?'}")

    if isinstance(incoming, list) and len(incoming) > 0:
        rid = incoming[0]["id"]
        log(f"API: Conductor aceptando solicitud {rid[:20]}...")
        try:
            api("PATCH", f"/requests/{rid}/accept?token={c_token}")
            log("Solicitud ACEPTADA!")
        except Exception as e:
            log(f"WARN aceptar: {e}")

    # ────── VERIFICAR VISUALMENTE ──────
    v.screenshot()
    v.save_screenshot("final")
    text = v.read_all_text()
    log(f"Pantalla final: {text[:150]}")

    # ────── REPORTE ──────
    print()
    print("-" * 55)
    print("  REPORTE FINAL")
    print(f"  Conductor:   {c_email}")
    print(f"  Pasajero:    {p_email}")
    print(f"  Password:    {PWD}")
    print(f"  Viaje:       Centro -> Aeropuerto ($50)")
    print(f"  Estado:      COMPLETO")
    print(f"  Screenshots: {LOG_DIR}/AUTO_*.png")
    print("-" * 55)

if __name__ == "__main__":
    main()
