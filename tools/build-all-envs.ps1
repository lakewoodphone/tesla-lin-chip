<#
.SYNOPSIS
    Build every supported XIAO LIN firmware environment.

.DESCRIPTION
    Runs PlatformIO for the passive field, passive no-WiFi, active bench BLE,
    and chip lab active environments. Use this before bench/car sessions and
    before committing firmware changes.
#>

param(
    [string[]] $Environments = @("field_passive", "field_passive_nowifi", "bench_active_ble", "chip_lab_active", "car_passthrough", "rev_a_passthrough", "rev_a_active_ble"),
    [string] $PlatformIo = ""
)

$ErrorActionPreference = "Stop"

function Resolve-PlatformIo {
    param([string] $RequestedPath)
    $candidates = @(
        $RequestedPath,
        (Join-Path $env:USERPROFILE ".platformio\penv\Scripts\platformio.exe")
    ) | Where-Object { $_ }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command platformio -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "PlatformIO not found. Install PlatformIO or pass -PlatformIo <path>."
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$PlatformIo = Resolve-PlatformIo $PlatformIo
Push-Location $repoRoot
try {
    foreach ($envName in $Environments) {
        Write-Host "============================================================" -ForegroundColor Yellow
        Write-Host "Building $envName" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Yellow
        & $PlatformIo run -e $envName
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO build failed for $envName" }
    }
    Write-Host "All requested firmware environments built successfully." -ForegroundColor Green
} finally {
    Pop-Location
}