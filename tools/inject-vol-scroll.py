#!/usr/bin/env python3
"""
Send confirmed Tesla Model 3/Y left-scroll volume frames through XIAO active firmware.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

try:
  import serial
except ImportError:  # pragma: no cover - operator-facing message
  serial = None

REPO_ROOT = Path(__file__).resolve().parents[1]
LOG_ROOT = REPO_ROOT / "logs" / "injection-runs"

LEFT_ID = 0x2A
LEFT_COUNTER_B = [
  0x7F, 0x62, 0x45, 0x58, 0x0B, 0x16, 0x31, 0x2C,
  0x97, 0x8A, 0xAD, 0xB0, 0xE3, 0xFE, 0xD9, 0xC4,
]

CONTROL_BYTES = {
  "up": 0x0D,
  "down": 0x0B,
  "click": 0x2C,
  "idle": 0x0C,
}

@dataclass(frozen=True)
class TxFrame:
  index: int
  raw_id: int
  data: list[int]

  @property
  def command(self) -> str:
    parts = [f"0x{self.raw_id:02X}"] + [f"0x{byte:02X}" for byte in self.data]
    return "tx:" + ",".join(parts)

def build_left_frame(action: str, counter: int) -> TxFrame:
  ctr = counter & 0x0F
  data = [
    CONTROL_BYTES[action],
    0x80,
    0x3F,
    0x96,
    0x00,
    0xF0 + ctr,
    LEFT_COUNTER_B[ctr],
  ]
  return TxFrame(index=counter, raw_id=LEFT_ID, data=data)

def read_available(port: "serial.Serial", settle_s: float = 0.12) -> str:
  time.sleep(settle_s)
  chunks: list[bytes] = []
  while port.in_waiting:
    chunks.append(port.read(port.in_waiting))
    time.sleep(0.02)
  return b"".join(chunks).decode(errors="replace")

def send_command(port: "serial.Serial", command: str, settle_s: float = 0.12) -> str:
  port.write((command + "\r\n").encode("ascii"))
  port.flush()
  return read_available(port, settle_s=settle_s)

def require_ack(label: str, response: str, expected: str) -> None:
  if expected not in response:
    raise RuntimeError(f"{label} did not return expected '{expected}'. Response: {response.strip()!r}")

def write_run_log(payload: dict) -> Path:
  LOG_ROOT.mkdir(parents=True, exist_ok=True)
  stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
  path = LOG_ROOT / f"model3y-volume-{stamp}.json"
  path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
  return path

def parse_args(argv: list[str]) -> argparse.Namespace:
  parser = argparse.ArgumentParser(description="Send confirmed Model 3/Y left volume scroll frames via XIAO.")
  parser.add_argument("port", nargs="?", default="COM7", help="XIAO USB serial port, default COM7")
  parser.add_argument("direction", nargs="?", choices=sorted(CONTROL_BYTES), default="up")
  parser.add_argument("legacy_count", nargs="?", type=int, help="Optional positional count for old usage")
  parser.add_argument("--count", type=int, default=None, help="Number of frames to send")
  parser.add_argument("--cadence-ms", type=int, default=90, help="Delay between frames, default 90 ms")
  parser.add_argument("--start-counter", type=int, default=0, help="Initial 0-15 counter slot")
  parser.add_argument("--timeout", type=float, default=2.0, help="Serial timeout seconds")
  parser.add_argument("--dry-run", action="store_true", help="Print planned commands and write no serial data")
  parser.add_argument("--no-log", action="store_true", help="Do not write logs/injection-runs JSON")
  parser.add_argument("--no-arm", action="store_true", help="Do not send safe:arm/safe:off; for manual bench sessions only")
  return parser.parse_args(argv)

def main(argv: list[str]) -> int:
  args = parse_args(argv)
  count = args.count if args.count is not None else (args.legacy_count if args.legacy_count is not None else 8)
  if count < 1 or count > 64:
    raise SystemExit("count must be 1-64")
  if args.cadence_ms < 40:
    raise SystemExit("cadence must be at least 40 ms to stay below firmware rate limits")

  frames = [build_left_frame(args.direction, args.start_counter + i) for i in range(count)]
  run = {
    "created_at": datetime.now().isoformat(timespec="seconds"),
    "port": args.port,
    "direction": args.direction,
    "count": count,
    "cadence_ms": args.cadence_ms,
    "mode": "dry-run" if args.dry_run else "serial",
    "frame_source": "guided capture 20260528_211119",
    "frames": [
      {"index": frame.index, "id": f"0x{frame.raw_id:02X}", "data": [f"0x{x:02X}" for x in frame.data], "command": frame.command}
      for frame in frames
    ],
    "serial": [],
  }

  print(f"Port:      {args.port}")
  print("Wheel:     left volume scroll (ID 0x2A)")
  print(f"Direction: {args.direction} (byte[0]=0x{CONTROL_BYTES[args.direction]:02X})")
  print(f"Frames:    {count}")
  print(f"Cadence:   {args.cadence_ms} ms")
  print()
  for frame in frames:
    print(frame.command)

  if args.dry_run:
    if not args.no_log:
      print(f"\nLog: {write_run_log(run)}")
    return 0

  if serial is None:
    raise SystemExit("pyserial is not installed. Install with: python -m pip install pyserial")

  port = serial.Serial(args.port, 115200, timeout=args.timeout)
  try:
    boot = read_available(port, settle_s=0.8)
    if boot.strip():
      print("[boot]")
      print(boot.strip())
      run["serial"].append({"label": "boot", "response": boot})

    if not args.no_arm:
      response = send_command(port, "safe:arm", settle_s=0.18)
      print(f"[arm] {response.strip()}")
      run["serial"].append({"label": "arm", "command": "safe:arm", "response": response})
      require_ack("safe:arm", response, "cmd: safe=armed")

    for ordinal, frame in enumerate(frames, 1):
      response = send_command(port, frame.command, settle_s=0.14)
      print(f"[tx {ordinal}/{count}] {response.strip()}")
      run["serial"].append({"label": f"tx {ordinal}/{count}", "command": frame.command, "response": response})
      require_ack(f"tx {ordinal}/{count}", response, "cmd: tx ID=0x2A len=7")
      time.sleep(args.cadence_ms / 1000.0)

    if not args.no_arm:
      response = send_command(port, "safe:off", settle_s=0.18)
      print(f"[disarm] {response.strip()}")
      run["serial"].append({"label": "disarm", "command": "safe:off", "response": response})
  finally:
    port.close()

  if not args.no_log:
    print(f"\nLog: {write_run_log(run)}")
  print("Done.")
  return 0

if __name__ == "__main__":
  try:
    raise SystemExit(main(sys.argv[1:]))
  except KeyboardInterrupt:
    print("Interrupted", file=sys.stderr)
    raise SystemExit(130)
