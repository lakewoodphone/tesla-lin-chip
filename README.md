# tesla-lin-chip

Tesla LIN reverse-engineering and anti-nag chip project. Covers passive LIN capture, active frame injection, Model 3/Y/X steering wheel volume control, and the custom dual-LIN ESP32-S3 Rev A PCB (JLCPCB order).

**Local path:** `C:\Users\ezabz\Code\tesla-lin-chip`
**GitHub:** `https://github.com/lakewoodphone/tesla-lin-chip`

Start with `START_HERE.md` when resuming. It is the canonical handoff and points to the active evidence, wiring, commands, and hard stops.

For the implementation plan that makes the bench, passive car testing, and final active-capable chip more robust, read `IMPLEMENTATION_ROADMAP.md`.

## Current Status

- Passive LIN receive is bench-verified at 19200 baud.
- Full no-car evidence passed on 2026-05-26 and again after APG reseat on 2026-05-27: 80/80 exact APG -> XIAO matches across raw IDs `0x00` through `0x3F`, with 0 APG failures.
- Active Model X bench TX is verified on the isolated bench. `model:x` + `antinag:start` produced more than 100 self-received `0x0C` frames with enhanced checksum and parity OK.
- Active improvements applied: bus-idle collision guard (2 ms silence before TX), realistic scroll payloads (non-zero B2/B3), and mirror/alive frame injection (`0x0D` at 500 ms via `mirror:on`).
- Active safety now reports reset reason, fault count, last fault, and lockout state. RX-integrity spikes or a dominant-line timeout while armed force active output off and block re-arm until `safe:off` is run after inspection.
- Repository default now builds `field_passive`; active TX is explicit via `bench_active_ble` or `chip_lab_active`.
- BLE service "TeslaAntiNag" in active builds exposes model (x/3/y/auto), mode (duty/always), period (5-120s), enable (on/off), status, and capabilities characteristics. Enable requires `safe:arm` first.
- BLE advertising was revalidated on 2026-05-27 after fixing invalid NimBLE advertising intervals; active lab builds report `advertising=yes` over serial.
- Car-day tooling enforces passive preflight and verifies `field_passive` firmware by default.
- APG known-ID raw fallback captures XIAO-generated active Model X frames after APG reseat: `active-apg-raw-proof.ps1` passed with 11 raw `ID=0x0C PID=0x4C` rows at `logs\lin-capture-20260527_212130.csv`.
- Model 3/Y steering LIN was captured on 2026-05-28. The confirmed left wheel control ID is `0x2A` (7 bytes) and right wheel control ID is `0x2B` (6 bytes). Left wheel byte[0] is `0x0D` volume up, `0x0B` volume down, `0x2C` click, `0x0C` idle. See `docs/model3y-steering-lin-2026-05-28.md`.
- `car_passthrough` is a new dual-transceiver firmware profile for the actual cut-wire bridge design. See `docs/model3y-passthrough-volume.md`.
- Final active-use hardware requires a custom dual-LIN passthrough PCB, not a one-LIN board. Current Rev A order core is `ESP32-S3-WROOM-1U-N8R8` plus 2x `TJA1021T/20`. See `docs/final-board-ordering-decision-2026-05-29.md`.

## Hard Stops

- Do not transmit on a vehicle LIN bus.
- Do not run `validate-xiao-bench.ps1`, `bench-evidence-suite.ps1`, `send-netanalyser-headless.ps1`, `antinag-replay.ps1`, or active firmware commands on a vehicle.
- Vehicle work starts passive only: APG passive monitor plus XIAO passive receive.
- Do not assume Model 3/Y IDs match Model X. Capture first, then label.
- Do not use the old `0x1A` Model 3/Y candidate for current Model 3 volume work; the confirmed left scroll wheel ID is `0x2A`.
- Do not use the old `C:\Users\ezabz\Code\Schematics\firmware\anti-nag-v1` path as active firmware.

## Hardware

| Component | Part | Notes |
|---|---|---|
| MCU | Seeed XIAO ESP32-C3 | USB CDC, normally COM4 |
| LIN analyzer | Microchip APGDT001 | VID `04D8`, PID `0A04`; PICkitS DLL is x86 |
| LIN transceiver | GODIYMODULES TJA1021 breakout | Logic header: `GND TX SLP RX`; bus header: `GND LIN INH VIN` |
| Level shifter | DIYables 4-channel bidirectional | HV=5V, LV=3.3V |
| PSU | Bench supply | 12V bus/module power |

