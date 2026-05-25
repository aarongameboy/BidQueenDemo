class_name ItemCatalog
extends RefCounted
## Loads items_master + spawn pools + quality modifiers from CSV.

const ITEMS_PATH := "res://config/items_master.csv"
const POOLS_PATH := "res://config/spawn_pool_table.csv"
const MODS_PATH := "res://config/quality_modifier_table.csv"

const QUALITY_TO_ENUM: Dictionary = {
    "white": GameConstants.Quality.WHITE,
    "green": GameConstants.Quality.GREEN,
    "blue": GameConstants.Quality.BLUE,
    "purple": GameConstants.Quality.PURPLE,
    "gold": GameConstants.Quality.GOLD,
    "red": GameConstants.Quality.RED,
}

## 道具类型（与 items_master item_type 列一致）
const TYPE_MAGIC: String = "magic"
const TYPE_BIOLOGICAL: String = "biological"
const TYPE_BUILDING: String = "building"
const TYPE_DAILY: String = "daily"
const TYPE_ART: String = "art"
const TYPE_DOCUMENT: String = "document"
const TYPE_RAW_MATERIAL: String = "raw_material"

const TYPE_ORDER: PackedStringArray = [
    TYPE_MAGIC, TYPE_BIOLOGICAL, TYPE_BUILDING, TYPE_DAILY,
    TYPE_ART, TYPE_DOCUMENT, TYPE_RAW_MATERIAL,
]

const TYPE_LABELS: Dictionary = {
    TYPE_MAGIC: "魔法物品",
    TYPE_BIOLOGICAL: "生物物品",
    TYPE_BUILDING: "建材工具",
    TYPE_DAILY: "日常用具",
    TYPE_ART: "艺术藏品",
    TYPE_DOCUMENT: "文献书籍",
    TYPE_RAW_MATERIAL: "原石木料",
}

var _items_by_id: Dictionary = {}
var _items_by_pool: Dictionary = {}
var _pools: Array[Dictionary] = []
var _quality_mods: Dictionary = {}
var _min_price_by_quality_size: Dictionary = {}
## 品质 + 占格总数（格数） -> 主表最低 base_price
var _min_price_by_quality_cells: Dictionary = {}
var _loaded: bool = false


func load_all() -> bool:
    _items_by_id.clear()
    _items_by_pool.clear()
    _pools.clear()
    _quality_mods.clear()
    if not _load_items():
        return false
    if not _load_pools():
        return false
    if not _load_modifiers():
        return false
    _build_min_price_index()
    _loaded = true
    return true


func is_loaded() -> bool:
    return _loaded


func get_item(item_id: String) -> Dictionary:
    return _items_by_id.get(item_id, {})


func get_items_by_quality_name(quality_name: String) -> Array:
    var out: Array = []
    for item in _items_by_id.values():
        if str(item.get("quality", "")) != quality_name:
            continue
        out.append(item)
    out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a.get("base_price", 0)) > int(b.get("base_price", 0))
    )
    return out


func get_items_in_pool(pool_tag: String) -> Array:
    if _items_by_pool.has(pool_tag):
        return _items_by_pool[pool_tag]
    match pool_tag:
        "epic":
            return _items_by_pool.get("rare", [])
        "mythic":
            return _items_by_pool.get("legendary", [])
        _:
            return []


func get_pools() -> Array[Dictionary]:
    return _pools


func get_quality_multiplier(context: String, quality_name: String) -> float:
    var ctx: Dictionary = _quality_mods.get(context, {})
    return float(ctx.get(quality_name, 1.0))


