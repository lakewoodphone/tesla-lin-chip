from __future__ import annotations

import argparse
import math
import re
import sys
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


REQUIRED_TESTPOINTS = {
    "TP1": ("GND", "GND"),
    "TP2": ("3V3", "3V3"),
    "TP3": ("VBAT", "VBAT_PROTECTED"),
    "TP4": ("USB-", "USB_D_MINUS"),
    "TP5": ("USB+", "USB_D_PLUS"),
    "TP6": ("UART_TX", "UART0_TX"),
    "TP7": ("UART_RX", "UART0_RX"),
    "TP8": ("EN", "EN"),
    "TP9": ("BOOT", "BOOT_GPIO0"),
    "TP10": ("LIN_A", "LIN_A"),
    "TP11": ("LIN_B", "LIN_B"),
    "TP12": ("LIN_A_TJA", "LIN_A_TJA"),
    "TP13": ("LIN_B_TJA", "LIN_B_TJA"),
    "TP14": ("LIN_EN", "LIN_EN"),
    "TP15": ("LIN_EN_DRV", "LIN_EN_DRIVE"),
    "TP16": ("ARM", "ARM_SENSE"),
    "TP17": ("WAKE_A", "WAKE_A_N"),
    "TP18": ("WAKE_B", "WAKE_B_N"),
    "TP19": ("INH_A", "INH_A_TP"),
    "TP20": ("INH_B", "INH_B_TP"),
}


class Finding:
    def __init__(self, severity: str, message: str) -> None:
        self.severity = severity
        self.message = message


def extract_blocks(text: str, head: str) -> list[str]:
    blocks: list[str] = []
    index = 0
    while True:
        start = text.find(head, index)
        if start < 0:
            return blocks
        depth = 0
        end = start
        in_string = False
        escape = False
        while end < len(text):
            char = text[end]
            if in_string:
                if escape:
                    escape = False
                elif char == "\\":
                    escape = True
                elif char == '"':
                    in_string = False
            else:
                if char == '"':
                    in_string = True
                elif char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth == 0:
                        end += 1
                        blocks.append(text[start:end])
                        index = end
                        break
            end += 1
        else:
            raise ValueError(f"unterminated block starting at offset {start}")


def property_value(block: str, name: str) -> str:
    match = re.search(rf'\(property "{re.escape(name)}" "([^"]*)"', block)
    return match.group(1) if match else ""


def footprint_at(block: str) -> tuple[float, float, float]:
    match = re.search(r'\(at ([\-0-9.]+) ([\-0-9.]+)(?: ([\-0-9.]+))?\)', block)
    if not match:
        return (math.nan, math.nan, 0.0)
    rotation = float(match.group(3)) if match.group(3) else 0.0
    return (float(match.group(1)), float(match.group(2)), rotation)


def footprint_net(block: str) -> str:
    matches = re.findall(r'\(net "([^"]+)"\)', block)
    return matches[-1] if matches else ""


def parse_footprints(text: str) -> list[dict[str, object]]:
    footprints: list[dict[str, object]] = []
    for block in extract_blocks(text, "(footprint "):
        fp_match = re.match(r'\(footprint "([^"]+)"', block)
        footprint = fp_match.group(1) if fp_match else ""
        x, y, rotation = footprint_at(block)
        footprints.append(
            {
                "reference": property_value(block, "Reference"),
                "value": property_value(block, "Value"),
                "footprint": footprint,
                "x": x,
                "y": y,
                "rotation": rotation,
                "net": footprint_net(block),
                "block": block,
            }
        )
    return footprints


def board_outline_size(text: str) -> tuple[float, float, tuple[float, float, float, float]]:
    matches = re.findall(
        r'\(gr_line\s+\(start ([\-0-9.]+) ([\-0-9.]+)\)\s+\(end ([\-0-9.]+) ([\-0-9.]+)\).*?\(layer "Edge\.Cuts"\)',
        text,
        re.S,
    )
    points: list[tuple[float, float]] = []
    for x0, y0, x1, y1 in matches:
        points.append((float(x0), float(y0)))
        points.append((float(x1), float(y1)))
    if not points:
        raise ValueError("no Edge.Cuts gr_line outline found")
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    return (max_x - min_x, max_y - min_y, (min_x, min_y, max_x, max_y))


