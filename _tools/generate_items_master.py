# -*- coding: utf-8 -*-
"""Generate config/items_master.csv with 500 items (UTF-8 BOM for Excel)."""
import csv
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "config" / "items_master.csv"
COUNT = 500

QUALITIES = [
    ("white", "#B2B2B2", "common", 35, (400, 2500)),
    ("green", "#44612b", "common", 25, (1500, 8000)),
    ("blue", "#29487d", "uncommon", 18, (6000, 25000)),
    ("purple", "#4e297d", "rare", 12, (18000, 80000)),
    ("gold", "#b1a221", "epic", 7, (60000, 250000)),
    ("red", "#a4492a", "mythic", 3, (200000, 1200000)),
]

SIZE_WEIGHTS = [
    (1, 1, 150),
    (1, 2, 65),
    (2, 1, 60),
    (2, 2, 125),
    (2, 3, 35),
    (3, 2, 35),
    (3, 3, 40),
]

def item_type_for_index(i: int) -> str:
    if i <= 57:
        return "magic"
    if i <= 87:
        return "biological"
    if i <= 133:
        return "building"
    if i <= 176:
        return "daily"
    if i <= 218:
        return "art"
    if i <= 239:
        return "document"
    if i <= 258:
        return "raw_material"
    return "magic"

NAMES = [
    "旧手表", "铜香炉", "瓷碗", "木雕", "邮票册", "银币", "罗盘", "砚台",
    "玉佩", "青铜镜", "油画", "雕塑", "古籍", "钻石", "金条", "石狮子",
    "红宝石", "跑车钥匙", "大红袍", "火焰欧泊", "非洲之心", "会员卡",
]


def pick_quality(rng: random.Random) -> tuple:
    roll = rng.randint(1, 100)
    acc = 0
    for q in QUALITIES:
        acc += q[3]
        if roll <= acc:
            return q
    return QUALITIES[0]


def pick_size(rng: random.Random) -> tuple:
    total = sum(w for _, _, w in SIZE_WEIGHTS)
    roll = rng.randint(1, total)
    acc = 0
    for sw, sh, w in SIZE_WEIGHTS:
        acc += w
        if roll <= acc:
            return sw, sh
    return 1, 1


def main() -> None:
    rng = random.Random(42)
    rows = []
    for i in range(1, COUNT + 1):
        item_id = f"itm_{i:05d}"
        qname, color, pool, _, pr = pick_quality(rng)
        sw, sh = pick_size(rng)
        area = sw * sh
        lo, hi = pr
        base = int(rng.randint(lo, hi) * (0.85 + 0.15 * area / 9.0))
        name = f"{rng.choice(NAMES)}{i:03d}"
        icon = f"res://assets/icons/items/{item_id}.png"
        weight = max(1, int(100 / (area + 1) * (0.3 if qname == "red" else 1.0)))
        rows.append({
            "item_id": item_id,
            "item_name": name,
            "size_w": sw,
            "size_h": sh,
            "base_price": base,
            "icon_path": icon,
            "quality": qname,
            "quality_color": color,
            "item_type": item_type_for_index(i),
            "pool_tag": pool if qname not in ("gold", "red") else (
                "legendary" if qname == "gold" else "mythic"
            ),
            "weight": weight,
            "enabled": 1,
        })
    OUT.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "item_id", "item_name", "size_w", "size_h", "base_price",
        "icon_path", "quality", "quality_color", "item_type", "pool_tag", "weight", "enabled",
    ]
    with OUT.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print("OK", len(rows), "->", OUT)


if __name__ == "__main__":
    main()
