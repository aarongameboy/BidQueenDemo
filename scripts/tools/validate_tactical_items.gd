extends SceneTree
## 战术道具配置校验（运行时 load，避免 headless 下 const preload 编译失败）

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var errors: int = 0
	var catalog_script: Script = load("res://scripts/data/tactical_item_catalog.gd") as Script
	var shop_script: Script = load("res://scripts/data/shop_catalog.gd") as Script
	var effects_script: Script = load("res://scripts/match/tactical_item_effects.gd") as Script
	if catalog_script == null or shop_script == null or effects_script == null:
		push_error("failed to load tactical scripts")
		quit(1)
		return
	var catalog: RefCounted = catalog_script.new()
	if not catalog.load_all():
		push_error("tactical_items.json load failed")
		quit(1)
		return
	var items: Array = catalog.get_all_items()
	if items.is_empty():
		push_error("tactical items list is empty")
		errors += 1
	var ids: Dictionary = {}
	for row in items:
		var item_id: String = str(row.get("id", ""))
		if item_id.is_empty():
			push_error("tactical item missing id")
			errors += 1
			continue
		if ids.has(item_id):
			push_error("duplicate tactical id: " + item_id)
			errors += 1
		ids[item_id] = true
		if str(row.get("effect", {}).get("type", "")).is_empty():
			push_error("tactical item missing effect type: " + item_id)
			errors += 1
	var shop: RefCounted = shop_script.new()
	if not shop.load_all():
		push_error("shop_config.json load failed")
		quit(1)
		return
	var shop_tactical: int = 0
	for product in shop.get_products_for_category("tactical"):
		shop_tactical += 1
		var effect: Dictionary = product.get("effect", {})
		if str(effect.get("type", "")) != "tactical_item":
			push_error("shop tactical product wrong effect: " + str(product.get("product_id", "")))
			errors += 1
			continue
		var tactical_id: String = str(effect.get("tactical_id", ""))
		if not ids.has(tactical_id):
			push_error("shop references unknown tactical id: " + tactical_id)
			errors += 1
	if shop_tactical != items.size():
		push_error("shop tactical count %d != config count %d" % [shop_tactical, items.size()])
		errors += 1
	if errors > 0:
		push_error("validate_tactical_items failed with %d error(s)" % errors)
		quit(1)
		return
	print("validate_tactical_items OK (items=%d shop=%d)" % [items.size(), shop_tactical])
	quit(0)
