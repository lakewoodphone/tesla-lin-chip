# LIN Capture Session 20260527_201205

- Mode: car-passive
- Vehicle: syntax-check
- Baud: 19200
- Capture point: 
- Firmware expected: field_passive
- Active TX allowed: False

## Preflight

- [ ] Run tools\\preflight-hardware-check.ps1 -Mode car-passive
- [ ] Run firmware version/config and save serial output
- [ ] Attach photos of probe/wiring setup if this is a car capture
- [ ] Copy APG CSV/TXT and XIAO logs into this folder
- [ ] Run tools\\analyze-lin-capture.py with --json into this folder

## Commands

`powershell
.\\tools\\car-day-launcher.ps1 -VehicleId syntax-check -Baud 19200 -DurationSeconds 120
`",
    ",
    


