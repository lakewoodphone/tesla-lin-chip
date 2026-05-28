<#
.SYNOPSIS
    Create a structured LIN bench/car capture session folder.

.DESCRIPTION
    Creates a timestamped folder under logs/sessions with a manifest JSON,
    operator checklist, and command notes. Use before passive vehicle captures
    or repeatable bench sessions so artifacts do not live only in chat history.
#>

param(
    [ValidateSet("bench", "car-passive", "chip-lab")]
    [string] $Mode = "car-passive",
    [string] $VehicleId = "tesla-unknown",
    [UInt16] $Baud = 19200,
    [string] $CapturePoint = "",
    [string] $Notes = "",
    [string] $LogDir = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs\sessions" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$safeVehicle = ($VehicleId -replace '[^A-Za-z0-9_.-]', '-')
$sessionDir = Join-Path $LogDir "${stamp}-${Mode}-${safeVehicle}"
New-Item -ItemType Directory -Path $sessionDir | Out-Null

$manifest = [ordered]@{
    schema = "xiao-lin-capture-session-v1"
    created_at = (Get-Date).ToString("o")
    mode = $Mode
    vehicle_id = $VehicleId
    baud = $Baud
    capture_point = $CapturePoint
    firmware_expected = if ($Mode -eq "car-passive") { "field_passive" } elseif ($Mode -eq "bench") { "bench_active_ble or field_passive" } else { "chip_lab_active" }
    active_tx_allowed = ($Mode -ne "car-passive")
    notes = $Notes
    artifacts = @{
        apg_csv = ""
        apg_txt = ""
        xiao_serial = ""
        analyzer_json = ""
        photos = @()
    }
    action_windows = @(
        @{ name = "baseline-idle"; start_ms = 0; end_ms = 120000; notes = "No controls touched" },
        @{ name = "steering-scroll-up"; start_ms = 0; end_ms = 0; notes = "Fill after capture" },
        @{ name = "steering-scroll-down"; start_ms = 0; end_ms = 0; notes = "Fill after capture" },
        @{ name = "wheel-click"; start_ms = 0; end_ms = 0; notes = "Fill after capture" }
    )
}

$manifestPath = Join-Path $sessionDir "manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Out-File -FilePath $manifestPath -Encoding utf8

$readme = @(
    "# LIN Capture Session $stamp",
    "",
    "- Mode: $Mode",
    "- Vehicle: $VehicleId",
    "- Baud: $Baud",
    "- Capture point: $CapturePoint",
    "- Firmware expected: $($manifest.firmware_expected)",
    "- Active TX allowed: $($manifest.active_tx_allowed)",
    "",
    "## Preflight",
    "",
    "- [ ] Run tools\\preflight-hardware-check.ps1 -Mode $Mode",
    "- [ ] Run firmware version/config and save serial output",
    "- [ ] Attach photos of probe/wiring setup if this is a car capture",
    "- [ ] Copy APG CSV/TXT and XIAO logs into this folder",
    "- [ ] Run tools\\analyze-lin-capture.py with --json into this folder",
    "",
    "## Commands",
    "",
    "```powershell",
    ".\\tools\\car-day-launcher.ps1 -VehicleId $VehicleId -Baud $Baud -DurationSeconds 120",
    "```",
    "",
    "## Notes",
    "",
    $Notes
)

$readme | Out-File -FilePath (Join-Path $sessionDir "README.md") -Encoding utf8
Write-Host "Capture session created: $sessionDir" -ForegroundColor Green
Write-Host "Manifest: $manifestPath" -ForegroundColor Cyan