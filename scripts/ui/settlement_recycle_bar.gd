class_name SettlementRecycleBar
extends PanelContainer
## 快速匹配结算：按品质筛选并一键回收战利品为银币

signal filter_changed(qualities: Array[int])
signal recycle_pressed(qualities: Array[int])

const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")

var _recycle_btn: Button
var _quality_buttons: Array[Button] = []
var _selected_qualities: Dictionary = {}


func _ready() -> void:
    _build_ui()
    FontUtilScript.apply_cjk_font(self, 13)
    reset_filters_all_selected()
    visible = false


func _build_ui() -> void:
    custom_minimum_size = Vector2(0, 52)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.08, 0.12, 0.92)
    sb.border_color = Color(0.28, 0.34, 0.44, 0.75)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(6)
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 8
    sb.content_margin_bottom = 8
    add_theme_stylebox_override("panel", sb)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    add_child(row)
    _recycle_btn = Button.new()
    _recycle_btn.custom_minimum_size = Vector2(148, 40)
    UiButtonStyleScript.apply(_recycle_btn, Color(0.72, 0.76, 0.82), 14)
    _recycle_btn.pressed.connect(_on_recycle_pressed)
    row.add_child(_recycle_btn)
    var filter_row := HBoxContainer.new()
    filter_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    filter_row.add_theme_constant_override("separation", 6)
    row.add_child(filter_row)
    var filter_lbl := Label.new()
    filter_lbl.text = "筛选:"
    filter_lbl.add_theme_font_size_override("font_size", 13)
    filter_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
    filter_row.add_child(filter_lbl)
    for q in GameConstants.QUALITY_COUNT:
        var btn := Button.new()
        btn.toggle_mode = true
        btn.button_pressed = true
        btn.custom_minimum_size = Vector2(26, 26)
        btn.tooltip_text = GameConstants.QUALITY_NAMES[q]
        var diamond := StyleBoxFlat.new()
        diamond.bg_color = GameConstants.get_quality_color(q)
        diamond.set_corner_radius_all(3)
        btn.add_theme_stylebox_override("normal", diamond)
        var dim := diamond.duplicate() as StyleBoxFlat
        dim.bg_color = dim.bg_color * Color(0.45, 0.45, 0.45, 1)
        btn.add_theme_stylebox_override("pressed", dim)
        var off := diamond.duplicate() as StyleBoxFlat
        off.bg_color = off.bg_color * Color(0.25, 0.25, 0.25, 0.85)
        btn.add_theme_stylebox_override("hover", diamond)
        btn.add_theme_stylebox_override("disabled", off)
        btn.toggled.connect(_on_quality_toggled.bind(q))
        filter_row.add_child(btn)
        _quality_buttons.append(btn)


func show_for_settlement(silver_amount: int, recyclable_count: int) -> void:
    reset_filters_all_selected()
    set_silver_display(silver_amount)
    update_recycle_count(recyclable_count)
    visible = true


func hide_bar() -> void:
    visible = false


func reset_filters_all_selected() -> void:
    _selected_qualities.clear()
    for q in GameConstants.QUALITY_COUNT:
        _selected_qualities[q] = true
    for btn in _quality_buttons:
        btn.button_pressed = true
    _emit_filter_changed()


func set_silver_display(_amount: int) -> void:
    pass


func update_recycle_count(count: int) -> void:
    if _recycle_btn == null:
        return
    _recycle_btn.text = "快捷回收(%d件)" % count
    _recycle_btn.disabled = count <= 0


func get_selected_qualities() -> Array[int]:
    var out: Array[int] = []
    for q in GameConstants.QUALITY_COUNT:
        if _selected_qualities.has(q):
            out.append(q)
    return out


func _on_quality_toggled(quality: int, pressed: bool) -> void:
    if pressed:
        _selected_qualities[quality] = true
    else:
        _selected_qualities.erase(quality)
    _emit_filter_changed()


func _on_recycle_pressed() -> void:
    recycle_pressed.emit(get_selected_qualities())


func _emit_filter_changed() -> void:
    filter_changed.emit(get_selected_qualities())


static func _format_comma(amount: int) -> String:
    var s: String = str(amount)
    var out: String = ""
    var n: int = s.length()
    for i in n:
        if i > 0 and (n - i) % 3 == 0:
            out += ","
        out += s[i]
    return out
