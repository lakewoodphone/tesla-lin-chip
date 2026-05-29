<#
.SYNOPSIS
    Guided interactive Model 3/Y steering LIN capture.

.DESCRIPTION
    Opens the XIAO serial port and logs everything to a UTF-8 file continuously.
    Walks you through each steering action one at a time. For each action:
      - The screen shows exactly what to do.
      - You walk to the car, do the action, walk back.
      - You press ENTER when you are back at the laptop.
    The script records wall-clock timestamps for every step so the analyzer
    knows exactly which frames came from which action.

.PARAMETER XiaoPort
    COM port for the XIAO. Default COM7.

.PARAMETER VehicleId
    Label for the session. Default: tesla-model-3-YYYYMMDD.

.PARAMETER SessionDir
    Where to write files. If omitted, creates a timestamped folder under logs\sessions\.

.PARAMETER IdleSeconds
    Auto-idle seconds between walking actions (default 12).
    Stay at the laptop during idle. Do NOT touch anything.

.PARAMETER BaselineSeconds
    Duration (seconds) of the initial no-touch baseline (default 15).

.EXAMPLE
    # Standard run on COM7
    .\tools\guided-model3y-capture.ps1 -XiaoPort COM7

.EXAMPLE
    # Resume into an existing session directory
    .\tools\guided-model3y-capture.ps1 -XiaoPort COM7 -SessionDir "logs\sessions\20260528_xyz"
#>

