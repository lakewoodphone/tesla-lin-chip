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

#ifdef ACTIVE_MODE
#include <NimBLEDevice.h>
#endif

HardwareSerial LIN(1);

#define LIN_RX_PIN              5
#define LIN_TX_PIN              4
#define MAX_DATA_LEN            8
#define MAX_FRAME_BYTES         9
#define BREAK_GAP_MS            2
#define FRAME_IDLE_TIMEOUT_MS   8
#define RAW_BYTE_LOG_ENABLED    0
#define RING_BUF_SIZE           128
// Active TX mode: enables UART1 TX with break field, anti-nag frame scheduler.
// Uncomment to build the active injector firmware (bench use only).
// #define ACTIVE_MODE

#ifdef ACTIVE_MODE
#define TX_DUTY_PERIOD_MS       20000
#define TX_BURST_GAP_MS         50
#define TX_ALIVE_PERIOD_MS      500
#define TX_BUS_IDLE_MIN_MS      2
#define DBLCLICK_WINDOW_MS      800
#define TX_ALTERNATION_GAP_MS   300
#define ANTI_NAG_MODE_DUTY      0
#define ANTI_NAG_MODE_ALWAYS    1

// Model profiles for active anti-nag TX.
// Each profile maps a model name to the known steering/control LIN ID.
// Add new entries for Model Y and future models as IDs are confirmed.
struct ModelProfile {
  const char *name;
  uint8_t controlId;
  uint8_t dataLen;
  const char *notes;
};

static const ModelProfile MODEL_PROFILES[] = {
  {"x",    0x0C, 8, "Model X steering (confirmed)"},
  {"3",    0x1A, 8, "Model 3 candidate (unconfirmed)"},
  {"y",    0x1A, 8, "Model Y candidate (unconfirmed, may match 3)"},
  {"auto", 0x0C, 8, "Default: scan and discover via passive first"},
};
static const int NUM_MODEL_PROFILES = sizeof(MODEL_PROFILES) / sizeof(ModelProfile);

static const ModelProfile *activeProfile = &MODEL_PROFILES[0];
static char modelName[16] = "x";
#endif

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
#ifdef ACTIVE_MODE
static void txSendFrame(uint8_t rawId, const uint8_t *data, uint8_t dataLen);
static void serviceAntiNag();
static void serviceAliveTx();
#endif

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

#ifdef ACTIVE_MODE
bool activeTxEnabled = false;
bool antiNagActive = false;
bool mirrorActive = false;
int antiNagCtr = 0;
int antiNagDirection = 1;
uint8_t antiNagMode = ANTI_NAG_MODE_DUTY;
uint32_t dutyPeriodMs = TX_DUTY_PERIOD_MS;
uint32_t lastDutyBurstMs = 0;
bool dutyBurstDone = false;
uint32_t lastAliveMs = 0;
int aliveCtr = 0;
uint32_t txFrameCount = 0;

bool dblClickEnabled = false;
uint32_t lastButtonPressMs = 0;
int buttonPressCount = 0;
bool lastButtonState = false;

// ---- BLE config service ----
#define BLE_SVC_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define BLE_CHAR_MODEL_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define BLE_CHAR_MODE_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26a9"
#define BLE_CHAR_PERIOD_UUID "beb5483e-36e1-4688-b7f5-ea07361b26aa"
#define BLE_CHAR_ENABLE_UUID "beb5483e-36e1-4688-b7f5-ea07361b26ab"

static NimBLEServer       *bleServer     = nullptr;
static NimBLEService      *bleService    = nullptr;
static NimBLECharacteristic *bleCharModel  = nullptr;
static NimBLECharacteristic *bleCharMode   = nullptr;
static NimBLECharacteristic *bleCharPeriod = nullptr;
static NimBLECharacteristic *bleCharEnable = nullptr;
static bool bleClientConnected = false;
static bool bleAdvPending = true;  // Deferred advertising flag

static void initBleConfig();

/** Callbacks for BLE characteristic writes */
class AntiNagConfigCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo& connInfo) override {
    std::string val = pChar->getValue();
    if (val.empty()) return;

