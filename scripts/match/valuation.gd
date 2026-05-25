class_name Valuation
extends RefCounted

static func estimate_from_intel(intel: Dictionary, bias: float) -> Dictionary:
	var low: int = int(intel.get("known_total_low", 50_000))
	var high: int = int(intel.get("known_total_high", 500_000))
	var mid: int = int((low + high) * 0.5 * (1.0 + bias))
	if intel.has("purple_count"):
		mid += int(intel["purple_count"]) * 15_000
	if intel.has("gold_count"):
		mid += int(intel["gold_count"]) * 60_000
	if intel.has("red_count"):
		mid += int(intel["red_count"]) * 120_000
	if intel.get("red_or_gold_hint", false):
		mid += 80_000
	return {"low": low, "mid": mid, "high": high}


static func bid_for_speed_win(second_bid: int, round_index: int) -> int:
	if second_bid <= 0:
		return 0
	var ratio_idx: int = mini(round_index, GameConstants.SPEED_WIN_RATIOS.size() - 1)
	var ratio: float = GameConstants.SPEED_WIN_RATIOS[ratio_idx]
	return int(ceil(float(second_bid) * ratio))
