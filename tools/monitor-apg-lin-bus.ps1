<#
.SYNOPSIS
    Passively monitor a LIN bus via APGDT001 and log all frames to a file.
    Run this on car day to capture real Tesla frame IDs and payloads.

.DESCRIPTION
    Puts the APGDT001 into SetModeDisplayAll (receive-only, no transmit).
    Subscribes to the PICkitS.LIN OnReceive and OnAnswer events using a C# delegate
    wrapper (required because GUINotifierOR is a custom delegate type).
    Logs every frame to the console and to a timestamped CSV/text log file.

    Works for Model X, 3, Y - whatever is on the bus gets captured.

.PARAMETER Baud
    LIN bus baud rate. Default 19200 (confirmed for Model X B-LIN bus).
    Try 9600 for older Tesla body buses if you see nothing.

.PARAMETER LogDir
    Directory to write log files. Default: C:\Users\ezabz\Code\xiao-lin-bench\logs

.PARAMETER DurationSeconds
    Stop after this many seconds. Default 0 = run until Ctrl+C.

.EXAMPLE
    # Full capture session at 19200 baud
    cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1

    # 60-second capture at 9600 baud (Model 3/Y fallback)
    cmd /c %WINDIR%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File tools\monitor-apg-lin-bus.ps1 -Baud 9600 -DurationSeconds 60

.NOTES
    MUST run in 32-bit PowerShell (SysWOW64) - PICkitS.dll is x86 only.
    APG must be connected via USB. LINBUS pins: pin1=LIN, pin2=GND, pin3=12V.
    Supply 12V to the APG LINBUS connector before connecting to vehicle.
#>

param(
    [UInt16] $Baud            = 19200,
    [string] $LogDir          = "C:\Users\ezabz\Code\xiao-lin-bench\logs",
    [int]    $DurationSeconds = 0
)

$ErrorActionPreference = "Stop"

# --- Must run in 32-bit PowerShell ---
if ([IntPtr]::Size -ne 4) {
    Write-Host "Relaunching in 32-bit PowerShell (required for PICkitS.dll)..." -ForegroundColor Yellow
    $args32 = @("-STA", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath,
                "-Baud", $Baud, "-LogDir", $LogDir, "-DurationSeconds", $DurationSeconds)
    & "$env:WINDIR\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" @args32
    exit $LASTEXITCODE
}

# --- Load APG / NetworkAnalyser assemblies ---
$analyzerDir = "C:\Users\ezabz\Downloads\LINAnalyzer"
$null = [System.Reflection.Assembly]::LoadFrom((Join-Path $analyzerDir "PICkitS.dll"))
Add-Type -AssemblyName System.Windows.Forms
$networkAsm = [System.Reflection.Assembly]::LoadFrom((Join-Path $analyzerDir "NetworkAnalyser.exe"))
$networkType = $networkAsm.GetType("WindowsApplication1.Network")
$networkForm = $networkAsm.CreateInstance("WindowsApplication1.Network")

