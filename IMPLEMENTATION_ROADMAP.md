# Tesla LIN Bench Implementation Roadmap

Updated: 2026-05-27

This is the implementation roadmap for making the Tesla LIN bench, passive car-testing workflow, and final active-capable chip more robust. It is intentionally practical: every phase has concrete build items, test evidence, and exit gates.

## Current Baseline

The project is no longer a loose experiment. The current baseline is:

- Firmware v5.1 builds and runs on the Seeed XIAO ESP32-C3.
- Default build is `field_passive`; active lab firmware is explicit via `bench_active_ble` or `chip_lab_active`.
- Passive APG -> TJA1021 -> level shifter -> XIAO receive path is proven at 19200 baud.
- Full no-car evidence passed: 80/80 exact APG -> XIAO matches across raw IDs `0x00` through `0x3F`.
- Model X active bench TX is proven on the isolated bench via XIAO self-receive and APG known-ID raw fallback.
- BLE active-lab builds compile with `NO_WIFI` and advertise as `TeslaAntiNag`, exposing model, mode, period, enable, status, and capabilities characteristics.
- Latest evening bench revalidation passed active XIAO self-receive and BLE advertising proof; new APG-dependent proof is blocked by the APGDT001 Windows `CM_PROB_FAILED_START` state until device recovery.
- Vehicle work is still passive-only. Model 3/Y steering IDs are candidates, not confirmed.

## Non-Negotiable Design Rules

1. Vehicle work starts passive-only. No transmit commands, active scripts, or active hardware driving on a real vehicle until a separate safety review and controlled-test gate are complete.
2. The final chip must be fail-safe at the hardware level, not only by operator discipline. Reset, crash, brownout, BLE loss, firmware exception, or cable fault must leave the vehicle bus passive.
3. Bench evidence must be repeatable from one command. A passing manual session is useful, but the roadmap gates require saved logs, summaries, and machine-checkable pass/fail results.
4. Field firmware must be vehicle-safe by default. Active lab firmware can exist, but the default field profile should be passive unless the build target explicitly says active lab.
5. Model 3/Y active behavior is blocked until passive capture proves the steering/control IDs and payload semantics.
6. Any active-capable final chip must include physical arming, software arming, rate limits, bus-idle gating, health monitoring, and an immediate off path.

## Gap Analysis

### Firmware Gaps

- DONE: `field_passive` is the repo default. Active output is compiled only in explicit active-lab environments.
- DONE: BLE/model/mode/period settings persist in NVS with version, CRC, and safe boot defaults.
- BLE is unauthenticated. Add pairing/passkey or a local physical-arm requirement before accepting write commands.
- The BLE advertising retry was corrected to use boolean success and retry throttling, but phone-app BLE write testing still needs a captured proof log.
- DONE: The custom `tx:` parser uses a shared auto-base parser; `0C`, `0x0C`, and `0d12` are predictable.
- DONE: `NO_WIFI`, passive, and active builds are verified by `tools/build-all-envs.ps1`.
- DONE: Firmware has frame counters, stats, and a persisted active event log for boot, arming, disarming, config changes, starts/stops, inhibits, and faults.
- DONE: Active safety now records reset reason, last fault, fault count, fault lockout, RX-integrity lockout, dominant-line timeout lockout, rate limits, bus-busy inhibit, active timeout, and an `events` log with NVS persisted recent slots.

### Bench Gaps

- Active Model X self-receive proof is good, but the bench still needs a single master proof that runs passive, active self-receive, APG raw observer, BLE write, power-cycle persistence, and final stop-state verification once the APG is recovered.
- APG event/display mode still misses XIAO-generated active frames. Keep raw fallback for known-ID active bench proof, and add a logic-analyzer proof path so APG is not the only independent observer.
- Hardware wiring is still jumper-based. Build a keyed fixture with strain relief, labels, test pads, and continuity checks.
- TXD low/high diagnostics are manual. Automate a preflight that asks for measured voltages and records them in the proof artifact.
- The bench should include simulated fault cases: missing ground, SLP low, disconnected TX jumper, wrong level-shifter channel, COM port busy, APG absent, WiFi absent, and secretary API down.

### Car-Testing Gaps

