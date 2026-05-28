<#
.SYNOPSIS
    Run the full isolated-bench proof flow for the XIAO LIN bench.

.DESCRIPTION
    BENCH ONLY. Builds passive and active firmware targets, records a hardware
    preflight artifact unless skipped, runs passive APG->XIAO evidence, active
    self-receive proof, optional APG raw observer proof, and writes a summary.
    This script does not flash firmware automatically; flash bench_active_ble
    before active proof steps and field_passive before passive vehicle work.
#>

param(
    [string] $ComPort = "COM4",
    [UInt16] $Baud = 19200,
    [string] $VehicleId = "tesla-bench-full",
    [string] $LogDir = "",
    [switch] $SkipBuild,
    [switch] $SkipPreflight,
    [switch] $SkipApgRawProof,
    [switch] $NoPost,
    [switch] $RunActive,
    [switch] $ConfirmBenchIsolation
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$proofDir = Join-Path $LogDir "full-bench-proof-${stamp}"
New-Item -ItemType Directory -Path $proofDir | Out-Null
$summaryPath = Join-Path $proofDir "full-bench-proof-${stamp}.md"
$transcriptPath = Join-Path $proofDir "full-bench-proof-${stamp}.log"

function Write-Proof([string] $Message) {
    $line = "[$(Get-Date -Format 'HH:mm:ss.fff')] $Message"
    $line | Tee-Object -FilePath $script:transcriptPath -Append
}

function Invoke-Step([string] $Name, [scriptblock] $Block) {
    Write-Proof "START $Name"
    try {
        & $Block 2>&1 | ForEach-Object { Write-Proof "  $_" }
        if ($LASTEXITCODE -ne 0) { throw "$Name exited with code $LASTEXITCODE" }
        Write-Proof "PASS $Name"
        return $true
    } catch {
        Write-Proof "FAIL $Name :: $($_.Exception.Message)"
        return $false
    }
}

Push-Location $repoRoot
try {
    Write-Proof "============================================================"
    Write-Proof "Full XIAO LIN bench proof"
    Write-Proof "Port=$ComPort Baud=$Baud Vehicle=$VehicleId Output=$proofDir"
    Write-Proof "BENCH ONLY - do not run while connected to a vehicle bus"
    Write-Proof "NOTE: script builds firmware but does not flash; active proof expects bench_active_ble already on the XIAO"
    Write-Proof "============================================================"

    if ($RunActive -and -not $ConfirmBenchIsolation) {
        $confirmation = Read-Host "Type BENCH to confirm the XIAO/TJA1021/APG rig is isolated from any vehicle before active proof"
        if ($confirmation -ne "BENCH") { throw "Active proof aborted: bench isolation was not confirmed" }
    }

    $results = New-Object System.Collections.Generic.List[object]

    if (-not $SkipBuild) {
        $ok = Invoke-Step "build-all-envs" { & powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-all-envs.ps1 }
        $results.Add([pscustomobject]@{ step = "build-all-envs"; status = $(if ($ok) { "PASS" } else { "FAIL" }) }) | Out-Null
    }

    if (-not $SkipPreflight) {
        Write-Host "Hardware preflight is interactive. Use -SkipPreflight for unattended dry runs." -ForegroundColor Yellow
        $ok = Invoke-Step "preflight-hardware-check" { & powershell -NoProfile -ExecutionPolicy Bypass -File tools\preflight-hardware-check.ps1 -Mode bench -LogDir $proofDir -RequirePass }
        $results.Add([pscustomobject]@{ step = "preflight-hardware-check"; status = $(if ($ok) { "PASS" } else { "FAIL" }) }) | Out-Null
    }

    $benchArgs = @("-ComPort", $ComPort, "-Baud", $Baud, "-VehicleId", $VehicleId, "-LogDir", $proofDir)
    if ($NoPost) { $benchArgs += "-NoPost" }
    $ok = Invoke-Step "bench-evidence-suite" { & powershell -NoProfile -ExecutionPolicy Bypass -File tools\bench-evidence-suite.ps1 @benchArgs }
    $results.Add([pscustomobject]@{ step = "bench-evidence-suite"; status = $(if ($ok) { "PASS" } else { "FAIL" }) }) | Out-Null

    if ($RunActive) {
        $ok = Invoke-Step "active-bench-proof" { & powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-bench-proof.ps1 -ComPort $ComPort -Model x -LogDir $proofDir -ConfirmBenchIsolation }
        $results.Add([pscustomobject]@{ step = "active-bench-proof"; status = $(if ($ok) { "PASS" } else { "FAIL" }) }) | Out-Null

        if (-not $SkipApgRawProof) {
            $ok = Invoke-Step "active-apg-raw-proof" { & powershell -NoProfile -ExecutionPolicy Bypass -File tools\active-apg-raw-proof.ps1 -ComPort $ComPort -Baud $Baud -LogDir $proofDir -ConfirmBenchIsolation }
            $results.Add([pscustomobject]@{ step = "active-apg-raw-proof"; status = $(if ($ok) { "PASS" } else { "FAIL" }) }) | Out-Null
        }
    } else {
        Write-Proof "SKIP active bench proof; pass -RunActive and confirm bench isolation to include TX tests"
        $results.Add([pscustomobject]@{ step = "active-bench-proof"; status = "SKIP" }) | Out-Null
        if (-not $SkipApgRawProof) { $results.Add([pscustomobject]@{ step = "active-apg-raw-proof"; status = "SKIP" }) | Out-Null }
    }

    $passed = -not ($results | Where-Object { $_.status -eq "FAIL" })
    $summary = @(
        "# Full Bench Proof $stamp",
        "",
        "- Port: $ComPort",
        "- Baud: $Baud",
        "- Vehicle label: $VehicleId",
        "- Result: $(if ($passed) { 'PASS' } else { 'FAIL' })",
        "- Output folder: $proofDir",
        "",
        "| Step | Result |",
        "|---|---|"
    )
    foreach ($result in $results) {
        $summary += "| $($result.step) | $($result.status) |"
    }
    $summary += ""
    $summary += "Transcript: $transcriptPath"
    $summary | Out-File -FilePath $summaryPath -Encoding utf8

    Write-Proof "SUMMARY $summaryPath"
    if (-not $passed) { exit 1 }
} finally {
    Pop-Location
}