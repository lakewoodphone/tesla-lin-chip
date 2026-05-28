<#
.SYNOPSIS
    Unified car-day launcher for Tesla 3/Y/X LIN bus capture.
    
.DESCRIPTION
    Single entry point for all car-day operations. Guides through:
      1. Preflight checks
      2. APGDT001 passive capture (high-volume)
      3. XIAO passive capture (real-time decode + WiFi telemetry)
      4. Post-capture summary

    Works for Tesla Model 3, Y, and X — no assumptions about IDs.
    Captures whatever the bus actually emits.

.PARAMETER Baud
    LIN bus baud rate. Default 19200 (Model X B-LIN, Model 3/Y steering).
    Try 9600 if you see nothing (older body buses).
    Runtime baud switch is supported via serial command to XIAO.

.PARAMETER VehicleId
    Vehicle identifier for labeling captures (e.g. tesla-model-3-vin123).
    Also sent to the XIAO firmware via serial command at startup.

.PARAMETER DurationSeconds
    APG capture duration in seconds. Default 120. 0 = manual stop via Ctrl+C.

.PARAMETER ApgOnly
    Skip XIAO setup; only run APG capture.

.PARAMETER XiaoOnly
    Skip APG capture; only monitor XIAO serial.

.PARAMETER XiaoPort
    COM port for XIAO. Default COM4.

.PARAMETER LogDir
    Directory for capture logs. Default: xiao-lin-bench\logs

.EXAMPLE
    # Full car day: APG + XIAO, Model 3, 180s capture
    .\tools\car-day-launcher.ps1 -VehicleId tesla-model-3-test -DurationSeconds 180

.EXAMPLE
    # Model X, shorter capture, 9600 baud fallback
    .\tools\car-day-launcher.ps1 -VehicleId tesla-model-x -Baud 9600 -DurationSeconds 60

.EXAMPLE
    # XIAO-only monitoring (APG already running)
    .\tools\car-day-launcher.ps1 -VehicleId tesla-model-y -XiaoOnly

.NOTES
    APG requires 32-bit PowerShell (SysWOW64).
    XIAO must be flashed and configured before car day.
#>

param(
    [UInt16] $Baud            = 19200,
    [string] $VehicleId       = "tesla-unknown",
    [int]    $DurationSeconds = 120,
    [switch] $ApgOnly,
    [switch] $XiaoOnly,
    [string] $XiaoPort        = "COM4",
    [string] $LogDir          = "",
    [switch] $SkipPreflight,
    [switch] $AllowNonPassiveFirmware
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionLog = Join-Path $LogDir "car-day-${stamp}.log"

function Write-Session($msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    $line | Tee-Object -FilePath $script:sessionLog -Append | Out-Null
}

function Test-XiaoPort {
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    return $ports -contains $XiaoPort
}

function Send-XiaoCommand {
    param([string]$Cmd)
    $lines = New-Object System.Collections.Generic.List[string]
    try {
        $port = New-Object System.IO.Ports.SerialPort($XiaoPort, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
        $port.DtrEnable = $true
        $port.RtsEnable = $false
        $port.ReadTimeout = 100
        $port.WriteTimeout = 500
        $port.Open()
        $port.WriteLine($Cmd)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt 500) {
            try {
                $line = $port.ReadLine().Trim()
                if ($line) {
                    [void]$lines.Add($line)
                    Write-Session "XIAO> $line"
                }
            } catch [System.TimeoutException] {
            }
        }
        $port.Close()
        Write-Session "XIAO< $Cmd"
    } catch {
        Write-Session "XIAO send failed: $_"
    }
    return $lines
}

# ---- Welcome ----
Clear-Host
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "   Tesla LIN Capture - Car Day Launcher"                       -ForegroundColor Cyan
Write-Host "   Vehicle: $VehicleId   Baud: $Baud"                          -ForegroundColor Cyan
Write-Host "   Log: $sessionLog"                                            -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Session "=== CAR DAY STARTED ==="
Write-Session "Vehicle: $VehicleId  Baud: $Baud"
Write-Session "APG-only: $ApgOnly  XIAO-only: $XiaoOnly  Duration: $DurationSeconds"

# ---- Preflight ----
Write-Host ""
Write-Host "--- PREFLIGHT CHECKLIST ---" -ForegroundColor Yellow
Write-Host "[ ] APGDT001 connected via USB"
Write-Host "[ ] XIAO connected on $XiaoPort"
Write-Host "[ ] 12V supply/battery clip ready"
Write-Host "[ ] GND jumper verified common"
Write-Host "[ ] Back-probes in bag"
Write-Host "[ ] Vehicle LIN wire identified (White/black/green?"
Write-Host "[ ] XIAO flashed with field_passive firmware"
Write-Host "[ ] Active TX path physically disconnected/off for vehicle"
Write-Host "[ ] Console output logging on laptop"
Write-Host ""

if (-not $SkipPreflight) {
    Write-Session "Running enforced passive car preflight"
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "tools\preflight-hardware-check.ps1") -Mode car-passive -LogDir $LogDir -RequirePass
    if ($LASTEXITCODE -ne 0) { throw "Passive car preflight failed; aborting capture launcher" }
} else {
    Write-Session "Preflight skipped by operator flag"
}

