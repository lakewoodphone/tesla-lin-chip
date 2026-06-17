---
title: "Tesla TSL Family Reverse-Engineering Map"
date: 2026-04-17
category: research
tags: [tesla, tsl5, tsl6, reverse-engineering, automotive, hardware]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-source-matrix.md
  - research/hardware/2026-04-17-tesla-tsl-vendor-family-timeline.md
  - research/hardware/2026-04-17-tesla-tsl-decision-memo.md
  - research/hardware/2026-04-17-tesla-tsl-bench-proof-plan.md
  - research/hardware/2026-04-17-tesla-tsl-bench-session-worksheet.md
  - research/hardware/2026-04-17-tesla-anti-nag-public-landscape.md
  - research/hardware/2026-04-17-tesla-anti-nag-vendor-map-and-diy-difficulty.md
  - hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
  - docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
  - external-research/2026-04-15-tsl5-ch571f-return-review/INDEX.md
  - external-research/2026-04-15-tsl5-ch571f-return-review/2026-04-15-vetted-synthesis.md
case_type: customer-linked-research
customer_name: Moti Zaks
customer_phone: +17328061206
---

# Tesla TSL Family Reverse-Engineering Map

## Purpose

This note consolidates the current internal understanding of the Tesla `TSL` product families, the seized `TSL5` / `CH571F` board in the Moti Zaks case, and the next non-destructive measurements most likely to resolve the remaining mechanism questions.

This is a defensive and analytical document only. It is intended to support identification, hardware understanding, and safe internal evidence collection. It is not a deployment, build, or bypass guide.

## Research Set Navigation

This is the flagship synthesis note in the Tesla document bundle.

Use the companion notes like this:

- `2026-04-17-tesla-research-set-overview.md` for `start here` navigation
- `2026-04-17-tesla-tsl-source-matrix.md` for claim-by-claim evidence weight
- `2026-04-17-tesla-tsl-vendor-family-timeline.md` for chronology and market phase evolution
- `2026-04-17-tesla-tsl-decision-memo.md` for settled versus still-conditional wording
- `2026-04-17-tesla-anti-nag-public-landscape.md` for `what people are doing now`
- `2026-04-17-tesla-anti-nag-vendor-map-and-diy-difficulty.md` for vendor roles and DIY difficulty
- `2026-04-17-tesla-tsl-bench-proof-plan.md` for ranked next-step testing
- `2026-04-17-tesla-tsl-bench-session-worksheet.md` for live bench execution

## Customer / Case Linkage

- Customer: Moti Zaks
- Phone: (732) 806-1206
- Ticket: Unknown
- Order: Unknown
- Work Order ID: Unknown
- Related Case Log: hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
- Related Sync Record: docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
- Intake Summary: Customer brought Tesla-related hardware that now appears to be a small `TSL5` board and harness assembly rather than loose Tesla battery modules.

## Current Internal Bottom Line

- The seized board is very likely part of the commercial `TSL5` anti-nag product family.
- Public-source evidence is now strong enough to separate `TSL2` from `TSL6` as two different public generations or product styles, even though neither has been locally captured in this repo.
- The repo evidence supports treating `TSL5` and `TSL6` as related but electrically distinct families.
- The best current structural split is `small steering-wheel-path TSL5 family` versus `larger gateway-style TSL6 family`.
- `TSL1` remains thinly documented, while `TSL3` currently appears mainly as a seller-side contrast label used to market `TSL6` as the easier later generation.
- The exact on-wire mechanism of the seized board is still not locally proven.
- The current evidence is strong enough for model-family classification and bench-priority planning, but not yet strong enough for a final architecture claim.

## What Is Actually Observed On The Seized Board

### Directly observed in local case material

