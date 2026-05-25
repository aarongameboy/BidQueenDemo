extends SceneTree

const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")

func _initialize() -> void:
	var cat = ItemCatalogScript.new()
	if not cat.load_all():
		push_error("catalog load failed")
		quit(1)
		return
	var pools: Dictionary = {}
	var errors: int = 0
	for pool in cat.get_pools():
		var tag: String = pool["pool_tag"]
		var items: Array = cat.get_items_in_pool(tag)
		if items.is_empty():
			print("WARN empty pool: ", tag)
		var wsum: int = 0
		for it in items:
			wsum += int(it["weight"])
		pools[tag] = {"count": items.size(), "weight_sum": wsum}
		if wsum <= 0:
			push_error("pool weight sum 0: " + tag)
			errors += 1
	var sample: Dictionary = cat.get_item("itm_00001")
	print("items_master sample ok=", not sample.is_empty(), " name=", sample.get("item_name", ""))
	print("pools: ", pools)
	if errors > 0:
		push_error("validation failed")
		quit(1)
	print("validate_item_tables OK")
	quit(0)
