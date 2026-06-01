from __future__ import annotations

import csv
from decimal import Decimal
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def money(value: str) -> Decimal:
    return Decimal(value.strip())


def main() -> int:
    path = ROOT / "bom" / "rev_a_cost_model.csv"
    rows = list(csv.DictReader(path.open(newline="", encoding="utf-8")))
    if not rows:
        raise SystemExit("No cost model rows found")

    print("scenario,quantity,total_low_usd,total_high_usd,midpoint_usd")
    for row in rows:
        low = money(row["total_low_usd"])
        high = money(row["total_high_usd"])
        midpoint = (low + high) / Decimal("2")
        print(f"{row['scenario']},{row['quantity']},{low},{high},{midpoint}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())