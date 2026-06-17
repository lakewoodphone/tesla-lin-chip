---
title: Tesla LIN bench-only BLE passthrough chip sourcing and board architecture
research_type: automotive-re
sensitivity: no-refusal-required
output_path: docs/research/responses/2026-05-29-tesla-lin-chip-sourcing-board-architecture.md
---

# Research Directive

We are designing a bench-only, non-road-use hardware module for a Tesla Model 3/Y steering-wheel LIN research fixture. The device is not intended for use while driving. It should support passive capture, dual-transceiver passthrough/proxy mode, and controlled active mocking of scroll up, scroll down, push/click, and double-push gestures for left and right scroll wheels where protocol data is confirmed.

Existing verified project constraints:

- Current prototype: Seeed XIAO ESP32-C3 with Arduino/PlatformIO firmware.
- LIN bus: 19200 baud.
- Confirmed Model 3 left wheel control: raw ID 0x2A, PID 0x6A, 7 data bytes, enhanced checksum.
- Left wheel byte[0]: idle 0x0C, scroll/volume up 0x0D, scroll/volume down 0x0B, click 0x2C.
- Left wheel counter tail: byte[5] 0xF0..0xFF with paired byte[6] table [7F,62,45,58,0B,16,31,2C,97,8A,AD,B0,E3,FE,D9,C4].
- Confirmed right wheel raw ID 0x2B, 6 bytes, but right-wheel counter model is not yet complete.
- Proper passthrough architecture requires two LIN transceivers: car-side and wheel-side. The MCU must answer car-side master headers immediately from cache/injection queue and poll/cache the wheel-side module.
- Existing firmware uses NimBLE on ESP32-C3 for BLE config, NVS for settings, safe:arm gates, 300s session limit, fault lockout, rate limit, bus-idle guard, and active output boots disabled.
- Desired next product direction: actual chip/board, Bluetooth controllable/updatable, passive/passthrough/active modes, VIN or test-vehicle binding, strong bench-only safety so it is hard to use in a real car on the road.

Research goals:

1. Recommend MCU/SoC choices for a small custom board, with current sourcing availability and practical reasons. Compare at least:
   - ESP32-C3 / ESP32-C6 / ESP32-S3 family
   - Nordic nRF52840 / nRF5340
   - STM32WB or similar BLE MCU
   - Any better practical alternative for BLE + secure OTA + at least two UART/LIN channels
2. Recommend LIN transceivers suitable for 12V automotive-style LIN benches, preferably available from Digi-Key/Mouser/LCSC/JLCPCB assembly when possible. Include TJA1021 successors/alternatives, Microchip MCP200x family, TI/Infineon/NXP/ST options, and notes on sleep, dominant timeout, EN/SLP pins, ESD, and 3.3V logic compatibility.
3. Recommend power/input protection architecture for bench/vehicle-adjacent use: 12V input, buck/LDO choices, reverse polarity, fuse/PTC, TVS, ESD, LIN bus protection, connector strategy, and isolation/test pads.
4. Recommend BLE provisioning/update/security architecture: OTA update options, secure boot/flash encryption or Nordic DFU equivalent, BLE pairing/bonding, authorization model, VIN/test-fixture binding storage, physical arming, serial recovery, and factory reset strategy.
5. Identify sourcing shortlist with indicative unit cost/availability and package/build practicality for prototype and small batch.
6. Identify gotchas for using ESP32-C3 specifically with two UART LIN channels and BLE at the same time; say whether moving to ESP32-S3/C6 or nRF52840 is materially better.
7. Output a concise board architecture recommendation and a phase plan: dev-board prototype, prototype PCB, safety validation, then locked bench-only release.

Safety constraints:

- Do not provide instructions for bypassing vehicle safety systems or using the device on public roads.
- The design should default to passive/off, require physical and BLE/USB authorization to enable active/passthrough injection, time out automatically, and bind to a test vehicle/fixture identity where feasible.
- Treat VIN binding as a safety/authorization feature, not as a DRM bypass.

Please cite official datasheets/manufacturer pages or reputable distributor pages where available. Prefer practical parts that can actually be bought and assembled in 2026.
