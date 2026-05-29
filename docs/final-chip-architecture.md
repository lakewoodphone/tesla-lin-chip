# Final Active Passthrough Board Architecture

Status: current Rev A hardware direction after the 2026-05-29 assumption audit. This is not a released PCB layout or road-use device.

The final active-capable product is a custom single PCB that sits inline between the Tesla car-side LIN harness and the steering-wheel side LIN harness. It is not a one-transceiver tap board, not a Copperhill/SK Pang gateway board, and not a stack of dev boards.

Pre-audit docs were archived under:

```text
docs/archive/2026-05-29-pre-assumption-audit/
```

Research artifacts behind this decision:

```text
personal-secretary-mvp/docs/research/responses/2026-05-29-tesla-lin-chip-sourcing-board-architecture.md
personal-secretary-mvp/docs/research/responses/2026-05-29-compact-all-in-one-lin-ble-board-selection.md
personal-secretary-mvp/docs/research/responses/2026-05-29-nrf5340-firmware-protection-anti-cloning-and-anti-abuse-architecture-for-compact-ac9a9b9f.md
personal-secretary-mvp/docs/research/responses/2026-05-29-cheapest-reliable-dual-lin-ble-passthrough-chip-module-f7be4c0f.md
personal-secretary-mvp/docs/research/responses/2026-05-29-authoritative-datasheet-check-dual-lin-ble-rev-a-bom-9abd3f3b.md
```

## Bottom Line

Build Rev A around:

```text
ESP32-S3-WROOM-1U-N8R8 module
+ 2x NXP TJA1021T/20 LIN transceivers
+ protected 12V input
+ USB-C service/provisioning
+ factory/service pads
+ keyed car-side and wheel-side harness connectors
+ physical mode switch
+ physical arm gate
+ default-off LIN TX gating
+ secure boot, flash encryption, signed updates, activation, and binding
```

Primary central module: `ESP32-S3-WROOM-1U-N8R8`.

Primary LIN transceiver: `TJA1021T/20`, used twice.

Backup central module: `MDBT53-P1M` or another nRF5340 module if a higher-security Nordic path becomes necessary.

Backup LIN transceiver: `TPIC1021D` if TJA1021 stock or lifecycle status becomes a problem.

## Why Passthrough Is Mandatory

The steering-wheel buttons must continue to work while the board is connected. That requirement changes the hardware completely.

A one-transceiver board can tap the existing bus and can sometimes inject frames on an isolated bench. It cannot sit cleanly between the car and the wheel while preserving native button behavior, because it cannot separate these two electrical sides:

```text
car-side LIN harness  <->  steering-wheel LIN module
```

The final board must split the connection and proxy it:

```text
car-side LIN harness
  <-> LIN transceiver A
  <-> MCU firmware/cache/proxy
  <-> LIN transceiver B
  <-> steering-wheel LIN module
```

This is why the final board needs two LIN transceivers. One transceiver sees and responds to the car-side LIN master. The other transceiver polls or listens to the steering-wheel side and maintains the current wheel state/cache. When the car asks for ID `0x2A`, the firmware can immediately return either the real cached wheel response or a controlled substituted volume frame.

LIN timing does not leave room to wait for the wheel side after the car-side header arrives. This is not a bit-for-bit wire bridge; it is a cached protocol proxy with two physical LIN domains.

## Hard Product Constraints

- One assembled PCB, not several boards wired together.
- Two independent LIN channels on the board.
- BLE on board for provisioning, control, status, and signed updates.
- Mostly plug-in operation after assembly: keyed harness connectors, USB/provisioning, no routine hand soldering.
- Protected 12V input and protected LIN/USB lines.
- Direct 3.3 V MCU-to-LIN-transceiver logic where possible; no routine level shifters.
- Hardware TX gate defaults off when the MCU is blank, crashed, reset, or in bootloader.
- Physical arm is required for any active or passthrough response.
- Firmware cannot be casually read out by plugging into USB/debug after provisioning.
- Active/passthrough modes require signed firmware, signed profile/config, activation, binding, authenticated BLE/USB, physical mode, physical arm, session timer, rate limits, and healthy LIN state.
- Vehicle differences are handled by software profiles and adapter harnesses, not by putting every OEM connector on the PCB.
- Bench/lab fixture first. No road-use workflow.

## Central MCU/BLE Decision

### Primary: ESP32-S3-WROOM-1U-N8R8

The assumption audit changed the default away from nRF5340. Nordic is cleaner on security, but the ESP32-S3 path is cheaper, available, easier to assemble, and much closer to the existing ESP32 firmware work.

Reasons to use the ESP32-S3 module for Rev A:

- It has three hardware UART controllers, enough for LIN A, LIN B, and service/debug.
- LIN is low bandwidth: 19200 baud on two sides is trivial for dual 240 MHz cores.
- BLE 5 support is built in.
- Secure boot, flash encryption, eFuse key storage, encrypted NVS, anti-rollback, and debug/bootloader lock-down are supported through ESP-IDF.
- Existing code and bench experience are already ESP32-family based.
- ESP32-S3 modules are broadly stocked and inexpensive compared with nRF5340 modules.
- A module avoids first-spin RF layout risk.

Use the `1U` external antenna variant for Rev A because the board may live near metal steering-wheel structure. The U.FL antenna lets the RF radiator move into a plastic or less-shielded area without respinning the board. If mechanical testing proves the board is outside the shielded cavity, `ESP32-S3-WROOM-1-N8R8` with PCB antenna becomes an acceptable simplification.

### Backup: nRF5340 Module

Keep an nRF5340 module path as a backup, not the primary Rev A path.

Use cases where nRF5340 may become primary later:

- A customer or partner requires Nordic's cleaner secure boot/readback/TrustZone story.
- BLE power behavior matters more than BOM cost.
- The product moves toward a higher-margin, higher-assurance security variant.

Recommended backup module family: Raytac `MDBT53-P1M` or Ezurio `BL5340` integrated-antenna/U.FL variant depending on stock and mechanical needs.

## LIN Transceiver Decision

### Primary: 2x NXP TJA1021T/20

Use two identical `TJA1021T/20` SO-8 transceivers for Rev A.

Why:

- LIN 2.1 / SAE J2602 class transceiver.
- Supports the 19200 baud Tesla steering-wheel bus.
- Automotive 12V LIN physical layer.
- Datasheet/product information explicitly states 3.3 V and 5 V MCU input-level compatibility.
- Existing bench rig already uses a TJA1021 breakout, so behavior is familiar.
- SO-8 is easy to inspect, probe, and assemble for Rev A.

The TJA1021 has some lifecycle/NRND signals on certain variants, so check distributor stock before layout lock. For Rev A prototype quantities this is acceptable; for Rev B production, either confirm supply or migrate to the backup footprint.

### Backup: TPIC1021D

Use `TPIC1021D` as the backup LIN transceiver because it also clearly supports 3.3 V / 5 V MCU logic compatibility.

### Demoted Parts

`MCP2003-E/SN` is cheap and valid as a LIN transceiver, but it is 5 V-logic-centric and does not cleanly meet the direct 3.3 V MCU interface requirement. It would likely require a level shifter or out-of-spec threshold assumptions. Do not use it as the Rev A primary.

`TLIN1029A-Q1` and `TLIN2029A-Q1` are attractive modern automotive LIN transceivers, but the authoritative check did not give the same clear direct 3.3 V logic guarantee as TJA1021/TPIC1021. They remain candidates only if the schematic intentionally includes level shifting or a verified VIO-compatible variant.

## Board Block Diagram

```text
12V input
  -> fuse/PTC
  -> reverse-polarity protection
  -> input TVS
  -> automotive buck regulator to 3V3, sized for ESP32-S3 peaks
  -> local decoupling and optional quiet sub-rails

ESP32-S3-WROOM-1U-N8R8
  -> UART0/service/debug/USB path
  -> UART1 -> LIN transceiver A TXD/RXD/SLEEP/EN -> car-side LIN
  -> UART2 -> LIN transceiver B TXD/RXD/SLEEP/EN -> wheel-side LIN
  -> physical mode switch
  -> physical arm input
  -> TX gate controls default-off
  -> LEDs: power, BLE, passive, armed, TX, fault
  -> provisioning/test pads
  -> U.FL external antenna

Car-side connector
  -> VBAT, GND, LIN_A, optional spare/wake/shield
  -> LIN ESD near connector

Wheel-side connector
  -> VBAT, GND, LIN_B, optional spare/wake/shield
  -> LIN ESD near connector
```

## Connector Strategy

Use generic keyed locking board connectors and vehicle-specific adapter harnesses.

Recommended Rev A pinout:

```text
CAR_SIDE:   VBAT, GND, LIN_A, spare/wake/shield
WHEEL_SIDE: VBAT, GND, LIN_B, spare/wake/shield
USB_C:      service/provisioning/logging
SERVICE:    internal pads or jumper for factory/rebind/recovery
```

Do not put Tesla-specific connectors directly on the base board. The base board should be reusable for bench, Tesla 3/Y, and future LIN fixtures through adapter harnesses.

## Power And Protection

Minimum Rev A protection stack:

