class_name ItemQualityFrame
extends RefCounted
## 道具品质底框图（white / green / blue / purple / gold / red）

const FRAME_DIR: String = "res://assets/icons/items/"
const QUALITY_KEYS: PackedStringArray = [
	"white", "green", "blue", "purple", "gold", "red",
]

static var _texture_cache: Dictionary = {}


static func get_frame_path(quality_enum: int) -> String:
	var idx: int = clampi(quality_enum, 0, QUALITY_KEYS.size() - 1)
	return "%s%s.png" % [FRAME_DIR, QUALITY_KEYS[idx]]


static func get_frame_path_by_name(quality_name: String) -> String:
	var key: String = quality_name.strip_edges().to_lower()
	var idx: int = QUALITY_KEYS.find(key)
	if idx < 0:
		idx = 0
	return get_frame_path(idx)


static func load_texture(quality_enum: int) -> Texture2D:
	if _texture_cache.has(quality_enum):
		return _texture_cache[quality_enum] as Texture2D
	var path: String = get_frame_path(quality_enum)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	_texture_cache[quality_enum] = tex
	return tex


static func make_frame_rect(quality_enum: int) -> TextureRect:
	var frame := TextureRect.new()
	frame.name = "QualityFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = load_texture(quality_enum)
	return frame


static func transparent_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(0)
	return sb
