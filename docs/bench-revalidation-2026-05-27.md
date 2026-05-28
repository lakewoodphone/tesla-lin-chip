# Bench Revalidation - 2026-05-27 Evening

This records the bench work performed on `ZABZ-TECH` after the roadmap hardening pass. It is isolated-bench evidence only; no vehicle bus was connected.

## Hardware State

- XIAO ESP32-C3: `COM4`, USB VID/PID `303A:1001`, MAC `80:f1:b2:60:4e:88`.
- APGDT001: USB VID/PID `04D8:0A04`, present in Windows as `USB Input Device` but currently failed-start.
- APG Windows state: `Status=Error`, `Problem=CM_PROB_FAILED_START`, `ConfigManagerErrorCode=CM_PROB_FAILED_START`.
- Non-elevated `pnputil /restart-device` was attempted and failed with `Access is denied`.

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

Artifact summary:

```text
logs\active-bench-proof-20260527_205055.md
logs\active-bench-proof-20260527_205055.log
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
cmd: config fw=v5.1 build=bench_active_ble reset=unknown model=x id=0x0C mode=duty period=20000ms armed=no running=no mirror=no tx=4 inhibit=0 last=none faults=0 fault=none lockout=no nvs=loaded crc=0x200CDC6E
cmd: frames=4 badChk=0 badPid=0 ovf=0 short=0 syncErr=0 edges=0 ring=4 wifi=disabled build=bench_active_ble active=yes reset=unknown
```

## APG Blocker

Passive APG -> XIAO validation is currently blocked by the APG device, not by the XIAO firmware.

Failed command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM4 -Baud 19200 -BootWaitSeconds 4 -PerFrameTimeoutMs 2500 -KillExistingMonitor
```

Observed result:

```text
RESULT FAIL - 5 frame validation(s) failed
APG Status: Error: Error sending script.
```

The raw PICkitS path also failed to initialize:

```text
Could not initialize APG/PICkit Serial.
```

`tools\active-apg-raw-proof.ps1` was hardened after this run: it now preflights APG raw monitor initialization before arming XIAO active TX. With the APG in the current failed-start state, it aborts before active TX:

```text
APG raw monitor preflight failed with code 1; active TX was not started
```

## Next APG Recovery Step

Recover the APG before relying on APG-based validation again:

1. Run VS Code/PowerShell elevated and retry `pnputil /restart-device "USB\VID_04D8&PID_0A04\..."`, or physically replug/reseat the APG.
2. Confirm Windows no longer reports `CM_PROB_FAILED_START`.
3. Rerun `tools\validate-xiao-bench.ps1` for passive APG transmit -> XIAO receive.
4. Rerun `tools\active-apg-raw-proof.ps1 -ConfirmBenchIsolation` for independent APG known-ID raw observation.
