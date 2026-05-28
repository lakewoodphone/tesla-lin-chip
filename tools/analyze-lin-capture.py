#!/usr/bin/env python3
r"""LIN capture analyzer for Tesla (Model 3/Y/X) - post-capture ID labeling + reference.

Usage:
    python tools\analyze-lin-capture.py logs\lin-capture-20260526_140000.csv
    python tools\analyze-lin-capture.py logs\ --latest

Given a CSV from monitor-apg-lin-bus.ps1, produces:
    - Per-ID frame counts, rates, unique payloads
    - Known-ID labeling using Tesla model reference tables
    - Unknown-ID alert
    - Payload variant heatmap per ID
"""

import csv, json, sys, os
from collections import defaultdict
from datetime import datetime, timezone

# =========================================================================
# TESLA KNOWN LIN ID REFERENCE TABLES
# =========================================================================
# These are compiled from real Model X captures (Moti Zaks, 2026-05-17).
# Model 3/Y IDs may differ - use these as a starting reference to compare
# against real captures. Unknown IDs are flagged, not assumed.
#
# LIN format: 19200 baud, enhanced checksum (LIN 2.x), 8 data bytes.
# PID is computed from raw ID (id & 0x3F) with parity bits.
# =========================================================================

ID_REFERENCE = {
    # === Model X steering-wheel SW bus (confirmed from field capture) ===
    "0x0C": {
        "model": "X",
        "bus": "SW (steering wheel)",
        "label": "Scroll/control",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Carries scroll wheel position (B0), button engage (B1), "
                 "rate (B2), accumulator (B3). B0=0x10=neutral, >0x10=UP, <0x10=DOWN.",
        "payload_candidates": {
            "idle":   "10 00 00 00 00 00 C0 <ctr>",
            "engage": "10 04 00 00 00 00 C0 <ctr>",
            "scroll_up": "1x 04/00 yy zz 00 00 C0 <ctr>",
            "scroll_dn": "0x 04/00 yy zz 00 00 C0 <ctr>",
        },
        "priority": "HIGH",
    },
    "0x0D": {
        "model": "X",
        "bus": "SW (steering wheel)",
        "label": "Passive mirror / response",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Same rate as 0x0C but only 17 unique payloads in 60s - "
                 "almost entirely counter variation. Not control-bearing.",
        "priority": "LOW",
    },
    "0x0E": {
        "model": "X",
        "bus": "SW (steering wheel)",
        "label": "Alive/heartbeat (1-bit toggle)",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Alternates between 0x50/0x51 first byte. Classic alive toggle.",
        "priority": "LOW",
    },
    "0x0F": {
        "model": "X",
        "bus": "SW (steering wheel)",
        "label": "Alive/heartbeat (1-bit toggle)",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Same as 0x0E - alternates 0x50/0x51. Seat/occupancy signal?",
        "priority": "LOW",
    },
    "0x16": {
        "model": "X",
        "bus": "SW (steering wheel)",
        "label": "Config/version frame",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Completely static across all captures.",
        "priority": "INFO",
    },
    "0x17": {
        "model": "X",
        "bus": "SW (steering wheel)",
        "label": "Config/version frame",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Completely static across all captures.",
        "priority": "INFO",
    },
    # === Model 3/Y candidates (from community reports - NOT YET CONFIRMED) ===
    "0x1A": {
        "model": "3/Y",
        "bus": "steering",
        "label": "CANDIDATE - scroll/buttons?",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Unconfirmed, reported in community as possible steering ID. "
                 "Capture and check B0/scroll correlation.",
        "priority": "INVESTIGATE",
    },
    "0x1B": {
        "model": "3/Y",
        "bus": "steering",
        "label": "CANDIDATE - scroll/buttons?",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Unconfirmed alternative steering ID candidate.",
        "priority": "INVESTIGATE",
    },
    "0x3C": {
        "model": "all",
        "bus": "diagnostic",
        "label": "Diagnostic / bulk",
        "length": 8,
        "checksum": "enhanced or classic",
        "notes": "LIN diagnostic frame (0x3C = 60 = diagnostic range). "
                 "Can be enhanced or classic checksum.",
        "priority": "INFO",
    },
    "0x3D": {
        "model": "all",
        "bus": "diagnostic",
        "label": "Diagnostic response",
        "length": 8,
        "checksum": "classic",
        "notes": "LIN diagnostic response frame. Classic checksum only.",
        "priority": "INFO",
    },
}

