class_name EmoteBubble
extends PanelContainer
## 头像右侧表情气泡（临时）

const FontUtilScript = preload("res://scripts/ui/font_util.gd")

const DISPLAY_SECONDS: float = 3.0
const AVATAR_GAP: float = 6.0

var _emoji_label: Label
var _caption_label: Label
var _hide_timer: SceneTreeTimer = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 130
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.92)
	sb.border_color = Color(0.22, 0.28, 0.38, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_emoji_label = Label.new()
	_emoji_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_emoji_label)
	_caption_label = Label.new()
	_caption_label.add_theme_font_size_override("font_size", 16)
	_caption_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	row.add_child(_caption_label)
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func display_beside_avatar(avatar: Control, host: Control, emoji: String, caption: String) -> void:
	if avatar == null or host == null:
		return
	_emoji_label.text = emoji
	_caption_label.text = caption
	if _hide_timer != null and is_instance_valid(_hide_timer):
		_hide_timer.timeout.disconnect(_on_hide_timeout)
	_hide_timer = null
	if get_parent() != host:
		if get_parent():
			get_parent().remove_child(self)
		host.add_child(self)
	show()
	call_deferred("_reposition_beside", avatar, host)
	_hide_timer = get_tree().create_timer(DISPLAY_SECONDS)
	_hide_timer.timeout.connect(_on_hide_timeout, CONNECT_ONE_SHOT)


## 兼容旧调用
func display_above(avatar: Control, host: Control, emoji: String, caption: String) -> void:
	display_beside_avatar(avatar, host, emoji, caption)


func _reposition_beside(avatar: Control, host: Control) -> void:
	if avatar == null or host == null or not is_instance_valid(avatar):
		return
	var avatar_rect: Rect2 = avatar.get_global_rect()
	var host_rect: Rect2 = host.get_global_rect()
	var local_origin: Vector2 = avatar_rect.position - host_rect.position
	var bubble_size: Vector2 = get_combined_minimum_size()
	if bubble_size.x < 8.0:
		bubble_size = size
	position = Vector2(
		local_origin.x + avatar_rect.size.x + AVATAR_GAP,
		local_origin.y + (avatar_rect.size.y - bubble_size.y) * 0.5,
	)
	move_to_front()
	call_deferred("_reposition_beside_finalize", avatar, host)


func _reposition_beside_finalize(avatar: Control, host: Control) -> void:
	if avatar == null or host == null or not is_instance_valid(avatar):
		return
	var avatar_rect: Rect2 = avatar.get_global_rect()
	var host_rect: Rect2 = host.get_global_rect()
	var local_origin: Vector2 = avatar_rect.position - host_rect.position
	var bubble_size: Vector2 = size
	if bubble_size.x < 8.0:
		bubble_size = get_combined_minimum_size()
	position = Vector2(
		local_origin.x + avatar_rect.size.x + AVATAR_GAP,
		local_origin.y + (avatar_rect.size.y - bubble_size.y) * 0.5,
	)


func _on_hide_timeout() -> void:
	hide()
