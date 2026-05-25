extends Node
## 4-seat open auction match; seat 0 can be human player.
const WarehouseScript = preload("res://scripts/match/warehouse.gd")
const PlayerStateScript = preload("res://scripts/match/player_state.gd")
const SettlementScript = preload("res://scripts/match/settlement.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")
const MatchConfigLoaderScript = preload("res://scripts/match/match_config_loader.gd")
const OpenAuctionRulesScript = preload("res://scripts/match/open_auction_rules.gd")
const OpenAuctionBotScript = preload("res://scripts/match/open_auction_bot.gd")
signal phase_changed(phase: int, round_index: int)
signal log_message(text: String)
signal open_board_updated(board)
signal bid_window_tick(seconds_left: float)
signal bid_window_waiting(done_count: int, total: int)
signal player_bid_result(ok: bool, reason: String)
signal match_forfeit_changed(forfeited: bool)
signal item_revealed(seat_visual: int, quality: int, value: int, index: int, total: int, item_name: String)
signal match_settled(result)
signal match_started()
signal round_closed(round_index: int)
signal skill_effects_updated(effects: Array)
@export var auto_start: bool = true
@export var match_seed: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _catalog = ItemCatalogScript.new()
var _cfg: Dictionary = {}
var _warehouse
var _players: Array = []
var _board
var _phase: int = GameConstants.MatchPhase.LOBBY
var _round_index: int = 0
var _winner_seat: int = -1
var _winning_bid: int = 0
var _running: bool = false
var _human_forfeited_match: bool = false
var _seat_bid_locked: Array[bool] = []
var _bot_schedules: Array[Dictionary] = []
var _round_seat_peak_bid: Dictionary = {}
func _ready() -> void:
	if not _catalog.load_all():
		push_error("ItemCatalog failed to load")
	if auto_start:
		call_deferred("start_match")
func start_match(seed_override: int = -1) -> void:
	if _running:
		return
	_running = true
	_human_forfeited_match = false
	match_forfeit_changed.emit(false)
	_cfg = MatchConfigLoaderScript.load_config()
	if seed_override >= 0:
		match_seed = seed_override
	else:
		match_seed = int(Time.get_unix_time_from_system()) % 1_000_000
	_rng.seed = match_seed
	_setup_players()
	_warehouse = WarehouseScript.new()
	_warehouse.generate_from_catalog(match_seed, _rng, _catalog, _cfg)
	_round_index = 0
	_winner_seat = -1
	_winning_bid = 0
	_board = null
	_log("=== 明拍开局 seed=%d 道具数=%d 估价概览(隐藏) ===" % [match_seed, _warehouse.items.size()])
	match_started.emit()
	_emit_skill_effects()
	_set_phase(GameConstants.MatchPhase.INFO)
	await get_tree().create_timer(0.4).timeout
	await _run_open_auction_loop()
	if _winner_seat >= 0:
		await _run_unbox()
		await _run_settlement()
	elif _winner_seat < 0 and _winning_bid == 0:
		_log(">> 流拍，无人成交")
	_set_phase(GameConstants.MatchPhase.MATCH_END)
	_running = false
func _setup_players() -> void:
	_players.clear()
	var seat_count: int = int(_cfg.get("seat_count", 4))
	var player_seat: int = int(_cfg.get("player_seat", 0))
	var bot_defs: Array[Dictionary] = [
		{"id": "ethan", "aggression": 0.25, "raise_tendency": 0.3, "valuation_bias": -0.08},
		{"id": "old_man", "aggression": 0.35, "raise_tendency": 0.35, "valuation_bias": 0.0},
		{"id": "weilong", "aggression": 0.7, "raise_tendency": 0.55, "valuation_bias": 0.12},
		{"id": "raven", "aggression": 0.5, "raise_tendency": 0.45, "valuation_bias": 0.05},
	]
	for i in seat_count:
		var cfg: Dictionary = {}
		if i == player_seat and player_seat >= 0:
			cfg = {
				"id": str(_cfg.get("player_character_id", "hero")),
				"is_human": true,
			}
		else:
			var bot_idx: int = i if i < player_seat else i - 1
			if player_seat < 0:
				bot_idx = i
			cfg = bot_defs[bot_idx % bot_defs.size()].duplicate()
			cfg["is_human"] = false
		var p = PlayerStateScript.new(i, cfg["id"], cfg)
		_players.append(p)
		var tag: String = " [主角]" if p.is_human else " [Bot]"
		_log("席位%d %s%s" % [i, p.display_name, tag])
