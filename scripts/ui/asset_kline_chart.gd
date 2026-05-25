class_name AssetKlineChart
extends Control
## 当日总资产 K 线：点击/悬停显示资产与较昨日资产涨跌幅

const COLOR_UP: Color = Color(0.95, 0.32, 0.28, 1.0)
const COLOR_DOWN: Color = Color(0.28, 0.88, 0.52, 1.0)
const GRID_COLOR: Color = Color(0.22, 0.26, 0.34, 0.45)
const WICK_WIDTH: float = 0.85
const BODY_WIDTH_RATIO: float = 0.42
const MIN_BODY_H: float = 1.5
const TOOLTIP_OFFSET: Vector2 = Vector2(14.0, -10.0)
const MIN_HIT_W: float = 10.0

var _values: PackedFloat32Array = PackedFloat32Array()
var _is_up: bool = true
var _yesterday_close_assets: int = 0
var _chart_rect: Rect2 = Rect2()
var _min_v: float = 0.0
var _max_v: float = 1.0
var _slot_w: float = 1.0
var _body_w: float = 4.0
var _hit_rects: Array[Rect2] = []
var _hit_indices: PackedInt32Array = PackedInt32Array()
var _hover_index: int = -1

var _tooltip: PanelContainer
var _tooltip_asset_label: Label
var _tooltip_pct_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_build_tooltip()
	resized.connect(_on_chart_resized)
	mouse_exited.connect(_on_mouse_exited)


func set_series(
	values: PackedFloat32Array,
	is_up_day: bool,
	yesterday_close_assets: int = 0,
) -> void:
	_values = values
	_is_up = is_up_day
	_yesterday_close_assets = maxi(0, yesterday_close_assets)
	_hover_index = -1
	_hide_tooltip()
	_rebuild_layout_cache()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _values.size() < 2:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var idx: int = _pick_bar_index(motion.position)
		if idx >= 0:
			_hover_index = idx
			_show_tooltip_for_index(idx, motion.global_position)
		else:
			_hover_index = -1
			_hide_tooltip()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var idx: int = _pick_bar_index(mb.position)
			if idx >= 0:
				_show_tooltip_for_index(idx, mb.global_position)
				accept_event()
			else:
				_hide_tooltip()


func _on_mouse_exited() -> void:
	_hover_index = -1
	_hide_tooltip()


func _draw() -> void:
	_rebuild_layout_cache()
	var rect: Rect2 = _chart_rect
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	_draw_grid(rect)
	if _values.size() < 2:
		return
	var min_v: float = _min_v
	var max_v: float = _max_v
	var span: float = max_v - min_v
	var slot_w: float = _slot_w
	var body_w: float = _body_w
	for i in range(1, _values.size()):
		var open_v: float = _values[i - 1]
		var close_v: float = _values[i]
		var high_v: float = maxf(open_v, close_v)
		var low_v: float = minf(open_v, close_v)
		var wick_span: float = (high_v - low_v) * 0.08 + span * 0.002
		high_v += wick_span * 0.5
		low_v -= wick_span * 0.5
		var cx: float = rect.position.x + float(i) * slot_w
		var y_high: float = _value_to_y(high_v, min_v, max_v, rect)
		var y_low: float = _value_to_y(low_v, min_v, max_v, rect)
		var y_open: float = _value_to_y(open_v, min_v, max_v, rect)
		var y_close: float = _value_to_y(close_v, min_v, max_v, rect)
		var up_candle: bool = close_v >= open_v
		var col: Color = COLOR_UP if up_candle else COLOR_DOWN
		if i == _hover_index:
			col = col.lightened(0.22)
		draw_line(Vector2(cx, y_high), Vector2(cx, y_low), col, WICK_WIDTH, true)
		var top_y: float = minf(y_open, y_close)
		var bot_y: float = maxf(y_open, y_close)
		if bot_y - top_y < MIN_BODY_H:
			var mid: float = (top_y + bot_y) * 0.5
			top_y = mid - MIN_BODY_H * 0.5
			bot_y = mid + MIN_BODY_H * 0.5
		var body_rect := Rect2(cx - body_w * 0.5, top_y, body_w, bot_y - top_y)
		draw_rect(body_rect, col, true)
	if _hover_index == 0:
		var x0: float = rect.position.x
		var y0: float = _value_to_y(_values[0], min_v, max_v, rect)
		var hl: Color = COLOR_UP if _is_up else COLOR_DOWN
		draw_circle(Vector2(x0, y0), 4.0, Color(hl.r, hl.g, hl.b, 0.35))
		draw_circle(Vector2(x0, y0), 2.0, hl.lightened(0.2))
	var end_pt := Vector2(
		rect.position.x + rect.size.x,
		_value_to_y(_values[_values.size() - 1], min_v, max_v, rect),
	)
	var end_col: Color = COLOR_UP if _is_up else COLOR_DOWN
	draw_circle(end_pt, 2.0, Color(end_col.r, end_col.g, end_col.b, 0.35))
	draw_circle(end_pt, 1.0, end_col)


