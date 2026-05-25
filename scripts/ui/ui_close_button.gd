class_name UiCloseButton
extends RefCounted
## 关闭/返回按钮图标（res://assets/ui/close.png）+ 方形暗色底衬

const CLOSE_PATH: String = "res://assets/ui/close.png"
const DEFAULT_SIZE: Vector2 = Vector2(48, 48)
const MASK_PAD: int = 4

static var _texture: Texture2D


static func get_texture() -> Texture2D:
    if _texture != null:
        return _texture
    if ResourceLoader.exists(CLOSE_PATH):
        _texture = load(CLOSE_PATH) as Texture2D
    return _texture


## 创建带方形底衬的关闭按钮（返回内部 Button，供绑定信号）
static func create(pressed_callback: Callable = Callable(), size: Vector2 = DEFAULT_SIZE) -> Button:
    var wrap: Control = _build_close_widget(pressed_callback, size)
    return _resolve_button(wrap)


## 顶栏 HBox 最右侧追加关闭按钮（标题等控件应先加入且 size_flags_horizontal = EXPAND）
static func append_to_header(
    header: HBoxContainer,
    pressed_callback: Callable = Callable(),
    size: Vector2 = DEFAULT_SIZE,
) -> Button:
    var wrap: Control = _build_close_widget(pressed_callback, size)
    var btn: Button = _resolve_button(wrap)
    if btn:
        btn.tooltip_text = "关闭"
    header.add_child(wrap)
    return btn


## 全屏界面右上角固定关闭按钮
static func pin_top_right(
    parent: Control,
    pressed_callback: Callable = Callable(),
    size: Vector2 = DEFAULT_SIZE,
    margin: Vector2 = Vector2(16, 12),
) -> Button:
    var wrap: Control = _build_close_widget(pressed_callback, size)
    var mask_size: Vector2 = wrap.custom_minimum_size
    var btn: Button = _resolve_button(wrap)
    if btn:
        btn.tooltip_text = "关闭"
    wrap.z_index = 20
    parent.add_child(wrap)
    wrap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    wrap.offset_top = margin.y
    wrap.offset_right = -margin.x
    wrap.offset_left = wrap.offset_right - mask_size.x
    wrap.offset_bottom = margin.y + mask_size.y
    return btn


static func _build_close_widget(pressed_callback: Callable, size: Vector2) -> Control:
    var mask_size: Vector2 = size + Vector2(MASK_PAD * 2, MASK_PAD * 2)
    var root := Control.new()
    root.name = "CloseButtonWrap"
    root.custom_minimum_size = mask_size
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    var mask := PanelContainer.new()
    mask.name = "Mask"
    mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.04, 0.05, 0.08, 0.82)
    sb.border_color = Color(0.32, 0.36, 0.44, 0.65)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(3)
    mask.add_theme_stylebox_override("panel", sb)
    root.add_child(mask)
    var btn := Button.new()
    btn.name = "CloseButton"
    btn.set_anchors_preset(Control.PRESET_CENTER)
    btn.offset_left = -size.x * 0.5
    btn.offset_top = -size.y * 0.5
    btn.offset_right = size.x * 0.5
    btn.offset_bottom = size.y * 0.5
    btn.mouse_filter = Control.MOUSE_FILTER_STOP
    apply(btn, size)
    if pressed_callback.is_valid():
        btn.pressed.connect(pressed_callback)
    root.add_child(btn)
    return root


static func _resolve_button(wrap: Control) -> Button:
    if wrap == null:
        return null
    var btn: Node = wrap.get_node_or_null("CloseButton")
    if btn is Button:
        return btn as Button
    return null


## 将已有 Button 改为关闭图标样式
static func apply(btn: Button, size: Vector2 = DEFAULT_SIZE) -> void:
    btn.flat = true
    btn.text = ""
    btn.custom_minimum_size = size
    btn.focus_mode = Control.FOCUS_NONE
    var tex: Texture2D = get_texture()
    if tex:
        btn.icon = tex
        btn.expand_icon = true
    else:
        btn.text = "✕"
    _apply_icon_theme(btn)


static func _apply_icon_theme(btn: Button) -> void:
    var empty := StyleBoxEmpty.new()
    btn.add_theme_stylebox_override("normal", empty)
    btn.add_theme_stylebox_override("hover", empty)
    btn.add_theme_stylebox_override("pressed", empty)
    btn.add_theme_stylebox_override("disabled", empty)
    btn.add_theme_stylebox_override("focus", empty)
    btn.add_theme_color_override("icon_normal_color", Color(0.95, 0.96, 1.0, 1))
    btn.add_theme_color_override("icon_hover_color", Color(1, 1, 1, 1))
    btn.add_theme_color_override("icon_pressed_color", Color(0.82, 0.86, 0.92, 1))
    btn.add_theme_color_override("icon_disabled_color", Color(0.45, 0.48, 0.52, 1))
    btn.add_theme_color_override("icon_focus_color", Color(1, 1, 1, 1))
