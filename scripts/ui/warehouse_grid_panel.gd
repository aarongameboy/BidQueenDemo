class_name WarehouseGridPanel
extends Control
## 战利品格（默认 10×15）：底图 + 格子对齐，道具按 size_w×size_h 占格

const MatchControllerScript = preload("res://scripts/match/match_controller.gd")
const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")
const ItemQualityGlowScript = preload("res://scripts/ui/item_quality_glow.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")

signal slot_pressed(item_index: int)

const DEFAULT_GRID_COLS: int = 10
const DEFAULT_GRID_ROWS: int = 20
const CELL_SIZE: int = 42
const CELL_GAP: int = 1

var _grid_cols: int = DEFAULT_GRID_COLS
var _grid_rows: int = DEFAULT_GRID_ROWS

var _grid_section: PanelContainer
var _grid_scroll: ScrollContainer
var _grid_frame: Control
var _grid_bg: ColorRect
var _cells_layer: Control
var _items_layer: Control
var _name_label: Label
var _estimate_label: Label
var _wiki_btn: Button
var _warehouse = null
var _catalog = null
var _item_tooltip: ItemTooltip
var _revealed_mask: Array[bool] = []
var _quality_revealed_mask: Array[bool] = []
var _outline_revealed_mask: Array[bool] = []
var _item_panels: Array[PanelContainer] = []
var _selected_index: int = -1
var _grid_content_visible: bool = false


func _ready() -> void:
    _build_ui()
    FontUtilScript.apply_cjk_font(self, 13)
    if not resized.is_connected(_fit_grid_scale):
        resized.connect(_fit_grid_scale)
    if _grid_section and not _grid_section.resized.is_connected(_fit_grid_scale):
        _grid_section.resized.connect(_fit_grid_scale)
    call_deferred("_fit_grid_scale")


func _fit_grid_scale() -> void:
    if _grid_scroll == null or _grid_frame == null:
        return
    var avail: Vector2 = _grid_scroll.size
    var grid_px: Vector2 = _grid_pixel_size()
    if avail.x < 8.0 or avail.y < 8.0:
        return
    var scale: float = minf(minf(avail.x / grid_px.x, avail.y / grid_px.y), 1.0)
    _grid_frame.scale = Vector2(scale, scale)
    _grid_frame.custom_minimum_size = grid_px * scale
    _grid_frame.size = grid_px * scale


func _grid_pixel_size() -> Vector2:
    var w: float = _grid_cols * CELL_SIZE + (_grid_cols - 1) * CELL_GAP
    var h: float = _grid_rows * CELL_SIZE + (_grid_rows - 1) * CELL_GAP
    return Vector2(w, h)


func _apply_grid_dimensions(cols: int, rows: int) -> void:
    var next_cols: int = maxi(cols, 4)
    var next_rows: int = maxi(rows, 4)
    if next_cols == _grid_cols and next_rows == _grid_rows and _cells_layer.get_child_count() > 0:
        return
    _grid_cols = next_cols
    _grid_rows = next_rows
    if _grid_frame == null or _cells_layer == null or _items_layer == null:
        return
    var grid_px: Vector2 = _grid_pixel_size()
    _grid_frame.custom_minimum_size = grid_px
    _grid_frame.size = grid_px
    _cells_layer.custom_minimum_size = grid_px
    _cells_layer.size = grid_px
    _items_layer.custom_minimum_size = grid_px
    _items_layer.size = grid_px
    for c in _cells_layer.get_children():
        c.queue_free()
    for gy in _grid_rows:
        for gx in _grid_cols:
            _cells_layer.add_child(_make_cell(gx, gy))
    call_deferred("_fit_grid_scale")


func _cell_origin(gx: int, gy: int) -> Vector2:
    return Vector2(gx * (CELL_SIZE + CELL_GAP), gy * (CELL_SIZE + CELL_GAP))


func _cell_span(sw: int, sh: int) -> Vector2:
    return Vector2(
        sw * CELL_SIZE + (sw - 1) * CELL_GAP,
        sh * CELL_SIZE + (sh - 1) * CELL_GAP,
    )


