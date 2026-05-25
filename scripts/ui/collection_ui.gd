class_name CollectionUI
extends Control
## 珍稀展柜：26×10 格矩阵（与战利品相同排布规则），红色藏品按价值从高到低填入

signal closed

const FontUtilScript = preload("res://scripts/ui/font_util.gd")
const UiButtonStyleScript = preload("res://scripts/ui/ui_button_style.gd")
const UiCloseButtonScript = preload("res://scripts/ui/ui_close_button.gd")
const ItemQualityFrameScript = preload("res://scripts/ui/item_quality_frame.gd")
const ItemIconUtilScript = preload("res://scripts/ui/item_icon_util.gd")
const ItemTooltipScript = preload("res://scripts/ui/item_tooltip.gd")
const UiTextureCacheScript = preload("res://scripts/ui/ui_texture_cache.gd")

const GRID_COLS: int = 26
const GRID_ROWS: int = 10
const CELL_SIZE: int = 42
const CELL_GAP: int = 1

var _catalog = null
var _count_label: Label
var _scroll: ScrollContainer
var _center_host: Control
var _grid_frame: Control
var _cells_layer: Control
var _items_layer: Control
var _item_tooltip: ItemTooltip


func _ready() -> void:
    _build_shell()
    FontUtilScript.apply_cjk_font(self, 14)
    hide()


func setup(catalog) -> void:
    _catalog = catalog


func open() -> void:
    _refresh_grid()
    show()
    move_to_front()
    call_deferred("_fit_grid_scale")


func close() -> void:
    hide()
    closed.emit()


func _build_shell() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    UiTextureCacheScript.add_shop_background_layers(self)
    var root := MarginContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("margin_left", 16)
    root.add_theme_constant_override("margin_top", 12)
    root.add_theme_constant_override("margin_right", 16)
    root.add_theme_constant_override("margin_bottom", 12)
    add_child(root)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    root.add_child(vbox)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    vbox.add_child(header)
    _count_label = Label.new()
    _count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    _count_label.custom_minimum_size = Vector2(88, 0)
    _count_label.add_theme_font_size_override("font_size", 16)
    _count_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
    header.add_child(_count_label)
    var title := Label.new()
    title.text = "珍稀展柜"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    FontUtilScript.style_title_label(title, 24)
    header.add_child(title)
    UiCloseButtonScript.append_to_header(header, close)
    var line := ColorRect.new()
    line.custom_minimum_size = Vector2(0, 1)
    line.color = Color(0.25, 0.28, 0.35, 0.8)
    vbox.add_child(line)
    var grid_panel := PanelContainer.new()
    grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var panel_sb := StyleBoxFlat.new()
    panel_sb.bg_color = Color(0.05, 0.06, 0.09, 0.62)
    panel_sb.border_color = Color(0.25, 0.32, 0.42, 0.55)
    panel_sb.set_border_width_all(1)
    panel_sb.set_corner_radius_all(6)
    grid_panel.add_theme_stylebox_override("panel", panel_sb)
    vbox.add_child(grid_panel)
    var grid_margin := MarginContainer.new()
    grid_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grid_margin.add_theme_constant_override("margin_left", 8)
    grid_margin.add_theme_constant_override("margin_top", 8)
    grid_margin.add_theme_constant_override("margin_right", 8)
    grid_margin.add_theme_constant_override("margin_bottom", 8)
    grid_panel.add_child(grid_margin)
    _scroll = ScrollContainer.new()
    _scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    grid_margin.add_child(_scroll)
    _center_host = Control.new()
    _scroll.add_child(_center_host)
    var grid_px: Vector2 = _grid_pixel_size()
    _grid_frame = Control.new()
    _grid_frame.custom_minimum_size = grid_px
    _grid_frame.size = grid_px
    _center_host.add_child(_grid_frame)
    var grid_bg := ColorRect.new()
    grid_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    grid_bg.color = Color(0.04, 0.06, 0.1, 0.45)
    grid_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _grid_frame.add_child(grid_bg)
    _cells_layer = Control.new()
    _cells_layer.custom_minimum_size = grid_px
    _cells_layer.size = grid_px
    _grid_frame.add_child(_cells_layer)
    _items_layer = Control.new()
    _items_layer.custom_minimum_size = grid_px
    _items_layer.size = grid_px
    _items_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _grid_frame.add_child(_items_layer)
    _scroll.resized.connect(_fit_grid_scale)
    resized.connect(_fit_grid_scale)
    _item_tooltip = ItemTooltipScript.new()
    add_child(_item_tooltip)


