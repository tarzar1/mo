# ESP32-C3 + Matrix WS2812B 8x8 - Demo Bajo Consumo
# Brillo ultra-bajo para funcionar SOLO con USB
# Si aun falla, conecta V+ de matriz a fuente externa 5V

from machine import Pin
import neopixel
import math
import random
import time

LED_PIN = Pin(2)
NUM_LEDS = 64
MATRIX = 8

np = neopixel.NeoPixel(LED_PIN, NUM_LEDS)

# ---- Utilidades ----
def xy(x, y):
    return y * MATRIX + (MATRIX - 1 - x) if y % 2 else y * MATRIX + x

def wheel(pos):
    pos = pos % 256
    if pos < 85:
        return (255 - pos * 3, pos * 3, 0)
    elif pos < 170:
        pos -= 85
        return (0, 255 - pos * 3, pos * 3)
    else:
        pos -= 170
        return (pos * 3, 0, 255 - pos * 3)

def clear():
    for i in range(NUM_LEDS):
        np[i] = (0, 0, 0)
    np.write()

# Brillo MUY bajo (5-8%) para funcionar con USB
def dim(c, factor=0.06):
    return tuple(max(0, min(255, int(v * factor))) for v in c)

# ---- Test: un LED a la vez ----
def test_pixel():
    print("Test: un LED a la vez (deberian prender los 64)")
    for i in range(NUM_LEDS):
        clear()
        np[i] = (10, 0, 0)  # Rojo muy tenue
        np.write()
        time.sleep(0.05)
    clear()

def test_rows():
    print("Test: por filas")
    for y in range(8):
        clear()
        for x in range(8):
            np[xy(x, y)] = dim((0, 255, 0))  # Verde
        np.write()
        time.sleep(0.3)
    clear()

def test_cols():
    print("Test: por columnas")
    for x in range(8):
        clear()
        for y in range(8):
            np[xy(x, y)] = dim((0, 0, 255))  # Azul
        np.write()
        time.sleep(0.3)
    clear()

# ---- Animaciones bajo consumo ----
def anim_rainbow(cycles=60):
    for j in range(cycles):
        t = time.ticks_ms() / 15
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = dim(wheel(int((x * 32 + y * 32 + t) % 256)), 0.05)
        np.write()
        time.sleep(0.04)

def anim_wave(cycles=60):
    for j in range(cycles):
        t = time.ticks_ms() / 8
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = dim(wheel(int((x * 35 + y * 35 + t) % 256)), 0.05)
        np.write()
        time.sleep(0.03)

def anim_heart(cycles=4):
    h = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 0, 0, 1, 1, 0],
        [1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1, 1],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ]
    for _ in range(cycles):
        for p in [3, 2, 3, 1.5]:
            for y in range(8):
                for x in range(8):
                    np[xy(x, y)] = dim((int(255 / p), 0, 0), 0.06) if h[y][x] else (0, 0, 0)
            np.write()
            time.sleep(0.25)

def anim_spiral(cycles=80):
    for j in range(cycles):
        t = time.ticks_ms() / 200
        for y in range(8):
            for x in range(8):
                a = abs(x - 3.5) + abs(y - 3.5)
                np[xy(x, y)] = dim(wheel(int((a * 32 + t * 30) % 256)), 0.05)
        np.write()
        time.sleep(0.04)

def anim_ripple(cycles=100):
    for j in range(cycles):
        t = time.ticks_ms() / 250
        clear()
        for r in range(1, 7):
            for y in range(8):
                for x in range(8):
                    d = math.sqrt((x - 3.5) ** 2 + (y - 3.5) ** 2)
                    if abs(d - r) < 0.6 and r % 2 == int(t * 3) % 2:
                        np[xy(x, y)] = dim(wheel(int(r * 40 + t * 50) % 256), 0.05)
        np.write()
        time.sleep(0.05)

def anim_explode(cycles=8):
    for _ in range(cycles):
        for r in range(1, 9):
            clear()
            t = time.ticks_ms() / 1500
            for y in range(8):
                for x in range(8):
                    d = math.sqrt((x - 3.5) ** 2 + (y - 3.5) ** 2)
                    if abs(d - r * 0.8) < 1.0:
                        np[xy(x, y)] = dim(wheel(int(t * 100 + d * 30) % 256), 0.06)
            np.write()
            time.sleep(0.08)

def anim_checkers(cycles=40):
    for j in range(cycles):
        t = time.ticks_ms() / 500
        off = int(t) % 4
        clear()
        for y in range(8):
            for x in range(8):
                if (x + y + off) % 4 < 2:
                    np[xy(x, y)] = dim(wheel(int((x + y) * 32 + t * 40) % 256), 0.05)
        np.write()
        time.sleep(0.18)

def anim_bounce(cycles=250):
    x, y = 3.0, 3.0
    dx, dy = 0.3, 0.2
    color = wheel(random.randint(0, 255))
    trail = []
    for _ in range(cycles):
        x += dx
        y += dy
        if x <= 0 or x >= 7:
            dx = -dx; x = max(0, min(7, x)); color = wheel(random.randint(0, 255))
        if y <= 0 or y >= 7:
            dy = -dy; y = max(0, min(7, y)); color = wheel(random.randint(0, 255))
        trail.append((x, y, color))
        if len(trail) > 15: trail.pop(0)
        clear()
        for i, (tx, ty, tc) in enumerate(trail):
            br_v = i / len(trail)
            np[xy(int(tx), int(ty))] = dim((int(tc[0] * br_v), int(tc[1] * br_v), int(tc[2] * br_v)), 0.06)
        np.write()
        time.sleep(0.05)

# ---- Main ----
print("=" * 40)
print("ESP32-C3 Matrix 8x8 - DEMO BAJO CONSUMO")
print("Brillo ~5% (USB-safe)")
print("=" * 40)

# Test inicial para verificar que todos los LEDs funcionan
test_pixel()
time.sleep(0.5)
test_rows()
time.sleep(0.5)
test_cols()
time.sleep(0.5)

ANIMS = [
    ("Arcoiris", anim_rainbow),
    ("Ola de colores", anim_wave),
    ("Corazon", anim_heart),
    ("Espiral", anim_spiral),
    ("Ondas", anim_ripple),
    ("Explosion", anim_explode),
    ("Ajedrez", anim_checkers),
    ("Rebote", anim_bounce),
]

i = 0
while True:
    name, func = ANIMS[i % len(ANIMS)]
    print(f"[{i+1}] {name}")
    try:
        func()
    except Exception as e:
        print(f"Error: {e}")
    clear()
    time.sleep(0.3)
    i += 1
