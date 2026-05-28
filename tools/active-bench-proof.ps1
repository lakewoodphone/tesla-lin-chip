<#
.SYNOPSIS
    Active Model X LIN bench proof runner for the XIAO firmware.

.DESCRIPTION
    Bench-only script. Opens the XIAO serial port, switches TXD back to UART mode,
    starts the selected active model profile, collects TX/self-receive evidence,
    dumps stats and the ring buffer, stops active TX, and writes proof logs.

    Do not run this while connected to a vehicle bus.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -Model x -DurationSeconds 8
#>

param(
    [string] $ComPort = "COM4",
    [ValidateSet("x", "3", "y", "auto")]
    [string] $Model = "x",
    [int] $DurationSeconds = 6,
    [int] $BootWaitSeconds = 2,
    [int] $RingReadMs = 3500,
    [int] $RequiredRingFrames = 3,
    [string] $LogDir = "",
    [switch] $ConfirmBenchIsolation
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$textLog = Join-Path $LogDir "active-bench-proof-${stamp}.log"
$summaryLog = Join-Path $LogDir "active-bench-proof-${stamp}.md"

function Write-ProofLog([string] $message) {
    $line = "[$(Get-Date -Format 'HH:mm:ss.fff')] $message"
    $line | Tee-Object -FilePath $script:textLog -Append
}

function Open-XiaoSerial {
    $serialPort = New-Object System.IO.Ports.SerialPort($ComPort, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $serialPort.DtrEnable = $false
    $serialPort.RtsEnable = $false
    $serialPort.NewLine = "`n"
    $serialPort.ReadTimeout = 150
    $serialPort.Open()
    return $serialPort
}

function Read-SerialLines($serialPort, [int] $timeoutMs) {
    $lines = New-Object System.Collections.Generic.List[string]
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.ElapsedMilliseconds -lt $timeoutMs) {
        try {
            $line = $serialPort.ReadLine().Trim()
            if ($line) {
                $lines.Add($line)
                Write-ProofLog "SERIAL $line"
            }
        } catch [System.TimeoutException] {
            # Continue until the timeout expires.
        }
    }
    return $lines
}

function Send-XiaoCommand($serialPort, [string] $command, [int] $settleMs = 150) {
    Write-ProofLog "XIAO< $command"
    $serialPort.WriteLine($command)
    Start-Sleep -Milliseconds $settleMs
}

function Add-CollectedLines($target, $lines) {
    foreach ($line in $lines) {
        [void]$target.Add([string]$line)
    }
}

Write-ProofLog "============================================================"
Write-ProofLog "XIAO active bench proof"
Write-ProofLog "Serial: $ComPort @ 115200   Model: $Model   Duration: ${DurationSeconds}s"
Write-ProofLog "Log: $textLog"
Write-ProofLog "Summary: $summaryLog"
Write-ProofLog "============================================================"
Write-ProofLog "BENCH ONLY. Do not run while connected to a vehicle bus."

if (-not $ConfirmBenchIsolation) {
    $confirmation = Read-Host "Type BENCH to confirm this active proof is on an isolated bench, not a vehicle bus"
    if ($confirmation -ne "BENCH") {
        Write-ProofLog "ABORT active proof: bench isolation not confirmed"
        exit 1
    }
}

$serialPort = $null
$allLines = New-Object System.Collections.Generic.List[string]
$exitCode = 1

try {
    $serialPort = Open-XiaoSerial
    Write-ProofLog "Serial opened. Waiting $BootWaitSeconds seconds for boot/settle..."
    Add-CollectedLines $allLines (Read-SerialLines $serialPort ($BootWaitSeconds * 1000))

    Send-XiaoCommand $serialPort "version"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 600)

    Send-XiaoCommand $serialPort "config"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 600)

    Send-XiaoCommand $serialPort "ble"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 600)

    Send-XiaoCommand $serialPort "txd:uart"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 600)

    Send-XiaoCommand $serialPort "safe:arm"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 600)

    Send-XiaoCommand $serialPort "model:$Model"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 600)

    Send-XiaoCommand $serialPort "antinag:start"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort ($DurationSeconds * 1000))

    Send-XiaoCommand $serialPort "stats"
    Start-Sleep -Milliseconds 100
    Send-XiaoCommand $serialPort "ring"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort $RingReadMs)

    Send-XiaoCommand $serialPort "antinag:stop"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 900)

    Send-XiaoCommand $serialPort "safe:off"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 700)

    Send-XiaoCommand $serialPort "events"
    Add-CollectedLines $allLines (Read-SerialLines $serialPort 1200)

    $joined = ($allLines -join "`n")
    $armAck = $joined -match "cmd: safe=armed"
    $activeAck = $joined -match "cmd: antinag=active"
    $stopAck = $joined -match "cmd: antinag=stopped"
    $txCount = ([regex]::Matches($joined, "TX #")).Count
    $ringOkMatches = [regex]::Matches($joined, "ID=0x0C\s+PID=0x4C\s+\[8B\].*enhanced parity=OK")
    $ringOkCount = $ringOkMatches.Count
    $badStats = $joined -match "badChk=[1-9]" -or $joined -match "badPid=[1-9]"

    $passed = $armAck -and $activeAck -and ($txCount -gt 0) -and ($ringOkCount -ge $RequiredRingFrames) -and (-not $badStats)

    $summary = @(
        "# Active Bench Proof ${stamp}",
        "",
        "- Port: $ComPort",
        "- Model: $Model",
        "- Duration seconds: $DurationSeconds",
        "- Active acknowledged: $activeAck",
        "- Safe arm acknowledged: $armAck",
        "- Stop acknowledged: $stopAck",
        "- TX lines observed: $txCount",
        "- Valid Model X ring frames: $ringOkCount",
        "- Bad checksum/parity stats seen: $badStats",
        "- Event log captured: $($joined -match 'events:')",
        "- Result: $(if ($passed) { 'PASS' } else { 'FAIL' })",
        "",
        "## Notes",
        "",
        "This is isolated-bench evidence only. It uses XIAO self-receive/ring validation because APG passive monitor did not log XIAO-generated active frames during the May 27 validation session.",
        "",
        "## Logs",
        "",
        "- Text log: $textLog"
    )
    $summary | Out-File -FilePath $summaryLog -Encoding utf8

    Write-ProofLog "============================================================"
    if ($passed) {
        Write-ProofLog "RESULT PASS - active bench frames observed in XIAO ring"
        $exitCode = 0
    } else {
        Write-ProofLog "RESULT FAIL - active proof did not meet thresholds"
        Write-ProofLog "armAck=$armAck activeAck=$activeAck stopAck=$stopAck txCount=$txCount ringOkCount=$ringOkCount badStats=$badStats"
        $exitCode = 1
    }
} finally {
    if ($serialPort -and $serialPort.IsOpen) {
        try { Send-XiaoCommand $serialPort "safe:off" 50 } catch {}
    }
    if ($serialPort -and $serialPort.IsOpen) { $serialPort.Close() }
}

Write-Host ""
Write-Host "Active bench proof summary: $summaryLog"
Write-Host "Active bench proof log:     $textLog"
exit $exitCode