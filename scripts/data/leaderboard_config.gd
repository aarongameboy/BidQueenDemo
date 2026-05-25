class_name LeaderboardConfig
extends RefCounted

const CONFIG_PATH := "res://config/leaderboard.json"

static var _loaded: bool = false
static var _data: Dictionary = {}


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("LeaderboardConfig: missing %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed


static func get_regions() -> Array:
	load_all()
	return _data.get("regions", [])


static func get_region_label(region_id: String) -> String:
	for row in get_regions():
		if str(row.get("id", "")) == region_id:
			return str(row.get("label", region_id))
	return region_id


static func get_categories() -> Array:
	load_all()
	return _data.get("categories", [])


static func get_category(category_id: String) -> Dictionary:
	for row in get_categories():
		if str(row.get("id", "")) == category_id:
			return row
	return {}


static func get_periods() -> Array:
	load_all()
	return _data.get("periods", [])


static func get_bot_npcs() -> Array:
	load_all()
	return _data.get("bot_npcs", [])
