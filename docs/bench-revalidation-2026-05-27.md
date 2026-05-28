# Bench Revalidation - 2026-05-27 Evening

This records the bench work performed on `ZABZ-TECH` after the roadmap hardening pass. It is isolated-bench evidence only; no vehicle bus was connected.

## Hardware State

- XIAO ESP32-C3: `COM4`, USB VID/PID `303A:1001`, MAC `80:f1:b2:60:4e:88`.
- Initial APGDT001 state: USB VID/PID `04D8:0A04`, present in Windows as `USB Input Device` but failed-start with `Status=Error`, `Problem=CM_PROB_FAILED_START`, `ConfigManagerErrorCode=CM_PROB_FAILED_START`.
- Non-elevated `pnputil /restart-device` was attempted before the reseat and failed with `Access is denied`.
- Final APGDT001 state after physical reseat: both HID interfaces are `Status=OK`, `Problem=CM_PROB_NONE`, `ConfigManagerErrorCode=CM_PROB_NONE`.

## Firmware And BLE Fix

- `tools/build-all-envs.ps1` passed for `field_passive`, `field_passive_nowifi`, `bench_active_ble`, and `chip_lab_active`.
- `bench_active_ble` was flashed to `COM4` successfully.
- Active lab builds now compile with `NO_WIFI`, keeping active lab control/evidence on BLE plus USB serial.
- BLE advertising was fixed by using valid advertising intervals (`0x20` to `0x40`) instead of invalid too-fast intervals that caused NimBLE `rc=3` / `BLE_HS_EINVAL`.
- Serial verification after the fix reported `cmd: BLE advertising=yes` with service `4fafc201-1fb5-459e-8fcc-c5c9c331914b` and all expected characteristics.
- The no-WiFi heartbeat now reports `lastByteMs` instead of printing a missing-format-argument garbage field.
- Empty persisted event slots no longer produce NVS `NOT_FOUND` noise.

## Active XIAO Bench Proof

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x -ConfirmBenchIsolation
```

Result:

```text
RESULT PASS - active bench frames observed in XIAO ring
```

Latest artifact summary:

```text
logs\active-bench-proof-20260527_211924.md
logs\active-bench-proof-20260527_211924.log
```

Observed proof details:

- Firmware identity: `fw=v5.1 build=bench_active_ble active=yes wifi=no baud=19200`.
- BLE state: `advertising=yes`, expected service and characteristic UUIDs printed.
- Safety gate: `safe:arm` acknowledged before TX; `safe:off` acknowledged after TX.
- Model: `model=x id=0x0C`.
- Frames: Model X `ID=0x0C PID=0x4C [8B]` frames self-received in the XIAO ring.
- Checks: `badChk=0`, `badPid=0`, `ovf=0`, `short=0`, `syncErr=0`.
- Representative frames:

```text
ID=0x0C PID=0x4C [8B] data: 11 04 10 00 00 00 C0 00 | chk=CD enhanced parity=OK
ID=0x0C PID=0x4C [8B] data: 0F 04 08 02 00 00 C0 02 | chk=D3 enhanced parity=OK
```

Final XIAO safe state after all proof attempts:

```text
cmd: safe=off armed=no
cmd: config fw=v5.1 build=bench_active_ble reset=unknown model=x id=0x0C mode=duty period=20000ms armed=no running=no mirror=no tx=45 inhibit=0 last=none faults=0 fault=none lockout=no nvs=loaded crc=0x200CDC6E
cmd: BLE advertising=yes client=disconnected model=x mode=duty period=20000ms armed=no running=no last=none
cmd: frames=45 badChk=0 badPid=0 ovf=0 short=0 syncErr=0 edges=0 ring=45 wifi=disabled build=bench_active_ble active=yes reset=unknown
```

## APG Recovery And Passive Proof

The physical APG reseat cleared the Windows failed-start state. After reseat, APG transmit and raw monitor initialization both worked again.

Quick passive APG -> XIAO validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM4 -Baud 19200 -BootWaitSeconds 4 -PerFrameTimeoutMs 2500 -KillExistingMonitor
```

Result:

```text
logs\xiao-bench-validation-20260527_211238.log
RESULT PASS - all bench frames decoded as expected
```

Full passive evidence suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\bench-evidence-suite.ps1 -ComPort COM4 -Baud 19200 -VehicleId tesla-bench-reseat-20260527 -BootWaitSeconds 4 -PerFrameTimeoutMs 2200 -NoPost
```

Result:

```text
Bench evidence complete: 80/80 exact matches, observed=80, apgFailures=0
Report: logs\bench-evidence-20260527_211310\bench-evidence-20260527_211310.md
CSV:    logs\bench-evidence-20260527_211310\bench-evidence-20260527_211310.csv
JSON:   logs\bench-evidence-20260527_211310\bench-evidence-20260527_211310.json
```

## APG Raw Observer Proof After Reseat

The first post-reseat active raw observer attempt initialized APG successfully but observed zero rows because the proof script inherited persisted `mode=duty period=20000ms`, consumed the immediate startup burst, and then started APG monitoring during the quiet duty window.

`tools\active-apg-raw-proof.ps1` was tightened after that failure. It now:

1. Preflights APG raw monitor initialization before active TX.
2. Forces `mode:always` during the APG monitor capture window.
3. Stops active TX, runs `safe:off`, and restores `mode:duty` afterward.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -ComPort COM4 -Baud 19200 -DurationSeconds 6 -MinFrames 8 -ConfirmBenchIsolation
```

Result:

```text
CSV: logs\lin-capture-20260527_212130.csv
XIAO TX lines observed: 41
APG raw rows observed: 11
PASS: APG raw fallback captured 11 checksum-valid known-ID frames.
```

Representative APG raw rows:

```text
0x0C 0x4C 0F-04-00-00-00-00-C0-0D error=0 baud=19200
0x0C 0x4C 11-04-00-00-00-00-C0-08 error=0 baud=19200
0x0C 0x4C 0F-04-00-00-00-00-C0-0B error=0 baud=19200
```

## Recurrence Note

If APG returns to `CM_PROB_FAILED_START`, recover it with elevated PnP restart or physical USB replug/reseat before relying on APG transmit/capture tools. The active raw proof now aborts before transmit when APG cannot initialize.
