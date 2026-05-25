class_name ShopUI
extends Control
## 商店：分类分页 + 商品格，仓库扩展箱永久限购

signal closed
signal warehouse_refresh_requested

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")
const ShopCatalogScript = preload("res://scripts/data/shop_catalog.gd")
const UiTextureCacheScript = preload("res://scripts/ui/ui_texture_cache.gd")

const COLOR_ACCENT: Color = Color(0.88, 0.95, 0.38, 1.0)
const MASCOT_RESERVE_RIGHT: int = 268
var _catalog: ShopCatalog = null
var _item_catalog = null
var _category_id: String = "items"
var _category_buttons: Array[Button] = []
var _category_ids: Array[String] = []
var _product_grid: GridContainer
var _silver_label: Label
var _section_title: Label
var _toast_callback: Callable


func _ready() -> void:
	_catalog = ShopCatalogScript.new()
	_catalog.load_all()
	_build_shell()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()


func setup(item_catalog, toast_callback: Callable = Callable()) -> void:
	_item_catalog = item_catalog
	_toast_callback = toast_callback


func open() -> void:
	_refresh_silver()
	_select_category(_category_id)
	show()
	move_to_front()


func close() -> void:
	hide()
	closed.emit()


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background_layer()
	_build_mascot_layer()
	var root := MarginContainer.new()
	root.name = "ContentRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 22)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", MASCOT_RESERVE_RIGHT)
	root.add_theme_constant_override("margin_bottom", 14)
	add_child(root)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)
	vbox.add_child(_build_top_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)
	body.add_child(_build_category_sidebar())
	body.add_child(_build_product_panel())


func _build_background_layer() -> void:
	UiTextureCacheScript.add_shop_background_layers(self)


func _build_mascot_layer() -> void:
	var tex: Texture2D = UiTextureCacheScript.get_shopgirl()
	if tex == null:
		return
	var mascot := TextureRect.new()
	mascot.name = "ShopMascot"
	mascot.texture = tex
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascot.anchor_left = 0.74
	mascot.anchor_top = 0.1
	mascot.anchor_right = 0.99
	mascot.anchor_bottom = 1.0
	mascot.offset_left = 0.0
	mascot.offset_top = 0.0
	mascot.offset_right = -12.0
	mascot.offset_bottom = -12.0
	add_child(mascot)


func _build_top_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_row)
	var cart := Label.new()
	cart.text = "🛒"
	cart.add_theme_font_size_override("font_size", 22)
	title_row.add_child(cart)
	var title := Label.new()
	title.text = "商店"
	FontUtilScript.style_title_label(title, 28)
	title_row.add_child(title)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 16)
	_silver_label = Label.new()
	_silver_label.add_theme_font_size_override("font_size", 16)
	_silver_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	money_row.add_child(_make_money_chip(true))
	money_row.add_child(_silver_label)
	row.add_child(money_row)
	UiCloseButtonScript.append_to_header(row, close)
	return row


func _make_money_chip(is_silver: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.color = Color(0.75, 0.78, 0.85) if is_silver else Color(0.95, 0.82, 0.35)
	row.add_child(icon)
	UiMoneyIconScript.replace_color_rect(icon)
	return row


func _build_category_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(132, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.82)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.3, 0.38, 0.6)
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(vbox)
	panel.add_child(margin)
	if _catalog:
		for cat in _catalog.get_categories(true):
			var cid: String = str(cat.get("id", ""))
			_category_ids.append(cid)
			var btn := Button.new()
			btn.text = str(cat.get("name", cid))
			btn.toggle_mode = true
			btn.custom_minimum_size = Vector2(108, 42)
			_category_buttons.append(btn)
			btn.pressed.connect(func() -> void: _select_category(cid))
			vbox.add_child(btn)
	return panel


func _build_product_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.68)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.32, 0.42, 0.55)
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(vbox)
	panel.add_child(margin)
	_section_title = Label.new()
	_section_title.text = "全部商品"
	_section_title.add_theme_font_size_override("font_size", 16)
	_section_title.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	vbox.add_child(_section_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_product_grid = GridContainer.new()
	_product_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_product_grid.columns = 3
	_product_grid.add_theme_constant_override("h_separation", 12)
	_product_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_product_grid)
	return panel


