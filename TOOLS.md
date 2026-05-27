# xiao-lin-bench Tools Reference

_Updated: May 26, 2026 — Firmware v4, all tools ready for Model 3/Y/X_

## Tool Inventory

| Tool | Purpose | Vehicle-safe? | Notes |
|---|---|---|---|
| `car-day-launcher.ps1` | Unified car-day entry point | PASSIVE only | Launches APG monitor + XIAO + summary |
| `monitor-apg-lin-bus.ps1` | APG passive LIN capture | ✅ Yes (receive only) | Requires 32-bit PowerShell |
| `send-netanalyser-headless.ps1` | APG headless transmit | ❌ No — bench only | Proven at 19200 baud |
| `validate-xiao-bench.ps1` | Bench validation matrix | ❌ No — bench only | Transmits 5 test frames |
| `bench-evidence-suite.ps1` | Full no-car APG/XIAO evidence matrix | ❌ No — bench only | Baseline, candidates, checksums, raw ID sweep, anti-nag, API post |
| `antinag-replay.ps1` | Anti-nag scroll replay | ❌ No — bench only | Alternating UP/DOWN with correct checksums |
| `serial-to-lin-events.ps1` | XIAO USB serial -> secretary API | ✅ Passive if capture source is passive | WiFi fallback telemetry bridge |
| `send-apg-lin-frame.ps1` | Direct PICkitS transmit | ❌ No — debug only | Baud unreliable at 19200 |
| `summarize-lin-capture.ps1` | Basic CSV summary | ✅ Post-capture | Per-ID counts |
| `analyze-lin-capture.py` | Full analysis + ID ref | ✅ Post-capture | Tesla ID reference tables, checksum verify |
| `lin-payload-calc.py` | PAYLOAD generator/verify | ✅ Reference | anti-nag/idle/verify/checksum/scan commands |

## Traffic Light — Which Tool Is For What

```
CAR DAY (vehicle bus):
    monitor-apg-lin-bus.ps1         ✅ PASSIVE CAPTURE ONLY
    car-day-launcher.ps1            ✅ Automates APG + XIAO passive
    XIAO firmware (via USB serial)  ✅ PASSIVE RECEIVE ONLY
    → admin must NOT send TX frames

BENCH (isolated bench only):
    send-netanalyser-headless.ps1   ✅ Send specific frames
    validate-xiao-bench.ps1         ✅ Full validation matrix
    bench-evidence-suite.ps1        ✅ Full no-car evidence matrix
    antinag-replay.ps1              ✅ Anti-nag scroll sequence
    send-apg-lin-frame.ps1          ✅ Debug only

POST-CAPTURE (anywhere):
    serial-to-lin-events.ps1         ✅ USB fallback to secretary API
    summarize-lin-capture.ps1       ✅ Quick per-ID counts
    analyze-lin-capture.py           ✅ Full analysis + reference
    lin-payload-calc.py              ✅ Checksum verification + generation
```

## Fast Command Reference

### Car day
```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench

# Full session (APG + XIAO + summary)
.\tools\car-day-launcher.ps1 -VehicleId tesla-model-3 -DurationSeconds 180 -Baud 19200

# APG only (high volume)
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200

# XIAO only (real-time decode)
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor --port COM4 --baud 115200 --dtr 1 --rts 0
```

### XIAO serial commands (type into monitor)
```
vehicle:tesla-model-3       Set vehicle ID at runtime
baud:19200                  Switch LIN baud (no reflash)
raw:1                       Enable raw byte debug
ring                        Dump last 128 frames
stats                       Print cumulative statistics
```

### Post-capture
```powershell
# Quick summary
.\tools\summarize-lin-capture.ps1

# Full analysis with Tesla reference
python tools\analyze-lin-capture.py --latest logs\
python tools\analyze-lin-capture.py logs\lin-capture-20260526_140000.csv

# Verify a captured frame
python tools\lin-payload-calc.py verify 0C 11 04 00 00 00 00 C0 0F CE
python tools\lin-payload-calc.py checksum 0C 10 00 00 00 00 00 C0 0F
```

### Bench validation
```powershell
# Full validation (transmits — bench only)
.\tools\validate-xiao-bench.ps1 -KillExistingMonitor

# Full no-car evidence suite (transmits — bench only)
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200

# Quick no-car smoke before packing
.\tools\bench-evidence-suite.ps1 -Quick -VehicleId tesla-bench-precar -ComPort COM4 -Baud 19200

# USB serial telemetry fallback when XIAO WiFi is unavailable
.\tools\serial-to-lin-events.ps1 -ComPort COM4 -VehicleId tesla-bench-usb -ApiBase http://localhost:8002

# Manual anti-nag replay (bench only)
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\antinag-replay.ps1 -Id 0x0C -Repeat 8

# Generate anti-nag reference table
python tools\lin-payload-calc.py antinag --id 0x0C --cycles 8
```

### Secretary API
```powershell
# Query recent LIN events
curl http://localhost:8002/api/v1/lin-events -s | python -m json.tool

# Query aggregated stats
curl "http://localhost:8002/api/v1/lin-stats?limit=5000" -s | python -m json.tool

# Filter by vehicle
curl "http://localhost:8002/api/v1/lin-events?vehicle=tesla-model-3" -s | python -m json.tool
```

## Known Issues

1. **APG baud reset**: `Network_Load` resets hardware baud to 9600. The `send-netanalyser-headless.ps1` calls `Change_LIN_BAUD_Rate` twice to work around this.
2. **PICkitS.dll is x86**: All APG tools require 32-bit PowerShell (`SysWOW64`). The scripts auto-relaunch.
3. **`send-apg-lin-frame.ps1` baud unreliable**: At 19200 this tool reports `Get_LIN_BAUD_Rate: 10000` even after setting to 19200. Use the NetworkAnalyser-based tools instead.
4. **XIAO COM port changes**: The XIAO may shift COM ports between connections. Run `[System.IO.Ports.SerialPort]::GetPortNames()` to find it.
5. **USB CDC requires --dtr 1**: Without `--dtr 1` flag, PlatformIO monitor shows no USB CDC output on Windows.
6. **XIAO WiFi can be skipped on the bench**: Use `serial-to-lin-events.ps1` to post decoded USB serial frames to secretary.
7. **Active TX wiring**: For bench-only active injection, connect XIAO D2/GPIO4 to TJA1021 TX through the level shifter. See `ACTIVE_INJECTOR.md`.

## Active TX Quick Reference

| XIAO | Level shifter | TJA1021 | Purpose |
|---|---|---|---|
| D3 / GPIO5 | LV/B1 <- HV/A1 | RX | Receive (passive) |
| D2 / GPIO4 | LV/B2 -> HV/A2 | TX | Transmit (active, bench only) |
| 5V | HV power | SLP | Keep TJA1021 awake |

Serial commands (ACTIVE_MODE): `model:x`, `model:3`, `model:y`, `antinag:start`, `antinag:stop`, `antinag:single`, `tx:`.