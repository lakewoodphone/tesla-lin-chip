---
title: "Tesla Multi-Board Diagnostic Comparison Plan"
date: 2026-04-18
category: research
tags: [tesla, multi-board, comparison, diagnostics, reverse-engineering, automotive, hardware]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
  - research/hardware/2026-04-17-tesla-tsl-source-matrix.md
  - research/hardware/2026-04-17-tesla-tsl-decision-memo.md
  - research/hardware/2026-04-17-tesla-tsl-bench-proof-plan.md
  - research/hardware/2026-04-18-tesla-multi-board-comparison-worksheet.md
  - hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
  - docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
case_type: customer-linked-research
customer_name: Moti Zaks
customer_phone: +17328061206
---

# Tesla Multi-Board Diagnostic Comparison Plan

## Purpose

This note turns the Tesla board work from a single-board investigation into a comparison-first workflow.

Use it when there is more than one Tesla-related board, harness, or variant on hand and the goal is to learn faster by comparing families rather than by overfitting to one unit too early.

The goal is not to make any board work in a car. The goal is to extract the highest-value architecture clues, family splits, and feasibility constraints from the boards already in hand.

## Research Set Position

This note sits between the Tesla synthesis bundle and live bench execution.

Use it before spending deep time on any single board if multiple boards are available.

Use the existing single-board proof plan when one specific board has already been selected for deeper work.

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

## Why Comparison First Helps

With only one board, it is easy to mistake a board-specific quirk for a family trait.

With multiple boards, comparison can answer higher-value questions much faster:

- which traits are stable across a family
- which connectors or pads are truly functional versus just present on one revision
- which ICs are shared and which ones define a family split
- whether the `TSL5` versus `TSL6` distinction is visible in hardware, power behavior, BLE identity, or harness structure
- which board is the cleanest candidate for a deeper reverse-engineering pass

## Main Questions This Plan Should Answer

1. Which boards appear to belong to the same family or sub-family?
2. Which boards expose the clearest wired path for non-destructive tracing?
3. Which boards share the same BLE or app-facing identity?
4. Which board is the best next deep-dive candidate?
5. How much of the build problem is common hardware versus software maintenance and compatibility drift?

## Operating Rules

- Stay non-destructive.
- Capture the same fields for every board before going deep on any one board.
- Treat family clustering as a first-class goal, not a byproduct.
- Prefer measurements that are cheap, repeatable, and comparable across boards.
- Do not treat a seller label as equal to a hardware family until the board-level evidence lines up.

## Comparison Sequence

### Phase 1: Normalize The Inventory

Create one inventory row per board.

Minimum output:

- board ID used internally in this repo
- visible labels and silkscreen
- connector count and rough harness type
- photo set location
- suspected family before testing

Why this matters:

- it prevents later confusion between revisions, photos, and measurements

### Phase 2: Passive Physical Inventory

Capture the visible architecture without powering anything.

Minimum output:

- main MCU or radio IC
- crystal markings
- regulators
- obvious transceivers or support ICs
- antenna style
- pad labels such as `DIN`, `DOUT`, `VCC`, `GND`, `VU`

Why this matters:

- shared component stacks often reveal family relationships faster than marketing names do

### Phase 3: Connector And Harness Truth Tables

For each board, map connector cavities, populated wires, colors, and PCB nets.

Minimum output:

- cavity count
- populated cavities
- net mapping
- whether the board is obviously one-way, inline, or still ambiguous

Why this matters:

- this is the fastest way to separate narrow wheel-path boards from broader gateway-style products

### Phase 4: Safe Power Baseline

Run the same careful power check on each board.

Minimum output:

- input voltage used
- current at idle
- logic rail voltage if present
- idle line voltages on exposed signal nets

Why this matters:

- a shared power profile can cluster boards quickly
- a very different power profile can reveal a deeper family split

### Phase 5: BLE And App-Facing Identity

Repeat the same BLE scan and basic GATT inventory for every board that appears to support it.

Minimum output:

- advertiser name or ID
- service set
- notify and write characteristics
- any visible strings, versioning, or app identity

Why this matters:

- this is the cleanest way to see whether multiple boards live in the same software ecosystem

### Phase 6: Quick Rail And Trace Triage

Only after the above, do a shallow comparison of rail ownership and obvious trace routing.

Minimum output:

- which IC appears tied to the wired path
- whether the support IC stack looks shared across boards
- whether any board offers an unusually clear routing picture worth prioritizing

Why this matters:

- it helps choose the best deep-dive target without spending hours on the wrong board first

## Core Comparison Axes

| Axis | Why it matters |
| --- | --- |
| Silkscreen and version labels | Helps distinguish marketing family versus actual board revision |
| Main MCU or radio IC | Fastest family-clustering clue |
| Regulator and rail behavior | Separates trivial radio boards from fuller interface boards |
| Support IC stack | Helps infer whether the board is acting on a real wired path |
| Connector style and populated wires | Strong clue for one-way injector versus inline proxy |
| Idle signal voltages | Helps compare likely bus or pulled-up line behavior |
| BLE advertiser and services | Strong clue for shared app ecosystem |
| App or mini-program identity | Helps connect boards to the later Chinese stack or other ecosystems |
| Physical install clues | Helps separate steering-wheel-path boards from gateway-style boards |

## Best First Targets For Deeper Work

After the comparison pass, prioritize the board that scores highest on these traits:

- clearest visible wired path
- cleanest underside routing
- strongest family-representative value
- least ambiguous connector mapping
- repeatable BLE identity or version clues
- simplest path to continuity work without destructive disassembly

Avoid choosing the first board only because it is already familiar.

## What This Helps With For A DIY Feasibility Read

This comparison workflow can materially help a research-level `could we build something in this class` question because it will clarify:

- what the minimum hardware stack seems to be
- which parts of the design appear shared versus revision-specific
- whether the hard part is mostly wired interface handling, BLE control, or software compatibility
- whether the modern market gap is hardware design or long-term firmware and ecosystem upkeep

It will not by itself solve the modern product problem.

It will only make the real constraint stack more visible.

## Stop Conditions

The comparison pass has done its job when:

- every board has a normalized inventory row
- every board has connector and power baseline data
- BLE identity is either captured or ruled out on each board
- the boards can be grouped into likely clusters or family splits
- one board is clearly selected as the next deep-dive target

## Internal Recommendation

If multiple boards are available, do not spend more than a short initial session on any single board before finishing Phases 1 through 5 across the full set.

Use the companion worksheet so each board is documented in the same format and the results can be pushed back into the Tesla source matrix and family map cleanly.