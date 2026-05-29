# Tesla LIN Bench - Start Here

Last updated: 2026-05-29 - dual-LIN final board order decision added

This is the canonical handoff for the Tesla LIN / anti-nag bench project. When the owner says "open the Tesla project", start here.

## Current State

The bench is working and validated end-to-end for passive LIN receive at 19200 baud.
**Firmware v5.1 now has explicit build profiles**: `field_passive` is the default, `field_passive_nowifi` validates the no-WiFi path, and `bench_active_ble` / `chip_lab_active` are named active lab builds.
Active lab builds are BLE/USB-first and compile with `NO_WIFI`; field passive remains the only WiFi telemetry build.
The no-car evidence suite passed a full raw-ID sweep again after the APG reseat: **80/80 exact XIAO matches, 0 APG failures** at `logs\bench-evidence-20260527_211310\bench-evidence-20260527_211310.md`.
Active Model X bench TX was validated on May 27: after fixing a disconnected D2 -> LV2 jumper, `model:x` + `antinag:start` produced self-received `0x0C` frames with enhanced checksum/parity OK. Latest self-receive revalidation: `tools\active-bench-proof.ps1 -ComPort COM4 -Model x -ConfirmBenchIsolation` passed at `logs\active-bench-proof-20260527_211924.md`.
APG known-ID raw observer proof also passes after APG reseat: `tools\active-apg-raw-proof.ps1 -ComPort COM4 -Baud 19200 -DurationSeconds 6 -MinFrames 8 -ConfirmBenchIsolation` captured 11 checksum-valid `ID=0x0C PID=0x4C` raw rows at `logs\lin-capture-20260527_212130.csv`.
BLE advertising is now verified clean after fixing invalid NimBLE advertising intervals; `ble` reports `advertising=yes` with the expected `TeslaAntiNag` service UUIDs.
Active TX now requires `safe:arm` first; `safe:off` stops output, clears fault lockout, and disarms. Active builds report reset reason, fault count, last fault, and lockout state. RX-integrity spikes or a dominant-line timeout while armed force active output off.

Current APG state: the APGDT001 recovered after physical reseat. Windows reports `CM_PROB_NONE` for the APG HID interfaces, APG transmit works, and APG raw monitor initialization works. If `CM_PROB_FAILED_START` recurs, physically replug/reseat or use elevated PnP restart before APG-dependent tests. See `docs/bench-revalidation-2026-05-27.md`.

Current operational state: the Model 3 steering LIN capture succeeded on 2026-05-28. The confirmed left wheel control ID is `0x2A` with 7 data bytes; byte[0] is `0x0D` volume up, `0x0B` volume down, `0x2C` click, `0x0C` idle. The confirmed right wheel control ID is `0x2B` with 6 data bytes. The old `0x1A` Model 3/Y candidate is superseded. See `docs/model3y-steering-lin-2026-05-28.md`.

The active proof path now has a counter-aware serial tool, `tools\inject-vol-scroll.py`, plus direct firmware commands `vol:up`, `vol:down`, `vol:click`, and `vol:idle`. The actual cut-wire passthrough direction is a separate dual-transceiver firmware profile, `car_passthrough`, documented in `docs/model3y-passthrough-volume.md`.

Final active-use hardware direction is now locked to a custom two-LIN passthrough PCB. The current Rev A ordering core is `ESP32-S3-WROOM-1U-N8R8` plus 2x `TJA1021T/20`; nRF5340/NORA/BL5340 is now a backup security path, not the primary cheapest-reliable Rev A default. See `docs/final-board-ordering-decision-2026-05-29.md` and `docs/final-chip-architecture.md`.

Vehicle-side work is paused until the steering wheel controls recover from the wiring short and all conductors are insulated. Bench proof comes before any further car-side active work.

Active project path:

```text
C:\Users\ezabz\Code\xiao-lin-bench
```

Clean snapshot archive, excluding build output, logs, and local `src/secrets.h`:

```text
C:\Users\ezabz\Code\_snapshots\xiao-lin-bench-20260526_134330.zip
```

Primary files:

