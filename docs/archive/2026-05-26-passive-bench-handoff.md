# Passive Bench Handoff — 2026-05-26

This was the state before active TX was validated on 2026-05-27.

## What Was True Then

- Firmware v4 was the primary live firmware.
- The bench was proven for passive LIN receive at 19200 baud.
- Full no-car evidence passed: 80/80 exact APG -> XIAO matches across raw IDs `0x00`-`0x3F`.
- Model X `0x0C` receive/decode was confirmed from previous passive capture.
- Model 3/Y IDs were still candidates only (`0x1A`/`0x1B`).
- Active TX firmware existed but had not yet been physically validated on the bus.

## Superseded By

The current root docs now supersede this passive-only state:

- `START_HERE.md`
- `ACTIVE_INJECTOR.md`
- `BENCH_EVIDENCE.md`

Key update on 2026-05-27: active Model X bench TX was validated after fixing a disconnected XIAO D2 -> level shifter LV2 jumper and switching active break generation to a half-baud UART `0x00` break.