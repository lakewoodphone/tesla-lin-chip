param(
    [switch]$InitializeNetworkAnalyser
)

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    $x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    $args32 = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
    if ($InitializeNetworkAnalyser.IsPresent) { $args32 += "-InitializeNetworkAnalyser" }
    & $x86PowerShell @args32
    exit $LASTEXITCODE
}

$analyzerDir = "C:\Users\ezabz\Downloads\LINAnalyzer"
$picKitPath = Join-Path $analyzerDir "PICkitS.dll"
$networkPath = Join-Path $analyzerDir "NetworkAnalyser.exe"

[System.Reflection.Assembly]::LoadFrom($picKitPath) | Out-Null
Add-Type -AssemblyName System.Windows.Forms
$networkAsm = [System.Reflection.Assembly]::LoadFrom($networkPath)

$allFlags = [System.Reflection.BindingFlags]"Public,NonPublic,Static,Instance,DeclaredOnly"
$networkFlags = [System.Reflection.BindingFlags]"Public,NonPublic,Static,Instance"
$pattern = "Receive|Answer|Listen|Display|Mode|LIN|Timer|Tick|Message|Data|Packet|Buffer|Flush|Port|Capture|Bus|Status|Error|Source|Baud|Option|Read|Write"

function Format-MethodSignature([System.Reflection.MethodBase]$Method) {
    $params = @($Method.GetParameters() | ForEach-Object {
        $suffix = if ($_.ParameterType.IsByRef) { "&" } else { "" }
        "$($_.ParameterType.FullName)$suffix $($_.Name)"
    }) -join ", "
    if ($Method -is [System.Reflection.MethodInfo]) {
        return "$($Method.Name)($params) -> $($Method.ReturnType.FullName)"
    }
    return "$($Method.Name)($params)"
}

function Write-TypeProbe([type]$Type, [System.Reflection.BindingFlags]$Flags) {
    Write-Host ""
    Write-Host "TYPE $($Type.FullName)" -ForegroundColor Yellow

    Write-Host "  EVENTS"
    $events = @($Type.GetEvents($Flags) | Sort-Object Name)
    if (-not $events) { Write-Host "    (none)" }
    foreach ($event in $events) {
        Write-Host "    $($event.Name) : $($event.EventHandlerType.FullName)"
        $invoke = $event.EventHandlerType.GetMethod("Invoke")
        if ($invoke) { Write-Host "      invoke $(Format-MethodSignature $invoke)" }
        if ($event.AddMethod) { Write-Host "      add    $(Format-MethodSignature $event.AddMethod)" }
        if ($event.RemoveMethod) { Write-Host "      remove $(Format-MethodSignature $event.RemoveMethod)" }
    }

    Write-Host "  METHODS"
    $methods = @($Type.GetMethods($Flags) | Where-Object { $_.Name -match $script:pattern } | Sort-Object Name)
    if (-not $methods) { Write-Host "    (none)" }
    foreach ($method in $methods) { Write-Host "    $(Format-MethodSignature $method)" }

    Write-Host "  FIELDS"
    $fields = @($Type.GetFields($Flags) | Where-Object { $_.Name -match $script:pattern -or $_.FieldType.FullName -match $script:pattern } | Sort-Object Name)
    if (-not $fields) { Write-Host "    (none)" }
    foreach ($field in $fields) { Write-Host "    $($field.Name) [$($field.FieldType.FullName)]" }

    Write-Host "  PROPERTIES"
    $properties = @($Type.GetProperties($Flags) | Where-Object { $_.Name -match $script:pattern -or $_.PropertyType.FullName -match $script:pattern } | Sort-Object Name)
    if (-not $properties) { Write-Host "    (none)" }
    foreach ($property in $properties) { Write-Host "    $($property.Name) [$($property.PropertyType.FullName)]" }
}

foreach ($typeName in @("PICkitS.Device", "PICkitS.LIN", "PICkitS.Basic")) {
    Write-TypeProbe -Type ([type]$typeName) -Flags $allFlags
}

$networkType = $networkAsm.GetType("WindowsApplication1.Network")
Write-TypeProbe -Type $networkType -Flags $networkFlags

if ($InitializeNetworkAnalyser.IsPresent) {
    Write-Host ""
    Write-Host "INITIALIZED NETWORKANALYSER FIELD VALUES" -ForegroundColor Yellow
    $networkForm = $networkAsm.CreateInstance("WindowsApplication1.Network")
    $load = $networkType.GetMethod("Network_Load", [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    $load.Invoke($networkForm, @($networkForm, [System.EventArgs]::Empty)) | Out-Null

    foreach ($field in ($networkType.GetFields($networkFlags) | Where-Object { $_.Name -match $pattern -or $_.FieldType.FullName -match $pattern } | Sort-Object Name)) {
        $value = $null
        try { $value = $field.GetValue($networkForm) } catch { $value = "<error: $($_.Exception.Message)>" }
        if ($null -eq $value) {
            Write-Host "  $($field.Name) [$($field.FieldType.FullName)] = <null>"
        } else {
            Write-Host "  $($field.Name) [$($field.FieldType.FullName)] = $($value.GetType().FullName) $value"
        }
    }
}