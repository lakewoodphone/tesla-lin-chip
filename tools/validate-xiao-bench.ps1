<#
.SYNOPSIS
    Bench validation runner for the XIAO LIN receiver.

.DESCRIPTION
    Opens the XIAO serial port, sends a matrix of LIN frames through the APGDT001,
    and checks that the XIAO reports the expected raw ID, actual payload length,
    checksum mode, and protected-ID parity.

    This is a bench-only transmit script. Do not run it while connected to a vehicle bus.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\validate-xiao-bench.ps1 -ComPort COM5 -Baud 19200
#>

param(
    [string] $ComPort = "COM4",
    [UInt16] $Baud = 19200,
    [int] $BootWaitSeconds = 14,
    [int] $PerFrameTimeoutMs = 3500,
    [switch] $KillExistingMonitor
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$netAnalyserSender = Join-Path $repoRoot "tools\send-netanalyser-headless.ps1"
$x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
$logDir = Join-Path $repoRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $logDir "xiao-bench-validation-${stamp}.log"

if ($KillExistingMonitor) {
    Get-Process platformio -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Write-LogLine([string] $message) {
    $message | Tee-Object -FilePath $script:logFile -Append
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
                Write-LogLine "SERIAL $line"
            }
        } catch [System.TimeoutException] {
            # keep collecting until timeout expires
        }
    }
    return $lines
}

function Get-ProtectedLinId([byte] $linId) {
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

function Send-LinFrame($test) {
    $protectedId = Get-ProtectedLinId ([byte]$test.Id)
    $frame = ("{0:X2} {1}" -f $test.Id, $test.Data).Trim()
    $args = @(
        "-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $netAnalyserSender,
        "-Baud", $Baud,
        "-Frame", $frame,
        "-Checksum", $test.Checksum
    )
    Write-LogLine ("SEND   {0}: ID=0x{1:X2} PID=0x{2:X2} frame='{3}' checksum={4}" -f $test.Name, $test.Id, $protectedId, $frame, $test.Checksum)
    $output = & $x86PowerShell @args 2>&1
    foreach ($line in $output) { Write-LogLine "APG    $line" }
}

$tests = @(
    [pscustomobject]@{ Name = "candidate-0c-2b"; Id = 0x0C; Data = "12 34"; Len = 2; Checksum = "Enhanced" },
    [pscustomobject]@{ Name = "body-10-2b";      Id = 0x10; Data = "AA 55"; Len = 2; Checksum = "Enhanced" },
    [pscustomobject]@{ Name = "class-22-4b";     Id = 0x22; Data = "01 02 03 04"; Len = 4; Checksum = "Enhanced" },
    [pscustomobject]@{ Name = "diag-3c-8b-enh";  Id = 0x3C; Data = "00 00 00 00 00 00 00 00"; Len = 8; Checksum = "Enhanced" },
    [pscustomobject]@{ Name = "diag-3c-8b-class";Id = 0x3C; Data = "00 00 00 00 00 00 00 00"; Len = 8; Checksum = "Classic" }
)

Write-LogLine "============================================================"
Write-LogLine "XIAO LIN bench validation"
Write-LogLine "Serial: $ComPort @ 115200   LIN baud: $Baud"
Write-LogLine "Log: $logFile"
Write-LogLine "============================================================"

$port = $null
$failures = 0
try {
    $port = Open-XiaoSerial
    Write-LogLine "Serial opened. Waiting $BootWaitSeconds seconds for boot/WiFi path..."
    [void](Read-SerialLines $port ($BootWaitSeconds * 1000))

    foreach ($test in $tests) {
        Send-LinFrame $test
        $lines = Read-SerialLines $port $PerFrameTimeoutMs
        $joined = ($lines -join "`n")
        $idPattern = "ID=0x{0:X2}" -f $test.Id
        $lenPattern = "\[{0}B" -f $test.Len
        $modePattern = if ($test.Checksum -eq "Classic") { "classic" } else { "enhanced" }

        $passed = $joined -match [regex]::Escape($idPattern) -and
                  $joined -match $lenPattern -and
                  $joined -match $modePattern -and
                  $joined -match "parity=OK"

        if ($passed) {
            Write-LogLine ("PASS   {0}" -f $test.Name)
        } else {
            $failures++
            Write-LogLine ("FAIL   {0} expected {1}, {2}, checksum {3}, parity=OK" -f $test.Name, $idPattern, $lenPattern, $modePattern)
        }
    }
} finally {
    if ($port -and $port.IsOpen) { $port.Close() }
}

Write-LogLine "============================================================"
if ($failures -eq 0) {
    Write-LogLine "RESULT PASS - all bench frames decoded as expected"
    exit 0
}

Write-LogLine "RESULT FAIL - $failures frame validation(s) failed"
exit 1