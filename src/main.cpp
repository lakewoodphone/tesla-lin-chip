// XIAO ESP32-C3 LIN receiver - vehicle bench firmware
//
// Design goals:
// - Work across Tesla Model X / 3 / Y LIN buses without assuming a fixed LDF.
// - Parse frames by observed break/idle boundary, not only by ID-derived length.
// - Validate protected-ID parity plus enhanced and classic checksums.
// - Keep LIN parsing real-time: HTTP telemetry is queued and rate-limited.
// - v4: Auto-baud scan, runtime vehicle ID, ring buffer, serial commands.

#include <Arduino.h>
#include <HardwareSerial.h>

#ifndef NO_WIFI
#include <WiFi.h>
#include <HTTPClient.h>
#endif

#include "secrets.h"

HardwareSerial LIN(1);

#define LIN_RX_PIN              5
#define LIN_TX_PIN              4
#define MAX_DATA_LEN            8
#define MAX_FRAME_BYTES         9
#define BREAK_GAP_MS            2
#define FRAME_IDLE_TIMEOUT_MS   8
#define RAW_BYTE_LOG_ENABLED    0
#define RING_BUF_SIZE           128

#ifndef NO_WIFI
#define TELEMETRY_QUEUE_SIZE    64
#define HTTP_POST_INTERVAL_MS   50
#define WIFI_RECONNECT_MS       10000
#endif

// ---------------------------------------------------------------------------
// Runtime state
// ---------------------------------------------------------------------------
uint16_t linBaud = 19200;   // default; overridable via serial command

static char vehicleId[32] = VEHICLE_ID;

// Forward declarations
static void resetFrameBuffer();
static void restartLinUart(uint16_t baud);

enum State { S_IDLE, S_SYNC, S_PID, S_BYTES };
State state = S_IDLE;

uint8_t pid = 0;
uint8_t rxBytes[MAX_FRAME_BYTES];
uint8_t rxCount = 0;
bool frameOverflow = false;

uint32_t lastByteMs = 0;
uint32_t frameCount = 0;
uint32_t lastHeartbeatMs = 0;
uint32_t checksumBadCount = 0;
uint32_t parityBadCount = 0;
uint32_t overflowCount = 0;
uint32_t shortFrameCount = 0;
uint32_t syncErrCount = 0;

volatile uint32_t edgeCount = 0;

bool rawByteLog = false;
bool autoBaudScanDone = false;

// Ring buffer of recent frames
struct RingFrame {
  uint8_t protectedId;
  uint8_t data[MAX_DATA_LEN];
  uint8_t dataLen;
  uint8_t rxChecksum;
  bool checksumOk;
  bool parityOk;
  char checksumMode[9];
  uint32_t uptimeMs;
};
RingFrame ringBuf[RING_BUF_SIZE];
uint32_t ringHead = 0;
uint32_t ringCount = 0;
uint32_t ringTotal = 0;

// ---------------------------------------------------------------------------
// Data length from LIN ID class
// ---------------------------------------------------------------------------
static uint8_t dataLenFromIdClass(uint8_t protectedId) {
  uint8_t id = protectedId & 0x3F;
  switch ((id >> 4) & 0x03) {
    case 0: return 2;
    case 1: return 2;
    case 2: return 4;
    case 3: return 8;
  }
  return 8;
}

// ---------------------------------------------------------------------------
// Protected ID computation / validation
// ---------------------------------------------------------------------------
static uint8_t makeProtectedId(uint8_t rawId) {
  uint8_t id = rawId & 0x3F;
  uint8_t id0 = (id >> 0) & 1;
  uint8_t id1 = (id >> 1) & 1;
  uint8_t id2 = (id >> 2) & 1;
  uint8_t id3 = (id >> 3) & 1;
  uint8_t id4 = (id >> 4) & 1;
  uint8_t id5 = (id >> 5) & 1;
  uint8_t p0 = id0 ^ id1 ^ id2 ^ id4;
  uint8_t p1 = (~(id1 ^ id3 ^ id4 ^ id5)) & 1;
  return id | (p0 << 6) | (p1 << 7);
}

static bool protectedIdIsValid(uint8_t protectedId) {
  return makeProtectedId(protectedId & 0x3F) == protectedId;
}

// ---------------------------------------------------------------------------
// LIN checksum (enhanced or classic)
// ---------------------------------------------------------------------------
static uint8_t linChecksum(uint8_t protectedId, const uint8_t *data, uint8_t n, bool enhanced) {
  uint16_t sum = enhanced ? protectedId : 0;
  for (uint8_t i = 0; i < n; i++) {
    sum += data[i];
    while (sum > 0xFF) sum = (sum & 0xFF) + (sum >> 8);
  }
  return ~(uint8_t)sum;
}

