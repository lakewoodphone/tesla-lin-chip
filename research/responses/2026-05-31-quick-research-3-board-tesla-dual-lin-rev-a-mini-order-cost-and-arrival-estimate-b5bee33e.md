---
job_id: b5bee33e-315b-4d53-ac85-8310d29985e6
directive_id: quick-research-3-board-tesla-dual-lin-rev-a-mini-order-cost-and-arrival-estimate
title: Quick Research: 3-board Tesla Dual LIN Rev A mini order cost and arrival estimate
domain: legal
sensitivity: standard
model_used: gpt-5.5
provider: openai
status: complete
completed_at: 2026-05-31T19:25:54.894468+00:00
cost_usd: 0.16414
input_tokens: 15544
output_tokens: 1953
reasoning_tokens: 261
search_count: 2
citation_count: 5
verifier_status: passed
schema_version: 1
---

## Quick estimate — 3-board Tesla Dual LIN Rev A mini order  
**Date basis:** 2026-05-31. **Destination assumed:** NJ/NY, USA.  
**Important:** an exact quote requires uploading **Gerbers + BOM + CPL/PNP** to JLCPCB/PCBWay; the ranges below are realistic pre-upload estimates.

### Current vendor facts used

- **JLCPCB PCBA:** JLCPCB documents Economic vs Standard PCBA capability, including **single-sided SMT / thru-hole** for Economic and 2/4/6-layer support; listed Economic PCBA build time is **1–3 days**, with Standard **≥4 days**, depending on options. ([jlcpcb.com](https://jlcpcb.com/capabilities/pcb-assembly-capabilities?utm_source=openai))  
- JLCPCB says SMT assembly lead time starts after bare PCBs arrive at the SMT line, while they use parallel preparation during PCB fab; quoted online price is real-time and includes setup/stencil/labor/components as applicable. ([jlcpcb.com](https://jlcpcb.com/help/article/smt-service-lead-time-overview?utm_source=openai))  
- JLCPCB notes through-hole support via wave soldering, but actual eligibility depends on the uploaded assembly data and parts. ([jlcpcb.com](https://jlcpcb.com/help/article/1098-pcb-assembly-faqs?utm_source=openai))  
- JLCPCB shipping delivery estimates are explicitly **not guaranteed**, and international shipments may incur duties/taxes beyond the shipping charge. ([jlcpcb.com](https://jlcpcb.com/es/help/article/shipping-methods-and-delivery-time?utm_source=openai))  
- **PCBWay fallback:** PCBWay advertises PCB assembly lead time of **3–5 days**; final PCBA pricing is quote/RFQ-driven. ([m.pcbway.com](https://m.pcbway.com/pcb-assembly.html?utm_source=openai))  

---

# Compass estimate — cost and arrival

| Bucket | Low | Likely | High | Notes |
|---|---:|---:|---:|---|
| **Bare PCB fabrication only** | **$25** | **$45–70** | **$100–140** | 100 × 56 mm, 4-layer, ENIG, qty likely 5 minimum even if only 3 needed. ENIG and 4-layer push above “promo” pricing. |
| **Vendor-assembled PCBA** | **$120** | **$170–260** | **$350–500** | Assumes most parts are LCSC/JLC-available, single-side assembly, no exotic substitutions, no major DFM issue. Includes assembly setup/stencil/labor + BOM. |
| **Manual / secondary ops** | **$10** | **$25–60** | **$100–180** | If Micro-Fit THT connectors and/or DPDT switch are not placed by vendor: hand-solder 6–9 parts total across 3 boards. Higher end if done by paid tech/local shop. |
| **Shipping / taxes / tariff buffer** | **$25** | **$45–90** | **$120–200** | Express shipping to NJ/NY usually dominates small orders. US import/tariff treatment can change; use vendor checkout total as source of truth. |
| **Total bare PCB only, landed** | **$50** | **$90–160** | **$220–320** | For unassembled boards only. |
| **Total assembled mini order, landed** | **$160** | **$240–410** | **$550–850** | Most realistic bench-test budget: **$300–450** if BOM is LCSC-friendly. |

**Compass arrival estimate from order placement**

- **JLCPCB bare PCB only:** likely **6–10 calendar days**, high-confidence window **5–14 calendar days**.  
- **JLCPCB PCBA:** likely **8–14 calendar days**, high-confidence window **7–21 calendar days** if no engineering questions, no part stock issue, and express/DDP-style shipping is selected.  
- **PCBWay PCBA fallback:** likely **10–18 calendar days**, high-confidence window **9–25 calendar days**, because assembly is more RFQ/sourcing dependent.

---

# Gemini estimate — cost and arrival

| Scenario | Low | Likely | High | Delivery window |
|---|---:|---:|---:|---|
| **A. Bare PCB fab only, JLCPCB** | **$45 landed** | **$100–140 landed** | **$250+ landed** | **~1–2 weeks** |
| **B. JLCPCB Economic/Standard PCBA, mostly turnkey** | **$180 landed** | **$280–450 landed** | **$700+ landed** | **~9–16 calendar days** |
| **C. JLCPCB assembled SMT only + manual THT/switch** | **$170 landed + labor** | **$300–500 landed** | **$750+ landed** | **~9–17 days + 0–2 days rework** |
| **D. PCBWay full assembly fallback** | **$300 landed** | **$450–750 landed** | **$1,000+ landed** | **~12–25 calendar days** |

**Gemini notes**

- For qty 3, the non-recurring setup/stencil/review/shipping costs dominate. The per-board BOM is probably not the main cost driver unless ESP32-S3-WROOM-1U, Molex connectors, or power parts are not in stock or require substitution.  
- The two Molex Micro-Fit 3.0 **43650-0415** THT board connectors are the main assembly risk. JLCPCB may support THT/wave soldering, but whether these exact connectors are eligible depends on the uploaded BOM/CPL and their process constraints.  
- If fastest bench testing matters more than a clean “production-like” assembly, let JLCPCB place all eligible SMT, then hand-install the Micro-Fit connectors and DPDT switch in-house.

---

## Recommended ordering path

**Fastest reliable path:**  
1. Upload to **JLCPCB PCBA first**, using **Economic PCBA** if the board and all selected parts qualify; otherwise use **Standard PCBA**.  
2. Mark the **Micro-Fit connectors and DPDT switch as DNI / not assembled** if JLC rejects them or adds delay.  
3. Order the THT connectors/switch separately from Digi-Key/Mouser/LCSC and hand-solder after boards arrive.  
4. Use express shipping rather than postal/airmail for a bench-test build.

**Practical budget to approve now:**  
- **Bare PCB only:** approve **$150**.  
- **3 assembled bench boards via JLCPCB with possible manual connector install:** approve **$450**.  
- **Contingency / fallback via PCBWay:** approve up to **$750–900** if JLCPCB has BOM/process blockers.

**Most realistic arrival if ordered today, Sunday May 31, 2026:**  
- **JLCPCB bare PCB:** around **June 6–10, 2026**; conservative **by June 14, 2026**.  
- **JLCPCB PCBA:** around **June 9–15, 2026**; conservative **by June 21, 2026**.  
- **PCBWay fallback PCBA:** around **June 12–25, 2026**, depending on RFQ review and parts sourcing.


## Citations

1. PCB Manufacturing & Assembly Capabilities - JLCPCB - https://jlcpcb.com/capabilities/pcb-assembly-capabilities?utm_source=openai
2. SMT Service Lead Time Overview - https://jlcpcb.com/help/article/smt-service-lead-time-overview?utm_source=openai
3. PCB Assembly FAQs - https://jlcpcb.com/help/article/1098-pcb-assembly-faqs?utm_source=openai
4. Métodos de envío y tiempo de entrega - https://jlcpcb.com/es/help/article/shipping-methods-and-delivery-time?utm_source=openai
5. Surface Mount SMT PCB Assembly Service - PCBWay - https://m.pcbway.com/pcb-assembly.html?utm_source=openai
