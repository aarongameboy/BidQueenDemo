extends Node
## 房间联机 N 人出价同步测试：-- --room-test=host|client --players=2|3|4

const MapModeConfigScript = preload("res://scripts/data/map_mode_config.gd")
const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

const SESSION_REL_PATH: String = ".room_test_session.json"
const WAIT_SEC: float = 120.0
const TEST_SEED: int = 424242

var _mode: String = ""
var _player_target: int = 2
var _mc: Node = null
var _exit_code: int = 0
var _session_path: String = ""


func _session_file_path() -> String:
    return ProjectSettings.globalize_path("res://%s" % SESSION_REL_PATH)


func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if args.is_empty():
        args = OS.get_cmdline_args()
    for arg in args:
        if arg.begins_with("--room-test="):
            _mode = arg.substr("--room-test=".length())
        elif arg.begins_with("--players="):
            _player_target = clampi(int(arg.substr("--players=".length())), 2, 4)
    if _mode != "host" and _mode != "client":
        push_error("用法: ... -- --room-test=host|client --players=2|3|4")
        get_tree().quit(1)
        return
    _session_path = _session_file_path()
    MapModeConfigScript.load_all()
    _mc = MatchControllerScript.new()
    _mc.name = "MatchController"
    add_child(_mc)
    _mc.add_to_group("match_controller")
    _mc.cinematic_requested.connect(func(_p: Dictionary) -> void: _mc.notify_cinematic_finished())
    await _run()
    get_tree().quit(_exit_code)


func _run() -> void:
    if _mode == "host":
        await _run_host()
    else:
        await _run_client()


func _run_host() -> void:
    print("[room-test:host] %d 人房…" % _player_target)
    if FileAccess.file_exists(_session_path):
        DirAccess.remove_absolute(_session_path)
    var created: Dictionary = RoomNetwork.create_room("dam", "normal", true, _player_target)
    if not created.get("ok", false):
        _fail("create_room: %s" % str(created.get("reason", "")))
        return
    var port: int = int(created.get("port", RoomNetwork.DEFAULT_PORT))
    var code: String = str(created.get("room_code", RoomNetwork.room_code))
    _write_session({"port": port, "code": code, "players": _player_target})
    print("[room-test:host] 房间 %s 端口 %d 目标 %d 人" % [code, port, _player_target])
    RoomNetwork.match_start_requested.connect(_on_match_start)
    var join_timeout: float = 15.0 + float(_player_target) * 8.0
    if not await _wait_until(func() -> bool: return RoomNetwork.get_connected_count() >= _player_target, join_timeout):
        _fail("等待 %d 人加入超时 (当前 %d)" % [_player_target, RoomNetwork.get_connected_count()])
        return
    RoomNetwork.set_local_ready(true)
    if not await _wait_until(func() -> bool: return RoomNetwork.get_ready_count() >= _player_target, 15.0):
        _fail("等待全员准备超时 ready=%d" % RoomNetwork.get_ready_count())
        return
    if not await _wait_until(
        func() -> bool: return _mc.get_phase() == GameConstants.MatchPhase.BID_WINDOW,
        WAIT_SEC,
    ):
        _fail("房主未进入出价阶段 phase=%d" % _mc.get_phase())
        return
    if _player_target > 1:
        if not await _wait_until(
            func() -> bool: return int(_mc.debug_bid_sync_snapshot().get("done", 0)) >= _player_target - 1,
            30.0,
        ):
            _fail("未收齐其他玩家出价 %s" % _mc.debug_bid_sync_snapshot())
            return
    await _wait_frames(5)
    var host_seat: int = RoomNetwork.get_local_seat()
    print("[room-test:host] 房主出价 seat=%d" % host_seat)
    RoomNetwork.request_bid_lock(host_seat, 120_000 + host_seat * 1000, false)
    if not await _wait_until(
        func() -> bool: return int(_mc.debug_bid_sync_snapshot().get("done", 0)) >= _player_target,
        20.0,
    ):
        _fail("未收齐全员出价 %s" % _mc.debug_bid_sync_snapshot())
        return
    if not await _wait_until(
        func() -> bool: return bool(_mc.debug_bid_sync_snapshot().get("all_locked", false)),
        15.0,
    ):
        _fail("all_locked=false %s" % _mc.debug_bid_sync_snapshot())
        return
    print("[room-test:host] 通过 %s" % _mc.debug_bid_sync_snapshot())
    _exit_code = 0