func _run_open_auction_loop() -> void:
	var max_rounds: int = int(_cfg.get("max_rounds", GameConstants.MAX_ROUNDS))
	var min_raise: int = int(_cfg.get("min_raise", GameConstants.DEFAULT_MIN_RAISE))
	var starting_bid: int = int(_cfg.get("starting_bid", GameConstants.DEFAULT_STARTING_BID))
	var reserve_qb: int = int(_cfg.get("reserve_quick_buy", 0))
	while _round_index < max_rounds and _winner_seat < 0:
		_round_index += 1
		for p in _players:
			p.reset_round_flags()
		_log("--- 第 %d/%d 轮 明拍 ---" % [_round_index, max_rounds])
		_set_phase(GameConstants.MatchPhase.INFO)
		_emit_skill_effects()
		await get_tree().create_timer(GameConstants.ROUND_PAUSE_SECONDS * 0.5).timeout
		if _board == null or _round_index == 1:
			_board = OpenAuctionRulesScript.create_board(_round_index, starting_bid, min_raise)
		else:
			_board.round_index = _round_index
			_board.raises_this_round = 0
			_board.any_raise_this_window = false
			_board.window_active = false
		_set_phase(GameConstants.MatchPhase.OPEN_BOARD)
		_emit_board()
		_set_phase(GameConstants.MatchPhase.BID_WINDOW)
		_round_seat_peak_bid.clear()
		var closed: bool = await _run_bid_window(min_raise, reserve_qb)
		_finalize_round_bids()
		_emit_board()
		round_closed.emit(_round_index)
		if closed:
			break
		_set_phase(GameConstants.MatchPhase.BID_RESOLVE)
		var close_res = OpenAuctionRulesScript.close_round(_board, max_rounds, reserve_qb)
		if close_res.auction_ended:
			_winner_seat = close_res.winner_seat
			_winning_bid = close_res.winning_bid
			if _winner_seat >= 0:
				_log(">> %s 以 %s 成交 (%s)" % [
					_players[_winner_seat].display_name,
					_format_silver(_winning_bid),
					close_res.reason,
				])
			break
		await get_tree().create_timer(GameConstants.ROUND_PAUSE_SECONDS).timeout
	if _winner_seat < 0 and _board != null and _board.current_highest_bid > 0:
		_winner_seat = _board.current_leader_seat
		_winning_bid = _board.current_highest_bid
		_log(">> 末轮最高价成交: %s %s" % [
			_players[_winner_seat].display_name,
			_format_silver(_winning_bid),
		])
func _run_bid_window(min_raise: int, reserve_qb: int) -> bool:
	var window_sec: float = float(_cfg.get("bid_window_seconds", 10.0))
	_board.window_active = true
	_board.any_raise_this_window = false
	_reset_seat_locks()
	_prepare_bot_schedules(window_sec)
	if _human_forfeited_match:
		_lock_seat_bid(_human_seat(), 0, true)
	var elapsed: float = 0.0
	var step: float = 0.05
	while elapsed < window_sec:
		await get_tree().create_timer(step).timeout
		elapsed += step
		var left: float = maxf(0.0, window_sec - elapsed)
		bid_window_tick.emit(left)
		_emit_bid_waiting()
		_process_bot_schedules(elapsed, min_raise)
		if _all_seats_locked():
			break
	_force_unlocked_passes()
	_board.window_active = false
	_resolve_round_bids(min_raise)
	_emit_board()
	if OpenAuctionRulesScript.check_quick_buy(_board, reserve_qb):
		return true
	return false
func _reset_seat_locks() -> void:
	_seat_bid_locked.clear()
	_bot_schedules.clear()
	for _i in _players.size():
		_seat_bid_locked.append(false)
func _prepare_bot_schedules(window_sec: float) -> void:
	for p in _players:
		if p.is_human:
			continue
		var fire_at: float = _rng.randf_range(1.0, window_sec)
		_bot_schedules.append({
			"seat": p.seat_index,
			"fire_at": fire_at,
			"fired": false,
		})
func _process_bot_schedules(elapsed: float, min_raise: int) -> void:
	for sched in _bot_schedules:
		if sched.get("fired", false):
			continue
		if elapsed < float(sched.get("fire_at", 999.0)):
			continue
		sched["fired"] = true
		_bot_submit_bid(int(sched.get("seat", -1)), min_raise)
func _bot_submit_bid(seat: int, min_raise: int) -> void:
	if seat < 0 or seat >= _seat_bid_locked.size() or _seat_bid_locked[seat]:
		return
	var p = _players[seat]
	var amount: int = 0
	var passed: bool = true
	if OpenAuctionBotScript.should_raise(p, _warehouse, _board, _rng):
		amount = OpenAuctionBotScript.pick_bid(p, _board, _rng)
		var check: Dictionary = OpenAuctionRulesScript.can_raise(
			_board, seat, amount, p.silver, false,
		)
		if check.get("ok", false):
			passed = false
		else:
			amount = 0
	_lock_seat_bid(seat, amount, passed)
