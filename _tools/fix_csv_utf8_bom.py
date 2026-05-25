# -*- coding: utf-8 -*-
"""Rewrite config/*.csv as UTF-8 with BOM so Excel / Windows editors show Chinese correctly."""
from __future__ import annotations

import sys
from pathlib import Path

CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"
BOM = b"\xef\xbb\xbf"


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    if raw.startswith(BOM):
        return raw[len(BOM) :].decode("utf-8")
    for enc in ("utf-8", "gbk", "cp936"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("utf-8", raw, 0, 1, "cannot decode %s" % path)


def write_utf8_bom(path: Path, text: str) -> None:
    path.write_bytes(BOM + text.encode("utf-8"))


def main() -> int:
    paths = sorted(CONFIG_DIR.glob("*.csv"))
    if not paths:
        print("No CSV files in", CONFIG_DIR)
        return 1
    for path in paths:
        text = read_text(path)
        if not text.endswith("\n"):
            text += "\n"
        write_utf8_bom(path, text)
        print("UTF-8 BOM:", path.name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
