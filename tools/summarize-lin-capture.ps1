<#
.SYNOPSIS
    Summarize an APG LIN capture CSV by ID, count, timing, and payload variants.

.DESCRIPTION
    Use after car-day passive capture. Reads logs/lin-capture-*.csv from
    monitor-apg-lin-bus.ps1 and produces a compact per-ID summary.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\summarize-lin-capture.ps1 -CsvPath logs\lin-capture-20260526_140000.csv
#>

param(
    [string] $CsvPath = "",
    [string] $OutPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$logDir = Join-Path $repoRoot "logs"

if (-not $CsvPath) {
    $latest = Get-ChildItem $logDir -Filter "lin-capture-*.csv" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No lin-capture-*.csv files found under $logDir" }
    $CsvPath = $latest.FullName
}

if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }

$rows = Import-Csv $CsvPath
if (-not $rows -or $rows.Count -eq 0) {
    Write-Host "No LIN frames found in $CsvPath"
    exit 0
}

if (-not $OutPath) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($CsvPath)
    $summaryName = $base -replace '^lin-capture', 'lin-summary'
    $OutPath = Join-Path (Split-Path -Parent $CsvPath) ($summaryName + ".csv")
}

$summary = foreach ($group in ($rows | Group-Object id_hex | Sort-Object Name)) {
    $items = $group.Group | Sort-Object { [int]$_.timestamp_ms }
    $firstMs = [int]$items[0].timestamp_ms
    $lastMs = [int]$items[-1].timestamp_ms
    $durationMs = [Math]::Max(1, $lastMs - $firstMs)
    $count = $items.Count
    $rateHz = [Math]::Round(($count - 1) / ($durationMs / 1000.0), 2)
    $payloads = $items | Group-Object data_hex | Sort-Object Count -Descending
    $samplePayloads = ($payloads | Select-Object -First 5 | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join "; "
    $errors = ($items | Where-Object { [int]$_.error -ne 0 }).Count

    [pscustomobject]@{
        id_hex = $group.Name
        id_dec = $items[0].id_dec
        pid_hex = $items[0].pid_hex
        data_len = $items[0].data_len
        frames = $count
        duration_ms = $durationMs
        approx_rate_hz = $rateHz
        unique_payloads = $payloads.Count
        error_frames = $errors
        sample_payloads = $samplePayloads
    }
}

$summary | Export-Csv -NoTypeInformation -Path $OutPath
$summary | Format-Table -AutoSize
Write-Host ""
Write-Host "Summary written: $OutPath"