class_name ItemQualityGlow
extends Control
## 程序生成的品质发光序列帧（叠在品质底图之上，随格子尺寸缩放）

const FRAME_COUNT: int = 8
const ANIM_FPS: float = 10.0

var _quality: int = GameConstants.Quality.WHITE
var _anim_time: float = 0.0
var _active: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 2
	set_process(true)


func setup(quality: int) -> void:
	_quality = clampi(quality, 0, GameConstants.QUALITY_COUNT - 1)
	queue_redraw()


func set_glow_active(active: bool) -> void:
	_active = active
	visible = active
	if active:
		set_process(true)
		queue_redraw()
	else:
		set_process(false)


func _process(delta: float) -> void:
	if not _active:
		return
	_anim_time += delta
	queue_redraw()


func _draw() -> void:
	if not _active or size.x < 4.0 or size.y < 4.0:
		return
	var phase: float = fmod(_anim_time * ANIM_FPS, float(FRAME_COUNT)) / float(FRAME_COUNT)
	var pulse: float = 0.5 + 0.5 * sin(phase * TAU)
	var base: Color = GameConstants.get_quality_color(_quality)
	var fill_a: float = lerpf(0.14, 0.38, pulse)
	var border_a: float = lerpf(0.45, 0.95, pulse)
	var border_w: float = lerpf(1.5, 3.0, pulse)
	var rect := Rect2(Vector2.ZERO, size)
	var inset: float = maxf(1.0, minf(size.x, size.y) * 0.06)
	var inner := rect.grow(-inset)
	draw_rect(inner, Color(base.r, base.g, base.b, fill_a))
	_draw_glow_border(inner, base, border_a, border_w)
	_draw_corner_sparkles(inner, base, pulse)


func _draw_glow_border(rect: Rect2, base: Color, alpha: float, width: float) -> void:
	var c := Color(base.r, base.g, base.b, alpha)
	draw_rect(rect, c, false, width)
	var outer: Rect2 = rect.grow(width * 0.65)
	draw_rect(outer, Color(base.r, base.g, base.b, alpha * 0.35), false, width * 0.55)


func _draw_corner_sparkles(rect: Rect2, base: Color, pulse: float) -> void:
	var r: float = clampf(minf(rect.size.x, rect.size.y) * 0.08, 2.0, 6.0)
	var c := Color(base.r, base.g, base.b, 0.25 + pulse * 0.45)
	var pts: PackedVector2Array = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	]
	for p in pts:
		draw_circle(p, r, c)
