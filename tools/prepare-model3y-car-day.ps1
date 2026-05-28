<#
.SYNOPSIS
    Prepare the bench rig for a passive Tesla Model 3/Y capture day.

.DESCRIPTION
    Verifies APG/XIAO USB health, flashes the vehicle-safe field_passive firmware,
    and checks XIAO serial identity. Run this before the car arrives so the only
    remaining work is physical passive probing and capture.
#>

param(
    [string] $ComPort = "COM4",
    [switch] $SkipFlash,
    [switch] $SkipBuildAll
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$pio = Join-Path $env:USERPROFILE ".platformio\penv\Scripts\platformio.exe"
if (-not (Test-Path $pio)) { throw "PlatformIO not found: $pio" }

function Assert-UsbHealthy {
    $devices = @(Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VID_04D8&PID_0A04|VID_303A&PID_1001' })
    if (-not ($devices | Where-Object { $_.InstanceId -match 'VID_04D8&PID_0A04' })) { throw "APGDT001 not present" }
    if (-not ($devices | Where-Object { $_.InstanceId -match 'VID_303A&PID_1001' })) { throw "XIAO ESP32-C3 not present" }
    $bad = @($devices | Where-Object { $_.Status -ne 'OK' })
    if ($bad.Count -gt 0) {
        $bad | Format-List Status,Class,FriendlyName,InstanceId,Problem,ConfigManagerErrorCode
        throw "APG/XIAO USB health check failed"
    }
    $devices | Format-Table Status,Class,FriendlyName,InstanceId -AutoSize
}

function Read-XiaoIdentity {
    $port = New-Object System.IO.Ports.SerialPort($ComPort, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $port.DtrEnable = $true
    $port.RtsEnable = $false
    $port.NewLine = "`n"
    $port.ReadTimeout = 150
    $lines = New-Object System.Collections.Generic.List[string]
    try {
        $port.Open()
        Start-Sleep -Milliseconds 600
        foreach ($cmd in @("version", "config", "stats")) {
            $port.WriteLine($cmd) | Out-Null
            Start-Sleep -Milliseconds 250
        }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 2500) {
            try {
                $line = $port.ReadLine().Trim()
                if ($line) { [void]$lines.Add($line) }
            } catch [TimeoutException] {
            }
        }
    } finally {
        if ($port.IsOpen) { $port.Close() }
    }
    return @($lines)
}

Push-Location $repoRoot
try {
    Write-Host "Checking APG/XIAO USB health..." -ForegroundColor Yellow
    Assert-UsbHealthy

    if (-not $SkipBuildAll) {
        Write-Host "Building all firmware environments..." -ForegroundColor Yellow
        & powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1
        if ($LASTEXITCODE -ne 0) { throw "build-all-envs failed" }
    }

    if (-not $SkipFlash) {
        Write-Host "Flashing field_passive to $ComPort..." -ForegroundColor Yellow
        & $pio run -e field_passive -t upload --upload-port $ComPort
        if ($LASTEXITCODE -ne 0) { throw "field_passive upload failed" }
    }

    Write-Host "Verifying XIAO reports field_passive..." -ForegroundColor Yellow
    $identityLines = Read-XiaoIdentity
    $identityLines | ForEach-Object { Write-Host $_ }
    $identity = $identityLines -join "`n"
    if ($identity -notmatch "build=field_passive") { throw "XIAO did not report build=field_passive" }
    if ($identity -match "active=yes") { throw "XIAO reports active=yes; do not connect to vehicle" }

    Write-Host "READY: APG/XIAO healthy, XIAO is field_passive. Waiting only on Model 3/Y arrival." -ForegroundColor Green
    Write-Host "Vehicle hard stop: keep XIAO D2/TX physically disconnected/off on the car." -ForegroundColor Cyan
} finally {
    Pop-Location
}