- Car-day tooling is passive in intent, but the workflow should make it harder to accidentally run active commands. Add a dedicated passive field build and a field preflight that checks firmware build target.
- The capture plan needs a structured action matrix: idle baseline, steering scroll up/down, wheel click, stalks, seat belt, doors, lock/unlock, HVAC, gear state, and Autopilot UI state where safe.
- Model 3/Y candidate IDs `0x1A` and `0x1B` need confidence scoring based on repeated passive captures, not one anecdotal change.
- Captures need a durable manifest that records vehicle, trim, date, location type, cable point, baud, APG mode, XIAO firmware hash, and operator notes.
- The analyzer should emit a ranked ID-change report with before/during/after windows and payload-byte deltas.

### Final Active Chip Gaps

- No PCB architecture is frozen yet. The final chip needs a formal hardware design with power protection, ESD protection, watchdog, arm switch, status LEDs, programming pads, and a passive default path.
- Current XIAO firmware is a prototype. Final firmware needs build-time product modes, config schema, persisted state, authenticated BLE, crash recovery, telemetry, and manufacturing self-test.
- The final active-capable chip must be validated on a bench harness and closed controlled test setup before any real driving context is considered.
- The final enclosure and harness need automotive strain relief, keyed connectors, insulation, thermal margin, and a way to remove or bypass the device quickly.

## Phase 0 - Stabilize The Current Baseline

Goal: make the current v5 state clean, buildable, and safe to resume.

Work items:

| ID | Task | Output | Gate |
|---|---|---|---|
| P0.1 | Split PlatformIO environments: `field_passive`, `bench_active_ble`, `chip_lab_active` | DONE: `platformio.ini` envs | All envs compile |
| P0.2 | Make `field_passive` the safest documented car-day build | DONE: README + START_HERE update | Car-day docs reference passive env first |
| P0.3 | Replace serial numeric parsing with shared auto-base parser | DONE: serial `tx:` token parser | `tx:0C,...`, `tx:0x0C,...`, and decimal-prefixed `0d12` are predictable |
| P0.4 | Compile `NO_WIFI`, passive, and active builds | DONE: `tools/build-all-envs.ps1` | 4/4 envs compile |
| P0.5 | Remove or document deprecated NimBLE `bleService->start()` warning | DONE: no-op removed | Build has no avoidable warnings |
| P0.6 | Add a `version` serial command | DONE: firmware/build mode string | Logs identify firmware without guesswork |

Exit gate:

- Fresh clone builds all supported environments.
- `START_HERE.md` and this roadmap agree on the current default and hard stops.
- The physical XIAO can be flashed with active bench firmware and passive field firmware without manual code edits.

## Phase 1 - Bench Robustness Sprint

Goal: turn the bench from a working prototype into a repeatable hardware-in-the-loop validation rig.

### Firmware Improvements

- DONE: Add persisted config in NVS:
  - model: `x`, `3`, `y`, `auto`
  - mode: `duty`, `always`
  - period: 5000-120000 ms
  - enable state defaults to `off` after reboot unless explicitly configured for bench tests
  - config version and CRC
- DONE: Add a `config` serial command to print the stored config and runtime config.
- DONE: Add `factory:reset` and `safe:off` serial commands.
- PARTIAL: Add a TX inhibit state machine:
  - disabled by default
  - software armed
  - physically armed (still a hardware/PCB task; current firmware has explicit software arm)
  - bus quiet
  - fault-free
  - active timeout not exceeded
- DONE: Add explicit inhibit logging: `TX inhibited: reason=bus_busy`, `reason=not_armed`, `reason=fault`, etc.
- DONE: Add TX budget limits:
  - maximum frames per second
  - maximum active session duration
  - maximum consecutive failures before forced off
- Add final neutral/stop behavior after any active burst.
- DONE: Add health output fields: build mode, reset reason, BLE status, arm status, active state, TX count, inhibit count, last inhibit, fault count, last fault, and fault lockout.

### BLE Improvements

- DONE: Add a read-only status characteristic:
  - firmware version
  - build mode
  - current model
  - active state
  - fault state
  - TX count
  - last inhibit reason
