# Final Chip Architecture

Status: planning document. Do not treat this as a released PCB design or road-use device.

This document defines the next hardware direction for a bench-only Tesla Model 3/Y steering-wheel LIN research module. The practical goal is a small custom board, not a custom silicon ASIC. The board should replace the breadboard/XIAO rig with a controlled fixture that can capture, proxy, and bench-mock steering-wheel scroll gestures while making road use difficult by design.

Research artifacts:

```text
personal-secretary-mvp/docs/research/responses/2026-05-29-tesla-lin-chip-sourcing-board-architecture.md
personal-secretary-mvp/docs/research/responses/2026-05-29-compact-all-in-one-lin-ble-board-selection.md
personal-secretary-mvp/docs/research/responses/2026-05-29-nrf5340-firmware-protection-anti-cloning-and-anti-abuse-architecture-for-compact-ac9a9b9f.md
```

## Hard Product Constraints

The final hardware target is a small, assembled, single PCB. Do not design the owner-facing board as a stack of XIAO/dev boards, LIN breakouts, click boards, flying jumpers, or soldered add-ons.

Required final-board properties:

- One assembled PCB contains MCU/BLE, two LIN transceivers, power protection, bus protection, controls, LEDs, programming/debug access, and harness connectors.
- Minimal soldering after fabrication: normal use should be plug-in harnesses, USB/SWD programming, and BLE updates.
- Robust handling: positive-latch connectors, strain relief path, protected 12V input, LIN/USB ESD, visible status, and test pads.
- Small enough to live as a compact harness fixture. Rev A can be debug-friendly; Rev B can miniaturize after validation.
- Universal across LIN scenarios through software profiles and adapter harnesses, not by putting every vehicle connector on the board.
- Firmware and configuration must be protected against casual readout/cloning; production boards must not ship with open SWD/debug access.
- Activation must require authenticated BLE/USB plus a device-specific proof/code and a binding record before any active or passthrough transmit mode.
- Bench-only by design. No active road-use workflow.

No researched off-the-shelf board satisfies all of these constraints. The closest commercial board found was the Copperhill/SK Pang ESP32S3 CAN & LIN board, but it has only one LIN channel and is a generic gateway board, so it cannot be the final passthrough fixture.

## Platform Decision

Primary Rev A direction: design a custom assembled single PCB around a certified Nordic nRF5340 module. Default module target is u-blox NORA-B106-00B, the NORA-B1 variant with an internal PCB antenna, unless live sourcing or RF layout constraints favor Ezurio BL5340 or another nRF5340 module.

Why:

- BLE is the main control/update channel, and Nordic has the strongest BLE-first tooling and secure DFU path.
- nRF5340 has an application core plus network core, which keeps BLE radio work away from the timing-sensitive LIN proxy loop.
- NORA-B1 exposes enough UART/GPIO for two LIN channels, debug, LEDs, arm inputs, and future fixture sensors; u-blox lists UART x5, USB, SPI, ADC, FOTA, secure-boot-ready status, and global certification.
- No WiFi radio is present, which reduces unnecessary attack surface for a bench-only tool.

Development kits are allowed only as pre-PCB firmware bring-up tools. They are not the owner-facing product form.

Acceptable fallback: ESP32-S3 module if staying close to the existing ESP32/NimBLE code is more important than BLE-first security. Do not choose ESP32-C3 for the final dual-LIN board unless the goal is only a transitional prototype; two UARTs plus USB/debug plus BLE leaves too little margin.

Alternate evaluation path: STM32WB55 if hardware USART LIN mode becomes more important than Nordic DFU/tooling.

If the project later truly needs non-LIN vehicles too, add a CAN-FD monitor/transceiver footprint as an optional populated feature. Do not let optional CAN bloat Rev A before the dual-LIN fixture is proven.

## Firmware IP Protection And Anti-Cloning

Security is a product requirement, not a post-build option. The target is not perfect resistance to a semiconductor lab; the target is to make normal copying, SWD readout, update-package reuse, and casual rebinding fail.

Required production protections:

- Enable nRF5340 APPROTECT / SECUREAPPROTECT before any board leaves provisioning so SWD cannot read internal flash/RAM.
- Enable ERASEPROTECT so an attacker cannot simply mass-erase and repurpose the board without the authorized service flow.
- Use MCUboot plus Nordic secure boot chain where practical; production boot must accept only signed firmware images.
- Use production signing keys only. Sample/demo keys must never appear in a production bootloader.
- Sign profile/config packages separately from firmware, and enforce anti-rollback on both firmware and profiles.
- Generate per-device secrets during provisioning and store them in KMU / secure storage or the strongest protected storage path available on the selected module.
- Use TrustZone / TF-M for protected key and security services as the firmware matures.
- Route SWD only to manufacturing Tag-Connect/test pads; do not expose a friendly external debug header.
- Treat debug-enabled boards as separately labeled engineering-only units that cannot be confused with production fixtures.

