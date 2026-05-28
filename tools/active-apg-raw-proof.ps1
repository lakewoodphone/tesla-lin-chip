param(
    [string] $ComPort = "COM4",
    [UInt16] $Baud = 19200,
    [int] $DurationSeconds = 6,
    [int] $MinFrames = 8,
    [Byte] $RawFallbackId = 0x0C,
    [string] $LogDir = "",
    [switch] $ConfirmBenchIsolation
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$monitorScript = Join-Path $repoRoot "tools\monitor-apg-lin-bus.ps1"
$x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }

function Open-XiaoSerial([string]$PortName) {
    $port = New-Object System.IO.Ports.SerialPort $PortName, 115200, ([System.IO.Ports.Parity]::None), 8, ([System.IO.Ports.StopBits]::One)
    $port.DtrEnable = $false
    $port.RtsEnable = $false
    $port.ReadTimeout = 150
    $port.Open()
    Start-Sleep -Milliseconds 400
    return $port
}

function Send-XiaoCommand([System.IO.Ports.SerialPort]$Port, [string]$Command) {
    $Port.WriteLine($Command)
    Start-Sleep -Milliseconds 120
}

function Read-XiaoLines([System.IO.Ports.SerialPort]$Port, [int]$Milliseconds) {
    $lines = @()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $Milliseconds) {
        try {
            $line = $Port.ReadLine().Trim()
            if ($line) { $lines += $line }
        } catch [System.TimeoutException] {
        }
    }
    return $lines
}

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$before = Get-Date
$xiaoLines = @()

Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "  Active APG Raw Proof - Model X known-ID capture" -ForegroundColor Yellow
Write-Host "  COM: $ComPort   Baud: $Baud   Raw ID: 0x$($RawFallbackId.ToString('X2'))" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow

if (-not $ConfirmBenchIsolation) {
    $confirmation = Read-Host "Type BENCH to confirm this active raw proof is on an isolated bench, not a vehicle bus"
    if ($confirmation -ne "BENCH") { throw "Active APG raw proof aborted: bench isolation was not confirmed" }
}

$serial = Open-XiaoSerial $ComPort
try {
    Send-XiaoCommand $serial "antinag:stop"
    Send-XiaoCommand $serial "txd:uart"
    Send-XiaoCommand $serial "safe:arm"
    Send-XiaoCommand $serial "model:x"
    Send-XiaoCommand $serial "antinag:start"
    $xiaoLines += Read-XiaoLines $serial 1000

    & $x86PowerShell -STA -NoProfile -ExecutionPolicy Bypass -File $monitorScript `
        -Baud $Baud -DurationSeconds $DurationSeconds -Mode DisplayAll `
        -RawFallback -RawFallbackId $RawFallbackId -LogDir $LogDir
    $monitorExit = $LASTEXITCODE

    Send-XiaoCommand $serial "antinag:stop"
    Send-XiaoCommand $serial "safe:off"
    $xiaoLines += Read-XiaoLines $serial 800
} finally {
    if ($serial -and $serial.IsOpen) {
        try { $serial.WriteLine("antinag:stop") } catch {}
        try { $serial.WriteLine("safe:off") } catch {}
        $serial.Close()
    }
}

if ($monitorExit -ne 0) { throw "monitor-apg-lin-bus.ps1 exited with code $monitorExit" }

$latestCsv = Get-ChildItem $LogDir -Filter "lin-capture-*.csv" |
    Where-Object { $_.LastWriteTime -ge $before.AddSeconds(-2) } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $latestCsv) { throw "No new lin-capture CSV was written under $LogDir" }

$rows = @(Import-Csv $latestCsv.FullName)
$rawRows = @($rows | Where-Object { $_.source -eq "raw" -and $_.id_hex -eq ("0x{0:X2}" -f $RawFallbackId) })
$txLines = @($xiaoLines | Where-Object { $_ -match '^TX #' })

Write-Host ""
Write-Host "Proof summary:" -ForegroundColor Yellow
Write-Host "  CSV: $($latestCsv.FullName)"
Write-Host "  XIAO TX lines observed: $($txLines.Count)"
Write-Host "  APG raw rows observed: $($rawRows.Count)"

if ($rawRows.Count -lt $MinFrames) {
    Write-Host ""
    Write-Host "XIAO serial tail:" -ForegroundColor Yellow
    $xiaoLines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    throw "APG raw proof failed: expected at least $MinFrames raw rows, got $($rawRows.Count)"
}

Write-Host "PASS: APG raw fallback captured $($rawRows.Count) checksum-valid known-ID frames." -ForegroundColor Green