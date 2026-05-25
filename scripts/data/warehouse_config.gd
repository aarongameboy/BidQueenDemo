class_name WarehouseConfig
extends RefCounted

const CONFIG_PATH := "res://config/warehouse_config.json"

static var _cached: Dictionary = {}


static func load_all() -> Dictionary:
	if not _cached.is_empty():
		return _cached
	if not FileAccess.file_exists(CONFIG_PATH):
		_cached = _defaults()
		return _cached
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		_cached = _defaults()
		return _cached
	_cached = parsed
	return _cached


static func get_default_page() -> Dictionary:
	var cfg: Dictionary = load_all()
	var page: Variant = cfg.get("default_page", {})
	if typeof(page) != TYPE_DICTIONARY:
		return _defaults()["default_page"]
	return page


static func get_expected_page_size(page_name: String) -> Vector2i:
	var cfg: Dictionary = load_all()
	var dp: Dictionary = cfg.get("default_page", {})
	if page_name == str(dp.get("name", "主仓库")):
		return Vector2i(int(dp.get("grid_w", 10)), int(dp.get("grid_h", 20)))
	var ep: Dictionary = cfg.get("expansion_pages", {})
	if ep.has(page_name):
		var e: Dictionary = ep[page_name]
		return Vector2i(int(e.get("grid_w", 0)), int(e.get("grid_h", 0)))
	return Vector2i.ZERO


static func _defaults() -> Dictionary:
	return {
		"default_page": {
			"name": "主仓库",
			"grid_w": 10,
			"grid_h": 20,
		},
	}
