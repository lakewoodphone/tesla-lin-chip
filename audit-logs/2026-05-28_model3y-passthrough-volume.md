# 2026-05-28 Model 3/Y Passthrough Volume Implementation

## Summary

- Consolidated the successful guided Model 3 steering LIN capture into durable docs.
- Confirmed left wheel ID `0x2A` and right wheel ID `0x2B` from 51,113 parsed frames.
- Fixed the active firmware `tx:` parser edge case where `0D` was treated as an empty decimal prefix.
- Replaced the quick volume injector with a counter-aware, 0x-prefixed, JSON-logged injector.
- Added `vol:up`, `vol:down`, `vol:click`, and `vol:idle` active firmware commands for confirmed Model 3/Y left-wheel frames.
- Added `car_passthrough` dual-transceiver firmware prototype for the actual cut-wire bridge architecture.
- Updated docs and tooling to supersede the old `0x1A`/`0x1B` Model 3/Y candidates.

## Canonical Artifacts

```text
docs/model3y-steering-lin-2026-05-28.md
docs/model3y-passthrough-volume.md
logs/sessions/20260528_211119-guided-tesla-model-3-20260528/analysis-byte-report.txt
tools/archive/inject-vol-scroll.quick-20260528.py
```

## Key Byte Map

```text
ID 0x2A / PID 0x6A / 7 bytes / enhanced checksum
byte[0] 0x0C idle, 0x0D volume up, 0x0B volume down, 0x2C click
payload [control, 80, 3F, 96, 00, F0..FF, paired-counter]
```

First volume-up payload:

```text
0x2A data 0D 80 3F 96 00 F0 7F checksum C1 enhanced
```

## Validation

- `python -m py_compile tools\inject-vol-scroll.py tools\analyze-log-bytes.py tools\analyze-lin-capture.py tools\lin-payload-calc.py` passed.
- PowerShell parser check passed for touched scripts.
- `tools\process-model3y-capture.ps1` successfully generated `analysis-byte-report.txt` for the guided capture.
- `python tools\inject-vol-scroll.py COM7 up 3 --dry-run --no-log` emitted corrected 0x2A up frames.
- `python tools\inject-vol-scroll.py COM7 down 4 --dry-run --no-log` emitted corrected 0x2A down frames.
- `python tools\lin-payload-calc.py checksum 0x2A 0D 80 3F 96 00 F0 7F` returned enhanced checksum `0xC1`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1` built all environments successfully, including `car_passthrough`.

## Safety Notes

Do not connect active TX or passthrough firmware to the vehicle until the steering wheel controls have recovered from the short event and all wiring is insulated. The current one-transceiver bench path is not the final passthrough install; the passthrough design requires two LIN transceivers.
