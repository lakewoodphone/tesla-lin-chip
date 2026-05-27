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

$rawBytes = New-Object System.Collections.Generic.List[byte]
$xiaoLines = @()

try {
    $initOk = [PICkitS.Device]::Initialize_PICkitSerial()
    if (-not $initOk) { $initOk = [PICkitS.Device]::Initialize_MyDevice(0, 0x0A04) }
    if (-not $initOk) { throw "Could not initialize APG/PICkit Serial" }

    $configOk = [PICkitS.LIN]::Configure_PICkitSerial_For_LIN($false, $true, $false)
    if (-not $configOk) { $configOk = [PICkitS.LIN]::Configure_PICkitSerial_For_LIN() }
    [PICkitS.Device]::Set_Buffer_Flush_Parameters($true, $true, [byte]1, [double]1) | Out-Null
    [PICkitS.LIN]::Change_LIN_BAUD_Rate($Baud) | Out-Null
    Start-Sleep -Milliseconds 50
    [PICkitS.LIN]::Change_LIN_BAUD_Rate($Baud) | Out-Null
    if ($Mode -eq "Listen") { [PICkitS.LIN]::SetModeListen() | Out-Null } else { [PICkitS.LIN]::SetModeDisplayAll() | Out-Null }
    [PICkitS.LIN]::Set_LIN_Options($false, $true, $false) | Out-Null

    Write-Host "APG raw USART buffer probe: initOk=$initOk configOk=$configOk mode=$Mode baud=$Baud reportedBaud=$([PICkitS.LIN]::Get_LIN_BAUD_Rate())"

    $serial.Open()
    Start-Sleep -Milliseconds 500
    Send-XiaoCommand $serial "txd:uart"
    Send-XiaoCommand $serial "model:x"
    Send-XiaoCommand $serial "antinag:start"

    $stopAt = [DateTime]::UtcNow.AddSeconds($DurationSeconds)
    while ([DateTime]::UtcNow -lt $stopAt) {
        $xiaoLines += Read-XiaoLines $serial 100
        $count = [PICkitS.Basic]::Retrieve_USART_Data_Byte_Count()
        if ($count -gt 0) {
            $buffer = New-Object byte[] ([int]$count)
            $ok = [PICkitS.Basic]::Retrieve_USART_Data([uint32]$count, [ref]$buffer)
            Write-Host "Retrieve_USART_Data count=$count ok=$ok bytes=$(($buffer | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')"
            foreach ($byte in $buffer) { $rawBytes.Add($byte) }
        }
    }

    Send-XiaoCommand $serial "antinag:stop"
    $xiaoLines += Read-XiaoLines $serial 500
} finally {
    if ($serial.IsOpen) {
        try { $serial.WriteLine("antinag:stop") } catch {}
        $serial.Close()
    }
}

$txLines = @($xiaoLines | Where-Object { $_ -match '^TX #' })
Write-Host "XIAO TX lines observed: $($txLines.Count)"
Write-Host "APG raw bytes observed: $($rawBytes.Count)"
if ($rawBytes.Count -gt 0) {
    Write-Host "APG raw byte tail: $((@($rawBytes.ToArray()) | Select-Object -Last 128 | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')"
}
Write-Host "--- XIAO serial tail ---"
$xiaoLines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }