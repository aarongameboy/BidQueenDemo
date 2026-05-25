class_name LeaderboardUI
extends Control

signal closed

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")
const LeaderboardConfigScript = preload("res://scripts/data/leaderboard_config.gd")
const LeaderboardServiceScript = preload("res://scripts/data/leaderboard_service.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const UiTextureCacheScript = preload("res://scripts/ui/ui_texture_cache.gd")

const COLOR_ACCENT: Color = Color(0.88, 0.95, 0.38, 1.0)
const COLOR_VALUE: Color = Color(0.42, 0.92, 0.55, 1.0)
const COLOR_SELF_BG: Color = Color(0.12, 0.28, 0.52, 0.55)
const COLOR_TOP1: Color = Color(0.95, 0.82, 0.35, 1.0)
const COLOR_TOP2: Color = Color(0.78, 0.82, 0.88, 1.0)
const COLOR_TOP3: Color = Color(0.82, 0.58, 0.38, 1.0)

var _period_id: String = "daily"
var _category_id: String = "total_profit"
var _period_group: ButtonGroup
var _period_underlines: Dictionary = {}
var _category_buttons: Array[Button] = []
var _list_box: VBoxContainer
var _self_row_host: PanelContainer
var _metric_header: Label


func _ready() -> void:
	LeaderboardConfigScript.load_all()
	_build_shell()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func open() -> void:
	_refresh_board()
	show()
	move_to_front()


func close() -> void:
	hide()
	closed.emit()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTextureCacheScript.add_shop_background_layers(self)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 18)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 18)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	root.add_child(vbox)
	vbox.add_child(_build_top_bar())
	vbox.add_child(_build_period_tabs())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	vbox.add_child(body)
	body.add_child(_build_category_sidebar())
	body.add_child(_build_main_panel())


func _build_top_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)
	var star := Label.new()
	star.text = "★"
	star.add_theme_font_size_override("font_size", 22)
	star.add_theme_color_override("font_color", COLOR_ACCENT)
	title_row.add_child(star)
	var title := Label.new()
	title.text = "排行榜"
	FontUtilScript.style_title_label(title, 28)
	title_row.add_child(title)
	UiCloseButtonScript.append_to_header(row, close)
	return row


func _build_period_tabs() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	_period_group = ButtonGroup.new()
	for period_row in LeaderboardConfigScript.get_periods():
		if typeof(period_row) != TYPE_DICTIONARY:
			continue
		var pid: String = str(period_row.get("id", ""))
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 4)
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _period_group
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		btn.text = str(period_row.get("label", pid))
		btn.add_theme_font_size_override("font_size", 16)
		btn.set_pressed_no_signal(pid == _period_id)
		btn.pressed.connect(_on_period_pressed.bind(pid, btn))
		wrap.add_child(btn)
		var underline := ColorRect.new()
		underline.custom_minimum_size = Vector2(48, 3)
		underline.color = COLOR_ACCENT if pid == _period_id else Color(0, 0, 0, 0)
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		underline.name = "Underline"
		wrap.add_child(underline)
		_period_underlines[pid] = underline
		row.add_child(wrap)
	return row


func _on_period_pressed(period_id: String, _btn: Button) -> void:
	_period_id = period_id
	for pid in _period_underlines:
		var line: ColorRect = _period_underlines[pid] as ColorRect
		if line:
			line.color = COLOR_ACCENT if pid == _period_id else Color(0, 0, 0, 0)
	_refresh_board()


func _build_category_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.88)
	sb.border_color = Color(0.22, 0.26, 0.34, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	_category_buttons.clear()
	for cat_row in LeaderboardConfigScript.get_categories():
		if typeof(cat_row) != TYPE_DICTIONARY:
			continue
		var cid: String = str(cat_row.get("id", ""))
		var btn := Button.new()
		btn.text = str(cat_row.get("label", cid))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(0, 36)
		btn.set_meta("category_id", cid)
		btn.pressed.connect(_on_category_pressed.bind(cid))
		_apply_category_style(btn, cid == _category_id)
		col.add_child(btn)
		_category_buttons.append(btn)
	return panel


func _on_category_pressed(category_id: String) -> void:
	_category_id = category_id
	for btn in _category_buttons:
		_apply_category_style(btn, str(btn.get_meta("category_id", "")) == _category_id)
	_refresh_board()


func _apply_category_style(btn: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 10
	normal.content_margin_right = 8
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	if selected:
		normal.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.22)
		normal.border_color = COLOR_ACCENT
		normal.set_border_width_all(1)
		btn.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		normal.bg_color = Color(0.1, 0.11, 0.14, 0.5)
		btn.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal.duplicate())
	btn.add_theme_stylebox_override("pressed", normal.duplicate())


func _build_main_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.75)
	sb.border_color = Color(0.22, 0.26, 0.34, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var header_block := VBoxContainer.new()
	header_block.add_theme_constant_override("separation", 6)
	header_block.add_child(_build_table_header())
	var header_line := ColorRect.new()
	header_line.custom_minimum_size = Vector2(0, 1)
	header_line.color = Color(0.28, 0.32, 0.4, 0.7)
	header_block.add_child(header_line)
	col.add_child(header_block)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 2)
	scroll.add_child(_list_box)
	_self_row_host = PanelContainer.new()
	_self_row_host.visible = false
	col.add_child(_self_row_host)
	return panel


func _build_table_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var rank_h := _header_label("排名", 56)
	row.add_child(rank_h)
	var av_h := _header_label("头像", 52)
	row.add_child(av_h)
	var name_h := _header_label("名称", 0)
	name_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_h)
	_metric_header = _header_label("总竞拍利润", 120)
	_metric_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_metric_header)
	return row


func _header_label(text: String, min_w: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if min_w > 0:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	return lbl


func _refresh_board() -> void:
	var board: Dictionary = LeaderboardServiceScript.build_board(_period_id, _category_id, "all")
	var category: Dictionary = board.get("category", {})
	var cat_label: String = str(category.get("label", ""))
	if _metric_header:
		_metric_header.text = cat_label
	for c in _list_box.get_children():
		c.queue_free()
	for row in board.get("entries", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		_list_box.add_child(_build_entry_row(row, false))
	var self_entry: Dictionary = board.get("self_entry", {})
	_build_self_row(self_entry)


func _build_self_row(entry: Dictionary) -> void:
	for c in _self_row_host.get_children():
		c.queue_free()
	if entry.is_empty():
		_self_row_host.visible = false
		return
	_self_row_host.visible = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_SELF_BG
	sb.set_corner_radius_all(4)
	_self_row_host.add_theme_stylebox_override("panel", sb)
	_self_row_host.add_child(_build_entry_row(entry, true))


func _build_entry_row(entry: Dictionary, is_self: bool) -> Control:
	if is_self:
		return _make_row_content(entry)
	var panel := PanelContainer.new()
	var row_inner := _make_row_content(entry)
	panel.add_child(row_inner)
	if int(entry.get("rank", 99)) % 2 == 0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.09, 0.12, 0.45)
		panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_row_content(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 8)
	var rank: int = int(entry.get("rank", 0))
	row.add_child(_build_rank_cell(rank))
	row.add_child(_build_avatar_cell(str(entry.get("character_id", ""))))
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 2)
	var name_l := Label.new()
	name_l.text = str(entry.get("display_name", ""))
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	name_col.add_child(name_l)
	var title: String = str(entry.get("title", ""))
	if not title.is_empty():
		var sub := Label.new()
		sub.text = title
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		name_col.add_child(sub)
	row.add_child(name_col)
	var val_row := HBoxContainer.new()
	val_row.custom_minimum_size = Vector2(120, 0)
	val_row.alignment = BoxContainer.ALIGNMENT_CENTER
	val_row.add_theme_constant_override("separation", 4)
	val_row.add_child(UiMoneyIconScript.make_texture_rect(Vector2(18, 18)))
	var val_l := Label.new()
	val_l.text = str(entry.get("value_text", ""))
	val_l.add_theme_font_size_override("font_size", 14)
	val_l.add_theme_color_override("font_color", COLOR_VALUE)
	val_row.add_child(val_l)
	row.add_child(val_row)
	return row


func _build_rank_cell(rank: int) -> Control:
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(56, 0)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if rank <= 0:
		lbl.text = "—"
	elif rank <= 3:
		lbl.text = "◆%d" % rank
		match rank:
			1:
				lbl.add_theme_color_override("font_color", COLOR_TOP1)
			2:
				lbl.add_theme_color_override("font_color", COLOR_TOP2)
			3:
				lbl.add_theme_color_override("font_color", COLOR_TOP3)
		lbl.add_theme_font_size_override("font_size", 16)
	else:
		lbl.text = str(rank)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	wrap.add_child(lbl)
	return wrap


func _build_avatar_cell(character_id: String) -> Control:
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(52, 0)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(40, 40)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path: String = RosterConfigScript.get_portrait_path(character_id)
	if ResourceLoader.exists(path):
		tex.texture = load(path) as Texture2D
	else:
		tex.modulate = Color(0.25, 0.28, 0.35)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	sb.border_color = Color(0.35, 0.4, 0.5, 0.8)
	sb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(tex)
	wrap.add_child(frame)
	return wrap