Encryption by itself is not enough. If keys are stored in readable flash, encryption only moves the secret. Mandatory controls are signed boot, readout protection, protected per-device keys, and a provisioning process that verifies the locks were actually enabled.

Known residual limits:

- A well-funded invasive lab may still attack silicon with glitching, probing, or side channels.
- A leaked firmware signing key would undermine secure boot until key rotation and device policy updates are handled.
- The board can protect this product's firmware and activation path; it cannot prevent someone from independently writing their own LIN research firmware from public protocol knowledge.

Detailed security spec: `docs/secure-provisioning-anti-cloning-2026-05-29.md`.

## Physical Board Target

Rev A target: approximately 60 mm x 35 mm, four-layer PCB, assembled by a PCB house, with larger packages and generous test pads for validation.

Rev B target: approximately 45 mm x 25 mm after the circuit, connectors, firmware, and safety gates are proven. Rev B can move from SO8/SOIC packages to HVSON/VSON and smaller connector families.

Recommended Rev A connector strategy:

| Connector | Purpose | Recommendation |
|---|---|---|
| Car-side harness | 12V/GND/LIN_A plus optional spare | Keyed positive-latch Micro-Fit/Nano-Fit class connector |
| Wheel-side harness | 12V/GND/LIN_B plus optional spare | Same family/keying, opposite gender or clearly keyed |
| USB-C | service, logs, initial provisioning, emergency recovery | On-board USB-C with ESD protection |
| SWD | factory programming and unbrick recovery | Tag-Connect or small keyed SWD footprint |
| Service/arm | physical mode and active gating | Board switch/key/jumper with clear silk labels |

Use vehicle-specific adapter harnesses outside the PCB. Do not hard-code Tesla or any other OEM connector into the base electronics.

## Product Modes

| Mode | TX compiled | TX electrically possible | Intended use |
|---|---:|---:|---|
| `SAFE_PASSIVE` | Optional | No | Default boot state, capture-only, no bus drive |
| `PASSIVE_CAPTURE` | No | No | Vehicle-adjacent stationary capture and bench capture |
| `PASSTHROUGH_LAB` | Yes | Yes, gated | Two-transceiver bench proxy with cached wheel responses |
| `ACTIVE_MOCK_LAB` | Yes | Yes, gated | Isolated bench gesture generation against simulator/APG/fixture |
| `SERVICE_DFU` | No active output | No | BLE/USB firmware update and recovery |

No mode is intended for use while driving. The board should physically and visually communicate that it is a bench fixture.

## Gesture Scope

| Gesture family | Left wheel `0x2A` | Right wheel `0x2B` |
|---|---|---|
| Scroll up | Enabled after bench proof | Disabled until counter model is extracted |
| Scroll down | Enabled after bench proof | Disabled until counter model is extracted |
| Push/click | Enabled after bench proof | Disabled until counter model is extracted |
| Double push | Implemented as two click primitives with idle gap after bench proof | Disabled until right-wheel click/counter model is extracted |
| Idle | Enabled | Passive/cache only until right model is safe |

The left wheel map is confirmed from the 2026-05-28 capture. Right-wheel byte[0] action values are visible, but the rolling bytes are not yet safe for injection. The firmware must expose right-wheel actions as unavailable until a specific right-wheel extractor, bench proof, and doc update complete.

## Hardware Block Diagram

```text
12V bench / vehicle-adjacent input
  -> fuse or resettable PTC
  -> reverse-polarity protection
  -> input TVS
  -> buck regulator to 5V or 3V3
  -> quiet 3V3 rail for MCU/radio

MCU / BLE module
  -> UART/LIN channel A: car-side transceiver
  -> UART/LIN channel B: wheel-side transceiver
  -> physical mode switch input
  -> physical arm input
  -> transceiver sleep/enable controls
  -> TX gate controls
  -> LEDs: power, passive, armed, TX, fault, BLE
  -> SWD/JTAG/debug pads
  -> USB service/debug connector

Car-side LIN connector
  -> LIN ESD/TVS
  -> automotive LIN transceiver A
  -> optional commander pull-up disabled by default
  -> test pads: LIN_A, RXD_A, TXD_A, SLP_A, GND

Wheel-side LIN connector
  -> LIN ESD/TVS
  -> automotive LIN transceiver B
  -> optional commander pull-up for bench polling, controlled/jumpered
  -> test pads: LIN_B, RXD_B, TXD_B, SLP_B, GND

Safety path
  -> physical arm switch/jumper/key
  -> hardware TX gate default-off
  -> transceiver SLP/EN default-safe pull resistors
  -> watchdog/fault line that forces safe-off
```