## Wiring

Power and bus:

```text
PSU 12V -> APG VBAT / bus power
PSU 12V -> module VIN
PSU GND -> APG GND -> module GND -> level shifter GND -> XIAO GND
APG LINBUS pin 1 -> module LIN
XIAO 5V/VUSB -> module SLP and level shifter HV
XIAO 3V3 -> level shifter LV
```

Passive receive path:

```text
module RX -> level shifter HV1/A1 -> level shifter LV1/B1 -> XIAO D3/GPIO5
```

Active bench TX path:

```text
XIAO D2/GPIO4 -> level shifter LV2/B2 -> level shifter HV2/A2 -> module TX
```

Known wiring lesson from 2026-05-27: if `txd:low` makes XIAO D2 near 0V but LV2 stays near 3.3V, the D2 -> LV2 jumper is disconnected or on the wrong channel.

## Firmware

Main file: `src/main.cpp`

Core passive features:

- UART1 at 19200 baud on RX GPIO5/D3 and TX GPIO4/D2.
- Boundary-based parser: break/idle -> sync `0x55` -> PID -> data/checksum.
- Actual payload length is observed from frame boundary; `pred=<n>` is only the ID-class length hint.
- Protected-ID parity validation.
- Enhanced/classic checksum detection.
- Ring buffer of recent frames via `ring`.
- Runtime serial commands: `vehicle:`, `baud:`, `raw:`, `ring`, `stats`.
- USB serial fallback when WiFi is unavailable.

Active mode (`bench_active_ble` / `chip_lab_active`, bench only):

- Active TX requires serial `safe:arm` before any frame, BLE enable, TXD diagnostic, or custom `tx:` command can transmit. Use `safe:off` to stop and disarm.
- Two modes: `mode:duty` (burst UP -> DOWN every `period:N` ms, default 20s) or `mode:always` (constant alternation every 300ms).
- Double-click scroll wheel button: two fast presses toggles chip output on/off.
- Model profiles: `model:x` (`0x0C` confirmed), `model:3` (`0x2A` confirmed left scroll wheel), `model:y` (`0x2A` likely; verify passively), `model:auto`.
- Active commands: `safe:arm`, `safe:off`, `factory:reset`, `config`, `model`, `model:x`, `model:3`, `model:y`, `antinag:start`, `antinag:stop`, `antinag:single`, `vol:up`, `vol:down`, `vol:click`, `vol:idle`, `mode:duty`, `mode:always`, `period:20000`, `mirror:on`, `mirror:off`, `tx:`.
- Active event log: `events` prints recent RAM events and persisted NVS slots for boot, arm, config, start/stop, inhibits, and faults.
- Diagnostics: `txd:low`, `txd:high`, `txd:uart`.
- BLE: NimBLE config service with model/mode/period/enable plus status/capabilities. Advertises as "TeslaAntiNag". Double-click wheel button still toggles on/off only after arming.
- Active lab builds define `NO_WIFI`; BLE and USB serial are the active-lab control/evidence paths so missing shop WiFi cannot interfere with BLE advertising.
- NVS persisted config stores model/mode/period with version+CRC; active output always boots off/disarmed.

## Build And Flash

Build current repo default passive field firmware:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
python -m platformio run
```

Build every supported firmware target:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1
```

Build active bench firmware explicitly:

```powershell
python -m platformio run -e bench_active_ble
```

Build the dual-transceiver passthrough prototype:

```powershell
python -m platformio run -e car_passthrough
```

Upload to the XIAO on COM4:

```powershell
python -m platformio run -t upload --upload-port COM4
```

Monitor XIAO USB serial:

```powershell
python -m platformio device monitor --port COM4 --baud 115200 --dtr 1 --rts 0
```

If normal PlatformIO upload fails, use the documented `esptool --no-stub` fallback from `START_HERE.md`.

## Validation

