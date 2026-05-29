# Single-Board Rev A Product Spec - 2026-05-29

Status: product-direction spec for the compact all-in-one board. This is not yet a schematic.

## Decision

Build a custom compact single PCB. Do not use an off-the-shelf board as the final product.

Best practical board architecture:

```text
u-blox NORA-B106-00B nRF5340 BLE module
+ 2x automotive LIN transceivers
+ protected 12V power front end
+ keyed car-side and wheel-side connectors
+ USB-C service/programming
+ SWD factory/recovery pads
+ physical mode switch
+ physical arm gate
+ secure boot/readout protection
+ per-device activation/binding
+ LEDs and test pads
+ enclosure and adapter harnesses
```

Ezurio BL5340 integrated-antenna module is the main alternate if NORA-B106 stock, placement, or pricing is worse at layout time.

## Non-Negotiable Constraints

- One assembled PCB, not several boards wired together.
- Mostly plug-in operation after assembly: no routine soldering by the owner.
- Two independent LIN channels on-board.
- BLE on-board with authenticated control and signed update path.
- Firmware cannot be read out by simply plugging into USB/SWD after provisioning.
- Production firmware and profile/config packages must be signed and anti-rollback protected.
- Board must require per-device activation and binding before active/passthrough transmit modes.
- Protected 12V input and protected LIN lines.
- Hardware TX gate defaults off without firmware cooperation.
- Physical arm is required for any active/passthrough transmit behavior.
- Vehicle/OEM differences are handled by adapter harnesses and software profiles.
- Bench-only; no road-use workflow.

## Board Size Target

| Revision | Target | Purpose |
|---|---|---|
| Rev A | about 60 mm x 35 mm, four-layer | Debuggable, robust, enough room for labels/test pads/connectors |
| Rev B | about 45 mm x 25 mm | Miniaturized after Rev A proves timing, safety, and connector strategy |

Rev A should favor reliability and observability over maximum miniaturization. Tiny is not useful if it breaks or cannot be probed.

## Required Blocks

| Block | Required implementation |
|---|---|
| MCU/BLE | NORA-B106-00B nRF5340 module or BL5340 alternate |
| LIN A | Car-side TJA1021/TLIN1029-class transceiver with ESD |
| LIN B | Wheel-side TJA1021/TLIN1029-class transceiver with ESD |
| Power | 12V input, fuse/PTC, reverse protection, TVS, buck, local decoupling |
| Programming | USB-C and SWD/Tag-Connect footprint |
| Storage | Internal flash first; protected key storage/KMU path for secrets; optional QSPI flash footprint for logs/DFU staging |
| Controls | Mode switch, arm control, service/rebind strap or pad |
| Indicators | Power, BLE, passive, armed, TX, fault |
| Connectors | Positive-latch car-side and wheel-side harness connectors |
| Mechanical | Strain relief path, enclosure holes, clear labels, no fragile antenna cable by default |

## Security And Clone Resistance

Required Rev A security controls:

- nRF5340 APPROTECT / SECUREAPPROTECT enabled before shipment.
- ERASEPROTECT enabled so external mass erase/reprogramming is not casual.
- MCUboot / secure boot chain accepts only production-signed firmware.
- Signed profile/config packages with anti-rollback.
- Per-device identity and secret generated during provisioning.
- Activation package tied to board serial/module identity.
- BLE admin provisioning requires LE Secure Connections, proof-of-possession, and bonding.
- SWD routed only to manufacturing/service pads, not an external user header.
- DFU/recovery mode keeps LIN TX electrically disabled.
- Development/debug boards must be physically and logically separate from production boards.

Security spec: `docs/secure-provisioning-anti-cloning-2026-05-29.md`.

## Connector Strategy

Use robust generic board connectors, then make vehicle-specific adapter harnesses.

Recommended Rev A connectors:

```text
CAR_SIDE:   VBAT, GND, LIN_A, spare/wake/shield
WHEEL_SIDE: VBAT, GND, LIN_B, spare/wake/shield
USB_C:      service/programming/logging
SWD:        factory/recovery programming
```

Use Molex Micro-Fit/Nano-Fit class positive-latch connectors unless mechanical CAD proves they are too large. JST-GH or Molex Micro-Lock class parts are acceptable only if the latch and strain relief are good enough.

Do not put Tesla-specific connectors directly on the base board. Make Tesla, bench, and future vehicle harnesses as replaceable adapters.

## Universal Behavior Target

The electronics should be universal for LIN steering/control research, not hard-coded to one car.

Required firmware capabilities:

- LIN baud profiles from 1 kBd to 20 kBd, with 19200 default for current Tesla work.
- Enhanced and classic checksum support.
- Commander/header generation mode for bench polling.
- Responder/slave emulation mode for car-side proxy response.
- Passive capture mode on either or both LIN channels.
- Passthrough/proxy mode with cached responses.
- Gesture/mock mode only for proven frame profiles.
- Profile engine for per-vehicle IDs, lengths, counters, and allowed actions.
- BLE and USB configuration export/import.

Physical universality still requires harness adapters. No small board can include every OEM connector.

## Safety Gates

Active behavior is permitted only if all gates are true:

```text
signed firmware valid
signed profile valid
anti-rollback state valid
device activated
binding present
mode switch in lab passthrough or active mock
physical arm present
authenticated BLE/USB session or supervised script
session timer not expired
rate limiter clear
LIN error counters below threshold
TX gate healthy
```

Any failed gate forces:

```text
TX gate off
transceivers safe/passive where possible
gesture queue cleared
fault/log event recorded
BLE status updated
```

## Why Not Existing Boards

| Option | Why it loses |
|---|---|
| Copperhill/SK Pang ESP32S3 CAN & LIN | Only one LIN channel; would need another board for true passthrough |
| MikroE LIN Click | One LIN only, no BLE, add-on board |
| XIAO ESP32-C3 rig | Proven but fragile, too few clean channels, breakout wiring |
| STM32WB boards | Good BLE MCU, no integrated dual LIN fixture |
| Microchip WBZ Curiosity | BLE MCU eval board, no onboard LIN transceivers |

Closest reference board is the Copperhill/SK Pang ESP32S3 CAN & LIN board. It is useful for ideas, not final hardware.

## First PCB Must Include

- NORA-B106 or BL5340 integrated-antenna module.
- Two SO8/SOIC LIN transceivers for Rev A debugability.
- LIN ESD parts near connectors.
- 12V input protection and buck regulator.
- TXD hardware gates or equivalent transceiver enable gating, default-off.
- USB-C with ESD.
- SWD/Tag-Connect pads.
- Security provisioning support: debug lock verification, signed boot/DFU, per-device identity, activation code/QR label.
- Mode switch, arm switch/jumper/key, service/rebind pad.
- LEDs and labeled test pads.
- Mounting holes and enclosure clearance.

## Open Mechanical Questions

- Final connector family after measuring available steering/bench space.
- Whether Rev A uses Micro-Fit/Nano-Fit or smaller JST-GH/Micro-Lock style connectors.
- Exact enclosure size and whether antenna keepout is clear enough for an internal PCB antenna module.
- Whether optional CAN-FD passive monitor footprint is worth the board area in Rev A or should wait for Rev B.

## Next Engineering Step

Create a schematic-level Rev A design brief with:

1. exact module MPN preference and backup,
2. exact LIN transceiver MPN preference and backup,
3. connector pinout,
4. power/protection reference circuit,
5. TX gate circuit,
6. test pad map,
7. enclosure/board outline assumptions,
8. firmware bring-up checklist.