# Checksum formula - for verification
def lin_enhanced_checksum(pid: int, data: list) -> int:
    s = pid
    for b in data:
        s += b
        if s > 0xFF:
            s -= 0xFF
    return 0xFF - s

def lin_classic_checksum(data: list) -> int:
    s = 0
    for b in data:
        s += b
        if s > 0xFF:
            s -= 0xFF
    return 0xFF - s

# Protected ID computation
def make_protected_id(raw_id: int) -> int:
    id_mask = raw_id & 0x3F
    id0 = (id_mask >> 0) & 1
    id1 = (id_mask >> 1) & 1
    id2 = (id_mask >> 2) & 1
    id3 = (id_mask >> 3) & 1
    id4 = (id_mask >> 4) & 1
    id5 = (id_mask >> 5) & 1
    p0 = id0 ^ id1 ^ id2 ^ id4
    p1 = (~(id1 ^ id3 ^ id4 ^ id5)) & 1
    return id_mask | (p0 << 6) | (p1 << 7)


def load_action_windows(path: str) -> list:
    if not path:
        return []
    with open(path, "r", encoding="utf-8-sig") as f:
        payload = json.load(f)
    windows = payload.get("action_windows", []) if isinstance(payload, dict) else payload
    normalized = []
    for win in windows:
        try:
            start_ms = int(win.get("start_ms", 0))
            end_ms = int(win.get("end_ms", 0))
            if end_ms <= start_ms:
                continue
            normalized.append({
                "name": str(win.get("name", "action")),
                "start_ms": start_ms,
                "end_ms": end_ms,
                "notes": str(win.get("notes", "")),
            })
        except (TypeError, ValueError):
            continue
    return normalized


def analyze_action_windows(frames: list, windows: list) -> list:
    reports = []
    for win in windows:
        duration_ms = max(1, win["end_ms"] - win["start_ms"])
        before_start = max(0, win["start_ms"] - duration_ms)
        before = [f for f in frames if before_start <= f["ts_ms"] < win["start_ms"]]
        during = [f for f in frames if win["start_ms"] <= f["ts_ms"] <= win["end_ms"]]

        before_by_id = defaultdict(list)
        during_by_id = defaultdict(list)
        for f in before:
            before_by_id[f["id_hex"]].append(f)
        for f in during:
            during_by_id[f["id_hex"]].append(f)

        ranked = []
        all_ids = sorted(set(before_by_id.keys()) | set(during_by_id.keys()), key=lambda x: int(x, 16))
        for id_hex in all_ids:
            before_items = before_by_id.get(id_hex, [])
            during_items = during_by_id.get(id_hex, [])
            if not during_items:
                continue
            before_payloads = set(f["data_hex"] for f in before_items)
            during_payloads = set(f["data_hex"] for f in during_items)
            new_payloads = during_payloads - before_payloads
            before_rate = len(before_items) / max(1, duration_ms / 1000)
            during_rate = len(during_items) / max(1, duration_ms / 1000)
            rate_delta = during_rate - before_rate
            score = (len(during_items) * 1.0) + (len(new_payloads) * 5.0) + max(0, rate_delta) * 2.0
            ref = ID_REFERENCE.get(id_hex, {})
            ranked.append({
                "id_hex": id_hex,
                "label": ref.get("label", "UNKNOWN"),
                "priority": ref.get("priority", "UNKNOWN"),
                "during_frames": len(during_items),
                "before_frames": len(before_items),
                "during_unique_payloads": len(during_payloads),
                "new_payloads": sorted(new_payloads)[:10],
                "rate_delta_hz": round(rate_delta, 2),
                "score": round(score, 2),
            })

        ranked.sort(key=lambda row: row["score"], reverse=True)
        reports.append({
            "name": win["name"],
            "start_ms": win["start_ms"],
            "end_ms": win["end_ms"],
            "notes": win.get("notes", ""),
            "ranked_ids": ranked[:12],
        })
    return reports