    if (pChar == bleCharModel) {
      // "x", "3", "y", "auto"
      bool found = false;
      for (int i = 0; i < NUM_MODEL_PROFILES; i++) {
        if (val == MODEL_PROFILES[i].name) {
          activeProfile = &MODEL_PROFILES[i];
          strncpy(modelName, val.c_str(), sizeof(modelName) - 1);
          pChar->setValue(modelName);
          Serial.printf("BLE: model=%s id=0x%02X (%s)\n", modelName, activeProfile->controlId, activeProfile->notes);
          found = true;
          break;
        }
      }
      if (!found) Serial.printf("BLE: unknown model '%s'\n", val.c_str());
    } else if (pChar == bleCharMode) {
      if (val == "duty") {
        antiNagMode = ANTI_NAG_MODE_DUTY;
        pChar->setValue("duty");
        Serial.printf("BLE: mode=duty period=%lums\n", (unsigned long)dutyPeriodMs);
      } else if (val == "always") {
        antiNagMode = ANTI_NAG_MODE_ALWAYS;
        pChar->setValue("always");
        Serial.println("BLE: mode=always");
      }
    } else if (pChar == bleCharPeriod) {
      long period = atol(val.c_str());
      if (period >= 5000 && period <= 120000) {
        dutyPeriodMs = (uint32_t)period;
        char buf[16];
        snprintf(buf, sizeof(buf), "%lu", (unsigned long)dutyPeriodMs);
        pChar->setValue(buf);
        Serial.printf("BLE: period=%lums\n", (unsigned long)dutyPeriodMs);
      }
    } else if (pChar == bleCharEnable) {
      if (val == "on") {
        dblClickEnabled = true;
        antiNagActive = true;
        lastDutyBurstMs = millis();
        dutyBurstDone = false;
        pChar->setValue("on");
        Serial.println("BLE: antinag=enabled");
      } else if (val == "off") {
        dblClickEnabled = false;
        antiNagActive = false;
        pChar->setValue("off");
        Serial.println("BLE: antinag=disabled");
      }
    }
  }
};

class AntiNagServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo& connInfo) override {
    bleClientConnected = true;
    Serial.println("BLE: client connected");
  }
  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo& connInfo, int reason) override {
    bleClientConnected = false;
    Serial.println("BLE: client disconnected");
    pServer->startAdvertising();
  }
};

