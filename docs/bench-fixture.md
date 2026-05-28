# Bench Fixture Plan

Goal: replace loose jumpers with a labeled, repeatable LIN hardware-in-the-loop fixture.

## Required Connections

| Net | Fixture label | Test pad | Notes |
|---|---|---|---|
| 12V bus | `12V_IN` | yes | Bench supply and APG bus power |
| Ground | `GND` | yes | Common APG/TJA1021/XIAO/level-shifter ground |
| LIN | `LIN_BUS` | yes | APG LIN pin 1 and TJA1021 LIN |
| Sleep | `SLP_HIGH` | yes | TJA1021 wake/sleep pin tied high for bench |
| RX | `TJA_RX_TO_XIAO_D3` | yes | Passive receive path |
| TX | `XIAO_D2_TO_TJA_TX` | yes | Active bench path only |
| TX enable | `TX_ENABLE` | yes | Physical switch/jumper, default off |

## Mechanical Requirements

- Mount XIAO, TJA1021 breakout, and level shifter so USB and test pads remain accessible.
- Use a keyed or color-coded APG/LIN/power connector.
- Add strain relief for USB and 12V supply leads.
- Add a visible `BENCH ONLY TX` label next to the TX enable switch.
- Keep a laminated wiring card or QR link to `START_HERE.md` with the fixture.

## Preflight

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\preflight-hardware-check.ps1 -Mode bench
```

Required readings before active bench proof:

- 12V present at bus input.
- SLP high.
- XIAO D2 reaches level shifter LV2.
- Level shifter HV2 reaches TJA1021 TX.
- XIAO D3 sees TJA1021 RX through the RX shifter path.
- TX enable switch/jumper state is recorded.

## Negative Tests

Record these once the fixture is built:

- TX enable off: `safe:arm` succeeds but physical TX path remains inactive.
- Missing APG: proof scripts fail clearly.
- Wrong COM port: proof scripts fail clearly.
- Disconnected TX path: `txd:low` shows D2 low but HV2/TJA TX unchanged.
- Passive field mode flashed: active proof blocks because active commands are missing.