- DONE: Add a read-only capabilities characteristic so a phone app can detect supported fields.
- DONE: Add write validation responses by updating characteristic values to accepted values only.
- PARTIAL: Add authentication or physical-arm gating for write operations. Current implementation requires serial `safe:arm`; BLE pairing/passkey and physical arm are still final-chip tasks.
- Test with nRF Connect or LightBlue and save a BLE proof log:
  - scan sees `TeslaAntiNag`
  - service UUID present
  - writes to model/mode/period/enable accepted
  - invalid values rejected
  - `off` always stops TX
  - power cycle returns to safe default

### Bench Tooling

- DONE: Create `tools/full-bench-proof.ps1` that runs:
  - build metadata capture
  - COM/APG discovery
  - passive validation
  - quick evidence suite
  - active Model X self-receive proof when `-RunActive` is supplied and isolated-bench confirmation is given
  - APG raw observer proof when `-RunActive` is supplied and isolated-bench confirmation is given
  - BLE serial status check
  - forced `antinag:stop`
  - final `stats` and `ring`
- DONE: Add `tools/preflight-hardware-check.ps1` for continuity and voltage prompts:
  - SLP high
  - 12V present
  - common ground
  - D2 -> LV2 -> HV2 continuity
  - D3 RX chain continuity
  - TX path disconnected before passive field mode
- Add logic analyzer capture support if hardware is available:
  - capture LIN wire during active bench TX
  - save waveform/screenshot
  - compare APG raw rows, XIAO ring, and analyzer trace
- Add failure fixtures or scripted negative tests for missing APG, wrong COM port, COM busy, WiFi down, API down, and disconnected TX jumper.

### Bench Hardware

- Move the jumper bench to a labeled fixture:
  - keyed power input
  - APG LIN/GND/12V connector
  - XIAO module mount
  - TJA1021 mount
  - level shifter mount
  - D2/D3 test pads
  - LIN, TXD, RXD, SLP, 3V3, 5V, 12V, and GND test pads
  - physical TX enable jumper/switch
- Add a laminated wiring card and QR/link to `START_HERE.md`.

Exit gate:

- One command produces a passing bench artifact set.
- Artifacts include firmware version, build mode, exact commands, serial logs, APG logs, and summary markdown.
- Power cycling the XIAO leaves active output off unless a bench-only test explicitly enables it.
- BLE proof passes from a phone app.

## Phase 2 - Passive Car Testing

Goal: collect real vehicle truth without transmitting.

Hard rule: no active TX on the vehicle bus in this phase.

### Pre-Car Prep

- Flash the `field_passive` firmware environment.
- Run quick bench evidence after flashing.
- Run `version`, `stats`, and `ring` and save the output.
- Pack:
  - APGDT001
  - XIAO passive sniffer
  - TJA1021 fixture
  - known-good USB cables
  - ground jumper
  - back-probes
  - 12V supply or safe battery clip only if needed
  - laptop with 32-bit PowerShell path verified
  - phone BLE scanner only for bench, not needed for passive car capture

### Capture Sessions

Run separate labeled captures rather than one long ambiguous file:

| Session | Duration | Actions | Expected Output |
|---|---:|---|---|
| baseline-idle | 120s | no controls touched | stable ID inventory |
| steering-scroll-up | 60s | repeated scroll up only | candidate byte deltas |
| steering-scroll-down | 60s | repeated scroll down only | opposite byte deltas |
| wheel-click | 60s | click/touch/release | button bits |
| autopilot-ui-state | 60s | UI state changes only if safe | correlation notes |
| body-controls | 120s | doors/locks/windows/HVAC as relevant | separate non-steering IDs |
| baud-fallback | 60s | repeat at 9600 only if no 19200 traffic | fallback evidence |

Each capture should record:

- vehicle model/year/trim
- capture point and wire colors
- baud
- APG mode
- XIAO firmware version/build mode
- exact action timestamps
- photos of non-invasive probe setup
- raw APG CSV/TXT
- XIAO serial log if available
- analyzer JSON summary

### Analyzer Improvements

- DONE: Add windowed action markers to `analyze-lin-capture.py`.
- DONE: Rank IDs by action correlation:
  - appears only during action
  - payload byte changes during action
  - rolling counter behavior
  - checksum validity
  - idle stability
