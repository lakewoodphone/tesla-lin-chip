#ifdef PASSTHROUGH_MODE

#include <Arduino.h>
#include <HardwareSerial.h>
#include <esp_system.h>

#ifdef BLE_ENABLED
#include <NimBLEDevice.h>
#endif

#ifndef FIRMWARE_VERSION
#define FIRMWARE_VERSION "v5.2-passthrough-dev"
#endif

#ifndef BUILD_PROFILE
#define BUILD_PROFILE "car_passthrough"
#endif

#define LIN_BAUD 19200
#ifndef CAR_RX_PIN
#define CAR_RX_PIN 5
#endif
#ifndef CAR_TX_PIN
#define CAR_TX_PIN 4
#endif
#ifndef WHEEL_RX_PIN
#define WHEEL_RX_PIN 20
#endif
#ifndef WHEEL_TX_PIN
#define WHEEL_TX_PIN 21
#endif
#ifndef LIN_EN_PIN
#define LIN_EN_PIN -1
#endif
#ifndef ARM_SENSE_PIN
#define ARM_SENSE_PIN -1
#endif
#ifndef ARM_SENSE_ACTIVE_LEVEL
#define ARM_SENSE_ACTIVE_LEVEL HIGH
#endif
#define BREAK_GAP_MS 2
#define RESPONSE_IDLE_TIMEOUT_MS 8
#define POLL_GAP_MS 8
#define ACTIVE_SESSION_MAX_MS 300000UL
#define MAX_DATA_LEN 8
#define CACHE_COUNT 64

HardwareSerial LIN_CAR(1);
HardwareSerial LIN_WHEEL(2);  // UART2: leaves Serial/UART0 on GPIO43/44 (TP6/TP7)

enum HeaderState { H_IDLE, H_SYNC, H_PID };

struct HeaderParser {
  HeaderState state = H_IDLE;
  uint32_t lastByteMs = 0;
  uint32_t headers = 0;
  uint32_t syncErrors = 0;
};

struct CachedFrame {
  uint8_t data[MAX_DATA_LEN] = {0};
  uint8_t len = 0;
  uint8_t checksum = 0;
  bool valid = false;
  uint32_t updatedMs = 0;
  uint32_t updates = 0;
};

static HeaderParser carParser;
static CachedFrame cache[CACHE_COUNT];
static char cmdBuf[96];
static uint8_t cmdIdx = 0;
static bool armed = false;
static bool bridgeEnabled = true;
static uint32_t activeSessionStartMs = 0;
static uint32_t lastHeartbeatMs = 0;
static uint32_t carResponses = 0;
static uint32_t carMisses = 0;
static uint32_t wheelPolls = 0;
static uint32_t wheelGood = 0;
static uint32_t wheelBad = 0;
static uint32_t injectedFrames = 0;
static uint32_t inhibitedFrames = 0;
static int leftInjectDirection = 0;
static int leftInjectRemaining = 0;
static uint8_t leftCounter = 0;
static bool antiNagEnabled = false;
static bool antiNagSingleCycle = false;
static uint32_t antiNagLastInjectionMs = 0;
static uint32_t antiNagIntervalMs = 15000;   // fire every 15s
static int antiNagPhase = 0;  // 0=up next, 1=down next
static uint32_t lastPollMs = 0;
static uint8_t pollIndex = 0;
static const uint8_t POLL_IDS[] = {0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D};
static const uint8_t POLL_COUNT = sizeof(POLL_IDS) / sizeof(POLL_IDS[0]);

static bool wheelAwaiting = false;
static uint8_t wheelRawId = 0;
static uint8_t wheelPid = 0;
static uint8_t wheelBytes[10] = {0};
static uint8_t wheelCount = 0;
static uint8_t wheelIgnoreEcho = 0;
static uint32_t wheelLastByteMs = 0;

static void setLinEnable(bool enable) {
  if (LIN_EN_PIN < 0) return;
  digitalWrite(LIN_EN_PIN, enable ? HIGH : LOW);
}

