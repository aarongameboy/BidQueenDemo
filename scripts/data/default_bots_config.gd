class_name DefaultBotsConfig
extends RefCounted
## 默认 Bot 席位：config/default_bots.json（v2.0 代理人）

const CONFIG_PATH := "res://config/default_bots.json"

static var _loaded: bool = false
static var _bots: Array[Dictionary] = []
static var _open_auction_defaults: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_bots.clear()
	_open_auction_defaults.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var open_cfg: Variant = parsed.get("open_auction", {})
	if typeof(open_cfg) == TYPE_DICTIONARY:
		_open_auction_defaults = open_cfg
	for row in parsed.get("bots", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		_bots.append(row)


static func get_bot_entries() -> Array[Dictionary]:
	ensure_loaded()
	return _bots.duplicate(true)


static func get_bot_for_seat(seat: int) -> Dictionary:
	ensure_loaded()
	for row in _bots:
		if int(row.get("seat", -1)) == seat:
			return row.duplicate(true)
	return {}


static func get_open_auction_defaults() -> Dictionary:
	ensure_loaded()
	return _open_auction_defaults.duplicate(true)