```text
START_HERE.md                             This handoff
BENCH_EVIDENCE.md                         Full no-car evidence summary
ACTIVE_INJECTOR.md                        Bench-only active TX wiring, operation, and TXD diagnostics
IMPLEMENTATION_ROADMAP.md                 Full bench, passive car-test, and final-chip robustness roadmap
README.md                                 Wiring, firmware, tools, gotchas
NEXT_STEPS.md                             Current work plan and passive car-day flow
docs/bench-revalidation-2026-05-27.md     Latest bench proof, BLE fix, APG reseat, and raw observer pass
docs/model3y-steering-lin-2026-05-28.md   Canonical Model 3 capture analysis and volume byte map
docs/model3y-passthrough-volume.md        Dual-transceiver passthrough architecture and commands
docs/final-board-ordering-decision-2026-05-29.md Current Rev A ordering decision
docs/final-chip-architecture.md            Current custom dual-LIN active board architecture
src/main.cpp                              XIAO firmware v5.1 - build profiles, safe arm gate, NVS config, BLE status, ring buffer
src/car_passthrough.cpp                   car_passthrough firmware prototype for cut-wire bridge
src/secrets.h.example                     Template for WiFi/API settings
platformio.ini                            Build config: passive default, active bench/chip lab envs
tools/build-all-envs.ps1                  Compile every supported firmware environment
tools/full-bench-proof.ps1                One-command isolated-bench proof wrapper
tools/preflight-hardware-check.ps1        Records physical power/ground/TX/RX checklist
tools/new-capture-session.ps1             Creates manifest-backed bench/car capture folders
tools/bench-evidence-suite.ps1            No-car evidence matrix + API posting
tools/active-bench-proof.ps1              Active Model X bench TX proof runner
tools/active-apg-raw-proof.ps1            Active Model X TX + APG known-ID raw observer proof
tools/prepare-model3y-car-day.ps1         Pre-arrival APG/XIAO health check and field_passive flash
tools/start-model3y-passive-capture.ps1   One-command passive Model 3/Y capture with action windows
tools/process-model3y-capture.ps1         Analyze capture and emit model-profile-candidate.json
tools/stage-model3y-active-bench.ps1      Apply reviewed 3/Y ID and run bench-only active proofs
tools/inject-vol-scroll.py                Confirmed Model 3/Y 0x2A left-volume proof tool with JSON logs
tools/serial-to-lin-events.ps1            USB serial -> secretary fallback telemetry
tools/car-day-launcher.ps1                Unified car-day entry point (NEW)
tools/send-netanalyser-headless.ps1       Proven APG transmit path
tools/validate-xiao-bench.ps1             Bench-only validation matrix
tools/monitor-apg-lin-bus.ps1             Car-day passive APG capture
tools/summarize-lin-capture.ps1           Post-capture ID/payload summary
tools/analyze-lin-capture.py              Python analyzer with Tesla ID reference (NEW)
```

## What Was Built

### Firmware v4/v5 (upgraded May 26-27)

`src/main.cpp` - major upgrade:

| Feature | Description |
|---|---|
| Runtime vehicle ID | Set via serial: `vehicle:tesla-model-3` |
| Runtime baud switch | Switch UART without reflash: `baud:19200` |
| Ring buffer | 128 most recent frames, dump via `ring` command |
| Serial commands | `version`, `config`, `safe:off`, `vehicle:`, `baud:`, `raw:`, `ring`, `stats` |
| Raw byte toggle | `raw:1` / `raw:0` at runtime |
| Auto-baud candidates | 19200, 9600, 10400 (configurable) |
| Telemetry queue | 64 frames (was 16) - less drop at high rates |
| Heartbeat | +baud, short frames, sync error counters |
| LED indicator | GPIO status on LIN activity |
| Active TX mode | Named active builds only: half-baud break, model profiles, safe arm gate, anti-nag scheduler, bus-idle collision guard, rate/session limits, realistic scroll payloads, mirror-frame injection, TXD diagnostics, double-click toggle |
| BLE config service | NimBLE "TeslaAntiNag": model/mode/period/enable plus status/capabilities, deferred advertising retry |
| Active safety lockout | Reset reason in `version`/`config`, RX-integrity fault lockout, dominant-line timeout lockout, fault count/last fault in serial and BLE status |
| Active event log | `events` command prints recent RAM events plus NVS persisted slots for boot, arm, config, start/stop, inhibits, and faults |

Default `platformio run` builds `field_passive`. Active mode is bench-only and must be built explicitly with `-e bench_active_ble` or `-e chip_lab_active`.

Active + BLE improvements (v5, 2026-05-27):
- Bus-idle collision guard (2 ms silence before TX).
- Realistic scroll payloads (non-zero velocity/accumulated bytes).
- Mirror/alive frame injection (`0x0D` at 500 ms via `mirror:on`).
- NimBLE BLE service with model (x/3/y/auto), mode (duty/always), period (5000-120000ms), and enable (on/off).
- BLE enable writes require `safe:arm`; invalid BLE values are rejected back to the current accepted value.
- `ble` serial command prints BLE state and characteristic UUIDs, including status/capabilities.
- NVS persisted config stores model/mode/period with version+CRC; enable state always boots off.

### Secretary API

```text
POST /api/v1/lin-events     XIAO posts decoded frames
GET  /api/v1/lin-events     Query recent telemetry
```

Both routes are live in `personal-secretary-mvp` (`app/main.py`). Events go to `activity_log` with `action='lin_event'`. CEO wake triggers on first frame or bad checksum.