func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vbox.add_theme_constant_override("separation", 8)
    add_child(vbox)
    var header_block := VBoxContainer.new()
    header_block.add_theme_constant_override("separation", 0)
    vbox.add_child(header_block)
    var header := HBoxContainer.new()
    header_block.add_child(header)
    var title := Label.new()
    title.text = "战利品"
    FontUtilScript.style_title_label(title, 18)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    header.add_child(title)
    header.alignment = BoxContainer.ALIGNMENT_CENTER
    _wiki_btn = Button.new()
    _wiki_btn.text = "藏品百科"
    _wiki_btn.custom_minimum_size = Vector2(96, 32)
    _wiki_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    UiButtonStyleScript.apply(_wiki_btn, Color(0.88, 0.92, 0.98), 13)
    _wiki_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
    header.add_child(_wiki_btn)
    _grid_section = PanelContainer.new()
    _grid_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _grid_section.custom_minimum_size = Vector2(0, 0)
    _apply_grid_section_style(_grid_section)
    vbox.add_child(_grid_section)
    var grid_margin := MarginContainer.new()
    grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    grid_margin.add_theme_constant_override("margin_left", 8)
    grid_margin.add_theme_constant_override("margin_top", 8)
    grid_margin.add_theme_constant_override("margin_right", 8)
    grid_margin.add_theme_constant_override("margin_bottom", 8)
    _grid_section.add_child(grid_margin)
    _grid_scroll = ScrollContainer.new()
    _grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    grid_margin.add_child(_grid_scroll)
    var grid_px: Vector2 = _grid_pixel_size()
    _grid_frame = Control.new()
    _grid_frame.custom_minimum_size = grid_px
    _grid_frame.size = grid_px
    _grid_scroll.add_child(_grid_frame)
    _grid_bg = ColorRect.new()
    _grid_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _grid_bg.color = Color(0.04, 0.06, 0.1, 0.45)
    _grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _grid_frame.add_child(_grid_bg)
    _cells_layer = Control.new()
    _cells_layer.custom_minimum_size = grid_px
    _cells_layer.size = grid_px
    _grid_frame.add_child(_cells_layer)
    for gy in _grid_rows:
        for gx in _grid_cols:
            _cells_layer.add_child(_make_cell(gx, gy))
    _items_layer = Control.new()
    _items_layer.custom_minimum_size = grid_px
    _items_layer.size = grid_px
    _items_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _grid_frame.add_child(_items_layer)
    _name_label = Label.new()
    _name_label.text = ""
    _name_label.visible = false
    _name_label.add_theme_font_size_override("font_size", 15)
    vbox.add_child(_name_label)
    _estimate_label = Label.new()
    _estimate_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.65))
    _estimate_label.text = "当前预估最低价格: —"
    vbox.add_child(_estimate_label)
    _show_cell_grid(true)
    _set_items_visible(false)
    _item_tooltip = ItemTooltipScript.new()
    add_child(_item_tooltip)


func _apply_grid_section_style(panel: PanelContainer) -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.05, 0.06, 0.09, 0.62)
    sb.border_color = Color(0.25, 0.32, 0.42, 0.55)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(6)
    panel.add_theme_stylebox_override("panel", sb)


func _make_cell(gx: int, gy: int) -> PanelContainer:
    var cell := PanelContainer.new()
    var pos: Vector2 = _cell_origin(gx, gy)
    cell.position = pos
    cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    cell.size = Vector2(CELL_SIZE, CELL_SIZE)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.04, 0.06, 0.1, 0.55)
    sb.border_color = Color(0.55, 0.65, 0.75, 0.45)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(0)
    cell.add_theme_stylebox_override("panel", sb)
    return cell


func get_wiki_button() -> Button:
    return _wiki_btn


func set_catalog(catalog) -> void:
    _catalog = catalog


func set_warehouse(warehouse, estimate_low: int) -> void:
    _warehouse = warehouse
    if _item_tooltip:
        _item_tooltip.hide_tooltip()
    _revealed_mask.clear()
    _quality_revealed_mask.clear()
    _outline_revealed_mask.clear()
    _clear_items()
    if warehouse == null:
        return
    _apply_grid_dimensions(warehouse.grid_w, warehouse.grid_h)
    for i in warehouse.items.size():
        _revealed_mask.append(false)
        _quality_revealed_mask.append(false)
        _outline_revealed_mask.append(false)
        var panel := _create_item_block(i, warehouse.items[i])
        panel.visible = false
        _items_layer.add_child(panel)
        _item_panels.append(panel)
    _show_cell_grid(true)
    _set_items_visible(false)
    _update_estimate_label(estimate_low)
    _name_label.text = ""
    _name_label.visible = false


