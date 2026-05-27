# Next Steps - xiao-lin-bench

_Updated: May 26, 2026._ **Firmware v4 is live.** Bench works at 19200 baud. The system now supports Tesla Model 3, Y, and X with runtime reconfiguration. Full no-car evidence passed: 80/80 exact matches across raw IDs `0x00`-`0x3F`.

For the full current handoff, read `START_HERE.md` first.

---

## What Changed in v4

| Feature | v3 | v4 |
|---|---|---|
| Baud switching | Compile-time only | Runtime via serial command `baud:19200` |
| Vehicle ID | Compile-time only | Runtime via serial command `vehicle:tesla-model-3` |
| Raw byte log | Compile flag `DEBUG_RAW_BYTES` | Runtime toggle `raw:1` / `raw:0` |
| Frame history | None | Ring buffer (128 frames), dump via `ring` |
| Auto-baud probe | None | Scan 19200/9600/10400 on startup |
| Serial commands | None | `vehicle:` `baud:` `raw:` `ring` `stats` |
| Telemetry queue | 16 frames | 64 frames (less drop at high frame rates) |
| Heartbeat | Basic counts | +baud, short, syncErr counters |
| Python analyzer | None | `tools/analyze-lin-capture.py` with Tesla ID ref |
| Car-day launcher | Manual multi-step | `tools/car-day-launcher.ps1` one-shot |
| USB telemetry bridge | None | `tools/serial-to-lin-events.ps1` posts decoded serial frames |
| Bench evidence suite | Manual notes | `tools/bench-evidence-suite.ps1` writes CSV/JSON/Markdown evidence |

---

## Current Status

- **Firmware v4** builds and runs: boundary-based LIN parser, ring buffer, runtime commands.
- Hardware wired and verified: APGDT001 -> TJA1021 -> level shifter -> XIAO D3/GPIO5.
- APG headless send works at 19200 baud (with the `Change_LIN_BAUD_Rate` ×2 fix).
- APG passive monitor ready: `tools/monitor-apg-lin-bus.ps1`.
- Bench validation passing: `tools/validate-xiao-bench.ps1`.
- Full no-car evidence passing: `tools/bench-evidence-suite.ps1` reported 80/80 exact matches, 64 unique raw IDs, and 0 bad checksum/parity frames.
- USB serial fallback telemetry is proven: evidence frames posted to `POST /api/v1/lin-events` without XIAO WiFi.
- Python capture analyzer with Tesla reference tables: `tools/analyze-lin-capture.py`.
- Unified car-day launcher: `tools/car-day-launcher.ps1`.
- Secretary API: `POST /api/v1/lin-events` and `GET /api/v1/lin-events`.

The system is **vehicle-agnostic**. It does not assume Model X, 3, and Y share IDs.
It captures whatever the bus emits and leaves signal naming for the decode phase.

---

## Tesla Model Reference IDs

| ID | Model X (confirmed) | Model 3/Y (candidate) | Notes |
|---|---|---|---|
| `0x0C` | ✅ Scroll/control (B0=position, B1=engage) | ❓ Unknown (check `0x1A`/`0x1B`) | HIGH priority |
| `0x0D` | ✅ Passive mirror | ❓ Unknown | LOW priority |
| `0x0E`/`0x0F` | ✅ Alive toggle | ❓ Unknown | LOW priority |
| `0x16`/`0x17` | ✅ Config/version | ❓ Unknown | INFO priority |
| `0x1A`/`0x1B` | ❓ Not seen | 🔍 CANDIDATE steering | INVESTIGATE |
| `0x3C` | ✅ Diagnostic | ✅ Diagnostic | INFO (all models) |

**Model 3/Y steering ID is NOT YET KNOWN.** The first car-day capture will discover it.
Use `tools/analyze-lin-capture.py` after capture to compare against reference tables.

---

## Before Car Day Checklist