def build_candidate_profile(csv_path: str, detected_model: str, by_id: dict, window_reports: list) -> dict:
    candidate_scores = defaultdict(float)
    candidate_windows = defaultdict(list)

    for report in window_reports:
        for row in report.get("ranked_ids", []):
            id_hex = row["id_hex"]
            candidate_scores[id_hex] += float(row.get("score", 0))
            candidate_windows[id_hex].append({
                "window": report.get("name", "action"),
                "score": row.get("score", 0),
                "during_frames": row.get("during_frames", 0),
                "new_payloads": row.get("new_payloads", []),
                "rate_delta_hz": row.get("rate_delta_hz", 0),
            })

    if not candidate_scores:
        for id_hex, items in by_id.items():
            ref = ID_REFERENCE.get(id_hex, {})
            priority = ref.get("priority", "UNKNOWN")
            base = {"HIGH": 50, "INVESTIGATE": 25, "UNKNOWN": 10, "INFO": 2, "LOW": 1}.get(priority, 1)
            payloads = set(f["data_hex"] for f in items)
            candidate_scores[id_hex] = base + min(len(payloads), 20)

    candidates = []
    for id_hex, score in sorted(candidate_scores.items(), key=lambda kv: kv[1], reverse=True):
        items = by_id.get(id_hex, [])
        if not items:
            continue
        ref = ID_REFERENCE.get(id_hex, {})
        payloads = defaultdict(int)
        for f in items:
            payloads[f["data_hex"]] += 1
        candidates.append({
            "id_hex": id_hex,
            "id_dec": int(id_hex, 16),
            "label": ref.get("label", "UNKNOWN"),
            "reference_priority": ref.get("priority", "UNKNOWN"),
            "reference_model": ref.get("model", "unknown"),
            "frame_count": len(items),
            "unique_payloads": len(payloads),
            "score": round(score, 2),
            "top_payloads": [
                {"data_hex": data_hex, "count": count}
                for data_hex, count in sorted(payloads.items(), key=lambda kv: -kv[1])[:10]
            ],
            "action_windows": candidate_windows.get(id_hex, []),
        })

    return {
        "schema": "xiao-lin-profile-candidate-v1",
        "source_csv": csv_path,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "detected_model": detected_model,
        "review_only": True,
        "active_profile_update_allowed": False,
        "minimum_review_gate": "Require at least two passive captures with matching ranked IDs before editing firmware profiles.",
        "candidates": candidates[:16],
    }


