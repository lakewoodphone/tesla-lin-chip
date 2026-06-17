# Tesla Anti-Nag DIY Module — Parts Inventory

**Documented:** 2026-05-06  
**Last updated:** 2026-05-10  
**Status:** Parts on hand; capture tooling mostly ready; frame ID still not captured

## Current Hold — 2026-05-10

- Source project docs live in `C:\Users\ezabz\Code\lpt-hub\hardware\tesla-anti-nag`.
- Older passive-sniffer firmware/docs live in `C:\Users\ezabz\Code\Schematics\firmware\anti-nag-v1`.
- Three saved Schematics captures (`2026-05-10_160553`, `_161000`, `_161248`) recorded `0` LIN frames and empty serial/CSV output.
- `sigrok-cli` is installed at `C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe`; the FX2 analyzer now scans as `fx2lafw:conn=1.40` after WinUSB/Zadig.
- The active TJA1020 bench-wiring path is paused because the old generic breadboard pinout conflicts with the board-measured `SH1020F2S` / TJA1020-family map in Schematics.
- Do not ask Moti to bring the Tesla until the passive divider, COM29 sniffer, and backprobe kit are preflighted.

---

## Parts Confirmed On Hand

| #   | Part                                     | Qty      | ID / Marking                                                              | Notes                                                                                                                                                                                             |
| --- | ---------------------------------------- | -------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **CD4066BE**                             | ~20      | "bridge gold" brand, DIP-14                                               | Bus isolation switch — critical component. Confirmed 14-pin DIP. Standard CD4066B pinout applies.                                                                                                 |
| 2   | **TSL5 anti-nag module**                 | 1        | Customer board (Moti Zaks)                                                | Reference unit for reverse engineering. DO NOT damage. Return to customer after SWD dump or LIN capture.                                                                                          |
| 3   | **LM2596 DC-DC buck module**             | 1        | "LM2596S" or "JM503RP", labeled "DCDC"                                    | Step-down voltage regulator module board. Useful for bench 12V → 3.3V supply for testing. Not in the final build BOM — likely ordered for bench power.                                            |
| 4   | **Seeed Studio XIAO ESP32-C3**           | 1        | "XIAO ESP32-C3"                                                           | **V1 prototype MCU.** Has built-in BLE + UART. 3.3V I/O, compatible with TJA1020T. Original V1 design used this chip.                                                                             |
| 5   | **ST-Link V2**                           | 1        | "ST LINK V2 / STMA / STM32 / RST SWIM GND 3.3V 5.0V"                      | STM32/STM8 programmer. ⚠️ **NOT a WCH-LinkE** — cannot program or dump CH571F (WCH RISC-V). Useful only if project pivots to STM32.                                                               |
| 6   | **TJA1020 LIN transceiver (NXP)**        | multiple | "1020/C" / "NXP" / "FUP148" / "ND342" — SOIC-8                            | ✅ **Confirmed TJA1020 from NXP.** Exact match to the transceiver on the TSL5 board. "FUP148" = manufacturing code, "ND342" = lot/date code. This is the LIN bus interface chip for the V1 build. |
| 7   | **CP2102 USB-to-TTL module**             | 1        | "ACP2102" or "CP2102"                                                     | USB ↔ UART serial bridge. Useful for ESP32-C3 firmware flashing and serial debug.                                                                                                                 |
| 8   | **HiLetGo 8-channel USB Logic Analyzer** | 1        | "Logic Analyzer 24MHz 8 channel / ARMFPGAM 100 SCM / CH0–CH7 + GND + VCC" | 24MHz, 8-channel, Cypress FX2LP-based. Works after WinUSB/Zadig; `sigrok-cli --scan` reports `fx2lafw:conn=1.40`. Use only on logic-level RXD/divider tap, not raw 12V LIN.                    |
| 9   | **WCH-LinkE programmer**                 | 1        | WCH-LinkE                                                                 | ✅ **Arrived 2026-05-09.** Required for SWD dump of TSL5's CH571F (WCH RISC-V). Pads/readout flow not yet proven.                                                                                  |

---

## What We Have vs What Was Originally Planned

