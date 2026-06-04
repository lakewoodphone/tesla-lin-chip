from __future__ import annotations

import os
import re
import uuid
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
KICAD_DIR = ROOT / "kicad"
SCHEMATIC_PATH = KICAD_DIR / "tesla-dual-lin-rev-a.kicad_sch"
PCB_PATH = KICAD_DIR / "tesla-dual-lin-rev-a.kicad_pcb"
UUID_NS = uuid.UUID("6af5e03f-6a6b-42f2-b5a3-0b48335c63c3")

BOARD_W = 100.0
BOARD_H = 56.0
HARNESS_CONNECTOR_FOOTPRINT = "Connector_Molex:Molex_Micro-Fit_3.0_43650-0415_1x04_P3.00mm_Vertical"


def stable_uuid(*parts: object) -> str:
    return str(uuid.uuid5(UUID_NS, ":".join(str(part) for part in parts)))


def fmt(value: float) -> str:
    text = f"{value:.3f}".rstrip("0").rstrip(".")
    return text if text else "0"


def q(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


# Canonical net registry (index 0 = unnamed)
ALL_NETS: list[str] = [
    "",
    "GND",
    "3V3",
    "VBAT_IN",
    "VBAT_PROTECTED",
    "VBAT_FILTERED",
    "LIN_A",
    "LIN_B",
    "LIN_A_TJA",
    "LIN_B_TJA",
    "LIN_A_MASTER_PU",
    "LIN_B_MASTER_PU",
    "LIN_A_TXD",
    "LIN_A_RXD",
    "LIN_B_TXD",
    "LIN_B_RXD",
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
    "USB_D_PLUS",
    "USB_D_MINUS",
    "USB_VBUS",
    "CC1",
    "CC2",
    "BOOT_GPIO0",
    "EN",
    "UART0_TX",
    "UART0_RX",
]


def net_index(name: str) -> int:
    try:
        return ALL_NETS.index(name)
    except ValueError:
        return 0


def net_declarations() -> str:
    return "\n".join(
        f'  (net {i} "{q(name)}")' if name else f"  (net {i} \"\")"
        for i, name in enumerate(ALL_NETS)
    )


@dataclass(frozen=True)
class SchematicComponent:
    ref: str
    value: str
    footprint: str
    pins: dict[int, str]
    at: tuple[float, float]
    description: str = ""
    dnp: bool = False
    extra_properties: tuple[tuple[str, str], ...] = ()

    @property
    def pin_count(self) -> int:
        return max(self.pins)

    @property
    def lib_id(self) -> str:
        return f"Connector_Generic:Conn_01x{self.pin_count:02d}"


@dataclass(frozen=True)
class FootprintInstance:
    ref: str
    value: str
    footprint: str
    at: tuple[float, float]
    rotation: float = 0.0
    layer: str = "F.Cu"
    pad_nets: dict[int | str, str] | None = None


def snap_grid(value: float, grid: float = 1.27) -> float:
    return round(value / grid) * grid


def component(
    ref: str, value: str, footprint: str, pin_count: int,
    nets: dict[int, str], x: float, y: float, dnp: bool = False,
    extra_properties: dict[str, str] | None = None,
) -> SchematicComponent:
    pins = {pin: nets.get(pin, f"NC_{ref}_{pin}") for pin in range(1, pin_count + 1)}
    return SchematicComponent(ref=ref, value=value, footprint=footprint,
                              pins=pins, at=(snap_grid(x), snap_grid(y)), dnp=dnp,
                              extra_properties=tuple((extra_properties or {}).items()))


# Schematic generation

def schematic_components() -> list[SchematicComponent]:
    u1_nets = {1: "GND", 2: "3V3", 3: "EN", 4: "LIN_A_RXD", 5: "LIN_A_TXD",
               6: "LIN_B_RXD", 7: "LIN_B_TXD", 12: "LIN_EN_DRIVE",
               13: "USB_D_MINUS", 14: "USB_D_PLUS", 17: "ARM_SENSE",
               27: "BOOT_GPIO0", 36: "UART0_RX", 37: "UART0_TX",
               40: "GND", 41: "GND"}
    components = [
        component("U1","ESP32-S3-WROOM-1U-N8R8","RF_Module:ESP32-S3-WROOM-1U", 41, u1_nets, 92, 112),
        component("U2","TJA1021T car LIN","Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", 8,
                  {1:"LIN_A_RXD",2:"LIN_EN",3:"WAKE_A_N",4:"LIN_A_TXD",5:"GND",6:"LIN_A_TJA",7:"VBAT_PROTECTED",8:"INH_A_TP"}, 52, 42),
        component("U3","TJA1021T wheel LIN","Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", 8,
                  {1:"LIN_B_RXD",2:"LIN_EN",3:"WAKE_B_N",4:"LIN_B_TXD",5:"GND",6:"LIN_B_TJA",7:"VBAT_PROTECTED",8:"INH_B_TP"}, 52, 78),
        component("U4","LM5164DDA 3V3 buck","Package_SO:HSOP-8-1EP_3.9x4.9mm_P1.27mm_EP2.41x3.1mm_ThermalVias", 9,
                  {1:"GND",2:"VBAT_FILTERED",3:"BUCK_EN",4:"BUCK_RON",5:"BUCK_FB",6:"BUCK_PGOOD",7:"BUCK_BST",8:"BUCK_SW",9:"GND"}, 52, 124),
        component("Q1","AO4407A-class reverse PFET","Package_SO:SOIC-8_3.9x4.9mm_P1.27mm", 8,
                  {1:"VBAT_IN",2:"VBAT_IN",3:"VBAT_IN",4:"GND",5:"VBAT_PROTECTED",6:"VBAT_PROTECTED",7:"VBAT_PROTECTED",8:"VBAT_PROTECTED"}, 52, 156),
        component("J1","USB-C service","Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12", 16,
                  {1:"USB_VBUS",2:"USB_D_MINUS",3:"USB_D_PLUS",4:"CC1",5:"CC2",6:"GND",7:"GND",8:"GND",9:"USB_D_PLUS",10:"USB_D_MINUS",11:"USB_VBUS",12:"GND",13:"GND",14:"GND",15:"GND",16:"GND"}, 148, 44),
        component("J2","car harness Micro-Fit 1x04",HARNESS_CONNECTOR_FOOTPRINT, 4, {1:"VBAT_IN",2:"GND",4:"LIN_A"}, 148, 78),
        component("J3","wheel harness Micro-Fit 1x04",HARNESS_CONNECTOR_FOOTPRINT, 4, {1:"VBAT_PROTECTED",2:"GND",4:"LIN_B"}, 148, 96),
        component("SW1","DPDT physical arm","Button_Switch_SMD:SW_DPDT_CK_JS202011JCQN", 6,
                  {1:"LIN_EN",2:"GND",3:"LIN_EN_DRIVE",4:"ARM_SENSE",5:"GND",6:"3V3"}, 148, 124),
        component("F1","1812 PPTC","Fuse:Fuse_1812_4532Metric", 2, {1:"VBAT_IN",2:"VBAT_PROTECTED"}, 148, 146),
        component("D1","SMBJ24A/26A TVS","Diode_SMD:D_SMB", 2, {1:"VBAT_PROTECTED",2:"GND"}, 148, 158),
        component("FB1","1206 input ferrite","Inductor_SMD:L_1206_3216Metric", 2, {1:"VBAT_PROTECTED",2:"VBAT_FILTERED"}, 148, 170),
        component("D2","LIN_A ESD","Diode_SMD:D_SOD-323", 2, {1:"LIN_A",2:"GND"}, 198, 42),
        component("D3","LIN_B ESD","Diode_SMD:D_SOD-323", 2, {1:"LIN_B",2:"GND"}, 198, 54),
        component("D4","USB ESD","Package_TO_SOT_SMD:SOT-23-6", 6,
                  {1:"USB_D_MINUS",2:"GND",3:"USB_D_PLUS",4:"USB_D_PLUS",5:"USB_VBUS",6:"USB_D_MINUS"}, 198, 72,
                  extra_properties={
                      "MPN": "USBLC6-2SC6",
                      "LCSC Part #": "C7519",
                      "JLC Replacement Note": "2026-06-04 package-correct SOT-23-6L replacement; do not use C138714/USON-10 on this footprint; mass-order check requires package/supplier revalidation",
                  }),
        component("R_CC1","5.1k","Resistor_SMD:R_0603_1608Metric", 2, {1:"CC1",2:"GND"}, 198, 94),
        component("R_CC2","5.1k","Resistor_SMD:R_0603_1608Metric", 2, {1:"CC2",2:"GND"}, 198, 106),
        component("R_EN1","10k","Resistor_SMD:R_0603_1608Metric", 2, {1:"EN",2:"3V3"}, 198, 118),
        component("R_BOOT1","10k","Resistor_SMD:R_0603_1608Metric", 2, {1:"BOOT_GPIO0",2:"3V3"}, 198, 130),
        component("R_LINEN_PD1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_EN",2:"GND"}, 198, 142),
        component("R_ARMSENSE_PD1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"ARM_SENSE",2:"GND"}, 198, 154),
        component("R_WAKE_A1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"WAKE_A_N",2:"VBAT_PROTECTED"}, 198, 166),
        component("R_WAKE_B1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"WAKE_B_N",2:"VBAT_PROTECTED"}, 198, 178),
        component("R_LINA_SER1","10R","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_A",2:"LIN_A_TJA"}, 198, 190),
        component("R_LINB_SER1","10R","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_B",2:"LIN_B_TJA"}, 198, 202),
        component("R_LINA_TXD_PU1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_A_TXD",2:"3V3"}, 198, 214),
        component("R_LINB_TXD_PU1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_B_TXD",2:"3V3"}, 198, 226),
        component("R_LINA_MASTER1","DNP 1k","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_A_MASTER_PU",2:"LIN_A"}, 198, 238, dnp=True),
        component("R_LINB_MASTER1","DNP 1k","Resistor_SMD:R_0603_1608Metric", 2, {1:"LIN_B_MASTER_PU",2:"LIN_B"}, 198, 250, dnp=True),
        component("D_LINA_MASTER1","DNP LIN master diode","Diode_SMD:D_SOD-323", 2, {1:"VBAT_PROTECTED",2:"LIN_A_MASTER_PU"}, 198, 262, dnp=True),
        component("D_LINB_MASTER1","DNP LIN master diode","Diode_SMD:D_SOD-323", 2, {1:"VBAT_PROTECTED",2:"LIN_B_MASTER_PU"}, 198, 274, dnp=True),
        component("R_FB_TOP1","174k","Resistor_SMD:R_0603_1608Metric", 2, {1:"3V3",2:"BUCK_FB"}, 244, 42),
        component("R_FB_BOT1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"BUCK_FB",2:"GND"}, 244, 54),
        component("R_BUCK_EN1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"VBAT_FILTERED",2:"BUCK_EN"}, 244, 66),
        component("R_BUCK_RON1","200k prelim","Resistor_SMD:R_0603_1608Metric", 2, {1:"VBAT_FILTERED",2:"BUCK_RON"}, 244, 78),
        component("R_PGOOD_PU1","100k","Resistor_SMD:R_0603_1608Metric", 2, {1:"BUCK_PGOOD",2:"3V3"}, 244, 90),
        component("C_BST1","100nF 50V","Capacitor_SMD:C_0603_1608Metric", 2, {1:"BUCK_BST",2:"BUCK_SW"}, 244, 106),
        component("L1","10uH shielded","Inductor_SMD:L_Bourns_SRU5016_5.2x5.2mm", 2, {1:"BUCK_SW",2:"3V3"}, 244, 118,
                  extra_properties={
                      "MPN": "SRU5016-100Y",
                      "LCSC Part #": "C5760316",
                      "JLC Replacement Note": "MASS ORDER BLOCKER: 2026-06-04 package-correct Bourns SRU5016 first article only; current-limit bring-up and prove current/thermal margin or select higher-current inductor/footprint before mass ordering",
                  }),
        component("C_IN1","10uF 50V","Capacitor_SMD:C_1206_3216Metric", 2, {1:"VBAT_FILTERED",2:"GND"}, 244, 134),
        component("C_3V3","22uF 10V","Capacitor_SMD:C_1206_3216Metric", 2, {1:"3V3",2:"GND"}, 244, 146),
        component("C_EN1","1uF 10V","Capacitor_SMD:C_0603_1608Metric", 2, {1:"EN",2:"GND"}, 320, 42),
        component("C_U1_DEC1","100nF 50V","Capacitor_SMD:C_0603_1608Metric", 2, {1:"3V3",2:"GND"}, 320, 54),
        component("C_U2_DEC1","100nF 50V","Capacitor_SMD:C_0603_1608Metric", 2, {1:"VBAT_PROTECTED",2:"GND"}, 320, 66),
        component("C_U3_DEC1","100nF 50V","Capacitor_SMD:C_0603_1608Metric", 2, {1:"VBAT_PROTECTED",2:"GND"}, 320, 78),
        component("C_U4_DEC1","100nF 50V","Capacitor_SMD:C_0603_1608Metric", 2, {1:"VBAT_FILTERED",2:"GND"}, 320, 90),
    ]
    tp_labels = "GND 3V3 VBAT USB- USB+ UART_TX UART_RX EN BOOT LIN_A LIN_B LIN_A_TJA LIN_B_TJA LIN_EN LIN_EN_DRV ARM WAKE_A WAKE_B INH_A INH_B".split()
    tp_nmap = {"GND":"GND","3V3":"3V3","VBAT":"VBAT_PROTECTED","USB-":"USB_D_MINUS","USB+":"USB_D_PLUS",
               "UART_TX":"UART0_TX","UART_RX":"UART0_RX","EN":"EN","BOOT":"BOOT_GPIO0",
               "LIN_A":"LIN_A","LIN_B":"LIN_B","LIN_A_TJA":"LIN_A_TJA","LIN_B_TJA":"LIN_B_TJA",
               "LIN_EN":"LIN_EN","LIN_EN_DRV":"LIN_EN_DRIVE","ARM":"ARM_SENSE",
               "WAKE_A":"WAKE_A_N","WAKE_B":"WAKE_B_N","INH_A":"INH_A_TP","INH_B":"INH_B_TP"}
    for idx, label in enumerate(tp_labels):
        components.append(component(f"TP{idx + 1}", label, "TestPoint:TestPoint_Pad_D1.5mm", 1,
                                    {1: tp_nmap[label]}, 244 + (idx % 4) * 32, 170 + (idx // 4) * 12))
    return components


def pin_y(component: SchematicComponent, pin: int) -> float:
    pin1_local_y = ((component.pin_count - 1) // 2) * 2.54
    local_y = pin1_local_y - (pin - 1) * 2.54
    return component.at[1] - local_y


def schematic_wire_and_label(component: SchematicComponent, pin: int, net: str) -> str:
    sx = component.at[0] - 5.08
    lx = component.at[0] - 17.78
    y = pin_y(component, pin)
    return f'''  (wire
    (pts (xy {fmt(lx)} {fmt(y)}) (xy {fmt(sx)} {fmt(y)}))
    (stroke (width 0) (type solid))
    (uuid "{stable_uuid('wire', component.ref, pin)}")
  )
  (label "{q(net)}"
    (at {fmt(lx)} {fmt(y)} 0)
    (effects (font (size 1.27 1.27)) (justify left bottom))
    (uuid "{stable_uuid('label', component.ref, pin, net)}")
  )'''


def schematic_no_connect(component: SchematicComponent, pin: int) -> str:
        x = component.at[0] - 5.08
        y = pin_y(component, pin)
        return f'''  (no_connect
        (at {fmt(x)} {fmt(y)})
        (uuid "{stable_uuid('no-connect', component.ref, pin)}")
    )'''


def schematic_property(name: str, value: str, x: float, y: float, hidden: bool = False) -> str:
    h = "\n      (hide yes)" if hidden else ""
    return f'''    (property "{q(name)}" "{q(value)}"
      (at {fmt(x)} {fmt(y)} 0){h}
      (effects (font (size 1.27 1.27)))
    )'''


def schematic_symbol(component: SchematicComponent) -> str:
    x, y = component.at
    pins = "\n".join(
        f'    (pin "{pin}"\n      (uuid "{stable_uuid("sym-pin", component.ref, pin)}")\n    )'
        for pin in sorted(component.pins)
    )
    extra_properties = "\n".join(
        schematic_property(name, value, x, y, hidden=True)
        for name, value in component.extra_properties
    )
    return f'''  (symbol
    (lib_id "{component.lib_id}")
    (at {fmt(x)} {fmt(y)} 0)
    (unit 1) (exclude_from_sim no) (in_bom yes) (on_board yes) (dnp {"yes" if component.dnp else "no"})
    (uuid "{stable_uuid('symbol', component.ref)}")
{schematic_property('Reference', component.ref, x, y - (component.pin_count * 1.27 + 4))}
{schematic_property('Value', component.value, x, y + (component.pin_count * 1.27 + 4))}
{schematic_property('Footprint', component.footprint, x, y, hidden=True)}
{schematic_property('Datasheet', '~', x, y, hidden=True)}
{schematic_property('Description', component.description, x, y, hidden=True)}
{extra_properties}
{pins}
    (instances
      (project "tesla-dual-lin-rev-a"
        (path "/{stable_uuid('project-path', component.ref)}"
          (reference "{component.ref}") (unit 1)))
    )
  )'''


def generate_schematic() -> str:
    components = schematic_components()
    ls = generate_lib_symbols(components)
    nets = "\n".join(
        schematic_no_connect(c, p) if n.startswith("NC_") else schematic_wire_and_label(c, p, n)
        for c in components for p, n in sorted(c.pins.items())
    )
    syms = "\n".join(schematic_symbol(c) for c in components)
    return f'''(kicad_sch
  (version 20250114)
  (generator "tesla-dual-lin-rev-a-generator") (generator_version "1")
  (uuid "{stable_uuid('schematic-root')}")
  (paper "A4")
  (title_block
    (title "Tesla Dual LIN Rev A") (rev "A")
    (company "LPT / Personal Secretary hardware project")
    (comment 1 "Dual TJA1021 LIN proxy, ESP32-S3, LM5164DDA buck, DPDT physical arm gate"))
  (lib_symbols\n{ls}\n  )
{nets}
{syms}
)'''


def extract_symbol_block(text: str, symbol_name: str) -> str:
    marker = f'(symbol "{symbol_name}"'
    start = text.find(marker)
    if start < 0:
        raise ValueError(f"Symbol {symbol_name} not found")
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    raise ValueError(f"Symbol {symbol_name} not balanced")


def indent_block(text: str, spaces: int) -> str:
    pre = " " * spaces
    return "\n".join(pre + line if line else line for line in text.splitlines())


def generate_lib_symbols(components: list[SchematicComponent]) -> str:
    share = locate_kicad_share()
    clib = share / "symbols" / "Connector_Generic.kicad_sym"
    raw = clib.read_text(encoding="utf-8")
    names = sorted({f"Conn_01x{c.pin_count:02d}" for c in components})
    blocks = []
    for name in names:
        block = extract_symbol_block(raw, name)
        block = block.replace(f'(symbol "{name}"', f'(symbol "Connector_Generic:{name}"', 1)
        blocks.append(indent_block(block, 4))
    return "\n".join(blocks)


def locate_kicad_share() -> Path:
    lap = os.environ.get("LOCALAPPDATA")
    candidates: list[Path] = []
    if lap:
        candidates.append(Path(lap) / "Programs" / "KiCad" / "10.0" / "share" / "kicad")
    candidates.extend([
        Path("C:/Program Files/KiCad/10.0/share/kicad"),
        Path("C:/Users/ezabz/AppData/Local/Programs/KiCad/10.0/share/kicad"),
    ])
    for c in candidates:
        if (c / "footprints").exists():
            return c
    raise FileNotFoundError("KiCad 10 share not found")


# PCB generation

def footprint_file(share: Path, footprint: str) -> Path:
    if ":" not in footprint:
        raise ValueError(f"Footprint must use Lib:Name: {footprint}")
    lib, name = footprint.split(":", 1)
    p = share / "footprints" / f"{lib}.pretty" / f"{name}.kicad_mod"
    if not p.exists():
        raise FileNotFoundError(f"Missing footprint {footprint}: {p}")
    return p


def strip_top(text: str) -> str:
    for kw in ["version", "generator", "generator_version"]:
        text = re.sub(rf'\n\s*\({kw}[^\n]+\)', '', text, count=1)
    return text


def replace_prop(text: str, name: str, value: str) -> str:
    return re.sub(rf'(\(property "{re.escape(name)}" ")[^"]*("\s*\n)', rf'\g<1>{q(value)}\2', text, count=1)


def uniquify_uuids(text: str, ref: str) -> str:
    counter = 0

    def repl(match: re.Match[str]) -> str:
        nonlocal counter
        counter += 1
        return f'(uuid "{stable_uuid("fp-uuid", ref, counter)}")'

    return re.sub(r'\(uuid "[^"]+"\)', repl, text)


def strip_silkscreen(text: str) -> str:
    text = text.replace('(layer "F.SilkS")', '(layer "F.Fab")')
    text = text.replace('(layer "B.SilkS")', '(layer "B.Fab")')
    parts: list[str] = []
    i = 0
    while i < len(text):
        ps = text.find("(fp_", i)
        if ps < 0:
            parts.append(text[i:])
            break
        parts.append(text[i:ps])
        depth = 0
        j = ps
        while j < len(text):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        block = text[ps:j]
        if '(layer "F.Fab")' in block or '(layer "B.Fab")' in block:
            parts.append(block)
        i = j
    return "".join(parts)


def normalize_drills(text: str) -> str:
    return text.replace("(drill 0.2)", "(drill 0.3)")


def assign_nets(text: str, inst: FootprintInstance) -> str:
    pn = inst.pad_nets
    if not pn:
        return text
    lu = {str(k): (net_index(v), v) for k, v in pn.items()}
    parts = []
    i = 0
    while i < len(text):
        ps = text.find("(pad ", i)
        if ps < 0:
            parts.append(text[i:])
            break
        parts.append(text[i:ps])
        depth = 0
        j = ps
        while j < len(text):
            if text[j] == "(":
                depth += 1
            elif text[j] == ")":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        blk = text[ps:j]
        m = re.match(r'\(pad\s+"?([^"\s]+)"?', blk)
        if m and m.group(1) in lu:
            ni, nn = lu[m.group(1)]
            net_line = f'\n\t\t(net {ni} "{q(nn)}")'
            if re.search(r'\n\s*\(net\s+\d+\s+"[^"]*"\)', blk):
                blk = re.sub(r'\n\s*\(net\s+\d+\s+"[^"]*"\)', net_line, blk, count=1)
            else:
                blk = blk.rstrip()
                if blk.endswith(")"):
                    blk = blk[:-1].rstrip() + net_line + "\n\t)"
        parts.append(blk)
        i = j
    return "".join(parts)


def board_footprint(inst: FootprintInstance, share: Path) -> str:
    raw = footprint_file(share, inst.footprint).read_text(encoding="utf-8")
    text = strip_top(raw)
    text = re.sub(r'^\(footprint "[^"]+"', f'(footprint "{q(inst.footprint)}"', text, count=1)
    if '(uuid ' not in text.split('\n', 8)[0]:
        text = text.replace('\n\t(layer ', f'\n\t(uuid "{stable_uuid("fp", inst.ref)}")\n\t(layer ', 1)
    text = re.sub(r'\n\s*\(at [-0-9.]+ [-0-9.]+(?: [-0-9.]+)?\)', '', text, count=1)
    ats = f'\n\t(at {fmt(inst.at[0])} {fmt(inst.at[1])}'
    if inst.rotation:
        ats += f' {fmt(inst.rotation)}'
    ats += ')'
    text = text.replace(f'\n\t(layer "{inst.layer}")', f'\n\t(layer "{inst.layer}"){ats}', 1)
    text = replace_prop(text, "Reference", inst.ref)
    text = replace_prop(text, "Value", inst.value)
    text = strip_silkscreen(text)
    text = normalize_drills(text)
    text = uniquify_uuids(text, inst.ref)
    text = assign_nets(text, inst)
    text = re.sub(r'\n\s*\(path "[^"]+"\)', '', text, count=1)
    text = text.rstrip()
    if not text.endswith(")"):
        raise ValueError(f"FP {inst.ref} no closing paren")
    text = text[:-1] + f'\n\t(path "/{stable_uuid("fp-path", inst.ref)}")\n)'
    return text


def mounting_holes() -> str:
    holes = []
    for cx, cy, ref in [(4, 4, "MH1"), (BOARD_W - 4, 4, "MH2"),
                         (4, BOARD_H - 4, "MH3"), (BOARD_W - 4, BOARD_H - 4, "MH4")]:
        holes.append(f'''  (footprint "MountingHole:MountingHole_3.2mm_M3"
    (layer "F.Cu") (uuid "{stable_uuid("mh", ref)}")
    (at {fmt(cx)} {fmt(cy)})
    (property "Reference" "{ref}" (at {fmt(cx)} {fmt(cy - 4)} 0) (layer "F.Fab")
      (uuid "{stable_uuid("mh-ref", ref)}") (effects (font (size 1 1) (thickness 0.15))))
    (property "Value" "MH3.2" (at {fmt(cx)} {fmt(cy + 4)} 0) (layer "F.Fab")
      (uuid "{stable_uuid("mh-val", ref)}") (effects (font (size 1 1) (thickness 0.15))))
    (path "/{stable_uuid("mh-path", ref)}")
  )''')
    return "\n".join(holes)


def copper_zones() -> str:
    # 4-layer GND strategy:
    #   F.Cu  : GND pour (thermal-relief pads, island_removal_mode 0 so stranded
    #           copper is dropped rather than flagged). The pour carries most of
    #           the top-side GND so FreeRouting is not overloaded routing GND.
    #   In2.Cu: solid GND plane, SOLID pad connection, the connectivity backbone.
    #   B.Cu  : GND pour for bottom-side return copper, same handling as F.Cu.
    # A dense via grid (see stitching_vias) ties the pours to the plane.
    poly = (f"(polygon (pts (xy 1 1) (xy {fmt(BOARD_W - 1)} 1) "
            f"(xy {fmt(BOARD_W - 1)} {fmt(BOARD_H - 1)}) (xy 1 {fmt(BOARD_H - 1)})))")
    specs = [
        # layer,   connect_pads,                          island_removal, min_thick
        ("F.Cu", "(connect_pads yes (clearance 0.2032))", 0, 0.13),
        ("In2.Cu", "(connect_pads yes (clearance 0.2032))", 1, 0.2032),
        ("B.Cu", "(connect_pads yes (clearance 0.2032))", 0, 0.13),
    ]
    nidx = net_index("GND")
    zones = []
    for layer, connect, removal, min_thick in specs:
        zones.append(f'''  (zone
    (net {nidx}) (net_name "GND")
    (layer "{layer}") (uuid "{stable_uuid("zone", layer)}")
    (hatch edge 0.508) (priority 1)
    {connect}
    (min_thickness {fmt(min_thick)}) (filled_areas_thickness no)
    (fill (mode polygon) (thermal_gap 0.508) (thermal_bridge_width 0.508) (island_removal_mode {removal}) (island_area_min 10))
        {poly}
  )''')
    return "\n".join(zones)


def keepout_zones() -> str:
    """Track/via keepout rule areas around fiducials.

    Fiducials are <no net> pads with a 0.6 mm local clearance override that
    FreeRouting does not honor, so it can route a track within ~0.5 mm of the
    fiducial copper (clearance + solder-mask-bridge errors). A Specctra keepout
    (exported from a KiCad rule area) forces the autorouter to keep tracks and
    vias out of a 1.6 mm radius ring; copper pours are still allowed so the GND
    pour fills around the fiducial normally.
    """
    import math

    fids = [(42.0, 5.0, "FID1"), (58.0, 5.0, "FID2"), (94.0, 44.0, "FID3")]
    r = 1.6
    zones = []
    for cx, cy, ref in fids:
        pts = " ".join(
            f"(xy {fmt(cx + r * math.cos(a))} {fmt(cy + r * math.sin(a))})"
            for a in (math.radians(d) for d in range(0, 360, 45))
        )
        zones.append(f'''  (zone
    (net 0) (net_name "")
    (layers "*.Cu") (uuid "{stable_uuid("fidkeep", ref)}")
    (hatch edge 0.508) (name "keepout_{ref}")
    (keepout (tracks not_allowed) (vias not_allowed) (pads allowed) (copperpour allowed) (footprints allowed))
    (fill (mode polygon))
    (polygon (pts {pts}))
  )''')

    # Perimeter keepout strips: keep autorouter tracks/vias >= the board-edge
    # clearance (0.5 mm) from the outline. FreeRouting otherwise squeezes vias
    # near the edge by the USB-C connector. Copper pours still fill (the pour
    # polygon is inset 1 mm) and pre-placed stitch vias sit at a 1.2 mm margin.
    w = 0.6
    strips = [
        (0.0, 0.0, BOARD_W, w, "top"),
        (0.0, BOARD_H - w, BOARD_W, BOARD_H, "bot"),
        (0.0, 0.0, w, BOARD_H, "left"),
        (BOARD_W - w, 0.0, BOARD_W, BOARD_H, "right"),
    ]
    for x0, y0, x1, y1, tag in strips:
        pts = (f"(xy {fmt(x0)} {fmt(y0)}) (xy {fmt(x1)} {fmt(y0)}) "
               f"(xy {fmt(x1)} {fmt(y1)}) (xy {fmt(x0)} {fmt(y1)})")
        zones.append(f'''  (zone
    (net 0) (net_name "")
    (layers "*.Cu") (uuid "{stable_uuid("edgekeep", tag)}")
    (hatch edge 0.508) (name "keepout_edge_{tag}")
    (keepout (tracks not_allowed) (vias not_allowed) (pads allowed) (copperpour allowed) (footprints allowed))
    (fill (mode polygon))
    (polygon (pts {pts}))
  )''')
    return "\n".join(zones)


def _footprint_keepout_radius(footprint: str, value: str) -> float:
    """Approximate courtyard radius (mm) used to keep stitching vias clear."""
    f = footprint.lower()
    if "esp32" in f:
        return 13.0
    if "usb_c" in f or "type-c" in f:
        return 9.0
    if "soic" in f or "hsop" in f or "so-8" in f or "package_so" in f:
        return 4.5
    if "sot-23" in f or "dpdt" in f or "sw_" in f:
        return 4.0
    if "inductor" in f or "l_" in f or "fuse" in f or "1812" in f or "1206" in f or "d_smb" in f:
        return 3.0
    if "sod-323" in f or "0603" in f or "0603" in value:
        return 2.0
    if "testpoint" in f or "fiducial" in f or "mountinghole" in f:
        return 2.5
    if "micro-fit" in f or "micro_fit" in f:
        return 8.5
    return 3.0


def connector_pin_labels() -> str:
    specs = [
        ("J2 1V 2G 3NC 4L", 1.0, 23.6, "j2"),
        ("J3 1V 2G 3NC 4L", 1.0, 35.6, "j3"),
    ]
    return "\n".join(
        f'  (gr_text "{q(text)}" (at {fmt(x)} {fmt(y)} 0) '
        f'(layer "F.SilkS") (uuid "{stable_uuid("conn-label", tag)}") '
        f'(effects (font (size 0.8 0.8) (thickness 0.1)) (justify left)))'
        for text, x, y, tag in specs
    )


def stitching_vias() -> str:
    """GND stitching vias tying F.Cu <-> In2 plane <-> B.Cu together.

    Placed pre-route so FreeRouting treats them as fixed GND obstacles and
    routes around them. A sparse grid ties fragmented outer pours into the
    internal plane; extra vias near J1 (board-edge USB-C) connect its GND.
    """
    nidx = net_index("GND")
    via_r = 0.3          # via radius (size 0.6)
    edge_margin = 1.2    # via center >= this from board edge (>=0.5 copper-edge)
    j1_at = (82.0, 6.0)  # USB-C connector center
    keepouts: list[tuple[float, float, float]] = []
    for inst in footprint_instances():
        cx, cy = inst.at
        keepouts.append((cx, cy, _footprint_keepout_radius(inst.footprint, inst.value)))
    # Mounting holes M3 at the four corners (5mm keepout).
    for hx, hy in ((4, 4), (BOARD_W - 4, 4), (4, BOARD_H - 4), (BOARD_W - 4, BOARD_H - 4)):
        keepouts.append((hx, hy, 4.0))

    def clear(x: float, y: float, ignore: tuple[float, float] | None = None) -> bool:
        if x < edge_margin or x > BOARD_W - edge_margin:
            return False
        if y < edge_margin or y > BOARD_H - edge_margin:
            return False
        for kx, ky, kr in keepouts:
            if ignore is not None and abs(kx - ignore[0]) < 1e-6 and abs(ky - ignore[1]) < 1e-6:
                continue
            if (x - kx) ** 2 + (y - ky) ** 2 < (kr + via_r) ** 2:
                return False
        return True

    points: list[tuple[float, float]] = []
    # Dense grid stitch ties fragmented outer pours into the In2 plane.
    gx = 6.0
    y = edge_margin + 1.0
    while y <= BOARD_H - edge_margin:
        x = edge_margin + 1.0
        while x <= BOARD_W - edge_margin:
            if clear(x, y):
                points.append((round(x, 3), round(y, 3)))
            x += gx
        y += gx
    # Targeted GND vias below J1 (USB-C) give FreeRouting nearby GND landing
    # points to route the connector's GND pads down to the In2 plane. They sit
    # inside J1's own keepout but are checked against every other footprint.
    j1_targets = [(77.5, 10.5), (82.0, 10.5), (86.5, 10.5)]
    for jx, jy in j1_targets:
        if clear(jx, jy, ignore=j1_at) and all(
            (jx - px) ** 2 + (jy - py) ** 2 > 4 for px, py in points
        ):
            points.append((jx, jy))

    vias = []
    for i, (x, y) in enumerate(points):
        vias.append(
            f'  (via (at {fmt(x)} {fmt(y)}) (size 0.6) (drill 0.3) '
            f'(layers "F.Cu" "B.Cu") (net {nidx}) '
            f'(uuid "{stable_uuid("stitch", i)}"))'
        )
    return "\n".join(vias)


def footprint_instances() -> list[FootprintInstance]:
    pas = "Resistor_SMD:R_0603_1608Metric"
    c0603 = "Capacitor_SMD:C_0603_1608Metric"
    c1206 = "Capacitor_SMD:C_1206_3216Metric"
    soic8 = "Package_SO:SOIC-8_3.9x4.9mm_P1.27mm"
    sod323 = "Diode_SMD:D_SOD-323"
    inst: list[FootprintInstance] = []

    # M3 holes at (4,4) (96,4) (4,52) (96,52); 5mm keepout around each.
    # TP row is slightly compressed upward to reduce area while preserving connector functionality.

    # Buck + power (left, x=6..34, y=10..40)
    inst.extend([
        FootprintInstance("U4","LM5164DDA","Package_SO:HSOP-8-1EP_3.9x4.9mm_P1.27mm_EP2.41x3.1mm_ThermalVias",
                          (16,12),0,pad_nets={1:"GND",2:"VBAT_FILTERED",3:"BUCK_EN",4:"BUCK_RON",5:"BUCK_FB",6:"BUCK_PGOOD",7:"BUCK_BST",8:"BUCK_SW",9:"GND"}),
            FootprintInstance("C_IN1","10uF 50V",c1206,(30,12),0,pad_nets={1:"VBAT_FILTERED",2:"GND"}),
            FootprintInstance("L1","10uH","Inductor_SMD:L_Bourns_SRU5016_5.2x5.2mm",(16,24),0,pad_nets={1:"BUCK_SW",2:"3V3"}),
            FootprintInstance("C_3V3","22uF 10V",c1206,(30,24),0,pad_nets={1:"3V3",2:"GND"}),
            FootprintInstance("C_BST1","100nF",c0603,(22,36),0,pad_nets={1:"BUCK_BST",2:"BUCK_SW"}),
        FootprintInstance("C_U4_DEC1","100nF",c0603,(24,8),0,pad_nets={1:"VBAT_FILTERED",2:"GND"}),
    ])
    for idx, (ref, nets) in enumerate([
        ("R_FB_TOP1",{1:"3V3",2:"BUCK_FB"}),
        ("R_FB_BOT1",{1:"BUCK_FB",2:"GND"}),
        ("R_BUCK_EN1",{1:"VBAT_FILTERED",2:"BUCK_EN"}),
        ("R_BUCK_RON1",{1:"VBAT_FILTERED",2:"BUCK_RON"}),
        ("R_PGOOD_PU1",{1:"BUCK_PGOOD",2:"3V3"}),
    ]):
        inst.append(FootprintInstance(ref,"0603",pas,(10+idx*5,40),0,pad_nets=nets))

    # Power protection and keyed harness service connectors (left side).
    inst.extend([
        FootprintInstance("J2","Molex Micro-Fit car service",HARNESS_CONNECTOR_FOOTPRINT,(6,18),0,
                          pad_nets={1:"VBAT_IN",2:"GND",4:"LIN_A"}),
        FootprintInstance("J3","Molex Micro-Fit wheel service",HARNESS_CONNECTOR_FOOTPRINT,(6,30),0,
                          pad_nets={1:"VBAT_PROTECTED",2:"GND",4:"LIN_B"}),
        FootprintInstance("Q1","AO4407A PFET",soic8,(10,44),0,
                          pad_nets={1:"VBAT_IN",2:"VBAT_IN",3:"VBAT_IN",4:"GND",5:"VBAT_PROTECTED",6:"VBAT_PROTECTED",7:"VBAT_PROTECTED",8:"VBAT_PROTECTED"}),
        FootprintInstance("F1","1812 PPTC","Fuse:Fuse_1812_4532Metric",(16,50),0,pad_nets={1:"VBAT_IN",2:"VBAT_PROTECTED"}),
        FootprintInstance("D1","SMBJ24A","Diode_SMD:D_SMB",(30,48),0,pad_nets={1:"VBAT_PROTECTED",2:"GND"}),
        FootprintInstance("FB1","1206 ferrite","Inductor_SMD:L_1206_3216Metric",(44,48),0,pad_nets={1:"VBAT_PROTECTED",2:"VBAT_FILTERED"}),
    ])

    # LIN transceivers (mid, x=42..70, y=6..50, 22mm pitched)
    inst.extend([
        FootprintInstance("U2","TJA1021T car",soic8,(48,8),0,
                          pad_nets={1:"LIN_A_RXD",2:"LIN_EN",3:"WAKE_A_N",4:"LIN_A_TXD",5:"GND",6:"LIN_A_TJA",7:"VBAT_PROTECTED",8:"INH_A_TP"}),
        FootprintInstance("U3","TJA1021T wheel",soic8,(48,32),0,
                          pad_nets={1:"LIN_B_RXD",2:"LIN_EN",3:"WAKE_B_N",4:"LIN_B_TXD",5:"GND",6:"LIN_B_TJA",7:"VBAT_PROTECTED",8:"INH_B_TP"}),
    ])
    for ref, nets, at in [
        ("R_WAKE_A1",{1:"WAKE_A_N",2:"VBAT_PROTECTED"},(64,8)),
        ("R_WAKE_B1",{1:"WAKE_B_N",2:"VBAT_PROTECTED"},(70,8)),
        ("R_LINA_SER1",{1:"LIN_A",2:"LIN_A_TJA"},(66,20)),
        ("R_LINB_SER1",{1:"LIN_B",2:"LIN_B_TJA"},(68,32)),
        ("R_LINEN_PD1",{1:"LIN_EN",2:"GND"},(73,32)),
        ("R_ARMSENSE_PD1",{1:"ARM_SENSE",2:"GND"},(78,32)),
        ("R_LINA_TXD_PU1",{1:"LIN_A_TXD",2:"3V3"},(58,14)),
        ("R_LINB_TXD_PU1",{1:"LIN_B_TXD",2:"3V3"},(58,38)),
        ("R_LINA_MASTER1",{1:"LIN_A_MASTER_PU",2:"LIN_A"},(62,18)),
        ("R_LINB_MASTER1",{1:"LIN_B_MASTER_PU",2:"LIN_B"},(62,36)),
    ]:
        inst.append(FootprintInstance(ref,"0603",pas,at,0,pad_nets=nets))
    inst.append(FootprintInstance("D2","LIN_A ESD",sod323,(74,20),0,pad_nets={1:"LIN_A",2:"GND"}))
    inst.append(FootprintInstance("D3","LIN_B ESD",sod323,(78,40),0,pad_nets={1:"LIN_B",2:"GND"}))
    inst.append(FootprintInstance("D_LINA_MASTER1","DNP LIN master diode",sod323,(66,16),0,pad_nets={1:"VBAT_PROTECTED",2:"LIN_A_MASTER_PU"}))
    inst.append(FootprintInstance("D_LINB_MASTER1","DNP LIN master diode",sod323,(66,34),0,pad_nets={1:"VBAT_PROTECTED",2:"LIN_B_MASTER_PU"}))
    inst.append(FootprintInstance("C_U2_DEC1","100nF",c0603,(58,8),0,pad_nets={1:"VBAT_PROTECTED",2:"GND"}))
    inst.append(FootprintInstance("C_U3_DEC1","100nF",c0603,(58,32),0,pad_nets={1:"VBAT_PROTECTED",2:"GND"}))

    # ESP32 + DPDT + USB (right, x=72..96)
    inst.append(FootprintInstance("U1","ESP32-S3-WROOM-1U","RF_Module:ESP32-S3-WROOM-1U",(90,32),0,
        pad_nets={1:"GND",2:"3V3",3:"EN",4:"LIN_A_RXD",5:"LIN_A_TXD",6:"LIN_B_RXD",7:"LIN_B_TXD",
                  12:"LIN_EN_DRIVE",13:"USB_D_MINUS",14:"USB_D_PLUS",17:"ARM_SENSE",
                  27:"BOOT_GPIO0",36:"UART0_RX",37:"UART0_TX",40:"GND",41:"GND"}))
    inst.append(FootprintInstance("SW1","DPDT ARM","Button_Switch_SMD:SW_DPDT_CK_JS202011JCQN",
                                   (66,46),0,pad_nets={1:"LIN_EN",2:"GND",3:"LIN_EN_DRIVE",4:"ARM_SENSE",5:"GND",6:"3V3"}))
    inst.append(FootprintInstance("J1","USB-C","Connector_USB:USB_C_Receptacle_HRO_TYPE-C-31-M-12",
                                   (82,6),0,
                                   pad_nets={"A1":"GND","A4":"USB_VBUS","A5":"CC1",
                                             "A6":"USB_D_PLUS","A7":"USB_D_MINUS","A9":"USB_VBUS","A12":"GND",
                                             "B1":"GND","B4":"USB_VBUS","B5":"CC2",
                                             "B6":"USB_D_PLUS","B7":"USB_D_MINUS","B9":"USB_VBUS","B12":"GND",
                                             "SH":"GND"}))
    inst.append(FootprintInstance("D4","USB ESD","Package_TO_SOT_SMD:SOT-23-6",(86,15),0,
        pad_nets={1:"USB_D_MINUS",2:"GND",3:"USB_D_PLUS",4:"USB_D_PLUS",5:"USB_VBUS",6:"USB_D_MINUS"}))
    for idx, (ref, nets) in enumerate([
        ("R_EN1",{1:"EN",2:"3V3"}), ("R_BOOT1",{1:"BOOT_GPIO0",2:"3V3"}),
        ("R_CC1",{1:"CC1",2:"GND"}), ("R_CC2",{1:"CC2",2:"GND"}),
    ]):
        inst.append(FootprintInstance(ref,"0603",pas,(76+(idx%2)*5,44+(idx//2)*4),0,pad_nets=nets))
    inst.append(FootprintInstance("C_U1_DEC1","100nF",c0603,(78,24),0,pad_nets={1:"3V3",2:"GND"}))
    inst.append(FootprintInstance("C_EN1","1uF 10V",c0603,(86,46),0,pad_nets={1:"EN",2:"GND"}))

    # TP row (y=50, x=7..92)
    tp_labels = "GND 3V3 VBAT USB- USB+ UART_TX UART_RX EN BOOT LIN_A LIN_B LIN_A_TJA LIN_B_TJA LIN_EN LIN_EN_DRV ARM WAKE_A WAKE_B INH_A INH_B".split()
    tp_nmap = {"GND":"GND","3V3":"3V3","VBAT":"VBAT_PROTECTED","USB-":"USB_D_MINUS","USB+":"USB_D_PLUS",
               "UART_TX":"UART0_TX","UART_RX":"UART0_RX","EN":"EN","BOOT":"BOOT_GPIO0",
               "LIN_A":"LIN_A","LIN_B":"LIN_B","LIN_A_TJA":"LIN_A_TJA","LIN_B_TJA":"LIN_B_TJA",
               "LIN_EN":"LIN_EN","LIN_EN_DRV":"LIN_EN_DRIVE","ARM":"ARM_SENSE",
               "WAKE_A":"WAKE_A_N","WAKE_B":"WAKE_B_N","INH_A":"INH_A_TP","INH_B":"INH_B_TP"}
    for idx, label in enumerate(tp_labels):
        inst.append(FootprintInstance(f"TP{idx+1}",label,"TestPoint:TestPoint_Pad_D1.5mm",
                           (7+idx*4.5,50),0,pad_nets={1:tp_nmap.get(label,"GND")}))

    # Fiducials (top edge, clear of MH and components)
    inst.extend([
        FootprintInstance("FID1","FID","Fiducial:Fiducial_1mm_Mask2mm",(42,5),0),
        FootprintInstance("FID2","FID","Fiducial:Fiducial_1mm_Mask2mm",(58,5),0),
        FootprintInstance("FID3","FID","Fiducial:Fiducial_1mm_Mask2mm",(94,44),0),
    ])
    return inst


def generate_board() -> str:
    share = locate_kicad_share()
    fps = "\n".join(board_footprint(x, share) for x in footprint_instances())
    mh = mounting_holes()
    zones = copper_zones()
    keepouts = keepout_zones()
    vias = stitching_vias()
    labels = connector_pin_labels()
    return f'''(kicad_pcb
  (version 20250513)
  (generator "tesla-dual-lin-rev-a-generator") (generator_version "1")
  (general (thickness 1.6) (legacy_teardrops no))
  (paper "A4")
  (title_block
    (title "Tesla Dual LIN Rev A") (rev "A")
    (company "LPT / Personal Secretary hardware project")
    (comment 1 "100x56mm 4-layer prototype - all pads net-assigned, copper pours, 4xM3 holes"))
  (layers
    (0 "F.Cu" signal) (4 "In1.Cu" power) (6 "In2.Cu" power) (2 "B.Cu" signal)
    (9 "F.Adhes" user "F.Adhesive") (11 "B.Adhes" user "B.Adhesive")
    (13 "F.Paste" user) (15 "B.Paste" user)
    (5 "F.SilkS" user "F.Silkscreen") (7 "B.SilkS" user "B.Silkscreen")
    (1 "F.Mask" user) (3 "B.Mask" user)
    (17 "Dwgs.User" user "User.Drawings") (19 "Cmts.User" user "User.Comments")
    (21 "Eco1.User" user "User.Eco1") (23 "Eco2.User" user "User.Eco2")
    (25 "Edge.Cuts" user) (27 "Margin" user)
    (31 "F.CrtYd" user "F.Courtyard") (29 "B.CrtYd" user "B.Courtyard")
    (35 "F.Fab" user) (33 "B.Fab" user))
  (setup
    (stackup
      (layer "F.SilkS" (type "Top Silk Screen") (color "White"))
      (layer "F.Paste" (type "Top Solder Paste"))
      (layer "F.Mask" (type "Top Solder Mask") (color "Green") (thickness 0.01))
      (layer "F.Cu" (type "copper") (thickness 0.035))
      (layer "dielectric 1" (type "prepreg") (thickness 0.18) (material "FR4") (epsilon_r 4.5) (loss_tangent 0.02))
      (layer "In1.Cu" (type "copper") (thickness 0.0175))
      (layer "dielectric 2" (type "core") (thickness 1.17) (material "FR4") (epsilon_r 4.5) (loss_tangent 0.02))
      (layer "In2.Cu" (type "copper") (thickness 0.0175))
      (layer "dielectric 3" (type "prepreg") (thickness 0.18) (material "FR4") (epsilon_r 4.5) (loss_tangent 0.02))
      (layer "B.Cu" (type "copper") (thickness 0.035))
      (layer "B.Mask" (type "Bottom Solder Mask") (color "Green") (thickness 0.01))
      (layer "B.Paste" (type "Bottom Solder Paste"))
      (layer "B.SilkS" (type "Bottom Silk Screen") (color "White"))
      (copper_finish "ENIG") (dielectric_constraints no))
    (pad_to_mask_clearance 0)
    (allow_soldermask_bridges_in_footprints no)
    (tenting front back)
    (pcbplotparams
      (layerselection 0x00000000_00000000_000000fc_ffffffff)
      (plot_on_all_layers_selection 0x00000000_00000000_00000020_00000000)
      (disableapertmacros no) (usegerberextensions no)
      (usegerberattributes yes) (usegerberadvancedattributes yes)
      (creategerberjobfile yes) (plotframeref no) (mode 1)
      (useauxorigin yes) (hpglpennumber 1) (hpglpenspeed 20)
      (hpglpendiameter 15.000000) (pdf_front_fp_property_popups yes)
      (pdf_back_fp_property_popups yes) (pdf_metadata yes)
      (pdf_single_document no) (dxfpolygonmode yes) (dxfimperialunits yes)
      (dxfusepcbnewfont yes) (psnegative no) (psa4output no)
      (plot_black_and_white yes) (plotinvisibletext no)
      (sketchpadsonfab no) (plotpadnumbers no) (hidednponfab no)
      (sketchdnponfab yes) (crossoutdnponfab yes) (subtractmaskfromsilk yes)
      (outputformat 1) (mirror no) (drillshape 0) (scaleselection 1)
      (outputdirectory "gerbers"))
  )
{net_declarations()}
{mh}
{zones}
{keepouts}
{vias}
{labels}
  (gr_line (start 0 0) (end {fmt(BOARD_W)} 0) (stroke (width 0.1) (type solid)) (layer "Edge.Cuts") (uuid "{stable_uuid('edge',1)}"))
  (gr_line (start {fmt(BOARD_W)} 0) (end {fmt(BOARD_W)} {fmt(BOARD_H)}) (stroke (width 0.1) (type solid)) (layer "Edge.Cuts") (uuid "{stable_uuid('edge',2)}"))
  (gr_line (start {fmt(BOARD_W)} {fmt(BOARD_H)}) (end 0 {fmt(BOARD_H)}) (stroke (width 0.1) (type solid)) (layer "Edge.Cuts") (uuid "{stable_uuid('edge',3)}"))
  (gr_line (start 0 {fmt(BOARD_H)}) (end 0 0) (stroke (width 0.1) (type solid)) (layer "Edge.Cuts") (uuid "{stable_uuid('edge',4)}"))
{fps}
)'''


def main() -> int:
    KICAD_DIR.mkdir(parents=True, exist_ok=True)
    SCHEMATIC_PATH.write_text(generate_schematic(), encoding="utf-8")
    PCB_PATH.write_text(generate_board(), encoding="utf-8")
    print(f"Generated {SCHEMATIC_PATH}")
    print(f"Generated {PCB_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())