- [x] Run full no-car evidence: `tools\bench-evidence-suite.ps1` (80/80 exact matches)
- [x] Confirm USB fallback telemetry posts to secretary (`tesla-bench-full-20260526`, 80 frames)
- [ ] Configure WiFi in `src/secrets.h` if wireless telemetry is needed (shop network or phone hotspot)
- [ ] Build firmware after any WiFi config change: `C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe run`
- [ ] Flash with esptool `--no-stub` command after any firmware/config change (see README)
- [ ] Run quick no-car evidence before packing: `powershell -NoProfile -ExecutionPolicy Bypass -File tools\bench-evidence-suite.ps1 -Quick -VehicleId tesla-bench-precar`
- [ ] Confirm `GET /api/v1/lin-events` returns posted XIAO telemetry for the current vehicle label
- [x] Confirm `tools\analyze-lin-capture.py` compiles; use it after APG car capture CSV exists
- [ ] Pack: APGDT001, XIAO bench, 12V supply/battery clip, GND jumper, back-probes, laptop USB cables, printed wiring note

---

## Bench Validation

Run before any vehicle connection:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor
```

Expected: `RESULT PASS - all bench frames decoded as expected`

Tests: ID=0x0C (2B enhanced), 0x10 (2B enhanced), 0x22 (4B enhanced), 0x3C (8B enhanced + 8B classic).

## Full No-Car Evidence

Run after wiring, parser, APG sender, or telemetry changes:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200
```

Latest full run: `tesla-bench-full-20260526`, 80/80 exact matches, 64 unique raw IDs, 0 APG failures, 0 bad checksum/parity frames.

Quick pre-car smoke:

```powershell
.\tools\bench-evidence-suite.ps1 -Quick -VehicleId tesla-bench-precar -ComPort COM4 -Baud 19200
```

If XIAO WiFi is unavailable, use USB serial telemetry instead of blocking:

```powershell
.\tools\serial-to-lin-events.ps1 -ComPort COM4 -VehicleId tesla-bench-usb -ApiBase http://localhost:8002
```

---

## Car Day — Quick Start

**Preflight:** Connect hardware. Verify LIN wire identification (white = LIN for Model X SW, verify on 3/Y).

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench

# Option A: Unified launcher (APG + XIAO + summary)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\car-day-launcher.ps1 -VehicleId tesla-model-3-test -DurationSeconds 180

# Option B: APG-only (high-volume capture)
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200 -DurationSeconds 120

# Option C: APG 9600 fallback (if no traffic at 19200)
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 9600 -DurationSeconds 120
```

---

## Car Day — XIAO Setup (after APG started)

```powershell
# Monitor XIAO serial
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor --port COM4 --baud 115200 --dtr 1 --rts 0

# Set runtime vehicle ID (send this in the serial terminal):
vehicle:tesla-model-3

# Switch baud if needed:
baud:19200
baud:9600

# Check stats:
stats

# Dump recent frames:
ring

# Enable raw byte debug (only if debugging parser):
raw:1
raw:0
```

Query secretary telemetry:

```powershell
curl http://localhost:8002/api/v1/lin-events -s | python -m json.tool
```

---

## Post-Capture Analysis

### Quick summary (existing):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1
```

### Python analyzer (recommended — includes Tesla reference + anti-nag payloads):
```powershell
# Analyze latest capture
python tools\analyze-lin-capture.py --latest logs\

# Analyze specific capture
python tools\analyze-lin-capture.py logs\lin-capture-20260526_140000.csv

# Export JSON summary
python tools\analyze-lin-capture.py --latest logs\ --json logs\capture-summary.json
```

The analyzer:
- Groups frames by ID with rate, count, unique payloads
- Labels known IDs from Tesla Model X reference
- Flags unknown IDs (breakers for 3/Y)
- Prints anti-nag injection reference table (bench only)
- Reports checksum failures
- Auto-detects likely model from ID presence

---

## Model 3/Y Discovery Workflow

