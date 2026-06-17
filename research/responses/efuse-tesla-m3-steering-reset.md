# Tesla Model 3 eFuse Reset Time After Short Circuit — Steering Wheel Controls

## Context
A Tesla Model 3 steering wheel controls circuit was shorted briefly (two bare wires touched). The steering wheel buttons and scroll wheels immediately stopped responding. No physical fuses exist on Model 3 — Tesla uses electronic eFuses (software-controlled current sensors).

## Research Questions
1. How long does a Tesla Model 3 eFuse typically take to auto-reset after the fault condition (short) is removed — specifically for low-voltage control circuits like steering wheel/SCCM?
2. Is the steering column control module (SCCM) / steering wheel LIN bus power circuit known to be a self-resetting eFuse, or a latching one that requires a Tesla service appointment or OTA update?
3. Owner-reported cases: steering wheel controls went dead after a short or accidental wiring contact — did they come back on their own, and how long did it take?
4. Is a hard MCU reboot (hold brake + both scroll wheels for 10 seconds) sufficient to clear a tripped SCCM eFuse, or does it require more?
5. What specific eFuse or software circuit label governs the steering wheel controls / SCCM on Model 3? Any Tesla service manual references or teardown data?

## Research Teams
- Compass (Claude)
- Gemini
