# ⚠️ SUPERSEDED — Tesla Model X LIN / XIAO Context - 2026-05-18

> **This file was the START-HERE briefing as of 2026-05-18. It is now superseded.**
> The bench was fully built and validated the night of 2026-05-25/26.
>
> **Current START HERE:** `C:\Users\ezabz\Code\xiao-lin-bench\README.md`
> **Next steps:** `C:\Users\ezabz\Code\xiao-lin-bench\NEXT_STEPS.md`
>
> Bench status as of 2026-05-26:
> - ✅ XIAO ESP32-C3 on COM4, firmware flashed, LIN parser running
> - ✅ APGDT001 USB-LIN analyzer headlessly controlled via `tools/send-netanalyser-headless.ps1`
> - ✅ TJA1021 transceiver + level shifter wired correctly (SLP tied to 5V)
> - ✅ First clean frame decoded: `#1 ID=0x3C data: 00 00 00 00 00 00 00 00 | chk=C3 OK`
> - ✅ Key bug fixed: `Change_LIN_BAUD_Rate` must be called after `Network_Load` (which resets to 9600)
>
> Keep reading this file only for historical context (field measurements, pre-bench state).

---

# HISTORICAL CONTEXT (2026-05-18) — kept for reference only

This file was written for an AI assistant working on the desktop machine. It is intentionally self-contained.

## Prior State as of 2026-05-18

The owner was trying to continue the Tesla Model X steering-wheel LIN / anti-nag research without the customer car. The desktop AI was struggling because the context was spread across docs, research artifacts, shell output, and a long chat.

State at that time: the customer 2025 Tesla Model X had been returned. Bench parts ordered but not yet arrived. Continue with documentation, parts, bench planning, capture analysis, and safe receive-path work only. Do not plan active injection on a customer vehicle from the current evidence.

## Absolute Hard Stops

- Do not inject, write, lock, spoof, or actively drive the LIN bus on a customer or owner Model X from the current evidence.
- Do not use `-ForceLock` on S/X customer cars.
- Do not probe `DAB`, yellow, SRS, or airbag connectors. `DAB` means Driver Air Bag.
- Do not connect raw 12-15 V LIN directly to XIAO ESP32-C3 GPIO or FX2 inputs.
- Do not connect XIAO `D2` or `D4` for active paths until receive is reliable and bench validation passes.
- Do not reuse the bare SOIC-8 TJA1020 that overheated. Treat that chip/build as unsafe.
- Do not assume Model 3/Y SCCM pinout applies to refreshed Model X.
- Do not do destructive git operations on the desktop. The desktop repos may be dirty and were updated by direct file copy because GitHub HTTPS auth failed under noninteractive SSH.

## Machines And Repo Paths

Laptop/current VS Code machine:

- `C:\Users\ezabz\code\personal-secretary-mvp`
- `C:\Users\ezabz\Code\lpt-schematics`

Desktop machine:

- Hostname: `zabz-tech`
- LAN SSH host: `192.168.50.138`
- `personal-secretary-mvp`: `C:\Users\ezabz\Code\personal-secretary-mvp`
- `lpt-schematics` clone is actually: `C:\Users\ezabz\Code\Schematics`
- Do not look for desktop `C:\Users\ezabz\Code\lpt-schematics`; it was missing during verification.

Desktop SSH helper from laptop:

```powershell
C:\Users\ezabz\code\personal-secretary-mvp\scripts\windows\Connect-DesktopSsh.ps1 -ForceLan -Command "hostname"
```

Important desktop git caveat: `git fetch` on the desktop failed under SSH with:

```text
fatal: could not read Username for 'https://github.com': No such file or directory
```

Because of that, docs were copied over SSH directly. On the desktop, some of these files may show as modified or untracked even though the laptop commits were pushed.

## Recent Commits Already Pushed From Laptop

`personal-secretary-mvp`:

- Branch: `master`
- Remote: `https://github.com/lakewoodphone/personal-secretary-mvp.git`
- Commit: `ce10f41`
- Message: `docs: save Tesla Model X LIN research`
- Scope: 20 Tesla/XIAO/LIN research and report files under `docs/reports/` and `docs/research/`.

`lpt-schematics`:

- Branch: `main`
- Remote: `https://github.com/lakewoodphone/lpt-schematics`
- Commit: `8db2773`
- Message: `docs: organize Model X LIN handoff`
- Scope: 7 anti-nag docs under `firmware/anti-nag-v1/`.

## Files The Desktop Should Have

On desktop `C:\Users\ezabz\Code\Schematics`:

- `firmware\anti-nag-v1\docs\model-x-xiao-lin-handoff-2026-05-18.md`
- `firmware\anti-nag-v1\docs\model-x-moti-visit-2026-05-17.md`
- `firmware\anti-nag-v1\docs\tesla-capture-guide.md`
- `firmware\anti-nag-v1\docs\field-checklist.md`
- `firmware\anti-nag-v1\docs\operator-card.md`
- `firmware\anti-nag-v1\README.md`

On desktop `C:\Users\ezabz\Code\personal-secretary-mvp`:

- `docs\reports\tesla-modelx-xiao-lin-field-analysis-2026-05-17.md`
- `docs\research\responses\2026-05-17-tesla-modelx-xiao-master-synthesis.md`
- `docs\research\responses\2026-05-18-urgent-tesla-lin-bench-mock-and-parts-research-ndate-2026-05-18-n-nwe-are-return-6242f52c.md`
- `docs\research\responses\2026-05-18-urgent-tesla-lin-bench-mock-and-parts-research-ndate-2026-05-18-n-nwe-are-return-6242f52c.json`
- Research directives 044, 045, 046, 047 under `docs\research\directives\`.

This file should also be copied to:

- `C:\Users\ezabz\Desktop\TESLA_MODEL_X_LIN_START_HERE_FOR_AI_2026-05-18.md`
- `C:\Users\ezabz\Code\Schematics\firmware\anti-nag-v1\docs\desktop-ai-context-2026-05-18.md`
- `C:\Users\ezabz\Code\personal-secretary-mvp\docs\reports\tesla-modelx-lin-desktop-ai-context-2026-05-18.md`

## Vehicle And Visit Facts

- Customer: Moti Zaks / Muteezax.
- Vehicle: 2025 Tesla Model X refresh, dark silver, AWD.
- Partial VIN / serial detail: `SF468907`.
- Plate: `H65 VSL`.
- Goal of visit: passive LIN discovery for steering-wheel / anti-nag research.
- Visit mode: capture-only. No BLE lock/write, no injection, no `-ForceLock`.
- Field access: steering wheel center airbag/horn pad was released using two stick-like tools through the rear wheel release holes.
- Useful connector found: labeled `SW`.
- Connector to avoid: labeled `DAB`; this is Driver Air Bag / SRS.

## SW Connector Wiring From Field Measurements

The `SW` connector had green, white, and black populated wires.

| Wire | Field measurement | Interpretation |
|---|---:|---|
| Black | about 1.8 mV to chassis | Ground / near-ground reference |
| Green | about 15.43 V | Vehicle low-voltage power; do not use for logic capture |
| White | about 11.57 V initially | LIN candidate before connector fully seated |
| White | about 8.15 V after SW connector was seated | Active/loaded LIN bus average |

Critical correction: early captures were taken while the SW connector was not fully seated, so the car was not reading steering-wheel presses. Those early captures still proved bus traffic on the white wire, but they did not show real wheel input changes.

## Confirmed Capture Wiring

Successful passive capture path:

```text
SW connector white wire
    -> backprobe / test lead
    -> breadboard row 1
    -> 4x10k divider
    -> breadboard row 4
    -> FX2 D0

Vehicle chassis ground
    -> breadboard GND rail
    -> FX2 GND
