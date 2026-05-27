param(
    [UInt16]$Baud = 19200,
    [Byte]$Id = 0x3C,
    [string]$Data = "00 00 00 00 00 00 00 00",
    [ValidateSet("Enhanced", "Classic", "Forced")]
    [string]$Checksum = "Enhanced",
    [int]$Repeat = 1,
    [int]$DelayMs = 200,
    [switch]$ChipSelectHi,
    [bool]$ReceiveEnable = $true,
    [bool]$Autobaud = $false,
    [switch]$NoTransmitMode
)

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    throw "Run this with 32-bit PowerShell: $env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -File $PSCommandPath"
}

$analyzerDir = "C:\Users\ezabz\Downloads\LINAnalyzer"
$dllPath = Join-Path $analyzerDir "PICkitS.dll"
[System.Reflection.Assembly]::LoadFrom($dllPath) | Out-Null

$dataBytes = @()
foreach ($part in ($Data -split "[ ,]+" | Where-Object { $_ })) {
    $dataBytes += [Convert]::ToByte($part, 16)
}

if ($dataBytes.Count -gt 63) {
    throw "Too many data bytes: $($dataBytes.Count)"
}

function Get-ProtectedLinId([byte]$linId) {
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

function Add-LinByteSum([int]$sum, [byte]$value) {
    $sum += $value
    while ($sum -ge 256) { $sum -= 255 }
    return $sum
}

$protectedId = Get-ProtectedLinId $Id
$sum = 0
if ($Checksum -eq "Enhanced") {
    $sum = Add-LinByteSum $sum $protectedId
}
foreach ($byte in $dataBytes) {
    $sum = Add-LinByteSum $sum ([byte]$byte)
}

if ($Checksum -eq "Forced") {
    $checksumByte = [byte]$sum
} else {
    $checksumByte = [byte](255 - $sum)
}

$frameBytes = @($dataBytes + $checksumByte)

$buffer = New-Object byte[] 64
for ($i = 0; $i -lt $frameBytes.Count; $i++) {
    $buffer[$i] = [byte]$frameBytes[$i]
}

Write-Host ("LIN id=0x{0:X2} protected=0x{1:X2} checksum={2} byte=0x{3:X2} count={4}" -f $Id, $protectedId, $Checksum, $checksumByte, $frameBytes.Count)

Write-Host "PICkit Serial count: $([PICkitS.Device]::How_Many_PICkitSerials_Are_Attached())"
Write-Host "APG PID 0x0A04 count: $([PICkitS.Device]::How_Many_Of_MyDevices_Are_Attached(0x0A04))"
Write-Host "Find_ThisDevice(04D8,0A04): $([PICkitS.Device]::Find_ThisDevice(0x04D8, 0x0A04))"

$ok = [PICkitS.Device]::Initialize_PICkitSerial()
Write-Host "Initialize_PICkitSerial: $ok"
if (-not $ok) {
    $ok = [PICkitS.Device]::Initialize_MyDevice(0, 0x0A04)
    Write-Host "Initialize_MyDevice(0,0x0A04): $ok"
}
if (-not $ok) { exit 2 }

$chipSelectHiValue = [bool]$ChipSelectHi.IsPresent
$configured = [PICkitS.LIN]::Configure_PICkitSerial_For_LIN($chipSelectHiValue, $ReceiveEnable, $Autobaud)
Write-Host "Configure_PICkitSerial_For_LIN($chipSelectHiValue,$ReceiveEnable,$Autobaud): $configured"
if (-not $configured) {
    $configured = [PICkitS.LIN]::Configure_PICkitSerial_For_LIN()
    Write-Host "Configure_PICkitSerial_For_LIN(): $configured"
}
if (-not $configured) {
    $configured = [PICkitS.LIN]::Configure_PICkitSerial_For_LIN_No_Autobaud()
    Write-Host "Configure_PICkitSerial_For_LIN_No_Autobaud(): $configured"
}
if (-not $configured) {
    $configured = [PICkitS.Basic]::Configure_PICkitSerial_For_LIN()
    Write-Host "Basic.Configure_PICkitSerial_For_LIN(): $configured"
}
if (-not $configured) {
    Write-Host "WARNING: configure returned false; continuing in case device is already in LIN mode."
}

$flushOk = [PICkitS.Device]::Set_Buffer_Flush_Parameters($true, $true, [byte]10, [double]10)
Write-Host "Set_Buffer_Flush_Parameters(true,true,10,10): $flushOk"

$displayAllOk = [PICkitS.LIN]::SetModeDisplayAll()
Write-Host "SetModeDisplayAll: $displayAllOk"

$optionsOk = [PICkitS.LIN]::Set_LIN_Options($chipSelectHiValue, $ReceiveEnable, $Autobaud)
Write-Host "Set_LIN_Options($chipSelectHiValue,$ReceiveEnable,$Autobaud): $optionsOk"

$ok = [PICkitS.LIN]::Change_LIN_BAUD_Rate($Baud)
Write-Host "Change_LIN_BAUD_Rate($Baud): $ok"
Write-Host "Get_LIN_BAUD_Rate: $([PICkitS.LIN]::Get_LIN_BAUD_Rate())"

if ($NoTransmitMode.IsPresent) {
    Write-Host "SetModeTransmit: skipped"
} else {
    $ok = [PICkitS.LIN]::SetModeTransmit()
    Write-Host "SetModeTransmit: $ok"
    if (-not $ok) { exit 4 }
}

for ($n = 1; $n -le $Repeat; $n++) {
    $errorString = ""
    $ok = [PICkitS.LIN]::Transmit($protectedId, $buffer, [byte]$frameBytes.Count, [ref]$errorString)
    Write-Host ("Transmit #{0}: ok={1} pid=0x{2:X2} count={3} err='{4}'" -f $n, $ok, $protectedId, $frameBytes.Count, $errorString)
    if ($DelayMs -gt 0 -and $n -lt $Repeat) {
        Start-Sleep -Milliseconds $DelayMs
    }
}