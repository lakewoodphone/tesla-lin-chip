---
title: "Tesla TSL Current Decision Memo"
date: 2026-04-17
category: research
tags: [tesla, tsl5, tsl6, decision-memo, reverse-engineering, automotive]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
  - research/hardware/2026-04-17-tesla-tsl-source-matrix.md
  - research/hardware/2026-04-17-tesla-tsl-vendor-family-timeline.md
  - research/hardware/2026-04-17-tesla-tsl-bench-proof-plan.md
  - research/hardware/2026-04-17-tesla-tsl-bench-session-worksheet.md
  - research/hardware/2026-04-17-tesla-anti-nag-public-landscape.md
  - research/hardware/2026-04-17-tesla-anti-nag-vendor-map-and-diy-difficulty.md
  - external-research/2026-04-21-tsl5-single-board-architecture-follow-up/2026-04-21-vetted-synthesis.md
  - hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
case_type: customer-linked-research
customer_name: Moti Zaks
customer_phone: +17328061206
---

# Tesla TSL Current Decision Memo

## Purpose

This memo freezes what is now strong enough to treat as the repo's working position, and what still must remain conditional.

## Research Set Position

This is the wording-boundary note for the Tesla bundle.

If a claim is not cleared here, keep it conditional in later summaries, timelines, landscape notes, and vendor notes.

## Decided Enough To Use Internally

- The seized board should be treated as part of the `TSL5` family.
- `TSL5` and `TSL6` should be treated as related but distinct public families, not interchangeable names for the same exact hardware.
- `TSL2` is now grounded enough to treat as a distinct earlier `Model 3/Y` steering-wheel-path generation in the public record.
- `TSL6` is grounded enough to treat as the later easier-install public family, usually described around `OBD`, rear-console, passenger-side, or similar plug-style installation contexts depending on model.
- `TSL电子模块` should now be treated as both a literal board label and a Chinese-side app or mini-program ecosystem name, especially around later `6代模块` and `非凡司令官 / 非凡指挥官` material.
- The SOIC-8 on the seized board is now strong enough to treat as a `TJA1020`-family or closely pin-compatible automotive LIN transceiver on the `DIN` side.
- The corrected `14`-pin device is now strong enough to treat as a `DIN`↔`DOUT` switch-matrix or pass-through class stage, with a `4066`-family bilateral-switch topology now the strongest exact architecture fit.

## Plausible But Still Conditional

- The seized `TSL5` board most likely acts on a steering-wheel-side low-wire-count signaling path.
- The currently observed `3`-wire harness most likely puts the board into a parallel observer-plus-injector mode rather than a live inline `DIN`↔`DOUT` bridge, because `DOUT` is not populated on the observed local lead.
- The board now looks materially stronger as a `LIN`-transceiver-plus-switch-matrix design than it did earlier, but the repo still does not prove the exact in-car behavior of every supported harness variant.
- The `CH571F` likely hosts at least part of the user-facing BLE control surface, but the earlier `FNB58` observation is not yet clean enough to use as final proof.
- `WL5` and `WL6` likely live in the same broader Chinese accessory ecosystem as later `TSL6`-era products, but their exact hardware relationship is still unresolved.

## Claims To Avoid Making

- Do not say the corrected `14`-pin device is manufacturer-proven as one specific public part number; use architecture class or `4066`-family fit wording instead.
- Do not say the currently observed local harness proves that `DOUT` is never used in any other SKU or install variant.
- Do not say all `TSL1` through `TSL6` labels describe one clean continuous architecture.
- Do not say the earlier `FNB58` advertiser definitely came from nearby unrelated bench gear.
- Do not say `TSL6` or similar products universally defeat the latest `FSD` attention checks.
- Do not collapse official Tesla China `小程序` platform support into proof about any one third-party vendor's hardware stack.

## Best Current Internal Phrasing

Use this form unless new bench evidence changes it:

`The seized board is best classified as a small TSL5 steering-wheel-path module with a DIN-side LIN transceiver and a corrected 14-pin DIN↔DOUT switch matrix whose exact deployed role remains unresolved. In the currently observed 3-wire harness, the board most likely behaves as a parallel observer-plus-injector rather than a live inline bridge. Public evidence supports treating TSL2 as an earlier steering-wheel-installed Model 3/Y generation and TSL6 as a later plug-style OBD or gateway family with broader app-linked features.`

## What Would Most Efficiently Change The Decision Boundary

- A dynamic proof of whether the corrected `14`-pin switch matrix actually closes or opens a live `DIN`↔`DOUT` path under powered conditions
- A fuller harness truth table for the seized board
- A sterile BLE re-test with repeatable advertiser and GATT data
- An underside trace map that shows which major IC owns the wired path

## Internal Recommendation

Future repo notes should be more confident about family separation than about exact protocol. The family map is now materially stronger than the signal-path proof.