from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def send_command(port_name: str, command: str, timeout_s: float = 2.0) -> str:
    try:
        import serial  # type: ignore[import-not-found]
    except ImportError as exc:
        raise RuntimeError("pyserial is required for live serial checks. Install pyserial or run --dry-run.") from exc

    with serial.Serial(port_name, 115200, timeout=0.2) as ser:
        time.sleep(0.2)
        ser.reset_input_buffer()
        ser.write((command + "\n").encode("ascii"))
        ser.flush()
        deadline = time.time() + timeout_s
        chunks: list[bytes] = []
        while time.time() < deadline:
            chunk = ser.read(512)
            if chunk:
                chunks.append(chunk)
        return b"".join(chunks).decode("utf-8", errors="replace")


def build_record(args: argparse.Namespace, live_results: dict[str, str]) -> dict[str, object]:
    final_status = "blocked" if args.dry_run else "pass"
    return {
        "schema_version": 2,
        "board_serial": args.board_serial,
        "esp32_mac": args.esp32_mac or "TBD_READ_FROM_DEVICE",
        "firmware_version": args.firmware_version or "v5.3-rev-a-passthrough",
        "operator": args.operator,
        "date_time_utc": datetime.now(timezone.utc).isoformat(),
        "idle_current_ma": args.idle_current_ma,
        "armed_current_ma": args.armed_current_ma,
        "vbat_input_v": args.vbat_input_v,
        "three_v3_idle_v": args.three_v3_idle_v,
        "three_v3_radio_burst_min_v": args.three_v3_radio_burst_min_v,
        "safe_off_lin_en_low": args.safe_off_lin_en_low,
        "physical_arm_blocks_safe_arm": args.physical_arm_blocks_safe_arm,
        "wake_n_pullups_verified": args.wake_n_pullups_verified,
        "inh_no_load_verified": args.inh_no_load_verified,
        "usb_backfeed_absent": args.usb_backfeed_absent,
        "no_lin_dominant_reset_boot_safe_off": args.no_lin_dominant_reset_boot_safe_off,
        "no_lin_dominant_brownout": args.no_lin_dominant_brownout,
        "lin_a_result": args.lin_a_result,
        "lin_b_result": args.lin_b_result,
        "usb_result": args.usb_result,
        "ble_result": args.ble_result,
        "serial_live_results": live_results,
        "final_status": final_status,
    }


def write_record(record: dict[str, object], output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    board_serial = str(record["board_serial"]).replace("/", "-").replace("\\", "-")
    path = output_dir / f"{board_serial}-{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}.json"
    path.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description="Run or stage Rev A first-article checks.")
    parser.add_argument("--port", help="Serial port for live rev_a_passthrough firmware checks, e.g. COM7")
    parser.add_argument("--dry-run", action="store_true", help="Do not open serial; write a blocked/template record")
    parser.add_argument("--board-serial", default="REV-A-UNASSIGNED")
    parser.add_argument("--esp32-mac", default="")
    parser.add_argument("--firmware-version", default="")
    parser.add_argument("--operator", default="copilot")
    parser.add_argument("--idle-current-ma", default="TBD")
    parser.add_argument("--armed-current-ma", default="TBD")
    parser.add_argument("--vbat-input-v", default="TBD")
    parser.add_argument("--three-v3-idle-v", default="TBD")
    parser.add_argument("--three-v3-radio-burst-min-v", default="TBD")
    parser.add_argument("--safe-off-lin-en-low", default="TBD")
    parser.add_argument("--physical-arm-blocks-safe-arm", default="TBD")
    parser.add_argument("--wake-n-pullups-verified", default="TBD")
    parser.add_argument("--inh-no-load-verified", default="TBD")
    parser.add_argument("--usb-backfeed-absent", default="TBD")
    parser.add_argument("--no-lin-dominant-reset-boot-safe-off", default="TBD")
    parser.add_argument("--no-lin-dominant-brownout", default="TBD")
    parser.add_argument("--lin-a-result", default="TBD")
    parser.add_argument("--lin-b-result", default="TBD")
    parser.add_argument("--usb-result", default="TBD")
    parser.add_argument("--ble-result", default="TBD")
    parser.add_argument("--output-dir", default=str(ROOT / "build" / "first-article-records"))
    args = parser.parse_args()

    live_results: dict[str, str] = {}
    if args.dry_run:
        live_results["dry_run"] = "serial checks skipped"
    else:
        if not args.port:
            raise SystemExit("--port is required unless --dry-run is set")
        for command in ("version", "safe:off", "config"):
            live_results[command] = send_command(args.port, command)

    record = build_record(args, live_results)
    path = write_record(record, Path(args.output_dir))
    print(f"Wrote first-article record: {path}")
    if args.dry_run:
        print("Dry run complete. Use --port COMx on real hardware for live checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())