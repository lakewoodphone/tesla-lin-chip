---
title: "Tesla TSL Bench-First Proof Plan"
date: 2026-04-17
category: research
tags: [tesla, tsl5, tsl6, bench-plan, reverse-engineering, automotive, hardware]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
  - research/hardware/2026-04-17-tesla-tsl-source-matrix.md
  - research/hardware/2026-04-17-tesla-tsl-decision-memo.md
  - research/hardware/2026-04-17-tesla-tsl-bench-session-worksheet.md
  - research/hardware/2026-04-18-tesla-multi-board-diagnostic-comparison-plan.md
  - research/hardware/2026-04-18-tesla-multi-board-comparison-worksheet.md
  - hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
  - docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
case_type: customer-linked-research
customer_name: Moti Zaks
customer_phone: +17328061206
---

# Tesla TSL Bench-First Proof Plan

## Purpose

This note turns the remaining Tesla `TSL5` mechanism uncertainty into a ranked bench program.

The goal is not to make the module work in a car. The goal is to collapse uncertainty at the board level, with the fewest destructive steps and the highest information gain per hour.

## Current Hold — 2026-05-10

- Source docs were reconciled from this curated set, `C:\Users\ezabz\Code\lpt-hub`, old chat context, and `C:\Users\ezabz\Code\Schematics`.
- The exact `SCROLL_WHEEL_FRAME_ID` and payload are still unknown.
- The Schematics passive vehicle-sniffer branch exists and uses XIAO `D3/GPIO5` through a 4x10k divider, but its three saved 2026-05-10 captures produced `0` LIN frames.
- `sigrok-cli` is installed and the FX2 analyzer scans as `fx2lafw:conn=1.40`.
- The active TJA1020 bench wiring path is paused until the generic TJA1020 breadboard guide is reconciled with the board-measured `SH1020F2S` / TJA1020-family pin map.
- Do not call for a Tesla visit until the passive divider, COM29 sniffer, and backprobe kit are preflighted.

## Research Set Position

This is the planning layer between the synthesis notes and the live worksheet.

Use it after the family map, source matrix, and decision memo have defined what still needs proof.

If multiple boards are available, start with the multi-board comparison plan and worksheet first, then come back to this note for the one board selected as the best deep-dive target.

## Customer / Case Linkage

- Customer: Moti Zaks
- Phone: (732) 806-1206
- Ticket: Unknown
- Order: Unknown
- Work Order ID: Unknown
- Related Case Log: hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
- Related Sync Record: docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
- Related Main Note: research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
- Related Source Matrix: research/hardware/2026-04-17-tesla-tsl-source-matrix.md

## Operating Rules

- Stay non-destructive until the continuity and trace picture is complete.
- Prefer measurements that collapse multiple theories at once.
- Treat public internet claims as hypothesis generators, not proof.
- Do not escalate to vehicle-side testing until the bench evidence says which wired path actually matters.

## Ranked Checks

| Rank | Check | Main Question Resolved | Expected Info Gain | Risk |
| --- | --- | --- | --- | --- |
| 1 | Full harness and connector truth table | Is the seized board truly using a 3-wire path, and is `DOUT` actually present in the installed assembly? | Very high | Very low |
| 2 | Sterile power and BLE re-test | Did the earlier `FNB58` advertiser belong to the board, and what does the module expose when isolated? | Very high | Very low |
| 3 | Rail map and current-state profile | Is the board a simple BLE tag, or a more serious wired interface board with multiple powered domains? | High | Low |
| 4 | Underside trace map and component-role pass | Do the TI device, SOIC-8, inductor, and regulator support an inline wired-interface architecture? | High | Low |
| 5 | Passive BLE and app-surface inventory | Does the firmware or BLE surface directly expose `TSL电子模块`, versioning, update flow, or user-control clues? | Medium-high | Low |
| 6 | Passive wired-signal capture only after the above | Is the wired path consistent with observation, translation, or injection? | High | Medium |

## Check 1: Full Harness And Connector Truth Table

### Objective

Create one definitive map from connector cavity to wire color to PCB net to labeled pad.

### Why this is first

This single step has the best chance of collapsing the `inline proxy` versus `parallel observer` versus `one-way injector` debate.

