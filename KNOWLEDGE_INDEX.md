# Tesla LIN Chip — Knowledge Index

This file maps all organized content in the repo. Updated 2026-06-16.

---

## Core Handoffs

| File | Purpose |
|---|---|
| `START_HERE.md` | **Start every session here.** Current state, active path, hard stops. |
| `BENCH_EVIDENCE.md` | Full passive + active bench evidence summary |
| `ACTIVE_INJECTOR.md` | Active TX wiring, operation, diagnostics |
| `IMPLEMENTATION_ROADMAP.md` | Full bench → passive car → final chip roadmap |
| `NEXT_STEPS.md` | Current work plan |

---

## Hardware Design

| File / Dir | Purpose |
|---|---|
| `hardware/tesla-dual-lin-rev-a/kicad/` | KiCad schematic + PCB (ESP32-S3-WROOM-1U-N8R8 + 2x TJA1021T/20) |
| `hardware/tesla-dual-lin-rev-a/bom/` | BOM strategy, cost model, supplier shortlist |
| `hardware/tesla-dual-lin-rev-a/manufacturing/` | JLCPCB order files |
| `hardware/tesla-dual-lin-rev-a/build/` | Generated Gerbers + drill files |
| `boards/tesla_dual_lin_esp32s3_n8r8.json` | ESP32-S3 N8R8 PlatformIO board definition |
| `tesla-dual-lin-rev-a-erc.rpt` | ERC report (root) |
| `test_minimal-drc.rpt` | DRC report (root) |

---

## Firmware

| File | Purpose |
|---|---|
| `src/main.cpp` | XIAO ESP32-C3 v5.1 — build profiles, safe arm gate, BLE status, ring buffer |
| `src/car_passthrough.cpp` | Dual-transceiver passthrough prototype for cut-wire bridge |
| `src/secrets.h.example` | WiFi/API settings template |
| `platformio.ini` | Build config: `field_passive` default, `bench_active_ble`, `chip_lab_active` |

---

## Design Docs

| File | Purpose |
|---|---|
| `docs/final-board-ordering-decision-2026-05-29.md` | **Current Rev A order decision** — ESP32-S3-WROOM-1U-N8R8 + 2x TJA1021T/20 |
| `docs/final-chip-architecture.md` | Dual-LIN active passthrough board architecture |
| `docs/model3y-steering-lin-2026-05-28.md` | **Model 3/Y confirmed IDs** — 0x2A left (volume up/down/click), 0x2B right |
| `docs/model3y-passthrough-volume.md` | Cut-wire passthrough architecture and commands |
| `docs/bench-revalidation-2026-05-27.md` | BLE fix + APG reseat proof (latest full bench validation) |
| `docs/chip-sourcing-shortlist-2026-05-29.md` | ESP32-S3 + TJA1021 supplier shortlist |
| `docs/secure-provisioning-anti-cloning-2026-05-29.md` | nRF5340 anti-cloning design notes |
| `docs/single-board-rev-a-product-spec-2026-05-29.md` | Rev A product spec |
| `docs/bench-fixture.md` | Bench fixture wiring reference |
| `docs/ble-phone-proof-checklist.md` | BLE phone-side verification checklist |

---

## Field Reports (docs/reports/)

| File | Purpose |
|---|---|
| `tesla-modelx-xiao-lin-field-analysis-2026-05-17.md` | Model X field session — XIAO passive capture analysis |
| `tesla-modelx-lin-desktop-ai-context-2026-05-18.md` | Model X LIN analysis — desktop AI synthesis context |
| `tesla-lin-bench-equipment-inventory-2026-05-19.md` | Bench equipment inventory |
| `tesla-lin-bench-handoff-2026-05-26.md` | Bench setup handoff (2026-05-26) |

---

## Research Directives (research/directives/)

| File | Topic |
|---|---|
| `019-tesla-purchase-due-diligence.md` | Tesla vehicle purchase due diligence |
| `022-tesla-logical-purchase-check.md` | Tesla purchase logical check |
| `027-final-3-call-day-tesla-shortlist.md` | Final 3 shortlisted vehicles |
| `044-esp32c3-lin-physical-layer-and-passive-capture-hardening.md` | ESP32-C3 LIN physical layer |
| `045-tesla-modelx-lin-id-0c-confidence-and-safe-gating.md` | Model X LIN ID 0x0C confidence build |
| `046-esp32c3-native-usb-cdc-platformio-windows-reliability.md` | ESP32-C3 USB CDC reliability |
| `047-authoritative-lin-receiver-and-esp32c3-thresholds.md` | LIN receiver + ESP32-C3 voltage thresholds |
| `052-tesla-lin-chip-sourcing-board-architecture.md` | LIN chip sourcing and board architecture |
| `053-compact-all-in-one-lin-ble-board-selection.md` | Compact LIN+BLE board selection |
| `054-nrf5340-firmware-protection-anti-cloning-anti-abuse.md` | nRF5340 firmware protection |
| `055-cheapest-reliable-dual-lin-ble-passthrough-chip.md` | Cheapest reliable dual-LIN BLE chip |
| `056-authoritative-dual-lin-ble-bom-datasheet-check.md` | Authoritative BOM datasheet check |

