class_name WarehouseUI
extends Control
## 持久化仓库：侧栏分页、批量出售、双击整理

signal closed
signal shop_requested

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")
const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
const PersistentGridUtilScript = preload("res://scripts/util/persistent_grid_util.gd")
const ItemTipsPopupScript = preload("res://scripts/ui/item_tips_popup.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")
const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")

const CELL_SIZE: int = 42
const CELL_GAP: int = 1
const COLOR_ACCENT: Color = Color(0.88, 0.95, 0.38, 1.0)
const PANEL_WIDTH_RATIO: float = 0.5
const PANEL_EDGE_MARGIN: int = 10
const DISMISS_DIM_ALPHA: float = 0.38

enum Mode { VIEW, BULK_SELL }

var _catalog = null
var _page_index: int = 0
var _mode: int = Mode.VIEW
var _selected_uids: Dictionary = {}

var _page_tabs: VBoxContainer
var _grid_host: Control
var _grid_frame: Control
var _cells_layer: Control
var _items_layer: Control
var _capacity_label: Label
var _sell_bar: VBoxContainer
var _sell_total_label: Label
var _sell_btn: Button
var _hint_label: Label
var _quality_btns: Array[Button] = []
var _updating_quality_btns: bool = false
var _warehouse_node: Node
var _item_tips: ItemTipsPopup
var _item_tooltip: ItemTooltip


func _ready() -> void:
	_build_shell()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func setup(catalog) -> void:
	_catalog = catalog
	_warehouse_node = get_node_or_null("/root/PlayerWarehouse")
	if _warehouse_node and not _warehouse_node.warehouse_changed.is_connected(_on_warehouse_changed):
		_warehouse_node.warehouse_changed.connect(_on_warehouse_changed)
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical and not tactical.inventory_changed.is_connected(_on_tactical_inventory_changed):
		tactical.inventory_changed.connect(_on_tactical_inventory_changed)


func open() -> void:
	_mode = Mode.VIEW
	_selected_uids.clear()
	_refresh_all()
	z_index = 130
	show()
	move_to_front()


func close() -> void:
	if _item_tips:
		_item_tips.hide_popup()
	if _item_tooltip:
		_item_tooltip.hide_tooltip()
	hide()
	closed.emit()


func _on_warehouse_changed() -> void:
	if is_visible_in_tree():
		_refresh_all()


func _on_tactical_inventory_changed() -> void:
	if is_visible_in_tree():
		_refresh_all()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dismiss := ColorRect.new()
	dismiss.name = "DismissLayer"
	dismiss.color = Color(0.02, 0.03, 0.05, DISMISS_DIM_ALPHA)
	dismiss.mouse_filter = Control.MOUSE_FILTER_STOP
	dismiss.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dismiss.anchor_right = PANEL_WIDTH_RATIO
	dismiss.offset_right = 0.0
	dismiss.gui_input.connect(_on_dismiss_clicked)
	add_child(dismiss)
	var dock := MarginContainer.new()
	dock.name = "PanelDock"
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock.anchor_left = PANEL_WIDTH_RATIO
	dock.offset_left = 0.0
	dock.add_theme_constant_override("margin_left", PANEL_EDGE_MARGIN)
	dock.add_theme_constant_override("margin_top", PANEL_EDGE_MARGIN)
	dock.add_theme_constant_override("margin_right", PANEL_EDGE_MARGIN)
	dock.add_theme_constant_override("margin_bottom", PANEL_EDGE_MARGIN)
	add_child(dock)
	var shell := PanelContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var shell_sb := StyleBoxFlat.new()
	shell_sb.bg_color = Color(0.06, 0.07, 0.1, 0.97)
	shell_sb.border_color = Color(0.32, 0.38, 0.5, 0.9)
	shell_sb.set_border_width_all(1)
	shell_sb.set_corner_radius_all(10)
	shell_sb.shadow_color = Color(0, 0, 0, 0.45)
	shell_sb.shadow_size = 8
	shell_sb.content_margin_left = 12
	shell_sb.content_margin_right = 12
	shell_sb.content_margin_top = 10
	shell_sb.content_margin_bottom = 10
	shell.add_theme_stylebox_override("panel", shell_sb)
	dock.add_child(shell)
	var root := MarginContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(root)
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 8)
	root.add_child(outer)
	outer.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	outer.add_child(body)
	body.add_child(_build_sidebar())
	body.add_child(_build_main())
	_sell_bar = _build_sell_bar()
	outer.add_child(_sell_bar)
	_sell_bar.visible = false
	_item_tips = ItemTipsPopupScript.new()
	_item_tips.closed.connect(_on_item_tips_closed)
	_item_tips.sell_pressed.connect(_on_item_tips_sell)
	shell.add_child(_item_tips)
	_item_tips.hide()
	_item_tooltip = ItemTooltipScript.new()
	shell.add_child(_item_tooltip)


