"""Deterministic GND stitch finisher (geometric island stitching).

FreeRouting ties GND together with its own (stochastic) vias, so after a SES
import the F.Cu/B.Cu GND pours can still fragment into filled islands that are
not tied to the In2 plane -- DRC reports these as zone<->zone unconnected items
and the count varies run to run.

This pass makes GND connectivity deterministic. After the SES import it:
  1. refills zones,
  2. enumerates every filled polygon of the F.Cu and B.Cu GND pours,
  3. for any island that has no GND via inside it, drops a GND via at an
     interior point (clear of other-net pads) tying that island to the In2
     plane,
  4. refills again and saves.

Run with the KiCad-bundled Python:
    kicad-python _stitch_gnd.py <routed.kicad_pcb> [out.kicad_pcb]
"""
from __future__ import annotations

import sys
from pathlib import Path

import pcbnew

VIA_SIZE_NM = pcbnew.FromMM(0.6)
VIA_DRILL_NM = pcbnew.FromMM(0.3)
MIN_OTHER_NET_MM = 0.6      # via center clearance to a non-GND pad
EDGE_MARGIN_MM = 1.2        # via center min distance from board edge
MIN_ISLAND_MM2 = 0.4        # ignore slivers smaller than this (mode-0 drops them)


def _poly_pts(outline) -> list[tuple[int, int]]:
    return [(outline.CPoint(i).x, outline.CPoint(i).y) for i in range(outline.PointCount())]


def _point_in_poly(x: int, y: int, pts: list[tuple[int, int]]) -> bool:
    inside = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (
            x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi
        ):
            inside = not inside
        j = i
    return inside


def _bbox(pts: list[tuple[int, int]]):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: _stitch_gnd.py <routed.kicad_pcb> [out.kicad_pcb]")
        return 2
    src = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else src

    board = pcbnew.LoadBoard(str(src))
    gnd = board.GetNetcodeFromNetname("GND")
    if gnd <= 0:
        print("STITCH_GND no GND net")
        return 1

    pcbnew.ZONE_FILLER(board).Fill(board.Zones())

    bw = pcbnew.FromMM(100.0)
    bh = pcbnew.FromMM(60.0)
    edge = pcbnew.FromMM(EDGE_MARGIN_MM)
    other_pads: list[tuple[int, int, int]] = []   # x, y, radius
    other_segs: list[tuple[int, int, int, int, int]] = []  # x1,y1,x2,y2,halfwidth
    gnd_vias: list[tuple[int, int]] = []
    for fp in board.GetFootprints():
        for pad in fp.Pads():
            p = pad.GetPosition()
            if pad.GetNetCode() != gnd:
                # bounding radius of the pad
                sz = pad.GetSize()
                r = max(sz.x, sz.y) // 2
                other_pads.append((p.x, p.y, r))
    for t in board.Tracks():
        if t.Type() == pcbnew.PCB_VIA_T:
            p = t.GetPosition()
            if t.GetNetCode() == gnd:
                gnd_vias.append((p.x, p.y))
            else:
                # via radius (avoid GetWidth(): needs a layer arg in KiCad 10)
                other_pads.append((p.x, p.y, t.GetDrill() // 2 + pcbnew.FromMM(0.15)))
        else:  # PCB_TRACK / PCB_ARC
            if t.GetNetCode() != gnd:
                s = t.GetStart()
                e = t.GetEnd()
                other_segs.append((s.x, s.y, e.x, e.y, t.GetWidth() // 2))

    placed: list[tuple[int, int]] = []
    via_r = pcbnew.FromMM(0.3)
    clearance = pcbnew.FromMM(0.25)
    dedup_r2 = pcbnew.FromMM(0.6) ** 2

    def _seg_dist2(px: int, py: int, x1: int, y1: int, x2: int, y2: int) -> float:
        dx, dy = x2 - x1, y2 - y1
        if dx == 0 and dy == 0:
            return (px - x1) ** 2 + (py - y1) ** 2
        t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
        t = max(0.0, min(1.0, t))
        cx, cy = x1 + t * dx, y1 + t * dy
        return (px - cx) ** 2 + (py - cy) ** 2

    def usable(x: int, y: int) -> bool:
        if x < edge or x > bw - edge or y < edge or y > bh - edge:
            return False
        for px, py, pr in other_pads:
            need = pr + via_r + clearance
            if (x - px) ** 2 + (y - py) ** 2 < need * need:
                return False
        for x1, y1, x2, y2, hw in other_segs:
            need = hw + via_r + clearance
            if _seg_dist2(x, y, x1, y1, x2, y2) < need * need:
                return False
        if any((x - px) ** 2 + (y - py) ** 2 < dedup_r2 for px, py in placed):
            return False
        return True

    def add_via(x: int, y: int) -> None:
        via = pcbnew.PCB_VIA(board)
        via.SetPosition(pcbnew.VECTOR2I(int(x), int(y)))
        via.SetWidth(VIA_SIZE_NM)
        via.SetDrill(VIA_DRILL_NM)
        via.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu)
        via.SetNetCode(gnd)
        board.Add(via)
        placed.append((int(x), int(y)))
        gnd_vias.append((int(x), int(y)))

    added = 0
    skipped = 0
    for z in board.Zones():
        layer = z.GetLayerSet().Seq()[0]
        lname = board.GetLayerName(layer)
        if lname not in ("F.Cu", "B.Cu"):
            continue  # In2 plane is the backbone; only stitch outer pours
        poly = z.GetFilledPolysList(layer)
        for i in range(poly.OutlineCount()):
            pts = _poly_pts(poly.Outline(i))
            if len(pts) < 3:
                continue
            area = abs(poly.Outline(i).Area()) / 1e12
            if area < MIN_ISLAND_MM2:
                continue
            # Already has a GND via inside?
            if any(_point_in_poly(vx, vy, pts) for vx, vy in gnd_vias):
                continue
            # Find an interior point clear of other-net pads.
            x0, y0, x1, y1 = _bbox(pts)
            step = pcbnew.FromMM(0.5)
            spot = None
            yy = y0 + step
            while yy < y1 and spot is None:
                xx = x0 + step
                while xx < x1:
                    if _point_in_poly(xx, yy, pts) and usable(xx, yy):
                        spot = (xx, yy)
                        break
                    xx += step
                yy += step
            if spot is None:
                skipped += 1
                cx = sum(p[0] for p in pts) // len(pts)
                cy = sum(p[1] for p in pts) // len(pts)
                print(f"  SKIP {lname} island area={area:.1f}mm2 near "
                      f"({cx/1e6:.1f},{cy/1e6:.1f}) - no clear interior point")
                continue
            add_via(*spot)
            added += 1

    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    board.BuildConnectivity()
    pcbnew.SaveBoard(str(out), board)
    print(f"STITCH_GND islands_stitched={added} skipped={skipped} -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
