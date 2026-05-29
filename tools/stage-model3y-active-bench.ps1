<#
.SYNOPSIS
    Apply a reviewed Model 3/Y candidate ID and run bench-only active proofs.

.DESCRIPTION
    Updates the provisional Model 3/Y firmware profile ID, builds/flashes
    bench_active_ble, then runs XIAO self-receive and APG raw observer proofs.
    This is bench-only. Never use it while connected to a vehicle bus.
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $CandidateJson,
    [ValidateSet("3", "y")]
    [string] $Model = "3",
    [string] $ConfirmedIdHex = "",
    [switch] $UseTopCandidate,
    [switch] $UpdateBoth3Y,
    [string] $ComPort = "COM4",
    [switch] $ConfirmProfileUpdate,
    [switch] $ConfirmBenchIsolation,
    [switch] $SkipFlash,
    [switch] $SkipProofs
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$pio = Join-Path $env:USERPROFILE ".platformio\penv\Scripts\platformio.exe"
if (-not (Test-Path $pio)) { throw "PlatformIO not found: $pio" }

function Convert-IdHex([string] $IdText) {
    if (-not $IdText) { throw "Missing ID" }
    $clean = $IdText.Trim()
    if ($clean -match '^0x') { $clean = $clean.Substring(2) }
    $value = [Convert]::ToInt32($clean, 16)
    if ($value -lt 0 -or $value -gt 0x3F) { throw "LIN raw ID must be 0x00-0x3F, got $IdText" }
    return $value
}

function Update-ProfileLine([string] $Content, [string] $ProfileName, [int] $RawId, [string] $SourceLeaf) {
    $idHex = "{0:X2}" -f $RawId
    $dataLen = if ($RawId -eq 0x2A) { 7 } else { 8 }
    $note = if ($RawId -eq 0x2A) {
        "Model $ProfileName left scroll wheel from guided capture $SourceLeaf"
    } else {
        "Model $ProfileName provisional from passive capture $SourceLeaf"
    }
    $pattern = '\{"' + [regex]::Escape($ProfileName) + '",\s*0x[0-9A-Fa-f]{2},\s*[0-9]+,\s*"[^"]*"\}'
    $replacement = ('{{"{0}",    0x{1}, {2}, "{3}"}}' -f $ProfileName, $idHex, $dataLen, $note)
    $updated = [regex]::Replace($Content, $pattern, $replacement, 1)
    if ($updated -eq $Content) { throw "Could not update MODEL_PROFILES entry for $ProfileName" }
    return $updated
}

Push-Location $repoRoot
try {
    if (-not $ConfirmProfileUpdate) { throw "Pass -ConfirmProfileUpdate after reviewing the candidate JSON. This script edits src/main.cpp." }
    if (-not $ConfirmBenchIsolation) { throw "Pass -ConfirmBenchIsolation only on the isolated bench. Never run this on a vehicle." }
    if (-not (Test-Path $CandidateJson)) { throw "CandidateJson not found: $CandidateJson" }

    $candidatePath = (Resolve-Path $CandidateJson).Path
    $candidate = Get-Content -Raw $candidatePath | ConvertFrom-Json
    if (-not $ConfirmedIdHex) {
        if (-not $UseTopCandidate) { throw "Provide -ConfirmedIdHex or pass -UseTopCandidate after review." }
        if (-not $candidate.candidates -or $candidate.candidates.Count -lt 1) { throw "Candidate JSON has no candidates" }
        $ConfirmedIdHex = [string]$candidate.candidates[0].id_hex
    }
    $rawId = Convert-IdHex $ConfirmedIdHex
    $idHex = "0x{0:X2}" -f $rawId
    Write-Host "Applying provisional Model $Model active bench profile ID $idHex" -ForegroundColor Yellow
    Write-Host "Source candidate: $candidatePath" -ForegroundColor Cyan

    $sourcePath = Join-Path $repoRoot "src\main.cpp"
    $content = Get-Content -Raw $sourcePath
    $sourceLeaf = Split-Path -Leaf (Split-Path -Parent $candidatePath)
    $content = Update-ProfileLine $content $Model $rawId $sourceLeaf
    if ($UpdateBoth3Y) {
        $sibling = if ($Model -eq "3") { "y" } else { "3" }
        $content = Update-ProfileLine $content $sibling $rawId $sourceLeaf
    }
    Set-Content -Path $sourcePath -Value $content -Encoding ascii

    if (-not $SkipFlash) {
        & $pio run -e bench_active_ble -t upload --upload-port $ComPort
        if ($LASTEXITCODE -ne 0) { throw "bench_active_ble upload failed" }
    }

    if (-not $SkipProofs) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort $ComPort -Model $Model -ConfirmBenchIsolation
        if ($LASTEXITCODE -ne 0) { throw "active-bench-proof failed" }
        & powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -ComPort $ComPort -Model $Model -RawFallbackId $rawId -ConfirmBenchIsolation
        if ($LASTEXITCODE -ne 0) { throw "active-apg-raw-proof failed" }
    }

    Write-Host "Bench-only active proof flow complete for Model $Model provisional ID $idHex." -ForegroundColor Green
} finally {
    Pop-Location
}