### Car-Day Launcher (NEW)

```text
tools/car-day-launcher.ps1
```

Single entry point for field work. Forces `safe:off`, logs `version` and `config`, sets XIAO vehicle ID + baud, starts APG passive capture, opens XIAO monitor, then runs capture summary. Supports `-ApgOnly`, `-XiaoOnly`, and `-DurationSeconds`.
It now runs enforced `car-passive` preflight and aborts if the XIAO does not report `build=field_passive` unless `-AllowNonPassiveFirmware` is explicitly supplied for a bench diagnostic.

### Python Capture Analyzer (NEW)

```text
tools/analyze-lin-capture.py
```

Post-capture analysis with built-in Tesla ID reference tables (Model X confirmed, 3/Y candidates). Per-ID frame stats, unknown ID alerting, checksum verification, action-window ranking from manifests, anti-nag payload generation, JSON export.
Use `--candidate-json` to emit a review-only `model-profile-candidate.json`; firmware profiles still require repeated passive captures that agree.

### APG Tools

Use the NetworkAnalyser-based tools for real work:

```text
tools/send-netanalyser-headless.ps1
tools/monitor-apg-lin-bus.ps1
```

Do not rely on `tools/send-apg-lin-frame.ps1` for 19200 validation - it uses the direct static PICkitS path and was observed returning `Get_LIN_BAUD_Rate: 10000` even when set to 19200.

Important APG discovery:

```text
NetworkAnalyser frame strings use raw LIN IDs, not protected PIDs.
Send: 0C 12 34
Not:  4C 12 34
```

## Verified Bench Evidence

Strongest current no-car run:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full-20260526 -ComPort COM4 -Baud 19200 -BootWaitSeconds 2 -PerFrameTimeoutMs 1600 -DelayMs 75
```

Result:

```text
Bench evidence complete: 80/80 exact matches, observed=80, apgFailures=0
Secretary stats: total_frames=80, unique_ids=64, bad_checksum=0, bad_parity=0
```

Coverage:

- Model X `0x0C` idle/up/down frames.
- Historical Model 3/Y candidate IDs `0x1A` and `0x1B`, now superseded by live capture (`0x2A` left wheel, `0x2B` right wheel).
- `0x3C` enhanced and classic checksum cases.
- Every raw LIN ID `0x00` through `0x3F`.
- Anti-nag UP/DOWN sequence plus neutral end frame.
- USB serial-to-secretary telemetry path while WiFi is unavailable.

Durable summary: `BENCH_EVIDENCE.md`.

Historic passing validation command:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor
```

Historic result:

```text
RESULT PASS - all bench frames decoded as expected
```

Latest APG-dependent validation after reseat:

```text
logs\xiao-bench-validation-20260527_211238.log
RESULT PASS - all bench frames decoded as expected
logs\bench-evidence-20260527_211310\bench-evidence-20260527_211310.md
Bench evidence complete: 80/80 exact matches, observed=80, apgFailures=0
```

Decoded frames from the passing run:

```text
ID=0x0C PID=0x4C [2B pred=2] data: 12 34 | chk=6D enhanced parity=OK
ID=0x10 PID=0x50 [2B pred=2] data: AA 55 | chk=AF enhanced parity=OK
ID=0x22 PID=0xE2 [4B pred=4] data: 01 02 03 04 | chk=13 enhanced parity=OK
ID=0x3C PID=0x3C [8B pred=8] data: 00 00 00 00 00 00 00 00 | chk=C3 enhanced parity=OK
ID=0x3C PID=0x3C [8B pred=8] data: 00 00 00 00 00 00 00 00 | chk=FF classic parity=OK
```

Final verification also passed:

```text
Firmware build: PlatformIO SUCCESS, flash use about 69.2%, RAM about 12.5%.
PowerShell scripts parse: monitor, validate, summarize, send-netanalyser all OK.
Passive monitor smoke test: starts in x86 PowerShell, sets NetworkAnalyser baud to about 19231, exits cleanly.
Secretary health: OK.
Secretary LIN POST: 200 OK.
Secretary LIN GET: returned stored bench-test frame.
```

