<#
.SYNOPSIS
    Anti-nag replay tool - sends a sequence of simulated scroll-wheel frames
    through the APGDT001 to the XIAO bench for receive validation.

.DESCRIPTION
    Generates alternating UP/DOWN scroll frames at ID=0x0C with correct
    rolling counter and LIN 2.1 enhanced checksums. This is a bench-only
    tool. NEVER run on a vehicle bus.

    The frames simulate the Tesla Model X scroll-wheel anti-nag pattern:
    alternating scroll up (B0=0x11) and scroll down (B0=0x0F) with
    engage bit (B1=0x04). Counter advances each frame. Net volume = 0.

.PARAMETER Id
    LIN raw ID to send. Default 0x0C (Model X steering). For Model 3/Y
    left-volume bench testing, use 0x2A; the old 0x1A/0x1B candidates are historical.

.PARAMETER Repeat
    Number of UP/DOWN cycles. Default 8 (16 frames).

.PARAMETER DelayMs
    Milliseconds between frames. Default 500 (adjust for Tesla bus timing).

.PARAMETER Baud
    LIN baud rate. Default 19200. Try 9600 if XIAO receives garbled.

.NOTES
    This transmits on the LIN bus. Only run on the isolated bench setup
    (APG + TJA1021 + XIAO). Do not connect to any vehicle.

    Requires 32-bit PowerShell (SysWOW64) - PICkitS.dll is x86 only.
#>

param(
    [Byte]    $Id      = 0x0C,
    [int]     $Repeat  = 8,
    [int]     $DelayMs = 500,
    [UInt16]  $Baud    = 19200,
    [ValidateRange(0,8)]
    [int]     $NeutralFrames = 2,
    [ValidateRange(1,5)]
    [int]     $RetryCount = 2
)

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    Write-Host "Relaunching in 32-bit PowerShell..." -ForegroundColor Yellow
    $args32 = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath,
                "-Id", $Id, "-Repeat", $Repeat, "-DelayMs", $DelayMs, "-Baud", $Baud,
                "-NeutralFrames", $NeutralFrames, "-RetryCount", $RetryCount)
    & "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" @args32
    exit $LASTEXITCODE
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$logDir = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "antinag-replay-${stamp}.csv"
$detailLog = Join-Path $logDir "antinag-replay-${stamp}.log"

# LIN checksum helper
function Get-LinChecksum([byte]$protectedId, [byte[]]$data) {
    $sum = [int]$protectedId
    foreach ($b in $data) {
        $sum += $b
        while ($sum -gt 0xFF) { $sum = ($sum -band 0xFF) + ($sum -shr 8) }
    }
    return [byte](255 - $sum)
}

# Protected ID computation
function Get-ProtectedId([byte]$rawId) {
    $id = $rawId -band 0x3F
    $id0 = ($id -shr 0) -band 1
    $id1 = ($id -shr 1) -band 1
    $id2 = ($id -shr 2) -band 1
    $id3 = ($id -shr 3) -band 1
    $id4 = ($id -shr 4) -band 1
    $id5 = ($id -shr 5) -band 1
    $p0 = $id0 -bxor $id1 -bxor $id2 -bxor $id4
    $p1 = -bnot ($id1 -bxor $id3 -bxor $id4 -bxor $id5) -band 1
    return [byte]($id -bor ($p0 -shl 6) -bor ($p1 -shl 7))
}

$netAnalyserSender = Join-Path $repoRoot "tools\send-netanalyser-headless.ps1"
$x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"

function Write-Detail([string]$message) {
    $line = "[$(Get-Date -Format 'HH:mm:ss.fff')] $message"
    $line | Out-File -FilePath $script:detailLog -Append -Encoding utf8
}

function Invoke-ApgSend {
    param(
        [string]$FrameArg,
        [string]$Label
    )

    $lastOutput = @()
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        Write-Detail "SEND label=$Label attempt=$attempt frame='$FrameArg' baud=$Baud"
        $sendArgs = @(
            "-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $netAnalyserSender,
            "-Baud", $Baud,
            "-Frame", $FrameArg,
            "-Checksum", "Enhanced"
        )
        $output = & $x86PowerShell @sendArgs 2>&1
        $exitCode = $LASTEXITCODE
        $lastOutput = $output
        foreach ($line in $output) { Write-Detail "APG $line" }
        $statusLine = ($output | Where-Object { $_ -match '^Status:' } | Select-Object -Last 1)
        $status = if ($statusLine) { ($statusLine -replace '^Status:\s*', '') } else { "exit=$exitCode no status" }

        if ($exitCode -eq 0 -and ($status -match 'Transmission successful' -or $status -match 'no status')) {
            return $status
        }

        if ($attempt -lt $RetryCount) {
            Write-Host "APG send retry $attempt/$RetryCount for $Label ($status)" -ForegroundColor Yellow
            Start-Sleep -Milliseconds 350
        }
    }

    $last = ($lastOutput -join " | ")
    throw "APG send failed for $Label frame '$FrameArg'. Last output: $last"
}

