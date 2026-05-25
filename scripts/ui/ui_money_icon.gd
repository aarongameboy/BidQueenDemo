class_name UiMoneyIcon
extends RefCounted
## 货币图标（res://assets/ui/money.png）

const MONEY_PATH: String = "res://assets/ui/money.png"
const DEFAULT_SIZE: Vector2 = Vector2(24, 24)

static var _texture: Texture2D


static func get_texture() -> Texture2D:
    if _texture != null:
        return _texture
    if ResourceLoader.exists(MONEY_PATH):
        _texture = load(MONEY_PATH) as Texture2D
    return _texture


static func make_texture_rect(size: Vector2 = DEFAULT_SIZE) -> TextureRect:
    var rect := TextureRect.new()
    rect.custom_minimum_size = size
    rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tex: Texture2D = get_texture()
    if tex:
        rect.texture = tex
    return rect


## 将场景中的 ColorRect 占位替换为货币图标，保持节点名与顺序
static func replace_color_rect(placeholder: ColorRect, size: Vector2 = Vector2.ZERO) -> TextureRect:
    var icon_size: Vector2 = size
    if icon_size == Vector2.ZERO:
        icon_size = placeholder.custom_minimum_size
    if icon_size == Vector2.ZERO:
        icon_size = DEFAULT_SIZE
    var parent: Node = placeholder.get_parent()
    if parent == null:
        push_warning("UiMoneyIcon: placeholder has no parent, skip replace")
        return make_texture_rect(icon_size)
    var idx: int = placeholder.get_index()
    var icon := make_texture_rect(icon_size)
    icon.name = placeholder.name
    parent.remove_child(placeholder)
    parent.add_child(icon)
    parent.move_child(icon, idx)
    placeholder.queue_free()
    return icon