- Silkscreen includes `TSL电子模块`, `Ver: TSL5`, and `蓝牙版`.
- Board exposes pads or labels for `DOUT`, `DIN`, `VCC`, and `GND`.
- A smaller observed lead uses only `DIN`, `VCC`, and `GND` and terminates in a 6-position female connector with 3 populated cavities.
- The board powers from a local bench setup at `5.0 V`, lights up, and draws about `0.001 A` in the recorded state.
- Idle measurements on both `DIN` and `DOUT` were about `4.207 V` to ground during that same bench state.
- Macro photos identify a `CH571F`, a `24.000` crystal, a printed RF antenna, a likely `78L33C` regulator, a TI-marked TSSOP-16 device, an SOIC-8 device, and a large inductor.
- User-provided operating context says the board installs inside a steering-wheel connector, is configured through WeChat, and can reportedly be toggled by double-clicking the left scroll wheel.

### Directly observed in the decoded overview image

- The top side clearly contains a large inductor, a TI-marked TSSOP-16 device, a QFN device near the crystal and antenna area, and a 4-pad breakout area that matches the documented labeled signal group.
- The currently available top-side image does not reveal a separate motor or actuator on that side of the assembly.
- The image supports a powered logic board plus interface or conditioning role, but does not by itself settle whether the car-facing mechanism is local signal injection, inline proxying, or a separate actuator elsewhere in the assembly.

## Family Taxonomy

### TSL1

- Current repo evidence for `TSL1` is still thin and public-source only.
- The strongest current use of the name is as an earlier, more cumbersome generation mentioned in later `TSL6` upgrade copy.
- Treat detailed mechanism claims about `TSL1` as provisional unless a real unit is documented locally.

### TSL2

- `TSL2` is now better grounded than `TSL1`, though still only through public sources.
- A March 2024 TesLaunch-linked review describes `TSL2` as a `Model 3/Y` steering-wheel-installed mod chip.
- That same review explicitly says it is `similar to Mars Mode`, does `not use CAN bus`, and does not require additional equipment or coding beyond the chip installed into the steering wheel.
- This makes `TSL2` the clearest currently documented pre-`TSL6` steering-wheel-path generation for `Model 3/Y` in the public record collected so far.

### TSL5

- Small steering-wheel-path family.
- Public material and local case evidence both point to a compact module associated with steering-wheel-side installation.
- The seized board belongs here with high confidence.
- Public fitment claims referenced in the repo currently cluster around `Model S/X 2017-2024`, `2021+ S/X`, and more tentative `Model 3 Highland` or related newer-platform steering-wheel references.
- Newly collected seller copy continues to reinforce the `3-pin connector` claim for `Model X/S` and repeatedly describes the effect as periodic scroll or volume-wheel interaction every few seconds rather than a generic wireless accessory function.
- Control appears to involve Bluetooth or WeChat on the user-facing side, but the exact car-facing electrical path is still unresolved locally.

### TSL6

- Larger gateway-style family.
- Public material in the repo describes a broader-featured Bluetooth or WeChat-configurable unit, distinct from the smaller seized inline board.
- Public install claims are model-sensitive rather than uniform. The repo currently contains references to `Model 3` / `Model Y` installs through the `OBD` region, `passenger side`, or `copilot inside` depending on model year and variant.
- The public-source role of `TSL6` is broader than the seized `TSL5` board and appears to include more vehicle-feature behavior than a simple small steering-wheel module.
- Newly collected owner reports strengthen that split further: users describe `TSL6` as an `OBDII` daisy-chain module, sometimes enabled or disabled by double-clicking the left scroll wheel with an audible beep, paired through a `WeChat` mini-program, and capable of broader `mini commander`-style behavior beyond the anti-nag role.
- Newly collected owner reports also say `TSL6` remains useful for basic Autopilot but does not solve cabin-camera attention enforcement in `FSD`, which further supports treating it as a torque or scroll-wheel-path aid rather than a universal driver-monitoring bypass.
- Chinese-language vendor sources now strongly suggest that late `TSL6`-era public branding overlaps with the `TSL电子模块` mini-program or app, `6代模块`, and `非凡司令官 / 非凡指挥官` naming ecosystem.

## Best Current Model Split

