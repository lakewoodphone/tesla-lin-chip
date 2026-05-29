# Final Board Ordering Decision - 2026-05-29

Status: current direct ordering answer for the first active-capable dual-LIN passthrough PCB.

## Order This Core

```text
ESP32-S3-WROOM-1U-N8R8
+ 2x NXP TJA1021T/20
+ 2.4 GHz U.FL antenna
```

This is the current final-board core. It is not the Copperhill board and not the nRF5340 DK. Those are useful references/dev tools, but they are not the orderable final passthrough board architecture.

## Why

The real requirement is not merely active LIN injection. The wheel buttons must continue to work while the device is installed. That means the device must sit inline and proxy the bus:

```text
car side <-> LIN A <-> MCU proxy/cache <-> LIN B <-> wheel side
```

That requires two LIN transceivers. A one-transceiver board cannot cleanly separate the car and wheel sides, so it cannot be the final active-use board.

## What Changed From The Previous Assumption

Earlier docs favored nRF5340 modules such as NORA-B106 or BL5340 because Nordic has a clean security story. After the assumption audit and datasheet check, the Rev A default changed:

| Question | Current answer |
|---|---|
| Is nRF5340 required? | No. ESP32-S3 is good enough and much cheaper for this threat model. |
| Does ESP32-S3 have enough UART/timing headroom? | Yes. Three UARTs and dual 240 MHz cores are more than enough for dual 19200 baud LIN plus BLE. |
| Is ESP32-S3 security enough? | Yes for casual cloning/readout resistance if Secure Boot V2, flash encryption, eFuse lockdown, signed updates, and anti-rollback are implemented correctly in ESP-IDF. |
| Does WiFi hurt the design? | Not materially if firmware never enables WiFi and secure boot prevents unauthorized firmware. |
| Is a certified module worth it? | Yes. Use a module for Rev A to avoid RF layout/certification risk. |
| Internal antenna or U.FL? | U.FL for Rev A because the steering-wheel area may be metal-heavy; external antenna placement reduces BLE risk. |
| Which LIN transceiver? | `TJA1021T/20` because it explicitly supports 3.3 V/5 V MCU logic and matches existing bench experience. |

## Immediate Buy List

For a practical Rev A order, buy:

| Qty | Part | Purpose |
|---:|---|---|
| 5-10 | `ESP32-S3-WROOM-1U-N8R8` | Rev A central BLE MCU module |
| 5-10 | 2.4 GHz U.FL antenna/pigtail | BLE antenna placement testing |
| 20 | `TJA1021T/20` | Two LIN transceivers per board plus spares |
| 10 | `TPIC1021D` | LIN transceiver backup path |
| 1-2 | ESP32-S3-DevKitC-1 or equivalent WROOM-based dev board | ESP-IDF bring-up while PCB is designed |
| 2-4 | TJA1021 breakout boards | Immediate dual-LIN bench passthrough wiring |

If you want the single most important item: `ESP32-S3-WROOM-1U-N8R8`.

If you want the smallest complete final-core order: `ESP32-S3-WROOM-1U-N8R8` plus two `TJA1021T/20` per board.

## Backup Decision

If the ESP32-S3 path is blocked, use an nRF5340 module:

```text
Raytac MDBT53-P1M
or Ezurio BL5340
```

Do this only if security/regulatory/customer requirements justify the higher cost and firmware rewrite.

## Rejected For Final Active Use

| Option | Rejection reason |
|---|---|
| Copperhill/SK Pang ESP32S3 CAN & LIN | One LIN only; cannot be inline passthrough by itself |
| Nordic nRF5340 DK | Excellent dev kit, not the final compact board |
| u-blox EVK-NORA-B1 | Dev kit only; still needs custom board |
| XIAO ESP32-C3 | Existing proof rig; too constrained for final dual-LIN/security path |
| MCP2003-E/SN | Cheap LIN part, but not the clean direct 3.3 V logic choice for ESP32-S3 |
| TLIN1029A-Q1 / TLIN2029A-Q1 | Good automotive parts, but demoted until exact 3.3 V logic/VIO path is intentionally designed |

## Final Practical Answer

The final active-use board is a custom PCB, and its core should be ordered now as:

```text
ESP32-S3-WROOM-1U-N8R8
2x TJA1021T/20 per board
```

That is the cheapest reliable path that still fully supports BLE control, dual-LIN passthrough, firmware protection, activation/binding, and active volume behavior without breaking the steering-wheel buttons.