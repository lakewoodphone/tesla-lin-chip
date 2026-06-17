# Research Directive: ESP32-C3 LIN Physical Layer Hardening for Passive Capture (Tesla Model X)

**Directive ID**: 044-esp32c3-lin-physical-layer-and-passive-capture-hardening  
**Date Issued**: 2026-05-17  
**Requestor**: ezabz  
**Priority**: Critical  
**Category**: automotive-re / embedded-hardware / signal-integrity / lin

---

## Context

We are running a field deployment on a 2025 Tesla Model X steering-wheel LIN candidate wire (SW white wire). Existing passive capture with FX2/sigrok decodes LIN at 19200 and identifies IDs `0C, 0D, 0E, 0F, 16, 17`.

We then moved to XIAO ESP32-C3 (`D3/GPIO5` RX) using a passive 4x10k divider tap (row 4). Measured row4 idle is ~`2.575V` to GND.

Current firmware telemetry on XIAO:

- rising `breaks`, `syncerr`, and `skips`
- `rx` transitions observed
- `frames=0` (no valid sync+PID decode)

Need an authoritative hardware path from noisy/marginal passive tap to robust logic decode on ESP32-C3, with customer-car safety constraints.

---

## Questions

1. What are best-practice LIN-to-MCU receive front-ends for passive sniffing with 3.3V MCUs (ESP32-C3), including transceiver-based and non-transceiver options?
2. For LIN idle levels and dominant/recessive behavior, what threshold/noise-margin issues typically break UART decoding when using resistor-divider-only taps?
3. Compare these receive approaches for our field constraints:
   - resistor divider only
   - divider + pull-up assist
   - divider + Schmitt trigger/comparator
   - dedicated LIN transceiver RXD path (TJA1020/TJA1021/TJA104x class)
4. What protection components are recommended for safe automotive capture (ESD/TVS, series resistors, clamp strategy, grounding)?
5. What quantitative acceptance criteria should we require before considering decode quality "good" (frame error rates, sync lock metrics, parity fail rates)?
6. Provide a practical BOM and wiring reference for a compact "passive capture daughterboard" that outputs clean 3.3V logic into ESP32-C3 RX.

---

## Required Output

Return:

1. A decision matrix with electrical robustness, complexity, BOM cost, and field safety.
2. A recommended reference circuit for Tesla LIN passive capture into ESP32-C3 RX.
3. A validation test protocol with pass/fail thresholds.
4. A "minimum viable field fix" and a "production-worthy fix".
5. Explicit notes on what NOT to do on a live customer car.

Use authoritative sources: LIN transceiver datasheets, MCU electrical thresholds, and practical app notes.
