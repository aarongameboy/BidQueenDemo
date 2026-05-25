class_name BidNumpad
extends PanelContainer
## 出价数字键盘（参考明拍 UI：4×4 键区 + 右侧确认区）

signal confirm_pressed
signal amount_changed(amount_text: String)

const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")

const KEY_ENTRIES: Array[Dictionary] = [
    {"text": "1", "action": "1"},
    {"text": "2", "action": "2"},
    {"text": "3", "action": "3"},
    {"text": "⌫", "action": "backspace"},
    {"text": "4", "action": "4"},
    {"text": "5", "action": "5"},
    {"text": "6", "action": "6"},
    {"text": "×2", "action": "mul"},
    {"text": "7", "action": "7"},
    {"text": "8", "action": "8"},
    {"text": "9", "action": "9"},
    {"text": "上轮", "action": "last_round"},
    {"text": "0", "action": "0"},
    {"text": "00", "action": "00"},
    {"text": "000", "action": "000"},
    {"text": "归零", "action": "clear"},
]

var _amount: String = ""
var _silver_max: int = 0
var _last_round_bid: int = 0
var _enabled: bool = true
var _amount_input: LineEdit
var _hint_label: Label
var _confirm_btn: Button
var _syncing_input: bool = false
var _multiplier: float = 2.0
var _mul_btn: Button = null


func _init() -> void:
    custom_minimum_size = Vector2(0, 168)
    _apply_panel_style()
    var root := HBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    add_child(root)
    root.add_child(_build_keypad())
    root.add_child(_build_action_column())
    _refresh_display()


func set_interactive(enabled: bool) -> void:
    _enabled = enabled
    _confirm_btn.disabled = not enabled
    if _amount_input:
        _amount_input.editable = enabled
        _amount_input.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
    for c in _get_key_buttons():
        c.disabled = not enabled


func set_silver_max(amount: int) -> void:
    _silver_max = maxi(0, amount)
    _refresh_display()


func set_last_round_bid(amount: int) -> void:
    _last_round_bid = maxi(0, amount)


func set_multiplier(mult: float) -> void:
    _multiplier = mult
    if _mul_btn != null:
        if absf(mult - roundf(mult)) < 0.001:
            _mul_btn.text = "×%d" % int(roundf(mult))
        else:
            _mul_btn.text = "×%s" % ("%.1f" % mult).rstrip("0").rstrip(".")


func set_amount_text(text: String) -> void:
    _amount = _sanitize_digits(text)
    _clamp_to_silver_max()
    _sync_amount_input_text()
    amount_changed.emit(_amount)


func get_amount_text() -> String:
    return _amount


func focus_amount_input() -> void:
    if _amount_input and _enabled:
        _amount_input.grab_focus()


func get_amount_value() -> int:
    if _amount.is_empty():
        return -1
    if not _amount.is_valid_int():
        return -1
    return int(_amount)


func _apply_panel_style() -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.12, 0.92)
    sb.border_color = Color(0.22, 0.28, 0.38, 0.85)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 6
    sb.content_margin_right = 6
    sb.content_margin_top = 6
    sb.content_margin_bottom = 6
    add_theme_stylebox_override("panel", sb)


func _build_keypad() -> GridContainer:
    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    grid.custom_minimum_size = Vector2(248, 148)
    for entry in KEY_ENTRIES:
        var btn := _make_key_button(str(entry["text"]), str(entry["action"]))
        if str(entry["action"]) == "mul":
            _mul_btn = btn
        grid.add_child(btn)
    return grid


func _build_action_column() -> Control:
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 6)
    _hint_label = Label.new()
    _hint_label.text = "注意：出价须大于 0，且不超过当前银币"
    _hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hint_label.add_theme_font_size_override("font_size", 11)
    _hint_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
    col.add_child(_hint_label)
    _amount_input = LineEdit.new()
    _amount_input.custom_minimum_size = Vector2(0, 40)
    _amount_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
    _amount_input.editable = true
    _amount_input.focus_mode = Control.FOCUS_ALL
    _amount_input.context_menu_enabled = false
    _amount_input.caret_blink = true
    _amount_input.max_length = 16
    _amount_input.add_theme_font_size_override("font_size", 18)
    _amount_input.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
    _amount_input.add_theme_color_override("font_placeholder_color", Color(0.55, 0.58, 0.65))
    _style_amount_input(_amount_input)
    _amount_input.text_changed.connect(_on_amount_input_changed)
    _amount_input.text_submitted.connect(_on_amount_input_submitted)
    col.add_child(_amount_input)
    _confirm_btn = Button.new()
    _confirm_btn.text = "确认出价"
    _confirm_btn.custom_minimum_size = Vector2(0, 44)
    _confirm_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _confirm_btn.pressed.connect(_on_confirm)
    _style_confirm_button(_confirm_btn)
    col.add_child(_confirm_btn)
    return col


