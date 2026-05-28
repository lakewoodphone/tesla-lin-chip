# Active Injector - Bench Wiring & Operation

This covers the physical TX wiring and runtime operation needed to go from **passive receiver** to **active anti-nag injector** on the isolated bench.

## Physical Wiring Change

The passive receiver already has:

```
APG LIN -> TJA1021 LIN -> TJA1021 RX -> level shifter HV -> level shifter LV -> XIAO D3/GPIO5
```

For active injection, add the TX path:

```
XIAO D2/GPIO4 (UART1 TX) -> level shifter LV/B2 -> level shifter HV/A2 -> TJA1021 TX
```

| Signal | XIAO pin | Level shifter | TJA1021 | Notes |
|---|---|---|---|---|
| RX | D3 / GPIO5 | LV/B1 <- HV/A1 | RX | Proven passive |
| TX | D2 / GPIO4 | LV/B2 -> HV/A2 | TX | Active bench only |
| SLP | 5V out | - | SLP | Must stay HIGH |
| VIN | - | - | Vbat | 12V from bench PSU |

## Multi-Model TX Profiles

| model | LIN ID | Source | Confidence |
|---|---|---|---|
| `x` | `0x0C` | Real Model X capture | CONFIRMED |
| `3` | `0x1A` | Community candidate | UNCONFIRMED |
| `y` | `0x1A` | Assumed same as 3 | UNCONFIRMED |
| `auto` | `0x0C` | Default fallback | DEFAULT |

## Serial Commands (Active Mode)

```
model             Show current profile
model:x           Model X (ID=0x0C)
model:3           Model 3 (ID=0x1A)
model:y           Model Y (ID=0x1A)
antinag:start     Start alternating UP / NEUTRAL / DOWN injection
antinag:stop      Stop injection
antinag:single    Send one UP or DOWN frame, toggle direction
safe:arm          Explicitly arm active TX for isolated bench work
safe:off          Stop active output and disarm
factory:reset     Clear stored model/mode/period config and return safe/off
config            Print runtime and persisted config state
mirror:on         Enable periodic 0x0D alive/mirror frames
mirror:off        Disable mirror frames
tx:id,b0,...      Send custom frame, e.g. tx:0C,10,00,00,00,00,00,C0,00
txd:low           Bench diagnostic: hold XIAO D2/TXD low
txd:high          Bench diagnostic: hold XIAO D2/TXD high
txd:uart          Return D2/TXD to UART mode after diagnostics
```

## Verified Active Bench Result

2026-05-27 active Model X bench TX was validated on the isolated bench after fixing a disconnected D2 -> LV2 jumper. The working active break method is a half-baud UART `0x00` break before returning to the normal LIN baud.

Improvements applied 2026-05-27 afternoon:
- Bus-idle collision guard: frames wait for 2 ms of bus silence before transmitting.
- Realistic scroll payloads: anti-nag frames simulate changing velocity (B2) and accumulated scroll (B3) rather than constant zeros.
- Mirror/alive frame injection: `mirror:on` sends periodic `0x0D` mirror frames every 500 ms alongside `0x0C` control frames.
- BLE configuration service: connect to "TeslaAntiNag" to set model, mode, period, and on/off. Disables cleanly - writes are reflected in real time.
- Active TX requires `safe:arm` before serial/BLE enable can transmit. `safe:off` stops output and disarms.
- Model/mode/period persist in NVS with version+CRC; enable state always boots off.

## BLE Configuration

The XIAO advertises as **"TeslaAntiNag"** after boot (NimBLE). Connect with any BLE client app (nRF Connect, LightBlue, etc.) and find the service `4fafc201-1fb5-459e-8fcc-c5c9c331914b` with these characteristics:

| Characteristic | UUID | Read/Write | Values | Effect |
|---|---|---|---|---|
| Model | `...b26a8` | R/W | `x`, `3`, `y`, `auto` | Switches control LIN ID |
| Mode | `...b26a9` | R/W | `duty`, `always` | 20s burst vs constant alternation |
| Period | `...b26aa` | R/W | `5000`-`120000` (ms) | Duty cycle interval |
| Enable | `...b26ab` | R/W | `on`, `off` | Toggle anti-nag TX after `safe:arm` |
| Status | `...b26ac` | R/Notify | semicolon-delimited state | Firmware/build/model/arm/TX/fault summary |
| Capabilities | `...b26ad` | R | semicolon-delimited capabilities | Phone app feature discovery |

Writing `on` to Enable starts anti-nag only after `safe:arm`; `off` stops it. The double-click wheel button still toggles only after arming.
Serial command `ble` prints full BLE state and UUIDs.

Evidence from XIAO ring/self-receive while running `model:x` + `antinag:start`:

```text
frames=117+ badChk=0 badPid=0
ID=0x0C PID=0x4C [8B] data: 11 04 00 00 00 00 C0 00 | chk=DD enhanced parity=OK
ID=0x0C PID=0x4C [8B] data: 0F 04 00 00 00 00 C0 02 | chk=DD enhanced parity=OK
ID=0x0C PID=0x4C [8B] data: 10 00 00 00 00 00 C0 0A | chk=D8 enhanced parity=OK
```

APG NetworkAnalyser event/display capture still logged zero rows for XIAO-generated frames in this session, but the APG raw USART buffer does see them. `tools\active-apg-raw-proof.ps1` captured 11 checksum-valid known-ID `0x0C` rows with `source=raw`, so the independent APG observer path is now proven for the Model X active bench stream.

## Bench Validation Steps

1. Wire TX as above. APG must be in LINBUS mode on the isolated bench.
2. Build and flash active bench firmware:
   ```powershell
   cd C:\Users\ezabz\Code\xiao-lin-bench
   python -m platformio run -e bench_active_ble
   python -m esptool --chip esp32c3 --port COM4 --baud 115200 --before default_reset --after hard_reset write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m 0x0000 .pio\build\bench_active_ble\bootloader.bin 0x8000 .pio\build\bench_active_ble\partitions.bin 0x10000 .pio\build\bench_active_ble\firmware.bin
   ```
3. Run the proof script:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x
   ```
4. Or open serial manually: `platformio device monitor --port COM4 --baud 115200 --dtr 1 --rts 0`.
5. Run `safe:arm`, `model:x`, then `antinag:start`.
6. Dump XIAO `stats` and `ring` to verify injected frames are being received back from the LIN bus:
   ```
   stats
   ring
   ```
7. Optional: start APG known-ID raw fallback as an independent observer for the Model X bench stream:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -DurationSeconds 6 -MinFrames 8
   ```
8. Verify alternating `0x0C` frames with `B0=0x11/0x0F` and neutral `B0=0x10`, with enhanced checksum/parity OK or `source=raw` APG rows.

## TX Path Debug Checklist

Use `safe:arm` then `txd:low` for one-point-at-a-time multimeter checks, but remember a LIN transceiver may release the bus after dominant-timeout if TXD is held low too long.

Expected low-hold readings after `txd:low`:

| Point | Expected |
|---|---:|
| XIAO D2/GPIO4 | near 0V |
| Level shifter LV2/B2 | near 0V |
| Level shifter HV2/A2 / module TX | near 0V |
| Module SLP | about 5V |

If XIAO D2 is low but LV2 is high, the D2 -> LV2 jumper is disconnected or on the wrong channel. That was the 2026-05-27 bench fault.

## Hard Stops

- TX path is for **isolated bench only** with APG in passive monitor mode.
- Disconnect TX from TJA1021 before any vehicle connection.
- Model 3/Y profiles use unconfirmed candidate IDs.
- Use `field_passive` for vehicle work. Do not flash `bench_active_ble`, `chip_lab_active`, or legacy `xiao_esp32c3` onto a vehicle-connected setup.