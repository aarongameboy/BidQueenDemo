extends Node
## 大厅 / 地图 BGM（assets/music 下 JY、AL、CA、CS）

const TRACK_PATHS: Dictionary = {
    "JY": "res://assets/music/JY.mp3",
    "AL": "res://assets/music/AL.mp3",
    "CA": "res://assets/music/CA.mp3",
    "CS": "res://assets/music/CS.mp3",
}

## map_id -> 曲目（银雾修道院对应配置中的 valley）
const MAP_TRACK: Dictionary = {
    "dam": "JY",
    "valley": "AL",
    "aerospace": "CA",
    "prison": "CS",
}

const LOBBY_TRACK: String = "JY"

var _player: AudioStreamPlayer
var _current_track: String = ""
var _stream_cache: Dictionary = {}


func _ready() -> void:
    _player = AudioStreamPlayer.new()
    _player.bus = &"Master"
    _player.finished.connect(_on_player_finished)
    add_child(_player)
    play_lobby()


func play_lobby() -> void:
    play_track(LOBBY_TRACK)


func play_for_map(map_id: String) -> void:
    var track: String = str(MAP_TRACK.get(map_id, LOBBY_TRACK))
    play_track(track)


func play_track(track_key: String) -> void:
    if track_key.is_empty():
        return
    if track_key == _current_track and _player.playing:
        return
    var stream: AudioStream = _load_stream(track_key)
    if stream == null:
        push_warning("BgmPlayer: missing track %s" % track_key)
        return
    _current_track = track_key
    _player.stream = stream
    _player.play()


func stop() -> void:
    _player.stop()
    _current_track = ""


func _load_stream(track_key: String) -> AudioStream:
    if _stream_cache.has(track_key):
        return _stream_cache[track_key] as AudioStream
    var path: String = str(TRACK_PATHS.get(track_key, ""))
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var loaded: Resource = load(path)
    if loaded is AudioStream:
        _stream_cache[track_key] = loaded
        return loaded as AudioStream
    return null


func _on_player_finished() -> void:
    if _player.stream != null:
        _player.play()
