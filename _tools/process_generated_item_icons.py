from __future__ import annotations

import argparse
import csv
import shutil
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GENERATED_DIR = Path(
    r"C:\Users\chenj\.codex\generated_images\019e783b-d9e9-7981-8216-df497b512379"
)
SHEETS_DIR = ROOT / "_tmp" / "item_icon_sheets_quality"
ICONS_DIR = ROOT / "assets" / "icons" / "items"
CSV_PATH = ROOT / "config" / "items_master.csv"
PENDING_CSV_PATH = ROOT / "config" / "items_master.csv.pending"
CONTACT_SHEET = ROOT / "_tmp" / "item_icons_quality_contact_sheet.png"
ALPHA_COMPONENT_THRESHOLD = 24
EDGE_MARGIN = 2
BLEED_HALO_RADIUS = 3
NEAR_EDGE_MARGIN = 12
TINY_EDGE_COMPONENT_AREA = 4
GREEN_SPILL_RADIUS = 3
TOP_RECOVERY_EXCLUSIONS = {"itm_00134"}
LEFT_RECOVERY_IDS = {"itm_00176"}


def remove_green_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    if hasattr(rgba, "get_flattened_data"):
        pixels = list(rgba.get_flattened_data())
    else:
        pixels = list(rgba.getdata())
    result = []
    for red, green, blue, _ in pixels:
        # Generated sheets use a saturated green chroma key. The two thresholds
        # preserve antialiased edges while removing minor background variation.
        dominance = green - max(red, blue)
        if green >= 135 and dominance >= 42:
            alpha = max(0, min(255, int((135 - dominance) * 3.2)))
            if alpha < 255:
                green = min(green, max(red, blue))
        else:
            alpha = 255
        result.append((red, green, blue, alpha))
    rgba.putdata(result)
    return rgba


def _touches_edge(bbox: tuple[int, int, int, int], width: int, height: int) -> bool:
    left, top, right, bottom = bbox
    return (
        left <= EDGE_MARGIN
        or top <= EDGE_MARGIN
        or right >= width - EDGE_MARGIN
        or bottom >= height - EDGE_MARGIN
    )


def _is_near_edge(bbox: tuple[int, int, int, int], width: int, height: int) -> bool:
    left, top, right, bottom = bbox
    return (
        left <= NEAR_EDGE_MARGIN
        or top <= NEAR_EDGE_MARGIN
        or right >= width - NEAR_EDGE_MARGIN
        or bottom >= height - NEAR_EDGE_MARGIN
    )


