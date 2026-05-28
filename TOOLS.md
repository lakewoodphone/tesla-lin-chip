# xiao-lin-bench Tools Reference

Updated: 2026-05-27. Firmware v5.1 is current with passive default build profiles, active bench BLE/USB build, safe arm gating, NVS config, and BLE status. Passive tools are ready for Model X/3/Y. Active Model X bench TX is verified on the isolated bench.

## Tool Inventory

| Tool | Purpose | Vehicle-safe? | Notes |
|---|---|---|---|
| `tools/monitor-apg-lin-bus.ps1` | APG passive LIN capture | Yes | Receive-only; use 32-bit PowerShell |
| `tools/car-day-launcher.ps1` | Passive car-day APG/XIAO launcher | Yes, passive-only | Enforces passive preflight and `field_passive` firmware by default |
| `tools/build-all-envs.ps1` | Compile supported firmware environments | Yes | Builds passive, no-WiFi, active bench, chip lab |
| `tools/new-capture-session.ps1` | Create manifest-backed capture folder | Yes | Creates manifest JSON and checklist README |
| `tools/preflight-hardware-check.ps1` | Record hardware preflight evidence | Yes | Interactive power/ground/TX/RX checklist; `-RequirePass` exits nonzero on failed gate |
| `tools/full-bench-proof.ps1` | One-command isolated-bench proof wrapper | No | Builds, preflights, passive proof; active/APG raw proof require `-RunActive -ConfirmBenchIsolation` |
| `tools/validate-xiao-bench.ps1` | APG transmit -> XIAO receive validation | No | Bench only |
| `tools/bench-evidence-suite.ps1` | Full no-car APG/XIAO evidence matrix | No | Bench only; baseline, candidates, checksums, ID sweep |
| `tools/active-bench-proof.ps1` | XIAO active TX self-receive proof | No | Bench only; saves log and Markdown summary |
| `tools/active-apg-raw-proof.ps1` | XIAO active TX plus APG known-ID raw observer proof | No | Bench only; starts/stops active TX and asserts raw CSV rows |
| `tools/prepare-model3y-car-day.ps1` | Pre-arrival 3/Y readiness | Yes | Checks APG/XIAO, builds, flashes `field_passive`, verifies passive identity |
| `tools/start-model3y-passive-capture.ps1` | Passive 3/Y capture launcher | Yes | Creates session, writes action windows, runs passive car-day capture |
| `tools/process-model3y-capture.ps1` | Post-capture 3/Y analysis | Yes | Runs summary/analyzer and emits candidate JSON |
| `tools/stage-model3y-active-bench.ps1` | Bench-only 3/Y active staging | No | Edits reviewed profile ID, flashes active build, runs bench proofs |
| `tools/send-netanalyser-headless.ps1` | APG headless LIN transmit | No | Bench only; preferred APG send path |
| `tools/antinag-replay.ps1` | APG-generated anti-nag sequence | No | Bench only |
| `tools/serial-to-lin-events.ps1` | XIAO USB serial -> secretary API | Passive if source is passive | WiFi fallback telemetry bridge |
| `tools/summarize-lin-capture.ps1` | Summarize APG CSV logs | Yes | Post-capture only |
| `tools/analyze-lin-capture.py` | Full capture analysis and Tesla ID reference | Yes | Post-capture; supports manifest action windows |
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
  field_passive XIAO firmware/serial monitor

DO NOT USE:
  validate-xiao-bench.ps1
  bench-evidence-suite.ps1
  active-bench-proof.ps1
  send-netanalyser-headless.ps1
  antinag-replay.ps1
  ACTIVE_MODE transmit commands
  bench_active_ble or chip_lab_active on a vehicle bus
```

Isolated bench:

```text
USE:
  validate-xiao-bench.ps1
  bench-evidence-suite.ps1
  send-netanalyser-headless.ps1
  antinag-replay.ps1
  active-apg-raw-proof.ps1
  active firmware commands only after safe:arm
```

Build all firmware environments:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1
```

Create a passive car capture session folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\new-capture-session.ps1 -Mode car-passive -VehicleId tesla-model-y-test -Baud 19200
```

Record physical preflight:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\preflight-hardware-check.ps1 -Mode car-passive -RequirePass
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
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x -ConfirmBenchIsolation
```

