# Tesla LIN Bench Equipment Inventory - 2026-05-19

Status: **BENCH BUILT AND VERIFIED 2026-05-26. See `C:\Users\ezabz\Code\xiao-lin-bench\README.md` for the final wiring diagram and `NEXT_STEPS.md` for what's next.** Parts arrived 2026-05-24; bench built and first clean LIN frame decoded the night of 2026-05-25/26. This file documents what was ordered and why — the active project is now `xiao-lin-bench`.

## Executive Summary

The ordered equipment is enough to build a real no-car LIN bench network and stop relying on the overheated tiny raw SOIC-8 TJA chip setup.

Important correction: the abandoned part is the loose/bare tiny TJA1020-style chip path. The current plan uses the APGDT001 as the real PC-side USB-LIN master/analyzer. A ready-made TJA1021-class breakout module is only for the XIAO-side LIN physical layer, and only after its pinout and RXD logic voltage are measured. Do not use a loose tiny SOIC TJA chip or the old overheated breadboard build.

The new lab direction is:

```text
Windows PC + Microchip APGDT001 USB-LIN analyzer/master
    -> 12-14 V LIN bench bus
    -> TJA1021 LIN transceiver module
    -> level-shifted Seeed XIAO ESP32-C3 UART
```

This lets us generate LIN master traffic, log responses, validate 19200 baud behavior, test PID `0x4C` / raw ID `0x0C`, verify enhanced checksum handling, and make the XIAO receive path reliable before touching a vehicle.

This does not prove in-car Tesla behavior by itself. Real vehicle wake/sleep timing, noise, grounding, and any active in-car injection still require careful later validation. If no physical Tesla steering-wheel module is on the bench, this setup can validate our electronics and fake/simulated LIN traffic, but it cannot prove a real Tesla module's payload behavior until the module or vehicle bus is connected.

## Ordered Equipment

### Mouser Order

| Item | Part / Listing | Qty | Purpose | Notes |
| --- | --- | ---: | --- | --- |
| Microchip LIN Serial Analyzer | Mouser `579-APGDT001`, manufacturer `APGDT001` | 1 | Real USB-LIN analyzer/master/snooper for PC-side bench work | User-confirmed Mouser listing showed 57 in stock, can ship immediately, unit price `$52.02`, interface type LIN/USB, operating supply 12 V to 14 V. |

APGDT001 is the main new capability. It lets the PC act as the LIN master on the bench, so we are no longer depending on a raw LIN chip plus hand-rolled timing just to create a bus.

### Amazon Cart

| Category | Item | Known ID / Detail | Expected Qty | Purpose | Storage Bucket |
| --- | --- | --- | ---: | --- | --- |
| LIN physical layer | Ready-made TJA1021 TTL UART to LIN breakout modules | ASIN `B0F31584W1` | 2 | XIAO-side LIN transceiver boards only; one primary, one spare. This is not the old bare tiny TJA chip path. | `Tesla LIN - transceivers` |
| Logic protection | DIYables 4-channel logic level shifter pack | ASIN `B0F9NCV286` | 1 pack | Protect XIAO 3.3 V GPIO if module RXD/TXD are 5 V logic | `Tesla LIN - XIAO interface` |
| Bench wiring | Terminal block distribution modules | Teansic 2x6 style, ASIN from prior cart context `B0DL51PXZX` | 1 kit | Clean bus/power breakout instead of loose breadboard wiring | `Tesla LIN - power and terminals` |
| Jumpers | ELEGOO Dupont jumper wires | ASIN `B01EV70C78` | Cart showed 2 packs | Temporary low-current logic connections | `Tesla LIN - jumpers` |
| Power wiring | BNTECHGO 22 AWG red/black silicone wire | ASIN `B07HGT44XY` | 1 | 12-14 V bench power, fused feeds, ground runs | `Tesla LIN - power and terminals` |
| Signal wiring | BNTECHGO 28 AWG silicone wire | Cart item from recovered list | 1 | Thin signal leads and tidy bench harnesses | `Tesla LIN - signal wire` |
| Protection | Mini inline fuse holder kit | MuHize mini fuse kit, ASIN `B08937HX12` | 1 kit | Fuse every 12-14 V bench feed before boards/modules | `Tesla LIN - power and terminals` |
| Reversible connections | WAGO 221 lever nuts | ASIN `B0CJ5QF3VX` | 1 kit | Reusable low-voltage bench joins without twisting/soldering | `Tesla LIN - power and terminals` |
| Vehicle-safe probing | Back-probe kit | 10-piece 0.7 mm back probe kit from cart | 1 | Probe connectors from the back without cutting harnesses | `Tesla LIN - vehicle probing` |
| Test leads | Multimeter/back-probe/piercing lead set | 6-piece lead kit from cart | 1 | Bench measurements and optional nonpreferred piercing leads | `Tesla LIN - vehicle probing` |

Piercing probes are last resort only. Use normal back-probing first. Do not pierce Tesla harness insulation unless there is no connector-safe option and the work has a reason worth the damage risk.

## Existing Equipment To Keep With This Kit

| Item | Current Role |
| --- | --- |
| Adjustable bench power supply | User already has this; use current limit for all first power-on work. |
| Seeed XIAO ESP32-C3 and current firmware/logging path | Embedded side of the test system. Known intended pins: RX on `D3/GPIO5`, TX on `D2/GPIO4`, active-path control later on `D4/GPIO6`. |
| Resistor assortment | Keep available for pull-ups, dividers, and quick safe measurement adapters. |
| FX2/sigrok logic analyzer setup | Secondary capture tool for checking waveform timing and validating APGDT001/XIAO observations. Do not connect raw 12-15 V LIN directly to FX2. |
| USB-C cables / PC tooling | Needed for XIAO serial logs and APGDT001 PC software. |

