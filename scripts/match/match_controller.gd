extends Node
## 4-seat open auction match; seat 0 can be human player.

const WarehouseScript = preload("res://scripts/match/warehouse.gd")
const PlayerStateScript = preload("res://scripts/match/player_state.gd")
const SettlementScript = preload("res://scripts/match/settlement.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")
const MatchConfigLoaderScript = preload("res://scripts/match/match_config_loader.gd")
const OpenAuctionRulesScript = preload("res://scripts/match/open_auction_rules.gd")
const OpenAuctionBotScript = preload("res://scripts/match/open_auction_bot.gd")
const MatchIntelScript = preload("res://scripts/match/match_intel.gd")
const CharacterSkillsScript = preload("res://scripts/match/character_skills.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const DefaultBotsConfigScript = preload("res://scripts/data/default_bots_config.gd")
const MapModeConfigScript = preload("res://scripts/data/map_mode_config.gd")
const MatchHeritageConfigScript = preload("res://scripts/data/match_heritage_config.gd")
const TacticalItemEffectsScript = preload("res://scripts/match/tactical_item_effects.gd")
const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")

signal phase_changed(phase: int, round_index: int)
signal cinematic_requested(payload: Dictionary)
signal log_message(text: String)
signal open_board_updated(board)
signal bid_window_tick(seconds_left: float)
signal bid_window_waiting(done_count: int, total: int)
signal player_bid_result(ok: bool, reason: String)
signal match_forfeit_changed(forfeited: bool)
signal item_revealed(seat_visual: int, quality: int, value: int, index: int, total: int, item_name: String)
signal settlement_tick(tick: Dictionary)
signal settlement_ready(result)
signal match_settled(result)
signal match_started()
signal round_closed(round_index: int)
signal skill_effects_updated(effects: Array)
signal skill_effects_reset()
signal skill_effect_appended(effect: Dictionary)
signal intel_items_revealed(indices: Array)
signal intel_outlines_revealed(indices: Array)
signal quality_size_revealed(indices: Array)
signal bid_window_finished(round_index: int)
signal tactical_state_changed(slots: Array)
signal tactical_item_used(slot_index: int, ok: bool, reason: String)

@export var auto_start: bool = false
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
var _seat_bid_locked: Dictionary = {}
var _bot_schedules: Array[Dictionary] = []
var _round_seat_peak_bid: Dictionary = {}
var _round_intel: Dictionary = {}
var _round_intel_history: Array[Dictionary] = []
## 已向玩家 UI 展示情报/技能效果的最大轮次（0=仅开局前）
var _skill_effects_ui_round: int = 0
var _round_skill_effect_history: Array[Dictionary] = []
var _match_start_skill_effects: Array[Dictionary] = []
var _settlement_claimed: bool = false
var _pending_settlement_result = null
var _settlement_rewards_applied: bool = false
## 跨局保留主角银币（-1 表示使用开局默认值）
var _session_human_silver: int = -1
var _bid_recording_round: int = 0
## 每次 restart 递增；与 start_match 内捕获的代次不一致时表示旧协程应停止（避免 _board 已清空仍跑 Bot）
var _match_run_generation: int = 0
var _pending_map_id: String = ""
var _pending_mode_id: String = ""
var _pending_mode_cfg: Dictionary = {}
var _cinematic_waiting: bool = false
var _practice_mode: bool = false
var _room_peer_seats: Dictionary = {}
var _lockstep_network: bool = false
var _client_sync_queue: Array = []
var _client_sync_busy: bool = false
var _client_waiting_bid_end: bool = false
var _tactical_match_slots: Array[Dictionary] = []
var _tactical_used_this_round: bool = false
var _tactical_catalog: TacticalItemCatalog = null


func _ready() -> void:
	add_to_group("match_controller")
	if not _catalog.load_all():
		push_error("ItemCatalog failed to load")
	MapModeConfigScript.load_all()
	call_deferred("_init_carry_from_portfolio")
	if auto_start:
		call_deferred("start_match")


func is_match_running() -> bool:
	return _running


func restart_match(seed_override: int = -1) -> void:
	_match_run_generation += 1
	_running = false
	_players.clear()
	_pending_map_id = ""
	_pending_mode_id = ""
	_pending_mode_cfg.clear()
	if seed_override >= 0:
		match_seed = seed_override
	_init_carry_from_portfolio()


func get_human_silver_preview() -> int:
	return _resolve_carry_human_silver()


func is_practice_mode() -> bool:
	return _practice_mode


func set_practice_mode(enabled: bool) -> void:
	_practice_mode = enabled


func configure_room_network(peer_seats: Dictionary, lockstep: bool = true) -> void:
	_room_peer_seats = peer_seats.duplicate()
	_lockstep_network = lockstep
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net and not net.match_sync_received.is_connected(_on_room_match_sync_received):
		net.match_sync_received.connect(_on_room_match_sync_received)


func clear_room_network() -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net and net.match_sync_received.is_connected(_on_room_match_sync_received):
		net.match_sync_received.disconnect(_on_room_match_sync_received)
	_room_peer_seats.clear()
	_lockstep_network = false
	_client_sync_queue.clear()
	_client_sync_busy = false


func _is_room_network_host() -> bool:
	return _lockstep_network and multiplayer.multiplayer_peer != null and multiplayer.is_server()


func _is_room_network_client() -> bool:
	return _lockstep_network and multiplayer.multiplayer_peer != null and not multiplayer.is_server()


func _broadcast_room_sync(step: String, data: Dictionary = {}) -> void:
	if not _is_room_network_host():
		return
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net:
		net.broadcast_match_sync(step, data)


func _on_room_match_sync_received(step: String, data: Dictionary) -> void:
	if not _is_room_network_client():
		return
	_client_sync_queue.append({"step": step, "data": data})
	if not _client_sync_busy:
		_process_client_sync_queue()


func _process_client_sync_queue() -> void:
	_client_sync_busy = true
	while not _client_sync_queue.is_empty():
		var item: Dictionary = _client_sync_queue.pop_front()
		await _apply_room_sync_step(str(item.get("step", "")), item.get("data", {}))
	_client_sync_busy = false


func _board_to_dict() -> Dictionary:
	if _board == null:
		return {}
	return {
		"current_highest_bid": _board.current_highest_bid,
		"current_leader_seat": _board.current_leader_seat,
		"min_next_bid": _board.min_next_bid,
		"round_index": _board.round_index,
		"raises_this_round": _board.raises_this_round,
		"window_active": _board.window_active,
		"any_raise_this_window": _board.any_raise_this_window,
	}


func _board_from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	if _board == null:
		_board = OpenAuctionRulesScript.OpenAuctionBoard.new()
	_board.current_highest_bid = int(d.get("current_highest_bid", 0))
	_board.current_leader_seat = int(d.get("current_leader_seat", -1))
	_board.min_next_bid = int(d.get("min_next_bid", 0))
	_board.round_index = int(d.get("round_index", _round_index))
	_board.raises_this_round = int(d.get("raises_this_round", 0))
	_board.window_active = bool(d.get("window_active", false))
	_board.any_raise_this_window = bool(d.get("any_raise_this_window", false))


func _peak_bids_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for seat in _round_seat_peak_bid.keys():
		out[str(seat)] = int(_round_seat_peak_bid[seat])
	return out


func _peak_bids_from_dict(d: Dictionary) -> void:
	_round_seat_peak_bid.clear()
	for key in d.keys():
		_round_seat_peak_bid[int(key)] = int(d[key])


func _apply_room_sync_step(step: String, data: Dictionary) -> void:
	var run_gen: int = int(data.get("run_gen", _match_run_generation))
	if run_gen != _match_run_generation:
		return
	match step:
		"present_round_intel":
			_round_index = int(data.get("round_index", _round_index))
			var intel: Dictionary = data.get("intel", {})
			var skill_by_seat: Dictionary = data.get("skill_by_seat", {})
			if skill_by_seat.is_empty() and data.has("skill_picked"):
				skill_by_seat = {str(_human_seat()): data.get("skill_picked", {})}
			if not intel.is_empty():
				_append_round_intel_history(intel)
			await _present_round_intel_with_teaser(run_gen, intel, skill_by_seat)
		"phase":
			_round_index = int(data.get("round_index", _round_index))
			_set_phase(int(data.get("phase", GameConstants.MatchPhase.INFO)))
		"board":
			_board_from_dict(data.get("board", {}))
			_emit_board()
		"bid_window_start":
			_prepare_client_bid_window(data)
			_run_bid_window_client_task(run_gen, data)
		"bid_waiting":
			bid_window_waiting.emit(
				int(data.get("done", 0)),
				int(data.get("total", 0)),
			)
		"bid_window_end":
			_apply_bid_window_end_sync(data)
		"after_bid_resolve":
			await _apply_after_bid_resolve_sync(run_gen, data)
		"round_closed":
			round_closed.emit(int(data.get("round_index", _round_index)))
		"run_unbox":
			await _run_unbox_and_settlement(run_gen)
		"match_finished":
			_set_phase(GameConstants.MatchPhase.MATCH_END)
			_running = false
		_:
			pass


func _apply_forfeited_seats_from_sync(data: Dictionary) -> void:
	var seats: Array = data.get("forfeited_seats", [])
	for seat_v in seats:
		var seat: int = int(seat_v)
		var p = _player_by_seat(seat)
		if p == null:
			continue
		if p.forfeited_match:
			continue
		p.forfeited_match = true
		_round_seat_peak_bid[seat] = 0
		p.current_bid = 0
		p.passed_this_round = true
		if seat == _human_seat():
			_human_forfeited_match = true
			match_forfeit_changed.emit(true)


func _forfeited_seats_list() -> Array:
	var seats: Array = []
	for p in _players:
		if p.forfeited_match:
			seats.append(p.seat_index)
	return seats


func _apply_bid_window_end_sync(data: Dictionary) -> void:
	_client_waiting_bid_end = false
	_apply_forfeited_seats_from_sync(data)
	_board_from_dict(data.get("board", {}))
	_peak_bids_from_dict(data.get("peak_bids", {}))
	if _board != null:
		_board.window_active = false
	_emit_board()
	bid_window_finished.emit(int(data.get("round_index", _bid_recording_round)))


func _apply_after_bid_resolve_sync(run_gen: int, data: Dictionary) -> void:
	var window_end: String = str(data.get("window_end", ""))
	var instant_kill: bool = bool(data.get("instant_kill", false))
	var match_ended: bool = bool(data.get("match_ended", false))
	_winner_seat = int(data.get("winner_seat", -1))
	_winning_bid = int(data.get("winning_bid", 0))
	if match_ended:
		var payloads: Array = data.get("cinematic_payloads", [])
		if payloads.is_empty():
			await _play_cinematic(run_gen, _build_round_reveal_payload(instant_kill))
		else:
			await _play_cinematic_sequence(run_gen, payloads)
	else:
		await _play_cinematic(run_gen, _build_round_reveal_payload(instant_kill))


func _prepare_client_bid_window(data: Dictionary) -> void:
	_bid_recording_round = int(data.get("round_index", _round_index))
	if _board != null:
		_board.window_active = true
	_reset_seat_locks()
	for p in _players:
		if p.forfeited_match:
			_lock_seat_bid(p.seat_index, 0, true, true)


func _run_bid_window_client_task(run_gen: int, data: Dictionary) -> void:
	await _run_bid_window_client(run_gen, data)


func _run_bid_window_client(run_gen: int, data: Dictionary) -> void:
	if _board == null:
		return
	var window_sec: float = float(data.get("window_sec", 15.0))
	_client_waiting_bid_end = true
	var elapsed: float = 0.0
	var step: float = 0.05
	while _client_waiting_bid_end and elapsed < window_sec:
		await get_tree().create_timer(step).timeout
		if run_gen != _match_run_generation:
			_client_waiting_bid_end = false
			if _board != null:
				_board.window_active = false
			return
		elapsed += step
		bid_window_tick.emit(maxf(0.0, window_sec - elapsed))
		_emit_bid_waiting()
	bid_window_tick.emit(0.0)


func apply_network_bid_lock(seat: int, amount: int, passed: bool) -> void:
	_lock_seat_bid(seat, amount, passed, true)


func _player_by_seat(seat: int):
	for p in _players:
		if p.seat_index == seat:
			return p
	return null


func _is_seat_locked(seat: int) -> bool:
	return bool(_seat_bid_locked.get(seat, false))


func apply_network_forfeit(seat: int) -> void:
	var p = _player_by_seat(seat)
	if p == null:
		return
	if p.forfeited_match:
		if _board != null and _board.window_active and not _is_seat_locked(seat):
			_lock_seat_bid(seat, 0, true, true)
		return
	p.forfeited_match = true
	_round_seat_peak_bid[seat] = 0
	p.current_bid = 0
	p.passed_this_round = true
	_log("  %s 弃权本局，进入观战" % p.display_name)
	if seat == _human_seat():
		_human_forfeited_match = true
		match_forfeit_changed.emit(true)
		player_bid_result.emit(true, "已弃权，可观战至本局结束")
	if _board != null and _board.window_active and not _is_seat_locked(seat):
		_lock_seat_bid(seat, 0, true, true)
	else:
		_emit_bid_waiting()


func validate_match_selection(map_id: String, mode_id: String) -> Dictionary:
	if _practice_mode:
		var mode_p: Dictionary = MapModeConfigScript.get_mode(map_id, mode_id)
		if mode_p.is_empty():
			return {"ok": false, "reason": "无效的地图或模式"}
		return {"ok": true, "reason": ""}
	var mode: Dictionary = MapModeConfigScript.get_mode(map_id, mode_id)
	if mode.is_empty():
		return {"ok": false, "reason": "无效的地图或模式"}
	var silver: int = _resolve_carry_human_silver()
	var threshold: int = int(mode.get("entry_threshold", 0))
	if silver < threshold:
		return {
			"ok": false,
			"reason": "未达到进入门槛（需要 %s）" % _format_silver(threshold),
		}
	var ticket: int = int(mode.get("ticket", 0))
	if silver < ticket:
		return {"ok": false, "reason": "银币不足支付门票（%s）" % _format_silver(ticket)}
	return {"ok": true, "reason": ""}


func set_match_selection(map_id: String, mode_id: String, practice_override: int = -1) -> bool:
	var check: Dictionary = validate_match_selection(map_id, mode_id)
	if not check.get("ok", false):
		return false
	if practice_override >= 0:
		_practice_mode = practice_override != 0
	_pending_map_id = map_id
	_pending_mode_id = mode_id
	_pending_mode_cfg = MapModeConfigScript.get_mode(map_id, mode_id)
	return true


func prepare_tactical_loadout() -> Dictionary:
	_tactical_match_slots.clear()
	_tactical_used_this_round = false
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical == null:
		tactical_state_changed.emit(get_tactical_slots())
		return {"ok": true}
	if tactical.has_method("sanitize_loadout_for_match"):
		tactical.sanitize_loadout_for_match()
	var check: Dictionary = tactical.validate_loadout_for_match()
	if not check.get("ok", false):
		return check
	var max_slots: int = tactical.get_catalog().get_max_loadout_slots()
	for i in mini(tactical.loadout.size(), max_slots):
		var item_id: String = str(tactical.loadout[i]).strip_edges()
		if item_id.is_empty():
			continue
		_tactical_match_slots.append({
			"item_id": item_id,
			"used": false,
			"loadout_index": i,
		})
	tactical_state_changed.emit(get_tactical_slots())
	return {"ok": true}


func get_tactical_slots() -> Array:
	var out: Array = []
	for slot in _tactical_match_slots:
		out.append(slot.duplicate())
	return out


## 对局结束后把未使用的战术道具写回口袋栏（防止开局误清 loadout）
func finalize_tactical_loadout_after_match() -> void:
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	for slot in _tactical_match_slots:
		if bool(slot.get("used", false)):
			continue
		if tactical == null:
			continue
		var loadout_idx: int = int(slot.get("loadout_index", -1))
		var item_id: String = str(slot.get("item_id", "")).strip_edges()
		if loadout_idx < 0 or item_id.is_empty():
			continue
		if loadout_idx >= tactical.loadout.size():
			continue
		if str(tactical.loadout[loadout_idx]).strip_edges().is_empty():
			tactical.set_loadout_slot(loadout_idx, item_id)
	_tactical_match_slots.clear()
	_tactical_used_this_round = false
	tactical_state_changed.emit(get_tactical_slots())


func can_use_tactical_item() -> bool:
	if _tactical_used_this_round:
		return false
	if _phase != GameConstants.MatchPhase.BID_WINDOW:
		return false
	if _board == null or not _board.window_active:
		return false
	if is_human_bid_locked():
		return false
	for slot in _tactical_match_slots:
		if not bool(slot.get("used", false)):
			return true
	return false


func request_use_tactical_item(slot_index: int) -> void:
	if is_human_bid_locked():
		tactical_item_used.emit(slot_index, false, "本轮已出价，无法再使用战术道具")
		return
	if not can_use_tactical_item():
		tactical_item_used.emit(slot_index, false, "本轮已使用过战术道具或不在出价窗口")
		return
	if slot_index < 0 or slot_index >= _tactical_match_slots.size():
		tactical_item_used.emit(slot_index, false, "无效槽位")
		return
	var slot: Dictionary = _tactical_match_slots[slot_index]
	if bool(slot.get("used", false)):
		tactical_item_used.emit(slot_index, false, "该道具本局已使用")
		return
	var item_id: String = str(slot.get("item_id", ""))
	if item_id.is_empty():
		tactical_item_used.emit(slot_index, false, "空槽位")
		return
	if _tactical_catalog == null:
		_tactical_catalog = TacticalCatalogScript.new()
		_tactical_catalog.load_all()
	var item_def: Dictionary = _tactical_catalog.get_item(item_id)
	if item_def.is_empty():
		tactical_item_used.emit(slot_index, false, "道具配置缺失")
		return
	_tactical_apply_item(slot_index, item_def)


func _tactical_apply_item(slot_index: int, item_def: Dictionary) -> void:
	var run_gen: int = _match_run_generation
	var effect: Dictionary = TacticalItemEffectsScript.build_effect(
		item_def,
		_warehouse,
		_rng,
		_round_index,
	)
	_tactical_match_slots[slot_index]["used"] = true
	_tactical_used_this_round = true
	var player = _player_by_seat(_human_seat())
	if player != null:
		player.record_round_tactical_item(_round_index, str(item_def.get("id", "")))
	var slot: Dictionary = _tactical_match_slots[slot_index]
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical != null:
		var loadout_idx: int = int(slot.get("loadout_index", -1))
		tactical.consume_on_use(str(item_def.get("id", "")), loadout_idx)
	tactical_state_changed.emit(get_tactical_slots())
	var entry: Dictionary = _enrich_effect_round_meta(effect)
	_append_round_skill_effect_history(entry)
	skill_effect_appended.emit(entry)
	await get_tree().create_timer(GameConstants.INTEL_CARD_DELAY).timeout
	if run_gen != _match_run_generation:
		return
	await _apply_single_effect_reveals(run_gen, effect)
	skill_effects_updated.emit(_build_skill_effects())
	tactical_item_used.emit(slot_index, true, "")
	_log("[战术道具] %s" % str(effect.get("body", item_def.get("name", ""))))


func start_match(seed_override: int = -1) -> void:
	if _running:
		return
	_running = true
	var run_gen: int = _match_run_generation
	_human_forfeited_match = false
	match_forfeit_changed.emit(false)
	_cfg = MatchConfigLoaderScript.load_config()
	var roster: Node = get_node_or_null("/root/PlayerRoster")
	if roster != null:
		_cfg["player_character_id"] = str(roster.selected_character_id)
	if seed_override >= 0:
		match_seed = seed_override
	else:
		match_seed = int(Time.get_unix_time_from_system()) % 1_000_000
	_rng.seed = match_seed
	var carry_silver: int = _resolve_carry_human_silver()
	_setup_players()
	_apply_carry_human_silver(carry_silver)
	if _pending_mode_cfg.is_empty():
		push_warning("MatchController: 未选择地图模式，使用默认琥珀商馆·标准")
		_pending_map_id = "dam"
		_pending_mode_id = "normal"
		_pending_mode_cfg = MapModeConfigScript.get_mode(_pending_map_id, _pending_mode_id)
	_apply_map_mode_to_cfg(_pending_mode_cfg)
	_apply_bot_bid_cap()
	_deduct_match_ticket()
	for p in _players:
		p.forfeited_match = false
	_warehouse = WarehouseScript.new()
	_warehouse.generate_from_catalog(match_seed, _rng, _catalog, _cfg)
	_round_intel_history.clear()
	_round_skill_effect_history.clear()
	_match_start_skill_effects.clear()
	_skill_effects_ui_round = 0
	_round_index = 0
	_winner_seat = -1
	_winning_bid = 0
	_board = null
	_pending_settlement_result = null
	_settlement_rewards_applied = false
	_settlement_claimed = false
	_log("=== 明拍开局 %s·%s seed=%d 道具数=%d ===" % [
		_cfg.get("map_name", ""),
		_cfg.get("mode_name", ""),
		match_seed,
		_warehouse.items.size(),
	])
	match_started.emit()
	_set_phase(GameConstants.MatchPhase.INFO)
	await _present_match_start_intro(run_gen)
	if run_gen != _match_run_generation:
		return
	if _is_room_network_client():
		return
	await _run_open_auction_loop(run_gen)
	if run_gen != _match_run_generation:
		return
	if _winner_seat < 0 and _board != null and _board.current_highest_bid > 0:
		_winner_seat = _board.current_leader_seat
		_winning_bid = _board.current_highest_bid
	if _winner_seat >= 0:
		_log(">> 准备结算 winner=%d bid=%s" % [_winner_seat, _format_silver(_winning_bid)])
		if _warehouse != null and _warehouse.items.size() > 0:
			_broadcast_room_sync("run_unbox", {"run_gen": run_gen})
			await _run_unbox_and_settlement(run_gen)
			if run_gen != _match_run_generation:
				return
		else:
			_log(">> 成交但仓库无道具，跳过开箱")
	elif _winning_bid == 0:
		_log(">> 流拍，无人成交")
	_broadcast_room_sync("match_finished", {"run_gen": run_gen})
	_set_phase(GameConstants.MatchPhase.MATCH_END)
	_running = false


func _force_match_winner(reason: String) -> void:
	if _board == null:
		return
	if _board.current_highest_bid > 0 and _board.current_leader_seat >= 0:
		_winner_seat = _board.current_leader_seat
		_winning_bid = _board.current_highest_bid
		_log(">> %s 以 %s 成交 (%s)" % [
			_players[_winner_seat].display_name,
			_format_silver(_winning_bid),
			reason,
		])


func _init_carry_from_portfolio() -> void:
	if _practice_mode:
		_session_human_silver = GameConstants.PRACTICE_MATCH_SILVER
		return
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio == null:
		return
	_session_human_silver = maxi(0, int(portfolio.total_assets))


func _resolve_carry_human_silver() -> int:
	if _practice_mode and not _running:
		return GameConstants.PRACTICE_MATCH_SILVER
	if _running:
		for p in _players:
			if p.is_human:
				return maxi(0, p.silver)
	if _session_human_silver >= 0:
		return _session_human_silver
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio != null:
		return maxi(0, int(portfolio.total_assets))
	return GameConstants.STARTING_SILVER


func _apply_carry_human_silver(amount: int) -> void:
	var silver: int = maxi(0, amount)
	for p in _players:
		if p.is_human:
			p.silver = silver
			_session_human_silver = silver
			return


func _sync_session_human_silver() -> void:
	for p in _players:
		if p.is_human:
			_session_human_silver = maxi(0, p.silver)
			return


func _setup_players() -> void:
	_players.clear()
	RosterConfigScript.ensure_loaded()
	if not _room_peer_seats.is_empty():
		_setup_players_room()
		return
	var seat_count: int = int(_cfg.get("seat_count", 4))
	var player_seat: int = int(_cfg.get("player_seat", 0))
	var human_char: String = str(_cfg.get("player_character_id", RosterConfigScript.get_default_id()))
	if not RosterConfigScript.has_character(human_char):
		human_char = RosterConfigScript.get_default_id()
	var all_chars: Array[String] = []
	for cid in RosterConfigScript.all_ids():
		if cid != human_char:
			all_chars.append(cid)
	if all_chars.is_empty():
		all_chars.append(human_char)
	DefaultBotsConfigScript.ensure_loaded()
	var open_defaults: Dictionary = DefaultBotsConfigScript.get_open_auction_defaults()
	for i in seat_count:
		var cfg: Dictionary = {}
		if i == player_seat and player_seat >= 0:
			cfg = RosterConfigScript.get_bot_cfg(human_char).duplicate()
			cfg["is_human"] = true
		else:
			var bot_entry: Dictionary = DefaultBotsConfigScript.get_bot_for_seat(i)
			var bot_char: String = str(bot_entry.get("character_id", ""))
			if bot_char.is_empty() or not RosterConfigScript.has_character(bot_char):
				bot_char = all_chars[_rng.randi_range(0, all_chars.size() - 1)]
			cfg = RosterConfigScript.get_bot_cfg(bot_char).duplicate()
			for key in ["aggression", "bluff_rate", "valuation_bias", "raise_tendency", "max_chase_ratio", "reaction_delay"]:
				if bot_entry.has(key):
					cfg[key] = bot_entry[key]
				elif open_defaults.has(key):
					cfg[key] = open_defaults[key]
			cfg["is_human"] = false
		var p = PlayerStateScript.new(i, str(cfg.get("id", human_char)), cfg)
		_players.append(p)
		var tag: String = " [你]" if p.is_human else " [对手]"
		_log("席位%d %s · %s%s" % [i, p.display_name, p.character_title, tag])


func _setup_players_room() -> void:
	var local_seat: int = int(_cfg.get("player_seat", 0))
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net:
		local_seat = net.get_local_seat()
	_cfg["player_seat"] = local_seat
	var human_char: String = str(_cfg.get("player_character_id", RosterConfigScript.get_default_id()))
	if not RosterConfigScript.has_character(human_char):
		human_char = RosterConfigScript.get_default_id()
	var occupied_seats: Array[int] = []
	for pid in _room_peer_seats.keys():
		var seat_i: int = int(_room_peer_seats[pid])
		if seat_i not in occupied_seats:
			occupied_seats.append(seat_i)
	occupied_seats.sort()
	_cfg["seat_count"] = occupied_seats.size()
	for i in occupied_seats:
		var is_local_human: bool = i == local_seat
		var seat_char: String = human_char
		var display_override: String = ""
		if net:
			for row in net.get_player_rows():
				if int(row.get("seat", -1)) == i:
					var row_cid: String = str(row.get("character_id", ""))
					if RosterConfigScript.has_character(row_cid):
						seat_char = row_cid
					display_override = str(row.get("display_name", ""))
					break
		var cfg: Dictionary = RosterConfigScript.get_bot_cfg(seat_char).duplicate()
		cfg["is_human"] = is_local_human
		cfg["is_bot"] = false
		var p = PlayerStateScript.new(i, str(cfg.get("id", seat_char)), cfg)
		if not display_override.is_empty():
			p.display_name = display_override
		_players.append(p)
		var tag: String = " [你]" if p.is_human else " [玩家]"
		_log("席位%d %s · %s%s" % [i, p.display_name, p.character_title, tag])


func _seat_is_remote_human(seat: int) -> bool:
	if _room_peer_seats.is_empty():
		return false
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net == null:
		return false
	var local_id: int = net.get_local_peer_id()
	for pid in _room_peer_seats.keys():
		if int(_room_peer_seats[pid]) == seat:
			return int(pid) != local_id
	return false


func _run_open_auction_loop(run_gen: int) -> void:
	var max_rounds: int = int(_cfg.get("max_rounds", GameConstants.MAX_ROUNDS))
	var min_raise: int = int(_cfg.get("min_raise", GameConstants.DEFAULT_MIN_RAISE))
	var starting_bid: int = int(_cfg.get("starting_bid", GameConstants.DEFAULT_STARTING_BID))
	var reserve_qb: int = int(_cfg.get("reserve_quick_buy", 0))
	while _round_index < max_rounds and _winner_seat < 0:
		_round_index += 1
		_tactical_used_this_round = false
		for p in _players:
			p.reset_round_flags()
		_log("--- 第 %d/%d 轮 明拍 ---" % [_round_index, max_rounds])
		_round_intel = MatchIntelScript.roll_random_intel(
			_warehouse,
			_rng,
			_round_index,
			_recent_intel_signatures(),
		)
		if not _round_intel.is_empty():
			_log("[第%d轮情报] %s" % [_round_index, _round_intel.get("body", "")])
		_append_round_intel_history(_round_intel)
		_set_phase(GameConstants.MatchPhase.INFO)
		var skill_by_seat: Dictionary = _pick_all_players_skill_indices()
		_broadcast_room_sync("present_round_intel", {
			"run_gen": run_gen,
			"round_index": _round_index,
			"intel": _round_intel,
			"skill_by_seat": skill_by_seat,
		})
		await _present_round_intel_with_teaser(run_gen, _round_intel, skill_by_seat)
		if run_gen != _match_run_generation:
			return
		await get_tree().create_timer(GameConstants.ROUND_PAUSE_SECONDS * 0.5).timeout
		if run_gen != _match_run_generation:
			return
		if _board == null or _round_index == 1:
			_board = OpenAuctionRulesScript.create_board(_round_index, starting_bid, min_raise)
		else:
			_board.round_index = _round_index
			_board.raises_this_round = 0
			_board.any_raise_this_window = false
			_board.window_active = false
			_board.min_next_bid = OpenAuctionRulesScript.compute_min_next_bid(
				_board.current_highest_bid, starting_bid, min_raise,
			)
		_broadcast_room_sync("phase", {
			"run_gen": run_gen,
			"phase": GameConstants.MatchPhase.OPEN_BOARD,
			"round_index": _round_index,
		})
		_set_phase(GameConstants.MatchPhase.OPEN_BOARD)
		_broadcast_room_sync("board", {"run_gen": run_gen, "board": _board_to_dict()})
		_emit_board()
		_broadcast_room_sync("phase", {
			"run_gen": run_gen,
			"phase": GameConstants.MatchPhase.BID_WINDOW,
			"round_index": _round_index,
		})
		_set_phase(GameConstants.MatchPhase.BID_WINDOW)
		_round_seat_peak_bid.clear()
		_broadcast_room_sync("bid_window_start", {
			"run_gen": run_gen,
			"round_index": _round_index,
			"window_sec": float(_cfg.get("bid_window_seconds", 10.0)),
		})
		var window_end: String = await _run_bid_window(run_gen, min_raise, reserve_qb, max_rounds)
		if run_gen != _match_run_generation:
			return
		_broadcast_room_sync("phase", {
			"run_gen": run_gen,
			"phase": GameConstants.MatchPhase.BID_RESOLVE,
			"round_index": _round_index,
		})
		_set_phase(GameConstants.MatchPhase.BID_RESOLVE)
		await get_tree().process_frame
		if run_gen != _match_run_generation:
			return
		_broadcast_room_sync("board", {"run_gen": run_gen, "board": _board_to_dict()})
		_emit_board()
		var instant_kill: bool = window_end == "instant_kill"
		var match_ended: bool = false
		if window_end != "":
			_force_match_winner(window_end)
			match_ended = _winner_seat >= 0
		elif _round_index >= max_rounds:
			_force_match_winner("max_rounds")
			match_ended = _winner_seat >= 0
		else:
			var close_res = OpenAuctionRulesScript.close_round(_board, max_rounds, reserve_qb)
			if close_res.auction_ended:
				_winner_seat = close_res.winner_seat
				_winning_bid = close_res.winning_bid
				match_ended = _winner_seat >= 0
				if _winner_seat >= 0:
					_log(">> %s 以 %s 成交 (%s)" % [
						_players[_winner_seat].display_name,
						_format_silver(_winning_bid),
						close_res.reason,
					])
		var cinematic_payloads: Array = []
		if match_ended:
			cinematic_payloads = [
				_build_round_reveal_payload(instant_kill),
				_build_auction_outcome_payload(),
			]
		_broadcast_room_sync("after_bid_resolve", {
			"run_gen": run_gen,
			"window_end": window_end,
			"instant_kill": instant_kill,
			"match_ended": match_ended,
			"winner_seat": _winner_seat,
			"winning_bid": _winning_bid,
			"cinematic_payloads": cinematic_payloads,
		})
		if match_ended:
			await _play_cinematic_sequence(run_gen, cinematic_payloads)
		else:
			await _play_cinematic(run_gen, _build_round_reveal_payload(instant_kill))
		if run_gen != _match_run_generation:
			return
		_broadcast_room_sync("round_closed", {"run_gen": run_gen, "round_index": _round_index})
		round_closed.emit(_round_index)
		if _round_index == 5 and max_rounds < 6 and _has_round_first_place_tie():
			max_rounds = 6
			_log("  第5轮最高价相同，进入第6轮加赛（秒杀倍率 1.1）")
		if match_ended:
			break
		await get_tree().create_timer(GameConstants.ROUND_PAUSE_SECONDS).timeout
		if run_gen != _match_run_generation:
			return
	if _winner_seat < 0 and _board != null and _board.current_highest_bid > 0:
		_winner_seat = _board.current_leader_seat
		_winning_bid = _board.current_highest_bid
		_log(">> 末轮最高价成交: %s %s" % [
			_players[_winner_seat].display_name,
			_format_silver(_winning_bid),
		])


func _run_bid_window(run_gen: int, min_raise: int, reserve_qb: int, _max_rounds: int) -> String:
	if _board == null:
		return ""
	_bid_recording_round = _round_index
	var window_sec: float = float(_cfg.get("bid_window_seconds", 10.0))
	_board.window_active = true
	_board.any_raise_this_window = false
	_reset_seat_locks()
	tactical_state_changed.emit(get_tactical_slots())
	_emit_board()
	_emit_bid_waiting()
	for p in _players:
		if p.forfeited_match:
			_lock_seat_bid(p.seat_index, 0, true)
	_prepare_bot_schedules(window_sec)
	var elapsed: float = 0.0
	var step: float = 0.05
	while elapsed < window_sec:
		await get_tree().create_timer(step).timeout
		if run_gen != _match_run_generation:
			if _board != null:
				_board.window_active = false
			return ""
		elapsed += step
		bid_window_tick.emit(maxf(0.0, window_sec - elapsed))
		_emit_bid_waiting()
		_process_bot_schedules(elapsed, min_raise, _max_rounds)
		if _all_seats_locked():
			bid_window_tick.emit(0.0)
			break
	_force_unlocked_passes()
	_resolve_round_bids(min_raise)
	_apply_end_of_round_forfeits()
	_finalize_round_bids()
	_board.window_active = false
	_emit_board()
	bid_window_finished.emit(_bid_recording_round)
	var window_end: String = ""
	if _try_instant_kill_finish():
		window_end = "instant_kill"
	elif OpenAuctionRulesScript.check_quick_buy(_board, reserve_qb):
		window_end = "quick_buy"
	if _is_room_network_host():
		_broadcast_room_sync("bid_window_end", {
			"run_gen": run_gen,
			"round_index": _bid_recording_round,
			"window_end": window_end,
			"board": _board_to_dict(),
			"peak_bids": _peak_bids_to_dict(),
			"forfeited_seats": _forfeited_seats_list(),
		})
	return window_end


func _reset_seat_locks() -> void:
	_seat_bid_locked.clear()
	_bot_schedules.clear()
	for p in _players:
		_seat_bid_locked[p.seat_index] = false


func _prepare_bot_schedules(window_sec: float) -> void:
	for p in _players:
		if p.is_human or p.forfeited_match:
			continue
		if _seat_is_remote_human(p.seat_index):
			continue
		_bot_schedules.append({
			"seat": p.seat_index,
			"fire_at": _rng.randf_range(1.0, window_sec),
			"fired": false,
		})


func _process_bot_schedules(elapsed: float, min_raise: int, max_rounds: int) -> void:
	for sched in _bot_schedules:
		if sched.get("fired", false):
			continue
		if elapsed < float(sched.get("fire_at", 999.0)):
			continue
		sched["fired"] = true
		var seat: int = int(sched.get("seat", -1))
		if _seat_is_remote_human(seat):
			continue
		_bot_submit_bid(seat, min_raise, max_rounds)


func _bot_submit_bid(seat: int, min_raise: int, max_rounds: int) -> void:
	if _board == null or _warehouse == null:
		return
	if _is_seat_locked(seat):
		return
	var p = _player_by_seat(seat)
	if p == null:
		return
	if p.forfeited_match:
		return
	var amount: int = OpenAuctionBotScript.pick_bid(p, _board, _warehouse, _rng, max_rounds, min_raise)
	if not OpenAuctionBotScript.should_raise(p, _warehouse, _board, _rng, max_rounds):
		amount = maxi(1, int(amount * _rng.randf_range(0.35, 0.72)))
	if p.silver > 0:
		amount = maxi(amount, 1)
		var check: Dictionary = OpenAuctionRulesScript.can_raise(
			_board, seat, amount, p.silver, false,
		)
		if not check.get("ok", false):
			amount = maxi(1, mini(p.silver, amount))
			check = OpenAuctionRulesScript.can_raise(_board, seat, amount, p.silver, false)
		if check.get("ok", false):
			_lock_seat_bid(seat, amount, false)
			return
	_lock_seat_bid(seat, 0, true)


func _force_unlocked_passes() -> void:
	for p in _players:
		if p.forfeited_match:
			continue
		if not _is_seat_locked(p.seat_index):
			_lock_seat_bid(p.seat_index, 0, true)


func _all_seats_locked() -> bool:
	if _players.is_empty():
		return false
	for p in _players:
		if p.forfeited_match:
			continue
		if not _is_seat_locked(p.seat_index):
			return false
	return true


func _bid_window_active_total() -> int:
	var n: int = 0
	for p in _players:
		if not p.forfeited_match:
			n += 1
	return n


func _bid_window_done_count() -> int:
	var n: int = 0
	for p in _players:
		if p.forfeited_match:
			continue
		if _is_seat_locked(p.seat_index):
			n += 1
	return n


func _emit_bid_waiting() -> void:
	var done_n: int = _bid_window_done_count()
	var total_n: int = _bid_window_active_total()
	bid_window_waiting.emit(done_n, total_n)
	if _is_room_network_host():
		_broadcast_room_sync("bid_waiting", {
			"run_gen": _match_run_generation,
			"done": done_n,
			"total": total_n,
		})


func _lock_seat_bid(seat: int, amount: int, passed: bool, from_network: bool = false) -> void:
	var p = _player_by_seat(seat)
	if p == null or _is_seat_locked(seat):
		return
	_seat_bid_locked[seat] = true
	if passed or amount <= 0:
		p.passed_this_round = true
		_round_seat_peak_bid[seat] = 0
	else:
		p.passed_this_round = false
		_round_seat_peak_bid[seat] = amount
	if p.is_human and not p.forfeited_match:
		if passed or amount <= 0:
			player_bid_result.emit(true, "本轮不出价，等待其他玩家")
		else:
			player_bid_result.emit(true, "出价已提交，等待其他玩家")
	_emit_bid_waiting()
	if _lockstep_network and not from_network and seat == _human_seat():
		var net: Node = get_node_or_null("/root/RoomNetwork")
		if net:
			net.request_bid_lock(seat, amount, passed)
		return


func _mark_player_forfeited(p, reason: String) -> void:
	if p.forfeited_match:
		return
	p.forfeited_match = true
	_log("  %s %s，不再参与竞拍" % [p.display_name, reason])
	if p.is_human:
		_human_forfeited_match = true
		match_forfeit_changed.emit(true)
		player_bid_result.emit(true, "已弃权，可观战至本局结束")


func _resolve_round_bids(min_raise: int) -> void:
	var candidates: Array[Dictionary] = []
	for p in _players:
		var seat: int = p.seat_index
		var amount: int = int(_round_seat_peak_bid.get(seat, 0))
		if amount <= 0 or p.forfeited_match:
			continue
		var check: Dictionary = OpenAuctionRulesScript.can_raise(
			_board, seat, amount, p.silver, false, true,
		)
		if not check.get("ok", false):
			continue
		candidates.append({"seat": seat, "amount": amount})
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["amount"]) > int(b["amount"])
	)
	var best_bid: int = int(candidates[0]["amount"])
	var tied: Array[int] = []
	for c in candidates:
		if int(c["amount"]) == best_bid:
			tied.append(int(c["seat"]))
	var winner: int = _resolve_tie_winner_seat(tied)
	if winner >= 0:
		_try_apply_bid(winner, best_bid, min_raise, true)


