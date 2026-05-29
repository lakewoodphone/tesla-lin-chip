#!/usr/bin/env python3
"""
LIN payload calculator - generate Tesla anti-nag frames or verify checksums.

Bench-only tool. Generates correct LIN 2.1 enhanced checksums for ID 0x0C
frames and can verify capture payloads.

Usage:
    python lin-payload-calc.py antinag [--id 0x0C] [--cycles 8]
    python lin-payload-calc.py verify 0x0C 11 04 00 00 00 00 C0 0F CE
    python lin-payload-calc.py checksum 0x0C 10 00 00 00 00 00 C0 0F
    python lin-payload-calc.py idle [--id 0x0C] [--counter 0]
    python lin-payload-calc.py scan 0x0C 0x2A 0x2B 0x3C
"""

import sys

# -- LIN protocol helpers ----------------------------------------------

def make_protected_id(raw_id: int) -> int:
    """Compute LIN 2.x protected ID (PID) from raw 6-bit ID."""
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


def lin_checksum(pid: int, data: list, enhanced: bool = True) -> int:
    """LIN checksum (enhanced = includes PID, classic = data only)."""
    s = pid if enhanced else 0
    for b in data:
        s += b
        if s > 0xFF:
            s -= 0xFF
    return 0xFF - s


def verify_frame(frame_hex: str) -> dict:
    """Verify a complete LIN frame string: '0x0C 11 04 00 00 00 00 C0 0F CE'"""
    parts = [int(x, 16) for x in frame_hex.replace(",", " ").split()]
    raw_id = parts[0]
    pid = make_protected_id(raw_id)
    data = parts[1:-1]
    rx_chk = parts[-1]

    exp_enh = lin_checksum(pid, data, enhanced=True)
    exp_cls = lin_checksum(pid, data, enhanced=False)

    return {
        "raw_id": raw_id,
        "id_hex": f"0x{raw_id:02X}",
        "pid_hex": f"0x{pid:02X}",
        "data": [f"0x{b:02X}" for b in data],
        "data_len": len(data),
        "rx_checksum": f"0x{rx_chk:02X}",
        "enhanced_expected": f"0x{exp_enh:02X}",
        "classic_expected": f"0x{exp_cls:02X}",
        "enhanced_match": rx_chk == exp_enh,
        "classic_match": rx_chk == exp_cls,
    }


# -- Commands ----------------------------------------------------------

def cmd_antinag(id_hex: str = "0x0C", cycles: int = 8):
    """Generate alternating UP/DOWN anti-nag frame table."""
    raw_id = int(id_hex, 16)
    pid = make_protected_id(raw_id)

    print(f"Anti-nag injection table - ID={id_hex} PID=0x{pid:02X}")
    print(f"LIN 2.1 enhanced checksum  |  Bench use ONLY")
    print(f"{'B0':>4} {'B1':>4} {'B2':>4} {'B3':>4} {'B4':>4} {'B5':>4} {'B6':>4} {'B7':>4} {'CHK':>4}  direction  ctr")
    print("-" * 60)

    for ctr in range(16):
        for direction, b0, b1 in [("UP", 0x11, 0x04), ("DOWN", 0x0F, 0x04)]:
            data = [b0, b1, 0x00, 0x00, 0x00, 0x00, 0xC0, ctr]
            chk = lin_checksum(pid, data, enhanced=True)
            print(f"  0x{b0:02X} 0x{b1:02X} 0x00 0x00 0x00 0x00 0xC0 0x{ctr:02X} 0x{chk:02X}  {direction:5s}  {ctr:2d}")

    print()
    print(f"Total: {16 * 2} unique frames")
    print("Safety: Bench validation required before any vehicle use.")


def cmd_idle(id_hex: str = "0x0C", counter: int = 0):
    """Generate a single idle frame with counter cycle."""
    raw_id = int(id_hex, 16)
    pid = make_protected_id(raw_id)
    data = [0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, counter]
    chk = lin_checksum(pid, data, enhanced=True)
    print(f"ID={id_hex} PID=0x{pid:02X} ctr={counter}")
    print(f"Frame:  0x{raw_id:02X} " + " ".join(f"0x{b:02X}" for b in data) + f" 0x{chk:02X}")
    print(f"Payload bytes: " + " ".join(f"{b:02X}" for b in data + [chk]))


