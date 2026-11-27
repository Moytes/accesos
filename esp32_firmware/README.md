# ESP32 QR Access Control — Firmware

## 📋 Requisitos de Hardware

| Componente | Descripción |
|------------|-------------|
| **ESP32 DevKit** | Cualquier placa ESP32 con WiFi |
| **GM65** | Módulo scanner QR (comunicación UART) |
| **LED Verde** | Indicador de acceso concedido |
| **LED Rojo** | Indicador de acceso denegado |
| **LED Azul** | Indicador de estado WiFi/servidor |
| **Buzzer** | Feedback auditivo |
| **Resistencias** | 220Ω para los LEDs |

## 🔌 Diagrama de Conexiones

```
ESP32           GM65
──────          ────
GPIO16 (RX2) ←── TX
GPIO17 (TX2) ──→ RX
5V           ──→ VCC
GND          ──→ GND

ESP32           LEDs / Buzzer
──────          ─────────────
GPIO25       ──→ LED Verde  (+ resistencia 220Ω → GND)
GPIO26       ──→ LED Rojo   (+ resistencia 220Ω → GND)
GPIO33       ──→ LED Azul   (+ resistencia 220Ω → GND)
GPIO27       ──→ Buzzer     (→ GND)
```

## ⚙️ Configuración

Antes de subir el firmware, edita estas constantes en `esp32_firmware.ino`:

```cpp
// WiFi
const char* WIFI_SSID      = "TU_RED_WIFI";
const char* WIFI_PASSWORD   = "TU_PASSWORD_WIFI";

// Servidor backend (.NET)
const char* SERVER_URL      = "http://TU_IP_SERVIDOR:5000";

// Identificador de la zona donde está instalado
const char* ZONE_ID         = "puerta-principal";
```

## 🚀 Compilar y Subir

### Opción 1: PlatformIO (recomendado)
```bash
# Instalar PlatformIO CLI
pip install platformio

# Compilar
pio run

# Subir al ESP32
pio run --target upload

# Monitor serial (debug)
pio device monitor
```

### Opción 2: Arduino IDE
1. Instalar ESP32 Board en Arduino IDE
2. Instalar librería: **ArduinoJson** (versión 7+)
3. Seleccionar Board: "ESP32 Dev Module"
4. Seleccionar puerto COM
5. Upload

## 📡 Flujo de Funcionamiento

```
1. BOOT     → Animación de LEDs
2. WiFi     → Conecta al WiFi (LED azul parpadea)
3. PING     → GET /api/Ping (verifica servidor)
4. READY    → LED azul fijo = listo
5. SCAN     → GM65 lee QR automáticamente
6. VALIDAR  → POST /api/accesos/validar { codigoQr, zoneId }
7. RESULT   → LED verde + beep largo   = ACCESO
              LED rojo  + 3 beeps      = DENEGADO
8. ESPERA   → 3 seg cooldown → vuelve al paso 5
```

## 🔍 Debug (Monitor Serial)

El firmware imprime logs detallados por Serial a 115200 baud:

```
=============================================
  ESP32 QR Access Control - Iniciando...
=============================================
[GM65] Puerto serial inicializado
[GM65] RX=16, TX=17, Baud=9600
[WIFI] Conectando a 'MiRedWiFi'...........
[WIFI] ✔ Conectado!
[WIFI] IP: 192.168.1.100
[WIFI] RSSI: -45 dBm
[PING] Servidor OK (HTTP 200): {"success":true,"message":"Servidor encendido"}
[SERVIDOR] Conexión exitosa con el backend
=============================================
  Sistema listo. Esperando códigos QR...
=============================================

─────────────────────────────────────────
[QR] Código leído: abc123-1727193600000
[HTTP] POST http://192.168.1.50:5000/api/accesos/validar
[HTTP] Body: {"codigoQr":"abc123-1727193600000","zoneId":"puerta-principal"}
[HTTP] Respuesta (HTTP 200): {"success":true,"message":"Acceso concedido exitosamente"}
[RESULTADO] success=true, mensaje=Acceso concedido exitosamente
[ACCESO] ✔ CONCEDIDO
```