func _try_apply_bid(seat: int, bid: int, min_raise: int, at_resolve: bool = false) -> void:
	var p = _players[seat]
	var check = OpenAuctionRulesScript.can_raise(
		_board, seat, bid, p.silver, p.passed_this_round if not at_resolve else false, at_resolve,
	)
	if not check["ok"]:
		if p.is_human:
			player_bid_result.emit(false, check["reason"])
		return
	OpenAuctionRulesScript.apply_raise(
		_board, seat, bid, min_raise,
		int(_cfg.get("starting_bid", GameConstants.DEFAULT_STARTING_BID)),
	)
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
	if _is_seat_locked(seat):
		player_bid_result.emit(false, "本轮已提交出价")
		return
	var p_submit = _player_by_seat(seat)
	if p_submit == null:
		return
	var check = OpenAuctionRulesScript.can_raise(
		_board, seat, amount, p_submit.silver, false,
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
	if _is_seat_locked(seat):
		player_bid_result.emit(false, "本轮已提交")
		return
	var p_pass = _player_by_seat(seat)
	if p_pass:
		_log("  %s 本轮不出价" % p_pass.display_name)
	_lock_seat_bid(seat, 0, true)


func player_forfeit_match() -> void:
	var seat: int = _human_seat()
	if seat < 0 or _player_by_seat(seat) == null:
		return
	if _human_forfeited_match:
		return
	if _lockstep_network:
		var net: Node = get_node_or_null("/root/RoomNetwork")
		if net:
			net.request_forfeit_match(seat)
		return
	var p = _player_by_seat(seat)
	if p == null:
		return
	p.forfeited_match = true
	_human_forfeited_match = true
	_round_seat_peak_bid[seat] = 0
	p.current_bid = 0
	p.passed_this_round = true
	_log("  %s 弃权本局，进入观战" % p.display_name)
	if _board != null and _board.window_active and not _is_seat_locked(seat):
		_lock_seat_bid(seat, 0, true)
	_emit_bid_waiting()
	match_forfeit_changed.emit(true)
	player_bid_result.emit(true, "已弃权，可观战至本局结束")


func is_human_forfeited() -> bool:
	return _human_forfeited_match


func get_human_seat() -> int:
	return _human_seat()


func _human_seat() -> int:
	return int(_cfg.get("player_seat", 0))


func _is_human_turn() -> bool:
	if _human_forfeited_match:
		return false
	var seat: int = _human_seat()
	var p = _player_by_seat(seat)
	if p == null:
		return false
	if p.forfeited_match:
		return false
	if _board == null or not _board.window_active:
		return false
	return p.is_human


func is_human_bid_locked() -> bool:
	var seat: int = _human_seat()
	if seat < 0:
		return false
	return _is_seat_locked(seat)


func _emit_board() -> void:
	open_board_updated.emit(_board)
	for p in _players:
		if _board == null:
			continue
		if p.forfeited_match:
			continue
		if _board.current_leader_seat == p.seat_index:
			p.current_bid = _board.current_highest_bid
			p.last_bid_hint = "领先"
		elif p.current_bid > 0 and p.seat_index != _board.current_leader_seat:
			p.last_bid_hint = "出局"


func _make_settlement_tick(
	phase: String,
	winning_bid: int,
	loot_total: int,
	profit: int,
	item_count: int,
) -> Dictionary:
	var winner_name: String = ""
	var winner_title: String = ""
	var winner_character_id: String = ""
	if _winner_seat >= 0 and _winner_seat < _players.size():
		winner_name = _players[_winner_seat].display_name
		winner_title = _players[_winner_seat].character_title
		winner_character_id = _players[_winner_seat].character_id
	return {
		"phase": phase,
		"winning_bid": winning_bid,
		"loot_total": loot_total,
		"profit": profit,
		"winner_seat": _winner_seat,
		"winner_name": winner_name,
		"winner_title": winner_title,
		"winner_character_id": winner_character_id,
		"item_count": item_count,
	}


func _run_unbox_and_settlement(run_gen: int) -> void:
	_set_phase(GameConstants.MatchPhase.UNBOX)
	_warehouse.revealed_count = 0
	_settlement_claimed = false
	_pending_settlement_result = null
	_settlement_rewards_applied = false
	var order: Array[int] = _warehouse.get_reveal_order_indices()
	var total_items: int = order.size()
	var loot_total: int = 0
	var profit: int = -_winning_bid
	var delay: float = float(_cfg.get("unbox_item_delay", GameConstants.UNBOX_ITEM_DELAY))
	_log("--- 对局结束 · 开箱结算 ---")
	settlement_tick.emit(_make_settlement_tick(
		"start", _winning_bid, loot_total, profit, total_items,
	))
	for seq in order.size():
		var item_idx: int = order[seq]
		var item = _warehouse.items[item_idx]
		_warehouse.mark_player_revealed(item_idx)
		_warehouse.revealed_count = maxi(_warehouse.revealed_count, item_idx + 1)
		loot_total += item.value
		profit += item.value
		item_revealed.emit(
			_winner_seat,
			item.quality,
			item.value,
			item_idx,
			total_items,
			item.item_name,
		)
		var item_tick: Dictionary = _make_settlement_tick(
			"item", _winning_bid, loot_total, profit, total_items,
		)
		item_tick["item_index"] = item_idx
		item_tick["item_seq"] = seq + 1
		item_tick["item_name"] = item.item_name
		item_tick["item_value"] = item.value
		settlement_tick.emit(item_tick)
		_log("  %d/%d %s [%s] %s" % [
			seq + 1,
			total_items,
			item.item_name,
			GameConstants.QUALITY_NAMES[item.quality],
			_format_silver(item.value),
		])
		await get_tree().create_timer(delay).timeout
		if run_gen != _match_run_generation:
			return
	_log("真实总值: %s" % _format_silver(_warehouse.true_total_value))
	_set_phase(GameConstants.MatchPhase.SETTLEMENT)
	var dividend_rate: float = float(_cfg.get("opponent_dividend_rate", 1.0))
	var result = SettlementScript.calculate(
		_winner_seat,
		_winning_bid,
		_warehouse,
		_players.size(),
		dividend_rate,
	)
	_pending_settlement_result = result
	var done_tick: Dictionary = _make_settlement_tick(
		"done", _winning_bid, loot_total, result.profit_winner, total_items,
	)
	done_tick["welfare_each"] = result.welfare_each
	settlement_tick.emit(done_tick)
	settlement_ready.emit(result)
	match_settled.emit(result)


func claim_settlement_rewards() -> int:
	if _pending_settlement_result == null or _settlement_rewards_applied:
		return 0
	var human_delta: int = _peek_human_settlement_delta(_pending_settlement_result)
	_apply_settlement_to_players(_pending_settlement_result)
	_settlement_claimed = true
	return human_delta


func _peek_human_settlement_delta(result) -> int:
	if result == null:
		return 0
	for p in _players:
		if p.is_human:
			var seat: int = p.seat_index
			if seat >= 0 and seat < result.player_deltas.size():
				return int(result.player_deltas[seat])
			return 0
	return 0


func _apply_settlement_to_players(result) -> void:
	if _settlement_rewards_applied:
		return
	_settlement_rewards_applied = true
	if _practice_mode:
		return
	for i in _players.size():
		var delta: int = result.player_deltas[i]
		_players[i].net_profit_this_match = result.profit_winner if i == _winner_seat else delta
		_players[i].silver = maxi(0, _players[i].silver + delta)
		if i == _winner_seat:
			_players[i].won_auction = true
		if delta != 0:
			_log("  %s 结算 %s%s" % [
				_players[i].display_name,
				"+" if delta >= 0 else "",
				_format_silver(delta),
			])
	_sync_session_human_silver()
	if result.welfare_each > 0:
		var div_pct: int = int(round(float(_cfg.get("opponent_dividend_rate", 1.0)) * 100.0))
		_log("  对手分红 每人 +%s（亏损 %s 的 %d%% 由 3 名对手瓜分）" % [
			_format_silver(result.welfare_each),
			_format_silver(result.loss_amount),
			div_pct,
		])
	if result.is_overbid and result.compensation_each > 0:
		_log("  超价补偿 每人 +%s（超价 %s 的 %d%%）" % [
			_format_silver(result.compensation_each),
			_format_silver(result.overbid_amount),
			int(round(GameConstants.OVERBID_COMPENSATION_RATE * 100.0)),
		])


func acknowledge_settlement_claim() -> void:
	claim_settlement_rewards()


func _wait_settlement_claim() -> void:
	while not _settlement_claimed:
		await get_tree().create_timer(0.1).timeout


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


func get_instant_kill_multiplier_for_round(round_index: int) -> float:
	if round_index < 1:
		return 1.0
	return MapModeConfigScript.instant_kill_multiplier_for_round(
		round_index,
		_cfg.get("instant_kill_multipliers", []),
	)


func _enrich_effect_round_meta(effect: Dictionary) -> Dictionary:
	var out: Dictionary = effect.duplicate(true)
	var ri: int = int(out.get("round_index", 0))
	if ri < 1:
		return out
	out["instant_kill_multiplier"] = get_instant_kill_multiplier_for_round(ri)
	return out


func get_catalog():
	return _catalog


func did_human_win_auction() -> bool:
	return _winner_seat == _human_seat() and _winner_seat >= 0


func get_estimated_min_price() -> int:
	if _warehouse == null:
		return 0
	return _warehouse.get_player_visible_value_total(_catalog)


func get_human_silver_amount() -> int:
	for p in _players:
		if p.is_human:
			return maxi(0, p.silver)
	return 0


func count_recyclable_items(qualities: Array[int]) -> int:
	if _warehouse == null or not did_human_win_auction():
		return 0
	var quality_set: Dictionary = _quality_filter_set(qualities)
	if quality_set.is_empty():
		return 0
	var count: int = 0
	for item in _warehouse.items:
		if quality_set.has(int(item.quality)):
			count += 1
	return count


func recycle_items_by_qualities(qualities: Array[int]) -> Dictionary:
	if _warehouse == null or not did_human_win_auction():
		return {"count": 0, "silver": 0}
	var quality_set: Dictionary = _quality_filter_set(qualities)
	if quality_set.is_empty():
		return {"count": 0, "silver": 0}
	var indices: Array[int] = []
	for i in _warehouse.items.size():
		if quality_set.has(int(_warehouse.items[i].quality)):
			indices.append(i)
	if indices.is_empty():
		return {"count": 0, "silver": 0}
	var silver: int = _warehouse.remove_items_at_indices(indices)
	for p in _players:
		if p.is_human:
			p.silver = maxi(0, p.silver + silver)
			break
	_sync_session_human_silver()
	return {"count": indices.size(), "silver": silver}


func _quality_filter_set(qualities: Array[int]) -> Dictionary:
	var out: Dictionary = {}
	for q_v in qualities:
		var q: int = int(q_v)
		if q >= 0 and q < GameConstants.QUALITY_COUNT:
			out[q] = true
	return out


func debug_bid_sync_snapshot() -> Dictionary:
	return {
		"done": _bid_window_done_count(),
		"total": _bid_window_active_total(),
		"locked_seats": _seat_bid_locked.duplicate(),
		"phase": _phase,
		"round_index": _round_index,
		"all_locked": _all_seats_locked(),
	}


func get_skill_effects() -> Array:
	return _build_skill_effects()


func _apply_end_of_round_forfeits() -> void:
	for p in _players:
		if not p.is_human:
			continue
		var amount: int = int(_round_seat_peak_bid.get(p.seat_index, 0))
		if amount <= 0:
			_mark_player_forfeited(p, "本轮未出价")


func _finalize_round_bids() -> void:
	var record_round: int = _bid_recording_round
	if record_round <= 0:
		record_round = _round_index
	for p in _players:
		var amount: int = int(_round_seat_peak_bid.get(p.seat_index, 0))
		if p.forfeited_match:
			amount = 0
		p.record_round_bid(record_round, amount)


func _apply_map_mode_to_cfg(mode: Dictionary) -> void:
	if mode.is_empty():
		return
	_cfg["map_id"] = str(mode.get("map_id", ""))
	_cfg["mode_id"] = str(mode.get("mode_id", ""))
	_cfg["map_name"] = str(mode.get("map_name", ""))
	_cfg["mode_name"] = str(mode.get("mode_name", ""))
	_cfg["item_weight_key"] = str(mode.get("weight_key", "weight"))
	_cfg["opponent_dividend_rate"] = float(mode.get("dividend_rate", 1.0))
	_cfg["match_ticket"] = int(mode.get("ticket", 0))
	_cfg["instant_kill_multipliers"] = MapModeConfigScript.get_instant_kill_multipliers()
	_cfg["bot_bid_cap"] = int(mode.get("bot_bid_cap", GameConstants.STARTING_SILVER))


func _apply_bot_bid_cap() -> void:
	var cap: int = int(_cfg.get("bot_bid_cap", GameConstants.STARTING_SILVER))
	if cap <= 0:
		cap = GameConstants.STARTING_SILVER
	for p in _players:
		if p.is_bot and not p.is_human:
			p.silver = cap


func _deduct_match_ticket() -> void:
	if _practice_mode:
		return
	var ticket: int = int(_cfg.get("match_ticket", 0))
	if ticket <= 0:
		return
	for p in _players:
		if not p.is_human:
			continue
		p.silver = maxi(0, p.silver - ticket)
		_log("  门票 -%s（%s · %s）" % [
			_format_silver(ticket),
			_cfg.get("map_name", ""),
			_cfg.get("mode_name", ""),
		])
		break


func _build_round_reveal_payload(instant_kill: bool) -> Dictionary:
	var rows: Array = []
	for p in _players:
		var amount: int = int(_round_seat_peak_bid.get(p.seat_index, 0))
		rows.append({
			"seat": p.seat_index,
			"display_name": p.display_name,
			"character_id": p.character_id,
			"amount": amount,
			"passed": amount <= 0 or p.passed_this_round,
			"is_human": p.is_human,
			"forfeited": p.forfeited_match,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["amount"]) != int(b["amount"]):
			return int(a["amount"]) > int(b["amount"])
		var a_bk: bool = _is_black_knight_seat(int(a["seat"]))
		var b_bk: bool = _is_black_knight_seat(int(b["seat"]))
		if a_bk != b_bk:
			return a_bk
		return int(a["seat"]) < int(b["seat"])
	)
	var human_seat: int = _human_seat()
	var human_rank: int = 0
	for i in rows.size():
		if int(rows[i].get("seat", -1)) == human_seat:
			human_rank = i + 1
			break
	var leader_seat: int = _board.current_leader_seat if _board != null else -1
	var ik_name: String = ""
	if instant_kill and leader_seat >= 0 and leader_seat < _players.size():
		ik_name = _players[leader_seat].display_name
	return {
		"type": "round_reveal",
		"round_index": _round_index,
		"rows": rows,
		"instant_kill": instant_kill,
		"instant_kill_winner_seat": leader_seat if instant_kill else -1,
		"instant_kill_winner_name": ik_name,
		"human_seat": human_seat,
		"human_rank": human_rank,
	}


func _build_auction_outcome_payload() -> Dictionary:
	var human_seat: int = _human_seat()
	var human_won: bool = _winner_seat == human_seat and _winner_seat >= 0
	var ranked: Array = _rank_round_peak_bids()
	var margin: int = 0
	if ranked.size() >= 2:
		margin = int(ranked[0]["amount"]) - int(ranked[1]["amount"])
	elif ranked.size() == 1:
		margin = int(ranked[0]["amount"])
	elif _winning_bid > 0:
		margin = _winning_bid
	var winner_name: String = ""
	var winner_character_id: String = ""
	var winner_title: String = "买家"
	if _winner_seat >= 0 and _winner_seat < _players.size():
		winner_name = _players[_winner_seat].display_name
		winner_character_id = _players[_winner_seat].character_id
		winner_title = _players[_winner_seat].character_title
	return {
		"type": "auction_success" if human_won else "auction_fail",
		"winner_name": winner_name,
		"winner_character_id": winner_character_id,
		"winner_title": winner_title,
		"hammer_price": _winning_bid,
		"margin_over_second": margin,
		"human_won": human_won,
	}


func _rank_round_peak_bids() -> Array:
	var ranked: Array = []
	for p in _players:
		if p.forfeited_match:
			continue
		var amount: int = int(_round_seat_peak_bid.get(p.seat_index, 0))
		if amount > 0:
			ranked.append({"seat": p.seat_index, "amount": amount})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["amount"]) != int(b["amount"]):
			return int(a["amount"]) > int(b["amount"])
		var a_bk: bool = _is_black_knight_seat(int(a["seat"]))
		var b_bk: bool = _is_black_knight_seat(int(b["seat"]))
		if a_bk != b_bk:
			return a_bk
		return int(a["seat"]) < int(b["seat"])
	)
	return ranked


func _has_round_first_place_tie() -> bool:
	var ranked: Array = _rank_round_peak_bids()
	if ranked.size() < 2:
		return false
	if int(ranked[0]["amount"]) != int(ranked[1]["amount"]):
		return false
	var top: int = int(ranked[0]["amount"])
	var tied: Array[int] = []
	for row in ranked:
		if int(row["amount"]) == top:
			tied.append(int(row["seat"]))
	if _resolve_tie_winner_seat(tied) >= 0:
		return false
	return true


func _try_instant_kill_finish() -> bool:
	if _board == null or _board.current_highest_bid <= 0:
		return false
	var ranked: Array = _rank_round_peak_bids()
	if ranked.is_empty():
		return false
	var top_seat: int = int(ranked[0]["seat"])
	var top: int = int(ranked[0]["amount"])
	if _is_black_knight_seat(top_seat):
		var another_bk_tied: bool = false
		for i in range(1, ranked.size()):
			if int(ranked[i]["amount"]) == top and _is_black_knight_seat(int(ranked[i]["seat"])):
				another_bk_tied = true
				break
		if another_bk_tied:
			_log("  [黑蔷薇威压] 双黑骑士并列第一，秒杀失效，继续竞价")
		else:
			_log("  [黑蔷薇威压] %s 排名第一，秒杀进入结算" % _players[top_seat].display_name)
			return true
	if ranked.size() < 2:
		return false
	var second: int = int(ranked[1]["amount"])
	if second <= 0 or top <= second:
		return false
	var mult: float = MapModeConfigScript.instant_kill_multiplier_for_round(
		_round_index,
		_cfg.get("instant_kill_multipliers", []),
	)
	if float(top) >= float(second) * mult:
		_log("  秒杀触发：%s ≥ %s × %.1f" % [
			_format_silver(top),
			_format_silver(second),
			mult,
		])
		return true
	return false


func _recent_intel_signatures() -> Array[String]:
	var out: Array[String] = []
	for intel in _round_intel_history:
		var sig: String = MatchIntelScript.intel_signature(intel)
		if not sig.is_empty() and not out.has(sig):
			out.append(sig)
	return out


func _append_round_intel_history(intel: Dictionary) -> void:
	if intel.is_empty():
		return
	var entry: Dictionary = intel.duplicate(true)
	if int(entry.get("round_index", 0)) < 1:
		entry["round_index"] = _round_index
	_round_intel_history.append(_enrich_effect_round_meta(entry))


func _append_round_skill_effect_history(effect: Dictionary) -> void:
	if effect.is_empty():
		return
	var entry: Dictionary = effect.duplicate(true)
	if int(entry.get("round_index", 0)) < 1:
		entry["round_index"] = _round_index
	_round_skill_effect_history.append(_enrich_effect_round_meta(entry))


func _human_character_id() -> String:
	var seat: int = _human_seat()
	var p = _player_by_seat(seat)
	if p == null:
		return RosterConfigScript.get_default_id()
	return p.character_id


func _pick_human_skill_indices() -> Dictionary:
	return _skill_indices_for_seat(_pick_all_players_skill_indices(), _human_seat())


func _pick_all_players_skill_indices() -> Dictionary:
	var by_seat: Dictionary = {}
	if _warehouse == null:
		return by_seat
	var used_skill_ids: Dictionary = {}
	for p in _players:
		var skill_id: String = RosterConfigScript.get_skill_id(p.character_id)
		if skill_id.is_empty() or used_skill_ids.has(skill_id):
			continue
		used_skill_ids[skill_id] = true
		var picked: Dictionary = CharacterSkillsScript.pick_round_skill_indices(
			_warehouse, _rng, skill_id, _round_index,
		)
		var rev: Array = picked.get("revealed_indices", [])
		var qs: Array = picked.get("quality_size_indices", [])
		var outlines: Array = picked.get("outline_indices", [])
		if not rev.is_empty() or not qs.is_empty() or not outlines.is_empty():
			by_seat[str(p.seat_index)] = picked
	return by_seat


func _skill_indices_for_seat(skill_by_seat: Dictionary, seat: int) -> Dictionary:
	var picked: Variant = skill_by_seat.get(str(seat), {})
	if picked is Dictionary:
		return picked
	return {"revealed_indices": [], "quality_size_indices": [], "outline_indices": []}


func _has_human_player() -> bool:
	var seat: int = _human_seat()
	var p = _player_by_seat(seat)
	if p == null:
		return false
	return p.is_human


func _is_black_knight_seat(seat: int) -> bool:
	var p = _player_by_seat(seat)
	if p == null:
		return false
	return RosterConfigScript.get_skill_id(p.character_id) == "black_rose_pressure"


func _resolve_tie_winner_seat(tied_seats: Array[int]) -> int:
	if tied_seats.is_empty():
		return -1
	if tied_seats.size() == 1:
		return tied_seats[0]
	var bk_seats: Array[int] = []
	for seat in tied_seats:
		if _is_black_knight_seat(seat):
			bk_seats.append(seat)
	if bk_seats.size() == 1:
		_log("  [黑蔷薇威压] %s 同价胜出" % _players[bk_seats[0]].display_name)
		return bk_seats[0]
	if bk_seats.size() >= 2:
		_log("  [黑蔷薇威压] 双黑骑士冲突（%s vs %s），同价技能失效" % [
			_players[bk_seats[0]].display_name,
			_players[bk_seats[1]].display_name,
		])
	return tied_seats[0]


func _emit_skill_effects() -> void:
	skill_effects_updated.emit(_build_skill_effects())


func notify_cinematic_finished() -> void:
	_cinematic_waiting = false


func _play_cinematic(run_gen: int, payload: Dictionary, options: Dictionary = {}) -> void:
	if run_gen != _match_run_generation:
		return
	if _should_auto_skip_cinematic():
		return
	_cinematic_waiting = true
	var req: Dictionary = payload.duplicate()
	if not options.is_empty():
		req["options"] = options
	cinematic_requested.emit(req)
	while _cinematic_waiting:
		await get_tree().process_frame
		if run_gen != _match_run_generation:
			_cinematic_waiting = false
			return


func _should_auto_skip_cinematic() -> bool:
	if OS.has_environment("BIDKING_ROOM_TEST"):
		return true
	var ds_name: String = DisplayServer.get_name()
	return ds_name == "headless" or ds_name == "dummy"


func _play_cinematic_sequence(run_gen: int, payloads: Array) -> void:
	if run_gen != _match_run_generation or payloads.is_empty():
		return
	if _should_auto_skip_cinematic():
		return
	_cinematic_waiting = true
	cinematic_requested.emit({"type": "_sequence", "sequence": payloads})
	while _cinematic_waiting:
		await get_tree().process_frame
		if run_gen != _match_run_generation:
			_cinematic_waiting = false
			return