static bool physicalArmIsOn() {
  if (ARM_SENSE_PIN < 0) return true;
  return digitalRead(ARM_SENSE_PIN) == ARM_SENSE_ACTIVE_LEVEL;
}

static const uint8_t MODEL3Y_LEFT_COUNTER_B6[16] = {
  0x7F, 0x62, 0x45, 0x58, 0x0B, 0x16, 0x31, 0x2C,
  0x97, 0x8A, 0xAD, 0xB0, 0xE3, 0xFE, 0xD9, 0xC4
};

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
    default: return "unknown";
  }
}

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

static bool protectedIdIsValid(uint8_t pid) {
  return makeProtectedId(pid & 0x3F) == pid;
}

static uint8_t linChecksum(uint8_t pid, const uint8_t *data, uint8_t len, bool enhanced) {
  uint16_t sum = enhanced ? pid : 0;
  for (uint8_t i = 0; i < len; i++) {
    sum += data[i];
    while (sum > 0xFF) sum = (sum & 0xFF) + (sum >> 8);
  }
  return ~(uint8_t)sum;
}

static void linBreak(HardwareSerial &port) {
  uint32_t bitTimeUs = 1000000UL / LIN_BAUD;
  port.flush();
  port.updateBaudRate(LIN_BAUD / 2);
  port.write((uint8_t)0x00);
  port.flush();
  port.updateBaudRate(LIN_BAUD);
  delayMicroseconds(bitTimeUs * 2);
}

static void sendHeader(HardwareSerial &port, uint8_t rawId) {
  linBreak(port);
  port.write((uint8_t)0x55);
  port.write(makeProtectedId(rawId));
  port.flush();
}

static void buildModel3YLeftFrame(int direction, uint8_t counter, uint8_t *data, uint8_t *len) {
  uint8_t ctr = counter & 0x0F;
  uint8_t control = 0x0C;
  if (direction == 2) control = 0x2C;
  else if (direction > 0) control = 0x0D;
  else if (direction < 0) control = 0x0B;
  data[0] = control;
  data[1] = 0x80;
  data[2] = 0x3F;
  data[3] = 0x96;
  data[4] = 0x00;
  data[5] = (uint8_t)(0xF0 + ctr);
  data[6] = MODEL3Y_LEFT_COUNTER_B6[ctr];
  *len = 7;
}

static void seedCache() {
  CachedFrame &id28 = cache[0x28];
  const uint8_t d28[5] = {0x68, 0x3C, 0x32, 0x22, 0x80};
  memcpy(id28.data, d28, sizeof(d28));
  id28.len = sizeof(d28);
  id28.checksum = linChecksum(makeProtectedId(0x28), id28.data, id28.len, true);
  id28.valid = true;

  CachedFrame &id2a = cache[0x2A];
  buildModel3YLeftFrame(0, 0, id2a.data, &id2a.len);
  id2a.checksum = linChecksum(makeProtectedId(0x2A), id2a.data, id2a.len, true);
  id2a.valid = true;

  CachedFrame &id2c = cache[0x2C];
  const uint8_t d2c[5] = {0x00, 0x00, 0x00, 0x00, 0xC0};
  memcpy(id2c.data, d2c, sizeof(d2c));
  id2c.len = sizeof(d2c);
  id2c.checksum = linChecksum(makeProtectedId(0x2C), id2c.data, id2c.len, true);
  id2c.valid = true;

  CachedFrame &id2d = cache[0x2D];
  memcpy(id2d.data, d2c, sizeof(d2c));
  id2d.len = sizeof(d2c);
  id2d.checksum = linChecksum(makeProtectedId(0x2D), id2d.data, id2d.len, true);
  id2d.valid = true;

  CachedFrame &id29 = cache[0x29];
  const uint8_t d29[5] = {0x00, 0x00, 0x24, 0x0C, 0x9D};
  memcpy(id29.data, d29, sizeof(d29));
  id29.len = sizeof(d29);
  id29.checksum = linChecksum(makeProtectedId(0x29), id29.data, id29.len, true);
  id29.valid = true;

  CachedFrame &id2b = cache[0x2B];
  const uint8_t d2b[6] = {0x0C, 0x00, 0x04, 0x6C, 0x81, 0x07};
  memcpy(id2b.data, d2b, sizeof(d2b));
  id2b.len = sizeof(d2b);
  id2b.checksum = linChecksum(makeProtectedId(0x2B), id2b.data, id2b.len, true);
  id2b.valid = true;
}