func _select_category(category_id: String) -> void:
	_category_id = category_id
	for i in _category_buttons.size():
		var btn: Button = _category_buttons[i]
		var active: bool = i < _category_ids.size() and _category_ids[i] == category_id
		btn.button_pressed = active
		if active:
			UiButtonStyleScript.apply(btn, COLOR_ACCENT, 13)
		else:
			UiButtonStyleScript.apply(btn, Color(0.82, 0.86, 0.94), 13)
	_section_title.text = "全部商品"
	_rebuild_products()


func _category_display_name(category_id: String) -> String:
	if _catalog == null:
		return ""
	for cat in _catalog.get_categories(true):
		if str(cat.get("id", "")) == category_id:
			return str(cat.get("name", ""))
	return ""


func _rebuild_products() -> void:
	for c in _product_grid.get_children():
		c.queue_free()
	if _catalog == null:
		return
	var shop_data: Node = get_node_or_null("/root/PlayerShop")
	for product in _catalog.get_products_for_category(_category_id):
		_product_grid.add_child(_make_product_card(product, shop_data))


func _make_product_card(product: Dictionary, shop_data: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(196, 148)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.92)
	sb.border_color = Color(0.3, 0.36, 0.45, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = str(product.get("name", ""))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	vbox.add_child(name_lbl)
	var desc := Label.new()
	desc.text = str(product.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
	vbox.add_child(desc)
	var price: int = int(product.get("price_silver", 0))
	var price_lbl := Label.new()
	price_lbl.text = "🪙 %s" % _format_comma(price)
	price_lbl.add_theme_font_size_override("font_size", 13)
	price_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 0.55))
	vbox.add_child(price_lbl)
	var product_id: String = str(product.get("product_id", ""))
	var limit: int = int(product.get("purchase_limit", 0))
	var bought: bool = shop_data != null and not shop_data.can_purchase(product)
	var status := Label.new()
	if bought:
		status.text = "已购买"
		status.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	elif limit > 0:
		status.text = "永久限购 %d 次" % limit
		status.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	vbox.add_child(status)
	var buy_btn := Button.new()
	buy_btn.text = "已拥有" if bought else "购买"
	buy_btn.disabled = bought
	UiButtonStyleScript.apply(buy_btn, COLOR_ACCENT if not bought else Color(0.5, 0.52, 0.58), 13)
	buy_btn.pressed.connect(func() -> void: _try_purchase(product))
	vbox.add_child(buy_btn)
	return panel


func _try_purchase(product: Dictionary) -> void:
	var shop_data: Node = get_node_or_null("/root/PlayerShop")
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	var warehouse: Node = get_node_or_null("/root/PlayerWarehouse")
	if shop_data == null or portfolio == null or warehouse == null:
		_show_toast("系统未就绪")
		return
	if not shop_data.can_purchase(product):
		_show_toast("已达购买上限")
		return
	var price: int = int(product.get("price_silver", 0))
	if not portfolio.spend_silver(price):
		_show_toast("银币不足")
		return
	var effect: Dictionary = product.get("effect", {})
	if str(effect.get("type", "")) == "warehouse_page":
		warehouse.unlock_expansion_page(
			str(effect.get("page_name", "扩展仓库")),
			int(effect.get("grid_w", 8)),
			int(effect.get("grid_h", 8)),
			bool(effect.get("is_collection_box", false)),
		)
	shop_data.record_purchase(str(product.get("product_id", "")))
	_show_toast("购买成功：%s" % str(product.get("name", "")))
	_refresh_silver()
	_rebuild_products()
	warehouse_refresh_requested.emit()


func _refresh_silver() -> void:
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio:
		_silver_label.text = _format_comma(int(portfolio.total_assets))


func _show_toast(msg: String) -> void:
	if _toast_callback.is_valid():
		_toast_callback.call(msg)


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
