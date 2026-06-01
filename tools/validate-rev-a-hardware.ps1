$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $repo 'hardware\tesla-dual-lin-rev-a\tools\validate_rev_a_inputs.py'
if (-not (Test-Path $validator)) {
  throw "Missing validator: $validator"
}
python $validator