param(
    [string] $XiaoPort        = "COM7",
    [string] $VehicleId       = "",
    [string] $SessionDir      = "",
    [int]    $IdleSeconds     = 12,
    [int]    $BaselineSeconds = 15
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

# -- Session directory --
if (-not $VehicleId) { $VehicleId = "tesla-model-3-$(Get-Date -Format yyyyMMdd)" }
if (-not $SessionDir) {
    $stamp      = Get-Date -Format "yyyyMMdd_HHmmss"
    $SessionDir = Join-Path $repoRoot "logs\sessions\${stamp}-guided-${VehicleId}"
}
if (-not (Test-Path $SessionDir)) { New-Item -ItemType Directory -Path $SessionDir | Out-Null }

$serialLogPath = Join-Path $SessionDir "xiao-guided-serial.log"
$manifestPath  = Join-Path $SessionDir "manifest.json"

# -- Action sequence --
# type="auto"   - timed idle; stay at laptop, do NOT touch anything
# type="action" - walk to car, do the action, walk back, press ENTER
$STEPS = @(
    [ordered]@{ name="baseline-idle";      type="auto";   seconds=$BaselineSeconds; display=$null;                                       notes="Initial baseline - no actions, stay at laptop" }
    [ordered]@{ name="left-scroll-up";     type="action"; seconds=0;                display="LEFT WHEEL -- SCROLL UP (5+ clicks)";            notes="Scroll left scroll wheel upward" }
    [ordered]@{ name="idle-1";             type="auto";   seconds=$IdleSeconds;     display=$null;                                       notes="Idle after left scroll up" }
    [ordered]@{ name="left-scroll-down";   type="action"; seconds=0;                display="LEFT WHEEL -- SCROLL DOWN (5+ clicks)";          notes="Scroll left scroll wheel downward" }
    [ordered]@{ name="idle-2";             type="auto";   seconds=$IdleSeconds;     display=$null;                                       notes="Idle after left scroll down" }
    [ordered]@{ name="left-wheel-click";   type="action"; seconds=0;                display="LEFT WHEEL -- CLICK the center button";          notes="Press/click the left scroll wheel button" }
    [ordered]@{ name="idle-3";             type="auto";   seconds=$IdleSeconds;     display=$null;                                       notes="Idle before right controls" }
    [ordered]@{ name="right-scroll-up";    type="action"; seconds=0;                display="RIGHT WHEEL -- SCROLL UP (5+ clicks)";           notes="Scroll right scroll wheel upward" }
    [ordered]@{ name="idle-4";             type="auto";   seconds=$IdleSeconds;     display=$null;                                       notes="Idle between right scroll actions" }
    [ordered]@{ name="right-scroll-down";  type="action"; seconds=0;                display="RIGHT WHEEL -- SCROLL DOWN (5+ clicks)";         notes="Scroll right scroll wheel downward" }
    [ordered]@{ name="idle-5";             type="auto";   seconds=$IdleSeconds;     display=$null;                                       notes="Idle after right scroll down" }
    [ordered]@{ name="right-wheel-click";  type="action"; seconds=0;                display="RIGHT WHEEL -- CLICK the center button";         notes="Press/click the right scroll wheel button" }
    [ordered]@{ name="final-idle";         type="auto";   seconds=$BaselineSeconds; display=$null;                                       notes="Final baseline - no actions, stay at laptop" }
)

$totalActions = @($STEPS | Where-Object { $_.type -eq "action" }).Count

# -- Background serial reader: uses Start-Job + a stop-flag file --
# The job writes "HH:mm:ss.fff <line>" to $serialLogPath.
# Main script counts lines in the file to get live frame count.
# Stop is signaled by creating $stopFlagPath.
$stopFlagPath = Join-Path $SessionDir "stop.flag"
if (Test-Path $stopFlagPath) { Remove-Item $stopFlagPath -Force }

$serialJob = Start-Job -ScriptBlock {
    param($port, $logPath, $flagPath)
    try {
        $sp = New-Object System.IO.Ports.SerialPort(
            $port, 115200,
            [System.IO.Ports.Parity]::None, 8,
            [System.IO.Ports.StopBits]::One)
        $sp.DtrEnable   = $true
        $sp.RtsEnable   = $false
        $sp.ReadTimeout = 300
        $sp.Open()

        $enc = New-Object System.Text.UTF8Encoding($false)
        $sw  = New-Object System.IO.StreamWriter($logPath, $false, $enc)
        $sw.AutoFlush = $true

        while (-not (Test-Path $flagPath)) {
            try {
                $line = $sp.ReadLine().TrimEnd()
                if ($line) {
                    $ts = [DateTime]::Now.ToString('HH:mm:ss.fff')
                    $sw.WriteLine("$ts $line")
                }
            } catch [System.TimeoutException] {
                # normal - keep looping
            }
        }

        $sw.Close()
        $sp.Close()

    } catch {
        $_ | Out-String | Set-Content -Path ($logPath + ".err")
    }
} -ArgumentList $XiaoPort, $serialLogPath, $stopFlagPath

# Helper: get current frame count by counting lines in the log
function Get-FrameCount {
    if (-not (Test-Path $serialLogPath)) { return 0 }
    try { return @(Get-Content $serialLogPath -ErrorAction SilentlyContinue).Count } catch { return 0 }
}

# Give the port 1s to open
Start-Sleep -Milliseconds 1500

# Check for startup errors
$errFile = $serialLogPath + ".err"
if (Test-Path $errFile) {
    $errText = Get-Content $errFile -Raw
    Write-Host ""
    Write-Host "  ERROR: Could not open $XiaoPort" -ForegroundColor Red
    Write-Host "  $errText" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Make sure the XIAO is plugged in and no other program is using $XiaoPort." -ForegroundColor Yellow
    Set-Content $stopFlagPath "stop"
    exit 1
}

# -- Display helpers --
function Show-Rule([ConsoleColor]$c = "DarkGray") {
    Write-Host ("  " + ("-" * 58)) -ForegroundColor $c
}

function Show-AutoIdle([string]$label, [int]$seconds) {
    Write-Host ""
    Write-Host "  [ IDLE - $label - stay at laptop, do NOT touch anything ]" -ForegroundColor DarkCyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $seconds) {
        $remaining = [int]($seconds - $sw.Elapsed.TotalSeconds)
        $frames    = Get-FrameCount
        Write-Host "`r  [ $remaining s remaining ... frames=$frames ]   " -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 400
    }
    Write-Host "`r  [ IDLE done - frames=$(Get-FrameCount) ]                         " -ForegroundColor DarkGray
    Write-Host ""
}

