---
title: "Tesla Multi-Board Comparison Worksheet"
date: 2026-04-18
category: research
tags: [tesla, multi-board, worksheet, diagnostics, reverse-engineering, automotive, hardware]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-18-tesla-multi-board-diagnostic-comparison-plan.md
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
  - research/hardware/2026-04-17-tesla-tsl-source-matrix.md
  - research/hardware/2026-04-17-tesla-tsl-bench-proof-plan.md
  - research/hardware/2026-04-17-tesla-tsl-bench-session-worksheet.md
  - hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
  - docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
case_type: customer-linked-research
customer_name: Moti Zaks
customer_phone: +17328061206
---

# Tesla Multi-Board Comparison Worksheet

## Purpose

This worksheet captures the same diagnostic fields across multiple Tesla-related boards so they can be compared directly.

Use it before deep-diving a single board when several boards or revisions are available.

## Research Set Position

This is the live comparison worksheet for the multi-board plan.

Use it to collect the comparison data, then push the resulting clusters and strongest facts back into the case log, source matrix, and family map.

## Session Header

- Date:
- Operator:
- Session objective:
- Boards on hand:
- Photo set root:
- Main case note to update after session:

## Pre-Flight Checklist

- [ ] ESD-safe workspace prepared
- [ ] One internal board ID assigned to each board
- [ ] Clean photos possible for both sides of each board
- [ ] Continuity meter ready
- [ ] Bench supply ready
- [ ] BLE scan device ready
- [ ] Notes capture method ready
- [ ] No vehicle-side probing planned for this session

## Board Inventory Table

| Board ID | Visible label or silkscreen | Suspected family before testing | Harness or connector summary | Photo set path | Notes |
| --- | --- | --- | --- | --- | --- |
| Board A |  |  |  |  |  |
| Board B |  |  |  |  |  |
| Board C |  |  |  |  |  |
| Board D |  |  |  |  |  |
| Board E |  |  |  |  |  |
| Board F |  |  |  |  |  |

## Cross-Board Quick Comparison Matrix

| Board ID | Main MCU or radio IC | Regulator | Support ICs | Key pads or labels | Connector style | Populated wires | Test voltage | Idle current | Idle signal levels | BLE advertiser | BLE services | Likely cluster |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Board A |  |  |  |  |  |  |  |  |  |  |  |  |
| Board B |  |  |  |  |  |  |  |  |  |  |  |  |
| Board C |  |  |  |  |  |  |  |  |  |  |  |  |
| Board D |  |  |  |  |  |  |  |  |  |  |  |  |
| Board E |  |  |  |  |  |  |  |  |  |  |  |  |
| Board F |  |  |  |  |  |  |  |  |  |  |  |  |

## Stage 1: Passive Physical Inventory

### Checklist For Each Board

- [ ] Top-side photo captured
- [ ] Underside photo captured
- [ ] Main ICs identified from markings
- [ ] Crystal marking recorded
- [ ] Regulator marking recorded
- [ ] Antenna style noted
- [ ] Any labeled pads recorded

### Board Detail Card Template

Copy this block once per board if deeper notes are needed during the session.

- Board ID:
- Top-side photo path:
- Underside photo path:
- Visible labels:
- Main MCU or radio IC:
- Crystal:
- Regulator:
- Support ICs:
- Antenna style:
- Labeled pads:
- Other visible clues:

## Stage 2: Connector And Harness Truth Table

### Per-Board Capture Table

| Board ID | Connector name or side | Cavity count | Populated cavities | Wire colors | Mapped nets | `DOUT` present on harness | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Board A |  |  |  |  |  |  |  |
| Board B |  |  |  |  |  |  |  |
| Board C |  |  |  |  |  |  |  |
| Board D |  |  |  |  |  |  |  |
| Board E |  |  |  |  |  |  |  |
| Board F |  |  |  |  |  |  |  |

### Decision Notes

- Boards that omit `DOUT` from the installed harness may belong to a different sub-class than boards with a clear inline path.
- Boards with richer connector topology may be better deep-dive candidates even if they are not the first ones found.

## Stage 3: Safe Power Baseline

| Board ID | Input voltage used | Current limit | Idle current | Regulator output | `DIN` idle | `DOUT` idle | Other rails | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Board A |  |  |  |  |  |  |  |  |
| Board B |  |  |  |  |  |  |  |  |
| Board C |  |  |  |  |  |  |  |  |
| Board D |  |  |  |  |  |  |  |  |
| Board E |  |  |  |  |  |  |  |  |
| Board F |  |  |  |  |  |  |  |  |

## Stage 4: BLE And App-Facing Identity

| Board ID | Advertiser seen | Advertiser name or ID | Manufacturer data | Services | Notify chars | Write chars | App or mini-program clue | Version clue | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Board A |  |  |  |  |  |  |  |  |  |
| Board B |  |  |  |  |  |  |  |  |  |
| Board C |  |  |  |  |  |  |  |  |  |
| Board D |  |  |  |  |  |  |  |  |  |
| Board E |  |  |  |  |  |  |  |  |  |
| Board F |  |  |  |  |  |  |  |  |  |

## Stage 5: Quick Trace And Role Triage

| Board ID | Wired-path owner looks like | Confidence | BLE looks shared with another board | Same support IC stack as another board | Best current model | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Board A |  |  |  |  |  |  |
| Board B |  |  |  |  |  |  |
| Board C |  |  |  |  |  |  |
| Board D |  |  |  |  |  |  |
| Board E |  |  |  |  |  |  |
| Board F |  |  |  |  |  |  |

## Cross-Board Clustering

### Likely Clusters

- Cluster 1:
- Cluster 2:
- Cluster 3:

### Shared Traits Worth Recording

- 
- 
- 

### Differences That Look Family-Defining

- 
- 
- 

## Best Next Deep-Dive Target

- Selected board ID:
- Why this board is the best next target:
- What it is most likely to resolve:

## End-Of-Session Decision Box

### Highest-Value New Fact Learned

- 

### Biggest Remaining Unknown

- 

### What Now Looks Shared Across The Set

- 

### What Now Looks Different Across The Set

- 

### Next Session Should Start With

- 

## Stop Conditions

This worksheet has done its job when:

- every board has a normalized row
- the boards can be grouped into likely clusters
- one board is clearly the best next deep-dive target
- the strongest new facts are ready to be pushed into the Tesla source matrix and family map