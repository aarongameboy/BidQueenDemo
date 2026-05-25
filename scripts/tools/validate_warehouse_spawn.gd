extends SceneTree

const MatchConfigLoaderScript = preload("res://scripts/match/match_config_loader.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")
const WarehouseScript = preload("res://scripts/match/warehouse.gd")


func _initialize() -> void:
	var catalog = ItemCatalogScript.new()
	if not catalog.load_all():
		push_error("catalog load failed")
		quit(1)
		return
	var cfg: Dictionary = MatchConfigLoaderScript.load_config()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var wh = WarehouseScript.new()
	wh.generate_from_catalog(42, rng, catalog, cfg)
	var min_c: int = int(cfg.get("warehouse_item_min", 10))
	if wh.items.size() < mini(min_c, 8):
		push_error("warehouse too few items: %d" % wh.items.size())
		quit(1)
		return
	if not wh.verify_compact_layout():
		push_error("warehouse layout not compact")
		quit(1)
		return
	print("warehouse_spawn OK items=%d value=%d" % [wh.items.size(), wh.true_total_value])
	quit(0)
