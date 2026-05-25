class_name WarehouseSpawn
extends RefCounted
## 仓库道具数量加权抽取（件数越多权重越低）

const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")


static func pick_item_count(cfg: Dictionary, rng: RandomNumberGenerator) -> int:
	var min_c: int = int(cfg.get("warehouse_item_min", 10))
	var max_c: int = int(cfg.get("warehouse_item_max", 20))
	min_c = clampi(min_c, 1, 64)
	max_c = clampi(max_c, min_c, 64)
	var weights_cfg: Variant = cfg.get("warehouse_item_count_weights", {})
	var entries: Array[Dictionary] = []
	if typeof(weights_cfg) == TYPE_DICTIONARY:
		for k in weights_cfg.keys():
			var n: int = int(k)
			if n < min_c or n > max_c:
				continue
			entries.append({"count": n, "weight": int(weights_cfg[k])})
	if entries.is_empty():
		entries = _default_count_weights(min_c, max_c)
	var picked: Variant = ItemCatalogScript.weighted_pick(entries, "weight", rng)
	if picked == null:
		return rng.randi_range(min_c, max_c)
	return int(picked.get("count", min_c))


static func _default_count_weights(min_c: int, max_c: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for n in range(min_c, max_c + 1):
		var span: int = maxi(max_c - min_c, 1)
		var w: int = maxi(1, (max_c - n + 1) * 4)
		entries.append({"count": n, "weight": w})
	return entries
