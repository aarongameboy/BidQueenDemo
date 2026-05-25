class_name MatchCinematicOverlay
extends CanvasLayer

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const MatchIntelScript = preload("res://scripts/match/match_intel.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")

const BG_COLOR := Color(0.03, 0.03, 0.04, 1.0)
const CREAM := Color(0.95, 0.9, 0.78, 1.0)
const GOLD := Color(1.0, 0.82, 0.22, 1.0)
const MUTED := Color(0.62, 0.64, 0.7, 0.92)
const MULT_PINK := Color(1.0, 0.38, 0.48, 1.0)
const INTEL_BORDER := Color(0.62, 0.38, 0.92, 0.95)
const INTEL_BG := Color(0.08, 0.05, 0.12, 0.88)
const SKILL_BORDER := Color(1.0, 0.82, 0.22, 0.95)
const SKILL_BG := Color(0.1, 0.09, 0.06, 0.88)
const ROW_BG := Color(0.1, 0.11, 0.14, 0.92)
const ROW_GOLD_BORDER := Color(1.0, 0.82, 0.22, 0.95)
const ROW_KILL_BORDER := Color(1.0, 0.38, 0.48, 0.95)
const SUCCESS_GREEN := Color(0.45, 0.95, 0.62, 1.0)
const FAIL_RED := Color(1.0, 0.38, 0.38, 1.0)

var _backdrop: ColorRect
var _scanlines: Control
var _fade_root: Control
var _stage: Control


func _init() -> void:
	layer = 50
	visible = false
	_build_shell()


func play(payload: Dictionary, options: Dictionary = {}) -> void:
	var opts: Dictionary = options if not options.is_empty() else payload.get("options", {})
	var fade_in: bool = bool(opts.get("fade_in", true))
	var fade_out: bool = bool(opts.get("fade_out", true))
	var hold_sec: float = _hold_for_type(str(payload.get("type", "")))
	_rebuild_stage(payload)
	visible = true
	if fade_in:
		_fade_root.modulate.a = 0.0
		var fade_in_tw := create_tween()
		fade_in_tw.tween_property(_fade_root, "modulate:a", 1.0, 0.35)
		await fade_in_tw.finished
	else:
		_fade_root.modulate.a = 1.0
	await get_tree().create_timer(hold_sec).timeout
	if fade_out:
		var fade_out_tw := create_tween()
		fade_out_tw.tween_property(_fade_root, "modulate:a", 0.0, 0.32)
		await fade_out_tw.finished
	visible = false
	_fade_root.modulate.a = 1.0


func play_sequence(payloads: Array) -> void:
	if payloads.is_empty():
		return
	visible = true
	_fade_root.modulate.a = 0.0
	var fade_in_tw := create_tween()
	fade_in_tw.tween_property(_fade_root, "modulate:a", 1.0, 0.35)
	await fade_in_tw.finished
	for i in payloads.size():
		var payload: Dictionary = payloads[i]
		_rebuild_stage(payload)
		await get_tree().create_timer(_hold_for_type(str(payload.get("type", "")))).timeout
	var fade_out_tw := create_tween()
	fade_out_tw.tween_property(_fade_root, "modulate:a", 0.0, 0.32)
	await fade_out_tw.finished
	visible = false
	_fade_root.modulate.a = 1.0


func dismiss_instant() -> void:
	visible = false
	_fade_root.modulate.a = 1.0


func _hold_for_type(type_name: String) -> float:
	match type_name:
		"auction_start":
			return GameConstants.CINEMATIC_AUCTION_START_HOLD
		"heritage":
			return GameConstants.CINEMATIC_HERITAGE_HOLD
		"round_start":
			return GameConstants.CINEMATIC_ROUND_START_HOLD
		"round_reveal":
			return GameConstants.CINEMATIC_ROUND_REVEAL_HOLD
		"auction_success":
			return GameConstants.CINEMATIC_AUCTION_SUCCESS_HOLD
		"auction_fail":
			return GameConstants.CINEMATIC_AUCTION_FAIL_HOLD
		_:
			return 2.0