func _make_key_button(display_text: String, action: String) -> Button:
    var btn := Button.new()
    btn.text = display_text
    btn.custom_minimum_size = Vector2(58, 34)
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(_on_key_action.bind(action))
    _style_key_button(btn)
    return btn


func _style_key_button(btn: Button) -> void:
    UiButtonStyleScript.apply(btn, Color(0.92, 0.94, 1.0), 13)


func _style_amount_input(field: LineEdit) -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.08, 0.12, 1.0)
    sb.border_color = Color(0.22, 0.26, 0.34, 1.0)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(4)
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    field.add_theme_stylebox_override("normal", sb)
    var sb_f := sb.duplicate() as StyleBoxFlat
    sb_f.border_color = Color(0.3, 0.55, 0.85, 0.9)
    field.add_theme_stylebox_override("focus", sb_f)


func _style_confirm_button(btn: Button) -> void:
    UiButtonStyleScript.apply_success(btn, 16)


func _on_key_action(action: String) -> void:
    if not _enabled:
        return
    match action:
        "backspace":
            if _amount.length() > 0:
                _amount = _amount.substr(0, _amount.length() - 1)
        "mul":
            _apply_multiplier()
        "last_round":
            if _last_round_bid > 0:
                _amount = str(_last_round_bid)
        "clear":
            _amount = ""
        "0", "00", "000":
            _append_digits(action)
        _:
            _append_digits(action)
    _clamp_to_silver_max()
    _sync_amount_input_text()
    amount_changed.emit(_amount)


func _get_current_amount_text() -> String:
    if _amount_input != null:
        var typed: String = _sanitize_digits(_amount_input.text)
        if not typed.is_empty():
            return typed
    return _amount


func _apply_multiplier() -> void:
    var base: String = _get_current_amount_text()
    if base.is_empty() or not base.is_valid_int():
        return
    var val: int = int(base)
    if val <= 0:
        return
    _amount = str(int(float(val) * _multiplier))


func _append_digits(digits: String) -> void:
    if _amount == "0":
        _amount = digits.lstrip("0")
        if _amount.is_empty():
            _amount = "0"
    else:
        _amount += digits
    if _amount.length() > 12:
        _amount = _amount.substr(0, 12)


func _clamp_to_silver_max() -> void:
    if not _amount.is_valid_int():
        return
    var val: int = int(_amount)
    if _silver_max > 0 and val > _silver_max:
        _amount = str(_silver_max)


func _sanitize_digits(text: String) -> String:
    var out: String = ""
    for c in text:
        if c >= "0" and c <= "9":
            out += c
    if out.is_empty():
        return ""
    while out.length() > 1 and out.begins_with("0"):
        out = out.substr(1)
    return out


func _on_amount_input_changed(new_text: String) -> void:
    if not _enabled or _syncing_input:
        return
    _amount = _sanitize_digits(new_text.replace(",", ""))
    if _amount.length() > 12:
        _amount = _amount.substr(0, 12)
    _clamp_to_silver_max()
    _sync_amount_input_text()
    amount_changed.emit(_amount)


func _on_amount_input_submitted(_text: String) -> void:
    if _enabled:
        _on_confirm()


func _sync_amount_input_text() -> void:
    if _amount_input == null:
        return
    var display: String = _format_comma_str(_amount) if not _amount.is_empty() else ""
    if _amount_input.text == display:
        _amount_input.placeholder_text = _build_placeholder_text()
        return
    _syncing_input = true
    _amount_input.text = display
    _amount_input.caret_column = display.length()
    _syncing_input = false
    _amount_input.placeholder_text = _build_placeholder_text()


func _refresh_display() -> void:
    if _amount_input == null:
        return
    _sync_amount_input_text()


func _build_placeholder_text() -> String:
    var max_txt: String = _format_comma(_silver_max) if _silver_max > 0 else "0"
    return "请输入竞拍价格：0 — %s" % max_txt


func _on_confirm() -> void:
    if _enabled:
        confirm_pressed.emit()


func _get_key_buttons() -> Array[Button]:
    var out: Array[Button] = []
    if get_child_count() == 0:
        return out
    var root: HBoxContainer = get_child(0) as HBoxContainer
    if root == null or root.get_child_count() == 0:
        return out
    var grid: GridContainer = root.get_child(0) as GridContainer
    if grid == null:
        return out
    for c in grid.get_children():
        if c is Button:
            out.append(c as Button)
    return out


static func _format_comma(amount: int) -> String:
    return _format_comma_str(str(amount))


static func _format_comma_str(s: String) -> String:
    if s.is_empty():
        return ""
    var result: String = ""
    for i in s.length():
        if i > 0 and (s.length() - i) % 3 == 0:
            result += ","
        result += s[i]
    return result