static bool txAllowed() {
  if (!physicalArmIsOn()) {
    armed = false;
    setLinEnable(false);
    inhibitedFrames++;
    return false;
  }
  if (!armed || !bridgeEnabled) {
    inhibitedFrames++;
    return false;
  }
  if (activeSessionStartMs && millis() - activeSessionStartMs > ACTIVE_SESSION_MAX_MS) {
    armed = false;
    setLinEnable(false);
    inhibitedFrames++;
    return false;
  }
  return true;
}

static void writeSlaveResponse(HardwareSerial &port, uint8_t rawId, const uint8_t *data, uint8_t len) {
  uint8_t pid = makeProtectedId(rawId);
  bool enhanced = rawId < 0x3C;
  uint8_t checksum = linChecksum(pid, data, len, enhanced);
  for (uint8_t i = 0; i < len; i++) port.write(data[i]);
  port.write(checksum);
  port.flush();
}

static void handleCarPid(uint8_t pid) {
  carParser.headers++;
  if (!protectedIdIsValid(pid)) return;
  uint8_t rawId = pid & 0x3F;
  if (rawId >= CACHE_COUNT) return;
  if (!txAllowed()) return;

  if (rawId == 0x2A && leftInjectRemaining > 0) {
    uint8_t data[8] = {0};
    uint8_t len = 0;
    buildModel3YLeftFrame(leftInjectDirection, leftCounter++, data, &len);
    writeSlaveResponse(LIN_CAR, rawId, data, len);
    leftInjectRemaining--;
    injectedFrames++;
    carResponses++;
    return;
  }

  CachedFrame &frame = cache[rawId];
  if (frame.valid && frame.len > 0) {
    writeSlaveResponse(LIN_CAR, rawId, frame.data, frame.len);
    carResponses++;
  } else {
    carMisses++;
  }
}

static void serviceCarHeaders() {
  while (LIN_CAR.available()) {
    uint8_t b = LIN_CAR.read();
    uint32_t now = millis();
    uint32_t gap = now - carParser.lastByteMs;
    carParser.lastByteMs = now;

    if (b == 0x00 && gap >= BREAK_GAP_MS) {
      carParser.state = H_SYNC;
      continue;
    }

    if (carParser.state == H_SYNC) {
      if (b == 0x55) carParser.state = H_PID;
      else if (b != 0x00) {
        carParser.syncErrors++;
        carParser.state = H_IDLE;
      }
    } else if (carParser.state == H_PID) {
      handleCarPid(b);
      carParser.state = H_IDLE;
    }
  }
}

static void startWheelPoll(uint8_t rawId) {
  wheelAwaiting = true;
  wheelRawId = rawId;
  wheelPid = makeProtectedId(rawId);
  wheelCount = 0;
  wheelIgnoreEcho = 3;
  wheelLastByteMs = millis();
  sendHeader(LIN_WHEEL, rawId);
  wheelPolls++;
}

static void finalizeWheelResponse() {
  if (!wheelAwaiting) return;
  wheelAwaiting = false;
  if (wheelCount < 2 || wheelRawId >= CACHE_COUNT) {
    wheelBad++;
    return;
  }
  uint8_t dataLen = wheelCount - 1;
  if (dataLen > MAX_DATA_LEN) {
    wheelBad++;
    return;
  }
  uint8_t rxChecksum = wheelBytes[dataLen];
  uint8_t expected = linChecksum(wheelPid, wheelBytes, dataLen, wheelRawId < 0x3C);
  if (rxChecksum != expected) {
    wheelBad++;
    return;
  }

  CachedFrame &frame = cache[wheelRawId];
  memcpy(frame.data, wheelBytes, dataLen);
  frame.len = dataLen;
  frame.checksum = rxChecksum;
  frame.valid = true;
  frame.updatedMs = millis();
  frame.updates++;
  wheelGood++;
}