Passive quick bench validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM4 -Baud 19200 -BootWaitSeconds 4 -PerFrameTimeoutMs 2500
```

Full no-car evidence suite:

```powershell
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200
```

Active Model X bench validation flow:

```powershell
# After flashing bench_active_ble firmware:
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x -ConfirmBenchIsolation
```

Expected active proof: `ring` shows `ID=0x0C PID=0x4C [8B]` frames with `enhanced parity=OK` and `badChk=0 badPid=0` in `stats`.

Independent APG known-ID raw observer proof, bench only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -Model x -DurationSeconds 6 -MinFrames 8 -ConfirmBenchIsolation
```

Expected APG raw proof: `PASS` with raw CSV rows for the selected model ID, `source=raw`. The script supports `-Model x|3|y|auto`, preflights APG initialization before active TX, forces continuous active mode during capture, restores duty mode afterward, and exits before transmit if APG is unavailable.

## Tooling

| Tool | Purpose | Vehicle-safe? |
|---|---|---|
| `tools/monitor-apg-lin-bus.ps1` | APG passive capture | Yes, receive-only |
| `tools/car-day-launcher.ps1` | Passive car-day APG/XIAO launcher | Yes, if used passive-only |
| `tools/build-all-envs.ps1` | Compile all firmware environments | Yes |
| `tools/new-capture-session.ps1` | Create manifest-backed capture folder | Yes |
| `tools/preflight-hardware-check.ps1` | Record physical preflight checks | Yes |
| `tools/full-bench-proof.ps1` | Build + passive proof; add `-RunActive -ConfirmBenchIsolation` for active/APG raw bench proof | No, bench only |
| `tools/validate-xiao-bench.ps1` | APG transmit -> XIAO receive validation | No, bench only |
| `tools/bench-evidence-suite.ps1` | Full APG/XIAO no-car evidence matrix | No, bench only |
| `tools/active-bench-proof.ps1` | XIAO active TX self-receive proof | No, bench only |
| `tools/active-apg-raw-proof.ps1` | XIAO active TX plus APG known-ID raw observer proof | No, bench only |
| `tools/prepare-model3y-car-day.ps1` | Pre-arrival APG/XIAO health check and `field_passive` flash | Yes |
| `tools/start-model3y-passive-capture.ps1` | Passive Model 3/Y capture wrapper with action windows | Yes, passive only |
| `tools/process-model3y-capture.ps1` | Analyze a capture session and emit candidate JSON | Yes, post-capture |
| `tools/stage-model3y-active-bench.ps1` | Apply reviewed 3/Y candidate and run bench-only active proofs | No, bench only |
| `tools/inject-vol-scroll.py` | Confirmed 0x2A left-volume active proof with JSON run logs | No, bench only |
| `tools/send-netanalyser-headless.ps1` | APG headless LIN transmit | No, bench only |
| `tools/antinag-replay.ps1` | APG anti-nag replay sequence | No, bench only |
| `tools/serial-to-lin-events.ps1` | XIAO USB serial -> secretary API | Passive if source is passive |
| `tools/analyze-lin-capture.py` | Post-capture analysis, Tesla ID reference, action-window ranking | Yes, post-capture |
| `tools/summarize-lin-capture.ps1` | Quick APG CSV summary | Yes, post-capture |
| `tools/lin-payload-calc.py` | Payload/checksum calculator | Reference only |

