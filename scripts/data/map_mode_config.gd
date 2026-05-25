class_name MapModeConfig
extends RefCounted

const CONFIG_PATH := "res://config/map_modes.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func load_all() -> bool:
	_data.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("Missing %s" % CONFIG_PATH)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid map_modes.json")
		return false
	_data = parsed
	_loaded = true
	return true


static func is_loaded() -> bool:
	return _loaded


static func get_maps() -> Array:
	if not _loaded:
		load_all()
	return _data.get("maps", [])


static func get_map(map_id: String) -> Dictionary:
	for entry in get_maps():
		if str(entry.get("map_id", "")) == map_id:
			return entry
	return {}


static func get_preview_image_path(map_id: String) -> String:
	return str(get_map(map_id).get("preview_image", ""))


static func get_feature_text(map_id: String) -> String:
	return str(get_map(map_id).get("feature_text", ""))


static func get_mode(map_id: String, mode_id: String) -> Dictionary:
	var map_entry: Dictionary = get_map(map_id)
	for mode in map_entry.get("modes", []):
		if str(mode.get("mode_id", "")) == mode_id:
			var out: Dictionary = mode.duplicate(true)
			out["map_id"] = map_id
			out["map_name"] = str(map_entry.get("map_name", map_id))
			return out
	return {}


static func get_instant_kill_multipliers() -> Array:
	if not _loaded:
		load_all()
	var arr: Array = _data.get("instant_kill_multipliers", [2.0, 1.8, 1.6, 1.4, 1.2, 1.1])
	return arr


static func instant_kill_multiplier_for_round(round_index: int, multipliers: Array = []) -> float:
	var list: Array = multipliers if not multipliers.is_empty() else get_instant_kill_multipliers()
	if list.is_empty():
		return 1.0
	var idx: int = clampi(round_index - 1, 0, list.size() - 1)
	return float(list[idx])