func _build_shell() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = BG_COLOR
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_scanlines = _ScanlineOverlay.new()
	_scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scanlines)
	_fade_root = Control.new()
	_fade_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_root)
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_root.add_child(_stage)


func _rebuild_stage(payload: Dictionary) -> void:
	for child in _stage.get_children():
		child.queue_free()
	match str(payload.get("type", "")):
		"auction_start":
			_build_auction_start()
		"heritage":
			_build_heritage(payload)
		"round_start":
			_build_round_start(payload)
		"round_reveal":
			_build_round_reveal(payload)
		"auction_success":
			_build_auction_success(payload)
		"auction_fail":
			_build_auction_fail(payload)
		_:
			pass


func _build_auction_start() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)
	var ring_host := Control.new()
	ring_host.custom_minimum_size = Vector2(320, 320)
	center.add_child(ring_host)
	var ring := _CircleRing.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring_host.add_child(ring)
	var title := Label.new()
	title.text = "竞拍开始"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	FontUtilScript.style_title_label(title, 42)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.75, 0.2, 0.35))
	title.add_theme_constant_override("outline_size", 6)
	ring_host.add_child(title)


func _build_heritage(payload: Dictionary) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(520, 0)
	center.add_child(col)
	var ring_host := Control.new()
	ring_host.custom_minimum_size = Vector2(300, 300)
	ring_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ring_host)
	var ring := _CircleRing.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring_host.add_child(ring)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 36
	inner.offset_right = -36
	inner.offset_top = 48
	inner.offset_bottom = -48
	inner.add_theme_constant_override("separation", 10)
	ring_host.add_child(inner)
	var intro := Label.new()
	intro.text = "本局遗产来自"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(intro, 16)
	intro.add_theme_color_override("font_color", MUTED)
	inner.add_child(intro)
	var divider := _GoldDivider.new()
	divider.custom_minimum_size = Vector2(180, 8)
	inner.add_child(divider)
	var name_lbl := Label.new()
	name_lbl.text = str(payload.get("location_name", ""))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontUtilScript.style_title_label(name_lbl, 34)
	name_lbl.add_theme_color_override("font_color", GOLD)
	name_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.7, 0.1, 0.4))
	name_lbl.add_theme_constant_override("outline_size", 8)
	inner.add_child(name_lbl)
	var desc := str(payload.get("description", ""))
	if not desc.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		FontUtilScript.style_body_label(desc_lbl, 14)
		desc_lbl.add_theme_color_override("font_color", MUTED)
		col.add_child(desc_lbl)


func _build_round_start(payload: Dictionary) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 36)
	root.custom_minimum_size = Vector2(560, 0)
	center.add_child(root)
	var round_row := HBoxContainer.new()
	round_row.alignment = BoxContainer.ALIGNMENT_CENTER
	round_row.add_theme_constant_override("separation", 28)
	root.add_child(round_row)
	round_row.add_child(_make_round_column(payload))
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 72)
	sep.color = Color(0.45, 0.47, 0.52, 0.55)
	round_row.add_child(sep)
	round_row.add_child(_make_mult_column(payload))
	root.add_child(_make_intel_panel(payload))
	var skill: Dictionary = payload.get("skill_effect", {})
	if not skill.is_empty():
		root.add_child(_make_skill_effect_panel(skill))


