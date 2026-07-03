# Model 3 Live Measurement Plan - Rev A Active Test

Updated: 2026-06-17

## Readiness Answer

Do not connect Rev A to the car until the final cleaned `rev_a_active_ble` firmware is flashed and the board passes serial plus BLE verification on the bench.

Current hard gate:

```text
NOT CAR-READY until:
  1. Final v5.5-rev-a-ble build is flashed after manual bootloader entry.
  2. COM6 responds to version/config/cache/nag:status.
  3. BLE scan sees TeslaPassthrough.
  4. safe:off is confirmed after boot and after reset.
  5. Physical arm behavior is understood and safe:arm is blocked unless intentionally active.
```

## Tools On The Bench

Have these ready before touching the car:

```text
Laptop with repo open
CP2102 adapter on COM6
Multimeter with sharp probes
Current-limited 12V bench supply
Insulated alligator clips or back probes
Electrical tape/heatshrink for any temporary conductors
Camera/phone for connection photos
Session log folder created by tools/new-rev-a-live-session.ps1
```

## Create Session Log

```powershell
cd C:\Users\ezabz\Code\tesla-lin-chip
powershell -NoProfile -ExecutionPolicy Bypass -File tools\new-rev-a-live-session.ps1 -VehicleId tesla-model-3-YYYYMMDD -ComPort COM6
```

Use the generated `measurements.md` file as the working log. Record every reading before moving to the next gate.

## Gate 1 - Unpowered Board Measurements

Record with Rev A unpowered.

| Item | Probe A | Probe B | Expected | Block if |
|---|---|---|---|---|
| GND to 3V3 | TP1 | TP2 | High resistance, no hard short | Beep or near 0 ohm |
| GND to VBAT_IN | TP1 | F1 left pad | High resistance | Beep or near 0 ohm |
| GND to VBAT_PROTECTED | TP1 | F1 right pad | High resistance | Beep or near 0 ohm |
| Fuse continuity | F1 left pad | F1 right pad | Low resistance/beep | Open circuit |
| LIN_A to GND | TP10 | TP1 | Open/high resistance | Short |
| LIN_B to GND | TP11 | TP1 | Open/high resistance | Short |
| LIN_A to LIN_B | TP10 | TP11 | Open/high resistance | Short |
| UART TX/RX not shorted | TP6 | TP7 | Open/high resistance | Short |
| EN not stuck low | TP8 | TP1 | Not hard short | Short |
| BOOT not stuck low | TP9 | TP1 | Not hard short | Short |

## Gate 2 - Bench Power Measurements

Use current limit. Start low and raise only if the board behaves normally.

| Item | Measurement | Expected | Block if |
|---|---|---|---|
| 3V3 rail | TP2 to TP1 | About 3.3 V | Low, high, unstable |
| VBAT protected | F1 right pad to TP1 | Matches bench 12 V path | Missing/unexpected |
| Current draw, idle | Bench supply | Stable and reasonable | Current limit hit, heating |
| ESP boot | COM6 serial | Boot banner or command response | No response |
| Firmware identity | `version` | `fw=v5.5-rev-a-ble build=rev_a_active_ble` | Wrong build/version |
| Safe state | `config` | `armed=no`, `nag=no` | Armed or nag on at boot |
| BLE advertising | `BleScan` | `TeslaPassthrough` found | Not found |

Bench commands:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Command -ComPort COM6 -Commands version,config,nag:status,cache
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action BleScan
```

## Gate 3 - Harness And Car-Side Pre-Connection

Record before plugging Rev A into the car.

| Item | Measurement | Expected | Block if |
|---|---|---|---|
| Car 12V | Vehicle 12V to vehicle ground | Normal vehicle supply | Unstable/unknown |
| Car ground to board GND | Vehicle ground to TP1 | Continuity/common ground when connected as intended | Ground path uncertain |
| Car LIN to ground, key state documented | Car-side LIN to vehicle ground | LIN idle voltage appropriate for bus state | Short to ground/battery |
| Wheel LIN to ground, key state documented | Wheel-side LIN to vehicle ground | LIN idle voltage appropriate for bus state | Short to ground/battery |
| Car/wheel orientation | Physical wiring photo | Car side and wheel side labeled | Ambiguous direction |
| Native controls | Wheel controls before board active test | Working normally | Controls already failed |

## Gate 4 - Connected Passive/Safe-Off Observation

Board may be physically connected only if Gates 1-3 pass.

Start safe:

```text
safe:off
bridge:off
config
stats
```

Record:

| Item | Expected |
|---|---|
| `armed` | `no` |
| `bridge` | `off` after command |
| `nag` | `no` |
| `car_headers` | May increase if car master is polling |
| `responses` | Should not increase while bridge off/safe off |
| `inhibited` | May increase while car headers arrive but TX is blocked |
| Vehicle behavior | No warnings, no control loss caused by board state |

Stop if vehicle behavior changes before active commands.

## Gate 5 - Bridge Observation

Only after Gate 4 is quiet.

Commands:

```text
bridge:on
config
cache
```

Record:

| Item | Expected |
|---|---|
| Wheel cache | `0x28` through `0x2D` present or explain missing IDs |
| `wheel_good` | Increasing on a healthy wheel-side bus |
| `wheel_bad` | Not climbing rapidly |
| Native controls | Still normal |

If native controls stop working, run `safe:off`, disconnect, and document.

## Gate 6 - Manual Injection

Only after native behavior is acceptable with bridge on.

Start with one-frame tests:

```text
safe:arm
vol:up:1
stats
vol:down:1
stats
vol:click:1
stats
inject:clear
```

Record for each command:

| Field | Record |
|---|---|
| Command sent | Exact command |
| Timestamp | Local time |
| `pending` before/after | From stats/config |
| `injected` before/after | From stats/config |
| Vehicle reaction | Volume change, click behavior, no reaction, warning |
| Driver display/audio state | What changed |
| Any fault | Warning, control loss, reboot, serial silence |

Immediate stop conditions:

```text
Unexpected volume runaway
Any warning/fault on car display
Native controls stop responding
Serial control is lost
Board heats, browns out, or resets unexpectedly
```

Stop command:

```text
safe:off
bridge:off
inject:clear
nag:off
```

## Gate 7 - Anti-Nag

Only after one-frame manual injection behaves correctly.

Test one cycle first:

```text
nag:status
nag:once
stats
nag:status
```

Then test recurring with conservative interval:

```text
nag:interval:15000
nag:on
stats
nag:off
stats
```

Record every up/down pair and whether the net effect is zero volume change.

## Final Session Closeout

Before ending:

```text
nag:off
inject:clear
bridge:off
safe:off
config
```

Session artifacts to keep:

```text
measurements.md
serial transcript
BLE scan output
photos of wiring
notes on every unexpected observation
```