## LIN Transceiver Choice

Rev A should use two identical automotive LIN transceivers with sleep/enable pins and dominant-timeout behavior.

Preferred footprints:

- SO8 for hand/debug-friendly Rev A.
- Optional HVSON/VSON second footprint only if assembly availability requires it.

Shortlist:

| Part family | Use | Notes |
|---|---|---|
| NXP TJA1021 | Primary candidate | LIN 2.x/SAE J2602, up to 20 kBd, 3.3V/5V logic compatible, passive unpowered behavior, TXD dominant timeout, SO8/HVSON8 |
| TI TLIN1029A-Q1 | Primary alternate | Automotive LIN, 4-36V supply, -45V to +45V bus fault, 20 kbps, dominant timeout, SOIC/VSON |
| TI TLIN4029A-Q1 | Rugged alternate | Higher bus-fault margin; use if cost/availability is acceptable |
| Microchip MCP2003/MCP2004 | Sourcing alternate | LIN 2.x/J2602 class transceiver; common fallback if NXP/TI supply is easier |
| MCP2025/TLIN1441 regulator variants | Not primary | Integrated regulators are useful for simple LIN nodes, but not enough as the main rail for BLE MCU peaks |

## Power And Protection

Minimum Rev A protection stack:

- 12V input through fuse or resettable PTC.
- Reverse-polarity MOSFET or automotive ideal-diode style controller.
- Input TVS near the connector.
- Buck regulator sized for at least 500 mA, preferably more for debug margin.
- Optional LDO from 5V to 3V3 if the buck is noisy.
- LIN ESD protection near each LIN connector.
- USB ESD protection near USB connector.
- Star/test ground points so APG, bench supply, PC, and fixture grounds can be checked before connection.
- Clearly labeled test pads for 12V, 5V, 3V3, LIN_A, LIN_B, RXD/TXD lines, SLP/EN lines, ARM, and FAULT.

USB isolation is not mandatory for Rev A, but an isolated USB-to-UART/SWD path or external USB isolator is strongly recommended for vehicle-adjacent lab work.

## Physical Safety Interlocks

The hardware must make active output impossible by default. Firmware checks are not enough.

Required:

- Active TX gate defaults open/disabled with pull resistors if the MCU is reset, blank, crashed, or in bootloader.
- Each LIN transceiver has MCU-controlled sleep/enable plus passive-safe resistor defaults.
- Physical arm switch/jumper/key must be present before any active or passthrough response is emitted.
- Removing physical arm immediately disables TX and clears the gesture queue.
- Visible armed indicator LED independent from the BLE phone app.
- Fault LED latches until `safe:off` or power cycle after inspection.
- Optional case-open/service strap required for binding reset or unsafe engineering modes.
- Fast physical bypass/remove path: the harness must be easy to unplug or bypass without software.

Recommended Rev A switch layout:

```text
MODE switch: PASSIVE / PASSTHROUGH_LAB / ACTIVE_MOCK_LAB
ARM control: momentary or keyed hold-to-arm input
SERVICE strap: internal jumper for factory reset / rebind / debug unlock
```

## BLE Provisioning And Control

BLE must be used for configuration, status, logs, and firmware updates. It must not be a casual unauthenticated remote control.

Required BLE model:

- LE Secure Connections pairing.
- Bonded admin device required for privileged writes.
- Factory proof-of-possession code printed on the board label, QR label, or exposed only over USB during first provisioning.
- Device identity challenge/response using a per-device secret or key before activation/rebind.
- Signed activation package tied to board serial/module identity.
- Active commands require both bonded BLE/USB authorization and physical arm.
- Disconnect during active session should disarm unless explicitly in a supervised USB bench mode.
- Failed activation attempts must be rate-limited and logged.

Suggested GATT services:

| Service | Purpose |
|---|---|
| Device info | Serial, board rev, firmware hash, build profile, boot reason |
| Status | Mode, armed state, BLE peer, faults, TX count, inhibited count, cache state |
| Config | Model profile, enabled gesture families, session timeout, rate limits |
| Binding | Test fixture ID or VIN label, binding hash, bind/rebind state |
| Control | `safe:arm`, `safe:off`, gesture queue, passthrough enable |
| Logs | Recent boot/config/arm/fault/TX events |
| DFU | Signed firmware update path |

Activation sequence:

