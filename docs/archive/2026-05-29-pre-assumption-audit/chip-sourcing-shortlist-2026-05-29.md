# Chip Sourcing Shortlist - 2026-05-29

Status: sourcing and architecture shortlist for Rev A planning. Check live distributor stock before ordering.

Research artifacts:

```text
personal-secretary-mvp/docs/research/responses/2026-05-29-tesla-lin-chip-sourcing-board-architecture.md
personal-secretary-mvp/docs/research/responses/2026-05-29-compact-all-in-one-lin-ble-board-selection.md
```

## Recommendation

Build Rev A as a compact custom assembled PCB around a certified nRF5340 module, not a bare RF chip, not the current ESP32-C3 XIAO, and not a stack of dev boards/breakouts.

Preferred path:

1. Use Nordic nRF5340 DK or u-blox EVK-NORA-B1 only for pre-PCB firmware/toolchain proof.
2. Prototype the first owner-facing board as one assembled PCB with a u-blox NORA-B106-00B module if available.
3. Use two automotive LIN transceivers in SO8 packages for visibility and hand-debuggability.
4. Keep the XIAO ESP32-C3 rig as the protocol discovery/proof bench, not the final dual-LIN product platform.

Off-the-shelf board conclusion: no currently found board satisfies BLE + two independent LIN channels + 12V protection + small single-board plug-in harness fixture. The Copperhill/SK Pang ESP32S3 CAN & LIN board is the closest reference, but it has only one LIN transceiver and should not be treated as the final hardware.

## MCU / BLE Platform Shortlist

| Priority | Part / board | Why it fits | Caveats |
|---:|---|---|---|
| 1 | u-blox NORA-B106-00B | nRF5340 inside, dual Cortex-M33, internal PCB antenna, BLE 5.2, TrustZone/CryptoCell class security, FOTA, secure-boot ready, global certification, UART x5, USB, SPI, GPIO, avoids RF layout and avoids fragile U.FL cable | Higher unit cost than bare SoC or ESP32; verify stock before layout lock |
| 2 | Ezurio BL5340 integrated-antenna variant | nRF5340, compact certified module, Zephyr/nRF Connect SDK, FOTA via MCUboot/Zephyr, strong distributor stock signals | Use if NORA-B106 stock, pricing, or placement is worse |
| 3 | Nordic nRF5340 DK / u-blox EVK-NORA-B1 | Best firmware development platform for BLE, DFU, dual-core timing, and debug | Pre-PCB only; not final form factor |
| 4 | ESP32-S3-WROOM / ESP32-S3-MINI | Easy continuation from ESP32/NimBLE, dual core, many GPIO/UART, secure boot/flash encryption, low cost; commercial ESP32S3 CAN/LIN board exists as reference | Includes WiFi, more custom secure OTA work, less BLE-first than Nordic |
| 5 | STM32WB55 module/eval | BLE plus STM32 USART LIN mode and ST secure boot/update ecosystem | Tooling stack is heavier; BLE/DFU workflow may take longer than Nordic |
| 6 | ESP32-C3 / XIAO ESP32-C3 | Already proven for passive, active bench TX, and BLE config | Too constrained for final dual-LIN + secure OTA + debug; keep as prototype only |

Practical module notes:

- u-blox NORA-B1 has nRF5340, BLE 5.2, FOTA, secure-boot-ready status, UART x5, USB, SPI, GPIO, ADC, and certified module variants.
- Default to an internal PCB antenna module for Rev A unless enclosure/placement forces U.FL. U.FL is flexible but mechanically easier to damage.
- ESP32-S3 modules are cheap and broadly stocked, and Espressif documents secure boot, flash encryption, Bluetooth 5 LE, many GPIOs, and ESP-IDF support.
- nRF5340 DK is the quickest way to validate architecture before a PCB, even if NORA-B1 is the eventual module.

## Existing Board Reality Check

| Existing option | Useful as | Why not final |
|---|---|---|
| Copperhill/SK Pang ESP32S3 CAN & LIN board | ESP32-S3 + TJA1021 + protected input reference | One LIN only; generic gateway size/layout; would require another board for passthrough |
| MikroE LIN Click | LIN transceiver reference | One LIN only, no BLE, requires host board |
| Microchip WBZ/PIC32CX-BZ Curiosity | BLE/802.15.4 MCU reference | No onboard LIN transceivers, dev-board form factor |
| STM32WB dev/module boards | BLE/security reference | No onboard dual LIN, generic headers |
| XIAO ESP32-C3 + breakouts | Existing proof rig | Too fragile and too few clean channels for final product |

## LIN Transceiver Shortlist

Use two identical transceivers on Rev A: one car-side and one wheel-side.

| Priority | Part family | Why it fits | Package preference |
|---:|---|---|---|
| 1 | NXP TJA1021 | LIN 2.x/SAE J2602/ISO17987, 1-20 kBd, passive behavior unpowered, 3.3V/5V logic compatible, TXD dominant timeout, short/thermal/transient protection | SO8 first, optional HVSON8 later |
| 2 | TI TLIN1029A-Q1 | Automotive LIN transceiver, 4-36V supply, -45V to +45V bus fault, 20 kbps, dominant-state timeout, active production options | SOIC for Rev A, VSON only for compact batch |
| 3 | TI TLIN4029A-Q1 | Higher ruggedness and fault margin; useful if price/availability is acceptable | Check stock and assembly support |
| 4 | Microchip MCP2003 / MCP2004 | Common LIN 2.x/J2602 class transceiver fallback | SOIC/TSSOP depending stock |
| 5 | MCP2025 / TLIN1441 regulator variants | Integrated regulator variants for simple nodes | Not primary for this BLE module because regulator current headroom is too low |

