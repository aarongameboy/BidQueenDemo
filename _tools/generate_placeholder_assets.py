# -*- coding: utf-8 -*-
"""Generate placeholder PNG icons and avatars (no external deps)."""
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets"
ICON_DIR = ROOT / "icons" / "items"
AVATAR_DIR = ROOT / "ui" / "avatars"


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_png(path: Path, w: int, h: int, rgba_fn) -> None:
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b, a = rgba_fn(x, y)
            raw.extend((r, g, b, a))
    comp = zlib.compress(bytes(raw), 9)
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = sig + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", comp) + _png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def icon_color(hex_color: str) -> tuple:
    h = hex_color.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def main() -> None:
    colors = ["#B0B0B0", "#4CAF50", "#2196F3", "#9C27B0", "#FFC107", "#F44336"]
    for i, col in enumerate(colors):
        c = icon_color(col)
        write_png(
            ICON_DIR / f"placeholder_q{i}.png",
            64,
            64,
            lambda x, y, c=c: (
                c[0], c[1], c[2], 255 if 4 < x < 60 and 4 < y < 60 else 40
            ),
        )
    avatar_colors = [(90, 140, 200), (200, 120, 90), (100, 180, 120), (170, 120, 200)]
    for i, c in enumerate(avatar_colors):
        write_png(
            AVATAR_DIR / f"avatar_{i}.png",
            128,
            128,
            lambda x, y, c=c: (
                c[0], c[1], c[2], 255 if (x - 64) ** 2 + (y - 64) ** 2 < 55 ** 2 else 0
            ),
        )
    print("OK icons + avatars ->", ROOT)


if __name__ == "__main__":
    main()
