class_name PlayerSeatCard
extends PanelContainer
## 左侧玩家席位卡片：头像、名称、五轮出价格

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")

var _avatar: TextureRect
var _name_label: Label
var _title_label: Label
var _self_badge: Label
var _bid_slots: Array[Label] = []
var _seat_index: int = -1
var _is_self: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(280, 130)
	_apply_panel_style()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Row 1: avatar (left) + name/title column (right) — header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	_avatar = TextureRect.new()
	_avatar.custom_minimum_size = Vector2(56, 56)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var av_path: String = "res://assets/ui/avatars/avatar_0.png"
	if ResourceLoader.exists(av_path):
		_avatar.texture = load(av_path)
	header.add_child(_avatar)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.add_theme_constant_override("separation", 2)
	header.add_child(name_col)

	_name_label = Label.new()
	FontUtilScript.style_body_label(_name_label, 15)
	name_col.add_child(_name_label)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_title_label.add_theme_font_size_override("font_size", 12)
	name_col.add_child(_title_label)

	_self_badge = Label.new()
	_self_badge.text = "主角"
	_self_badge.visible = false
	_self_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_self_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_self_badge.custom_minimum_size = Vector2(38, 20)
	_self_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_self_badge.add_theme_font_size_override("font_size", 10)
	_self_badge.add_theme_color_override("font_color", Color(0.12, 0.1, 0.06))
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.95, 0.78, 0.22, 0.98)
	badge_sb.set_corner_radius_all(4)
	badge_sb.content_margin_left = 5
	badge_sb.content_margin_right = 5
	badge_sb.content_margin_top = 1
	badge_sb.content_margin_bottom = 1
	_self_badge.add_theme_stylebox_override("normal", badge_sb)
	header.add_child(_self_badge)

	# Row 2: 5 round bid slots spanning full width
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 4)
	root.add_child(slots_row)
	for i in GameConstants.MAX_ROUNDS:
		var slot := _make_bid_slot(i + 1)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots_row.add_child(slot)
		_bid_slots.append(slot)

	FontUtilScript.apply_cjk_font(self, 13)


func get_avatar_control() -> TextureRect:
	return _avatar


func set_avatar_seat(seat_visual: int) -> void:
	var path: String = "res://assets/ui/avatars/avatar_%d.png" % (seat_visual % 4)
	if ResourceLoader.exists(path):
		_avatar.texture = load(path)


func set_avatar_character(character_id: String) -> void:
	var path: String = RosterConfigScript.get_portrait_path(character_id)
	if ResourceLoader.exists(path):
		_avatar.texture = load(path)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 0.94)
	style.border_color = Color(0.32, 0.38, 0.5, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)


func _make_bid_slot(round_num: int) -> Label:
	var slot := Label.new()
	slot.custom_minimum_size = Vector2(36, 28)
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.text = str(round_num)
	slot.add_theme_font_size_override("font_size", 11)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb.border_color = Color(0.35, 0.4, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("normal", sb)
	return slot


func bind_player(player, seat_visual: int, is_leader: bool, is_self: bool = false) -> void:
	_seat_index = player.seat_index
	_is_self = is_self
	if RosterConfigScript.has_character(player.character_id):
		set_avatar_character(player.character_id)
	else:
		set_avatar_seat(seat_visual)
	_name_label.text = player.display_name
	_title_label.text = player.character_title
	if _self_badge:
		_self_badge.visible = is_self
	_apply_panel_border(is_self, is_leader)


func _style_slot(slot: Label, has_bid: bool, is_current_round: bool) -> void:
	var sb := StyleBoxFlat.new()
	if is_current_round:
		sb.border_color = Color(0.2, 0.85, 1.0)
		sb.set_border_width_all(2)
		sb.bg_color = Color(0.1, 0.25, 0.35, 0.95)
	elif has_bid:
		sb.border_color = Color(0.45, 0.75, 0.55)
		sb.bg_color = Color(0.12, 0.22, 0.16, 0.95)
	else:
		sb.border_color = Color(0.35, 0.4, 0.5)
		sb.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("normal", sb)


func _style_slot_forfeited(slot: Label, is_current: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.1, 0.1, 0.95)
	sb.border_color = Color(0.6, 0.3, 0.3)
	if is_current:
		sb.set_border_width_all(2)
	else:
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("normal", sb)


func _apply_panel_border(is_self: bool, is_leader: bool) -> void:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if is_self:
		style.border_color = Color(0.95, 0.78, 0.22, 0.98)
		style.set_border_width_all(3)
	elif is_leader:
		style.border_color = Color(0.25, 0.75, 1.0)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.25, 0.32, 0.45, 0.9)
		style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)


func update_from_player(
	player,
	leader_seat: int,
	current_round: int,
	hide_current_round_bid: bool = false,
	is_self: bool = false,
	show_leader: bool = true,
) -> void:
	var is_leader: bool = show_leader and leader_seat >= 0 and player.seat_index == leader_seat
	if player.forfeited_match:
		is_leader = false
	bind_player(player, player.seat_index, is_leader, is_self)
	for i in _bid_slots.size():
		var amount: int = player.round_bids[i] if i < player.round_bids.size() else 0
		var is_current: bool = i + 1 == current_round
		var round_num: int = i + 1
		if player.forfeited_match and round_num >= current_round and amount <= 0:
			_bid_slots[i].text = "弃权"
			_style_slot_forfeited(_bid_slots[i], is_current)
			continue
		var hide_this: bool = (
			is_current
			and hide_current_round_bid
			and not player.is_human
		)
		if hide_this:
			_bid_slots[i].text = "…"
			_style_slot(_bid_slots[i], false, is_current)
		elif amount > 0:
			_bid_slots[i].text = MatchControllerScript._format_silver(amount)
			_style_slot(_bid_slots[i], true, is_current)
		elif is_current and hide_current_round_bid:
			_bid_slots[i].text = "…"
			_style_slot(_bid_slots[i], false, is_current)
		else:
			_bid_slots[i].text = str(i + 1)
			_style_slot(_bid_slots[i], false, is_current)