if (-not $XiaoOnly) {
    $confirmed = Read-Host "Press Enter to start APG capture, or Ctrl+C to abort"
}

# ---- Phase 1: XIAO configuration ----
if (-not $ApgOnly -and (Test-XiaoPort)) {
    Write-Session "Configuring XIAO on $XiaoPort"
    [void](Send-XiaoCommand "safe:off")
    $versionLines = @(Send-XiaoCommand "version")
    $configLines = @(Send-XiaoCommand "config")
    $identity = (($versionLines + $configLines) -join "`n")
    if (-not $AllowNonPassiveFirmware) {
        if ($identity -match "active=yes" -or $identity -notmatch "build=field_passive") {
            Write-Session "ABORT: XIAO is not reporting field_passive passive firmware"
            throw "Car-day launcher requires field_passive firmware by default. Reflash field_passive or pass -AllowNonPassiveFirmware for a bench-only diagnostic session."
        }
    }
    [void](Send-XiaoCommand "vehicle:$VehicleId")
    [void](Send-XiaoCommand "baud:$Baud")
    Write-Host "XIAO configured: vehicle=$VehicleId baud=$Baud" -ForegroundColor Green
}

# ---- Phase 2: APG passive capture ----
if (-not $XiaoOnly) {
    Write-Session "Starting APG passive capture at $Baud baud"
    Write-Host ""
    Write-Host "--- APG PASSIVE CAPTURE ---" -ForegroundColor Green
    Write-Host "APG LINBUS: pin1=LIN  pin2=GND  pin3=12V" -ForegroundColor DarkGray
    Write-Host "Capture will run for ${DurationSeconds}s (or Ctrl+C to stop early)" -ForegroundColor Gray
    Write-Host ""

    $apgScript = Join-Path $repoRoot "tools\monitor-apg-lin-bus.ps1"
    $apgArgs = @(
        "-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $apgScript,
        "-Baud", $Baud,
        "-LogDir", $LogDir,
        "-DurationSeconds", $DurationSeconds
    )

    try {
        & "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" @apgArgs
    } catch {
        Write-Session "APG capture stopped: $_"
    }
    Write-Session "APG capture completed"
}

# ---- Phase 3: XIAO monitoring ----
if (-not $ApgOnly) {
    Write-Host ""
    Write-Host "--- XIAO PASSIVE MONITOR ---" -ForegroundColor Green
    Write-Host "Opening XIAO serial on $XiaoPort @ 115200" -ForegroundColor Gray
    Write-Host "Commands: vehicle:<id>  baud:<rate>  raw:0/1  ring  stats" -ForegroundColor DarkGray
    Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
    Write-Host ""

    if (Test-XiaoPort) {
        Write-Session "Starting XIAO serial monitor on $XiaoPort"
        & "C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe" device monitor --port $XiaoPort --baud 115200 --dtr 1 --rts 0
        Write-Session "XIAO monitor stopped"
    } else {
        Write-Warning "XIAO not found on $XiaoPort — skip monitor"
    }
}

# ---- Phase 4: Summary ----
Write-Host ""
Write-Host "--- CAPTURE SUMMARY ---" -ForegroundColor Yellow

$csvFiles = Get-ChildItem $LogDir -Filter "lin-capture-*.csv" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if ($csvFiles) {
    $latestCsv = $csvFiles[0].FullName
    $summaryScript = Join-Path $repoRoot "tools\summarize-lin-capture.ps1"
    Write-Session "Generating capture summary from $latestCsv"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $summaryScript -CsvPath $latestCsv
} else {
    Write-Host "No APG capture CSV found in $LogDir" -ForegroundColor DarkGray
}

Write-Session "=== CAR DAY COMPLETE ==="
Write-Host ""
Write-Host "Session log: $sessionLog" -ForegroundColor Cyan
Write-Host "APG logs:    $LogDir\lin-capture-*.txt/csv" -ForegroundColor Cyan
Write-Host "Telemetry:   curl http://localhost:8002/api/v1/lin-events" -ForegroundColor Cyan