func _present_match_start_intro(run_gen: int) -> void:
	var heritage: Dictionary = MatchHeritageConfigScript.pick_random(_pending_map_id, match_seed)
	await _play_cinematic_sequence(run_gen, [
		{"type": "auction_start"},
		{
			"type": "heritage",
			"location_name": heritage.get("name", ""),
			"description": heritage.get("description", ""),
		},
	])
	if run_gen != _match_run_generation:
		return
	var used_start_skill_ids: Dictionary = {}
	for p in _players:
		var skill_id: String = RosterConfigScript.get_skill_id(p.character_id)
		if skill_id.is_empty() or used_start_skill_ids.has(skill_id):
			continue
		used_start_skill_ids[skill_id] = true
		var mia_start: Array[int] = []
		if skill_id == "holy_bell_shake":
			var picked: Dictionary = CharacterSkillsScript.pick_round_skill_indices(
				_warehouse, _rng, "holy_bell_shake", 1,
			)
			mia_start = picked.get("quality_size_indices", [])
			if p.is_human:
				for idx_v in mia_start:
					_warehouse.mark_quality_size_revealed(int(idx_v))
		for eff in CharacterSkillsScript.build_match_start_effects(
			_warehouse, _cfg, p.character_id, mia_start,
		):
			var entry: Dictionary = _enrich_effect_round_meta(eff)
			if not mia_start.is_empty():
				entry["quality_size_indices"] = mia_start.duplicate()
			_match_start_skill_effects.append(entry)


