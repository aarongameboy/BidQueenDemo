class_name LobbyUI
extends Control

signal quick_match_pressed
signal room_battle_pressed
signal ai_practice_pressed
signal coming_soon_pressed(feature_name: String)
signal encyclopedia_pressed
signal collection_pressed
signal warehouse_pressed
signal shop_pressed
signal characters_pressed
signal leaderboard_pressed

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const AssetKlineChartScript = preload("res://scripts/ui/asset_kline_chart.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")

const ICON_TINT_SHADER: Shader = preload("res://shaders/ui_icon_tint.gdshader")
const NAV_ICON_TINT: Color = Color(0.95, 0.96, 1.0, 1.0)
const ICONS_DIR: String = "res://assets/ui/icons/"
const NAV_ICON_SIZE: int = 22
const NAV_ICON_PAD: int = 3
const NAV_BAR_SEPARATION: int = 8
const NAV_ITEM_LABEL_GAP: int = 4
const NAV_LABEL_FONT_SIZE: int = 10
const PANEL_CORNER_RADIUS: int = 8
const QUICK_MATCH_BTN_HEIGHT: int = 98
const MODE_CARD_HEIGHT: int = 62
const QUICK_MATCH_ACCENT: Color = Color(0.92, 0.34, 0.32)

## 右上角导航：visible=false 默认不显示（设置/竞拍/任务）
const NAV_ENTRIES: Array[Dictionary] = [
	{"label": "商店", "icon": "shop_outlined.svg", "action": "shop", "visible": true},
	{"label": "仓库", "icon": "hdd_outlined.svg", "action": "warehouse", "visible": true},
	{"label": "设置", "icon": "setting_outlined.svg", "action": "settings", "visible": false},
	{"label": "竞拍", "icon": "rise_outlined.svg", "action": "auction", "visible": false},
	{"label": "收藏", "icon": "trophy_outlined.svg", "action": "collection", "visible": true},
	{"label": "角色", "icon": "user_switch_outlined.svg", "action": "characters", "visible": true},
	{"label": "百科", "icon": "eye_outlined.svg", "action": "encyclopedia", "visible": true},
	{"label": "排行榜", "icon": "book_outlined.svg", "action": "leaderboard", "visible": true},
	{"label": "任务", "icon": "file_exclamation_outlined.svg", "action": "tasks", "visible": false},
]

var _total_label: Label
var _change_label: Label
var _chart: AssetKlineChart
var _chart_panel: PanelContainer
var _player_name_label: Label
var _player_avatar: TextureRect
var _icon_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	_build_ui()
	FontUtilScript.apply_cjk_font(self, 14)
	refresh_portfolio()


func refresh_portfolio() -> void:
	_refresh_player_header()
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio == null:
		return
	var total: int = int(portfolio.total_assets)
	var change: int = int(portfolio.get_today_change())
	var pct: float = float(portfolio.get_today_change_pct())
	_total_label.text = _format_yuan(total, true)
	var sign: String = "+" if change >= 0 else ""
	_change_label.text = "%s%s  %s%.2f%%" % [
		sign,
		_format_yuan(change, true),
		sign,
		pct,
	]
	var up: bool = bool(portfolio.is_chart_overall_up())
	_change_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.35, 0.32) if up else Color(0.35, 0.88, 0.52),
	)
	if _chart_panel:
		_chart_panel.visible = true
	if _chart:
		var yesterday: int = int(portfolio.get_yesterday_close_assets())
		_chart.set_series(portfolio.get_chart_values(), up, yesterday)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MenuBackgroundScript.apply(self, 0.34)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_top", 18)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)
	_build_header(vbox)
	_build_asset_block(vbox)
	_build_chart_area(vbox)
	_build_match_buttons(vbox)


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	_player_avatar = TextureRect.new()
	_player_avatar.custom_minimum_size = Vector2(44, 44)
	_player_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(_player_avatar)
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(name_col)
	_player_name_label = Label.new()
	_player_name_label.text = "匿名买家#9821"
	_player_name_label.add_theme_font_size_override("font_size", 15)
	name_col.add_child(_player_name_label)
	row.add_child(_build_top_nav())


func _build_top_nav() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", NAV_BAR_SEPARATION)
	for entry: Dictionary in NAV_ENTRIES:
		if not bool(entry.get("visible", true)):
			continue
		bar.add_child(_make_nav_item(entry))
	return bar


