<#
.SYNOPSIS
  Full PCB pipeline for tesla-dual-lin-rev-a: generate -> ERC -> DSN -> FreeRoute -> import SES -> DRC.

.DESCRIPTION
  Deterministic, headless route of the generated board. Produces a fully-routed
  board at build\tesla-dual-lin-rev-a-routed.kicad_pcb and a DRC report.

  Requirements:
    - KiCad 10 at C:\Users\<user>\AppData\Local\Programs\KiCad\10.0
    - Microsoft OpenJDK 21
    - FreeRouting 2.1.0 jar at tools\freerouting\freerouting-2.1.0.jar
#>
[CmdletBinding()]
param(
  [int]$Passes = 30,
  [switch]$SkipGenerate
)

$ErrorActionPreference = 'Stop'
# $PSScriptRoot = ...\xiao-lin-bench\hardware\tesla-dual-lin-rev-a\tools
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
Set-Location $repo

$kicad = "$env:LOCALAPPDATA\Programs\KiCad\10.0\bin"
$cli   = Join-Path $kicad 'kicad-cli.exe'
$kpy   = Join-Path $kicad 'python.exe'
$java  = 'C:\Program Files\Microsoft\jdk-21.0.11.10-hotspot\bin\java.exe'
$jar   = Join-Path $repo 'tools\freerouting\freerouting-2.1.0.jar'

$base  = 'hardware\tesla-dual-lin-rev-a'
$sch   = "$base\kicad\tesla-dual-lin-rev-a.kicad_sch"
$pcb   = "$base\kicad\tesla-dual-lin-rev-a.kicad_pcb"
$dsn   = "$base\build\tesla-dual-lin-rev-a.dsn"
$ses   = "$base\build\tesla-dual-lin-rev-a.ses"
# Route in place on the in-project board: keeping the basename means the sibling
# .kicad_pro + fp-lib-table load during DRC, so the cosmetic
# 'lib_footprint_issues' warnings do not appear. 'generate' reproduces the
# unrouted source deterministically, so it is fine to route over it.
$routed= $pcb
$rlog  = "$base\build\_route.log"
$rpt   = "$base\build\_drc-routed.rpt"
New-Item -ItemType Directory -Force -Path "$base\build" | Out-Null

if (-not $SkipGenerate) {
  Write-Host '=== GENERATE ===' -ForegroundColor Cyan
  & python "$base\tools\generate_kicad_rev_a.py"
  if ($LASTEXITCODE) { throw "generate failed ($LASTEXITCODE)" }
}

Write-Host '=== ERC ===' -ForegroundColor Cyan
& $cli sch erc --exit-code-violations $sch 2>&1 | Select-String 'Found'
$ercExit = $LASTEXITCODE

Write-Host '=== EXPORT DSN ===' -ForegroundColor Cyan
& $kpy "$base\tools\_export_dsn.py" $pcb $dsn 2>&1 | Select-String 'EXPORT_DSN'
if ($LASTEXITCODE) { throw "DSN export failed" }

# Pristine unrouted board: routing/import happen in place on $pcb, so keep a
# clean copy to restore before each route attempt.
$pristine = "$base\build\_unrouted.kicad_pcb"
Copy-Item $pcb $pristine -Force

