# ESP32-C3 + Matrix WS2812B 8x8 - Control por BLE
# 25 animaciones + editor de patrones via Bluetooth

import bluetooth
import gc
import json
import math
import random
import struct
import time
from machine import Pin
from micropython import const
import neopixel

# ===== CONFIG =====
LED_PIN = Pin(2)
NUM_LEDS = 64
MATRIX = 8
BLE_NAME = "Matrix 8x8"

np = neopixel.NeoPixel(LED_PIN, NUM_LEDS)

# Estado
current_anim = None
brightness = 100
speed_val = 100
stop_flag = False
connected = False
cmd_buffer = bytearray(200)
cmd_handle = None

# BLE IRQ const
_IRQ_CENTRAL_CONNECT = const(1)
_IRQ_CENTRAL_DISCONNECT = const(2)
_IRQ_GATTS_WRITE = const(3)

_SERVICE_UUID = bluetooth.UUID("19B10000-E8F2-537E-4F6C-D104768A1214")
_CMD_CHAR_UUID = bluetooth.UUID("19B10001-E8F2-537E-4F6C-D104768A1214")


# ===== UTILIDADES =====

def xy(x, y):
    return y * MATRIX + (MATRIX - 1 - x) if y % 2 else y * MATRIX + x


def scale(c, b):
    return tuple(max(0, min(255, int(v * b / 100))) for v in c)


def clear_matrix():
    for i in range(NUM_LEDS):
        np[i] = (0, 0, 0)
    np.write()


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


def check_stop(secs):
    global stop_flag
    for _ in range(int(secs * 20)):
        if stop_flag:
            return True
        time.sleep(0.05)
    return stop_flag


# ===== BLE =====

def init_ble():
    global cmd_handle
    ble = bluetooth.BLE()
    ble.active(True)
    ble.irq(ble_irq)

    ((cmd_handle,), ) = ble.gatts_register_services([(
        _SERVICE_UUID,
        (
            (_CMD_CHAR_UUID, bluetooth.FLAG_WRITE | bluetooth.FLAG_WRITE_NO_RESPONSE),
        ),
    )])

    ble.gatts_set_buffer(cmd_handle, 200)
    ble.gatts_write(cmd_handle, cmd_buffer)

    name_bytes = BLE_NAME.encode()
    adv = (b'\x02\x01\x06' +
           bytes([len(name_bytes) + 1, 0x09]) + name_bytes)
    ble.gap_advertise(500000, adv_data=adv)
    print(f"BLE: '{BLE_NAME}' anunciandose...")
    return ble


def ble_irq(event, data):
    global connected, stop_flag, current_anim, brightness, speed_val

    if event == _IRQ_CENTRAL_CONNECT:
        _, _, _ = data
        connected = True
        print("BLE: conectado")

    elif event == _IRQ_CENTRAL_DISCONNECT:
        _, _, _ = data
        connected = False
        stop_flag = True
        current_anim = None
        clear_matrix()
        print("BLE: desconectado")

    elif event == _IRQ_GATTS_WRITE:
        _, attr_handle = data
        raw = ble.gatts_read(attr_handle)
        try:
            text = raw.decode('utf-8', 'replace').strip('\x00').strip()
            cmd = json.loads(text)
        except:
            return

        t = cmd.get('t', '')

        if t == 'anim':
            name = cmd.get('n', '')
            if name in ANIMATIONS:
                stop_flag = True
                current_anim = name
                print(f"Anim: {name}")

        elif t == 'bri':
            brightness = max(1, min(100, int(cmd.get('v', 100))))
            print(f"Brillo: {brightness}")

        elif t == 'spd':
            speed_val = max(10, min(300, int(cmd.get('v', 100))))
            print(f"Velocidad: {speed_val}")

        elif t == 'stop':
            stop_flag = True
            current_anim = None
            clear_matrix()
            print("STOP")

        elif t == 'clear':
            stop_flag = True
            current_anim = None
            clear_matrix()
            print("CLEAR")

        elif t == 'custom':
            stop_flag = True
            current_anim = None
            time.sleep(0.1)
            clear_matrix()
            pixels = cmd.get('d', [])
            for p in pixels:
                x, y, r, g, b = int(p[0]), int(p[1]), int(p[2]), int(p[3]), int(p[4])
                if 0 <= x < 8 and 0 <= y < 8:
                    np[xy(x, y)] = scale((r, g, b), brightness)
            np.write()
            print("Custom pattern")


