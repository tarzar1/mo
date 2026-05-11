# Diagnostico rapido - solo escanea I2C sin probar OLED
# Muestra solo la direccion I2C real

from machine import Pin, SoftI2C
import time, sys

time.sleep(1)

print("=== ESCANEO I2C RAPIDO ===")

pin_combos = [
    (8, 9),
    (6, 7),
    (5, 6),
    (4, 5),
    (2, 3),
    (21, 20),
    (3, 2),
    (7, 6),
    (9, 8),
]

found = []
for sda, scl in pin_combos:
    try:
        i2c = SoftI2C(sda=Pin(sda), scl=Pin(scl), freq=100000)
        devices = i2c.scan()
        if devices:
            print(f"SDA=GPIO{sda} SCL=GPIO{scl}  ->  {[hex(d) for d in devices]}")
            for d in devices:
                found.append((sda, scl, d))
    except Exception as e:
        print(f"SDA=GPIO{sda} SCL=GPIO{scl}  ->  Error: {e}")

print()
if found:
    print("DISPOSITIVOS ENCONTRADOS:")
    for sda, scl, addr in found:
        print(f"  SDA={sda} SCL={scl}  addr={hex(addr)}")
    # Tomar el primero
    sda, scl, addr = found[0]
    print(f"\nUSANDO: SDA={sda}, SCL={scl}, addr={hex(addr)}")
    print("Ahora probando OLED...")

    # Inicializar OLED de forma simple
    from framebuf import FrameBuffer, MONO_VLSB
    W, H = 72, 40

    i2c = SoftI2C(sda=Pin(sda), scl=Pin(scl), freq=400000)

    # Secuencia de inicializacion SSD1306 simple
    buf = bytearray(128 * (H // 8))

    def cmd(c):
        i2c.writeto(addr, b'\x00' + bytes([c]))

    try:
        # Display off
        cmd(0xAE)
        # Set clock div
        cmd(0xD5); cmd(0x80)
        # Set multiplex
        cmd(0xA8); cmd(H - 1)
        # Set display offset
        cmd(0xD3); cmd(0x00)
        # Set start line
        cmd(0x40)
        # Charge pump
        cmd(0x8D); cmd(0x14)
        # Set memory mode
        cmd(0x20); cmd(0x00)
        # Set segment remap (column 127 mapped to SEG0)
        cmd(0xA0 | 0x01)
        # COM scan direction
        cmd(0xC8)
        # COM pins
        cmd(0xDA); cmd(0x02)
        # Set contrast
        cmd(0x81); cmd(0xCF)
        # Set precharge
        cmd(0xD9); cmd(0xF1)
        # Set VCOMH
        cmd(0xDB); cmd(0x40)
        # Display on
        cmd(0xA4)
        cmd(0xA6)
        cmd(0xAF)

        print("OLED inicializado. Enviando datos de prueba...")

        # Dibujar en el framebuffer y enviar
        fb = FrameBuffer(buf, 128, H, MONO_VLSB)
        fb.fill(0)
        fb.text("OK", 0, 0)
        fb.text("ESP32-C3", 0, 12)
        fb.text("OLED!", 0, 24)

        # Enviar
        cmd(0x21); cmd(0); cmd(127)
        cmd(0x22); cmd(0); cmd(H // 8 - 1)
        i2c.writeto(addr, b'\x40' + buf[0:128 * (H // 8)])

        print("DATOS ENVIADOS. Deberias ver texto en pantalla.")
        print("Si no ves nada, posiblemente:")
        print("  - La resolucion no es 72x40")
        print("  - El OLED esta danado")
        print("  - El chip es SH1106, no SSD1306")

    except Exception as e:
        print(f"ERROR al inicializar OLED: {e}")

else:
    print("NINGUN DISPOSITIVO I2C ENCONTRADO")
    print("Revisa cableado VCC=3.3V GND=GND SDA SCK")

print("\n=== FIN ===")