func _rebuild_layout_cache() -> void:
	_hit_rects.clear()
	_hit_indices = PackedInt32Array()
	_chart_rect = get_rect().grow(-8.0)
	if _values.size() < 2 or _chart_rect.size.x < 8.0:
		return
	_min_v = _values[0]
	_max_v = _values[0]
	for v in _values:
		_min_v = minf(_min_v, v)
		_max_v = maxf(_max_v, v)
	if is_equal_approx(_min_v, _max_v):
		_min_v -= 1.0
		_max_v += 1.0
	var pad: float = (_max_v - _min_v) * 0.08
	_min_v -= pad
	_max_v += pad
	_slot_w = _chart_rect.size.x / float(_values.size() - 1)
	_body_w = clampf(_slot_w * BODY_WIDTH_RATIO, 2.0, 8.0)
	var half_hit: float = maxf(maxf(_body_w * 0.55, _slot_w * 0.42), MIN_HIT_W * 0.5)
	var x0: float = _chart_rect.position.x
	_hit_rects.append(Rect2(x0 - half_hit, _chart_rect.position.y, half_hit * 2.0, _chart_rect.size.y))
	_hit_indices.append(0)
	for i in range(1, _values.size()):
		var cx: float = _chart_rect.position.x + float(i) * _slot_w
		_hit_rects.append(Rect2(cx - half_hit, _chart_rect.position.y, half_hit * 2.0, _chart_rect.size.y))
		_hit_indices.append(i)


func _pick_bar_index(local_pos: Vector2) -> int:
	for j in _hit_rects.size():
		if _hit_rects[j].has_point(local_pos):
			return _hit_indices[j]
	return -1


func _show_tooltip_for_index(index: int, global_mouse: Vector2) -> void:
	if index < 0 or index >= _values.size():
		return
	var assets: int = maxi(0, int(_values[index]))
	var base: int = _yesterday_close_assets
	var change: int = assets - base
	var pct: float = 0.0
	if base > 0:
		pct = float(change) / float(base) * 100.0
	var sign: String = "+" if change >= 0 else "-"
	var up: bool = change >= 0
	_tooltip_asset_label.text = "资产  %s" % _format_amount(assets)
	_tooltip_pct_label.text = "较昨日资产  %s%.2f%%" % [sign, absf(pct)]
	_tooltip_pct_label.add_theme_color_override(
		"font_color",
		COLOR_UP if up else COLOR_DOWN,
	)
	_tooltip.visible = true
	_tooltip.move_to_front()
	call_deferred("_position_tooltip", global_mouse)


func _position_tooltip(global_mouse: Vector2) -> void:
	if _tooltip == null or not _tooltip.visible:
		return
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var tip_size: Vector2 = _tooltip.get_combined_minimum_size()
	if tip_size.x < 1.0:
		tip_size = Vector2(196.0, 54.0)
	var anchor_global: Vector2 = global_mouse + Vector2(TOOLTIP_OFFSET.x, TOOLTIP_OFFSET.y - tip_size.y)
	var local_pos: Vector2 = inv * anchor_global
	local_pos.x = clampf(local_pos.x, 4.0, size.x - tip_size.x - 4.0)
	local_pos.y = clampf(local_pos.y, 4.0, size.y - tip_size.y - 4.0)
	_tooltip.position = local_pos
	_tooltip.size = tip_size


func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.visible = false


func _on_chart_resized() -> void:
	_rebuild_layout_cache()
	_hide_tooltip()
	queue_redraw()


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 20
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	sb.border_color = Color(0.38, 0.45, 0.58, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_tooltip.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_tooltip.add_child(vbox)
	_tooltip_asset_label = Label.new()
	_tooltip_asset_label.add_theme_font_size_override("font_size", 13)
	_tooltip_asset_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	vbox.add_child(_tooltip_asset_label)
	_tooltip_pct_label = Label.new()
	_tooltip_pct_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_tooltip_pct_label)
	add_child(_tooltip)


func _value_to_y(value: float, min_v: float, max_v: float, rect: Rect2) -> float:
	var t_y: float = (value - min_v) / (max_v - min_v)
	return rect.position.y + rect.size.y * (1.0 - t_y)


func _draw_grid(rect: Rect2) -> void:
	var rows: int = 4
	var cols: int = 6
	for r in range(1, rows):
		var y: float = rect.position.y + rect.size.y * float(r) / float(rows)
		draw_line(
			Vector2(rect.position.x, y),
			Vector2(rect.position.x + rect.size.x, y),
			GRID_COLOR,
			0.85,
		)
	for c in range(1, cols):
		var x: float = rect.position.x + rect.size.x * float(c) / float(cols)
		draw_line(
			Vector2(x, rect.position.y),
			Vector2(x, rect.position.y + rect.size.y),
			GRID_COLOR,
			0.85,
		)


static func _format_amount(amount: int) -> String:
	var n: int = absi(amount)
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out
