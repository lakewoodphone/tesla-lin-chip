# Audit Log — Tesla LIN Bench v5 BLE Finalization

Timestamp: 2026-05-27 16:45 -04:00
Node: desktop (ZABZ-TECH)
Slot: slot-01, session a507b8c7 ("Tesla anti-nag project details")

## Scope

Complete the BLE config service build that was started in the previous session,
update all project documentation, and finalize v5 as the default firmware.

## Work Completed

### Firmware v5 — ACTIVE_MODE + BLE (src/main.cpp)
- Enabled `ACTIVE_MODE` permanently via `-DACTIVE_MODE` in platformio.ini
- Added NimBLE Arduino dependency (`h2zero/NimBLE-Arduino @ ^2.2.0`)
- Fixed NimBLE 2.5.0 API incompatibilities:
  - `onWrite(NimBLECharacteristic*, NimBLEConnInfo&)` — was missing ConnInfo param
  - `onConnect(NimBLEServer*, NimBLEConnInfo&)` — same
  - `onDisconnect(NimBLEServer*, NimBLEConnInfo&, int reason)` — added reason param
  - `setMinInterval`/`setMaxInterval` — was `setMinPreferred`/`setMaxPreferred`
- Implemented BLE config service with 4 characteristics:
  - Model: "x", "3", "y", "auto" (UUID ...b26a8)
  - Mode: "duty", "always" (UUID ...b26a9)
  - Period: 5000-120000ms string (UUID ...b26aa)
  - Enable: "on", "off" (UUID ...b26ab)
- Deferred advertising retry in loop() for NimBLE host sync delay (rc=3)
- Added `ble` serial command for BLE diagnostics
- Build: RAM 16.1%, Flash 85.0%, SUCCESS

### Flash & Verify
- Flashed v5 to XIAO ESP32-C3 on COM4 (esptool --no-stub not needed; direct works)
- Confirmed BLE advertising: first attempt rc=3 (host busy), retry succeeds
- Firmware shows: "BLE: config ready... BLE: advertising started"
- XIAO alive heartbeats flowing, 0 badChk/badPid

### Documentation Updated
- README.md: removed stale "ACTIVE_MODE commented out" and "BLE not enabled" lines
- BENCH_EVIDENCE.md: updated active/ble references to match v5 default
- ACTIVE_INJECTOR.md: added BLE Configuration section, updated flash commands
- TOOLS.md: updated version note for v5 ACTIVE_MODE + BLE
- NEXT_STEPS.md: updated current state, added BLE to Done list
- START_HERE.md: added BLE features to table and improvements list, updated date

### Git Push
- Committed to xiao-lin-bench: `52dc702` on master
- Pushed to github.com/lakewoodphone/xiao-lin-bench
- 5 files changed, +286/-44 lines

## Current State

- Firmware: v5 with ACTIVE_MODE + NimBLE BLE, flashed and verified on bench XIAO (COM4)
- BLE: advertising as "TeslaAntiNag", 4 config characteristics
- Passive: 80/80 evidence suite passing
- Active: Model X bench TX self-receive and APG raw observer proven
- All docs reflect v5 defaults (no stale "commented out" or "not enabled" references)

## Next Actions (if resumed)

1. Test BLE with a phone app (nRF Connect / LightBlue) — connect, write "on" to enable
2. For car day: run quick bench evidence, pack kit
3. For Model 3/Y: passive capture first, confirm IDs before active
4. If WiFi wanted: update src/secrets.h with real credentials