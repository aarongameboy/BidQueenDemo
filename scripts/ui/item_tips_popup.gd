class_name ItemTipsPopup
extends Control
## 道具详情 Tips（参考设计稿：名称、售价、类型、占格、可选出售）

signal closed
signal sell_pressed(item_uid: String)

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")
const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")

const PANEL_MIN_SIZE: Vector2 = Vector2(300, 380)
const GRID_PREVIEW_COLS: int = 5

var _panel: PanelContainer
var _title_label: Label
var _price_value_label: Label
var _type_value_label: Label
var _description_label: Label
var _icon_host: Control
var _size_grid_host: VBoxContainer
var _sell_btn: Button
var _footer: HBoxContainer

var _item_uid: String = ""
var _sell_price: int = 0
var _show_sell: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	hide()


func show_item(
	item_row: Dictionary,
	options: Dictionary = {},
) -> void:
	_item_uid = str(options.get("uid", ""))
	_show_sell = bool(options.get("show_sell_button", false))
	_sell_price = int(item_row.get("base_price", 0))
	var name: String = str(item_row.get("item_name", "未知道具"))
	var q_enum: int = int(item_row.get("quality_enum", GameConstants.Quality.WHITE))
	var sw: int = clampi(int(item_row.get("size_w", 1)), 1, GRID_PREVIEW_COLS)
	var sh: int = clampi(int(item_row.get("size_h", 1)), 1, GRID_PREVIEW_COLS)
	var type_key: String = str(item_row.get("item_type", ""))
	var type_label: String = str(ItemCatalogScript.TYPE_LABELS.get(type_key, type_key))
	if type_label.is_empty():
		type_label = "—"
	_title_label.text = name
	_price_value_label.text = _format_price(_sell_price)
	_type_value_label.text = type_label
	_description_label.text = str(item_row.get("flavor_text", "")).strip_edges()
	_description_label.visible = not _description_label.text.is_empty()
	_rebuild_icon(item_row, q_enum)
	_rebuild_size_grid(sw, sh)
	_footer.visible = _show_sell
	_sell_btn.visible = _show_sell
	show()
	move_to_front()


func hide_popup() -> void:
	hide()
	_item_uid = ""
	closed.emit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_clicked)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_MIN_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.1, 0.11, 0.14, 0.96)
	panel_sb.border_color = Color(0.28, 0.32, 0.4, 0.85)
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(6)
	panel_sb.content_margin_left = 16
	panel_sb.content_margin_right = 16
	panel_sb.content_margin_top = 14
	panel_sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", panel_sb)
	center.add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)
	root.add_child(_build_header_row())
	root.add_child(_build_price_row())
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 12)
	_description_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	root.add_child(_description_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.custom_minimum_size = Vector2(0, 200)
	root.add_child(body)
	_icon_host = Control.new()
	_icon_host.custom_minimum_size = Vector2(160, 180)
	_icon_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_icon_host)
	var meta_col := VBoxContainer.new()
	meta_col.add_theme_constant_override("separation", 12)
	meta_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meta_col.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(meta_col)
	meta_col.add_child(_build_meta_block("道具类型", true))
	meta_col.add_child(_build_size_block())
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 0)
	root.add_child(_footer)
	_sell_btn = Button.new()
	_sell_btn.text = "出售"
	_sell_btn.custom_minimum_size = Vector2(220, 44)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_ghost_button_style(_sell_btn)
	_sell_btn.pressed.connect(_on_sell_pressed)
	_footer.add_child(_sell_btn)
	_footer.visible = false


func _build_header_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_title_label = Label.new()
	_title_label.text = "道具"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FontUtilScript.style_title_label(_title_label, 18)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	row.add_child(_title_label)
	UiCloseButtonScript.append_to_header(row, hide_popup, Vector2(36, 36))
	return row


func _build_price_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := Label.new()
	cap.text = "出售价格"
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color(0.62, 0.67, 0.76))
	row.add_child(cap)
	row.add_child(UiMoneyIconScript.make_texture_rect(Vector2(22, 22)))
	_price_value_label = Label.new()
	_price_value_label.text = "0"
	_price_value_label.add_theme_font_size_override("font_size", 16)
	_price_value_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	row.add_child(_price_value_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	return row


func _build_meta_block(caption: String, is_type: bool) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	var cap_lbl := Label.new()
	cap_lbl.text = caption
	cap_lbl.add_theme_font_size_override("font_size", 11)
	cap_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	block.add_child(cap_lbl)
	var val := Label.new()
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	block.add_child(val)
	if is_type:
		_type_value_label = val
	return block


func _build_size_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	var cap_lbl := Label.new()
	cap_lbl.text = "占格大小"
	cap_lbl.add_theme_font_size_override("font_size", 11)
	cap_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	block.add_child(cap_lbl)
	_size_grid_host = VBoxContainer.new()
	_size_grid_host.add_theme_constant_override("separation", 4)
	_size_grid_host.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(_size_grid_host)
	return block


func _rebuild_icon(item_row: Dictionary, quality_enum: int) -> void:
	for c in _icon_host.get_children():
		c.queue_free()
	var wrap := Control.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.custom_minimum_size = Vector2(140, 160)
	_icon_host.add_child(wrap)
	wrap.add_child(ItemQualityFrameScript.make_frame_rect(quality_enum))
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ItemIconUtilScript.get_texture(item_row)
	wrap.add_child(icon)


func _rebuild_size_grid(sw: int, sh: int) -> void:
	for c in _size_grid_host.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = GRID_PREVIEW_COLS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_size_grid_host.add_child(grid)
	for y in GRID_PREVIEW_COLS:
		for x in GRID_PREVIEW_COLS:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(8, 8)
			var on: bool = x < sw and y < sh
			cell.color = Color(0.92, 0.94, 0.98, 0.95) if on else Color(0.14, 0.16, 0.2, 0.85)
			grid.add_child(cell)
	var dim_lbl := Label.new()
	dim_lbl.text = "%d×%d 格" % [sw, sh]
	dim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dim_lbl.add_theme_font_size_override("font_size", 10)
	dim_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	_size_grid_host.add_child(dim_lbl)


func _apply_ghost_button_style(btn: Button) -> void:
	btn.flat = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.75)
	sb.border_color = Color(0.82, 0.86, 0.92)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.04, 0.05, 0.08, 0.95)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	btn.add_theme_font_size_override("font_size", 16)


func _on_dim_clicked(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		hide_popup()


func _on_sell_pressed() -> void:
	if _item_uid.is_empty():
		return
	sell_pressed.emit(_item_uid)


static func _format_price(amount: int) -> String:
	var n: int = absi(amount)
	if n >= 1_000_000:
		return "%.2fM" % (float(n) / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (float(n) / 1_000.0)
	return str(n)
