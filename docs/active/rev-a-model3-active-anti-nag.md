# Rev A Model 3 Active Anti-Nag Runbook

Updated: 2026-06-17

## Scope

This is the current operating runbook for the Rev A dual-LIN ESP32-S3 board with `rev_a_active_ble` firmware. It is for bench bring-up and owner-supervised Model 3 testing only.

## Hardware Map

```text
CP2102 COM6:
  GND  -> TP1
  3V3  -> TP2
  RXD  -> TP6 / UART0_TX
  TXD  -> TP7 / UART0_RX
  EN   -> TP8
  BOOT -> TP9 / GPIO0

Rev A firmware pins:
  LIN_CAR   UART1 RX=GPIO4 TX=GPIO5
  LIN_WHEEL UART2 RX=GPIO6 TX=GPIO7
  LIN_EN    GPIO8
  ARM_SENSE GPIO9 active-high
```

Manual bootloader sequence:

```text
Hold BOOT/TP9 low, tap EN/TP8 low, release BOOT/TP9.
```

## Build And Flash

```powershell
cd C:\Users\ezabz\Code\tesla-lin-chip
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Build
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Flash -ComPort COM6 -ManualBoot
```

## Bench Verification Gate

Do not go to the vehicle until all of these pass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\new-rev-a-live-session.ps1 -VehicleId tesla-model-3-YYYYMMDD -ComPort COM6
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Command -ComPort COM6 -Commands version,config,nag:status,cache
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action BleScan
```

Use `docs/active/model3-live-measurement-plan.md` for the full measurement list and stop conditions.

Expected serial identity:

```text
fw=v5.5-rev-a-ble
build=rev_a_active_ble
baud=19200
armed=no
bridge=on
nag=no
```

Expected BLE identity:

```text
TeslaPassthrough
```

If serial is silent and BLE is not advertising, stop and debug boot/power/USB CDC before vehicle work.

## Serial Commands

Read-only/status:

```text
version
config
stats
cache
nag:status
```

Safety and bridge:

```text
safe:arm
safe:off
bridge:on
bridge:off
inject:clear
reset
```

Manual injection:

```text
vol:up[:count]
vol:down[:count]
vol:click[:count]
vol:idle[:count]
```

Anti-nag:

```text
nag:once
nag:on
nag:off
nag:interval:<ms>
```

`nag:once` queues one up/down pair. `nag:on` repeats up/down pairs at the configured interval. Minimum interval is 5000 ms.

## Vehicle Test Order

1. Confirm `safe:off` before connecting.
2. Confirm physical arm input is not accidentally active.
3. Connect car-side and wheel-side LIN exactly as mapped.
4. Watch `stats` with `bridge:off` first.
5. Use `bridge:on` only after baseline behavior is understood.
6. Test `vol:up:1`, `vol:down:1`, and `vol:click:1` before any automated nag behavior.
7. Test `nag:once` before `nag:on`.
8. If anything behaves unexpectedly, run `safe:off`, disconnect, and preserve logs.

## Open Validation Items

- Serial and BLE must be revalidated after the current v5.5 build.
- Bench-side car/wheel LIN simulator proof is still needed before confident vehicle-side active use.
- Right-wheel `0x2B` injection is intentionally out of scope.
