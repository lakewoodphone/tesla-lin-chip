<#
.SYNOPSIS
    Rev A ESP32-S3 Model 3 active anti-nag build/flash/control helper.

.DESCRIPTION
    Provides one current entry point for the Rev A dual-LIN board. It avoids the
    older XIAO/APG assumptions and uses CP2102 COM6 plus the rev_a_active_ble
    PlatformIO environment.
#>

param(
    [ValidateSet("Build", "Flash", "Command", "Monitor", "BleScan", "Preflight")]
    [string] $Action = "Preflight",
    [string] $ComPort = "COM6",
    [string[]] $Commands = @("version", "config"),
    [switch] $ManualBoot,
    [int] $ReadMilliseconds = 2000,
    [string] $PlatformIo = "",
    [string] $Python = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$envName = "rev_a_active_ble"

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
    throw "PlatformIO not found. Pass -PlatformIo <path>."
}

function Resolve-Python {
    param([string] $RequestedPath)
    $candidates = @(
        $RequestedPath,
        "C:\Users\ezabz\Code\personal-secretary-mvp\.venv\Scripts\python.exe"
    ) | Where-Object { $_ }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "Python not found. Pass -Python <path>."
}

function Write-Preflight {
    Write-Host "Rev A Model 3 active anti-nag preflight" -ForegroundColor Cyan
    Write-Host "  Repo:     $repoRoot"
    Write-Host "  Env:      $envName"
    Write-Host "  COM port: $ComPort"
    Write-Host ""
    Write-Host "Before flashing: hold BOOT/TP9 low, tap EN/TP8 low, release BOOT/TP9." -ForegroundColor Yellow
    Write-Host "Before vehicle work: verify serial, BLE, safe:off, rails, LIN isolation, and physical arm behavior." -ForegroundColor Yellow
}

function Invoke-Build {
    $pio = Resolve-PlatformIo $PlatformIo
    Push-Location $repoRoot
    try {
        & $pio run -e $envName
        if ($LASTEXITCODE -ne 0) { throw "PlatformIO build failed for $envName" }
    } finally {
        Pop-Location
    }
}

function Invoke-Flash {
    $pythonExe = Resolve-Python $Python
    if ($ManualBoot) {
        Write-Host "Manual bootloader required now:" -ForegroundColor Yellow
        Write-Host "  Hold BOOT/TP9 low, tap EN/TP8 low, release BOOT/TP9."
    }
    $buildDir = Join-Path $repoRoot ".pio\build\$envName"
    $args = @(
        "-m", "esptool",
        "--chip", "esp32s3",
        "--port", $ComPort,
        "--baud", "460800",
        "--before", "default-reset",
        "--after", "hard-reset",
        "write-flash",
        "0x0", (Join-Path $buildDir "bootloader.bin"),
        "0x8000", (Join-Path $buildDir "partitions.bin"),
        "0x10000", (Join-Path $buildDir "firmware.bin")
    )
    & $pythonExe @args
    if ($LASTEXITCODE -ne 0) { throw "esptool flash failed" }
}

function Invoke-SerialCommands {
    Add-Type -AssemblyName System.IO.Ports
    $port = [System.IO.Ports.SerialPort]::new($ComPort, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $port.NewLine = "`n"
    $port.ReadTimeout = 100
    $port.WriteTimeout = 500
    try {
        $port.Open()
        Start-Sleep -Milliseconds 300
        foreach ($cmd in $Commands) {
            Write-Host "TX> $cmd" -ForegroundColor DarkCyan
            $port.WriteLine($cmd)
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while ($sw.ElapsedMilliseconds -lt $ReadMilliseconds) {
                try {
                    $line = $port.ReadLine().Trim()
                    if ($line) { Write-Host "RX> $line" }
                } catch [TimeoutException] {
                }
            }
        }
    } finally {
        if ($port.IsOpen) { $port.Close() }
    }
}

function Invoke-Monitor {
    $pio = Resolve-PlatformIo $PlatformIo
    & $pio device monitor --port $ComPort --baud 115200 --dtr 0 --rts 0
}

function Invoke-BleScan {
    $pythonExe = Resolve-Python $Python
    $script = @'
import asyncio
from bleak import BleakScanner

async def main():
    print("Scanning for TeslaPassthrough for 10 seconds...")
    devices = await BleakScanner.discover(timeout=10.0)
    found = [d for d in devices if d.name == "TeslaPassthrough"]
    if found:
        for device in found:
            print(f"FOUND TeslaPassthrough address={device.address} rssi={device.rssi}")
    else:
        named = [d.name for d in devices if d.name]
        print(f"TeslaPassthrough not found. Scanned {len(devices)} devices; named={named[:10]}")

asyncio.run(main())
'@
    $temp = New-TemporaryFile
    try {
        Set-Content -Path $temp -Value $script -Encoding ascii
        & $pythonExe $temp
    } finally {
        Remove-Item $temp -Force -ErrorAction SilentlyContinue
    }
}

switch ($Action) {
    "Preflight" { Write-Preflight }
    "Build" { Invoke-Build }
    "Flash" { Invoke-Flash }
    "Command" { Invoke-SerialCommands }
    "Monitor" { Invoke-Monitor }
    "BleScan" { Invoke-BleScan }
}