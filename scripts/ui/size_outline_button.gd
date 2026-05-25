class_name SizeOutlineButton
extends Button
## 轮廓筛选按钮：小网格展示占位形状

const FontUtilScript = preload("res://scripts/ui/font_util.gd")

var size_w: int = 1
var size_h: int = 1
var _grid: GridContainer
var _size_label: Label


func _init(sw: int, sh: int) -> void:
  size_w = sw
  size_h = sh
  custom_minimum_size = Vector2(48, 56)
  toggle_mode = true
  clip_contents = true
  var v := VBoxContainer.new()
  v.mouse_filter = Control.MOUSE_FILTER_IGNORE
  add_child(v)
  _size_label = Label.new()
  _size_label.text = "%d×%d" % [sw, sh]
  _size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  _size_label.add_theme_font_size_override("font_size", 10)
  _size_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
  _size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
  v.add_child(_size_label)
  _grid = GridContainer.new()
  _grid.columns = 5
  _grid.custom_minimum_size = Vector2(36, 36)
  _grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
  v.add_child(_grid)
  for y in 5:
    for x in 5:
      var cell := ColorRect.new()
      cell.custom_minimum_size = Vector2(6, 6)
      var on: bool = x < sw and y < sh
      cell.color = Color(0.35, 0.75, 1.0, 0.95) if on else Color(0.15, 0.17, 0.22, 0.8)
      cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
      _grid.add_child(cell)
  _apply_styleboxes()
  toggled.connect(_on_toggled)
  sync_visual_state()


func _apply_styleboxes() -> void:
  var sb := StyleBoxFlat.new()
  sb.bg_color = Color(0.1, 0.12, 0.16, 0.9)
  sb.set_corner_radius_all(4)
  sb.set_border_width_all(1)
  sb.border_color = Color(0.28, 0.32, 0.42)
  sb.set_content_margin_all(4)
  add_theme_stylebox_override("normal", sb)
  var sb_hover := sb.duplicate() as StyleBoxFlat
  sb_hover.border_color = Color(0.42, 0.5, 0.62)
  sb_hover.bg_color = Color(0.12, 0.14, 0.2, 0.95)
  add_theme_stylebox_override("hover", sb_hover)
  var sb_on := sb.duplicate() as StyleBoxFlat
  sb_on.bg_color = Color(0.14, 0.2, 0.3, 0.98)
  sb_on.border_color = Color(0.35, 0.88, 1.0)
  sb_on.set_border_width_all(2)
  add_theme_stylebox_override("pressed", sb_on)
  add_theme_stylebox_override("hover_pressed", sb_on)
  add_theme_stylebox_override("focus", sb.duplicate())


func _on_toggled(_pressed: bool) -> void:
  sync_visual_state()


func sync_visual_state() -> void:
  if _size_label:
    _size_label.add_theme_color_override(
      "font_color",
      Color(0.55, 0.95, 1.0) if button_pressed else Color(0.72, 0.78, 0.88),
    )


func apply_filter_label_style() -> void:
  if _size_label:
    FontUtilScript.style_semibold_label(_size_label, 10)
