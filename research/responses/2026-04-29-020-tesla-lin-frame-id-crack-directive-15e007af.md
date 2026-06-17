---
job_id: 15e007af-c9eb-4cf2-89d8-9c493b41cd62
directive_id: 020-tesla-lin-frame-id-crack-directive
title: 020 Tesla Lin Frame Id Crack Directive
domain: automotive_re
sensitivity: no_refusal_required
model_used: moonshotai/kimi-k2.6
provider: openrouter
status: complete
completed_at: 2026-04-29T17:34:22.256844+00:00
cost_usd: 0.03579
input_tokens: 12213
output_tokens: 6048
reasoning_tokens: 0
search_count: 4
citation_count: 14
verifier_status: passed
schema_version: 1
---

1. FINDINGS SUMMARY
Zero confirmed Frame IDs, PID bytes, or 8-byte payloads were recovered from the provided source set. All fourteen prefetched sources are outside the scope of Tesla interior-bus reverse engineering: they consist of NHTSA recall notices, EV market analytics, unrelated academic papers, generic CAN-bus tutorials, and federal procurement data. No raw LIN captures, no leaked service topology, no diagnostic tool disclosures, and no Ryan Huber documentation were found. Consequently, both firmware constants—`SCROLL_WHEEL_FRAME_ID` and `SCROLL_DATA[8]`—remain blocked.

2. Q1 RESULTS — Raw LIN captures
Confidence: UNKNOWN
- Sources [2][3] (Tesla Motors Club, “2023 model Y steering wheels problem error UI_a020”) were inspected for embedded LIN dumps or hex traces. They contain only owner-reported diagnostic trouble code UI_a020 and symptom discussion; no logic-analyzer output, .csv frames, .ldf files, or PLIN-USB captures are present [2][3].
- Sources [13][14] (Stack Overflow, All About Circuits) are generic CAN frame-structure tutorials (arbitration, control, CRC fields) and contain no Tesla-specific LIN data, no SavvyCAN LIN examples, and no 19,200-baud captures [13][14].
- No opendbc LIN branches, Comma.ai/Panda LIN test scripts, or conference papers were located in the provided set.

3. Q2 RESULTS — Diagnostic / tool sources
Confidence: UNKNOWN
- Sources [1][4] (Facebook/Teslarati and LinkedIn articles on NHTSA steering-wheel probes) are media coverage of mechanical recall issues; they name no LIN node IDs, diagnostic adapters, or tool firmware [1][4].
- Sources [10][11][12] (Recurrent Auto, Fortune Business Insights, Reddit) address 2026 EV market trends, pricing, and tax-credit demand shifts; they contain no automotive bus diagnostics [10][11][12].
- Source [9] (ResearchGate) is an unavailable/blocked EV-market PDF; no LIN content could be retrieved [9].
- No TeslaScope, Tesspy, pyTesla, Panda LIN, OBDLink, Carista, or third-party TPMS tool documentation was found.

4. Q3 RESULTS — Service docs / firmware leaks
Confidence: UNKNOWN
- No service manuals, wiring diagrams, MCU firmware dumps, NHTSA ECU-level bus-architecture filings, or ALLDATA previews appear in the source set.
- Sources [5][6][7][8] (SBIR award CSV, arXiv “Ara Protocol” paper, analytics.usa.gov traffic data, Murdoch probiotics PDF) are entirely unrelated to automotive networking [5][6][7][8].

5. Q4 RESULTS — Ryan Huber findings
Confidence: UNKNOWN
- Ryan Huber, his Plaid-to-Model-3 retrofit write-ups, translation-layer source code, and any partial hex disclosures are absent from all prefetched sources. No tweets, GitHub repositories, blog posts, or forum threads referencing his work were found.

6. Q5 RESULTS — Encoding format (delta vs. rolling counter)
Confidence: UNKNOWN
- None of the sources clarify whether Tesla scroll-wheel LIN uses one-shot delta or accumulated counter encoding. The generic CAN tutorials in [13][14] do not reference Tesla Party CAN ID 0x785 (decimal 785) or the `scrollWheelPressed` signal. No opendbc excerpts were present to correlate CAN-layer behavior with LIN-layer encoding.