func _force_unlocked_passes() -> void:
	for p in _players:
		if not _seat_bid_locked[p.seat_index]:
			_lock_seat_bid(p.seat_index, 0, true)
func _all_seats_locked() -> bool:
	if _seat_bid_locked.is_empty():
		return false
	for locked in _seat_bid_locked:
		if not locked:
			return false
	return true
func _locked_count() -> int:
	var n: int = 0
	for locked in _seat_bid_locked:
		if locked:
			n += 1
	return n
func _emit_bid_waiting() -> void:
	bid_window_waiting.emit(_locked_count(), _players.size())
func _lock_seat_bid(seat: int, amount: int, passed: bool) -> void:
	if seat < 0 or seat >= _seat_bid_locked.size() or _seat_bid_locked[seat]:
		return
	_seat_bid_locked[seat] = true
	var p = _players[seat]
	if passed or amount <= 0:
		p.passed_this_round = true
		_round_seat_peak_bid[seat] = 0
	else:
		p.passed_this_round = false
		_round_seat_peak_bid[seat] = amount
	if p.is_human:
		if passed or amount <= 0:
			player_bid_result.emit(true, "本轮不出价，等待其他玩家")
		else:
			player_bid_result.emit(true, "出价已提交，等待其他玩家")
	_emit_bid_waiting()
func _resolve_round_bids(min_raise: int) -> void:
	var bids: Array[Dictionary] = []
	for p in _players:
		var seat: int = p.seat_index
		var amount: int = int(_round_seat_peak_bid.get(seat, 0))
		if amount > 0:
			bids.append({"seat": seat, "bid": amount})
	bids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("bid", 0)) < int(b.get("bid", 0))
	)
	for entry in bids:
		_try_apply_bid(int(entry.get("seat", -1)), int(entry.get("bid", 0)), min_raise)
func _try_apply_bid(seat: int, bid: int, min_raise: int) -> void:
	var p = _players[seat]
	var check = OpenAuctionRulesScript.can_raise(_board, seat, bid, p.silver, p.passed_this_round)
	if not check["ok"]:
		if p.is_human:
			player_bid_result.emit(false, check["reason"])
		return
	OpenAuctionRulesScript.apply_raise(_board, seat, bid, min_raise)
	p.current_bid = bid
	p.last_bid_hint = "领先" if _board.current_leader_seat == seat else "已出价"
	_log("  %s -> %s" % [p.display_name, _format_silver(bid)])
func player_submit_bid(amount: int) -> void:
	if _human_forfeited_match:
		player_bid_result.emit(false, "已弃权，无法出价")
		return
	if not _is_human_turn():
		player_bid_result.emit(false, "当前不可出价")
		return
	var seat: int = _human_seat()
	if _seat_bid_locked[seat]:
		player_bid_result.emit(false, "本轮已提交出价")
		return
	var check = OpenAuctionRulesScript.can_raise(
		_board, seat, amount, _players[seat].silver, false,
	)
	if not check["ok"]:
		player_bid_result.emit(false, check["reason"])
		return
	_lock_seat_bid(seat, amount, false)
func player_pass_round() -> void:
	if _human_forfeited_match:
		player_bid_result.emit(false, "已弃权")
		return
	if not _is_human_turn():
		return
	var seat: int = _human_seat()
	if _seat_bid_locked[seat]:
		player_bid_result.emit(false, "本轮已提交")
		return
	_lock_seat_bid(seat, 0, true)
	var p_pass = _players[seat]
	_log("  %s 本轮不出价" % p_pass.display_name)
func player_forfeit_match() -> void:
	if _human_forfeited_match:
		return
	_human_forfeited_match = true
	var seat: int = _human_seat()
	if seat >= 0:
		_log("  %s 弃权本局，进入观战" % _players[seat].display_name)
		if _board != null and _board.window_active and not _seat_bid_locked[seat]:
			_lock_seat_bid(seat, 0, true)
	match_forfeit_changed.emit(true)
	player_bid_result.emit(true, "已弃权，可观战至本局结束")
func is_human_forfeited() -> bool:
	return _human_forfeited_match
func _human_seat() -> int:
	return int(_cfg.get("player_seat", 0))
