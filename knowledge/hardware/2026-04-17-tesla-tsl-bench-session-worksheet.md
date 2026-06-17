---
title: "Tesla TSL Bench Session Worksheet"
date: 2026-04-17
category: research
tags: [tesla, tsl5, worksheet, bench, reverse-engineering, automotive, hardware]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-bench-proof-plan.md
  - research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
  - research/hardware/2026-04-17-tesla-tsl-source-matrix.md
  - research/hardware/2026-04-17-tesla-tsl-decision-memo.md
  - hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
  - docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
case_type: customer-linked-research
customer_name: Moti Zaks
customer_phone: +17328061206
---

# Tesla TSL Bench Session Worksheet

## Purpose

This worksheet is the live-session companion to the bench proof plan.

Use it when actually sitting at the bench. It compresses the high-value work into one capture template with checkboxes, expected observations, and branch logic.

## Current Hold — 2026-05-10

- No valid LIN frame has been captured yet; `SCROLL_WHEEL_FRAME_ID` remains unknown.
- Schematics passive-sniffer captures from `2026-05-10_160553`, `_161000`, and `_161248` all show `0` frames.
- For the next physical session, use the passive 4x10k divider/XIAO `D3/GPIO5` path first.
- Keep active TJA1020/TJA1020-family bench wiring unpowered until pinout/orientation is verified against the actual chip and board-measured `SH1020F2S` map.
- Vehicle-side work is still a preflight decision, not a standing instruction to call Moti.

## Research Set Position

This is the execution companion note, not the planning note.

Use it with the bench proof plan, then push confirmed findings back into the case log, source matrix, and family map.

## Session Header

- Date:
- Operator:
- Board ID or label:
- Photo set location:
- Case note to update after session:
- Session objective:

## Pre-Flight Checklist

- [ ] ESD-safe workspace prepared
- [ ] Clean photos possible for both sides of board
- [ ] Continuity meter ready
- [ ] Bench supply ready
- [ ] BLE scan device ready
- [ ] Notes capture method ready
- [ ] No vehicle-side probing planned for this session
- [ ] Passive divider verified with a meter before any 12V source is attached
- [ ] `COM29` XIAO serial path verified
- [ ] `sigrok-cli --scan` shows `fx2lafw:conn=1.40` if using the logic analyzer

## Prior Baseline To Compare Against

- Prior local power-up record: `5.0 V`
- Prior recorded current: about `0.001 A`
- Prior local signal reading: `DIN` measured about `4.2 V` to ground in the recorded idle state at `5.0 V`, while the observed installed lead leaves `DOUT` unpopulated
- Prior BLE note: an iPhone BLE scanner sees the board as `tsl5`, while the device does not appear in the standard iPhone Bluetooth settings menu
- Prior operating-context note: seller says Bluetooth / WeChat is for setup and programming, not a constantly required runtime link, and the unit can be configured to stay on after setup

## Stage 1: Harness Truth Table

### Objective

Resolve whether the installed assembly is truly three-wire and whether `DOUT` is only a pad or a real routed signal.

### Checklist

- [ ] Count connector cavities
- [ ] Mark populated cavities
- [ ] Record wire colors
- [ ] Continuity each conductor to labeled pad or net
- [ ] Determine whether `DOUT` is routed anywhere in the installed harness

### Record Table

| Connector side | Cavity | Populated | Wire color | PCB net or pad | Notes |
| --- | --- | --- | --- | --- | --- |
| Harness | 1 |  |  |  |  |
| Harness | 2 |  |  |  |  |
| Harness | 3 |  |  |  |  |
| Harness | 4 |  |  |  |  |
| Harness | 5 |  |  |  |  |
| Harness | 6 |  |  |  |  |

### Expected Observation

- The currently documented lead appears to use only `DIN`, `VCC`, and `GND`.
- `DOUT` may still exist elsewhere on the board as a pad or alternate harness path.

### Decision Branch

- If `DOUT` is absent from the installed harness: downgrade `full inline proxy` and prioritize `one-way injector` or `observer` models.
- If `DOUT` is routed on the actual installation path: keep `inline proxy` high on the list.

## Stage 2: Sterile Power And BLE Re-Test

### Objective

Verify what the board itself does in a clean environment.

### Checklist

- [ ] Power board from bench supply only
- [ ] Remove likely nearby BLE noise sources
- [ ] Scan for advertiser after power-up
- [ ] Re-scan after waiting
- [ ] Record any services or characteristics seen

### Record Table