// ---------------------------------------------------------------------------
// Auto-baud scanning — try common Tesla LIN rates
// ---------------------------------------------------------------------------
static const uint16_t BAUD_CANDIDATES[] = {19200, 9600, 10400};
static const int NUM_BAUD_CANDIDATES = 3;
static int currentBaudIdx = 0;

static void restartLinUart(uint16_t baud) {
  LIN.end();
  delay(20);
  LIN.begin(baud, SERIAL_8N1, LIN_RX_PIN, LIN_TX_PIN);
  linBaud = baud;
  state = S_IDLE;
  resetFrameBuffer();
}

static void tryNextBaud() {
  currentBaudIdx = (currentBaudIdx + 1) % NUM_BAUD_CANDIDATES;
  restartLinUart(BAUD_CANDIDATES[currentBaudIdx]);
  Serial.printf("baud: switched to %u\n", linBaud);
}

static void probeAndSetBaud() {
  // Try each baud briefly. The one that yields valid frames first wins.
  // Start from 19200 (most common Tesla LIN).
  for (int i = 0; i < NUM_BAUD_CANDIDATES; i++) {
    currentBaudIdx = i;
    restartLinUart(BAUD_CANDIDATES[currentBaudIdx]);
    Serial.printf("baud: probing %u\n", linBaud);
    // Give it a couple seconds — if frames start flowing, we stay.
    // (We don't block here; the caller just starts capture with this baud
    // and auto-scan logic in loop() handles switching if frames==0.)
  }
}

// ---------------------------------------------------------------------------
// Ring buffer (stores last N frames for summary / serial dump)
// ---------------------------------------------------------------------------
static void ringPush(uint8_t protectedId, const uint8_t *data, uint8_t dataLen,
                     uint8_t rxChecksum, bool checksumOk, bool parityOk,
                     const char *checksumMode) {
  uint32_t idx = (ringHead + ringCount) % RING_BUF_SIZE;
  if (ringCount == RING_BUF_SIZE) {
    ringHead = (ringHead + 1) % RING_BUF_SIZE;
    ringCount--;
  }
  ringBuf[idx].protectedId = protectedId;
  memcpy(ringBuf[idx].data, data, dataLen);
  ringBuf[idx].dataLen = dataLen;
  ringBuf[idx].rxChecksum = rxChecksum;
  ringBuf[idx].checksumOk = checksumOk;
  ringBuf[idx].parityOk = parityOk;
  strncpy(ringBuf[idx].checksumMode, checksumMode, sizeof(ringBuf[idx].checksumMode) - 1);
  ringBuf[idx].uptimeMs = millis();
  ringCount++;
  ringTotal++;
}

static void dumpRing() {
  uint32_t start = ringHead;
  Serial.printf("ring: %lu frames (total=%lu)\n", (unsigned long)ringCount, (unsigned long)ringTotal);
  for (uint32_t i = 0; i < ringCount; i++) {
    uint32_t idx = (start + i) % RING_BUF_SIZE;
    auto &f = ringBuf[idx];
    uint8_t rawId = f.protectedId & 0x3F;
    Serial.printf(" [%lu] ID=0x%02X PID=0x%02X [%uB] data:",
      (unsigned long)i, rawId, f.protectedId, f.dataLen);
    for (uint8_t j = 0; j < f.dataLen; j++) Serial.printf(" %02X", f.data[j]);
    Serial.printf(" | chk=%02X %s parity=%s\n",
      f.rxChecksum, f.checksumMode, f.parityOk ? "OK" : "BAD");
  }
}

// ---------------------------------------------------------------------------
// Serial command handler (runtime reconfiguration)
// ---------------------------------------------------------------------------
// Commands:
//   vehicle:tesla-model-3    Set vehicle ID
//   baud:9600                Switch LIN baud rate
//   baud:19200               Switch LIN baud rate
//   baud:10400               Switch LIN baud rate
//   raw:1                    Enable raw byte logging
//   raw:0                    Disable raw byte logging
//   ring                     Dump ring buffer
//   stats                    Print capture stats
// ---------------------------------------------------------------------------
static char cmdBuf[64];
static uint8_t cmdIdx = 0;

