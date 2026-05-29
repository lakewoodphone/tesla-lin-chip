# Secure Provisioning, Anti-Cloning, and Anti-Abuse - 2026-05-29

Status: current security architecture for the ESP32-S3 Rev A dual-LIN passthrough board. The nRF5340-first version is archived under `docs/archive/2026-05-29-pre-assumption-audit/`.

## Goal

The board should resist casual cloning and unsafe activation:

```text
secure boot
+ flash encryption
+ signed firmware
+ signed profile/config packages
+ anti-rollback
+ eFuse/debug lockdown
+ per-device activation/binding
+ authenticated BLE/USB provisioning
+ physical mode and arm gates
+ hardware TX default-off
```

This does not stop a well-funded invasive chip lab. It should stop the realistic threats: someone plugs into USB/UART/debug, copies flash, loads unofficial firmware, reuses an update package, or casually rebinds a board.

## Threat Model

| Threat | What they try | Required control |
|---|---|---|
| Casual USB user | Enable board without activation | Activation package, binding, authenticated session, no active commands before gates |
| Firmware copier | Dump flash and clone code | Flash encryption, debug lockdown, encrypted config |
| Unsigned updater | Load modified firmware | Secure Boot V2 and signed image verification |
| Rollback attacker | Install older vulnerable firmware/profile | Anti-rollback counters/versions |
| Clone builder | Use copied app on another board | Per-device identity and signed activation tied to identity |
| Careless operator | Active output in wrong situation | Physical mode switch, arm gate, rate/session limits, fault latch |
| Invasive lab | Glitch/probe silicon | Out of full prevention scope; minimize global secrets |

## ESP32-S3 Production Protections

Use ESP-IDF for the production security path.

Required features:

- Secure Boot V2 enabled.
- Production firmware signing keys generated and stored outside the repo.
- Flash encryption enabled in production mode.
- eFuse policy burned to prevent casual plaintext reflashing/readout.
- JTAG/debug disabled for production boards.
- ROM download mode disabled or restricted according to the final ESP-IDF production policy.
- Encrypted NVS or equivalent protected storage for activation, binding, and secrets.
- Firmware anti-rollback enabled.
- Profile/config anti-rollback enforced by app logic and signed package metadata.
- Device serial/identity and activation material provisioned per unit.

Arduino-ESP32 is acceptable for quick logic proof only. The locked Rev A firmware should use ESP-IDF because secure boot, flash encryption, partitioning, OTA, anti-rollback, and production eFuse policy must be deliberate and testable.

## Manufacturing Provisioning Flow

1. Assemble board with ESP32-S3-WROOM-1U-N8R8, two LIN transceivers, and protection circuitry.
2. Flash factory test image over USB/UART/service pads.
3. Run hardware test: rails, USB, BLE advertisement, antenna RSSI, LIN A RX/TX gate, LIN B RX/TX gate, mode switch, arm input, LEDs.
4. Generate device serial and per-device activation identity.
5. Program production bootloader/app/profile with test-safe inactive state.
6. Enable secure boot and flash encryption according to ESP-IDF production flow.
7. Burn debug/bootloader/eFuse restrictions for production-profile unit.
8. Verify flash readout/unsafe reflashing is blocked.
9. Verify unsigned firmware is rejected.
10. Verify inactive board cannot enable LIN TX.
11. Record public serial, board rev, firmware hash, profile hash, test result, and lock state in the manufacturing registry.
12. Ship inactive/passive with proof-of-possession code or QR label.

Engineering units may skip lock steps during bring-up, but they must be physically labeled and never shipped as production-profile boards.

## Activation Flow

1. Board boots `SAFE_PASSIVE`.
2. Operator connects over BLE or USB.
3. Tool requires proof-of-possession code printed on board label/QR or shown over USB during factory mode.
4. BLE uses authenticated pairing/bonding for privileged writes.
5. Board proves device identity with challenge/response or signed nonce using per-device material.
6. Tool sends signed activation package tied to board identity.
7. Operator enters fixture ID and optional VIN label manually.
8. Board stores binding record in encrypted/protected config.
9. Active/passthrough TX remains locked until physical mode, physical arm, session timer, rate limits, and LIN health gates are also valid.

