extends Node
## 全界面 BGM 路由（config/audio_screens.json + assets/music）

const CONFIG_PATH := "res://config/audio_screens.json"

var _player: AudioStreamPlayer
var _current_track: String = ""
var _current_screen: String = ""
var _stream_cache: Dictionary = {}
var _config: Dictionary = {}
var _base_volume_db: float = 0.0
var _ducked: bool = false
var _duck_db: float = -12.0


func _ready() -> void:
	_load_config()
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	play_for_screen("lobby")


func play_lobby() -> void:
	play_for_screen("lobby")


func play_for_map(map_id: String) -> void:
	play_for_screen("match", {"map_id": map_id})


func play_for_screen(screen_id: String, context: Dictionary = {}) -> void:
	if not _config_loaded():
		play_track(_fallback_track_for_screen(screen_id, context))
		return
	var screens: Dictionary = _config.get("screens", {})
	if not screens.has(screen_id):
		push_warning("BgmPlayer: unknown screen %s" % screen_id)
		return
	var screen_cfg: Dictionary = screens[screen_id]
	if screen_id == "cinematic":
		_apply_duck(true, float(screen_cfg.get("duck_db", _duck_db)))
		return
	_apply_duck(false)
	var track_key: String = _resolve_track_key(screen_id, screen_cfg, context)
	if track_key.is_empty():
		return
	_base_volume_db = float(screen_cfg.get("volume_db", 0.0))
	_current_screen = screen_id
	play_track(track_key)


func set_ducked(ducked: bool, duck_db: float = -12.0) -> void:
	_duck_db = duck_db
	_apply_duck(ducked)


func play_track(track_key: String) -> void:
	if track_key.is_empty():
		return
	if track_key == _current_track and _player.playing:
		_apply_volume()
		return
	var stream: AudioStream = _load_stream(track_key)
	if stream == null:
		push_warning("BgmPlayer: missing track %s" % track_key)
		return
	_current_track = track_key
	_player.stream = stream
	_apply_volume()
	_player.play()


func stop() -> void:
	_player.stop()
	_current_track = ""
	_current_screen = ""


func _load_config() -> void:
	_config.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("BgmPlayer: missing %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BgmPlayer: invalid audio config")
		return
	_config = parsed


func _config_loaded() -> bool:
	return not _config.is_empty()


func _resolve_track_key(screen_id: String, screen_cfg: Dictionary, context: Dictionary) -> String:
	if bool(screen_cfg.get("track_from_map", false)):
		var map_id: String = str(context.get("map_id", ""))
		var map_tracks: Dictionary = _config.get("map_tracks", {})
		return str(map_tracks.get(map_id, "JY"))
	return str(screen_cfg.get("track", ""))


func _fallback_track_for_screen(screen_id: String, context: Dictionary) -> String:
	const LEGACY_MAP_TRACK: Dictionary = {
		"dam": "JY",
		"valley": "AL",
		"aerospace": "CA",
		"prison": "CS",
	}
	if screen_id == "match":
		return str(LEGACY_MAP_TRACK.get(str(context.get("map_id", "")), "JY"))
	return "JY"


func _load_stream(track_key: String) -> AudioStream:
	if _stream_cache.has(track_key):
		return _stream_cache[track_key] as AudioStream
	var tracks: Dictionary = _config.get("tracks", {})
	var track_entry: Variant = tracks.get(track_key, null)
	var path: String = ""
	if typeof(track_entry) == TYPE_DICTIONARY:
		path = str(track_entry.get("path", ""))
	elif typeof(track_entry) == TYPE_STRING:
		path = track_entry
	if path.is_empty():
		path = _legacy_track_path(track_key)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded is AudioStream:
		_stream_cache[track_key] = loaded
		return loaded as AudioStream
	return null


func _legacy_track_path(track_key: String) -> String:
	const LEGACY: Dictionary = {
		"JY": "res://assets/music/JY.mp3",
		"AL": "res://assets/music/AL.mp3",
		"CA": "res://assets/music/CA.mp3",
		"CS": "res://assets/music/CS.mp3",
	}
	return str(LEGACY.get(track_key, ""))


func _apply_duck(ducked: bool, duck_db: float = -12.0) -> void:
	_ducked = ducked
	if ducked:
		_duck_db = duck_db
	_apply_volume()


func _apply_volume() -> void:
	var volume: float = _base_volume_db
	if _ducked:
		volume += _duck_db
	_player.volume_db = volume


func _on_player_finished() -> void:
	if _player.stream != null:
		_player.play()
