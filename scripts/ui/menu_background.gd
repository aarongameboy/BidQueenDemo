class_name MenuBackground
extends RefCounted
## 菜单页前景遮罩（大厅/选图/匹配/角色）。
##
## 说明：
## - `Main/BgTexture` + `Background` 才是全屏底图（设计分辨率 1280×720，随窗口拉伸）。
## - 半透明 dim 统一使用 `Main/BgDim`，铺满整个 Background，避免各子界面尺寸不一致。
## - 各菜单 Control 不要再铺第二张底图，也不要再嵌套 MenuBgDim。

const UiTextureCacheScript = preload("res://scripts/ui/ui_texture_cache.gd")


## 设置全屏 dim 透明度（底图由 Main 场景 BgTexture 统一提供）
static func apply(parent: Control, dim_alpha: float = 0.28) -> void:
	_remove_legacy_menu_dim(parent)
	ensure_main_viewport_background()
	set_viewport_dim(dim_alpha)


static func set_viewport_dim(dim_alpha: float) -> void:
	var bg_dim: ColorRect = _get_main_bg_dim()
	if bg_dim == null:
		return
	if dim_alpha <= 0.0:
		clear_viewport_dim()
		return
	bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_dim.offset_left = 0.0
	bg_dim.offset_top = 0.0
	bg_dim.offset_right = 0.0
	bg_dim.offset_bottom = 0.0
	bg_dim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_dim.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg_dim.color = Color(0.04, 0.05, 0.08, dim_alpha)
	bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_dim.visible = true
	_ensure_bg_dim_layer_order(bg_dim)


static func clear_viewport_dim() -> void:
	var bg_dim: ColorRect = _get_main_bg_dim()
	if bg_dim == null:
		return
	bg_dim.visible = false


## 配置 Main 根节点上的 BgTexture，铺满 1280×720 视口
static func ensure_main_viewport_background() -> void:
	var tex: Texture2D = UiTextureCacheScript.get_warehouse_bg()
	var main: Node = _get_main_node()
	if main == null:
		return
	var bg_tex: TextureRect = main.get_node_or_null("BgTexture") as TextureRect
	if bg_tex == null:
		return
	if tex:
		bg_tex.texture = tex
	bg_tex.visible = true
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


static func _remove_legacy_menu_dim(parent: Control) -> void:
	if parent == null:
		return
	var legacy: Node = parent.get_node_or_null("MenuBgDim")
	if legacy:
		legacy.queue_free()


static func _ensure_bg_dim_layer_order(bg_dim: ColorRect) -> void:
	var main: Node = bg_dim.get_parent()
	if main == null:
		return
	var bg_tex: Node = main.get_node_or_null("BgTexture")
	if bg_tex:
		main.move_child(bg_dim, bg_tex.get_index() + 1)


static func _get_main_bg_dim() -> ColorRect:
	var main: Node = _get_main_node()
	if main == null:
		return null
	return main.get_node_or_null("BgDim") as ColorRect


static func _get_main_node() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	if tree.root.get_child_count() == 0:
		return null
	return tree.root.get_child(0)