func _on_dismiss_clicked(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		close()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "仓库"
	FontUtilScript.style_title_label(title, 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_capacity_label = Label.new()
	_capacity_label.add_theme_font_size_override("font_size", 14)
	_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	row.add_child(_capacity_label)
	UiCloseButtonScript.append_to_header(row, close)
	return row


func _build_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.85)
	sb.border_color = Color(0.25, 0.3, 0.38, 0.6)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	_page_tabs = VBoxContainer.new()
	_page_tabs.add_theme_constant_override("separation", 4)
	_page_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_page_tabs)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	vbox.add_child(_make_side_action("批量出售", _enter_bulk_sell))
	var organize_btn := _make_side_action("整理当页", _on_organize_pressed)
	vbox.add_child(organize_btn)
	organize_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.double_click:
			_on_organize_pressed()
	)
	var organize_all_btn := _make_side_action("全局整理", _on_organize_all_pressed)
	vbox.add_child(organize_all_btn)
	vbox.add_child(_make_side_action("商店", func() -> void: shop_requested.emit()))
	_hint_label = Label.new()
	_hint_label.text = "「全局整理」将红色品质道具优先放入藏品箱"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
	vbox.add_child(_hint_label)
	return panel


func _make_side_action(label_text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(58, 36)
	UiButtonStyleScript.apply(btn, Color(0.82, 0.86, 0.94), 11)
	btn.pressed.connect(on_press)
	return btn


func _build_main() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.72)
	sb.border_color = Color(0.25, 0.32, 0.42, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)
	_grid_host = Control.new()
	scroll.add_child(_grid_host)
	_grid_frame = Control.new()
	_grid_host.add_child(_grid_frame)
	var grid_bg := ColorRect.new()
	grid_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_bg.color = Color(0.04, 0.06, 0.1, 0.45)
	grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_frame.add_child(grid_bg)
	_cells_layer = Control.new()
	_grid_frame.add_child(_cells_layer)
	_items_layer = Control.new()
	_items_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_frame.add_child(_items_layer)
	return panel


func _build_sell_bar() -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 6)
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	wrapper.add_child(filter_row)
	var filter_lbl := Label.new()
	filter_lbl.text = "按品质选择:"
	filter_lbl.add_theme_font_size_override("font_size", 13)
	filter_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	filter_row.add_child(filter_lbl)
	_quality_btns.clear()
	for q in GameConstants.QUALITY_COUNT:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_pressed = false
		btn.custom_minimum_size = Vector2(32, 26)
		btn.tooltip_text = GameConstants.QUALITY_NAMES[q]
		btn.text = GameConstants.QUALITY_NAMES[q]
		var base_color: Color = GameConstants.get_quality_color(q)
		var dim_sb := StyleBoxFlat.new()
		dim_sb.bg_color = base_color * Color(0.5, 0.5, 0.5, 0.8)
		dim_sb.set_corner_radius_all(3)
		dim_sb.content_margin_left = 4
		dim_sb.content_margin_right = 4
		btn.add_theme_stylebox_override("normal", dim_sb)
		var bright_sb := StyleBoxFlat.new()
		bright_sb.bg_color = base_color
		bright_sb.border_color = COLOR_ACCENT
		bright_sb.set_border_width_all(2)
		bright_sb.set_corner_radius_all(3)
		bright_sb.content_margin_left = 4
		bright_sb.content_margin_right = 4
		btn.add_theme_stylebox_override("pressed", bright_sb)
		var hover_sb := dim_sb.duplicate() as StyleBoxFlat
		hover_sb.bg_color = base_color * Color(0.7, 0.7, 0.7, 0.9)
		btn.add_theme_stylebox_override("hover", hover_sb)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		var quality: int = q
		btn.toggled.connect(func(_on: bool) -> void: _on_quality_sell_toggled(quality))
		filter_row.add_child(btn)
		_quality_btns.append(btn)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 12)
	var cancel := Button.new()
	cancel.text = "取消"
	UiButtonStyleScript.apply(cancel, Color(0.75, 0.78, 0.85), 13)
	cancel.pressed.connect(_exit_bulk_sell)
	action_row.add_child(cancel)
	_sell_total_label = Label.new()
	_sell_total_label.text = "已选 0"
	_sell_total_label.add_theme_font_size_override("font_size", 16)
	_sell_total_label.add_theme_color_override("font_color", COLOR_ACCENT)
	action_row.add_child(_sell_total_label)
	_sell_btn = Button.new()
	_sell_btn.text = "出售"
	_sell_btn.custom_minimum_size = Vector2(120, 40)
	UiButtonStyleScript.apply(_sell_btn, Color(0.35, 0.88, 0.52), 15)
	_sell_btn.pressed.connect(_confirm_bulk_sell)
	action_row.add_child(_sell_btn)
	wrapper.add_child(action_row)
	return wrapper


