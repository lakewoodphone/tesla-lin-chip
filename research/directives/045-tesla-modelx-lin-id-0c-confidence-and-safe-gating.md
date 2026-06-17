# Research Directive: 2025 Tesla Model X Steering LIN ID 0x0C Confidence Build and Safe Injection Gating

**Directive ID**: 045-tesla-modelx-lin-id-0c-confidence-and-safe-gating  
**Date Issued**: 2026-05-17  
**Requestor**: ezabz  
**Priority**: Critical  
**Category**: automotive-re / protocol-analysis / safety-gating

---

## Context

Field capture summary:

- Wire: SW white (steering wheel candidate)
- Decoded at 19200 via FX2/sigrok
- IDs observed: `0C, 0D, 0E, 0F, 16, 17`
- Single-control tests indicate ID `0x0C` has strongest payload variation and is current top control-sensitive candidate.

However, this is still an inference stage. We need a rigorous confidence framework before any lock/write/injection path is considered.

---

## Questions

1. What is the strongest methodology to prove a specific LIN frame ID carries a steering-wheel control signal, not just correlated traffic?
2. What statistical and experimental design should be used to isolate wheel input from confounders (vehicle state changes, periodic counters, checksums, unrelated controls)?
3. How should payload bytes be analyzed for signed-delta behavior, counters, and state bits?
4. What minimum evidence threshold should be required before classifying ID `0x0C` as "control-bearing"?
5. What explicit safety gates should be required before any active injection on non-bench hardware?
6. Provide a staged validation plan from passive capture -> bench replay -> isolated non-customer validation -> controlled in-vehicle test.

---

## Required Output

Return:

1. A rigorous confidence-scoring rubric for frame-ID attribution.
2. A recommended experiment matrix for steering inputs (single-axis, repeated, randomized, blinded segments).
3. A byte-level analysis checklist (delta, monotonic counters, CRC/checksum handling, timing alignment).
4. A hard-stop safety gate list (must-pass criteria) before any injection activity.
5. A concise "go/no-go" decision template suitable for field operators.

Prefer sources on automotive reverse-engineering methodology and LIN protocol behavior, plus practical applied workflows.
