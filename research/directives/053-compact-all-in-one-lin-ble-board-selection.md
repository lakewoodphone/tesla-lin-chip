---
title: Compact all-in-one BLE LIN board selection for bench-only vehicle steering fixture
research_type: automotive-re
sensitivity: no-refusal-required
output_path: docs/research/responses/2026-05-29-compact-all-in-one-lin-ble-board-selection.md
---

# Research Directive

We need to refine an existing Tesla Model 3/Y steering-wheel LIN research fixture architecture into a small, robust, mostly plug-in, all-on-one-board product direction.

Existing verified context:

- Bench-only, non-road-use LIN research module for steering-wheel controls.
- Must support passive capture, dual-LIN passthrough/proxy, and controlled active/mock gesture generation where frame models are proven.
- Current proof rig uses Seeed XIAO ESP32-C3 + external TJA1021 LIN transceiver breakout(s), but the user does not want a final design that requires attaching several boards together.
- LIN is 19200 baud; proper passthrough requires two LIN transceivers, one car-side and one wheel-side.
- BLE control/update is required.
- Safety: default passive/off; physical arm gate; authenticated BLE/USB control; timeout; fault lockout; signed firmware update; VIN/test-fixture binding; no road-use design.
- Current first-pass recommendation was nRF5340 / u-blox NORA-B1 module for Rev A, with ESP32-S3 as fallback and STM32WB as alternate.

New hard constraints from user:

1. The final hardware should be pretty small.
2. It must be all on one board, not a stack of dev boards/breakouts.
3. It should include board, connectors, protection, LIN channels, MCU/BLE, and service/debug access.
4. Minimal soldering: ideally order assembled PCB, plug in harness/connectors, program/update over USB/BLE/SWD.
5. It should be robust and not easy to break: good power protection, ESD, connectors, strain relief, and test pads.
6. It should be as universal as practical across vehicle LIN scenarios: all modes, configurable LIN roles, configurable baud/profiles, adapter harnesses rather than redesigning the electronics for every car.
7. Easily programmable and Bluetooth-updatable.

Research goals:

- Determine whether an existing commercial/off-the-shelf board already satisfies most requirements: BLE MCU + two LIN transceivers + 12V automotive protection + connectors + programmable firmware. Include any small dev boards, automotive prototyping boards, MikroE/click type boards, CAN/LIN BLE boards, Arduino/Nordic/ESP32 automotive LIN boards, and why they do or do not fit.
- If no existing board is good enough, recommend the best single custom PCB architecture and the exact module/chip strategy for minimum soldering and robustness.
- Compare compact module choices for the single-board PCB: u-blox NORA-B1/nRF5340, Raytac nRF5340 if available, nRF52840 modules, ESP32-S3 modules, ESP32-C6 modules, STM32WB modules, Microchip WBZ/PIC32CX-BZ modules. Focus on UART count, BLE OTA, secure boot/DFU, module certification, footprint, availability, and ease of assembly.
- Recommend connector strategy for small plug-in board: keyed automotive-style connectors, JST/Molex/MicroFit, separate harness adapters, test pads, USB-C/SWD, mode/arm controls.
- Recommend board size/features target: approximate size class, two LIN transceivers, protection, power, LEDs, switch/jumper placement, programming/debug access.
- Identify the absolute best practical path for Rev A and a possible later Rev B miniaturization path.

Output should be opinionated: name the best path and why. Include a table of considered existing boards/modules and a final recommendation. Use official manufacturer/distributor sources where possible.