func _refresh_all() -> void:
	_rebuild_page_tabs()
	_refresh_grid()
	_update_sell_bar()


func _rebuild_page_tabs() -> void:
	for c in _page_tabs.get_children():
		c.queue_free()
	if _warehouse_node == null:
		return
	var pages: Array = _warehouse_node.get_pages()
	for i in pages.size():
		var page: Dictionary = pages[i]
		var btn := Button.new()
		var used: int = _warehouse_node.get_used_cells(i, _catalog) if _catalog else 0
		var cap: int = _warehouse_node.get_capacity_cells(i)
		btn.text = "%s\n%d/%d" % [str(page.get("name", "页")), used, cap]
		btn.toggle_mode = true
		btn.button_pressed = i == _page_index
		btn.custom_minimum_size = Vector2(58, 48)
		var idx: int = i
		btn.pressed.connect(func() -> void:
			_page_index = idx
			_refresh_all()
		)
		if i == _page_index:
			UiButtonStyleScript.apply(btn, COLOR_ACCENT, 10)
		else:
			UiButtonStyleScript.apply(btn, Color(0.78, 0.82, 0.9), 10)
		_page_tabs.add_child(btn)


func _refresh_grid() -> void:
	for c in _cells_layer.get_children():
		c.queue_free()
	for c in _items_layer.get_children():
		c.queue_free()
	if _warehouse_node == null or _catalog == null:
		return
	var page: Dictionary = _warehouse_node.get_page(_page_index)
	if page.is_empty():
		return
	var cols: int = int(page.get("grid_w", 8))
	var rows: int = int(page.get("grid_h", 8))
	var grid_px: Vector2 = _grid_pixel_size(cols, rows)
	_grid_frame.custom_minimum_size = grid_px
	_grid_frame.size = grid_px
	_cells_layer.custom_minimum_size = grid_px
	_cells_layer.size = grid_px
	_items_layer.custom_minimum_size = grid_px
	_items_layer.size = grid_px
	for gy in rows:
		for gx in cols:
			_cells_layer.add_child(_make_cell(gx, gy))
	var occupancy: Array = PersistentGridUtilScript.new_occupancy(cols, rows)
	for entry in page.get("items", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _catalog.get_item(str(entry.get("item_id", "")))
		if row.is_empty():
			continue
		var sw: int = clampi(int(row.get("size_w", 1)), 1, cols)
		var sh: int = clampi(int(row.get("size_h", 1)), 1, rows)
		var gx: int = int(entry.get("x", 0))
		var gy: int = int(entry.get("y", 0))
		if PersistentGridUtilScript.can_place(occupancy, gx, gy, sw, sh, cols, rows):
			PersistentGridUtilScript.occupy(occupancy, gx, gy, sw, sh)
		_items_layer.add_child(_make_item_block(entry, row, gx, gy, sw, sh))
	var tactical_cells: int = _add_tactical_items_to_grid(page, cols, rows, occupancy)
	var used: int = _warehouse_node.get_used_cells(_page_index, _catalog) + tactical_cells
	var cap: int = _warehouse_node.get_capacity_cells(_page_index)
	_capacity_label.text = "%s · %d / %d 格" % [str(page.get("name", "")), used, cap]


func _make_item_block(entry: Dictionary, row: Dictionary, gx: int, gy: int, sw: int, sh: int) -> PanelContainer:
	var uid: String = str(entry.get("uid", ""))
	var span: Vector2 = _cell_span(sw, sh)
	var panel := PanelContainer.new()
	panel.position = _cell_origin(gx, gy)
	panel.size = span
	panel.custom_minimum_size = span
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var q_enum: int = int(row.get("quality_enum", GameConstants.Quality.WHITE))
	panel.add_theme_stylebox_override("panel", ItemQualityFrameScript.transparent_panel_style())
	panel.add_child(ItemQualityFrameScript.make_frame_rect(q_enum))
	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var selected: bool = _mode == Mode.BULK_SELL and _selected_uids.has(uid)
	if selected:
		var sel_bg := ColorRect.new()
		sel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sel_bg.color = Color(0.15, 0.55, 0.32, 0.42)
		sel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sel_bg)
		var sel_border := PanelContainer.new()
		sel_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sel_sb := StyleBoxFlat.new()
		sel_sb.bg_color = Color(0, 0, 0, 0)
		sel_sb.border_color = COLOR_ACCENT
		sel_sb.set_border_width_all(3)
		sel_sb.set_corner_radius_all(4)
		sel_border.add_theme_stylebox_override("panel", sel_sb)
		inner.add_child(sel_border)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 14
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = ItemIconUtilScript.get_texture(row)
	inner.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = str(row.get("item_name", ""))
	name_lbl.position = Vector2(4, 2)
	name_lbl.size = Vector2(span.x - 8.0, 14.0)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)
	ItemTooltipScript.bind_hover(
		panel,
		_item_tooltip,
		func() -> Dictionary:
			return ItemTooltipScript.build_payload_from_catalog(row),
	)
	if _mode == Mode.VIEW:
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_item_tips(uid, row)
		)
	elif _mode == Mode.BULK_SELL:
		var check := Label.new()
		check.text = "✓" if selected else ""
		check.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		check.offset_right = -2
		check.offset_top = 0
		check.add_theme_font_size_override("font_size", 20)
		check.add_theme_color_override("font_color", Color(1.0, 1.0, 0.75, 1.0))
		check.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.08, 1.0))
		check.add_theme_constant_override("outline_size", 3)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(check)
		var price: int = int(row.get("base_price", 0))
		var price_lbl := Label.new()
		price_lbl.text = _format_price(price)
		price_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		price_lbl.offset_right = -4
		price_lbl.offset_bottom = -2
		price_lbl.add_theme_font_size_override("font_size", 10)
		price_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 0.55))
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(price_lbl)
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if _selected_uids.has(uid):
					_selected_uids.erase(uid)
				else:
					_selected_uids[uid] = true
				_refresh_grid()
				_update_sell_bar()
		)
	return panel


