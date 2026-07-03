from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    raise SystemExit(1)


def load_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        fail(f"missing required file: {path}")
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def load_json(path: Path) -> dict[str, object]:
    if not path.exists():
        fail(f"missing required file: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def check_project() -> None:
    path = ROOT / "project.json"
    if not path.exists():
        fail("project.json is missing")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(data.get("cad_target", "").startswith("KiCad"), "project must target KiCad")
    non_negotiables = set(data.get("non_negotiables", []))
    require("two independent LIN physical channels" in non_negotiables, "two-LIN requirement missing")
    blocked_until = "\n".join(data.get("blocked_until", []))
    require(
        "MASS ORDER BLOCKER" in blocked_until
        and "SRU5016-100Y" in blocked_until
        and "higher-current" in blocked_until,
        "project mass-order D4/L1 blocker missing",
    )

    board_def = ROOT.parents[1] / "boards" / "tesla_dual_lin_esp32s3_n8r8.json"
    require(board_def.exists(), "local PlatformIO Rev A ESP32-S3 N8R8 board definition is missing")
    board_data = json.loads(board_def.read_text(encoding="utf-8"))
    flags = "\n".join(board_data.get("build", {}).get("extra_flags", []))
    require("BOARD_HAS_PSRAM" in flags, "Rev A board definition must enable PSRAM")
    require(board_data.get("upload", {}).get("flash_size") == "8MB", "Rev A board definition must use 8MB flash")


def check_bom() -> None:
    rows = load_csv(ROOT / "bom" / "rev_a_initial_bom.csv")
    by_mpn = "\n".join(row.get("mpn", "") for row in rows)
    require("ESP32-S3-WROOM-1U-N8R8" in by_mpn, "ESP32-S3-WROOM-1U-N8R8 missing from BOM")
    require("TJA1021T/20/C,118" in by_mpn, "TJA1021T/20/C,118 missing from BOM")
    require("MCP2003" not in by_mpn.upper(), "MCP2003 must not be a Rev A primary BOM item")

    lin_rows = [row for row in rows if row.get("mpn") == "TJA1021T/20/C,118"]
    require(len(lin_rows) == 1, "expected one grouped TJA1021 BOM line")
    require(lin_rows[0].get("qty") == "2", "Rev A must have exactly two TJA1021 transceivers")

    test_pad_rows = [row for row in rows if "Pogo" in row.get("function", "")]
    require(test_pad_rows, "pogo/test pad BOM line missing")


def check_bom_strategy() -> None:
    rows = load_csv(ROOT / "bom" / "rev_a_bom_strategy.csv")
    require(rows, "BOM strategy must have rows")

    items = {row["item"]: row for row in rows}
    require(items.get("MCU/BLE", {}).get("rev_a_selected_mpn") == "ESP32-S3-WROOM-1U-N8R8", "BOM strategy must lock ESP32-S3-WROOM-1U-N8R8")
    require(items.get("LIN transceiver", {}).get("qty") == "2", "BOM strategy must require two LIN transceivers")
    require(items.get("LIN transceiver", {}).get("rev_a_selected_mpn") == "TJA1021T/20/C,118", "BOM strategy must lock TJA1021T/20/C,118")
    require("LM5164DDA" in items.get("Buck regulator", {}).get("rev_a_selected_mpn", ""), "BOM strategy must select LM5164DDA for Rev A first articles")
    require("MCP2003" not in "\n".join(row.get("rev_a_selected_mpn", "") for row in rows).upper(), "BOM strategy must not select MCP2003")

    required_items = {
        "Buck regulator",
        "Reverse polarity MOSFET",
        "Input PTC/fuse",
        "VBAT TVS",
        "LIN ESD",
        "USB-C connector",
        "Physical arm switch",
        "Pogo pads",
        "Fiducials",
    }
    missing = sorted(required_items - set(items))
    require(not missing, f"BOM strategy missing items: {', '.join(missing)}")


def check_cost_model() -> None:
    rows = load_csv(ROOT / "bom" / "rev_a_cost_model.csv")
    by_scenario = {row["scenario"]: row for row in rows}
    expected = {
        "cost_down_pilot": ("10", "24", "38"),
        "cost_down_batch": ("100", "16", "27"),
        "lm5164_first_article_pilot": ("10", "28", "43"),
        "lm5164_first_article_batch": ("100", "18", "32"),
    }
    for scenario, (quantity, low, high) in expected.items():
        require(scenario in by_scenario, f"cost model missing {scenario}")
        row = by_scenario[scenario]
        require(row["quantity"] == quantity, f"{scenario} quantity must be {quantity}")
        require(row["total_low_usd"] == low, f"{scenario} low estimate must be {low}")
        require(row["total_high_usd"] == high, f"{scenario} high estimate must be {high}")


def check_pin_plan() -> None:
    rows = load_csv(ROOT / "electrical" / "pin-plan.csv")
    nets = {row["net"] for row in rows}
    required_nets = {
        "USB_D_MINUS",
        "USB_D_PLUS",
        "BOOT_GPIO0",
        "EN",
        "UART0_TX",
        "UART0_RX",
        "LIN_A_TXD",
        "LIN_A_RXD",
        "LIN_B_TXD",
        "LIN_B_RXD",
        "LIN_EN",
        "ARM_SENSE",
    }
    missing = sorted(required_nets - nets)
    require(not missing, f"pin plan missing nets: {', '.join(missing)}")

    assigned = [
        row["esp32_s3_pin"]
        for row in rows
        if not row["esp32_s3_pin"].startswith("TBD") and row["esp32_s3_pin"] != "NO_MCU_PIN"
    ]
    duplicates = sorted({pin for pin in assigned if assigned.count(pin) > 1})
    require(not duplicates, f"duplicate ESP32 pin assignments: {', '.join(duplicates)}")


def check_net_plan() -> None:
    rows = load_csv(ROOT / "electrical" / "net-plan.csv")
    nets = {row["net"] for row in rows}
    for net in (
        "VBAT_IN",
        "VBAT_PROTECTED",
        "VBAT_FILTERED",
        "3V3",
        "GND",
        "LIN_A",
        "LIN_B",
        "LIN_A_TJA",
        "LIN_B_TJA",
        "LIN_EN",
        "LIN_EN_DRIVE",
        "ARM_SENSE",
        "WAKE_A_N",
        "WAKE_B_N",
        "INH_A_TP",
        "INH_B_TP",
        "BUCK_EN",
        "BUCK_SW",
        "BUCK_FB",
        "BUCK_BST",
        "BUCK_RON",
        "BUCK_PGOOD",
    ):
        require(net in nets, f"net plan missing {net}")


def check_component_decisions() -> None:
    path = ROOT / "electrical" / "component-decisions.yaml"
    require(path.exists(), "component-decisions.yaml is missing")
    text = path.read_text(encoding="utf-8")
    for required_text in (
        "RXD=1, SLP_N=2, WAKE_N=3, TXD=4, GND=5, LIN=6, VBAT=7, INH=8",
        "wake_n: pulled high to VBAT_PROTECTED through 100k",
        "inh: not used to enable the buck regulator",
        "type: DPDT slide switch",
        "pole_b_common: ARM_SENSE",
        "LM5164DDA",
        "default_no_master_pullup_populated: true",
        "optional_dnp_master_pullup_footprints: true",
        "GPIO19",
        "GPIO20",
        "GPIO43",
        "GPIO44",
    ):
        require(required_text in text, f"component decisions missing {required_text}")

    supplier_rows = load_csv(ROOT / "bom" / "rev_a_supplier_shortlist.csv")
    supplier_items = {row["item"] for row in supplier_rows}
    for item in (
        "Buck regulator",
        "LIN ESD",
        "VBAT TVS",
        "USB-C connector",
        "Physical arm switch",
        "Harness Micro-Fit service connectors",
    ):
        require(item in supplier_items, f"supplier shortlist missing {item}")

    gate_path = ROOT / "manufacturing" / "release_gates.yaml"
    require(gate_path.exists(), "release_gates.yaml is missing")
    gate_text = gate_path.read_text(encoding="utf-8")
    for gate_name in (
        "gate_1_component_level_schematic_release",
        "gate_2_layout_release",
        "gate_4_first_article_bench",
        "gate_6_100_unit_release",
    ):
        require(gate_name in gate_text, f"release gates missing {gate_name}")


def check_schematic_netlist() -> None:
    path = ROOT / "electrical" / "schematic-netlist.json"
    require(path.exists(), "schematic-netlist.json is missing")
    data = json.loads(path.read_text(encoding="utf-8"))
    components = data.get("components", {})
    for reference in ("U1", "U2", "U3", "J1", "J2", "J3", "SW1", "R_CC1", "R_CC2", "R_LINEN_PD1", "TP_ARRAY"):
        require(reference in components, f"schematic netlist missing {reference}")

    require(components["U2"].get("mpn") == "TJA1021T/20/C,118", "U2 must be the car-side TJA1021")
    require(components["U3"].get("mpn") == "TJA1021T/20/C,118", "U3 must be the wheel-side TJA1021")
    expected_tja_pinout = {
        "RXD": 1,
        "SLP_N": 2,
        "WAKE_N": 3,
        "TXD": 4,
        "GND": 5,
        "LIN": 6,
        "VBAT": 7,
        "INH": 8,
    }
    require(components["U2"].get("pin_numbers") == expected_tja_pinout, "U2 TJA1021 SOIC-8 pinout must be explicit")
    require(components["U3"].get("pin_numbers") == expected_tja_pinout, "U3 TJA1021 SOIC-8 pinout must be explicit")
    require(components["U2"].get("connections", {}).get("SLP_N") == "LIN_EN", "U2 SLP_N must be on LIN_EN")
    require(components["U3"].get("connections", {}).get("SLP_N") == "LIN_EN", "U3 SLP_N must be on LIN_EN")
    require(components["U2"].get("connections", {}).get("WAKE_N") == "WAKE_A_N", "U2 WAKE_N must be resolved")
    require(components["U3"].get("connections", {}).get("WAKE_N") == "WAKE_B_N", "U3 WAKE_N must be resolved")
    require(components["U2"].get("connections", {}).get("INH") == "INH_A_TP", "U2 INH must be test-only net")
    require(components["U3"].get("connections", {}).get("INH") == "INH_B_TP", "U3 INH must be test-only net")
    require(components["U2"].get("connections", {}).get("LIN") == "LIN_A_TJA", "U2 LIN must be after series resistor")
    require(components["U3"].get("connections", {}).get("LIN") == "LIN_B_TJA", "U3 LIN must be after series resistor")
    require(components["U1"].get("connections", {}).get("GPIO19") == "USB_D_MINUS", "GPIO19 must be USB D-")
    require(components["U1"].get("connections", {}).get("GPIO20") == "USB_D_PLUS", "GPIO20 must be USB D+")
    require(components["U1"].get("connections", {}).get("GPIO8") == "LIN_EN_DRIVE", "GPIO8 must drive pre-switch LIN_EN_DRIVE")
    require(components["U1"].get("connections", {}).get("GPIO9") == "ARM_SENSE", "GPIO9 must read independent ARM_SENSE")
    for reference, vbat_net, lin_net in (("J2", "VBAT_IN", "LIN_A"), ("J3", "VBAT_PROTECTED", "LIN_B")):
        connector = components[reference]
        connections = connector.get("connections", {})
        require("Micro-Fit" in connector.get("mpn", ""), f"{reference} must use Micro-Fit service connector")
        require(connections.get("1_VBAT") == vbat_net, f"{reference} pin 1 must be {vbat_net}")
        require(connections.get("2_GND") == "GND", f"{reference} pin 2 must be GND")
        require(connections.get("3_RESERVED") == "NC", f"{reference} pin 3 must be reserved/NC")
        require(connections.get("4_LIN") == lin_net, f"{reference} pin 4 must be {lin_net}")
    sw1_connections = components["SW1"].get("connections", {})
    require("DPDT" in components["SW1"].get("mpn", ""), "SW1 must be a DPDT physical arm switch")
    require(sw1_connections.get("LIN_COMMON") == "LIN_EN", "SW1 LIN pole common must be post-switch LIN_EN")
    require(sw1_connections.get("LIN_ARM_THROW") == "LIN_EN_DRIVE", "SW1 LIN arm throw must be MCU LIN_EN_DRIVE")
    require(sw1_connections.get("LIN_SAFE_THROW") == "GND", "SW1 LIN safe throw must force LIN_EN to GND")
    require(sw1_connections.get("SENSE_COMMON") == "ARM_SENSE", "SW1 sense pole common must be ARM_SENSE")
    require(sw1_connections.get("SENSE_ARM_THROW") == "3V3", "SW1 sense arm throw must be 3V3")
    require(sw1_connections.get("SENSE_SAFE_THROW") == "GND", "SW1 sense safe throw must be GND")

    for reference in ("R_ARMSENSE_PD1", "R_WAKE_A1", "R_WAKE_B1", "R_LINA_SER1", "R_LINB_SER1", "D2", "D3", "R_FB_TOP1", "R_FB_BOT1"):
        require(reference in components, f"schematic netlist missing {reference}")
    require(components["R_ARMSENSE_PD1"].get("connections", {}).get("1") == "ARM_SENSE", "R_ARMSENSE_PD1 must pull ARM_SENSE")
    require(components["R_ARMSENSE_PD1"].get("connections", {}).get("2") == "GND", "R_ARMSENSE_PD1 must pull to GND")
    require(components["R_WAKE_A1"].get("connections", {}).get("2") == "VBAT_PROTECTED", "R_WAKE_A1 must pull to protected VBAT")
    require(components["R_WAKE_B1"].get("connections", {}).get("2") == "VBAT_PROTECTED", "R_WAKE_B1 must pull to protected VBAT")
    for reference in ("R_LINA_TXD_PU1", "R_LINB_TXD_PU1", "R_LINA_MASTER1", "R_LINB_MASTER1", "D_LINA_MASTER1", "D_LINB_MASTER1"):
        require(reference in components, f"schematic netlist missing {reference}")
    require(components["R_LINA_TXD_PU1"].get("connections", {}).get("2") == "3V3", "R_LINA_TXD_PU1 must pull TXD recessive to 3V3")
    require(components["R_LINB_TXD_PU1"].get("connections", {}).get("2") == "3V3", "R_LINB_TXD_PU1 must pull TXD recessive to 3V3")
    require("DNP" in components["R_LINA_MASTER1"].get("mpn", ""), "R_LINA_MASTER1 must default DNP")
    require("DNP" in components["R_LINB_MASTER1"].get("mpn", ""), "R_LINB_MASTER1 must default DNP")
    expected_lm5164_pinout = {
        "GND": 1,
        "VIN": 2,
        "EN_UVLO": 3,
        "RON": 4,
        "FB": 5,
        "PGOOD": 6,
        "BST": 7,
        "SW": 8,
        "EP": 9,
    }
    require("LM5164DDA" in components["U4"].get("mpn", ""), "U4 must name the Rev A LM5164DDA robust default")
    require(components["U4"].get("pin_numbers") == expected_lm5164_pinout, "U4 LM5164DDA pinout must be explicit")
    require(components["U4"].get("connections", {}).get("VIN") == "VBAT_FILTERED", "U4 VIN must be post-filter VBAT")
    require(components["U4"].get("connections", {}).get("FB") == "BUCK_FB", "U4 FB must connect to BUCK_FB")
    require(components["U4"].get("connections", {}).get("RON") == "BUCK_RON", "U4 RON must connect to BUCK_RON")
    require(components["U4"].get("connections", {}).get("PGOOD") == "BUCK_PGOOD", "U4 PGOOD must connect to BUCK_PGOOD")
    for reference in ("R_BUCK_EN1", "R_BUCK_RON1", "R_PGOOD_PU1", "C_BST1", "L1"):
        require(reference in components, f"schematic netlist missing {reference}")

    test_nets = set(components["TP_ARRAY"].get("required_nets", []))
    for net in (
        "GND",
        "3V3",
        "VBAT_PROTECTED",
        "EN",
        "BOOT_GPIO0",
        "LIN_A",
        "LIN_B",
        "LIN_A_TJA",
        "LIN_B_TJA",
        "LIN_EN",
        "LIN_EN_DRIVE",
        "ARM_SENSE",
        "WAKE_A_N",
        "WAKE_B_N",
        "INH_A_TP",
        "INH_B_TP",
    ):
        require(net in test_nets, f"test pad array missing {net}")


def check_manufacturing_inputs() -> None:
    for relative_path in (
        "manufacturing/fab_notes.yaml",
        "manufacturing/production_flow.yaml",
        "manufacturing/assembly_policy.csv",
        "manufacturing/vendor_quote_package.yaml",
        "tests/provisioning_jig_plan.yaml",
        "tests/first_article_record_schema.json",
        "manufacturing/release_gates.yaml",
        "electrical/power-protection-design.yaml",
        "electrical/component-decisions.yaml",
        "bom/rev_a_supplier_shortlist.csv",
        "tools/export_kicad_outputs.ps1",
        "tools/estimate_rev_a_cost.py",
        "tools/rev_a_first_article_check.py",
        "tools/check_physical_layout_gates.py",
        "../../docs/rev-b-quality-gate-2026-06-16.md",
    ):
        require((ROOT / relative_path).exists(), f"missing manufacturing/export input: {relative_path}")

    repo_root = ROOT.parents[1]
    for relative_path in ("tools/estimate-rev-a-cost.ps1", "tools/rev-a-first-article-check.ps1", "tools/check-rev-b-layout-gates.ps1"):
        require((repo_root / relative_path).exists(), f"missing repo tool wrapper: {relative_path}")

    assembly_rows = load_csv(ROOT / "manufacturing" / "assembly_policy.csv")
    categories = {row["category"] for row in assembly_rows}
    for category in ("Fine-pitch/module ICs", "Protection semiconductors", "USB-C", "Harness connectors"):
        require(category in categories, f"assembly policy missing category: {category}")

    first_article_schema = load_json(ROOT / "tests" / "first_article_record_schema.json")
    require(first_article_schema.get("schema_version") == 2, "first article schema must be version 2")
    first_article_fields = set(first_article_schema.get("required_fields", []))
    for field in (
        "vbat_input_v",
        "three_v3_idle_v",
        "three_v3_radio_burst_min_v",
        "wake_n_pullups_verified",
        "inh_no_load_verified",
        "usb_backfeed_absent",
        "no_lin_dominant_reset_boot_safe_off",
        "no_lin_dominant_brownout",
    ):
        require(field in first_article_fields, f"first article schema missing {field}")

    power_text = (ROOT / "electrical" / "power-protection-design.yaml").read_text(encoding="utf-8")
    for required_text in ("P-channel MOSFET", "resettable PPTC", "SMBJ24A", "LIN_EN_DRIVE", "LIN_EN", "LM5164DDA", "WAKE_N"):
        require(required_text in power_text, f"power protection design missing {required_text}")

    for relative_path in (
        "manufacturing/release_gates.yaml",
        "manufacturing/production_flow.yaml",
        "manufacturing/vendor_quote_package.yaml",
        "kicad/footprint-map.csv",
    ):
        text = (ROOT / relative_path).read_text(encoding="utf-8")
        require(
            "MASS ORDER BLOCKER" in text
            and "SRU5016-100Y" in text
            and "higher-current" in text,
            f"missing D4/L1 mass-order blocker in {relative_path}",
        )

    gate_text = (ROOT / "manufacturing" / "release_gates.yaml").read_text(encoding="utf-8")
    for required_text in (
        "tools/check-rev-b-layout-gates.ps1",
        "USB-C receptacle opening faces outward",
        "no test pad is overlapped blocked shadowed",
    ):
        require(required_text in gate_text, f"release gates missing Rev B physical gate text: {required_text}")


def check_kicad_seed() -> None:
    kicad_dir = ROOT / "kicad"
    for file_name in (
        "tesla-dual-lin-rev-a.kicad_pro",
        "tesla-dual-lin-rev-a.kicad_sch",
        "tesla-dual-lin-rev-a.kicad_pcb",
    ):
        require((kicad_dir / file_name).exists(), f"missing KiCad seed file: {file_name}")

    board_text = (kicad_dir / "tesla-dual-lin-rev-a.kicad_pcb").read_text(encoding="utf-8")
    require('(4 "In1.Cu" power)' in board_text, "PCB seed must be 4-layer with In1.Cu")
    require('(6 "In2.Cu" power)' in board_text, "PCB seed must be 4-layer with In2.Cu")

    edge_blocks = re.findall(r'\(gr_line\s+\(start ([0-9.]+) ([0-9.]+)\)\s+\(end ([0-9.]+) ([0-9.]+)\).*?\(layer "Edge\.Cuts"\)', board_text, re.S)
    points = []
    for x0, y0, x1, y1 in edge_blocks:
        points.append((float(x0), float(y0)))
        points.append((float(x1), float(y1)))
    xs = sorted({point[0] for point in points})
    ys = sorted({point[1] for point in points})
    require(xs == [0.0, 100.0], f"PCB outline X coordinates must be 0 and 100mm, got {xs}")
    require(ys == [0.0, 56.0], f"PCB outline Y coordinates must be 0 and 56mm, got {ys}")


def check_footprints_and_layout_plan() -> None:
    footprint_rows = load_csv(ROOT / "kicad" / "footprint-map.csv")
    by_refdes = {row["refdes"]: row for row in footprint_rows}
    require(by_refdes.get("U1", {}).get("selected_footprint") == "RF_Module:ESP32-S3-WROOM-1U", "U1 footprint must be ESP32-S3-WROOM-1U")
    require(by_refdes.get("U2", {}).get("selected_footprint") == "Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", "U2 footprint must be SOIC-8")
    require(by_refdes.get("U3", {}).get("selected_footprint") == "Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", "U3 footprint must be SOIC-8")
    require(by_refdes.get("U4", {}).get("selected_footprint") == "Package_SO:HSOP-8-1EP_3.9x4.9mm_P1.27mm_EP2.41x3.1mm_ThermalVias", "U4 footprint must be LM5164DDA HSOP-8 PowerPAD for robust first articles")
    require(by_refdes.get("Q1", {}).get("selected_footprint") == "Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", "Q1 footprint must be SOIC-8 for AO4407A-class default")
    require(by_refdes.get("F1", {}).get("selected_footprint") == "Fuse:Fuse_1812_4532Metric", "F1 footprint must be 1812 PPTC")
    require(by_refdes.get("D1", {}).get("selected_footprint") == "Diode_SMD:D_SMB", "D1 footprint must be SMB for low-cost TVS default")
    require(by_refdes.get("SW1", {}).get("selected_footprint") == "Button_Switch_SMD:SW_DPDT_CK_JS202011JCQN", "SW1 footprint must be DPDT for independent arm sense")
    require("USB_C_Receptacle_HRO_TYPE-C-31-M-12" in by_refdes.get("J1", {}).get("selected_footprint", ""), "J1 must use the HRO Type-C footprint candidate")
    require("TestPoint_Pad_D1.5mm" in by_refdes.get("TP_ARRAY", {}).get("selected_footprint", ""), "TP_ARRAY must use 1.5mm pogo pad candidate")
    require("Fiducial_1mm_Mask2mm" in by_refdes.get("FID1 FID2 FID3", {}).get("selected_footprint", ""), "global fiducial footprint missing")

    layout_path = ROOT / "layout" / "placement-zones.yaml"
    require(layout_path.exists(), "placement-zones.yaml is missing")
    layout_text = layout_path.read_text(encoding="utf-8")
    for zone_name in (
        "car_harness_and_protection",
        "power_conversion",
        "esp32_rf_and_service",
        "wheel_harness_and_second_lin",
        "user_safety_controls",
        "bottom_test_access",
    ):
        require(zone_name in layout_text, f"placement plan missing zone {zone_name}")


def main() -> int:
    check_project()
    check_bom()
    check_bom_strategy()
    check_cost_model()
    check_pin_plan()
    check_net_plan()
    check_component_decisions()
    check_schematic_netlist()
    check_manufacturing_inputs()
    check_kicad_seed()
    check_footprints_and_layout_plan()
    print(f"Rev A hardware input scaffold OK: {ROOT}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())