- DONE: Emit a review-only model profile candidate JSON with `--candidate-json`; it explicitly says firmware updates are blocked until repeated passive captures agree.
- Add report sections for confirmed, candidate, unrelated, and noisy IDs.

Exit gate:

- Model X capture reconfirms `0x0C` and payload semantics.
- Model 3/Y capture either confirms or rejects `0x1A`/`0x1B` as steering candidates.
- At least two repeated passive captures agree before updating firmware profiles.
- No active command was run on a vehicle bus.

## Phase 3 - Controlled Active Validation Planning

Goal: define the controlled test sequence for any future active-capable validation without treating a public road as a lab.

Prerequisites:

- Phase 1 bench gate passed.
- Phase 2 passive vehicle ID confidence passed.
- A passive field firmware and active lab firmware are separate build targets.
- Hardware includes physical arm switch and fail-passive default.
- Owner explicitly accepts the safety/legal boundary for a controlled private test.

Controlled active validation should start with the safest possible setup:

1. Reproduce target bus on bench with real captured frames and simulated master timing.
2. Validate active behavior against replayed captures before touching a vehicle.
3. Validate final neutral/off behavior and no dominant-line lockup.
4. If ever tested on a vehicle, use a stationary controlled setup first, with active TX physically disconnected until final confirmation.
5. Use a second observer: APG, logic analyzer, or both.
6. Keep a human-accessible hardware kill/off path within reach.

Exit gate:

- A written controlled-test plan exists with rollback, stop conditions, and proof artifacts.
- The chip demonstrably returns to passive on reset, crash, power loss, BLE disconnect, and timeout.
- Active behavior is never enabled by default after power-up.

## Phase 4 - Final Active-Capable Chip Architecture

Goal: turn the bench prototype into a hardware design that is passive by default and active only under deliberate, observable, reversible conditions.

### Hardware Architecture

Recommended blocks:

- Automotive-safe power front end:
  - fuse or resettable protection
  - reverse polarity protection
  - load-dump/transient protection
  - TVS diode on vehicle power
  - buck regulator with thermal margin
- LIN front end:
  - automotive LIN transceiver rated for 12V environments
  - ESD protection on LIN
  - test pad for LIN bus voltage
  - optional separate passive sniffer and active driver paths
- Active gate:
  - hardware TX enable controlled by MCU and physical arm
  - default TX disabled via pull-down/pull-up chosen so reset means passive
  - indicator LED for active arm state
  - optional inline jumper that physically removes TX drive
- MCU/debug:
  - SWD/UART programming pads
  - boot/flash pads accessible but protected
  - watchdog/reset circuit
  - status LEDs: power, passive RX, armed, active TX, fault
- Mechanical:
  - keyed connectors
  - strain relief
  - insulated enclosure
  - service label with firmware version and safe-removal note

### Firmware Architecture

- Build modes:
  - `field_passive`: no TX code compiled in
  - `bench_active_ble`: active bench proof mode
  - `chip_lab_active`: final active-capable lab mode with all gates enabled
- Boot sequence:
  - start passive
  - read config with CRC
  - verify hardware arm state
  - advertise BLE/status
  - never start active output automatically
- State machine:
  - `SAFE_PASSIVE`
  - `ARMED_IDLE`
  - `ACTIVE_DUTY`
  - `FAULT_LOCKOUT`
  - `SERVICE_DIAGNOSTIC`
- Faults that force `SAFE_PASSIVE` or `FAULT_LOCKOUT`:
  - bus dominant too long
  - checksum/parity spike
  - unexpected baud / sync loss
  - excessive TX rate
  - BLE write invalid too many times
  - watchdog reset
  - brownout reset
  - physical arm removed
- Data logging:
  - boot reason
  - firmware version
  - config CRC
  - arming/disarming events
  - every TX burst summary
  - last N faults

### Manufacturing/Test Jig

- Bed-of-nails or cable test fixture for:
  - power draw
  - regulator voltage
  - LIN RX decode
  - TX enable off by default
  - TX waveform when armed
  - BLE scan and characteristic read
  - firmware version command
  - reset returns passive
- Serial number and firmware hash should be printed in the final test report.

Exit gate:

- Rev A PCB passes bench passive, active bench, power-cycle, reset, fault-injection, BLE, and final-off tests.
- Rev B only happens after Rev A failure notes are closed.
- Final chip has a documented removal/bypass path.

## Phase 5 - Data And Operations Layer

Goal: make evidence easy to inspect and hard to lose.

Work items:

- DONE: Add a capture manifest format under `logs/`.
- DONE: Add `tools/new-capture-session.ps1` to create a folder with manifest, commands, and checklists.
- DONE: Add `tools/collect-artifacts.ps1` to bundle APG logs, XIAO logs, analyzer JSON, photos, and summary markdown.
- Add secretary-side dashboard or report surface for LIN sessions:
  - total frames
  - unique IDs
  - bad checksum/parity
  - action windows
  - candidate IDs
  - artifacts link
- Create an issue template for new vehicle captures and profile updates.

Exit gate:

- Every bench/car session has a single folder with a manifest and summary.
- A new contributor can inspect a capture without reading chat history.

## Phase 6 - Release Gates

### Bench Gate

Required before any car session:

- `field_passive` build succeeds.
- `bench_active_ble` build succeeds.
- quick evidence suite passes.
- active bench proof passes on isolated bench.
- APG raw observer proof passes for known Model X stream.
- BLE phone proof passes.
- power cycle returns to safe default.
- final `stats` has no bad checksum/parity spike.

### Passive Car Gate

Required before any profile update:

- at least two passive captures agree on target IDs.
- analyzer report ranks the same ID(s) for action windows.
- payload bytes are mapped with idle/up/down/click evidence.
- no active script or command was run on the vehicle.
- docs updated with confidence and uncertainty.

### Final Active-Capable Chip Gate

Required before calling hardware final:

- hardware defaults passive on reset, brownout, firmware crash, and unarmed state.
- physical arm and software arm are both required for TX.
- BLE cannot enable active output unless physical arm is present.
- active session has a timeout and final neutral/off behavior.
- line dominant fault forces lockout.
- watchdog reset reason is logged.
- final test jig report passes.
- enclosure/harness strain relief passes bench handling.

## Immediate Next 12 Actions

1. Flash `field_passive` and verify `version`/`config` output on COM4 before any car capture.
2. Run enforced passive preflight with `tools/preflight-hardware-check.ps1 -Mode car-passive -RequirePass`.
3. Run `tools/new-capture-session.ps1 -Mode car-passive` and keep all APG/XIAO/analyzer artifacts in the session folder.
4. Run passive Model X/3/Y captures and update model confidence from repeated passive evidence only.
5. Use `tools/analyze-lin-capture.py --windows manifest.json --candidate-json model-profile-candidate.json` after each capture.
6. Complete BLE phone proof on isolated bench and save screenshots/export in the proof folder.
7. Build the labeled bench fixture with physical TX enable switch and test pads.
8. Add logic-analyzer proof if the hardware is available.
9. Exercise the persistent event log on hardware and add its output to bench proof artifacts.
10. Add final-chip physical-arm GPIO support once hardware exists.
11. Add secretary-side LIN session report surface for manifest-backed captures.
12. Keep active validation blocked until passive IDs, hardware gate, written controlled-test plan, and owner decision are complete.

## Open Decisions

- Should the repo default stay active bench, or should `field_passive` become the default environment? Recommendation: default to passive field and make active explicit.
- Should BLE writes require passkey pairing, a physical arm, or both? Recommendation: both for the final chip; physical arm only may be enough for bench firmware.
- Should the final chip be a parallel sniffer/driver or an inline gateway? Recommendation: decide after passive car captures reveal bus topology and timing.
- Should WiFi stay in final firmware, or should USB/BLE-only logging be preferred? Recommendation: keep WiFi optional; do not let cloud/API failure affect local safe behavior.
- What is the acceptable controlled-test environment for active-capable validation? This needs owner decision before Phase 3 exits.

## Documentation Rules Going Forward

- Keep `START_HERE.md` short and current.
- Keep historical handoffs in `docs/archive/`.
- Record each bench or car session in `audit-logs/` or a capture manifest.
- Do not rely on chat history as the only source of truth.
- Update this roadmap when a gate is passed or invalidated.