| Item | Result |
| --- | --- |
| Supply voltage |  |
| Current limit |  |
| Idle current |  |
| Advertiser seen |  |
| Advertiser name or ID |  |
| Manufacturer data |  |
| GATT services |  |
| Notify characteristics |  |
| Write characteristics |  |
| Strings or version clues |  |

### Expected Observation

- A functioning board may advertise over BLE, but the earlier `FNB58` result is not yet clean enough to trust as final.
- If the suspected `78L33` is active, a logic domain near `3.3 V` is plausible.

### Decision Branch

- If a repeatable advertiser appears and looks vendor-linked: strengthen the `CH571F hosts user-facing control` model.
- If no advertiser appears: document whether the board may require a wake condition or whether the earlier BLE reading was likely a false attribution.

## Stage 3: Rail Map And Current-State Profile

### Objective

Determine whether the board contains a meaningful wired-interface power architecture rather than only a simple radio section.

### Checklist

- [ ] Measure incoming supply at connector
- [ ] Measure suspected regulator input and output
- [ ] Measure current at idle
- [ ] Note any current change during BLE activity
- [ ] Note which major ICs sit on regulated rail

### Record Table

| Node | Voltage | Notes |
| --- | --- | --- |
| Connector `VCC` |  |  |
| Suspected regulator input |  |  |
| Suspected regulator output |  |  |
| `CH571F` supply rail |  |  |
| TI-marked device supply rail |  |  |
| SOIC-8 supply rail |  |  |

### Expected Observation

- A stable logic rail near `3.3 V` would fit the suspected regulator and BLE MCU.
- Multiple powered domains or clearly powered support ICs would argue against the board being a trivial adapter.

### Decision Branch

- If only the radio section appears meaningfully powered: keep the architecture question open.
- If the wired-side ICs are clearly powered and active: strengthen the `serious wired interface board` model.

## Stage 4: Underside Trace Map

### Objective

Tie connector nets to actual silicon roles.

### Checklist

- [ ] Capture sharp underside photos
- [ ] Mark trace paths from connector pads
- [ ] Continuity-test connector nets to major IC pins
- [ ] Note any obvious level shifting, switching, or isolation

### Record Table

| Net | Connected IC or block | Confidence | Notes |
| --- | --- | --- | --- |
| `DIN` |  |  |  |
| `DOUT` |  |  |  |
| `VCC` |  |  |  |
| `GND` |  |  |  |

### Expected Observation

- At least one of the TI device or SOIC-8 should own part of the wired path if the board is more than a radio-trigger board.

### Decision Branch

- If the TI device is on the main signal path: prioritize `proxy`, `translation`, or `injection` theories.
- If only the MCU touches the path directly: reconsider how much external support silicon is actually involved.

## Stage 5: Passive BLE And App-Surface Inventory

### Objective

Collect software-facing clues without trying to drive the board in-car.

### Checklist

- [ ] Enumerate all visible UUIDs
- [ ] Record readable strings
- [ ] Record notify and write endpoints
- [ ] Look for version or update references
- [ ] Note any direct linkage to `TSL电子模块`, `蓝牙版`, or Chinese app identity

### Record Table

| Artifact | Result |
| --- | --- |
| Visible name |  |
| Version string |  |
| Update clue |  |
| App or mini-program clue |  |
| BLE UUID set |  |
| Other notes |  |

### Expected Observation

- The later public ecosystem strongly suggests that at least some `TSL` products expose updateable or app-linked identity.
- For this board specifically, seller context says the app is a setup path rather than a continuously required operating link, so do not treat the lack of a persistent phone connection as evidence that the board is inactive.

### Decision Branch

- If version or app identity appears: place the board more firmly inside the Chinese software ecosystem.
- If identity remains generic: rely more heavily on physical and seller evidence for classification.

## End-Of-Session Decision Box

### Best Current Model After This Session

- [ ] Small one-way wheel-path injector
- [ ] Small inline proxy or MITM board
- [ ] Observer plus timed local injection
- [ ] Still unresolved

### Confidence

- Confidence level `0-5`:

### Highest-Value New Fact Learned

- 

### Biggest Remaining Unknown

- 

### Next Session Should Start With

- 

## Stop Conditions

Stop and update the main case note if any of the following happen:

- You prove whether `DOUT` is or is not part of the installed harness.
- You get a clean repeatable BLE identity tied to the board.
- You prove which major IC actually owns the wired path.

At that point the repo's classification should get materially stronger without needing broader new web research.