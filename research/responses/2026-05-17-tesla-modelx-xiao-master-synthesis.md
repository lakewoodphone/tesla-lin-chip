# Tesla Model X XIAO LIN Master Synthesis

Date: 2026-05-17

## Scope

This document synthesizes:

- Live field evidence from the 2025 Model X steering LIN work.
- Firmware and tooling validation from the XIAO ESP32-C3 deployment.
- Deep research outputs from directives 044, 045, 046, and 047.

Primary objective: convert current findings into a clear technical truth, a safety-gated execution plan, and production-grade documentation for continuing work.

## Evidence Base

### Local field and firmware evidence

- Active firmware tree: C:/Users/ezabz/Code/lpt-schematics/firmware/anti-nag-v1
- XIAO COM identity is stable when configured correctly (VID_303A, PID_1001, COM6 in current session).
- Stable diagnostic telemetry repeatedly shows:
  - rx transitions present
  - breaks and sync skips increasing
  - frames staying at 0
- Measured row4 tap voltage to GND: 2.575 V.
- Current wiring state:
  - D3/GPIO5 to divider row 4
  - GND to GND
  - D2 and D4 intentionally disconnected for passive mode

### Research jobs completed

- 044 physical-layer hardening: complete (OpenRouter DeepSeek v4 Pro)
- 045 ID 0x0C confidence and gating: complete (Perplexity sonar deep research)
- 046 ESP32-C3 USB CDC reliability workflow: complete (Perplexity sonar deep research)
- 047 authoritative hardware-source refresh: complete (Perplexity sonar deep research)

## Ground Truth Summary

1. Firmware and USB pipeline are no longer the blocker.
2. Decoder failure is now dominated by physical-layer signal integrity into ESP32-C3 RX.
3. Divider-only taps are not sufficiently robust for reliable LIN decode in the vehicle environment.
4. Current 0x0C signal candidacy is promising, but not yet at proof threshold for safe active manipulation.
5. Customer-car safety requires strict passive-only operation until hard gates are passed.

## Why Frames Stay at Zero

Given the telemetry and measured voltage, the node is alive and seeing transitions, but not seeing reliably decodable sync/PID bytes.

Most likely chain:

- LIN bus is percentage-threshold, automotive-noise-tolerant signaling in a 12 V domain.
- Divider tap at row 4 yields safe voltage, but marginal high-level/noise margin at MCU threshold boundary.
- RX threshold crossings and edge quality are not clean enough for consistent UART decode.
- Result: activity counters increase, valid frame counter does not.

This matches field observation and research conclusions.

## USB CDC and Flashing Runbook (Now Standard)

Known-good PlatformIO setup for XIAO ESP32-C3:

- ARDUINO_USB_MODE=1
- ARDUINO_USB_CDC_ON_BOOT=1
- monitor_dtr=0
- monitor_rts=0
- upload_protocol=esptool
- upload_speed=115200

Operational truth:

- PlatformIO default upload can work, but direct esptool no-stub at 115200 is the stability fallback and should be considered standard for field recovery.
- Always close monitors before flashing.
- If connect fails, force bootloader mode and use no-stub write_flash flow.

## Hardware Decision Matrix (Final)

### Option A: Immediate field-safe improvement

- Keep passive mode only.
- Introduce proper LIN transceiver receive path so XIAO reads transceiver RXD logic, not raw divider-derived signal.
- Use automotive protection basics (TVS on power/input, sane grounding, short leads).

Use case:

- Fast field stabilization and reliable passive decode.

### Option B: Production-grade capture module

- LIN transceiver + dedicated automotive-qualified power path + full ESD/transient protection.
- Clean 3.3 V logic-level interface into ESP32-C3.
- Designed to fail safe and not disturb bus if module faults.

Use case:

- Repeatable operations, permanent tooling, customer-safe long-term reliability.

Decision:

- Move immediately to transceiver-based RX path.
- Do not continue iterative divider-only decoding on customer vehicle.

## 0x0C Confidence Framework

Current state:

- 0x0C remains best control-sensitive candidate from passive captures.
- Not yet enough to classify as safely inject-able.

Required confidence dimensions before any active step:

- Temporal causality: control change leads payload change with stable lag.
- Specificity: payload does not change under no-input controls/baselines.
- Reproducibility: behavior persists across repeated sessions and conditions.
- Payload semantics: byte and bit roles are interpretable and consistent.
- Exclusivity: 0x0C explains control behavior better than other candidate IDs.

Minimum decision stance today:

- Continue classification as candidate-only.
- No lock/write/injection authorization.

## Hard Safety Gates (Must Pass in Order)

1. Passive capture quality gate:
   - stable decoded frames present
   - no persistent parity/checksum anomalies from capture path
2. Attribution gate:
   - 0x0C confidence rubric passes threshold on repeated datasets
3. Bench replay gate:
   - payload/CRC handling validated off-vehicle
4. Isolation gate:
   - active-path hardware cannot unintentionally drive bus
