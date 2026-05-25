class_name OpenAuctionRules
extends RefCounted
## Open (English) auction board rules for BidKing demo.

class OpenAuctionBoard:
	var current_highest_bid: int = 0
	var current_leader_seat: int = -1
	var min_next_bid: int = 0
	var round_index: int = 0
	var raises_this_round: int = 0
	var window_active: bool = false
	var any_raise_this_window: bool = false


class RoundCloseResult:
	var auction_ended: bool = false
	var winner_seat: int = -1
	var winning_bid: int = 0
	var reason: String = ""


static func create_board(round_index: int, starting_bid: int, min_raise: int) -> OpenAuctionBoard:
	var board := OpenAuctionBoard.new()
	board.round_index = round_index
	board.current_highest_bid = 0
	board.current_leader_seat = -1
	board.min_next_bid = 0
	board.raises_this_round = 0
	board.window_active = false
	board.any_raise_this_window = false
	return board


static func can_raise(
	board: OpenAuctionBoard,
	seat: int,
	bid: int,
	silver: int,
	passed: bool,
	allow_closed_window: bool = false,
) -> Dictionary:
	if not board.window_active and not allow_closed_window:
		return {"ok": false, "reason": "窗口未开放"}
	if passed:
		return {"ok": false, "reason": "已放弃本轮"}
	if bid <= 0:
		return {"ok": false, "reason": "请输入有效出价"}
	if bid > silver:
		return {"ok": false, "reason": "金币不足，无法出价"}
	return {"ok": true, "reason": ""}


static func apply_raise(
	board: OpenAuctionBoard,
	seat: int,
	bid: int,
	min_raise: int,
) -> void:
	board.current_highest_bid = bid
	board.current_leader_seat = seat
	board.min_next_bid = 0
	board.raises_this_round += 1
	board.any_raise_this_window = true


static func check_quick_buy(board: OpenAuctionBoard, reserve_quick_buy: int) -> bool:
	if reserve_quick_buy <= 0:
		return false
	return board.current_highest_bid >= reserve_quick_buy


static func close_round(
	board: OpenAuctionBoard,
	max_rounds: int,
	reserve_quick_buy: int,
) -> RoundCloseResult:
	var res := RoundCloseResult.new()
	if check_quick_buy(board, reserve_quick_buy):
		res.auction_ended = true
		res.winner_seat = board.current_leader_seat
		res.winning_bid = board.current_highest_bid
		res.reason = "quick_buy"
		return res
	if board.round_index >= max_rounds:
		if board.current_highest_bid > 0:
			res.auction_ended = true
			res.winner_seat = board.current_leader_seat
			res.winning_bid = board.current_highest_bid
			res.reason = "max_rounds"
		else:
			res.auction_ended = true
			res.winner_seat = -1
			res.winning_bid = 0
			res.reason = "passed_all"
	return res
