---
job_id: 62723b8e-d83d-41a6-8c49-8dc4f78a742b
directive_id: quick-research-jlc-lcsc-part-matches-for-tesla-dual-lin-rev-a-quote-bom
title: Quick Research: JLC/LCSC Part Matches for Tesla Dual LIN Rev A Quote BOM
domain: legal
sensitivity: standard
model_used: gpt-5.5
provider: openai
status: complete
completed_at: 2026-06-01T06:26:38.379918+00:00
cost_usd: 0.443845
input_tokens: 48645
output_tokens: 3575
reasoning_tokens: 779
search_count: 7
citation_count: 19
verifier_status: passed
schema_version: 1
---

## Quick result — JLC/LCSC matches for missing SMT BOM rows  
**Date checked:** 2026-06-01.  
**Scope note:** I only list an LCSC number where I found supporting evidence. “Basic/Common/Extended” is often not visible in public LCSC search snippets; where not directly confirmed, I mark it **unknown** or **likely**.

| BOM row | Recommended LCSC part | Match notes | JLC status | Confidence |
|---|---:|---|---|---|
| **C_3V3 — 22uF 10V, C_1206_3216Metric** | **C108717** | FH **1206X226M100NT**; 22uF, 10V, X5R, 1206 ceramic MLCC. Exact value/package/voltage; OK for 3V3 bulk, but expect DC-bias derating. ([lcsc.com](https://www.lcsc.com/product-detail/Multilayer-Ceramic-Capacitors-MLCC-SMD-SMT_22uF-226-20-10V_C108717.html?utm_source=openai)) | Unknown; likely assembly-available, may be Extended | **High** |
| **C_BST1, C_U1_DEC1, C_U2_DEC1, C_U3_DEC1, C_U4_DEC1 — 100nF 50V, C_0603_1608Metric** | **C91183** | Yageo **CC0603JRX7R9BB104**; 100nF, 50V, X7R, 0603. Exact value/package/voltage; good decoupler. ([lcsc.com](https://www.lcsc.com/product-detail/Multilayer-Ceramic-Capacitors-MLCC-SMD-SMT_100nF-104-5-50V_C91183.html?utm_source=openai)) | Unknown; common commodity, likely Basic/Common but not confirmed | **High** |
| **C_EN1 — 1uF 10V, C_0603_1608Metric** | **C15849** | Samsung **CL10A105KB8NNNC**; public LCSC category listing shows 1uF, 50V, X5R, 0603. This exceeds 10V rating and matches footprint. ([lcsc.com](https://www.lcsc.com/category/1142.html?utm_source=openai)) | Unknown; likely Common/Extended | **High** |
| **C_IN1 — 10uF 50V, C_1206_3216Metric** | **C13585** | 10uF, 50V, X5R, 1206 MLCC per LCSC capacitor listing. Exact value/package/voltage. For vehicle input, OK as ceramic bulk but should not be the only surge/hold-up element. ([lcsc.com](https://www.lcsc.com/flashSale/capacitors_312.html?utm_source=openai)) | Unknown; likely Extended | **Medium-High** |
| **D1 — SMBJ24A/26A TVS, D_SMB** | **C224017** preferred; **C493201** acceptable cheaper alt | Littelfuse **SMBJ24A**, LCSC C224017: 24V VRWM, 29.5V breakdown, unidirectional, SMB/DO-214AA family; reputable brand for vehicle-power protection. SMC C493201 is also SMBJ24A, SMB(DO-214AA), 24VWM, 38.9VC, 600W. ([lcsc.com](https://www.lcsc.com/product-detail/C224017.html?utm_source=openai)) | Likely Extended | **High** for C224017 footprint/value; **Medium** for system-level suitability |
| **D2 — LIN_A ESD, D_SOD-323** | **C20345390** if orderable/assembly-supported | TI **ESD1LIN24-Q1** datasheet via LCSC: automotive 24V, 1-channel ESD, **SOD-323/DYF**, intended for LIN-style 24V protection. This is the best safety-quality match found, but public result was datasheet rather than full product page/stock. ([datasheet.lcsc.com](https://datasheet.lcsc.com/datasheet/pdf/4d54fbbecc9b9f427e0d3e5c10499982.pdf?productCode=C20345390&utm_source=openai)) | Unknown; likely Extended/manual review | **Medium** |
| **D3 — LIN_B ESD, D_SOD-323** | **C20345390** if orderable/assembly-supported | Same as D2. Use same part on both LIN lines for symmetric protection. ([datasheet.lcsc.com](https://datasheet.lcsc.com/datasheet/pdf/4d54fbbecc9b9f427e0d3e5c10499982.pdf?productCode=C20345390&utm_source=openai)) | Unknown; likely Extended/manual review | **Medium** |
| **D4 — USB ESD, SOT-23-6** | **C138714** preferred if selecting TI; **C2827646** lower-cost clone/alt | TI **TPD4E05U06DQAR**, LCSC listing in category shows **C138714**, 4-channel, 5.5V VRWM, low-cap ESD, SOT-23-6-class USB/high-speed protection; TECH PUBLIC C2827646 has same MPN string and specs but not TI. ([lcsc.com](https://lcsc.com/products/ESD-and-Surge-Protection-TVS-ESD_526_page4.html?utm_source=openai)) | C138714 likely Hot/Common; confirm in JLC cart | **Medium-High** |
| **F1 — 1812 PPTC, Fuse_1812_4532Metric** | **C913244** | Bourns **MF-MSMF050/40X-2**, package 1812. This is a reputable PPTC family; exact hold/trip/current must be checked against your input current budget before locking. ([lcsc.com](https://www.lcsc.com/product-detail/C913244.html?utm_source=openai)) | Unknown; likely Extended | **Medium** |
| **FB1 — 1206 input ferrite, L_1206_3216Metric** | **C845119** preferred; **C127295** alt | Vishay **ILHB1206ER601V**, 600Ω@100MHz, 1206, 2.5A, 70mΩ; strong input ferrite choice. TAI-TECH C127295 is 600Ω@100MHz, 1206, 1A, 100mΩ. ([lcsc.com](https://www.lcsc.com/product-detail/C845119.html?utm_source=openai)) | Unknown; likely Extended | **High** |
| **J1 — USB-C service, HRO TYPE-C-31-M-12 footprint** | **C165948** | Korean Hroparts **TYPE-C-31-M-12**, exact MPN/footprint family; LCSC shows 16P SMD USB-C receptacle and high stock. This is the KiCad HRO footprint match. ([lcsc.com](https://www.lcsc.com/product-detail/C165948.html?utm_source=openai)) | Likely Common/Extended; confirm in JLC cart | **High** |
| **L1 — 10uH shielded, L_Bourns_SRU5016_5.2x5.2mm** | **Blank — manual review** | I found Bourns SRU5016 family evidence and SRU5016-100Y specs from distributors, but not a confident LCSC product page/part number. Do **not** auto-substitute a generic 5x5 inductor without checking pad geometry, saturation current, DCR, and LM5164 current ripple. ([bourns.com](https://bourns.com/docs/technical-documents/technical-library/inductive-components/publications/Bourns_IC_Product_Application_xref_guide.pdf?sfvrsn=4&utm_source=openai)) | Needs manual JLC/LCSC match | **Low** |
| **Q1 — AO4407A-class reverse PFET, SOIC-8_3.9x4.9mm_P1.27mm** | **C16072** | AOS **AO4407A**, P-channel MOSFET, 30V, 12A, SOIC-8; exact named part and footprint class. For vehicle input reverse protection, verify 30V VDS margin versus your surge strategy; TVS must clamp appropriately. ([lcsc.com](https://www.lcsc.com/product-detail/MOSFET_Alpha-Omega-Semicon-AOS-AO4407A_C16072.html?utm_source=openai)) | Unknown; likely Extended | **High** for part match; **Medium** for vehicle margin |
| **100k 0603 resistor row** | **C25803** | UNI-ROYAL **0603WAF1003T5E**; external indexed data tied to LCSC datasheet shows 100kΩ, 100mW, 75V, ±1%, 0603. ([flux.ai](https://www.flux.ai/hoopla/0603waf1003t5e-7wn4s?utm_source=openai)) | Likely Basic/Common commodity; not directly confirmed | **Medium-High** |
| **10k 0603 resistor row** | **C25804** | UNI-ROYAL **0603WAF1002T5E**; multiple indexed references tie C25804 to 10kΩ, 0603, ±1% thick-film. ([lcsc.com](https://lcsc.com/flashSale/resistors_308.html?utm_source=openai)) | Likely Basic/Common commodity; not directly confirmed | **High** |
| **R_BUCK_RON1 — 200k prelim 0603** | **C25811** | UNI-ROYAL **0603WAF2003T5E**; LCSC brand page shows 200kΩ, ±1%, 100mW, 75V, 0603 thick-film. ([lcsc.com](https://www.lcsc.com/brand/1199-99.html?utm_source=openai)) | Likely Basic/Common commodity; not directly confirmed | **High** |
| **5.1k 0603 resistor row** | **C101083** | LIZ **CR0603FA5101G**; 5.1kΩ, ±1%, 100mW, 0603 thick-film. Suitable for USB-C CC Rd if these are the 5.1k parts. ([lcsc.com](https://www.lcsc.com/product-detail/chip-resistor-surface-mount_liz-elec-cr0603fa5101g_C101083.html?utm_source=openai)) | Unknown; likely common commodity | **High** |
| **R_FB_TOP1 — 174k 0603** | **C482778** | Yageo **RC0603FR-07174KL**; 174kΩ, 100mW, 75V, ±1%, 0603. Exact E96 feedback value. ([lcsc.com](https://www.lcsc.com/product-detail/Chip-Resistor-Surface-Mount_YAGEO-RC0603FR-07174KL_C482778.html?utm_source=openai)) | Likely Extended/Common; not confirmed | **High** |
| **10R 0603 resistor row** | **C22859** | UNI-ROYAL **0603WAF100JT5E**; indexed references tie C22859 to 10Ω, 0603, ±1%, 100mW. ([flux.ai](https://www.flux.ai/vasy_skral/0603waf100jt5e.md?utm_source=openai)) | Likely Basic/Common commodity; not directly confirmed | **High** |
| **U4 — LM5164DDA 3V3 buck, HSOP-8/PowerPAD DDA** | **C477928** | TI **LM5164DDAR**; LCSC/TI datasheet shows LM5164DDAR, SO PowerPAD, package drawing **DDA**, 8 pins; matches HSOP/SO-8 PowerPAD DDA footprint. Public Flux/JLC-style component page labels it Extended. ([datasheet.lcsc.com](https://datasheet.lcsc.com/datasheet/pdf/0adc8e389ed3e6197be57b9940aa6370.pdf?productCode=C477928&utm_source=openai)) | **Extended confirmed by indexed component page** | **High** |

## Compass / Gemini split recommendations

### Compass recommendation set — conservative/protection-weighted
- Use **Littelfuse C224017** for D1 rather than lowest-cost SMBJ24A.
- Use **TI ESD1LIN24-Q1 C20345390** for both LIN ESD positions only if JLC confirms it is orderable and fits SOD-323.
- Use **TI TPD4E05U06DQAR C138714** for USB ESD if available, rather than the TECH PUBLIC C2827646 clone.
- Keep **L1 blank** until JLC/LCSC confirms an exact SRU5016-100Y or pad-compatible 5.2×5.2mm inductor with adequate saturation current.

### Gemini recommendation set — bench-test/assembly-friendly
- Passive commodity rows can be safely locked with the listed UNI-ROYAL/Yageo/Samsung/LIZ parts for first bench PCBAs.
- For FB1, prefer **C845119 Vishay** because it has better current rating than the 1A TAI-TECH option.
- For Q1, **C16072 AO4407A** is an exact part match, but system safety depends on D1 clamp behavior and expected vehicle transient profile.
- Let JLC auto-match only the rows where footprint/value are standard **and** the BOM row is non-safety-critical; do not auto-match D1/D2/D3/D4/F1/L1/U4.


## Citations

1. 1206X226M100NT | FH | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/Multilayer-Ceramic-Capacitors-MLCC-SMD-SMT_22uF-226-20-10V_C108717.html?utm_source=openai
2. CC0603JRX7R9BB104 | YAGEO | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/Multilayer-Ceramic-Capacitors-MLCC-SMD-SMT_100nF-104-5-50V_C91183.html?utm_source=openai
3. Ceramic Capacitors | Electronic Components Distributor | LCSC Electronics - https://www.lcsc.com/category/1142.html?utm_source=openai
4. Flash Sale | Electronic Parts Deals | LCSC Electronics - https://www.lcsc.com/flashSale/capacitors_312.html?utm_source=openai
5. SMBJ24A | Littelfuse | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/C224017.html?utm_source=openai
6. ESD1LIN24-Q1, ESD751-Q1, ESD761-Q1 - https://datasheet.lcsc.com/datasheet/pdf/4d54fbbecc9b9f427e0d3e5c10499982.pdf?productCode=C20345390&utm_source=openai
7. ESD and Surge Protection (TVS/ESD) | Electronic Components Distributor | LCSC Electronics - https://lcsc.com/products/ESD-and-Surge-Protection-TVS-ESD_526_page4.html?utm_source=openai
8. MF-MSMF050/40X-2 | BOURNS | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/C913244.html?utm_source=openai
9. ILHB1206ER601V | VISHAY | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/C845119.html?utm_source=openai
10. TYPE-C-31-M-12 | Korean Hroparts Elec | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/C165948.html?utm_source=openai
11. Bourns
® Inductors
Product Selection Guide • Appli - https://bourns.com/docs/technical-documents/technical-library/inductive-components/publications/Bourns_IC_Product_Application_xref_guide.pdf?sfvrsn=4&utm_source=openai
12. AO4407A | AOS | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/MOSFET_Alpha-Omega-Semicon-AOS-AO4407A_C16072.html?utm_source=openai
13. Schematic Symbol for 0603WAF1003T5E: -55℃~+155℃ 100kΩ 100mW 75V... - https://www.flux.ai/hoopla/0603waf1003t5e-7wn4s?utm_source=openai
14. Flash Sale | Electronic Parts Deals | LCSC Electronics - https://lcsc.com/flashSale/resistors_308.html?utm_source=openai
15. UNI-ROYAL Chip Resistor - Surface Mount | LCSC Electronics - https://www.lcsc.com/brand/1199-99.html?utm_source=openai
16. CR0603FA5101G | LIZ | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/chip-resistor-surface-mount_liz-elec-cr0603fa5101g_C101083.html?utm_source=openai
17. RC0603FR-07174KL | YAGEO | Price | In Stock | LCSC Electronics - https://www.lcsc.com/product-detail/Chip-Resistor-Surface-Mount_YAGEO-RC0603FR-07174KL_C482778.html?utm_source=openai
18. Loading · Flux - https://www.flux.ai/vasy_skral/0603waf100jt5e.md?utm_source=openai
19. LM5164 100-V Input, 1-A Synchronous Buck DC/DC Converter With Ultra-Low IQ datasheet (Rev. A) - https://datasheet.lcsc.com/datasheet/pdf/0adc8e389ed3e6197be57b9940aa6370.pdf?productCode=C477928&utm_source=openai
