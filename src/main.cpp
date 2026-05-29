// XIAO ESP32-C3 LIN receiver - vehicle bench firmware
//
// Design goals:
// - Work across Tesla Model X / 3 / Y LIN buses without assuming a fixed LDF.
// - Parse frames by observed break/idle boundary, not only by ID-derived length.
// - Validate protected-ID parity plus enhanced and classic checksums.
// - Keep LIN parsing real-time: HTTP telemetry is queued and rate-limited.
// - v5: Active bench TX, BLE config, runtime vehicle ID, ring buffer, serial commands.

#include <Arduino.h>
#include <HardwareSerial.h>
#include <esp_system.h>

#ifndef NO_WIFI
#include <WiFi.h>
#include <HTTPClient.h>
#endif

#include "secrets.h"

#ifndef PASSTHROUGH_MODE

#ifdef ACTIVE_MODE
#include <NimBLEDevice.h>
#include <Preferences.h>
#endif

#ifndef FIRMWARE_VERSION
#define FIRMWARE_VERSION "v5.1-dev"
#endif

#ifndef BUILD_PROFILE
#ifdef ACTIVE_MODE
#define BUILD_PROFILE "active_unknown"
#else
#define BUILD_PROFILE "field_passive"
#endif
#endif

#ifdef ACTIVE_MODE
#define ACTIVE_STATE_LABEL "yes"
#else
#define ACTIVE_STATE_LABEL "no"
#endif

#ifndef NO_WIFI
#define WIFI_STATE_LABEL "yes"
#else
#define WIFI_STATE_LABEL "no"
#endif

static const char *resetReasonLabel() {
  switch (esp_reset_reason()) {
    case ESP_RST_POWERON: return "poweron";
    case ESP_RST_EXT: return "external";
    case ESP_RST_SW: return "software";
    case ESP_RST_PANIC: return "panic";
    case ESP_RST_INT_WDT: return "interrupt_watchdog";
    case ESP_RST_TASK_WDT: return "task_watchdog";
    case ESP_RST_WDT: return "other_watchdog";
    case ESP_RST_DEEPSLEEP: return "deepsleep";
    case ESP_RST_BROWNOUT: return "brownout";
    case ESP_RST_SDIO: return "sdio";
    default: return "unknown";
  }
}

HardwareSerial LIN(1);

#define LIN_RX_PIN              5
#define LIN_TX_PIN              4
#define MAX_DATA_LEN            8
#define MAX_FRAME_BYTES         9
#define BREAK_GAP_MS            2
#define FRAME_IDLE_TIMEOUT_MS   8
#define RAW_BYTE_LOG_ENABLED    0
#define RING_BUF_SIZE           128
// Active TX mode is enabled by the platformio.ini -DACTIVE_MODE build flag.
// Remove that flag to build passive-only firmware.

#ifdef ACTIVE_MODE
#define TX_DUTY_PERIOD_MS       20000
#define TX_BURST_GAP_MS         50
#define TX_ALIVE_PERIOD_MS      500
#define TX_BUS_IDLE_MIN_MS      2
#define TX_MAX_FRAMES_PER_SEC   10
#define TX_ACTIVE_SESSION_MAX_MS 300000UL
#define DBLCLICK_WINDOW_MS      800
#define TX_ALTERNATION_GAP_MS   300
#define ANTI_NAG_MODE_DUTY      0
#define ANTI_NAG_MODE_ALWAYS    1
#define CONFIG_VERSION          1
#define ACTIVE_EVENT_LOG_SIZE   16

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
  {"3",    0x2A, 7, "Model 3 left scroll wheel from 2026-05-28 capture"},
  {"y",    0x2A, 7, "Model Y likely same as Model 3 left scroll wheel; verify passively"},
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
static bool txSendFrame(uint8_t rawId, const uint8_t *data, uint8_t dataLen);
static void serviceAntiNag();
static void serviceAliveTx();
#endif

static bool parseUintToken(const char *text, const char **next, uint32_t maxValue, uint32_t *out, bool preferHexByte) {
  if (!text || !out) return false;

  const char *p = text;
  while (*p == ' ' || *p == '\t' || *p == ',') p++;
  if (*p == '\0') return false;

  char token[16] = {0};
  uint8_t len = 0;
  while (*p && *p != ',' && *p != ' ' && *p != '\t' && len < sizeof(token) - 1) {
    token[len++] = *p++;
  }
  token[len] = '\0';
  if (next) *next = p;
  if (len == 0) return false;

  uint8_t base = 10;
  const char *number = token;
  if ((token[0] == '0') && (token[1] == 'x' || token[1] == 'X')) {
    base = 16;
    number = token + 2;
  } else if (len > 2 && (token[0] == '0') && (token[1] == 'd' || token[1] == 'D')) {
    base = 10;
    number = token + 2;
  } else if (preferHexByte && len <= 2) {
    base = 16;
  } else {
    for (uint8_t i = 0; i < len; i++) {
      if ((token[i] >= 'a' && token[i] <= 'f') || (token[i] >= 'A' && token[i] <= 'F')) {
        base = 16;
        break;
      }
    }
  }

  if (*number == '\0') return false;
  char *end = nullptr;
  unsigned long parsed = strtoul(number, &end, base);
  if (!end || *end != '\0' || parsed > maxValue) return false;

  *out = (uint32_t)parsed;
  return true;
}

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
uint32_t txInhibitCount = 0;
uint32_t txRateWindowMs = 0;
uint8_t txRateWindowCount = 0;
uint32_t activeSessionStartMs = 0;
bool activeTxArmed = false;
bool faultLockout = false;
char lastTxInhibitReason[32] = "none";
char lastFaultReason[32] = "none";
uint32_t faultCount = 0;
uint32_t lastFaultMs = 0;
uint32_t safetyChecksumBadSeen = 0;
uint32_t safetyParityBadSeen = 0;
uint32_t safetySyncErrSeen = 0;
uint32_t rxDominantSinceMs = 0;
char configLoadStatus[48] = "not_loaded";
Preferences configPrefs;
bool configPrefsOpen = false;

