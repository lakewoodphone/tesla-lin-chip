"""Export a KiCad PCB to a Specctra DSN for FreeRouting.

Run with the KiCad-bundled Python:
    kicad-python _export_dsn.py <board.kicad_pcb> <out.dsn>
"""
from __future__ import annotations

import sys
from pathlib import Path

import pcbnew


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: _export_dsn.py <board.kicad_pcb> <out.dsn>")
        return 2
    board_path = Path(sys.argv[1]).resolve()
    dsn_path = Path(sys.argv[2]).resolve()
    dsn_path.parent.mkdir(parents=True, exist_ok=True)
    board = pcbnew.LoadBoard(str(board_path))
    ok = pcbnew.ExportSpecctraDSN(board, str(dsn_path))
    size = dsn_path.stat().st_size if dsn_path.exists() else 0
    print(f"EXPORT_DSN ok={ok} exists={dsn_path.exists()} bytes={size}")
    return 0 if ok and size > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
