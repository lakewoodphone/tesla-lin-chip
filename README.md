# xiao-lin-bench

LIN bus receive bench using XIAO ESP32-C3, APGDT001 LIN analyzer, and TJA1021 transceiver module.

**Goal:** Validate Tesla Model X / Model 3 / Model Y LIN receive at the bench before touching a vehicle bus.

**Start here next time:** read `START_HERE.md` first. It is the canonical handoff for current status, validated commands, passing evidence, hard stops, and the next action.

---

## Hardware

| Component | Part | Notes |
|---|---|---|
| MCU | Seeed XIAO ESP32-C3 | USB CDC, COM4 |
| LIN analyzer / transmitter | Microchip APGDT001 | VID=04D8 PID=0A04, HID USB |
| LIN transceiver module | GODIYMODULES TJA1021 breakout | 5V logic, open-drain LIN bus |
| Level shifter | DIYables 4-channel bidirectional | HV=5V ↔ LV=3.3V |
| PSU | Bench supply | 12V / 200mA |

---

## Wiring

```
PSU 12V ──────────────────────────────── APG VBAT (or bus power)
PSU 12V ──────────────────────────────── Module VIN
PSU GND ─┬──────────────────────────────── APG GND
          ├──────────────────────────────── Module GND
          ├──────────────────────────────── Level shifter GND
          └──────────────────────────────── XIAO GND

APG LINBUS ────────────────────────────── Module LIN

XIAO 5V ─┬──────────────────────────────── Module SLP  (HIGH = awake)
          └──────────────────────────────── Level shifter HV

XIAO 3V3 ────────────────────────────── Level shifter LV

Module RX ──────────────────────────────── Level shifter HV/A1
Level shifter LV/B1 ─────────────────── XIAO D3 (GPIO5) ← UART1 RX
```

> **SLP must be tied HIGH.** If SLP floats or is grounded, the TJA1021 enters sleep mode and passes no signal.

> **Wire the module RX pin, not TX.** The TJA1021's RX pin is the output from the transceiver toward the MCU. TX is the input from the MCU toward the bus (not used for receive-only bench work).

---

## Firmware

**File:** `src/main.cpp`

- UART1 at 19200 baud on GPIO5 (D3)
- GPIO5 interrupt edge counter (sanity check, resets each second)
- Boundary-based parser: IDLE -> SYNC(0x55) -> PID -> bytes until break/idle
- Actual payload length is observed from the frame boundary; ID-class length is reported only as `pred=<n>`
- Protected-ID parity validation
- Enhanced and classic checksum detection
- Raw byte trace disabled by default (`DEBUG_RAW_BYTES=0`) so vehicle-bus parsing is not slowed by USB logging
- Queued/rate-limited WiFi telemetry to `POST /api/v1/lin-events`; UART parsing never waits on HTTP
- Heartbeat: `alive d3=<pin_level> edges=<count> frames=<n> badChk=<n> badPid=<n> ovf=<n> ...`

**Secrets:** copy `src/secrets.h.example` to `src/secrets.h` and set WiFi + secretary URL before flashing. `src/secrets.h` is gitignored.

**Build/upload:**

```powershell
# Build
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe run

# Upload (must use --no-stub, stub fails on this chip/board combo)
C:\Users\ezabz\.platformio\penv\Scripts\python.exe -m esptool `
  --chip esp32c3 --port COM4 --baud 115200 `
  --before default_reset --after hard_reset --no-stub `
  write_flash -z --flash_mode dio --flash_freq 80m --flash_size 4MB `
  0x0    .pio\build\xiao_esp32c3\bootloader.bin `
  0x8000 .pio\build\xiao_esp32c3\partitions.bin `
  0x10000 .pio\build\xiao_esp32c3\firmware.bin
```

**Monitor:**

```powershell
C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor `
  --port COM4 --baud 115200 --dtr 1 --rts 0