struct ActiveEvent {
  uint32_t uptimeMs;
  char type[16];
  char detail[48];
};

ActiveEvent activeEvents[ACTIVE_EVENT_LOG_SIZE];
uint8_t activeEventHead = 0;
uint32_t activeEventTotal = 0;

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
#define BLE_CHAR_STATUS_UUID "beb5483e-36e1-4688-b7f5-ea07361b26ac"
#define BLE_CHAR_CAPS_UUID   "beb5483e-36e1-4688-b7f5-ea07361b26ad"

static NimBLEServer       *bleServer     = nullptr;
static NimBLEService      *bleService    = nullptr;
static NimBLECharacteristic *bleCharModel  = nullptr;
static NimBLECharacteristic *bleCharMode   = nullptr;
static NimBLECharacteristic *bleCharPeriod = nullptr;
static NimBLECharacteristic *bleCharEnable = nullptr;
static NimBLECharacteristic *bleCharStatus = nullptr;
static NimBLECharacteristic *bleCharCaps   = nullptr;
static bool bleClientConnected = false;
static bool bleAdvPending = true;  // Deferred advertising flag
static uint32_t bleLastAdvAttemptMs = 0;

static void initBleConfig();
static void updateBleStatus();

static void appendActiveEvent(const char *type, const char *detail, bool persist) {
  ActiveEvent &event = activeEvents[activeEventHead];
  event.uptimeMs = millis();
  strncpy(event.type, type ? type : "event", sizeof(event.type) - 1);
  event.type[sizeof(event.type) - 1] = '\0';
  strncpy(event.detail, detail ? detail : "", sizeof(event.detail) - 1);
  event.detail[sizeof(event.detail) - 1] = '\0';
  activeEventHead = (activeEventHead + 1) % ACTIVE_EVENT_LOG_SIZE;
  activeEventTotal++;

  if (persist && configPrefsOpen) {
    uint32_t slot = configPrefs.getUInt("elog_slot", 0) % ACTIVE_EVENT_LOG_SIZE;
    char key[8];
    snprintf(key, sizeof(key), "ev%02lu", (unsigned long)slot);
    char value[96];
    snprintf(value, sizeof(value), "%lu;%s;%s", (unsigned long)event.uptimeMs, event.type, event.detail);
    configPrefs.putString(key, value);
    configPrefs.putUInt("elog_slot", (slot + 1) % ACTIVE_EVENT_LOG_SIZE);
    configPrefs.putUInt("elog_total", configPrefs.getUInt("elog_total", 0) + 1);
  }
}

static void dumpActiveEvents() {
  Serial.printf("events: ram_total=%lu persisted_total=%lu\n",
    (unsigned long)activeEventTotal,
    configPrefsOpen ? (unsigned long)configPrefs.getUInt("elog_total", 0) : 0UL);

  uint32_t count = activeEventTotal < ACTIVE_EVENT_LOG_SIZE ? activeEventTotal : ACTIVE_EVENT_LOG_SIZE;
  uint32_t start = (activeEventHead + ACTIVE_EVENT_LOG_SIZE - count) % ACTIVE_EVENT_LOG_SIZE;
  for (uint32_t i = 0; i < count; i++) {
    ActiveEvent &event = activeEvents[(start + i) % ACTIVE_EVENT_LOG_SIZE];
    Serial.printf(" event[%lu] t=%lu type=%s detail=%s\n",
      (unsigned long)i,
      (unsigned long)event.uptimeMs,
      event.type,
      event.detail);
  }

  if (configPrefsOpen) {
    Serial.println("events: persisted recent slots");
    for (uint32_t i = 0; i < ACTIVE_EVENT_LOG_SIZE; i++) {
      char key[8];
      snprintf(key, sizeof(key), "ev%02lu", (unsigned long)i);
      if (!configPrefs.isKey(key)) continue;
      String value = configPrefs.getString(key, "");
      if (value.length() > 0) Serial.printf(" persisted[%02lu] %s\n", (unsigned long)i, value.c_str());
    }
  }
}

static const ModelProfile *findModelProfile(const char *name) {
  if (!name || !*name) return nullptr;
  for (int i = 0; i < NUM_MODEL_PROFILES; i++) {
    if (strcmp(name, MODEL_PROFILES[i].name) == 0) return &MODEL_PROFILES[i];
  }
  return nullptr;
}

