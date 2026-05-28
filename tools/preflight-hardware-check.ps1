<#
.SYNOPSIS
    Record a bench or passive-car hardware preflight checklist.

.DESCRIPTION
    Prompts for the critical physical checks that cannot be inferred from
    software: power, common ground, SLP, RX/TX continuity, and whether the TX
    path is physically disconnected for passive vehicle work. Writes a Markdown
    artifact in logs/preflight-*.
#>

param(
    [ValidateSet("bench", "car-passive", "chip-lab")]
    [string] $Mode = "bench",
    [string] $LogDir = "",
    [switch] $RequirePass
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $LogDir) { $LogDir = Join-Path $repoRoot "logs" }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outPath = Join-Path $LogDir "preflight-${Mode}-${stamp}.md"

function Ask-Check([string] $Prompt) {
    $answer = Read-Host "$Prompt [y/N or value]"
    if (-not $answer) { $answer = "no" }
    return $answer
}

function Test-YesOrMeasured([string] $Value) {
    if (-not $Value) { return $false }
    return $Value -match '^(y|yes|ok|pass|true|verified|measured|[0-9]+(\.[0-9]+)?\s*v?)$'
}

function Test-TxPassive([string] $Value) {
    if (-not $Value) { return $false }
    return $Value -match '(disconnect|disconnected|off|open|removed|isolated|no|none)'
}

$checks = [ordered]@{}
$checks["mode"] = $Mode
$checks["timestamp"] = (Get-Date).ToString("s")
$checks["12v_present"] = Ask-Check "12V present at APG/module bus input"
$checks["common_ground"] = Ask-Check "APG, TJA1021, level shifter, XIAO share ground"
$checks["slp_high"] = Ask-Check "TJA1021 SLP is high / transceiver awake"
$checks["lin_idle_voltage"] = Ask-Check "LIN idle voltage measured"
$checks["rx_path"] = Ask-Check "Module RX -> level shifter -> XIAO D3 continuity verified"
$checks["tx_path"] = Ask-Check "XIAO D2 -> level shifter -> module TX continuity verified or intentionally disconnected"
$checks["tx_physical_state"] = Ask-Check "TX physical enable state (disconnected/off/on)"
$checks["com_port_free"] = Ask-Check "XIAO COM port is free"
$checks["apg_present"] = Ask-Check "APGDT001 present and visible"
$checks["notes"] = Ask-Check "Notes"

if ($Mode -eq "car-passive" -and $checks["tx_physical_state"] -notmatch "disconnect|off|no") {
    Write-Warning "Passive car mode expects the active TX path physically disconnected or off."
}

$failures = New-Object System.Collections.Generic.List[string]
foreach ($key in @("12v_present", "common_ground", "slp_high", "rx_path", "com_port_free", "apg_present")) {
    if (-not (Test-YesOrMeasured $checks[$key])) { [void]$failures.Add($key) }
}

if ($Mode -eq "car-passive") {
    if (-not (Test-TxPassive $checks["tx_physical_state"])) { [void]$failures.Add("tx_physical_state_not_passive") }
}

$result = if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }

$lines = @(
    "# Hardware Preflight $stamp",
    "",
    "- Mode: $Mode",
    "- Created: $($checks['timestamp'])",
    "- Result: $result",
    "- Failures: $(if ($failures.Count) { $failures -join ', ' } else { 'none' })",
    "",
    "| Check | Result |",
    "|---|---|"
)

foreach ($key in $checks.Keys) {
    if ($key -in @("mode", "timestamp")) { continue }
    $lines += "| $key | $($checks[$key]) |"
}

$lines | Out-File -FilePath $outPath -Encoding utf8
Write-Host "Preflight written: $outPath" -ForegroundColor Green
if ($result -eq "PASS") {
    Write-Host "Preflight result: PASS" -ForegroundColor Green
} else {
    Write-Warning "Preflight result: FAIL ($($failures -join ', '))"
    if ($RequirePass -or $Mode -eq "car-passive") { exit 1 }
}