---

## Research Responses (research/responses/)

Key synthesis documents:

| File | Topic |
|---|---|
| `2026-05-17-tesla-modelx-xiao-master-synthesis.md` | Master synthesis — Model X XIAO LIN work |
| `2026-05-29-tesla-lin-chip-sourcing-board-architecture.md` | Chip sourcing + board architecture synthesis |
| `2026-05-29-dual-lin-esp32-s3-rev-a-schematic-and-pcba-design-rules-*.md` | Rev A schematic and PCBA design rules |
| `2026-05-29-cost-optimized-rev-a-dual-lin-esp32-s3-pcba-bom-research-*.md` | Rev A cost-optimized BOM |
| `2026-05-29-100-unit-dual-lin-ble-passthrough-board-manufacturing-plan-*.md` | 100-unit manufacturing plan |
| `2026-05-31-tesla-dual-lin-rev-a-order-readiness-*.md` | Rev A order readiness check |
| `2026-06-01-quick-research-jlc-lcsc-part-matches-*.md` | JLCPCB/LCSC part matches for Rev A BOM |
| `2026-04-29-020-tesla-lin-frame-id-crack-directive-*.md` | LIN frame ID crack directive |
| `2026-05-10-tesla-model-3-y-steering-wheel-lin-bus-frame-id-research-*.md` | Model 3/Y frame ID research |
| `2026-05-10-tesla-model-3-y-steering-wheel-lin-bus-physical-access-point-*.md` | Model 3/Y physical access points |
| `2026-05-17-research-directive-2025-tesla-model-x-steering-lin-id-0x0c-*.md` | Model X ID 0x0C confidence build |
| `2026-05-17-2025-tesla-model-x-sccm-lin-passive-capture-*.md` | Model X SCCM LIN passive capture |
| `2026-05-18-urgent-tesla-lin-bench-mock-and-parts-research-*.md` | Bench mock and parts research |
| `2026-05-29-tesla-model-3-efuse-reset-time-*.md` | eFuse reset time after short circuit |
| `efuse-tesla-m3-steering-reset.md` | eFuse steering reset reference |
| `019-tesla-purchase-due-diligence-synthesis.md` | Purchase due diligence synthesis |
| `022-tesla-logical-purchase-check.md` | Purchase logical check response |
| `027-final-3-call-day-tesla-shortlist.md` | Final shortlist response |

---

## Hardware Knowledge Base (knowledge/hardware/)

| File | Topic |
|---|---|
| `2026-04-17-tesla-research-set-overview.md` | Research set overview |
| `2026-04-17-tesla-tsl-decision-memo.md` | TSL product decision memo |
| `2026-04-17-tesla-tsl-family-reverse-engineering-map.md` | TSL family RE map |
| `2026-04-17-tesla-tsl-source-matrix.md` | TSL source matrix |
| `2026-04-17-tesla-tsl-vendor-family-timeline.md` | TSL vendor/family timeline |
| `2026-04-17-tesla-anti-nag-public-landscape.md` | Anti-nag public landscape |
| `2026-04-17-tesla-anti-nag-vendor-map-and-diy-difficulty.md` | Vendor map and DIY difficulty |
| `2026-04-17-tesla-tsl-bench-proof-plan.md` | Bench proof plan |
| `2026-04-17-tesla-tsl-bench-session-worksheet.md` | Bench session worksheet |
| `2026-04-18-tesla-multi-board-comparison-worksheet.md` | Multi-board comparison worksheet |
| `2026-04-18-tesla-multi-board-diagnostic-comparison-plan.md` | Multi-board diagnostic comparison plan |
| `2026-05-06-tesla-anti-nag-parts-inventory.md` | Anti-nag parts inventory |

---

## Captures

| Dir | Content |
|---|---|
| `captures/sigrok/` | Raw Sigrok .sr captures — FX2 device, Model X field sessions (2026-05-17) |
| `logs/` | Bench LIN CSV captures, active proof logs, bench-evidence session archives |

---

## Photos (photos/)

8 vehicle visit photos from Model X field session 2026-05-17 (SCCM access, steering column, LIN harness).

---

## Audit Logs (audit-logs/)

| File | Event |
|---|---|
| `2026-04-27_012100_tesla_deal_pass.md` | Tesla vehicle purchase decision — passed on deal |
| `2026-05-26_205500_lin-bench-full-setup.md` | Full bench setup session |

---

## Tools (tools/)

See `TOOLS.md` for full reference. Notable additions:

| File | Purpose |
|---|---|
| `tesla-tsl5-lin-capture.ps1` | LIN capture via FX2/Sigrok for TSL5 bench work |
| `tesla-tsl5-bench-readiness.ps1` | TSL5 bench readiness and environment check |