```

> `--dtr 1` is required. Without it, USB CDC output does not appear on Windows.

---

## Tooling (tools/)

### send-netanalyser-headless.ps1 — PRIMARY SEND TOOL

Drives the APGDT001 headlessly via .NET reflection into `NetworkAnalyser.exe`. No GUI required.

```powershell
# Must run as 32-bit PowerShell (PICkitS.dll is x86)
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\send-netanalyser-headless.ps1 -Baud 19200 -Frame "0C 12 34" -Checksum Enhanced
```

### monitor-apg-lin-bus.ps1 — CAR-DAY PASSIVE CAPTURE

Passively monitors the LIN bus via APGDT001 (receive-only). Logs every frame to CSV + text. Works for Model X, 3, Y — captures whatever the bus emits.

### car-day-launcher.ps1 — UNIFIED ENTRY POINT (NEW)

Single command for field work: sets XIAO vehicle ID/baud, starts APG capture, opens XIAO monitor, runs summary.

### validate-xiao-bench.ps1 — BENCH VALIDATION

Full bench validation matrix (5 test frames). TRANSMITS — do not run on a vehicle.

### bench-evidence-suite.ps1 — FULL NO-CAR EVIDENCE

Runs baseline Model X frames, Model 3/Y candidate IDs, enhanced/classic checksum cases, a raw ID sweep, and anti-nag replay while listening to XIAO serial. Writes CSV/JSON/Markdown evidence and posts decoded frames to secretary.

Latest full run: 80/80 exact matches, 64 unique raw IDs, 0 APG send failures, 0 bad checksum/parity frames.

```powershell
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200
.\tools\bench-evidence-suite.ps1 -Quick -VehicleId tesla-bench-precar -ComPort COM4 -Baud 19200
```

### serial-to-lin-events.ps1 — USB TELEMETRY FALLBACK

Parses XIAO USB serial decoded frame lines and posts them to `POST /api/v1/lin-events`. Use this when XIAO WiFi is unavailable.

```powershell
.\tools\serial-to-lin-events.ps1 -ComPort COM4 -VehicleId tesla-bench-usb -ApiBase http://localhost:8002
```

### antinag-replay.ps1 — ANTI-NAG REPLAY (NEW)

Generates alternating UP/DOWN scroll frames with correct LIN checksums. Bench only.
The APG sender is launched as a fresh 32-bit PowerShell process per frame to avoid NetworkAnalyser state leakage.

### summarize-lin-capture.ps1 — CAPTURE SUMMARY

Quick per-ID frame counts from APG CSV.

### analyze-lin-capture.py — PYTHON ANALYZER (NEW)

Full post-capture analysis with Tesla ID reference tables (Model X confirmed, 3/Y candidates). Per-ID stats, unknown ID alerts, checksum verification, anti-nag payload generation, JSON export.

### lin-payload-calc.py — PAYLOAD CALCULATOR (NEW)

Generate anti-nag frame tables, verify captured frames, compute checksums, scan multiple IDs. Commands: `antinag`, `idle`, `verify`, `checksum`, `scan`.

### send-apg-lin-frame.ps1 — DEBUG ONLY

Direct PICkitS path. Baud unreliable at 19200 (reports 10000). Use NetworkAnalyser tools instead.
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `
  -STA -NoProfile -ExecutionPolicy Bypass `
  -File tools\send-netanalyser-headless.ps1 `
  -Frame "3C 00 00 00 00 00 00 00 00" `
  -Checksum Enhanced `
  -Baud 19200
```

**Parameters:**
- `-Frame` — space-separated hex bytes: PID followed by payload bytes (e.g. `"3C 00 00 00 00 00 00 00 00"` for an 8-byte bench frame)
- `-Checksum` — `Enhanced` (default), `Classic`, or `Forced`
- `-Baud` — LIN baud rate, default 19200

**How it works:**
1. Loads `NetworkAnalyser.exe` as a .NET assembly via reflection
2. Creates the `WindowsApplication1.Network` form instance
3. Fires `Network_Load` (initializes PICkitS hardware at 9600 baud)
4. Sets `MasterBaudRate` field to target baud
5. Calls `_OnAnswerSource.Change_LIN_BAUD_Rate(baud)` twice (first call reconfigures the control block; second ensures the register write completes before transmit)
6. Sets checksum radio button, puts frame in the message list
7. Calls `Sendbtn_Click` to transmit

**Key discovery:** `Network_Load` always initializes the hardware at 9600. Setting `MasterBaudRate` alone is insufficient — you must call `Change_LIN_BAUD_Rate` on the `_OnAnswerSource` PICkitS.LIN instance after load to reconfigure the hardware.

---

### validate-xiao-bench.ps1 — BENCH SELF-TEST

Opens XIAO serial on COM4, transmits representative APG frames, and verifies that XIAO reports the expected ID, actual byte length, checksum mode, and parity.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tools\validate-xiao-bench.ps1 `
  -KillExistingMonitor