### Minimum output

- Connector shell size and cavity count
- Which cavities are populated
- Which conductor lands on `DIN`, `DOUT`, `VCC`, and `GND`
- Whether `DOUT` is only a pad, only a test point, or actually routed to the observed harness

### What would change the model fast

- If the installed harness really omits `DOUT`, the board starts looking less like a classic full inline proxy.
- If `DOUT` is routed but simply absent on the currently photographed lead, the inline theory stays much stronger.

## Check 2: Sterile Power And BLE Re-Test

### Objective

Repeat the power-up in a clean RF environment and verify what the board itself advertises.

### Why this matters

The earlier `FNB58` result is useful but still not clean enough to treat as settled.

### Minimum output

- Bench supply voltage and current at idle
- Whether a BLE advertiser appears at all
- Advertised name, manufacturer data, services, and writable or notifiable characteristics if present
- Whether the board's BLE surface changes after power cycling or waiting

### What would change the model fast

- A repeatable `TSL`- or vendor-linked BLE surface would strengthen the `CH571F hosts user-facing control` picture.
- No advertiser at all would push attention back toward wake conditions, alternate radio behavior, or a mistaken earlier attribution.

## Check 3: Rail Map And Current-State Profile

### Objective

Identify the board's powered domains and whether the wireless and wired sides look independently meaningful.

### Minimum output

- Regulator output voltage
- Static current in idle state
- Any current change during BLE advertising or user interaction
- Which major ICs sit on the regulated rail versus the incoming supply

### Why this matters

This is the fastest way to separate a trivial radio board from a real vehicle-interface board.

## Check 4: Underside Trace Map And Component-Role Pass

### Objective

Use sharp underside imagery and continuity work to connect the major silicon blocks to the labeled nets.

### Minimum output

- Trace path from connector to TI-marked TSSOP-16
- Trace path from connector to SOIC-8
- Trace path from connector to `CH571F`
- Any obvious isolation, level shifting, or power-switching features

### Why this matters

Right now the broad architecture is still inferred from top-side clues. One clean underside pass could settle whether the TI device is on the main wired path or just supporting power or switching.

## Check 5: Passive BLE And App-Surface Inventory

### Objective

Inventory the software-facing setup surface without assuming the app must stay connected during normal operation.

### Minimum output

- BLE UUID inventory
- Characteristic permissions and notify or write roles
- Any readable strings, firmware identifiers, or update endpoints
- Any visible linkage to `TSL电子模块`, `蓝牙版`, or the Chinese mini-program ecosystem

### Why this matters

The Chinese-side public record strongly suggests that later `TSL` products live in an OTA and mini-program ecosystem. Seller context for this specific board now says Bluetooth / WeChat is used for programming and setup, and that the unit can be configured to stay on afterward. Even passive identifiers can therefore help place this board inside that setup stack without over-assuming that a live app session is required for runtime behavior.

## Check 6: Passive Wired-Signal Capture Only After The Above

### Objective

If a suitable host environment ever becomes available, capture the wired path passively before making any architecture claim.

### Why this is last

Without the continuity map, rail map, and trace map, a live capture can be misleading and hard to interpret.

### Minimum output

- Which net is the real active data path
- Idle level and transition behavior under real host conditions
- Whether the board appears to observe, repeat, or originate events on that path

### Current caution

This repo is not yet at the point where vehicle-side probing is the best next move. The highest-value uncertainty is still on the board itself.

## Stop Conditions

If the following become true, the main mechanism question is mostly settled:

- The harness map shows whether the board is truly one-way or inline.
- The TI or SOIC device is visibly tied to the wired path rather than only to power support.
- A sterile BLE retest shows whether the board itself owns the wireless control surface.

At that point, the repo should be able to say whether `TSL5` is best modeled as a local steering-wheel-path observer, injector, or inline proxy, even if the exact protocol is still pending.

## Internal Recommendation

Do not spend the next session chasing broad new web claims until Checks 1 through 4 are done. The highest remaining uncertainty is now physical, not internet-side.

For live execution, use the worksheet companion note so the session output is captured in one consistent format instead of scattered across ad hoc notes.