5. Controlled non-customer validation gate:
   - no adverse effects in bounded tests
6. Customer-car gate:
   - explicit owner approval after all prior gates pass

Current status:

- Gates 1-6 are not yet all passed.

## Immediate Execution Plan

### Phase 1: Hardware stabilization for receive

- Build transceiver-based passive receive adapter.
- Keep D2/D4 disconnected during customer-car tests.
- Re-run passive capture and heartbeat diagnostics.
- Success criterion: frames increments reliably under expected traffic.

### Phase 2: Structured confidence experiments

- Run baseline, single-control, mixed randomized segments.
- Produce byte-level transition and timing correlation matrix for IDs 0x0C, 0x0D, 0x0E, 0x0F, 0x16, 0x17.
- Re-score 0x0C with rubric.

### Phase 3: Bench-only active validation

- Validate framing/checksum and schedule assumptions in bench setup first.
- Build abort-safe tooling and collision avoidance checks.

### Phase 4: Go/No-Go board

- If all gates pass, prepare a constrained, reversible, non-customer in-vehicle test plan.
- If any gate fails, remain passive and iterate capture hardware or attribution analysis.

## Do-Not-Do List (Enforced)

- Do not connect MCU pins directly to raw LIN.
- Do not treat divider-only decode success as production-safe.
- Do not connect D2 or D4 in customer-car phase while receive path is unresolved.
- Do not classify 0x0C as lock/write-ready from correlation alone.
- Do not run injection tests on customer hardware.

## 0x0C Frame Byte Structure — Decoded (2026-05-17)

Source: FX2/sigrok seated capture (60s, connector fully hooked, user actively operating controls).
Analysis tooling: `analyze-lin-capture.ps1` (fixed raw-UART parser), `compare-lin-captures.ps1`.

### Frame layout (9 bytes: 8 data + 1 checksum)

```
Byte  Offset  Name       Idle   Active range       Notes
B0    0       Control    0x10   0x0A – 0x15        Position/torque offset from neutral (0x10)
B1    1       Buttons    0x00   0x04, 0x08, 0x0C,  Bit-packed button/control state
                                0x10, 0x1C
B2    2       Rate       0x00   0x08 – 0x48        Instantaneous scroll velocity
B3    3       Accum      0x00   0x10 – 0xB0        Accumulated scroll count (≈ 2×B2)
B4    4       Reserved   0x00   0x00               Always 0x00
B5    5       Reserved   0x00   0x00               Always 0x00
B6    6       Status     0xC0   0xC0               Always 0xC0 (alive/status flags)
B7    7       Counter    XF     0x0F–0xFF (XF)     Rolling 4-bit counter, upper nibble 0→F cycle
B8    8       Checksum   var    var                LIN enhanced checksum
```

### Confirmed byte semantics (from user: "scrolled up and down for volume change")

The user operated the **left steering-wheel scroll wheel** (volume control) during the seated and single-control captures. This directly confirms:

| B0 value | Meaning |
|----------|---------|
| `0x10` | Neutral — wheel at rest, no scroll |
| `> 0x10` (e.g. `0x11`–`0x15`) | Scroll UP → volume increase |
| `< 0x10` (e.g. `0x0F`–`0x0A`) | Scroll DOWN → volume decrease |

B1 `0x04` = scroll-wheel **touch/engage** flag (set as soon as finger contacts the wheel, before meaningful position delta).

### LIN enhanced checksum — confirmed formula

`PID = 0x4C` (verified from decoded capture: sync = `0x55`, next byte = `0x4C`, and `0x4C & 0x3F = 0x0C`).

```python
def lin_enhanced_checksum(pid: int, data: list) -> int:
    s = pid
    for b in data:
        s += b
        if s > 0xFF:
            s -= 0xFF   # absorb carry (1s-complement addition)
    return 0xFF - s
```

Verified 15/15 against real payloads from baseline, single-control, and seated captures. Zero failures.

### Key observations

- Manual capture (SW connector not seated): B0 = `0x10` only; B1, B2, B3 all `0x00`. Zero control events. 1 unique payload.
- Seated capture (active use, ~60s): 309 unique payloads. B0 ranges `0x0A`–`0x15`; B1 bit-patterns appear; B2 and B3 both non-zero during scroll.
- **B2 and B3 always move together.** B3 ≈ 2×B2 — consistent with B2 = instantaneous rate and B3 = running total for that scroll event.
- When wheel returns to idle: B2 and B3 both return to `0x00`.
- B6 = `0xC0` is invariant across all 309 unique payloads — pure status field, ignore for control decoding.
- B7 (rolling counter) increments regardless of control state — this is a frame-alive counter, not a control field.

### Single scroll event signature (from single-control vs baseline compare)

A single light scroll produces 6 new payloads vs baseline. Distinguishing features:

| Payload | Interpretation |
|---------|---------------|
| `10 04 00 00 ...` | B1 bit 2 set — scroll-wheel contact/engage event |
| `11 00 00 00 ...` | B0 = `0x11` — 1 step away from neutral |
| `10 00 00 10 ...` | B3 = `0x10` — accumulated 1 tick |

### 0x0D behaviour

ID `0x0D` also fires at 1438 frames (same rate as 0x0C) but shows only 17 unique payloads across the full seated session — almost entirely the rolling counter variation with B0–B3 fixed at idle levels. **0x0D is passive/response or a mirror node; it does not carry control-event data.**

### 0x0E and 0x0F behaviour

Both alternate between two values (`0x50`/`0x51` in first byte). Classic 1-bit alive toggle — likely a heartbeat or seat/occupancy signal. Not relevant to scroll/control work.

### 0x16 and 0x17

Completely static across all captures. Configuration/version frames — not relevant.

### Implication for anti-nag work

The SCCM frame to watch for anti-nag purposes is **ID `0x0C`**. A minimal "input seen" signal needs:

- B0 ≠ `0x10` (e.g. `0x11` or `0x0F`), **or**
- B1 ≠ `0x00` (e.g. `0x04`), **or**
- B2/B3 non-zero (scroll activity)

The checksum and rolling counter must be correct for any active-injection test.

### Generated idle counter-cycle table (for passive monitoring reference)

All 16 frames for idle state `B0=0x10, B1=B2=B3=0x00`, counter 0–15. Checksums verified by formula.

```
B0  B1  B2  B3  B4  B5  B6  B7  CHK   ctr
10  00  00  00  00  00  C0  0F  D3    0
10  00  00  00  00  00  C0  1F  C3    1
10  00  00  00  00  00  C0  2F  B3    2
10  00  00  00  00  00  C0  3F  A3    3
10  00  00  00  00  00  C0  4F  93    4
10  00  00  00  00  00  C0  5F  83    5
10  00  00  00  00  00  C0  6F  73    6
10  00  00  00  00  00  C0  7F  63    7
10  00  00  00  00  00  C0  8F  53    8
10  00  00  00  00  00  C0  9F  43    9
10  00  00  00  00  00  C0  AF  33   10
10  00  00  00  00  00  C0  BF  23   11
10  00  00  00  00  00  C0  CF  13   12
10  00  00  00  00  00  C0  DF  03   13
10  00  00  00  00  00  C0  EF  F2   14  ← also seen in baseline capture ✓
10  00  00  00  00  00  C0  FF  E2   15  ← also seen in baseline capture ✓
```

Cross-check: these exact payloads appear in the real baseline capture. This confirms the formula is production-accurate.

### Generated anti-nag injection sequence (bench/lab only — not customer-car ready)

Alternating UP (B0=`0x11`) / DOWN (B0=`0x0F`) with B1=`0x04` (scroll engage). Net volume change ≈ 0. Counter advances each frame. 8 pairs = 16 frames before cycle repeats.

```
B0  B1  B2  B3  B4  B5  B6  B7  CHK   direction  ctr
11  04  00  00  00  00  C0  0F  CE    UP         0
0F  04  00  00  00  00  C0  1F  D0    DOWN       1

11  04  00  00  00  00  C0  2F  AE    UP         2
0F  04  00  00  00  00  C0  3F  B0    DOWN       3

11  04  00  00  00  00  C0  4F  8E    UP         4
0F  04  00  00  00  00  C0  5F  90    DOWN       5

11  04  00  00  00  00  C0  6F  6E    UP         6
0F  04  00  00  00  00  C0  7F  70    DOWN       7

11  04  00  00  00  00  C0  8F  4E    UP         8
0F  04  00  00  00  00  C0  9F  50    DOWN       9

11  04  00  00  00  00  C0  AF  2E    UP        10
0F  04  00  00  00  00  C0  BF  30    DOWN      11

11  04  00  00  00  00  C0  CF  0E    UP        12
0F  04  00  00  00  00  C0  DF  10    DOWN      13

11  04  00  00  00  00  C0  EF  EE    UP        14
0F  04  00  00  00  00  C0  FF  F0    DOWN      15
```

Inject at ~200–500 ms per frame. Monitor volume level. Return to idle (B0=`0x10`, B1=`0x00`) between gesture pairs if drift is observed.

Tooling: `scripts/lin-payload-calc.py` — run `python lin-payload-calc.py antinag` to regenerate.

**SAFETY HARD STOPS:** Bench/lab validation required. Do NOT inject on customer or owner vehicle. Active injection on Tesla LIN may trigger SCCM fault codes or SRS diagnostics.

---

## Do-Not-Do List (Enforced)

The project is in a good state operationally: firmware, flashing, and logging are recoverable and repeatable.

The true remaining blocker is physical-layer conditioning from vehicle LIN into a robust digital RX signal for ESP32-C3. The right move now is hardware interface correction (transceiver-based passive receive), followed by structured confidence testing for 0x0C under strict safety gates.

This keeps progress high while preserving customer-car safety and engineering rigor.