static uint32_t configCrc(const char *name, uint8_t mode, uint32_t periodMs) {
  uint32_t crc = 2166136261UL;
  const char *p = name ? name : "";
  while (*p) {
    crc ^= (uint8_t)(*p++);
    crc *= 16777619UL;
  }
  crc ^= mode;
  crc *= 16777619UL;
  for (uint8_t i = 0; i < 4; i++) {
    crc ^= (uint8_t)((periodMs >> (i * 8)) & 0xFF);
    crc *= 16777619UL;
  }
  crc ^= CONFIG_VERSION;
  crc *= 16777619UL;
  return crc;
}

static void noteTxInhibit(const char *reason) {
  txInhibitCount++;
  strncpy(lastTxInhibitReason, reason ? reason : "unknown", sizeof(lastTxInhibitReason) - 1);
  lastTxInhibitReason[sizeof(lastTxInhibitReason) - 1] = '\0';
  bool persist = reason && strcmp(reason, "bus_busy") != 0;
  appendActiveEvent("inhibit", lastTxInhibitReason, persist);
}

static void applyModelProfile(const ModelProfile *profile, const char *source) {
  if (!profile) return;
  activeProfile = profile;
  strncpy(modelName, profile->name, sizeof(modelName) - 1);
  modelName[sizeof(modelName) - 1] = '\0';
  Serial.printf("%s: model=%s id=0x%02X (%s)\n", source, modelName, activeProfile->controlId, activeProfile->notes);
  appendActiveEvent("model", modelName, true);
}

static void saveConfig(const char *reason) {
  if (!configPrefsOpen) return;
  uint32_t crc = configCrc(modelName, antiNagMode, dutyPeriodMs);
  configPrefs.putUChar("ver", CONFIG_VERSION);
  configPrefs.putString("model", modelName);
  configPrefs.putUChar("mode", antiNagMode);
  configPrefs.putUInt("period", dutyPeriodMs);
  configPrefs.putUInt("crc", crc);
  Serial.printf("config: saved reason=%s model=%s mode=%s period=%lums crc=0x%08lX\n",
    reason ? reason : "unknown",
    modelName,
    antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
    (unsigned long)dutyPeriodMs,
    (unsigned long)crc);
  appendActiveEvent("config", reason ? reason : "save", true);
}

static void loadConfig() {
  configPrefsOpen = configPrefs.begin("antinag", false);
  if (!configPrefsOpen) {
    strncpy(configLoadStatus, "nvs_open_failed", sizeof(configLoadStatus) - 1);
    return;
  }

  uint8_t version = configPrefs.getUChar("ver", 0);
  String storedModel = configPrefs.getString("model", modelName);
  uint8_t storedMode = configPrefs.getUChar("mode", ANTI_NAG_MODE_DUTY);
  uint32_t storedPeriod = configPrefs.getUInt("period", TX_DUTY_PERIOD_MS);
  uint32_t storedCrc = configPrefs.getUInt("crc", 0);
  uint32_t expectedCrc = configCrc(storedModel.c_str(), storedMode, storedPeriod);
  const ModelProfile *profile = findModelProfile(storedModel.c_str());

  if (version == CONFIG_VERSION && storedCrc == expectedCrc && profile &&
      (storedMode == ANTI_NAG_MODE_DUTY || storedMode == ANTI_NAG_MODE_ALWAYS) &&
      storedPeriod >= 5000 && storedPeriod <= 120000) {
    activeProfile = profile;
    strncpy(modelName, storedModel.c_str(), sizeof(modelName) - 1);
    modelName[sizeof(modelName) - 1] = '\0';
    antiNagMode = storedMode;
    dutyPeriodMs = storedPeriod;
    snprintf(configLoadStatus, sizeof(configLoadStatus), "loaded crc=0x%08lX", (unsigned long)storedCrc);
    Serial.printf("config: loaded model=%s mode=%s period=%lums crc=0x%08lX\n",
      modelName,
      antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
      (unsigned long)dutyPeriodMs,
      (unsigned long)storedCrc);
  } else {
    snprintf(configLoadStatus, sizeof(configLoadStatus), "defaults reason=invalid_or_empty");
    saveConfig("defaults");
  }

  activeTxArmed = false;
  antiNagActive = false;
  dblClickEnabled = false;
  appendActiveEvent("boot", resetReasonLabel(), true);
}

static void updateBleStatus() {
  if (!bleCharStatus) return;
  char status[256];
  snprintf(status, sizeof(status),
    "fw=%s;build=%s;reset=%s;active=%s;armed=%s;model=%s;id=0x%02X;mode=%s;period=%lu;running=%s;client=%s;tx=%lu;inhibit=%lu;last=%s;faults=%lu;fault=%s;lockout=%s;config=%s",
    FIRMWARE_VERSION,
    BUILD_PROFILE,
    resetReasonLabel(),
    ACTIVE_STATE_LABEL,
    activeTxArmed ? "yes" : "no",
    modelName,
    activeProfile->controlId,
    antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
    (unsigned long)dutyPeriodMs,
    antiNagActive ? "yes" : "no",
    bleClientConnected ? "connected" : "disconnected",
    (unsigned long)txFrameCount,
    (unsigned long)txInhibitCount,
    lastTxInhibitReason,
    (unsigned long)faultCount,
    lastFaultReason,
    faultLockout ? "yes" : "no",
    configLoadStatus);
  bleCharStatus->setValue(status);
  if (bleClientConnected) bleCharStatus->notify();
}