| Planned                              | Have It?       | Notes                                                                     |
| ------------------------------------ | -------------- | ------------------------------------------------------------------------- |
| CH571F (WCH RISC-V, QFN-28) — V2 MCU | ❌ No          | Not on hand. V1 path (ESP32-C3) is available.                             |
| WCH-LinkE programmer                 | ✅ Yes         | **Arrived 2026-05-09.** Can now attempt SWD dump of TSL5's CH571F.        |
| TJA1020T LIN transceiver (SOIC-8)    | ✅ Yes         | Confirmed NXP TJA1020, SOIC-8, markings: "1020/C / NXP / FUP148 / ND342". |
| CD4066B bus isolation switch         | ✅ Yes         | 20 pcs on hand.                                                           |
| XIAO ESP32-C3 (V1 MCU)               | ✅ Yes         | V1 prototype path is viable.                                              |
| Logic analyzer                       | ✅ Yes (bonus) | HiLetGo 8-ch. Enables LIN bus sniffing/verification.                      |
| CP2102 UART bridge                   | ✅ Yes         | For firmware flashing.                                                    |

---

## Build Path Decision

**Given available hardware, the active path is:**

### Path A — SWD dump of CH571F from Moti's TSL5: HARDWARE ARRIVED, NOT PROVEN

- ✅ WCH-LinkE arrived 2026-05-09
- Next step: identify CH571F SWD/ISP pads and prove the WCH-LinkRV/MounRiver/OpenOCD flow without damaging the customer board

### Path B — CAN brute force on a real Tesla: NOT YET

- Need OBD-II CAN adapter (not on hand)
- Need access to Moti's Tesla (hasn't been arranged)

### Path C — LIN bus sniff: VIABLE, BUT NO FRAMES YET

- We have the 8-channel logic analyzer
- We have the ESP32-C3 which can act as a LIN master stimulus
- `sigrok-cli` is installed at `C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe`
- Analyzer enumerates as `fx2lafw:conn=1.40`
- Schematics passive sniffer branch exists with a 4x10k divider into XIAO `D3/GPIO5`
- Three saved 2026-05-10 dry captures recorded `0` frames; a real signal capture is still pending
- Do not connect raw 12V LIN directly to the USB analyzer or XIAO

### V1 Prototype Build: BLOCKED ON FRAME ID / PAYLOAD

- MCU: XIAO ESP32-C3 (on hand)
- Switch: CD4066BE (on hand)
- Transceiver: candidate TJA1020/TJA1020-family parts on hand; exact bench wiring pinout must be re-verified
- Firmware: Can write and flash once Frame ID is confirmed

---

## Immediate Next Steps

1. **Re-verify passive divider rig** — four 10k resistors in series, XIAO `D3/GPIO5` at the R3/R4 tap, shared ground, no direct 12V to logic input.
2. **Run local preflight** — confirm `COM29`, sniffer firmware if using Schematics branch, and `sigrok-cli --scan` showing `fx2lafw:conn=1.40`.
3. **Only then arrange passive vehicle capture** — backprobe only, no disconnecting connectors, capture idle plus deliberate scroll events.
4. **Keep TJA1020 active bench wiring paused** — reconcile generic breadboard pinout against the board-measured `SH1020F2S` / TJA1020-family map first.
5. **SWD remains optional** — WCH-LinkE is here, but pad ID and readout are not proven.

---

## Key Technical Constants (from research)

- **Baud rate:** 19200 (NOT 9600 — this was the original bug)
- **Checksum:** LIN 2.1 Enhanced (includes PID in sum)
- **Frame ID:** Unknown — to be extracted via LIN sniff (Path C) or CAN brute force (Path B)
- **Payload (inferred):** Idle=`00 00 00 00 00 00 00 00`, Up=`00 00 01 00 00 00 00 00`, Down=`00 00 FF 00 00 00 00 00`
- **Injection timing:** Switch CD4066B open during ~200µs inter-frame space, inject, close before next 10ms poll
- **CAN verification:** Monitor CAN ID 0x3C2 (`VCLEFT_switchStatus`), bits 16–21 = `swcLeftScrollTicks`
- **Platform scope:** Pre-Highland Model 3/Y (2021–2023) — different frame structure on Highland/Juniper/Yoke