func _load_items() -> bool:
    if not FileAccess.file_exists(ITEMS_PATH):
        push_error("Missing %s" % ITEMS_PATH)
        return false
    var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
    var header: PackedStringArray = file.get_csv_line()
    var idx: Dictionary = _header_index(header)
    while not file.eof_reached():
        var line: PackedStringArray = file.get_csv_line()
        if line.is_empty() or line.size() < header.size():
            continue
        if line[idx["enabled"]] != "1":
            continue
        var item: Dictionary = {
            "item_id": line[idx["item_id"]].strip_edges(),
            "item_name": line[idx["item_name"]].strip_edges(),
            "size_w": int(line[idx["size_w"]]),
            "size_h": int(line[idx["size_h"]]),
            "base_price": int(line[idx["base_price"]]),
            "icon_path": line[idx["icon_path"]].strip_edges(),
            "quality": line[idx["quality"]].strip_edges(),
            "quality_enum": QUALITY_TO_ENUM.get(line[idx["quality"]].strip_edges(), GameConstants.Quality.WHITE),
            "quality_color": GameConstants.get_quality_color_hex(
                line[idx["quality"]].strip_edges(),
            ),
            "item_type": resolve_item_type(line[idx["item_id"]].strip_edges()),
            "flavor_text": _parse_optional_cell(line, idx, "flavor_text"),
            "pool_tag": line[idx["pool_tag"]].strip_edges(),
            "weight": _parse_float_cell(line, idx, "weight", 0.0),
        }
        for key in idx.keys():
            if key.begins_with("w_"):
                item[key] = _parse_float_cell(line, idx, key, float(item["weight"]))
        _items_by_id[item["item_id"]] = item
        var pool: String = item["pool_tag"]
        if not _items_by_pool.has(pool):
            _items_by_pool[pool] = []
        _items_by_pool[pool].append(item)
    return _items_by_id.size() > 0


func _load_pools() -> bool:
    if not FileAccess.file_exists(POOLS_PATH):
        return false
    var file := FileAccess.open(POOLS_PATH, FileAccess.READ)
    var header: PackedStringArray = file.get_csv_line()
    var idx: Dictionary = _header_index(header)
    while not file.eof_reached():
        var line: PackedStringArray = file.get_csv_line()
        if line.is_empty() or line.size() < header.size() or line[idx["enabled"]] != "1":
            continue
        _pools.append({
            "pool_tag": line[idx["pool_tag"]],
            "pool_weight": int(line[idx["pool_weight"]]),
            "min_items": int(line[idx["min_items"]]),
            "max_items": int(line[idx["max_items"]]),
        })
    return not _pools.is_empty()


func _load_modifiers() -> bool:
    if not FileAccess.file_exists(MODS_PATH):
        return false
    var file := FileAccess.open(MODS_PATH, FileAccess.READ)
    var header: PackedStringArray = file.get_csv_line()
    var idx: Dictionary = _header_index(header)
    while not file.eof_reached():
        var line: PackedStringArray = file.get_csv_line()
        if line.is_empty() or line.size() < header.size() or line[idx["enabled"]] != "1":
            continue
        var ctx: String = line[idx["context"]]
        if not _quality_mods.has(ctx):
            _quality_mods[ctx] = {}
        _quality_mods[ctx][line[idx["quality"]]] = float(line[idx["multiplier"]])
    return true


func get_min_base_price_for_quality_size(quality_enum: int, size_w: int, size_h: int) -> int:
    var key: String = _quality_size_key(quality_enum, size_w, size_h)
    return int(_min_price_by_quality_size.get(key, 0))


func get_min_base_price_for_quality_cells(quality_enum: int, cell_count: int) -> int:
    var key: String = _quality_cells_key(quality_enum, cell_count)
    return int(_min_price_by_quality_cells.get(key, 0))


func get_min_base_price_for_known_item(quality_enum: int, size_w: int, size_h: int) -> int:
    var cells: int = maxi(size_w * size_h, 1)
    var by_cells: int = get_min_base_price_for_quality_cells(quality_enum, cells)
    if by_cells > 0:
        return by_cells
    var by_size: int = get_min_base_price_for_quality_size(quality_enum, size_w, size_h)
    if by_size > 0:
        return by_size
    return 0


## 仅知占格、不知品质时：各品质同 footprint 的 catalog 最低价
func get_min_base_price_for_size(size_w: int, size_h: int) -> int:
    var best: int = 0
    for q in range(GameConstants.QUALITY_COUNT):
        var p: int = get_min_base_price_for_known_item(q, size_w, size_h)
        if p > 0 and (best == 0 or p < best):
            best = p
    return best


