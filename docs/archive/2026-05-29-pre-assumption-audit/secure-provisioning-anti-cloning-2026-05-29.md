# Secure Provisioning, Anti-Cloning, and Anti-Abuse - 2026-05-29

Status: security architecture requirement for the compact single-board Rev A. This is not a released security certification.

Research artifact:

```text
personal-secretary-mvp/docs/research/responses/2026-05-29-nrf5340-firmware-protection-anti-cloning-and-anti-abuse-architecture-for-compact-ac9a9b9f.md
```

## Bottom Line

Do not rely on one magic feature called encryption. The board needs layered protection:

```text
secure boot
+ signed firmware and signed profile/config packages
+ SWD/debug readout protection
+ erase-all protection
+ per-device keys
+ authenticated BLE/USB activation
+ binding to fixture/car label
+ hardware TX gates
+ physical mode/arm controls
+ bench-only connectors/harness policy
+ signed logs and lockout counters
```

The goal is to stop casual copying, stop normal SWD/USB firmware readout, make cloning economically annoying, and make unsafe road-use repurposing hard enough that the board is clearly a bench research fixture. This will not stop a well-funded invasive silicon lab from attacking the chip. It should stop the realistic cases: someone plugs it into a computer, opens the enclosure, attaches a debugger, copies an update package, or tries to rebind it casually.

## Threat Model

| Threat | What they try | Required control |
|---|---|---|
| Casual USB/BLE user | Use board without activation or load unofficial firmware | Admin provisioning, signed DFU, no privileged commands before activation |
| Hobbyist with SWD probe | Read flash or clone firmware | APPROTECT/SECUREAPPROTECT, ERASEPROTECT, no user SWD header |
| Update-package copier | Use captured firmware on another board | Signed images, anti-rollback, optional per-device encrypted payloads, activation check |
| Clone builder | Program similar hardware with copied app | Per-device keys and signed activation profile tied to serial/device ID |
| Careless operator | Use active mode in a real car | Bench-only labeling, keyed bench harnesses, physical arm, mode switch, active timeouts |
| Malicious road-use user | Repurpose board as generic LIN injector | Secure boot, signed configs, TX gates, binding, rate/session limits, no generic active profile |
| Invasive lab | Glitch/probe silicon | Out of full prevention scope; minimize global secrets and accept residual risk |

## nRF5340 Protections To Use

The NORA-B1 and BL5340 module paths expose the nRF5340 security model. Production firmware must explicitly enable it; development modules ship with protections open.

Required Rev A settings and features:

- Enable APPROTECT / SECUREAPPROTECT so SWD cannot read internal flash/RAM.
- Enable ERASEPROTECT so an attacker cannot simply mass-erase the device and repurpose it without the authorized unlock flow.
- Use MCUboot plus Nordic secure boot chain where practical.
- Use production signing keys, never sample/demo keys.
- Enforce anti-rollback for firmware and configuration/profile packages.
- Use TrustZone / TF-M for protected key and security services as the firmware matures.
- Store per-device secrets in KMU / secure storage or the strongest available protected storage path.
- Keep SWD on Tag-Connect/test pads for manufacturing only; do not expose a friendly debug header.
- Treat debug-enabled boards as lab-only engineering units with different labels and firmware.

## Manufacturing Provisioning Flow

1. Assemble board with NORA-B106 or BL5340 module.
2. Program secure bootloader, TF-M/security partition if used, and manufacturing test image over SWD.
3. Run hardware test: rails, LIN_A RX/TX gate, LIN_B RX/TX gate, USB, BLE advertisement, buttons, LEDs.
4. Generate device serial and per-device key material.
5. Store secrets in protected storage; record public identity, serial, board rev, and test result in the manufacturing registry.
6. Flash production application and baseline signed profile package.
7. Enable APPROTECT/SECUREAPPROTECT and ERASEPROTECT.
8. Verify SWD readout is blocked.
9. Verify unsigned firmware is rejected.
10. Ship in inactive/passive-only state with proof-of-possession code or activation QR.

No unit should leave provisioning with readable debug access enabled.

## Activation Flow

Activation should be explicit and boring:

1. Board boots in inactive passive mode.
2. Operator opens app/tool and enters/scans board proof-of-possession code.
3. BLE uses LE Secure Connections and bonds an admin device.
4. Board proves device identity through challenge/response using per-device secret or key.
5. Tool sends signed activation package tied to board serial/device identity.
6. Operator enters fixture ID and optional VIN label manually.
7. Board stores binding hash/display label in protected config.
8. Active/passthrough modes remain unavailable until physical mode switch and arm input are also present.

