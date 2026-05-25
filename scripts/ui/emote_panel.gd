class_name EmotePanel
extends PanelContainer
## 临时表情选择面板

signal emote_picked(emoji: String, caption: String)

const EMOTES: Array[Dictionary] = [
	{"emoji": "😀", "caption": "大笑"},
	{"emoji": "😭", "caption": "流泪"},
	{"emoji": "😘", "caption": "爱你"},
	{"emoji": "😱", "caption": "惊恐"},
	{"emoji": "👌", "caption": "好的"},
]

var _anchor: Control = null


func _init() -> void:
	custom_minimum_size = Vector2(168, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	sb.border_color = Color(0.28, 0.34, 0.45, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	for entry in EMOTES:
		var btn := Button.new()
		btn.text = "%s  %s" % [entry["emoji"], entry["caption"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_emote_pressed.bind(str(entry["emoji"]), str(entry["caption"])))
		_style_emote_button(btn)
		vbox.add_child(btn)
	hide()


func toggle_near(anchor: Control) -> void:
	if visible and _anchor == anchor:
		hide()
		return
	_anchor = anchor
	open_near(anchor)


func open_near(anchor: Control) -> void:
	_anchor = anchor
	var anchor_rect: Rect2 = anchor.get_global_rect()
	var parent_ctrl: Control = get_parent() as Control
	if parent_ctrl == null:
		show()
		return
	var local_origin: Vector2 = parent_ctrl.get_global_transform_with_canvas().affine_inverse() * anchor_rect.position
	var panel_h: float = maxf(get_combined_minimum_size().y, 200.0)
	var y: float = local_origin.y - panel_h - 8.0
	if y < 8.0:
		y = local_origin.y + anchor_rect.size.y + 8.0
	position = Vector2(local_origin.x, y)
	show()
	move_to_front()


func _on_emote_pressed(emoji: String, caption: String) -> void:
	emote_picked.emit(emoji, caption)
	hide()


func _style_emote_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22, 1.0)
	sb.border_color = Color(0.25, 0.3, 0.4, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.2, 0.24, 0.32, 1.0)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_font_size_override("font_size", 15)