7. Q6 RESULTS — Gen 1 vs. Gen 2 frame ID relationship
Confidence: UNKNOWN
- No evidence in the source set addresses whether VCLEFT uses the same 6-bit Frame ID across stalk (Gen 1) and stalkless (Gen 2) platforms, or whether turn-signal/wiper/horn functions are multiplexed onto the same frame. The NHTSA recall sources [1][4] discuss physical steering-wheel detachment, not LIN topology differences between model years.

8. FIRMWARE CONSTANTS
No values can be filled from the current evidence.

| Constant | Gen 1 (Stalk) | Gen 2 (Stalkless) | Evidence Status |
|---|---|---|---|
| `SCROLL_WHEEL_FRAME_ID` | Unknown | Unknown | No source found |
| `SCROLL_DATA` idle[8] | Unknown | Unknown | No source found |
| `SCROLL_DATA` up[8] | Unknown | Unknown | No source found |
| `SCROLL_DATA` down[8] | Unknown | Unknown | No source found |

9. REMAINING BLOCKERS
Both firmware constants remain blocked. The provided source set does not contain any automotive bus reverse-engineering artifacts for Tesla. A targeted external search is required.

**Proposed next query set**
1. **GitHub** — `tesla lin steering wheel frame id`, `VCLEFT LIN`, `tesla scroll wheel hex`, `ryanhuber plaid model3 lin`, `opendbc lin tesla`.
2. **Tesla Motors Club / Reddit** — `LIN bus logic analyzer steering wheel`, `PLIN-USB tesla`, `Saleae tesla steering wheel`, `scroll wheel raw hex`.
3. **YouTube / Blogs** — `tesla steering wheel retrofit lin protocol`, `ryan huber plaid steering wheel`, `tesla stalkless lin reverse engineering`.
4. **Conference / Academic** — DEFCON, Black Hat, CCC, PoC||GTFO archives for `tesla interior bus LIN`, `VCLEFT`, `body control`.
5. **Commercial / Grey-market** — AliExpress/Taobao listings for `Tesla steering wheel emulator LIN`, `anti nag module frame`, `TSL5 TSL6 LIN id`.
6. **opendbc & Comma.ai** — Deep search of opendbc issues/PRs and panda firmware for `lin`, `785`, `scroll`, `wheel`, `vcleft`.

10. CITATIONS

[1] Teslarati. “NHTSA has ended a probe into over 120,000 Tesla Model Y vehicles…” Facebook, 2023. Checked: no LIN data. URL: https://www.facebook.com/Teslarati/posts/nhtsa-has-ended-a-probe-into-over-120000-tesla-model-y-vehicles-after-claims-tha/1373182654832063/

[2] Tesla Motors Club. “2023 model Y steering wheels problem error UI_a020.” Checked: DTC UI_a020 discussion only; no LIN dumps. URL: https://teslamotorsclub.com/tmc/threads/2023-model-y-steering-wheels-problem-error-ui_a020.299528/

[3] Tesla Motors Club. “2023 model Y steering wheels problem error UI_a020 | Page 2.” Checked: same as [2]. URL: https://teslamotorsclub.com/tmc/threads/2023-model-y-steering-wheels-problem-error-ui_a020.299528/page-2

[4] LinkedIn News. “Tesla steering wheels under probe.” Checked: NHTSA recall coverage; no bus diagnostics. URL: https://www.linkedin.com/news/story/tesla-steering-wheels-under-probe-5569964/

[5] SBIR.gov. Award data CSV. Checked: unrelated federal procurement data. URL: https://data.www.sbir.gov/mod_awarddatapublic_no_abstract/award_data_no_abstract.csv

[6] arXiv. “The Ara Protocol.” Checked: research reproducibility protocol; no automotive content. URL: https://arxiv.org/html/2604.24658v1

