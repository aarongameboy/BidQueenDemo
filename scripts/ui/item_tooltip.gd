class_name ItemTooltip
extends PanelContainer
## 悬停道具 Tips：紧凑卡片浮窗（参考设计稿）

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiMoneyIconScript = preload("res://scripts/ui/ui_money_icon.gd")
const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")

const OFFSET_X: float = 14.0
const OFFSET_Y: float = 8.0
const PANEL_WIDTH: float = 340.0
const PANEL_MAX_HEIGHT: float = 200.0
const ICON_SIZE: float = 72.0
const FLAVOR_MAX_LINES: int = 2
const Z_TOOLTIP: int = 200

var _name_label: Label
var _type_label: Label
var _value_label: Label
var _flavor_label: Label
var _icon_rect: TextureRect
var _divider: ColorRect

## 当前正在 hover 的触发控件；null 表示无悬浮
var _active_control: Control = null


func _init() -> void:
    visible = false
    top_level = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = Z_TOOLTIP
    _build_ui()
    _ignore_mouse_recursive(self)


func _process(_delta: float) -> void:
    if _active_control == null:
        return
    if not is_instance_valid(_active_control) or not _active_control.is_visible_in_tree():
        _do_hide()
        return
    var mouse_pos := get_viewport().get_mouse_position()
    if not _active_control.get_global_rect().has_point(mouse_pos):
        _do_hide()
        return
    _position_at(mouse_pos)


func hide_tooltip() -> void:
    _do_hide()


func _do_hide() -> void:
    _active_control = null
    visible = false


func show_for_catalog_row(catalog_row: Dictionary, anchor_global: Vector2) -> void:
    if catalog_row.is_empty():
        hide_tooltip()
        return
    var payload: Dictionary = build_payload_from_catalog(catalog_row)
    _apply_payload(payload)
    _active_control = null
    visible = true
    _position_at(anchor_global)


func show_for_warehouse_item(
    wh_item,
    catalog,
    reveal_mode: String,
    anchor_global: Vector2,
) -> void:
    var payload: Dictionary = build_payload_from_warehouse_item(wh_item, catalog, reveal_mode)
    if not bool(payload.get("visible", false)):
        hide_tooltip()
        return
    _apply_payload(payload)
    _active_control = null
    visible = true
    _position_at(anchor_global)


static func build_payload_from_catalog(catalog_row: Dictionary) -> Dictionary:
    var type_key: String = str(catalog_row.get("item_type", ""))
    var type_label: String = str(ItemCatalogScript.TYPE_LABELS.get(type_key, type_key))
    if type_label.is_empty():
        type_label = "—"
    return {
        "visible": true,
        "name": str(catalog_row.get("item_name", "未知道具")),
        "type_label": type_label,
        "value": int(catalog_row.get("base_price", 0)),
        "flavor": str(catalog_row.get("flavor_text", "")),
        "icon_row": catalog_row,
        "quality_enum": int(catalog_row.get("quality_enum", 0)),
    }


static func build_payload_from_warehouse_item(
    wh_item,
    catalog,
    reveal_mode: String,
) -> Dictionary:
    if wh_item == null:
        return {"visible": false}
    var catalog_row: Dictionary = {}
    if catalog != null and catalog.is_loaded():
        catalog_row = catalog.get_item(str(wh_item.item_id))
    match reveal_mode:
        "full":
            var row_full: Dictionary = _warehouse_item_as_icon_row(wh_item)
            if not catalog_row.is_empty():
                row_full.merge(catalog_row, true)
            var type_full: String = str(
                ItemCatalogScript.TYPE_LABELS.get(str(catalog_row.get("item_type", "")), "")
            )
            if type_full.is_empty():
                type_full = "—"
            return {
                "visible": true,
                "name": str(wh_item.item_name),
                "type_label": type_full,
                "value": int(wh_item.value),
                "flavor": str(catalog_row.get("flavor_text", "")),
                "icon_row": row_full,
                "quality_enum": int(wh_item.quality),
            }
        "quality_size":
            var q_idx: int = int(wh_item.quality)
            var type_qs: String = (
                GameConstants.QUALITY_NAMES[q_idx]
                if q_idx >= 0 and q_idx < GameConstants.QUALITY_NAMES.size()
                else "未知品质"
            )
            var val_qs: int = 0
            if catalog != null:
                val_qs = catalog.get_min_base_price_for_known_item(
                    int(wh_item.quality), int(wh_item.size_w), int(wh_item.size_h),
                )
            if val_qs <= 0:
                var cells_qs: int = maxi(int(wh_item.size_w) * int(wh_item.size_h), 1)
                val_qs = int(GameConstants.QUALITY_SLOT_VALUE.get(int(wh_item.quality), 500)) * cells_qs
            return {
                "visible": true,
                "name": "未知道具",
                "type_label": "%s · %d×%d" % [type_qs, int(wh_item.size_w), int(wh_item.size_h)],
                "value": val_qs,
                "flavor": "",
                "icon_row": _warehouse_item_as_icon_row(wh_item),
                "quality_enum": q_idx,
            }
        "outline":
            var val_outline: int = 0
            if catalog != null:
                val_outline = catalog.get_min_base_price_for_size(
                    int(wh_item.size_w), int(wh_item.size_h),
                )
            if val_outline <= 0:
                var cells_ol: int = maxi(int(wh_item.size_w) * int(wh_item.size_h), 1)
                val_outline = 500 * cells_ol
            return {
                "visible": true,
                "name": "未知道具",
                "type_label": "占格 %d×%d" % [int(wh_item.size_w), int(wh_item.size_h)],
                "value": val_outline,
                "flavor": "",
                "icon_row": _warehouse_item_as_icon_row(wh_item),
                "quality_enum": int(wh_item.quality),
            }
        _:
            return {"visible": false}


