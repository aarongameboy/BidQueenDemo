#!/usr/bin/env python3
"""扫描 BidKing Demo 美术资源与代码引用，生成 docs/asset-library/manifest.json"""
from __future__ import annotations

import csv
import json
import re
import shutil
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
OUT_DIR = ROOT / "docs" / "asset-library"
PREVIEW_DIR = OUT_DIR / "preview"
MANIFEST_PATH = OUT_DIR / "manifest.json"
OVERRIDES_PATH = OUT_DIR / "overrides.json"

# 代码路径与磁盘文件名不一致时，用已有文件生成预览
FILE_ALIASES: dict[str, str] = {
    "assets/ui/close.png": "assets/ui/close_button.png",
}

PREVIEW_EXTS = {".png", ".jpg", ".jpeg", ".svg", ".webp", ".mp3", ".wav"}

SCAN_EXTS = {".gd", ".json", ".tscn", ".csv", ".md"}
ASSET_EXT = {".png", ".jpg", ".jpeg", ".svg", ".webp", ".ttf", ".otf", ".mp3", ".wav"}
RES_RE = re.compile(r"res://assets/[A-Za-z0-9_./\-%~\u4e00-\u9fff]+")

# 手工文案（可在此维护；生成器会合并自动描述）
MANUAL_DESC: dict[str, str] = {
    "res://assets/ui/bg_warehouse.png": "主界面/对局全屏背景，推荐 1280×720，UiTextureCache + main.tscn",
    "res://assets/ui/button.png": "通用按钮九宫格底图，UiButtonStyle.make_box（运行期多改为扁平样式）",
    "res://assets/ui/close.png": "关闭/返回图标，UiCloseButton（磁盘上可能为 close_button.png，需对齐）",
    "res://assets/ui/close_button.png": "关闭按钮图（若代码仍写 close.png 需同步）",
    "res://assets/ui/money.png": "银币/货币图标，UiMoneyIcon、大厅资产行",
    "res://assets/music/JY.mp3": "BGM · 琥珀商馆 dam",
    "res://assets/music/AL.mp3": "BGM · 银雾修道院 valley",
    "res://assets/music/CA.mp3": "BGM · 航天城 aerospace",
    "res://assets/music/CS.mp3": "BGM · 黑牢 prison",
}

CATEGORY_RULES: list[tuple[str, str, tuple[str, ...]]] = [
    ("ui-shell", "UI · 壳层与控件", ("assets/ui/bg_", "assets/ui/button", "assets/ui/close", "assets/ui/money")),
    ("ui-nav", "UI · 导航图标", ("assets/ui/icons/",)),
    ("ui-maps", "UI · 地图预览", ("assets/ui/maps/",)),
    ("ui-characters", "UI · 角色立绘", ("assets/ui/characters/",)),
    ("ui-avatars", "UI · 席位头像", ("assets/ui/avatars/",)),
    ("items-icons", "道具 · 图标", ("assets/icons/items/itm_", "assets/icons/items/placeholder")),
    ("items-frames", "道具 · 品质框", ("assets/icons/items/white", "assets/icons/items/green",
     "assets/icons/items/blue", "assets/icons/items/purple", "assets/icons/items/gold",
     "assets/icons/items/red")),
    ("audio", "音频 · BGM", ("assets/music/",)),
    ("fonts", "字体", ("assets/fonts/",)),
    ("concept", "概念稿", ("assets/ui/art_concept/",)),
]


def res_to_rel(res_path: str) -> str:
    if res_path.startswith("res://"):
        return res_path[6:]
    return res_path


def collect_asset_files() -> dict[str, Path]:
    found: dict[str, Path] = {}
    if not ASSETS.exists():
        return found
    for p in ASSETS.rglob("*"):
        if p.is_file() and p.suffix.lower() in ASSET_EXT:
            res = "res://" + p.relative_to(ROOT).as_posix()
            found[res] = p
    return found


def collect_code_refs() -> dict[str, list[dict]]:
    refs: dict[str, list[dict]] = defaultdict(list)
    for path in ROOT.rglob("*"):
        if path.suffix not in SCAN_EXTS:
            continue
        if "docs/asset-library" in path.as_posix():
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            for m in RES_RE.finditer(line):
                res = m.group(0).rstrip(".,;)'\"")
                refs[res].append({
                    "file": path.relative_to(ROOT).as_posix(),
                    "line": i,
                    "snippet": line.strip()[:120],
                })
    return refs


def load_item_icons_from_csv() -> dict[str, str]:
    desc: dict[str, str] = {}
    csv_path = ROOT / "config" / "items_master.csv"
    if not csv_path.exists():
        return desc
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            icon = (row.get("icon_path") or "").strip()
            name = (row.get("item_name") or "").strip()
            iid = (row.get("item_id") or "").strip()
            if icon.startswith("res://") and name:
                key = icon
                line = f"道具「{name}」({iid})，items_master.csv"
                if key in desc:
                    if name not in desc[key]:
                        desc[key] += f"；{name}"
                else:
                    desc[key] = line
    return desc


