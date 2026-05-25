class_name AuctionRules
extends RefCounted

class RoundResult:
	var round_index: int = 0
	var bids: Array[int] = []
	var winner_seat: int = -1
	var speed_win: bool = false
	var speed_win_ratio: float = 0.0
	var auction_ended: bool = false
	var rank_hints: Array[String] = []


static func resolve_round(round_index: int, bids: Array[int]) -> RoundResult:
	var result := RoundResult.new()
	result.round_index = round_index
	result.bids = bids.duplicate()
	var sorted: Array = []
	for seat in bids.size():
		sorted.append({"seat": seat, "bid": bids[seat]})
	sorted.sort_custom(func(a, b): return a["bid"] > b["bid"])
	result.rank_hints = _build_rank_hints(bids, sorted)
	if sorted[0]["bid"] <= 0:
		return result
	var first: Dictionary = sorted[0]
	var second_bid: int = 0
	if sorted.size() > 1:
		second_bid = sorted[1]["bid"]
	if round_index < GameConstants.MAX_ROUNDS and second_bid > 0:
		var ratio_idx: int = mini(round_index, GameConstants.SPEED_WIN_RATIOS.size() - 1)
		var required: float = GameConstants.SPEED_WIN_RATIOS[ratio_idx]
		if float(first["bid"]) >= float(second_bid) * required:
			result.winner_seat = first["seat"]
			result.speed_win = true
			result.speed_win_ratio = required
			result.auction_ended = true
			return result
	if round_index >= GameConstants.MAX_ROUNDS:
		result.winner_seat = first["seat"]
		if sorted.size() > 1 and sorted[1]["bid"] == first["bid"]:
			result.auction_ended = false
		else:
			result.auction_ended = true
	return result


static func _build_rank_hints(bids: Array[int], sorted: Array) -> Array[String]:
	var hints: Array[String] = []
	hints.resize(bids.size())
	var max_bid: int = sorted[0]["bid"] if not sorted.is_empty() else 0
	var sum_bids: int = 0
	var count_positive: int = 0
	for b in bids:
		if b > 0:
			sum_bids += b
			count_positive += 1
	var avg: float = float(sum_bids) / float(maxi(count_positive, 1))
	for seat in bids.size():
		var b: int = bids[seat]
		if b <= 0:
			hints[seat] = "未出价"
		elif b == max_bid:
			hints[seat] = "领先"
		elif float(b) >= avg:
			hints[seat] = "高于多数人"
		else:
			hints[seat] = "低于多数人"
	return hints
