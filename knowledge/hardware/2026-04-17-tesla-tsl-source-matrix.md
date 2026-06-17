---
title: "Tesla TSL Public-Source Matrix"
date: 2026-04-17
category: research
tags: [tesla, tsl1, tsl2, tsl5, tsl6, source-matrix, automotive]
status: in-progress
priority: high
related:
  - research/hardware/2026-04-17-tesla-research-set-overview.md
  - research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
  - research/hardware/2026-04-17-tesla-tsl-vendor-family-timeline.md
  - research/hardware/2026-04-17-tesla-tsl-decision-memo.md
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

# Tesla TSL Public-Source Matrix

## Purpose

This note converts the current Tesla `TSL` family research into a stricter claim matrix. Each row is tagged by a primary evidence bucket so future work can quickly distinguish direct local facts from seller copy, owner reports, and Tesla-side technical context.

This is a defensive research artifact only. It is meant to improve identification quality, source discipline, and future bench prioritization.

## Research Set Position

This is the evidence anchor for the Tesla research bundle.

Use it when the question is `how strong is this claim` or `what bucket does this evidence belong to`.

Update this note before updating the family map, timeline, landscape, vendor map, or decision memo.

## Customer / Case Linkage

- Customer: Moti Zaks
- Phone: (732) 806-1206
- Ticket: Unknown
- Order: Unknown
- Work Order ID: Unknown
- Related Case Log: hardware-diagnostics/intake-moti-zaks-tesla-modules-2026-04-15.md
- Related Sync Record: docs/customer-operations/sync-records/tesla-modules-moti-zaks-2026-04-15.json
- Related Main Note: research/hardware/2026-04-17-tesla-tsl-family-reverse-engineering-map.md
- Intake Summary: Customer brought Tesla-related hardware that now appears to be a small `TSL5` board and harness assembly rather than loose Tesla battery modules.

## Evidence Buckets

- `Local observation`: directly observed in repo case files, images, measurements, or local inspection.
- `Seller copy`: marketplace listings, vendor marketing, vendor-run app pages, or vendor-run Bilibili or Douyin posts.
- `Owner report`: hands-on user or reviewer reports describing installation or behavior in the field.
- `Tesla-side technical context`: Tesla platform behavior, steering-wheel function, clockspring or steering-column topology, or official Tesla China WeChat mini-program context used to interpret product claims.

## Source Quality Rules Used Here

- Fetched full pages are weighted above isolated search snippets.
- Vendor-run Bilibili and app-listing pages are still treated as `seller copy`, even when they contain more detail than a normal store listing.
- Public reviewer videos are treated as `owner report` when they describe hands-on install or behavior.
- Marketplace mirror pages and auto-generated Taobao world pages are kept but downweighted when the copy reads templated or marketing-rewritten.

## Tranche Handling Note

- Rows `1-30` establish the base family map and seized-board identification picture.
- Rows `31+` extend the matrix into late `2025` and `2026` so the repo has a dated record of the newer OTA, camera-era, and multifunction-controller phase.
- The newer tranche should be read mainly as market-shift evidence, not as stronger proof about the seized board's exact wired mechanism.

## Claim Matrix

