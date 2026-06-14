class_name SettlementOverlay
extends Control

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")

signal claim_pressed

var _panel: PanelContainer
var _title_label: Label
var _winner_row: HBoxContainer
var _winner_avatar: TextureRect
var _winner_name_label: Label
var _winner_title_label: Label
var _bid_caption: Label
var _bid_value_label: Label
var _loot_caption: Label
var _loot_value_label: Label
var _profit_caption: Label
var _profit_value_label: Label
var _welfare_label: Label
var _claim_btn: Button
var _continue_hint: Label


func _init() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 40
    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(380, 0)
    _panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
    _panel.offset_left = 32
    _panel.offset_top = -260
    _panel.offset_right = 412
    _panel.offset_bottom = 260
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.08, 0.12, 0.72)
    sb.border_color = Color(0.35, 0.55, 0.75, 0.75)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(10)
    sb.content_margin_left = 24
    sb.content_margin_right = 24
    sb.content_margin_top = 20
    sb.content_margin_bottom = 20
    _panel.add_theme_stylebox_override("panel", sb)
    add_child(_panel)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    _panel.add_child(vbox)
    _title_label = Label.new()
    _title_label.text = "对局结束"
    FontUtilScript.style_title_label(_title_label, 30)
    vbox.add_child(_title_label)
    _winner_row = HBoxContainer.new()
    _winner_row.add_theme_constant_override("separation", 14)
    vbox.add_child(_winner_row)
    _winner_avatar = TextureRect.new()
    _winner_avatar.custom_minimum_size = Vector2(88, 88)
    _winner_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _winner_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _winner_row.add_child(_winner_avatar)
    var winner_info := VBoxContainer.new()
    winner_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    winner_info.add_theme_constant_override("separation", 4)
    _winner_row.add_child(winner_info)
    _winner_name_label = Label.new()
    FontUtilScript.style_title_label(_winner_name_label, 26)
    winner_info.add_child(_winner_name_label)
    _winner_title_label = Label.new()
    _winner_title_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
    _winner_title_label.add_theme_font_size_override("font_size", 14)
    winner_info.add_child(_winner_title_label)
    _bid_caption = _make_caption("最终竞拍价格")
    vbox.add_child(_bid_caption)
    _bid_value_label = _make_value_label()
    vbox.add_child(_bid_value_label)
    _loot_caption = _make_caption("战利品价格")
    vbox.add_child(_loot_caption)
    _loot_value_label = _make_value_label()
    vbox.add_child(_loot_value_label)
    _profit_caption = _make_caption("利润")
    vbox.add_child(_profit_caption)
    _profit_value_label = _make_value_label(32)
    vbox.add_child(_profit_value_label)
    _welfare_label = Label.new()
    _welfare_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.55))
    _welfare_label.add_theme_font_size_override("font_size", 14)
    _welfare_label.visible = false
    vbox.add_child(_welfare_label)
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 8)
    vbox.add_child(spacer)
    var claim_row := CenterContainer.new()
    vbox.add_child(claim_row)
    _claim_btn = Button.new()
    _claim_btn.text = "领取"
    _claim_btn.visible = false
    _claim_btn.disabled = false
    _claim_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _claim_btn.focus_mode = Control.FOCUS_ALL
    _claim_btn.pressed.connect(func() -> void: claim_pressed.emit())
    claim_row.add_child(_claim_btn)
    _continue_hint = Label.new()
    _continue_hint.text = "点击领取后继续"
    _continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _continue_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
    _continue_hint.add_theme_font_size_override("font_size", 13)
    _continue_hint.visible = false
    vbox.add_child(_continue_hint)
    _style_claim_button()
    FontUtilScript.apply_cjk_font(self, 14)
    hide()


func bind_main_columns(_columns: Control) -> void:
    pass


func show_overlay() -> void:
    show()