func _build_min_price_index() -> void:
    _min_price_by_quality_size.clear()
    _min_price_by_quality_cells.clear()
    for item in _items_by_id.values():
        var q: int = int(item["quality_enum"])
        var sw: int = int(item["size_w"])
        var sh: int = int(item["size_h"])
        var price: int = int(item["base_price"])
        var size_key: String = _quality_size_key(q, sw, sh)
        if not _min_price_by_quality_size.has(size_key) or price < _min_price_by_quality_size[size_key]:
            _min_price_by_quality_size[size_key] = price
        var cells: int = maxi(sw * sh, 1)
        var cells_key: String = _quality_cells_key(q, cells)
        if not _min_price_by_quality_cells.has(cells_key) or price < _min_price_by_quality_cells[cells_key]:
            _min_price_by_quality_cells[cells_key] = price


static func _quality_size_key(quality_enum: int, size_w: int, size_h: int) -> String:
    return "%d_%d_%d" % [quality_enum, size_w, size_h]


static func _quality_cells_key(quality_enum: int, cell_count: int) -> String:
    return "%d_c%d" % [quality_enum, maxi(cell_count, 1)]


func get_all_items() -> Array:
    var list: Array = []
    for id in _items_by_id.keys():
        list.append(_items_by_id[id])
    return list


func get_unique_sizes() -> Array:
    var seen: Dictionary = {}
    var out: Array = []
    for item in _items_by_id.values():
        var key: String = "%d_%d" % [item["size_w"], item["size_h"]]
        if seen.has(key):
            continue
        seen[key] = true
        out.append({"size_w": item["size_w"], "size_h": item["size_h"], "key": key})
    out.sort_custom(func(a, b):
        return a["size_w"] * a["size_h"] < b["size_w"] * b["size_h"]
    )
    return out


static func _parse_optional_cell(line: PackedStringArray, idx: Dictionary, key: String) -> String:
    if not idx.has(key) or idx[key] >= line.size():
        return ""
    return line[idx[key]].strip_edges()


static func _parse_int_cell(line: PackedStringArray, idx: Dictionary, key: String, fallback: int) -> int:
    if not idx.has(key) or idx[key] >= line.size():
        return fallback
    var raw: String = line[idx[key]].strip_edges()
    if raw.is_valid_int():
        return int(raw)
    return fallback


static func _parse_float_cell(line: PackedStringArray, idx: Dictionary, key: String, fallback: float) -> float:
    if not idx.has(key) or idx[key] >= line.size():
        return fallback
    var raw: String = line[idx[key]].strip_edges()
    if raw.is_valid_float():
        return float(raw)
    return fallback


## 按 item_id 序号划分类型：00001-00057 魔法 … 00240-00258 原石木料
static func resolve_item_type(item_id: String) -> String:
    var num: int = _item_id_number(item_id)
    if num <= 0:
        return TYPE_MAGIC
    if num <= 57:
        return TYPE_MAGIC
    if num <= 87:
        return TYPE_BIOLOGICAL
    if num <= 133:
        return TYPE_BUILDING
    if num <= 176:
        return TYPE_DAILY
    if num <= 218:
        return TYPE_ART
    if num <= 239:
        return TYPE_DOCUMENT
    if num <= 258:
        return TYPE_RAW_MATERIAL
    return TYPE_MAGIC


static func get_type_label(type_id: String) -> String:
    return str(TYPE_LABELS.get(type_id, type_id))


static func _item_id_number(item_id: String) -> int:
    var digits: String = item_id.strip_edges()
    if digits.begins_with("itm_"):
        digits = digits.substr(4)
    if digits.is_valid_int():
        return int(digits)
    return 0


static func _header_index(header: PackedStringArray) -> Dictionary:
    var idx: Dictionary = {}
    for i in header.size():
        var key: String = header[i].strip_edges()
        if key.begins_with("\ufeff"):
            key = key.substr(1)
        idx[key] = i
    return idx


static func weighted_pick(entries: Array, weight_key: String, rng: RandomNumberGenerator) -> Variant:
    const SCALE: float = 10000.0
    var total: int = 0
    for e in entries:
        total += int(float(e.get(weight_key, 0.0)) * SCALE)
    if total <= 0:
        return null
    var roll: int = rng.randi_range(1, total)
    var acc: int = 0
    for e in entries:
        acc += int(float(e.get(weight_key, 0.0)) * SCALE)
        if roll <= acc:
            return e
    return entries.back()
