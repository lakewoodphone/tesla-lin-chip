# Next Steps - xiao-lin-bench

Updated: 2026-06-16.

Current state: passive bench receive is proven, full no-car evidence passed again after APG reseat, active Model X bench TX is proven, and the Model 3 steering LIN capture succeeded on 2026-05-28. The confirmed left scroll wheel ID is `0x2A` with 7 data bytes; byte[0] is `0x0D` volume up, `0x0B` volume down, `0x2C` click, `0x0C` idle. The right scroll wheel ID is `0x2B` with 6 data bytes. Rev A first-article boards arrived on 2026-06-16 and are suitable for bench electrical bring-up, but not final packaging. The current active work is Rev A bench validation plus Rev B compact mechanical/layout correction, not more ID discovery.

For the complete handoff, read `START_HERE.md` first.
For the deeper implementation plan, read `IMPLEMENTATION_ROADMAP.md`.

## Done

- Passive APG -> TJA1021 -> XIAO receive path validated at 19200 baud.
- Full no-car evidence suite passed 80/80 exact matches across raw IDs `0x00` through `0x3F`.
- USB serial -> secretary API fallback proved while XIAO WiFi was unavailable.
- Model X `0x0C` profile confirmed from real capture and bench replay.
- Active Model X bench TX validated on 2026-05-27:
  - fixed disconnected XIAO D2 -> level shifter LV2 jumper
  - switched TX break generation to half-baud UART `0x00`
  - `model:x` + `antinag:start` produced more than 100 self-received `0x0C` frames
  - enhanced checksums and parity were OK
- APG known-ID raw fallback validated on 2026-05-27:
  - NetworkAnalyser event/display modes still log zero rows for XIAO-generated frames
  - direct PICkitS USART polling sees the external frame bytes
  - `active-apg-raw-proof.ps1` captured 11 checksum-valid `0x0C` rows with `source=raw`
- BLE config service added: model, mode, period, enable, status, and capabilities characteristics; `ble` serial command for diagnostics.
- BLE advertising fixed and verified after replacing invalid NimBLE advertising intervals; active lab builds now report `advertising=yes` cleanly.
- Firmware active safety now reports reset reason, fault count, last fault, and fault lockout; RX-integrity spikes or a dominant-line timeout while armed force output off and require manual `safe:off` before re-arming.
- Car-day launcher now enforces passive preflight and requires XIAO `field_passive` output unless explicitly overridden for bench diagnostics.
- Active proof scripts now require explicit isolated-bench confirmation before any TX test.
- Analyzer can emit a review-only profile candidate file with `--candidate-json`; it must not auto-update firmware profiles.
- Active docs and diagnostics added: `ACTIVE_INJECTOR.md`, `txd:low`, `txd:high`, `txd:uart`.
- Roadmap Phase 0 mostly implemented: build profile split, default passive build, `version/config/safe:off/factory:reset`, NVS config CRC, BLE status/capabilities, safe arm gate, TX rate/session gates, all-env build script, capture session manifest, hardware preflight, and full bench proof wrapper.
- 2026-05-27 evening active self-receive proof passed again: `logs\active-bench-proof-20260527_211924.md`.
- 2026-05-27 APG reseat cleared `CM_PROB_FAILED_START`; quick passive validation passed at `logs\xiao-bench-validation-20260527_211238.log`.
- Full passive evidence suite passed after reseat: `logs\bench-evidence-20260527_211310\bench-evidence-20260527_211310.md` with 80/80 exact matches and 0 APG failures.
- `tools\active-apg-raw-proof.ps1` now preflights APG raw monitor initialization, forces `mode:always` while APG is monitoring, restores `mode:duty`, and passed with 11 APG raw rows at `logs\lin-capture-20260527_212130.csv`.
- Model 3/Y arrival workflow scripts added: `tools\prepare-model3y-car-day.ps1`, `tools\start-model3y-passive-capture.ps1`, `tools\process-model3y-capture.ps1`, and `tools\stage-model3y-active-bench.ps1`.
- Model 3 guided capture completed: `logs\sessions\20260528_211119-guided-tesla-model-3-20260528` with 51,113 parsed frames and saved `analysis-byte-report.txt`.
- Confirmed `0x2A` left wheel and `0x2B` right wheel control bytes; old `0x1A` candidate is superseded.
- Replaced quick `tools\inject-vol-scroll.py` with a logged/counter-aware 0x2A volume proof tool and archived the quick version under `tools\archive\`.
- Added `car_passthrough` dual-transceiver firmware prototype and documentation.
- Rev A first-article board photos archived under `photos/rev-a-first-article-2026-06-16/` with physical review in `docs/rev-a-first-article-2026-06-16.md`.

## Next Work

1. Rev A bench bring-up only: visual inspection, no-short checks, treat USB-C as inaccessible because the receptacle faces inward, use the TP1-TP9 test-pad row for service/recovery if needed, 3V3 validation, current-limited 12V buck validation, passive/default firmware flash, then isolated two-LIN bench validation.
2. Restore steering wheel controls after the short event before any further vehicle-side active work.
3. Bench-build and validate `bench_active_ble` with the corrected `vol:up` / `vol:down` frames.
4. Bench-build `car_passthrough` and validate it only with a two-transceiver fixture or simulator.
5. Extract and validate the right-wheel `0x2B` counter model before any right-wheel injection.
6. Start Rev B as a compact mechanical/layout revision: target the real installation envelope, shrink from the current 100 x 56 mm functional outline toward 60 x 35 mm or a justified 70 x 42 mm fallback, rotate/move/replace USB-C so the opening faces outward on a reachable service edge, and decide connector/pigtail strategy before ordering. Rev B ordering is blocked until `docs/rev-b-quality-gate-2026-06-16.md` passes, including `tools/check-rev-b-layout-gates.ps1`. See `docs/rev-a-first-article-2026-06-16.md`, `docs/final-board-ordering-decision-2026-05-29.md`, `docs/final-chip-architecture.md`, `docs/chip-sourcing-shortlist-2026-05-29.md`, `docs/single-board-rev-a-product-spec-2026-05-29.md`, and `docs/secure-provisioning-anti-cloning-2026-05-29.md`.
7. If APG returns to `CM_PROB_FAILED_START`, recover it by elevated device restart or physical USB replug/reseat before APG-dependent tests.

## Quick Validation Commands

Build current default firmware:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1
```

