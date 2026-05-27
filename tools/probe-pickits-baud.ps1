Add-Type -AssemblyName System.Windows.Forms
$dir = "C:\Users\ezabz\Downloads\LINAnalyzer"
$pks = [System.Reflection.Assembly]::LoadFrom((Join-Path $dir "PICkitS.dll"))
[System.Reflection.Assembly]::LoadFrom((Join-Path $dir "NetworkAnalyser.exe")) | Out-Null

Write-Host "=== PICkitS types ==="
$pks.GetTypes() | Select-Object -ExpandProperty FullName

Write-Host ""
Write-Host "=== PICkitS LIN-related methods (all types) ==="
foreach ($t in $pks.GetTypes()) {
    $methods = $t.GetMethods([System.Reflection.BindingFlags]"Public,NonPublic,Static,Instance") |
        Where-Object { $_.Name -match "LIN|Lin|Baud|baud|Speed|speed|Rate|rate|Master|master" }
    foreach ($m in $methods) {
        $params = ($m.GetParameters() | ForEach-Object { "$($_.ParameterType.Name) $($_.Name)" }) -join ", "
        Write-Host "  $($t.Name).$($m.Name)($params)"
    }
}
