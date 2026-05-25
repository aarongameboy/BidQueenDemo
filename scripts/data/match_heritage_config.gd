class_name MatchHeritageConfig
extends RefCounted

const CONFIG_PATH := "res://config/match_heritage_lore.json"

static var _loaded: bool = false
static var _by_map: Dictionary = {}


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	_by_map = {}
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("MatchHeritageConfig: missing %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("MatchHeritageConfig: invalid JSON")
		return
	_by_map = parsed


static func pick_random(map_id: String, seed: int) -> Dictionary:
	load_all()
	var list: Array = _by_map.get(map_id, [])
	if list.is_empty():
		return {
			"name": "未知仓库",
			"description": "本批藏品来源不明，竞拍会仅保证封箱完整。",
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [map_id, seed])
	var row: Dictionary = list[rng.randi_range(0, list.size() - 1)]
	return {
		"name": str(row.get("name", "未知仓库")),
		"description": str(row.get("description", "")),
	}
