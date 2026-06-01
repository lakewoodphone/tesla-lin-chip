from __future__ import annotations

import csv
import shutil
from datetime import date
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
FAB = BUILD / "fab"

GERBERS = BUILD / "tesla-dual-lin-rev-a-gerbers.zip"
SOURCE_BOM = FAB / "tesla-dual-lin-rev-a-bom.csv"
SOURCE_CPL = FAB / "tesla-dual-lin-rev-a-cpl.csv"
DRC_REPORT = BUILD / "_drc-routed.rpt"

PACKAGE_ROOT = BUILD / "quote"
PACKAGE_DIR = PACKAGE_ROOT / f"jlcpcb-mini-order-{date.today():%Y-%m-%d}"
PACKAGE_ZIP_BASE = PACKAGE_ROOT / f"jlcpcb-mini-order-{date.today():%Y-%m-%d}"

MANUAL_DESIGNATORS = {"J2", "J3", "SW1"}
BOARD_ONLY_PREFIXES = ("TP", "FID", "MH")

KNOWN_LCSC_PARTS = {
    "C_3V3": "C108717",
    "C_BST1": "C91183",
    "C_U1_DEC1": "C91183",
    "C_U2_DEC1": "C91183",
    "C_U3_DEC1": "C91183",
    "C_U4_DEC1": "C91183",
    "C_EN1": "C15849",
    "C_IN1": "C13585",
    "D1": "C224017",
    "D2": "C20345390",
    "D3": "C20345390",
    "D4": "C138714",
    "F1": "C12559",
    "FB1": "C845119",
    "J1": "C165948",
    "L1": "C511407",
    "Q1": "C16072",
    "R_ARMSENSE_PD1": "C25803",
    "R_BUCK_EN1": "C25803",
    "R_FB_BOT1": "C25803",
    "R_LINA_TXD_PU1": "C25803",
    "R_LINB_TXD_PU1": "C25803",
    "R_LINEN_PD1": "C25803",
    "R_PGOOD_PU1": "C25803",
    "R_WAKE_A1": "C25803",
    "R_WAKE_B1": "C25803",
    "R_BOOT1": "C25804",
    "R_EN1": "C25804",
    "R_BUCK_RON1": "C25811",
    "R_CC1": "C101083",
    "R_CC2": "C101083",
    "R_FB_TOP1": "C482778",
    "R_LINA_SER1": "C22859",
    "R_LINB_SER1": "C22859",
    "U1": "C2980300",
    "U2": "C271675",
    "U3": "C271675",
    "U4": "C477928",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def split_designators(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def is_board_only(designator: str) -> bool:
    return designator.startswith(BOARD_ONLY_PREFIXES)


def lcsc_for(designators: list[str]) -> str:
    part_numbers = {KNOWN_LCSC_PARTS[designator] for designator in designators if designator in KNOWN_LCSC_PARTS}
    if len(part_numbers) == 1:
        return next(iter(part_numbers))
    return ""


def classify_bom_rows(source_rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    assembly_rows: list[dict[str, str]] = []
    manual_rows: list[dict[str, str]] = []
    dnp_rows: list[dict[str, str]] = []

    for row in source_rows:
        designators = split_designators(row["Refs"])
        if row.get("DNP"):
            dnp_rows.append({
                "Designator": ",".join(designators),
                "Comment": row["Value"],
                "Footprint": row["Footprint"],
                "Qty": row["Qty"],
                "Reason": "DNP by topology default",
            })
            continue

        if all(is_board_only(designator) for designator in designators):
            continue

        if any(designator in MANUAL_DESIGNATORS for designator in designators):
            manual_rows.append({
                "Designator": ",".join(designators),
                "Comment": row["Value"],
                "Footprint": row["Footprint"],
                "Qty": row["Qty"],
                "InstallPlan": "Manual or JLC/PCBWay secondary operation after quote review",
            })
            continue

        assembly_rows.append({
            "Designator": ",".join(designators),
            "Comment": row["Value"],
            "Footprint": row["Footprint"],
            "LCSC Part #": lcsc_for(designators),
        })

    return assembly_rows, manual_rows, dnp_rows


def filter_cpl(source_rows: list[dict[str, str]], assembly_designators: set[str]) -> list[dict[str, str]]:
    cpl_rows: list[dict[str, str]] = []
    for row in source_rows:
        designator = row["Ref"].strip()
        if designator not in assembly_designators:
            continue
        cpl_rows.append({
            "Designator": designator,
            "Mid X": row["PosX"],
            "Mid Y": row["PosY"],
            "Layer": "Top" if row["Side"].strip().lower() == "top" else row["Side"],
            "Rotation": row["Rot"],
        })
    return cpl_rows


def write_notes(assembly_rows: list[dict[str, str]], manual_rows: list[dict[str, str]], dnp_rows: list[dict[str, str]]) -> None:
    match_needed = [row for row in assembly_rows if not row["LCSC Part #"]]
    notes = f"""project: tesla-dual-lin-rev-a
revision: A
prepared_at: {date.today():%Y-%m-%d}
order_intent: 3 usable assembled bench-test boards
practical_jlc_order_quantity: 5
quantity_note: JLCPCB quote flow showed 5 PCB minimum and PCBA quantity options of 5 or 2 during the first live quote attempt.
vendor_first_choice: JLCPCB PCBA
vendor_fallback: PCBWay PCBA or SMT-first JLCPCB plus local manual install
board:
    size_mm: [100, 56]
    layers: 4
    finish_preference: HASL_with_lead_for_first_bench_batch
    soldermask: green or cheapest available
    assembly_side: single-sided top
upload_files:
  gerbers: tesla-dual-lin-rev-a-gerbers.zip
  jlc_bom: jlcpcb-smt-first-bom.csv
  jlc_cpl: jlcpcb-smt-first-cpl.csv
  original_bom: original-kicad-bom.csv
  original_cpl: original-kicad-cpl.csv
assembly_plan:
  vendor_smt_rows: {len(assembly_rows)}
  vendor_missing_lcsc_rows: {len(match_needed)}
  manual_or_secondary_rows: {len(manual_rows)}
  dnp_rows: {len(dnp_rows)}
manual_or_secondary_parts:
"""
    for row in manual_rows:
        notes += f"  - designator: {row['Designator']}\n"
        notes += f"    comment: {row['Comment']}\n"
        notes += f"    plan: {row['InstallPlan']}\n"
    notes += "dnp_parts:\n"
    for row in dnp_rows:
        notes += f"  - designator: {row['Designator']}\n"
        notes += f"    comment: {row['Comment']}\n"
        notes += f"    reason: {row['Reason']}\n"
    notes += "quote_review_checks:\n"
    notes += "  - Confirm JLC placement preview orientation before paying.\n"
    notes += "  - Confirm ESP32-S3-WROOM-1U-N8R8 and TJA1021T part matches.\n"
    notes += "  - If LM5164DDA is unavailable, stop and review substitution before ordering.\n"
    notes += "  - Confirm selected F1 PPTC and L1 inductor package/orientation in JLC preview before payment.\n"
    notes += "  - Do not populate DNP LIN master pullup/diode parts for vehicle-side testing.\n"
    notes += "  - Order Molex 43025-0400 housings and 43030-series terminals separately for bench pigtails.\n"
    notes += "  - If the quote UI forces a 5-board minimum, order 5 assembled boards and reserve 2 as spares/rework units.\n"
    notes += "  - No checkout/payment without owner approval of final quote total and ETA.\n"
    (PACKAGE_DIR / "quote-notes.yaml").write_text(notes, encoding="utf-8")


def main() -> int:
    for required in (GERBERS, SOURCE_BOM, SOURCE_CPL, DRC_REPORT):
        if not required.exists():
            raise SystemExit(f"Missing required quote input: {required}")

    PACKAGE_DIR.mkdir(parents=True, exist_ok=True)

    shutil.copy2(GERBERS, PACKAGE_DIR / GERBERS.name)
    shutil.copy2(SOURCE_BOM, PACKAGE_DIR / "original-kicad-bom.csv")
    shutil.copy2(SOURCE_CPL, PACKAGE_DIR / "original-kicad-cpl.csv")
    shutil.copy2(DRC_REPORT, PACKAGE_DIR / "drc-routed-report.txt")

    source_bom_rows = read_csv(SOURCE_BOM)
    source_cpl_rows = read_csv(SOURCE_CPL)
    assembly_rows, manual_rows, dnp_rows = classify_bom_rows(source_bom_rows)
    assembly_designators = {
        designator
        for row in assembly_rows
        for designator in split_designators(row["Designator"])
    }
    cpl_rows = filter_cpl(source_cpl_rows, assembly_designators)

    write_csv(PACKAGE_DIR / "jlcpcb-smt-first-bom.csv", ["Designator", "Comment", "Footprint", "LCSC Part #"], assembly_rows)
    write_csv(PACKAGE_DIR / "jlcpcb-smt-first-cpl.csv", ["Designator", "Mid X", "Mid Y", "Layer", "Rotation"], cpl_rows)
    write_csv(PACKAGE_DIR / "manual-secondary-parts.csv", ["Designator", "Comment", "Footprint", "Qty", "InstallPlan"], manual_rows)
    write_csv(PACKAGE_DIR / "dnp-parts.csv", ["Designator", "Comment", "Footprint", "Qty", "Reason"], dnp_rows)
    write_csv(PACKAGE_DIR / "vendor-match-needed.csv", ["Designator", "Comment", "Footprint", "LCSC Part #"], [row for row in assembly_rows if not row["LCSC Part #"]])
    write_notes(assembly_rows, manual_rows, dnp_rows)
    archive_path = shutil.make_archive(str(PACKAGE_ZIP_BASE), "zip", PACKAGE_DIR)

    print(f"Prepared quote package: {PACKAGE_DIR}")
    print(f"Prepared quote package zip: {archive_path}")
    print(f"Vendor SMT BOM rows: {len(assembly_rows)}")
    print(f"Vendor match-needed rows: {sum(1 for row in assembly_rows if not row['LCSC Part #'])}")
    print(f"Vendor CPL rows: {len(cpl_rows)}")
    print(f"Manual/secondary rows: {len(manual_rows)}")
    print(f"DNP rows: {len(dnp_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