static void stopActiveOutput(const char *reason) {
  antiNagActive = false;
  dblClickEnabled = false;
  mirrorActive = false;
  activeSessionStartMs = 0;
  if (bleCharEnable) bleCharEnable->setValue("off");
  Serial.printf("cmd: antinag=stopped reason=%s\n", reason ? reason : "manual");
  appendActiveEvent("stop", reason ? reason : "manual", true);
  updateBleStatus();
}

static bool ensureArmedForActive(const char *source) {
  if (faultLockout) {
    noteTxInhibit("fault_lockout");
    Serial.printf("%s: blocked reason=fault_lockout fault=%s; run safe:off, inspect bench, then safe:arm\n", source ? source : "active", lastFaultReason);
    updateBleStatus();
    return false;
  }
  if (activeTxArmed) return true;
  noteTxInhibit("not_armed");
  Serial.printf("%s: blocked reason=not_armed; run safe:arm on isolated bench only\n", source ? source : "active");
  updateBleStatus();
  return false;
}

static bool txAllowed(uint8_t rawId) {
  uint32_t now = millis();
  if (faultLockout) {
    noteTxInhibit("fault_lockout");
    Serial.printf("TX inhibited: reason=fault_lockout fault=%s id=0x%02X\n", lastFaultReason, rawId);
    updateBleStatus();
    return false;
  }
  if (!activeTxArmed) {
    noteTxInhibit("not_armed");
    Serial.printf("TX inhibited: reason=not_armed id=0x%02X\n", rawId);
    updateBleStatus();
    return false;
  }
  if (now - lastByteMs < TX_BUS_IDLE_MIN_MS) {
    noteTxInhibit("bus_busy");
    return false;
  }
  if (antiNagActive && activeSessionStartMs && now - activeSessionStartMs > TX_ACTIVE_SESSION_MAX_MS) {
    noteTxInhibit("session_timeout");
    stopActiveOutput("session_timeout");
    return false;
  }
  if (now - txRateWindowMs >= 1000) {
    txRateWindowMs = now;
    txRateWindowCount = 0;
  }
  if (txRateWindowCount >= TX_MAX_FRAMES_PER_SEC) {
    noteTxInhibit("rate_limit");
    Serial.printf("TX inhibited: reason=rate_limit id=0x%02X\n", rawId);
    updateBleStatus();
    return false;
  }
  txRateWindowCount++;
  return true;
}

static void recordActiveFault(const char *reason) {
  faultCount++;
  lastFaultMs = millis();
  strncpy(lastFaultReason, reason ? reason : "unknown", sizeof(lastFaultReason) - 1);
  lastFaultReason[sizeof(lastFaultReason) - 1] = '\0';
  faultLockout = true;
  activeTxArmed = false;
  noteTxInhibit(lastFaultReason);
  stopActiveOutput(lastFaultReason);
  appendActiveEvent("fault", lastFaultReason, true);
  Serial.printf("FAULT: reason=%s count=%lu lockout=yes armed=no active=off\n", lastFaultReason, (unsigned long)faultCount);
  updateBleStatus();
}

static void serviceActiveSafety() {
  if (!activeTxArmed && !antiNagActive) {
    rxDominantSinceMs = 0;
    safetyChecksumBadSeen = checksumBadCount;
    safetyParityBadSeen = parityBadCount;
    safetySyncErrSeen = syncErrCount;
    return;
  }

  if (checksumBadCount > safetyChecksumBadSeen || parityBadCount > safetyParityBadSeen || syncErrCount > safetySyncErrSeen) {
    safetyChecksumBadSeen = checksumBadCount;
    safetyParityBadSeen = parityBadCount;
    safetySyncErrSeen = syncErrCount;
    recordActiveFault("rx_integrity");
    return;
  }

  if (digitalRead(LIN_RX_PIN) == LOW) {
    uint32_t now = millis();
    if (rxDominantSinceMs == 0) rxDominantSinceMs = now;
    if (now - rxDominantSinceMs > 25) {
      rxDominantSinceMs = 0;
      recordActiveFault("dominant_timeout");
    }
  } else {
    rxDominantSinceMs = 0;
  }
}

/** Callbacks for BLE characteristic writes */
class AntiNagConfigCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo& connInfo) override {
    std::string val = pChar->getValue();
    if (val.empty()) return;

