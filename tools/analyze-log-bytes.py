#!/usr/bin/env python3
"""
Analyze a Tesla steering LIN capture session directory.
Supports two log formats:
  - Old car-day format:  UTF-16,  "[HH:MM:SS] XIAO> #N ID=0x.. data: .."
  - New guided format:   UTF-8,   "HH:MM:SS.mmm #N ID=0x.. data: .."

Action window classification:
  - Guided sessions (manifest has wall_start/wall_end): uses wall-clock times.
  - Old sessions: uses elapsed-second offsets from start of log.

Usage:
    python analyze-log-bytes.py <session_dir>
"""

import re
import sys
import os
import json
from collections import defaultdict
from datetime import datetime, date

SESSION_DIR = sys.argv[1] if len(sys.argv) > 1 else "."

# -- Find log file and manifest -------------------------------------------------
def find_log(session_dir):
    for name in os.listdir(session_dir):
        if name.startswith("xiao-guided-serial") and name.endswith(".log"):
            return os.path.join(session_dir, name), "guided"
        if name.startswith("car-day-") and name.endswith(".log"):
            return os.path.join(session_dir, name), "car-day"
    return None, None

def load_manifest(session_dir):
    p = os.path.join(session_dir, "manifest.json")
    if os.path.exists(p):
        with open(p, "r", encoding="utf-8-sig") as f:
            return json.load(f)
    return None

log_file, log_format = find_log(SESSION_DIR)
if not log_file:
    print("ERROR: No xiao-guided-serial*.log or car-day-*.log found in", SESSION_DIR)
    sys.exit(1)

print(f"Analyzing: {log_file}  (format={log_format})")
manifest = load_manifest(SESSION_DIR)

# -- Regex patterns -------------------------------------------------------------
# Guided: "20:55:31.123 #91530 ID=0x28 ..."
GUIDED_RE = re.compile(
    r'^(\d{2}:\d{2}:\d{2}\.\d{3})\s+'
    r'#\d+\s+ID=(0x[0-9A-Fa-f]+)\s+PID=(0x[0-9A-Fa-f]+)\s+\[\d+B.*?\]\s+data:\s+([0-9A-Fa-f ]+?)\s*\|'
)
# Old car-day: "[20:41:34] XIAO> #24402 ID=0x2A ..."
CARDAY_RE = re.compile(
    r'\[(\d{2}:\d{2}:\d{2})\].*?#\d+\s+ID=(0x[0-9A-Fa-f]+)\s+PID=(0x[0-9A-Fa-f]+)\s+\[\d+B.*?\]\s+data:\s+([0-9A-Fa-f ]+?)\s*\|'
)

# -- Build action window classifier --------------------------------------------
# Returns a function: timestamp (datetime) -> window_name (str)
today = date.today()

def _dt(ts_str, has_ms=False):
    fmt = "%H:%M:%S.%f" if has_ms else "%H:%M:%S"
    t = datetime.strptime(ts_str, fmt)
    return datetime(today.year, today.month, today.day, t.hour, t.minute, t.second,
                    t.microsecond)

if manifest and manifest.get("action_windows") and \
   "wall_start" in manifest["action_windows"][0]:
    # Guided format: use wall-clock ranges from manifest
    windows = []
    for w in manifest["action_windows"]:
        # ISO 8601 with offset - strip offset for naive compare
        ws = w["wall_start"][:19]
        we = w["wall_end"][:19]
        windows.append((w["name"], datetime.fromisoformat(ws), datetime.fromisoformat(we)))

    def classify_window(ts):
        for name, ws, we in windows:
            # normalize ts to same date as window (handles midnight crossings)
            ts_n = ts.replace(year=ws.year, month=ws.month, day=ws.day)
            if ws <= ts_n <= we:
                return name
        return "outside-windows"