```

Do not connect the SW white wire directly to FX2 or XIAO. It must go through the divider or, preferably for XIAO receive, through a real LIN transceiver.

## Capture Artifacts

Useful capture folders in the `lpt-schematics` anti-nag project:

| Purpose | Path | Notes |
|---|---|---|
| First manual, SW not seated | `firmware/anti-nag-v1/captures/moti-modelx-manual-20260517-133400/white-sw-d0-90s.sr` | Decoded LIN, but steering controls were not being read |
| Seated / controls active | `firmware/anti-nag-v1/captures/moti-modelx-seated-20260517-134748/white-sw-seated-60s.sr` | Primary discovery capture |
| Hands-off baseline | `firmware/anti-nag-v1/captures/moti-modelx-baseline-20260517-135436/white-sw-baseline-30s.sr` | Baseline comparison |
| Single-control | `firmware/anti-nag-v1/captures/moti-modelx-single-control-20260517-135746/white-sw-single-control-30s.sr` | Best one-action comparison capture |

Ignore or treat as failed/debug:

- `firmware/anti-nag-v1/captures/moti-modelx-targeted-20260517-133732/`
- `firmware/anti-nag-v1/captures/moti-modelx-targeted-20260517-133739/`
- `moti-modelx-targeted-verified-*` folders from transient command experiments.

FX2 connection IDs change. Always run `sigrok-cli --scan` immediately before capture.

## Protocol Facts

- LIN baud confirmed: `19200`.
- Observed IDs on SW white bus: `0x0C`, `0x0D`, `0x0E`, `0x0F`, `0x16`, `0x17`.
- Main control-sensitive candidate: ID `0x0C`.
- PID for ID `0x0C`: `0x4C`.
- Frame layout: Break -> sync `0x55` -> PID -> 8 data bytes -> checksum.
- Checksum type: LIN 2.x enhanced checksum, includes PID and data.
- `0x0C` is strong enough for bench analysis planning, not strong enough for in-vehicle active manipulation.

Useful decode command pattern:

```powershell
& 'C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe' `
  -i white-sw-seated-60s.sr `
  -P "uart:rx=D0:baudrate=19200:format=hex,lin:version=2" `
  --protocol-decoder-samplenum > lin_decoded_exact_19200.txt
```

sigrok may emit only `lin-1: Break condition` plus raw `uart-1: XX` bytes. Analysis scripts must reconstruct frames from break -> `0x55` sync -> PID -> data/checksum. Do not rely only on friendly LIN PID/data annotations.

## Decoded ID 0x0C Semantics

The user explicitly said they scrolled up and down for volume change during capture. That ties the changing payloads to left steering-wheel scroll behavior.

Frame has 8 data bytes plus checksum:

| Byte | Name | Idle | Active / observed range | Meaning |
|---|---|---:|---|---|
| B0 | Control / scroll delta | `0x10` | `0x0A` to `0x15` | Direction/position around neutral |
| B1 | Button/control bits | `0x00` | `0x04`, `0x08`, `0x0C`, `0x10`, `0x1C` | Bit-packed control state; `0x04` likely touch/engage |
| B2 | Rate | `0x00` | `0x08` to `0x48` | Instantaneous scroll velocity |
| B3 | Accumulated count | `0x00` | `0x10` to `0xB0` | Accumulated scroll count, often about 2x B2 |
| B4 | Reserved | `0x00` | `0x00` | Always zero in observed data |
| B5 | Reserved | `0x00` | `0x00` | Always zero in observed data |
| B6 | Status | `0xC0` | `0xC0` | Invariant alive/status |
| B7 | Counter | `XF` | `0x0F` to `0xFF` with low nibble F | Rolling 4-bit counter in upper nibble |
| B8 | Checksum | variable | variable | LIN enhanced checksum |

Confirmed B0 interpretation:

| B0 value | Meaning |
|---|---|
| `0x10` | Neutral, wheel at rest |
| Greater than `0x10`, such as `0x11` to `0x15` | Scroll up / volume increase |
| Less than `0x10`, such as `0x0F` to `0x0A` | Scroll down / volume decrease |

Example new `0x0C` payloads from single-control vs baseline:

```text
10 04 00 00 00 00 C0 CF
10 04 00 00 00 00 C0 DF
11 00 00 00 00 00 C0 FF
10 00 00 10 00 00 C0 FF
10 04 00 00 00 00 C0 FF
```

Interpretation examples:

- `10 04 00 00 ...` means B1 bit 2 set: scroll touch/engage.
- `11 00 00 00 ...` means B0 one step above neutral: scroll up.
- `10 00 00 10 ...` means accumulated count tick in B3.

## Enhanced Checksum Formula

For ID `0x0C`, PID is `0x4C`. The checksum includes PID and all 8 data bytes.

```python
def lin_enhanced_checksum(pid: int, data: list[int]) -> int:
    checksum_sum = pid
    for value in data:
        checksum_sum += value
        if checksum_sum > 0xFF:
            checksum_sum -= 0xFF
    return 0xFF - checksum_sum
```

This was verified 15/15 against real payloads from baseline, single-control, and seated captures.

## Other IDs

- `0x0D`: same approximate frame rate as `0x0C`, but only 17 unique payloads across full seated session. Mostly rolling counter / passive mirror-like behavior. It did not gain single-control payloads vs baseline in the final comparison.
- `0x0E` and `0x0F`: alternate between two values, likely heartbeat/alive toggles. `0x0F` had one minor new payload but far lower confidence than `0x0C`.
- `0x16` and `0x17`: static across captures, likely configuration/version/status frames.

## XIAO ESP32-C3 State

The XIAO firmware, flashing, and USB logging pipeline are recovered. The remaining blocker is physical-layer conditioning into ESP32-C3 RX.

Observed diagnostic pattern:

- USB CDC heartbeat stable.
- `rx`, `breaks`, `syncerr`, and `skips` increase.
- `frames` remains `0`.
- Divider row 4 measured about `2.575 V`.

Interpretation: XIAO is seeing electrical activity, but the divided waveform is too marginal/noisy for reliable UART LIN decode. Treat this as a physical-layer problem, not a PlatformIO or USB problem, unless diagnostics change.

Known intended XIAO pins in the current firmware work:

- `D3/GPIO5`: LIN RX.
- `D2/GPIO4`: LIN TX.
- `D4/GPIO6`: CD4066B / active path control.

For passive receive next step, only `D3/GPIO5` and GND should matter, fed from LIN transceiver RXD.

Known-good PlatformIO settings:

```ini
platform = espressif32@6.9.0
board = seeed_xiao_esp32c3
framework = arduino
upload_protocol = esptool
upload_speed = 115200
monitor_speed = 115200
monitor_dtr = 0
monitor_rts = 0
build_flags =
  -DARDUINO_USB_MODE=1
  -DARDUINO_USB_CDC_ON_BOOT=1
  -DCORE_DEBUG_LEVEL=3
  -DCONFIG_UART_ISR_IN_IRAM=1
```

Direct esptool `--no-stub` at 115200 is the recovery path when PlatformIO upload is unstable.

## Hardware Decision

Current ordered equipment inventory and bench organization is saved in `docs/reports/tesla-lin-bench-equipment-inventory-2026-05-19.md`.

Abandoned path:

- Bare/tiny SOIC-8 TJA1020 breadboard attempt overheated badly. Do not continue that exact hardware path.
- Do not hand-wire or revive a loose tiny TJA chip by guessed pinout. That failure mode is exactly what the new bench plan is avoiding.

Recommended path:

- Use APGDT001 as the PC-side USB-LIN master/analyzer.
- Use a ready-made TJA1021-class or MC33662-class TTL UART to LIN transceiver breakout module only as the XIAO-side physical-layer interface, after measuring its pin labels and logic voltages.
- Recommended Amazon candidate from research/shopping: ASIN `B0F31584W1`, TJA1021-based TTL UART <-> LIN module.
- TJA1021/MC33662 class is appropriate for LIN 2.x / ISO 17987 12 V systems, 3.3 V logic, and up to 20 kBd. Tesla bus is 19.2 kBd.
- Avoid CAN transceiver modules. CAN is a different physical layer.
- Avoid USB-TTL-only adapters. They do not provide LIN physical-layer level shifting.
- Avoid RS485 modules. RS485 is differential and not LIN.

## Correct Receive Topology

For vehicle passive receive or bench passive receive:

```text
Vehicle or bench LIN wire
    -> LIN transceiver LIN pin

LIN transceiver RXD
    -> XIAO D3/GPIO5

Common ground
    -> XIAO GND and transceiver GND

Vehicle/bench LV rail
    -> transceiver VBAT only, fused/protected
```

Do not connect raw LIN to XIAO. Do not connect XIAO `D2` or `D4` during passive receive stabilization.

## Bench Mock Goal

Goal: continue work without the Tesla by reproducing the steering-wheel LIN cluster off-vehicle.

Core bench topology:

```text
12-15 V bench supply with current limit/fuse
    -> Tesla steering-wheel module green LV power
    -> LIN transceiver VBAT

Bench supply ground
    -> Tesla module black ground
    -> LIN transceiver ground
    -> XIAO ground

XIAO UART TX/RX
    -> LIN transceiver TXD/RXD

LIN transceiver LIN
    -> Tesla module white LIN
```

Bench master requirements:

- 19200 bps.
- LIN break at least 13 dominant bit times.
- Sync byte `0x55`.
- PID `0x4C` for ID `0x0C`.
- 8 data bytes plus enhanced checksum.
- Correct LIN master pull-up / termination: typically 1k plus diode from VBAT to LIN. Verify whether the module includes this; add it if not.

## Parts To Order Or Stage

Minimum:

- TJA1021 or MC33662 TTL-to-LIN module/breakout with separate VBAT, GND, LIN, TXD, RXD.
- Adjustable 0-20 V bench supply with current limiting, or known-good 12-15 V supply.
- Inline automotive fuse holder and 2-5 A blade fuses for Tesla module LV power.
- Small screw-terminal board or proto board for repeatable wiring.
- Jumper wires, labels, and non-destructive harness pigtails.
- DMM.

Strongly useful:

- Logic analyzer or oscilloscope with LIN decode. FX2/sigrok is acceptable if carefully decoded.
- Extra TJA1021/MC33662 modules so one failed board does not stop work.
- TVS / basic automotive transient protection components for the bench harness.
- Mating connector or sacrificial harness pigtail for the Tesla steering-wheel module if available.

Do not buy as substitutes:

- CAN transceiver module.
- RS485 module.
- Bare USB-TTL adapter.
- Random 12 V relay / optocoupler board marketed for automotive signals without LIN support.

## What Was Still Worth Capturing If The Vehicle Was Present

If the car is somehow still available, these are useful but not required enough to hold the vehicle indefinitely:

- Clear photos of SW connector orientation, pin numbering, wire colors, part labels, and module labels/barcodes.
- Green-to-black voltage in off, accessory/wake, and active/ready states.
- White LIN idle/min/max voltage to black ground, ideally scoped.
- Approximate module current draw if safe.
- No-touch baseline capture.
- Single-control captures for left scroll up/down, right controls, voice, turn signal/stalks, and other steering controls.
- Power-up/wake capture from cold/off to active.
- Restore SW connector fully seated and confirm no airbag/steering warnings.

The working decision already given: the Tesla did not need to be held once photos/restoration/no-warning checks were done.

## Tooling And Script State

Important local `lpt-schematics` scripts were improved during the session but may not have been committed in the doc-only push. Check their presence before depending on desktop copies:

- `firmware/anti-nag-v1/scripts/analyze-lin-capture.ps1`
- `firmware/anti-nag-v1/scripts/compare-lin-captures.ps1`
- `firmware/anti-nag-v1/scripts/flash-xiao-field.ps1`
- `firmware/anti-nag-v1/scripts/read-xiao-diagnostic.ps1`
- `firmware/anti-nag-v1/scripts/lin-payload-calc.py`

At the time of handoff, these were untracked or modified locally in the laptop `lpt-schematics` working tree and were deliberately not included in the two doc-only commits. If the desktop AI needs these tools and they are missing on desktop, copy them from the laptop repo or ask the owner before committing/staging broader work.

Useful script behavior:

- `analyze-lin-capture.ps1` reconstructs frames from raw sigrok break + UART byte annotations and reports per-capture varying IDs.
- `compare-lin-captures.ps1` ranks baseline-vs-event new payloads; the rerun ranked `0x0C` top.
- `lin-payload-calc.py` can verify/generate enhanced checksums and candidate payloads; keep generated payload use bench-only.

## Suggested Next Work Order For Desktop AI

1. Read this file first, then read `C:\Users\ezabz\Code\Schematics\firmware\anti-nag-v1\docs\model-x-xiao-lin-handoff-2026-05-18.md`.
2. Verify whether the desktop has the latest docs by checking the files listed above. Do not force-reset or clean the desktop repos.
3. If asked to continue hardware work, focus on a transceiver RXD -> XIAO D3 passive receive adapter.
4. If asked to order parts, recommend TJA1021/MC33662-class LIN module, 12-15 V bench supply/current limit, inline fuses, screw terminal/proto board, and analyzer/scope support. Mention ASIN `B0F31584W1` as the cheap Amazon candidate.
5. If asked to run analysis, use the seated, baseline, and single-control captures. Ignore targeted/debug folders unless specifically investigating failed commands.
6. If asked about active anti-nag/injection, answer that current evidence is bench-analysis-only; active work must wait until receive quality, attribution, bench replay, isolation, and non-customer validation gates pass.
7. If asked why XIAO is not decoding frames, explain physical layer margin: divider row 4 shows transitions but is not reliable enough for ESP32-C3 UART LIN decode; use proper LIN transceiver RXD.
8. Keep all customer-facing conclusions conservative: Model X refresh is not a supported customer install from this evidence alone.

## Confidence Gates Before Any Active Step

These gates must pass in order:

1. Passive capture quality gate: stable decoded frames with transceiver receive path and no persistent checksum/parity anomalies.
2. Attribution gate: repeated labeled datasets prove `0x0C` semantics better than all other IDs.
3. Bench replay gate: framing, PID, schedule, and enhanced checksum validated off-vehicle.
4. Isolation gate: active path hardware cannot unintentionally drive the bus.
5. Controlled non-customer validation gate: bounded reversible tests, no adverse vehicle effects.
6. Customer-car gate: explicit owner approval after all prior gates pass.

Current status: these gates have not all passed. Stay passive/bench-only.

## Short Answer If Owner Asks What We Know

We found a real 19.2 kbps LIN bus on the 2025 Model X steering-wheel `SW` connector white wire. The green wire is about 15.4 V LV power, black is ground, and `DAB` is airbag/SRS and must not be touched. The strongest control frame is ID `0x0C` / PID `0x4C`; B0 centers at `0x10`, rises for volume up, falls for volume down, B1 `0x04` looks like touch/engage, B6 is constant `0xC0`, and B7 is a rolling counter. Checksum is LIN enhanced. The customer car should remain research-only; next step is a TJA1021/MC33662 LIN transceiver module feeding clean RXD into XIAO D3 and a fused 12-15 V bench mock.

## Do Not Lose This Context

The practical reason this file exists: the desktop AI did not have enough context from the scattered docs. Keep this as the first briefing for future desktop chats about Tesla Model X LIN, XIAO, anti-nag, or Moti Zaks vehicle work.