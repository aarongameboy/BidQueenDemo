extends Node
## 玩家排行榜统计（持久化），供排行榜展示与上榜

const SAVE_PATH := "user://player_leaderboard.json"
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")

var total_profit: int = 0
var total_loss: int = 0
var red_collect_count: int = 0
var single_profit: int = 0
var single_loss: int = 0
var match_count: int = 0
var win_count: int = 0
var bid_count: int = 0
var consign_profit: int = 0


func _ready() -> void:
	RosterConfigScript.ensure_loaded()
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	total_profit = int(parsed.get("total_profit", 0))
	total_loss = int(parsed.get("total_loss", 0))
	red_collect_count = int(parsed.get("red_collect_count", 0))
	single_profit = int(parsed.get("single_profit", 0))
	single_loss = int(parsed.get("single_loss", 0))
	match_count = int(parsed.get("match_count", 0))
	win_count = int(parsed.get("win_count", 0))
	bid_count = int(parsed.get("bid_count", 0))
	consign_profit = int(parsed.get("consign_profit", 0))


func save_data() -> void:
	var data: Dictionary = {
		"total_profit": total_profit,
		"total_loss": total_loss,
		"red_collect_count": red_collect_count,
		"single_profit": single_profit,
		"single_loss": single_loss,
		"match_count": match_count,
		"win_count": win_count,
		"bid_count": bid_count,
		"consign_profit": consign_profit,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func record_match(human_won: bool, profit_delta: int, winning_bid: int, red_items: int = 0) -> void:
	match_count += 1
	bid_count += 1
	if human_won:
		win_count += 1
	if profit_delta > 0:
		total_profit += profit_delta
		single_profit = maxi(single_profit, profit_delta)
		consign_profit += int(profit_delta * 0.15)
	elif profit_delta < 0:
		var loss: int = absi(profit_delta)
		total_loss += loss
		single_loss = maxi(single_loss, loss)
	if red_items > 0:
		red_collect_count += red_items
	elif human_won and winning_bid > 0:
		red_collect_count += 1
	save_data()


func get_value(category_id: String, period: String) -> float:
	var scale: float = _period_scale(period)
	match category_id:
		"total_profit":
			return float(total_profit) * scale
		"total_loss":
			return float(total_loss) * scale
		"red_collect_count":
			return float(red_collect_count) * _count_scale(period)
		"single_profit":
			return float(single_profit) * scale
		"single_loss":
			return float(single_loss) * scale
		"total_profit_ratio":
			return _ratio_percent(total_profit, total_loss) * _ratio_period_scale(period)
		"bid_spread_ratio":
			return clampf(8.0 + float(bid_count) * 1.2, 5.0, 45.0) * _ratio_period_scale(period)
		"bid_success_rate":
			if bid_count <= 0:
				return 0.0
			return float(win_count) / float(bid_count) * 100.0
		"consign_profit":
			return float(consign_profit) * scale
		_:
			return 0.0


static func _period_scale(period: String) -> float:
	match period:
		"weekly":
			return 4.0
		"monthly":
			return 14.0
		_:
			return 1.0


static func _count_scale(period: String) -> float:
	match period:
		"weekly":
			return 2.5
		"monthly":
			return 8.0
		_:
			return 1.0


static func _ratio_period_scale(period: String) -> float:
	match period:
		"weekly":
			return 1.05
		"monthly":
			return 1.12
		_:
			return 1.0


static func _ratio_percent(gain: int, loss: int) -> float:
	var g: float = float(maxi(0, gain))
	var l: float = float(maxi(0, loss))
	if g <= 0.0 and l <= 0.0:
		return 0.0
	if l <= 0.0:
		return 100.0
	return clampf(g / (g + l) * 100.0, 0.0, 100.0)