else:
    # Old format: elapsed-second offsets
    OLD_WINDOWS = [
        ("baseline-idle",         0,   30),
        ("left-scroll-up",       30,   45),
        ("idle-after-left-up",   45,   60),
        ("left-scroll-down",     60,   75),
        ("idle-after-left-down", 75,   90),
        ("left-wheel-click",     90,  105),
        ("idle-before-right",   105,  120),
        ("right-scroll-up",     120,  135),
        ("right-scroll-down",   135,  150),
        ("right-wheel-click",   150,  165),
        ("final-idle",          165,  180),
    ]
    _start_ref = [None]

    def classify_window(ts):
        if _start_ref[0] is None:
            _start_ref[0] = ts
        elapsed = (ts - _start_ref[0]).total_seconds()
        for name, s, e in OLD_WINDOWS:
            if s <= elapsed < e:
                return name
        return "post-capture" if elapsed >= 0 else "pre-capture"

# -- Parse log file -------------------------------------------------------------
def open_log(path, fmt):
    if fmt == "guided":
        return open(path, "r", encoding="utf-8", errors="replace")
    # Old car-day: PowerShell Out-File default = UTF-16 LE
    try:
        return open(path, "r", encoding="utf-16", errors="replace")
    except Exception:
        return open(path, "r", encoding="utf-8", errors="replace")

frames = []
print("Parsing frames...")
with open_log(log_file, log_format) as f:
    for line in f:
        if log_format == "guided":
            m = GUIDED_RE.match(line)
            if not m:
                continue
            ts_str, id_hex, pid_hex, data_str = m.groups()
            ts = _dt(ts_str, has_ms=True)
        else:
            m = CARDAY_RE.search(line)
            if not m:
                continue
            ts_str, id_hex, pid_hex, data_str = m.groups()
            ts = _dt(ts_str, has_ms=False)

        data_bytes = bytes(int(x, 16) for x in data_str.strip().split())
        lid = int(id_hex, 16)
        win = classify_window(ts)
        frames.append({
            "ts":     ts,
            "window": win,
            "id":     lid,
            "id_hex": id_hex.upper(),
            "data":   data_bytes,
        })

if not frames:
    print("  No frames found - check log file and encoding.")
    sys.exit(1)

first_ts = frames[0]["ts"].strftime("%H:%M:%S")
last_ts  = frames[-1]["ts"].strftime("%H:%M:%S")
print(f"  Parsed {len(frames)} frames  ({first_ts} -> {last_ts})")

# -- Per-ID, per-window byte value sets ----------------------------------------
# id -> window -> byte_pos -> set(values)
id_window_bytes = defaultdict(lambda: defaultdict(lambda: defaultdict(set)))

for fr in frames:
    lid = fr["id"]
    win = fr["window"]
    for pos, val in enumerate(fr["data"]):
        id_window_bytes[lid][win][pos].add(val)

# Collect all window names seen, ordered as they appear in manifest (or sort)
if manifest and manifest.get("action_windows"):
    ALL_WINDOWS_ORDERED = [w["name"] for w in manifest["action_windows"]]
    CONTROL_WINDOWS = {w["name"] for w in manifest["action_windows"]
                       if w.get("type") == "action"}
    IDLE_WINDOWS    = {w["name"] for w in manifest["action_windows"]
                       if w.get("type") == "auto"}
else:
    ALL_WINDOWS_ORDERED = [
        "baseline-idle", "left-scroll-up", "idle-after-left-up",
        "left-scroll-down", "idle-after-left-down", "left-wheel-click",
        "idle-before-right", "right-scroll-up", "right-scroll-down",
        "right-wheel-click", "final-idle",
    ]
    CONTROL_WINDOWS = {"left-scroll-up", "left-scroll-down", "left-wheel-click",
                       "right-scroll-up", "right-scroll-down", "right-wheel-click"}
    IDLE_WINDOWS    = {n for n in ALL_WINDOWS_ORDERED if n not in CONTROL_WINDOWS}

# -- Byte-level analysis --------------------------------------------------------
INTERESTING_IDS = sorted(id_window_bytes.keys())
candidate_signals = []

print("\n" + "=" * 80)
print("BYTE-LEVEL ANALYSIS BY LIN ID AND ACTION WINDOW")
print("=" * 80)

