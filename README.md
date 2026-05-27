# xiao-lin-bench

Tesla LIN bench project using a Seeed XIAO ESP32-C3, APGDT001 LIN analyzer, TJA1021 transceiver module, and 3.3V/5V level shifter.

Start with `START_HERE.md` when resuming. It is the current handoff and points to the active evidence, wiring, commands, and hard stops.

## Current Status

- Passive LIN receive is bench-verified at 19200 baud.
- Full no-car evidence passed on 2026-05-26: 80/80 exact APG -> XIAO matches across raw IDs `0x00` through `0x3F`, with 0 checksum/parity failures.
- Active Model X bench TX is verified on the isolated bench. `model:x` + `antinag:start` produced more than 100 self-received `0x0C` frames with enhanced checksum and parity OK.
- Active improvements applied: bus-idle collision guard (2 ms silence before TX), realistic scroll payloads (non-zero B2/B3), and mirror/alive frame injection (`0x0D` at 500 ms via `mirror:on`).
- Repository source defaults to passive/safe mode: `ACTIVE_MODE` is commented out in `src/main.cpp`.
- The physical bench XIAO is currently flashed with the working active firmware from 2026-05-27.
- APG known-ID raw fallback now captures XIAO-generated active Model X frames. NetworkAnalyser event/display modes still log zero rows for those external frames, but `monitor-apg-lin-bus.ps1 -RawFallback -RawFallbackId 0x0C` polls the PICkitS USART buffer directly and writes checksum-valid CSV rows.

## Hard Stops

- Do not transmit on a vehicle LIN bus.
- Do not run `validate-xiao-bench.ps1`, `bench-evidence-suite.ps1`, `send-netanalyser-headless.ps1`, `antinag-replay.ps1`, or active firmware commands on a vehicle.
- Vehicle work starts passive only: APG passive monitor plus XIAO passive receive.
- Do not assume Model 3/Y IDs match Model X. Capture first, then label.
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

Active mode (`#define ACTIVE_MODE`, bench only):

- Two modes: `mode:duty` (burst UP→DOWN every `period:N` ms, default 20s) or `mode:always` (constant alternation every 300ms).
- Double-click scroll wheel button: two fast presses toggles chip output on/off.
- Model profiles: `model:x` (`0x0C` confirmed), `model:3` (`0x1A` candidate), `model:y` (`0x1A` candidate), `model:auto`.
- Active commands: `model`, `model:x`, `model:3`, `model:y`, `antinag:start`, `antinag:stop`, `antinag:single`, `mode:duty`, `mode:always`, `period:20000`, `mirror:on`, `mirror:off`, `tx:`.
- Diagnostics: `txd:low`, `txd:high`, `txd:uart`.
- BLE: not enabled (NimBLE requires Arduino-as-IDF `sdkconfig` integration).

## Build And Flash

Build current repo default:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
python -m platformio run
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
# After enabling ACTIVE_MODE and flashing active firmware:
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x
```

Expected active proof: `ring` shows `ID=0x0C PID=0x4C [8B]` frames with `enhanced parity=OK` and `badChk=0 badPid=0` in `stats`.

Independent APG known-ID raw observer proof, bench only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -DurationSeconds 6 -MinFrames 8
```

Expected APG raw proof: `PASS` with raw CSV rows for `ID=0x0C`, `PID=0x4C`, `source=raw`.

## Tooling

| Tool | Purpose | Vehicle-safe? |
|---|---|---|
| `tools/monitor-apg-lin-bus.ps1` | APG passive capture | Yes, receive-only |
| `tools/car-day-launcher.ps1` | Passive car-day APG/XIAO launcher | Yes, if used passive-only |
| `tools/validate-xiao-bench.ps1` | APG transmit -> XIAO receive validation | No, bench only |
| `tools/bench-evidence-suite.ps1` | Full APG/XIAO no-car evidence matrix | No, bench only |
| `tools/active-bench-proof.ps1` | XIAO active TX self-receive proof | No, bench only |
| `tools/active-apg-raw-proof.ps1` | XIAO active TX plus APG known-ID raw observer proof | No, bench only |
| `tools/send-netanalyser-headless.ps1` | APG headless LIN transmit | No, bench only |
| `tools/antinag-replay.ps1` | APG anti-nag replay sequence | No, bench only |
| `tools/serial-to-lin-events.ps1` | XIAO USB serial -> secretary API | Passive if source is passive |
| `tools/analyze-lin-capture.py` | Post-capture analysis and Tesla ID reference | Yes, post-capture |
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
- `NEXT_STEPS.md` - current work plan.
- `TOOLS.md` - tool reference.
- `docs/archive/` - old passive-only and capture-history notes.

## Known Issues

| Issue | Current understanding |
|---|---|
| APG NetworkAnalyser event/display modes log zero rows for XIAO-generated active frames | Settled: use `monitor-apg-lin-bus.ps1 -RawFallback -RawFallbackId 0x0C` or `active-apg-raw-proof.ps1` for known-ID bench observation. Generic vehicle discovery still uses normal passive event capture first. |
| XIAO WiFi reports `NO_AP_FOUND` | Use USB serial and `serial-to-lin-events.ps1` unless WiFi credentials are repaired |
| `PermissionError` on COM4 | A serial monitor is holding the port; stop PlatformIO/terminal process |
| Direct `send-apg-lin-frame.ps1` baud looks wrong | Use NetworkAnalyser-based tools for real validation |
| Holding TXD low does not always pull LIN low forever | LIN dominant-timeout can release the bus; validate with real frames and ring buffer |