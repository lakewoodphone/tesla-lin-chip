<#
.SYNOPSIS
    Analyze a passive Model 3/Y capture session and emit candidate profile data.

.DESCRIPTION
    Finds the APG CSV for a session, runs the summary/analyzer with manifest
    action windows, writes analysis.json and model-profile-candidate.json, and
    prints the top candidate IDs for review.
#>

param(
    [string] $SessionDir = "",
    [string] $CsvPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Get-LatestSession {
    $sessionRoot = Join-Path $repoRoot "logs\sessions"
    $latest = Get-ChildItem $sessionRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'car-passive|guided' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No Model 3/Y capture session found under $sessionRoot" }
    return $latest.FullName
}

Push-Location $repoRoot
try {
    if (-not $SessionDir) { $SessionDir = Get-LatestSession }
    if (-not (Test-Path $SessionDir)) { throw "SessionDir not found: $SessionDir" }
    $SessionDir = (Resolve-Path $SessionDir).Path
    $manifestPath = Join-Path $SessionDir "manifest.json"
    if (-not (Test-Path $manifestPath)) { throw "manifest.json not found in $SessionDir" }

    $guidedLog = Get-ChildItem $SessionDir -Filter "xiao-guided-serial*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $byteReport = Join-Path $SessionDir "analysis-byte-report.txt"
    if ($guidedLog) {
        Write-Host "Running guided byte analysis..." -ForegroundColor Yellow
        & python tools\analyze-log-bytes.py $SessionDir 2>&1 | Tee-Object -FilePath $byteReport
        if ($LASTEXITCODE -ne 0) { throw "analyze-log-bytes failed" }
        Write-Host "Byte report: $byteReport" -ForegroundColor Cyan
    }

    if (-not $CsvPath) {
        $csv = Get-ChildItem $SessionDir -Filter "lin-capture-*.csv" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($csv) { $CsvPath = $csv.FullName }
    }

    if (-not $CsvPath) {
        Write-Host "No APG CSV found; guided byte analysis complete." -ForegroundColor Yellow
        Write-Host "Confirmed 2026-05-28 Model 3 map: left wheel ID 0x2A, right wheel ID 0x2B, byte[0] 0x0D up / 0x0B down / 0x2C click / 0x0C idle." -ForegroundColor Green
        return
    }
    $CsvPath = (Resolve-Path $CsvPath).Path

    $analysisJson = Join-Path $SessionDir "analysis.json"
    $candidateJson = Join-Path $SessionDir "model-profile-candidate.json"

    & powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1 -CsvPath $CsvPath
    if ($LASTEXITCODE -ne 0) { throw "summarize-lin-capture failed" }

    & python tools\analyze-lin-capture.py $CsvPath --json $analysisJson --windows $manifestPath --candidate-json $candidateJson
    if ($LASTEXITCODE -ne 0) { throw "analyze-lin-capture failed" }

    $candidate = Get-Content -Raw $candidateJson | ConvertFrom-Json
    Write-Host ""
    Write-Host "Top candidate IDs:" -ForegroundColor Yellow
    $candidate.candidates | Select-Object -First 8 id_hex,id_dec,label,reference_priority,frame_count,unique_payloads,score | Format-Table -AutoSize
    Write-Host ""
    Write-Host "Analysis:  $analysisJson" -ForegroundColor Cyan
    Write-Host "Candidate: $candidateJson" -ForegroundColor Cyan
    Write-Host "Bench-only next step after human review:" -ForegroundColor Green
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File tools\stage-model3y-active-bench.ps1 -CandidateJson `"$candidateJson`" -Model 3 -UseTopCandidate -ConfirmProfileUpdate -ConfirmBenchIsolation"
} finally {
    Pop-Location
}