func _add_tactical_items_to_grid(page: Dictionary, cols: int, rows: int, occupancy: Array) -> int:
	if _page_index != 0:
		return 0
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical == null:
		return 0
	var catalog: TacticalItemCatalog = tactical.get_catalog()
	if catalog == null:
		return 0
	var cells_used: int = 0
	for item in catalog.get_all_items():
		var item_id: String = str(item.get("id", ""))
		var count: int = int(tactical.get_count(item_id))
		if count <= 0:
			continue
		var pos: Vector2i = PersistentGridUtilScript.find_first_fit(occupancy, 1, 1, cols, rows)
		if pos.x < 0:
			break
		PersistentGridUtilScript.occupy(occupancy, pos.x, pos.y, 1, 1)
		_items_layer.add_child(_make_tactical_item_block(item, item_id, count, pos.x, pos.y))
		cells_used += 1
	return cells_used


func _make_tactical_item_block(item: Dictionary, item_id: String, count: int, gx: int, gy: int) -> PanelContainer:
	var uid: String = _tactical_uid(item_id)
	var catalog_row: Dictionary = _catalog.get_item(item_id) if _catalog else {}
	var span: Vector2 = _cell_span(1, 1)
	var panel := PanelContainer.new()
	panel.position = _cell_origin(gx, gy)
	panel.size = span
	panel.custom_minimum_size = span
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var q_enum: int = TacticalCatalogScript.quality_to_enum(str(item.get("quality", "white")))
	panel.add_theme_stylebox_override("panel", ItemQualityFrameScript.transparent_panel_style())
	panel.add_child(ItemQualityFrameScript.make_frame_rect(q_enum))
	var inner := Control.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var selected: bool = _mode == Mode.BULK_SELL and _selected_uids.has(uid)
	if selected:
		var sel_bg := ColorRect.new()
		sel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sel_bg.color = Color(0.15, 0.55, 0.32, 0.42)
		sel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(sel_bg)
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 14
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path: String = str(item.get("icon_path", ""))
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	else:
		icon.texture = ItemQualityFrameScript.load_texture(q_enum)
	inner.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", ""))
	name_lbl.position = Vector2(4, 2)
	name_lbl.size = Vector2(span.x - 8.0, 14.0)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_lbl)
	if count > 1:
		var qty := Label.new()
		qty.text = "x%d" % count
		qty.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		qty.offset_right = -3
		qty.offset_bottom = -1
		qty.add_theme_font_size_override("font_size", 11)
		qty.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(qty)
	ItemTooltipScript.bind_hover(
		panel,
		_item_tooltip,
		func() -> Dictionary:
			return ItemTooltipScript.build_payload_from_catalog(catalog_row),
	)
	if _mode == Mode.VIEW:
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_open_item_tips(uid, catalog_row)
		)
	elif _mode == Mode.BULK_SELL:
		var price_lbl := Label.new()
		price_lbl.text = _format_price(int(catalog_row.get("base_price", 0)) * count)
		price_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		price_lbl.offset_right = -4
		price_lbl.offset_bottom = -2
		price_lbl.add_theme_font_size_override("font_size", 10)
		price_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 0.55))
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(price_lbl)
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if _selected_uids.has(uid):
					_selected_uids.erase(uid)
				else:
					_selected_uids[uid] = true
				_refresh_grid()
				_update_sell_bar()
		)
	return panel


