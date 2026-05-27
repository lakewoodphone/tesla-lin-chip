# Active Injector — Bench Wiring & Operation

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
| SLP | 5V out | — | SLP | Must stay HIGH |
| VIN | — | — | Vbat | 12V from bench PSU |

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
tx:id,b0,...      Send custom frame, e.g. tx:0C,10,00,00,00,00,00,C0,00
txd:low           Bench diagnostic: hold XIAO D2/TXD low
txd:high          Bench diagnostic: hold XIAO D2/TXD high
txd:uart          Return D2/TXD to UART mode after diagnostics
```

## Verified Active Bench Result

2026-05-27 active Model X bench TX was validated on the isolated bench after fixing a disconnected D2 -> LV2 jumper. The working active break method is a half-baud UART `0x00` break before returning to the normal LIN baud.

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
2. Uncomment `#define ACTIVE_MODE`, build, and flash. The repository default keeps active mode commented out.
3. Run the proof script:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort COM4 -Model x
   ```
4. Or open serial manually: `platformio device monitor --port COM4 --baud 115200 --dtr 1 --rts 0`.
5. Run `model:x` then `antinag:start`.
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

Use `txd:low` for one-point-at-a-time multimeter checks, but remember a LIN transceiver may release the bus after dominant-timeout if TXD is held low too long.

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
- Comment `#define ACTIVE_MODE` to revert to passive-only firmware.