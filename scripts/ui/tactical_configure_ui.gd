class_name TacticalConfigureUI
extends Control
## 战术道具配置：查看库存、装配口袋、就地购买

signal closed
signal open_shop_requested
signal toast_requested(text: String)
signal inventory_changed

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")
const ShopCatalogScript = preload("res://scripts/data/shop_catalog.gd")

const CATEGORY_FILTERS: Array[Dictionary] = [
	{"id": "", "label": "全部"},
	{"id": "random_reveal", "label": "显示"},
	{"id": "scan", "label": "扫描"},
	{"id": "stock", "label": "存量"},
	{"id": "valuation", "label": "估价"},
	{"id": "random_quality_id", "label": "鉴定"},
	{"id": "avg_cells", "label": "均格"},
	{"id": "omniscient", "label": "全知"},
]

var _catalog: TacticalItemCatalog = null
var _shop_catalog: ShopCatalog = null
var _list: VBoxContainer
var _subtitle: Label
var _active_category_filter: String = ""
var _filter_buttons: Dictionary = {}


func _ready() -> void:
	_build_shell()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func open_panel() -> void:
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical != null:
		_catalog = tactical.get_catalog()
	if _shop_catalog == null:
		_shop_catalog = ShopCatalogScript.new()
		_shop_catalog.load_all()
	refresh()
	show()
	move_to_front()