# ===== 25 ANIMACIONES =====

ANIMATIONS = {}


def anim(name):
    def dec(f):
        ANIMATIONS[name] = f
        return f
    return dec


@anim("Arcoiris")
def a_rainbow():
    global stop_flag
    stop_flag = False
    t0 = time.ticks_ms()
    while not stop_flag:
        t = time.ticks_ms() - t0
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = scale(wheel(int((x * 32 + y * 32 + t / (10 / (speed_val / 100))) % 256)), brightness)
        np.write()
        if check_stop(0.03): return


@anim("Ola de colores")
def a_wave():
    global stop_flag
    stop_flag = False
    t0 = time.ticks_ms()
    while not stop_flag:
        t = time.ticks_ms() - t0
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = scale(wheel(int((x * 35 + y * 35 + t / (5 / (speed_val / 100))) % 256)), brightness)
        np.write()
        if check_stop(0.025): return


@anim("Lluvia")
def a_rain():
    global stop_flag
    stop_flag = False
    drops = [(random.randint(0, 7), random.randint(-7, 7), wheel(random.randint(0, 255))) for _ in range(8)]
    while not stop_flag:
        clear_matrix()
        for i, (x, y, c) in enumerate(drops):
            if 0 <= y < 8:
                np[xy(x, y)] = scale(c, brightness)
            drops[i] = (x, y + 1, c)
            if y >= 7:
                drops[i] = (random.randint(0, 7), 0, wheel(random.randint(0, 255)))
        np.write()
        if check_stop(0.1 / (speed_val / 100)): return


@anim("Corazon")
def a_heart():
    global stop_flag
    stop_flag = False
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
    while not stop_flag:
        for p in [1.5, 2.5, 1]:
            for y in range(8):
                for x in range(8):
                    np[xy(x, y)] = scale((int(255 / p), 0, 0), brightness) if h[y][x] else (0, 0, 0)
            np.write()
            if check_stop(0.25): return
        if check_stop(0.3): return


@anim("Snake")
def a_snake():
    global stop_flag
    stop_flag = False
    body = [(random.randint(0, 7), random.randint(0, 7))]
    d = random.choice([(1, 0), (-1, 0), (0, 1), (0, -1)])
    hue = 0
    while not stop_flag:
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
        clear_matrix()
        for i, (sx, sy) in enumerate(body):
            np[xy(sx, sy)] = scale(wheel((hue + i * 18) % 256), brightness)
        np.write()
        hue = (hue + 5) % 256
        if check_stop(0.08 / (speed_val / 100)): return


@anim("Explosion")
def a_explode():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        for r in range(1, 9):
            clear_matrix()
            t = time.ticks_ms() / 1000
            for y in range(8):
                for x in range(8):
                    d = math.sqrt((x - 3.5) ** 2 + (y - 3.5) ** 2)
                    if abs(d - r * 0.8) < 1.0:
                        np[xy(x, y)] = scale(wheel(int(t * 80 + d * 26) % 256), brightness)
            np.write()
            if check_stop(0.06 / (speed_val / 100)): return


@anim("Espiral")
def a_spiral():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / 150
        for y in range(8):
            for x in range(8):
                a = abs(x - 3.5) + abs(y - 3.5)
                np[xy(x, y)] = scale(wheel(int((a * 32 + t * 30 * (speed_val / 100)) % 256)), brightness)
        np.write()
        if check_stop(0.035): return


