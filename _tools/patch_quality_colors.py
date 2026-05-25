# -*- coding: utf-8 -*-
"""按 GameConstants 规范更新 items_master.csv 的 quality_color 列。"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "config" / "items_master.csv"

COLORS = {
    "white": "#B2B2B2",
    "green": "#44612b",
    "blue": "#29487d",
    "purple": "#4e297d",
    "gold": "#b1a221",
    "red": "#a4492a",
}


def main() -> None:
    with CSV_PATH.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    fieldnames = list(rows[0].keys())
    for row in rows:
        q = row["quality"].strip().lower()
        row["quality_color"] = COLORS.get(q, COLORS["white"])
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print("OK", len(rows), "->", CSV_PATH)


if __name__ == "__main__":
    main()