    if (pChar == bleCharModel) {
      // "x", "3", "y", "auto"
      const ModelProfile *profile = findModelProfile(val.c_str());
      if (profile) {
        applyModelProfile(profile, "BLE");
        pChar->setValue(modelName);
        saveConfig("ble_model");
      } else {
        pChar->setValue(modelName);
        Serial.printf("BLE: unknown model '%s'\n", val.c_str());
      }
    } else if (pChar == bleCharMode) {
      if (val == "duty") {
        antiNagMode = ANTI_NAG_MODE_DUTY;
        pChar->setValue("duty");
        Serial.printf("BLE: mode=duty period=%lums\n", (unsigned long)dutyPeriodMs);
        saveConfig("ble_mode");
      } else if (val == "always") {
        antiNagMode = ANTI_NAG_MODE_ALWAYS;
        pChar->setValue("always");
        Serial.println("BLE: mode=always");
        saveConfig("ble_mode");
      } else {
        pChar->setValue(antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always");
      }
    } else if (pChar == bleCharPeriod) {
      long period = atol(val.c_str());
      if (period >= 5000 && period <= 120000) {
        dutyPeriodMs = (uint32_t)period;
        char buf[16];
        snprintf(buf, sizeof(buf), "%lu", (unsigned long)dutyPeriodMs);
        pChar->setValue(buf);
        Serial.printf("BLE: period=%lums\n", (unsigned long)dutyPeriodMs);
        saveConfig("ble_period");
      } else {
        char buf[16];
        snprintf(buf, sizeof(buf), "%lu", (unsigned long)dutyPeriodMs);
        pChar->setValue(buf);
        Serial.printf("BLE: period out of range '%s'\n", val.c_str());
      }
    } else if (pChar == bleCharEnable) {
      if (val == "on") {
        if (!ensureArmedForActive("BLE enable")) {
          pChar->setValue("off");
          return;
        }
        dblClickEnabled = true;
        antiNagActive = true;
        lastDutyBurstMs = millis();
        dutyBurstDone = false;
        activeSessionStartMs = millis();
        pChar->setValue("on");
        Serial.println("BLE: antinag=enabled");
        appendActiveEvent("ble_enable", "on", true);
      } else if (val == "off") {
        stopActiveOutput("ble_off");
        pChar->setValue("off");
      } else {
        pChar->setValue(antiNagActive ? "on" : "off");
      }
    }
    updateBleStatus();
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
    bleAdvPending = true;
    bleLastAdvAttemptMs = 0;
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

  bleCharStatus = bleService->createCharacteristic(
    BLE_CHAR_STATUS_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
  );

  bleCharCaps = bleService->createCharacteristic(
    BLE_CHAR_CAPS_UUID,
    NIMBLE_PROPERTY::READ
  );
  bleCharCaps->setValue("models=x,3,y,auto;mode=duty,always;period=5000-120000;enable=requires_safe_arm;status=read_notify;build=" BUILD_PROFILE ";fw=" FIRMWARE_VERSION);
  updateBleStatus();

  NimBLEAdvertising *ad = NimBLEDevice::getAdvertising();
  ad->addServiceUUID(BLE_SVC_UUID);
  ad->setMinInterval(0x20);
  ad->setMaxInterval(0x40);
  // Advertising will start in loop() when NimBLE host is ready
  bleAdvPending = true;

  Serial.println("BLE: config ready, waiting for host sync...");
  Serial.printf("BLE: service=%s\n", BLE_SVC_UUID);
  Serial.printf("BLE: model=%s mode=%s period=%lums status_uuid=%s\n",
    modelName,
    antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
    (unsigned long)dutyPeriodMs,
    BLE_CHAR_STATUS_UUID);
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
// Auto-baud scanning - try common Tesla LIN rates
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
    // Give it a couple seconds - if frames start flowing, we stay.
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

static bool txSendFrame(uint8_t rawId, const uint8_t *data, uint8_t dataLen) {
  if (dataLen > 8) dataLen = 8;
  if (!txAllowed(rawId)) return false;

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
  updateBleStatus();
  return true;
}

static const uint8_t MODEL3Y_LEFT_COUNTER_B6[16] = {
  0x7F, 0x62, 0x45, 0x58, 0x0B, 0x16, 0x31, 0x2C,
  0x97, 0x8A, 0xAD, 0xB0, 0xE3, 0xFE, 0xD9, 0xC4
};

static bool activeProfileIsModel3YLeft() {
  return activeProfile && activeProfile->controlId == 0x2A && activeProfile->dataLen == 7;
}

static uint8_t model3yControlByte(int direction) {
  if (direction == 2) return 0x2C;
  if (direction > 0) return 0x0D;
  if (direction < 0) return 0x0B;
  return 0x0C;
}

static uint8_t buildActiveProfileFrame(int direction, int counter, uint8_t *data) {
  uint8_t ctr = (uint8_t)(counter & 0x0F);
  if (activeProfileIsModel3YLeft()) {
    data[0] = model3yControlByte(direction);
    data[1] = 0x80;
    data[2] = 0x3F;
    data[3] = 0x96;
    data[4] = 0x00;
    data[5] = (uint8_t)(0xF0 + ctr);
    data[6] = MODEL3Y_LEFT_COUNTER_B6[ctr];
    return 7;
  }

  uint8_t b0 = 0x10;
  uint8_t b1 = 0x00;
  uint8_t b2 = 0x00;
  uint8_t b3 = 0x00;
  if (direction > 0) {
    b0 = 0x11;
    b1 = 0x04;
    b2 = 0x10;
    b3 = (uint8_t)(counter * 2);
  } else if (direction < 0) {
    b0 = 0x0F;
    b1 = 0x04;
    b2 = 0x08;
    b3 = 0x02;
  }
  data[0] = b0;
  data[1] = b1;
  data[2] = b2;
  data[3] = b3;
  data[4] = 0x00;
  data[5] = 0x00;
  data[6] = 0xC0;
  data[7] = ctr;
  return 8;
}

static bool txSendActiveProfileFrame(int direction, int counter) {
  uint8_t data[8] = {0};
  uint8_t len = buildActiveProfileFrame(direction, counter, data);
  return txSendFrame(activeProfile->controlId, data, len);
}

static bool txSendModel3YVolumeFrame(int direction, int counter) {
  uint8_t data[7] = {0};
  uint8_t ctr = (uint8_t)(counter & 0x0F);
  data[0] = model3yControlByte(direction);
  data[1] = 0x80;
  data[2] = 0x3F;
  data[3] = 0x96;
  data[4] = 0x00;
  data[5] = (uint8_t)(0xF0 + ctr);
  data[6] = MODEL3Y_LEFT_COUNTER_B6[ctr];
  return txSendFrame(0x2A, data, 7);
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

    if (antiNagDirection == 1) {
      if (txSendActiveProfileFrame(1, antiNagCtr)) antiNagDirection = -1;
    } else {
      if (txSendActiveProfileFrame(-1, antiNagCtr + 1)) {
        antiNagDirection = 1;
        dutyBurstDone = true;
      }
    }
    if (dutyBurstDone || antiNagDirection == -1) antiNagCtr++;
  } else {
    if (now - lastDutyBurstMs < TX_ALTERNATION_GAP_MS) return;
    if (now - lastByteMs < TX_BUS_IDLE_MIN_MS) return;
    lastDutyBurstMs = now;
    if (txSendActiveProfileFrame(antiNagDirection, antiNagCtr)) {
      antiNagDirection = -antiNagDirection;
      antiNagCtr++;
    }
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
  if (txSendFrame(0x0D, mirrorData, 8)) aliveCtr++;
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
#ifndef NO_WIFI
  String wifiStatusString = WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : "off";
  const char *wifiStatus = wifiStatusString.c_str();
#else
    const char *wifiStatus = "disabled";
#endif
    Serial.printf("cmd: frames=%lu badChk=%lu badPid=%lu ovf=%lu short=%lu syncErr=%lu edges=%lu ring=%lu wifi=%s build=%s active=%s reset=%s\n",
      (unsigned long)frameCount, (unsigned long)checksumBadCount,
      (unsigned long)parityBadCount, (unsigned long)overflowCount,
      (unsigned long)shortFrameCount, (unsigned long)syncErrCount,
      (unsigned long)edgeCount, (unsigned long)ringTotal,
      wifiStatus,
      BUILD_PROFILE,
      ACTIVE_STATE_LABEL,
      resetReasonLabel());
    return;
  }

  if (strcmp(cmdBuf, "version") == 0) {
    Serial.printf("cmd: version fw=%s build=%s active=%s wifi=%s baud=%u reset=%s\n",
      FIRMWARE_VERSION, BUILD_PROFILE, ACTIVE_STATE_LABEL, WIFI_STATE_LABEL, linBaud, resetReasonLabel());
    return;
  }

  if (strcmp(cmdBuf, "config") == 0) {
#ifdef ACTIVE_MODE
    Serial.printf("cmd: config fw=%s build=%s reset=%s model=%s id=0x%02X mode=%s period=%lums armed=%s running=%s mirror=%s tx=%lu inhibit=%lu last=%s faults=%lu fault=%s lockout=%s nvs=%s\n",
      FIRMWARE_VERSION,
      BUILD_PROFILE,
      resetReasonLabel(),
      modelName,
      activeProfile->controlId,
      antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
      (unsigned long)dutyPeriodMs,
      activeTxArmed ? "yes" : "no",
      antiNagActive ? "yes" : "no",
      mirrorActive ? "yes" : "no",
      (unsigned long)txFrameCount,
      (unsigned long)txInhibitCount,
      lastTxInhibitReason,
      (unsigned long)faultCount,
      lastFaultReason,
      faultLockout ? "yes" : "no",
      configLoadStatus);
#else
    Serial.printf("cmd: config fw=%s build=%s active=no passive_only=true baud=%u reset=%s\n", FIRMWARE_VERSION, BUILD_PROFILE, linBaud, resetReasonLabel());
#endif
    return;
  }

  if (strcmp(cmdBuf, "safe:off") == 0) {
#ifdef ACTIVE_MODE
    activeTxArmed = false;
    faultLockout = false;
    stopActiveOutput("safe_off");
    Serial.println("cmd: safe=off armed=no");
#else
    Serial.println("cmd: safe=off passive-only build");
#endif
    return;
  }

#ifdef ACTIVE_MODE
  if (strcmp(cmdBuf, "safe:arm") == 0) {
    if (faultLockout) {
      Serial.printf("cmd: safe=arm blocked reason=fault_lockout fault=%s; run safe:off after inspection\n", lastFaultReason);
      updateBleStatus();
      return;
    }
    activeTxArmed = true;
    strncpy(lastTxInhibitReason, "none", sizeof(lastTxInhibitReason) - 1);
    lastTxInhibitReason[sizeof(lastTxInhibitReason) - 1] = '\0';
    Serial.println("cmd: safe=armed bench-only active TX allowed");
    appendActiveEvent("arm", "serial", true);
    updateBleStatus();
    return;
  }

  if (strcmp(cmdBuf, "factory:reset") == 0) {
    if (configPrefsOpen) configPrefs.clear();
    activeProfile = &MODEL_PROFILES[0];
    strncpy(modelName, activeProfile->name, sizeof(modelName) - 1);
    modelName[sizeof(modelName) - 1] = '\0';
    antiNagMode = ANTI_NAG_MODE_DUTY;
    dutyPeriodMs = TX_DUTY_PERIOD_MS;
    activeTxArmed = false;
    faultLockout = false;
    strncpy(lastFaultReason, "none", sizeof(lastFaultReason) - 1);
    lastFaultReason[sizeof(lastFaultReason) - 1] = '\0';
    faultCount = 0;
    stopActiveOutput("factory_reset");
    strncpy(configLoadStatus, "factory_reset", sizeof(configLoadStatus) - 1);
    saveConfig("factory_reset");
    Serial.println("cmd: factory reset complete; active output off and disarmed");
    appendActiveEvent("factory_reset", "serial", true);
    updateBleStatus();
    return;
  }

  if (strncmp(cmdBuf, "model:", 6) == 0) {
    const char *name = cmdBuf + 6;
    const ModelProfile *profile = findModelProfile(name);
    if (profile) {
      applyModelProfile(profile, "cmd");
      saveConfig("serial_model");
      updateBleStatus();
    } else {
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
    if (!ensureArmedForActive("cmd: antinag:start")) return;
    antiNagActive = true;
    dblClickEnabled = true;
    antiNagCtr = 0;
    antiNagDirection = 1;
    lastDutyBurstMs = millis();
    activeSessionStartMs = millis();
    dutyBurstDone = false;
    Serial.printf("cmd: antinag=active model=%s id=0x%02X mode=%s period=%lums\n",
      modelName, activeProfile->controlId,
      antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
      (unsigned long)dutyPeriodMs);
    appendActiveEvent("start", modelName, true);
    updateBleStatus();
    return;
  }
  if (strcmp(cmdBuf, "antinag:stop") == 0) {
    stopActiveOutput("serial_stop");
    return;
  }
  if (strcmp(cmdBuf, "mode:duty") == 0) {
    antiNagMode = ANTI_NAG_MODE_DUTY;
    Serial.printf("cmd: mode=duty period=%lums\n", (unsigned long)dutyPeriodMs);
    saveConfig("serial_mode");
    updateBleStatus();
    return;
  }
  if (strcmp(cmdBuf, "mode:always") == 0) {
    antiNagMode = ANTI_NAG_MODE_ALWAYS;
    Serial.println("cmd: mode=always (constant alternation)");
    saveConfig("serial_mode");
    updateBleStatus();
    return;
  }
  if (strncmp(cmdBuf, "period:", 7) == 0) {
    long period = atol(cmdBuf + 7);
    if (period >= 5000 && period <= 120000) {
      dutyPeriodMs = (uint32_t)period;
      Serial.printf("cmd: duty period=%lums\n", (unsigned long)dutyPeriodMs);
      saveConfig("serial_period");
      updateBleStatus();
    } else {
      Serial.printf("cmd: period out of range (5000-120000ms)\n");
    }
    return;
  }
  if (strcmp(cmdBuf, "antinag:single") == 0) {
    if (!ensureArmedForActive("cmd: antinag:single")) return;
    int ctr = antiNagCtr & 0x0F;
    if (txSendActiveProfileFrame(antiNagDirection, antiNagCtr)) {
      Serial.printf("cmd: antinag single model=%s dir=%s ctr=%d\n", modelName, antiNagDirection == 1 ? "UP" : "DOWN", ctr);
      antiNagDirection = -antiNagDirection;
      antiNagCtr++;
    }
    return;
  }
  if (strncmp(cmdBuf, "vol:", 4) == 0) {
    if (!ensureArmedForActive("cmd: vol")) return;
    const char *action = cmdBuf + 4;
    int direction = 0;
    if (strcmp(action, "up") == 0) {
      direction = 1;
    } else if (strcmp(action, "down") == 0) {
      direction = -1;
    } else if (strcmp(action, "click") == 0) {
      direction = 2;
    } else if (strcmp(action, "idle") == 0) {
      direction = 0;
    } else {
      Serial.println("cmd: vol unknown. Use vol:up, vol:down, vol:click, or vol:idle");
      return;
    }
    if (txSendModel3YVolumeFrame(direction, antiNagCtr)) {
      Serial.printf("cmd: vol=%s id=0x2A ctr=%d\n", action, antiNagCtr & 0x0F);
      antiNagCtr++;
    }
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
    if (!ensureArmedForActive("cmd: txd:low")) return;
    antiNagActive = false;
    LIN.flush();
    LIN.end();
    pinMode(LIN_TX_PIN, OUTPUT);
    digitalWrite(LIN_TX_PIN, LOW);
    Serial.println("cmd: txd=low dominant-hold");
    return;
  }
  if (strcmp(cmdBuf, "txd:high") == 0) {
    if (!ensureArmedForActive("cmd: txd:high")) return;
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
    if (!ensureArmedForActive("cmd: tx")) return;
    const char *p = cmdBuf + 3;
    uint32_t parsedId = 0;
    uint8_t buf[8] = {0};
    int n = 0;
    if (!parseUintToken(p, &p, 0x3F, &parsedId, true)) {
      Serial.println("cmd: tx parse error. Use tx:0C,11,04,00 or tx:0x0C,0x11,0x04. Prefix decimal as 0d12.");
      return;
    }
    while (*p && n < 8) {
      uint32_t parsedByte = 0;
      if (!parseUintToken(p, &p, 0xFF, &parsedByte, true)) break;
      buf[n++] = (uint8_t)parsedByte;
    }
    if (n > 0) {
      if (txSendFrame((uint8_t)parsedId, buf, n)) {
        Serial.printf("cmd: tx ID=0x%02X len=%d\n", (unsigned int)parsedId, n);
      }
    } else {
      Serial.println("cmd: tx requires at least one data byte");
    }
    return;
  }
  if (strcmp(cmdBuf, "ble") == 0) {
    updateBleStatus();
    NimBLEAdvertising *ad = NimBLEDevice::getAdvertising();
    bool advertising = ad && ad->isAdvertising();
    const char *advState = advertising ? "yes" : (bleAdvPending ? "pending" : "no");
    Serial.printf("cmd: BLE advertising=%s client=%s model=%s mode=%s period=%lums armed=%s running=%s last=%s\n",
      advState,
      bleClientConnected ? "connected" : "disconnected",
      modelName,
      antiNagMode == ANTI_NAG_MODE_DUTY ? "duty" : "always",
      (unsigned long)dutyPeriodMs,
      activeTxArmed ? "yes" : "no",
      antiNagActive ? "yes" : "no",
      lastTxInhibitReason);
    if (bleServer) {
      Serial.printf("BLE: service=%s\n  model uuid=%s\n  mode uuid=%s\n  period uuid=%s\n  enable uuid=%s\n  status uuid=%s\n  caps uuid=%s\n",
        BLE_SVC_UUID, BLE_CHAR_MODEL_UUID, BLE_CHAR_MODE_UUID, BLE_CHAR_PERIOD_UUID, BLE_CHAR_ENABLE_UUID,
        BLE_CHAR_STATUS_UUID, BLE_CHAR_CAPS_UUID);
    }
    return;
  }
  if (strcmp(cmdBuf, "events") == 0) {
    dumpActiveEvents();
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
        if (!activeTxArmed) {
          noteTxInhibit("button_not_armed");
          Serial.println("cmd: button double-click blocked reason=not_armed");
        } else {
          dblClickEnabled = !dblClickEnabled;
          antiNagActive = dblClickEnabled;
          if (dblClickEnabled) {
            lastDutyBurstMs = millis();
            activeSessionStartMs = millis();
          } else {
            activeSessionStartMs = 0;
          }
          Serial.printf("cmd: button double-click -> %s\n", dblClickEnabled ? "enabled" : "disabled");
        }
        updateBleStatus();
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
  Serial.printf("LIN receiver %s - build=%s active=%s wifi=%s reset=%s\n", FIRMWARE_VERSION, BUILD_PROFILE, ACTIVE_STATE_LABEL, WIFI_STATE_LABEL, resetReasonLabel());
  Serial.printf("Vehicle: %s  Default Baud: %u\n", vehicleId, linBaud);
  Serial.println("Commands: version  config  safe:off  vehicle:<id>  baud:<rate>  raw:0/1  ring  stats  vol:up/down");

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
  loadConfig();
  safetyChecksumBadSeen = checksumBadCount;
  safetyParityBadSeen = parityBadCount;
  safetySyncErrSeen = syncErrCount;
  initBleConfig();
  Serial.println("Active mode: safe:arm required before TX. BLE: TeslaAntiNag");
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
    Serial.printf("alive d3=%d edges=%lu frames=%lu badChk=%lu badPid=%lu ovf=%lu short=%lu syncErr=%lu baud=%u lastByteMs=%lu\n",
      digitalRead(LIN_RX_PIN),
      (unsigned long)edges,
      (unsigned long)frameCount,
      (unsigned long)checksumBadCount,
      (unsigned long)parityBadCount,
      (unsigned long)overflowCount,
      (unsigned long)shortFrameCount,
      (unsigned long)syncErrCount,
      linBaud,
      (unsigned long)lastByteMs);
#endif
  }

#ifdef ACTIVE_MODE
  serviceActiveSafety();
  serviceAntiNag();
  if (mirrorActive && dblClickEnabled) serviceAliveTx();
  // Retry BLE advertising after NimBLE host sync. start() returns true on success.
  NimBLEAdvertising *ad = NimBLEDevice::getAdvertising();
  if (bleAdvPending && ad && now - bleLastAdvAttemptMs >= 500) {
    bleLastAdvAttemptMs = now;
    if (ad->isAdvertising()) {
      bleAdvPending = false;
    } else {
      bool started = ad->start();
      if (started) {
        bleAdvPending = false;
        Serial.println("BLE: advertising started");
      }
    }
  }
#endif

#ifndef NO_WIFI
  serviceTelemetry();
#endif
}

#endif  // PASSTHROUGH_MODE