static func _warehouse_item_as_icon_row(wh_item) -> Dictionary:
    return {
        "icon_path": str(wh_item.icon_path),
        "quality_enum": int(wh_item.quality),
        "item_id": str(wh_item.item_id),
    }


static func bind_hover(
    control: Control,
    tooltip: ItemTooltip,
    payload_factory: Callable,
) -> void:
    if control == null or tooltip == null:
        return
    if control.has_meta("_tooltip_bound"):
        return
    control.set_meta("_tooltip_bound", true)
    control.mouse_entered.connect(func() -> void:
        if not control.is_visible_in_tree():
            return
        var payload: Variant = payload_factory.call()
        if typeof(payload) != TYPE_DICTIONARY:
            tooltip.hide_tooltip()
            return
        var dict: Dictionary = payload
        if not bool(dict.get("visible", true)) or dict.is_empty():
            tooltip.hide_tooltip()
            return
        tooltip._apply_payload(dict)
        tooltip._active_control = control
        tooltip.visible = true
        tooltip._position_at(tooltip.get_viewport().get_mouse_position())
    )


func _apply_payload(payload: Dictionary) -> void:
    _name_label.text = str(payload.get("name", ""))
    _type_label.text = str(payload.get("type_label", "—"))
    _value_label.text = _format_value(int(payload.get("value", 0)))
    var flavor: String = str(payload.get("flavor", "")).strip_edges()
    if flavor.is_empty():
        _flavor_label.text = "暂无描述"
        _flavor_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
    else:
        _flavor_label.text = flavor
        _flavor_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
    var icon_row: Dictionary = payload.get("icon_row", {})
    _icon_rect.texture = ItemIconUtilScript.get_texture(icon_row) if not icon_row.is_empty() else null
    var q_enum: int = int(payload.get("quality_enum", 0))
    _divider.color = GameConstants.get_quality_color(q_enum)
    _ignore_mouse_recursive(self)


func _position_at(anchor_global: Vector2) -> void:
    var tip_size: Vector2 = get_combined_minimum_size()
    tip_size.x = PANEL_WIDTH
    tip_size.y = minf(tip_size.y, PANEL_MAX_HEIGHT)
    var screen: Vector2 = get_viewport_rect().size
    var pos: Vector2 = anchor_global + Vector2(OFFSET_X, OFFSET_Y)
    if pos.x + tip_size.x > screen.x - 4.0:
        pos.x = maxf(4.0, anchor_global.x - tip_size.x - OFFSET_X)
    if pos.y + tip_size.y > screen.y - 4.0:
        pos.y = maxf(4.0, anchor_global.y - tip_size.y - OFFSET_Y)
    position = pos
    size = tip_size


static func _ignore_mouse_recursive(node: Control) -> void:
    for child in node.get_children():
        if child is Control:
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _ignore_mouse_recursive(child)


func _build_ui() -> void:
    custom_minimum_size = Vector2(PANEL_WIDTH, 0)
    size = Vector2(PANEL_WIDTH, 0)
    clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.09, 0.13, 0.95)
    sb.border_color = Color(0.25, 0.28, 0.36, 0.7)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 12
    sb.content_margin_right = 12
    sb.content_margin_top = 10
    sb.content_margin_bottom = 8
    add_theme_stylebox_override("panel", sb)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 6)
    add_child(root)

    # --- Header: left text + right icon ---
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    root.add_child(header)

    var text_col := VBoxContainer.new()
    text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_col.add_theme_constant_override("separation", 2)
    header.add_child(text_col)

    _name_label = Label.new()
    _name_label.add_theme_font_size_override("font_size", 16)
    _name_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
    _name_label.clip_text = true
    _name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    text_col.add_child(_name_label)

    _type_label = Label.new()
    _type_label.add_theme_font_size_override("font_size", 11)
    _type_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
    text_col.add_child(_type_label)

    # Value row inside text column
    var value_row := HBoxContainer.new()
    value_row.add_theme_constant_override("separation", 4)
    text_col.add_child(value_row)

    value_row.add_child(UiMoneyIconScript.make_texture_rect(Vector2(16, 16)))

    _value_label = Label.new()
    _value_label.add_theme_font_size_override("font_size", 14)
    _value_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
    value_row.add_child(_value_label)

    # Icon on right side
    _icon_rect = TextureRect.new()
    _icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
    _icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(_icon_rect)

    # --- Divider: quality color bar ---
    _divider = ColorRect.new()
    _divider.custom_minimum_size = Vector2(0, 3)
    _divider.color = Color(0.45, 0.28, 0.62, 0.9)
    _divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_divider)

    # --- Flavor text ---
    _flavor_label = Label.new()
    _flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _flavor_label.max_lines_visible = FLAVOR_MAX_LINES
    _flavor_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _flavor_label.add_theme_font_size_override("font_size", 11)
    _flavor_label.add_theme_color_override("font_color", Color(0.68, 0.7, 0.76))
    _flavor_label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0)
    root.add_child(_flavor_label)

    FontUtilScript.apply_cjk_font(self, 11)


static func _format_value(amount: int) -> String:
    var n: int = absi(amount)
    if n >= 1_000_000_000:
        return "%d,%03d,%03d,%03d" % [n / 1_000_000_000, (n / 1_000_000) % 1000, (n / 1000) % 1000, n % 1000]
    if n >= 1_000_000:
        return "%d,%03d,%03d" % [n / 1_000_000, (n / 1000) % 1000, n % 1000]
    if n >= 1_000:
        return "%d,%03d" % [n / 1000, n % 1000]
    return str(n)
