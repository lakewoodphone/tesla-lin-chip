Add-Type -AssemblyName System.Windows.Forms
$dir = "C:\Users\ezabz\Downloads\LINAnalyzer"
[System.Reflection.Assembly]::LoadFrom((Join-Path $dir "PICkitS.dll")) | Out-Null
$asm = [System.Reflection.Assembly]::LoadFrom((Join-Path $dir "NetworkAnalyser.exe"))
$type = $asm.GetType("WindowsApplication1.Network")
$form = $asm.CreateInstance("WindowsApplication1.Network")
$type.GetMethod("Network_Load", [System.Reflection.BindingFlags]"Public,NonPublic,Instance").Invoke($form, @($form, [System.EventArgs]::Empty)) | Out-Null

Write-Host "=== Fields of PICkitS.LIN type on form ==="
$type.GetFields([System.Reflection.BindingFlags]"Public,NonPublic,Instance") |
    Where-Object { $_.FieldType.FullName -like "*LIN*" -or $_.FieldType.Name -eq "LIN" } |
    ForEach-Object {
        Write-Host "$($_.Name) [$($_.FieldType.FullName)]"
    }

Write-Host ""
Write-Host "=== All non-UI fields (possible LIN wrapper) ==="
$type.GetFields([System.Reflection.BindingFlags]"Public,NonPublic,Instance") |
    Where-Object { $_.FieldType.Namespace -like "PICkitS*" } |
    ForEach-Object {
        Write-Host "$($_.Name) [$($_.FieldType.FullName)]"
    }
