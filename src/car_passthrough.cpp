#ifdef PASSTHROUGH_MODE

#include <Arduino.h>
#include <HardwareSerial.h>
#include <esp_system.h>

#ifndef FIRMWARE_VERSION
#define FIRMWARE_VERSION "v5.2-passthrough-dev"
#endif

#ifndef BUILD_PROFILE
#define BUILD_PROFILE "car_passthrough"
#endif

#define LIN_BAUD 19200
#define CAR_RX_PIN 5
#define CAR_TX_PIN 4
#define WHEEL_RX_PIN 20
#define WHEEL_TX_PIN 21
#define BREAK_GAP_MS 2
#define RESPONSE_IDLE_TIMEOUT_MS 8
#define POLL_GAP_MS 8
#define ACTIVE_SESSION_MAX_MS 300000UL
#define MAX_DATA_LEN 8
#define CACHE_COUNT 64

HardwareSerial LIN_CAR(1);
HardwareSerial LIN_WHEEL(0);

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
}

static bool txAllowed() {
  if (!armed || !bridgeEnabled) {
    inhibitedFrames++;
    return false;
  }
  if (activeSessionStartMs && millis() - activeSessionStartMs > ACTIVE_SESSION_MAX_MS) {
    armed = false;
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
    Serial.printf("cmd: config build=%s armed=%s bridge=%s car_headers=%lu responses=%lu misses=%lu injected=%lu inhibited=%lu wheel_polls=%lu wheel_good=%lu wheel_bad=%lu syncErr=%lu pending=%d\n",
      BUILD_PROFILE,
      armed ? "yes" : "no",
      bridgeEnabled ? "yes" : "no",
      (unsigned long)carParser.headers,
      (unsigned long)carResponses,
      (unsigned long)carMisses,
      (unsigned long)injectedFrames,
      (unsigned long)inhibitedFrames,
      (unsigned long)wheelPolls,
      (unsigned long)wheelGood,
      (unsigned long)wheelBad,
      (unsigned long)carParser.syncErrors,
      leftInjectRemaining);
    return;
  }
  if (strcmp(cmdBuf, "safe:arm") == 0) {
    armed = true;
    activeSessionStartMs = millis();
    Serial.println("cmd: safe=armed passthrough responses enabled");
    return;
  }
  if (strcmp(cmdBuf, "safe:off") == 0) {
    armed = false;
    leftInjectRemaining = 0;
    activeSessionStartMs = 0;
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

  Serial.printf("cmd: unknown '%s'\n", cmdBuf);
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
  Serial.begin(115200);
  delay(1200);
  Serial.printf("LIN passthrough %s build=%s reset=%s\n", FIRMWARE_VERSION, BUILD_PROFILE, resetReasonLabel());
  Serial.printf("car RX=%d TX=%d wheel RX=%d TX=%d baud=%d\n", CAR_RX_PIN, CAR_TX_PIN, WHEEL_RX_PIN, WHEEL_TX_PIN, LIN_BAUD);
  Serial.println("Commands: version config stats safe:arm safe:off bridge:on/off cache vol:up[:count] vol:down[:count] inject:clear");
  seedCache();
  LIN_CAR.begin(LIN_BAUD, SERIAL_8N1, CAR_RX_PIN, CAR_TX_PIN);
  LIN_WHEEL.begin(LIN_BAUD, SERIAL_8N1, WHEEL_RX_PIN, WHEEL_TX_PIN);
}

void loop() {
  uint32_t now = millis();
  serviceSerial();
  serviceCarHeaders();
  serviceWheelPoller();

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
  }
}

#endif
