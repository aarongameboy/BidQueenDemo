class_name MatchmakingOverlay
extends Control

signal matching_finished
signal matching_cancelled

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const MenuBackgroundScript = preload("res://scripts/ui/menu_background.gd")
const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")

var _active: bool = false
var _elapsed: float = 0.0
var _duration: float = 7.0
var _map_name_label: Label
var _timer_label: Label
var _silver_label: Label


func _ready() -> void:
    _build_ui()
    FontUtilScript.apply_cjk_font(self, 14)
    hide()


func _process(delta: float) -> void:
    if not _active:
        return
    _elapsed += delta
    var sec: int = int(floor(_elapsed))
    _timer_label.text = "%ds" % maxi(1, sec)
    if _elapsed >= _duration:
        _active = false
        hide()
        matching_finished.emit()


func start_matching(map_name: String, silver: int) -> void:
    MenuBackgroundScript.set_viewport_dim(0.4)
    _duration = randf_range(5.0, 10.0)
    _elapsed = 0.0
    _active = true
    _map_name_label.text = map_name
    _silver_label.text = _format_yuan(silver)
    _timer_label.text = "1s"
    show()
    move_to_front()


func cancel_matching() -> void:
    if not _active:
        return
    _active = false
    hide()
    matching_cancelled.emit()


func _build_ui() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    MenuBackgroundScript.apply(self, 0.4)
    var root := MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 20)
    root.add_theme_constant_override("margin_top", 16)
    root.add_theme_constant_override("margin_right", 20)
    root.add_theme_constant_override("margin_bottom", 24)
    add_child(root)
    var vbox := VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(vbox)
    var top := HBoxContainer.new()
    vbox.add_child(top)
    var tag_col := VBoxContainer.new()
    tag_col.add_theme_constant_override("separation", 2)
    top.add_child(tag_col)
    var tag := Label.new()
    tag.text = "快速匹配"
    tag.add_theme_font_size_override("font_size", 12)
    tag.add_theme_color_override("font_color", Color(0.45, 0.88, 0.55))
    tag_col.add_child(tag)
    _map_name_label = Label.new()
    _map_name_label.text = "琥珀商馆"
    FontUtilScript.style_title_label(_map_name_label, 26)
    tag_col.add_child(_map_name_label)
    var top_spacer := Control.new()
    top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(top_spacer)
    var silver_row := HBoxContainer.new()
    silver_row.add_theme_constant_override("separation", 6)
    silver_row.alignment = BoxContainer.ALIGNMENT_CENTER
    silver_row.add_child(UiMoneyIconScript.make_texture_rect(Vector2(22, 22)))
    _silver_label = Label.new()
    _silver_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _silver_label.add_theme_font_size_override("font_size", 18)
    _silver_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
    silver_row.add_child(_silver_label)
    top.add_child(silver_row)
    var center_spacer := Control.new()
    center_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(center_spacer)
    var status_box := VBoxContainer.new()
    status_box.alignment = BoxContainer.ALIGNMENT_CENTER
    status_box.add_theme_constant_override("separation", 10)
    vbox.add_child(status_box)
    var status := Label.new()
    status.text = "匹配中"
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 32)
    status_box.add_child(status)
    _timer_label = Label.new()
    _timer_label.text = "1s"
    _timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _timer_label.add_theme_font_size_override("font_size", 66)
    _timer_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.55))
    status_box.add_child(_timer_label)
    var hint := Label.new()
    hint.text = "正在寻找对手..."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 14)
    hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
    status_box.add_child(hint)
    var bottom_spacer := Control.new()
    bottom_spacer.custom_minimum_size = Vector2(0, 48)
    vbox.add_child(bottom_spacer)
    var cancel_row := HBoxContainer.new()
    cancel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_child(cancel_row)
    var cancel_side_l := Control.new()
    cancel_side_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_side_l.size_flags_stretch_ratio = 1.0
    cancel_row.add_child(cancel_side_l)
    var cancel_btn := Button.new()
    cancel_btn.text = "取消匹配"
    cancel_btn.custom_minimum_size = Vector2(0, 44)
    cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_btn.size_flags_stretch_ratio = 1.0
    UiButtonStyleScript.apply_centered_action(cancel_btn, Color(0.75, 0.78, 0.85), 16, 44)
    cancel_btn.pressed.connect(cancel_matching)
    cancel_row.add_child(cancel_btn)
    var cancel_side_r := Control.new()
    cancel_side_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_side_r.size_flags_stretch_ratio = 1.0
    cancel_row.add_child(cancel_side_r)


static func _format_yuan(amount: int) -> String:
    var prefix: String = "¥"
    var n: int = absi(amount)
    var s: String = str(n)
    var out: String = ""
    while s.length() > 3:
        out = "," + s.substr(s.length() - 3, 3) + out
        s = s.substr(0, s.length() - 3)
    return prefix + s + out
