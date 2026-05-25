class_name Settlement
extends RefCounted

class SettlementResult:
	var winner_seat: int = -1
	var winning_bid: int = 0
	var true_value: int = 0
	var profit_winner: int = 0
	var is_loss: bool = false
	var loss_amount: int = 0
	var welfare_each: int = 0
	var is_overbid: bool = false
	var overbid_amount: int = 0
	var compensation_each: int = 0
	var player_deltas: Array[int] = []


static func calculate(
	winner_seat: int,
	winning_bid: int,
	warehouse,
	player_count: int,
	opponent_dividend_rate: float = 1.0,
) -> SettlementResult:
	var res := SettlementResult.new()
	res.winner_seat = winner_seat
	res.winning_bid = winning_bid
	res.true_value = warehouse.true_total_value
	res.player_deltas.resize(player_count)
	for i in player_count:
		res.player_deltas[i] = 0
	res.profit_winner = res.true_value - res.winning_bid
	res.player_deltas[winner_seat] = -res.winning_bid
	if res.profit_winner < 0:
		res.is_loss = true
		res.loss_amount = -res.profit_winner
		var rate: float = clampf(opponent_dividend_rate, 0.0, 1.0)
		var opponent_count: int = maxi(player_count - 1, 1)
		var total_pool: int = int(floor(float(res.loss_amount) * rate))
		res.welfare_each = int(floor(float(total_pool) / float(opponent_count)))
		for i in player_count:
			if i != winner_seat:
				res.player_deltas[i] += res.welfare_each
	if res.winning_bid > res.true_value:
		res.is_overbid = true
		res.overbid_amount = res.winning_bid - res.true_value
		res.compensation_each = res.welfare_each
	return res
