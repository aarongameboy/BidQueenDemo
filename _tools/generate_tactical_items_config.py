#!/usr/bin/env python3
"""Generate config/tactical_items.json with stable tactical icon paths."""
import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUALITIES = ["white", "green", "blue", "purple", "gold", "red"]
Q_LABELS = {
    "white": "白品",
    "green": "良品",
    "blue": "蓝品",
    "purple": "优品",
    "gold": "珍品",
    "red": "极品",
}
Q_NAMES = {
    "white": "白色",
    "green": "绿色",
    "blue": "蓝色",
    "purple": "紫色",
    "gold": "金色",
    "red": "红色",
}
PRICES = {
    "white": 5000,
    "green": 12000,
    "blue": 30000,
    "purple": 75000,
    "gold": 180000,
    "red": 450000,
}
QUALITY_COLORS = {
    "white": "#B2B2B2",
    "green": "#44612b",
    "blue": "#29487d",
    "purple": "#4e297d",
    "gold": "#b1a221",
    "red": "#a4492a",
}
REVEAL_COUNTS = {"white": 1, "green": 2, "blue": 3, "purple": 4, "gold": 5, "red": 6}
IDENT_COUNTS = {"white": 2, "green": 4, "blue": 6, "purple": 8, "gold": 10, "red": 12}

CATEGORIES = [
    (
        "random_reveal",
        "随机显示",
        "显示",
        lambda q: f"随机显示 {REVEAL_COUNTS[q]} 件藏品全部信息。",
        lambda q: {"type": "random_reveal", "count": REVEAL_COUNTS[q]},
    ),
    (
        "scan",
        "扫描",
        "扫描",
        lambda q: f"显示所有{Q_NAMES[q]}品质藏品的总格数。",
        lambda q: {"type": "scan", "quality": q},
    ),
    (
        "stock",
        "存量",
        "存量",
        lambda q: f"显示所有{Q_NAMES[q]}品质藏品的总数量。",
        lambda q: {"type": "stock", "quality": q},
    ),
    (
        "valuation",
        "估价",
        "估价",
        lambda q: f"显示所有{Q_NAMES[q]}品质藏品的总价值。",
        lambda q: {"type": "valuation", "quality": q},
    ),
    (
        "random_quality_id",
        "随机品质鉴定",
        "鉴定",
        lambda q: f"随机鉴定 {IDENT_COUNTS[q]} 件未知藏品的品质与占格。",
        lambda q: {"type": "random_quality_id", "count": IDENT_COUNTS[q]},
    ),
    (
        "avg_cells",
        "均格",
        "均格",
        lambda q: f"显示所有{Q_NAMES[q]}品质藏品的平均格数。",
        lambda q: {"type": "avg_cells", "quality": q},
    ),
]


def icon_path(item_id: str) -> str:
    return f"res://assets/icons/tactical/{item_id}.png"


def build_items() -> list[dict]:
    items: list[dict] = []
    for cat_id, cat_label, _icon_label, desc_fn, effect_fn in CATEGORIES:
        for quality in QUALITIES:
            item_id = f"tact_{cat_id}_{quality}"
            items.append(
                {
                    "id": item_id,
                    "name": f"{Q_LABELS[quality]}{cat_label}",
                    "category": cat_id,
                    "quality": quality,
                    "icon_path": icon_path(item_id),
                    "description": desc_fn(quality),
                    "effect": effect_fn(quality),
                    "shop_price": PRICES[quality],
                }
            )
    items.append(
        {
            "id": "tact_omniscient",
            "name": "全知全能",
            "category": "omniscient",
            "quality": "red",
            "icon_path": icon_path("tact_omniscient"),
            "description": "显示所有藏品的全部信息。",
            "effect": {"type": "omniscient"},
            "shop_price": 2000000,
        }
    )
    return items


def write_tactical_config(items: list[dict]) -> None:
    tactical_path = ROOT / "config" / "tactical_items.json"
    tactical_path.write_text(
        json.dumps({"max_loadout_slots": 5, "items": items}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def sync_items_master(items: list[dict]) -> None:
    items_path = ROOT / "config" / "items_master.csv"
    with items_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file)
        fieldnames = list(reader.fieldnames or [])
        rows = [row for row in reader if not str(row.get("item_id", "")).startswith("tact_")]
    for item in items:
        row = {field: "" for field in fieldnames}
        row.update(
            {
                "item_id": item["id"],
                "item_name": item["name"],
                "size_w": "1",
                "size_h": "1",
                "base_price": str(item["shop_price"]),
                "icon_path": item["icon_path"],
                "quality": item["quality"],
                "quality_color": QUALITY_COLORS[item["quality"]],
                "item_type": "tactical",
                "flavor_text": item["description"],
                "pool_tag": "",
                "weight": "0",
                "enabled": "1",
            }
        )
        rows.append(row)
    with items_path.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def sync_shop(items: list[dict]) -> None:
    shop_path = ROOT / "config" / "shop_config.json"
    shop = json.loads(shop_path.read_text(encoding="utf-8"))
    categories = shop.get("categories", [])
    if not any(category.get("id") == "tactical" for category in categories):
        categories.append({"id": "tactical", "name": "战术道具", "enabled": True})
    shop["categories"] = categories
    products = [product for product in shop.get("products", []) if product.get("category") != "tactical"]
    for item in items:
        products.append(
            {
                "product_id": f"shop_{item['id']}",
                "category": "tactical",
                "name": item["name"],
                "description": item["description"],
                "price_silver": item["shop_price"],
                "purchase_limit": 0,
                "effect": {
                    "type": "tactical_item",
                    "tactical_id": item["id"],
                    "grant_count": 1,
                },
            }
        )
    shop["products"] = products
    shop_path.write_text(json.dumps(shop, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sync-shop", action="store_true", help="Also refresh tactical entries in shop_config.json")
    args = parser.parse_args()
    items = build_items()
    write_tactical_config(items)
    sync_items_master(items)
    if args.sync_shop:
        sync_shop(items)
    print(f"Wrote {len(items)} tactical items")


if __name__ == "__main__":
    main()
