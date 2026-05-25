class_name CharacterSelectionUI
extends Control
## 出战角色选择：立绘为主、技能描述叠在立绘下半部

signal closed
signal character_selected(character_id: String)

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")

## 立绘资源为 1:1 方图（豆包 1024/2048）
const PORTRAIT_ASPECT: float = 1.0
const PICKER_COL_WIDTH: int = 112
const PICKER_THUMB_SIZE: int = 100
const PICKER_LABEL_HEIGHT: int = 28
## 信息区左侧留白，避免被角色列表遮挡
const INFO_PANEL_LEFT_INSET: int = PICKER_COL_WIDTH + 28
const INFO_PANEL_ANCHOR_TOP: float = 0.74
const DEPLOY_BTN_SIZE: Vector2 = Vector2(200, 44)
const DEPLOY_BTN_FONT: int = 20

var _roster: Node
var _selected_id: String = ""
var _portrait: TextureRect
var _portrait_stack: Control
var _info_panel: PanelContainer
var _name_label: Label
var _role_label: Label
var _skill_name_label: Label
var _skill_desc_label: Label
var _deploy_btn: Button
var _picker_list: VBoxContainer


func _ready() -> void:
	_roster = get_node_or_null("/root/PlayerRoster")
	_build_shell()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func open() -> void:
	RosterConfigScript.ensure_loaded()
	MenuBackgroundScript.apply(self, 0.32)
	_selected_id = _get_selected_id()
	_refresh_picker()
	_refresh_detail()
	show()
	move_to_front()


func close() -> void:
	hide()
	closed.emit()


func _get_selected_id() -> String:
	if _roster != null:
		return str(_roster.selected_character_id)
	return RosterConfigScript.get_default_id()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MenuBackgroundScript.apply(self, 0.32)
	_build_portrait_layer()
	UiCloseButtonScript.pin_top_right(self, close)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 0)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)
	_build_picker_column(body)
	var portrait_spacer := Control.new()
	portrait_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(portrait_spacer)


func _build_picker_column(parent: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(PICKER_COL_WIDTH, 0)
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(PICKER_COL_WIDTH, 0)
	col.add_child(scroll)
	_picker_list = VBoxContainer.new()
	_picker_list.custom_minimum_size = Vector2(PICKER_COL_WIDTH, 0)
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_picker_list)


func _build_portrait_layer() -> void:
	_portrait_stack = Control.new()
	_portrait_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_stack.clip_contents = true
	_portrait_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_stack)
	_portrait = TextureRect.new()
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_left = -40.0
	_portrait.offset_top = -48.0
	_portrait.offset_right = 40.0
	_portrait.offset_bottom = 8.0
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_stack.add_child(_portrait)
	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info_panel.anchor_top = INFO_PANEL_ANCHOR_TOP
	_info_panel.offset_left = float(INFO_PANEL_LEFT_INSET)
	_info_panel.offset_top = 0.0
	_info_panel.offset_right = -12.0
	_info_panel.offset_bottom = 0.0
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var info_sb := StyleBoxFlat.new()
	info_sb.bg_color = Color(0.05, 0.07, 0.11, 0.88)
	info_sb.border_color = Color(0.28, 0.35, 0.48, 0.7)
	info_sb.set_border_width_all(1)
	info_sb.set_corner_radius_all(8)
	info_sb.content_margin_left = 12
	info_sb.content_margin_right = 14
	info_sb.content_margin_top = 8
	info_sb.content_margin_bottom = 10
	_info_panel.add_theme_stylebox_override("panel", info_sb)
	_portrait_stack.add_child(_info_panel)
	var info_margin := MarginContainer.new()
	info_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	info_margin.add_theme_constant_override("margin_left", 4)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_top", 2)
	info_margin.add_theme_constant_override("margin_bottom", 4)
	_info_panel.add_child(info_margin)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info_margin.add_child(info)
	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	_name_label = Label.new()
	FontUtilScript.style_title_label(_name_label, 20)
	name_row.add_child(_name_label)
	_role_label = Label.new()
	_role_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	_role_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(_role_label)
	var skill_cap := Label.new()
	skill_cap.text = "局内技能"
	skill_cap.add_theme_font_size_override("font_size", 12)
	skill_cap.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
	info.add_child(skill_cap)
	_skill_name_label = Label.new()
	_skill_name_label.add_theme_font_size_override("font_size", 14)
	_skill_name_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	info.add_child(_skill_name_label)
	_skill_desc_label = Label.new()
	_skill_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_desc_label.add_theme_font_size_override("font_size", 13)
	_skill_desc_label.custom_minimum_size = Vector2(0, 36)
	_skill_desc_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8))
	info.add_child(_skill_desc_label)
	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(0, 6)
	info.add_child(btn_spacer)
	var btn_row := CenterContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(btn_row)
	_deploy_btn = Button.new()
	_deploy_btn.text = "出战"
	_deploy_btn.custom_minimum_size = DEPLOY_BTN_SIZE
	_style_deploy_button()
	_deploy_btn.pressed.connect(_on_deploy_pressed)
	btn_row.add_child(_deploy_btn)
	move_child(_portrait_stack, 0)


func _picker_item_height() -> int:
	return PICKER_THUMB_SIZE + PICKER_LABEL_HEIGHT + 10


func _refresh_picker() -> void:
	for c in _picker_list.get_children():
		c.queue_free()
	for cid in RosterConfigScript.all_ids():
		_picker_list.add_child(_make_picker_item(cid))


func _make_picker_item(character_id: String) -> Button:
	var selected: bool = character_id == _selected_id
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(PICKER_COL_WIDTH - 4, _picker_item_height())
	btn.toggle_mode = true
	btn.button_pressed = selected
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	btn.add_child(vbox)
	var thumb_wrap := CenterContainer.new()
	thumb_wrap.custom_minimum_size = Vector2(PICKER_THUMB_SIZE, PICKER_THUMB_SIZE)
	thumb_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(thumb_wrap)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(PICKER_THUMB_SIZE, int(PICKER_THUMB_SIZE / PORTRAIT_ASPECT))
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = RosterConfigScript.get_portrait_path(character_id)
	if ResourceLoader.exists(path):
		thumb.texture = load(path)
	thumb_wrap.add_child(thumb)
	var lbl := Label.new()
	lbl.text = RosterConfigScript.get_display_name(character_id)
	lbl.custom_minimum_size = Vector2(PICKER_COL_WIDTH - 8, PICKER_LABEL_HEIGHT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.max_lines_visible = 2
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	_style_picker_button(btn, selected)
	btn.pressed.connect(func() -> void: _on_picker_pressed(character_id))
	return btn


func _style_picker_button(btn: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(0.12, 0.2, 0.28, 0.92)
		sb.border_color = Color(0.35, 0.88, 0.55)
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.08, 0.1, 0.14, 0.75)
		sb.border_color = Color(0.25, 0.3, 0.4, 0.8)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover", sb)


func _style_deploy_button() -> void:
	UiButtonStyleScript.apply_primary(_deploy_btn, DEPLOY_BTN_FONT)
	for state_name: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		var sb: StyleBox = _deploy_btn.get_theme_stylebox(state_name)
		if sb == null:
			continue
		var dup: StyleBox = sb.duplicate()
		if dup is StyleBoxTexture:
			(dup as StyleBoxTexture).content_margin_left = 14
			(dup as StyleBoxTexture).content_margin_right = 14
			(dup as StyleBoxTexture).content_margin_top = 12
			(dup as StyleBoxTexture).content_margin_bottom = 12
		elif dup is StyleBoxFlat:
			(dup as StyleBoxFlat).content_margin_left = 14
			(dup as StyleBoxFlat).content_margin_right = 14
			(dup as StyleBoxFlat).content_margin_top = 12
			(dup as StyleBoxFlat).content_margin_bottom = 12
		_deploy_btn.add_theme_stylebox_override(state_name, dup)


func _on_picker_pressed(character_id: String) -> void:
	_selected_id = character_id
	_refresh_picker()
	_refresh_detail()


func _refresh_detail() -> void:
	if _selected_id.is_empty():
		_selected_id = _get_selected_id()
	var row: Dictionary = RosterConfigScript.get_row(_selected_id)
	_name_label.text = RosterConfigScript.get_display_name(_selected_id)
	_role_label.text = " · %s" % str(row.get("role", ""))
	_skill_name_label.text = RosterConfigScript.get_skill_name(_selected_id)
	_skill_desc_label.text = RosterConfigScript.get_skill_desc(_selected_id)
	var path: String = RosterConfigScript.get_portrait_path(_selected_id)
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	else:
		_portrait.texture = null
	var is_deployed: bool = _selected_id == _get_selected_id()
	if is_deployed:
		_deploy_btn.text = "出战中"
		_deploy_btn.disabled = true
	else:
		_deploy_btn.text = "出战"
		_deploy_btn.disabled = false


func _on_deploy_pressed() -> void:
	if _deploy_btn.disabled:
		return
	if _roster != null:
		_roster.set_selected(_selected_id)
	character_selected.emit(_selected_id)
	_refresh_picker()
	_refresh_detail()