func _run_client() -> void:
    var session: Dictionary = await _wait_for_session(25.0)
    if session.is_empty():
        _fail("未读到 session 文件")
        return
    _player_target = clampi(int(session.get("players", 2)), 2, 4)
    print("[room-test:client] 加入 %d 人房 session=%s" % [_player_target, session])
    var join: Dictionary = RoomNetwork.join_room(
        str(session.get("code", "")),
        "127.0.0.1",
        int(session.get("port", RoomNetwork.DEFAULT_PORT)),
    )
    if not join.get("ok", false):
        _fail("join_room: %s" % str(join.get("reason", "")))
        return
    if not await _wait_until(func() -> bool: return RoomNetwork.is_in_room(), 10.0):
        _fail("未进入房间")
        return
    var join_timeout: float = 15.0 + float(_player_target) * 8.0
    if not await _wait_until(func() -> bool: return RoomNetwork.get_connected_count() >= _player_target, join_timeout):
        _fail("大厅未满员 %d/%d" % [RoomNetwork.get_connected_count(), _player_target])
        return
    RoomNetwork.match_start_requested.connect(_on_match_start)
    RoomNetwork.set_local_ready(true)
    if not await _wait_until(
        func() -> bool: return _mc.get_phase() == GameConstants.MatchPhase.BID_WINDOW,
        WAIT_SEC,
    ):
        _fail("未进入出价阶段 phase=%d" % _mc.get_phase())
        return
    await _wait_frames(5)
    var seat: int = RoomNetwork.get_local_seat()
    var amount: int = 95_000 + seat * 1000
    print("[room-test:client] seat=%d 出价 %d" % [seat, amount])
    RoomNetwork.request_bid_lock(seat, amount, false)
    if not await _wait_until(
        func() -> bool: return int(_mc.debug_bid_sync_snapshot().get("done", 0)) >= 1,
        10.0,
    ):
        _fail("本机未锁定出价 %s" % _mc.debug_bid_sync_snapshot())
        return
    if not await _wait_until(
        func() -> bool: return int(_mc.debug_bid_sync_snapshot().get("done", 0)) >= _player_target,
        30.0,
    ):
        _fail("未同步全员出价 %s" % _mc.debug_bid_sync_snapshot())
        return
    if not await _wait_until(
        func() -> bool: return bool(_mc.debug_bid_sync_snapshot().get("all_locked", false)),
        15.0,
    ):
        _fail("all_locked=false %s" % _mc.debug_bid_sync_snapshot())
        return
    print("[room-test:client] 通过 %s" % _mc.debug_bid_sync_snapshot())
    _exit_code = 0


func _on_match_start(payload: Dictionary) -> void:
    var assignments: Dictionary = payload.get("assignments", {})
    var seed: int = int(payload.get("seed", TEST_SEED))
    _mc.set_practice_mode(true)
    _mc.set_match_selection(str(payload.get("map_id", "dam")), str(payload.get("mode_id", "normal")), 1)
    _mc.configure_room_network(assignments, true)
    _mc.start_match(seed)


func _write_session(data: Dictionary) -> void:
    var f := FileAccess.open(_session_path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))


func _read_session() -> Dictionary:
    if not FileAccess.file_exists(_session_path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_session_path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _wait_for_session(timeout_sec: float) -> Dictionary:
    var elapsed: float = 0.0
    while elapsed < timeout_sec:
        var session: Dictionary = _read_session()
        if str(session.get("code", "")).length() == 4:
            return session
        await get_tree().create_timer(0.1).timeout
        elapsed += 0.1
    return {}


func _wait_until(cond: Callable, timeout_sec: float) -> bool:
    var elapsed: float = 0.0
    while elapsed < timeout_sec:
        if cond.call():
            return true
        await get_tree().create_timer(0.1).timeout
        elapsed += 0.1
    return false


func _wait_frames(n: int) -> void:
    for _i in n:
        await get_tree().process_frame


func _fail(reason: String) -> void:
    push_error("[room-test:%s x%d] FAIL: %s" % [_mode, _player_target, reason])
    _exit_code = 1
