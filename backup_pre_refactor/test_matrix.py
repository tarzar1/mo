# Test simple de matrix WS2812B 8x8
# Todos los LEDs en rojo para verificar conexion

from machine import Pin
import neopixel
import time

LED_PIN = Pin(2)   # Cambia a 3, 6, 7, 10 si no funciona
NUM_LEDS = 64

np = neopixel.NeoPixel(LED_PIN, NUM_LEDS)

print("Encendiendo todos los LEDs en ROJO...")
for i in range(NUM_LEDS):
    np[i] = (50, 0, 0)  # Rojo a 20% brillo
np.write()
print("OK - Deberias ver todos rojos")
print("Si no ves nada:")
print("  1. Revisa que V+ tenga 5V y V- este a GND")
print("  2. Cambia LED_PIN a otro GPIO (prueba 3, 6, 7, 10)")
print("  3. Algunas matrix usan orden de pines diferente")
print("  4. Prueba con fuente externa 5V (no solo USB del ESP32)")
time.sleep(3)

# Apagar
for i in range(NUM_LEDS):
    np[i] = (0, 0, 0)
np.write()
print("Apagado.")
