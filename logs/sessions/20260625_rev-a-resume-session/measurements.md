# Rev A Model 3 Active Session — Resume 2026-06-25

**Previous session:** `sessions/20260617_154311-rev-a-active-tesla-model-3-live-prep-20260617/`
**Previous result:** Bench Verification Gate PASSED. Board left safe: armed=no, nag=no, bridge=yes, pending=0.

**This session resume point:** Gate 1 — Unpowered Board Measurements (last 3 checks)
**Current board state:** v5.5-rev-a-ble on COM6, CP2102 disconnected, no VBAT

---

## Gate 1 — Unpowered Board Measurements

**Tool:** Multimeter (continuity/resistance mode)
**Power:** OFF — CP2102 USB disconnected, no VBAT

### Already verified (2026-06-17 first article):
| # | Check | Result |
|---|-------|--------|
| A | TP1 (GND) → TP2 (3V3) | 79kΩ rising ✅ |
| B | TP1 (GND) → F1 left (VBAT_IN) | 1.2MΩ rising ✅ |
| C | TP1 (GND) → F1 right (VBAT_PROTECTED) | 1.2MΩ rising ✅ |
| D | F1 left → F1 right (fuse) | Beep ✅ |
| E | TP10 (LIN_A) → TP1 (GND) | OL ✅ |
| F | TP11 (LIN_B) → TP1 (GND) | OL ✅ |
| G | TP10 (LIN_A) → TP11 (LIN_B) | OL ✅ |

### Need to do now:
| # | Check | Probe A | Probe B | Expected | Result | Notes |
|---|-------|---------|---------|----------|--------|-------|
| H | UART TX/RX not shorted | **TP6 (UART0_TX)** | **TP7 (UART0_RX)** | Open/high resistance | OL | ✅ |
| I | EN not stuck low | **TP8 (EN)** | **TP1 (GND)** | Not hard short | ~134kΩ rising | ✅ |
| J | BOOT not stuck low | **TP9 (BOOT)** | **TP1 (GND)** | Not hard short | ~130kΩ | ✅ |

---

## Gate 2 — Bench Power Measurements

**Prerequisite:** Gate 1 all pass
**Tool:** Multimeter (DC voltage), current-limited bench supply, CP2102 adapter

| # | Check | Expected | Result | Notes |
|---|-------|----------|--------|-------|
| 2.1 | Connect CP2102 (3V3→TP2, GND→TP1, RXD→TP6, TXD→TP7) | — | Done | ✅ |
| 2.2 | Measure TP2 (3V3) → TP1 (GND) | ~3.3V | 3.317V | ✅ |
| 2.3 | If VBAT connected: F1 right → TP1 | ~12V | | |
| 2.4 | Current draw idle | Stable, low mA | | |
| 2.5 | Serial `version` on COM6 | `fw=v5.5-rev-a-ble` | `fw=v5.5-rev-a-ble build=rev_a_active_ble reset=poweron` | ✅ |
| 2.6 | Serial `config` — safe state | `armed=no nag=no` | `armed=no bridge=yes nag=no pending=0` | ✅ |
| 2.7 | Serial `nag:status` | `nag=disabled` | `nag=disabled interval=15000ms` | ✅ |
| 2.8 | Serial `cache` | 6 frames seeded | `0x28,0x29,0x2A,0x2B,0x2C,0x2D` all valid | ✅ |
| 2.9 | BLE scan | `TeslaPassthrough` found | Serial: "BLE: init done" + "BLE: advertising" confirmed on boot. External scanner can't see NimBLE extended advertising — same known limitation from June 17 | ✅ (serial confirmed) |
| 2.10 | Physical arm: GPIO9 HIGH → `safe:arm` | `armed=yes` | | |
| 2.11 | Physical arm: GPIO9 LOW → `safe:arm` | `blocked physical_arm=off` | | |
| 2.12 | Leave safe: `safe:off`, `nag:off`, `inject:clear` | Safe state | | |

---

## Gate 3 — Car Harness Pre-Connection

**Prerequisite:** Gate 1 + 2 pass
**Location:** At the vehicle

| # | Check | Expected | Result | Notes |
|---|-------|----------|--------|-------|
| 3.1 | Vehicle 12V → vehicle ground | ~12-14V | | |
| 3.2 | Vehicle ground → TP1 continuity | Continuity | | |
| 3.3 | Car-side LIN idle voltage | LIN idle range | | |
| 3.4 | Wheel-side LIN idle voltage | LIN idle range | | |
| 3.5 | Photo: car/wheel connector orientation | Saved | | |
| 3.6 | Native wheel controls | Working normally | | |

---

## Gate 4 — Connected Passive / Safe-Off Observation

**Prerequisite:** Gates 1-3 pass. Board connected. `safe:off`, `bridge:off`.

| # | Command | Expected | Result | Notes |
|---|---------|----------|--------|-------|
| 4.1 | `safe:off` | `armed=no` | | |
| 4.2 | `bridge:off` | `bridge=off` | | |
| 4.3 | `config` / `stats` | No unexpected changes | | |
| 4.4 | Vehicle behavior | Normal, no warnings | | |
| 4.5 | Stop if vehicle reacts | — | | |

---

## Gate 5 — Bridge Observation

**Prerequisite:** Gate 4 quiet.

| # | Command | Expected | Result | Notes |
|---|---------|----------|--------|-------|
| 5.1 | `bridge:on` | `bridge=on` | | |
| 5.2 | `cache` | 0x28-0x2D present | | |
| 5.3 | `config` / `stats` | Normal | | |
| 5.4 | Native controls | Still working | | |

---

## Gate 6 — Manual Injection

**Prerequisite:** Gate 5 acceptable.

| # | Command | Expected | Result | Notes |
|---|---------|----------|--------|-------|
| 6.1 | `safe:arm` | `armed=yes` | | |
| 6.2 | `vol:up:1` | pending=1 | | |
| 6.3 | `stats` / vehicle | Volume up | | |
| 6.4 | `vol:down:1` | pending=1 | | |
| 6.5 | `stats` / vehicle | Volume down | | |
| 6.6 | `vol:click:1` | pending=1 | | |
| 6.7 | `stats` / vehicle | Click | | |
| 6.8 | `inject:clear` | Cleared | | |

**Immediate stop if:** volume runaway, warning lights, controls stop, serial lost, heat.

---

## Gate 7 — Anti-Nag

**Prerequisite:** Gate 6 one-frame tests pass.

| # | Command | Expected | Result | Notes |
|---|---------|----------|--------|-------|
| 7.1 | `nag:once` | Up then down | | |
| 7.2 | `stats` / vehicle | Net zero volume change | | |
| 7.3 | `nag:interval:15000` | 15s interval | | |
| 7.4 | `nag:on` | Repeating | | |
| 7.5 | Monitor | Net zero volume | | |
| 7.6 | `nag:off` | Stopped | | |

---

## Final Session Closeout

| # | Command | Done |
|---|---------|------|
| ☐ | `nag:off` | |
| ☐ | `inject:clear` | |
| ☐ | `bridge:off` | |
| ☐ | `safe:off` | |
| ☐ | Final `config` captured | |