def analyze_csv(csv_path: str, output_json: str = "", action_windows: list | None = None, candidate_json: str = ""):
    if not os.path.exists(csv_path):
        print(f"ERROR: CSV not found: {csv_path}")
        sys.exit(1)

    print(f"Reading: {csv_path}")
    print()

    # Parse CSV
    frames = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                frames.append({
                    "ts_ms": int(row.get("timestamp_ms", 0)),
                    "id_hex": row.get("id_hex", "").strip(),
                    "id_dec": int(row.get("id_dec", 0)),
                    "pid_hex": row.get("pid_hex", "").strip(),
                    "data_len": int(row.get("data_len", 0)),
                    "data_hex": row.get("data_hex", "").strip().replace("-", " "),
                    "rx_checksum": row.get("rx_checksum", row.get("checksum", row.get("chk", ""))).strip(),
                    "error": int(row.get("error", 0)),
                    "baud": int(row.get("baud", 0)),
                })
            except (ValueError, KeyError) as e:
                print(f"  WARN: skipping row - {e}: {row}")

    if not frames:
        print("No valid frames found.")
        return

    # Group by ID
    by_id = defaultdict(list)
    for f in frames:
        by_id[f["id_hex"]].append(f)

    # Stats
    total_frames = len(frames)
    duration_ms = frames[-1]["ts_ms"] - frames[0]["ts_ms"] if len(frames) > 1 else 1
    duration_s = max(1, duration_ms / 1000)
    overall_rate = total_frames / duration_s

    print("=" * 72)
    print(f"LIN CAPTURE ANALYSIS")
    print(f"  {total_frames} frames over {duration_s:.1f}s ({overall_rate:.1f} Hz)")
    print(f"  Unique IDs: {len(by_id)}")
    print()

    # Detect Tesla model from IDs present
    model_scores = {"X": 0, "3/Y": 0}
    for id_hex in by_id:
        if id_hex in ID_REFERENCE:
            ref = ID_REFERENCE[id_hex]
            m = ref["model"]
            if m in model_scores:
                model_scores[m] += by_id[id_hex][0]["baud"]  # weight by baud
    detected_model = max(model_scores, key=model_scores.get) if max(model_scores.values()) > 0 else "unknown"
    print(f"  Detected model: {detected_model.upper()}")
    print()

    # Per-ID analysis
    unknown_ids = []
    for id_hex in sorted(by_id.keys(), key=lambda x: int(x, 16)):
        items = by_id[id_hex]
        count = len(items)
        first_ms = items[0]["ts_ms"]
        last_ms = items[-1]["ts_ms"]
        span = max(1, last_ms - first_ms)
        rate_hz = (count - 1) / (span / 1000) if span > 0 else 0

        payloads = defaultdict(int)
        for f in items:
            payloads[f["data_hex"]] += 1

        errors = sum(1 for f in items if f["error"] != 0)
        data_len = items[0]["data_len"]

        # Check reference
        ref = ID_REFERENCE.get(id_hex)
        label_str = ""
        priority_str = ""
        notes_str = ""
        checksum_good = True
        if ref:
            label_str = ref["label"]
            priority_str = ref.get("priority", "")
            notes_str = ref.get("notes", "")

            # Check checksum if we have data
            try:
                pid_val = int(items[0]["pid_hex"], 16) if items[0]["pid_hex"] else make_protected_id(int(id_hex, 16))
                for f in items[:20]:  # check first 20
                    if not f.get("rx_checksum"):
                        continue
                    data_bytes = [int(x, 16) for x in f["data_hex"].split() if x]
                    if data_bytes:
                        data_part = data_bytes
                        rx_chk = int(f["rx_checksum"].replace("0x", ""), 16)
                        exp_enh = lin_enhanced_checksum(pid_val, data_part)
                        exp_cls = lin_classic_checksum(data_part)
                        if rx_chk != exp_enh and rx_chk != exp_cls:
                            checksum_good = False
            except Exception:
                pass
        else:
            unknown_ids.append(id_hex)
            label_str = "** UNKNOWN **"
            priority_str = "UNKNOWN"

        # Format sample payloads
        top_payloads = sorted(payloads.items(), key=lambda x: -x[1])[:5]

        print(f"  ID={id_hex:<6}  [{data_len}B]  "
              f"{count:>6} frames  {rate_hz:>6.1f} Hz  "
              f"{len(payloads):>4} variants  "
              f"err={errors:<3}")
        print(f"       [{priority_str:<12}] {label_str}")
        if notes_str:
            print(f"       {notes_str}")
        for pay, pc in top_payloads[:3]:
            print(f"       payload: {pay:<30} x{pc}")
        if not checksum_good:
            print(f"       *** CHECKSUM FAILURES DETECTED ***")
        print()

    # Unknown IDs
    if unknown_ids:
        print("--- UNKNOWN IDS (not in Tesla reference) ---")
        print("These IDs were not recognized from any Tesla model reference.")
        print("Capture their full context (control inputs) to determine meaning.")
        for uid in sorted(unknown_ids, key=lambda x: int(x, 16)):
            items = by_id[uid]
            sample_data = set(f["data_hex"] for f in items[:10])
            print(f"  ID={uid}  {len(items)} frames  samples: {'; '.join(list(sample_data)[:3])}")
        print()

    # Summary by priority
    print("--- PRIORITY SUMMARY ---")
    for pri in ["HIGH", "INVESTIGATE", "LOW", "INFO", "UNKNOWN"]:
        ids_in_pri = []
        for id_hex in sorted(by_id.keys(), key=lambda x: int(x, 16)):
            ref = ID_REFERENCE.get(id_hex)
            p = ref.get("priority", "UNKNOWN") if ref else "UNKNOWN"
            if p == pri:
                ids_in_pri.append(f"{id_hex} ({len(by_id[id_hex])} frames)")
        if ids_in_pri:
            print(f"  {pri:<12}: {', '.join(ids_in_pri)}")
    print()

    # Anti-nag payload generation (for any HIGH ID with known structure)
    if "0x0C" in by_id:
        pid_val = make_protected_id(0x0C)
        print("--- ANTI-NAG INJECTION REFERENCE (ID=0x0C, bench only) ---")
        print("Alternating UP/DOWN scroll with engage bit.")
        print("DO NOT USE ON VEHICLE - bench validation required.")
        print()

    window_reports = analyze_action_windows(frames, action_windows or [])
    if window_reports:
        print("--- ACTION WINDOW CORRELATION ---")
        for report in window_reports:
            print(f"  {report['name']}  {report['start_ms']}ms -> {report['end_ms']}ms")
            for row in report["ranked_ids"][:8]:
                print(
                    f"    {row['id_hex']:<6} score={row['score']:<7} "
                    f"during={row['during_frames']:<5} new_payloads={len(row['new_payloads']):<3} "
                    f"delta={row['rate_delta_hz']:<6} [{row['priority']}] {row['label']}"
                )
            print()
        print(f"{'B0':>4} {'B1':>4} {'B2':>4} {'B3':>4} {'B4':>4} {'B5':>4} {'B6':>4} {'B7':>4} {'CHK':>4}  direction  ctr")
        for ctr in range(16):
            for direction, b0, b1 in [("UP  ", 0x11, 0x04), ("DOWN", 0x0F, 0x04)]:
                data = [b0, b1, 0x00, 0x00, 0x00, 0x00, 0xC0, ctr]
                chk = lin_enhanced_checksum(make_protected_id(0x0C), data)
                print(f"  0x{b0:02X} 0x{b1:02X} 0x00 0x00 0x00 0x00 0xC0 0x{ctr:02X} 0x{chk:02X}  {direction}  {ctr}")
        print()

    # Output summary JSON if requested
    if output_json:
        summary = {
            "csv": csv_path,
            "analyzed_at": datetime.now(timezone.utc).isoformat(),
            "model": detected_model,
            "total_frames": total_frames,
            "duration_s": round(duration_s, 1),
            "rate_hz": round(overall_rate, 1),
            "unique_ids": len(by_id),
            "ids": {},
            "action_windows": window_reports,
        }
        for id_hex in sorted(by_id.keys(), key=lambda x: int(x, 16)):
            items = by_id[id_hex]
            payloads = defaultdict(int)
            for f in items:
                payloads[f["data_hex"]] += 1
            ref = ID_REFERENCE.get(id_hex, {})
            summary["ids"][id_hex] = {
                "count": len(items),
                "rate_hz": round((len(items) - 1) / max(1, (items[-1]["ts_ms"] - items[0]["ts_ms"]) / 1000), 1),
                "unique_payloads": len(payloads),
                "label": ref.get("label", "UNKNOWN"),
                "priority": ref.get("priority", "UNKNOWN"),
            }
        with open(output_json, "w") as f:
            json.dump(summary, f, indent=2)
        print(f"JSON summary: {output_json}")

    if candidate_json:
        candidate_profile = build_candidate_profile(csv_path, detected_model, by_id, window_reports)
        with open(candidate_json, "w", encoding="utf-8") as f:
            json.dump(candidate_profile, f, indent=2)
        print(f"Candidate profile: {candidate_json}")


