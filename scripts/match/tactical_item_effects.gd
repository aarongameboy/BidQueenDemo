class_name TacticalItemEffects
extends RefCounted

const TacticalCatalogScript = preload("res://scripts/data/tactical_item_catalog.gd")


static func build_effect(
	item_def: Dictionary,
	warehouse,
	rng: RandomNumberGenerator,
	round_index: int,
) -> Dictionary:
	if item_def.is_empty() or warehouse == null:
		return _empty(round_index)
	var effect_cfg: Dictionary = item_def.get("effect", {})
	match str(effect_cfg.get("type", "")):
		"random_reveal":
			return _effect_random_reveal(item_def, warehouse, rng, round_index, int(effect_cfg.get("count", 1)))
		"scan":
			return _effect_scan(item_def, warehouse, round_index, str(effect_cfg.get("quality", "white")))
		"stock":
			return _effect_stock(item_def, warehouse, round_index, str(effect_cfg.get("quality", "white")))
		"valuation":
			return _effect_valuation(item_def, warehouse, round_index, str(effect_cfg.get("quality", "white")))
		"random_quality_id":
			return _effect_random_quality_id(item_def, warehouse, rng, round_index, int(effect_cfg.get("count", 2)))
		"avg_cells":
			return _effect_avg_cells(item_def, warehouse, round_index, str(effect_cfg.get("quality", "white")))
		"omniscient":
			return _effect_omniscient(item_def, warehouse, round_index)
		_:
			return _empty(round_index)


static func _empty(round_index: int) -> Dictionary:
	return {
		"title": "战术道具",
		"body": "道具效果未能生效。",
		"icon_kind": "tactical",
		"round_index": round_index,
	}


static func _base_meta(item_def: Dictionary, round_index: int, body: String, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {
		"title": str(item_def.get("name", "战术道具")),
		"body": body,
		"icon_kind": "tactical",
		"tactical_id": str(item_def.get("id", "")),
		"round_index": round_index,
		"sort_order": 900,
	}
	for key in extra.keys():
		out[key] = extra[key]
	return out


static func _pick_unrevealed_full(warehouse, rng: RandomNumberGenerator, count: int) -> Array[int]:
	var pool: Array[int] = []
	for i in warehouse.items.size():
		if not warehouse.is_player_revealed(i):
			pool.append(i)
	return _pick_from_pool(pool, rng, count)


static func _pick_unrevealed_quality_id(warehouse, rng: RandomNumberGenerator, count: int) -> Array[int]:
	var pool: Array[int] = []
	for i in warehouse.items.size():
		if warehouse.is_player_revealed(i):
			continue
		if warehouse.is_quality_size_revealed(i):
			continue
		pool.append(i)
	return _pick_from_pool(pool, rng, count)


static func _pick_from_pool(pool: Array[int], rng: RandomNumberGenerator, count: int) -> Array[int]:
	var picked: Array[int] = []
	var work: Array[int] = pool.duplicate()
	for _n in count:
		if work.is_empty():
			break
		var at: int = rng.randi_range(0, work.size() - 1)
		picked.append(work[at])
		work.remove_at(at)
	return picked


static func _effect_random_reveal(item_def: Dictionary, warehouse, rng: RandomNumberGenerator, round_index: int, count: int) -> Dictionary:
	var indices: Array[int] = _pick_unrevealed_full(warehouse, rng, count)
	var body: String = "随机显示 %d 件藏品全部信息。" % count
	if indices.is_empty():
		body = "没有可随机显示的未揭示藏品。"
	return _base_meta(item_def, round_index, body, {"revealed_indices": indices})


static func _effect_scan(item_def: Dictionary, warehouse, round_index: int, quality_key: String) -> Dictionary:
	var q_enum: int = TacticalCatalogScript.quality_to_enum(quality_key)
	var q_label: String = TacticalCatalogScript.quality_label(quality_key)
	var cells: int = warehouse.get_quality_cell_total(q_enum)
	var body: String = "所有%s品质藏品总格数：%d" % [q_label, cells]
	return _base_meta(item_def, round_index, body)


static func _effect_stock(item_def: Dictionary, warehouse, round_index: int, quality_key: String) -> Dictionary:
	var q_enum: int = TacticalCatalogScript.quality_to_enum(quality_key)
	var q_label: String = TacticalCatalogScript.quality_label(quality_key)
	var count: int = warehouse.get_quality_item_count(q_enum)
	var body: String = "所有%s品质藏品总数量：%d" % [q_label, count]
	return _base_meta(item_def, round_index, body)


static func _effect_valuation(item_def: Dictionary, warehouse, round_index: int, quality_key: String) -> Dictionary:
	var q_enum: int = TacticalCatalogScript.quality_to_enum(quality_key)
	var q_label: String = TacticalCatalogScript.quality_label(quality_key)
	var summary: Dictionary = warehouse.get_quality_value_summary(q_enum)
	var total: int = int(summary.get("total", 0))
	var body: String = "所有%s品质藏品总价值：%s" % [
		q_label,
		_format_silver(total),
	]
	return _base_meta(item_def, round_index, body)


static func _effect_random_quality_id(item_def: Dictionary, warehouse, rng: RandomNumberGenerator, round_index: int, count: int) -> Dictionary:
	var indices: Array[int] = _pick_unrevealed_quality_id(warehouse, rng, count)
	var body: String = "随机鉴定 %d 件藏品的品质与占格。" % count
	if indices.is_empty():
		body = "没有可鉴定的未知藏品。"
	return _base_meta(item_def, round_index, body, {"quality_size_indices": indices})


static func _effect_avg_cells(item_def: Dictionary, warehouse, round_index: int, quality_key: String) -> Dictionary:
	var q_enum: int = TacticalCatalogScript.quality_to_enum(quality_key)
	var q_label: String = TacticalCatalogScript.quality_label(quality_key)
	var avg: float = warehouse.get_quality_avg_cells(q_enum)
	var body: String = "所有%s品质藏品平均格数：%.1f" % [q_label, avg]
	return _base_meta(item_def, round_index, body)


static func _format_silver(amount: int) -> String:
	if abs(amount) >= 1_000_000:
		return "%.2fM" % (float(amount) / 1_000_000.0)
	if abs(amount) >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)


static func _effect_omniscient(item_def: Dictionary, warehouse, round_index: int) -> Dictionary:
	var indices: Array[int] = []
	for i in warehouse.items.size():
		indices.append(i)
	return _base_meta(
		item_def,
		round_index,
		"全知全能：已显示所有藏品的全部信息。",
		{"revealed_indices": indices},
	)
