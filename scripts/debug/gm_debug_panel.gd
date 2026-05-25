extends CanvasLayer
## 测试 GM 面板：Backspace 呼出/关闭

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")

signal state_changed

var _panel: PanelContainer
var _silver_input: LineEdit
var _item_search: LineEdit
var _item_list: ItemList
var _status_label: Label
var _catalog = null
var _search_rows: Array[Dictionary] = []
var _selected_item_id: String = ""


func _ready() -> void:
	layer = 500
	_build_ui()
	FontUtilScript.apply_cjk_font(_panel, 13)
	hide()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_BACKSPACE:
			toggle_panel()
			get_viewport().set_input_as_handled()


func toggle_panel() -> void:
	if visible:
		hide()
	else:
		_ensure_catalog()
		show()
		layer = 500
		_status_label.text = "GM 测试面板（Backspace 关闭）"
		_refresh_item_search()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			hide()
	)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 520)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	sb.border_color = Color(0.45, 0.55, 0.7, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)
	var title := Label.new()
	title.text = "GM 测试指令"
	FontUtilScript.style_title_label(title, 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	root.add_child(title)
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	root.add_child(_status_label)
	root.add_child(_make_section_label("1. 添加金币"))
	var silver_row := HBoxContainer.new()
	silver_row.add_theme_constant_override("separation", 8)
	root.add_child(silver_row)
	_silver_input = LineEdit.new()
	_silver_input.placeholder_text = "数量，如 100000"
	_silver_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_silver_input.text_submitted.connect(func(_t: String) -> void: _on_add_silver())
	silver_row.add_child(_silver_input)
	var silver_btn := _make_button("添加")
	silver_btn.pressed.connect(_on_add_silver)
	silver_row.add_child(silver_btn)
	root.add_child(_make_section_label("2. 添加道具到仓库（可模糊搜索）"))
	_item_search = LineEdit.new()
	_item_search.placeholder_text = "道具 ID 或名称，如 itm_00001 / 浮尘"
	_item_search.text_changed.connect(_on_item_search_changed)
	root.add_child(_item_search)
	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(0, 140)
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	root.add_child(_item_list)
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 8)
	root.add_child(item_row)
	var item_btn := _make_button("添加选中道具")
	item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_btn.pressed.connect(_on_add_item)
	item_row.add_child(item_btn)
	root.add_child(_make_section_label("3. 仓库 / 藏品"))
	var wh_row := HBoxContainer.new()
	wh_row.add_theme_constant_override("separation", 8)
	root.add_child(wh_row)
	var clear_btn := _make_button("清空仓库")
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear_warehouse)
	wh_row.add_child(clear_btn)
	var coll_btn := _make_button("激活全部藏品")
	coll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coll_btn.pressed.connect(_on_unlock_all_collection)
	wh_row.add_child(coll_btn)


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	UiButtonStyleScript.apply(btn, Color(0.9, 0.92, 1.0), 13)
	return btn


func _ensure_catalog() -> void:
	if _catalog != null and _catalog.is_loaded():
		return
	_catalog = ItemCatalogScript.new()
	if not _catalog.load_all():
		_catalog = null
		_set_status("道具表加载失败", false)


func _on_add_silver() -> void:
	var portfolio: Node = get_node_or_null("/root/PlayerPortfolio")
	if portfolio == null:
		_set_status("PlayerPortfolio 未就绪", false)
		return
	var amount: int = int(_silver_input.text.strip_edges())
	if amount <= 0:
		_set_status("请输入大于 0 的金币数量", false)
		return
	portfolio.add_silver(amount)
	_silver_input.text = ""
	_set_status("已添加 %s 金币，当前总资产 %s" % [
		_format_num(amount),
		_format_num(int(portfolio.total_assets)),
	], true)
	_notify_refresh()


func _on_item_search_changed(_new_text: String) -> void:
	_refresh_item_search()


func _refresh_item_search() -> void:
	_item_list.clear()
	_search_rows.clear()
	_selected_item_id = ""
	if _catalog == null:
		return
	var q: String = _item_search.text.strip_edges()
	if q.is_empty():
		return
	_search_rows = _catalog.search_items(q, 40)
	for item: Dictionary in _search_rows:
		var line: String = "%s  %s" % [
			str(item.get("item_id", "")),
			str(item.get("item_name", "")),
		]
		_item_list.add_item(line)
	if _search_rows.size() == 1:
		_item_list.select(0)
		_on_item_selected(0)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _search_rows.size():
		_selected_item_id = ""
		return
	_selected_item_id = str(_search_rows[index].get("item_id", ""))


func _on_add_item() -> void:
	_ensure_catalog()
	if _catalog == null:
		return
	var item_id: String = _selected_item_id
	if item_id.is_empty():
		var q: String = _item_search.text.strip_edges()
		if not q.is_empty():
			var hits: Array[Dictionary] = _catalog.search_items(q, 1)
			if not hits.is_empty():
				item_id = str(hits[0].get("item_id", ""))
	if item_id.is_empty():
		_set_status("请选择或输入有效道具 ID", false)
		return
	var warehouse: Node = get_node_or_null("/root/PlayerWarehouse")
	if warehouse == null:
		_set_status("PlayerWarehouse 未就绪", false)
		return
	if warehouse.try_add_from_catalog(item_id, _catalog):
		var row: Dictionary = _catalog.get_item(item_id)
		_set_status("已添加 %s（%s）到仓库" % [
			item_id,
			str(row.get("item_name", "")),
		], true)
		_notify_refresh()
	else:
		_set_status("添加失败：仓库已满或 ID 无效 (%s)" % item_id, false)


func _on_clear_warehouse() -> void:
	var warehouse: Node = get_node_or_null("/root/PlayerWarehouse")
	if warehouse == null:
		_set_status("PlayerWarehouse 未就绪", false)
		return
	warehouse.clear_all_items()
	_set_status("仓库已清空", true)
	_notify_refresh()


func _on_unlock_all_collection() -> void:
	_ensure_catalog()
	if _catalog == null:
		return
	var collection: Node = get_node_or_null("/root/PlayerCollection")
	if collection == null:
		_set_status("PlayerCollection 未就绪", false)
		return
	var added: int = collection.unlock_all_red_from_catalog(_catalog)
	_set_status("已激活 %d 件红色藏品（共 %d 件已收藏）" % [
		added,
		collection.collected_count(),
	], true)
	_notify_refresh()


func _set_status(text: String, ok: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override(
		"font_color",
		Color(0.45, 0.9, 0.55) if ok else Color(0.95, 0.45, 0.4),
	)


func _notify_refresh() -> void:
	state_changed.emit()
	var lobby: Node = get_tree().get_first_node_in_group("lobby_ui")
	if lobby and lobby.has_method("refresh_portfolio"):
		lobby.refresh_portfolio()
	var main: Node = get_tree().current_scene
	if main == null:
		return
	var match_ui: Node = main.get_node_or_null("MatchUI")
	if match_ui and match_ui.has_method("_resolve_item_catalog"):
		var catalog = match_ui._resolve_item_catalog()
		var wh_ui = match_ui.get("_warehouse_ui")
		if wh_ui and catalog and wh_ui.has_method("setup") and wh_ui.visible:
			wh_ui.setup(catalog)
			if wh_ui.has_method("open"):
				wh_ui.open()


static func _format_num(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
