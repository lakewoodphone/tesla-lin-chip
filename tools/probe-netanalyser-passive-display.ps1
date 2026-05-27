param(
    [string] $ComPort = "COM4",
    [UInt16] $Baud = 19200,
    [ValidateSet("DisplayAll", "Listen")]
    [string] $Mode = "DisplayAll",
    [int] $DurationSeconds = 6
)

$ErrorActionPreference = "Stop"

if ([IntPtr]::Size -ne 4) {
    $x86PowerShell = Join-Path $env:WINDIR "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    & $x86PowerShell -STA -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -ComPort $ComPort -Baud $Baud -Mode $Mode -DurationSeconds $DurationSeconds
    exit $LASTEXITCODE
}

$analyzerDir = "C:\Users\ezabz\Downloads\LINAnalyzer"
[System.Reflection.Assembly]::LoadFrom((Join-Path $analyzerDir "PICkitS.dll")) | Out-Null
Add-Type -AssemblyName System.Windows.Forms
$networkAsm = [System.Reflection.Assembly]::LoadFrom((Join-Path $analyzerDir "NetworkAnalyser.exe"))
$networkType = $networkAsm.GetType("WindowsApplication1.Network")
$networkForm = $networkAsm.CreateInstance("WindowsApplication1.Network")

function Invoke-NetworkPrivate($Name, [object[]]$InvokeArgs) {
    $method = $networkType.GetMethod($Name, [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    if (-not $method) { throw "NetworkAnalyser method not found: $Name" }
    return $method.Invoke($networkForm, $InvokeArgs)
}

function Get-NetworkFieldValue($Name) {
    $field = $networkType.GetField($Name, [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    if (-not $field) { return $null }
    return $field.GetValue($networkForm)
}

function Send-XiaoCommand([System.IO.Ports.SerialPort]$Port, [string]$Command) {
    $Port.WriteLine($Command)
    Start-Sleep -Milliseconds 100
}

function Read-XiaoLines([System.IO.Ports.SerialPort]$Port, [int]$Milliseconds) {
    $lines = @()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $Milliseconds) {
        try {
            $line = $Port.ReadLine().Trim()
            if ($line) { $lines += $line }
        } catch [System.TimeoutException] {
        }
    }
    return $lines
}

$serial = New-Object System.IO.Ports.SerialPort $ComPort, 115200, ([System.IO.Ports.Parity]::None), 8, ([System.IO.Ports.StopBits]::One)
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.ReadTimeout = 150

try {
    Invoke-NetworkPrivate "Network_Load" @($networkForm, [System.EventArgs]::Empty) | Out-Null

    $baudField = $networkType.GetField("MasterBaudRate", [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    $baudField.SetValue($networkForm, [uint16]$Baud)
    $linObj = (Get-NetworkFieldValue "_OnAnswerSource")
    if (-not $linObj) { throw "NetworkAnalyser LIN source not initialized" }
    $changeBaudMethod = $linObj.GetType().GetMethod("Change_LIN_BAUD_Rate")
    $changeBaudMethod.Invoke($linObj, @([uint16]$Baud)) | Out-Null
    Start-Sleep -Milliseconds 50
    $changeBaudMethod.Invoke($linObj, @([uint16]$Baud)) | Out-Null

    $modeOk = if ($Mode -eq "Listen") { [PICkitS.LIN]::SetModeListen() } else { [PICkitS.LIN]::SetModeDisplayAll() }
    $optionsOk = [PICkitS.LIN]::Set_LIN_Options($false, $true, $false)
    Write-Host "NetworkAnalyser passive display probe: mode=$Mode modeOk=$modeOk optionsOk=$optionsOk baud=$Baud"

    $serial.Open()
    Start-Sleep -Milliseconds 500
    Send-XiaoCommand $serial "txd:uart"
    Send-XiaoCommand $serial "model:x"
    Send-XiaoCommand $serial "antinag:start"

    $xiaoLines = @()
    $stopAt = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
    while ([DateTime]::UtcNow -lt $stopAt) {
        [System.Windows.Forms.Application]::DoEvents()
        $xiaoLines += Read-XiaoLines $serial 200
    }

    Send-XiaoCommand $serial "antinag:stop"
    $xiaoLines += Read-XiaoLines $serial 500

    $textBox1 = Get-NetworkFieldValue "_TextBox1"
    $rtfString = Get-NetworkFieldValue "RTFstrng"
    $displayText = ""
    if ($textBox1 -and $textBox1.Text) { $displayText += $textBox1.Text }
    if ($rtfString -and $rtfString.Text) { $displayText += "`n" + $rtfString.Text }

    $txLines = @($xiaoLines | Where-Object { $_ -match '^TX #' })
    Write-Host "XIAO TX lines observed: $($txLines.Count)"
    Write-Host "NetworkAnalyser display chars: $($displayText.Length)"
    if ($displayText.Length -gt 0) {
        Write-Host "--- NetworkAnalyser display tail ---"
        Write-Host ($displayText.Substring([Math]::Max(0, $displayText.Length - 1000)))
    }
    Write-Host "--- XIAO serial tail ---"
    $xiaoLines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
} finally {
    if ($serial.IsOpen) {
        try { $serial.WriteLine("antinag:stop") } catch {}
        $serial.Close()
    }
}