def load_character_portraits() -> dict[str, str]:
    desc: dict[str, str] = {}
    cfg = ROOT / "config" / "characters.json"
    if not cfg.exists():
        return desc
    data = json.loads(cfg.read_text(encoding="utf-8"))
    for ch in data.get("characters", []):
        port = ch.get("portrait", "")
        if port:
            desc[port] = (
                f"{ch.get('display_name', '')} · {ch.get('role', '')} · "
                f"技能「{ch.get('skill_name', '')}」— {ch.get('skill_desc', '')}"
            )
    return desc


def load_map_previews() -> dict[str, str]:
    desc: dict[str, str] = {}
    cfg = ROOT / "config" / "map_modes.json"
    if not cfg.exists():
        return desc
    data = json.loads(cfg.read_text(encoding="utf-8"))
    for m in data.get("maps", []):
        img = m.get("preview_image", "")
        if img:
            desc[img] = f"选图卡片预览 · {m.get('map_name', m.get('map_id', ''))}"
    return desc


def resolve_disk_path(rel: str, files: dict[str, Path]) -> tuple[Path | None, bool]:
    res = f"res://{rel}"
    disk = files.get(res)
    if disk is not None and disk.exists():
        return disk, True
    alias_rel = FILE_ALIASES.get(rel, "")
    if alias_rel:
        alias_path = ROOT / alias_rel
        if alias_path.exists():
            return alias_path, True
    direct = ROOT / rel
    if direct.exists():
        return direct, True
    return None, False


def prepare_preview_dir() -> None:
    if PREVIEW_DIR.exists():
        shutil.rmtree(PREVIEW_DIR)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)


def copy_to_preview(rel: str, source: Path) -> str:
    if source.suffix.lower() not in PREVIEW_EXTS:
        return ""
    dest = PREVIEW_DIR / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, dest)
    return f"preview/{rel}".replace("\\", "/")


def sync_project_asset_aliases() -> None:
    for target_rel, source_rel in FILE_ALIASES.items():
        target = ROOT / target_rel
        source = ROOT / source_rel
        if source.exists() and not target.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            print(f"  alias: {target_rel} <- {source_rel}")


def categorize(res_path: str) -> str:
    rel = res_to_rel(res_path)
    for cat_id, _, prefixes in CATEGORY_RULES:
        for pref in prefixes:
            if rel.startswith(pref) or pref in rel:
                return cat_id
    return "other"


def build_tokens() -> dict:
    art = ROOT / "docs" / "art_concept" / "medieval_anime_auction_art_direction.md"
    brand_colors = [
        {"name": "深靛蓝（背景）", "hex": "#182033", "usage": "美术方案主背景色"},
        {"name": "王冠金", "hex": "#D8A84E", "usage": "强调、资产数字"},
        {"name": "羊皮纸", "hex": "#E7D4A2", "usage": "信息层、说明文案"},
        {"name": "宝石青", "hex": "#40C2B8", "usage": "练习模式、正向提示"},
        {"name": "酒红", "hex": "#8B2F45", "usage": "警示、稀有氛围"},
    ]
    quality = [
        {"key": k, "hex": v, "label": n}
        for k, v, n in [
            ("white", "#B2B2B2", "白"),
            ("green", "#44612b", "绿"),
            ("blue", "#29487d", "蓝"),
            ("purple", "#4e297d", "紫"),
            ("gold", "#b1a221", "金"),
            ("red", "#a4492a", "红"),
        ]
    ]
    ui_accents = [
        {"name": "快速匹配强调", "hex": "#EB5757", "rgb": "0.92,0.34,0.32", "file": "lobby_ui.gd"},
        {"name": "面板背景", "hex": "#0F101A", "rgb": "0.06,0.07,0.1", "file": "多处 Panel StyleBoxFlat"},
        {"name": "按钮扁平底", "hex": "#242A38", "rgb": "0.14,0.16,0.22", "file": "ui_button_style.gd"},
        {"name": "正文浅色", "hex": "#F3F6FA", "rgb": "0.95,0.97,1.0", "file": "按钮/标签默认字色"},
    ]
    fonts = [
        {
            "role": "标题",
            "paths": [
                "res://assets/fonts/LaoMingChaoD.ttf",
                "res://assets/fonts/老明朝D.ttf",
                "res://assets/fonts/LaoMingChaoD.otf",
            ],
            "code": "FontUtil.get_title_font() / style_title_label",
            "fallback": "老明朝体 / Songti SC",
        },
        {
            "role": "正文（中文+英文回退）",
            "paths": [
                "res://assets/fonts/SourceHanSansSC-Regular.otf",
                "res://assets/fonts/NotoSansSC-Regular.otf",
                "res://assets/fonts/Futura.ttf",
            ],
            "code": "FontUtil.get_body_font() / apply_cjk_font",
            "fallback": "思源黑体 + Futura",
        },
    ]
    for f in fonts:
        f["exists"] = any((ROOT / res_to_rel(p)).exists() for p in f["paths"])

    nav_icons = [
        {"file": "shop_outlined.svg", "label": "商店", "action": "shop"},
        {"file": "hdd_outlined.svg", "label": "仓库", "action": "warehouse"},
        {"file": "eye_outlined.svg", "label": "百科", "action": "encyclopedia"},
        {"file": "trophy_outlined.svg", "label": "收藏", "action": "collection"},
        {"file": "user_switch_outlined.svg", "label": "角色", "action": "characters"},
        {"file": "book_outlined.svg", "label": "排行榜", "action": "leaderboard"},
    ]
    return {
        "brand": brand_colors,
        "quality": quality,
        "ui_accents": ui_accents,
        "fonts": fonts,
        "nav_icons": nav_icons,
        "viewport": {"width": 1280, "height": 720},
    }