func _fit_grid_scale() -> void:
    if _scroll == null or _grid_frame == null or _center_host == null:
        return
    var avail: Vector2 = _scroll.size
    var grid_px: Vector2 = _grid_pixel_size()
    if avail.x < 8.0 or avail.y < 8.0:
        return
    var scale: float = minf(minf(avail.x / grid_px.x, avail.y / grid_px.y), 1.0)
    var scaled: Vector2 = grid_px * scale
    _grid_frame.scale = Vector2(scale, scale)
    _grid_frame.custom_minimum_size = scaled
    _grid_frame.size = scaled
    var host_size: Vector2 = Vector2(maxi(avail.x, scaled.x), maxi(avail.y, scaled.y))
    _center_host.custom_minimum_size = host_size
    _center_host.size = host_size
    _grid_frame.position = (host_size - scaled) * 0.5


func _refresh_grid() -> void:
    for c in _cells_layer.get_children():
        c.queue_free()
    for c in _items_layer.get_children():
        c.queue_free()
    if _catalog == null or not _catalog.is_loaded():
        _count_label.text = "0 / 0"
        return
    var portfolio: Node = get_node_or_null("/root/PlayerCollection")
    var catalog_reds: Array = _catalog.get_items_by_quality_name("red")
    var collected_n: int = 0
    if portfolio:
        collected_n = int(portfolio.collected_count())
    _count_label.text = "%d / %d" % [collected_n, catalog_reds.size()]
    var grid_px: Vector2 = _grid_pixel_size()
    _grid_frame.custom_minimum_size = grid_px
    _grid_frame.size = grid_px
    _cells_layer.custom_minimum_size = grid_px
    _cells_layer.size = grid_px
    _items_layer.custom_minimum_size = grid_px
    _items_layer.size = grid_px
    for gy in GRID_ROWS:
        for gx in GRID_COLS:
            _cells_layer.add_child(_make_cell(gx, gy))
    var occupancy: Array = _new_occupancy(GRID_ROWS)
    for item in catalog_reds:
        var sw: int = clampi(int(item.get("size_w", 1)), 1, GRID_COLS)
        var sh: int = clampi(int(item.get("size_h", 1)), 1, GRID_ROWS)
        if sw > GRID_COLS or sh > GRID_ROWS:
            continue
        var pos: Vector2i = _find_first_fit(occupancy, sw, sh, GRID_ROWS)
        if pos.x < 0:
            continue
        _occupy(occupancy, pos.x, pos.y, sw, sh)
        _items_layer.add_child(_make_item_slot(item, pos.x, pos.y, sw, sh))
    call_deferred("_fit_grid_scale")


func _new_occupancy(row_count: int = GRID_ROWS) -> Array:
    var grid: Array = []
    for _y in row_count:
        var row: Array = []
        row.resize(GRID_COLS)
        for x in GRID_COLS:
            row[x] = false
        grid.append(row)
    return grid


func _find_first_fit(occupancy: Array, sw: int, sh: int, row_count: int) -> Vector2i:
    for y in row_count - sh + 1:
        for x in GRID_COLS - sw + 1:
            if _can_place(occupancy, x, y, sw, sh):
                return Vector2i(x, y)
    return Vector2i(-1, -1)


func _can_place(occupancy: Array, x: int, y: int, sw: int, sh: int) -> bool:
    if x < 0 or y < 0 or x + sw > GRID_COLS or y + sh > GRID_ROWS:
        return false
    for dy in sh:
        for dx in sw:
            if occupancy[y + dy][x + dx]:
                return false
    return true