function Show-ActionPrompt([string]$stepName, [string]$display, [int]$actionNum) {
    Write-Host ""
    Write-Host ""
    Show-Rule "Yellow"
    Write-Host ""
    Write-Host ("  ACTION {0} of {1}" -f $actionNum, $totalActions) -ForegroundColor White
    Write-Host ""
    Write-Host "      1.  Walk to the car" -ForegroundColor Yellow
    Write-Host ("      2.  {0}" -f $display) -ForegroundColor Cyan
    Write-Host "      3.  Walk back to the laptop" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  When you are BACK and DONE, press  ENTER" -ForegroundColor Green
    Write-Host ""
    Show-Rule "Yellow"
    Write-Host ""
    $null = Read-Host
}

# -- Manifest init --
$manifest = [ordered]@{
    schema         = "xiao-lin-guided-v1"
    created_at     = (Get-Date -Format "o")
    mode           = "guided-interactive"
    vehicle_id     = $VehicleId
    xiao_port      = $XiaoPort
    serial_log     = $serialLogPath
    action_windows = [System.Collections.ArrayList]@()
}

# -- Welcome screen --
Clear-Host
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "  Tesla Model 3/Y  -  Guided Steering LIN Capture" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Vehicle   :  $VehicleId" -ForegroundColor Gray
Write-Host "  Port      :  $XiaoPort" -ForegroundColor Gray
Write-Host "  Log file  :  $serialLogPath" -ForegroundColor Gray
Write-Host "  Manifest  :  $manifestPath" -ForegroundColor Gray
Write-Host ""
Write-Host ("  This capture has {0} walking actions." -f $totalActions) -ForegroundColor White
Write-Host "  For each action the script will pause and show you what to do." -ForegroundColor White
Write-Host "  You walk to the car, do it, walk back, and press ENTER." -ForegroundColor White
Write-Host ""

# Verify frames are coming in
Write-Host "  Checking XIAO serial... " -NoNewline -ForegroundColor DarkGray
Start-Sleep -Milliseconds 1500
    $check = Get-FrameCount
    if ($check -gt 0) {
        Write-Host "$check frames already received. XIAO is live." -ForegroundColor Green
    } else {
        Write-Host "0 frames received." -ForegroundColor Yellow
    Write-Host "  XIAO may still be starting up. Continuing - frames will appear once the car is on." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "  Do NOT touch any controls yet." -ForegroundColor Red
Write-Host "  Press ENTER when you are ready to begin..." -ForegroundColor Green
$null = Read-Host

# -- Main capture loop --
$actionNumber = 0

try {
    foreach ($step in $STEPS) {

        $stepStart = Get-Date

        if ($step.type -eq "auto") {
            Show-AutoIdle -label $step.name -seconds $step.seconds

        } elseif ($step.type -eq "action") {
            $actionNumber++
            Show-ActionPrompt -stepName $step.name -display $step.display -actionNum $actionNumber
        }

        $stepEnd = Get-Date

        [void]$manifest.action_windows.Add([ordered]@{
            name         = $step.name
            type         = $step.type
            wall_start   = $stepStart.ToString("o")
            wall_end     = $stepEnd.ToString("o")
            duration_s   = [math]::Round(($stepEnd - $stepStart).TotalSeconds, 2)
            frames_at_end = Get-FrameCount
            notes        = $step.notes
        })

        Write-Host "  >> $($step.name)  [frames so far: $(Get-FrameCount)]" -ForegroundColor DarkGray
    }

} finally {
    # Signal the background job to stop and wait for it
    Set-Content -Path $stopFlagPath -Value "stop"
    Wait-Job $serialJob -Timeout 5 | Out-Null
    Remove-Job $serialJob -Force

    # Write manifest
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding utf8 -NoNewline
}

# -- Done --
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "  CAPTURE COMPLETE" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("  Frames captured  :  {0}" -f (Get-FrameCount)) -ForegroundColor White
Write-Host "  Log file         :  $serialLogPath" -ForegroundColor Cyan
Write-Host "  Manifest         :  $manifestPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Run the analyzer with:" -ForegroundColor Yellow
Write-Host "    python tools\analyze-log-bytes.py `"$SessionDir`"" -ForegroundColor White
Write-Host ""
