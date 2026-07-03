# Current Next Steps - Rev A Model 3 Active Anti-Nag

Updated: 2026-06-17 18:00 (post-bench-verification session)

## ✅ Completed: Bench Verification Gate (2026-06-17)

Firmware v5.5-rev-a-ble flashed and fully verified on the Rev A ESP32-S3 board:

- Serial console: COM6, 115200 baud, responding reliably
- Full boot sequence confirmed: PSRAM enabled, banner printed, NimBLE started, BLE advertising
- All 13 commands tested and passing: version, config, cache, safe:arm, safe:off, bridge:on, bridge:off, nag:on, nag:off, nag:status, nag:once, vol:click, inject:clear, reset
- Cache auto-seeded on boot with 6 Model 3 frame IDs (0x28-0x2D)
- nag:once correctly blocked when not armed (antiNagSingleCycle safety gate)
- BLE init + advertising confirmed via serial console (NimBLE extended advertising — external BLE scanner limitation, not a firmware bug)
- Board left in safe state: armed=no, nag=off, pending=0, bridge=yes

Session worksheet: `logs/sessions/20260617_154311-rev-a-active-tesla-model-3-live-prep-20260617/measurements.md`

## Resume Here — Next Gate: Unpowered Board Measurements

**Tools needed:** Multimeter (continuity + DC voltage)

1. **Power OFF** — disconnect CP2102 USB, no VBAT connected.
2. Measure continuity/resistance between TP1 (GND) and TP2 (3V3) — confirm not shorted.
3. Measure F1 (fuse) continuity — left pad to right pad, should be ~0Ω.
4. Measure TP10 (LIN_A) to TP1 (GND) — confirm not shorted.
5. Measure TP11 (LIN_B) to TP1 (GND) — confirm not shorted.
6. Measure TP10 (LIN_A) to TP11 (LIN_B) — confirm not shorted together.
7. Measure TP6 (UART0_TX) to TP7 (UART0_RX) — confirm not shorted.
8. Measure TP8 (EN) to TP1 (GND) — should be high impedance.
9. Measure TP9 (BOOT) to TP1 (GND) — should be high impedance.
10. Record all readings in the session worksheet.

## After Unpowered Gate → Bench Power Measurements

1. Connect CP2102 (3V3 + GND to TP2/TP1).
2. Measure TP2 (3V3) to TP1 (GND) — should be ~3.3V.
3. If VBAT connected: measure F1 right (VBAT_PROTECTED) to TP1.
4. Measure current draw at idle (if meter supports inline current).
5. Confirm serial console still responds on COM6 (`version`, `config`).
6. Test physical arm behavior: tie GPIO9 high, verify `safe:arm` works. Tie low, verify blocked.
7. Leave board in safe state after measurements.

## After Bench Power Gate → Car Harness Measurements

1. At the vehicle, before connecting the board:
   - Measure vehicle 12V to vehicle ground.
   - Measure car-side LIN idle voltage.
   - Measure wheel-side LIN idle voltage.
   - Verify native wheel controls work normally.
2. Photo of car/wheel connector orientation for reference.

## Live Model 3 Test Order (after all gates pass)

1. Connect only after the bench checklist is complete.
2. Start with `safe:off` and `bridge:off`.
3. Observe `config` / `stats` while connected, with no active injection.
4. Enable bridge only after native wheel behavior is understood.
5. Queue single manual events first: `vol:up:1`, `vol:down:1`, `vol:click:1`.
6. Test `nag:once` before `nag:on`.
7. If the vehicle reacts incorrectly, immediately run `safe:off` and disconnect.

## Keep Later

- Rev B mechanical/layout correction remains blocked by `docs/rev-b-quality-gate-2026-06-16.md`.
- Model X support remains historical/reference until Rev A Model 3 passthrough is proven.
- Right-wheel `0x2B` injection remains not ready; Rev A active injection currently targets left-wheel `0x2A` only.
- BLE external scanner limitation with NimBLE extended advertising — investigate if needed for production, not blocking for bench/car testing.