Since Model 3/Y steering IDs are not yet known:

1. **APG passive capture** at 19200 baud while operating controls
2. **Run analyzer** — it flags unknown IDs automatically
3. **Identify steering ID**: look for an ID that shows payload variation when you:
   - Scroll up/down (left wheel = volume)
   - Press scroll wheel
   - Press buttons (if equipped)
4. **Check against community reports**: IDs `0x1A` and `0x1B` are candidates
5. **Record findings**: update `tools/analyze-lin-capture.py` ID_REFERENCE with confirmed payloads

### Control test matrix (for any model):
| Test | Action duration | What to watch |
|---|---|---|
| Idle baseline | 30s | All IDs, no inputs |
| Scroll UP | 10s continuous | ID with B0 > neutral |
| Scroll DOWN | 10s continuous | ID with B0 < neutral |
| Scroll click | 5 presses | ID with B1=0x04 |
| Mixed scroll | 30s random | ID with B2/B3 non-zero |

---

## Hard Stops

- No active transmit/injection on a vehicle bus until passive capture is decoded and reviewed.
- Do not run `validate-xiao-bench.ps1` on a vehicle — it transmits frames.
- Do not power from uncertain vehicle wires without common ground verified.
- Do not pierce harness insulation unless connector-safe probing is impossible and risk is accepted.
- Do not assume Model 3/Y IDs match Model X. Capture first, then label.
- Do not use anti-nag injection reference on a customer vehicle.

## Car Day Step 2 - XIAO Passive Capture

The XIAO firmware passively reads the same LIN physical layer through the TJA1021 module. It prints every decoded frame to USB serial and queues WiFi telemetry to secretary.

Important details:

- Parser finalizes frames by actual break/idle boundary, not only by predicted length.
- `pred=<n>` in serial output is only the old ID-class length hint. The actual `[nB]` is what was observed.
- Both enhanced and classic checksums are accepted and labeled.
- Protected-ID parity is reported as `parity=OK` or `parity=BAD`.
- HTTP posting is rate-limited and queued, so UART parsing stays real-time.

Monitor XIAO:

```powershell
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor --port COM4 --baud 115200 --dtr 1 --rts 0
```

Query secretary telemetry:

```powershell
curl http://localhost:8002/api/v1/lin-events -s | python -m json.tool
```

---

## Decode Phase

After a capture session, group by vehicle and ID:

- Model X known steering/body candidates from earlier work: `0x0C`, `0x0D`, `0x0E`, `0x0F`, `0x16`, `0x17`.
- Model 3/Y IDs are not assumed. Capture first, then label.
- Compare payload changes while toggling locks, windows, seat belt, HVAC, and steering wheel controls.

Use the APG CSV as the authoritative high-volume capture. Use XIAO secretary telemetry as a second path and integration proof.

---

## Hard Stops

- No active transmit/injection on a vehicle bus until passive capture is decoded and reviewed.
- Do not run `validate-xiao-bench.ps1` on a vehicle. It transmits frames.
- Do not power the APG/XIAO setup from uncertain vehicle wires without common ground verified.
- Do not pierce harness insulation unless connector-safe probing is impossible and the risk is accepted.

---

## Quick Commands

```powershell
# Build firmware
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe run

# Flash firmware
C:\Users\ezabz\.platformio\penv\Scripts\python.exe -m esptool --chip esp32c3 --port COM4 --baud 115200 --before default_reset --after hard_reset --no-stub write_flash -z --flash_mode dio --flash_freq 80m --flash_size 4MB 0x0 .pio\build\xiao_esp32c3\bootloader.bin 0x8000 .pio\build\xiao_esp32c3\partitions.bin 0x10000 .pio\build\xiao_esp32c3\firmware.bin

# Monitor XIAO
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor --port COM4 --baud 115200 --dtr 1 --rts 0

# Bench validation, transmit mode, not for vehicle
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor

# Car day passive APG monitor
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1
```