[7] analytics.usa.gov. “all-pages-realtime.csv.” Checked: federal web traffic; unrelated. URL: https://analytics.usa.gov/data/live/all-pages-realtime.csv

[8] Murdoch University. “Probiotics and human health…” PDF. Checked: biology review; unrelated. URL: https://researchportal.murdoch.edu.au/view/pdfCoverPage?instCode=61MUN_INST&filePid=13194056910007891&download=true

[9] ResearchGate. “The Future of Electric Vehicles…” Checked: unavailable/EV market trends; no LIN data. URL: https://www.researchgate.net/publication/390661749_The_Future_of_Electric_Vehicles_Technological_Innovations_and_Market_Trends

[10] Recurrent Auto. “2026 EV Market & Trends Report.” Checked: market analysis; no bus diagnostics. URL: https://www.recurrentauto.com/research/new-ev-market-trends-report

[11] Fortune Business Insights. “Electric Vehicle Market Size, Share, Growth, Report, 2034.” Checked: market forecast; no LIN data. URL: https://www.fortunebusinessinsights.com/industry-reports/electric-vehicle-market-101678

[12] Reddit r/electricvehicles. “What is really going on with the EV market?” Checked: market discussion; no LIN data. URL: https://www.reddit.com/r/electricvehicles/comments/18gob2j/what_is_really_going_on_with_the_ev_market/

[13] Stack Overflow. “Controller Area Network (CAN).” Checked: generic CAN tutorial; no Tesla LIN. URL: https://stackoverflow.com/questions/65188892/controller-area-network-can

[14] All About Circuits Forum. “CAN Message Frame.” Checked: generic CAN tutorial; no Tesla LIN. URL: https://forum.allaboutcircuits.com/threads/can-message-frame.197286/


## Citations

1. NHTSA has ended a probe into over 120,000 Tesla Model Y ... - https://www.facebook.com/Teslarati/posts/nhtsa-has-ended-a-probe-into-over-120000-tesla-model-y-vehicles-after-claims-tha/1373182654832063/
2. 2023 model Y steering wheels problem error UI_a020 - https://teslamotorsclub.com/tmc/threads/2023-model-y-steering-wheels-problem-error-ui_a020.299528/
3. 2023 model Y steering wheels problem error UI_a020 | Page 2 - https://teslamotorsclub.com/tmc/threads/2023-model-y-steering-wheels-problem-error-ui_a020.299528/page-2
4. Tesla steering wheels under probe | LinkedIn - https://www.linkedin.com/news/story/tesla-steering-wheels-under-probe-5569964/
5. https://data.www.sbir.gov/mod_awarddatapublic_no_a... - https://data.www.sbir.gov/mod_awarddatapublic_no_abstract/award_data_no_abstract.csv
6. 1 Introduction - https://arxiv.org/html/2604.24658v1
7. Learn More - analytics.usa.gov - https://analytics.usa.gov/data/live/all-pages-realtime.csv
8. [PDF] Probiotics and human health: biological activities, nutritional aspects ... - https://researchportal.murdoch.edu.au/view/pdfCoverPage?instCode=61MUN_INST&filePid=13194056910007891&download=true
9. (PDF) The Future of Electric Vehicles: Technological Innovations ... - https://www.researchgate.net/publication/390661749_The_Future_of_Electric_Vehicles_Technological_Innovations_and_Market_Trends
10. 2026 EV Market & Trends Report - https://www.recurrentauto.com/research/new-ev-market-trends-report
11. Electric Vehicle Market Size, Share, Growth, Report, 2034 - https://www.fortunebusinessinsights.com/industry-reports/electric-vehicle-market-101678
12. What is really going on with the EV market? : r/electricvehicles - Reddit - https://www.reddit.com/r/electricvehicles/comments/18gob2j/what_is_really_going_on_with_the_ev_market/
13. Controller Area Network (CAN) - Stack Overflow - https://stackoverflow.com/questions/65188892/controller-area-network-can
14. CAN Message Frame - All About Circuits Forum - https://forum.allaboutcircuits.com/threads/can-message-frame.197286/
