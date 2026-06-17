# Tesla Model X XIAO LIN Field Analysis (2026-05-17)

> **Status as of 2026-05-26: BENCH COMPLETE.** The blocker documented here (physical-layer signal conditioning / `frames=0`) has been resolved. A proper TJA1021 transceiver + level shifter was added and first clean LIN frame decoded: `#1 ID=0x3C data: 00 00 00 00 00 00 00 00 | chk=C3 OK`.
>
> **Active project is now `C:\Users\ezabz\Code\xiao-lin-bench`.**  
> This doc is preserved as the field evidence baseline and root-cause record.

---

## Scope

This document consolidates field observations, firmware state, serial diagnostics, and risk analysis for the 2025 Tesla Model X steering wheel LIN work performed on 2026-05-17.

Goal of this phase: establish reliable passive receive on XIAO ESP32-C3 and validate whether candidate LIN frame ID `0x0C` can be safely advanced toward controlled testing.

## Executive Summary

The firmware stack and flashing/logging pipeline are now operational and stable:

- Build succeeds on `espressif32@6.9.0`.
- Direct esptool `--no-stub` flashing at `115200` is reliable.
- USB CDC logging on COM6 is stable with ESP32-C3-specific flags enabled.

However, passive decode on the current resistor-divider tap is not yet valid:

- XIAO reads transitions (`rx` flips, `breaks` and `skips` rise).
- No valid LIN sync/PID decode (`frames=0`).
- Measured tap voltage `row4 -> GND = 2.575V` indicates the node is active and electrically safe, but likely marginal for robust UART-high discrimination on ESP32-C3 under in-vehicle noise/edge conditions.

Conclusion: software path is recovered; current blocker is physical-layer signal conditioning into XIAO RX.

## Live Hardware / Field Context

- Vehicle: 2025 Tesla Model X (Moti visit set)
- Proven candidate wire for passive LIN capture: SW white wire
- Passive divider chain in use: 4x10k ladder
- Current XIAO hookup:
  - `D3/GPIO5` -> divider row 4 (RX tap)
  - `GND` -> shared ground
  - `D2/GPIO4` and `D4/GPIO6` intentionally disconnected for passive mode
- Voltage:
  - `row4 -> GND = 2.575V`

Safety status for current customer-car work:

- Keep passive-only mode.
- Do not connect TX/injection path yet.
- Do not perform write/lock/injection actions until receive path is clean and frame semantics are reconfirmed.

## Firmware / Build State (Current)

External source tree in active use: `C:\Users\ezabz\Code\lpt-schematics\firmware\anti-nag-v1`

### platformio.ini

Current key settings:

- `platform = espressif32@6.9.0`
- `upload_protocol = esptool`
- `upload_speed = 115200`
- `monitor_dtr = 0`
- `monitor_rts = 0`
- `-DARDUINO_USB_MODE=1`
- `-DARDUINO_USB_CDC_ON_BOOT=1`
- BLE intentionally stubbed for field build stability

### Config and scan start

- `SCAN_ID_START = 0x0C`
- `SCAN_ID_END = 0x2F`
- Auto-scan starts at `0x0C` when no locked frame ID exists.

### Runtime diagnostics in loop heartbeat

Heartbeat reports include:

- `baud`, `inv`, `scan`, `candidate`, `known`
- `rx`
- `breaks`, `syncerr`, `skips`, `frames`
- `err`, `inj`

This instrumentation is sufficient to separate:

1. board dead / serial dead,
2. RX electrically dead,
3. RX active but decode-invalid.

Current state is (3).

## Verified Command Outcomes

### Flash / transport

Direct esptool no-stub write with verification succeeded after PlatformIO uploader instability.

Known stable command family (already validated during session):

- `--chip esp32c3 --port COM6 --baud 115200 --before usb_reset --after hard_reset --no-stub write_flash ...`

### Serial capture

Stable COM6 diagnostic capture returned repeating heartbeats, for example:

- `ALIVE #2 ... rx=1 breaks=157 syncerr=160 skips=3960 frames=0 ...`
- `ALIVE #3 ... rx=1 breaks=237 syncerr=240 skips=5880 frames=0 ...`
- `ALIVE #4 ... rx=1 breaks=317 syncerr=320 skips=7800 frames=0 ...`
- `ALIVE #5 ... rx=0 breaks=397 syncerr=401 skips=9720 frames=0 ...`

Interpretation:

- Data transitions are present.
- Parser is not seeing clean LIN sync/PID sequences.
- This is not a firmware boot crash or dead COM problem.

## Technical Root-Cause Analysis

Most probable cause chain:

1. Raw LIN waveform is being reduced via passive divider to a logic-level-adjacent tap.
2. At row4, idle sits near `2.575V`, only moderately above ESP32-C3 VIH threshold margin in real noisy automotive conditions.
3. Edge distortion/noise plus threshold margin causes UART byte stream corruption.
4. Stream shows activity but cannot consistently produce valid `0x55` sync and parity-valid PID.

Secondary contributors considered:

- Wrong baud: tested broadly during session, no decode win.
- RX inversion mismatch: attempted runtime inversion probe, resulted in instability and was rolled back.
- USB/serial transport issue: ruled out by stable heartbeat telemetry.

## Risks and Guardrails

### Immediate technical risks

- False confidence from "activity seen" without frame decode.
- Overstepping into injection with incomplete receive confidence.
- Raising tap voltage unsafely (for example by moving to a high divider node) and damaging XIAO GPIO.

### Operational guardrails

- Passive capture only on customer vehicle.
- Keep `D2` and `D4` disconnected until explicit bench validation gates are met.
- No frame lock/write action from candidate findings alone.

## Recommended Next Actions

### Priority A (field-safe)

1. Keep current wiring (`D3 + GND` only).
2. Add mild pull-up assist from row4 to XIAO `3V3` using ~`30k-47k` effective resistance to improve high-level margin without overdriving pin limits.
3. Re-capture heartbeat and evaluate whether `frames` starts incrementing.

### Priority B (preferred robust path)

1. Insert a proper LIN physical receiver stage (for example TJA1020-class transceiver RXD output) between vehicle LIN and XIAO RX.
2. Feed only cleaned logic-level RXD into `D3/GPIO5`.
3. Re-run passive decode metrics and compare frame quality with FX2 baseline.

### Priority C (validation/control)

1. Reconfirm control sensitivity of ID `0x0C` under repeatable input sequences.
2. Build byte-level transition matrix and entropy/time correlation before any lock/injection decision.
3. Keep customer-car testing non-invasive until deterministic control mapping is established.

## Open Questions

1. Exact row-level waveform shape at the XIAO pin (rise/fall, ringing, duty under load).
2. Whether Schmitt/comparator conditioning materially outperforms transceiver RXD for this setup.
3. Whether a software edge-time decoder on GPIO can recover frames if UART remains unreliable.

## Artifact Relationship

This report is the local evidence baseline. Research directives 044/045/046 extend this with external documentation and comparative engineering options, then synthesis should be folded back into this operating plan.
