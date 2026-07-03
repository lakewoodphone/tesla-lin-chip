# Model 3 Capture Data Index

Updated: 2026-06-17

## Confirmed Live Data

Primary Model 3 data lives under:

```text
logs/sessions/
```

Key sessions:

```text
20260528_204132-car-passive-tesla-model-3-20260528
20260528_211119-guided-tesla-model-3-20260528
```

The guided session contains 51,113 parsed frames across baseline and action windows. It is the best source for byte-level Model 3 steering-wheel behavior.

## Model 3 Steering IDs

Confirmed from the guided session:

| Raw ID | Len | Current role |
|---|---:|---|
| `0x28` | 5 | Stable steering module frame |
| `0x29` | 5 | Counter/toggle frame |
| `0x2A` | 7 | Left wheel control-bearing frame; current injection target |
| `0x2B` | 6 | Right wheel/control-bearing frame; not injection-ready |
| `0x2C` | 5 | Mostly static/status |
| `0x2D` | 5 | Mostly static/status |
| `0x3C` | 8 | Static/unrelated in observed capture |
| `0x3D` | 8 | Slightly variable; not active target |

## Current Injection Target

Rev A active firmware targets `0x2A` only.

Payload shape:

```text
ID 0x2A, PID 0x6A, 7 data bytes, enhanced checksum
[control, 0x80, 0x3F, 0x96, 0x00, counter_a, counter_b]
```

Control byte:

```text
0x0C idle
0x0D volume up
0x0B volume down
0x2C click
```

Do not promote `0x2B` injection until its counter and payload behavior are independently validated.

## Historical Contrast

Model X uses a different ID set (`0x0C-0x0F`, `0x16-0x17`) and a different primary control-bearing frame (`0x0C`). Do not transfer Model X IDs into the Model 3 Rev A path.
