Add-Type -AssemblyName System.Windows.Forms
$dir = "C:\Users\ezabz\Downloads\LINAnalyzer"
[System.Reflection.Assembly]::LoadFrom((Join-Path $dir "PICkitS.dll")) | Out-Null
$asm = [System.Reflection.Assembly]::LoadFrom((Join-Path $dir "NetworkAnalyser.exe"))
$type = $asm.GetType("WindowsApplication1.Network")
$form = $asm.CreateInstance("WindowsApplication1.Network")
$type.GetMethod("Network_Load", [System.Reflection.BindingFlags]"Public,NonPublic,Instance").Invoke($form, @($form, [System.EventArgs]::Empty)) | Out-Null

Write-Host "=== Fields matching baud/speed/rate/lin ==="
$type.GetFields([System.Reflection.BindingFlags]"Public,NonPublic,Instance") |
    Where-Object { $_.Name -match "baud|Baud|speed|Speed|rate|Rate|kbps|Combo|combo|Drop|drop" } |
    ForEach-Object {
        $val = try { $_.GetValue($form) } catch { "ERR" }
        Write-Host "$($_.Name) [$($_.FieldType.Name)] = $val"
    }

Write-Host ""
Write-Host "=== All ComboBox fields ==="
$type.GetFields([System.Reflection.BindingFlags]"Public,NonPublic,Instance") |
    Where-Object { $_.FieldType.Name -eq "ComboBox" } |
    ForEach-Object {
        $cb = $_.GetValue($form)
        $items = if ($cb) { ($cb.Items | ForEach-Object { $_.ToString() }) -join ", " } else { "null" }
        $sel = if ($cb) { $cb.SelectedItem } else { "null" }
        Write-Host "$($_.Name): selected='$sel' items=[$items]"
    }