func _open_item_tips(uid: String, catalog_row: Dictionary) -> void:
	if _item_tips == null:
		return
	_item_tips.show_item(catalog_row, {"uid": uid, "show_sell_button": true})


func _on_item_tips_closed() -> void:
	pass


func _on_item_tips_sell(uid: String) -> void:
	if uid.is_empty() or _catalog == null:
		return
	if _is_tactical_uid(uid):
		var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
		var tactical_id: String = _tactical_id_from_uid(uid)
		var row: Dictionary = _catalog.get_item(tactical_id)
		var price: int = int(row.get("base_price", 0))
		if not tactical or not tactical.sell_items(tactical_id, 1):
			return
		var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
		if portfolio and price > 0 and portfolio.has_method("add_silver"):
			portfolio.add_silver(price)
		_item_tips.hide_popup()
		_refresh_all()
		return
	if _warehouse_node == null:
		return
	var entry := _find_item_by_uid(uid)
	if entry.is_empty():
		_item_tips.hide_popup()
		return
	var row: Dictionary = _catalog.get_item(str(entry.get("item_id", "")))
	var price: int = int(row.get("base_price", 0))
	_warehouse_node.remove_items_by_uid([uid])
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio and price > 0 and portfolio.has_method("add_silver"):
		portfolio.add_silver(price)
	_item_tips.hide_popup()
	_refresh_all()


func _enter_bulk_sell() -> void:
	if _item_tips:
		_item_tips.hide_popup()
	_mode = Mode.BULK_SELL
	_selected_uids.clear()
	_sell_bar.visible = true
	_hint_label.text = "点击道具勾选 / 按品质快捷选择"
	_refresh_grid()
	_update_sell_bar()


func _exit_bulk_sell() -> void:
	_mode = Mode.VIEW
	_selected_uids.clear()
	_sell_bar.visible = false
	_hint_label.text = "「全局整理」将红色品质道具优先放入藏品箱"
	_refresh_grid()


func _update_sell_bar() -> void:
	var total: int = 0
	var count: int = 0
	if _catalog:
		for uid in _selected_uids.keys():
			var entry := _find_item_by_uid(str(uid))
			if _is_tactical_uid(str(uid)):
				var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
				var tactical_id: String = _tactical_id_from_uid(str(uid))
				var tactical_count: int = int(tactical.get_count(tactical_id)) if tactical else 0
				total += int(_catalog.get_item(tactical_id).get("base_price", 0)) * tactical_count
				count += tactical_count
			elif not entry.is_empty():
				var row: Dictionary = _catalog.get_item(str(entry.get("item_id", "")))
				total += int(row.get("base_price", 0))
				count += 1
	_sell_total_label.text = "已选 %d 件 · %s" % [count, _format_price(total)]
	_update_quality_btn_states()


func _on_quality_sell_toggled(quality: int) -> void:
	if _updating_quality_btns:
		return
	var uids := _get_page_uids_of_quality(quality)
	if _quality_btns[quality].button_pressed:
		for uid in uids:
			_selected_uids[uid] = true
	else:
		for uid in uids:
			_selected_uids.erase(uid)
	_refresh_grid()
	_update_sell_bar()


