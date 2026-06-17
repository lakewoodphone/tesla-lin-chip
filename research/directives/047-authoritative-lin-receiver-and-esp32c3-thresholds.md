# Research Directive: Authoritative LIN Receiver Design for ESP32-C3 Capture (Datasheet-Grade Sources Only)

**Directive ID**: 047-authoritative-lin-receiver-and-esp32c3-thresholds  
**Date Issued**: 2026-05-17  
**Requestor**: ezabz  
**Priority**: Critical  
**Category**: automotive-re / embedded-hardware / authoritative-sources

---

## Objective

Produce a hardware design recommendation for Tesla LIN passive capture into ESP32-C3 RX using only authoritative sources (chip vendor docs, standards, official board docs, major semiconductor app notes).

## Constraints

1. Source quality requirement:
   - Prefer Espressif docs, Seeed official docs, NXP/TI/Infineon/ST/Littelfuse datasheets/app notes, ISO/LIN consortium references.
   - Avoid random blogs, low-quality scraped pages, generic forum speculation unless used only as supplemental context.
2. Must identify relevant electrical thresholds and margins clearly.
3. Must provide a practical field-safe recommendation and a production-ready recommendation.

## Questions

1. What are the actual ESP32-C3 input threshold constraints relevant to decoding a LIN-derived UART signal at 3.3V IO?
2. What is the accepted LIN physical signaling and receiver threshold behavior that explains why divider-only taps can fail decode?
3. Which LIN transceiver families are most suitable for passive receive into 3.3V MCU logic (RXD output compatibility, protection, EMC)?
4. What front-end protection parts should be used on a vehicle LIN tap (TVS, series resistance, reverse battery protection)?
5. Define measurable acceptance criteria for decode quality before moving beyond passive capture.

## Required Output

Return:

1. A concise hardware recommendation table with at least two validated implementation options.
2. A reference wiring block diagram suitable for immediate field build.
3. A pass/fail validation checklist with numeric thresholds.
4. A strict "do not do" list for customer-vehicle safety.

## Output Path

Save response under docs/research/responses with normal dispatcher naming.
