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
```

## Bench Validation Steps

1. Wire TX as above. APG must be in LINBUS mode on the isolated bench.
2. Flash firmware with `#define ACTIVE_MODE` enabled (already enabled in default).
3. Open serial: `platformio device monitor --port COM4 --baud 115200 --dtr 1 --rts 0`
4. Run `model:x` then `antinag:start`.
5. Start APG passive monitor to verify injected frames on the LIN bus:
   ```
   cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1
   ```
6. Verify APG sees alternating `0x0C` frames with `B0=0x11/0x0F` and neutral `B0=0x10`.

## Hard Stops

- TX path is for **isolated bench only** with APG in passive monitor mode.
- Disconnect TX from TJA1021 before any vehicle connection.
- Model 3/Y profiles use unconfirmed candidate IDs.
- Comment `#define ACTIVE_MODE` to revert to passive-only firmware.