def cmd_verify(frame_str: str):
    """Verify a full frame string against enhanced + classic checksums."""
    result = verify_frame(frame_str)
    print(f"Frame:  {result['id_hex']} {' '.join(result['data'])} chk={result['rx_checksum']}")
    print(f"PID:    {result['pid_hex']}  (ID {result['id_hex']})")
    print(f"Data:   {result['data_len']} bytes")
    print(f"Enhanced: expected {result['enhanced_expected']} - {'MATCH' if result['enhanced_match'] else 'MISMATCH'}")
    print(f"Classic:  expected {result['classic_expected']} - {'MATCH' if result['classic_match'] else 'MISMATCH'}")
    if result['enhanced_match']:
        print("\nResult: PASS (enhanced checksum matches)")
    elif result['classic_match']:
        print("\nResult: PASS (classic checksum matches)")
    else:
        print("\nResult: FAIL - no checksum variant matches")


def cmd_checksum(id_hex: str, *data_bytes: str):
    """Compute expected checksum for a frame (data only, no rx checksum)."""
    raw_id = int(id_hex, 16)
    pid = make_protected_id(raw_id)
    data = [int(b, 16) for b in data_bytes]
    enh = lin_checksum(pid, data, enhanced=True)
    cls = lin_checksum(pid, data, enhanced=False)
    print(f"ID={id_hex}  PID=0x{pid:02X}  data={len(data)} bytes")
    print(f"Data:  {' '.join(f'{b:02X}' for b in data)}")
    print(f"Enhanced checksum: 0x{enh:02X}")
    print(f"Classic checksum:  0x{cls:02X}")
    print(f"Full frame to send:  {id_hex} {' '.join(f'{b:02X}' for b in data)} {enh:02X}")


def cmd_scan(*id_hexes: str):
    """Compute PID + checksum for multiple IDs (Model 3/Y candidate discovery)."""
    print(f"{'ID':>6} {'PID':>6}  data  enhanced classic")
    print("-" * 45)
    for id_str in id_hexes:
        raw_id = int(id_str, 16)
        pid = make_protected_id(raw_id)
        # Standard idle payload: B0=neutral, rest zero
        data = [0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, 0x00]
        enh = lin_checksum(pid, data, enhanced=True)
        cls = lin_checksum(pid, data, enhanced=False)
        print(f"{id_str:>6} 0x{pid:02X}   8B  0x{enh:02X}   0x{cls:02X}")


# -- Main --------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "antinag":
        id_hex = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else "0x0C"
        cycles = 8
        if "--cycles" in sys.argv:
            ci = sys.argv.index("--cycles")
            cycles = int(sys.argv[ci + 1])
        if "--id" in sys.argv:
            ci = sys.argv.index("--id")
            id_hex = sys.argv[ci + 1]
        cmd_antinag(id_hex, cycles)

    elif cmd == "idle":
        id_hex = "0x0C"
        counter = 0
        if "--id" in sys.argv:
            ci = sys.argv.index("--id")
            id_hex = sys.argv[ci + 1]
        if "--counter" in sys.argv:
            ci = sys.argv.index("--counter")
            counter = int(sys.argv[ci + 1])
        cmd_idle(id_hex, counter)

    elif cmd == "verify":
        # Collect everything after 'verify' as the frame string
        frame = " ".join(sys.argv[2:])
        cmd_verify(frame)

    elif cmd == "checksum":
        if len(sys.argv) < 4:
            print("Usage: lin-payload-calc.py checksum <id_hex> <data_bytes...>")
            sys.exit(1)
        cmd_checksum(sys.argv[2], *sys.argv[3:])

    elif cmd == "scan":
        ids = sys.argv[2:] if len(sys.argv) > 2 else ["0x0C", "0x2A", "0x2B", "0x3C"]
        cmd_scan(*ids)

    else:
        print(f"Unknown command: {cmd}")
        print(__doc__)