extends Node
## 房间联机：ENet 大厅 + 锁步出价同步（快速匹配可复用接口）

signal lobby_state_changed
signal lobby_error(message: String)
signal lobby_message(message: String)
signal match_start_requested(payload: Dictionary)
signal match_sync_received(step: String, data: Dictionary)

const RosterConfigScript = preload("res://scripts/data/roster_config.gd")

const CODE_CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const DEFAULT_PORT: int = 17777
const MAX_PORT_TRIES: int = 32
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4

enum LobbyRole { NONE, HOST, CLIENT }

var role: int = LobbyRole.NONE
var room_code: String = ""
var host_address: String = "127.0.0.1"
var listen_port: int = DEFAULT_PORT
var map_id: String = ""
var mode_id: String = ""
var is_practice: bool = true
## 房主设定的人数（2~4），全员到齐且准备后才会开局
var target_player_count: int = MIN_PLAYERS

var _peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var _players: Dictionary = {} ## peer_id:int -> { peer_id, display_name, seat, ready, is_host }
var _local_ready: bool = false
var _match_started: bool = false
var _lobby_synced: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_in_room() -> bool:
	return role != LobbyRole.NONE and multiplayer.multiplayer_peer != null


func get_player_rows() -> Array:
	var rows: Array = []
	var ids: Array = _players.keys()
	ids.sort()
	for pid_v in ids:
		rows.append(_players[pid_v].duplicate())
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("seat", 99)) < int(b.get("seat", 99))
	)
	return rows


func get_ready_count() -> int:
	var n: int = 0
	for p in _players.values():
		if p.get("ready", false):
			n += 1
	return n


func get_connected_count() -> int:
	return _players.size()


func is_local_in_lobby() -> bool:
	return _has_player(get_local_peer_id())


func is_lobby_synced() -> bool:
	return _lobby_synced


func get_target_player_count() -> int:
	return target_player_count


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()


func get_local_seat() -> int:
	var pid: int = get_local_peer_id()
	if _has_player(pid):
		return int(_get_player_entry(pid).get("seat", 0))
	return 0


func get_peer_seat_map() -> Dictionary:
	var out: Dictionary = {}
	for pid in _players.keys():
		out[int(pid)] = int(_get_player_entry(int(pid)).get("seat", 0))
	return out


func wait_for_lobby_sync(timeout_sec: float = 10.0) -> bool:
	var elapsed: float = 0.0
	while elapsed < timeout_sec:
		if not is_in_room():
			return false
		if role == LobbyRole.HOST:
			return is_local_in_lobby()
		var peer: MultiplayerPeer = multiplayer.multiplayer_peer
		if peer == null:
			return false
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			return false
		if _lobby_synced and is_local_in_lobby():
			return true
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_request_join_when_ready()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return _lobby_synced and is_local_in_lobby()


func leave_room() -> void:
	if role == LobbyRole.HOST and multiplayer.multiplayer_peer != null:
		var peers: Array = multiplayer.get_peers()
		if not peers.is_empty():
			_rpc_room_closed.rpc("房主已离开房间")
	_match_started = false
	_local_ready = false
	_lobby_synced = false
	_players.clear()
	target_player_count = MIN_PLAYERS
	room_code = ""
	role = LobbyRole.NONE
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	lobby_state_changed.emit()


func create_room(
	p_map_id: String,
	p_mode_id: String,
	practice: bool = true,
	player_count: int = MIN_PLAYERS,
) -> Dictionary:
	leave_room()
	map_id = p_map_id
	mode_id = p_mode_id
	is_practice = practice
	target_player_count = clampi(player_count, MIN_PLAYERS, MAX_PLAYERS)
	room_code = _generate_room_code()
	var port_result: Dictionary = _bind_host_port(DEFAULT_PORT)
	if not port_result.get("ok", false):
		return port_result
	listen_port = int(port_result.get("port", DEFAULT_PORT))
	multiplayer.multiplayer_peer = _peer
	role = LobbyRole.HOST
	_register_local_player(true)
	_lobby_synced = true
	lobby_message.emit("房间已创建：%s（端口 %d）" % [room_code, listen_port])
	lobby_state_changed.emit()
	return {"ok": true, "room_code": room_code, "port": listen_port}


