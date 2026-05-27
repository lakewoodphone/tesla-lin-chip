<#
.SYNOPSIS
    Bridge XIAO USB serial LIN frames into the secretary LIN API.

.DESCRIPTION
    Reads the XIAO firmware's decoded serial lines, writes local evidence logs,
    and POSTs each parsed frame to /api/v1/lin-events. This is the bench-safe
    fallback when XIAO WiFi is unavailable.

    Expected XIAO frame line:
      #12 ID=0x0C PID=0x4C [8B pred=2] data: 10 00 ... | chk=89 enhanced parity=OK src=idle

.EXAMPLE
    .\tools\serial-to-lin-events.ps1 -ComPort COM4 -VehicleId tesla-bench-usb

.EXAMPLE
    .\tools\serial-to-lin-events.ps1 -DurationSeconds 60 -NoPost
#>

param(
    [string] $ComPort = "COM4",
    [string] $VehicleId = "tesla-bench-usb",
    [UInt16] $LinBaud = 19200,
    [string] $ApiBase = "http://localhost:8002",
    [int] $DurationSeconds = 0,
    [string] $LogDir = "",
    [switch] $NoPost,
    [switch] $NoConfigureXiao
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$textLog = Join-Path $LogDir "xiao-serial-bridge-${stamp}.log"
$jsonlLog = Join-Path $LogDir "xiao-serial-bridge-${stamp}.jsonl"
$csvLog = Join-Path $LogDir "xiao-serial-bridge-${stamp}.csv"
$apiRoot = $ApiBase.TrimEnd("/")
$eventUrl = "$apiRoot/api/v1/lin-events"

$frameRegex = [regex]'#(?<frame>\d+)\s+ID=0x(?<id>[0-9A-Fa-f]{2})\s+PID=0x(?<pid>[0-9A-Fa-f]{2})\s+\[(?<len>\d+)B\s+pred=(?<pred>\d+)\]\s+data:\s*(?<data>(?:[0-9A-Fa-f]{2}\s*)*)\|\s+chk=(?<chk>[0-9A-Fa-f]{2})\s+(?<mode>enhanced|classic|bad)\s+parity=(?<parity>OK|BAD)\s+src=(?<src>\w+)'

"timestamp,vehicle,frame_count,id_hex,pid_hex,data_len,expected_len,data_hex,rx_checksum,checksum_mode,pid_valid,posted" |
    Out-File -FilePath $csvLog -Encoding utf8

function Write-BridgeLog([string] $message) {
    $line = "[$(Get-Date -Format 'HH:mm:ss.fff')] $message"
    $line | Tee-Object -FilePath $script:textLog -Append
}

function Convert-DataText([string] $dataText) {
    $trimmed = $dataText.Trim()
    if (-not $trimmed) { return @() }
    return @($trimmed -split '\s+' | ForEach-Object { [Convert]::ToInt32($_, 16) })
}

function Parse-XiaoFrame([string] $line) {
    $m = $script:frameRegex.Match($line)
    if (-not $m.Success) { return $null }

    $idHex = "0x{0}" -f $m.Groups["id"].Value.ToUpperInvariant()
    $pidHex = "0x{0}" -f $m.Groups["pid"].Value.ToUpperInvariant()
    $chkHex = "0x{0}" -f $m.Groups["chk"].Value.ToUpperInvariant()
    $data = Convert-DataText $m.Groups["data"].Value
    $mode = $m.Groups["mode"].Value.ToLowerInvariant()
    $parityOk = $m.Groups["parity"].Value -eq "OK"

    return [ordered]@{
        vehicle = $script:VehicleId
        id = [Convert]::ToInt32($m.Groups["id"].Value, 16)
        id_hex = $idHex
        pid = $pidHex
        data = @($data)
        data_len = [int]$m.Groups["len"].Value
        expected_len = [int]$m.Groups["pred"].Value
        checksum_ok = ($mode -ne "bad")
        checksum_mode = $mode
        pid_valid = $parityOk
        rx_checksum = $chkHex
        frame_count = [int]$m.Groups["frame"].Value
        uptime_ms = 0
        source = "usb_serial_bridge"
        serial_source = $m.Groups["src"].Value
        captured_at = (Get-Date).ToString("o")
    }
}

function Post-LinEvent($event) {
    if ($NoPost) { return "skipped" }
    try {
        $json = $event | ConvertTo-Json -Depth 8 -Compress
        Invoke-RestMethod -Method Post -Uri $script:eventUrl -ContentType "application/json" -Body $json | Out-Null
        return "ok"
    } catch {
        Write-BridgeLog "POST failed: $($_.Exception.Message)"
        return "failed"
    }
}

function Open-XiaoSerial {
    $port = New-Object System.IO.Ports.SerialPort($ComPort, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $port.DtrEnable = $true
    $port.RtsEnable = $false
    $port.NewLine = "`n"
    $port.ReadTimeout = 250
    $port.Open()
    $port.DiscardInBuffer()
    return $port
}

Write-BridgeLog "XIAO USB serial bridge starting port=$ComPort vehicle=$VehicleId api=$eventUrl post=$(-not $NoPost)"
Write-BridgeLog "Logs: $textLog ; $jsonlLog ; $csvLog"

$port = $null
$parsed = 0
$posted = 0
$failed = 0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$stopAtMs = if ($DurationSeconds -gt 0) { $DurationSeconds * 1000 } else { [int64]::MaxValue }

try {
    $port = Open-XiaoSerial

    if (-not $NoConfigureXiao) {
        foreach ($cmd in @("vehicle:$VehicleId", "baud:$LinBaud", "raw:0")) {
            $port.WriteLine($cmd)
            Write-BridgeLog "XIAO< $cmd"
            Start-Sleep -Milliseconds 150
        }
    }

    Write-BridgeLog "Listening. Press Ctrl+C to stop."
    while ($stopwatch.ElapsedMilliseconds -lt $stopAtMs) {
        try {
            $line = $port.ReadLine().Trim()
        } catch [System.TimeoutException] {
            continue
        }

        if (-not $line) { continue }
        Write-BridgeLog "SERIAL $line"

        $event = Parse-XiaoFrame $line
        if (-not $event) { continue }

        $parsed++
        $postStatus = Post-LinEvent $event
        if ($postStatus -eq "ok") { $posted++ }
        if ($postStatus -eq "failed") { $failed++ }

        ($event | ConvertTo-Json -Depth 8 -Compress) | Out-File -FilePath $jsonlLog -Append -Encoding utf8
        $dataHex = (($event.data | ForEach-Object { "{0:X2}" -f $_ }) -join "-")
        "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11}" -f `
            (Get-Date).ToString("o"), $VehicleId, $event.frame_count, $event.id_hex, $event.pid,
            $event.data_len, $event.expected_len, $dataHex, $event.rx_checksum,
            $event.checksum_mode, $event.pid_valid, $postStatus |
            Out-File -FilePath $csvLog -Append -Encoding utf8
    }
} finally {
    if ($port -and $port.IsOpen) { $port.Close() }
    Write-BridgeLog "Bridge complete parsed=$parsed posted=$posted failed=$failed"
    Write-Host ""
    Write-Host "XIAO bridge complete: parsed=$parsed posted=$posted failed=$failed" -ForegroundColor Green
    Write-Host "Log:  $textLog" -ForegroundColor Gray
    Write-Host "JSON: $jsonlLog" -ForegroundColor Gray
    Write-Host "CSV:  $csvLog" -ForegroundColor Gray
}