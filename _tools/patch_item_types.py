# -*- coding: utf-8 -*-
"""将 items_master.csv 的 item_type 按 itm 序号区间写入。关闭 Godot 后运行。"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "config" / "items_master.csv"

RANGES = [
    (1, 57, "magic"),
    (58, 87, "biological"),
    (88, 133, "building"),
    (134, 176, "daily"),
    (177, 218, "art"),
    (219, 239, "document"),
    (240, 258, "raw_material"),
]


def type_for_num(n: int) -> str:
    for lo, hi, t in RANGES:
        if lo <= n <= hi:
            return t
    return "magic"


def main() -> None:
    with CSV_PATH.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    fieldnames = list(rows[0].keys())
    for row in rows:
        num = int(row["item_id"].strip().replace("itm_", ""))
        row["item_type"] = type_for_num(num)
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print("OK", len(rows), "->", CSV_PATH)


if __name__ == "__main__":
    main()