Passive bench validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM4 -Baud 19200 -BootWaitSeconds 4 -PerFrameTimeoutMs 2500
```

Full no-car evidence:

```powershell
.\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-full -ComPort COM4 -Baud 19200
```

Active Model X bench proof, after enabling `ACTIVE_MODE` and flashing:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x -ConfirmBenchIsolation
```

Expected proof: `stats` shows frames increasing with `badChk=0 badPid=0`; `ring` shows `ID=0x0C PID=0x4C [8B]` frames with enhanced checksum and parity OK.

APG known-ID raw observer proof, bench only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -DurationSeconds 6 -MinFrames 8 -ConfirmBenchIsolation
```

`active-apg-raw-proof.ps1` preflights APG initialization before active TX, forces continuous active mode during APG monitoring, restores duty mode afterward, and exits before transmit if APG is unavailable.

## Car Day Passive Flow

Do not transmit on the vehicle bus.

Preferred wrapper:

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
powershell -NoProfile -ExecutionPolicy Bypass -File tools\start-model3y-passive-capture.ps1 -Model 3 -VehicleId tesla-model-3-YYYYMMDD -Baud 19200 -DurationSeconds 180
```

After capture:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\process-model3y-capture.ps1 -SessionDir logs\sessions\<session-folder>
```

```powershell
cd C:\Users\ezabz\Code\xiao-lin-bench
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 19200 -DurationSeconds 120
```

Fallback only if 19200 shows no traffic:

```powershell
cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 9600 -DurationSeconds 120
```

Analyze after capture:

```powershell
python tools\analyze-lin-capture.py --latest logs\
python tools\analyze-lin-capture.py --latest logs\ --windows logs\sessions\<session>\manifest.json --candidate-json logs\sessions\<session>\model-profile-candidate.json
powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1
```

## Model 3/Y Discovery

Model 3 steering IDs are now confirmed for this vehicle:

```text
0x2A left wheel, 7 bytes: byte[0] 0x0D up / 0x0B down / 0x2C click / 0x0C idle
0x2B right wheel, 6 bytes: same byte[0] pattern, counter model not yet injection-ready
```

For any new Model Y or different trim/year, keep the workflow passive first:

1. Capture idle baseline.
2. Operate scroll up/down, wheel click, and relevant steering controls.
3. Run `tools/analyze-lin-capture.py`.
4. Identify IDs whose payload changes only during the control action.
5. Update `MODEL_PROFILES[]` only after confirmation.
6. To bench-test a reviewed candidate immediately, use `tools/stage-model3y-active-bench.ps1`; it edits the provisional firmware ID, flashes `bench_active_ble`, and runs active proofs on the isolated bench only.

## Hard Stops

- No active transmit/injection on a vehicle bus.
- Do not run bench transmit tools on a vehicle.
- Do not power from uncertain vehicle wires without common ground verified.
- Do not pierce harness insulation unless connector-safe probing is impossible and risk is accepted.
- Do not use active anti-nag references on a customer vehicle.