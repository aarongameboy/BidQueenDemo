class_name ItemEncyclopedia
extends CanvasLayer
## 藏品百科弹窗（参考截图：左筛选 + 右藏品列表）

signal closed

const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const SizeOutlineButtonScript = preload("res://scripts/ui/size_outline_button.gd")
const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")
const UiTextureCacheScript = preload("res://scripts/ui/ui_texture_cache.gd")

const ENCYCLOPEDIA_BG_DIM_ALPHA: float = 0.55

const QUALITY_ORDER: PackedStringArray = GameConstants.QUALITY_KEYS
const TYPE_LABELS: Dictionary = ItemCatalogScript.TYPE_LABELS
const TYPE_ORDER: PackedStringArray = ItemCatalogScript.TYPE_ORDER

var _catalog = null
var _panel: PanelContainer
var _avg_label: Label
var _items_grid: GridContainer
var _filter_quality: Dictionary = {}
var _filter_types: Dictionary = {}
var _filter_size_key: String = ""
var _quality_checks: Array[CheckBox] = []
var _type_checks: Array[CheckBox] = []
var _size_buttons: Array[SizeOutlineButton] = []
var _filter_section_labels: Array[Label] = []
var _quality_option_labels: Array[Label] = []
var _item_tooltip: ItemTooltip


## 低于 MatchUI 结算层(68)，高于对局主 UI
const LAYER_NORMAL: int = 60
## 结算展示时百科需盖在 SettlementLayer(68) 之上，仍低于重启按钮层(72)
const LAYER_ABOVE_SETTLEMENT: int = 70

func _init(catalog) -> void:
	_catalog = catalog
	layer = LAYER_NORMAL


func _ready() -> void:
	_build_ui()
	FontUtilScript.apply_cjk_font(_panel, 13)
	_apply_filter_typography()
	_reset_filters()
	_refresh_list()


