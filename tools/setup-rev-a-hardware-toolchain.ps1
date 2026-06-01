$ErrorActionPreference = 'Stop'

function Test-KiCadCli {
  $command = Get-Command kicad-cli -ErrorAction SilentlyContinue
  if ($command) {
    kicad-cli version
    return $true
  }

  $candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\KiCad\10.0\bin\kicad-cli.exe'),
    'C:\Program Files\KiCad\10.0\bin\kicad-cli.exe'
  )
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      & $candidate version
      Write-Host "KiCad CLI available at $candidate"
      return $true
    }
  }

  return $false
}

if (Test-KiCadCli) {
  Write-Host 'KiCad CLI already available.'
  exit 0
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw 'winget is required for automated KiCad install on this workstation.'
}

$ProgressPreference = 'SilentlyContinue'
winget install --id KiCad.KiCad --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity --silent

if (-not (Test-KiCadCli)) {
  throw 'KiCad install finished, but kicad-cli was not found.'
}