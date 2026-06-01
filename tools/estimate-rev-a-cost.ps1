$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$estimator = Join-Path $repo 'hardware\tesla-dual-lin-rev-a\tools\estimate_rev_a_cost.py'
if (-not (Test-Path $estimator)) {
  throw "Missing estimator: $estimator"
}
python $estimator