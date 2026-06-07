class_name TacticalPickerUI
extends Control
## 对局内选择本轮使用的战术道具（每轮最多 1 次，非模态，不阻挡出价）

signal item_selected(slot_index: int)
signal closed

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")

const CELL_SIZE: int = 48
const PICKER_Z: int = 180

var _catalog: TacticalItemCatalog = null
var _grid: GridContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func open_picker(slots: Array) -> void:
	_catalog = TacticalCatalogScript.new()
	_catalog.load_all()
	_rebuild(slots)
	z_index = PICKER_Z
	show()
	move_to_front()


func close_picker() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -244
	panel.offset_bottom = -96
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.97)
	sb.border_color = Color(0.35, 0.4, 0.5, 0.85)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "使用战术道具"
	FontUtilScript.style_title_label(title, 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	UiCloseButtonScript.append_to_header(header, close_picker, Vector2(36, 36))
	vbox.add_child(header)
	var hint := Label.new()
	hint.text = "每轮最多 1 个；出价后不可再用。点击格子使用，可继续出价。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	vbox.add_child(hint)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)


func _rebuild(slots: Array) -> void:
	for c in _grid.get_children():
		c.queue_free()
	for i in slots.size():
		var slot: Dictionary = slots[i]
		_grid.add_child(_make_slot_cell(i, slot))


func _make_slot_cell(slot_index: int, slot: Dictionary) -> Control:
	var item_id: String = str(slot.get("item_id", ""))
	var used: bool = bool(slot.get("used", false))
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.add_theme_stylebox_override("panel", ItemQualityFrameScript.transparent_panel_style())
	if item_id.is_empty():
		var empty_bg := ColorRect.new()
		empty_bg.color = Color(0.08, 0.1, 0.14, 0.9)
		empty_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(empty_bg)
		return cell
	var item: Dictionary = _catalog.get_item(item_id)
	var q_enum: int = TacticalCatalogScript.quality_to_enum(str(item.get("quality", "white")))
	cell.tooltip_text = str(item.get("name", item_id))
	var frame := ItemQualityFrameScript.make_frame_rect(q_enum)
	cell.add_child(frame)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = str(item.get("icon_path", ""))
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	cell.add_child(icon)
	if used:
		cell.modulate = Color(0.45, 0.45, 0.45, 1.0)
		cell.tooltip_text += "（已使用）"
	else:
		cell.gui_input.connect(_on_cell_input.bind(slot_index))
	return cell


func _on_cell_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		item_selected.emit(slot_index)
		close_picker()
