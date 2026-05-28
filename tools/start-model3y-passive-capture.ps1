<#
.SYNOPSIS
    Start a passive Model 3/Y capture with a timed steering-control action plan.

.DESCRIPTION
    Creates a manifest-backed car-passive session, injects standard action
    windows for later analyzer correlation, then launches the enforced passive
    car-day capture flow. This never transmits on the vehicle bus.
#>

param(
    [ValidateSet("3", "y", "unknown")]
    [string] $Model = "3",
    [string] $VehicleId = "",
    [UInt16] $Baud = 19200,
    [int] $DurationSeconds = 180,
    [string] $XiaoPort = "COM4",
    [string] $CapturePoint = "Model 3/Y steering LIN",
    [switch] $SkipPreflight,
    [switch] $ApgOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $VehicleId) { $VehicleId = "tesla-model-$Model-$(Get-Date -Format yyyyMMdd)" }
if ($DurationSeconds -lt 180) { throw "Use DurationSeconds >= 180 so the standard action windows fit." }

function Set-ActionWindows([string] $ManifestPath) {
    $manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json
    $manifest.action_windows = @(
        [pscustomobject]@{ name = "baseline-idle"; start_ms = 0; end_ms = 30000; notes = "No controls touched" },
        [pscustomobject]@{ name = "left-scroll-up"; start_ms = 30000; end_ms = 45000; notes = "Repeat left scroll wheel up" },
        [pscustomobject]@{ name = "idle-after-left-up"; start_ms = 45000; end_ms = 60000; notes = "No controls touched" },
        [pscustomobject]@{ name = "left-scroll-down"; start_ms = 60000; end_ms = 75000; notes = "Repeat left scroll wheel down" },
        [pscustomobject]@{ name = "idle-after-left-down"; start_ms = 75000; end_ms = 90000; notes = "No controls touched" },
        [pscustomobject]@{ name = "left-wheel-click"; start_ms = 90000; end_ms = 105000; notes = "Repeat left wheel click/press" },
        [pscustomobject]@{ name = "idle-before-right"; start_ms = 105000; end_ms = 120000; notes = "No controls touched" },
        [pscustomobject]@{ name = "right-scroll-up"; start_ms = 120000; end_ms = 135000; notes = "Repeat right scroll wheel up" },
        [pscustomobject]@{ name = "right-scroll-down"; start_ms = 135000; end_ms = 150000; notes = "Repeat right scroll wheel down" },
        [pscustomobject]@{ name = "right-wheel-click"; start_ms = 150000; end_ms = 165000; notes = "Repeat right wheel click/press" },
        [pscustomobject]@{ name = "final-idle"; start_ms = 165000; end_ms = 180000; notes = "No controls touched" }
    )
    $manifest.notes = ($manifest.notes + "`nStandard 180s Model 3/Y steering action plan applied.").Trim()
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $ManifestPath -Encoding utf8
}

Push-Location $repoRoot
try {
    $sessionOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File tools\new-capture-session.ps1 `
        -Mode car-passive -VehicleId $VehicleId -Baud $Baud -CapturePoint $CapturePoint `
        -Notes "Passive Model 3/Y discovery capture. Active TX is not allowed."
    $sessionOutput | ForEach-Object { Write-Host $_ }
    $sessionLine = $sessionOutput | Where-Object { $_ -match '^Capture session created:\s*(.+)$' } | Select-Object -First 1
    if (-not $sessionLine) { throw "Could not determine session directory" }
    $sessionDir = ($sessionLine -replace '^Capture session created:\s*', '').Trim()
    $manifestPath = Join-Path $sessionDir "manifest.json"
    Set-ActionWindows $manifestPath

    Write-Host ""
    Write-Host "ACTION PLAN DURING CAPTURE" -ForegroundColor Yellow
    Write-Host "  0-30s idle"
    Write-Host "  30-45s left scroll up"
    Write-Host "  45-60s idle"
    Write-Host "  60-75s left scroll down"
    Write-Host "  75-90s idle"
    Write-Host "  90-105s left wheel click"
    Write-Host "  105-120s idle"
    Write-Host "  120-135s right scroll up"
    Write-Host "  135-150s right scroll down"
    Write-Host "  150-165s right wheel click"
    Write-Host "  165-180s idle"
    Write-Host ""
    Write-Host "Passive only: XIAO D2/TX must be disconnected/off before continuing." -ForegroundColor Cyan

    $launcherArgs = @("-VehicleId", $VehicleId, "-Baud", $Baud, "-DurationSeconds", $DurationSeconds, "-XiaoPort", $XiaoPort, "-LogDir", $sessionDir)
    if ($SkipPreflight) { $launcherArgs += "-SkipPreflight" }
    if ($ApgOnly) { $launcherArgs += "-ApgOnly" }
    & powershell -NoProfile -ExecutionPolicy Bypass -File tools\car-day-launcher.ps1 @launcherArgs
    if ($LASTEXITCODE -ne 0) { throw "car-day-launcher failed with code $LASTEXITCODE" }

    Write-Host "Session complete: $sessionDir" -ForegroundColor Green
    Write-Host "Next: powershell -NoProfile -ExecutionPolicy Bypass -File tools\process-model3y-capture.ps1 -SessionDir `"$sessionDir`"" -ForegroundColor Cyan
} finally {
    Pop-Location
}