func join_room(code: String, address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Dictionary:
	leave_room()
	var norm_code: String = _normalize_code(code)
	if norm_code.length() != 4:
		return {"ok": false, "reason": "房间号须为 4 位"}
	host_address = address.strip_edges()
	if host_address.is_empty():
		host_address = "127.0.0.1"
	var err: Error = _peer.create_client(host_address, port)
	if err != OK:
		return {"ok": false, "reason": "无法连接主机（%s）" % error_string(err)}
	multiplayer.multiplayer_peer = _peer
	role = LobbyRole.CLIENT
	room_code = norm_code
	listen_port = port
	_lobby_synced = false
	lobby_message.emit("正在加入房间 %s…" % room_code)
	return {"ok": true}


func set_local_ready(ready: bool) -> void:
	_local_ready = ready
	var pid: int = get_local_peer_id()
	if _has_player(pid):
		_get_player_entry(pid)["ready"] = ready
	_flush_local_ready_rpc()
	lobby_state_changed.emit()
	if role == LobbyRole.HOST:
		_try_host_start_match()


func host_request_start() -> void:
	if role != LobbyRole.HOST:
		return
	_try_host_start_match()


func _try_host_start_match() -> void:
	if role != LobbyRole.HOST or _match_started:
		return
	if get_connected_count() < MIN_PLAYERS:
		return
	if get_connected_count() < target_player_count:
		return
	if get_ready_count() < get_connected_count():
		return
	_match_started = true
	var seed: int = int(Time.get_unix_time_from_system()) % 1_000_000
	var assignments: Dictionary = get_peer_seat_map()
	var payload: Dictionary = {
		"seed": seed,
		"map_id": map_id,
		"mode_id": mode_id,
		"practice": is_practice,
		"assignments": assignments,
	}
	_rpc_begin_match.rpc(payload)


func request_bid_lock(seat: int, amount: int, passed: bool) -> void:
	if not is_in_room() or not _match_started:
		return
	if multiplayer.is_server():
		_rpc_bid_lock.rpc(seat, amount, passed)
	else:
		_rpc_request_bid_lock.rpc_id(1, seat, amount, passed)


func request_forfeit_match(seat: int) -> void:
	if not is_in_room() or not _match_started:
		return
	if multiplayer.is_server():
		_rpc_forfeit_match.rpc(seat)
	else:
		_rpc_request_forfeit_match.rpc_id(1, seat)


func broadcast_match_sync(step: String, data: Dictionary) -> void:
	if not is_in_room() or not _match_started or not multiplayer.is_server():
		return
	_rpc_match_sync.rpc(step, data)


# --- RPC ---


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_join(code: String, display_name: String, character_id: String = "") -> void:
	if role != LobbyRole.HOST:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if _normalize_code(code) != room_code:
		_rpc_join_rejected.rpc_id(sender, "房间号不正确")
		return
	if _has_player(sender):
		_refresh_player(sender, display_name, false, character_id)
		_sync_lobby_to_all()
		return
	if _players.size() >= MAX_PLAYERS:
		_rpc_join_rejected.rpc_id(sender, "房间已满")
		return
	_add_player(sender, display_name, false, character_id)
	_sync_lobby_to_all()


@rpc("authority", "call_remote", "reliable")
func _rpc_join_rejected(reason: String) -> void:
	leave_room()
	lobby_error.emit(reason)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = get_local_peer_id()
	if not _has_player(sender):
		return
	_get_player_entry(sender)["ready"] = ready
	lobby_state_changed.emit()
	if role == LobbyRole.HOST:
		_try_host_start_match()


@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(payload: Dictionary) -> void:
	_match_started = true
	match_start_requested.emit(payload)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_bid_lock(seat: int, amount: int, passed: bool) -> void:
	if not multiplayer.is_server():
		return
	_rpc_bid_lock.rpc(seat, amount, passed)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_forfeit_match(seat: int) -> void:
	if not multiplayer.is_server():
		return
	_rpc_forfeit_match.rpc(seat)


@rpc("any_peer", "call_local", "reliable")
func _rpc_bid_lock(seat: int, amount: int, passed: bool) -> void:
	var bridge: Node = _find_match_controller()
	if bridge and bridge.has_method("apply_network_bid_lock"):
		bridge.apply_network_bid_lock(seat, amount, passed)


@rpc("any_peer", "call_local", "reliable")
func _rpc_forfeit_match(seat: int) -> void:
	var bridge: Node = _find_match_controller()
	if bridge and bridge.has_method("apply_network_forfeit"):
		bridge.apply_network_forfeit(seat)


@rpc("authority", "call_local", "reliable")
func _rpc_match_sync(step: String, data: Dictionary) -> void:
	match_sync_received.emit(step, data)


func _find_match_controller() -> Node:
	var bridge: Node = get_tree().root.get_node_or_null("Main/MatchController")
	if bridge == null:
		bridge = get_tree().get_first_node_in_group("match_controller")
	return bridge


@rpc("authority", "call_local", "reliable")
func _rpc_room_closed(reason: String) -> void:
	if role == LobbyRole.HOST:
		return
	leave_room()
	lobby_error.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_lobby(state: Dictionary) -> void:
	room_code = str(state.get("room_code", room_code))
	map_id = str(state.get("map_id", map_id))
	mode_id = str(state.get("mode_id", mode_id))
	is_practice = bool(state.get("practice", true))
	listen_port = int(state.get("port", listen_port))
	_players = _normalize_players_dict(state.get("players", {}))
	target_player_count = clampi(int(state.get("target_player_count", target_player_count)), MIN_PLAYERS, MAX_PLAYERS)
	_lobby_synced = true
	var pid: int = get_local_peer_id()
	if _has_player(pid):
		_get_player_entry(pid)["ready"] = _local_ready
	lobby_state_changed.emit()
	_flush_local_ready_rpc()


# --- Multiplayer callbacks ---


func _on_peer_connected(peer_id: int) -> void:
	if role != LobbyRole.HOST:
		return
	lobby_message.emit("玩家 %d 已连接" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var pid: int = int(peer_id)
	if _has_player(pid):
		_remove_player(pid)
		lobby_state_changed.emit()
		if role == LobbyRole.HOST:
			_match_started = false
			_sync_lobby_to_all()
	if role == LobbyRole.CLIENT and pid == 1:
		leave_room()
		lobby_error.emit("已与主机断开连接")


func _on_server_disconnected() -> void:
	if role == LobbyRole.CLIENT:
		leave_room()
		lobby_error.emit("已与主机断开连接")


func _register_local_player(as_host: bool) -> void:
	var pid: int = get_local_peer_id()
	var name: String = _local_display_name()
	_add_player(pid, name, as_host, _local_character_id())
	if as_host and _has_player(pid):
		_get_player_entry(pid)["ready"] = _local_ready


func _add_player(peer_id: int, display_name: String, as_host: bool, character_id: String = "") -> void:
	var seat: int = _next_free_seat()
	var cid: String = character_id.strip_edges()
	if cid.is_empty() or not RosterConfigScript.has_character(cid):
		cid = RosterConfigScript.get_default_id()
	_set_player_entry(peer_id, {
		"peer_id": peer_id,
		"display_name": display_name,
		"seat": seat,
		"ready": false,
		"is_host": as_host,
		"character_id": cid,
	})


func _refresh_player(peer_id: int, display_name: String, as_host: bool, character_id: String = "") -> void:
	var seat: int = _next_free_seat()
	if _has_player(peer_id):
		seat = int(_get_player_entry(peer_id).get("seat", seat))
	var cid: String = character_id.strip_edges()
	if cid.is_empty() or not RosterConfigScript.has_character(cid):
		cid = RosterConfigScript.get_default_id()
	_set_player_entry(peer_id, {
		"peer_id": peer_id,
		"display_name": display_name,
		"seat": seat,
		"ready": false,
		"is_host": as_host,
		"character_id": cid,
	})


func _remove_player(peer_id: int) -> void:
	if _players.has(peer_id):
		_players.erase(peer_id)
	elif _players.has(str(peer_id)):
		_players.erase(str(peer_id))


func _set_player_entry(peer_id: int, row: Dictionary) -> void:
	if _players.has(str(peer_id)):
		_players.erase(str(peer_id))
	_players[peer_id] = row


func _has_player(peer_id: int) -> bool:
	return _players.has(peer_id) or _players.has(str(peer_id))


func _get_player_entry(peer_id: int) -> Dictionary:
	if _players.has(peer_id):
		return _players[peer_id]
	if _players.has(str(peer_id)):
		return _players[str(peer_id)]
	return {}


func _normalize_players_dict(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in (raw as Dictionary).keys():
		var pid: int = int(key)
		var row_v: Variant = (raw as Dictionary)[key]
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = (row_v as Dictionary).duplicate(true)
		row["peer_id"] = pid
		row["seat"] = int(row.get("seat", 0))
		row["ready"] = bool(row.get("ready", false))
		row["is_host"] = bool(row.get("is_host", false))
		out[pid] = row
	return out


func _next_free_seat() -> int:
	var used: Dictionary = {}
	for p in _players.values():
		used[int(p.get("seat", -1))] = true
	for s in MAX_PLAYERS:
		if not used.has(s):
			return s
	return MAX_PLAYERS - 1


func _sync_lobby_to_all() -> void:
	if role != LobbyRole.HOST:
		return
	var state: Dictionary = {
		"room_code": room_code,
		"map_id": map_id,
		"mode_id": mode_id,
		"practice": is_practice,
		"port": listen_port,
		"target_player_count": target_player_count,
		"players": _serialize_players_for_rpc(),
	}
	_rpc_sync_lobby.rpc(state)


func _serialize_players_for_rpc() -> Dictionary:
	var out: Dictionary = {}
	for pid in _players.keys():
		var row: Dictionary = (_players[pid] as Dictionary).duplicate(true)
		out[str(pid)] = row
	return out


func _local_display_name() -> String:
	return RosterConfigScript.get_display_name(_local_character_id())


func _local_character_id() -> String:
	RosterConfigScript.ensure_loaded()
	var roster: Node = get_node_or_null("/root/PlayerRoster")
	if roster:
		var cid: String = str(roster.selected_character_id)
		if RosterConfigScript.has_character(cid):
			return cid
	return RosterConfigScript.get_default_id()


func _flush_local_ready_rpc() -> void:
	if not is_in_room():
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return
	if role == LobbyRole.CLIENT:
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			return
		if not _has_player(get_local_peer_id()):
			return
	_rpc_set_ready.rpc(_local_ready)


func _on_connected_to_server() -> void:
	if role != LobbyRole.CLIENT:
		return
	_request_join_when_ready()


func _request_join_when_ready() -> void:
	if role != LobbyRole.CLIENT or not is_in_room():
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	_rpc_request_join.rpc_id(1, room_code, _local_display_name(), _local_character_id())


func _generate_room_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code: String = ""
	for _i in 4:
		code += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return code


func _normalize_code(code: String) -> String:
	return code.strip_edges().to_upper().replace(" ", "")


func _bind_host_port(start_port: int) -> Dictionary:
	for i in MAX_PORT_TRIES:
		var port: int = start_port + i
		var err: Error = _peer.create_server(port, MAX_PLAYERS)
		if err == OK:
			return {"ok": true, "port": port}
	return {"ok": false, "reason": "无法绑定本地端口（%d+）" % start_port}
