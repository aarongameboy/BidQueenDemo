class_name LootGridPanel
extends Control
## 右侧战利品网格展示

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")

signal slot_pressed(index: int)

var _grid: GridContainer
var _slots: Array[PanelContainer] = []
var _name_label: Label
var _estimate_label: Label
var _selected_index: int = 0
var _warehouse = null
var _revealed_mask: Array[bool] = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "战利品"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var wiki_btn := Button.new()
	wiki_btn.text = "藏品百科"
	wiki_btn.custom_minimum_size = Vector2(100, 36)
	wiki_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiButtonStyleScript.apply(wiki_btn, Color(0.88, 0.92, 0.98), 13)
	header.add_child(wiki_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	vbox.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.text = "—"
	vbox.add_child(_name_label)
	_estimate_label = Label.new()
	_estimate_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.65))
	_estimate_label.text = "当前预估最低价格: —"
	vbox.add_child(_estimate_label)


func set_warehouse(warehouse, estimate_low: int) -> void:
	_warehouse = warehouse
	_revealed_mask.clear()
	_clear_grid()
	if warehouse == null:
		return
	for i in warehouse.items.size():
		_revealed_mask.append(false)
		var slot := _create_slot(i, warehouse.items[i], false)
		_grid.add_child(slot)
		_slots.append(slot)
	_select_slot(0)
	_estimate_label.text = "当前预估最低价格: %s" % _format_comma_price(estimate_low)


func reveal_item(index: int) -> void:
	if _warehouse == null or index < 0 or index >= _warehouse.items.size():
		return
	if index < _revealed_mask.size():
		_revealed_mask[index] = true
	if index < _slots.size():
		_refresh_slot(_slots[index], _warehouse.items[index], true)
	_select_slot(index)


func _clear_grid() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	for c in _grid.get_children():
		c.queue_free()


func _create_slot(index: int, item, revealed: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 96)
	panel.add_theme_stylebox_override("panel", ItemQualityFrameScript.transparent_panel_style())
	if item != null:
		panel.add_child(ItemQualityFrameScript.make_frame_rect(item.quality))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 6)
	v.add_theme_constant_override("margin_right", 6)
	v.add_theme_constant_override("margin_top", 4)
	v.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(v)
	var name_l := Label.new()
	name_l.name = "ItemName"
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.visible = false
	v.add_child(name_l)
	var icon_host := Control.new()
	icon_host.name = "IconHost"
	icon_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_host.custom_minimum_size = Vector2(64, 64)
	v.add_child(icon_host)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_host.add_child(icon)
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_slot(index)
			slot_pressed.emit(index)
	)
	_refresh_slot(panel, item, revealed)
	return panel


func _refresh_slot(panel: PanelContainer, item, revealed: bool) -> void:
	var name_l: Label = panel.find_child("ItemName", true, false) as Label
	var icon: TextureRect = panel.find_child("Icon", true, false) as TextureRect
	var frame: TextureRect = panel.find_child("QualityFrame", true, false) as TextureRect
	if revealed and item != null:
		name_l.text = item.item_name
		if icon:
			icon.texture = _load_item_texture(item)
		if frame:
			frame.modulate = Color(1, 1, 1, 1)
	else:
		name_l.text = "???"
		if icon:
			icon.texture = null
		if frame and item != null:
			frame.modulate = Color(0.7, 0.74, 0.82, 0.75)


func _select_slot(index: int) -> void:
	_selected_index = index
	for i in _slots.size():
		var slot: PanelContainer = _slots[i]
		slot.modulate = Color(1.12, 1.12, 1.15, 1) if i == index else Color(1, 1, 1, 1)
	if _warehouse != null and index >= 0 and index < _warehouse.items.size():
		var item = _warehouse.items[index]
		var revealed: bool = index < _revealed_mask.size() and _revealed_mask[index]
		if revealed:
			_name_label.text = item.item_name
		else:
			_name_label.text = "未知藏品"


static func _load_item_texture(item) -> Texture2D:
	const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
	if item == null:
		return null
	var row: Dictionary = {
		"icon_path": str(item.icon_path),
		"quality_enum": int(item.quality),
	}
	return ItemIconUtilScript.get_texture(row)


static func _format_comma_price(amount: int) -> String:
	var s: String = str(amount)
	var out: String = ""
	var n: int = s.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
