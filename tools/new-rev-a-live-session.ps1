<#
.SYNOPSIS
    Create a dated Rev A Model 3 live-test session folder and measurement log.

.DESCRIPTION
    This script does not talk to the board or vehicle. It creates a structured
    folder under logs/sessions with a measurements.md worksheet for recording
    preflight readings, serial commands, BLE checks, photos, and findings.
#>

param(
    [string] $VehicleId = "tesla-model-3-unknown",
    [string] $ComPort = "COM6",
    [string] $Operator = $env:USERNAME,
    [string] $OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $OutputRoot) { $OutputRoot = Join-Path $repoRoot "logs\sessions" }
if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$safeVehicleId = ($VehicleId -replace '[^A-Za-z0-9_.-]', '-')
$sessionDir = Join-Path $OutputRoot "$stamp-rev-a-active-$safeVehicleId"
New-Item -ItemType Directory -Path $sessionDir | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sessionDir "photos") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sessionDir "serial") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sessionDir "ble") | Out-Null

$measurementPath = Join-Path $sessionDir "measurements.md"
$content = @"
# Rev A Model 3 Active Session Measurements

Session: $stamp
Vehicle ID: $VehicleId
Operator: $Operator
COM port: $ComPort
Firmware target: rev_a_active_ble / v5.5-rev-a-ble

## Decision Gate

- [ ] Final firmware flashed after manual bootloader entry
- [ ] COM6 responds to version/config/cache/nag:status
- [ ] BLE scan sees TeslaPassthrough
- [ ] safe:off confirmed after boot
- [ ] Physical arm behavior verified
- [ ] Unpowered board measurements pass
- [ ] Bench power measurements pass
- [ ] Car harness measurements pass

Do not connect or arm unless every relevant gate above is checked and notes are filled in.

## Unpowered Board Measurements

| Check | Reading | Pass/Fail | Notes |
|---|---|---|---|
| TP1 GND to TP2 3V3 |  |  |  |
| TP1 GND to F1 left VBAT_IN |  |  |  |
| TP1 GND to F1 right VBAT_PROTECTED |  |  |  |
| F1 left to F1 right fuse continuity |  |  |  |
| TP10 LIN_A to TP1 GND |  |  |  |
| TP11 LIN_B to TP1 GND |  |  |  |
| TP10 LIN_A to TP11 LIN_B |  |  |  |
| TP6 UART0_TX to TP7 UART0_RX |  |  |  |
| TP8 EN to TP1 GND |  |  |  |
| TP9 BOOT to TP1 GND |  |  |  |

## Bench Power Measurements

| Check | Reading | Pass/Fail | Notes |
|---|---|---|---|
| TP2 3V3 to TP1 GND |  |  |  |
| F1 right VBAT_PROTECTED to TP1 GND |  |  |  |
| Current draw idle |  |  |  |
| Serial version response |  |  |  |
| Serial config response |  |  |  |
| BLE scan result |  |  |  |
| safe:off confirmed |  |  |  |

## Car Harness Measurements

| Check | Reading | Pass/Fail | Notes |
|---|---|---|---|
| Vehicle 12V to vehicle ground |  |  |  |
| Vehicle ground to TP1 |  |  |  |
| Car-side LIN idle voltage |  |  |  |
| Wheel-side LIN idle voltage |  |  |  |
| Car/wheel orientation photo saved |  |  |  |
| Native wheel controls work before test |  |  |  |

## Serial Transcript Notes

| Time | Command | Response summary | Observation |
|---|---|---|---|
|  | safe:off |  |  |
|  | bridge:off |  |  |
|  | config |  |  |
|  | cache |  |  |
|  | bridge:on |  |  |
|  | safe:arm |  |  |
|  | vol:up:1 |  |  |
|  | vol:down:1 |  |  |
|  | vol:click:1 |  |  |
|  | nag:once |  |  |
|  | nag:on |  |  |
|  | nag:off |  |  |
|  | safe:off |  |  |

## Findings

- 

## Stop Events / Faults

- 

## Final Safe State

- [ ] nag:off sent
- [ ] inject:clear sent
- [ ] bridge:off sent
- [ ] safe:off sent
- [ ] final config captured
"@

Set-Content -Path $measurementPath -Value $content -Encoding ascii

$readmePath = Join-Path $sessionDir "README.md"
Set-Content -Path $readmePath -Value @"
# Rev A Active Session Folder

Use `measurements.md` as the working checklist.

Subfolders:

```text
photos/   wiring and bench photos
serial/   serial transcripts or copied terminal output
ble/      BLE scan output/screenshots
```

Reference plan: docs/active/model3-live-measurement-plan.md
"@ -Encoding ascii

Write-Host "Created session folder:" -ForegroundColor Green
Write-Host $sessionDir
Write-Host "Measurement log:" -ForegroundColor Green
Write-Host $measurementPath
