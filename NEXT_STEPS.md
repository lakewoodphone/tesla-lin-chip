# Next Steps - xiao-lin-bench

Updated: 2026-05-27.

Current state: passive bench receive is proven, full no-car evidence passed, and active Model X bench TX is proven by XIAO self-receive/ring evidence. The repository source defaults to passive mode (`ACTIVE_MODE` commented out); the physical bench XIAO is flashed with the working active firmware.

For the complete handoff, read `START_HERE.md` first.

## Done

- Passive APG -> TJA1021 -> XIAO receive path validated at 19200 baud.
- Full no-car evidence suite passed 80/80 exact matches across raw IDs `0x00` through `0x3F`.
- USB serial -> secretary API fallback proved while XIAO WiFi was unavailable.
- Model X `0x0C` profile confirmed from real capture and bench replay.
- Active Model X bench TX validated on 2026-05-27:
  - fixed disconnected XIAO D2 -> level shifter LV2 jumper
  - switched TX break generation to half-baud UART `0x00`
  - `model:x` + `antinag:start` produced more than 100 self-received `0x0C` frames
  - enhanced checksums and parity were OK
- Active docs and diagnostics added: `ACTIVE_INJECTOR.md`, `txd:low`, `txd:high`, `txd:uart`.

## Next Work

1. Keep root docs current and use `docs/archive/` for historical handoffs.
2. Improve APG passive monitor behavior for XIAO-generated active frames; `DisplayAll` and `Listen` modes now print receive diagnostics, but both still log zero rows while XIAO self-receive parses valid bus frames.
3. If wireless telemetry matters, update `src/secrets.h`, rebuild, and verify WiFi or keep using USB serial telemetry.
4. Before any vehicle session, run passive quick evidence and pack the bench kit.
5. For Model 3/Y, do passive capture first and confirm steering IDs before adding new active profiles.

## Quick Validation Commands

Build current default firmware:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
python -m platformio run
```

Passive bench validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM4 -Baud 19200 -BootWaitSeconds 4 -PerFrameTimeoutMs 2500
```

Full no-car evidence:

```powershell
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200
```

Active Model X bench proof, after enabling `ACTIVE_MODE` and flashing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x
```

Expected proof: `stats` shows frames increasing with `badChk=0 badPid=0`; `ring` shows `ID=0x0C PID=0x4C [8B]` frames with enhanced checksum and parity OK.

## Car Day Passive Flow

Do not transmit on the vehicle bus.

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200 -DurationSeconds 120
```

Fallback only if 19200 shows no traffic:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 9600 -DurationSeconds 120
```

Analyze after capture:

```powershell
python tools\analyze-lin-capture.py --latest logs\
powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1
```

## Model 3/Y Discovery

Model 3/Y steering IDs are not confirmed. Candidate IDs are `0x1A` and `0x1B`, but the workflow is passive capture first:

1. Capture idle baseline.
2. Operate scroll up/down, wheel click, and relevant steering controls.
3. Run `tools/analyze-lin-capture.py`.
4. Identify IDs whose payload changes only during the control action.
5. Update `MODEL_PROFILES[]` only after confirmation.

## Hard Stops

- No active transmit/injection on a vehicle bus.
- Do not run bench transmit tools on a vehicle.
- Do not power from uncertain vehicle wires without common ground verified.
- Do not pierce harness insulation unless connector-safe probing is impossible and risk is accepted.
- Do not use active anti-nag references on a customer vehicle.