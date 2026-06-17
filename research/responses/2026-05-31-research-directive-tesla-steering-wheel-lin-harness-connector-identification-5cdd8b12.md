---
job_id: 5cdd8b12-7353-40c5-87aa-31c14ab3141a
directive_id: research-directive-tesla-steering-wheel-lin-harness-connector-identification
title: Research Directive: Tesla Steering Wheel LIN Harness Connector Identification
domain: legal
sensitivity: standard
model_used: gpt-5.5
provider: openai
status: complete
completed_at: 2026-05-31T18:24:34.991187+00:00
cost_usd: 0.494965
input_tokens: 51221
output_tokens: 4087
reasoning_tokens: 875
search_count: 9
citation_count: 6
verifier_status: passed
schema_version: 1
---

## Tesla steering-wheel LIN connector finding — Compass + Gemini

### Team Compass — confirmed facts from Tesla public service/electrical docs

**Confirmed: the Model 3/Y-style steering-wheel controls path is not a simple 3-pin connector in Tesla documentation; the relevant steering-wheel switch inline connector is shown as a 4-cavity inline connector with three populated signals.**

Tesla Model Y SOP6 electrical reference, Steering page, labels the connector as **“Steering Wheel Switch Inline”** and shows:

> “Steering Wheel Switch Inline”  
> “VBatt (out) — X178-1 High-Side Drive”  
> “Ground — X178-2 Ground”  
> “LIN — X178-4 LIN” ([service.tesla.com](https://service.tesla.com/docs/ModelY/ElectricalReference/prog-202/diagram/2023.2_ModelY-SOP6.pdf))

So, for 2023-era Model Y SOP6 at least:

| Tesla ref | Function | Populated? |
|---|---:|---:|
| X178-1 | VBAT / high-side drive out | yes |
| X178-2 | Ground | yes |
| X178-3 | not shown in snippet as used for steering-wheel switch inline | likely unused |
| X178-4 | LIN | yes |

**Confirmed: the steering-wheel button controller itself is also shown as a 4-cavity device connector, with pins 1, 2, and 4 used.**

Tesla shows:

> “Steering Wheel Button Controller Ground — X184-1 Ground”  
> “Steering Wheel Button Controller Power — X184-2 High-Side Drive”  
> “Steering Wheel Button Controller LIN — X184-4 LIN” ([service.tesla.com](https://service.tesla.com/docs/ModelY/ElectricalReference/prog-202/diagram/2023.2_ModelY-SOP6.pdf))

**Confirmed: Tesla service procedures for 2017–2023 Model 3 and 2020–2024 Model Y refer to disconnecting the steering-wheel electrical harness, but do not expose connector family/pitch in the service manual text.**

Model 3 service manual:

> “Disconnect the steering wheel electrical wiring harness connector.” ([service.tesla.com](https://service.tesla.com/docs/Model3/ServiceManual/en-us/GUID-A8654666-5B69-4082-ADE0-4373AE46C154.html?utm_source=openai))

Model Y / Model 3 harness procedure:

> “Disconnect the steering wheel electrical wiring harness from the connector.” ([service.tesla.com](https://service.tesla.com/docs/Model3/ServiceManual/en-us/GUID-748469CF-09D5-4ECA-9234-255BFAAC6FFD.html?utm_source=openai))

**Confirmed: Tesla’s electrical-reference system states that connector popups contain connector cavity/function/destination data, and that inline connector gender is terminal-type based.**

Tesla’s interactive schematic guide says:

> “Click on pin numbers and connector blocks for connector reference information.”  
> “open the Connector cavities section to see all the cavities with their function and destination” ([service.tesla.com](https://service.tesla.com/docs/Model3/ElectricalReference/prog-233/interactive/html/index.html?expbackground=true&page=0))

Tesla’s printed electrical-reference notes say:

> “Inline connectors with ‘M’ suffix have male, tab or pin terminals”  
> “Inline connectors with ‘F’ suffix have female, receptacle or socket terminals” ([service.tesla.com](https://service.tesla.com/docs/Model3/ElectricalReference/prog-233/interactive/pdf/index_print.pdf))

### Team Gemini — connector-family identification status

**Hard conclusion:** I could confirm the **Tesla logical connector identity and pin usage** — **X178 / 4-cavity / pins 1, 2, 4 = VBAT, GND, LIN** — but I could **not prove the exact physical connector family, pitch, latch/keying, or mating commercial part numbers for Model 3/Y X178/X184 from public sources in the available evidence.**

The public Tesla service pages and schematic snippets identify **X178** and **X184** and their cavities/functions, but the Model Y connector-reference page as fetched did not expose manufacturer/part-number detail for X178/X184. The search result for unrelated **Model X X178** showed a TE/AMP connector, but that is **not safe to apply to Model 3/Y** because X-number reuse across Tesla platforms is not proof of the same physical connector.

**Therefore, the exact Tesla connector family/pitch/keying is unproven from public sources.**

---

## Answers to the research questions

### 1. Exact connector used on Tesla Model 3/Y steering-wheel LIN harness?

**Confirmed:** For Model Y SOP6 / 2023-era documentation, the steering-wheel controls inline connector is **Tesla X178**, called **“Steering Wheel Switch Inline.”** It carries **VBAT, GND, LIN** on cavities **1, 2, and 4**. ([service.tesla.com](https://service.tesla.com/docs/ModelY/ElectricalReference/prog-202/diagram/2023.2_ModelY-SOP6.pdf))

**Not confirmed:** Exact OEM physical connector family, pitch, keying, latch geometry, and commercial housing/terminal MPNs for Model 3/Y X178/X184.

**Model-year note:** Public Tesla electrical-reference index shows Model 3 SOP ranges changed over time, including SOP7 for Fremont 2022-01-17 to 2023-12-31 and SOP8 from 2024-01-01 to 2025-10-03; Model Y has multiple SOP revisions through 2026. That means connector changes are plausible across production revisions and should not be assumed stable without checking the target VIN/SOP. ([service.tesla.com](https://service.tesla.com/docs/Model3/ElectricalReference/index.html?utm_source=openai))

### 2. Is the relevant inline connector 3-pin, 4-pin, 6-pin, or another count?

**Confirmed for the steering-wheel switch inline path:** **4-cavity connector, 3 populated signals.**

| Cavity | Signal | Tesla description |
|---:|---|---|
| 1 | VBAT / switched high-side power | “VBatt (out) — X178-1 High-Side Drive” |
| 2 | Ground | “Ground — X178-2 Ground” |
| 3 | no confirmed steering-wheel LIN signal in public snippet | likely unused / not used for this path |
| 4 | LIN | “LIN — X178-4 LIN” |

Source: Tesla Model Y SOP6 Steering schematic. ([service.tesla.com](https://service.tesla.com/docs/ModelY/ElectricalReference/prog-202/diagram/2023.2_ModelY-SOP6.pdf))

**Do not implement as a 3-pin keyed Tesla-direct connector unless you have a physical harness sample proving the target car actually uses a 3-cavity housing.** The public Tesla schematic evidence points to **4 cavities with cavity 3 unused**, not a true 3-pin housing.

### 3. Exact connector series, pitch, terminal family, latch/keying, PCB-side equivalent?

**Confirmed:** Not available/proven from public sources gathered.

**Inference:** This is likely an automotive wire-to-wire inline connector, not a PCB header series. Tesla service docs describe it as an inline steering-wheel harness connection, and the electrical-reference notes distinguish inline connector gender by terminal type. ([service.tesla.com](https://service.tesla.com/docs/Model3/ElectricalReference/prog-233/interactive/pdf/index_print.pdf))

**Unproven:**  
- pitch  
- OEM housing family  
- terminal family  
- latch/keying  
- board-mount mate  
- exact plug/receptacle MPNs

### 4. Board-mount connector vs adapter pigtail strategy?

**Recommendation: use short adapter pigtails, not direct Tesla-harness board mating, for Rev A.**

Reasoning:

- Tesla public docs confirm the required electrical interface but not the purchasable physical connector details.
- Steering-wheel area is mechanically constrained and safety-adjacent.
- Directly mounting an unverified automotive inline mate on the PCB risks wrong keying, wrong gender, latch interference, or harness strain.
- A pigtail lets Rev A use a known, cheap, assembleable PCB connector while preserving the ability to terminate the vehicle side with harvested/OEM Tesla connectors once physically verified.

**Safest production architecture:**

```text
Tesla car-side harness
   ⇄ short adapter pigtail with verified Tesla mate
   ⇄ board service connector J2

Board service connector J3
   ⇄ short adapter pigtail with verified Tesla mate
   ⇄ steering-wheel module/harness
```

---

## Recommended Rev A implementation

### Electrical mapping

Use **4-circuit board connectors**, not 3-circuit, to preserve Tesla cavity numbering and avoid future respin if cavity 3 is physically present but unused.

#### J2 — car-side input

| Board pin | Tesla X178-equivalent cavity | Signal |
|---:|---:|---|
| 1 | 1 | VBAT_IN |
| 2 | 2 | GND |
| 3 | 3 | NC / reserved |
| 4 | 4 | LIN_A |

#### J3 — wheel-side output

| Board pin | Tesla X184/X178-equivalent cavity | Signal |
|---:|---:|---|
| 1 | 1 or 2 depending final harness gender | VBAT_PROTECTED |
| 2 | 2 or 1 depending final harness gender | GND |
| 3 | 3 | NC / reserved |
| 4 | 4 | LIN_B |

**Important:** keep board silkscreen as **VBAT, GND, NC, LIN** and verify final physical Tesla cavity orientation on an actual harness before crimping pigtails.

### Connector choice for Rev A board

#### Preferred first-article connector family: Molex Micro-Fit 3.0, 4-circuit

Good for hand assembly, field service, keyed/latching, widely stocked, more robust than JST-GH/PH, and commonly acceptable for low-volume builds.

| Item | MPN | Use |
|---|---|---|
| Board vertical header, 4-circuit | **Molex 43650-0415** | J2/J3 PCB header |
| Cable receptacle housing, 4-circuit | **Molex 43025-0400** | Pigtail board-side plug |
| Female crimp terminal | **Molex 43030 series**, choose wire-gauge variant | Pigtail terminals |

**Footprint to add now:**  
Use KiCad Molex Micro-Fit 3.0 vertical 1x04 footprint or draw from datasheet. Reserve keepout for latch access and cable bend.

Recommended board pinout:

```text
Pin 1  VBAT
Pin 2  GND
Pin 3  NC / ID / reserved
Pin 4  LIN
```

Add silkscreen triangle at pin 1 and text:

```text
1 VBAT
2 GND
3 NC
4 LIN
```

### Alternative cheap/serviceable connector

If vertical height matters less than cost and availability, use **JST-VH 3.96 mm, 4-circuit**:

| Item | MPN | Use |
|---|---|---|
| Board header | **JST B4B-VH** or **B4B-VH-FB-B** | PCB |
| Housing | **JST VHR-4N** | Cable plug |
| Terminal | **JST SVH-21T-P1.1** or gauge-appropriate VH terminal | Cable crimp |

This is cheap and easy, but less automotive-like than Micro-Fit and easier to mis-key unless boxed/keyed variants are used.

---

## Implementation decision

### Add to Rev A now

1. Replace each 1x03 2.54 mm header with a **4-circuit keyed/latching service connector footprint**.
2. Recommended: **Molex Micro-Fit 3.0 vertical 1x04** for J2 and J3.
3. Pin 3 should be routed to a test pad or left NC, but physically present.
4. Add nearby 1.27/2.54 mm test pads for:
   - VBAT_IN
   - VBAT_PROTECTED
   - GND
   - LIN_A
   - LIN_B
5. Leave mechanical room for adapter pigtails and strain relief.

### Do not do yet

- Do **not** commit to a Tesla-direct board connector footprint.
- Do **not** assume the Tesla connector is a 3-pin 2.54 mm, JST-XH, JST-GH, or Molex KK style.
- Do **not** remove cavity 3 from the PCB interface; Tesla docs indicate a 4-cavity inline connector with cavity 3 unused for this LIN path.

---

## Confidence

| Claim | Confidence |
|---|---:|
| Steering-wheel LIN/power/ground exists as Tesla-documented interface | High |
| Relevant inline connector is X178 “Steering Wheel Switch Inline” | High |
| X178 uses cavities 1, 2, and 4 for VBAT, GND, LIN | High |
| It is physically a 4-cavity interface rather than true 3-pin | Medium-high |
| Exact OEM connector family/pitch/keying/terminal MPN | Low / not proven |
| Adapter-pigtail strategy is safest for Rev A | High |
| Molex Micro-Fit 3.0 4-circuit is a good board-side service connector | Medium-high |

## Bottom line

Public Tesla sources confirm the **electrical interface** as **4-cavity / 3-signal: pin 1 VBAT, pin 2 GND, pin 4 LIN** on the steering-wheel switch inline path. They do **not** publicly prove the exact Model 3/Y physical connector family or mating purchasable MPNs.

For Rev A, use **4-pin keyed board service connectors** and **adapter pigtails**. The production-safe footprint to add now is **Molex Micro-Fit 3.0 1x04**, with **pin 3 reserved/NC**, so the PCB does not need to know the Tesla OEM connector family until a physical harness is measured and matched.


## Citations

1. https://service.tesla.com/docs/ModelY/ElectricalReference/prog-202/diagram/2023.2_ModelY-SOP6.pdf - https://service.tesla.com/docs/ModelY/ElectricalReference/prog-202/diagram/2023.2_ModelY-SOP6.pdf
2. Steering Wheel (Remove and Install) - https://service.tesla.com/docs/Model3/ServiceManual/en-us/GUID-A8654666-5B69-4082-ADE0-4373AE46C154.html?utm_source=openai
3. Harness - Steering Wheel (Remove and Replace) - https://service.tesla.com/docs/Model3/ServiceManual/en-us/GUID-748469CF-09D5-4ECA-9234-255BFAAC6FFD.html?utm_source=openai
4. Schematics - https://service.tesla.com/docs/Model3/ElectricalReference/prog-233/interactive/html/index.html?expbackground=true&page=0
5. https://service.tesla.com/docs/Model3/ElectricalReference/prog-233/interactive/pdf/index_print.pdf - https://service.tesla.com/docs/Model3/ElectricalReference/prog-233/interactive/pdf/index_print.pdf
6. Electrical Reference - https://service.tesla.com/docs/Model3/ElectricalReference/index.html?utm_source=openai
