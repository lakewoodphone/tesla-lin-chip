# Cheapest Reliable Dual-LIN + BLE Passthrough Chip / Module

Date: 2026-05-29

## Mission

Find the cheapest reliable central MCU/BLE chip or module that can be ordered soon in the US and can realistically serve as the core of the final Tesla Model 3/Y steering-wheel dual-LIN passthrough board.

This research must question the current working assumption that a Nordic nRF5340 module, especially u-blox NORA-B106 or Ezurio BL5340, is the best final choice. It must compare that path against cheaper choices that may be good enough, especially ESP32-S3 module variants, while preserving the real product requirements.

Use exactly two analysis tracks:

- Compass: conservative hardware/product decision, prioritizing reliability, security, and low bring-up risk.
- Gemini: cost/sourcing-focused challenge, prioritizing cheapest credible parts that are stocked and shippable soon.

## Product Requirements

The final board is not a single-transceiver tap. It must be a cut-wire passthrough/proxy fixture:

```text
Tesla car side <-> LIN transceiver A <-> MCU <-> LIN transceiver B <-> steering wheel side
```

Required capabilities:

- Two independent LIN channels through two external automotive LIN transceivers.
- Enough UART/peripheral support for both LIN sides plus USB/debug/logging.
- BLE control/provisioning from phone/app/tool.
- Secure boot or signed firmware update path.
- Readout/cloning resistance: production units must resist casual USB/SWD/JTAG/UART flash readout.
- Per-device activation/binding possible using protected key material or eFuse/secure storage equivalent.
- Anti-rollback or a credible update-version lock path.
- Fits on a small custom assembled PCB, roughly 60 mm x 35 mm Rev A.
- Parts available from reputable distributors or assembly channels soon, ideally Digi-Key, Mouser, Newark, Arrow, JLCPCB/LCSC, or manufacturer direct.
- Low unit cost matters, but not if it breaks passthrough timing, BLE provisioning, firmware security, or manufacturability.

## Important Clarification

The answer may be a certified module rather than a bare chip. For this project, module-level RF certification and faster PCB bring-up can beat a cheaper bare SoC if it materially reduces risk. However, the research must still identify the cheapest credible option that fully works.

Do not recommend any single off-the-shelf board as the final product unless it has two LIN transceivers on one board, BLE, protected 12V input, and security/provisioning support. Prior research found no such board; re-check this assumption briefly but do not spend the whole effort there.

## Candidates To Compare

At minimum compare:

- ESP32-S3-WROOM / ESP32-S3-MINI module variants.
- ESP32-C6 or C5 only if they truly improve BLE/security/peripheral fit.
- Nordic nRF5340 module variants: u-blox NORA-B106, Ezurio/Laird BL5340, Raytac MDBT53 class if relevant.
- Nordic nRF52840/nRF54 class modules only if they meet dual LIN + security + availability better.
- STM32WB55 or STM32WBA modules.
- Microchip PIC32CX-BZ / WBZ modules.

Also compare companion LIN transceiver availability/cost for:

- NXP TJA1021 SO8/SOIC-compatible options.
- TI TLIN1029A-Q1 / TLIN2029 / TLIN1021-Q1 class parts.
- Microchip MCP2003/MCP2004 fallback.

## Assumptions To Challenge

Question each assumption explicitly:

1. Does the final board truly need nRF5340 dual-core, or is ESP32-S3 good enough and cheaper?
2. Does WiFi presence on ESP32-S3 materially hurt product security if WiFi is disabled and secure boot/flash encryption are used?
3. Is Nordic secure boot/readout protection materially stronger for this threat model, or just cleaner?
4. Does ESP32-S3 have enough UARTs/peripherals and timing headroom for cached LIN passthrough plus BLE?
5. Does any cheaper BLE MCU/module fail because of too few UARTs, weak tooling, poor stock, or weak security?
6. Is a certified module worth the extra cost versus a bare chip for Rev A?
7. Which part can actually be ordered today and arrive soon from US-accessible sources?
8. Which part is easiest to assemble on a custom PCB through JLCPCB/PCBWay/standard assembly?
9. Which choice minimizes firmware rewrite from the current ESP32/Arduino proof while still supporting production security?
10. Which choice remains viable for the eventual compact, connectorized active passthrough product?

## Desired Output

Produce a decision-grade answer with:

- One recommended central MCU/BLE chip/module to order now.
- One backup central MCU/BLE chip/module.
- One recommended dev board or eval board for firmware bring-up if different from the module.
- Recommended LIN transceiver part to pair with it, plus backup.
- Approximate current unit price and stock/availability signals.
- Specific distributor/manufacturer search terms or MPNs to order.
- Why cheaper rejected candidates are not safe enough or complete enough.
- What assumptions changed from previous nRF5340-first guidance.
- A short final BOM seed for a first custom Rev A board.

Be practical and decisive. The owner wants to order parts now for a final active-capable passthrough board, not another broad dev-board menu.