1. Board boots inactive/passive.
2. Operator enters or scans proof-of-possession code.
3. BLE/USB session authenticates the admin tool.
4. Board proves its identity with challenge/response.
5. Tool installs a signed activation package.
6. Operator enters fixture ID and optional VIN label.
7. Active modes remain locked until mode switch, physical arm, session timer, rate limit, binding, and LIN health gates are all true.

## VIN / Fixture Binding

Binding is a safety feature, not a vehicle-security bypass.

Rules:

- Do not read or infer VIN from vehicle networks for this feature.
- User provisions a VIN label or fixture ID over authenticated BLE/USB.
- Store a hash plus display label in protected settings.
- Active modes require a non-empty binding and an operator confirmation that the bench fixture matches it.
- Rebind requires bonded admin credentials, physical service strap or case-open action, and a signed rebind token.
- Factory reset clears binding and returns to passive-only provisioning mode.

For the first implementation, store binding in normal protected settings and include it in every log. On nRF5340/NORA-B1, move toward secure storage / TF-M-backed storage as the firmware matures.

Binding must not scrape or infer VIN from vehicle networks. It is an intentional operator-provisioned safety label and audit record.

## Firmware Architecture

The current ESP32/XIAO firmware should remain the protocol proving ground. The final-chip firmware should be a cleaner split:

```text
lin_phy/
  uart_break_detect
  checksum_pid
  transceiver_control

lin_proxy/
  car_side_header_listener
  wheel_side_poller
  cache_by_id
  immediate_response_engine

gestures/
  model3_left_0x2a
  model3_right_0x2b_pending
  click_sequence_engine
  queue_limits

safety/
  physical_arm
  mode_switch
  session_timer
  rate_limit
  bus_fault_lockout
  binding_gate
  activation_gate
  signed_profile_gate
  watchdog_safe_off

ble/
  provisioning
  proof_of_possession
  status_notify
  config_write
  control_write
  secure_dfu

security/
  secure_boot_policy
  signed_config_verify
  per_device_identity
  anti_rollback
  debug_lock_state

logging/
  ring_buffer
  persisted_events
  export_over_ble_usb
```

LIN response timing must not depend on BLE callbacks. BLE can enqueue commands and update settings, but the LIN proxy loop must run at higher priority and use prevalidated gesture/cached-frame data.

## Rev A Development Plan

1. Pre-PCB firmware bring-up: use nRF5340 DK or NORA-B1 EVK only to prove the BLE/DFU/toolchain path and dual-UART LIN timing. Temporary breakouts are allowed here only.
2. Rev A schematic: one PCB with nRF5340 module, two LIN transceivers, protected 12V input, USB-C, SWD, physical controls, LEDs, and harness connectors.
3. Rev A assembled PCB: order mostly assembled; hand-solder only through-hole/keyed connectors if the assembler cannot place them.
4. Dual-LIN bench proxy: simulate car-side master with APG or a second XIAO, use wheel-side simulator/fixture, verify immediate cached responses at 19200.
5. Gesture queue: enable left-wheel `0x2A` up/down/click/double-click on bench only. Keep right-wheel disabled.
6. Security provisioning: implement signed boot/DFU, signed profile packages, debug/readout lock plan, per-device identity, activation package, and anti-rollback.
7. BLE provisioning: implement bonded admin, proof-of-possession, status, config, control, event logs, binding/rebinding, and signed DFU path.
8. Rev A safety validation: prove every reset/fault/unarmed/bootloader/DFU/unactivated/unbound path leaves TX electrically disabled.
9. Right-wheel work: extract counter model from dedicated capture, add a disabled-by-default implementation, then bench proof before enabling.

## Rev A Exit Gate

- Passive capture decodes known APG/XIAO frames at 19200 on both LIN channels.
- Transceiver TX is electrically disabled on reset, brownout, firmware crash simulation, bootloader mode, unarmed mode, and BLE disconnect.
- Production debug/readout lock is enabled and verified; SWD cannot read flash after provisioning.
- Unsigned firmware, unsigned profile packages, and older rollback versions are rejected.
- Board without activation cannot enable active or passthrough transmit.
- Removing physical arm stops TX within one control-loop pass and clears pending gestures.
- BLE active command fails before physical arm and software authorization.
- Signed DFU works, unsigned DFU is rejected, and DFU never leaves active output enabled.
- Fixture binding is required for active modes and is included in logs.
- `PASSTHROUGH_LAB` responds from cache with valid checksums and records misses/faults.
- Left-wheel `0x2A` up/down/click/double-click bench proof passes with APG/raw observer.
- Right-wheel injection remains disabled until its counter model has its own proof artifact.
- Test report includes serial number, board rev, firmware hash, current draw, rail voltages, LIN idle voltages, RX proof, TX proof, BLE proof, DFU proof, fault proof, and final `safe:off` proof.