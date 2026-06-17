param(
    [string]$Device = "fx2lafw:conn=1.40",
    [string]$Channel = "D0",
    [int]$Seconds = 10,
    [string]$SampleRate = "1m",
    [string]$OutDir = "_scratch\tesla-tsl5-captures",
    [string]$InputFile = ""
)

$ErrorActionPreference = "Stop"

function Resolve-SigrokCli {
    $command = Get-Command sigrok-cli -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @(
        "C:\Program Files\sigrok\sigrok-cli\sigrok-cli.exe",
        "C:\Program Files (x86)\sigrok\sigrok-cli\sigrok-cli.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }

    throw "sigrok-cli is not available on PATH or at the known Program Files install paths. Install sigrok/PulseView first."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$sigrokCli = Resolve-SigrokCli

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$decoder = "uart:rx=${Channel}:baudrate=19200:format=hex,lin:version=2"

if ($InputFile) {
    $decodePath = [System.IO.Path]::ChangeExtension($InputFile, ".decode.txt")
    Write-Host "Decoding $InputFile with $decoder"
    & $sigrokCli -i $InputFile -P $decoder --protocol-decoder-samplenum | Tee-Object -FilePath $decodePath
    if ($LASTEXITCODE -ne 0) {
        throw "sigrok decode failed with exit code $LASTEXITCODE"
    }
    Write-Host "Decode written to $decodePath"
    exit 0
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$capturePath = Join-Path $OutDir "tsl5-lin-$timestamp.sr"
$decodePath = Join-Path $OutDir "tsl5-lin-$timestamp.decode.txt"

Write-Host "Capturing $Seconds second(s) from $Device channel $Channel at $SampleRate"
& $sigrokCli -d $Device --config "samplerate=$SampleRate" --channels $Channel --time ($Seconds * 1000) -O srzip -o $capturePath
if ($LASTEXITCODE -ne 0) {
    throw "sigrok capture failed with exit code $LASTEXITCODE"
}

Write-Host "Capture written to $capturePath"
Write-Host "Decoding with $decoder"
& $sigrokCli -i $capturePath -P $decoder --protocol-decoder-samplenum | Tee-Object -FilePath $decodePath
if ($LASTEXITCODE -ne 0) {
    throw "sigrok decode failed with exit code $LASTEXITCODE"
}

Write-Host "Decode written to $decodePath"