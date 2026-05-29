# Single-Board Rev A Product Spec - 2026-05-29

Status: current compact board product spec after the dual-LIN passthrough correction and chip assumption audit.

## Decision

Build one custom compact PCB for inline active passthrough:

```text
ESP32-S3-WROOM-1U-N8R8 BLE module
+ 2x TJA1021T/20 LIN transceivers
+ protected 12V input
+ keyed car-side and wheel-side connectors
+ USB-C service/provisioning
+ physical mode switch
+ physical arm gate
+ secure boot/flash encryption
+ signed firmware/profile updates
+ activation and binding
```

This board is the final-product direction. Dev boards and breakouts are allowed only to validate the schematic and firmware before the PCB arrives.

## Non-Negotiable Behavior

- The wheel buttons must still work when the device is connected.
- Therefore the device must be an inline two-LIN passthrough/proxy, not a one-LIN tap.
- The default state after boot, crash, reset, failed activation, or service mode is passive/safe-off.
- Active output requires hardware arm plus authenticated software authorization.
- The board must never rely on a phone app alone to decide whether it can transmit.

## Physical Topology

```text
CAR SIDE
  VBAT/GND/LIN_A
  -> protection
  -> LIN transceiver A
  -> ESP32-S3 firmware proxy/cache
  -> LIN transceiver B
  -> protection
  VBAT/GND/LIN_B
WHEEL SIDE
```

The board does not literally relay every bit in real time. It uses cached wheel-side responses and immediate car-side responder behavior because LIN response timing is too tight to wait for the wheel after the car sends a header.

## Size Target

| Revision | Target | Priority |
|---|---|---|
| Rev A | about 60 mm x 35 mm, four-layer | Debuggable, labeled, probeable, mechanically reliable |
| Rev B | about 45 mm x 25 mm | Shrink only after Rev A timing, safety, RF, and harness behavior are proven |

Rev A should favor clear test pads, SO-8 packages, and readable labels over maximum miniaturization.

## Required Blocks

| Block | Required implementation |
|---|---|
| MCU/BLE | `ESP32-S3-WROOM-1U-N8R8`, U.FL antenna |
| LIN A | `TJA1021T/20` car-side transceiver with ESD |
| LIN B | `TJA1021T/20` wheel-side transceiver with ESD |
| Power | 12V input, fuse/PTC, reverse protection, TVS, automotive buck to 3.3V |
| Programming/service | USB-C, service pads, boot/reset access, factory provisioning path |
| Controls | Physical mode switch, physical arm, service/rebind strap or pad |
| Indicators | Power, BLE, passive, armed, TX, fault |
| Security | Secure boot, flash encryption, eFuse/debug lockdown, signed updates, activation/binding |
| Connectors | Positive-latch car-side and wheel-side harness connectors |
| Mechanical | Strain relief, antenna retention, mounting holes, enclosure clearance |

## Connector Strategy

Use robust generic connectors on the board and adapter harnesses outside the board.

Recommended pin groups:

```text
CAR_SIDE:   VBAT, GND, LIN_A, spare/wake/shield
WHEEL_SIDE: VBAT, GND, LIN_B, spare/wake/shield
USB_C:      service/provisioning/logging
SERVICE:    internal strap/pads for rebind/factory recovery
```

Do not put Tesla-specific connectors directly on Rev A unless mechanical proof shows that an adapter harness is worse. Generic keyed connectors keep the electronics reusable and reduce board respin risk.

## Electrical Defaults

- TX gates default disabled by resistor state.
- LIN transceiver sleep/enable defaults safe when MCU is reset or unprogrammed.
- Physical arm removal immediately disables TX and clears queued gestures.
- Bootloader, DFU, and service modes keep LIN TX electrically disabled.
- A latched fault requires `safe:off`, power cycle, or service inspection before re-arm.

## Firmware Requirements

Rev A firmware should be ESP-IDF based for security-critical work.

Required features:

- Two UART-backed LIN channels.
- Enhanced and classic checksum support.
- 19200 baud Tesla profile, with configurable LIN profile engine.
- Wheel-side cache for `0x28..0x2D` class frames.
- Car-side responder/proxy for confirmed IDs.
- Proven left-wheel `0x2A` substitution for volume up/down/click/idle.
- Right-wheel `0x2B` disabled for injection until counter model is proven.
- BLE status/provisioning/control service.
- USB service shell and logs.
- Signed profile import/export.
- Activation and binding before any active passthrough behavior.

## Security Requirements

- ESP32-S3 Secure Boot V2 enabled for production-profile units.
- ESP32-S3 flash encryption enabled in production mode.
- Production signing keys never stored in the repo.
- Debug/JTAG and unsafe ROM download paths disabled or restricted for production units.
- Per-device identity and activation state provisioned at manufacturing time.
- Signed firmware images only.
- Signed profile/config packages only.
- Anti-rollback for both firmware and profile/config versions.
- Encrypted NVS or equivalent protected storage for binding/config/secrets.
- Engineering units must be visibly labeled and logically separated from locked production units.

## Safety Gates

Active or passthrough TX is permitted only when every gate is true:

```text
valid signed firmware
valid signed profile
anti-rollback state valid
device activated
binding present
mode switch in PASSTHROUGH_LAB or ACTIVE_MOCK_LAB
physical arm present
authenticated BLE/USB session
session timer valid
rate limiter clear
LIN health counters clean
TX gate self-check passed
```

Failure response:

```text
TX gate off
transceivers safe/passive
gesture queue clear
fault event logged
BLE/USB status updated
```

## Expected Product Modes

| Mode | TX allowed | Description |
|---|---:|---|
| `SAFE_PASSIVE` | No | Default boot and locked state |
| `PASSIVE_CAPTURE` | No | Receive-only diagnostics |
| `PASSTHROUGH_LAB` | Yes, gated | Inline cached proxy with native wheel state preserved |
| `ACTIVE_MOCK_LAB` | Yes, gated | Bench-only generated frames to simulator/APG |
| `SERVICE_DFU` | No | Signed updates and recovery |

## Rejected Product Shapes

| Shape | Reason rejected |
|---|---|
| One-transceiver board | Cannot maintain clean car-side + wheel-side passthrough |
| Copperhill/SK Pang ESP32S3 CAN & LIN board | Good reference, but only one LIN transceiver |
| XIAO ESP32-C3 + breakouts | Proven discovery rig, not robust final hardware |
| nRF5340-first Rev A | Security-clean but more expensive and larger firmware rewrite than needed |
| MCP2003 direct-to-ESP32 | Cheap, but not the clean 3.3 V logic transceiver path for Rev A |

## Rev A Acceptance Tests

- Board powers from 12V through protection without overheating.
- BLE connects reliably with external antenna in intended enclosure position.
- USB service/provisioning works.
- Both LIN channels receive valid frames at 19200 baud.
- Both LIN channels can transmit in isolated bench mode only when armed.
- Car-side proxy returns valid cached idle frames.
- Native wheel button events pass through when no injection is pending.
- Volume up/down/click substitution works only for confirmed `0x2A` profile.
- Removing physical arm disables TX within one firmware cycle and by hardware gate.
- Unsigned firmware and unsigned profiles are rejected.
- Flash/debug readout is blocked on production-profile unit.
- Unactivated/unbound board cannot transmit.