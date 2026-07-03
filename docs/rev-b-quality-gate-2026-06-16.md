# Rev B Quality Gate - 2026-06-16

Rev A boards arrived on 2026-06-16 and exposed mechanical/layout failures that must not repeat.

## Rev A Failure Summary

Observed from first-article photos and KiCad inspection:

- USB-C receptacle opening faces inward toward the board and is not really accessible.
- The functional PCB outline is 100 x 56 mm, far larger than the intended compact in-car module.
- TP3 and F1 occupy the same coordinate, x=16, y=50. F1 is the 1812 PPTC/current-limit part that may be marked `R050`, so TP3 is blocked in the physical board.
- The bottom test-pad row was treated as a placement convenience, not as a protected fixture interface.
- Mechanical serviceability was not independently proven before ordering.

Rev A is therefore bench bring-up hardware only. It is not a product-form mechanical prototype.

## What Went Wrong In The Process

- ERC/DRC was treated as enough, but ERC/DRC did not catch service direction or practical fixture access.
- Test pads were placed by coordinate instead of being guarded as a no-component zone.
- USB-C orientation was not verified from a 3D/mechanical view with a real cable exit direction.
- The compact-layout target was documented but not enforced by a pre-order gate.
- There was no independent physical-layout audit between generation/routing and manufacturing upload.

## Mandatory Rev B Gates

Rev B must not be ordered until every gate below is complete.

1. **Package target locked**
   - Preferred target: 60 x 35 mm.
   - Fallback target: no larger than 70 x 42 mm, with a written reason.
   - Anything larger requires owner approval before quote upload.

2. **USB-C service direction proven**
   - USB-C must open outward on a reachable service edge or service notch.
   - A 3D KiCad screenshot, mechanical screenshot, or bench mockup photo must be saved before order.
   - A real USB-C cable must be shown clearing the board outline, harness exits, and enclosure/install envelope.

3. **Test-pad row protected**
   - Every test pad must have a unique coordinate.
   - No non-test component center may be within 2.0 mm of a test-pad center.
   - No part may overlap, cover, shadow, or block a test pad.
   - Test pads must be labeled and ordered consistently from one physical side.

4. **Automated physical layout gate passes**
   - Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-rev-b-layout-gates.ps1 `
  -PcbPath hardware\tesla-dual-lin-rev-a\kicad\tesla-dual-lin-rev-b.kicad_pcb `
  -MaxWidthMm 70 `
  -MaxHeightMm 42 `
  -UsbAccessArtifact docs\mechanical\rev-b-usb-service-access.png
```

   - The gate checks board outline, exact footprint center overlaps, required test-pad nets, blocked test pads, and proof artifact presence for USB service access.
   - This script intentionally fails the current Rev A layout.

5. **Manual physical audit completed**
   - Print a 1:1 board outline/component placement PDF or screenshot.
   - Check USB cable insertion direction.
   - Check harness connector/cable exits.
   - Check arm switch reachability.
   - Check antenna/U.FL access.
   - Check that test pads can be touched by pogo pins or hand probes.
   - Save photos/screenshots under `docs/mechanical/` or `photos/`.

6. **KiCad checks completed**
   - ERC passes.
   - DRC passes.
   - 3D viewer reviewed.
   - Gerber viewer reviewed after export.
   - Pick-and-place/CPL preview reviewed for all assembled parts.

7. **Pre-order signoff packet created**
   - Schematic PDF.
   - Board PDF or screenshots, top and bottom.
   - 3D USB service screenshot.
   - Gerber preview screenshot.
   - BOM/CPL review note.
   - Physical layout gate output.
   - Known risks and explicit owner approval for order.

## Rev B Layout Requirements

- Move F1 away from the test-pad row or make the protected side of F1 the explicitly labeled VBAT_PROTECTED test point.
- Keep all power-protection parts near the input connector, but not on top of fixture pads.
- Keep LIN_A and LIN_B protection near their harness entries.
- Move USB-C to a real service edge, with the opening facing outward.
- Collapse long routing runs and large empty regions.
- Preserve safe defaults: LIN TX disabled when unarmed, reset, blank, booting, or faulted.
- Preserve physical arm gate and protected 12 V input.
- Preserve UART/EN/BOOT recovery access even if USB is unavailable.

## Rev A Bench Path After Findings

Use Rev A only for controlled bench learning:

1. No vehicle connection.
2. No active/passthrough LIN tests until isolated bench evidence is clean.
3. Do not force the inward-facing USB-C connector.
4. Treat TP3 as inaccessible because F1/R050 blocks it.
5. Use TP1, TP6, TP7, TP8, and TP9 for UART recovery/programming if needed.
6. Probe F1 pad 2 only if protected VBAT must be measured.

## One-At-A-Time Bring-Up Sequence

Stop after each step and record pass/fail before moving on.

1. Photograph the exact board side and orientation being tested.
2. Visual inspection under magnification.
3. Continuity/no-short checks with no power attached.
4. Identify UART pads and confirm the USB-UART adapter is 3.3 V logic.
5. Try UART bootloader entry without 12 V attached.
6. If UART works, flash passive/default firmware.
7. Current-limited 12 V input test.
8. Verify 3V3 rail and reset behavior.
9. Isolated LIN bench validation, passive first.
10. Only after bench evidence: evaluate whether Rev A is worth any further rework.