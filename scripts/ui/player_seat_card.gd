class_name PlayerSeatCard
extends PanelContainer
## 左侧玩家席位卡片：角色信息、五轮战术道具与出价记录。

signal tactical_item_pressed(item_id: String, anchor_global: Vector2)

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")

const ROUND_SLOT_SIZE := Vector2(46, 88)

var _avatar: TextureRect
var _name_label: Label
var _title_label: Label
var _self_badge: Label
var _round_buttons: Array[Button] = []
var _item_icons: Array[TextureRect] = []
var _bid_labels: Array[Label] = []
var _catalog: TacticalItemCatalog
var _seat_index: int = -1
var _is_self: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(410, 110)
	_catalog = TacticalCatalogScript.new()
	_catalog.load_all()
	_apply_panel_style()
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(_build_character_block())
	var slots_row := HBoxContainer.new()
	slots_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_row.add_theme_constant_override("separation", 4)
	root.add_child(slots_row)
	for i in GameConstants.MAX_ROUNDS:
		slots_row.add_child(_make_round_slot(i + 1))
	FontUtilScript.apply_cjk_font(self, 12)


func _build_character_block() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(132, 0)
	header.add_theme_constant_override("separation", 7)
	_avatar = TextureRect.new()
	_avatar.custom_minimum_size = Vector2(64, 64)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	header.add_child(_avatar)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 3)
	header.add_child(text_col)
	_name_label = Label.new()
	_name_label.custom_minimum_size = Vector2(68, 0)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontUtilScript.style_body_label(_name_label, 13)
	text_col.add_child(_name_label)
	_title_label = Label.new()
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_title_label.add_theme_font_size_override("font_size", 11)
	text_col.add_child(_title_label)
	_self_badge = Label.new()
	_self_badge.text = "主角"
	_self_badge.visible = false
	_self_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_self_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_self_badge.custom_minimum_size = Vector2(36, 18)
	_self_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_self_badge.add_theme_font_size_override("font_size", 9)
	_self_badge.add_theme_color_override("font_color", Color(0.12, 0.1, 0.06))
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.95, 0.78, 0.22, 0.98)
	badge_sb.set_corner_radius_all(4)
	badge_sb.content_margin_left = 4
	badge_sb.content_margin_right = 4
	_self_badge.add_theme_stylebox_override("normal", badge_sb)
	text_col.add_child(_self_badge)
	return header


func _make_round_slot(round_num: int) -> Button:
	var slot := Button.new()
	slot.custom_minimum_size = ROUND_SLOT_SIZE
	slot.focus_mode = Control.FOCUS_NONE
	slot.set_meta("round_index", round_num)
	slot.pressed.connect(_on_round_slot_pressed.bind(slot))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(col)
	var round_label := Label.new()
	round_label.text = str(round_num)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 10)
	round_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8))
	round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(round_label)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(icon)
	var bid := Label.new()
	bid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bid.add_theme_font_size_override("font_size", 9)
	bid.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
	bid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bid)
	_round_buttons.append(slot)
	_item_icons.append(icon)
	_bid_labels.append(bid)
	return slot


func get_avatar_control() -> TextureRect:
	return _avatar


func set_avatar_seat(seat_visual: int) -> void:
	var path: String = "res://assets/ui/avatars/avatar_%d.png" % (seat_visual % 4)
	if ResourceLoader.exists(path):
		_avatar.texture = load(path)


func set_avatar_character(character_id: String) -> void:
	_avatar.texture = RosterConfigScript.get_avatar_texture(character_id)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 0.94)
	style.border_color = Color(0.32, 0.38, 0.5, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", style)


func bind_player(player, seat_visual: int, is_leader: bool, is_self: bool = false) -> void:
	_seat_index = player.seat_index
	_is_self = is_self
	if RosterConfigScript.has_character(player.character_id):
		set_avatar_character(player.character_id)
		_name_label.text = RosterConfigScript.get_display_name(player.character_id)
	else:
		set_avatar_seat(seat_visual)
		_name_label.text = player.character_title
	_title_label.text = player.character_title
	_self_badge.visible = is_self
	_apply_panel_border(is_self, is_leader)


func _style_slot(slot: Button, has_bid: bool, is_current_round: bool, has_item: bool) -> void:
	var sb := StyleBoxFlat.new()
	if is_current_round:
		sb.border_color = Color(0.2, 0.85, 1.0)
		sb.set_border_width_all(2)
		sb.bg_color = Color(0.1, 0.25, 0.35, 0.95)
	elif has_item:
		sb.border_color = Color(0.64, 0.5, 0.88)
		sb.set_border_width_all(1)
		sb.bg_color = Color(0.13, 0.11, 0.2, 0.95)
	elif has_bid:
		sb.border_color = Color(0.45, 0.75, 0.55)
		sb.set_border_width_all(1)
		sb.bg_color = Color(0.12, 0.22, 0.16, 0.95)
	else:
		sb.border_color = Color(0.35, 0.4, 0.5)
		sb.set_border_width_all(1)
		sb.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("normal", sb)
	slot.add_theme_stylebox_override("hover", sb.duplicate())
	slot.add_theme_stylebox_override("pressed", sb.duplicate())


func _style_slot_forfeited(slot: Button, is_current: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.1, 0.1, 0.95)
	sb.border_color = Color(0.6, 0.3, 0.3)
	sb.set_border_width_all(2 if is_current else 1)
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
	for i in _round_buttons.size():
		var amount: int = player.round_bids[i] if i < player.round_bids.size() else 0
		var item_id: String = player.round_tactical_items[i] if i < player.round_tactical_items.size() else ""
		var is_current: bool = i + 1 == current_round
		_apply_round_item(i, item_id)
		if player.forfeited_match and i + 1 >= current_round and amount <= 0:
			_bid_labels[i].text = "弃权"
			_style_slot_forfeited(_round_buttons[i], is_current)
			continue
		var hide_this: bool = is_current and hide_current_round_bid and not player.is_human
		if hide_this or (is_current and hide_current_round_bid and amount <= 0):
			_bid_labels[i].text = "..."
		elif amount > 0:
			_bid_labels[i].text = MatchControllerScript._format_silver(amount)
		else:
			_bid_labels[i].text = "-"
		_style_slot(_round_buttons[i], amount > 0, is_current, not item_id.is_empty())


func _apply_round_item(index: int, item_id: String) -> void:
	var slot: Button = _round_buttons[index]
	var icon: TextureRect = _item_icons[index]
	icon.texture = null
	slot.set_meta("item_id", item_id)
	slot.tooltip_text = ""
	if item_id.is_empty():
		return
	var item: Dictionary = _catalog.get_item(item_id)
	var icon_path: String = str(item.get("icon_path", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path) as Texture2D
	slot.tooltip_text = str(item.get("name", item_id))


func _on_round_slot_pressed(slot: Button) -> void:
	var item_id: String = str(slot.get_meta("item_id", ""))
	if item_id.is_empty():
		return
	tactical_item_pressed.emit(item_id, slot.global_position + Vector2(slot.size.x, 0))