static void serviceWheelPoller() {
  uint32_t now = millis();
  while (LIN_WHEEL.available()) {
    uint8_t b = LIN_WHEEL.read();
    wheelLastByteMs = now;
    if (wheelIgnoreEcho > 0) {
      wheelIgnoreEcho--;
      continue;
    }
    if (wheelCount < sizeof(wheelBytes)) wheelBytes[wheelCount++] = b;
  }

  if (wheelAwaiting) {
    if (wheelCount > 0 && now - wheelLastByteMs >= RESPONSE_IDLE_TIMEOUT_MS) finalizeWheelResponse();
    if (wheelCount == 0 && now - wheelLastByteMs >= RESPONSE_IDLE_TIMEOUT_MS + 4) {
      wheelAwaiting = false;
      wheelBad++;
    }
    return;
  }

  if (now - lastPollMs >= POLL_GAP_MS) {
    lastPollMs = now;
    uint8_t id = POLL_IDS[pollIndex++ % POLL_COUNT];
    startWheelPoll(id);
  }
}

static void dumpCache() {
  Serial.println("cache: id len age_ms updates data checksum");
  uint32_t now = millis();
  for (uint8_t rawId = 0; rawId < CACHE_COUNT; rawId++) {
    CachedFrame &frame = cache[rawId];
    if (!frame.valid) continue;
    Serial.printf(" 0x%02X %u %lu %lu", rawId, frame.len,
      frame.updatedMs ? (unsigned long)(now - frame.updatedMs) : 0UL,
      (unsigned long)frame.updates);
    for (uint8_t i = 0; i < frame.len; i++) Serial.printf(" %02X", frame.data[i]);
    Serial.printf(" | %02X\n", frame.checksum);
  }
}