func _update_quality_btn_states() -> void:
	_updating_quality_btns = true
	for q in GameConstants.QUALITY_COUNT:
		if q >= _quality_btns.size():
			break
		var uids := _get_page_uids_of_quality(q)
		var all_selected: bool = not uids.is_empty()
		for uid in uids:
			if not _selected_uids.has(uid):
				all_selected = false
				break
		_quality_btns[q].button_pressed = all_selected
	_updating_quality_btns = false


func _get_page_uids_of_quality(quality: int) -> Array[String]:
	var result: Array[String] = []
	if _warehouse_node == null or _catalog == null:
		return result
	var page: Dictionary = _warehouse_node.get_page(_page_index)
	for entry in page.get("items", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = _catalog.get_item(str(entry.get("item_id", "")))
		if int(row.get("quality_enum", 0)) == quality:
			result.append(str(entry.get("uid", "")))
	if _page_index == 0:
		var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
		if tactical:
			for item in tactical.get_catalog().get_all_items():
				var item_id: String = str(item.get("id", ""))
				if tactical.get_count(item_id) > 0 and TacticalCatalogScript.quality_to_enum(str(item.get("quality", "white"))) == quality:
					result.append(_tactical_uid(item_id))
	return result


func _confirm_bulk_sell() -> void:
	if _selected_uids.is_empty() or _warehouse_node == null:
		return
	var uids: Array[String] = []
	for uid in _selected_uids.keys():
		uids.append(str(uid))
	var total: int = 0
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if _catalog:
		for uid in uids:
			if _is_tactical_uid(uid):
				var tactical_id: String = _tactical_id_from_uid(uid)
				var tactical_count: int = int(tactical.get_count(tactical_id)) if tactical else 0
				total += int(_catalog.get_item(tactical_id).get("base_price", 0)) * tactical_count
				if tactical and tactical_count > 0:
					tactical.sell_items(tactical_id, tactical_count)
			else:
				var entry := _find_item_by_uid(uid)
				var row: Dictionary = _catalog.get_item(str(entry.get("item_id", "")))
				total += int(row.get("base_price", 0))
	var warehouse_uids: Array[String] = []
	for uid in uids:
		if not _is_tactical_uid(uid):
			warehouse_uids.append(uid)
	_warehouse_node.remove_items_by_uid(warehouse_uids)
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio and total > 0 and portfolio.has_method("add_silver"):
		portfolio.add_silver(total)
	_selected_uids.clear()
	_exit_bulk_sell()


func _on_organize_pressed() -> void:
	if _warehouse_node and _catalog:
		_warehouse_node.auto_organize_page(_page_index, _catalog)


func _on_organize_all_pressed() -> void:
	if _warehouse_node and _catalog:
		_warehouse_node.auto_organize_all(_catalog)


func _find_item_by_uid(uid: String) -> Dictionary:
	if _warehouse_node == null:
		return {}
	for entry in _warehouse_node.get_page(_page_index).get("items", []):
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("uid", "")) == uid:
			return entry
	return {}


func _tactical_uid(item_id: String) -> String:
	return "tactical:" + item_id


func _is_tactical_uid(uid: String) -> bool:
	return uid.begins_with("tactical:")


func _tactical_id_from_uid(uid: String) -> String:
	return uid.trim_prefix("tactical:")


func _grid_pixel_size(cols: int, rows: int) -> Vector2:
	return Vector2(
		cols * CELL_SIZE + (cols - 1) * CELL_GAP,
		rows * CELL_SIZE + (rows - 1) * CELL_GAP,
	)


func _cell_origin(gx: int, gy: int) -> Vector2:
	return Vector2(gx * (CELL_SIZE + CELL_GAP), gy * (CELL_SIZE + CELL_GAP))


func _cell_span(sw: int, sh: int) -> Vector2:
	return Vector2(
		sw * CELL_SIZE + (sw - 1) * CELL_GAP,
		sh * CELL_SIZE + (sh - 1) * CELL_GAP,
	)


func _make_cell(gx: int, gy: int) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.position = _cell_origin(gx, gy)
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.size = Vector2(CELL_SIZE, CELL_SIZE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.1, 0.55)
	sb.border_color = Color(0.45, 0.52, 0.62, 0.4)
	sb.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", sb)
	return cell


func _format_price(amount: int) -> String:
	if amount >= 1000000:
		return "%.1fM" % (float(amount) / 1000000.0)
	if amount >= 1000:
		return "%.1fK" % (float(amount) / 1000.0)
	return str(amount)