Active Model X proof with APG raw observer:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -Model x -DurationSeconds 6 -MinFrames 8 -ConfirmBenchIsolation
```

Model 3/Y car arrival flow:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\prepare-model3y-car-day.ps1 -ComPort COM4
powershell -NoProfile -ExecutionPolicy Bypass -File tools\start-model3y-passive-capture.ps1 -Model 3 -VehicleId tesla-model-3-YYYYMMDD -Baud 19200 -DurationSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File tools\process-model3y-capture.ps1 -SessionDir logs\sessions\<session-folder>
powershell -NoProfile -ExecutionPolicy Bypass -File tools\stage-model3y-active-bench.ps1 -CandidateJson logs\sessions\<session-folder>\model-profile-candidate.json -Model 3 -UseTopCandidate -ConfirmProfileUpdate -ConfirmBenchIsolation
```

USB serial telemetry fallback:

```powershell
.\tools\serial-to-lin-events.ps1 -ComPort COM4 -VehicleId tesla-bench-usb -ApiBase http://localhost:8002
```

Post-capture analysis:

```powershell
python tools\analyze-lin-capture.py --latest logs\
python tools\analyze-lin-capture.py logs\lin-capture-example.csv --json logs\analysis.json --windows logs\sessions\session\manifest.json --candidate-json logs\sessions\session\model-profile-candidate.json
powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1
```

## Active Bench Commands

These exist only when firmware is built as `bench_active_ble`, `chip_lab_active`, or the legacy `xiao_esp32c3` active env.

```text
safe:arm         Explicitly arm active TX for isolated bench work
safe:off         Stop active output and disarm
factory:reset    Clear persisted model/mode/period config and return safe/off
config           Print active config, NVS status, arm state, TX counters
events           Print recent active events plus persisted event slots
stats            Print reset reason, frame counters, build mode, and active/passive state
model             Show current active profile
model:x           Model X, ID 0x0C, confirmed
model:3           Model 3 candidate, ID 0x1A, unconfirmed
model:y           Model Y candidate, ID 0x1A, unconfirmed
antinag:start     Start active frames after safe:arm
antinag:stop      Stop active frames
antinag:single    Send one active frame
mode:duty         Duty-cycle mode: burst UP -> DOWN every `period` ms
mode:always       Always mode: constant alternation every 300ms
period:60000      Set duty-cycle period (5000-120000ms, default 20000)
mirror:on         Enable periodic 0x0D mirror/alive frames
mirror:off        Disable mirror frames
tx:id,b0,...      Send a custom frame after safe:arm; byte tokens default to hex, prefix decimal as 0d12
txd:low           Hold XIAO D2/TXD low for wiring diagnostics after safe:arm
txd:high          Hold XIAO D2/TXD high for wiring diagnostics after safe:arm
txd:uart          Return D2/TXD to UART mode
```

Active bench proof command flow is automated by `tools/active-bench-proof.ps1`.

## APG Notes

- `PICkitS.dll` is x86. Use `SysWOW64\WindowsPowerShell\v1.0\powershell.exe` for APG scripts that load it.
- NetworkAnalyser frame strings use raw LIN IDs, not protected PIDs. Send `0C 12 34`, not `4C 12 34`.
- `Network_Load` initializes hardware at 9600; the working sender calls `Change_LIN_BAUD_Rate` after load.
- NetworkAnalyser event/display modes can miss externally generated XIAO active frames. For known-ID bench observation, `monitor-apg-lin-bus.ps1 -RawFallback` bypasses NetworkAnalyser and polls `PICkitS.Basic.Retrieve_USART_Data` directly, then checksum-validates frames using `-RawFallbackId`.
- If Windows shows the APGDT001 as `CM_PROB_FAILED_START`, APG send/capture tools will fail. Recover the device first with an elevated PnP restart or physical USB replug/reseat; the May 27 reseat restored `CM_PROB_NONE` and both passive/APG raw proofs passed afterward.
- `send-apg-lin-frame.ps1` is kept for API discovery/debug only. Use NetworkAnalyser-based tools for real validation.

## Known Tooling Gaps

- Generic APG event/display capture is still the right first path for vehicle discovery, but it does not report the XIAO-generated active bench stream. That bench case is settled through known-ID raw fallback (`source=raw` CSV rows), not NetworkAnalyser events.
- `active-apg-raw-proof.ps1` preflights APG raw monitor initialization before starting active TX, supports `-Model x|3|y|auto`, forces `mode:always` during the APG capture window, restores `mode:duty` afterward, and exits before transmit if APG initialization fails.
- XIAO WiFi was unavailable on the bench (`NO_AP_FOUND`). USB serial telemetry is the reliable fallback.