| ID | Claim | Family / Topic | Primary Bucket | Source Snapshot | Confidence | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | The seized board is explicitly branded `TSL电子模块`, `Ver: TSL5`, and `蓝牙版`. | Seized unit | Local observation | Local case photos and case log | Strong | This is the hardest local anchor for the `TSL5` identification. |
| 2 | The seized unit exposes `DIN`, `DOUT`, `VCC`, and `GND`, and the observed harness variant uses only three populated conductors. | Seized unit | Local observation | Local bench notes and images | Strong | This supports a low-wire-count steering-wheel-path interpretation. |
| 3 | The seized board contains a `CH571F`, RF antenna area, crystal, likely regulator, TI-marked TSSOP-16 device, SOIC-8 device, and large inductor. | Seized unit | Local observation | Local macro image review | Strong | Enough silicon is present to rule out a trivial passive adapter. |
| 4 | The board was reported by the user as installing inside a steering-wheel connector, configured through WeChat, and toggled by double-clicking the left scroll wheel. | Seized unit behavior | Owner report | Customer-supplied operating context in the case log | Moderate | Strong enough to guide research direction, but still second-hand field testimony. |
| 5 | `TSL1` is an older generation name, but the current source pool does not define its mechanism clearly. | TSL1 | Seller copy | Later `TSL6` comparison copy referring back to `TSL1` | Weak | Keep as lineage label only. |
| 6 | `TSL2` appears as a steering-wheel-installed `Model 3/Y` mod chip. | TSL2 | Owner report | March 2024 TesLaunch-linked review of `TSL2` | Moderate | First reasonably concrete public identity for `TSL2`. |
| 7 | That same `TSL2` review says the chip is similar to `Mars Mode`, does not use `CAN bus`, and does not require extra equipment or coding beyond steering-wheel installation. | TSL2 | Owner report | March 2024 TesLaunch-linked review | Moderate | Useful but still depends on reviewer accuracy and seller-provided framing. |
| 8 | `TSL6` is explicitly sold as the later, easier-install generation contrasted against `TSL1`, `TSL2`, and `TSL3`. | TSL6 lineage | Seller copy | `TSL6` upgrade copy in English-language seller material | Moderate | This is the clearest public generation contrast collected so far. |
| 9 | `TSL6` for `Model 3/Y` is marketed as plug-style installation at the OBD connector, with Highland moving to a passenger-side location. | TSL6 install path | Seller copy | Evooor and related seller pages | Moderate | Good fitment clue, but still marketing-side. |
| 10 | `TSL6` owner reports describe OBDII daisy-chain installation in the car. | TSL6 install path | Owner report | Tesla Motors Club user reports | Moderate | Independent owner discussion reinforces the OBD path claim. |
| 11 | `TSL6` owner reports describe WeChat mini-program pairing and broader command-style behavior beyond the anti-nag role. | TSL6 control path | Owner report | Tesla Motors Club thread | Moderate | Stronger than seller copy because it includes actual use reporting. |
| 12 | `TSL6` owner reports describe left-scroll double-click enable or disable behavior with an audible beep on some firmware. | TSL6 field behavior | Owner report | Tesla Motors Club thread | Moderate | Useful for matching product family behavior to the customer description. |
| 13 | `TSL6` owner reports say it remains useful for basic Autopilot but does not defeat camera-based attention enforcement in FSD. | TSL6 capability boundary | Owner report | Tesla Motors Club thread | Moderate | Helps separate wheel-input simulation from driver-camera defeat claims. |
| 14 | `TSL5` is repeatedly marketed for `Model S/X` with a `3-pin connector`. | TSL5 fitment | Seller copy | AliExpress, eBay title, and seller snippets | Moderate | This converges well with the seized unit's smaller harness. |
| 15 | `TSL5` seller copy says it scrolls the steering-wheel volume control button every `1-5` seconds to clear the warning. | TSL5 mechanism claim | Seller copy | AliExpress snippet | Moderate | Marketing language, but repeated enough to matter. |
| 16 | A generic steering-wheel module seller note says buyers should first confirm that manually turning the left or right scroll wheel clears the prompt on their car. | Steering-wheel method class | Seller copy | Seller note surfaced in search results | Moderate | Supports the wheel-input method family rather than a pure torque-weight picture. |
| 17 | Some seller copy for `Model S/X 2016-2020` says the module toggles the menu through steering-wheel controls to eliminate the alert. | S/X wheel-input method class | Seller copy | TLYard or AFA-Motors generic steering-wheel module page | Weak to moderate | Not always TSL-branded, but converges with the same method family. |
| 18 | The exact phrase `TSL电子模块` appears as the name of a mini-program used for firmware pushes to `6代模块` and `非凡司令官 / 非凡指挥官`. | Chinese vendor ecosystem | Seller copy | Vendor-run Bilibili page fetched directly | Moderate | Important because the seized board uses the same `TSL电子模块` text on its silkscreen. |
| 19 | Vendor-run Chinese pages say `6代模块` and related hardware are Bluetooth-capable and support mini-program upgrades and parameter setting. | Chinese vendor ecosystem | Seller copy | Bilibili and Douyin vendor posts | Moderate | Strengthens the board's `蓝牙版` interpretation. |
| 20 | Chinese app-distribution pages describe `TSL电子模块` as a third-party Tesla control app that connects through Bluetooth and is associated with `非凡指挥官 / 非凡司令官`. | Chinese vendor ecosystem | Seller copy | iPA store page fetched directly | Moderate | Not the vendor's own store, but still a distribution listing for the same app name. |
| 21 | `WL5` is described in Chinese vendor material as Bluetooth-capable, mini-program-updatable, and able to link with `6代模块` and `非凡指挥官`. | WL5 relationship | Seller copy | Vendor-run Bilibili content | Weak to moderate | Suggests adjacent SKUs or companion modules inside the same ecosystem. |
| 22 | `TSL6`, `6代模块`, and `非凡司令官 / 非凡指挥官` appear repeatedly in overlapping Chinese-language vendor posts and upgrade announcements. | Branding overlap | Seller copy | Bilibili, Douyin, Taobao, iPA store | Moderate | Strong branding overlap, but hardware identity is still not fully proven. |
| 23 | A Taobao world page for `TSL6代電子模塊小程序藍牙版` uses heavy `volume control`, `phone integration`, and `smart assistant` marketing language. | TSL6 marketplace copy | Seller copy | World Taobao fetched page | Weak | Keep as low-trust marketing copy because the page reads templated and auto-expanded. |
| 24 | Tesla officially launched in-car WeChat mini-program support in China in software `2022.44.30.8`. | Tesla China platform context | Tesla-side technical context | Guancha article on Tesla China update | Strong | Important to avoid conflating Tesla's official WeChat ecosystem with the third-party `TSL电子模块` mini-program. |
| 25 | WeChat's own developer community has discussion about building mini-programs for Tesla in-car use. | Tesla China platform context | Tesla-side technical context | WeChat developer community page | Moderate | Reinforces that `Tesla + 小程序` is legitimate platform vocabulary in China. |
| 26 | Refreshed `S/X` owners discuss direct `CAN`, `LIN`, and `12 V` access behind the steering-wheel clockspring connector. | Steering-wheel bus context | Tesla-side technical context | Tesla Motors Club refreshed `S/X` retrofit discussion | Moderate | Makes a small inline steering-wheel module electrically plausible. |
| 27 | Older Tesla retrofit discussion says the old steering-column setup expected `LIN`, while a newer setup moved the steering-wheel-switch path onto `CAN`. | Steering-column generation shift | Tesla-side technical context | Tesla Motors Club heated-wheel or stalk retrofit discussion | Moderate | Supports model-dependent path variation rather than one universal wiring assumption. |
| 28 | Tesla wheel buttons or scroll-wheel actions can satisfy the Autopilot nag, which is why these products keep targeting wheel-input paths. | Tesla-side behavior | Tesla-side technical context | Tesla community behavior threads | Moderate | Core behavioral rationale for the whole product family. |
| 29 | The left scroll wheel on Tesla steering wheels controls volume-related functions. | Tesla wheel function | Tesla-side technical context | Tesla owner manual plus Tesla community references | Strong | Explains why `volume control button` language keeps showing up in `TSL5` copy. |
| 30 | The current repo-backed position that the seized board belongs to the smaller `TSL5` steering-wheel-path family is stronger than any exact `LIN` claim. | Main synthesis | Local observation | Combined reading of local board facts plus public-source matrix | Strong | This is the safest present conclusion. |
| 31 | A vendor-run Bilibili post dated `2025-11-26` says firmware `V4.1.20` supports Tesla software `2025.38.11` and that opening the `TSL电子模块` mini-program will deliver the update, synchronized across `非凡司令官`, `非凡指挥官`, and `6代模块`. | Chinese vendor ecosystem | Seller copy | Directly fetched `非凡科技FPV` Bilibili post from `2025-11-26` | Moderate to strong | This is the cleanest late-dated proof that `TSL电子模块` functions as an OTA or control-surface name, not just a PCB label. |
| 32 | That same late-2025 Bilibili post markets a bundled feature stack including `AP免打扰`, `连续AP`, `AP自动恢复`, `青春版EAP`, phone dashboard features, manual high beam, seat functions, Bluetooth support, and mini-program parameter setting across `3/Y` and refreshed `S/X`. | Late `TSL6` or `非凡` feature bundle | Seller copy | Same `2025-11-26` Bilibili post | Moderate | Strong evidence that the later Chinese stack is now sold as a platform rather than a single anti-nag widget. |
| 33 | Late-model `TSL6` listings now explicitly market fitment for `2025 Model Y Juniper` and qualify the module as `AP only`, not `EAP` or `FSD`. | Late `TSL6` fitment and limitation | Seller copy | AliExpress listing snippet for `2025 Model Y Juniper TSL6` surfaced by 2026 web search | Moderate | The direct page fetch failed, so treat this as explicit but still snippet-level seller evidence. |
| 34 | That same late-model seller snippet says the module only works if turning one of the steering-wheel scroll wheels can clear the nag on the car. | Late `TSL6` dependency | Seller copy | Same AliExpress `2025 Juniper` listing snippet | Moderate | Shows that even newer `TSL6` marketing still depends on the underlying wheel-acknowledgement path rather than promising universal compatibility. |
| 35 | By `March 2025`, some Tesla Motors Club owners report that `Autopilot` can run for many minutes without a torque nag as long as the driver keeps looking ahead, implying primary cabin-camera or face-monitoring in at least some deployments. | `AP` attention change | Owner report | Tesla Motors Club thread `No nag on Autopilot now unless not looking ahead.` | Moderate | Important because this moves part of the public conversation away from pure wheel-torque logic. |
| 36 | The same `March 2025` owner thread says the newer attention regime is region-dependent and light-sensitive: daylight can be mostly gaze-driven while poor lighting may reduce eye or face detection and bring back wheel-dependent behavior. | `AP` attention change | Owner report | Same Tesla Motors Club thread | Moderate | The rollout is clearly not uniform across regions or lighting conditions. |
| 37 | That same `2025` thread also describes strike-based enforcement tied to attention monitoring, including examples where looking at the center screen or turning the head during curved off-ramps caused warnings or strikes, with a five-strike week-loss framework discussed by owners. | `AP` or `FSD` enforcement | Owner report | Same Tesla Motors Club thread | Moderate | This is one of the strongest public signs that the monitoring problem is no longer just a nuisance-prompt issue. |
| 38 | A `March 2026` owner report says `AP` or `EAP` can remain mostly nag-free by day but revert to a `15 second` torque nag at night on dark unlit roads, alongside `camera blocked or blinded` messages. | `2026` night behavior | Owner report | Tesla Motors Club thread `EAP use at night and AP nags.` | Moderate | Valuable because it extends the attention story into 2026 with a concrete night-driving boundary. |
| 39 | Replies in the same `2026` thread interpret those repeated night nags as camera or face-visibility failure rather than simple cabin-condensation noise, and suggest interior or screen lighting changes as partial attempts to stabilize recognition. | `2026` night behavior interpretation | Owner report | Same Tesla Motors Club thread | Weak to moderate | This is interpretation, not hard proof, but it explains why day and night behavior can diverge so sharply. |
| 40 | Enhance Auto's official `S3XY Buttons` page presents a Commander-linked, app-configurable ecosystem with over `130` supported actions and `Activate Autopilot` among many features, rather than positioning itself as a single-purpose nag device. | Multifunction controller ecosystem | Seller copy | Directly fetched official Enhance Auto `Buttons` page | Strong | Strong evidence that the broader market is moving toward programmable control platforms. |
| 41 | An `August 2025` public review of `S3XY Knob` and `Commander` explicitly tests `continuous Autopilot` as one feature inside a much larger `80+` feature Tesla automation platform. | Multifunction controller ecosystem | Owner report | Tesla Jigsaw YouTube description snippet from `2025-08-12` | Moderate | Important adjacent-market evidence even though it is not the same vendor lineage as `TSL`. |
| 42 | The late-2025 and 2026 public record is best read as a market bifurcation: narrow wheel-path products still exist, but the growth area is software-sensitive, updateable, app-linked controller ecosystems that treat anti-nag behavior as only one feature among many. | Market landscape synthesis | Local observation | Combined reading of the late-2025 Bilibili posts, 2025-2026 Tesla Motors Club threads, official Enhance Auto pages, and late-model seller snippets | Moderate to strong | This row is a repo synthesis statement about the market phase, not a hardware-identity claim about the seized board. |