Add LIN ESD parts near each connector. TI's product page suggests ESD1LIN24-Q1 as a LIN-oriented ESD protection diode class; equivalent automotive LIN ESD diodes are acceptable.

## Power / Protection Parts To Source

These are part classes for schematic work, not final MPN locks:

| Function | Preferred class | Notes |
|---|---|---|
| Input fuse | Resettable PTC or replaceable fuse | Size for bench fixture current; protect against wiring mistakes |
| Reverse protection | P-channel MOSFET ideal diode or automotive ideal-diode controller | TI LM74700D-Q1 class part is a good reference point |
| Input transient clamp | Automotive TVS on 12V input | Place near connector after fuse/protection strategy is decided |
| Buck regulator | 12V to 5V or 3V3 buck, at least 500 mA | Leave headroom for BLE peaks, LEDs, debug, and transceivers |
| Clean rail | Optional LDO from 5V to 3V3 | Useful if buck ripple is visible in radio or ADC behavior |
| USB ESD | USB D+/D- ESD array | Required if USB is on board |
| LIN ESD | Single-line automotive LIN ESD diode per LIN connector | Place close to connector |
| TX gate | Logic gate, load switch, or transceiver enable gate | Must default off if MCU is blank/reset/crashed |
| Connectors | Keyed locking connectors | Separate car-side, wheel-side, 12V, and debug where possible |

## Single-Board Feature Target

Rev A target: about 60 mm x 35 mm, four-layer PCB, assembled with surface-mount parts. Rev B can shrink after the circuit is proven.

Board should include:

- NORA-B106 or BL5340 nRF5340 module.
- Two TJA1021 or TLIN1029A-Q1 LIN transceivers.
- Two LIN ESD/protection parts.
- Protected 12V input: fuse/PTC, reverse protection, input TVS.
- Buck regulator plus optional quiet 3V3 LDO.
- USB-C with ESD for service/programming/logs.
- SWD/Tag-Connect footprint for unbrick/factory programming.
- Optional QSPI flash footprint for logs/DFU staging if firmware size/logging warrants it.
- Physical mode switch: passive / passthrough lab / active mock lab.
- Physical arm control that is required for any TX.
- Hardware TX gating default-off on reset/blank MCU/bootloader.
- LEDs for power, BLE, passive, armed, TX, and fault.
- Two keyed harness connectors: car side and wheel side.
- Test pads for 12V, 5V, 3V3, LIN_A, LIN_B, RXD/TXD, SLP/EN, ARM, FAULT, SWD, GND.

Connector recommendation: use a positive-latch Molex Micro-Fit/Nano-Fit class connector family for Rev A unless the enclosure demands a smaller JST-GH/Micro-Lock class part. Use adapter harnesses for Tesla/other OEM connectors; do not put every OEM connector on the PCB.

## Prototype Buy List

Buy these first for architecture validation. Breakouts/dev kits are for pre-PCB validation only, not the final form factor:

- 1x Nordic nRF5340 DK.
- 1x u-blox EVK-NORA-B1 or MINI-NORA-B1 if available at sane pricing.
- Samples/reels/cut tape of NORA-B106-00B or Ezurio BL5340 integrated-antenna variant for PCB planning.
- 10x NXP TJA1021 SO8 or TI TLIN1029A-Q1 SOIC, whichever is easier to source from Digi-Key/Mouser/JLCPCB.
- 10x LIN ESD diodes suitable for 12V LIN.
- 2-4x LIN transceiver breakout boards for fast wiring before PCB.
- 1x isolated USB adapter or USB isolator for vehicle-adjacent bench work.
- PTC/fuse assortment, automotive TVS assortment, reverse-protection MOSFETs/controller samples.
- Keyed connector assortment for 12V/GND/LIN and car-side/wheel-side split harness.
- Extra APG/XIAO wiring and labels so the two-LIN fixture is hard to miswire.

## Do Not Buy For Rev A

- A bare nRF5340 chip as the first custom board unless RF layout/certification is the actual goal.
- A one-transceiver-only design for passthrough. It cannot be a proper proxy.
- A final design that requires the owner to plug together several boards.
- MCP2025/TLIN1441-style regulator LIN parts as the main power plan for a BLE MCU.
- Random marketplace ESP32 boards for safety validation. Use official/dev-kit/distributor parts.
- Any harness plan that lacks a physical bypass/removal path.

## Board Setup Direction

Rev A should be one PCB with two clear zones:

```text
Control side:
  BLE MCU module
  USB/SWD/debug
  physical mode/arm/service controls
  status LEDs
  protected 3V3/5V power

LIN side:
  car-side LIN transceiver + ESD + test pads
  wheel-side LIN transceiver + ESD + test pads
  optional bench-master pull-up/jumper
  default-off TX gates and transceiver sleep controls
```

Use wide labels and test pads. The point of Rev A is not miniaturization; it is observability, safety proof, and clean firmware bring-up.

## Open Sourcing Questions

- Which exact NORA-B1 variant has the best distributor availability right now: PCB antenna, antenna pin, or U.FL.
- Whether JLCPCB can source/assemble the selected LIN transceiver and ESD parts directly, or whether they should be customer-supplied.
- Whether Rev A uses USB-C onboard or an isolated external USB-UART/SWD adapter.
- Whether the physical active gate should switch transceiver SLP/EN, TXD path, or both.
- Whether the first PCB should include footprints for both TJA1021 SO8 and TLIN1029A-Q1 SOIC if pinouts allow clean routing.