function Write-ReplayCsv {
    param(
        [int]$Cycle,
        [string]$Direction,
        [int]$FrameNumber,
        [string]$DataHex,
        [byte]$Checksum,
        [string]$Status
    )

    "{0},{1},{2},0x{3:X2},{4},{5},0x{6:X2},{7},{8}" -f `
        $Cycle, $Direction, $FrameNumber, $Id, $script:pidHex, ($DataHex -replace " ","-"), $Checksum, $Baud, ($Status -replace ',', ';') |
        Out-File -FilePath $script:logFile -Append -Encoding utf8
}

# CSV header
"cycle,direction,frame_num,id_hex,pid_hex,data_hex,chk_hex,baud,status" | Out-File -FilePath $logFile -Encoding utf8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "        ANTI-NAG BENCH REPLAY v1"                             -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ID=0x$("{0:X2}" -f $Id)  Baud=$Baud  Repeat=$Repeat  Delay=${DelayMs}ms" -ForegroundColor Cyan
Write-Host "  BENCH ONLY - NOT FOR VEHICLE USE"                           -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$protectedId = Get-ProtectedId $Id
$pidHex = "0x{0:X2}" -f $protectedId
$frameNum = 0
$frameLog = @()
$ctrlUp = @(0x11, 0x04, 0x00, 0x00, 0x00, 0x00, 0xC0)
$ctrlDown = @(0x0F, 0x04, 0x00, 0x00, 0x00, 0x00, 0xC0)
$ctrlNeutralOnly = @(0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0)

for ($cycle = 1; $cycle -le $Repeat; $cycle++) {
    $directions = @(
        @{ name = "UP"; data = $ctrlUp },
        @{ name = "DOWN"; data = $ctrlDown }
    )

    foreach ($dir in $directions) {
        $ctr = $frameNum % 16
        $frameData = $dir.data + @($ctr)
        $chk = Get-LinChecksum $protectedId $frameData
        $dataHex = ($frameData | ForEach-Object { "{0:X2}" -f $_ }) -join " "

        Write-Host ("[{0,2}/{1}] {2,-5} ctr={3,2}  ID=0x{4:X2} PID={5}  data: {6}  chk=0x{7:X2}" -f `
            $cycle, $Repeat, $dir.name, $ctr, $Id, $pidHex, $dataHex, $chk)

        # Send via APG (ID byte + data bytes only; APG computes checksum)
        $frameArg = "{0:X2} {1}" -f $Id, $dataHex
        $status = Invoke-ApgSend -FrameArg $frameArg -Label ("{0}-{1}" -f $cycle, $dir.name)
        Write-ReplayCsv -Cycle $cycle -Direction $dir.name -FrameNumber $frameNum -DataHex $dataHex -Checksum $chk -Status $status

        $frameNum++
        Start-Sleep -Milliseconds $DelayMs
    }
}

# Send neutral frame(s) with next counters to indicate end of replay.
# More than one neutral gives the receiver a stable idle signature after the
# alternating UP/DOWN sequence.
for ($neutral = 1; $neutral -le $NeutralFrames; $neutral++) {
    $ctr = $frameNum % 16
    $frameData = $ctrlNeutralOnly + @($ctr)
    $chk = Get-LinChecksum $protectedId $frameData
    $dataHex = ($frameData | ForEach-Object { "{0:X2}" -f $_ }) -join " "
    $frameArg = "{0:X2} {1}" -f $Id, $dataHex

    Write-Host ("[neutral {0}/{1}] ctr={2,2}  ID=0x{3:X2} PID={4}  data: {5}  chk=0x{6:X2}" -f `
        $neutral, $NeutralFrames, $ctr, $Id, $pidHex, $dataHex, $chk)

    $status = Invoke-ApgSend -FrameArg $frameArg -Label ("neutral-{0}" -f $neutral)
    Write-ReplayCsv -Cycle 0 -Direction "NEUTRAL" -FrameNumber $frameNum -DataHex $dataHex -Checksum $chk -Status $status
    $frameNum++
    if ($neutral -lt $NeutralFrames) { Start-Sleep -Milliseconds $DelayMs }
}

Write-Host ""
Write-Host "Replay complete - $frameNum frames sent" -ForegroundColor Green
Write-Host "Log: $logFile" -ForegroundColor Gray
Write-Host "Detail log: $detailLog" -ForegroundColor Gray
Write-Host ""
Write-Host "Check XIAO serial output to confirm reception:" -ForegroundColor Yellow
Write-Host "  C:\Users\ezabz\.platformio\penv\Scripts\platformio.exe device monitor --port COM4 --baud 115200 --dtr 1 --rts 0" -ForegroundColor DarkGray
Write-Host ""