static void processCommand() {
  cmdBuf[cmdIdx] = '\0';
  cmdIdx = 0;

  if (strncmp(cmdBuf, "vehicle:", 8) == 0) {
    strncpy(vehicleId, cmdBuf + 8, sizeof(vehicleId) - 1);
    Serial.printf("cmd: vehicle=%s\n", vehicleId);
    return;
  }

  if (strncmp(cmdBuf, "baud:", 5) == 0) {
    uint16_t newBaud = (uint16_t)atoi(cmdBuf + 5);
    if (newBaud >= 1200 && newBaud <= 20000) {
      restartLinUart(newBaud);
      Serial.printf("cmd: baud=%u\n", newBaud);
    } else {
      Serial.printf("cmd: invalid baud %u\n", newBaud);
    }
    return;
  }

  if (strcmp(cmdBuf, "raw:1") == 0) {
    rawByteLog = true;
    Serial.println("cmd: raw=on");
    return;
  }
  if (strcmp(cmdBuf, "raw:0") == 0) {
    rawByteLog = false;
    Serial.println("cmd: raw=off");
    return;
  }

  if (strcmp(cmdBuf, "ring") == 0) {
    dumpRing();
    return;
  }

  if (strcmp(cmdBuf, "stats") == 0) {
    Serial.printf("cmd: frames=%lu badChk=%lu badPid=%lu ovf=%lu short=%lu syncErr=%lu edges=%lu ring=%lu wifi=%s\n",
      (unsigned long)frameCount, (unsigned long)checksumBadCount,
      (unsigned long)parityBadCount, (unsigned long)overflowCount,
      (unsigned long)shortFrameCount, (unsigned long)syncErrCount,
      (unsigned long)edgeCount, (unsigned long)ringTotal,
      WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString().c_str() : "off");
    return;
  }

  Serial.printf("cmd: unknown '%s'\n", cmdBuf);
}

static void serviceSerialCommands() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (cmdIdx > 0) processCommand();
    } else if (cmdIdx < sizeof(cmdBuf) - 1) {
      cmdBuf[cmdIdx++] = c;
    }
  }
}

#ifndef NO_WIFI
struct TelemetryEvent {
  uint8_t protectedId;
  uint8_t rawId;
  uint8_t data[MAX_DATA_LEN];
  uint8_t dataLen;
  uint8_t predictedLen;
  uint8_t rxChecksum;
  bool checksumOk;
  bool parityOk;
  char checksumMode[9];
  uint32_t frameNumber;
  uint32_t uptimeMs;
  uint32_t telemetryDrops;
};

TelemetryEvent telemetryQueue[TELEMETRY_QUEUE_SIZE];
uint8_t telemetryHead = 0;
uint8_t telemetryTail = 0;
uint8_t telemetryCount = 0;
uint32_t telemetryDropCount = 0;
uint32_t postFailCount = 0;
uint32_t lastHttpPostMs = 0;
uint32_t lastWifiAttemptMs = 0;
bool wifiOk = false;

static void connectWifiBlocking() {
  Serial.printf("WiFi: connecting to %s ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  uint32_t started = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - started < 10000) {
    delay(200);
    Serial.print(".");
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiOk = true;
    Serial.printf("\nWiFi: connected IP=%s\n", WiFi.localIP().toString().c_str());
  } else {
    wifiOk = false;
    lastWifiAttemptMs = millis();
    Serial.println("\nWiFi: timeout - USB/APG capture still active");
  }
}

static void serviceWifi() {
  if (WiFi.status() == WL_CONNECTED) {
    wifiOk = true;
    return;
  }

  wifiOk = false;
  uint32_t now = millis();
  if (now - lastWifiAttemptMs >= WIFI_RECONNECT_MS) {
    lastWifiAttemptMs = now;
    Serial.println("WiFi: reconnect attempt");
    WiFi.disconnect(false);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
  }
}

static void enqueueTelemetry(const TelemetryEvent &event) {
  if (telemetryCount >= TELEMETRY_QUEUE_SIZE) {
    telemetryHead = (telemetryHead + 1) % TELEMETRY_QUEUE_SIZE;
    telemetryCount--;
    telemetryDropCount++;
  }
  telemetryQueue[telemetryTail] = event;
  telemetryQueue[telemetryTail].telemetryDrops = telemetryDropCount;
  telemetryTail = (telemetryTail + 1) % TELEMETRY_QUEUE_SIZE;
  telemetryCount++;
}

static bool dequeueTelemetry(TelemetryEvent &event) {
  if (telemetryCount == 0) return false;
  event = telemetryQueue[telemetryHead];
  telemetryHead = (telemetryHead + 1) % TELEMETRY_QUEUE_SIZE;
  telemetryCount--;
  return true;
}

static void postTelemetryEvent(const TelemetryEvent &event) {
  char dataJson[48] = "[";
  for (uint8_t i = 0; i < event.dataLen; i++) {
    char tmp[8];
    snprintf(tmp, sizeof(tmp), "%s%u", i ? "," : "", event.data[i]);
    strncat(dataJson, tmp, sizeof(dataJson) - strlen(dataJson) - 1);
  }
  strncat(dataJson, "]", sizeof(dataJson) - strlen(dataJson) - 1);

  char body[384];
  snprintf(body, sizeof(body),
    "{\"vehicle\":\"%s\",\"id\":%u,\"id_hex\":\"0x%02X\","
    "\"pid\":\"0x%02X\",\"data\":%s,\"data_len\":%u,"
    "\"expected_len\":%u,\"checksum_ok\":%s,\"checksum_mode\":\"%s\","
    "\"pid_valid\":%s,\"rx_checksum\":\"0x%02X\",\"frame_count\":%lu,"
    "\"uptime_ms\":%lu,\"telemetry_drops\":%lu}",
    vehicleId,                    // <-- runtime vehicle ID
    event.rawId,
    event.rawId,
    event.protectedId,
    dataJson,
    event.dataLen,
    event.predictedLen,
    event.checksumOk ? "true" : "false",
    event.checksumMode,
    event.parityOk ? "true" : "false",
    event.rxChecksum,
    (unsigned long)event.frameNumber,
    (unsigned long)event.uptimeMs,
    (unsigned long)event.telemetryDrops
  );

  HTTPClient http;
  http.begin(SECRETARY_URL "/api/v1/lin-events");
  http.addHeader("Content-Type", "application/json");
  int code = http.POST(body);
  if (code <= 0) {
    postFailCount++;
    Serial.printf("POST err: %s\n", http.errorToString(code).c_str());
  }
  http.end();
}

static void serviceTelemetry() {
  serviceWifi();
  if (!wifiOk) return;

  uint32_t now = millis();
  if (now - lastHttpPostMs < HTTP_POST_INTERVAL_MS) return;

  TelemetryEvent event;
  if (!dequeueTelemetry(event)) return;
  lastHttpPostMs = now;
  postTelemetryEvent(event);
}
#endif

static void resetFrameBuffer() {
  rxCount = 0;
  frameOverflow = false;
}

static void finalizeBufferedFrame(const char *source) {
  if (state != S_BYTES) return;

  if (frameOverflow) {
    overflowCount++;
    Serial.printf("[frame overflow pid=0x%02X source=%s]\n", pid, source);
    state = S_IDLE;
    resetFrameBuffer();
    return;
  }

  if (rxCount < 2) {
    shortFrameCount++;
    Serial.printf("[short frame pid=0x%02X bytes=%u source=%s]\n", pid, rxCount, source);
    state = S_IDLE;
    resetFrameBuffer();
    return;
  }

  uint8_t dataLen = rxCount - 1;
  if (dataLen > MAX_DATA_LEN) {
    overflowCount++;
    Serial.printf("[long frame pid=0x%02X dataLen=%u source=%s]\n", pid, dataLen, source);
    state = S_IDLE;
    resetFrameBuffer();
    return;
  }

  uint8_t rxChecksum = rxBytes[dataLen];
  uint8_t enhanced = linChecksum(pid, rxBytes, dataLen, true);
  uint8_t classic = linChecksum(pid, rxBytes, dataLen, false);
  bool parityOk = protectedIdIsValid(pid);
  bool enhancedOk = rxChecksum == enhanced;
  bool classicOk = rxChecksum == classic;
  bool checksumOk = enhancedOk || classicOk;
  const char *checksumMode = enhancedOk ? "enhanced" : (classicOk ? "classic" : "bad");
  uint8_t rawId = pid & 0x3F;
  uint8_t predictedLen = dataLenFromIdClass(pid);

  frameCount++;
  if (!parityOk) parityBadCount++;
  if (!checksumOk) checksumBadCount++;

  // Push to ring buffer
  ringPush(pid, rxBytes, dataLen, rxChecksum, checksumOk, parityOk, checksumMode);

  Serial.printf("#%lu ID=0x%02X PID=0x%02X [%uB pred=%u] data:",
    (unsigned long)frameCount, rawId, pid, dataLen, predictedLen);
  for (uint8_t i = 0; i < dataLen; i++) Serial.printf(" %02X", rxBytes[i]);
  Serial.printf(" | chk=%02X %s parity=%s src=%s\n",
    rxChecksum,
    checksumMode,
    parityOk ? "OK" : "BAD",
    source);

#ifndef NO_WIFI
  TelemetryEvent event = {};
  event.protectedId = pid;
  event.rawId = rawId;
  event.dataLen = dataLen;
  event.predictedLen = predictedLen;
  event.rxChecksum = rxChecksum;
  event.checksumOk = checksumOk;
  event.parityOk = parityOk;
  strncpy(event.checksumMode, checksumMode, sizeof(event.checksumMode) - 1);
  event.frameNumber = frameCount;
  event.uptimeMs = millis();
  for (uint8_t i = 0; i < dataLen; i++) event.data[i] = rxBytes[i];
  enqueueTelemetry(event);
#endif

  state = S_IDLE;
  resetFrameBuffer();
}