func _present_round_intel_with_teaser(
	run_gen: int,
	round_intel: Dictionary,
	skill_by_seat: Dictionary,
) -> void:
	var skill_eff: Dictionary = {}
	if _has_human_player():
		skill_eff = CharacterSkillsScript.build_round_skill_effect(
			_warehouse,
			_human_character_id(),
			_skill_indices_for_seat(skill_by_seat, _human_seat()),
			maxi(_round_index, 1),
			_catalog,
		)
	var max_rounds: int = int(_cfg.get("max_rounds", GameConstants.MAX_ROUNDS))
	await _play_cinematic(run_gen, {
		"type": "round_start",
		"round_index": _round_index,
		"max_rounds": max_rounds,
		"instant_kill_mult": get_instant_kill_multiplier_for_round(_round_index),
		"intel": round_intel,
		"skill_effect": skill_eff,
	}, {"fade_out": false})
	if run_gen != _match_run_generation:
		return
	await _present_round_info_sequence(run_gen, round_intel, skill_by_seat)


func _present_round_info_sequence(run_gen: int, round_intel: Dictionary, skill_by_seat: Dictionary) -> void:
	_skill_effects_ui_round = maxi(_skill_effects_ui_round, _round_index)
	var queue: Array[Dictionary] = _build_round_info_effect_queue(round_intel, skill_by_seat)
	await _present_effect_queue(run_gen, queue, false)
	if run_gen != _match_run_generation:
		return
	skill_effects_updated.emit(_build_skill_effects())


func _build_round_info_effect_queue(round_intel: Dictionary, skill_by_seat: Dictionary) -> Array[Dictionary]:
	var queue: Array[Dictionary] = []
	if not round_intel.is_empty():
		queue.append(_enrich_effect_round_meta(round_intel))
	if not _match_start_skill_effects.is_empty():
		for deferred in _match_start_skill_effects:
			_append_round_skill_effect_history(deferred)
			queue.append(deferred)
		_match_start_skill_effects.clear()
	var used_skill_ids: Dictionary = {}
	for p in _players:
		var skill_id: String = RosterConfigScript.get_skill_id(p.character_id)
		if skill_id.is_empty() or used_skill_ids.has(skill_id):
			continue
		var indices: Dictionary = _skill_indices_for_seat(skill_by_seat, p.seat_index)
		var skill_eff: Dictionary = CharacterSkillsScript.build_round_skill_effect(
			_warehouse,
			p.character_id,
			indices,
			maxi(_round_index, 1),
			_catalog,
		)
		if skill_eff.is_empty():
			continue
		used_skill_ids[skill_id] = true
		var entry: Dictionary = _enrich_effect_round_meta(skill_eff)
		_append_round_skill_effect_history(entry)
		queue.append(entry)
	return queue


func _should_show_skill_effect_in_ui(effect: Dictionary) -> bool:
	if bool(effect.get("is_teaser", false)):
		return true
	if str(effect.get("icon_kind", "")) == "tactical":
		return true
	var effect_round: int = int(effect.get("round_index", 0))
	if effect_round > 0 and effect_round > _skill_effects_ui_round:
		return false
	if str(effect.get("icon_kind", "")) != "character":
		return true
	var cid: String = str(effect.get("character_id", ""))
	if cid.is_empty():
		return false
	return cid == _human_character_id()


func _present_effect_queue(run_gen: int, queue: Array[Dictionary], teaser_extra_delay: bool) -> void:
	skill_effects_reset.emit()
	await get_tree().process_frame
	for effect in queue:
		if run_gen != _match_run_generation:
			return
		var show_ui: bool = _should_show_skill_effect_in_ui(effect)
		if show_ui:
			skill_effect_appended.emit(_enrich_effect_round_meta(effect))
			var wait_sec: float = GameConstants.INTEL_CARD_DELAY
			if teaser_extra_delay and bool(effect.get("is_teaser", false)):
				wait_sec = GameConstants.INTEL_TEASER_DELAY
			await get_tree().create_timer(wait_sec).timeout
			if run_gen != _match_run_generation:
				return
			await _apply_single_effect_reveals(run_gen, effect)
	skill_effects_updated.emit(_build_skill_effects())


func _apply_effect_queue_reveals(run_gen: int, queue: Array[Dictionary]) -> void:
	for effect in queue:
		if run_gen != _match_run_generation:
			return
		await _apply_single_effect_reveals(run_gen, effect)


func _apply_single_effect_reveals(run_gen: int, effect: Dictionary) -> void:
	if run_gen != _match_run_generation:
		return
	var icon_kind: String = str(effect.get("icon_kind", ""))
	var can_reveal_visual: bool = icon_kind == "tactical" or icon_kind != "character" or str(effect.get("character_id", "")) == _human_character_id()
	var outline_indices: Array = effect.get("outline_indices", [])
	if not outline_indices.is_empty() and can_reveal_visual:
		for idx_v in outline_indices:
			_warehouse.mark_outline_revealed(int(idx_v))
		intel_outlines_revealed.emit(outline_indices.duplicate())
		await get_tree().create_timer(GameConstants.INTEL_ITEM_REVEAL_DELAY).timeout
		if run_gen != _match_run_generation:
			return
	var intel_indices: Array = effect.get("revealed_indices", [])
	for idx_v in intel_indices:
		var idx: int = int(idx_v)
		if _warehouse.is_player_revealed(idx):
			continue
		_warehouse.mark_player_revealed(idx)
		intel_items_revealed.emit([idx])
		await get_tree().create_timer(GameConstants.INTEL_ITEM_REVEAL_DELAY).timeout
		if run_gen != _match_run_generation:
			return
	var qs_indices: Array = effect.get("quality_size_indices", [])
	if not can_reveal_visual:
		qs_indices = []
	var qs_revealed: int = 0
	for idx_v in qs_indices:
		var idx: int = int(idx_v)
		if _warehouse.is_quality_size_revealed(idx):
			continue
		_warehouse.mark_quality_size_revealed(idx)
		quality_size_revealed.emit([idx])
		qs_revealed += 1
		await get_tree().create_timer(GameConstants.INTEL_ITEM_REVEAL_DELAY).timeout
		if run_gen != _match_run_generation:
			return
	if qs_revealed > 0:
		var owner_name: String = str(effect.get("title", ""))
		if owner_name.is_empty():
			owner_name = RosterConfigScript.get_display_name(_human_character_id())
		_log("  [%s] 探测 %d 件品质与占格" % [owner_name, qs_revealed])


func _build_skill_effects() -> Array:
	var effects: Array = []
	if _warehouse == null:
		return effects
	for i in range(_round_intel_history.size() - 1, -1, -1):
		var intel: Dictionary = _round_intel_history[i].duplicate()
		var ri: int = int(intel.get("round_index", 0))
		if ri > _skill_effects_ui_round:
			continue
		if not _should_show_skill_effect_in_ui(intel):
			continue
		effects.append(intel)
		for skill_row in _find_all_skill_effects_for_round(ri):
			if _should_show_skill_effect_in_ui(skill_row):
				effects.append(skill_row)
	if _has_human_player() and _skill_effects_ui_round >= 1:
		var chip: Dictionary = CharacterSkillsScript.build_persistent_skill_chip(
			_warehouse,
			_human_character_id(),
			_skill_effects_ui_round,
		)
		if not chip.is_empty():
			effects.append(_enrich_effect_round_meta(chip))
	return effects


func _find_skill_effect_for_round(round_index: int) -> Dictionary:
	var rows: Array = _find_all_skill_effects_for_round(round_index)
	if rows.is_empty():
		return {}
	return rows[rows.size() - 1]


func _find_all_skill_effects_for_round(round_index: int) -> Array:
	var rows: Array = []
	for row in _round_skill_effect_history:
		if int(row.get("round_index", 0)) == round_index:
			rows.append(row.duplicate(true))
	return rows


static func _format_silver(amount: int) -> String:
	if abs(amount) >= 1_000_000:
		return "%.2fM" % (float(amount) / 1_000_000.0)
	if abs(amount) >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)
