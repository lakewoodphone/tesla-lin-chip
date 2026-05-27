# No-Car Bench Evidence

_Updated: May 26, 2026._

This file records the strongest bench-only evidence collected before touching a car. The goal is to prove the APGDT001 -> TJA1021 -> level shifter -> XIAO receive chain, parser, checksum handling, candidate-ID handling, anti-nag replay sequence, and secretary API telemetry path.

**Active injector firmware is also built (ACTIVE_MODE).** XIAO generates anti-nag frames on UART1 TX with runtime model switching (`model:x`, `model:3`, `model:y`). TX wiring to TJA1021 is required for bench bus injection validation; see `ACTIVE_INJECTOR.md`.

## Hardware Under Test

- Host: `ZABZ-TECH` desktop
- XIAO: ESP32-C3 on `COM4`, USB VID/PID `303A:1001`
- APGDT001: USB LIN analyzer, VID/PID `04D8:0A04`
- LIN transceiver: TJA1021 module
- Bench LIN baud: `19200`
- Receive path: APG LIN -> TJA1021 LIN/RX -> level shifter -> XIAO D3/GPIO5
- Power: APG VBAT and TJA1021 VIN tied to bench 12V, common ground, SLP high

## Full Evidence Suite

Command:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
.\tools\bench-evidence-suite.ps1 `
  -VehicleId tesla-bench-full-20260526 `
  -ComPort COM4 `
  -Baud 19200 `
  -BootWaitSeconds 2 `
  -PerFrameTimeoutMs 1600 `
  -DelayMs 75
```

Result:

```text
Bench evidence complete: 80/80 exact matches, observed=80, apgFailures=0
```

Phase breakdown:

| Phase | Cases | Observed | Exact Match |
|---|---:|---:|---:|
| baseline | 3 | 3 | 3 |
| candidate | 2 | 2 | 2 |
| checksum | 2 | 2 | 2 |
| id-sweep | 64 | 64 | 64 |
| antinag | 9 | 9 | 9 |

What this proves:

- XIAO receives and decodes every raw LIN ID from `0x00` through `0x3F` on the isolated bench.
- Protected PID parity validates for every sweep case.
- Enhanced checksums validate on normal frames.
- Classic checksum validation is proven on diagnostic `0x3C`.
- Model X control frames on `0x0C` decode correctly for idle, up, down, and neutral.
- Model 3/Y candidate IDs `0x1A` and `0x1B` decode cleanly as bench candidates.
- Anti-nag UP/DOWN replay plus neutral end frame decodes exactly.
- The USB serial fallback path posts parsed frames to the secretary API even while XIAO WiFi is unavailable.

Generated local artifacts are under ignored `logs/`:

```text
logs\bench-evidence-20260526_211956\bench-evidence-20260526_211956.md
logs\bench-evidence-20260526_211956\bench-evidence-20260526_211956.csv
logs\bench-evidence-20260526_211956\bench-evidence-20260526_211956.json
logs\bench-evidence-20260526_211956\xiao-serial-20260526_211956.log
logs\bench-evidence-20260526_211956\apg-send-20260526_211956.log
```

Secretary API verification:

```powershell
curl "http://localhost:8002/api/v1/lin-stats?vehicle=tesla-bench-full-20260526&limit=10000" | python -m json.tool
```

Observed API result:

```text
total_frames=80
bad_checksum=0
bad_parity=0
unique_ids=64
```

## Quick Evidence Suite

Command:

```powershell
.\tools\bench-evidence-suite.ps1 `
  -Quick `
  -VehicleId tesla-bench-quick-20260526 `
  -ComPort COM4 `
  -Baud 19200 `
  -BootWaitSeconds 3 `
  -PerFrameTimeoutMs 1800
```

Result:

```text
Bench evidence complete: 32/32 exact matches, observed=32, apgFailures=0
```

Use the quick suite before field work when time is short. Use the full suite after wiring or parser changes.

## Standalone Anti-Nag Replay

Command:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `
  -STA -NoProfile -ExecutionPolicy Bypass `
  -File tools\antinag-replay.ps1 `
  -Id 0x0C `
  -Repeat 2 `
  -DelayMs 150 `
  -NeutralFrames 2
```

Result:

```text
Replay complete - 6 frames sent
```

The replay script now launches the APG sender as a fresh 32-bit PowerShell child process per frame. That avoids NetworkAnalyser state leakage and fixes the earlier final-neutral failure.

## New Bench Tools

| Tool | Purpose | Vehicle-safe? |
|---|---|---|
| `tools/bench-evidence-suite.ps1` | Runs baseline, candidate, checksum, raw ID sweep, and anti-nag no-car tests; writes CSV/JSON/Markdown evidence and posts to secretary | No, transmits |
| `tools/serial-to-lin-events.ps1` | Bridges XIAO USB serial decoded frames into `POST /api/v1/lin-events` when WiFi is unavailable | Passive if APG/vehicle is passive |

## Remaining No-Car Limits

- The bench can prove parser correctness, checksum behavior, APG send behavior, telemetry plumbing, and active injection on the isolated bench.
- It cannot identify actual Model 3/Y steering IDs without passive vehicle capture.
- It cannot prove Tesla accepts any anti-nag sequence. Vehicle work must start passive only.
- Active injection is firmware-ready; physical TX wiring and APG passive-monitor validation are needed to complete the bench validation loop.

## Active Injection Status (May 2026)

- Firmware v5 with `#define ACTIVE_MODE` flashable to the connected XIAO.
- Multi-model profile system: `model:x` (0x0C), `model:3` (0x1A), `model:y` (0x1A).
- Anti-nag scheduler confirmed on USB serial: alternating `11 04` / `0F 04` at 300ms, neutral `10 00` at 1s.
- Physical TX wiring step needed: XIAO D2/GPIO4 → level shifter → TJA1021 TX.
- Once wired, APG passive monitor will capture the injected frames on the bench LIN bus.