| Family | Physical form factor | Claimed install context | User-facing control | Best current electrical read |
| --- | --- | --- | --- | --- |
| `TSL1` | Older lineage, not locally captured | Public-source only | Unknown | Treat as earlier lineage label only |
| `TSL2` | Small chip or wheel-path module | Steering-wheel-installed on `Model 3/Y` in public review material | Not clearly settled | Public review says wheel-installed and not `CAN`-based |
| `TSL5` | Small inline board | Steering-wheel connector path | Bluetooth / WeChat | Likely local steering-wheel-path signaling, exact path unresolved |
| `TSL6` | Larger gateway-style module | `OBD`, passenger-side, or `copilot inside` depending on vehicle | Bluetooth / WeChat | Publicly treated as the broader, distinct family from seized `TSL5` |

## Public-Source Lineage Tightening

### English-side lineage signal

- TesLaunch-linked 2024 public material now gives the cleanest currently collected generation contrast.
- `TSL2` appears as a steering-wheel-installed `Model 3/Y` chip in a March 2024 review, with the reviewer explicitly describing it as not using `CAN bus` and not needing extra equipment or coding beyond the chip installation.
- `TSL6` is then marketed as the easier later generation, explicitly contrasted against `TSL1`, `TSL2`, and `TSL3`, with install language centered on faster plug-style installation instead of steering-wheel teardown.

### Chinese-side ecosystem signal

- The exact string `TSL电子模块` is no longer just a silkscreen clue from the seized board. Chinese-language pages now show it as the name of a mini-program or app used for updates and Bluetooth-linked control.
- Chinese vendor-facing pages and videos repeatedly co-mention `TSL电子模块`, `6代模块`, and `非凡司令官 / 非凡指挥官`, suggesting a shared vendor ecosystem or at least tightly coordinated branding.
- `WL5` and `WL6` also appear in that same ecosystem as Bluetooth-capable modules that support mini-program upgrades, settings, and linkage with `6代模块` or `非凡指挥官`.

### Interpretation that is now safer than before

- `TSL2` is no longer best treated as a vague historical label. It now has a distinct public image as a steering-wheel-installed `Model 3/Y` generation.
- `TSL6` is no longer best treated as merely `another seller name`. It is now better supported as the later, easier-install, broader-feature public family.
- `TSL5` still fits best as the smaller steering-wheel-path family associated with `Model S/X` 3-pin connector claims and periodic wheel-input claims.
- The Chinese vendor-app ecosystem likely represents a later software and accessory layer around `TSL6`-class hardware, but that exact corporate or hardware relationship is still not fully proven locally.
- It remains important not to confuse the product-side `TSL电子模块` mini-program claims with Tesla's own official China in-car WeChat mini-program environment.

## Competing Mechanism Theories For The Seized TSL5 Board

### 1. Small steering-wheel-path signal injector or proxy

This is the strongest current working theory.

Why it fits:

- The board is physically small and paired with steering-wheel connector context.
- The observed signal labels and 3-wire lead fit a low-wire-count control path better than a broad vehicle gateway picture.
- User-reported install location and control behavior align with a steering-wheel-path device.
- The repo's vetted synthesis now treats this smaller `TSL5` family as distinct from the larger `TSL6` family.

What still blocks a final claim:

- No local continuity map yet proves whether the board is inline, parallel, or partly isolated.
- No locally captured live protocol trace yet proves whether the path is LIN, local switch-state emulation, or another conditioned signal path.

### 2. True LIN-path MITM or local serial-path proxy

This remains plausible but not yet proven.

Why it fits:

- A 3-wire lead, steering-wheel context, and pulled-up idle behavior are all compatible with a low-speed vehicle-side control path.
- The TI device plus the inductor and regulation chain suggest more than a trivial BLE daughterboard.
- New Tesla community retrofit discussion adds vehicle-side plausibility: refreshed `S/X` owners explicitly discuss direct `CAN`, `LIN`, and `12 V` availability at the clockspring module connector behind the steering wheel.

Why confidence is still limited:

- The repo does not yet contain underside routing proof.
- The current case log intentionally stops short of declaring the board to be on LIN as settled fact.

### 3. Physical actuator-based scroll-wheel mover

This is weaker than before.

Why it was initially attractive:

- Some public write-ups and seller descriptions collapse earlier families into physical scroll-wheel-actuation language.

Why it is now downgraded:

- The earlier interpretation was partly driven by confusion over the smaller lead.
- The current local record clarifies that the smaller observed lead is a 3-wire connector path, not a confirmed 4-wire actuator lead.
- The currently reviewed top-side image does not show a separate actuator on that visible side.

### 4. Benign steering-wheel accessory or audio-control helper

This is currently weak.

Why it remains possible in the abstract:

- The board is visibly small, powered, and tied to steering-wheel-area context.

Why it is not the best fit:

- The exact `TSL5` and `蓝牙版` branding lines up unusually well with the repo's public-source anti-nag family material.
- The broader pattern in current repo material points away from a generic convenience accessory and toward the `TSL` anti-nag product family.

## What The Alternate Longform Analysis Gets Right And Wrong

### Strong contributions from the alternate longform analysis

- It usefully emphasizes that the board is not a passive adapter.
- It correctly treats the `CH571F` as a serious clue about an integrated BLE-capable control MCU rather than a dumb harness tag.
- It usefully frames the board as a specialized automotive control board rather than a battery-module accessory.

### Parts that should stay downgraded internally

- Its claim that the observed `FNB58-051849` BLE advertiser definitely came from nearby bench equipment is still stronger than the local record justifies.
- It pushes a high-confidence LIN interpretation further than the current local evidence supports.
- It includes at least one clearly bad citation path in support of a component-role claim, which lowers trust in the most specific architecture assertions.

Internal handling recommendation:

- Keep the `FNB58` attribution unresolved pending a sterile re-test.
- Keep `LIN` as plausible, not settled.
- Keep the board-family classification stronger than any exact signal-path claim.

## Web Research Delta

### TSL5 claims that kept repeating

- Multiple seller-facing pages continue to describe `TSL5` as the smaller `Model S/X` family module with a `3-pin connector`.
- The recurring seller-side mechanism language is not generic torque reduction. It repeatedly describes periodic steering-wheel `scroll` or `volume control button` interaction.
- The strongest repeated fitment bucket remains `Model S/X`, with weaker spillover references that now mention `Highland` and `Juniper` in mixed marketplace contexts.

### TSL6 behavior that is now better grounded

- `TSL6` is repeatedly described by owners as an `OBDII`-attached device rather than a tiny steering-wheel-inline board.
- The same owner thread describes firmware variability: some units simulate right-wheel speed changes, while others appear tied to the left or volume wheel.
- The same owner thread describes a double-click toggle on the left scroll wheel with an audible beep on at least some firmware.
- The same owner thread identifies the configuration path as a `WeChat` mini-program and describes the unit as a broader `mini commander` with additional vehicle-feature settings.
- Owner reports also explicitly say it remains useful for basic Autopilot but does not defeat cabin-camera attention checks in `FSD`.

### Tesla-side technical context that matters

- A Tesla Motors Club refreshed `S/X` discussion explicitly states that there is direct `CAN`, `LIN`, and `12 V` access on the back of the clockspring module connector behind the steering wheel.
- Older Tesla retrofit discussions also describe steering-column generations where the old setup expected `LIN` input and the newer setup moved steering-wheel-switch behavior onto `CAN`.
- Tesla's own China-specific vehicle software environment also matters here: official Tesla in-car WeChat mini-program support exists, which means the phrase `小程序` around Tesla products is real platform vocabulary and not automatically evidence of any one third-party hardware vendor.
- Taken together, those discussions do not prove the exact path used by the seized board, but they do make a steering-wheel-path low-wire-count controller significantly more plausible than a generic standalone Bluetooth gadget.

### FNB58 delta

- The new web pass gives a narrower conclusion than before: `FNB58` definitely has Bluetooth-capable variants, and community reverse-engineering confirms BLE notification traffic exists.
- A public reverse-engineering thread also states that one tester cannot use `USB` and `Bluetooth` at the same time.
- This makes an `FNB58` false-positive scenario plausible in the abstract, but still does not prove that the original local advertiser record came from a nearby meter rather than the board.

