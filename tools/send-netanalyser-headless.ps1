param(
    [string]$Frame = "3C 00 00 00 00 00 00 00 00",
    [ValidateSet("Enhanced", "Classic", "Forced")]
    [string]$Checksum = "Enhanced",
    [UInt16]$Baud = 19200
)

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    throw "Run this with 32-bit PowerShell."
}

Add-Type -AssemblyName System.Windows.Forms
$dir = "C:\Users\ezabz\Downloads\LINAnalyzer"
[System.Reflection.Assembly]::LoadFrom((Join-Path $dir "PICkitS.dll")) | Out-Null
$asm = [System.Reflection.Assembly]::LoadFrom((Join-Path $dir "NetworkAnalyser.exe"))
$type = $asm.GetType("WindowsApplication1.Network")
$form = $asm.CreateInstance("WindowsApplication1.Network")

function Invoke-Private($name, [object[]]$invokeArgs) {
    $method = $type.GetMethod($name, [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    if (-not $method) { throw "Method not found: $name" }
    return $method.Invoke($form, $invokeArgs)
}

function Get-FormProperty($name) {
    $property = $type.GetProperty($name, [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    if (-not $property) { throw "Property not found: $name" }
    return $property.GetValue($form, $null)
}

Invoke-Private "Network_Load" @($form, [System.EventArgs]::Empty) | Out-Null

$messageList = Get-FormProperty "MessageLstBox"
$messageList.Items.Clear()
$messageList.Items.Add($Frame) | Out-Null
$messageList.SelectedIndex = 0

$sendOnceField = $type.GetField("SendOnce", [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
$sendOnceField.SetValue($form, $true)

# Set baud rate (default loads as 9600 after Network_Load)
$baudField = $type.GetField("MasterBaudRate", [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
$baudField.SetValue($form, [uint16]$Baud)

# Also configure the PICkitS LIN hardware baud rate via the LIN instance.
# Must be called AFTER Network_Load. Call twice — first call reconfigures the
# hardware control block, second ensures the register write completes.
$linField = $type.GetField("_OnAnswerSource", [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
$linObj = $linField.GetValue($form)
if ($linObj) {
    $changeBaudMethod = $linObj.GetType().GetMethod("Change_LIN_BAUD_Rate")
    $changeBaudMethod.Invoke($linObj, @([uint16]$Baud)) | Out-Null
    Start-Sleep -Milliseconds 50
    $changeBaudMethod.Invoke($linObj, @([uint16]$Baud)) | Out-Null
    Write-Host "Hardware baud rate set to: $Baud"
} else {
    Write-Host "WARNING: LIN hardware instance not found"
}
Write-Host "MasterBaudRate field: $($baudField.GetValue($form))"

(Get-FormProperty "classicRadioButton").Checked = ($Checksum -eq "Classic")
(Get-FormProperty "enhancedRadioButton").Checked = ($Checksum -eq "Enhanced")
(Get-FormProperty "forcedRadioButton").Checked = ($Checksum -eq "Forced")

Write-Host "Headless NetworkAnalyser sending: $Frame checksum=$Checksum"
Invoke-Private "Sendbtn_Click" @($form, [System.EventArgs]::Empty) | Out-Null
Start-Sleep -Milliseconds 500
Write-Host "Status: $((Get-FormProperty "StatusError").Text)"