```

This script transmits frames. Use it only on the bench, never while connected to a vehicle bus.

Validation matrix currently passes on the bench for:

- `0x0C` 2-byte enhanced checksum
- `0x10` 2-byte enhanced checksum
- `0x22` 4-byte enhanced checksum
- `0x3C` 8-byte enhanced checksum
- `0x3C` 8-byte classic checksum

Important: NetworkAnalyser frame strings use the raw LIN ID (`0C`), not the protected PID (`4C`). The GUI computes the protected PID internally.

---

### monitor-apg-lin-bus.ps1 — CAR DAY PASSIVE CAPTURE

Puts APGDT001 into display-all receive mode and logs all frames to `.txt` and `.csv` files under `logs/`.

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `
  -STA -NoProfile -ExecutionPolicy Bypass `
  -File tools\monitor-apg-lin-bus.ps1

# Fallback speed if a 3/Y bus segment shows no 19200 traffic
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `
  -STA -NoProfile -ExecutionPolicy Bypass `
  -File tools\monitor-apg-lin-bus.ps1 -Baud 9600
```

This is receive-only. It is the primary car-day capture path.

The monitor initializes through `NetworkAnalyser.exe`, not the direct static PICkitS baud path. This matters because the direct static path reports `Get_LIN_BAUD_Rate: 10000` even when asked for 19200.

---

### summarize-lin-capture.ps1 — CAPTURE SUMMARY

Summarizes a `logs/lin-capture-*.csv` file by ID, payload length, count, approximate rate, payload variants, and error count.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tools\summarize-lin-capture.ps1
```

---

### send-apg-lin-frame.ps1 — Direct PICkitS API (debug only)

Calls `PICkitS.LIN` static methods directly without the GUI form. Keep this for API discovery and debugging only. Live bench validation showed this path can transmit while still reporting `Get_LIN_BAUD_Rate: 10000`, so it is not trusted for 19200 bench validation or car-day capture.

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `
  -NoProfile -ExecutionPolicy Bypass `
  -File tools\send-apg-lin-frame.ps1 `
  -Baud 19200 -Id 0x3C -Data "00 00 00 00 00 00 00 00" `
  -Checksum Enhanced -Repeat 3 -DelayMs 200
```

---

### Probe/discovery scripts

| Script | Purpose |
|---|---|
| `probe-pickits-lin.ps1` | Lists all PICkitS.LIN methods and their signatures |
| `probe-baud-fields.ps1` | Finds baud/speed fields + all ComboBoxes on the form |
| `probe-baud-methods.ps1` | Finds baud/config/init methods on the form |
| `probe-lin-instance.ps1` | Finds the PICkitS.LIN instance fields on the form |
| `probe-pickits-baud.ps1` | Full PICkitS type dump + LIN-related method list |
| `disasm-netanalyser-method.ps1` | IL disassembler for inspecting form methods |

---

## Verified Working State (May 2026)

- XIAO receives and parses LIN frames at 19200 baud
- Headless CLI send working, no GUI needed
- Enhanced checksum validates correctly
- Typical output for a clean frame:

```
raw gap=63542 b=00 state=0       ← break field (0x00 after idle)
raw gap=1 b=55 state=1           ← sync byte
raw gap=0 b=3C state=2           ← PID (ID=0x3C with parity)
raw gap=1 b=00 state=3           ← data byte 0
...
raw gap=1 b=C3 state=4           ← checksum
#1 ID=0x3C PID=0x3C [8B pred=8] data: 00 00 00 00 00 00 00 00 | chk=C3 enhanced parity=OK src=idle
```

---

## Known Issues / Gotchas

| Issue | Root cause | Fix |
|---|---|---|
| `edges=0` after send | Missing GND connection or SLP not tied HIGH | Add GND wire between all components; tie SLP to 5V |
| `sync err: got 0x66` instead of `0x55` | APG transmitting at 9600, XIAO receiving at 19200 | Call `Change_LIN_BAUD_Rate` on `_OnAnswerSource` after `Network_Load` |
| `PermissionError: Access is denied` on COM4 | Stale platformio monitor process holding the port | `Stop-Process -Name platformio -Force` |
| Upload fails with stub error | esptool stub incompatible with this board | Always use `--no-stub` flag |
| No serial output in monitor | DTR not asserted | Use `--dtr 1` with platformio monitor |

---

## Dependencies

- PlatformIO (espressif32 @ 6.9.0)
- `C:\Users\ezabz\Downloads\LINAnalyzer\` — contains `NetworkAnalyser.exe` and `PICkitS.dll` (x86)
- Windows 32-bit PowerShell (`SysWOW64\WindowsPowerShell\v1.0\powershell.exe`) for PICkitS.dll reflection
