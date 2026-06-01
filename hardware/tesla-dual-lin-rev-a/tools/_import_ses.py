"""Import a FreeRouting .ses session into the KiCad board and save it.

Usage:
    kicad-python _import_ses.py <board.kicad_pcb> <route.ses> [out.kicad_pcb]
"""
from pathlib import Path
import sys
import pcbnew


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: _import_ses.py <board.kicad_pcb> <route.ses> [out.kicad_pcb]")
        return 2
    board_path = Path(sys.argv[1]).resolve()
    ses_path = Path(sys.argv[2]).resolve()
    out_path = Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else board_path

    board = pcbnew.LoadBoard(str(board_path))
    tracks_before = len(list(board.GetTracks()))
    ok = pcbnew.ImportSpecctraSES(board, str(ses_path))
    tracks_after = len(list(board.GetTracks()))

    # Refill zones so pours connect to the freshly routed copper.
    try:
        filler = pcbnew.ZONE_FILLER(board)
        filler.Fill(board.Zones())
    except Exception as exc:  # pragma: no cover - environment dependent
        print(f"zone_fill_warning={exc!r}")

    pcbnew.SaveBoard(str(out_path), board)
    print(f"IMPORT_SES ok={bool(ok)} tracks_before={tracks_before} tracks_after={tracks_after}")
    print(f"SAVED {out_path}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