def remove_green_edge_spill(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    near_transparency = alpha.point(
        lambda value: 255 if value == 0 else 0
    ).filter(ImageFilter.MaxFilter(GREEN_SPILL_RADIUS * 2 + 1))
    source_pixels = image.load()
    near_pixels = near_transparency.load()
    cleaned = image.copy()
    cleaned_pixels = cleaned.load()

    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha_value = source_pixels[x, y]
            if (
                alpha_value
                and near_pixels[x, y]
                and green - max(red, blue) >= 16
            ):
                cleaned_pixels[x, y] = (red, max(red, blue), blue, alpha_value)
    return cleaned


def recover_top_overflow(
    sheet: Image.Image,
    box: tuple[int, int, int, int],
    item_id: str,
) -> tuple[Image.Image, int]:
    """Restore target pixels that crossed into the cell above."""
    left, top, right, bottom = box
    cell = sheet.crop(box)
    if top <= 0 or item_id in TOP_RECOVERY_EXCLUSIONS:
        return remove_green_background(cell), 0

    width = right - left
    height = bottom - top
    padding = min(height, top)
    expanded = remove_green_background(
        sheet.crop((left, top - padding, right, bottom))
    )
    alpha = expanded.getchannel("A")
    pixels = alpha.load()
    expanded_height = expanded.height
    visited = bytearray(width * expanded_height)
    connected_offsets = set()

    for y in range(expanded_height):
        for x in range(width):
            offset = y * width + x
            if visited[offset] or pixels[x, y] < ALPHA_COMPONENT_THRESHOLD:
                continue
            visited[offset] = 1
            queue = deque([(x, y)])
            component_offsets = []
            crosses_cell_top = False
            while queue:
                px, py = queue.popleft()
                component_offsets.append(py * width + px)
                if padding <= py <= padding + EDGE_MARGIN:
                    crosses_cell_top = True
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= expanded_height:
                        continue
                    neighbor_offset = ny * width + nx
                    if (
                        visited[neighbor_offset]
                        or pixels[nx, ny] < ALPHA_COMPONENT_THRESHOLD
                    ):
                        continue
                    visited[neighbor_offset] = 1
                    queue.append((nx, ny))
            if crosses_cell_top:
                connected_offsets.update(component_offsets)

    if not any(offset // width < padding for offset in connected_offsets):
        return remove_green_background(cell), 0

    # Preserve antialiased edge pixels around the connected high-alpha region.
    kept_offsets = connected_offsets.copy()
    frontier = connected_offsets.copy()
    for _ in range(BLEED_HALO_RADIUS):
        expanded_offsets = set()
        for offset in frontier:
            x = offset % width
            y = offset // width
            for nx in range(max(0, x - 1), min(width, x + 2)):
                for ny in range(max(0, y - 1), min(expanded_height, y + 2)):
                    neighbor_offset = ny * width + nx
                    if neighbor_offset not in kept_offsets:
                        expanded_offsets.add(neighbor_offset)
        kept_offsets.update(expanded_offsets)
        frontier = expanded_offsets

    cleaned = expanded.copy()
    cleaned_pixels = cleaned.load()
    recovered_pixels = 0
    for y in range(padding):
        for x in range(width):
            offset = y * width + x
            red, green, blue, alpha_value = cleaned_pixels[x, y]
            if offset not in kept_offsets:
                cleaned_pixels[x, y] = (red, green, blue, 0)
            elif alpha_value:
                recovered_pixels += 1
    return cleaned, recovered_pixels


def recover_left_overflow(
    sheet: Image.Image,
    box: tuple[int, int, int, int],
    image: Image.Image,
    item_id: str,
) -> tuple[Image.Image, int]:
    """Restore selected target pixels that crossed into the cell to the left."""
    left, top, right, bottom = box
    if left <= 0 or item_id not in LEFT_RECOVERY_IDS:
        return image, 0

    width = right - left
    height = bottom - top
    padding = min(width, left)
    expanded = remove_green_background(
        sheet.crop((left - padding, top, right, bottom))
    )
    alpha = expanded.getchannel("A")
    pixels = alpha.load()
    expanded_width = expanded.width
    visited = bytearray(expanded_width * height)
    connected_offsets = set()

    for y in range(height):
        for x in range(expanded_width):
            offset = y * expanded_width + x
            if visited[offset] or pixels[x, y] < ALPHA_COMPONENT_THRESHOLD:
                continue
            visited[offset] = 1
            queue = deque([(x, y)])
            component_offsets = []
            crosses_cell_left = False
            while queue:
                px, py = queue.popleft()
                component_offsets.append(py * expanded_width + px)
                if padding <= px <= padding + EDGE_MARGIN:
                    crosses_cell_left = True
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or ny < 0 or nx >= expanded_width or ny >= height:
                        continue
                    neighbor_offset = ny * expanded_width + nx
                    if (
                        visited[neighbor_offset]
                        or pixels[nx, ny] < ALPHA_COMPONENT_THRESHOLD
                    ):
                        continue
                    visited[neighbor_offset] = 1
                    queue.append((nx, ny))
            if crosses_cell_left:
                connected_offsets.update(component_offsets)

    if not any(offset % expanded_width < padding for offset in connected_offsets):
        return image, 0

    # Preserve antialiased edge pixels around the connected high-alpha region.
    kept_offsets = connected_offsets.copy()
    frontier = connected_offsets.copy()
    for _ in range(BLEED_HALO_RADIUS):
        expanded_offsets = set()
        for offset in frontier:
            x = offset % expanded_width
            y = offset // expanded_width
            for nx in range(max(0, x - 1), min(expanded_width, x + 2)):
                for ny in range(max(0, y - 1), min(height, y + 2)):
                    neighbor_offset = ny * expanded_width + nx
                    if neighbor_offset not in kept_offsets:
                        expanded_offsets.add(neighbor_offset)
        kept_offsets.update(expanded_offsets)
        frontier = expanded_offsets

    cleaned = Image.new("RGBA", (image.width + padding, image.height), (0, 0, 0, 0))
    cleaned.alpha_composite(image, (padding, 0))
    cleaned_pixels = cleaned.load()
    expanded_pixels = expanded.load()
    y_offset = image.height - height
    recovered_pixels = 0
    for y in range(height):
        for x in range(padding):
            offset = y * expanded_width + x
            if offset in kept_offsets and expanded_pixels[x, y][3]:
                cleaned_pixels[x, y + y_offset] = expanded_pixels[x, y]
                recovered_pixels += 1
    return cleaned, recovered_pixels


def remove_detached_edge_bleed(image: Image.Image) -> tuple[Image.Image, int]:
    """Remove neighbor fragments that crossed a generated sheet cell boundary."""
    alpha = image.getchannel("A")
    width, height = image.size
    pixels = alpha.load()
    visited = bytearray(width * height)
    components: list[dict] = []

    for y in range(height):
        for x in range(width):
            offset = y * width + x
            if visited[offset] or pixels[x, y] < ALPHA_COMPONENT_THRESHOLD:
                continue
            visited[offset] = 1
            queue = deque([(x, y)])
            points = []
            left = right = x
            top = bottom = y
            while queue:
                px, py = queue.popleft()
                points.append((px, py))
                left = min(left, px)
                top = min(top, py)
                right = max(right, px)
                bottom = max(bottom, py)
                for nx, ny in ((px - 1, py), (px + 1, py), (px, py - 1), (px, py + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    neighbor_offset = ny * width + nx
                    if visited[neighbor_offset] or pixels[nx, ny] < ALPHA_COMPONENT_THRESHOLD:
                        continue
                    visited[neighbor_offset] = 1
                    queue.append((nx, ny))
            bbox = (left, top, right + 1, bottom + 1)
            components.append(
                {
                    "points": points,
                    "area": len(points),
                    "bbox": bbox,
                    "touches_edge": _touches_edge(bbox, width, height),
                }
            )

    if not components:
        return image, 0

    # The generated object itself may touch the cell edge. The largest connected
    # region is still the safest anchor; only detached edge regions are bleed.
    seed = max(components, key=lambda component: component["area"])
    to_remove = [
        component
        for component in components
        if component is not seed
        and (
            component["touches_edge"]
            or (
                component["area"] <= TINY_EDGE_COMPONENT_AREA
                and _is_near_edge(component["bbox"], width, height)
            )
        )
    ]
    if not to_remove:
        return image, 0

    cleaned = image.copy()
    cleaned_pixels = cleaned.load()
    removal_offsets = set()
    for component in to_remove:
        for x, y in component["points"]:
            removal_offsets.add(y * width + x)

    # Clear a small halo as well. The high-alpha component identifies bleed
    # reliably, but chroma-key antialiasing leaves faint green fringe pixels.
    frontier = removal_offsets.copy()
    for _ in range(BLEED_HALO_RADIUS):
        expanded = set()
        for offset in frontier:
            x = offset % width
            y = offset // width
            for nx in range(max(0, x - 1), min(width, x + 2)):
                for ny in range(max(0, y - 1), min(height, y + 2)):
                    neighbor_offset = ny * width + nx
                    if neighbor_offset not in removal_offsets:
                        expanded.add(neighbor_offset)
        removal_offsets.update(expanded)
        frontier = expanded

    removed_pixels = 0
    for offset in removal_offsets:
        x = offset % width
        y = offset // width
        red, green, blue, alpha = cleaned_pixels[x, y]
        if alpha:
            cleaned_pixels[x, y] = (red, green, blue, 0)
            removed_pixels += 1
    return cleaned, removed_pixels


def fit_icon(image: Image.Image, width: int, height: int) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Icon cell became fully transparent after chroma removal")
    cropped = image.crop(bbox)
    padding = max(6, int(min(width, height) * 0.08))
    usable_w = max(1, width - padding * 2)
    usable_h = max(1, height - padding * 2)
    scale = min(usable_w / cropped.width, usable_h / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(
        resized, ((width - resized.width) // 2, (height - resized.height) // 2)
    )
    return remove_green_edge_spill(canvas)


def cut_grid(sheet: Image.Image, columns: int, rows: int) -> list[Image.Image]:
    cells = []
    for row in range(rows):
        y0 = round(sheet.height * row / rows)
        y1 = round(sheet.height * (row + 1) / rows)
        for column in range(columns):
            x0 = round(sheet.width * column / columns)
            x1 = round(sheet.width * (column + 1) / columns)
            cells.append(sheet.crop((x0, y0, x1, y1)))
    return cells


def load_rows() -> list[dict[str, str]]:
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_rows(rows: list[dict[str, str]]) -> None:
    try:
        handle = CSV_PATH.open("w", encoding="utf-8-sig", newline="")
    except PermissionError:
        handle = PENDING_CSV_PATH.open("w", encoding="utf-8-sig", newline="")
    with handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def build_contact_sheet(rows: list[dict[str, str]]) -> None:
    thumb = 96
    columns = 16
    targets = [row for row in rows if 16 <= int(row["item_id"][4:]) <= 258]
    rows_count = (len(targets) + columns - 1) // columns
    canvas = Image.new("RGB", (columns * thumb, rows_count * thumb), (28, 28, 32))
    draw = ImageDraw.Draw(canvas)
    for index, row in enumerate(targets):
        item_id = row["item_id"]
        icon = Image.open(ICONS_DIR / f"{item_id}.png").convert("RGBA")
        icon.thumbnail((thumb - 6, thumb - 18), Image.Resampling.LANCZOS)
        x = index % columns * thumb + (thumb - icon.width) // 2
        y = index // columns * thumb + 14 + (thumb - 18 - icon.height) // 2
        canvas.paste(icon, (x, y), icon)
        draw.text((index % columns * thumb + 3, index // columns * thumb + 2), item_id[4:], fill="white")
    canvas.save(CONTACT_SHEET)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cut generated item sheets into clean icons.")
    parser.add_argument("--generated-dir", type=Path, default=DEFAULT_GENERATED_DIR)
    parser.add_argument("--sheets-dir", type=Path, default=SHEETS_DIR)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    sheets_dir: Path = args.sheets_dir
    sheets_dir.mkdir(parents=True, exist_ok=True)
    ICONS_DIR.mkdir(parents=True, exist_ok=True)
    local_sheets = sorted(sheets_dir.glob("quality_sheet_*.png"))
    if len(local_sheets) != 16:
        generated = sorted(args.generated_dir.glob("*.png"), key=lambda path: path.stat().st_mtime)
        quality_sheets = generated[-16:]
        if len(quality_sheets) != 16:
            raise RuntimeError(f"Expected 16 quality sheets, found {len(quality_sheets)}")
        local_sheets = []
        for index, source in enumerate(quality_sheets, start=1):
            target = sheets_dir / f"quality_sheet_{index:02d}.png"
            shutil.copy2(source, target)
            local_sheets.append(target)

    rows = load_rows()
    by_id = {row["item_id"]: row for row in rows}
    item_cells: dict[str, Image.Image] = {}
    recovered_top_pixels = 0
    recovered_top_icons = 0
    recovered_left_pixels = 0
    recovered_left_icons = 0

    ordered_ids = [
        *range(16, 128),
        *range(128, 139),
        *range(140, 257),
    ]
    if len(ordered_ids) != 240:
        raise RuntimeError(f"Expected 240 main-sheet ids, found {len(ordered_ids)}")

    for batch_index, sheet_path in enumerate(local_sheets[:15]):
        sheet = Image.open(sheet_path).convert("RGB")
        for offset in range(16):
            item_number = ordered_ids[batch_index * 16 + offset]
            item_id = f"itm_{item_number:05d}"
            row, column = divmod(offset, 4)
            x0 = round(sheet.width * column / 4)
            x1 = round(sheet.width * (column + 1) / 4)
            y0 = round(sheet.height * row / 4)
            y1 = round(sheet.height * (row + 1) / 4)
            item_cells[item_id], recovered_pixels = recover_top_overflow(
                sheet, (x0, y0, x1, y1), item_id
            )
            if recovered_pixels:
                recovered_top_icons += 1
                recovered_top_pixels += recovered_pixels
            item_cells[item_id], recovered_pixels = recover_left_overflow(
                sheet, (x0, y0, x1, y1), item_cells[item_id], item_id
            )
            if recovered_pixels:
                recovered_left_icons += 1
                recovered_left_pixels += recovered_pixels

    supplement = Image.open(local_sheets[15]).convert("RGB")
    supplement_cells = cut_grid(supplement, 2, 2)
    item_cells["itm_00257"] = remove_green_background(supplement_cells[0])
    item_cells["itm_00258"] = remove_green_background(supplement_cells[1])
    item_cells["itm_00139"] = remove_green_background(supplement_cells[2])
    # The fourth cell is an unused fork variant.

    removed_bleed_pixels = 0
    cleaned_icons = 0
    for item_number in range(16, 259):
        item_id = f"itm_{item_number:05d}"
        row = by_id[item_id]
        cutout = item_cells[item_id]
        cutout, removed_pixels = remove_detached_edge_bleed(cutout)
        if removed_pixels:
            cleaned_icons += 1
            removed_bleed_pixels += removed_pixels
        final_icon = fit_icon(cutout, int(row["size_w"]) * 128, int(row["size_h"]) * 128)
        final_icon.save(ICONS_DIR / f"{item_id}.png", optimize=True)
        row["icon_path"] = f"res://assets/icons/items/{item_id}.png"

    write_rows(rows)
    build_contact_sheet(rows)
    print(f"Created {258 - 16 + 1} icons")
    print(f"Recovered clipped tops for {recovered_top_icons} icons ({recovered_top_pixels} pixels)")
    print(f"Recovered clipped left edges for {recovered_left_icons} icons ({recovered_left_pixels} pixels)")
    print(f"Removed detached edge bleed from {cleaned_icons} icons ({removed_bleed_pixels} pixels)")
    print(f"Updated {CSV_PATH}")
    print(f"Contact sheet: {CONTACT_SHEET}")


if __name__ == "__main__":
    main()
