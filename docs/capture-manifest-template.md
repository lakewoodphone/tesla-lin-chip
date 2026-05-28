# LIN Capture Manifest Template

Use `tools/new-capture-session.ps1` to create a real session folder. This file documents the required fields.

```json
{
  "schema": "xiao-lin-capture-session-v1",
  "created_at": "2026-05-27T00:00:00Z",
  "mode": "car-passive",
  "vehicle_id": "tesla-model-y-example",
  "baud": 19200,
  "capture_point": "non-invasive probe point and wire colors",
  "firmware_expected": "field_passive",
  "active_tx_allowed": false,
  "notes": "operator notes",
  "artifacts": {
    "apg_csv": "lin-capture-*.csv",
    "apg_txt": "lin-capture-*.txt",
    "xiao_serial": "xiao-serial.log",
    "analyzer_json": "analysis.json",
    "photos": []
  },
  "action_windows": [
    { "name": "baseline-idle", "start_ms": 0, "end_ms": 120000, "notes": "No controls touched" },
    { "name": "steering-scroll-up", "start_ms": 0, "end_ms": 0, "notes": "Fill after capture" },
    { "name": "steering-scroll-down", "start_ms": 0, "end_ms": 0, "notes": "Fill after capture" },
    { "name": "wheel-click", "start_ms": 0, "end_ms": 0, "notes": "Fill after capture" }
  ]
}
```

Rules:

- Vehicle sessions must use `mode=car-passive` and `active_tx_allowed=false`.
- Record firmware `version` and `config` serial output before capture.
- Keep raw APG logs, XIAO serial logs, analyzer JSON, and photos in the session folder.
- Do not edit firmware profiles from one capture. Require repeated passive captures that agree.