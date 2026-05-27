param()

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    $x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    & $x86PowerShell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

$analyzerDir = "C:\Users\ezabz\Downloads\LINAnalyzer"
$dllPath = Join-Path $analyzerDir "PICkitS.dll"
[System.Reflection.Assembly]::LoadFrom($dllPath) | Out-Null

foreach ($typeName in @("PICkitS.Device", "PICkitS.LIN")) {
    $type = [type]$typeName
    Write-Host "TYPE $typeName"
    foreach ($method in $type.GetMethods([System.Reflection.BindingFlags]"Public,Static,Instance,DeclaredOnly") | Sort-Object Name) {
        if ($method.Name -match "Initialize|Find|Configure|BAUD|Options|Mode|Transmit|Attached") {
            Write-Host "  METHOD $($method.Name) -> $($method.ReturnType.FullName)"
            foreach ($parameter in $method.GetParameters()) {
                Write-Host "    PARAM $($parameter.Position) $($parameter.ParameterType.FullName) $($parameter.Name) byref=$($parameter.ParameterType.IsByRef)"
            }
        }
    }
}