The board must not infer or read VIN from vehicle networks for binding. Binding is a safety/accountability label, not a vehicle-security bypass.

## Firmware And Profile Updates

- Firmware images must be signed.
- Profile/config packages must be signed separately.
- Firmware rollback must be rejected.
- Profile/config rollback must be rejected.
- DFU/service mode must hold LIN TX disabled in hardware and firmware.
- Development keys must not run on locked production units.
- Production signing keys must stay outside the repo and preferably on an offline or restricted signing machine.
- Update package copying should not activate a different board without a valid activation/binding package for that board.

## Binding Record

Required binding data:

```text
board serial
ESP32 eFuse/device identity/public identity
board revision
firmware hash/version
firmware signing key ID
profile hash/version
profile signing key ID
fixture ID
operator-entered VIN label, optional
binding version
binding timestamp
binding hash/signature
```

Rebinding requires:

- Bonded/admin credential.
- Physical service strap or case-open/service action.
- Signed rebind token.
- Clearing active session state and gesture queues.
- Log entry with old binding hash, new binding hash, reason, and tool/operator ID.

Factory reset returns to passive/inactive provisioning state. It must not erase immutable device identity unless the board is being retired or remanufactured.

## Anti-Abuse Controls

- No generic arbitrary LIN transmit command in production firmware.
- Only signed, proven profiles expose active primitives.
- Right-wheel `0x2B` actions remain disabled until counter model is proven.
- Power cycle always returns to safe passive.
- BLE disconnect during active session disarms unless a supervised USB bench session explicitly owns the session.
- Active sessions have short timeouts.
- Rate limits cap repeated gestures.
- LIN error counters/faults inhibit TX.
- Fault LED/status latches until `safe:off`, power cycle, or service inspection.
- Base board uses generic keyed connectors and adapter harnesses, not a hidden plug-and-drive design.

## Security State Machine

```text
BLANK_OR_ENGINEERING
  -> factory/debug access allowed
  -> no production secrets
  -> no shipped active device

PROVISIONED_LOCKED
  -> secure boot and flash encryption enabled
  -> debug/readout locked
  -> passive only until activation

ACTIVATED_BOUND
  -> binding present
  -> config/profile updates require signed packages
  -> active still requires physical mode and arm

ARMED_SESSION
  -> short timeout
  -> rate limits
  -> TX gate enabled only while all gates hold
  -> fault, disconnect, or unarm returns to safe-off

SERVICE_DFU
  -> signed update only
  -> LIN TX disabled
  -> no raw memory readout

RETIRED_OR_COMPROMISED
  -> identity revoked
  -> no new activation/rebind packages
```

## Rev A Security Acceptance Tests

- Unsigned firmware image is rejected.
- Older signed firmware is rejected after anti-rollback advancement.
- Unsigned profile/config package is rejected.
- Older signed profile/config is rejected after profile anti-rollback advancement.
- Flash readout/casual dump path is blocked on production-profile board.
- Production board cannot be reflashed with plaintext/debug image.
- Unactivated board cannot enable passthrough or active output.
- Activated but unbound board cannot enable passthrough or active output.
- Bound board without physical arm cannot transmit.
- Removing arm disables TX and clears gesture queue.
- DFU/recovery mode cannot transmit on LIN.
- Rebind requires admin auth plus physical service action plus signed token.
- Failed activation attempts are rate-limited and logged.
- Logs include serial, firmware hash, profile hash, binding hash, active sessions, faults, and inhibited TX attempts.

## Residual Risk

- A capable invasive lab may still bypass chip protections.
- If production signing keys leak, secure boot is compromised until key rotation/revocation is deployed.
- Someone can independently reimplement public LIN behavior on their own hardware. This security model protects this board and firmware; it cannot prevent all independent reverse engineering.
- Bench-only/anti-abuse controls are layered friction and accountability, not a mathematical guarantee.