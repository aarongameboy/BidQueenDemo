class_name PlayerState
extends RefCounted

const CharacterDataScript = preload("res://scripts/data/character_data.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")

var seat_index: int = 0
var character_id: String = ""
var display_name: String = ""
var is_bot: bool = true
var is_human: bool = false
var silver: int = GameConstants.STARTING_SILVER
var current_bid: int = 0
var last_bid_hint: String = ""
var valuation_bias: float = 0.0
var aggression: float = 0.3
var bluff_rate: float = 0.1
var raise_tendency: float = 0.35
var max_chase_ratio: float = 1.25
var reaction_delay: float = 1.0
var passed_this_round: bool = false
## 任一轮未出价则视为整场弃权，不再参与后续竞拍
var forfeited_match: bool = false
var net_profit_this_match: int = 0
var won_auction: bool = false
var character_title: String = ""
## 每轮最终出价（5 轮），0 表示该轮未出价
var round_bids: Array[int] = []
## 每轮使用的战术道具 ID；空字符串表示该轮未使用
var round_tactical_items: Array[String] = []


func _init(seat: int, char_id: String, bot_cfg: Dictionary = {}) -> void:
	seat_index = seat
	character_id = char_id
	if char_id == "hero":
		display_name = "巅峰收藏家"
		character_title = "主角"
	else:
		display_name = CharacterDataScript.get_display_name(char_id)
		if RosterConfigScript.has_character(char_id):
			character_title = RosterConfigScript.get_role_title(char_id)
		else:
			character_title = _title_for_legacy_character(char_id)
	round_bids.resize(GameConstants.MAX_ROUNDS)
	round_tactical_items.resize(GameConstants.MAX_ROUNDS)
	for i in GameConstants.MAX_ROUNDS:
		round_bids[i] = 0
		round_tactical_items[i] = ""
	is_human = bool(bot_cfg.get("is_human", false))
	if bot_cfg.has("is_bot"):
		is_bot = bool(bot_cfg["is_bot"])
	else:
		is_bot = not is_human
	if bot_cfg.has("aggression"):
		aggression = float(bot_cfg["aggression"])
	if bot_cfg.has("bluff_rate"):
		bluff_rate = float(bot_cfg["bluff_rate"])
	if bot_cfg.has("valuation_bias"):
		valuation_bias = float(bot_cfg["valuation_bias"])
	if bot_cfg.has("raise_tendency"):
		raise_tendency = float(bot_cfg["raise_tendency"])
	if bot_cfg.has("max_chase_ratio"):
		max_chase_ratio = float(bot_cfg["max_chase_ratio"])
	if bot_cfg.has("reaction_delay"):
		reaction_delay = float(bot_cfg["reaction_delay"])


func can_afford(bid: int) -> bool:
	return bid > 0 and bid <= silver


func reset_round_flags() -> void:
	passed_this_round = false


func record_round_bid(round_index: int, amount: int) -> void:
	var idx: int = round_index - 1
	if idx < 0 or idx >= round_bids.size():
		return
	round_bids[idx] = amount


func record_round_tactical_item(round_index: int, item_id: String) -> void:
	var idx: int = round_index - 1
	if idx < 0 or idx >= round_tactical_items.size():
		return
	round_tactical_items[idx] = item_id.strip_edges()


static func _title_for_legacy_character(char_id: String) -> String:
	match char_id:
		"ethan":
			return "精算师"
		"old_man":
			return "古董商"
		"weilong":
			return "抬价者"
		"raven":
			return "跟价客"
		_:
			return "收藏家"