- Resettable PTC or fuse on 12V input.
- Reverse-polarity MOSFET or automotive ideal-diode style protection.
- Automotive TVS on 12V input near connector.
- Buck regulator from 12V to 3.3V sized for ESP32-S3 peak current, not a LIN transceiver's tiny integrated regulator.
- LIN ESD/TVS on both LIN lines near connectors.
- USB ESD on USB D+/D-.
- Default-off pull resistors for transceiver sleep/enable and TX gate signals.
- Test pads for VBAT, 3V3, LIN_A, LIN_B, RXD/TXD lines, SLP/EN, ARM, FAULT, and GND.

## Firmware Architecture

Rev A firmware should move from Arduino-style proof work toward ESP-IDF for production security.

Required firmware layers:

- LIN A car-side responder/proxy.
- LIN B wheel-side poll/listen/cache engine.
- Model profile engine for IDs, lengths, checksum type, counters, and allowed actions.
- Safe default passive state after every boot.
- BLE provisioning/control/status services.
- USB service shell and logs.
- Secure boot and flash encryption production profile.
- Signed firmware and signed profile/config packages.
- Anti-rollback for firmware and profiles.
- Per-device activation/binding record.
- Rate limits, session timeout, fault latching, and health counters.

Current confirmed Model 3/Y left-wheel profile:

```text
ID 0x2A, PID 0x6A, 7 data bytes, enhanced checksum
Payload: [control, 0x80, 0x3F, 0x96, 0x00, counter_a, counter_b]
control: 0x0C idle, 0x0D volume up, 0x0B volume down, 0x2C click
```

Right-wheel ID `0x2B` remains capture-confirmed but not injection-ready until its counter model is extracted and validated.

## Security Architecture

Production Rev A must use ESP32-S3 security features deliberately:

- Secure Boot V2 enabled with production signing keys.
- Flash encryption enabled in production mode.
- JTAG/debug and unsafe bootloader paths disabled or restricted by eFuse policy.
- Per-device key/identity material generated during provisioning.
- Encrypted NVS or protected storage for activation/binding/config state.
- Signed firmware updates only.
- Signed profile/config packages only.
- Anti-rollback versioning for firmware and profiles.
- Production keys kept outside the repo.
- Debug-enabled engineering boards physically labeled and never treated as production units.

This does not stop an invasive silicon lab. It should stop casual USB/UART/SWD/flash readout, firmware copying, unsigned update loading, and casual rebinding.

## Product Modes

| Mode | TX possible | Intended use |
|---|---:|---|
| `SAFE_PASSIVE` | No | Default boot state, capture/status only |
| `PASSIVE_CAPTURE` | No | Bench and vehicle-adjacent receive-only diagnostics |
| `PASSTHROUGH_LAB` | Yes, gated | Dual-LIN cached proxy bench validation |
| `ACTIVE_MOCK_LAB` | Yes, gated | Isolated bench gesture generation or simulator work |
| `SERVICE_DFU` | No | Signed update/recovery with LIN TX disabled |

## Safety Gates

Active behavior is allowed only when all gates are true:

```text
signed firmware valid
signed profile valid
anti-rollback state valid
device activated
binding present
mode switch in passthrough lab or active mock
physical arm present
authenticated BLE/USB session
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
BLE/USB status updated
```

## Rev A Development Path

1. Order ESP32-S3-WROOM-1U-N8R8 modules, U.FL antennas, TJA1021T/20 transceivers, and backup TPIC1021D transceivers.
2. Build a two-LIN ESP32-S3 bench fixture with two transceiver breakouts to validate UART timing and cached proxy logic before PCB assembly.
3. Create Rev A schematic with the exact ESP32-S3 module, two TJA1021 channels, protected 12V input, USB-C, mode/arm controls, LEDs, and test pads.
4. Validate security/provisioning on ESP-IDF: secure boot, flash encryption, signed update, signed profile, activation, binding, and debug lockdown.
5. Layout a four-layer debug-friendly board around 60 mm x 35 mm.
6. Assemble a small Rev A batch.
7. Run bring-up: rails, USB, BLE, flash/security, LIN A, LIN B, TX gate, arm/mode, fault paths.
8. Run bench-only passthrough validation with simulated car master and real/simulated wheel side.
9. Do not attempt vehicle-side active validation until steering-wheel controls are restored and bench passthrough is proven.

## Rev A Exit Gate

Rev A is accepted only when:

- Both LIN channels pass receive/transmit bench validation at 19200 baud.
- Car-side proxy returns valid cached `0x2A` idle frames with enhanced checksum.
- Volume up/down/click substitutions produce valid `0x2A` responses only while armed.
- Native wheel button state is preserved when no injection is pending.
- Removing physical arm disables TX immediately.
- USB/BLE disconnect or timeout disarms active sessions.
- Unsigned firmware and unsigned profile packages are rejected.
- Flash readout/debug is locked on production-profile boards.
- Unactivated/unbound boards cannot enable active or passthrough TX.
- Faults latch and are visible in logs/status.