static void processCommand() {
  cmdBuf[cmdIdx] = '\0';
  cmdIdx = 0;

  if (strcmp(cmdBuf, "version") == 0) {
    Serial.printf("cmd: version fw=%s build=%s baud=%u reset=%s\n", FIRMWARE_VERSION, BUILD_PROFILE, LIN_BAUD, resetReasonLabel());
    return;
  }
  if (strcmp(cmdBuf, "config") == 0 || strcmp(cmdBuf, "stats") == 0) {
    Serial.printf("cmd: config build=%s armed=%s bridge=%s nag=%s nag_interval_ms=%lu car_headers=%lu responses=%lu misses=%lu injected=%lu inhibited=%lu wheel_polls=%lu wheel_good=%lu wheel_bad=%lu syncErr=%lu pending=%d inj_dir=%d\n",
      BUILD_PROFILE,
      armed ? "yes" : "no",
      bridgeEnabled ? "yes" : "no",
      antiNagEnabled ? "yes" : "no",
      (unsigned long)antiNagIntervalMs,
      (unsigned long)carParser.headers,
      (unsigned long)carResponses,
      (unsigned long)carMisses,
      (unsigned long)injectedFrames,
      (unsigned long)inhibitedFrames,
      (unsigned long)wheelPolls,
      (unsigned long)wheelGood,
      (unsigned long)wheelBad,
      (unsigned long)carParser.syncErrors,
      leftInjectRemaining,
      leftInjectDirection);
    return;
  }
  if (strcmp(cmdBuf, "safe:arm") == 0) {
    if (!physicalArmIsOn()) {
      armed = false;
      setLinEnable(false);
      Serial.println("cmd: safe=blocked physical_arm=off");
      return;
    }
    armed = true;
    activeSessionStartMs = millis();
    setLinEnable(true);
    Serial.println("cmd: safe=armed passthrough responses enabled");
    return;
  }
  if (strcmp(cmdBuf, "safe:off") == 0) {
    armed = false;
    leftInjectRemaining = 0;
    antiNagSingleCycle = false;
    activeSessionStartMs = 0;
    setLinEnable(false);
    Serial.println("cmd: safe=off armed=no pending=0");
    return;
  }
  if (strcmp(cmdBuf, "bridge:on") == 0) {
    bridgeEnabled = true;
    Serial.println("cmd: bridge=on");
    return;
  }
  if (strcmp(cmdBuf, "bridge:off") == 0) {
    bridgeEnabled = false;
    Serial.println("cmd: bridge=off");
    return;
  }
  if (strcmp(cmdBuf, "cache") == 0) {
    dumpCache();
    return;
  }
  if (strncmp(cmdBuf, "vol:", 4) == 0) {
    const char *p = cmdBuf + 4;
    char action[12] = {0};
    uint8_t i = 0;
    while (*p && *p != ':' && i < sizeof(action) - 1) action[i++] = *p++;
    int count = 6;
    if (*p == ':') count = atoi(p + 1);
    if (count < 1) count = 1;
    if (count > 64) count = 64;

    if (strcmp(action, "up") == 0) leftInjectDirection = 1;
    else if (strcmp(action, "down") == 0) leftInjectDirection = -1;
    else if (strcmp(action, "click") == 0) leftInjectDirection = 2;
    else if (strcmp(action, "idle") == 0) leftInjectDirection = 0;
    else {
      Serial.println("cmd: vol unknown. Use vol:up[:count], vol:down[:count], vol:click[:count], vol:idle[:count]");
      return;
    }
    leftInjectRemaining = count;
    Serial.printf("cmd: vol=%s pending=%d id=0x2A\n", action, leftInjectRemaining);
    return;
  }
  if (strcmp(cmdBuf, "inject:clear") == 0) {
    leftInjectRemaining = 0;
    Serial.println("cmd: inject cleared");
    return;
  }
  if (strcmp(cmdBuf, "nag:on") == 0) {
    antiNagEnabled = true;
    antiNagLastInjectionMs = 0;
    antiNagPhase = 0;
    Serial.printf("cmd: nag=enabled interval=%lums\n", (unsigned long)antiNagIntervalMs);
    return;
  }
  if (strcmp(cmdBuf, "nag:off") == 0) {
    antiNagEnabled = false;
    antiNagSingleCycle = false;
    antiNagPhase = 0;
    Serial.println("cmd: nag=disabled");
    return;
  }
  if (strcmp(cmdBuf, "nag:once") == 0) {
    if (!txAllowed()) {
      Serial.println("cmd: nag:once blocked (not armed or bridge off)");
      return;
    }
    antiNagSingleCycle = true;
    antiNagPhase = 0;
    antiNagLastInjectionMs = 0;
    Serial.println("cmd: nag:once firing up then down");
    return;
  }
  if (strcmp(cmdBuf, "nag:status") == 0) {
    Serial.printf("cmd: nag=%s once=%s phase=%d interval=%lums last_injection=%lums_ago\n",
      antiNagEnabled ? "enabled" : "disabled",
      antiNagSingleCycle ? "yes" : "no",
      antiNagPhase,
      (unsigned long)antiNagIntervalMs,
      antiNagLastInjectionMs ? (unsigned long)(millis() - antiNagLastInjectionMs) : 0UL);
    return;
  }
  if (strncmp(cmdBuf, "nag:interval:", 13) == 0) {
    unsigned long ms = strtoul(cmdBuf + 13, nullptr, 10);
    if (ms < 5000) ms = 5000;
    if (ms > 300000) ms = 300000;
    antiNagIntervalMs = ms;
    if (antiNagEnabled) antiNagLastInjectionMs = 0;
    Serial.printf("cmd: nag interval=%lums\n", (unsigned long)antiNagIntervalMs);
    return;
  }
  if (strcmp(cmdBuf, "reset") == 0) {
    Serial.println("cmd: reset rebooting ESP32...");
    delay(200);
    ESP.restart();
    return;
  }

  Serial.printf("cmd: unknown '%s'\n", cmdBuf);
}