APG tools must run through 32-bit PowerShell when they load `PICkitS.dll`:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200
```

## Evidence And Docs

- `START_HERE.md` - canonical current handoff.
- `BENCH_EVIDENCE.md` - passive and active bench evidence.
- `ACTIVE_INJECTOR.md` - active bench wiring, operation, and diagnostics.
- `IMPLEMENTATION_ROADMAP.md` - full roadmap for bench robustness, passive car testing, and final active-capable chip development.
- `NEXT_STEPS.md` - current work plan.
- `TOOLS.md` - tool reference.
- `docs/archive/` - old passive-only and capture-history notes.
- `docs/final-board-ordering-decision-2026-05-29.md` - current direct Rev A order decision.
- `docs/final-chip-architecture.md` - current dual-LIN active passthrough board architecture.

## Known Issues

| Issue | Current understanding |
|---|---|
| APG NetworkAnalyser event/display modes log zero rows for XIAO-generated active frames | Settled: use `monitor-apg-lin-bus.ps1 -RawFallback -RawFallbackId 0x0C` or `active-apg-raw-proof.ps1` for known-ID bench observation. Generic vehicle discovery still uses normal passive event capture first. |
| APGDT001 reports `CM_PROB_FAILED_START` / `Error sending script` | Reseat/replug or use elevated PnP restart before APG-dependent tests. The May 27 physical reseat recovered APG to `CM_PROB_NONE`, and passive plus APG raw proofs passed afterward. |
| XIAO WiFi reports `NO_AP_FOUND` | Use USB serial and `serial-to-lin-events.ps1` unless WiFi credentials are repaired |
| `PermissionError` on COM4 | A serial monitor is holding the port; stop PlatformIO/terminal process |
| Direct `send-apg-lin-frame.ps1` baud looks wrong | Use NetworkAnalyser-based tools for real validation |
| Holding TXD low does not always pull LIN low forever | LIN dominant-timeout can release the bus; validate with real frames and ring buffer |

## Repository Structure

```
tesla-lin-chip/
├── README.md                     This file — project overview and wiring reference
├── START_HERE.md                 Canonical current handoff — start here every session
├── BENCH_EVIDENCE.md             Passive and active bench evidence summary
├── ACTIVE_INJECTOR.md            Active TX bench wiring, operation, and diagnostics
├── IMPLEMENTATION_ROADMAP.md     Full roadmap: bench → passive car → final chip
├── NEXT_STEPS.md                 Current work plan
├── TOOLS.md                      Tool reference
├── platformio.ini                PlatformIO build config (passive default + active envs)
│
├── src/                          XIAO ESP32-C3 firmware
│   ├── main.cpp                  v5.1 — build profiles, safe arm gate, BLE, ring buffer
│   ├── car_passthrough.cpp       Dual-transceiver passthrough firmware prototype
│   └── secrets.h.example         WiFi/API settings template
│
├── hardware/
│   └── tesla-dual-lin-rev-a/     Rev A PCB — ESP32-S3-WROOM-1U-N8R8 + 2x TJA1021T/20
│       ├── kicad/                KiCad schematic + PCB (tesla-dual-lin-rev-a.kicad_sch/pcb)
│       ├── bom/                  BOM strategy, cost model, supplier shortlist
│       ├── build/                Generated Gerbers, drill files
│       ├── manufacturing/        JLCPCB order files
│       ├── electrical/           Constraint files
│       └── tests/                DRC/ERC reports
│
├── docs/
│   ├── final-board-ordering-decision-2026-05-29.md  Rev A order decision
│   ├── final-chip-architecture.md                   Dual-LIN active board architecture
│   ├── model3y-steering-lin-2026-05-28.md           Model 3/Y confirmed ID map (0x2A left, 0x2B right)
│   ├── model3y-passthrough-volume.md                Cut-wire passthrough architecture
│   ├── bench-revalidation-2026-05-27.md             BLE fix + APG reseat proof
│   ├── chip-sourcing-shortlist-2026-05-29.md        ESP32-S3 + TJA1021 supplier shortlist
│   ├── secure-provisioning-anti-cloning-2026-05-29.md  nRF5340 anti-cloning design notes
│   ├── single-board-rev-a-product-spec-2026-05-29.md   Rev A product spec
│   ├── reports/                  Field analysis reports from vehicle visits
│   └── archive/                  Historical passive/capture notes
│
├── research/
│   ├── directives/               Research directives (ESP32, LIN, PCB, Tesla purchase)
│   └── responses/                Research responses and synthesis documents
│
├── knowledge/
│   └── hardware/                 Hardware knowledge base (TSL family, anti-nag landscape, BOM strategy)
│
├── tools/                        PowerShell + Python operational scripts
│   ├── tesla-tsl5-lin-capture.ps1     LIN capture via FX2/Sigrok for TSL5 bench
│   ├── tesla-tsl5-bench-readiness.ps1 TSL5 bench readiness check
│   └── ... (see TOOLS.md for full list)
│
├── captures/
│   ├── sigrok/                   Raw .sr Sigrok captures (FX2 device, Model X field sessions)
│   └── lin-csv/                  (use logs/ for CSV captures from the bench)
│
├── logs/                         Bench CSV captures, active proof logs, bench evidence archives
├── photos/                       Vehicle visit photos (Model X SCCM, steering wheel access points)
├── audit-logs/                   Session audit logs (Tesla deal, bench setup sessions)
└── boards/                       Board JSON definitions (ESP32-S3 N8R8)
```