func update_estimate(estimate_low: int) -> void:
    _update_estimate_label(estimate_low)


func _update_estimate_label(estimate_low: int) -> void:
    _estimate_label.text = "当前预估最低价格: %s" % _format_comma(estimate_low)


func reveal_intel_items(indices: Array) -> void:
    _show_cell_grid(true)
    for idx_v in indices:
        reveal_item(int(idx_v))


func reveal_quality_size_items(indices: Array) -> void:
    _show_cell_grid(true)
    for idx_v in indices:
        reveal_quality_size_item(int(idx_v))


func reveal_outline_items(indices: Array) -> void:
    _show_cell_grid(true)
    for idx_v in indices:
        reveal_outline_item(int(idx_v))


func reveal_outline_item(index: int) -> void:
    if _warehouse == null or index < 0 or index >= _warehouse.items.size():
        return
    _show_cell_grid(true)
    if index < _outline_revealed_mask.size():
        _outline_revealed_mask[index] = true
    if index < _item_panels.size():
        var panel: PanelContainer = _item_panels[index]
        panel.visible = true
        _apply_reveal_mode(panel, _warehouse.items[index], index)


func reveal_quality_size_item(index: int) -> void:
    if _warehouse == null or index < 0 or index >= _warehouse.items.size():
        return
    _show_cell_grid(true)
    if index < _quality_revealed_mask.size():
        _quality_revealed_mask[index] = true
    if index < _item_panels.size():
        var panel: PanelContainer = _item_panels[index]
        panel.visible = true
        _apply_reveal_mode(panel, _warehouse.items[index], index)
    _update_item_name_label(index)


func reveal_item(index: int) -> void:
    if _warehouse == null or index < 0 or index >= _warehouse.items.size():
        return
    _show_cell_grid(true)
    if index < _revealed_mask.size():
        _revealed_mask[index] = true
    if index < _quality_revealed_mask.size():
        _quality_revealed_mask[index] = true
    if index < _item_panels.size():
        var panel: PanelContainer = _item_panels[index]
        panel.visible = true
        _apply_reveal_mode(panel, _warehouse.items[index], index)
    _update_item_name_label(index)


func _show_cell_grid(visible: bool) -> void:
    if _cells_layer:
        _cells_layer.visible = visible
    if _grid_bg:
        _grid_bg.visible = visible


func _set_items_visible(visible: bool) -> void:
    _grid_content_visible = visible
    if not visible:
        for p in _item_panels:
            p.visible = false


func _clear_items() -> void:
    for p in _item_panels:
        p.queue_free()
    _item_panels.clear()


func _create_item_block(index: int, item) -> PanelContainer:
    var panel := PanelContainer.new()
    var origin: Vector2 = _cell_origin(item.grid_x, item.grid_y)
    var span: Vector2 = _cell_span(item.size_w, item.size_h)
    panel.position = origin
    panel.size = span
    panel.custom_minimum_size = span
    panel.add_theme_stylebox_override("panel", ItemQualityFrameScript.transparent_panel_style())
    panel.add_child(ItemQualityFrameScript.make_frame_rect(item.quality))
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 4)
    margin.add_theme_constant_override("margin_right", 4)
    margin.add_theme_constant_override("margin_top", 2)
    margin.add_theme_constant_override("margin_bottom", 2)
    panel.add_child(margin)
    var inner := Control.new()
    inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_child(inner)
    var name_l := Label.new()
    name_l.name = "ItemName"
    name_l.position = Vector2(4, 2)
    name_l.add_theme_font_size_override("font_size", 11)
    inner.add_child(name_l)
    var icon := TextureRect.new()
    icon.name = "Icon"
    icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    icon.offset_left = 4
    icon.offset_top = 4
    icon.offset_right = -4
    icon.offset_bottom = -4
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    inner.add_child(icon)
    panel.set_meta("item_index", index)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.gui_input.connect(func(ev: InputEvent) -> void:
        if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
            _select_item(index)
            slot_pressed.emit(index)
    )
    var glow := ItemQualityGlowScript.new()
    glow.name = "QualityGlow"
    panel.add_child(glow)
    glow.setup(item.quality)
    _apply_reveal_mode(panel, item, index)
    var item_index: int = index
    ItemTooltipScript.bind_hover(
        panel,
        _item_tooltip,
        func() -> Dictionary:
            if _warehouse == null or item_index < 0 or item_index >= _warehouse.items.size():
                return {"visible": false}
            return ItemTooltipScript.build_payload_from_warehouse_item(
                _warehouse.items[item_index],
                _catalog,
                _item_reveal_mode(item_index),
            ),
    )
    return panel


