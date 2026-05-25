class_name UiTextureCache
extends RefCounted
## 缓存 UI 贴图，避免重复 load 且在导入未完成时安全降级
## 全屏背景建议尺寸：1280×720（16:9），与 GameConstants.VIEWPORT_* 一致

const WAREHOUSE_BG_PATH := "res://assets/ui/bg_warehouse.png"
const SHOP_BG_PATH := "res://assets/ui/bg_shop.png"
const SHOPGIRL_PATH := "res://assets/ui/shopgirl.png"
const RECOMMENDED_BG_SIZE := Vector2i(1280, 720)

const SHOP_BG_DIM_ALPHA: float = 0.38

static var _warehouse_bg: Texture2D
static var _shop_bg: Texture2D
static var _shopgirl: Texture2D


static func get_warehouse_bg() -> Texture2D:
	if _warehouse_bg != null:
		return _warehouse_bg
	if not ResourceLoader.exists(WAREHOUSE_BG_PATH):
		return null
	var res: Resource = ResourceLoader.load(WAREHOUSE_BG_PATH)
	if res is Texture2D:
		_warehouse_bg = res as Texture2D
		if _warehouse_bg.get_width() != RECOMMENDED_BG_SIZE.x or _warehouse_bg.get_height() != RECOMMENDED_BG_SIZE.y:
			push_warning(
				"UiTextureCache: %s 为 %dx%d，建议导出为 %dx%d 与视口一致"
				% [
					WAREHOUSE_BG_PATH,
					_warehouse_bg.get_width(),
					_warehouse_bg.get_height(),
					RECOMMENDED_BG_SIZE.x,
					RECOMMENDED_BG_SIZE.y,
				]
			)
	return _warehouse_bg


static func get_shop_bg() -> Texture2D:
	if _shop_bg != null:
		return _shop_bg
	if not ResourceLoader.exists(SHOP_BG_PATH):
		return null
	var res: Resource = ResourceLoader.load(SHOP_BG_PATH)
	if res is Texture2D:
		_shop_bg = res as Texture2D
		if _shop_bg.get_width() != RECOMMENDED_BG_SIZE.x or _shop_bg.get_height() != RECOMMENDED_BG_SIZE.y:
			push_warning(
				"UiTextureCache: %s 为 %dx%d，建议导出为 %dx%d 与视口一致"
				% [
					SHOP_BG_PATH,
					_shop_bg.get_width(),
					_shop_bg.get_height(),
					RECOMMENDED_BG_SIZE.x,
					RECOMMENDED_BG_SIZE.y,
				]
			)
	return _shop_bg


static func get_shopgirl() -> Texture2D:
	if _shopgirl != null:
		return _shopgirl
	if not ResourceLoader.exists(SHOPGIRL_PATH):
		return null
	var res: Resource = ResourceLoader.load(SHOPGIRL_PATH)
	if res is Texture2D:
		_shopgirl = res as Texture2D
	return _shopgirl


## 全屏商店背景 + 暗色遮罩（与 ShopUI 一致，子节点按添加顺序叠放）；返回遮罩节点便于挂交互
static func add_shop_background_layers(
	parent: Control,
	dim_alpha: float = SHOP_BG_DIM_ALPHA,
	dim_mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_IGNORE,
) -> ColorRect:
	var tex: Texture2D = get_shop_bg()
	if tex:
		var bg := TextureRect.new()
		bg.name = "ShopBg"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bg)
	var dim := ColorRect.new()
	dim.name = "ShopBgDim"
	dim.color = Color(0.03, 0.05, 0.09, dim_alpha if tex else 0.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = dim_mouse_filter
	parent.add_child(dim)
	return dim
