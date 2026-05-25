class_name FontUtil
extends RefCounted
## 字体规范
## - 标题：老明朝D（中英数字）
## - 正文：思源黑体（中文）+ Futura（英文数字），通过 Font 回退链实现

const FONT_TITLE_PATHS: PackedStringArray = [
    "res://assets/fonts/LaoMingChaoD.ttf",
    "res://assets/fonts/老明朝D.ttf",
    "res://assets/fonts/LaoMingChaoD.otf",
]

const FONT_BODY_CN_PATHS: PackedStringArray = [
    "res://assets/fonts/SourceHanSansSC-Regular.otf",
    "res://assets/fonts/NotoSansSC-Regular.otf",
    "res://assets/fonts/SourceHanSansCN-Regular.otf",
]

const FONT_BODY_EN_PATHS: PackedStringArray = [
    "res://assets/fonts/Futura.ttf",
    "res://assets/fonts/Futura-Medium.ttf",
    "res://assets/fonts/futura.ttf",
]

const TITLE_SYSTEM_FALLBACK: PackedStringArray = [
    "老明朝体",
    "老明朝",
    "Songti SC",
    "STSong",
    "Source Han Serif SC",
    "SimSun",
]

const BODY_CN_SYSTEM_FALLBACK: PackedStringArray = [
    "Source Han Sans SC",
    "Noto Sans SC",
    "思源黑体",
    "Microsoft YaHei UI",
    "PingFang SC",
]

const BODY_EN_SYSTEM_FALLBACK: PackedStringArray = [
    "Futura",
    "Futura PT",
    "Century Gothic",
    "Arial",
]

static var _title_font: Font
static var _body_font: Font
static var _semibold_font: Font


static func get_title_font() -> Font:
    if _title_font != null:
        return _title_font
    _title_font = _load_first_font_file(FONT_TITLE_PATHS)
    if _title_font == null:
        _title_font = _make_system_font(TITLE_SYSTEM_FALLBACK)
    return _title_font


static func get_body_font() -> Font:
    if _body_font != null:
        return _body_font
    _body_font = _load_first_font_file(FONT_BODY_CN_PATHS)
    if _body_font == null:
        _body_font = _make_system_font(BODY_CN_SYSTEM_FALLBACK)
    _attach_en_fallback(_body_font)
    return _body_font


static func apply_body_font(root: Node, size: int = 14) -> void:
    _apply_recursive(root, get_body_font(), size)


## 兼容旧调用
static func apply_cjk_font(root: Node, size: int = 14) -> void:
    apply_body_font(root, size)


static func apply_title_font(root: Node, size: int = 28) -> void:
    _apply_recursive(root, get_title_font(), size)


static func style_title_label(label: Label, size: int = 28) -> void:
    label.add_theme_font_override("font", get_title_font())
    label.add_theme_font_size_override("font_size", size)


static func style_body_label(label: Label, size: int = 14) -> void:
    label.add_theme_font_override("font", get_body_font())
    label.add_theme_font_size_override("font_size", size)


static func get_semibold_font() -> Font:
    if _semibold_font != null:
        return _semibold_font
    var base: Font = get_body_font()
    if base == null:
        return null
    var variation := FontVariation.new()
    variation.base_font = base
    variation.variation_opentype = {"wght": 600}
    _semibold_font = variation
    return _semibold_font


static func style_semibold_label(label: Label, size: int = 14) -> void:
    var font: Font = get_semibold_font()
    if font == null:
        style_body_label(label, size)
        return
    label.add_theme_font_override("font", font)
    label.add_theme_font_size_override("font_size", size)


static func apply_semibold_font(control: Control, size: int = 14) -> void:
    var font: Font = get_semibold_font()
    if font == null:
        font = get_body_font()
    if font == null:
        return
    control.add_theme_font_override("font", font)
    control.add_theme_font_size_override("font_size", size)


static func _load_first_font_file(paths: PackedStringArray) -> Font:
    for path in paths:
        if not ResourceLoader.exists(path):
            continue
        var res: Resource = load(path)
        if res is Font:
            return res as Font
    return null


static func _attach_en_fallback(base: Font) -> void:
    var en: Font = _load_first_font_file(FONT_BODY_EN_PATHS)
    if en == null:
        en = _make_system_font(BODY_EN_SYSTEM_FALLBACK)
    if en != null and base != null:
        var fallbacks: Array[Font] = []
        for f in base.get_fallbacks():
            fallbacks.append(f)
        fallbacks.append(en)
        base.set_fallbacks(fallbacks)


static func _make_system_font(names: PackedStringArray) -> SystemFont:
    var font := SystemFont.new()
    font.font_names = names
    font.font_weight = 400
    font.font_stretch = 100
    return font


static func _apply_recursive(node: Node, font: Font, size: int) -> void:
    if node is Label:
        var label := node as Label
        label.add_theme_font_override("font", font)
        if label.get_theme_font_size("font_size") <= 0:
            label.add_theme_font_size_override("font_size", size)
    elif node is Button:
        var button := node as Button
        button.add_theme_font_override("font", font)
        if button.get_theme_font_size("font_size") <= 0:
            button.add_theme_font_size_override("font_size", size)
    elif node is LineEdit:
        var line_edit := node as LineEdit
        line_edit.add_theme_font_override("font", font)
        if line_edit.get_theme_font_size("font_size") <= 0:
            line_edit.add_theme_font_size_override("font_size", size)
    elif node is RichTextLabel:
        var rich := node as RichTextLabel
        rich.add_theme_font_override("normal_font", font)
        if rich.get_theme_font_size("normal_font_size") <= 0:
            rich.add_theme_font_size_override("normal_font_size", size)
    for child in node.get_children():
        _apply_recursive(child, font, size)
