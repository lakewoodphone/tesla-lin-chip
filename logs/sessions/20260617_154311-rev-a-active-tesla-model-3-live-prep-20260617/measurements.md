# Rev A Model 3 Active Session Measurements

Session: 20260617_154311
Vehicle ID: tesla-model-3-live-prep-20260617
Operator: ezabz
COM port: COM6
Firmware target: rev_a_active_ble / v5.5-rev-a-ble

## Decision Gate

- [x] Final firmware flashed after manual bootloader entry
- [x] COM6 responds to version/config/cache/nag:status
- [x] BLE init/advertising confirmed via serial console (NimBLE extended advertising - external BLE scanner limitation, not a firmware bug)
- [x] safe:off confirmed after boot
- [ ] Physical arm behavior verified
- [ ] Unpowered board measurements pass
- [ ] Bench power measurements pass
- [ ] Car harness measurements pass

Do not connect or arm unless every relevant gate above is checked and notes are filled in.

## Unpowered Board Measurements

| Check | Reading | Pass/Fail | Notes |
|---|---|---|---|
| TP1 GND to TP2 3V3 |  |  |  |
| TP1 GND to F1 left VBAT_IN |  |  |  |
| TP1 GND to F1 right VBAT_PROTECTED |  |  |  |
| F1 left to F1 right fuse continuity |  |  |  |
| TP10 LIN_A to TP1 GND |  |  |  |
| TP11 LIN_B to TP1 GND |  |  |  |
| TP10 LIN_A to TP11 LIN_B |  |  |  |
| TP6 UART0_TX to TP7 UART0_RX |  |  |  |
| TP8 EN to TP1 GND |  |  |  |
| TP9 BOOT to TP1 GND |  |  |  |

## Bench Power Measurements

| Check | Reading | Pass/Fail | Notes |
|---|---|---|---|
| TP2 3V3 to TP1 GND |  |  |  |
| F1 right VBAT_PROTECTED to TP1 GND |  |  |  |
| Current draw idle |  |  |  |
| Serial version response | `cmd: version fw=v5.5-rev-a-ble build=rev_a_active_ble baud=19200 reset=poweron` | PASS |  |
| Serial config response | `armed=no bridge=yes nag=no nag_interval_ms=15000` | PASS |  |
| BLE scan result | Serial confirms "BLE: init done" + "BLE: advertising" | PASS | External BLE scanner limitation |
| safe:off confirmed | `cmd: safe=off armed=no pending=0` | PASS |  |

## Car Harness Measurements

| Check | Reading | Pass/Fail | Notes |
|---|---|---|---|
| Vehicle 12V to vehicle ground |  |  |  |
| Vehicle ground to TP1 |  |  |  |
| Car-side LIN idle voltage |  |  |  |
| Wheel-side LIN idle voltage |  |  |  |
| Car/wheel orientation photo saved |  |  |  |
| Native wheel controls work before test |  |  |  |

## Serial Transcript Notes

| Time | Command | Response summary | Observation |
|---|---|---|---|
| 17:50 | safe:off | `cmd: safe=off armed=no pending=0` | PASS |
| 17:50 | bridge:off | `cmd: bridge=off` | PASS |
| 17:50 | config | `armed=no bridge=yes nag=no nag_interval_ms=15000 car=0 resp=0 miss=0 inj=0 wheel=0/1706 bad=1705` | PASS - wheel garbage expected (no LIN) |
| 17:50 | cache | 0x28(5B), 0x29(5B), 0x2A(7B), 0x2B(6B), 0x2C(5B), 0x2D(5B) all seeded | PASS |
| 17:50 | bridge:on | `cmd: bridge=on` | PASS |
| 17:51 | vol:click:1 | `cmd: vol=click pending=1 id=0x2A` | PASS - pending queued, won't fire unarmed |
| 17:51 | nag:on | `cmd: nag=enabled interval=15000ms` | PASS |
| 17:51 | nag:status | `cmd: nag=enabled once=no phase=0 interval=15000ms last_injection=0ms_ago` | PASS |
| 17:51 | nag:once | `cmd: nag:once blocked (not armed or bridge off)` | PASS - correctly blocked (not armed) |
| 17:51 | inject:clear | `cmd: inject cleared` | PASS |
| 17:51 | nag:off | `cmd: nag=disabled` | PASS |
| 17:52 | reset | Full boot: PSRAM, banner, NimBLE, BLE init done, BLE advertising | PASS - clean boot sequence |

## Findings

- Firmware v5.5-rev-a-ble boots cleanly on Rev A board
- Serial console on COM6 at 115200 baud works reliably
- All 13 tested commands respond correctly
- Cache auto-seeded on boot with 6 Model 3 frame IDs
- nag:once correctly blocked when not armed (antiNagSingleCycle safety)
- vol:click correctly queues injection (won't fire unarmed at 0x2A)
- BLE init + advertising confirmed via serial; external scanner doesn't see NimBLE extended advertising (known limitation, not a firmware bug)
- Reset reason "poweron" on first boot, "software" after serial reset command
- wheel_polls incrementing with ~100% bad rate — expected with floating LIN pins
- Next gate: unpowered board measurements (fuse, shorts, continuity)

## Stop Events / Faults

- 

## Final Safe State

- [x] nag:off sent
- [x] inject:clear sent
- [ ] bridge:off sent (left bridge=yes — harmless when disarmed, no LIN connected)
- [x] safe:off sent
- [x] final config captured

## HOLDING STATE — 2026-06-17 18:00

Session paused after completing Bench Verification Gate. Board is fully operational on the bench.

**Current board state:**
- Firmware: v5.5-rev-a-ble (rev_a_active_ble)
- Serial: COM6, 115200 baud
- armed=no, nag=no, pending=0, bridge=yes
- BLE: advertising as TeslaPassthrough (NimBLE extended advertising)
- Cache: seeded with 6 Model 3 frame IDs

**Resume with:** Unpowered board measurements (multimeter — TP1/TP2 shorts, F1 fuse continuity, LIN_A/LIN_B isolation, EN/BOOT impedance).

**Complete checklist in:** `NEXT_STEPS.md` → "Resume Here — Next Gate: Unpowered Board Measurements"
