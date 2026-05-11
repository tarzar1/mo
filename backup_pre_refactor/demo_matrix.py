# ESP32-C3 + Matrix WS2812B 8x8 - Demo de Animaciones
# Cicla automaticamente entre varias animaciones sin BLE

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

def dim(c, factor=0.25):
    return tuple(max(0, min(255, int(v * factor))) for v in c)

# ---- Animaciones ----
def anim_rainbow(cycles=80):
    for j in range(cycles):
        t = time.ticks_ms() / 10
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = dim(wheel(int((x * 32 + y * 32 + t) % 256)))
        np.write()
        time.sleep(0.03)

def anim_wave(cycles=80):
    for j in range(cycles):
        t = time.ticks_ms() / 5
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = dim(wheel(int((x * 35 + y * 35 + t) % 256)))
        np.write()
        time.sleep(0.025)

def anim_fire(cycles=120):
    xv, yv = 1.2, 1.2
    for j in range(cycles):
        t = time.ticks_ms() / 150
        xv += random.uniform(-0.03, 0.03)
        yv += random.uniform(-0.03, 0.03)
        for y in range(8):
            for x in range(8):
                v = int((1 + math.sin(x * 1.2 / xv + t) * math.cos(y * 1.2 / yv + t * 0.8) *
                         math.sin((x + y) * 0.6 + t * 0.6)) * 127)
                r = max(0, min(255, v))
                g = max(0, min(200, v // 3)) if v > 50 else 0
                np[xy(x, y)] = dim((r, g, 0))
        np.write()
        time.sleep(0.045)

def anim_heart(cycles=6):
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
        for p in [2.5, 1.5, 2.0, 1]:
            for y in range(8):
                for x in range(8):
                    np[xy(x, y)] = dim((int(255 / p), 0, 0)) if h[y][x] else (0, 0, 0)
            np.write()
            time.sleep(0.2)

def anim_snake(cycles=200):
    body = [(random.randint(0, 7), random.randint(0, 7))]
    d = random.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
    hue = 0
    for _ in range(cycles):
        hx, hy = body[0]
        nx, ny = hx + d[0], hy + d[1]
        if nx < 0 or nx >= 8 or ny < 0 or ny >= 8 or (nx, ny) in body:
            opts = [(dx, dy) for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]
                    if 0 <= hx + dx < 8 and 0 <= hy + dy < 8 and (hx + dx, hy + dy) not in body]
            if opts:
                d = random.choice(opts)
                nx, ny = hx + d[0], hy + d[1]
            else:
                body = [(random.randint(0, 7), random.randint(0, 7))]
                continue
        body.insert(0, (nx, ny))
        if len(body) > 14:
            body.pop()
        clear()
        for i, (sx, sy) in enumerate(body):
            np[xy(sx, sy)] = dim(wheel((hue + i * 18) % 256))
        np.write()
        hue = (hue + 5) % 256
        time.sleep(0.08)

def anim_spiral(cycles=100):
    for j in range(cycles):
        t = time.ticks_ms() / 150
        for y in range(8):
            for x in range(8):
                a = abs(x - 3.5) + abs(y - 3.5)
                np[xy(x, y)] = dim(wheel(int((a * 32 + t * 30) % 256)))
        np.write()
        time.sleep(0.035)

def anim_ripple(cycles=120):
    for j in range(cycles):
        t = time.ticks_ms() / 200
        clear()
        for r in range(1, 7):
            for y in range(8):
                for x in range(8):
                    d = math.sqrt((x - 3.5) ** 2 + (y - 3.5) ** 2)
                    if abs(d - r) < 0.6 and r % 2 == int(t * 3) % 2:
                        np[xy(x, y)] = dim(wheel(int(r * 40 + t * 50) % 256))
        np.write()
        time.sleep(0.05)

def anim_checkers(cycles=50):
    for j in range(cycles):
        t = time.ticks_ms() / 400
        off = int(t) % 4
        clear()
        for y in range(8):
            for x in range(8):
                if (x + y + off) % 4 < 2:
                    np[xy(x, y)] = dim(wheel(int((x + y) * 32 + t * 40) % 256))
        np.write()
        time.sleep(0.15)

def anim_explode(cycles=10):
    for _ in range(cycles):
        for r in range(1, 9):
            clear()
            t = time.ticks_ms() / 1000
            for y in range(8):
                for x in range(8):
                    d = math.sqrt((x - 3.5) ** 2 + (y - 3.5) ** 2)
                    if abs(d - r * 0.8) < 1.0:
                        np[xy(x, y)] = dim(wheel(int(t * 80 + d * 26) % 256))
            np.write()
            time.sleep(0.06)

def anim_bounce(cycles=300):
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
        if len(trail) > 20: trail.pop(0)
        clear()
        for i, (tx, ty, tc) in enumerate(trail):
            br_v = i / len(trail)
            np[xy(int(tx), int(ty))] = dim((int(tc[0] * br_v), int(tc[1] * br_v), int(tc[2] * br_v)))
        np.write()
        time.sleep(0.04)

# ---- Main ----
ANIMS = [
    ("Arcoiris", anim_rainbow),
    ("Ola de colores", anim_wave),
    ("Fuego / Plasma", anim_fire),
    ("Corazon", anim_heart),
    ("Snake", anim_snake),
    ("Espiral", anim_spiral),
    ("Ondas", anim_ripple),
    ("Ajedrez", anim_checkers),
    ("Explosion", anim_explode),
    ("Rebote", anim_bounce),
]

print("=" * 40)
print("ESP32-C3 Matrix 8x8 - DEMO")
print("Ciclando animaciones...")
print("=" * 40)

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