func refresh() -> void:
	_rebuild_list()
	_refresh_silver_hint()
	if _subtitle:
		var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
		var equipped: int = int(tactical.get_equipped_count()) if tactical else 0
		var max_slots: int = _catalog.get_max_loadout_slots() if _catalog else 5
		_subtitle.text = "口袋：%d/%d（点击有库存的道具装入口袋，点击口袋位可卸下）" % [equipped, max_slots]


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_top = -300
	panel.offset_right = 420
	panel.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.13, 0.96)
	sb.border_color = Color(0.35, 0.4, 0.5, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "战术道具"
	FontUtilScript.style_title_label(title, 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	UiCloseButtonScript.append_to_header(header, _on_close)
	root.add_child(header)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	root.add_child(_subtitle)
	root.add_child(_build_loadout_row())
	root.add_child(_build_category_filter_row())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(760, 360)
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)
	root.add_child(_build_silver_hint_row())


func _build_silver_hint_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var hint := Label.new()
	hint.name = "SilverHint"
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	var silver: int = int(portfolio.total_assets) if portfolio else 0
	hint.text = "当前银币：%s" % _format_comma(silver)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	row.add_child(hint)
	return row


func _refresh_silver_hint() -> void:
	var hint: Label = find_child("SilverHint", true, false) as Label
	if hint == null:
		return
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	var silver: int = int(portfolio.total_assets) if portfolio else 0
	hint.text = "当前银币：%s" % _format_comma(silver)


func _format_comma(n: int) -> String:
	var s: String = str(maxi(0, n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return out


func _build_category_filter_row() -> Control:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "筛选:"
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
	wrap.add_child(label)
	for filter_def in CATEGORY_FILTERS:
		var category_id: String = str(filter_def.get("id", ""))
		var btn := Button.new()
		btn.text = str(filter_def.get("label", category_id))
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(52, 30)
		btn.button_pressed = category_id == _active_category_filter
		btn.pressed.connect(_on_category_filter_pressed.bind(category_id))
		_filter_buttons[category_id] = btn
		_apply_filter_button_style(btn, category_id == _active_category_filter)
		wrap.add_child(btn)
	return wrap


func _apply_filter_button_style(btn: Button, active: bool) -> void:
	if active:
		UiButtonStyleScript.apply(btn, Color(0.88, 0.95, 0.38), 11)
	else:
		UiButtonStyleScript.apply(btn, Color(0.72, 0.76, 0.84), 11)


func _on_category_filter_pressed(category_id: String) -> void:
	_active_category_filter = category_id
	for id in _filter_buttons.keys():
		var btn: Button = _filter_buttons[id] as Button
		if btn == null:
			continue
		var active: bool = str(id) == category_id
		btn.button_pressed = active
		_apply_filter_button_style(btn, active)
	_rebuild_list()


func _build_loadout_row() -> Control:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	sb.border_color = Color(0.25, 0.28, 0.34, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	wrap.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)
	row.add_child(_make_loadout_slots())
	return wrap


func _make_loadout_slots() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "LoadoutSlots"
	row.add_theme_constant_override("separation", 6)
	for i in 5:
		row.add_child(_make_loadout_slot(i))
	return row


func _make_loadout_slot(slot_index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(56, 56)
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("slot_index", slot_index)
	btn.pressed.connect(_on_loadout_slot_pressed.bind(slot_index))
	_apply_loadout_slot_style(btn, slot_index)
	return btn


func _apply_loadout_slot_style(btn: Button, slot_index: int) -> void:
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	var item_id: String = ""
	if tactical and slot_index < tactical.loadout.size():
		item_id = str(tactical.loadout[slot_index])
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	if item_id.is_empty():
		btn.text = "+"
		btn.icon = null
		btn.tooltip_text = ""
		sb.bg_color = Color(0.12, 0.14, 0.18, 0.95)
		sb.border_color = Color(0.35, 0.38, 0.45, 0.7)
	else:
		var item: Dictionary = _catalog.get_item(item_id) if _catalog else {}
		var item_name: String = str(item.get("name", item_id))
		btn.text = ""
		btn.tooltip_text = item_name
		btn.expand_icon = true
		var icon_path: String = str(item.get("icon_path", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path) as Texture2D
		var q: String = str(item.get("quality", "white"))
		sb.border_color = TacticalCatalogScript.quality_color(q)
		sb.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb.duplicate())
	btn.add_theme_stylebox_override("pressed", sb.duplicate())


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _catalog == null:
		return
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	var all_items: Array[Dictionary] = _catalog.get_all_items()
	var rows: Array[Dictionary] = []
	for i in all_items.size():
		var item: Dictionary = all_items[i]
		if not _item_matches_category_filter(item):
			continue
		var item_id: String = str(item.get("id", ""))
		var count: int = int(tactical.get_count(item_id)) if tactical else 0
		rows.append({"item": item, "index": i, "owned": count > 0, "count": count})
	rows.sort_custom(_compare_list_rows)
	for row in rows:
		_list.add_child(_make_item_row(row["item"], tactical, int(row["count"])))


func _item_matches_category_filter(item: Dictionary) -> bool:
	if _active_category_filter.is_empty():
		return true
	return str(item.get("category", "")) == _active_category_filter


func _compare_list_rows(a: Dictionary, b: Dictionary) -> bool:
	var owned_a: bool = bool(a.get("owned", false))
	var owned_b: bool = bool(b.get("owned", false))
	if owned_a != owned_b:
		return owned_a
	return int(a.get("index", 0)) < int(b.get("index", 0))


func _make_item_row(item: Dictionary, tactical: Node, count: int = -1) -> PanelContainer:
	var item_id: String = str(item.get("id", ""))
	if count < 0:
		count = int(tactical.get_count(item_id)) if tactical else 0
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.85)
	sb.border_color = Color(0.18, 0.2, 0.26, 0.9)
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = str(item.get("icon_path", ""))
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	row.add_child(icon)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)
	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", item_id))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)
	var qty := Label.new()
	qty.text = "数量：%d" % count
	qty.add_theme_font_size_override("font_size", 13)
	qty.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55) if count > 0 else Color(0.92, 0.35, 0.32))
	name_row.add_child(qty)
	text_col.add_child(name_row)
	var desc := Label.new()
	desc.text = str(item.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	text_col.add_child(desc)
	var action := Button.new()
	var price: int = _get_item_price(item_id, item)
	if count > 0:
		action.text = "装入"
		UiButtonStyleScript.apply(action, Color(0.88, 0.95, 0.38), 12)
		action.pressed.connect(_on_equip_pressed.bind(item_id))
	else:
		action.text = "购买 %s" % _format_comma(price)
		UiButtonStyleScript.apply(action, Color(0.95, 0.82, 0.38), 12)
		action.pressed.connect(_on_purchase_pressed.bind(item_id))
	row.add_child(action)
	return panel


func _get_item_price(item_id: String, item: Dictionary) -> int:
	if _shop_catalog == null:
		_shop_catalog = ShopCatalogScript.new()
		_shop_catalog.load_all()
	var product: Dictionary = _shop_catalog.get_product_by_tactical_id(item_id)
	if not product.is_empty():
		return int(product.get("price_silver", 0))
	return int(item.get("shop_price", 0))


func _on_purchase_pressed(item_id: String) -> void:
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if portfolio == null or tactical == null:
		_show_toast("系统未就绪")
		return
	if _shop_catalog == null:
		_shop_catalog = ShopCatalogScript.new()
		_shop_catalog.load_all()
	var product: Dictionary = _shop_catalog.get_product_by_tactical_id(item_id)
	var item: Dictionary = _catalog.get_item(item_id) if _catalog else {}
	var price: int = int(product.get("price_silver", item.get("shop_price", 0)))
	if price <= 0:
		_show_toast("无法购买该道具")
		return
	if not portfolio.spend_silver(price):
		_show_toast("银币不足")
		return
	tactical.add_items(item_id, maxi(1, int(product.get("effect", {}).get("grant_count", 1))))
	var name: String = str(product.get("name", item.get("name", item_id)))
	_show_toast("购买成功：%s" % name)
	inventory_changed.emit()
	_refresh_silver_hint()
	refresh()


func _show_toast(msg: String) -> void:
	toast_requested.emit(msg)


func _on_equip_pressed(item_id: String) -> void:
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical == null:
		return
	var max_slots: int = _catalog.get_max_loadout_slots()
	for i in max_slots:
		if i >= tactical.loadout.size():
			break
		if str(tactical.loadout[i]).strip_edges() == item_id:
			_show_toast("该道具已在口袋中")
			return
	for i in max_slots:
		if i >= tactical.loadout.size():
			break
		if str(tactical.loadout[i]).strip_edges().is_empty():
			tactical.set_loadout_slot(i, item_id)
			_refresh_loadout_slots()
			refresh()
			return
	_show_toast("口袋已满，请先点击口袋位卸下")


func _on_loadout_slot_pressed(slot_index: int) -> void:
	var tactical: Node = get_node_or_null("/root/PlayerTacticalItems")
	if tactical == null:
		return
	tactical.clear_loadout_slot(slot_index)
	_refresh_loadout_slots()
	refresh()


func _refresh_loadout_slots() -> void:
	var slots_row: HBoxContainer = find_child("LoadoutSlots", true, false) as HBoxContainer
	if slots_row == null:
		return
	for child in slots_row.get_children():
		if child is Button:
			var idx: int = int(child.get_meta("slot_index", 0))
			_apply_loadout_slot_style(child as Button, idx)


func _on_close() -> void:
	hide()
	closed.emit()