func open() -> void:
	show()
	_refresh_list()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "DimOverlay"
	dim.color = Color(0.0, 0.0, 0.0, ENCYCLOPEDIA_BG_DIM_ALPHA)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close()
	)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1100, 640)
	_panel.offset_left = -550
	_panel.offset_top = -320
	_panel.offset_right = 550
	_panel.offset_bottom = 320
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.1, 0.96)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.28, 0.28)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	_panel.add_child(root)
	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(300, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb_side := StyleBoxFlat.new()
	sb_side.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	sb_side.content_margin_left = 12
	sb_side.content_margin_right = 12
	sb_side.content_margin_top = 12
	sb_side.content_margin_bottom = 12
	sidebar.add_theme_stylebox_override("panel", sb_side)
	root.add_child(sidebar)
	var side_scroll := ScrollContainer.new()
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sidebar.add_child(side_scroll)
	var side_v := VBoxContainer.new()
	side_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_v.add_theme_constant_override("separation", 8)
	side_scroll.add_child(side_v)
	_add_section_title(side_v, "品质")
	var q_grid := GridContainer.new()
	q_grid.columns = 2
	q_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_grid.add_theme_constant_override("h_separation", 6)
	q_grid.add_theme_constant_override("v_separation", 4)
	side_v.add_child(q_grid)
	for i in QUALITY_ORDER.size():
		var q_key: String = QUALITY_ORDER[i]
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(0, 22)
		var cb := CheckBox.new()
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = false
		cb.toggled.connect(func(pressed: bool) -> void: _on_quality_toggled(q_key, pressed))
		row.add_child(cb)
		var q_lbl := Label.new()
		q_lbl.text = GameConstants.QUALITY_NAMES[i]
		q_lbl.add_theme_font_size_override("font_size", 12)
		q_lbl.add_theme_color_override("font_color", GameConstants.get_quality_color(i))
		q_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q_lbl.clip_text = true
		row.add_child(q_lbl)
		_quality_option_labels.append(q_lbl)
		q_grid.add_child(row)
		_quality_checks.append(cb)
	_add_section_title(side_v, "类型")
	var type_grid := GridContainer.new()
	type_grid.columns = 2
	type_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_grid.add_theme_constant_override("h_separation", 4)
	type_grid.add_theme_constant_override("v_separation", 2)
	side_v.add_child(type_grid)
	for type_id in TYPE_ORDER:
		var tcb := CheckBox.new()
		tcb.text = TYPE_LABELS[type_id]
		tcb.focus_mode = Control.FOCUS_NONE
		tcb.add_theme_font_size_override("font_size", 11)
		tcb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tcb.clip_text = true
		tcb.custom_minimum_size = Vector2(128, 24)
		tcb.toggled.connect(func(pressed: bool) -> void: _on_type_toggled(type_id, pressed))
		type_grid.add_child(tcb)
		_type_checks.append(tcb)
	_add_section_title(side_v, "轮廓")
	var size_grid := GridContainer.new()
	size_grid.columns = 3
	size_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_grid.add_theme_constant_override("h_separation", 4)
	size_grid.add_theme_constant_override("v_separation", 4)
	side_v.add_child(size_grid)
	if _catalog:
		for sz in _catalog.get_unique_sizes():
			var ob := SizeOutlineButtonScript.new(sz["size_w"], sz["size_h"])
			var size_key: String = sz["key"]
			ob.toggled.connect(func(pressed: bool) -> void: _on_size_toggled(size_key, ob, pressed))
			ob.apply_filter_label_style()
			size_grid.add_child(ob)
			_size_buttons.append(ob)
	var all_size_btn := Button.new()
	all_size_btn.text = "全部尺寸"
	all_size_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_size_btn.custom_minimum_size = Vector2(0, 36)
	all_size_btn.pressed.connect(_on_all_sizes)
	UiButtonStyleScript.apply(all_size_btn, Color(0.82, 0.86, 0.94), 12)
	side_v.add_child(all_size_btn)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var top_bar := HBoxContainer.new()
	right.add_child(top_bar)
	_avg_label = Label.new()
	_avg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_avg_label.text = "当前筛选藏品平均价值为 —"
	top_bar.add_child(_avg_label)
	UiCloseButtonScript.append_to_header(top_bar, close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	_items_grid = GridContainer.new()
	_items_grid.columns = 2
	_items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_grid.add_theme_constant_override("h_separation", 12)
	_items_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_items_grid)
	_item_tooltip = ItemTooltipScript.new()
	_panel.add_child(_item_tooltip)


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	parent.add_child(l)
	_filter_section_labels.append(l)


func _apply_filter_typography() -> void:
	for l in _filter_section_labels:
		FontUtilScript.style_semibold_label(l, 14)
	for l in _quality_option_labels:
		FontUtilScript.style_semibold_label(l, 12)
	for tcb in _type_checks:
		FontUtilScript.apply_semibold_font(tcb, 11)
	for ob in _size_buttons:
		ob.apply_filter_label_style()


func _reset_filters() -> void:
	_filter_quality.clear()
	_filter_types.clear()
	_filter_size_key = ""
	_sync_filter_checkboxes()


func _sync_filter_checkboxes() -> void:
	for cb in _quality_checks:
		cb.set_pressed_no_signal(false)
	for tcb in _type_checks:
		tcb.set_pressed_no_signal(false)
	for ob in _size_buttons:
		ob.set_pressed_no_signal(false)
		ob.sync_visual_state()


func _on_quality_toggled(quality: String, pressed: bool) -> void:
	if pressed:
		_filter_quality[quality] = true
	else:
		_filter_quality.erase(quality)
	_refresh_list()


func _on_type_toggled(type_id: String, pressed: bool) -> void:
	if pressed:
		_filter_types[type_id] = true
	else:
		_filter_types.erase(type_id)
	_refresh_list()


func _on_size_toggled(key: String, btn: SizeOutlineButton, pressed: bool) -> void:
	if pressed:
		for ob in _size_buttons:
			if ob != btn:
				ob.set_pressed_no_signal(false)
				ob.sync_visual_state()
		_filter_size_key = key
	else:
		_filter_size_key = ""
	btn.sync_visual_state()
	_refresh_list()


func _on_all_sizes() -> void:
	_filter_size_key = ""
	for ob in _size_buttons:
		ob.set_pressed_no_signal(false)
		ob.sync_visual_state()
	_refresh_list()


func _filtered_items() -> Array:
	var list: Array = []
	if _catalog == null:
		return list
	for item in _catalog.get_all_items():
		if not _filter_quality.is_empty() and not _filter_quality.has(item["quality"]):
			continue
		if not _filter_types.is_empty() and not _filter_types.has(item.get("item_type", "")):
			continue
		if _filter_size_key != "":
			var key: String = "%d_%d" % [item["size_w"], item["size_h"]]
			if key != _filter_size_key:
				continue
		list.append(item)
	return list


func _refresh_list() -> void:
	for c in _items_grid.get_children():
		c.queue_free()
	var items: Array = _filtered_items()
	var sum_val: int = 0
	for item in items:
		sum_val += int(item["base_price"])
		_items_grid.add_child(_make_item_card(item))
	var avg: int = sum_val / maxi(items.size(), 1)
	_avg_label.text = "当前筛选藏品平均价值为 %s" % _format_comma(avg)


func _make_item_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 200)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.14, 0.92)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(v)
	var name_l := Label.new()
	name_l.text = item["item_name"]
	name_l.add_theme_font_size_override("font_size", 16)
	v.add_child(name_l)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var q_idx: int = int(item.get("quality_enum", 0))
	var icon_host := Control.new()
	icon_host.custom_minimum_size = Vector2(120, 120)
	icon_host.add_child(ItemQualityFrameScript.make_frame_rect(q_idx))
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
	icon.texture = ItemIconUtilScript.get_texture(item)
	icon_host.add_child(icon)
	body.add_child(icon_host)
	var foot_col := VBoxContainer.new()
	foot_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(foot_col)
	foot_col.add_child(SizeOutlineButtonScript.new(item["size_w"], item["size_h"]))
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_END
	var price := Label.new()
	price.text = "🪙 %s" % _format_comma(int(item["base_price"]))
	price.add_theme_font_size_override("font_size", 14)
	price_row.add_child(price)
	v.add_child(price_row)
	ItemTooltipScript.bind_hover(
		card,
		_item_tooltip,
		func() -> Dictionary:
			return ItemTooltipScript.build_payload_from_catalog(item),
	)
	return card


static func _format_comma(amount: int) -> String:
	var s: String = str(amount)
	var out: String = ""
	var n: int = s.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
