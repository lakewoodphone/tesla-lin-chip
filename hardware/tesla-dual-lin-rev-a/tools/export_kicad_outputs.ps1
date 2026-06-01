$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$kicadDir = Join-Path $projectRoot 'kicad'
$outDir = Join-Path $projectRoot 'build\kicad-outputs'
$schematic = Join-Path $kicadDir 'tesla-dual-lin-rev-a.kicad_sch'
$board = Join-Path $kicadDir 'tesla-dual-lin-rev-a.kicad_pcb'

function Resolve-KiCadCli {
  $command = Get-Command kicad-cli -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\KiCad\10.0\bin\kicad-cli.exe'),
    'C:\Program Files\KiCad\10.0\bin\kicad-cli.exe'
  )

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) { return $candidate }
  }

  return $null
}

$kicadCli = Resolve-KiCadCli
if (-not $kicadCli) {
  throw 'kicad-cli was not found on PATH. Install KiCad 10.x first.'
}

if (-not (Test-Path $schematic)) {
  throw "Missing schematic: $schematic"
}

if (-not (Test-Path $board)) {
  throw "Missing board file: $board"
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outDir 'gerbers') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outDir 'drill') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outDir 'reports') | Out-Null

& $kicadCli sch erc --output (Join-Path $outDir 'reports\erc.rpt') $schematic
& $kicadCli pcb drc --output (Join-Path $outDir 'reports\drc.rpt') $board
& $kicadCli sch export pdf --output (Join-Path $outDir 'schematic.pdf') $schematic
& $kicadCli sch export bom --output (Join-Path $outDir 'bom.csv') $schematic
$fabLayers = 'F.Cu,In1.Cu,In2.Cu,B.Cu,F.Paste,B.Paste,F.Silkscreen,B.Silkscreen,F.Mask,B.Mask,Edge.Cuts,F.Fab,B.Fab'
& $kicadCli pcb export gerbers --layers $fabLayers --subtract-soldermask --output (Join-Path $outDir 'gerbers') $board
& $kicadCli pcb export drill --output (Join-Path $outDir 'drill') $board
& $kicadCli pcb export pos --format csv --side both --output (Join-Path $outDir 'cpl.csv') $board

Write-Host "KiCad outputs exported to $outDir"