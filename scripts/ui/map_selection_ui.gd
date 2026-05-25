class_name MapSelectionUI
extends Control

signal match_confirmed(map_id: String, mode_id: String)
signal selection_cancelled

const MapModeConfigScript = preload("res://scripts/data/map_mode_config.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")

## 横向卡片顺序（左→右）
const MAP_SCROLL_ORDER: PackedStringArray = ["dam", "valley", "aerospace", "prison"]
const CARD_SIZE := Vector2(200, 400)
const SCROLLBAR_GAP := 14
const RIGHT_PANEL_WIDTH := 320
## 难度越高颜色越醒目：简单 → 普通 → 困难
const MODE_DIFFICULTY_COLORS: Array[Color] = [
	Color(0.68, 0.86, 0.72, 1.0),
	Color(0.95, 0.82, 0.38, 1.0),
	Color(0.98, 0.42, 0.32, 1.0),
]
const MODE_BUTTON_HEIGHT := 44

var _human_silver: int = GameConstants.STARTING_SILVER
var _practice_mode: bool = false
var _practice_subtitle: String = "练习模式"
var _selected_map_id: String = ""
var _selected_mode_id: String = ""
var _map_scroll: ScrollContainer
var _map_row: HBoxContainer
var _map_cards: Dictionary = {}
var _detail_panel: PanelContainer
var _mode_list: VBoxContainer
var _feature_label: Label
var _ticket_value_label: Label
var _threshold_value_label: Label
var _threshold_hint_label: Label
var _confirm_btn: Button
var _mode_group: ButtonGroup
var _lobby_back_btn: Button


func _ready() -> void:
	MapModeConfigScript.load_all()
	_build_ui()
	FontUtilScript.apply_cjk_font(self, 14)
	_reset_selection()


func set_human_silver(amount: int) -> void:
	_human_silver = maxi(0, amount)
	_refresh_mode_list()
	_update_cost_display()
	_update_confirm_state()


func set_practice_mode(enabled: bool, subtitle: String = "") -> void:
	_practice_mode = enabled
	_practice_subtitle = subtitle if not subtitle.is_empty() else "练习模式"
	_update_cost_display()
	_update_confirm_state()


func reset_to_map_list() -> void:
	_reset_selection()


func _reset_selection() -> void:
	_selected_map_id = ""
	_selected_mode_id = ""
	for map_id in MAP_SCROLL_ORDER:
		var entry: Dictionary = MapModeConfigScript.get_map(map_id)
		if entry.is_empty():
			continue
		_selected_map_id = map_id
		var modes: Array = entry.get("modes", [])
		if not modes.is_empty():
			_selected_mode_id = str(modes[0].get("mode_id", ""))
		break
	_rebuild_map_cards()
	_refresh_detail_panel()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MenuBackgroundScript.apply(self, 0.36)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_top", 20)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_bottom", 20)
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	vbox.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	vbox.add_child(body)
	body.add_child(_build_map_scroll_area())
	body.add_child(_build_detail_panel())


func _build_header() -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = "选择目的地"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FontUtilScript.style_title_label(title, 30)
	row.add_child(title)
	_lobby_back_btn = UiCloseButtonScript.append_to_header(row, _on_back_to_lobby)
	_lobby_back_btn.tooltip_text = "返回主界面"
	return row


func _build_map_scroll_area() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", SCROLLBAR_GAP)
	var scroll_wrap := MarginContainer.new()
	scroll_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_wrap.add_theme_constant_override("margin_bottom", SCROLLBAR_GAP)
	_map_scroll = ScrollContainer.new()
	_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_scroll.follow_focus = false
	scroll_wrap.add_child(_map_scroll)
	wrap.add_child(scroll_wrap)
	_map_row = HBoxContainer.new()
	_map_row.add_theme_constant_override("separation", 16)
	_map_scroll.add_child(_map_row)
	return wrap


func _build_detail_panel() -> Control:
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(RIGHT_PANEL_WIDTH, 0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11, 0.72)
	sb.border_color = Color(0.28, 0.32, 0.4, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_detail_panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(col)
	var diff_title := Label.new()
	diff_title.text = "难度"
	FontUtilScript.style_title_label(diff_title, 20)
	col.add_child(diff_title)
	_mode_group = ButtonGroup.new()
	_mode_list = VBoxContainer.new()
	_mode_list.add_theme_constant_override("separation", 10)
	col.add_child(_mode_list)
	_feature_label = Label.new()
	_feature_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feature_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
	_feature_label.add_theme_font_size_override("font_size", 13)
	col.add_child(_feature_label)
	_ticket_value_label = _add_money_block(col, "入场券")
	_threshold_value_label = _add_money_block(col, "门槛要求")
	_threshold_hint_label = Label.new()
	_threshold_hint_label.text = ""
	_threshold_hint_label.visible = false
	_threshold_hint_label.add_theme_font_size_override("font_size", 13)
	_threshold_hint_label.add_theme_color_override("font_color", Color(0.82, 0.38, 0.32))
	col.add_child(_threshold_hint_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_confirm_btn = Button.new()
	_confirm_btn.text = "确认选择"
	_confirm_btn.focus_mode = Control.FOCUS_NONE
	_style_confirm_button(_confirm_btn)
	_confirm_btn.pressed.connect(_on_confirm)
	col.add_child(_confirm_btn)
	return _detail_panel


func _add_money_block(parent: VBoxContainer, title: String) -> Label:
	var block_title := Label.new()
	block_title.text = title
	FontUtilScript.style_title_label(block_title, 18)
	parent.add_child(block_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(48, 48)
	row.add_child(icon_wrap)
	icon_wrap.add_child(UiMoneyIconScript.make_texture_rect(Vector2(40, 40)))
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.55))
	row.add_child(value_label)
	return value_label


func _rebuild_map_cards() -> void:
	for c in _map_row.get_children():
		c.queue_free()
	_map_cards.clear()
	for map_id in MAP_SCROLL_ORDER:
		var map_entry: Dictionary = MapModeConfigScript.get_map(map_id)
		if map_entry.is_empty():
			continue
		var card := _build_map_card(map_entry)
		_map_row.add_child(card)
		_map_cards[map_id] = card
	_update_card_highlights()


func _build_map_card(map_entry: Dictionary) -> PanelContainer:
	var map_id: String = str(map_entry.get("map_id", ""))
	var map_name: String = str(map_entry.get("map_name", map_id))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_map_card_input.bind(map_id))
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("margin_left", 2)
	inner.add_theme_constant_override("margin_right", 2)
	inner.add_theme_constant_override("margin_top", 2)
	inner.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(inner)
	var stack := Control.new()
	stack.custom_minimum_size = CARD_SIZE - Vector2(4, 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(stack)
	var preview := TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img_path: String = str(map_entry.get("preview_image", ""))
	if not img_path.is_empty() and ResourceLoader.exists(img_path):
		preview.texture = load(img_path) as Texture2D
	else:
		preview.modulate = Color(0.15, 0.18, 0.22)
	stack.add_child(preview)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -72
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(shade)
	var name_l := Label.new()
	name_l.text = map_name
	name_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_l.offset_top = -40
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontUtilScript.apply_body_font(name_l)
	stack.add_child(name_l)
	_apply_card_style(panel, map_id == _selected_map_id)
	return panel


func _apply_card_style(panel: PanelContainer, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.4)
	if selected:
		sb.border_color = Color(0.92, 0.94, 0.98, 0.95)
		sb.set_border_width_all(2)
	else:
		sb.border_color = Color(0.2, 0.24, 0.3, 0.5)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)


