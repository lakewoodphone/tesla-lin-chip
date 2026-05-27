Add-Type -AssemblyName System.Windows.Forms
$dir = "C:\Users\ezabz\Downloads\LINAnalyzer"
[System.Reflection.Assembly]::LoadFrom((Join-Path $dir "PICkitS.dll")) | Out-Null
$asm = [System.Reflection.Assembly]::LoadFrom((Join-Path $dir "NetworkAnalyser.exe"))
$type = $asm.GetType("WindowsApplication1.Network")
Write-Host "=== Methods matching baud/speed/config/init ==="
$type.GetMethods([System.Reflection.BindingFlags]"Public,NonPublic,Instance") |
    Where-Object { $_.Name -match "Baud|baud|Speed|speed|Config|Init|Setup|LIN|Lin" } |
    Select-Object -ExpandProperty Name