@anim("Fuego / Plasma")
def a_fire():
    global stop_flag
    stop_flag = False
    xv, yv = 1.2, 1.2
    while not stop_flag:
        t = time.ticks_ms() / (150 / (speed_val / 100))
        xv += random.uniform(-0.03, 0.03)
        yv += random.uniform(-0.03, 0.03)
        for y in range(8):
            for x in range(8):
                v = int((1 + math.sin(x * 1.2 / xv + t) * math.cos(y * 1.2 / yv + t * 0.8) *
                         math.sin((x + y) * 0.6 + t * 0.6)) * 127)
                r = max(0, min(255, v))
                g = max(0, min(200, v // 3)) if v > 50 else 0
                np[xy(x, y)] = scale((r, g, 0), brightness)
        np.write()
        if check_stop(0.045): return


@anim("VU Meter")
def a_vu():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / 120
        clear_matrix()
        for col in range(8):
            h2 = int(3 + 4 * (1 + math.sin(t * (1.4 + col * 0.6) * (speed_val / 100) + col)) / 2)
            for row in range(7 - h2, 8):
                np[xy(col, row)] = scale(wheel(int(col * 32 + t * 20) % 256), brightness)
        np.write()
        if check_stop(0.06): return


@anim("Cubo 3D")
def a_cube():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (200 / (speed_val / 100))
        clear_matrix()
        ca, sa = math.cos(t), math.sin(t)
        cb, sb = math.cos(t * 0.7), math.sin(t * 0.7)
        pts = [(-1, -1, -1), (-1, -1, 1), (-1, 1, -1), (-1, 1, 1),
               (1, -1, -1), (1, -1, 1), (1, 1, -1), (1, 1, 1)]
        edges = [(0, 1), (0, 2), (0, 4), (1, 3), (1, 5), (2, 3), (2, 6),
                 (3, 7), (4, 5), (4, 6), (5, 7), (6, 7)]
        proj = []
        for px, py, pz in pts:
            rx = px * ca - pz * sa
            rz = px * sa + pz * ca
            ry = py * cb - rz * sb
            rz = py * sb + rz * cb
            proj.append((int(rx * 1.5 + 3.5), int(ry * 1.5 + 3.5), rz))
        for a, b in edges:
            for i in (a, b):
                sx, sy, sz = proj[i]
                if 0 <= sx < 8 and 0 <= sy < 8:
                    d2 = int(abs(sz) * 100)
                    np[xy(sx, sy)] = scale((d2, 255 - d2, 255 - d2 // 2), brightness)
        np.write()
        if check_stop(0.06): return


@anim("Estrella fugaz")
def a_star():
    global stop_flag
    stop_flag = False
    parts = []
    while not stop_flag:
        if random.random() < 0.3 * (speed_val / 100):
            sx, sy = random.randint(0, 7), random.randint(0, 3)
            dx, dy = random.choice([(1, 1), (-1, 1), (1, -1), (-1, -1)])
            parts.append([sx, sy, dx, dy, 255, random.randint(0, 255)])
        clear_matrix()
        new_p = []
        for p in parts:
            p[0] += p[2] * 0.3 * (speed_val / 100)
            p[1] += p[3] * 0.3 * (speed_val / 100)
            p[4] -= 8
            if 0 <= int(p[0]) < 8 and 0 <= int(p[1]) < 8 and p[4] > 0:
                np[xy(int(p[0]), int(p[1]))] = scale(wheel(p[5]), brightness * p[4] // 255)
                new_p.append(p)
        parts = new_p
        np.write()
        if check_stop(0.04): return


@anim("Torbellino")
def a_tornado():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (150 / (speed_val / 100))
        clear_matrix()
        for i in range(40):
            a = i * 0.4 + t
            r = (i * 0.2) % 5
            sx, sy = int(3.5 + r * math.cos(a)), int(3.5 + r * math.sin(a) * 0.6)
            if 0 <= sx < 8 and 0 <= sy < 8:
                np[xy(sx, sy)] = scale(wheel(int(i * 7 + t * 40) % 256), brightness)
        np.write()
        if check_stop(0.04): return


@anim("Ondas")
def a_ripple():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (200 / (speed_val / 100))
        clear_matrix()
        for r in range(1, 7):
            for y in range(8):
                for x in range(8):
                    d = math.sqrt((x - 3.5) ** 2 + (y - 3.5) ** 2)
                    if abs(d - r) < 0.6 and r % 2 == int(t * 3) % 2:
                        np[xy(x, y)] = scale(wheel(int(r * 40 + t * 50) % 256), brightness)
        np.write()
        if check_stop(0.05): return


@anim("Ajedrez")
def a_checkers():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (400 / (speed_val / 100))
        off = int(t) % 4
        clear_matrix()
        for y in range(8):
            for x in range(8):
                if (x + y + off) % 4 < 2:
                    np[xy(x, y)] = scale(wheel(int((x + y) * 32 + t * 40) % 256), brightness)
        np.write()
        if check_stop(0.15): return


@anim("Escalera")
def a_stairs():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (200 / (speed_val / 100))
        clear_matrix()
        for i in range(8):
            row = (int(t) + i) % 8
            for x in range(i + 1):
                if x < 8:
                    np[xy(x, row)] = scale(wheel(int(i * 32 + t * 20) % 256), brightness)
        np.write()
        if check_stop(0.1): return


@anim("Pacman")
def a_pacman():
    global stop_flag
    stop_flag = False
    pac = [3, 3, 1, 0]
    dots = [(x, y) for x in range(8) for y in range(8) if not (x == 3 and y == 3)]
    while not stop_flag and dots:
        clear_matrix()
        for dx, dy in dots:
            np[xy(dx, dy)] = scale((40, 40, 40), brightness)
        np[xy(pac[0], pac[1])] = scale((255, 255, 0), brightness)
        if (pac[0], pac[1]) in dots:
            dots.remove((pac[0], pac[1]))
        nx, ny = pac[0] + pac[2], pac[1] + pac[3]
        if nx < 0 or nx >= 8 or ny < 0 or ny >= 8 or random.random() < 0.1:
            dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
            random.shuffle(dirs)
            for dx2, dy2 in dirs:
                ttx, tty = pac[0] + dx2, pac[1] + dy2
                if 0 <= ttx < 8 and 0 <= tty < 8:
                    pac[2], pac[3] = dx2, dy2
                    nx, ny = ttx, tty
                    break
        pac[0], pac[1] = nx, ny
        np.write()
        if check_stop(0.15 / (speed_val / 100)): return
    if not stop_flag:
        clear_matrix()
        for y in range(8):
            for x in range(8):
                if random.random() < 0.3:
                    np[xy(x, y)] = scale(wheel(random.randint(0, 255)), brightness)
        np.write()
        check_stop(2)


@anim("Game of Life")
def a_life():
    global stop_flag
    stop_flag = False
    grid = [[random.randint(0, 1) for _ in range(8)] for _ in range(8)]
    prev = None
    for _ in range(12):
        if stop_flag: return
        for y in range(8):
            for x in range(8):
                np[xy(x, y)] = scale((0, 255, 100), brightness) if grid[y][x] else (0, 0, 0)
        np.write()
        new_grid = [row[:] for row in grid]
        for y in range(8):
            for x in range(8):
                n = sum(grid[(y + dy) % 8][(x + dx) % 8]
                        for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy != 0 or dx != 0)
                new_grid[y][x] = 1 if (grid[y][x] and 2 <= n <= 3) or (not grid[y][x] and n == 3) else 0
        if new_grid == prev: break
        prev = new_grid
        grid = new_grid
        if check_stop(0.35 / (speed_val / 100)): return


@anim("Navidad")
def a_xmas():
    global stop_flag
    stop_flag = False
    tree = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
        [0, 0, 0, 1, 1, 0, 0, 0],
    ]
    while not stop_flag:
        for y in range(8):
            for x in range(8):
                if tree[y][x]:
                    np[xy(x, y)] = scale((255, 255, 0), brightness) if y == 2 else scale((0, 200 + random.randint(0, 55), 0), brightness)
        np.write()
        if check_stop(0.3): return


@anim("Pixel x Pixel")
def a_pixel():
    global stop_flag
    stop_flag = False
    pxls = [(x, y) for y in range(8) for x in range(8)]
    random.shuffle(pxls)
    colors = [wheel(random.randint(0, 255)) for _ in pxls]
    clear_matrix()
    for i, (x, y) in enumerate(pxls):
        if stop_flag: return
        np[xy(x, y)] = scale(colors[i], brightness)
        np.write()
        if check_stop(0.04 / (speed_val / 100)): return
    check_stop(2)


@anim("Sweep H")
def a_sweep_h():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (150 / (speed_val / 100))
        col = int(t) % 10 - 1
        clear_matrix()
        for x in range(8):
            for y in range(8):
                d = abs(x - col)
                if d < 4:
                    br_v = 255 - d * 70
                    np[xy(x, y)] = scale((br_v, br_v, br_v), brightness)
        np.write()
        if check_stop(0.04): return


@anim("Sweep V")
def a_sweep_v():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (150 / (speed_val / 100))
        row = int(t) % 10 - 1
        clear_matrix()
        for y in range(8):
            for x in range(8):
                d = abs(y - row)
                if d < 4:
                    br_v = 255 - d * 70
                    np[xy(x, y)] = scale((br_v, br_v, br_v), brightness)
        np.write()
        if check_stop(0.04): return


@anim("Morse")
def a_morse():
    global stop_flag
    stop_flag = False
    msg = "MATRIX LED"
    mm = {'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
          'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
          'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
          'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
          'Y': '-.--', 'Z': '--..', ' ': ' '}
    while not stop_flag:
        for ch in msg + '  ':
            if stop_flag: return
            code = mm.get(ch.upper(), '')
            for sym in code:
                if stop_flag: return
                on_t = 0.25 if sym == '-' else 0.1
                for i in range(NUM_LEDS):
                    np[i] = scale(wheel(random.randint(0, 255)) if sym != ' ' else (0, 0, 0), brightness)
                np.write()
                if check_stop(on_t / (speed_val / 100)): return
                clear_matrix()
                if check_stop(0.1 / (speed_val / 100) if sym != ' ' else 0.2): return
            if check_stop(0.3 / (speed_val / 100)): return


@anim("Caos")
def a_chaos():
    global stop_flag
    stop_flag = False
    xs, ys = [0] * 64, [0] * 64
    dxs = [random.uniform(-0.5, 0.5) for _ in range(64)]
    dys = [random.uniform(-0.5, 0.5) for _ in range(64)]
    cols = [wheel(random.randint(0, 255)) for _ in range(64)]
    for i in range(64):
        xs[i] = random.uniform(0, 7)
        ys[i] = random.uniform(0, 7)
    while not stop_flag:
        clear_matrix()
        for i in range(64):
            xs[i] += dxs[i] * (speed_val / 100)
            ys[i] += dys[i] * (speed_val / 100)
            if xs[i] < 0 or xs[i] >= 7:
                dxs[i] = -dxs[i]
                xs[i] = max(0, min(7, xs[i]))
            if ys[i] < 0 or ys[i] >= 7:
                dys[i] = -dys[i]
                ys[i] = max(0, min(7, ys[i]))
            np[xy(int(xs[i]), int(ys[i]))] = scale(cols[i], brightness)
        np.write()
        if check_stop(0.04): return


@anim("Rebote")
def a_bounce():
    global stop_flag
    stop_flag = False
    x, y = 3.0, 3.0
    dx, dy = 0.3, 0.2
    color = wheel(random.randint(0, 255))
    trail = []
    while not stop_flag:
        x += dx * (speed_val / 100)
        y += dy * (speed_val / 100)
        if x <= 0 or x >= 7:
            dx = -dx; x = max(0, min(7, x)); color = wheel(random.randint(0, 255))
        if y <= 0 or y >= 7:
            dy = -dy; y = max(0, min(7, y)); color = wheel(random.randint(0, 255))
        trail.append((x, y, color))
        if len(trail) > 20: trail.pop(0)
        clear_matrix()
        for i, (tx, ty, tc) in enumerate(trail):
            br_v = i / len(trail)
            np[xy(int(tx), int(ty))] = scale((int(tc[0] * br_v), int(tc[1] * br_v), int(tc[2] * br_v)), brightness)
        np.write()
        if check_stop(0.04 / (speed_val / 100)): return


@anim("Ruleta")
def a_roulette():
    global stop_flag
    stop_flag = False
    while not stop_flag:
        t = time.ticks_ms() / (120 / (speed_val / 100))
        clear_matrix()
        ang = (t * 50) % 360
        for y in range(8):
            for x in range(8):
                px, py = x - 3.5, y - 3.5
                a = (math.atan2(py, px) * 180 / math.pi + 180) % 360
                d2 = math.sqrt(px * px + py * py)
                if d2 <= 3.8:
                    seg = int(a / 45)
                    if int((ang + seg * 45) / 45) % 2:
                        np[xy(x, y)] = scale(wheel(seg * 32), brightness)
        np.write()
        if check_stop(0.06): return


# ===== MAIN =====

def main():
    global stop_flag, current_anim, connected, brightness, speed_val

    print("=" * 40)
    print("ESP32-C3 Matrix 8x8 - BLE Controller")
    print(f"{len(ANIMATIONS)} animaciones")
    print("=" * 40)

    clear_matrix()

    try:
        ble = init_ble()
    except Exception as e:
        print(f"BLE init error: {e}")
        return

    print(f"BLE: '{BLE_NAME}' listo. Esperando conexion...")

    # Idle: pulso azul cuando desconectado
    pulse = 0

    while True:
        if not connected:
            # Pulso azul de espera
            b = int(20 + 15 * math.sin(pulse * 0.1))
            for i in range(NUM_LEDS):
                np[i] = scale((0, 0, b), brightness)
            np.write()
            pulse += 1
            time.sleep(0.05)

        elif current_anim and not stop_flag:
            name = current_anim
            func = ANIMATIONS.get(name)
            if func:
                try:
                    func()
                except Exception as e:
                    print(f"Error en {name}: {e}")
                finally:
                    current_anim = None
        else:
            time.sleep(0.05)


if __name__ == "__main__":
    main()