#ifdef BLE_ENABLED
// ---- BLE passthrough config service ----
#define PT_BLE_SVC_UUID      "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define PT_BLE_CHAR_ARM_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b0"
#define PT_BLE_CHAR_BRG_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b1"
#define PT_BLE_CHAR_VOL_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b2"
#define PT_BLE_CHAR_STS_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b3"
#define PT_BLE_CHAR_CAP_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b4"
#define PT_BLE_CHAR_NAG_UUID "beb5483e-36e1-4688-b7f5-ea07361b26b5"

static NimBLEServer         *ptBleServer  = nullptr;
static NimBLEService        *ptBleService = nullptr;
static NimBLECharacteristic *ptBleArm     = nullptr;
static NimBLECharacteristic *ptBleBridge  = nullptr;
static NimBLECharacteristic *ptBleVol     = nullptr;
static NimBLECharacteristic *ptBleStatus  = nullptr;
static NimBLECharacteristic *ptBleNag     = nullptr;
static bool ptBleConnected   = false;
static bool ptBleAdvPending  = true;
static uint32_t ptBleLastAdvMs = 0;

static void updatePtBleStatus() {
  if (!ptBleStatus) return;
  char buf[200];
  snprintf(buf, sizeof(buf),
    "armed=%s bridge=%s nag=%s nag_interval_ms=%lu car_hdr=%lu resp=%lu miss=%lu inj=%lu inh=%lu wpoll=%lu wgood=%lu wbad=%lu pending=%d dir=%d",
    armed ? "yes" : "no",
    bridgeEnabled ? "yes" : "no",
    antiNagEnabled ? "yes" : "no",
    (unsigned long)antiNagIntervalMs,
    (unsigned long)carParser.headers,
    (unsigned long)carResponses,
    (unsigned long)carMisses,
    (unsigned long)injectedFrames,
    (unsigned long)inhibitedFrames,
    (unsigned long)wheelPolls,
    (unsigned long)wheelGood,
    (unsigned long)wheelBad,
    leftInjectRemaining,
    leftInjectDirection);
  ptBleStatus->setValue(buf);
  if (ptBleConnected) ptBleStatus->notify();
}

class PtBleCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *pChar, NimBLEConnInfo &connInfo) override {
    std::string val = pChar->getValue();
    if (val.empty()) return;

