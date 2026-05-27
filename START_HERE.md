# Tesla LIN Bench - Start Here

Last updated: 2026-05-27 13:35 -04:00

This is the canonical handoff for the Tesla LIN / anti-nag bench project. When the owner says "open the Tesla project", start here.

## Current State

The bench is working and validated end-to-end for passive LIN receive at 19200 baud.
**Firmware v5 is live on the bench XIAO** with multi-model runtime support, ring buffer, serial commands, and optional active TX behind `ACTIVE_MODE`.
The no-car evidence suite passed a full raw-ID sweep: **80/80 exact XIAO matches, 0 APG failures, 0 bad checksum/parity frames posted to secretary**.
Active Model X bench TX was validated on May 27: after fixing a disconnected D2 -> LV2 jumper, `model:x` + `antinag:start` produced >100 self-received `0x0C` frames with enhanced checksum/parity OK. APG known-ID raw fallback is also validated: `active-apg-raw-proof.ps1` captured 11 checksum-valid `0x0C` CSV rows with `source=raw`.

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
README.md                                 Wiring, firmware, tools, gotchas
NEXT_STEPS.md                             Current work plan and passive car-day flow
src/main.cpp                              XIAO firmware v5 — multi-model, ring buf, cmds, optional active TX
src/secrets.h.example                     Template for WiFi/API settings
tools/bench-evidence-suite.ps1            No-car evidence matrix + API posting
tools/active-bench-proof.ps1              Active Model X bench TX proof runner
tools/active-apg-raw-proof.ps1            Active Model X TX + APG known-ID raw observer proof
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

`src/main.cpp` — major upgrade:

| Feature | Description |
|---|---|
| Runtime vehicle ID | Set via serial: `vehicle:tesla-model-3` |
| Runtime baud switch | Switch UART without reflash: `baud:19200` |
| Ring buffer | 128 most recent frames, dump via `ring` command |
| Serial commands | `vehicle:`, `baud:`, `raw:`, `ring`, `stats` |
| Raw byte toggle | `raw:1` / `raw:0` at runtime |
| Auto-baud candidates | 19200, 9600, 10400 (configurable) |
| Telemetry queue | 64 frames (was 16) — less drop at high rates |
| Heartbeat | +baud, short frames, sync error counters |
| LED indicator | GPIO status on LIN activity |
| Active TX mode | Optional `ACTIVE_MODE`: half-baud break, model profiles, anti-nag scheduler, TXD diagnostics |

Active mode is bench-only and source-controlled behind `#define ACTIVE_MODE`. The repository default keeps it commented out. The physical bench XIAO is currently flashed active from the May 27 validation session.

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

Single entry point for field work. Sets XIAO vehicle ID + baud, starts APG passive capture, opens XIAO monitor, then runs capture summary. Supports `-ApgOnly`, `-XiaoOnly`, and `-DurationSeconds`.

### Python Capture Analyzer (NEW)

```text
tools/analyze-lin-capture.py
```

Post-capture analysis with built-in Tesla ID reference tables (Model X confirmed, 3/Y candidates). Per-ID frame stats, unknown ID alerting, checksum verification, anti-nag payload generation, JSON export.

### APG Tools

Use the NetworkAnalyser-based tools for real work:

```text
tools/send-netanalyser-headless.ps1
tools/monitor-apg-lin-bus.ps1
```

Do not rely on `tools/send-apg-lin-frame.ps1` for 19200 validation — it uses the direct static PICkitS path and was observed returning `Get_LIN_BAUD_Rate: 10000` even when set to 19200.

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
- Model 3/Y candidate IDs `0x1A` and `0x1B`.
- `0x3C` enhanced and classic checksum cases.
- Every raw LIN ID `0x00` through `0x3F`.
- Anti-nag UP/DOWN sequence plus neutral end frame.
- USB serial-to-secretary telemetry path while WiFi is unavailable.

Durable summary: `BENCH_EVIDENCE.md`.

Latest validation command:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor
```

Result:

```text
RESULT PASS - all bench frames decoded as expected
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

Latest APG raw observer proof:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -DurationSeconds 6 -MinFrames 8
```

Result:

```text
XIAO TX lines observed: 55
APG raw rows observed: 11
PASS: APG raw fallback captured 11 checksum-valid known-ID frames.
```

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

Before the car arrives:

1. Keep the current bench wiring intact; passive RX and active Model X TX are proven on the isolated bench.
2. Before future active tests, confirm XIAO D2 -> LV2 -> HV2 -> module TX using `txd:low`; the May 27 fault was a disconnected D2 -> LV2 jumper.
3. Use `tools\active-bench-proof.ps1` to verify XIAO self-receive, and `tools\active-apg-raw-proof.ps1` when you want APG known-ID raw observer evidence.
4. If WiFi telemetry is needed, set real WiFi/hotspot credentials in `src/secrets.h`, rebuild, and flash.
5. If WiFi remains unavailable, use `tools/serial-to-lin-events.ps1`; USB telemetry is proven.
6. Run the quick no-car suite before packing: `tools\bench-evidence-suite.ps1 -Quick -VehicleId tesla-bench-precar`.
7. Pack APGDT001, XIAO bench, TJA1021 wiring, 12V supply/battery clip, ground jumper, and back-probes.

Car day:

1. Use APG passive monitor first.
2. Do not transmit on the vehicle bus.
3. Capture at 19200 first.
4. If no traffic appears, retry 9600 only as a fallback.
5. Save APG `.csv` and `.txt` logs.
6. Run `tools/summarize-lin-capture.ps1`.
7. Compare payload changes while toggling locks, windows, seat belt, HVAC, and steering controls.

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
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor
```

Then continue from the first unchecked item in `NEXT_STEPS.md`.