def build_manifest() -> dict:
    files = collect_asset_files()
    refs = collect_code_refs()
    auto_desc = {}
    auto_desc.update(load_item_icons_from_csv())
    auto_desc.update(load_character_portraits())
    auto_desc.update(load_map_previews())

    all_paths = set(files.keys()) | set(refs.keys())
    # 代码引用但磁盘缺失
    for res in list(refs.keys()):
        if res not in files:
            all_paths.add(res)

    items_by_cat: dict[str, list] = defaultdict(list)
    for res in sorted(all_paths):
        rel = res_to_rel(res)
        disk, exists = resolve_disk_path(rel, files)
        desc = MANUAL_DESC.get(res) or auto_desc.get(res, "")
        if not desc:
            if "placeholder_q" in rel:
                q = rel.split("placeholder_q")[-1].split(".")[0]
                desc = f"未揭示道具占位图 · 品质槽 {q}"
            elif rel.endswith("/white.png") or "/green.png" in rel:
                desc = "道具格品质边框 · ItemQualityFrame"
            elif "avatar_" in rel:
                desc = "席位占位头像（Bot/默认）"
            elif rel.endswith(".svg") and "icons/" in rel:
                desc = "大厅导航描边图标 · lobby_ui ICONS_DIR"
            else:
                desc = "（暂无描述，可在 generate_asset_library.py 的 MANUAL_DESC 补充）"

        usage = refs.get(res, [])
        preview_url = copy_to_preview(rel, disk) if exists and disk else ""
        web_url = f"/{rel}" if exists else ""
        items_by_cat[categorize(res)].append({
            "id": rel.replace("/", "__"),
            "path": res,
            "previewUrl": preview_url,
            "webUrl": web_url,
            "relFile": f"../../{rel}" if exists else "",
            "fileName": Path(rel).name,
            "description": desc,
            "usages": usage[:12],
            "usageCount": len(usage),
            "exists": exists,
            "ext": Path(rel).suffix.lower(),
        })

    categories = []
    cat_names = {cid: name for cid, name, _ in CATEGORY_RULES}
    cat_names["other"] = "其他"
    order = [c[0] for c in CATEGORY_RULES] + ["other"]
    for cid in order:
        group = items_by_cat.get(cid, [])
        if not group:
            continue
        categories.append({
            "id": cid,
            "name": cat_names.get(cid, cid),
            "count": len(group),
            "items": group,
        })

    missing = [i for c in categories for i in c["items"] if not i["exists"]]
    manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "project": "BidKing Demo",
        "projectRoot": str(ROOT),
        "stats": {
            "assetFiles": len(files),
            "referencedPaths": len(refs),
            "missingOnDisk": len(missing),
        },
        "tokens": build_tokens(),
        "categories": categories,
        "missingAssets": missing,
        "previewDir": "preview",
        "serveHint": "本地编辑: python tools/serve_asset_library.py → http://127.0.0.1:8765/",
        "overridesFile": "overrides.json",
    }
    apply_overrides_to_manifest(manifest, load_overrides())
    return manifest


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Syncing asset aliases...")
    sync_project_asset_aliases()
    print("Building preview copies...")
    prepare_preview_dir()
    manifest = build_manifest()
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Wrote {MANIFEST_PATH}")
    preview_count = sum(
        1
        for cat in manifest["categories"]
        for item in cat["items"]
        if item.get("previewUrl")
    )
    print(
        f"  assets={manifest['stats']['assetFiles']} "
        f"refs={manifest['stats']['referencedPaths']} "
        f"missing={manifest['stats']['missingOnDisk']} "
        f"previews={preview_count}"
    )


if __name__ == "__main__":
    main()
