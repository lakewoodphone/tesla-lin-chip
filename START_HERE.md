# tesla-lin-chip - Start Here

Last updated: 2026-06-17

This project is now organized around the Rev A dual-LIN ESP32-S3 board and active Model 3 anti-nag validation. Older XIAO/APG passive discovery material is preserved under `docs/archive/legacy-xiao-2026-06-17/` and remains useful historical evidence, but it is no longer the first operating surface.

## Current Active Objective

Prepare and validate the Rev A board for supervised active anti-nag testing on a Model 3.

Current bench hardware:

```text
Board: Rev A Tesla dual-LIN ESP32-S3-WROOM-1U-N8R8
USB/UART adapter: CP2102 on COM6
Serial console: UART0, 115200 baud, TP6/TP7
Car LIN UART: UART1, GPIO4 RX / GPIO5 TX
Wheel LIN UART: UART2, GPIO6 RX / GPIO7 TX
LIN baud: 19200
Firmware env: rev_a_active_ble
Firmware version: v5.5-rev-a-ble
BLE name: TeslaPassthrough
```

Primary current docs:

```text
docs/README.md                                  Documentation map and archive policy
docs/active/rev-a-model3-active-anti-nag.md     Current live-test runbook
docs/active/model3-live-measurement-plan.md      Full measurement list and stop gates
docs/active/model3-capture-data-index.md        Capture inventory and ID map
docs/model3y-passthrough-volume.md              Passthrough architecture reference
docs/rev-a-first-article-2026-06-16.md          Rev A physical review and bring-up notes
docs/rev-b-quality-gate-2026-06-16.md           Rev B ordering gate
```

Primary current script:

```text
tools/rev-a-active-model3.ps1
```

## Hard Stops

- Do not connect Rev A to a vehicle until serial control, BLE advertising, safe-off, and bench-side LIN behavior are verified.
- Do not arm (`safe:arm`) unless the physical arm input is intentionally enabled and the board is connected exactly as intended.
- Do not transmit on a customer or unknown vehicle. The current target is owner-supervised Model 3 testing only.
- Do not use the old XIAO one-LIN active bench scripts for Rev A vehicle passthrough testing.
- If the steering wheel controls are still affected by a prior short, restore the vehicle first before active testing.

## Immediate Workflow

Build Rev A active BLE firmware:

```powershell
cd C:\Users\ezabz\Code\tesla-lin-chip
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Build
```

Flash after manual bootloader entry:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Flash -ComPort COM6 -ManualBoot
```

Verify serial identity:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\new-rev-a-live-session.ps1 -VehicleId tesla-model-3-YYYYMMDD -ComPort COM6
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Command -ComPort COM6 -Commands version,config,nag:status,cache
```

Scan BLE:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action BleScan
```

Use `docs/active/rev-a-model3-active-anti-nag.md` as the live checklist once serial and BLE are verified.
