param(
  [string] $PcbPath = '',
  [double] $MaxWidthMm = 70.0,
  [double] $MaxHeightMm = 42.0,
  [double] $TestPadCenterClearanceMm = 2.0,
  [string] $UsbAccessArtifact = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repo 'hardware\tesla-dual-lin-rev-a\tools\check_physical_layout_gates.py'
if (-not (Test-Path $script)) {
  throw "Missing physical layout gate checker: $script"
}

$argsList = @(
  $script,
  '--max-width-mm', $MaxWidthMm,
  '--max-height-mm', $MaxHeightMm,
  '--testpad-center-clearance-mm', $TestPadCenterClearanceMm
)

if ($PcbPath) {
  $argsList += @('--pcb', $PcbPath)
}
if ($UsbAccessArtifact) {
  $argsList += @('--usb-access-artifact', $UsbAccessArtifact)
}

python @argsList