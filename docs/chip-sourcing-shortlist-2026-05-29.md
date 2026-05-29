# Chip Sourcing Shortlist - 2026-05-29

Status: current order-oriented shortlist after the assumption audit and authoritative datasheet check. Earlier nRF5340-first and broad shortlist versions are archived under `docs/archive/2026-05-29-pre-assumption-audit/`.

## Direct Order Decision

For the first custom active-capable dual-LIN passthrough board, order around this core:

```text
ESP32-S3-WROOM-1U-N8R8
+ 2x TJA1021T/20
```

This is the cheapest reliable path that still satisfies the actual requirement: the wheel buttons continue working while the board is connected inline, and the board can actively substitute/proxy known frames when armed.

## Why This Replaced The nRF5340-First Plan

The original recommendation favored NORA-B106 / BL5340 because Nordic has a clean BLE/security story. The assumption audit challenged that and found that ESP32-S3 is the better Rev A default:

- Much cheaper module.
- Easier and faster firmware migration from the existing ESP32 proof work.
- Enough UARTs and timing headroom for two LIN channels.
- Secure Boot V2, flash encryption, eFuse key storage, encrypted config, anti-rollback, and debug lockdown are adequate for this threat model.
- Broad distributor availability and easy module assembly.

nRF5340 remains a valid backup if the product later needs a stronger formal security story or a Nordic-specific customer requirement.

## Primary Parts

| Function | Primary part | Why |
|---|---|---|
| BLE MCU module | `ESP32-S3-WROOM-1U-N8R8` | Cheap, stocked, 3 UARTs, BLE 5, secure boot/flash encryption, external antenna flexibility |
| LIN transceiver A | `TJA1021T/20` | 3.3 V/5 V MCU logic compatible, LIN 2.1/SAE J2602 class, familiar from current TJA1021 bench rig |
| LIN transceiver B | `TJA1021T/20` | Same part on both sides simplifies firmware, validation, and failure analysis |
| Antenna | 2.4 GHz U.FL antenna compatible with Espressif module guidance | Lets RF radiator move outside metal-heavy steering-wheel area |
| Firmware framework | ESP-IDF | Required path for secure boot, flash encryption, signed OTA/profile, anti-rollback, and production provisioning |

## Backup Parts

| Function | Backup part | Use if |
|---|---|---|
| BLE MCU module | `MDBT53-P1M` nRF5340 module | ESP32-S3 path is blocked by security/customer/regulatory requirement |
| BLE MCU alternate | Ezurio `BL5340` | Raytac module stock/mechanics are worse |
| LIN transceiver | `TPIC1021D` | TJA1021 stock/lifecycle risk is unacceptable |
| ESP32 module alternate | `ESP32-S3-WROOM-1-N8R8` | Board/antenna can sit in a plastic/open area and internal PCB antenna is proven reliable |

## Do Not Use As Final Core

| Part / board | Reason |
|---|---|
| Copperhill/SK Pang ESP32S3 CAN & LIN board | One LIN transceiver only; cannot do final car-side + wheel-side passthrough |
| MikroE LIN Click / one LIN breakout | Add-on board only; one LIN; no BLE core |
| XIAO ESP32-C3 | Existing proof rig only; too constrained for final dual-LIN + secure provisioning |
| ESP32-S3 dev board by itself | Useful bring-up board, not final harness fixture |
| `MCP2003-E/SN` | Cheap but 5 V-logic-centric; not the clean direct 3.3 V ESP32 interface we want |
| `TLIN1029A-Q1` / `TLIN2029A-Q1` | Attractive but demoted until exact 3.3 V logic path is verified or level shifting is intentionally added |
| Bare nRF5340 or bare ESP32-S3 chip | Avoid bare RF chip on Rev A; use certified module first |

## What To Buy Now

Order enough to cover one PCB spin plus bench mistakes:

| Qty | Item | Purpose |
|---:|---|---|
| 5-10 | `ESP32-S3-WROOM-1U-N8R8` | Primary Rev A MCU/BLE modules |
| 5-10 | 2.4 GHz U.FL antennas/pigtails | BLE antenna placement testing |
| 20 | `TJA1021T/20` | Two per board plus spares |
| 10 | `TPIC1021D` | Backup LIN transceiver validation |
| 1-2 | ESP32-S3-DevKitC-1 or equivalent WROOM-based dev board | ESP-IDF bring-up while PCB is designed |
| 2-4 | TJA1021 breakout boards | Immediate two-LIN passthrough bench wiring before PCB |
| assorted | 12V TVS, LIN ESD, USB ESD, PTC/fuse, reverse-protection MOSFET/controller, buck regulator samples | Protection/power schematic validation |
| assorted | keyed connector samples | Fit check for car-side/wheel-side harness split |

If ordering only one thing for the final board core, order `ESP32-S3-WROOM-1U-N8R8`. If ordering the actual dual-LIN core set, order that plus two `TJA1021T/20` per board.

## First PCB Seed BOM

| Block | Seed choice |
|---|---|
| MCU/BLE | ESP32-S3-WROOM-1U-N8R8 |
| LIN A | TJA1021T/20, SO-8 |
| LIN B | TJA1021T/20, SO-8 |
| Antenna | U.FL 2.4 GHz antenna, mechanically retained |
| Power | Automotive 12V to 3.3V buck, >500 mA headroom |
| Input protection | PTC/fuse, reverse-polarity MOSFET/controller, automotive TVS |
| LIN protection | LIN ESD/TVS diode on each LIN connector |
| USB | USB-C service connector with ESD and correct CC resistors |
| Controls | Mode switch, physical arm, service/rebind strap/pad |
| Indicators | Power, BLE, passive, armed, TX, fault LEDs |
| Connectors | Keyed positive-latch car-side and wheel-side harness connectors |
| Test points | VBAT, 3V3, LIN_A, LIN_B, RXD/TXD A/B, SLP/EN A/B, ARM, FAULT, GND |

## Open Before Layout Lock

- Confirm distributor stock for `ESP32-S3-WROOM-1U-N8R8`, `TJA1021T/20`, and `TPIC1021D` on the actual order day.
- Confirm whether `TJA1021T/20` lifecycle status is acceptable for prototype and short-run production.
- Choose exact automotive buck regulator and ESD/TVS parts.
- Choose connector family after measuring enclosure/harness space.
- Confirm U.FL antenna retention and antenna location so the pigtail cannot loosen in use.