for lid in INTERESTING_IDS:
    id_str   = f"0x{lid:02X}"
    win_data = id_window_bytes[lid]
    present  = sorted(win_data.keys())

    all_lens = [max(pos_vals.keys()) + 1 for pos_vals in win_data.values() if pos_vals]
    data_len = max(all_lens) if all_lens else 0

    print(f"\nID {id_str} ({data_len} bytes):")
    print(f"  Windows: {', '.join(present)}")

    for pos in range(data_len):
        idle_vals = set()
        ctrl_vals = set()
        for win in IDLE_WINDOWS:
            if win in win_data and pos in win_data[win]:
                idle_vals.update(win_data[win][pos])
        for win in CONTROL_WINDOWS:
            if win in win_data and pos in win_data[win]:
                ctrl_vals.update(win_data[win][pos])

        control_unique = ctrl_vals - idle_vals
        idle_unique    = idle_vals - ctrl_vals

        if control_unique or idle_unique:
            hex_idle = "{" + ", ".join(f"0x{v:02X}" for v in sorted(idle_vals)) + "}"
            hex_ctrl = "{" + ", ".join(f"0x{v:02X}" for v in sorted(ctrl_vals)) + "}"
            print(f"  byte[{pos}]: idle={hex_idle}  ctrl={hex_ctrl}  ** DIFFERS **")
            candidate_signals.append((id_str, pos, idle_vals, ctrl_vals))
        else:
            all_vals = idle_vals | ctrl_vals
            if len(all_vals) <= 4:
                hex_all = "{" + ", ".join(f"0x{v:02X}" for v in sorted(all_vals)) + "}"
                print(f"  byte[{pos}]: stable={hex_all}")
            else:
                print(f"  byte[{pos}]: {len(all_vals)} distinct values (counter/noise)")

# -- Per-window detail for candidate bytes -------------------------------------
print("\n" + "=" * 80)
print("PER-WINDOW DETAIL FOR CANDIDATE CONTROL BYTES")
print("=" * 80)

for id_str, pos, idle_vals, ctrl_vals in candidate_signals:
    lid = int(id_str, 16)
    print(f"\n  {id_str} byte[{pos}] - control candidate")
    for win_name in ALL_WINDOWS_ORDERED:
        win_data = id_window_bytes[lid]
        marker   = " <<" if win_name in CONTROL_WINDOWS else ""
        if win_name in win_data and pos in win_data[win_name]:
            vals     = sorted(win_data[win_name][pos])
            hex_vals = ", ".join(f"0x{v:02X}" for v in vals)
            print(f"    {win_name:32s}: {hex_vals}{marker}")
        else:
            print(f"    {win_name:32s}: (no data)")

# -- Frame counts per window ----------------------------------------------------
print("\n" + "=" * 80)
print("FRAME COUNTS PER ACTION WINDOW")
print("=" * 80)
win_counts = defaultdict(lambda: defaultdict(int))
for fr in frames:
    win_counts[fr["window"]][fr["id"]] += 1

all_seen_wins = sorted(set(fr["window"] for fr in frames),
                       key=lambda n: ALL_WINDOWS_ORDERED.index(n)
                       if n in ALL_WINDOWS_ORDERED else 999)
for win_name in all_seen_wins:
    total   = sum(win_counts[win_name].values())
    ids     = sorted(win_counts[win_name].keys())
    id_list = " ".join(f"0x{i:02X}:{win_counts[win_name][i]}" for i in ids)
    marker  = " <<" if win_name in CONTROL_WINDOWS else ""
    print(f"  {win_name:32s}: {total:5d} frames  {id_list}{marker}")

# -- Summary --------------------------------------------------------------------
print("\n" + "=" * 80)
print("SUMMARY: CANDIDATE CONTROL BYTES")
print("=" * 80)
if candidate_signals:
    for id_str, pos, idle_vals, ctrl_vals in candidate_signals:
        idle_hex = ", ".join(f"0x{v:02X}" for v in sorted(idle_vals))
        ctrl_hex = ", ".join(f"0x{v:02X}" for v in sorted(ctrl_vals))
        print(f"  {id_str} byte[{pos}]:  idle=[{idle_hex}]  control=[{ctrl_hex}]")
else:
    print("  No candidate bytes found.")
    if not (CONTROL_WINDOWS & set(w for fr in frames for w in [fr["window"]])):
        print("  NOTE: No frames were classified into control windows.")
        print("  This likely means no actions were performed during the capture.")

print(f"\nAnalysis complete. Total frames: {len(frames)}")