## Claims Still Not Cleared By The Matrix

- The seized `TSL5` board is not yet proven to be a true `LIN` MITM. The matrix only raises the plausibility of that theory.
- The exact hardware relationship between `TSL6`, `6代模块`, `非凡司令官 / 非凡指挥官`, and `TSL电子模块` remains unresolved.
- `WL5` may be a sibling product, companion module, or naming variant. Current evidence does not settle which.
- `TSL1` remains the least grounded family label in the current source set.
- The late `2025` and `2026` attention-monitoring picture is still region-, mode-, and lighting-dependent, so it should not be flattened into one global Tesla behavior claim.
- The repo still does not have evidence that the Chinese `TSL电子模块 / 6代模块 / 非凡` stack and Western `Commander`-class products share hardware lineage. The current evidence only says they now occupy a similar market phase.

## Late-2025 To 2026 Delta Takeaway

- The later Chinese ecosystem now looks like an update-driven product stack with synchronized firmware, mini-program control, and a growing non-AP feature bundle.
- The Tesla-side enforcement environment is increasingly shaped by cabin-camera or face-monitoring behavior rather than only wheel torque.
- The broader market is converging toward multifunction Tesla control platforms, with anti-nag behavior becoming one feature inside a much larger convenience and automation surface.

## Best Use Of This Matrix

- Use `Local observation` rows as the anchor when bench work conflicts with internet claims.
- Use `Owner report` rows to prioritize which behaviors are most worth reproducing locally.
- Use `Seller copy` rows to map naming drift, model-fit claims, and ecosystem overlap, but not to settle architecture by themselves.
- Use `Tesla-side technical context` rows to judge whether a claimed method even makes sense on the vehicle side.