# Rev A First Article Physical Review - 2026-06-16

Board photos were received from the owner on 2026-06-16 and archived under:

```text
photos/rev-a-first-article-2026-06-16/
```

## Photo Files

- `tesla-dual-lin-rev-a-board-arrival-01.HEIC` / `.jpg`
- `tesla-dual-lin-rev-a-board-arrival-02.HEIC` / `.jpg`
- `tesla-dual-lin-rev-a-board-arrival-03.HEIC` / `.jpg`
- `tesla-dual-lin-rev-a-board-arrival-04.HEIC` / `.jpg`

## Physical Read

Rev A is useful as an electrical first-article and bench bring-up board, but it is not the intended product form factor.

Main physical issues from the photos:

- The delivered assembly is visually massive. The JLC/assembly handling rails and side tabs make the received panel larger than the KiCad functional outline, but even the intended board outline is still too large for an in-car inline module.
- The KiCad board outline is 100 x 56 mm, while the earlier placement-zone target was 60 x 35 mm. The board area is therefore roughly 2.7x the target package.
- There is a large amount of empty board area and long parallel routing. This made first-pass routing easier, but it is not a compact harness-adapter layout.
- USB-C is not just awkward: the receptacle opening faces inward toward the board instead of outward toward a serviceable edge. The owner confirmed it is not really accessible. This is a Rev A mechanical/layout error. Treat Rev A USB-C as inaccessible unless a specific physical cable fit is proven on the bench.
- Through-hole harness connector positions appear unpopulated in the first-article photos, matching the prior SMT-first PCBA assumption. Connector population/adapter pigtail work remains a separate physical step before vehicle use.

## Rev A Usefulness

Rev A should be treated as:

- Bench electrical bring-up hardware.
- Firmware flashing and USB-service validation hardware.
- Dual LIN transceiver validation hardware after connector/pigtail setup.
- A layout lesson for Rev B, not a product-shape success.

Rev A should not be treated as:

- Final in-car packaging.
- A compact inline harness dongle.
- Proof that the mechanical design is acceptable.

## Inaccessible USB-C Workaround

Do not force a USB-C cable into the inward-facing connector.

Do not mechanically pull individual USB-C connector pins as a first move. The J1 front pad row carries GND, USB_VBUS, CC1/CC2, USB_D_PLUS, and USB_D_MINUS; tearing or bending those pads can lift traces or create a VBUS/GND/data short. If J1 must be reworked, prefer controlled hot-air removal under magnification, or leave J1 alone and use the test pads below.

The KiCad layout includes a straight top-side test-pad row at y=50 mm that can be used for bench bring-up or recovery if the physical pads are reachable:

Physical locator: with the component side facing up and the Espressif ESP32-S3 module visible toward the lower/right side of the board, the test pads are the small round gold circles running along the lower long edge. CAD intended 20 pads, but Rev A has a placement defect at TP3: F1, the 1812 PPTC fuse/current-limit part that may be marked `R050`, is centered at the exact same coordinate as TP3. In practice, expect 19 obvious round test pads plus F1 sitting where TP3 should have been. Left-to-right in this orientation is TP1, TP2, then the F1/TP3 overlap, then TP4 through TP20.

| Pad | Net | Coordinate |
|---|---|---|
| TP1 | GND | x=7, y=50 |
| TP2 | 3V3 | x=11.5, y=50 |
| TP3 | VBAT_PROTECTED | x=16, y=50; blocked/overlapped by F1 on Rev A |
| TP4 | USB_D_MINUS | x=20.5, y=50 |
| TP5 | USB_D_PLUS | x=25, y=50 |
| TP6 | UART0_TX | x=29.5, y=50 |
| TP7 | UART0_RX | x=34, y=50 |
| TP8 | EN | x=38.5, y=50 |
| TP9 | BOOT_GPIO0 | x=43, y=50 |
| TP10-TP20 | LIN/test/control nets | x=47.5 through 92.5, y=50 |

Preferred Rev A service approach:

1. Use the test-pad row, not the Type-C connector, for first bring-up.
2. Start with continuity/no-short checks on TP1, TP2, TP4, TP5, LIN_A, and LIN_B. Do not assume TP3 is accessible.
3. For firmware recovery/programming, prefer a 3.3 V UART adapter on TP6/TP7/GND with EN/BOOT control on TP8/TP9, or a pogo/soldered USB D+/D- breakout on TP4/TP5 only after power strategy is reviewed.
4. Do not backfeed unknown USB power paths. If powering from the bench, use a current-limited supply and verify the intended rail before attaching data lines.
5. Treat any soldered service wires as temporary bench rework only. They are not a production or in-car service solution.

F1/TP3 detail:

- F1 is at x=16, y=50, the same coordinate as TP3. This should not have happened.
- F1 pad 1 is `VBAT_IN` at approximately x=13.86, y=50.
- F1 pad 2 is `VBAT_PROTECTED` at approximately x=18.14, y=50.
- If a protected VBAT measurement is needed, probe F1 pad 2 carefully. Do not bridge F1 pad 1 to pad 2, and do not short either side to TP1/GND or adjacent pads.
- Rev B must move TP3 away from F1 or remove TP3 and label the protected-side fuse terminal/test point explicitly.

## Rev B Required Direction

Rev B should be a mechanical/layout revision, not just a small cleanup.

Required changes:

1. Retarget the outline around a real installation envelope, preferably near 60 x 35 mm if routing allows, or a deliberately justified fallback such as 70 x 42 mm.
2. Remove first-article sprawl: collapse the LIN transceivers toward their harness connectors, keep protection at the entries, and shorten long cross-board routes.
3. Decide the actual installed orientation before USB placement. USB-C must exit toward the reachable service side, not inward toward the board interior.
4. Move USB-C to a dedicated service edge or service notch, rotate/replace the footprint so the receptacle opening faces outward, and verify connector opening orientation in 3D before ordering.
5. Keep the ESP32-S3 antenna/U.FL access clear, but do not let RF keepout become a giant unused board region.
6. Define whether Rev B uses populated board connectors, solder pads plus pigtails, or a smaller adapter-harness strategy.
7. Keep Rev A safety gates: LIN TX disabled by default, physical arm gate, protected 12V input, and bench-only active validation before any vehicle-side TX.

## Immediate Bring-Up Guardrails

Before vehicle-side use:

1. Visual inspection under magnification.
2. Confirm no shorts between VBAT, 3V3, GND, USB_VBUS, LIN_A, and LIN_B.
3. Assume USB-C is inaccessible. Do not force a cable into the inward-facing connector.
4. Use TP1-TP9 for bench service/recovery if needed: GND, 3V3, VBAT_PROTECTED, USB_D-/D+, UART0 TX/RX, EN, and BOOT.
5. USB-only power-up is no longer the default path unless a cable fit is proven; otherwise use the test-pad row and current-limited bench power.
6. Bench power 12V input with current limit and verify buck output before attaching any LIN bus.
7. Flash passive/default firmware first.
8. Validate both LIN channels only on an isolated bench fixture.
9. Do not connect to vehicle LIN for active/passthrough tests until bench evidence is clean and connector/pigtail mapping is verified.

## Bench Continuity Test Log — 2026-06-17

All measurements taken unpowered, component side up, multimeter in resistance/continuity mode.

| Check | Probe A | Probe B | Expected | Result | Status |
|---|---|---|---|---|---|
| A | TP1 (GND) | TP2 (3V3) | High / no short | 79 kΩ rising | ✓ PASS |
| B | TP1 (GND) | F1 left pad (VBAT_IN) | High / no short | 1.2 MΩ rising | ✓ PASS |
| C | TP1 (GND) | F1 right pad (VBAT_PROTECTED) | High / no short | ~1.2 MΩ rising | ✓ PASS |
| D | F1 left pad (VBAT_IN) | F1 right pad (VBAT_PROTECTED) | Low / beep (fuse intact) | Beep | ✓ PASS |
| E | TP1 (GND) | TP10 (LIN_A) | High / no short | OL | ✓ PASS |
| F | TP1 (GND) | TP11 (LIN_B) | High / no short | OL | ✓ PASS |
| G | TP10 (LIN_A) | TP11 (LIN_B) | High / no short (channels isolated) | OL | ✓ PASS |

Rising resistance readings on Checks A–C are expected: the multimeter is charging the rail bypass capacitors.
All 7 checks passed. No power-rail shorts, no blown fuse, no LIN-to-GND shorts, LIN channels isolated from each other. Board is clear for UART adapter bring-up.