func begin_settlement(
    winning_bid: int,
    winner_name: String = "",
    winner_seat: int = -1,
    winner_title: String = "",
    winner_character_id: String = "",
) -> void:
    show_overlay()
    _claim_btn.visible = false
    _continue_hint.visible = false
    _welfare_label.visible = false
    _set_winner(winner_name, winner_seat, winner_title, winner_character_id)
    _bid_value_label.text = _format_comma(winning_bid)
    _loot_value_label.text = "0"
    _set_profit(-winning_bid)


func apply_tick(tick: Dictionary) -> void:
    var loot: int = int(tick.get("loot_total", 0))
    var profit: int = int(tick.get("profit", 0))
    _loot_value_label.text = _format_comma(loot)
    _set_profit(profit)
    if not winner_name_from_tick(tick).is_empty():
        _set_winner(
            winner_name_from_tick(tick),
            int(tick.get("winner_seat", -1)),
            str(tick.get("winner_title", "")),
            str(tick.get("winner_character_id", "")),
        )


static func winner_name_from_tick(tick: Dictionary) -> String:
    return str(tick.get("winner_name", ""))


func show_final(result, can_claim: bool = true) -> void:
    var welfare: int = int(result.welfare_each) if result else 0
    if welfare > 0 and can_claim:
        _welfare_label.text = "本场福利（每人）: %s" % _format_comma(welfare)
        _welfare_label.visible = true
    else:
        _welfare_label.visible = false
    _claim_btn.text = "领取"
    _claim_btn.visible = can_claim
    _claim_btn.disabled = not can_claim
    _claim_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _continue_hint.text = "点击领取后继续"
    _continue_hint.visible = can_claim


func show_final_continue(result) -> void:
    var welfare: int = int(result.welfare_each) if result else 0
    if welfare > 0:
        _welfare_label.text = "本场福利（每人）: %s" % _format_comma(welfare)
        _welfare_label.visible = true
    else:
        _welfare_label.visible = false
    _claim_btn.text = "继续"
    _claim_btn.visible = true
    _claim_btn.disabled = false
    _claim_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _continue_hint.text = "奖励已自动结算"
    _continue_hint.visible = true


func _set_winner(name: String, seat: int, title: String, character_id: String = "") -> void:
    if name.is_empty():
        _winner_row.visible = false
        return
    _winner_row.visible = true
    _winner_name_label.text = name
    _winner_title_label.text = title if not title.is_empty() else "竞拍成功者"
    _winner_title_label.visible = not _winner_title_label.text.is_empty()
    _winner_avatar.texture = _resolve_winner_avatar_texture(character_id, seat)


static func _resolve_winner_avatar_texture(character_id: String, seat: int) -> Texture2D:
    if not character_id.is_empty() and RosterConfigScript.has_character(character_id):
        return RosterConfigScript.get_avatar_texture(character_id)
    var fallback_path: String = "res://assets/ui/avatars/avatar_%d.png" % (maxi(seat, 0) % 4)
    if ResourceLoader.exists(fallback_path):
        return load(fallback_path) as Texture2D
    return null


func _set_profit(profit: int) -> void:
    var sign_prefix: String = "+" if profit >= 0 else ""
    _profit_value_label.text = "%s%s" % [sign_prefix, _format_comma(profit)]
    if profit < 0:
        _profit_value_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
    else:
        _profit_value_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65))


func _make_caption(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8))
    label.add_theme_font_size_override("font_size", 14)
    return label


func _make_value_label(font_size: int = 28) -> Label:
    var label := Label.new()
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
    return label


func _style_claim_button() -> void:
    UiButtonStyleScript.apply_settlement_action(_claim_btn)


static func _format_comma(amount: int) -> String:
    var neg: bool = amount < 0
    var s: String = str(abs(amount))
    var out: String = "-" if neg else ""
    for i in s.length():
        if i > 0 and (s.length() - i) % 3 == 0:
            out += ","
        out += s[i]
    return out