## Box Organization

Use one labeled project bin: `Tesla LIN Bench`.

Inside it, separate the small parts into these sub-bags or boxes:

| Label | Contents | Rule |
| --- | --- | --- |
| `01 USB-LIN Tool` | APGDT001, USB cable, any Mouser packing slip/manual | This is the master/analyzer. Keep it with documentation. |
| `02 LIN Transceivers` | TJA1021 modules, spare headers, module notes | These replace the raw 8-pin chip path. |
| `03 XIAO Interface` | XIAO boards, level shifters, resistors, short Dupont leads | Nothing in this bag should touch raw vehicle LIN directly. |
| `04 Power Protection` | Fuse holders, fuses, WAGO connectors, terminal blocks, 22 AWG wire | Every 12-14 V feed gets current limit and fuse. |
| `05 Signal Harness` | 28 AWG wire, jumper wires, small labels | Use for short bench harnesses only. |
| `06 Vehicle Probing` | Back probes, multimeter leads, piercing leads | Back probes first; piercing only with explicit reason. |

## Bench Wiring Plan

### PC Master To Bench LIN Bus

Follow the APGDT001 silkscreen/manual for exact terminals. Do not wire by assumed color or pin order.

Expected functional connections:

```text
Bench supply positive, current limited, fused
    -> APGDT001 LIN supply / VBAT if required by tool
    -> TJA1021 module VBAT

Bench supply ground
    -> APGDT001 ground/reference
    -> TJA1021 module ground
    -> XIAO ground

APGDT001 LIN
    -> shared bench LIN bus
    -> TJA1021 module LIN pin
```

Start at 12 V with a low current limit. Raise toward 13.8-14 V only after the bus behaves normally.

### TJA1021 Module To XIAO

The Amazon TJA1021 module is not trusted until measured.

```text
TJA1021 module RXD
    -> measure idle voltage first
    -> level shifter or divider if above 3.3 V
    -> XIAO D3/GPIO5

XIAO D2/GPIO4
    -> level shifter if needed
    -> TJA1021 module TXD

TJA1021 module GND
    -> XIAO GND
```

First XIAO test should be receive-only. Leave XIAO TX inactive until APGDT001-to-XIAO receive logging is reliable.

## What This Equipment Lets Us Test Without A Car

- APGDT001 master-mode LIN frame generation at `19200` baud.
- PID `0x4C` / raw ID `0x0C` polling and logging workflows.
- Enhanced checksum generation and rejection of bad checksums.
- Repeatable schedule timing from the PC-side tool.
- XIAO UART receive reliability through a real LIN transceiver instead of the marginal divider path.
- Safe 12-14 V wiring, fused power distribution, and common-ground discipline.
- Bench-only firmware parsing of 8-byte payloads plus checksum.
- Secondary verification with FX2/sigrok or a scope if the bus looks odd.

## What Still Needs Real Hardware Later

- A physical Tesla steering-wheel module or a live vehicle connection to observe true Tesla responses.
- Confirmation of real wake/sleep behavior and module current draw.
- Confirmation that Tesla's actual master schedule matches our bench schedule assumptions.
- Any in-car active behavior testing. Current evidence supports research and bench work, not customer-car injection approval.

## First Arrival Checklist

1. Photograph the APGDT001, TJA1021 modules, level shifters, and terminal blocks before wiring.
2. Save any Mouser/Microchip paperwork with the project bin.
3. Install Microchip's APGDT001 software on the Windows bench PC.
4. Put the bench supply at 12 V with current limit enabled before connecting modules.
5. Fuse the 12 V feed before it reaches terminal blocks or modules.
6. Power one TJA1021 module alone and measure logic-side RXD idle voltage.
7. If RXD idles above 3.3 V, put the level shifter or resistor divider between RXD and XIAO `D3/GPIO5`.
8. Connect APGDT001 to the bench LIN bus and send a known frame at `19200` baud.
9. Confirm the XIAO logs stable frame activity from the transceiver RXD path.
10. Only after receive is stable, test XIAO transmit on the isolated bench bus.

## Safety Boundaries

- Do not reuse the raw overheated tiny SOIC-8 TJA LIN chip breadboard as the primary path.
- Do not wire a loose/bare tiny TJA chip by guessed pinout. Use only the APGDT001 and measured ready-made breakout modules.
- Do not connect raw 12-15 V LIN directly to XIAO GPIO or FX2 inputs.
- Do not connect XIAO `D2` transmit or `D4` active-path control to a vehicle until bench validation passes and the work is explicitly approved.
- Do not probe DAB/SRS connectors.
- Do not pierce vehicle harness insulation unless back-probing is impossible and the purpose is worth the damage risk.
- Treat APGDT001 and TJA1021 grounds as common with bench supply ground during bench tests.
- Keep every 12-14 V feed fused and current limited during first power-up.

## Known LIN Target Context

Current Tesla Model X steering-wheel LIN assumptions from the existing project context:

| Field | Current Value |
| --- | --- |
| Vehicle side wire | White SW wire is LIN |
| Power | Green is about 15.4 V low-voltage power in vehicle context |
| Ground | Black is ground |
| Baud | `19200` |
| Strongest candidate raw ID | `0x0C` |
| Strongest candidate PID | `0x4C` |
| Frame shape | Break, sync `0x55`, PID, 8 data bytes, enhanced checksum |

## References

- `docs/reports/tesla-modelx-lin-desktop-ai-context-2026-05-18.md`
- `docs/research/responses/2026-05-19-usb-lin-analyzer-master-purchase-search-87122ae9.md`
- `docs/research/responses/2026-05-19-apgdt001-faster-shipping-search-7d48bd47.md`