func _make_nav_item(entry: Dictionary) -> Button:
	var label_text: String = str(entry.get("label", ""))
	var icon_file: String = str(entry.get("icon", ""))
	var action: String = str(entry.get("action", ""))
	var plate_w: int = NAV_ICON_SIZE + NAV_ICON_PAD * 2 + 8
	var plate_h: int = (
		NAV_ICON_PAD + NAV_ICON_SIZE + NAV_ITEM_LABEL_GAP
		+ NAV_LABEL_FONT_SIZE + 6 + NAV_ICON_PAD
	)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.tooltip_text = label_text
	hit.custom_minimum_size = Vector2(plate_w, plate_h)
	hit.z_index = 10
	var normal_sb := _make_nav_icon_style(false)
	var hover_sb := _make_nav_icon_style(true)
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_panel.set_meta("nav_normal_style", normal_sb)
	bg_panel.set_meta("nav_hover_style", hover_sb)
	bg_panel.add_theme_stylebox_override("panel", normal_sb)
	hit.add_child(bg_panel)
	var wrap := VBoxContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("separation", NAV_ITEM_LABEL_GAP)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	bg_panel.add_child(wrap)
	var icon_tex := TextureRect.new()
	icon_tex.custom_minimum_size = Vector2(NAV_ICON_SIZE, NAV_ICON_SIZE)
	icon_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = _load_nav_icon(icon_file)
	if tex:
		icon_tex.texture = tex
		_apply_nav_icon_tint(icon_tex, NAV_ICON_TINT)
		wrap.add_child(icon_tex)
	else:
		push_warning("LobbyUI: 导航图标加载失败: %s" % icon_file)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", NAV_LABEL_FONT_SIZE)
	name_lbl.add_theme_color_override("font_color", Color(0.62, 0.67, 0.76))
	wrap.add_child(name_lbl)
	hit.pressed.connect(_on_nav_pressed.bind(action, label_text))
	hit.mouse_entered.connect(func() -> void: _set_nav_item_hover(bg_panel, true))
	hit.mouse_exited.connect(func() -> void: _set_nav_item_hover(bg_panel, false))
	return hit


func _make_nav_icon_style(hover: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if hover:
		sb.bg_color = Color(0.12, 0.14, 0.2, 0.88)
		sb.border_color = Color(0.42, 0.5, 0.62, 0.75)
	else:
		sb.bg_color = Color(0.06, 0.07, 0.1, 0.72)
		sb.border_color = Color(0.2, 0.24, 0.32, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(PANEL_CORNER_RADIUS)
	sb.content_margin_left = NAV_ICON_PAD
	sb.content_margin_right = NAV_ICON_PAD
	sb.content_margin_top = NAV_ICON_PAD
	sb.content_margin_bottom = NAV_ICON_PAD + 2
	return sb


func _set_nav_item_hover(bg_panel: PanelContainer, hover: bool) -> void:
	if bg_panel == null:
		return
	var key: String = "nav_hover_style" if hover else "nav_normal_style"
	var sb: Variant = bg_panel.get_meta(key)
	if sb is StyleBox:
		bg_panel.add_theme_stylebox_override("panel", sb as StyleBox)


func _load_nav_icon(icon_file: String) -> Texture2D:
	if icon_file.is_empty():
		return null
	if _icon_cache.has(icon_file):
		return _icon_cache[icon_file] as Texture2D
	var path: String = ICONS_DIR + icon_file
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_icon_cache[icon_file] = tex
	return tex


func _on_nav_pressed(action: String, label_text: String) -> void:
	match action:
		"shop":
			shop_pressed.emit()
		"warehouse":
			warehouse_pressed.emit()
		"encyclopedia":
			encyclopedia_pressed.emit()
		"collection":
			collection_pressed.emit()
		"characters":
			characters_pressed.emit()
		"leaderboard":
			leaderboard_pressed.emit()
		"auction":
			quick_match_pressed.emit()
		"settings":
			coming_soon_pressed.emit("设置")
		"tasks":
			coming_soon_pressed.emit("任务")
		_:
			coming_soon_pressed.emit(label_text)


func _apply_nav_icon_tint(icon_tex: TextureRect, tint: Color) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = ICON_TINT_SHADER
	mat.set_shader_parameter("tint_color", tint)
	icon_tex.material = mat


func _build_asset_block(parent: VBoxContainer) -> void:
	var cap := Label.new()
	cap.text = "总资产"
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	parent.add_child(cap)
	var total_row := HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)
	total_row.add_child(UiMoneyIconScript.make_texture_rect(Vector2(36, 36)))
	_total_label = Label.new()
	_total_label.text = "¥0"
	FontUtilScript.style_title_label(_total_label, 40)
	_total_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	total_row.add_child(_total_label)
	parent.add_child(total_row)
	_change_label = Label.new()
	_change_label.text = "+0  +0.00%"
	_change_label.add_theme_font_size_override("font_size", 15)
	parent.add_child(_change_label)


func _build_chart_area(parent: VBoxContainer) -> void:
	_chart_panel = PanelContainer.new()
	var panel := _chart_panel
	panel.custom_minimum_size = Vector2(0, 220)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.2
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.6)
	sb.border_color = Color(0.18, 0.22, 0.3, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	_chart = AssetKlineChartScript.new()
	_chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chart.clip_contents = false
	panel.add_child(_chart)
	panel.clip_contents = false
	panel.visible = true


func _build_match_buttons(parent: VBoxContainer) -> void:
	parent.add_child(_make_quick_match_card())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	row.add_child(_make_mode_card("房间对战", "邀请好友", Color(0.35, 0.65, 0.95), "房间对战"))
	row.add_child(_make_mode_card("AI练习", "单人免费", Color(0.35, 0.88, 0.52), "AI练习"))


func _make_quick_match_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, QUICK_MATCH_BTN_HEIGHT)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.35
	var normal_sb := _make_quick_match_style(false, false)
	var hover_sb := _make_quick_match_style(true, false)
	var pressed_sb := _make_quick_match_style(false, true)
	panel.add_theme_stylebox_override("panel", normal_sb)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)
	var title_lbl := Label.new()
	title_lbl.text = "快速匹配"
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontUtilScript.style_title_label(title_lbl, 26)
	title_lbl.add_theme_color_override("font_color", QUICK_MATCH_ACCENT.lightened(0.12))
	texts.add_child(title_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = "随机玩家 · 即时开局"
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FontUtilScript.style_body_label(sub_lbl, 13)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	texts.add_child(sub_lbl)
	var arrow := Label.new()
	arrow.text = "›"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_size_override("font_size", 32)
	arrow.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(arrow)
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.pressed.connect(func() -> void: quick_match_pressed.emit())
	hit.mouse_entered.connect(
		func() -> void: panel.add_theme_stylebox_override("panel", hover_sb),
	)
	hit.mouse_exited.connect(
		func() -> void: panel.add_theme_stylebox_override("panel", normal_sb),
	)
	hit.button_down.connect(
		func() -> void: panel.add_theme_stylebox_override("panel", pressed_sb),
	)
	hit.button_up.connect(
		func() -> void:
			if hit.is_hovered():
				panel.add_theme_stylebox_override("panel", hover_sb)
			else:
				panel.add_theme_stylebox_override("panel", normal_sb),
	)
	panel.add_child(hit)
	return panel


func _make_quick_match_style(hover: bool, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if pressed:
		sb.bg_color = Color(0.08, 0.1, 0.14, 0.98)
		sb.border_color = QUICK_MATCH_ACCENT.darkened(0.08)
	elif hover:
		sb.bg_color = Color(0.14, 0.16, 0.22, 0.98)
		sb.border_color = QUICK_MATCH_ACCENT.lightened(0.18)
	else:
		sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
		sb.border_color = QUICK_MATCH_ACCENT
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	return sb


func _make_mode_card(title: String, subtitle: String, accent: Color, feature: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, MODE_CARD_HEIGHT)
	var normal_sb := _make_mode_card_style(accent, false, false)
	var hover_sb := _make_mode_card_style(accent, true, false)
	var pressed_sb := _make_mode_card_style(accent, false, true)
	panel.add_theme_stylebox_override("panel", normal_sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var t := Label.new()
	t.text = title
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_font_size_override("font_size", 17)
	t.add_theme_color_override("font_color", accent.lightened(0.12))
	vbox.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_theme_font_size_override("font_size", 10)
	s.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	vbox.add_child(s)
	var hit := Button.new()
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	if feature == "房间对战":
		hit.pressed.connect(func() -> void: room_battle_pressed.emit())
	elif feature == "AI练习":
		hit.pressed.connect(func() -> void: ai_practice_pressed.emit())
	else:
		hit.pressed.connect(func() -> void: coming_soon_pressed.emit(feature))
	hit.mouse_entered.connect(
		func() -> void: panel.add_theme_stylebox_override("panel", hover_sb),
	)
	hit.mouse_exited.connect(
		func() -> void: panel.add_theme_stylebox_override("panel", normal_sb),
	)
	hit.button_down.connect(
		func() -> void: panel.add_theme_stylebox_override("panel", pressed_sb),
	)
	hit.button_up.connect(
		func() -> void:
			if hit.is_hovered():
				panel.add_theme_stylebox_override("panel", hover_sb)
			else:
				panel.add_theme_stylebox_override("panel", normal_sb),
	)
	panel.add_child(hit)
	return panel


func _make_mode_card_style(accent: Color, hover: bool, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if pressed:
		sb.bg_color = Color(0.08, 0.1, 0.14, 0.98)
		sb.border_color = accent.darkened(0.08)
	elif hover:
		sb.bg_color = Color(0.14, 0.16, 0.22, 0.98)
		sb.border_color = accent.lightened(0.18)
	else:
		sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
		sb.border_color = accent
	sb.border_width_left = 3
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _refresh_player_header() -> void:
	if _player_name_label == null:
		return
	RosterConfigScript.ensure_loaded()
	var roster: Node = get_node_or_null("/root/PlayerRoster")
	var cid: String = RosterConfigScript.get_default_id()
	if roster != null:
		cid = str(roster.selected_character_id)
	_player_name_label.text = RosterConfigScript.get_display_name(cid)
	if _player_avatar != null:
		_player_avatar.texture = RosterConfigScript.get_avatar_texture(cid)


static func _format_yuan(amount: int, change_only: bool = false) -> String:
	var n: int = absi(amount)
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	var body: String = s + out
	if change_only:
		return body if amount >= 0 else "-" + body
	return ("-¥" if amount < 0 else "¥") + body