func _make_round_column(payload: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(120, 0)
	var cap := Label.new()
	cap.text = "ROUND"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(cap, 13)
	cap.add_theme_color_override("font_color", MUTED)
	col.add_child(cap)
	var num := Label.new()
	num.text = str(payload.get("round_index", 1))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_title_label(num, 52)
	num.add_theme_color_override("font_color", CREAM)
	col.add_child(num)
	var total := Label.new()
	total.text = " / %d" % int(payload.get("max_rounds", GameConstants.MAX_ROUNDS))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(total, 16)
	total.add_theme_color_override("font_color", MUTED)
	col.add_child(total)
	return col


func _make_mult_column(payload: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size = Vector2(140, 0)
	var mult: float = float(payload.get("instant_kill_mult", 2.0))
	var mult_lbl := Label.new()
	mult_lbl.text = _format_mult(mult)
	mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_title_label(mult_lbl, 48)
	mult_lbl.add_theme_color_override("font_color", MULT_PINK)
	col.add_child(mult_lbl)
	var cap := Label.new()
	cap.text = "秒杀倍率"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(cap, 14)
	cap.add_theme_color_override("font_color", MUTED)
	col.add_child(cap)
	return col


func _make_intel_panel(payload: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = INTEL_BG
	sb.border_color = INTEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var header := Label.new()
	header.text = "// 公开情报广播"
	FontUtilScript.style_body_label(header, 13)
	header.add_theme_color_override("font_color", Color(0.72, 0.55, 0.95, 1.0))
	vbox.add_child(header)
	var intel: Dictionary = payload.get("intel", {})
	var headline := MatchIntelScript.format_cinematic_headline(intel)
	var bbcode_text: String = str(intel.get("body_bbcode", ""))
	if not bbcode_text.is_empty():
		var main := RichTextLabel.new()
		main.bbcode_enabled = true
		main.fit_content = true
		main.scroll_active = false
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.custom_minimum_size = Vector2(480, 0)
		main.add_theme_font_override("normal_font", FontUtilScript.get_title_font())
		main.add_theme_font_size_override("normal_font_size", 28)
		main.add_theme_color_override("default_color", CREAM)
		main.text = bbcode_text
		vbox.add_child(main)
	else:
		var main := Label.new()
		main.text = headline
		main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main.custom_minimum_size = Vector2(480, 0)
		FontUtilScript.style_title_label(main, 28)
		main.add_theme_color_override("font_color", CREAM)
		vbox.add_child(main)
	var detail_text := MatchIntelScript.format_cinematic_detail(intel)
	if not detail_text.is_empty() and detail_text != headline:
		var detail := Label.new()
		detail.text = detail_text
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.custom_minimum_size = Vector2(480, 0)
		FontUtilScript.style_body_label(detail, 15)
		detail.add_theme_color_override("font_color", MUTED)
		vbox.add_child(detail)
	return panel


func _make_skill_effect_panel(skill: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SKILL_BG
	sb.border_color = SKILL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var header := Label.new()
	header.text = "// 角色技能发动"
	FontUtilScript.style_body_label(header, 13)
	header.add_theme_color_override("font_color", GOLD)
	vbox.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vbox.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var cid: String = str(skill.get("character_id", ""))
	if not cid.is_empty():
		var portrait: String = RosterConfigScript.get_portrait_path(cid)
		if ResourceLoader.exists(portrait):
			icon.texture = load(portrait)
	if icon.texture == null:
		var ph := ColorRect.new()
		ph.color = Color(0.55, 0.4, 0.25)
		ph.custom_minimum_size = Vector2(56, 56)
		row.add_child(ph)
	else:
		row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 6)
	row.add_child(texts)
	var title_lbl := Label.new()
	title_lbl.text = str(skill.get("title", ""))
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontUtilScript.style_title_label(title_lbl, 20)
	title_lbl.add_theme_color_override("font_color", CREAM)
	texts.add_child(title_lbl)
	var body_lbl := Label.new()
	body_lbl.text = str(skill.get("body", ""))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	FontUtilScript.style_body_label(body_lbl, 15)
	body_lbl.add_theme_color_override("font_color", MUTED)
	texts.add_child(body_lbl)
	return panel


static func _format_mult(mult: float) -> String:
	if absf(mult - roundf(mult)) < 0.05:
		return "%dx" % int(roundf(mult))
	return "%.1fx" % mult


func _build_round_reveal(payload: Dictionary) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size = Vector2(560, 0)
	center.add_child(col)
	var header := Label.new()
	header.text = "// 同时开价 - 揭示"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(header, 14)
	header.add_theme_color_override("font_color", MUTED)
	col.add_child(header)
	var rows: Array = payload.get("rows", [])
	var instant_kill: bool = bool(payload.get("instant_kill", false))
	var ik_seat: int = int(payload.get("instant_kill_winner_seat", -1))
	for rank_i in rows.size():
		var row: Dictionary = rows[rank_i]
		var seat: int = int(row.get("seat", -1))
		var show_kill: bool = instant_kill and seat == ik_seat and rank_i == 0
		var is_human: bool = bool(row.get("is_human", false))
		col.add_child(_make_reveal_row(rank_i + 1, row, show_kill, is_human))
	col.add_child(_make_reveal_footer(payload))


func _make_reveal_row(rank: int, row: Dictionary, show_kill_tag: bool, is_human: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 56)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_BG
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	if show_kill_tag:
		sb.border_color = ROW_KILL_BORDER
		sb.set_border_width_all(2)
	elif is_human:
		sb.border_color = ROW_GOLD_BORDER
		sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.custom_minimum_size = Vector2(36, 0)
	FontUtilScript.style_body_label(rank_lbl, 14)
	rank_lbl.add_theme_color_override("font_color", MUTED)
	hbox.add_child(rank_lbl)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var char_id: String = str(row.get("character_id", ""))
	var portrait: String = RosterConfigScript.get_portrait_path(char_id)
	if ResourceLoader.exists(portrait):
		avatar.texture = load(portrait)
	hbox.add_child(avatar)
	var name_lbl := Label.new()
	name_lbl.text = str(row.get("display_name", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FontUtilScript.style_body_label(name_lbl, 17)
	var name_color: Color = GOLD if is_human else CREAM
	name_lbl.add_theme_color_override("font_color", name_color)
	hbox.add_child(name_lbl)
	var amount: int = int(row.get("amount", 0))
	var passed: bool = bool(row.get("passed", false)) or amount <= 0
	var amt_lbl := Label.new()
	if passed:
		amt_lbl.text = "不出价"
	else:
		amt_lbl.text = _format_yuan(amount)
	FontUtilScript.style_title_label(amt_lbl, 22)
	var amt_color: Color = GOLD if is_human else CREAM
	if show_kill_tag:
		amt_color = MULT_PINK
	amt_lbl.add_theme_color_override("font_color", amt_color)
	hbox.add_child(amt_lbl)
	if show_kill_tag:
		var tag := _make_kill_tag()
		hbox.add_child(tag)
	return panel


func _make_kill_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.08, 0.14, 0.95)
	sb.border_color = MULT_PINK
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	tag.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = "秒杀"
	FontUtilScript.style_body_label(lbl, 13)
	lbl.add_theme_color_override("font_color", MULT_PINK)
	tag.add_child(lbl)
	return tag


func _make_reveal_footer(payload: Dictionary) -> Label:
	var footer := Label.new()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_title_label(footer, 26)
	if bool(payload.get("instant_kill", false)):
		var ik_name: String = str(payload.get("instant_kill_winner_name", ""))
		footer.text = "%s 达到秒杀价" % ik_name
		footer.add_theme_color_override("font_color", MULT_PINK)
	else:
		var rank: int = int(payload.get("human_rank", 0))
		if rank > 0:
			footer.text = "本回合第%d名" % rank
		else:
			footer.text = "本回合未出价"
		footer.add_theme_color_override("font_color", CREAM)
	return footer


func _build_auction_success(payload: Dictionary) -> void:
	_build_auction_outcome(payload, true)


func _build_auction_fail(payload: Dictionary) -> void:
	_build_auction_outcome(payload, false)


func _build_auction_outcome(payload: Dictionary, is_success: bool) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(480, 0)
	center.add_child(col)
	var status := Label.new()
	status.text = "竞拍成功" if is_success else "竞拍失败"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(status, 16)
	status.add_theme_color_override(
		"font_color",
		SUCCESS_GREEN if is_success else FAIL_RED,
	)
	col.add_child(status)
	col.add_child(_make_winner_row(payload, is_success))
	col.add_child(_make_hammer_block(int(payload.get("hammer_price", 0))))
	if is_success:
		var margin: int = int(payload.get("margin_over_second", 0))
		if margin > 0:
			var lead := Label.new()
			lead.text = "领先第二名 +%s" % _format_yuan(margin)
			lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			FontUtilScript.style_body_label(lead, 15)
			lead.add_theme_color_override("font_color", SUCCESS_GREEN)
			col.add_child(lead)
		var hint := Label.new()
		hint.text = "买定离手 - 开始清点物品"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		FontUtilScript.style_body_label(hint, 14)
		hint.add_theme_color_override("font_color", MUTED)
		col.add_child(hint)
	else:
		var hint := Label.new()
		hint.text = "遗产易主 — 正在还原物品"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		FontUtilScript.style_body_label(hint, 14)
		hint.add_theme_color_override("font_color", MUTED)
		col.add_child(hint)


func _make_winner_row(payload: Dictionary, is_success: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(72, 72)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var char_id: String = str(payload.get("winner_character_id", ""))
	var portrait: String = RosterConfigScript.get_portrait_path(char_id)
	if ResourceLoader.exists(portrait):
		avatar.texture = load(portrait)
	row.add_child(avatar)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	var name_lbl := Label.new()
	name_lbl.text = str(payload.get("winner_name", ""))
	FontUtilScript.style_title_label(name_lbl, 24)
	name_lbl.add_theme_color_override("font_color", CREAM)
	info.add_child(name_lbl)
	var role_lbl := Label.new()
	role_lbl.text = str(payload.get("winner_title", "买家"))
	FontUtilScript.style_body_label(role_lbl, 14)
	role_lbl.add_theme_color_override("font_color", MUTED)
	info.add_child(role_lbl)
	if not is_success:
		var deal := Label.new()
		deal.text = "以 %s 成交" % _format_yuan(int(payload.get("hammer_price", 0)))
		FontUtilScript.style_body_label(deal, 14)
		deal.add_theme_color_override("font_color", MUTED)
		info.add_child(deal)
	row.add_child(info)
	return row


func _make_hammer_block(price: int) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	var cap := Label.new()
	cap.text = "HAMMER PRICE"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_body_label(cap, 11)
	cap.add_theme_color_override("font_color", MUTED)
	block.add_child(cap)
	var price_lbl := Label.new()
	price_lbl.text = _format_yuan(price)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontUtilScript.style_title_label(price_lbl, 44)
	price_lbl.add_theme_color_override("font_color", GOLD)
	price_lbl.add_theme_color_override("font_outline_color", Color(1.0, 0.7, 0.1, 0.35))
	price_lbl.add_theme_constant_override("outline_size", 6)
	block.add_child(price_lbl)
	return block


static func _format_yuan(amount: int) -> String:
	return "¥" + _format_comma(amount)


static func _format_comma(amount: int) -> String:
	var s: String = str(amount)
	var out: String = ""
	var n: int = s.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			out += ","
		out += s[i]
	return out


class _ScanlineOverlay extends Control:
	func _draw() -> void:
		var h: float = size.y
		var y: float = 0.0
		while y < h:
			draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(1, 1, 1, 0.035), 1.0)
			y += 4.0


class _CircleRing extends Control:
	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5 - 4.0
		var c: Vector2 = size * 0.5
		draw_arc(c, r, 0.0, TAU, 96, Color(0.92, 0.9, 0.86, 0.75), 2.0, true)


class _GoldDivider extends Control:
	func _draw() -> void:
		var mid_y: float = size.y * 0.5
		var w: float = size.x
		draw_line(Vector2(0.0, mid_y), Vector2(w * 0.35, mid_y), Color(0.5, 0.5, 0.55, 0.35), 1.0)
		draw_line(Vector2(w * 0.35, mid_y), Vector2(w * 0.65, mid_y), Color(1.0, 0.75, 0.2, 0.85), 2.0)
		draw_line(Vector2(w * 0.65, mid_y), Vector2(w, mid_y), Color(0.5, 0.5, 0.55, 0.35), 1.0)