The board must not read VIN from the car network for binding. Binding is an operator safety label, not a vehicle-security bypass.

## Firmware And Config Update Rules

- Firmware images must be signed.
- Profile/config packages must be signed separately from firmware.
- Older firmware/config versions must be rejected after anti-rollback version is advanced.
- DFU can happen over BLE or USB, but only signed images are accepted.
- DFU mode must force LIN TX disabled in hardware and firmware.
- Development firmware must use a different key path and must not run on provisioned production boards.
- Signing keys must live outside the repo. Ideally use an offline machine or HSM-backed signing flow for production.

Optional later improvement: encrypt firmware/config packages per device or per small cohort. This helps confidentiality of update packages, but signing and readout protection are the mandatory core.

## Binding And Rebinding

Binding is required before any active or passthrough transmit mode.

Required binding record:

```text
board serial
module unique ID / public identity
firmware signing key ID
config signing key ID
fixture ID
operator-provided VIN label, if used
profile ID
binding version
binding timestamp
binding hash/signature
```

Rebinding rules:

- Requires bonded admin credential.
- Requires physical service strap or case-open/service action.
- Requires signed rebind token from the activation tool.
- Clears active session state and gesture queues.
- Logs old binding hash, new binding hash, reason, and operator/tool ID.

Factory reset clears user binding and returns to passive-only provisioning mode. It must not clear the device identity key unless the board is being retired or re-manufactured.

## Road-Use Abuse Resistance

No software lock can absolutely prevent misuse if someone controls hardware and signing keys. The board should still make unsafe use difficult and clearly outside the intended design.

Required anti-abuse controls:

- Bench-only label and documentation.
- Base board uses generic keyed harness connectors, not direct OEM vehicle connectors.
- Active output requires signed firmware, signed profile, valid binding, authenticated session, physical mode switch, physical arm, active timeout, rate limit, and healthy LIN error counters.
- No generic arbitrary LIN transmit command in production firmware.
- Only proven gesture/profile primitives are exposed.
- Right-wheel actions remain disabled until the counter model is separately proven.
- Disconnect from BLE during active session disarms unless supervised USB bench mode is explicitly active.
- Power cycle always returns to safe passive.
- Faults latch until explicit safe-off or power-cycle inspection.

## Security State Machine

```text
BLANK_OR_FACTORY
  -> manufacturing SWD only
  -> no LIN TX

PROVISIONED_LOCKED
  -> debug/readout locked
  -> signed firmware only
  -> passive capture allowed
  -> active/passthrough unavailable until activation

ACTIVATED_BOUND
  -> admin BLE/USB required for config
  -> binding present
  -> active still requires physical mode + arm

ARMED_SESSION
  -> short timeout
  -> rate limits
  -> TX gate enabled only while all gates hold
  -> fault/disconnect/unarm returns to ACTIVATED_BOUND safe-off

SERVICE_RECOVERY
  -> signed DFU only
  -> LIN TX hardware disabled
  -> no raw memory readout

RETIRED_OR_COMPROMISED
  -> identity revoked in registry
  -> no new activation/rebind packages
```

## Rev A Acceptance Tests

- SWD readout attempt fails after provisioning.
- External mass erase fails unless authorized service flow is used.
- Unsigned DFU image is rejected.
- Older signed firmware is rejected after anti-rollback advancement.
- Older signed config/profile is rejected after anti-rollback advancement.
- Board without activation cannot enable passthrough or active output.
- Board without binding cannot enable passthrough or active output.
- Bound board without physical arm cannot transmit.
- Removing arm disables TX gate and clears gesture queue.
- DFU/recovery mode cannot transmit on LIN.
- Factory reset returns to passive-only state and preserves device identity.
- Rebind requires admin auth plus service strap/action.
- Failed activation attempts are rate-limited and logged.
- Exported logs include serial, board rev, firmware hash, binding hash, active sessions, faults, and inhibited TX attempts.

## Residual Risk

- A sufficiently capable invasive lab may still extract secrets or bypass protections.
- If production signing keys leak, secure boot loses most of its value until keys are rotated and devices reject old keys.
- A determined person can build their own hardware from scratch after learning the protocol. The product can protect this board and firmware; it cannot make public LIN knowledge disappear.
- Bench-only enforcement is layered friction and accountability, not a mathematical guarantee.

## Design Principle

Default state is passive and locked. Every step toward active behavior must require a different kind of proof: cryptographic proof, device identity, operator binding, physical action, session timing, and healthy bus state.