# Outer verification loop: FreeRouting is stochastic, so re-roll the whole
# route -> import -> GND-stitch -> DRC cycle until DRC itself confirms 0
# unconnected items (the ground-truth gate). The DSN is fixed; each FreeRouting
# run explores a different solution. This makes the final board deterministic
# in outcome (always fully connected) even though routing is stochastic.
$maxAttempts = 20
$cleanRoute = $false
$bestUnconn = [int]::MaxValue
for ($a = 1; $a -le $maxAttempts; $a++) {
  Copy-Item $pristine $pcb -Force
  if (Test-Path $ses) { Remove-Item $ses }
  & $java -jar $jar -de $dsn -do $ses -mp $Passes *> $rlog
  if (-not (Test-Path $ses)) { Write-Host ("  attempt {0}: no SES" -f $a) -ForegroundColor Red; continue }
  $done = (Get-Content $rlog | Select-String 'Auto-routing was completed' | Select-Object -Last 1).Line
  $unr = if ($done -match 'unrouted') { [int][regex]::Match($done, '\((\d+) unrouted\)').Groups[1].Value } else { 0 }

  & $kpy "$base\tools\_import_ses.py" $routed $ses $routed *>$null
  & $kpy "$base\tools\_stitch_gnd.py" $routed $routed *>$null
  & $cli pcb drc --refill-zones --save-board --severity-all --format report -o $rpt $routed *>$null
  $unconn = [int]((Get-Content $rpt | Select-String 'Found (\d+) unconnected').Matches.Groups[1].Value)
  if ($unconn -lt $bestUnconn) {
    $bestUnconn = $unconn
    Copy-Item $routed "$routed.best" -Force
  }
  if ($unconn -eq 0) {
    Write-Host ("  attempt {0}: routed={1} unrouted -> 0 unconnected (clean)" -f $a, $unr) -ForegroundColor Green
    $cleanRoute = $true
    break
  }
  Write-Host ("  attempt {0}: routed={1} unrouted -> {2} unconnected (best {3}) - re-rolling" -f $a, $unr, $unconn, $bestUnconn) -ForegroundColor DarkYellow
}
if (-not $cleanRoute) {
  if (Test-Path "$routed.best") { Copy-Item "$routed.best" $routed -Force }
  Write-Host ("  WARNING: no fully-connected route in {0} attempts (best {1} unconnected)" -f $maxAttempts, $bestUnconn) -ForegroundColor Red
}

Write-Host '=== DRC (final) ===' -ForegroundColor Cyan
& $cli pcb drc --refill-zones --save-board --severity-all --format report -o $rpt $routed 2>&1 | Select-String 'Found'

Write-Host '--- violation summary ---' -ForegroundColor Yellow
Get-Content $rpt |
  Select-String -Pattern '^\[([^\]]+)\]' |
  ForEach-Object { ($_ -replace '^\[([^\]]+)\].*', '$1') } |
  Group-Object | Sort-Object Count -Descending |
  Format-Table Count, Name -AutoSize

Write-Host '=== FAB OUTPUTS ===' -ForegroundColor Cyan
$fab = "$base\build\fab"
if (Test-Path $fab) { Remove-Item $fab -Recurse -Force }
New-Item -ItemType Directory -Force -Path $fab | Out-Null

# Gerbers (standard fab layer set only) + Excellon drill (board-origin so the
# fab aligns layers).
$fabLayers = 'F.Cu,In1.Cu,In2.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts'
& $cli pcb export gerbers --output "$fab\" --layers $fabLayers --no-protel-ext $routed 2>&1 |
    Select-String -Pattern 'Plotted|Created|error' | Select-Object -Last 1
& $cli pcb export drill --output "$fab\" --format excellon --drill-origin absolute `
    --excellon-units mm --generate-map --map-format gerberx2 $routed 2>&1 |
    Select-String -Pattern 'Created|drill|error' | Select-Object -Last 1

# Pick-and-place centroid (CPL) for both sides, mm, CSV.
& $cli pcb export pos --output "$fab\tesla-dual-lin-rev-a-cpl.csv" --side both `
    --format csv --units mm --use-drill-file-origin $routed 2>&1 |
    Select-String -Pattern 'Wrote|error' | Select-Object -Last 1

# BOM from the schematic (grouped by Value+Footprint).
& $cli sch export bom --output "$fab\tesla-dual-lin-rev-a-bom.csv" `
    --group-by 'Value,Footprint' `
    --fields 'Reference,Value,Footprint,${QUANTITY},${DNP}' `
    --labels 'Refs,Value,Footprint,Qty,DNP' $sch 2>&1 |
    Select-String -Pattern 'Wrote|error' | Select-Object -Last 1

# Zip gerbers + drill for the manufacturer.
$zip = "$base\build\tesla-dual-lin-rev-a-gerbers.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$fab\*.gbr", "$fab\*.gbrjob", "$fab\*.drl" -DestinationPath $zip -ErrorAction SilentlyContinue
Write-Host ("  fab dir: {0} ({1} files); zip: {2}" -f $fab, (Get-ChildItem $fab).Count, $zip)

Write-Host "ERC_EXIT=$ercExit  Report: $rpt" -ForegroundColor Green
