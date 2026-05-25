class_name RoomBattleUI
extends Control
## 房间对战：创建/加入 + 等待房间（练习模式）

signal hub_back_pressed
signal room_left

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const RoomNetworkScript = preload("res://scripts/network/room_network.gd")

var _pending_map_id: String = ""
var _pending_mode_id: String = ""

var _hub_panel: Control
var _room_panel: Control
var _join_code_input: LineEdit
var _join_host_input: LineEdit
var _join_port_input: LineEdit
var _room_code_label: Label
var _room_port_hint: Label
var _player_list: VBoxContainer
var _ready_btn: Button
var _status_btn: Button
var _practice_note: Label
var _player_count_option: OptionButton


func _ready() -> void:
	_build_ui()
	FontUtilScript.apply_cjk_font(self, 14)
	hide()
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net:
		net.lobby_state_changed.connect(_on_lobby_state_changed)
		net.lobby_error.connect(_on_lobby_error)
		net.lobby_message.connect(_on_lobby_message)


func open_hub(map_id: String, mode_id: String) -> void:
	_pending_map_id = map_id
	_pending_mode_id = mode_id
	_show_hub()
	show()
	move_to_front()


func _show_hub() -> void:
	_hub_panel.visible = true
	_room_panel.visible = false
	MenuBackgroundScript.set_viewport_dim(0.38)


func _show_room() -> void:
	_hub_panel.visible = false
	_room_panel.visible = true
	_refresh_room_panel()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	MenuBackgroundScript.apply(self, 0.42)
	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 48)
	root.add_theme_constant_override("margin_right", 48)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)
	var stack := Control.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stack)
	_hub_panel = _build_hub_panel()
	stack.add_child(_hub_panel)
	_room_panel = _build_room_panel()
	stack.add_child(_room_panel)
	_room_panel.visible = false
	UiCloseButtonScript.pin_top_right(self, _on_hub_back_pressed)


func _build_hub_panel() -> Control:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.custom_minimum_size = Vector2(520, 0)
	wrap.add_child(col)
	col.add_child(_make_header("在线对战"))
	var create_card := _make_card()
	col.add_child(create_card)
	var create_v := VBoxContainer.new()
	create_v.add_theme_constant_override("separation", 10)
	create_card.add_child(create_v)
	create_v.add_child(_code_comment_label("// 创建房间"))
	var create_desc := Label.new()
	create_desc.text = "生成房间号，发给对手加入"
	create_desc.add_theme_font_size_override("font_size", 12)
	create_desc.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	create_v.add_child(create_desc)
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	create_v.add_child(count_row)
	var count_lbl := Label.new()
	count_lbl.text = "房间人数"
	count_lbl.add_theme_font_size_override("font_size", 13)
	count_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	count_row.add_child(count_lbl)
	_player_count_option = OptionButton.new()
	_player_count_option.add_item("2 人对战", 2)
	_player_count_option.add_item("3 人对战", 3)
	_player_count_option.add_item("4 人对战", 4)
	_player_count_option.selected = 2
	count_row.add_child(_player_count_option)
	var create_btn := _make_slant_button("创建新房间", Color(0.22, 0.48, 0.82))
	create_btn.custom_minimum_size = Vector2(0, 52)
	create_btn.pressed.connect(_on_create_room_pressed)
	create_v.add_child(create_btn)
	var or_lbl := Label.new()
	or_lbl.text = "- OR -"
	or_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
	col.add_child(or_lbl)
	var join_card := _make_card()
	col.add_child(join_card)
	var join_v := VBoxContainer.new()
	join_v.add_theme_constant_override("separation", 10)
	join_card.add_child(join_v)
	join_v.add_child(_code_comment_label("// 加入房间"))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	join_v.add_child(join_row)
	_join_code_input = LineEdit.new()
	_join_code_input.placeholder_text = "输入房间号"
	_join_code_input.max_length = 4
	_join_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_code_input.custom_minimum_size = Vector2(0, 44)
	_style_input(_join_code_input)
	join_row.add_child(_join_code_input)
	var join_btn := _make_slant_button("加入", Color(0.22, 0.48, 0.82))
	join_btn.custom_minimum_size = Vector2(96, 44)
	join_btn.pressed.connect(_on_join_room_pressed)
	join_row.add_child(join_btn)
	var adv := HBoxContainer.new()
	adv.add_theme_constant_override("separation", 8)
	join_v.add_child(adv)
	_join_host_input = LineEdit.new()
	_join_host_input.placeholder_text = "主机 IP（默认 127.0.0.1）"
	_join_host_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_input(_join_host_input)
	adv.add_child(_join_host_input)
	_join_port_input = LineEdit.new()
	_join_port_input.placeholder_text = "端口"
	_join_port_input.text = str(RoomNetworkScript.DEFAULT_PORT)
	_join_port_input.custom_minimum_size = Vector2(88, 0)
	_style_input(_join_port_input)
	adv.add_child(_join_port_input)
	var practice_lbl := Label.new()
	practice_lbl.text = "练习模式 — 免入场费、不计盈亏、战利品不入仓库"
	practice_lbl.add_theme_font_size_override("font_size", 11)
	practice_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
	col.add_child(practice_lbl)
	return wrap


func _build_room_panel() -> Control:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(520, 0)
	wrap.add_child(col)
	col.add_child(_make_header("在线对战"))
	var card := _make_card()
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(_code_comment_label("// 你的房间号"))
	_room_code_label = Label.new()
	_room_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_title_label(_room_code_label, 42)
	_room_code_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.45))
	v.add_child(_room_code_label)
	var hint := Label.new()
	hint.text = "将此号发给最多 3 位对手加入"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	v.add_child(hint)
	_room_port_hint = Label.new()
	_room_port_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_port_hint.add_theme_font_size_override("font_size", 11)
	_room_port_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62))
	v.add_child(_room_port_hint)
	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 6)
	v.add_child(_player_list)
	_ready_btn = _make_slant_button("✋ 准备好了", Color(0.25, 0.72, 0.38))
	_ready_btn.custom_minimum_size = Vector2(0, 48)
	_ready_btn.toggle_mode = true
	_ready_btn.toggled.connect(_on_ready_toggled)
	v.add_child(_ready_btn)
	_status_btn = _make_slant_button("⏳ 等待准备 (0/0)", Color(0.22, 0.48, 0.82))
	_status_btn.disabled = true
	_status_btn.custom_minimum_size = Vector2(0, 44)
	v.add_child(_status_btn)
	_practice_note = Label.new()
	_practice_note.text = "练习模式 — 免入场费、不计盈亏"
	_practice_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_practice_note.add_theme_font_size_override("font_size", 11)
	_practice_note.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
	v.add_child(_practice_note)
	var leave_btn := Button.new()
	leave_btn.text = "离开房间"
	leave_btn.pressed.connect(_on_leave_room_pressed)
	UiButtonStyleScript.apply(leave_btn, Color(0.75, 0.78, 0.85), 13)
	v.add_child(leave_btn)
	return wrap


func _make_header(title: String) -> Control:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FontUtilScript.style_title_label(lbl, 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	return row


func _make_card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	sb.border_color = Color(0.22, 0.28, 0.36)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	return p


func _code_comment_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
	return l


func _make_slant_button(text: String, tint: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.border_color = tint.lightened(0.25)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = tint.lightened(0.12)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	btn.add_theme_font_size_override("font_size", 16)
	return btn


func _style_input(field: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1)
	sb.border_color = Color(0.25, 0.32, 0.42)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(4)
	field.add_theme_stylebox_override("normal", sb)
	field.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	field.add_theme_color_override("font_placeholder_color", Color(0.45, 0.5, 0.58))


func _on_create_room_pressed() -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net == null:
		return
	var player_count: int = 2
	if _player_count_option:
		player_count = int(_player_count_option.get_selected_id())
	var result: Dictionary = net.create_room(_pending_map_id, _pending_mode_id, true, player_count)
	if not result.get("ok", false):
		_on_lobby_error(str(result.get("reason", "创建失败")))
		return
	_show_room()
	_refresh_room_panel()


func _on_join_room_pressed() -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net == null:
		return
	var host: String = _join_host_input.text.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port: int = int(_join_port_input.text.strip_edges())
	if port <= 0:
		port = RoomNetworkScript.DEFAULT_PORT
	var result: Dictionary = net.join_room(_join_code_input.text, host, port)
	if not result.get("ok", false):
		_on_lobby_error(str(result.get("reason", "加入失败")))
		return
	_show_room()
	_refresh_room_panel()
	_join_wait_for_sync(net)


func _on_ready_toggled(ready: bool) -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net == null:
		return
	if not net.is_local_in_lobby():
		_ready_btn.set_block_signals(true)
		_ready_btn.button_pressed = false
		_ready_btn.set_block_signals(false)
		_on_lobby_error("尚未加入房间列表，请稍候或重新加入")
		return
	net.set_local_ready(ready)
	_refresh_room_panel()


func _on_leave_room_pressed() -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net:
		net.leave_room()
	_reset_ready_button()
	_show_hub()
	room_left.emit()


func _on_hub_back_pressed() -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net and net.is_in_room():
		net.leave_room()
	hide()
	hub_back_pressed.emit()


func _on_lobby_state_changed() -> void:
	if not visible:
		return
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net and net.is_in_room():
		_show_room()
	_refresh_room_panel()


func _on_lobby_error(message: String) -> void:
	push_warning("Room: %s" % message)
	_reset_ready_button()
	_show_hub()


func _on_lobby_message(_message: String) -> void:
	pass


func _refresh_room_panel() -> void:
	var net: Node = get_node_or_null("/root/RoomNetwork")
	if net == null or not net.is_in_room():
		return
	var code: String = str(net.room_code)
	if code.length() == 4:
		var spaced: PackedStringArray = []
		for i in 4:
			spaced.append(code[i])
		_room_code_label.text = " ".join(spaced)
	else:
		_room_code_label.text = code
	_room_port_hint.text = "联机端口：%d（局域网加入需填写主机 IP）" % int(net.listen_port)
	for c in _player_list.get_children():
		c.queue_free()
	var local_id: int = net.get_local_peer_id()
	var rows: Array = net.get_player_rows()
	var seat_taken: Dictionary = {}
	for row in rows:
		var seat: int = int(row.get("seat", 0))
		seat_taken[seat] = true
		_player_list.add_child(_make_player_row(row, int(row.get("peer_id", -1)) == local_id))
	for seat in range(RoomNetworkScript.MAX_PLAYERS):
		if seat_taken.has(seat):
			continue
		_player_list.add_child(_make_empty_slot_row(seat))
	var ready_n: int = net.get_ready_count()
	var total_n: int = net.get_connected_count()
	var target_n: int = net.get_target_player_count()
	var in_lobby: bool = net.is_local_in_lobby()
	_ready_btn.disabled = not in_lobby
	if not in_lobby:
		_status_btn.text = "⏳ 正在同步房间…"
	elif total_n < target_n:
		_status_btn.text = "⏳ 等待加入 (%d/%d)" % [total_n, target_n]
	elif ready_n < total_n:
		_status_btn.text = "⏳ 等待准备 (%d/%d)" % [ready_n, total_n]
	else:
		_status_btn.text = "✓ 全员就绪，即将开局…"
	var local_ready: bool = false
	if in_lobby:
		for row in rows:
			if int(row.get("peer_id", -1)) == local_id:
				local_ready = bool(row.get("ready", false))
				break
	_ready_btn.set_block_signals(true)
	_ready_btn.button_pressed = local_ready
	_ready_btn.set_block_signals(false)
	_ready_btn.text = "✋ 已准备" if local_ready else "✋ 准备好了"


func _join_wait_for_sync(net: Node) -> void:
	var ok: bool = await net.wait_for_lobby_sync(12.0)
	if not ok:
		_on_lobby_error("加入房间超时，请确认房主在线后重试")
		if net.is_in_room():
			net.leave_room()
		return
	_refresh_room_panel()


func _reset_ready_button() -> void:
	_ready_btn.set_block_signals(true)
	_ready_btn.button_pressed = false
	_ready_btn.set_block_signals(false)
	_ready_btn.disabled = false


func _make_empty_slot_row(seat: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08)
	sb.border_color = Color(0.2, 0.24, 0.3)
	sb.border_width_left = 1
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "%d号位 · 等待加入…" % [seat + 1]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.58))
	panel.add_child(lbl)
	return panel


func _make_player_row(row: Dictionary, is_local: bool) -> PanelContainer:
	var seat: int = int(row.get("seat", 0))
	var name: String = str(row.get("display_name", "玩家"))
	var ready: bool = bool(row.get("ready", false))
	var is_host: bool = bool(row.get("is_host", false))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11)
	sb.border_color = Color(0.35, 0.85, 0.45) if is_local else Color(0.22, 0.28, 0.36)
	sb.border_width_left = 2
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_right = 12
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	var tags: PackedStringArray = []
	if is_host:
		tags.append("房主")
	if is_local:
		tags.append("你")
	if ready:
		tags.append("已准备")
	else:
		tags.append("未准备")
	lbl.text = "%d号位 · %s  (%s)" % [seat + 1, name, " · ".join(tags)]
	lbl.add_theme_font_size_override("font_size", 13)
	panel.add_child(lbl)
	return panel
