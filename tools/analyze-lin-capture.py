#!/usr/bin/env python3
r"""LIN capture analyzer for Tesla (Model 3/Y/X) — post-capture ID labeling + reference.

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
from datetime import datetime

# =========================================================================
# TESLA KNOWN LIN ID REFERENCE TABLES
# =========================================================================
# These are compiled from real Model X captures (Moti Zaks, 2026-05-17).
# Model 3/Y IDs may differ — use these as a starting reference to compare
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
        "notes": "Same rate as 0x0C but only 17 unique payloads in 60s — "
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
        "notes": "Same as 0x0E — alternates 0x50/0x51. Seat/occupancy signal?",
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
    # === Model 3/Y candidates (from community reports — NOT YET CONFIRMED) ===
    "0x1A": {
        "model": "3/Y",
        "bus": "steering",
        "label": "CANDIDATE — scroll/buttons?",
        "length": 8,
        "checksum": "enhanced",
        "notes": "Unconfirmed, reported in community as possible steering ID. "
                 "Capture and check B0/scroll correlation.",
        "priority": "INVESTIGATE",
    },
    "0x1B": {
        "model": "3/Y",
        "bus": "steering",
        "label": "CANDIDATE — scroll/buttons?",
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

# Checksum formula — for verification
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


def analyze_csv(csv_path: str, output_json: str = ""):
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
                    "error": int(row.get("error", 0)),
                    "baud": int(row.get("baud", 0)),
                })
            except (ValueError, KeyError) as e:
                print(f"  WARN: skipping row — {e}: {row}")

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
                    data_bytes = [int(x, 16) for x in f["data_hex"].split() if x]
                    if len(data_bytes) >= 2:
                        # Last byte is checksum
                        data_part = data_bytes[:-1]
                        rx_chk = data_bytes[-1]
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
        print("DO NOT USE ON VEHICLE — bench validation required.")
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
            "analyzed_at": datetime.utcnow().isoformat(),
            "model": detected_model,
            "total_frames": total_frames,
            "duration_s": round(duration_s, 1),
            "rate_hz": round(overall_rate, 1),
            "unique_ids": len(by_id),
            "ids": {},
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
        print("  python analyze-lin-capture.py <csv_path> [--json <out.json>]")
        print("  python analyze-lin-capture.py --latest [<log_dir>]")
        sys.exit(1)

    csv_arg = sys.argv[1]
    json_out = ""
    if "--json" in sys.argv:
        idx = sys.argv.index("--json")
        json_out = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""

    if csv_arg == "--latest":
        log_dir = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "logs"
        )
        analyze_csv(find_latest_csv(log_dir), json_out)
    else:
        analyze_csv(csv_arg, json_out)