func _is_human_turn() -> bool:
	if _human_forfeited_match:
		return false
	if _board == null or not _board.window_active:
		return false
	var seat: int = _human_seat()
	if seat < 0 or seat >= _players.size():
		return false
	return _players[seat].is_human
func is_human_bid_locked() -> bool:
	var seat: int = _human_seat()
	if seat < 0 or seat >= _seat_bid_locked.size():
		return false
	return _seat_bid_locked[seat]
func _emit_board() -> void:
	open_board_updated.emit(_board)
	for p in _players:
		if _board == null:
			continue
		if _board.current_leader_seat == p.seat_index:
			p.current_bid = _board.current_highest_bid
			p.last_bid_hint = "领先"
		elif p.current_bid > 0 and p.seat_index != _board.current_leader_seat:
			p.last_bid_hint = "出局"
func _run_unbox() -> void:
	_set_phase(GameConstants.MatchPhase.UNBOX)
	_warehouse.revealed_count = 0
	_log("--- 开箱 ---")
	for idx in _warehouse.get_reveal_order().size():
		var item = _warehouse.reveal_next()
		if item == null:
			break
		item_revealed.emit(
			_winner_seat,
			item.quality,
			item.value,
			idx + 1,
			_warehouse.items.size(),
			item.item_name,
		)
		_log("  %d/%d %s [%s] %s" % [
			idx + 1,
			_warehouse.items.size(),
			item.item_name,
			GameConstants.QUALITY_NAMES[item.quality],
			_format_silver(item.value),
		])
		await get_tree().create_timer(GameConstants.UNBOX_ITEM_DELAY).timeout
	_log("真实总值: %s" % _format_silver(_warehouse.true_total_value))
func _run_settlement() -> void:
	_set_phase(GameConstants.MatchPhase.SETTLEMENT)
	var result = SettlementScript.calculate(_winner_seat, _winning_bid, _warehouse, _players.size())
	for i in _players.size():
		_players[i].net_profit_this_match = result.player_deltas[i]
		if i == _winner_seat:
			_players[i].won_auction = true
		if result.player_deltas[i] != 0:
			_log("  %s 净收益 %s%s" % [
				_players[i].display_name,
				"+" if result.player_deltas[i] >= 0 else "",
				_format_silver(result.player_deltas[i]),
			])
	if result.is_overbid:
		_log("  爆仓补偿 每人 %s" % _format_silver(result.compensation_each))
	match_settled.emit(result)
func _set_phase(phase: int) -> void:
	_phase = phase
	phase_changed.emit(phase, _round_index)
func _log(text: String) -> void:
	log_message.emit(text)
func get_players() -> Array:
	return _players
func get_warehouse():
	return _warehouse
func get_board():
	return _board
func get_phase() -> int:
	return _phase
func get_round_index() -> int:
	return _round_index
func get_catalog():
	return _catalog
func get_estimated_min_price() -> int:
	if _warehouse == null:
		return 0
	var intel: Dictionary = _warehouse.get_intel_summary(0, _round_index)
	return int(intel.get("known_total_low", 0))
func get_skill_effects() -> Array:
	return _build_skill_effects()
func _finalize_round_bids() -> void:
	for p in _players:
		var amount: int = int(_round_seat_peak_bid.get(p.seat_index, 0))
		p.record_round_bid(_round_index, amount)
func _emit_skill_effects() -> void:
	skill_effects_updated.emit(_build_skill_effects())
func _build_skill_effects() -> Array:
	var effects: Array = []
	if _warehouse == null:
		return effects
	effects.append({
		"title": "潮牌仓库：竞拍信息",
		"body": "本局仓库共 %d 件收藏品（格位 %dx%d）" % [
			_warehouse.items.size(), _warehouse.grid_w, _warehouse.grid_h,
		],
		"icon_kind": "warehouse",
	})
	for p in _players:
		if p.is_human or p.seat_index == 0:
			effects.append({
				"title": "%s：情报技能" % p.display_name,
				"body": "预估价值区间 %s ~ %s" % [
					_format_silver(get_estimated_min_price()),
					_format_silver(int(get_estimated_min_price() * 1.8)),
				],
				"icon_kind": "character",
				"seat": p.seat_index,
			})
			break
	var intel: Dictionary = _warehouse.get_intel_summary(0, maxi(_round_index, 1))
	if intel.get("red_or_gold_hint", false):
		effects.append({
			"title": "稀有提示",
			"body": "探测到金色或红色品质藏品信号",
			"icon_kind": "hint",
		})
	return effects
static func _format_silver(amount: int) -> String:
	if abs(amount) >= 1_000_000:
		return "%.2fM" % (float(amount) / 1_000_000.0)
	if abs(amount) >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)

