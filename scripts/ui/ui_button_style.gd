class_name UiButtonStyle
extends RefCounted
## 通用按钮样式：扁平九宫格 + 对称内边距，保证运行期文字垂直居中

const BUTTON_PATH: String = "res://assets/ui/button.png"
const PATCH_MARGIN: int = 16
const ACTION_BTN_SIZE: Vector2 = Vector2(200, 52)
const ACTION_BTN_TEXT_COLOR: Color = Color(0.95, 0.97, 1.0)
const ACTION_BTN_FONT_SIZE: int = 18
const DEFAULT_BTN_HEIGHT: int = 44

static var _texture: Texture2D


static func get_texture() -> Texture2D:
	if _texture != null:
		return _texture
	if ResourceLoader.exists(BUTTON_PATH):
		_texture = load(BUTTON_PATH) as Texture2D
	return _texture


## 保留底图九宫格（特殊场景）；默认请用 apply / apply_centered_action
static func make_box(modulate: Color = Color.WHITE) -> StyleBox:
	var tex: Texture2D = get_texture()
	if tex == null:
		return _fallback_flat(modulate)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = PATCH_MARGIN
	sb.texture_margin_top = PATCH_MARGIN
	sb.texture_margin_right = PATCH_MARGIN
	sb.texture_margin_bottom = PATCH_MARGIN
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.modulate_color = modulate
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func apply(btn: Button, font_color: Color = Color(0.92, 0.94, 0.98), font_size: int = -1) -> void:
	var fs: int = _resolve_font_size(btn, font_size)
	var h: int = _resolve_style_height(btn)
	apply_centered_action(btn, font_color, fs, h)


static func apply_primary(btn: Button, font_size: int = -1) -> void:
	apply(btn, Color(0.96, 0.88, 0.58), font_size)


static func apply_success(btn: Button, font_size: int = -1) -> void:
	apply(btn, Color(0.88, 0.98, 0.78), font_size)


static func apply_danger(btn: Button, font_size: int = -1) -> void:
	apply(btn, Color(1.0, 0.82, 0.82), font_size)


## 扁平底图 + 水平/垂直居中文字（避免九宫格底图导致文字偏上）
static func apply_centered_action(
	btn: Button,
	font_color: Color = Color(0.95, 0.97, 1.0),
	font_size: int = 18,
	min_height: int = -1,
) -> void:
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.flat = false
	var h: int = min_height if min_height > 0 else _resolve_style_height(btn)
	var fs: int = _resolve_font_size(btn, font_size)
	var pad_v: int = _compute_vertical_pad(h, fs)
	_set_centered_styleboxes(btn, pad_v)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color.darkened(0.08))
	btn.add_theme_color_override("font_disabled_color", Color(0.42, 0.45, 0.5))
	if fs > 0:
		btn.add_theme_font_size_override("font_size", fs)


## 结算领取 / 重新游戏等固定宽主操作按钮
static func apply_settlement_action(btn: Button) -> void:
	btn.custom_minimum_size = ACTION_BTN_SIZE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_centered_action(btn, ACTION_BTN_TEXT_COLOR, ACTION_BTN_FONT_SIZE, int(ACTION_BTN_SIZE.y))


static func refresh_centered(btn: Button) -> void:
	if not btn.is_inside_tree():
		return
	var fs: int = _resolve_font_size(btn, -1)
	var font_color: Color = btn.get_theme_color("font_color")
	var h: int = _resolve_style_height(btn)
	var pad_v: int = _compute_vertical_pad(h, fs)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_set_centered_styleboxes(btn, pad_v)


static func _resolve_style_height(btn: Button) -> int:
	var min_h: int = int(btn.custom_minimum_size.y)
	var size_h: int = int(btn.size.y)
	if min_h > 0 and size_h > min_h + 1:
		return size_h
	if min_h > 0:
		return min_h
	if size_h > 0:
		return size_h
	return DEFAULT_BTN_HEIGHT


static func _resolve_font_size(btn: Button, font_size: int) -> int:
	if font_size > 0:
		return font_size
	if btn.has_theme_font_size_override("font_size"):
		var themed: int = btn.get_theme_font_size("font_size")
		if themed > 0:
			return themed
	return 14


static func _compute_vertical_pad(height: int, font_size: int) -> int:
	var border: int = 2
	var inner: int = maxi(height - border, font_size + 4)
	return maxi(6, int((inner - font_size) * 0.5))


static func _set_centered_styleboxes(btn: Button, pad_v: int) -> void:
	var specs: Array = [
		[&"normal", Color(1, 1, 1, 1)],
		[&"hover", Color(1.08, 1.08, 1.12, 1)],
		[&"pressed", Color(0.88, 0.88, 0.92, 1)],
		[&"disabled", Color(0.58, 0.6, 0.64, 0.8)],
		[&"focus", Color(1.04, 1.04, 1.08, 1)],
	]
	for spec in specs:
		btn.add_theme_stylebox_override(spec[0], _make_centered_flat_box(spec[1], pad_v))


static func _make_centered_flat_box(modulate: Color, pad_v: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22) * modulate
	sb.border_color = Color(0.28, 0.32, 0.4, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func _fallback_flat(modulate: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22) * modulate
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