## High-Level Architecture That Best Fits The Current Evidence

The current best-fit non-actionable block picture is:

1. A vehicle-side low-wire-count signaling path enters the board through the observed connector path.
2. A power-conditioning section converts the incoming supply into a stable logic rail.
3. The `CH571F` acts as the local control MCU and likely hosts the user-facing Bluetooth or WeChat-side control path.
4. The TI-marked device and other support silicon likely handle part of the wired interface, conditioning, translation, or switching role.
5. The board either observes, conditions, injects, or proxies steering-wheel-path signals closely enough to simulate a user interaction event.

The repo evidence currently does not justify choosing between:

- passive observation plus timed injection,
- true inline proxying,
- or another mixed local emulation method.

## Reverse-Engineering Program

### Phase 1: Finish the physical map

- Capture both PCB sides sharply.
- Map `DIN`, `DOUT`, `VCC`, `GND`, and any `VU`-labeled node by continuity.
- Determine whether `DOUT` actually routes to active silicon or is effectively unused in the observed harness configuration.
- Identify the exact connector family, cavity count, keying, and whether the 6-position housing matches known Tesla steering-wheel-side connectors.

### Phase 2: Finish the power and identity map

- Re-test BLE in a sterile bench environment with no possible `FNB58`-class device nearby.
- Confirm the actual regulator output under power.
- Determine whether the logged `5.0 V` state was true operating state, partial wake, or undervolted standby.
- Record current draw versus power-up state changes only after the input rail expectations are locally confirmed.

### Phase 3: Finish the signal-path map

- Determine whether the observed 3-wire path behaves as a simple one-line control path, a true bidirectional bus path, or a board-local input path with a separate downstream route.
- If safe and justified later, use passive observation tools to learn whether the board ever drives the wired side or only watches it in the tested state.
- Do not treat the board as definitively `LIN` until routing or trace data proves it.

### Phase 4: Finish the software-access map

- Search for likely WCH debug or ISP pads on the underside.
- Determine whether the board exposes SWIO, SWCLK, or hidden USB data pads.
- Assume read protection may block non-destructive extraction.
- If readout is blocked, keep the firmware as a black box and prioritize external signal-path understanding instead.

## Highest-Value Questions Still Open

- Is the seized board truly on a LIN path, or does it emulate a simpler local button or wheel signal path?
- Is `DOUT` a real active downstream path in the final installation, or just a board/debug pad not used in the observed harness state?
- What voltage range does the board actually expect at its primary input?
- Does the `CH571F` host the whole user-facing BLE stack for this board, or is the real field control path gated by a wake condition not yet reproduced locally?
- What part of the `TSL5` / `TSL6` naming is true technical generation and what part is just seller-side branding drift?
- Which Tesla-side platform transitions matter most here: older `LIN`-leaning steering-column assumptions, newer `CAN`-heavier steering-wheel integration, or a mixed design depending on model and generation?
- Are `TSL6`, `6代模块`, `TSL电子模块`, and `非凡司令官 / 非凡指挥官` all names for one evolving vendor stack, or partially distinct hardware and software SKUs that only interoperate?
- Is `WL5` a sibling product family, a companion accessory module, or simply a regional naming variant inside the same later-generation ecosystem?

## Fastest Path To A Better Answer

If only a few new observations are gathered, the best return likely comes from:

1. underside photo set,
2. continuity map of `DIN`, `DOUT`, and the connector housing,
3. sterile BLE re-test,
4. regulator-output measurement,
5. direct confirmation of the exact Tesla-side mating connector.

## Working Conclusion

The repo now has enough evidence to treat the seized board as part of the `TSL5` family with high confidence and to treat `TSL5` and `TSL6` as meaningfully distinct families rather than interchangeable names. The seized board currently reads best as a small steering-wheel-path control board built around a `CH571F`, with Bluetooth or WeChat likely used on the user-facing side and a still-unresolved local vehicle-side signaling method on the wired side. The next stage of reverse engineering should focus on routing proof and power-state proof, not on broader internet theory collection.