def is_testpoint(footprint: dict[str, object]) -> bool:
    return str(footprint["footprint"]).startswith("TestPoint:") or str(footprint["reference"]).startswith("TP")


def distance(a: dict[str, object], b: dict[str, object]) -> float:
    return math.hypot(float(a["x"]) - float(b["x"]), float(a["y"]) - float(b["y"]))


def check_layout(args: argparse.Namespace) -> list[Finding]:
    pcb_path = Path(args.pcb)
    text = pcb_path.read_text(encoding="utf-8")
    footprints = parse_footprints(text)
    by_ref = {str(item["reference"]): item for item in footprints}
    findings: list[Finding] = []

    width, height, bounds = board_outline_size(text)
    if width > args.max_width_mm or height > args.max_height_mm:
        findings.append(
            Finding(
                "ERROR",
                f"board outline is {width:.2f} x {height:.2f} mm, over Rev B gate {args.max_width_mm:.2f} x {args.max_height_mm:.2f} mm; bounds={bounds}",
            )
        )

    centers: dict[tuple[float, float], list[dict[str, object]]] = defaultdict(list)
    for item in footprints:
        centers[(round(float(item["x"]), 3), round(float(item["y"]), 3))].append(item)
    for (x, y), items in sorted(centers.items()):
        visible_items = [item for item in items if not str(item["footprint"]).startswith("MountingHole:")]
        if len(visible_items) > 1:
            refs = ", ".join(f"{item['reference']}({item['value']})" for item in visible_items)
            findings.append(Finding("ERROR", f"footprint center overlap at x={x}, y={y}: {refs}"))

    testpoints = {str(item["reference"]): item for item in footprints if is_testpoint(item)}
    for ref, (expected_label, expected_net) in REQUIRED_TESTPOINTS.items():
        item = testpoints.get(ref)
        if not item:
            findings.append(Finding("ERROR", f"missing required test point {ref} ({expected_label}/{expected_net})"))
            continue
        label = str(item["value"])
        net = str(item["net"])
        if label != expected_label or net != expected_net:
            findings.append(Finding("ERROR", f"{ref} expected {expected_label}/{expected_net}, got {label}/{net}"))

    non_test_footprints = [item for item in footprints if not is_testpoint(item) and not str(item["footprint"]).startswith("MountingHole:")]
    for ref, item in sorted(testpoints.items(), key=lambda pair: int(pair[0].replace("TP", "")) if pair[0].replace("TP", "").isdigit() else 999):
        for other in non_test_footprints:
            gap = distance(item, other)
            if gap < args.testpad_center_clearance_mm:
                findings.append(
                    Finding(
                        "ERROR",
                        f"{ref} center is {gap:.2f} mm from {other['reference']}({other['value']}) at x={other['x']}, y={other['y']}; minimum center clearance is {args.testpad_center_clearance_mm:.2f} mm",
                    )
                )

    j1 = by_ref.get("J1")
    if not j1:
        findings.append(Finding("ERROR", "missing J1 USB-C connector footprint"))
    elif not args.usb_access_artifact:
        findings.append(
            Finding(
                "ERROR",
                "USB-C service access is not machine-verifiable from the PCB alone; provide --usb-access-artifact with a 3D/mechanical screenshot or photo proving the receptacle opens outward on a reachable service edge",
            )
        )
    else:
        artifact = Path(args.usb_access_artifact)
        if not artifact.exists():
            findings.append(Finding("ERROR", f"USB access artifact does not exist: {artifact}"))

    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description="Check KiCad physical layout gates before Rev B ordering.")
    parser.add_argument("--pcb", default=str(ROOT / "kicad" / "tesla-dual-lin-rev-a.kicad_pcb"))
    parser.add_argument("--max-width-mm", type=float, default=70.0)
    parser.add_argument("--max-height-mm", type=float, default=42.0)
    parser.add_argument("--testpad-center-clearance-mm", type=float, default=2.0)
    parser.add_argument("--usb-access-artifact", default="")
    args = parser.parse_args()

    findings = check_layout(args)
    if findings:
        print("Physical layout gate FAILED")
        for finding in findings:
            print(f"{finding.severity}: {finding.message}")
        return 1

    print("Physical layout gate PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())