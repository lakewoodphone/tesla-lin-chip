# BLE Phone Proof Checklist

Use this after flashing `bench_active_ble` on the isolated bench.

## Setup

- XIAO flashed with `bench_active_ble`.
- TX path connected only on isolated bench.
- Serial monitor open or proof script logging enabled.
- Phone app: nRF Connect, LightBlue, or equivalent BLE client.

## Expected Service

| Item | Value |
|---|---|
| Advertised name | `TeslaAntiNag` |
| Service UUID | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Model UUID | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Mode UUID | `beb5483e-36e1-4688-b7f5-ea07361b26a9` |
| Period UUID | `beb5483e-36e1-4688-b7f5-ea07361b26aa` |
| Enable UUID | `beb5483e-36e1-4688-b7f5-ea07361b26ab` |
| Status UUID | `beb5483e-36e1-4688-b7f5-ea07361b26ac` |
| Capabilities UUID | `beb5483e-36e1-4688-b7f5-ea07361b26ad` |

## Proof Steps

1. Power-cycle XIAO and confirm status shows `armed=no` and `running=no`.
2. Write invalid model, mode, and period values; verify each characteristic returns the prior accepted value.
3. Write model `x`, mode `duty`, period `20000`; confirm serial `config` matches.
4. Write enable `on` before `safe:arm`; verify it returns/stays `off` and status last reason is `not_armed`.
5. In serial, run `safe:arm`.
6. Write enable `on`; verify serial shows active and status shows `armed=yes;running=yes`.
7. Write enable `off`; verify status shows `running=no`.
8. Run serial `safe:off`; verify `armed=no`.
9. Run serial `events`; verify boot/config/arm/start/stop/inhibit/fault events are visible and persisted slots print.
10. Power-cycle and verify the model/mode/period persisted but enable state is off/disarmed.

Save screenshots or phone-app export into the active bench proof folder.