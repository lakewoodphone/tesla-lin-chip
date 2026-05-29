# Model 3/Y Steering LIN Capture - 2026-05-28

This is the canonical record for the successful Tesla Model 3 steering wheel LIN capture and the current volume-control injection map.

## Source Artifacts

Session:

```text
logs/sessions/20260528_211119-guided-tesla-model-3-20260528/
```

Files:

```text
manifest.json
xiao-guided-serial.log
analysis-byte-report.txt
```

Processing command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\process-model3y-capture.ps1 -SessionDir logs\sessions\20260528_211119-guided-tesla-model-3-20260528
```

Result: 51,113 parsed LIN frames from 21:11:20 to 21:19:55.

## Confirmed IDs

| Raw ID | PID | Length | Role |
|---|---:|---:|---|
| `0x28` | `0xA8` | 5 | Static steering-wheel module/config frame |
| `0x29` | `0xE9` | 5 | Counter/status frame |
| `0x2A` | `0x6A` | 7 | Left scroll wheel controls |
| `0x2B` | `0x2B` | 6 | Right scroll wheel controls |
| `0x2C` | `0xEC` | 5 | Mostly static status frame |
| `0x2D` | `0xAD` | 5 | Mostly static status frame |
| `0x3C` | `0x3C` | 8 | Diagnostic request, classic checksum possible |
| `0x3D` | `0x7D` | 8 | Diagnostic response, classic checksum possible |

The earlier `0x1A` Model 3/Y candidate was wrong for this car. Keep it only as historical context.

## Left Wheel Volume Map

ID `0x2A`, 7 bytes, enhanced checksum.

```text
byte[0]  control state
byte[1]  0x80 stable
byte[2]  0x3F stable
byte[3]  0x96 usual stable value; 0x94 appears during some transitions
byte[4]  0x00 stable
byte[5]  16-step counter: 0xF0..0xFF
byte[6]  paired counter/check byte
```

Control byte:

| Action | byte[0] |
|---|---:|
| Idle | `0x0C` |
| Scroll up / volume up | `0x0D` |
| Scroll down / volume down | `0x0B` |
| Click | `0x2C` |

Counter pair used by the current injector and firmware:

| Slot | byte[5] | byte[6] |
|---:|---:|---:|
| 0 | `0xF0` | `0x7F` |
| 1 | `0xF1` | `0x62` |
| 2 | `0xF2` | `0x45` |
| 3 | `0xF3` | `0x58` |
| 4 | `0xF4` | `0x0B` |
| 5 | `0xF5` | `0x16` |
| 6 | `0xF6` | `0x31` |
| 7 | `0xF7` | `0x2C` |
| 8 | `0xF8` | `0x97` |
| 9 | `0xF9` | `0x8A` |
| 10 | `0xFA` | `0xAD` |
| 11 | `0xFB` | `0xB0` |
| 12 | `0xFC` | `0xE3` |
| 13 | `0xFD` | `0xFE` |
| 14 | `0xFE` | `0xD9` |
| 15 | `0xFF` | `0xC4` |

First volume-up payload:

```text
ID=0x2A PID=0x6A data=0D 80 3F 96 00 F0 7F checksum=C1 enhanced
```

Tool verification:

```powershell
python tools\lin-payload-calc.py checksum 0x2A 0D 80 3F 96 00 F0 7F
```

## Right Wheel Map

ID `0x2B`, 6 bytes, enhanced checksum.

The same byte[0] control pattern appears in right-wheel action windows:

| Action | byte[0] |
|---|---:|
| Idle | `0x0C` and occasional `0x4C` |
| Scroll up | `0x0D` |
| Scroll down | `0x0B` |
| Click | `0x2C` |

Bytes 2-5 are a denser rolling status/counter pattern. Do not use the right-wheel frame for injection until a dedicated right-wheel counter model is extracted.

## Old Script Failure Root Cause

The original quick injector sent this style of command:

```text
tx:2A,0D,80,3F,94,00,00,0B
```

Two issues made it unreliable:

1. Firmware parsing treated token `0D` as a decimal prefix (`0d`) with no numeric body, so parsing stopped before any data bytes and returned `cmd: tx requires at least one data byte`.
2. The script used stale frame data: byte[3] `0x94` and fixed `00 0B` tail bytes instead of the confirmed 7-byte frame with the `F0..FF` counter pair.

Fixes applied:

- Firmware now treats `0D` as hex unless the token is actually longer than `0d`.
- New injector emits explicit `0x` byte tokens.
- New injector uses the confirmed `0x2A` 7-byte payload and counter table.
- New injector writes JSON run logs under `logs/injection-runs/` unless `--no-log` is passed.

## Current Active Commands

Bench active firmware supports direct Model 3/Y volume commands after `safe:arm`:

```text
vol:up
vol:down
vol:click
vol:idle
```

The serial injector sends explicit `tx:` commands instead:

```powershell
python tools\inject-vol-scroll.py COM7 up 8
python tools\inject-vol-scroll.py COM7 down --count 5
python tools\inject-vol-scroll.py COM7 up --dry-run
```

## Safety State

The steering wheel controls stopped responding after a wiring short. Based on the eFuse research, do not assume waiting alone will recover the circuit. Use a software Power Off, then a full LV/12V reset if needed, before reconnecting experiment hardware.

No active transmission should be attempted on the vehicle until steering controls are recovered and the wiring is fully insulated. Bench validation comes first.
