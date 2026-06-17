# Tesla LIN Bench Handoff - 2026-05-26

## Start Here

Canonical current handoff:

```text
C:\Users\ezabz\Code\xiao-lin-bench\START_HERE.md
```

Clean snapshot archive:

```text
C:\Users\ezabz\Code\_snapshots\xiao-lin-bench-20260526_134330.zip
```

When the owner says "open the Tesla project", use this sequence:

1. Open `C:\Users\ezabz\Code\xiao-lin-bench\START_HERE.md`.
2. Open `C:\Users\ezabz\Code\xiao-lin-bench\NEXT_STEPS.md`.
3. If hardware is connected, run `tools\validate-xiao-bench.ps1 -KillExistingMonitor`.
4. Continue from the first unchecked item in `NEXT_STEPS.md`.

## Current Status

Bench is working end-to-end at 19200 baud for passive LIN receive.

Verified components:

- XIAO ESP32-C3 on COM4.
- APGDT001 USB-LIN analyzer.
- GODIYMODULES TJA1021 module with SLP tied high.
- DIYables bidirectional level shifter.
- Firmware v3 in `src/main.cpp`.
- APG NetworkAnalyser-based sender and passive monitor tools.
- Secretary `POST /api/v1/lin-events` and `GET /api/v1/lin-events`.

## Latest Bench Validation

Command:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -KillExistingMonitor
```

Result:

```text
RESULT PASS - all bench frames decoded as expected
```

Passing frames:

```text
ID=0x0C PID=0x4C [2B pred=2] data: 12 34 | chk=6D enhanced parity=OK
ID=0x10 PID=0x50 [2B pred=2] data: AA 55 | chk=AF enhanced parity=OK
ID=0x22 PID=0xE2 [4B pred=4] data: 01 02 03 04 | chk=13 enhanced parity=OK
ID=0x3C PID=0x3C [8B pred=8] data: 00 00 00 00 00 00 00 00 | chk=C3 enhanced parity=OK
ID=0x3C PID=0x3C [8B pred=8] data: 00 00 00 00 00 00 00 00 | chk=FF classic parity=OK
```

## Important Discoveries

- NetworkAnalyser resets APG hardware to 9600 at `Network_Load`; set `MasterBaudRate`, then call `_OnAnswerSource.Change_LIN_BAUD_Rate(19200)` twice.
- NetworkAnalyser frame strings use raw LIN IDs, not protected PIDs. Send `0C 12 34`, not `4C 12 34`.
- Direct static PICkitS sender is debug-only; it can report/transmit while `Get_LIN_BAUD_Rate` shows 10000.
- APG passive monitor now initializes through NetworkAnalyser so it is safe for 19200 capture.
- TJA1021 `SLP` must be tied high to XIAO 5V.
- Wire TJA1021 module `RX` into the level shifter/XIAO, not module `TX`.

## Current Next Action

Configure `C:\Users\ezabz\Code\xiao-lin-bench\src\secrets.h` with real WiFi/hotspot credentials, `SECRETARY_URL`, and `VEHICLE_ID`, then rebuild and flash once more.

Car-day work is passive capture only until decoded and reviewed. No vehicle injection/transmit.
