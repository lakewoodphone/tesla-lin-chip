# Authoritative Datasheet Check: Dual-LIN + BLE Rev A BOM

Date: 2026-05-29

## Mission

Verify the exact orderable parts for the first custom Rev A dual-LIN + BLE passthrough board using authoritative manufacturer/distributor sources, not forum summaries. This is a follow-up to directive 055 and must catch hidden incompatibilities before the ordering decision is documented.

Use exactly two analysis tracks:

- Compass: datasheet/security/manufacturing correctness.
- Gemini: cost, stock, and quick ordering practicality.

## Context

The target board is a compact custom assembled PCB for a Tesla Model 3/Y steering-wheel cut-wire passthrough/proxy. It must have:

- One central BLE MCU/module.
- Two external automotive LIN transceivers.
- 3.3 V MCU logic preferred, without routine level shifters.
- Protected 12 V input.
- USB/provisioning/debug support.
- Secure boot, firmware readout resistance, signed updates, activation/binding.

Previous research favored ESP32-S3-WROOM-1U family as cheapest credible central module, with nRF5340 module backup. It also mentioned MCP2003-E/SN as a cheap LIN transceiver. This follow-up must verify whether that LIN transceiver and the alternatives are truly compatible with direct 3.3 V MCU IO, or whether a VIO-capable/transceiver-specific choice is safer.

## Parts To Verify

Central module candidates:

- ESP32-S3-WROOM-1-N8 or N8R8, internal PCB antenna.
- ESP32-S3-WROOM-1U-N8 or N8R8, external antenna connector.
- ESP32-S3-MINI-1 variants if cheaper/smaller and still practical.
- nRF5340 module backup: Raytac MDBT53-P1M or Ezurio BL5340.

LIN transceiver candidates:

- TI TLIN1029A-Q1 / TLIN1029-Q1.
- TI TLIN2029A-Q1 / TLIN2029-Q1.
- NXP TJA1021 / TJA1021T/20.
- Microchip MCP2003-E/SN and MCP2004 family.
- Any other clearly better low-cost 3.3 V MCU-compatible LIN transceiver available now.

## Required Checks

For each central module candidate, verify:

- Orderable MPN(s), approximate price, and stock signal from Digi-Key/Mouser/manufacturer/distributor.
- Integrated antenna vs U.FL/external antenna tradeoff for a compact board.
- Module certification status at high level.
- Number of usable UARTs / GPIO enough for two LIN channels plus service/debug.
- Secure boot, flash encryption/readout protection, eFuse/key storage, and update signing support.
- Whether Arduino-ESP32 is viable for Rev A or ESP-IDF is required for production security.

For each LIN transceiver candidate, verify:

- Exact package and orderable MPN.
- Supply pins and whether it supports direct 3.3 V MCU TXD/RXD logic or requires 5 V VCC/level shifting.
- LIN baud support at 19.2 kbaud and LIN 2.x / SAE J2602 compatibility.
- Dominant timeout / fault protection / wake/sleep/enable behavior.
- Automotive qualification if available.
- Approximate price and stock signal.

## Output Required

Produce a short decisive answer with:

- Exact primary central module MPN to order for Rev A.
- Exact central module backup MPN.
- Exact primary LIN transceiver MPN to use twice.
- Exact LIN transceiver backup MPN.
- Whether to use internal PCB antenna or U.FL for Rev A, and why.
- Whether any level shifter is needed between the MCU and LIN transceiver.
- One seed BOM table for the first Rev A board.
- A list of rejected parts and the exact reason.

Keep the conclusion practical: the owner needs parts that can be ordered now and will actually work for the active dual-LIN passthrough board.