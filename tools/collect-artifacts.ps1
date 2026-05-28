<#
.SYNOPSIS
    Collect LIN session artifacts into a manifest-backed folder.

.DESCRIPTION
    Copies APG CSV/TXT logs, XIAO serial logs, analyzer JSON, Markdown reports,
    and photos into a capture session folder. If the folder has manifest.json,
    this script updates its artifact fields where possible.
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $SessionDir,
    [string[]] $Files = @(),
    [string] $LatestFromLogDir = "",
    [switch] $IncludeLatestApg,
    [switch] $IncludeLatestBenchReports
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not (Test-Path $SessionDir)) { throw "SessionDir not found: $SessionDir" }
$SessionDir = (Resolve-Path $SessionDir).Path
if (-not $LatestFromLogDir) { $LatestFromLogDir = Join-Path $repoRoot "logs" }

function Copy-Artifact([string] $Path) {
    if (-not $Path) { return $null }
    if (-not (Test-Path $Path)) { throw "Artifact not found: $Path" }
    $item = Get-Item $Path
    $dest = Join-Path $SessionDir $item.Name
    Copy-Item -Path $item.FullName -Destination $dest -Force
    return (Resolve-Path $dest).Path
}

$copied = New-Object System.Collections.Generic.List[string]

foreach ($file in $Files) {
    $dest = Copy-Artifact $file
    if ($dest) { $copied.Add($dest) | Out-Null }
}

if ($IncludeLatestApg) {
    foreach ($pattern in @("lin-capture-*.csv", "lin-capture-*.txt")) {
        $latest = Get-ChildItem $LatestFromLogDir -Filter $pattern -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($latest) {
            $dest = Copy-Artifact $latest.FullName
            if ($dest) { $copied.Add($dest) | Out-Null }
        }
    }
}

if ($IncludeLatestBenchReports) {
    foreach ($pattern in @("*.md", "*.json", "*.log")) {
        $latest = Get-ChildItem $LatestFromLogDir -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notlike "*$([IO.Path]::DirectorySeparatorChar).pio$([IO.Path]::DirectorySeparatorChar)*" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 3
        foreach ($item in $latest) {
            $dest = Copy-Artifact $item.FullName
            if ($dest) { $copied.Add($dest) | Out-Null }
        }
    }
}

$manifestPath = Join-Path $SessionDir "manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
    foreach ($path in $copied) {
        $name = Split-Path -Leaf $path
        if ($name -like "lin-capture-*.csv") { $manifest.artifacts.apg_csv = $name }
        elseif ($name -like "lin-capture-*.txt") { $manifest.artifacts.apg_txt = $name }
        elseif ($name -like "*serial*.log" -or $name -like "xiao-*.log") { $manifest.artifacts.xiao_serial = $name }
        elseif ($name -like "*analysis*.json") { $manifest.artifacts.analyzer_json = $name }
    }
    $manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $manifestPath -Encoding utf8
}

Write-Host "Collected $($copied.Count) artifact(s) into $SessionDir" -ForegroundColor Green
$copied | ForEach-Object { Write-Host "  $_" }