def find_latest_csv(log_dir: str) -> str:
    csv_files = sorted(
        [os.path.join(log_dir, f) for f in os.listdir(log_dir) if f.startswith("lin-capture-") and f.endswith(".csv")],
        key=os.path.getmtime,
        reverse=True,
    )
    if not csv_files:
        print(f"No lin-capture-*.csv found in {log_dir}")
        sys.exit(1)
    return csv_files[0]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python analyze-lin-capture.py <csv_path> [--json <out.json>] [--candidate-json <candidate.json>] [--windows <manifest.json>]")
        print("  python analyze-lin-capture.py --latest [<log_dir>] [--windows <manifest.json>] [--candidate-json <candidate.json>]")
        sys.exit(1)

    csv_arg = sys.argv[1]
    json_out = ""
    if "--json" in sys.argv:
        idx = sys.argv.index("--json")
        json_out = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""
    candidate_out = ""
    if "--candidate-json" in sys.argv:
        idx = sys.argv.index("--candidate-json")
        candidate_out = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""
    windows = []
    if "--windows" in sys.argv:
        idx = sys.argv.index("--windows")
        windows_path = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""
        windows = load_action_windows(windows_path)

    if csv_arg == "--latest":
        log_dir = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "logs"
        )
        analyze_csv(find_latest_csv(log_dir), json_out, windows, candidate_out)
    else:
        analyze_csv(csv_arg, json_out, windows, candidate_out)