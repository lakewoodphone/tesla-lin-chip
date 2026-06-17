# LIN Bench Full Setup - 2026-05-26 20:55

## Summary

Complete end-to-end LIN bench buildout on the desktop node (ZABZ-TECH). The project evolved from the original TSL5 board + lpt-schematics firmware to a fully working LIN bench with APGDT001 analyzer and TJA1021 transceiver.

## What Was Done

### Phase 1: Firmware v4 Upgrade
- Upgraded `src/main.cpp` from v3 to v4:
  - Runtime vehicle ID (`vehicle:tesla-model-3`)
  - Runtime baud switch (`baud:19200`)
  - 128-frame ring buffer with `ring` dump command
  - Raw byte toggle (`raw:1`/`raw:0`)
  - Serial command handler (`vehicle:`, `baud:`, `raw:`, `ring`, `stats`)
  - Telemetry queue expanded from 16→64 frames
  - Auto-baud candidates (19200/9600/10400)

### Phase 2: Tools & Dashboard
- **`tools/car-day-launcher.ps1`** — Unified car-day entry point
- **`tools/antinag-replay.ps1`** — Bench-only anti-nag scroll sequence generator
- **`tools/lin-payload-calc.py`** — CLI payload calculator (antinag/idle/verify/checksum/scan)
- **`tools/analyze-lin-capture.py`** — Post-capture analyzer with Tesla ID reference tables
- **`TOOLS.md`** — Complete tool reference with traffic-light safety indicators
- **Captaincy API endpoints:**
  - `POST /api/v1/lin-events` (existing)
  - `GET /api/v1/lin-events` (existing)
  - `GET /api/v1/lin-stats` (NEW — aggregated per-ID stats)
- **Next.js dashboard:** `/lin` page with live stats, ID summary cards, recent events table
- **Nav link:** Intelligence → LIN Bus (🔌) added to sidebar
- **Dashboard proxy:** `/api/v1/*` added to public path bypass in `proxy.ts`
- **Next config:** `/api/v1/*` rewrite to backend

### Phase 3: Hardware Validation
- Connected XIAO ESP32-C3 on COM4
- Connected APGDT001 (VID_04D8&PID_0A04)
- Fixed VIN wire on TJA1021 module (was loose, needed 12V)
- **Bench validation: ALL 5 TESTS PASSED**
  - `ID=0x0C [2B] enhanced parity=OK` ✓
  - `ID=0x10 [2B] enhanced parity=OK` ✓
  - `ID=0x22 [4B] enhanced parity=OK` ✓
  - `ID=0x3C [8B] enhanced parity=OK` ✓
  - `ID=0x3C [8B] classic parity=OK` ✓
- **Anti-nag replay:** 4 alternating UP/DOWN frames sent successfully via APG
- Secretion dashboard proxy fixed (was blocking `/api/v1/*` behind auth)

### Phase 4: Git & Publish
- **personal-secretary-mvp:** Pushed commit `2fb7da9` to GitHub (`d394458..2fb7da9`)
- **xiao-lin-bench:** New repo created at `https://github.com/lakewoodphone/xiao-lin-bench`
  - 24 files, 3321 lines, initial commit `71bcd76`
  - Description: "Tesla LIN bus bench for Model 3/Y/X passive LIN capture"
- **Snapshot:** `C:\Users\ezabz\Code\_snapshots\xiao-lin-bench-20260526_205500.zip`

## Current State

### Running Services (on ZABZ-TECH desktop)

| Service | Port | Status |
|---|---|---|
| Secretary API (uvicorn) | 8002 | ✅ Live with all LIN endpoints |
| Next.js Dashboard | 3000 | ✅ `/lin` route live |
| XIAO ESP32-C3 (firmware v4) | COM4 | ✅ Listening at 19200 baud |
| APGDT001 | USB | ✅ Ready to send/receive |

### Tesla Known IDs

| ID | Model | Label | Priority |
|---|---|---|---|
| `0x0C` | X | Scroll/control (B0=position, B1=engage) | HIGH |
| `0x0D` | X | Passive mirror | LOW |
| `0x0E`/`0x0F` | X | Alive toggle | LOW |
| `0x16`/`0x17` | X | Config/version | INFO |
| `0x1A`/`0x1B` | 3/Y | CANDIDATE steering (unconfirmed) | INVESTIGATE |
| `0x3C`/`0x3D` | All | Diagnostic | INFO |

### Seed Data in API
- 36 frames across 3 vehicles (tesla-model-x-moti, tesla-model-3-unknown, bench-test)
- 3 unique IDs (0x0C, 0x0D, 0x1A)
- Bad checksum/parity frames present (shows alerting works)

## Known Issues

1. `send-apg-lin-frame.ps1` reports baud=10000 at 19200 — use NetworkAnalyser tools
2. PICkitS.dll is x86 only — all APG tools need 32-bit PowerShell
3. WiFi config in `secrets.h` points to `xiao-lin-bench` network — may need hotspot for field
4. Anti-nag replay's neutral sentinel frame errors with "Error sending script" — cosmetic, 4 data frames go through
5. `secrets.h` is gitignored — needs config for each deployment

## Next Actions (unprioritized)
1. Push to vehicle — connect APG + XIAO to real Tesla Model 3/Y/X LIN bus
2. Discover Model 3/Y steering IDs using the control test matrix in NEXT_STEPS.md
3. Run `python tools/analyze-lin-capture.py --latest` after each capture
4. Commit `xiao-lin-bench\src\secrets.h` with real WiFi config for field deployment
5. Consider adding `tools/lpt-portable-check.ps1` for quick connectivity testing