Current APG raw observer proof:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -ComPort COM4 -Baud 19200 -DurationSeconds 6 -MinFrames 8 -ConfirmBenchIsolation
```

Result:

```text
CSV: logs\lin-capture-20260527_212130.csv
XIAO TX lines observed: 41
APG raw rows observed: 11
PASS: APG raw fallback captured 11 checksum-valid known-ID frames.
```

Current APG raw proof behavior: `tools\active-apg-raw-proof.ps1` preflights APG raw monitor initialization before active TX, forces `mode:always` during the monitor window so APG cannot miss a duty-cycle gap, then stops output, runs `safe:off`, and restores `mode:duty`. If APG initialization fails, it aborts before active TX.

## Hardware Wiring

Current verified receive path:

```text
APG LINBUS -> Module LIN -> Module RX -> Level shifter HV/A1 -> Level shifter LV/B1 -> XIAO D3/GPIO5
```

Power/ground:

```text
12V PSU -> APG VBAT / bus power
12V PSU -> TJA1021 module VIN
PSU GND -> APG GND -> module GND -> level shifter GND -> XIAO GND
XIAO 5V -> TJA1021 SLP and level shifter HV
XIAO 3V3 -> level shifter LV
```

Critical wiring facts:

- TJA1021 `SLP` must be tied high to XIAO 5V.
- Use module `RX`, not module `TX`, for receive into the XIAO.
- Active TX path is XIAO D2/GPIO4 -> level shifter LV2/B2 -> HV2/A2 -> module `TX`.
- If `txd:low` makes XIAO D2 low but LV2 stays high, the D2 -> LV2 jumper is disconnected or on the wrong channel.
- Shared ground is mandatory.

## Current Next Action

If the car has not arrived yet:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\prepare-model3y-car-day.ps1 -ComPort COM4
```

Before the car arrives:

1. Keep the current bench wiring intact; passive RX and active Model X TX are proven on the isolated bench.
2. Before future active tests, confirm XIAO D2 -> LV2 -> HV2 -> module TX using `txd:low`; the May 27 fault was a disconnected D2 -> LV2 jumper.
3. Use `tools\active-bench-proof.ps1` to verify XIAO self-receive, and `tools\active-apg-raw-proof.ps1` for APG known-ID raw observer proof on the isolated bench.
	Both active proof scripts require `-ConfirmBenchIsolation` or an interactive `BENCH` confirmation.
4. If WiFi telemetry is needed, set real WiFi/hotspot credentials in `src/secrets.h`, rebuild, and flash.
5. If WiFi remains unavailable, use `tools/serial-to-lin-events.ps1`; USB telemetry is proven.
6. If wiring is disturbed before packing, rerun the quick no-car suite: `tools\bench-evidence-suite.ps1 -Quick -VehicleId tesla-bench-precar`.
7. Pack APGDT001, XIAO bench, TJA1021 wiring, 12V supply/battery clip, ground jumper, and back-probes.

Car day:

1. Use the wrapper: `tools\start-model3y-passive-capture.ps1 -Model 3 -VehicleId tesla-model-3-YYYYMMDD`.
2. Do not transmit on the vehicle bus.
3. Confirm the preflight says TX physical state is disconnected/off.
4. Capture at 19200 first; retry 9600 only if 19200 shows no traffic after wiring is checked.
5. Follow the printed 180s action plan: idle, left scroll up/down/click, right scroll up/down/click, idle.
6. Run `tools\process-model3y-capture.ps1 -SessionDir <session folder>`.
7. If the candidate ID is convincing, return to the isolated bench and run `tools\stage-model3y-active-bench.ps1`; this is not a vehicle script.

## Commands

Build firmware:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe run
```

Flash firmware:

```powershell
C:\Users\ezabz\.platformio\penv\Scripts\python.exe -m esptool --chip esp32c3 --port COM4 --baud 115200 --before default_reset --after hard_reset --no-stub write_flash -z --flash_mode dio --flash_freq 80m --flash_size 4MB 0x0 .pio\build\xiao_esp32c3\bootloader.bin 0x8000 .pio\build\xiao_esp32c3\partitions.bin 0x10000 .pio\build\xiao_esp32c3\firmware.bin
```

Monitor XIAO:

```powershell
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor --port COM4 --baud 115200 --dtr 1 --rts 0
```

Run bench validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor
```

Run passive APG capture on car day:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1
```

Summarize latest capture:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1
```

Query secretary telemetry:

```powershell
curl http://localhost:8002/api/v1/lin-events -s | python -m json.tool
```

## Hard Stops

- Do not run `validate-xiao-bench.ps1` on a vehicle. It transmits frames.
- Do not actively inject/transmit on a vehicle LIN bus until passive capture is decoded and reviewed.
- Do not use the old `C:\Users\ezabz\Code\Schematics\firmware\anti-nag-v1` as active firmware.
- Do not use the direct static PICkitS sender for final 19200 validation.
- Do not pierce harness insulation unless connector-safe probing is impossible and the risk is intentionally accepted.

## When Resuming

Start by doing this:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
Get-Content START_HERE.md
Get-Content NEXT_STEPS.md
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VID_04D8&PID_0A04' }
```

APG is currently recovered. If it returns to `CM_PROB_FAILED_START`, reseat/replug it or run an elevated PnP restart, then rerun `tools\validate-xiao-bench.ps1 -KillExistingMonitor` before trusting APG-dependent tests.