func _item_reveal_mode(index: int) -> String:
    if index < _revealed_mask.size() and _revealed_mask[index]:
        return "full"
    if index < _quality_revealed_mask.size() and _quality_revealed_mask[index]:
        return "quality_size"
    if index < _outline_revealed_mask.size() and _outline_revealed_mask[index]:
        return "outline"
    return "hidden"


func _apply_reveal_mode(panel: PanelContainer, item, index: int) -> void:
    var mode: String = _item_reveal_mode(index)
    var name_l: Label = panel.find_child("ItemName", true, false) as Label
    var icon: TextureRect = panel.find_child("Icon", true, false) as TextureRect
    var frame: TextureRect = panel.find_child("QualityFrame", true, false) as TextureRect
    var glow: ItemQualityGlow = panel.find_child("QualityGlow", true, false) as ItemQualityGlow
    var sb := ItemQualityFrameScript.transparent_panel_style()
    var qcolor := Color.from_string(item.quality_color, Color.GRAY)
    match mode:
        "full":
            name_l.visible = false
            name_l.text = item.item_name
            icon.texture = _load_item_texture(item)
            sb.bg_color = Color(qcolor.r, qcolor.g, qcolor.b, 0.28)
            if frame:
                frame.modulate = Color(1, 1, 1, 1)
            if glow:
                glow.set_glow_active(false)
            panel.modulate = Color(1, 1, 1, 1)
        "quality_size":
            name_l.visible = false
            name_l.text = ""
            icon.texture = null
            sb.bg_color = Color(qcolor.r, qcolor.g, qcolor.b, 0.08)
            if frame:
                frame.modulate = Color(1, 1, 1, 1)
            if glow:
                glow.setup(item.quality)
                glow.set_glow_active(true)
            panel.modulate = Color(1, 1, 1, 1)
        "outline":
            name_l.visible = false
            name_l.text = ""
            icon.texture = null
            sb.bg_color = Color(0.08, 0.1, 0.14, 0.2)
            if frame:
                frame.modulate = Color(0.92, 0.95, 1.0, 1)
            if glow:
                glow.setup(item.quality)
                glow.set_glow_active(true)
            panel.modulate = Color(1, 1, 1, 1)
        _:
            name_l.visible = false
            name_l.text = ""
            icon.texture = null
            sb.bg_color = Color(qcolor.r, qcolor.g, qcolor.b, 0.06)
            if frame:
                frame.modulate = Color(0.82, 0.85, 0.92, 0.9)
            if glow:
                glow.setup(item.quality)
                glow.set_glow_active(true)
            panel.modulate = Color(0.92, 0.94, 1.0, 1)
    panel.add_theme_stylebox_override("panel", sb)


func _load_item_texture(item) -> Texture2D:
    const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
    if item == null:
        return null
    if item is Dictionary:
        return ItemIconUtilScript.get_texture(item)
    var row: Dictionary = {
        "icon_path": str(item.icon_path),
        "quality_enum": int(item.quality),
    }
    return ItemIconUtilScript.get_texture(row)


func _select_item(index: int) -> void:
    _selected_index = index
    _update_item_name_label(index)


func _update_item_name_label(index: int) -> void:
    if _warehouse == null or index < 0 or index >= _warehouse.items.size():
        _name_label.visible = false
        _name_label.text = ""
        return
    var item = _warehouse.items[index]
    var mode: String = _item_reveal_mode(index)
    if mode == "full":
        _name_label.visible = true
        _name_label.text = item.item_name
    else:
        _name_label.visible = false
        _name_label.text = ""


static func _format_comma(amount: int) -> String:
    var s: String = str(amount)
    var out: String = ""
    var n: int = s.length()
    for i in n:
        if i > 0 and (n - i) % 3 == 0:
            out += ","
        out += s[i]
    return out
