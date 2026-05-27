# xiao-lin-bench Tools Reference

Updated: 2026-05-27. Firmware v5 is current. Passive tools are ready for Model X/3/Y. Active Model X bench TX is verified on the isolated bench.

## Tool Inventory

| Tool | Purpose | Vehicle-safe? | Notes |
|---|---|---|---|
| `tools/monitor-apg-lin-bus.ps1` | APG passive LIN capture | Yes | Receive-only; use 32-bit PowerShell |
| `tools/car-day-launcher.ps1` | Passive car-day APG/XIAO launcher | Yes, passive-only | Starts capture/monitor/summary flow |
| `tools/validate-xiao-bench.ps1` | APG transmit -> XIAO receive validation | No | Bench only |
| `tools/bench-evidence-suite.ps1` | Full no-car APG/XIAO evidence matrix | No | Bench only; baseline, candidates, checksums, ID sweep |
| `tools/active-bench-proof.ps1` | XIAO active TX self-receive proof | No | Bench only; saves log and Markdown summary |
| `tools/active-apg-raw-proof.ps1` | XIAO active TX plus APG known-ID raw observer proof | No | Bench only; starts/stops active TX and asserts raw CSV rows |
| `tools/send-netanalyser-headless.ps1` | APG headless LIN transmit | No | Bench only; preferred APG send path |
| `tools/antinag-replay.ps1` | APG-generated anti-nag sequence | No | Bench only |
| `tools/serial-to-lin-events.ps1` | XIAO USB serial -> secretary API | Passive if source is passive | WiFi fallback telemetry bridge |
| `tools/summarize-lin-capture.ps1` | Summarize APG CSV logs | Yes | Post-capture only |
| `tools/analyze-lin-capture.py` | Full capture analysis and Tesla ID reference | Yes | Post-capture only |
| `tools/lin-payload-calc.py` | Payload/checksum calculator | Reference only | Generates/validates frame payloads |
| `tools/send-apg-lin-frame.ps1` | Direct PICkitS transmit | No | Debug only; baud reporting is unreliable |
| `tools/probe-apg-receive-api.ps1` | Reflect PICkitS/NetworkAnalyser receive APIs | Yes | Diagnostic only |
| `tools/probe-apg-usart-buffer.ps1` | Poll PICkitS raw USART bytes while XIAO transmits | No | Bench diagnostic; starts active TX |
| `tools/probe-netanalyser-passive-display.ps1` | Check whether NetworkAnalyser UI display sees XIAO frames | No | Bench diagnostic; starts active TX |

## Traffic Light

Vehicle bus:

```text
USE:
  monitor-apg-lin-bus.ps1
  car-day-launcher.ps1 in passive mode
  XIAO passive firmware/serial monitor

DO NOT USE:
  validate-xiao-bench.ps1
  bench-evidence-suite.ps1
  active-bench-proof.ps1
  send-netanalyser-headless.ps1
  antinag-replay.ps1
  ACTIVE_MODE transmit commands
```

Isolated bench:

```text
USE:
  validate-xiao-bench.ps1
  bench-evidence-suite.ps1
  send-netanalyser-headless.ps1
  antinag-replay.ps1
  active-apg-raw-proof.ps1
  active firmware commands after enabling ACTIVE_MODE
```

## Common Commands

APG passive capture at 19200:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200 -DurationSeconds 120
```

Alternate APG passive mode while troubleshooting external frames:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200 -DurationSeconds 120 -Mode Listen
```

APG known-ID raw fallback for the active Model X bench stream:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200 -DurationSeconds 10 -Mode DisplayAll -RawFallback -RawFallbackId 0x0C
```

APG headless send, bench only:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\send-netanalyser-headless.ps1 -Baud 19200 -Frame "0C 12 34" -Checksum Enhanced
```

Passive bench validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM4 -Baud 19200 -BootWaitSeconds 4 -PerFrameTimeoutMs 2500
```

Full no-car evidence:

```powershell
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200
```

Active Model X bench proof:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x
```

Active Model X proof with APG raw observer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -DurationSeconds 6 -MinFrames 8
```

USB serial telemetry fallback:

```powershell
.\tools\serial-to-lin-events.ps1 -ComPort COM4 -VehicleId tesla-bench-usb -ApiBase http://localhost:8002
```

Post-capture analysis:

```powershell
python tools\analyze-lin-capture.py --latest logs\
powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1
```

## Active Bench Commands

These exist only when firmware is built with `#define ACTIVE_MODE` enabled.

```text
model             Show current active profile
model:x           Model X, ID 0x0C, confirmed
model:3           Model 3 candidate, ID 0x1A, unconfirmed
model:y           Model Y candidate, ID 0x1A, unconfirmed
antinag:start     Start alternating active frames
antinag:stop      Stop active frames
antinag:single    Send one active frame
mirror:on         Enable periodic 0x0D mirror/alive frames
mirror:off        Disable mirror frames
tx:id,b0,...      Send a custom frame
txd:low           Hold XIAO D2/TXD low for wiring diagnostics
txd:high          Hold XIAO D2/TXD high for wiring diagnostics
txd:uart          Return D2/TXD to UART mode
```

Active bench proof command flow is automated by `tools/active-bench-proof.ps1`.

## APG Notes

- `PICkitS.dll` is x86. Use `SysWOW64\WindowsPowerShell\v1.0\powershell.exe` for APG scripts that load it.
- NetworkAnalyser frame strings use raw LIN IDs, not protected PIDs. Send `0C 12 34`, not `4C 12 34`.
- `Network_Load` initializes hardware at 9600; the working sender calls `Change_LIN_BAUD_Rate` after load.
- NetworkAnalyser event/display modes can miss externally generated XIAO active frames. For known-ID bench observation, `monitor-apg-lin-bus.ps1 -RawFallback` bypasses NetworkAnalyser and polls `PICkitS.Basic.Retrieve_USART_Data` directly, then checksum-validates frames using `-RawFallbackId`.
- `send-apg-lin-frame.ps1` is kept for API discovery/debug only. Use NetworkAnalyser-based tools for real validation.

## Known Tooling Gaps

- Generic APG event/display capture is still the right first path for vehicle discovery, but it does not report the XIAO-generated active bench stream. That bench case is settled through known-ID raw fallback (`source=raw` CSV rows), not NetworkAnalyser events.
- XIAO WiFi was unavailable on the bench (`NO_AP_FOUND`). USB serial telemetry is the reliable fallback.