func _occupy(occupancy: Array, x: int, y: int, sw: int, sh: int) -> void:
    for dy in sh:
        for dx in sw:
            occupancy[y + dy][x + dx] = true


func _grid_pixel_size() -> Vector2:
    return Vector2(
        GRID_COLS * CELL_SIZE + (GRID_COLS - 1) * CELL_GAP,
        GRID_ROWS * CELL_SIZE + (GRID_ROWS - 1) * CELL_GAP,
    )


func _cell_origin(gx: int, gy: int) -> Vector2:
    return Vector2(gx * (CELL_SIZE + CELL_GAP), gy * (CELL_SIZE + CELL_GAP))


func _cell_span(sw: int, sh: int) -> Vector2:
    return Vector2(
        sw * CELL_SIZE + (sw - 1) * CELL_GAP,
        sh * CELL_SIZE + (sh - 1) * CELL_GAP,
    )


func _make_cell(gx: int, gy: int) -> PanelContainer:
    var cell := PanelContainer.new()
    cell.position = _cell_origin(gx, gy)
    cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
    cell.size = Vector2(CELL_SIZE, CELL_SIZE)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.04, 0.06, 0.1, 0.55)
    sb.border_color = Color(0.55, 0.65, 0.75, 0.45)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(0)
    cell.add_theme_stylebox_override("panel", sb)
    return cell


func _make_item_slot(item: Dictionary, gx: int, gy: int, sw: int, sh: int) -> PanelContainer:
    var item_id: String = str(item.get("item_id", ""))
    var collected: bool = false
    var portfolio: Node = get_node_or_null("/root/PlayerCollection")
    if portfolio:
        collected = bool(portfolio.has_collected(item_id))
    var span: Vector2 = _cell_span(sw, sh)
    var panel := PanelContainer.new()
    panel.position = _cell_origin(gx, gy)
    panel.size = span
    panel.custom_minimum_size = span
    panel.add_theme_stylebox_override("panel", ItemQualityFrameScript.transparent_panel_style())
    var frame_q: int = (
        GameConstants.Quality.RED if collected else GameConstants.Quality.WHITE
    )
    var frame := ItemQualityFrameScript.make_frame_rect(frame_q)
    if collected:
        panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
        frame.modulate = Color(1, 1, 1, 1)
    else:
        panel.modulate = Color(0.72, 0.74, 0.78, 0.88)
        frame.modulate = Color(0.55, 0.58, 0.64, 0.75)
    panel.add_child(frame)
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
    var icon := TextureRect.new()
    icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    icon.offset_left = 4
    icon.offset_top = 14
    icon.offset_right = -4
    icon.offset_bottom = -4
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.texture = ItemIconUtilScript.get_texture(item)
    if collected:
        icon.modulate = Color(1, 1, 1, 1)
    else:
        icon.modulate = Color(0.45, 0.48, 0.52, 0.65)
    inner.add_child(icon)
    var name_l := Label.new()
    name_l.text = str(item.get("item_name", ""))
    name_l.position = Vector2(4, 2)
    name_l.size = Vector2(span.x - 8.0, 14.0)
    name_l.clip_text = true
    name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    name_l.add_theme_font_size_override("font_size", 9)
    if collected:
        name_l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.82))
    else:
        name_l.add_theme_color_override("font_color", Color(0.5, 0.52, 0.56))
    inner.add_child(name_l)
    if not collected:
        var lock_lbl := Label.new()
        lock_lbl.text = "未获得"
        lock_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        lock_lbl.offset_bottom = -2
        lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lock_lbl.add_theme_font_size_override("font_size", 8)
        lock_lbl.add_theme_color_override("font_color", Color(0.42, 0.44, 0.48, 0.9))
        inner.add_child(lock_lbl)
    ItemTooltipScript.bind_hover(
        panel,
        _item_tooltip,
        func() -> Dictionary:
            return ItemTooltipScript.build_payload_from_catalog(item),
    )
    return panel
