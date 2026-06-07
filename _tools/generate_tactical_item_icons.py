#!/usr/bin/env python3
"""Generate 128x128 text-first tactical item icons and a contact sheet."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from generate_tactical_items_config import CATEGORIES, ROOT, build_items, sync_items_master, write_tactical_config

SIZE = 128
OUT_DIR = ROOT / "assets" / "icons" / "tactical"
PREVIEW_PATH = ROOT / "_tmp" / "tactical_item_icons_preview.png"
FONT_PATH = Path(r"C:\Windows\Fonts\SourceHanSansCNBold.ttf")
QUALITY_COLORS = {
    "white": "#B2B2B2",
    "green": "#44612b",
    "blue": "#29487d",
    "purple": "#4e297d",
    "gold": "#b1a221",
    "red": "#a4492a",
}
QUALITY_TEXT_COLORS = {
    "white": "#E0E0E0",
    "green": "#7CCD5F",
    "blue": "#5EB3FF",
    "purple": "#C882FF",
    "gold": "#FFD645",
    "red": "#FF6B5E",
}
ICON_LABELS = {category: icon_label for category, _name, icon_label, _desc, _effect in CATEGORIES}
ICON_LABELS["omniscient"] = "全知"


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def draw_centered(draw: ImageDraw.ImageDraw, text: str, y: int, text_font: ImageFont.FreeTypeFont, fill: str) -> None:
    box = draw.textbbox((0, 0), text, font=text_font, stroke_width=1)
    width = box[2] - box[0]
    draw.text(
        ((SIZE - width) // 2, y),
        text,
        font=text_font,
        fill=fill,
        stroke_width=1,
        stroke_fill="#111621",
    )


def draw_icon(item: dict) -> Image.Image:
    quality = item["quality"]
    border = QUALITY_COLORS[quality]
    text_color = QUALITY_TEXT_COLORS[quality]
    image = Image.new("RGBA", (SIZE, SIZE), "#101722")
    draw = ImageDraw.Draw(image)

    draw.rounded_rectangle((3, 3, 124, 124), radius=15, fill="#151F2D", outline=border, width=4)
    draw.rounded_rectangle((10, 10, 117, 117), radius=11, outline="#2A3545", width=2)
    draw.line((20, 32, 108, 32), fill=border, width=2)
    draw.line((20, 96, 108, 96), fill=border, width=2)
    draw.ellipse((16, 16, 24, 24), outline=border, width=2)
    draw.ellipse((104, 16, 112, 24), outline=border, width=2)
    draw.ellipse((16, 104, 24, 112), outline=border, width=2)
    draw.ellipse((104, 104, 112, 112), outline=border, width=2)

    label = ICON_LABELS[item["category"]]
    label_font = font(42 if len(label) == 2 else 31)
    draw_centered(draw, label, 40 if len(label) == 2 else 45, label_font, text_color)
    return image


def make_preview(items: list[dict], icons: list[Image.Image]) -> None:
    columns = 7
    rows = (len(items) + columns - 1) // columns
    cell_w, cell_h = 164, 168
    preview = Image.new("RGB", (columns * cell_w, rows * cell_h), "#0B1018")
    draw = ImageDraw.Draw(preview)
    label_font = font(16)
    quality_font = font(13)
    for index, (item, icon) in enumerate(zip(items, icons)):
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        preview.paste(icon.convert("RGB"), (x + 18, y + 8))
        label = ICON_LABELS[item["category"]]
        draw.text((x + 18, y + 139), f"{label} / {item['quality']}", font=label_font, fill=QUALITY_TEXT_COLORS[item["quality"]])
        draw.text((x + 18, y + 155), item["id"], font=quality_font, fill="#8D9BAD")
    PREVIEW_PATH.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW_PATH)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    items = build_items()
    icons = []
    for item in items:
        image = draw_icon(item)
        image.save(OUT_DIR / f"{item['id']}.png")
        icons.append(image)
    write_tactical_config(items)
    sync_items_master(items)
    make_preview(items, icons)
    print(f"Wrote {len(items)} icons to {OUT_DIR}")
    print(f"Wrote preview to {PREVIEW_PATH}")


if __name__ == "__main__":
    main()