function Invoke-NetworkPrivate($name, [object[]]$invokeArgs) {
    $method = $networkType.GetMethod($name, [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    if (-not $method) { throw "NetworkAnalyser method not found: $name" }
    return $method.Invoke($networkForm, $invokeArgs)
}

function Get-NetworkField($name) {
    $field = $networkType.GetField($name, [System.Reflection.BindingFlags]"Public,NonPublic,Instance")
    if (-not $field) { throw "NetworkAnalyser field not found: $name" }
    return $field
}

# --- C# delegate wrapper ---
# PowerShell cannot directly cast a scriptblock to PICkitS.LIN+GUINotifierOR.
# We create a static C# helper whose static method matches the delegate signature,
# and wire a PowerShell Action into it so we can log from PowerShell.
Add-Type -ReferencedAssemblies @((Join-Path $analyzerDir "PICkitS.dll"), "mscorlib") @"
using System;
using PICkitS;

public static class LinFrameRouter {
    public delegate void LinFrameCallback(byte masterid, byte[] data, byte length, byte error, ushort baud, double time);

    // Called by PICkitS runtime on each received LIN frame
    public static LinFrameCallback OnFrame;

    public static void HandleOR(byte masterid, byte[] data, byte length, byte error, ushort baud, double time) {
        if (OnFrame != null)
            OnFrame(masterid, data, length, error, baud, time);
    }
    public static void HandleOA(byte masterid, byte[] data, byte length, byte error, ushort baud, double time) {
        if (OnFrame != null)
            OnFrame(masterid, data, length, error, baud, time);
    }
}
"@

# --- Ensure log directory exists ---
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $LogDir "lin-capture-${stamp}.txt"
$csvFile = Join-Path $LogDir "lin-capture-${stamp}.csv"

# Write CSV header
"timestamp_ms,id_hex,id_dec,pid_hex,data_len,data_hex,error,baud" | Out-File -FilePath $csvFile -Encoding utf8

$sessionStart = [System.Diagnostics.Stopwatch]::StartNew()
$frameCount   = 0
$idSeen       = @{}   # track unique IDs observed

# --- Frame handler (runs on UI thread via Add-Type delegate) ---
[LinFrameRouter+LinFrameCallback] $callback = {
    param($masterid, $data, $length, $error, $baud, $time)

    $elapsed   = [int]$sessionStart.Elapsed.TotalMilliseconds
    $idHex     = "0x{0:X2}" -f $masterid
    $pidByte   = $masterid   # PID = protected ID received on bus
    $rawId     = $masterid -band 0x3F
    $rawIdHex  = "0x{0:X2}" -f $rawId
    $dataBytes = if ($length -gt 0 -and $data) { $data[0..([Math]::Min($length-1, 7))] } else { @() }
    $dataHex   = ($dataBytes | ForEach-Object { "{0:X2}" -f $_ }) -join " "
    $errTag    = if ($error -ne 0) { " ERR=0x{0:X2}" -f $error } else { "" }

    $script:frameCount++
    if (-not $script:idSeen.ContainsKey($rawIdHex)) {
        $script:idSeen[$rawIdHex] = 0
    }
    $script:idSeen[$rawIdHex]++

    $line = "[{0,8}ms] #{1,-5} PID=0x{2:X2} ID={3} [{4}B] {5,-23}{6}" -f `
            $elapsed, $script:frameCount, $pidByte, $rawIdHex, $length, $dataHex, $errTag

    Write-Host $line -ForegroundColor $(if ($error -ne 0) { "Red" } else { "Cyan" })
    $line | Out-File -FilePath $script:logFile -Append -Encoding utf8

    # CSV row
    "{0},{1},{2},0x{3:X2},{4},{5},{6},{7}" -f `
        $elapsed, $rawIdHex, $rawId, $pidByte, $length, ($dataHex.Replace(" ","-")), $error, $baud |
        Out-File -FilePath $script:csvFile -Append -Encoding utf8
}
[LinFrameRouter]::OnFrame = $callback

# --- Create and subscribe delegates ---
$orDelegate = [System.Delegate]::CreateDelegate(
    [PICkitS.LIN+GUINotifierOR],
    [LinFrameRouter].GetMethod("HandleOR")
)
$oaDelegate = [System.Delegate]::CreateDelegate(
    [PICkitS.LIN+GUINotifierOA],
    [LinFrameRouter].GetMethod("HandleOA")
)
[PICkitS.LIN]::add_OnReceive($orDelegate)
[PICkitS.LIN]::add_OnAnswer($oaDelegate)

# --- Initialize APG hardware through NetworkAnalyser.exe ---
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host "  LIN Bus Monitor - APGDT001 Passive Capture"         -ForegroundColor Yellow
Write-Host "  Baud: $Baud   Vehicle: any (3/Y/X)"                 -ForegroundColor Yellow
Write-Host "  Log:  $logFile"                                      -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Yellow
Write-Host ""

Invoke-NetworkPrivate "Network_Load" @($networkForm, [System.EventArgs]::Empty) | Out-Null

$baudField = Get-NetworkField "MasterBaudRate"
$baudField.SetValue($networkForm, [uint16]$Baud)

$linField = Get-NetworkField "_OnAnswerSource"
$linObj = $linField.GetValue($networkForm)
if (-not $linObj) { Write-Error "NetworkAnalyser LIN instance not found."; exit 2 }

$changeBaudMethod = $linObj.GetType().GetMethod("Change_LIN_BAUD_Rate")
$getBaudMethod = $linObj.GetType().GetMethod("Get_LIN_BAUD_Rate")
$changeBaudMethod.Invoke($linObj, @([uint16]$Baud)) | Out-Null
Start-Sleep -Milliseconds 50
$changeBaudMethod.Invoke($linObj, @([uint16]$Baud)) | Out-Null

Write-Host "NetworkAnalyser MasterBaudRate field: $($baudField.GetValue($networkForm))"
if ($getBaudMethod) {
    Write-Host "NetworkAnalyser LIN instance baud: $($getBaudMethod.Invoke($linObj, @()))"
}

# Passive receive - do NOT call SetModeTransmit
$modeOk = [PICkitS.LIN]::SetModeDisplayAll()
Write-Host "SetModeDisplayAll: $modeOk"
$null = [PICkitS.LIN]::Set_LIN_Options($false, $true, $false)

Write-Host ""
Write-Host "Listening on LIN bus at $Baud baud. Press Ctrl+C to stop." -ForegroundColor Green
Write-Host "Connect APG LINBUS: pin1=LIN  pin2=GND  pin3=12V" -ForegroundColor DarkGray
Write-Host ""

# --- Capture loop ---
$stopAt = if ($DurationSeconds -gt 0) { $sessionStart.Elapsed.TotalSeconds + $DurationSeconds } else { [double]::MaxValue }
try {
    while ($sessionStart.Elapsed.TotalSeconds -lt $stopAt) {
        Start-Sleep -Milliseconds 50
        # Events fire on the background USB thread via the delegate; no polling needed
    }
} finally {
    # --- Unsubscribe delegates ---
    try { [PICkitS.LIN]::remove_OnReceive($orDelegate) } catch {}
    try { [PICkitS.LIN]::remove_OnAnswer($oaDelegate)  } catch {}

    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Yellow
    Write-Host ("  Capture complete - {0} frames, {1} unique IDs" -f $frameCount, $idSeen.Count)
    Write-Host ""
    Write-Host "  Unique IDs seen:"
    foreach ($entry in ($idSeen.GetEnumerator() | Sort-Object Name)) {
        Write-Host ("    {0}  ({1} frames)" -f $entry.Key, $entry.Value)
    }
    Write-Host ""
    Write-Host "  Log:  $logFile"
    Write-Host "  CSV:  $csvFile"
    Write-Host "=====================================================" -ForegroundColor Yellow
}

[System.Environment]::Exit(0)