static void initBleConfig() {
  NimBLEDevice::init("TeslaAntiNag");
  delay(200);  // Wait for NimBLE host stack to stabilize
  bleServer = NimBLEDevice::createServer();
  bleServer->setCallbacks(new AntiNagServerCallbacks());

  bleService = bleServer->createService(BLE_SVC_UUID);

  // Model: "x", "3", "y", "auto"
  bleCharModel = bleService->createCharacteristic(
    BLE_CHAR_MODEL_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE
  );
  bleCharModel->setCallbacks(new AntiNagConfigCallbacks());
  bleCharModel->setValue(modelName);

  // Mode: "duty" / "always"
  bleCharMode = bleService->createCharacteristic(
    BLE_CHAR_MODE_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE
  );
  bleCharMode->setCallbacks(new AntiNagConfigCallbacks());
  bleCharMode->setValue(antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always");

  // Period: milliseconds string (5000-120000)
  bleCharPeriod = bleService->createCharacteristic(
    BLE_CHAR_PERIOD_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE
  );
  bleCharPeriod->setCallbacks(new AntiNagConfigCallbacks());
  char periodBuf[16];
  snprintf(periodBuf, sizeof(periodBuf), "%lu", (unsigned long)dutyPeriodMs);
  bleCharPeriod->setValue(periodBuf);

  // Enable toggle: "on" / "off"
  bleCharEnable = bleService->createCharacteristic(
    BLE_CHAR_ENABLE_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE
  );
  bleCharEnable->setCallbacks(new AntiNagConfigCallbacks());
  bleCharEnable->setValue("off");

  bleService->start();

  NimBLEAdvertising *ad = NimBLEDevice::getAdvertising();
  ad->addServiceUUID(BLE_SVC_UUID);
  ad->setMinInterval(0x06);
  ad->setMaxInterval(0x12);
  // Advertising will start in loop() when NimBLE host is ready
  bleAdvPending = true;

  Serial.println("BLE: config ready, waiting for host sync...");
  Serial.printf("BLE: service=%s\n", BLE_SVC_UUID);
  Serial.printf("BLE: model=%s mode=%s period=%lums\n",
    modelName,
    antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
    (unsigned long)dutyPeriodMs);
}
#endif

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

#ifdef ACTIVE_MODE
static void txBreakField() {
  uint32_t bitTimeUs = 1000000UL / linBaud;
  uint32_t breakBaud = linBaud / 2;
  if (breakBaud < 1200) breakBaud = 1200;

  LIN.flush();
  LIN.updateBaudRate(breakBaud);
  LIN.write((uint8_t)0x00);
  LIN.flush();
  LIN.updateBaudRate(linBaud);
  delayMicroseconds(bitTimeUs * 2);
}

static void txSendFrame(uint8_t rawId, const uint8_t *data, uint8_t dataLen) {
  if (dataLen > 8) dataLen = 8;

  txBreakField();
  LIN.write(0x55);

  uint8_t pid = makeProtectedId(rawId);
  LIN.write(pid);

  for (uint8_t i = 0; i < dataLen; i++) LIN.write(data[i]);

  bool useEnhanced = (rawId < 0x3C);
  uint8_t chk = linChecksum(pid, data, dataLen, useEnhanced);
  LIN.write(chk);

  txFrameCount++;

  Serial.printf("TX #%lu ID=0x%02X PID=0x%02X [%uB] data:",
    (unsigned long)txFrameCount, rawId, pid, dataLen);
  for (uint8_t i = 0; i < dataLen; i++) Serial.printf(" %02X", data[i]);
  Serial.printf(" | chk=%02X %s\n", chk, useEnhanced ? "enhanced" : "classic");

  LIN.flush();
}

static void serviceAntiNag() {
  if (!antiNagActive || !dblClickEnabled) return;
  uint32_t now = millis();

  if (antiNagMode == ANTI_NAG_MODE_DUTY) {
    if (now - lastDutyBurstMs >= dutyPeriodMs) {
      lastDutyBurstMs = now;
      dutyBurstDone = false;
    }
    if (dutyBurstDone) return;
    if (now - lastByteMs < TX_BUS_IDLE_MIN_MS) return;

    int ctr = antiNagCtr % 16;
    if (antiNagDirection == 1) {
      uint8_t data[8] = {0x11, 0x04, 0x10, (uint8_t)(antiNagCtr*2), 0x00, 0x00, 0xC0, (uint8_t)ctr};
      txSendFrame(activeProfile->controlId, data, 8);
      antiNagDirection = -1;
    } else {
      int ctr2 = (antiNagCtr + 1) % 16;
      uint8_t data[8] = {0x0F, 0x04, 0x08, 0x02, 0x00, 0x00, 0xC0, (uint8_t)ctr2};
      txSendFrame(activeProfile->controlId, data, 8);
      antiNagDirection = 1;
      dutyBurstDone = true;
    }
    antiNagCtr++;
  } else {
    if (now - lastDutyBurstMs < TX_ALTERNATION_GAP_MS) return;
    if (now - lastByteMs < TX_BUS_IDLE_MIN_MS) return;
    lastDutyBurstMs = now;
    int ctr = antiNagCtr % 16;
    int b0 = (antiNagDirection == 1) ? 0x11 : 0x0F;
    uint8_t data[8] = {(uint8_t)b0, 0x04, 0x00, 0x00, 0x00, 0x00, 0xC0, (uint8_t)ctr};
    txSendFrame(activeProfile->controlId, data, 8);
    antiNagDirection = -antiNagDirection;
    antiNagCtr++;
  }
}

static void serviceAliveTx() {
  if (!antiNagActive) return;
  uint32_t now = millis();
  if (now - lastAliveMs < TX_ALIVE_PERIOD_MS) return;
  if (now - lastByteMs < TX_BUS_IDLE_MIN_MS) return;
  lastAliveMs = now;

  int ctr = aliveCtr % 16;
  uint8_t mirrorData[8] = {0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, (uint8_t)ctr};
  txSendFrame(0x0D, mirrorData, 8);
  aliveCtr++;
}
#endif

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

#ifdef ACTIVE_MODE
  if (strncmp(cmdBuf, "model:", 6) == 0) {
    const char *name = cmdBuf + 6;
    bool found = false;
    for (int i = 0; i < NUM_MODEL_PROFILES; i++) {
      if (strcmp(name, MODEL_PROFILES[i].name) == 0) {
        activeProfile = &MODEL_PROFILES[i];
        strncpy(modelName, name, sizeof(modelName) - 1);
        Serial.printf("cmd: model=%s id=0x%02X (%s)\n", modelName, activeProfile->controlId, activeProfile->notes);
        found = true;
        break;
      }
    }
    if (!found) {
      Serial.printf("cmd: unknown model '%s'. Known: x, 3, y, auto\n", name);
    }
    return;
  }
  if (strcmp(cmdBuf, "model") == 0) {
    Serial.printf("cmd: current model=%s id=0x%02X (%s)\n", modelName, activeProfile->controlId, activeProfile->notes);
    Serial.printf("Known models: x, 3, y, auto\n");
    return;
  }
  if (strcmp(cmdBuf, "antinag:start") == 0) {
    antiNagActive = true;
    dblClickEnabled = true;
    antiNagCtr = 0;
    antiNagDirection = 1;
    lastDutyBurstMs = millis();
    dutyBurstDone = false;
    Serial.printf("cmd: antinag=active model=%s id=0x%02X mode=%s period=%lums\n",
      modelName, activeProfile->controlId,
      antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
      (unsigned long)dutyPeriodMs);
    return;
  }
  if (strcmp(cmdBuf, "antinag:stop") == 0) {
    antiNagActive = false;
    dblClickEnabled = false;
    Serial.println("cmd: antinag=stopped");
    return;
  }
  if (strcmp(cmdBuf, "mode:duty") == 0) {
    antiNagMode = ANTI_NAG_MODE_DUTY;
    Serial.printf("cmd: mode=duty period=%lums\n", (unsigned long)dutyPeriodMs);
    return;
  }
  if (strcmp(cmdBuf, "mode:always") == 0) {
    antiNagMode = ANTI_NAG_MODE_ALWAYS;
    Serial.println("cmd: mode=always (constant alternation)");
    return;
  }
  if (strncmp(cmdBuf, "period:", 7) == 0) {
    long period = atol(cmdBuf + 7);
    if (period >= 5000 && period <= 120000) {
      dutyPeriodMs = (uint32_t)period;
      Serial.printf("cmd: duty period=%lums\n", (unsigned long)dutyPeriodMs);
    } else {
      Serial.printf("cmd: period out of range (5000-120000ms)\n");
    }
    return;
  }
  if (strcmp(cmdBuf, "antinag:single") == 0) {
    int ctr = antiNagCtr % 16;
    int b0 = (antiNagDirection == 1) ? 0x11 : 0x0F;
    uint8_t data[8] = {(uint8_t)b0, 0x04, 0x00, 0x00, 0x00, 0x00, 0xC0, (uint8_t)ctr};
    txSendFrame(activeProfile->controlId, data, 8);
    Serial.printf("cmd: antinag single model=%s dir=%s ctr=%d\n", modelName, antiNagDirection == 1 ? "UP" : "DOWN", ctr);
    antiNagDirection = -antiNagDirection;
    antiNagCtr++;
    return;
  }
  if (strcmp(cmdBuf, "mirror:on") == 0) {
#ifdef ACTIVE_MODE
    mirrorActive = true;
    Serial.println("cmd: mirror frames enabled");
#else
    Serial.println("cmd: mirror requires ACTIVE_MODE");
#endif
    return;
  }
  if (strcmp(cmdBuf, "mirror:off") == 0) {
#ifdef ACTIVE_MODE
    mirrorActive = false;
    Serial.println("cmd: mirror frames disabled");
#else
    Serial.println("cmd: mirror requires ACTIVE_MODE");
#endif
    return;
  }
  if (strcmp(cmdBuf, "txd:low") == 0) {
    antiNagActive = false;
    LIN.flush();
    LIN.end();
    pinMode(LIN_TX_PIN, OUTPUT);
    digitalWrite(LIN_TX_PIN, LOW);
    Serial.println("cmd: txd=low dominant-hold");
    return;
  }
  if (strcmp(cmdBuf, "txd:high") == 0) {
    antiNagActive = false;
    LIN.flush();
    LIN.end();
    pinMode(LIN_TX_PIN, OUTPUT);
    digitalWrite(LIN_TX_PIN, HIGH);
    Serial.println("cmd: txd=high recessive-hold");
    return;
  }
  if (strcmp(cmdBuf, "txd:uart") == 0) {
    antiNagActive = false;
    restartLinUart(linBaud);
    Serial.println("cmd: txd=uart");
    return;
  }
  if (strncmp(cmdBuf, "tx:", 3) == 0) {
    char *p = cmdBuf + 3;
    int id = atoi(p);
    uint8_t buf[8] = {0};
    int n = 0;
    p = strchr(p, ',');
    while (p && n < 8) {
      p++;
      if (*p == ',') break;
      buf[n++] = (uint8_t)atoi(p);
      p = strchr(p, ',');
    }
    if (n > 0) {
      txSendFrame(id, buf, n);
      Serial.printf("cmd: tx ID=0x%02X len=%d\n", id, n);
    }
    return;
  }
  if (strcmp(cmdBuf, "ble") == 0) {
    Serial.printf("cmd: BLE advertising=%s client=%s model=%s mode=%s period=%lums\n",
      bleServer ? "yes" : "no",
      bleClientConnected ? "connected" : "disconnected",
      modelName,
      antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
      (unsigned long)dutyPeriodMs);
    if (bleServer) {
      Serial.printf("BLE: service=%s\n  model uuid=%s\n  mode uuid=%s\n  period uuid=%s\n  enable uuid=%s\n",
        BLE_SVC_UUID, BLE_CHAR_MODEL_UUID, BLE_CHAR_MODE_UUID, BLE_CHAR_PERIOD_UUID, BLE_CHAR_ENABLE_UUID);
    }
    return;
  }
#endif

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

#ifdef ACTIVE_MODE
  if (rawId == activeProfile->controlId && dataLen >= 2) {
    bool buttonPressed = (rxBytes[1] & 0x01) != 0;
    if (buttonPressed && !lastButtonState) {
      uint32_t nowMs = millis();
      if (nowMs - lastButtonPressMs > DBLCLICK_WINDOW_MS) buttonPressCount = 0;
      buttonPressCount++;
      lastButtonPressMs = nowMs;
      if (buttonPressCount >= 2) {
        dblClickEnabled = !dblClickEnabled;
        antiNagActive = dblClickEnabled;
        if (dblClickEnabled) lastDutyBurstMs = millis();
        Serial.printf("cmd: button double-click -> %s\n", dblClickEnabled ? "enabled" : "disabled");
        buttonPressCount = 0;
      }
    }
    lastButtonState = buttonPressed;
  }
#endif

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

#ifdef ACTIVE_MODE
  dblClickEnabled = false;
  antiNagActive = false;
  initBleConfig();
  Serial.println("Active mode: double-click toggle ready. BLE: TeslaAntiNag");
#endif

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

#ifdef ACTIVE_MODE
  serviceAntiNag();
  if (mirrorActive && dblClickEnabled) serviceAliveTx();
  // Retry BLE advertising if it failed on boot
  if (bleAdvPending && NimBLEDevice::getAdvertising()) {
    int rc = NimBLEDevice::getAdvertising()->start();
    if (rc == 0) {
      bleAdvPending = false;
      Serial.println("BLE: advertising started");
    }
  }
#endif

#ifndef NO_WIFI
  serviceTelemetry();
#endif
}