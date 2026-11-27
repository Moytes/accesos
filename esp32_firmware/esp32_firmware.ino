/*
 * ============================================================
 *  FIRMWARE ESP32 — Sistema de Control de Acceso con QR
 *  Módulo Scanner: GM65 (comunicación serial UART)
 *  Backend: ASP.NET Core → POST /api/accesos/validar
 * ============================================================
 *
 *  Conexiones ESP32 ↔ GM65:
 *    ESP32 GPIO16 (RX2) ← GM65 TX
 *    ESP32 GPIO17 (TX2) → GM65 RX
 *    ESP32 5V           → GM65 VCC
 *    ESP32 GND          → GM65 GND
 *
 *  Conexiones ESP32 ↔ Indicadores:
 *    GPIO 25 → LED Verde  (acceso concedido)
 *    GPIO 26 → LED Rojo   (acceso denegado)
 *    GPIO 27 → Buzzer
 *    GPIO 33 → LED Azul   (estado WiFi/conexión)
 *
 *  Serial Monitor: 115200 baud
 *  GM65 UART:      9600 baud
 * ============================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ===================== CONFIGURACIÓN WiFi =====================
const char* WIFI_SSID     = "TU_RED_WIFI";                   // ← Cambia esto
const char* WIFI_PASSWORD  = "TU_PASSWORD_WIFI";              // ← Cambia esto

// ===================== CONFIGURACIÓN SERVIDOR =================
const char* SERVER_URL       = "https://qrgodimoi-gbc4fpfba7fgexfc.westus-01.azurewebsites.net";
const char* ENDPOINT_VALIDAR = "/api/accesos/validar";
const char* ENDPOINT_PING    = "/api/Ping";
const char* API_KEY          = "CAMBIA_TU_API_KEY_IOT";        // ← Debe coincidir con IoT__ApiKey en Azure

// ===================== CONFIGURACIÓN ZONA =====================
const char* ZONE_ID = "puerta-principal";  // ← Cambia según la ubicación

// ===================== PINES HARDWARE =========================
#define GM65_RX_PIN   16   // ESP32 RX2 ← GM65 TX
#define GM65_TX_PIN   17   // ESP32 TX2 → GM65 RX
#define GM65_BAUD     9600 // Baudrate del GM65

#define LED_VERDE     25
#define LED_ROJO      26
#define BUZZER_PIN    27
#define LED_ESTADO    33   // LED azul de estado

// ===================== TIEMPOS ================================
#define WIFI_TIMEOUT_MS         15000
#define WIFI_RECONNECT_DELAY_MS 5000
#define HTTP_TIMEOUT_MS         8000
#define PING_INTERVAL_MS        30000
#define QR_COOLDOWN_MS          3000
#define LED_FEEDBACK_MS         2000
#define DEBOUNCE_MS             1500

// ===================== VARIABLES GLOBALES =====================
String ultimoQrLeido = "";
unsigned long ultimaLecturaMs = 0;
unsigned long ultimoPingMs = 0;
bool servidorOnline = false;
String bufferSerial = "";
unsigned long contadorEscaneos = 0;    // Total de QRs escaneados
unsigned long contadorAccesos = 0;     // Accesos concedidos
unsigned long contadorDenegados = 0;   // Accesos denegados
unsigned long contadorErrores = 0;     // Errores de red/servidor

// Cliente HTTPS seguro
WiFiClientSecure secureClient;

// ===================== PROTOTIPOS =============================
void conectarWiFi();
bool verificarServidor();
String leerQrGM65();
bool validarQrEnServidor(const String& codigoQr);
void indicarAccesoConcedido();
void indicarAccesoDenegado();
void indicarError();
void beep(int duracionMs, int cantidad);
void apagarIndicadores();
String obtenerUptime();
void diagnosticarGM65();

// Control de monitoreo de bytes crudos del GM65
unsigned long ultimoReporteGM65 = 0;
unsigned long bytesRecibidosGM65 = 0;

// =============================================================
//                          SETUP
// =============================================================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════════════╗");
  Serial.println("║         ESP32 QR ACCESS CONTROL — Sistema de Accesos        ║");
  Serial.println("║                Modulo Scanner: GM65 (UART)                  ║");
  Serial.println("╚═══════════════════════════════════════════════════════════════╝");
  Serial.println();

  // ─── Info del chip ───
  Serial.println("┌─── INFORMACION DEL HARDWARE ─────────────────────────────────┐");
  Serial.printf("│  Chip:          ESP32 Rev %d\n", ESP.getChipRevision());
  Serial.printf("│  CPU Freq:      %d MHz\n", ESP.getCpuFreqMHz());
  Serial.printf("│  Flash:         %d KB\n", ESP.getFlashChipSize() / 1024);
  Serial.printf("│  RAM libre:     %d bytes\n", ESP.getFreeHeap());
  Serial.printf("│  SDK:           %s\n", ESP.getSdkVersion());
  Serial.println("└─────────────────────────────────────────────────────────────┘");
  Serial.println();

  // ─── Puertos Seriales y Baudrates ───
  Serial.println("┌─── PUERTOS SERIALES / BAUDRATES ─────────────────────────────┐");
  Serial.printf("│  Serial0 (USB/Monitor):   115200 baud  ← Estas leyendo aqui\n");
  Serial.printf("│  Serial2 (GM65 Scanner):  %d baud\n", GM65_BAUD);
  Serial.printf("│    ├─ ESP32 RX2 (←GM65):  GPIO %d\n", GM65_RX_PIN);
  Serial.printf("│    ├─ ESP32 TX2 (→GM65):  GPIO %d\n", GM65_TX_PIN);
  Serial.println("│    └─ Formato:           8N1 (8 data, No parity, 1 stop)");
  Serial.println("└─────────────────────────────────────────────────────────────┘");

  // Inicializar Serial2 para GM65
  Serial2.begin(GM65_BAUD, SERIAL_8N1, GM65_RX_PIN, GM65_TX_PIN);
  Serial.println("[SERIAL2] ✔ Puerto GM65 inicializado OK");
  Serial.println();

  // ─── Diagnóstico GM65 ───
  diagnosticarGM65();

  // ─── Pines de salida ───
  Serial.println("┌─── PINES DE SALIDA (GPIO) ──────────────────────────────────┐");
  Serial.printf("│  LED Verde   (Acceso OK):     GPIO %d\n", LED_VERDE);
  Serial.printf("│  LED Rojo    (Denegado):      GPIO %d\n", LED_ROJO);
  Serial.printf("│  LED Azul    (Estado WiFi):   GPIO %d\n", LED_ESTADO);
  Serial.printf("│  Buzzer      (Audio):         GPIO %d\n", BUZZER_PIN);
  Serial.println("└─────────────────────────────────────────────────────────────┘");

  pinMode(LED_VERDE, OUTPUT);
  pinMode(LED_ROJO, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_ESTADO, OUTPUT);
  apagarIndicadores();
  Serial.println("[GPIO] ✔ Todos los pines configurados como OUTPUT");
  Serial.println();

  // ─── Animación de inicio ───
  Serial.println("[BOOT] Ejecutando test de LEDs...");
  for (int i = 0; i < 3; i++) {
    digitalWrite(LED_VERDE, HIGH);
    Serial.printf("[BOOT]   LED Verde ON  (GPIO %d)\n", LED_VERDE);
    delay(100);
    digitalWrite(LED_VERDE, LOW);
    digitalWrite(LED_ROJO, HIGH);
    Serial.printf("[BOOT]   LED Rojo ON   (GPIO %d)\n", LED_ROJO);
    delay(100);
    digitalWrite(LED_ROJO, LOW);
    digitalWrite(LED_ESTADO, HIGH);
    Serial.printf("[BOOT]   LED Azul ON   (GPIO %d)\n", LED_ESTADO);
    delay(100);
    digitalWrite(LED_ESTADO, LOW);
  }
  Serial.println("[BOOT] ✔ Test de LEDs completado");
  Serial.println();

  // ─── HTTPS ───
  secureClient.setInsecure();
  Serial.println("[HTTPS] ✔ Cliente WiFiClientSecure configurado (sin verificacion cert)");
  Serial.println();

  // ─── Config de red ───
  Serial.println("┌─── CONFIGURACION DE RED ─────────────────────────────────────┐");
  Serial.printf("│  SSID:          %s\n", WIFI_SSID);
  Serial.println("│  Password:      ********");
  Serial.printf("│  Servidor:      %s\n", SERVER_URL);
  Serial.printf("│  EP Ping:       %s%s\n", SERVER_URL, ENDPOINT_PING);
  Serial.printf("│  EP Validar:    %s%s\n", SERVER_URL, ENDPOINT_VALIDAR);
  Serial.printf("│  Zona ID:       %s\n", ZONE_ID);
  Serial.println("│  Protocolo:     HTTPS (TLS)");
  Serial.println("└─────────────────────────────────────────────────────────────┘");
  Serial.println();

  // ─── Conectar WiFi ───
  conectarWiFi();

  // ─── Verificar servidor ───
  Serial.println();
  Serial.println("[SERVIDOR] Verificando backend en Azure...");
  Serial.printf("[SERVIDOR] GET %s%s\n", SERVER_URL, ENDPOINT_PING);
  if (verificarServidor()) {
    servidorOnline = true;
    Serial.println("[SERVIDOR] ✔ Backend ONLINE — Conexion exitosa con Azure");
    beep(100, 2);
  } else {
    servidorOnline = false;
    Serial.println("[SERVIDOR] ✘ Backend OFFLINE — No se pudo contactar");
    Serial.println("[SERVIDOR]   Verifica que el App Service este corriendo en Azure");
    indicarError();
  }

  // ─── Tiempos ───
  Serial.println();
  Serial.println("┌─── TIEMPOS CONFIGURADOS ─────────────────────────────────────┐");
  Serial.printf("│  Timeout WiFi:         %5d ms  (%d seg)\n", WIFI_TIMEOUT_MS, WIFI_TIMEOUT_MS/1000);
  Serial.printf("│  Timeout HTTP:         %5d ms  (%d seg)\n", HTTP_TIMEOUT_MS, HTTP_TIMEOUT_MS/1000);
  Serial.printf("│  Ping al servidor:     %5d ms  (%d seg)\n", PING_INTERVAL_MS, PING_INTERVAL_MS/1000);
  Serial.printf("│  Cooldown entre QR:    %5d ms  (%d seg)\n", QR_COOLDOWN_MS, QR_COOLDOWN_MS/1000);
  Serial.printf("│  Debounce duplicados:  %5d ms\n", DEBOUNCE_MS);
  Serial.printf("│  Feedback LEDs:        %5d ms  (%d seg)\n", LED_FEEDBACK_MS, LED_FEEDBACK_MS/1000);
  Serial.println("└─────────────────────────────────────────────────────────────┘");

  Serial.println();
  Serial.printf("[MEMORIA] RAM libre despues del setup: %d bytes\n", ESP.getFreeHeap());
  Serial.println();
  Serial.println("╔═══════════════════════════════════════════════════════════════╗");
  Serial.println("║   ✔ SISTEMA LISTO — Esperando codigos QR...                 ║");
  Serial.println("║   Acerque un codigo QR al modulo GM65 para escanear         ║");
  Serial.println("║   Serial Monitor: 115200 baud | GM65: 9600 baud            ║");
  Serial.println("╚═══════════════════════════════════════════════════════════════╝");
  Serial.println();
}

// =============================================================
//                        LOOP PRINCIPAL
// =============================================================
void loop() {
  // --- 1. Verificar WiFi ---
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println();
    Serial.println("[WIFI] ⚠ Conexion perdida!");
    Serial.printf("[WIFI]   Estado WiFi: %d\n", WiFi.status());
    Serial.println("[WIFI]   Intentando reconectar...");
    digitalWrite(LED_ESTADO, LOW);
    conectarWiFi();
  }

  // --- 2. Ping periódico al servidor ---
  if (millis() - ultimoPingMs > PING_INTERVAL_MS) {
    Serial.printf("[PING] Verificacion periodica (cada %d seg)...\n", PING_INTERVAL_MS/1000);
    servidorOnline = verificarServidor();
    ultimoPingMs = millis();

    if (servidorOnline) {
      digitalWrite(LED_ESTADO, HIGH);
    } else {
      digitalWrite(LED_ESTADO, LOW);
      contadorErrores++;
      Serial.println("[PING] ✘ Servidor no responde");
      Serial.printf("[PING]   Errores acumulados: %lu\n", contadorErrores);
    }
  }

  // --- 3. Monitoreo de datos crudos del GM65 ---
  // Reportar cada 10 seg si se están recibiendo bytes o no
  if (millis() - ultimoReporteGM65 > 10000) {
    ultimoReporteGM65 = millis();
    int bytesDisponibles = Serial2.available();
    if (bytesDisponibles > 0) {
      Serial.printf("[GM65] 📡 Hay %d bytes esperando en Serial2\n", bytesDisponibles);
    } else if (bytesRecibidosGM65 == 0) {
      Serial.printf("[GM65] ⚠ Sin datos del GM65 aun. Uptime: %s\n", obtenerUptime().c_str());
      Serial.println("[GM65]   Verifica: 1) Cableado TX/RX  2) Alimentacion 5V  3) Baudrate");
    }
  }

  // --- 4. Leer QR del GM65 ---
  String qrLeido = leerQrGM65();

  if (qrLeido.length() > 0) {
    // Debounce
    if (qrLeido == ultimoQrLeido && (millis() - ultimaLecturaMs < DEBOUNCE_MS)) {
      Serial.println("[GM65] ⚠ QR duplicado detectado (debounce), ignorando...");
      return;
    }

    ultimoQrLeido = qrLeido;
    ultimaLecturaMs = millis();
    contadorEscaneos++;

    Serial.println();
    Serial.println("╔═══════════════════════════════════════════════════════════════╗");
    Serial.println("║                    QR ESCANEADO                             ║");
    Serial.println("╚═══════════════════════════════════════════════════════════════╝");
    Serial.printf("[GM65] Codigo leido:    %s\n", qrLeido.c_str());
    Serial.printf("[GM65] Longitud:        %d caracteres\n", qrLeido.length());
    Serial.printf("[GM65] Escaneo #:       %lu\n", contadorEscaneos);
    Serial.printf("[GM65] Recibido por:    Serial2 (UART) a %d baud\n", GM65_BAUD);
    Serial.printf("[GM65] Uptime:          %s\n", obtenerUptime().c_str());
    Serial.printf("[WIFI] Estado:          %s (RSSI: %d dBm)\n",
                  WiFi.status() == WL_CONNECTED ? "Conectado" : "Desconectado",
                  WiFi.RSSI());
    Serial.printf("[WIFI] IP local:        %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("[MEMORIA] RAM libre:    %d bytes\n", ESP.getFreeHeap());
    Serial.println("─────────────────────────────────────────────────────────────");

    // Verificar servidor
    if (!servidorOnline) {
      contadorErrores++;
      Serial.println("[ERROR] ✘ Servidor OFFLINE — No se puede validar el QR");
      Serial.printf("[ERROR]   URL servidor: %s\n", SERVER_URL);
      Serial.printf("[ERROR]   Errores acumulados: %lu\n", contadorErrores);
      Serial.println("[ERROR]   Accion: Reintentando ping...");
      servidorOnline = verificarServidor();
      if (!servidorOnline) {
        indicarError();
        Serial.println("[ERROR]   Servidor sigue offline. QR no procesado.");
        return;
      }
      Serial.println("[ERROR]   ✔ Servidor recuperado! Continuando...");
    }

    // --- 4. Validar QR en el servidor ---
    Serial.println("[HTTP] Enviando QR al backend para validacion...");
    unsigned long inicioHttp = millis();
    bool accesoConcedido = validarQrEnServidor(qrLeido);
    unsigned long tiempoHttp = millis() - inicioHttp;

    Serial.printf("[HTTP] Tiempo de respuesta: %lu ms\n", tiempoHttp);
    Serial.println("─────────────────────────────────────────────────────────────");

    if (accesoConcedido) {
      contadorAccesos++;
      indicarAccesoConcedido();
    } else {
      contadorDenegados++;
      indicarAccesoDenegado();
    }

    // Resumen de estadísticas
    Serial.println();
    Serial.println("┌─── ESTADISTICAS DE SESION ──────────────────────────────────┐");
    Serial.printf("│  Total escaneos:     %lu\n", contadorEscaneos);
    Serial.printf("│  Accesos OK:         %lu\n", contadorAccesos);
    Serial.printf("│  Accesos denegados:  %lu\n", contadorDenegados);
    Serial.printf("│  Errores red:        %lu\n", contadorErrores);
    Serial.printf("│  Uptime:             %s\n", obtenerUptime().c_str());
    Serial.println("└─────────────────────────────────────────────────────────────┘");

    // Cooldown
    delay(QR_COOLDOWN_MS);
    apagarIndicadores();
    Serial.println();
    Serial.println("[SISTEMA] ✔ Listo para siguiente lectura. Esperando QR...");
    Serial.println();
  }
}

// =============================================================
//                    CONEXIÓN WiFi
// =============================================================
void conectarWiFi() {
  Serial.println("[WIFI] ────────────────────────────────────────────");
  Serial.printf("[WIFI] Conectando a: '%s'\n", WIFI_SSID);
  Serial.println("[WIFI] Modo: STA (Station)");
  Serial.println("[WIFI] Esperando conexion...");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long inicioMs = millis();
  int intentos = 0;

  while (WiFi.status() != WL_CONNECTED) {
    digitalWrite(LED_ESTADO, !digitalRead(LED_ESTADO));
    delay(500);
    intentos++;
    Serial.printf("[WIFI]   Intento %d... (estado: %d)\n", intentos, WiFi.status());

    if (millis() - inicioMs > WIFI_TIMEOUT_MS) {
      Serial.println("[WIFI] ✘ Timeout alcanzado!");
      Serial.printf("[WIFI]   Tiempo: %lu ms | Intentos: %d\n", millis() - inicioMs, intentos);
      Serial.printf("[WIFI]   Reintentando en %d seg...\n", WIFI_RECONNECT_DELAY_MS/1000);
      digitalWrite(LED_ESTADO, LOW);
      WiFi.disconnect();
      delay(WIFI_RECONNECT_DELAY_MS);

      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      inicioMs = millis();
      intentos = 0;
    }
  }

  unsigned long tiempoConexion = millis() - inicioMs;
  Serial.println("[WIFI] ────────────────────────────────────────────");
  Serial.println("[WIFI] ✔ CONECTADO EXITOSAMENTE!");
  Serial.printf("[WIFI]   SSID:            %s\n", WiFi.SSID().c_str());
  Serial.printf("[WIFI]   IP local:        %s\n", WiFi.localIP().toString().c_str());
  Serial.printf("[WIFI]   Gateway:         %s\n", WiFi.gatewayIP().toString().c_str());
  Serial.printf("[WIFI]   DNS:             %s\n", WiFi.dnsIP().toString().c_str());
  Serial.printf("[WIFI]   MAC:             %s\n", WiFi.macAddress().c_str());
  Serial.printf("[WIFI]   RSSI:            %d dBm", WiFi.RSSI());
  // Indicador de calidad de señal
  int rssi = WiFi.RSSI();
  if (rssi > -50)       Serial.println(" (Excelente)");
  else if (rssi > -60)  Serial.println(" (Buena)");
  else if (rssi > -70)  Serial.println(" (Regular)");
  else                   Serial.println(" (Debil!)");
  Serial.printf("[WIFI]   Canal:           %d\n", WiFi.channel());
  Serial.printf("[WIFI]   Tiempo conexion: %lu ms\n", tiempoConexion);
  Serial.println("[WIFI] ────────────────────────────────────────────");

  digitalWrite(LED_ESTADO, HIGH);
}

// =============================================================
//                 VERIFICAR SERVIDOR (PING)
// =============================================================
bool verificarServidor() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[PING] ✘ Sin WiFi, no se puede hacer ping");
    return false;
  }

  HTTPClient http;
  String url = String(SERVER_URL) + ENDPOINT_PING;

  Serial.printf("[PING] GET %s\n", url.c_str());
  http.begin(secureClient, url);
  http.setTimeout(HTTP_TIMEOUT_MS);

  unsigned long inicioPing = millis();
  int httpCode = http.GET();
  unsigned long tiempoPing = millis() - inicioPing;

  if (httpCode == 200) {
    String respuesta = http.getString();
    Serial.printf("[PING] ✔ HTTP %d — %s (%lu ms)\n", httpCode, respuesta.c_str(), tiempoPing);
    http.end();
    return true;
  }

  Serial.printf("[PING] ✘ HTTP %d (%lu ms)\n", httpCode, tiempoPing);
  if (httpCode < 0) {
    Serial.printf("[PING]   Error: %s\n", http.errorToString(httpCode).c_str());
  }
  http.end();
  return false;
}

// =============================================================
//                LECTURA QR DEL GM65 (UART)
// =============================================================
String leerQrGM65() {
  while (Serial2.available()) {
    char c = Serial2.read();
    bytesRecibidosGM65++;

    // Mostrar cada byte crudo recibido (solo los primeros 200 bytes para no saturar)
    if (bytesRecibidosGM65 <= 200) {
      if (c >= 32 && c <= 126) {
        Serial.printf("[GM65 RAW] Byte #%lu: 0x%02X '%c'\n", bytesRecibidosGM65, (uint8_t)c, c);
      } else {
        Serial.printf("[GM65 RAW] Byte #%lu: 0x%02X (control)\n", bytesRecibidosGM65, (uint8_t)c);
      }
    }

    if (c == '\n' || c == '\r') {
      if (bufferSerial.length() > 0) {
        String resultado = bufferSerial;
        resultado.trim();
        bufferSerial = "";
        Serial.printf("[GM65] ✔ Linea completa recibida (%d chars, %lu bytes totales)\n",
                      resultado.length(), bytesRecibidosGM65);
        return resultado;
      }
    } else {
      bufferSerial += c;

      if (bufferSerial.length() > 512) {
        Serial.println("[GM65] ⚠ Buffer overflow (>512 bytes), limpiando...");
        bufferSerial = "";
      }
    }
  }

  return "";
}

// =============================================================
//             VALIDAR QR EN EL SERVIDOR (.NET)
// =============================================================
bool validarQrEnServidor(const String& codigoQr) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[HTTP] ✘ Sin conexion WiFi — No se puede enviar");
    return false;
  }

  HTTPClient http;
  String url = String(SERVER_URL) + ENDPOINT_VALIDAR;

  http.begin(secureClient, url);
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Api-Key", API_KEY);

  // Construir JSON
  JsonDocument doc;
  doc["codigoQr"] = codigoQr;
  doc["zoneId"] = ZONE_ID;

  String jsonBody;
  serializeJson(doc, jsonBody);

  Serial.printf("[HTTP] ─── REQUEST ────────────────────────────────\n");
  Serial.printf("[HTTP] POST %s\n", url.c_str());
  Serial.printf("[HTTP] Content-Type: application/json\n");
  Serial.printf("[HTTP] Body: %s\n", jsonBody.c_str());
  Serial.printf("[HTTP] Timeout: %d ms\n", HTTP_TIMEOUT_MS);
  Serial.printf("[HTTP] ───────────────────────────────────────────\n");

  int httpCode = http.POST(jsonBody);

  Serial.printf("[HTTP] ─── RESPONSE ───────────────────────────────\n");

  if (httpCode > 0) {
    String respuesta = http.getString();
    Serial.printf("[HTTP] Status: HTTP %d %s\n", httpCode,
                  httpCode == 200 ? "OK" : httpCode == 400 ? "Bad Request" : "Otro");
    Serial.printf("[HTTP] Body:   %s\n", respuesta.c_str());

    JsonDocument respDoc;
    DeserializationError error = deserializeJson(respDoc, respuesta);

    if (error) {
      Serial.printf("[HTTP] ✘ Error parseando JSON: %s\n", error.c_str());
      http.end();
      return false;
    }

    bool success = respDoc["success"] | false;
    const char* mensaje = respDoc["message"] | "Sin mensaje";
    const char* tipoAcceso = respDoc["tipo"] | "entrada";

    if (success) {
      Serial.printf("[HTTP] ✔ RESULTADO: ACCESO CONCEDIDO (%s)\n", tipoAcceso);
    } else {
      Serial.printf("[HTTP] ✘ RESULTADO: ACCESO DENEGADO\n");
    }
    Serial.printf("[HTTP] Mensaje: %s\n", mensaje);
    Serial.printf("[HTTP] ───────────────────────────────────────────\n");

    http.end();
    return success;
  }

  Serial.printf("[HTTP] ✘ Error de conexion: %d\n", httpCode);
  Serial.printf("[HTTP] Descripcion: %s\n", http.errorToString(httpCode).c_str());
  Serial.printf("[HTTP] ───────────────────────────────────────────\n");
  http.end();
  return false;
}

// =============================================================
//                  INDICADORES (LEDs + Buzzer)
// =============================================================

void indicarAccesoConcedido() {
  Serial.println();
  Serial.println("[ACCESO] ═══════════════════════════════════════");
  Serial.println("[ACCESO]  ✔✔✔  ACCESO CONCEDIDO  ✔✔✔");
  Serial.printf("[ACCESO]  LED Verde ON (GPIO %d) + Buzzer 500ms\n", LED_VERDE);
  Serial.println("[ACCESO] ═══════════════════════════════════════");
  apagarIndicadores();

  digitalWrite(LED_VERDE, HIGH);
  beep(500, 1);
  delay(LED_FEEDBACK_MS);
}

void indicarAccesoDenegado() {
  Serial.println();
  Serial.println("[ACCESO] ═══════════════════════════════════════");
  Serial.println("[ACCESO]  ✘✘✘  ACCESO DENEGADO  ✘✘✘");
  Serial.printf("[ACCESO]  LED Rojo ON (GPIO %d) + Buzzer 3x150ms\n", LED_ROJO);
  Serial.println("[ACCESO] ═══════════════════════════════════════");
  apagarIndicadores();

  digitalWrite(LED_ROJO, HIGH);
  beep(150, 3);
  delay(LED_FEEDBACK_MS);
}

void indicarError() {
  Serial.println("[ERROR] Indicador visual de error activado");
  Serial.printf("[ERROR]   LED Rojo parpadeando (GPIO %d) + Buzzer\n", LED_ROJO);
  apagarIndicadores();

  for (int i = 0; i < 5; i++) {
    digitalWrite(LED_ROJO, HIGH);
    digitalWrite(BUZZER_PIN, HIGH);
    delay(100);
    digitalWrite(LED_ROJO, LOW);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }
}

void beep(int duracionMs, int cantidad) {
  for (int i = 0; i < cantidad; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(duracionMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < cantidad - 1) {
      delay(100);
    }
  }
}

void apagarIndicadores() {
  digitalWrite(LED_VERDE, LOW);
  digitalWrite(LED_ROJO, LOW);
  digitalWrite(BUZZER_PIN, LOW);
}

// =============================================================
//                    UTILIDADES
// =============================================================
String obtenerUptime() {
  unsigned long seg = millis() / 1000;
  unsigned long min = seg / 60;
  unsigned long hr = min / 60;
  seg %= 60;
  min %= 60;

  char buf[20];
  sprintf(buf, "%02lu:%02lu:%02lu", hr, min, seg);
  return String(buf);
}

// =============================================================
//            DIAGNÓSTICO GM65 (al arrancar)
// =============================================================
void diagnosticarGM65() {
  Serial.println("┌─── DIAGNOSTICO GM65 ──────────────────────────────────────────┐");
  Serial.printf("│  Puerto:      Serial2 (UART2)\n");
  Serial.printf("│  Baudrate:    %d baud\n", GM65_BAUD);
  Serial.printf("│  RX (←GM65):  GPIO %d\n", GM65_RX_PIN);
  Serial.printf("│  TX (→GM65):  GPIO %d\n", GM65_TX_PIN);
  Serial.println("│");

  // Limpiar buffer por si hay basura
  while (Serial2.available()) Serial2.read();

  // Enviar comando de activación al GM65
  // El GM65 responde a comandos seriales con prefijo 0x7E 0x00
  // Comando: Activar modo escaneo continuo
  Serial.println("│  [1/3] Enviando comando de activacion al GM65...");

  // Comando GM65: Activar lectura (trigger scan)
  // Protocolo: 0x7E 0x00 0x08 0x01 0x00 0x02 0xAB 0xCD
  uint8_t cmdTrigger[] = {0x7E, 0x00, 0x08, 0x01, 0x00, 0x02, 0xAB, 0xCD};
  Serial2.write(cmdTrigger, sizeof(cmdTrigger));
  Serial.println("│         Comando trigger enviado (8 bytes)");
  Serial.print("│         HEX: ");
  for (int i = 0; i < sizeof(cmdTrigger); i++) {
    Serial.printf("0x%02X ", cmdTrigger[i]);
  }
  Serial.println();

  // Esperar respuesta del GM65 (2 segundos)
  Serial.println("│");
  Serial.println("│  [2/3] Esperando respuesta del GM65 (2 seg)...");

  unsigned long espera = millis();
  int bytesRecibidos = 0;

  while (millis() - espera < 2000) {
    if (Serial2.available()) {
      uint8_t b = Serial2.read();
      bytesRecibidos++;
      if (bytesRecibidos <= 20) {
        Serial.printf("│         Byte recibido #%d: 0x%02X", bytesRecibidos, b);
        if (b >= 32 && b <= 126) Serial.printf(" ('%c')", (char)b);
        Serial.println();
      }
    }
    delay(10);
  }

  Serial.println("│");
  Serial.printf("│  [3/3] Resultado: %d bytes recibidos en 2 seg\n", bytesRecibidos);
  Serial.println("│");

  if (bytesRecibidos > 0) {
    Serial.println("│  ✔ GM65 RESPONDIENDO — Modulo detectado!");
    Serial.println("│    El modulo esta enviando datos por Serial2.");

    // Enviar comando para modo escaneo continuo
    // GM65 command: Set continuous mode
    // 0x7E 0x00 0x0D 0x00 0x00 0x01 0xAB 0xCD (modo continuo = scan siempre)
    uint8_t cmdContinuo[] = {0x7E, 0x00, 0x0D, 0x00, 0x00, 0x01, 0xAB, 0xCD};
    Serial2.write(cmdContinuo, sizeof(cmdContinuo));
    Serial.println("│    Comando 'modo continuo' enviado al GM65.");
  } else {
    Serial.println("│  ⚠ GM65 NO RESPONDE — Posibles causas:");
    Serial.println("│");
    Serial.println("│    1. CABLEADO: Verifica que TX del GM65 va a GPIO 16 (RX2)");
    Serial.println("│                 y RX del GM65 va a GPIO 17 (TX2)");
    Serial.println("│                 Prueba INTERCAMBIAR los cables TX↔RX");
    Serial.println("│");
    Serial.println("│    2. ALIMENTACION: El GM65 necesita 5V (no 3.3V)");
    Serial.println("│                     Verifica que el LED del GM65 enciende");
    Serial.println("│");
    Serial.println("│    3. BAUDRATE: Algunos GM65 usan 115200 en vez de 9600");
    Serial.println("│                 Cambia GM65_BAUD en el codigo y recompila");
    Serial.println("│");
    Serial.println("│    4. MODO: Si tiene boton/switch, verificar modo UART activo");

    // Intentar con 115200
    Serial.println("│");
    Serial.println("│  Intentando con 115200 baud...");
    Serial2.end();
    Serial2.begin(115200, SERIAL_8N1, GM65_RX_PIN, GM65_TX_PIN);
    Serial2.write(cmdTrigger, sizeof(cmdTrigger));

    espera = millis();
    bytesRecibidos = 0;
    while (millis() - espera < 1500) {
      if (Serial2.available()) {
        uint8_t b = Serial2.read();
        bytesRecibidos++;
        if (bytesRecibidos <= 10) {
          Serial.printf("│    Byte@115200 #%d: 0x%02X\n", bytesRecibidos, b);
        }
      }
      delay(10);
    }

    if (bytesRecibidos > 0) {
      Serial.printf("│  ✔ GM65 responde a 115200 baud! (%d bytes)\n", bytesRecibidos);
      Serial.println("│    CAMBIA GM65_BAUD a 115200 en el codigo!");
      // Dejar en 115200 si funciona
    } else {
      Serial.println("│    Tampoco responde a 115200.");
      // Volver al baudrate original
      Serial2.end();
      Serial2.begin(GM65_BAUD, SERIAL_8N1, GM65_RX_PIN, GM65_TX_PIN);
    }
  }

  // Limpiar buffer
  while (Serial2.available()) Serial2.read();

  Serial.println("└─────────────────────────────────────────────────────────────────┘");
  Serial.println();
}