    if (pChar == ptBleArm) {
      if (val == "arm") {
        if (!physicalArmIsOn()) {
          pChar->setValue("off");
          Serial.println("BLE: arm blocked (physical arm off)");
        } else {
          armed = true;
          activeSessionStartMs = millis();
          setLinEnable(true);
          pChar->setValue("armed");
          Serial.println("BLE: armed");
        }
      } else {
        armed = false;
        leftInjectRemaining = 0;
        activeSessionStartMs = 0;
        setLinEnable(false);
        pChar->setValue("off");
        Serial.println("BLE: disarmed");
      }
      updatePtBleStatus();
    } else if (pChar == ptBleBridge) {
      bridgeEnabled = (val == "on");
      pChar->setValue(bridgeEnabled ? "on" : "off");
      Serial.printf("BLE: bridge=%s\n", bridgeEnabled ? "on" : "off");
      updatePtBleStatus();
    } else if (pChar == ptBleVol) {
      const char *p = val.c_str();
      char action[12] = {0};
      uint8_t i = 0;
      while (*p && *p != ':' && i < 11) action[i++] = *p++;
      int count = 6;
      if (*p == ':') count = atoi(p + 1);
      if (count < 1) count = 1;
      if (count > 64) count = 64;
      if (strcmp(action, "up") == 0) leftInjectDirection = 1;
      else if (strcmp(action, "down") == 0) leftInjectDirection = -1;
      else if (strcmp(action, "click") == 0) leftInjectDirection = 2;
      else if (strcmp(action, "idle") == 0) leftInjectDirection = 0;
      else { pChar->setValue("err"); return; }
      leftInjectRemaining = count;
      Serial.printf("BLE: vol=%s pending=%d\n", action, leftInjectRemaining);
      updatePtBleStatus();
    } else if (pChar == ptBleNag) {
      if (val == "on") {
        antiNagEnabled = true;
        antiNagLastInjectionMs = 0;
        antiNagPhase = 0;
        ptBleNag->setValue("on");
        Serial.printf("BLE: nag=enabled interval=%lums\n", (unsigned long)antiNagIntervalMs);
      } else if (val == "off") {
        antiNagEnabled = false;
        antiNagPhase = 0;
        ptBleNag->setValue("off");
        Serial.println("BLE: nag=disabled");
      } else {
        unsigned long ms = strtoul(val.c_str(), nullptr, 10);
        if (ms >= 5000 && ms <= 300000) {
          antiNagIntervalMs = ms;
          if (antiNagEnabled) antiNagLastInjectionMs = 0;
          char buf[16];
          snprintf(buf, sizeof(buf), "%lu", ms);
          ptBleNag->setValue(buf);
          Serial.printf("BLE: nag interval=%lums\n", (unsigned long)antiNagIntervalMs);
        }
      }
      updatePtBleStatus();
    }
  }
};

class PtBleServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *, NimBLEConnInfo &) override {
    ptBleConnected = true;
    Serial.println("BLE: connected");
    updatePtBleStatus();
  }
  void onDisconnect(NimBLEServer *, NimBLEConnInfo &, int) override {
    ptBleConnected = false;
    Serial.println("BLE: disconnected");
    ptBleAdvPending = true;
    ptBleLastAdvMs = 0;
  }
};

