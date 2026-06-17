param(
    [string]$EspPort = "COM29"
)

$ErrorActionPreference = "Stop"

function Resolve-CommandPath {
    param(
        [string]$Name,
        [string[]]$FallbackPaths = @()
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    foreach ($candidate in $FallbackPaths) {
        if (Test-Path $candidate) { return $candidate }
    }

    return $null
}

function Test-CommandAvailable {
    param(
        [string]$Name,
        [string[]]$FallbackPaths = @()
    )

    $resolvedPath = Resolve-CommandPath $Name $FallbackPaths
    [pscustomobject]@{
        Check = $Name
        Ready = [bool]$resolvedPath
        Detail = if ($resolvedPath) { $resolvedPath } else { "not on PATH or known install paths" }
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "== Tooling =="
$sigrokFallbacks = @(
    "C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe",
    "C:\Program Files (x86)\sigrok\sigrok-cli\sigrok-cli.exe"
)
$tools = @(
    Test-CommandAvailable "sigrok-cli" $sigrokFallbacks
    Test-CommandAvailable "PulseView"
    Test-CommandAvailable "openocd"
    Test-CommandAvailable "MRS"
    Test-CommandAvailable "pio"
    Test-CommandAvailable "arduino-cli"
)
$tools | Format-Table -AutoSize

Write-Host "`n== Sigrok Devices =="
$sigrokCli = Resolve-CommandPath "sigrok-cli" $sigrokFallbacks
if ($sigrokCli) {
    & $sigrokCli --scan
} else {
    Write-Warning "sigrok-cli not found; skipping analyzer scan."
}

Write-Host "`n== Relevant USB Devices =="
Get-PnpDevice -PresentOnly |
    Where-Object { $_.InstanceId -match "VID_303A|VID_0925|WCH|CH57|CP210|USB-SERIAL|USB Serial" } |
    Select-Object Status, Class, FriendlyName, InstanceId |
    Format-Table -AutoSize

Write-Host "`n== ESP32 Probe =="
if (Test-Path ".venv\Scripts\python.exe") {
    & .\.venv\Scripts\python.exe -m esptool --port $EspPort chip-id
} else {
    Write-Warning "Project venv not found; skipping esptool probe."
}

Write-Host "`nExpected state: fx2lafw analyzer detected, ESP32-C3 reachable, and WCH-LinkE visible before SWD dump work."