func _on_map_card_input(event: InputEvent, map_id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_map(map_id)


func _select_map(map_id: String) -> void:
	if map_id == _selected_map_id:
		return
	_selected_map_id = map_id
	var entry: Dictionary = MapModeConfigScript.get_map(map_id)
	var modes: Array = entry.get("modes", [])
	if modes.is_empty():
		_selected_mode_id = ""
	else:
		_selected_mode_id = str(modes[0].get("mode_id", ""))
	_update_card_highlights()
	_refresh_detail_panel()


func _update_card_highlights() -> void:
	for map_id in _map_cards:
		var panel: PanelContainer = _map_cards[map_id] as PanelContainer
		if panel:
			_apply_card_style(panel, map_id == _selected_map_id)


func _refresh_detail_panel() -> void:
	_refresh_mode_list()
	var entry: Dictionary = MapModeConfigScript.get_map(_selected_map_id)
	var feat: String = str(entry.get("feature_text", ""))
	_feature_label.text = feat
	_update_cost_display()
	_update_confirm_state()


func _refresh_mode_list() -> void:
	for c in _mode_list.get_children():
		c.queue_free()
	var entry: Dictionary = MapModeConfigScript.get_map(_selected_map_id)
	var modes: Array = entry.get("modes", [])
	for i in modes.size():
		_mode_list.add_child(_build_mode_button(modes[i], i))
	call_deferred("_refresh_mode_button_visuals")


func _difficulty_tier(mode: Dictionary, index: int) -> int:
	var mode_id: String = str(mode.get("mode_id", ""))
	match mode_id:
		"normal":
			return 0
		"confidential":
			return 1
		"top_secret":
			return 2
	var mode_name: String = str(mode.get("mode_name", ""))
	match mode_name:
		"简单":
			return 0
		"普通":
			return 1
		"困难":
			return 2
	return clampi(index, 0, MODE_DIFFICULTY_COLORS.size() - 1)


func _difficulty_color(tier: int) -> Color:
	var idx: int = clampi(tier, 0, MODE_DIFFICULTY_COLORS.size() - 1)
	return MODE_DIFFICULTY_COLORS[idx]


func _build_mode_button(mode: Dictionary, index: int) -> Button:
	var mode_id: String = str(mode.get("mode_id", ""))
	var mode_name: String = str(mode.get("mode_name", mode_id))
	var tier: int = _difficulty_tier(mode, index)
	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_group = _mode_group
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = mode_name
	btn.custom_minimum_size = Vector2(0, MODE_BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.set_meta("mode_id", mode_id)
	btn.set_meta("tier", tier)
	btn.set_pressed_no_signal(mode_id == _selected_mode_id)
	btn.pressed.connect(_on_mode_selected.bind(mode_id))
	_apply_mode_button_style(btn, tier, btn.button_pressed)
	return btn


func _apply_mode_button_style(btn: Button, tier: int, selected: bool) -> void:
	var accent: Color = _difficulty_color(tier)
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(6)
	normal.set_border_width_all(2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	if selected:
		normal.bg_color = Color(accent.r, accent.g, accent.b, 0.32)
		normal.border_color = accent
		var text_on: Color = accent.lightened(0.22)
		btn.add_theme_color_override("font_color", text_on)
		btn.add_theme_color_override("font_pressed_color", text_on)
		btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	else:
		normal.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
		normal.border_color = Color(accent.r, accent.g, accent.b, 0.62)
		btn.add_theme_color_override("font_color", accent)
		btn.add_theme_color_override("font_hover_color", accent.lightened(0.18))
		btn.add_theme_color_override("font_pressed_color", accent.lightened(0.1))
	var hover := normal.duplicate() as StyleBoxFlat
	if selected:
		hover.bg_color = Color(accent.r, accent.g, accent.b, 0.42)
	else:
		hover.bg_color = Color(accent.r, accent.g, accent.b, 0.22)
		hover.border_color = accent.lightened(0.12)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(accent.r * 0.75, accent.g * 0.75, accent.b * 0.75, 0.45)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_font_size_override("font_size", 17)
	FontUtilScript.apply_body_font(btn)


func _refresh_mode_button_visuals() -> void:
	for child in _mode_list.get_children():
		if child is Button:
			var btn: Button = child as Button
			var tier: int = int(btn.get_meta("tier", 0))
			_apply_mode_button_style(btn, tier, btn.button_pressed)


func _on_mode_selected(mode_id: String) -> void:
	_selected_mode_id = mode_id
	_refresh_mode_button_visuals()
	_update_cost_display()
	_update_confirm_state()


func _update_cost_display() -> void:
	var mode: Dictionary = MapModeConfigScript.get_mode(_selected_map_id, _selected_mode_id)
	if _practice_mode:
		_ticket_value_label.text = "%s · 免门票" % _practice_subtitle
		_ticket_value_label.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
		_threshold_value_label.text = "%s · 无门槛" % _practice_subtitle
		_threshold_value_label.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
		_threshold_hint_label.visible = false
		_threshold_hint_label.text = ""
		return
	var ticket: int = int(mode.get("ticket", 0))
	var threshold: int = int(mode.get("entry_threshold", 0))
	var have: int = _human_silver
	var ticket_ok: bool = have >= ticket
	_ticket_value_label.text = "%s / %s" % [
		MatchControllerScript._format_silver(have),
		MatchControllerScript._format_silver(ticket),
	]
	_ticket_value_label.add_theme_color_override(
		"font_color",
		_color_ok() if ticket_ok else _color_fail(),
	)
	if threshold <= 0:
		_threshold_value_label.text = "%s / 无" % MatchControllerScript._format_silver(have)
		_threshold_value_label.add_theme_color_override("font_color", _color_ok())
		_threshold_hint_label.visible = false
		_threshold_hint_label.text = ""
	else:
		var threshold_ok: bool = have >= threshold
		var have_text: String = (
			MatchControllerScript._format_silver(have)
			if threshold_ok
			else "不足"
		)
		_threshold_value_label.text = "%s / %s" % [
			have_text,
			MatchControllerScript._format_silver(threshold),
		]
		_threshold_value_label.add_theme_color_override(
			"font_color",
			_color_ok() if threshold_ok else _color_fail(),
		)
		if threshold_ok:
			_threshold_hint_label.visible = false
			_threshold_hint_label.text = ""
		else:
			_threshold_hint_label.visible = true
			_threshold_hint_label.text = "门槛不足，无法确认进入"


func _color_ok() -> Color:
	return Color(0.88, 0.84, 0.55)


func _color_fail() -> Color:
	return Color(0.82, 0.38, 0.32)


func _style_confirm_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiButtonStyleScript.apply_centered_action(btn, Color(0.95, 0.97, 1.0), 18, 56)


func _update_confirm_state() -> void:
	var mode: Dictionary = MapModeConfigScript.get_mode(_selected_map_id, _selected_mode_id)
	if mode.is_empty():
		_confirm_btn.disabled = true
		return
	if _practice_mode:
		_confirm_btn.disabled = false
		return
	var threshold: int = int(mode.get("entry_threshold", 0))
	var ticket: int = int(mode.get("ticket", 0))
	_confirm_btn.disabled = _human_silver < threshold or _human_silver < ticket


func _on_confirm() -> void:
	if _selected_map_id.is_empty() or _selected_mode_id.is_empty():
		return
	match_confirmed.emit(_selected_map_id, _selected_mode_id)
	hide()


func _on_back_to_lobby() -> void:
	selection_cancelled.emit()