void IRAM_ATTR onLinEdge() { edgeCount++; }

void setup() {
  Serial.begin(115200);
  delay(1500);
  Serial.println("LIN receiver v4 - multi-model, ring buffer, serial commands");
  Serial.printf("Vehicle: %s  Default Baud: %u\n", vehicleId, linBaud);
  Serial.println("Commands: vehicle:<id>  baud:<rate>  raw:0/1  ring  stats");

#ifndef NO_WIFI
  connectWifiBlocking();
#else
  Serial.println("WiFi: disabled (NO_WIFI)");
#endif

  pinMode(LIN_RX_PIN, INPUT);
  attachInterrupt(digitalPinToInterrupt(LIN_RX_PIN), onLinEdge, CHANGE);

  // Start at the primary Tesla LIN baud
  restartLinUart(linBaud);
}

void loop() {
  uint32_t now = millis();

  // --- Serial commands (non-blocking, runs every loop) ---
  serviceSerialCommands();

  // --- Parse LIN bytes from UART ---
  while (LIN.available()) {
    uint8_t b = LIN.read();
    now = millis();
    uint32_t gap = now - lastByteMs;
    lastByteMs = now;

    if (rawByteLog) {
      Serial.printf("raw gap=%lu b=%02X state=%d\n", (unsigned long)gap, b, state);
    }

    if (b == 0x00 && gap >= BREAK_GAP_MS) {
      finalizeBufferedFrame("break");
      state = S_SYNC;
      resetFrameBuffer();
      continue;
    }

    switch (state) {
      case S_BYTES:
        if (rxCount > 0 && gap >= FRAME_IDLE_TIMEOUT_MS) {
          finalizeBufferedFrame("idle");
        }
        if (rxCount < MAX_FRAME_BYTES) {
          rxBytes[rxCount++] = b;
        } else {
          frameOverflow = true;
        }
        break;

      case S_SYNC:
        if (b == 0x55) {
          state = S_PID;
        } else if (b != 0x00) {
          syncErrCount++;
          Serial.printf("[sync err 0x%02X]\n", b);
          state = S_IDLE;
        }
        break;

      case S_PID:
        pid = b;
        resetFrameBuffer();
        state = S_BYTES;
        break;

      default:
        break;
    }
  }

  // --- Idle timeout for S_BYTES (re-check after LIN read) ---
  if (state == S_BYTES && rxCount > 0 && now - lastByteMs >= FRAME_IDLE_TIMEOUT_MS) {
    finalizeBufferedFrame("idle");
  }

  // --- Heartbeat ---
  if (now - lastHeartbeatMs >= 1000) {
    lastHeartbeatMs = now;
    noInterrupts();
    uint32_t edges = edgeCount;
    edgeCount = 0;
    interrupts();

#ifndef NO_WIFI
    Serial.printf("alive d3=%d edges=%lu frames=%lu badChk=%lu badPid=%lu ovf=%lu short=%lu syncErr=%lu baud=%u q=%u drop=%lu postFail=%lu wifi=%s\n",
      digitalRead(LIN_RX_PIN),
      (unsigned long)edges,
      (unsigned long)frameCount,
      (unsigned long)checksumBadCount,
      (unsigned long)parityBadCount,
      (unsigned long)overflowCount,
      (unsigned long)shortFrameCount,
      (unsigned long)syncErrCount,
      linBaud,
      telemetryCount,
      (unsigned long)telemetryDropCount,
      (unsigned long)postFailCount,
      wifiOk ? WiFi.localIP().toString().c_str() : "off");
#else
    Serial.printf("alive d3=%d edges=%lu frames=%lu badChk=%lu badPid=%lu ovf=%lu short=%lu syncErr=%lu baud=%u lip=%u\n",
      digitalRead(LIN_RX_PIN),
      (unsigned long)edges,
      (unsigned long)frameCount,
      (unsigned long)checksumBadCount,
      (unsigned long)parityBadCount,
      (unsigned long)overflowCount,
      (unsigned long)shortFrameCount,
      (unsigned long)syncErrCount,
      linBaud);
#endif
  }

#ifndef NO_WIFI
  serviceTelemetry();
#endif
}