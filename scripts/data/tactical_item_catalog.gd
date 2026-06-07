class_name TacticalItemCatalog
extends RefCounted

const CONFIG_PATH := "res://config/tactical_items.json"

var _items_by_id: Dictionary = {}
var _items: Array[Dictionary] = []
var _max_loadout_slots: int = 5
var _loaded: bool = false


func load_all() -> bool:
	_items_by_id.clear()
	_items.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	_max_loadout_slots = int(parsed.get("max_loadout_slots", 5))
	for row in parsed.get("items", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = row
		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty():
			continue
		_items.append(item)
		_items_by_id[item_id] = item
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


func get_max_loadout_slots() -> int:
	return _max_loadout_slots


func get_all_items() -> Array[Dictionary]:
	return _items.duplicate()


func get_item(item_id: String) -> Dictionary:
	return _items_by_id.get(item_id, {}).duplicate(true)


func get_items_by_category(category_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in _items:
		if str(row.get("category", "")) == category_id:
			out.append(row)
	return out


static func quality_to_enum(quality_key: String) -> int:
	var key: String = quality_key.strip_edges().to_lower()
	for i in GameConstants.QUALITY_KEYS.size():
		if GameConstants.QUALITY_KEYS[i] == key:
			return i
	return GameConstants.Quality.WHITE


static func quality_label(quality_key: String) -> String:
	var idx: int = quality_to_enum(quality_key)
	if idx >= 0 and idx < GameConstants.QUALITY_NAMES.size():
		return str(GameConstants.QUALITY_NAMES[idx])
	return quality_key


static func quality_color(quality_key: String) -> Color:
	return GameConstants.get_quality_color(quality_to_enum(quality_key))
