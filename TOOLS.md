# Current Tools - Rev A Active Path

Updated: 2026-06-17

## Primary Tool

Use this for the current Rev A Model 3 active workflow:

```powershell
tools\rev-a-active-model3.ps1
```

Actions:

| Action | Purpose |
|---|---|
| `Build` | Build `rev_a_active_ble` |
| `Flash` | Flash bootloader, partitions, and firmware over CP2102 COM6 |
| `Command` | Send serial commands and capture responses |
| `Monitor` | Open a serial monitor on COM6 |
| `BleScan` | Scan for `TeslaPassthrough` BLE advertising |
| `Preflight` | Print the Rev A bench/live-test preflight checklist |

Use `tools\new-rev-a-live-session.ps1` before a bench/car session to create a dated `measurements.md` worksheet under `logs\sessions\`.

Examples:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Build
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Flash -ComPort COM6 -ManualBoot
powershell -NoProfile -ExecutionPolicy Bypass -File tools\new-rev-a-live-session.ps1 -VehicleId tesla-model-3-YYYYMMDD -ComPort COM6
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action Command -ComPort COM6 -Commands version,config,nag:status
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rev-a-active-model3.ps1 -Action BleScan
```

## Still Useful Legacy Tools

The old XIAO/APG tools remain in `tools/` because they are useful for passive capture, APG reference, and bench archaeology. Their old guide is archived at:

```text
docs/archive/legacy-xiao-2026-06-17/TOOLS.legacy.md
```

Do not use old one-LIN XIAO active transmit scripts for Rev A vehicle passthrough testing.