static void initPtBle() {
  NimBLEDevice::init("TeslaPassthrough");
  delay(100);
  ptBleServer = NimBLEDevice::createServer();
  ptBleServer->setCallbacks(new PtBleServerCallbacks());
  ptBleService = ptBleServer->createService(PT_BLE_SVC_UUID);

  ptBleArm = ptBleService->createCharacteristic(PT_BLE_CHAR_ARM_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
  ptBleArm->setCallbacks(new PtBleCallbacks());
  ptBleArm->setValue("off");

  ptBleBridge = ptBleService->createCharacteristic(PT_BLE_CHAR_BRG_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
  ptBleBridge->setCallbacks(new PtBleCallbacks());
  ptBleBridge->setValue("on");

  ptBleVol = ptBleService->createCharacteristic(PT_BLE_CHAR_VOL_UUID,
    NIMBLE_PROPERTY::WRITE);
  ptBleVol->setCallbacks(new PtBleCallbacks());

  ptBleStatus = ptBleService->createCharacteristic(PT_BLE_CHAR_STS_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

  ptBleNag = ptBleService->createCharacteristic(PT_BLE_CHAR_NAG_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
  ptBleNag->setCallbacks(new PtBleCallbacks());
  ptBleNag->setValue("off");

  NimBLECharacteristic *ptBleCaps = ptBleService->createCharacteristic(
    PT_BLE_CHAR_CAP_UUID, NIMBLE_PROPERTY::READ);
  ptBleCaps->setValue(
    "arm=arm/off;bridge=on/off;nag=on/off/interval_ms;vol=up/down/click/idle[:count];"
    "status=read_notify;build=" BUILD_PROFILE ";fw=" FIRMWARE_VERSION);

  ptBleService->start();
  updatePtBleStatus();

  NimBLEAdvertising *ad = NimBLEDevice::getAdvertising();
  ad->addServiceUUID(PT_BLE_SVC_UUID);
  ad->setMinInterval(0x20);
  ad->setMaxInterval(0x40);
  ptBleAdvPending = true;
}

static void servicePtBleAdv(uint32_t now) {
  if (ptBleConnected) return;
  if (!ptBleAdvPending) return;
  if (now - ptBleLastAdvMs < 2000) return;
  ptBleLastAdvMs = now;
  NimBLEAdvertising *ad = NimBLEDevice::getAdvertising();
  if (!ad->isAdvertising()) {
    ad->start();
    Serial.println("BLE: advertising");
  }
  ptBleAdvPending = false;
}
#endif // BLE_ENABLED

static void serviceAntiNag(uint32_t now) {
  if (!antiNagEnabled && !antiNagSingleCycle) return;
  if (!txAllowed()) return;
  if (leftInjectRemaining > 0) return;

  bool intervalDue = antiNagLastInjectionMs == 0 || now - antiNagLastInjectionMs >= antiNagIntervalMs;
  if (!antiNagSingleCycle && antiNagPhase == 0 && !intervalDue) return;

  if (antiNagPhase == 0) {
    antiNagPhase = 1;
    leftInjectDirection = 1;   // up
    leftInjectRemaining = 1;
  } else if (antiNagPhase == 1) {
    antiNagPhase = 0;
    leftInjectDirection = -1;  // down
    leftInjectRemaining = 1;
    antiNagLastInjectionMs = now;
    antiNagSingleCycle = false;
  }
}

static void serviceSerial() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (cmdIdx > 0) processCommand();
    } else if (cmdIdx < sizeof(cmdBuf) - 1) {
      cmdBuf[cmdIdx++] = c;
    }
  }
}

void setup() {
  if (LIN_EN_PIN >= 0) {
    pinMode(LIN_EN_PIN, OUTPUT);
    setLinEnable(false);
  }
  if (ARM_SENSE_PIN >= 0) {
    pinMode(ARM_SENSE_PIN, INPUT_PULLDOWN);
  }
  Serial.begin(115200);
  delay(1200);
  Serial.printf("LIN passthrough %s build=%s reset=%s\n", FIRMWARE_VERSION, BUILD_PROFILE, resetReasonLabel());
  Serial.printf("car RX=%d TX=%d wheel RX=%d TX=%d lin_en=%d arm_sense=%d baud=%d\n", CAR_RX_PIN, CAR_TX_PIN, WHEEL_RX_PIN, WHEEL_TX_PIN, LIN_EN_PIN, ARM_SENSE_PIN, LIN_BAUD);
  Serial.println("Commands: version config stats safe:arm safe:off bridge:on/off nag:on/off/once/status nag:interval:<ms> cache vol:up[:count] vol:down[:count] vol:click[:count] inject:clear reset");
  seedCache();
  LIN_CAR.begin(LIN_BAUD, SERIAL_8N1, CAR_RX_PIN, CAR_TX_PIN);
  LIN_WHEEL.begin(LIN_BAUD, SERIAL_8N1, WHEEL_RX_PIN, WHEEL_TX_PIN);
#ifdef BLE_ENABLED
  initPtBle();
  Serial.println("BLE: init done");
#endif
}

void loop() {
  uint32_t now = millis();
  serviceSerial();
  serviceCarHeaders();
  serviceWheelPoller();
  serviceAntiNag(now);
#ifdef BLE_ENABLED
  servicePtBleAdv(now);
#endif

  if (now - lastHeartbeatMs >= 1000) {
    lastHeartbeatMs = now;
    Serial.printf("alive armed=%s bridge=%s car=%lu resp=%lu miss=%lu inj=%lu wheel=%lu/%lu bad=%lu pending=%d\n",
      armed ? "yes" : "no",
      bridgeEnabled ? "yes" : "no",
      (unsigned long)carParser.headers,
      (unsigned long)carResponses,
      (unsigned long)carMisses,
      (unsigned long)injectedFrames,
      (unsigned long)wheelGood,
      (unsigned long)wheelPolls,
      (unsigned long)wheelBad,
      leftInjectRemaining);
#ifdef BLE_ENABLED
    updatePtBleStatus();
#endif
  }
}

#endif
