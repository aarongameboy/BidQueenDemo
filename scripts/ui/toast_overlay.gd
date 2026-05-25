class_name ToastOverlay
extends Control
## 屏幕顶部短暂提示

const FontUtilScript = preload("res://scripts/ui/font_util.gd")

var _panel: PanelContainer
var _label: Label
var _hide_timer: Timer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 400
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_top = 72
	_panel.offset_left = -180
	_panel.offset_right = 180
	_panel.offset_bottom = 120
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	sb.border_color = Color(0.85, 0.35, 0.35, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.75))
	_panel.add_child(_label)
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_on_hide_timeout)
	add_child(_hide_timer)
	FontUtilScript.apply_cjk_font(self, 16)


func show_message(text: String, duration_sec: float = 2.2) -> void:
	_label.text = text
	_panel.visible = true
	_hide_timer.stop()
	_hide_timer.start(duration_sec)


func _on_hide_timeout() -> void:
	_panel.visible = false
