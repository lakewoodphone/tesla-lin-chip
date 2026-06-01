param(
  [string] $Port = '',
  [string] $BoardSerial = 'REV-A-UNASSIGNED',
  [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repo 'hardware\tesla-dual-lin-rev-a\tools\rev_a_first_article_check.py'
if (-not (Test-Path $script)) {
  throw "Missing first-article checker: $script"
}

$argsList = @($script, '--board-serial', $BoardSerial)
if ($DryRun) { $argsList += '--dry-run' }
if ($Port) { $argsList += @('--port', $Port) }

python @argsList