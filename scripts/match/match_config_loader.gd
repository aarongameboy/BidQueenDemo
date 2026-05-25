class_name MatchConfigLoader
extends RefCounted

const CONFIG_PATH := "res://config/match_config.json"


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return _defaults()
	var text: String = FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _defaults()
	var cfg: Dictionary = _defaults()
	cfg.merge(parsed, true)
	return cfg


static func _defaults() -> Dictionary:
	return {
		"auction_mode": "open",
		"seat_count": 4,
		"player_seat": 0,
		"player_character_id": "aria_lionheart",
		"max_rounds": 5,
		"bid_window_seconds": GameConstants.DEFAULT_BID_WINDOW_SECONDS,
		"min_raise": GameConstants.DEFAULT_MIN_RAISE,
		"starting_bid": GameConstants.DEFAULT_STARTING_BID,
		"reserve_quick_buy": 0,
		"bot_tick_seconds": GameConstants.DEFAULT_BOT_TICK_SECONDS,
		"warehouse_grid_w": 10,
		"warehouse_grid_h": 20,
		"warehouse_item_min": 15,
		"warehouse_item_max": 40,
		"warehouse_item_count_weights": {},
		"max_place_retries": 24,
		"unbox_item_delay": 0.55,
	}
