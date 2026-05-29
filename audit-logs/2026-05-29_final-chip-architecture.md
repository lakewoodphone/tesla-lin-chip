# 2026-05-29 Final Chip Architecture Planning

## Request

Design the actual bench-only chip/board direction now that the Tesla Model 3/Y steering LIN data is known. Include both-wheel scroll up/down, push, double-push goals, passive/passthrough/active modes, Bluetooth control/update, VIN/test-fixture binding, and safety controls to prevent road-use deployment.

## Research

Ran the Personal Secretary research dispatcher:

```text
personal-secretary-mvp/docs/research/directives/052-tesla-lin-chip-sourcing-board-architecture.md
personal-secretary-mvp/docs/research/responses/2026-05-29-tesla-lin-chip-sourcing-board-architecture.md
```

Provider/result:

```text
provider=perplexity
model=sonar-deep-research
status=complete
cost_usd=0.59776
search_count=48
citation_count=45
```

Supplemental official-page checks confirmed key details for NXP TJA1021, TI TLIN1029A-Q1, Nordic nRF5340 DK, Espressif ESP32-S3, and u-blox NORA-B1.

## Decisions Captured

- Primary Rev A direction: Nordic nRF5340, preferably via certified u-blox NORA-B1 module for the first custom PCB.
- Development platform: nRF5340 DK or NORA-B1 EVK/MINI-NORA-B1.
- Keep XIAO ESP32-C3 as protocol proving rig, not final dual-LIN product platform.
- ESP32-S3 remains a fallback if staying close to the current ESP32/NimBLE code matters more than BLE-first security.
- STM32WB55 remains an alternate if hardware USART LIN mode becomes the deciding factor.
- LIN transceiver shortlist: NXP TJA1021 primary, TI TLIN1029A-Q1 primary alternate, TI TLIN4029A-Q1 rugged alternate, Microchip MCP2003/MCP2004 fallback.
- Rev A must use two LIN transceivers for passthrough: car-side and wheel-side.
- Active output must be hardware-gated and default-off independent of firmware.
- VIN/test-fixture binding is a safety/authorization gate, not a vehicle-security bypass.
- Right-wheel injection remains disabled until the `0x2B` counter model is extracted and bench-proven.

## Files Updated

```text
docs/final-chip-architecture.md
docs/chip-sourcing-shortlist-2026-05-29.md
docs/single-board-rev-a-product-spec-2026-05-29.md
docs/secure-provisioning-anti-cloning-2026-05-29.md
NEXT_STEPS.md
```

## Single-Board Constraint Follow-Up

The owner clarified that the final device must be small, all on one board, connectorized, minimal-soldering, robust, and plug-in friendly. A second focused research pass was run:

```text
personal-secretary-mvp/docs/research/directives/053-compact-all-in-one-lin-ble-board-selection.md
personal-secretary-mvp/docs/research/responses/2026-05-29-compact-all-in-one-lin-ble-board-selection.md
```

Provider/result:

```text
provider=perplexity
model=sonar-deep-research
status=complete
cost_usd=0.42985
search_count=39
citation_count=36
```

Outcome: no researched commercial/off-the-shelf board satisfies BLE + two independent LIN channels + protected 12V + small single-board plug-in harness fixture. The closest reference is the Copperhill/SK Pang ESP32S3 CAN & LIN board, but it has only one LIN channel and cannot be the final passthrough board.

Updated final direction: compact custom assembled PCB, defaulting to u-blox NORA-B106-00B / nRF5340 with Ezurio BL5340 integrated-antenna module as alternate. Rev A target is about 60 mm x 35 mm, four-layer, assembled, with two LIN transceivers, protected 12V input, LIN/USB ESD, keyed positive-latch car/wheel harness connectors, USB-C, SWD, physical mode switch, physical arm, LEDs, test pads, and adapter harnesses for vehicle-specific connectors.

## Firmware Protection / Anti-Cloning Follow-Up

The owner clarified that a user must not be able to plug the board into a computer/debugger, read the firmware, clone it, or casually activate/rebind it. A third focused research pass was run:

```text
personal-secretary-mvp/docs/research/directives/054-nrf5340-firmware-protection-anti-cloning-anti-abuse.md
personal-secretary-mvp/docs/research/responses/2026-05-29-nrf5340-firmware-protection-anti-cloning-and-anti-abuse-architecture-for-compact-ac9a9b9f.md
```

Provider/result:

```text
provider=perplexity
model=sonar-deep-research
status=complete
cost_usd=0.43612
search_count=35
citation_count=35
```

Outcome: encryption alone is not sufficient. Rev A must layer secure boot, signed firmware, signed profile/config packages, anti-rollback, nRF5340 APPROTECT/SECUREAPPROTECT, ERASEPROTECT, per-device keys, authenticated BLE/USB activation, binding/rebinding tokens, hardware TX gates, physical mode/arm controls, and bench-only connector/harness policy.

Residual risk is explicit: this protects against casual and intermediate cloning/readout, but not against a well-funded invasive silicon lab. Production signing keys must stay outside the repo and preferably offline/HSM-backed.

## Safety Position

No active vehicle testing is implied by this architecture. Rev A is a bench fixture. The board must boot passive, require physical arm plus authenticated BLE/USB authorization for active/passthrough modes, time out automatically, log binding and safety state, reject unsigned firmware, and make active output electrically impossible on reset/brownout/crash/bootloader/unarmed states.
