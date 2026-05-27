<#
.SYNOPSIS
    Run a no-car LIN bench evidence suite using APG transmit + XIAO receive.

.DESCRIPTION
    Sends a structured frame matrix through the isolated bench only, listens to
    the XIAO USB serial decoder, compares expected vs observed frames, posts
    observed frames to the secretary LIN API unless disabled, and writes CSV,
    JSON, raw serial, APG, and Markdown report artifacts.

    This script transmits LIN frames. Never run it while connected to a vehicle.

.EXAMPLE
    .\tools\bench-evidence-suite.ps1 -VehicleId tesla-bench-suite

.EXAMPLE
    .\tools\bench-evidence-suite.ps1 -Quick -NoPost
#>

param(
    [string] $ComPort = "COM4",
    [UInt16] $Baud = 19200,
    [string] $VehicleId = "tesla-bench-suite",
    [string] $ApiBase = "http://localhost:8002",
    [string] $LogDir = "",
    [int] $BootWaitSeconds = 5,
    [int] $PerFrameTimeoutMs = 2200,
    [int] $DelayMs = 150,
    [int] $IdStart = 0x00,
    [int] $IdEnd = 0x3F,
    [switch] $Quick,
    [switch] $NoPost,
    [switch] $NoConfigureXiao
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$suiteDir = Join-Path $LogDir "bench-evidence-${stamp}"
New-Item -ItemType Directory -Path $suiteDir | Out-Null

$csvPath = Join-Path $suiteDir "bench-evidence-${stamp}.csv"
$jsonPath = Join-Path $suiteDir "bench-evidence-${stamp}.json"
$reportPath = Join-Path $suiteDir "bench-evidence-${stamp}.md"
$serialLog = Join-Path $suiteDir "xiao-serial-${stamp}.log"
$apgLog = Join-Path $suiteDir "apg-send-${stamp}.log"

$sender = Join-Path $repoRoot "tools\send-netanalyser-headless.ps1"
$x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
$apiRoot = $ApiBase.TrimEnd("/")
$eventUrl = "$apiRoot/api/v1/lin-events"

$frameRegex = [regex]'#(?<frame>\d+)\s+ID=0x(?<id>[0-9A-Fa-f]{2})\s+PID=0x(?<pid>[0-9A-Fa-f]{2})\s+\[(?<len>\d+)B\s+pred=(?<pred>\d+)\]\s+data:\s*(?<data>(?:[0-9A-Fa-f]{2}\s*)*)\|\s+chk=(?<chk>[0-9A-Fa-f]{2})\s+(?<mode>enhanced|classic|bad)\s+parity=(?<parity>OK|BAD)\s+src=(?<src>\w+)'
$results = New-Object System.Collections.Generic.List[object]

function Write-SerialLog([string] $message) {
    $message | Out-File -FilePath $script:serialLog -Append -Encoding utf8
}

function Write-ApgLog([string] $message) {
    $line = "[$(Get-Date -Format 'HH:mm:ss.fff')] $message"
    $line | Out-File -FilePath $script:apgLog -Append -Encoding utf8
}

function Get-ProtectedLinId([int] $linId) {
    $id = $linId -band 0x3F
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

function Get-StandardPayload([int] $linId) {
    $class = (($linId -band 0x3F) -shr 4) -band 0x03
    if ($class -le 1) { return @((0xA0 -bor ($linId -band 0x0F)), ($linId -band 0x3F)) }
    if ($class -eq 2) { return @(0x01, 0x02, ($linId -band 0x3F), 0x55) }
    return @(0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, ($linId -band 0x0F))
}

function Format-DataHex([int[]] $data) {
    return (($data | ForEach-Object { "{0:X2}" -f $_ }) -join " ")
}

function Open-XiaoSerial {
    $port = New-Object System.IO.Ports.SerialPort($ComPort, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $port.DtrEnable = $true
    $port.RtsEnable = $false
    $port.NewLine = "`n"
    $port.ReadTimeout = 100
    $port.Open()
    $port.DiscardInBuffer()
    return $port
}

function Read-SerialLines($port, [int] $timeoutMs) {
    $lines = New-Object System.Collections.Generic.List[string]
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $timeoutMs) {
        try {
            $line = $port.ReadLine().Trim()
            if ($line) {
                $lines.Add($line)
                Write-SerialLog $line
            }
        } catch [System.TimeoutException] {
        }
    }
    return $lines
}

function Convert-DataText([string] $dataText) {
    $trimmed = $dataText.Trim()
    if (-not $trimmed) { return @() }
    return @($trimmed -split '\s+' | ForEach-Object { [Convert]::ToInt32($_, 16) })
}

function Parse-XiaoFrame([string] $line) {
    $m = $script:frameRegex.Match($line)
    if (-not $m.Success) { return $null }
    $data = Convert-DataText $m.Groups["data"].Value
    $mode = $m.Groups["mode"].Value.ToLowerInvariant()
    return [pscustomobject]@{
        frame_count = [int]$m.Groups["frame"].Value
        id = [Convert]::ToInt32($m.Groups["id"].Value, 16)
        id_hex = "0x{0}" -f $m.Groups["id"].Value.ToUpperInvariant()
        pid = "0x{0}" -f $m.Groups["pid"].Value.ToUpperInvariant()
        data = @($data)
        data_hex = Format-DataHex $data
        data_len = [int]$m.Groups["len"].Value
        expected_len = [int]$m.Groups["pred"].Value
        checksum_ok = ($mode -ne "bad")
        checksum_mode = $mode
        pid_valid = ($m.Groups["parity"].Value -eq "OK")
        rx_checksum = "0x{0}" -f $m.Groups["chk"].Value.ToUpperInvariant()
        serial_source = $m.Groups["src"].Value
    }
}

function Convert-ToApiEvent($frame) {
    return [ordered]@{
        vehicle = $script:VehicleId
        id = $frame.id
        id_hex = $frame.id_hex
        pid = $frame.pid
        data = @($frame.data)
        data_len = $frame.data_len
        expected_len = $frame.expected_len
        checksum_ok = $frame.checksum_ok
        checksum_mode = $frame.checksum_mode
        pid_valid = $frame.pid_valid
        rx_checksum = $frame.rx_checksum
        frame_count = $frame.frame_count
        uptime_ms = 0
        source = "bench_evidence_suite"
    }
}

function Post-LinEvent($frame) {
    if ($NoPost -or -not $frame) { return "skipped" }
    try {
        $body = (Convert-ToApiEvent $frame) | ConvertTo-Json -Depth 8 -Compress
        Invoke-RestMethod -Method Post -Uri $script:eventUrl -ContentType "application/json" -Body $body | Out-Null
        return "ok"
    } catch {
        return "failed: $($_.Exception.Message)"
    }
}

function Invoke-ApgSend([string] $frameArg, [string] $checksum) {
    $args = @(
        "-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $sender,
        "-Baud", $Baud,
        "-Frame", $frameArg,
        "-Checksum", $checksum
    )
    Write-ApgLog "SEND frame='$frameArg' checksum=$checksum baud=$Baud"
    $output = & $x86PowerShell @args 2>&1
    $exitCode = $LASTEXITCODE
    foreach ($line in $output) { Write-ApgLog "APG $line" }
    $statusLine = ($output | Where-Object { $_ -match '^Status:' } | Select-Object -Last 1)
    $status = if ($statusLine) { ($statusLine -replace '^Status:\s*', '') } else { "exit=$exitCode no status" }
    return [pscustomobject]@{ exit_code = $exitCode; status = $status; output = ($output -join " | ") }
}

function Run-Case {
    param(
        [string] $Name,
        [string] $Phase,
        [int] $Id,
        [int[]] $Data,
        [ValidateSet("Enhanced", "Classic", "Forced")]
        [string] $Checksum = "Enhanced"
    )

    $idHex = "0x{0:X2}" -f ($Id -band 0x3F)
    $pidHex = "0x{0:X2}" -f (Get-ProtectedLinId $Id)
    $dataHex = Format-DataHex $Data
    $frameArg = "{0:X2} {1}" -f ($Id -band 0x3F), $dataHex
    Write-Host ("{0,-24} {1} {2}" -f $Name, $idHex, $dataHex) -ForegroundColor Cyan

    $apg = Invoke-ApgSend -frameArg $frameArg -checksum $Checksum
    $lines = Read-SerialLines $script:port $PerFrameTimeoutMs
    $parsed = @($lines | ForEach-Object { Parse-XiaoFrame $_ } | Where-Object { $_ })
    $observed = $parsed | Where-Object { $_.id -eq ($Id -band 0x3F) -and $_.data_hex -eq $dataHex } | Select-Object -First 1
    if (-not $observed -and $parsed.Count -gt 0) { $observed = $parsed[-1] }
    $matched = $false
    if ($observed) {
        $matched = ($observed.id -eq ($Id -band 0x3F) -and $observed.data_hex -eq $dataHex -and $observed.pid_valid -and $observed.checksum_ok)
    }
    $postStatus = Post-LinEvent $observed

    $result = [pscustomobject]@{
        name = $Name
        phase = $Phase
        tx_id_hex = $idHex
        tx_pid_hex = $pidHex
        tx_data_hex = $dataHex
        checksum = $Checksum
        apg_exit = $apg.exit_code
        apg_status = $apg.status
        observed = [bool]$observed
        matched = [bool]$matched
        observed_id_hex = if ($observed) { $observed.id_hex } else { "" }
        observed_pid_hex = if ($observed) { $observed.pid } else { "" }
        observed_data_hex = if ($observed) { $observed.data_hex } else { "" }
        observed_data_len = if ($observed) { $observed.data_len } else { 0 }
        observed_checksum_mode = if ($observed) { $observed.checksum_mode } else { "" }
        observed_pid_valid = if ($observed) { $observed.pid_valid } else { $false }
        observed_rx_checksum = if ($observed) { $observed.rx_checksum } else { "" }
        posted = $postStatus
        serial_lines = $lines.Count
    }
    $script:results.Add($result) | Out-Null

    if ($matched) {
        Write-Host "  PASS observed and matched" -ForegroundColor Green
    } else {
        Write-Host "  WARN no exact match (apg=$($apg.status), observed=$([bool]$observed))" -ForegroundColor Yellow
    }

    Start-Sleep -Milliseconds $DelayMs
}

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "  XIAO/APG No-Car Bench Evidence Suite" -ForegroundColor Yellow
Write-Host "  Vehicle=$VehicleId Port=$ComPort LIN=$Baud API=$eventUrl" -ForegroundColor Yellow
Write-Host "  Output=$suiteDir" -ForegroundColor Yellow
Write-Host "  BENCH ONLY - do not run on a vehicle bus" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

$port = $null
try {
    $script:port = Open-XiaoSerial
    Write-Host "Serial opened. Waiting $BootWaitSeconds seconds for boot/settle..." -ForegroundColor Gray
    [void](Read-SerialLines $script:port ($BootWaitSeconds * 1000))

    if (-not $NoConfigureXiao) {
        foreach ($cmd in @("vehicle:$VehicleId", "baud:$Baud", "raw:0")) {
            $script:port.WriteLine($cmd)
            Write-SerialLog "XIAO< $cmd"
            Start-Sleep -Milliseconds 150
        }
        [void](Read-SerialLines $script:port 500)
    }

    Run-Case -Name "model-x-idle-0c" -Phase "baseline" -Id 0x0C -Data @(0x10,0x00,0x00,0x00,0x00,0x00,0xC0,0x00)
    Run-Case -Name "model-x-up-0c" -Phase "baseline" -Id 0x0C -Data @(0x11,0x04,0x00,0x00,0x00,0x00,0xC0,0x01)
    Run-Case -Name "model-x-down-0c" -Phase "baseline" -Id 0x0C -Data @(0x0F,0x04,0x00,0x00,0x00,0x00,0xC0,0x02)
    Run-Case -Name "model-3y-candidate-1a" -Phase "candidate" -Id 0x1A -Data @(0x10,0x00,0x00,0x00,0x00,0x00,0xC0,0x00)
    Run-Case -Name "model-3y-candidate-1b" -Phase "candidate" -Id 0x1B -Data @(0x10,0x00,0x00,0x00,0x00,0x00,0xC0,0x01)
    Run-Case -Name "diag-3c-enhanced" -Phase "checksum" -Id 0x3C -Data @(0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00) -Checksum "Enhanced"
    Run-Case -Name "diag-3c-classic" -Phase "checksum" -Id 0x3C -Data @(0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00) -Checksum "Classic"

    $sweepIds = if ($Quick) {
        @(0x00,0x01,0x0C,0x0D,0x0E,0x0F,0x10,0x16,0x17,0x1A,0x1B,0x22,0x2A,0x30,0x3C,0x3D)
    } else {
        $IdStart..$IdEnd
    }
    foreach ($id in $sweepIds) {
        Run-Case -Name ("sweep-{0:X2}" -f $id) -Phase "id-sweep" -Id $id -Data (Get-StandardPayload $id)
    }

    for ($i = 0; $i -lt 8; $i++) {
        $dir = if (($i % 2) -eq 0) { "up" } else { "down" }
        $b0 = if ($dir -eq "up") { 0x11 } else { 0x0F }
        Run-Case -Name ("antinag-{0}-{1}" -f $dir, $i) -Phase "antinag" -Id 0x0C -Data @($b0,0x04,0x00,0x00,0x00,0x00,0xC0,($i -band 0x0F))
    }
    Run-Case -Name "antinag-neutral-end" -Phase "antinag" -Id 0x0C -Data @(0x10,0x00,0x00,0x00,0x00,0x00,0xC0,0x08)
} finally {
    if ($script:port -and $script:port.IsOpen) { $script:port.Close() }
}

$results | Export-Csv -NoTypeInformation -Path $csvPath
$results | ConvertTo-Json -Depth 8 | Out-File -FilePath $jsonPath -Encoding utf8

$total = $results.Count
$matchedCount = @($results | Where-Object { $_.matched }).Count
$observedCount = @($results | Where-Object { $_.observed }).Count
$apgFailCount = @($results | Where-Object { $_.apg_exit -ne 0 -or $_.apg_status -notmatch 'Transmission successful' }).Count
$postOkCount = @($results | Where-Object { $_.posted -eq 'ok' }).Count

$report = @()
$report += "# XIAO/APG No-Car Bench Evidence"
$report += ""
$report += "- Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "- Vehicle label: $VehicleId"
$report += "- XIAO port: $ComPort"
$report += "- LIN baud: $Baud"
$report += "- API: $eventUrl"
$report += "- Posted frames: $postOkCount"
$report += "- Cases: $total"
$report += "- Observed by XIAO: $observedCount"
$report += "- Exact matches: $matchedCount"
$report += "- APG send failures: $apgFailCount"
$report += ""
$report += "## Result By Phase"
$report += ""
$report += "| Phase | Cases | Observed | Exact Match |"
$report += "|---|---:|---:|---:|"
foreach ($phaseGroup in ($results | Group-Object phase | Sort-Object Name)) {
    $cases = $phaseGroup.Count
    $obs = @($phaseGroup.Group | Where-Object { $_.observed }).Count
    $match = @($phaseGroup.Group | Where-Object { $_.matched }).Count
    $report += "| $($phaseGroup.Name) | $cases | $obs | $match |"
}
$report += ""
$report += "## Files"
$report += ""
$report += "- Results CSV: $csvPath"
$report += "- Results JSON: $jsonPath"
$report += "- Raw serial log: $serialLog"
$report += "- APG log: $apgLog"
$report += ""
$report += "## Non-Matching Cases"
$report += ""
$nonMatches = @($results | Where-Object { -not $_.matched })
if ($nonMatches.Count -eq 0) {
    $report += "All observed frames matched the transmitted ID and payload."
} else {
    $report += "| Case | TX | Observed | APG Status |"
    $report += "|---|---|---|---|"
    foreach ($row in $nonMatches) {
        $report += "| $($row.name) | $($row.tx_id_hex) $($row.tx_data_hex) | $($row.observed_id_hex) $($row.observed_data_hex) | $($row.apg_status) |"
    }
}
$report | Out-File -FilePath $reportPath -Encoding utf8

Write-Host ""
Write-Host "Bench evidence complete: $matchedCount/$total exact matches, observed=$observedCount, apgFailures=$apgFailCount" -ForegroundColor Green
Write-Host "Report: $reportPath" -ForegroundColor Cyan
Write-Host "CSV:    $csvPath" -ForegroundColor Gray
Write-Host "JSON:   $jsonPath" -ForegroundColor Gray