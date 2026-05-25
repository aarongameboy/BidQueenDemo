class_name Warehouse
extends RefCounted
## Warehouse filled from item catalog.

const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")
const WarehouseSpawnScript = preload("res://scripts/match/warehouse_spawn.gd")

class WarehouseItem:
	var item_id: String = ""
	var item_name: String = ""
	var quality: int = GameConstants.Quality.WHITE
	var quality_color: String = "#FFFFFF"
	var value: int = 0
	var size_w: int = 1
	var size_h: int = 1
	var icon_path: String = ""
	var grid_x: int = 0
	var grid_y: int = 0


var seed: int = 0
var grid_w: int = 10
var grid_h: int = 20
var items: Array = []
var true_total_value: int = 0
var revealed_count: int = 0
var _occupancy: Array = []
## 玩家已在战利品格中看到的道具（情报翻开 / 结算开箱，含名称价值）
var _player_revealed: Array[bool] = []
## 仅揭示品质与占格（主角情报技能）
var _quality_size_revealed: Array[bool] = []
## 仅揭示占格轮廓（情报「显示轮廓」）
var _outline_revealed: Array[bool] = []


func generate_from_catalog(
	p_seed: int,
	rng: RandomNumberGenerator,
	catalog,
	cfg: Dictionary,
) -> void:
	seed = p_seed
	grid_w = int(cfg.get("warehouse_grid_w", 10))
	grid_h = int(cfg.get("warehouse_grid_h", 20))
	items.clear()
	true_total_value = 0
	revealed_count = 0
	_init_grid()
	var target_count: int = WarehouseSpawnScript.pick_item_count(cfg, rng)
	var retries_per_item: int = int(cfg.get("max_place_retries", 24))
	var catalog_items: Array = catalog.get_all_items()
	if catalog_items.is_empty():
		push_warning("Warehouse: item catalog empty")
		return
	var placed: int = 0
	var attempts: int = 0
	var max_attempts: int = target_count * retries_per_item
	while placed < target_count and attempts < max_attempts:
		attempts += 1
		var weight_key: String = str(cfg.get("item_weight_key", "weight"))
		var picked: Dictionary = ItemCatalogScript.weighted_pick(catalog_items, weight_key, rng)
		if picked.is_empty() and weight_key != "weight":
			picked = ItemCatalogScript.weighted_pick(catalog_items, "weight", rng)
		if picked.is_empty():
			break
		var sw: int = int(picked["size_w"])
		var sh: int = int(picked["size_h"])
		if sw > grid_w or sh > grid_h:
			continue
		var pos: Vector2i = _find_free_spot(sw, sh, rng)
		if pos.x < 0:
			continue
		var wh_item := WarehouseItem.new()
		wh_item.item_id = picked["item_id"]
		wh_item.item_name = picked["item_name"]
		wh_item.quality = picked["quality_enum"]
		wh_item.quality_color = picked["quality_color"]
		wh_item.value = int(picked["base_price"])
		wh_item.size_w = sw
		wh_item.size_h = sh
		wh_item.icon_path = picked["icon_path"]
		wh_item.grid_x = pos.x
		wh_item.grid_y = pos.y
		_occupy(pos.x, pos.y, sw, sh)
		items.append(wh_item)
		true_total_value += wh_item.value
		placed += 1
	if placed < int(cfg.get("warehouse_item_min", 10)):
		push_warning("Warehouse: only placed %d / %d items" % [placed, target_count])
	_compact_layout_top_left()
	_reset_player_revealed()


func _init_grid() -> void:
	_occupancy.clear()
	for y in grid_h:
		var row: Array = []
		row.resize(grid_w)
		for x in grid_w:
			row[x] = false
		_occupancy.append(row)


func _find_free_spot(sw: int, sh: int, rng: RandomNumberGenerator) -> Vector2i:
	if sw > grid_w or sh > grid_h:
		return Vector2i(-1, -1)
	var tries: int = 80
	for _i in tries:
		var x: int = rng.randi_range(0, grid_w - sw)
		var y: int = rng.randi_range(0, grid_h - sh)
		if _can_place(x, y, sw, sh):
			return Vector2i(x, y)
	return Vector2i(-1, -1)


func _can_place(x: int, y: int, sw: int, sh: int) -> bool:
	if x < 0 or y < 0 or x + sw > grid_w or y + sh > grid_h:
		return false
	for dy in sh:
		for dx in sw:
			if _occupancy[y + dy][x + dx]:
				return false
	return true


func _occupy(x: int, y: int, sw: int, sh: int) -> void:
	for dy in sh:
		for dx in sw:
			_occupancy[y + dy][x + dx] = true


## 将道具按左上→右下紧凑排列，消除随机放置产生的大块空隙
func _compact_layout_top_left() -> void:
	if items.is_empty():
		return
	var order: Array = items.duplicate()
	order.sort_custom(func(a, b) -> bool:
		var area_a: int = a.size_w * a.size_h
		var area_b: int = b.size_w * b.size_h
		if area_a != area_b:
			return area_a > area_b
		if a.size_h != b.size_h:
			return a.size_h > b.size_h
		return a.size_w > b.size_w
	)
	_init_grid()
	for item in order:
		var pos: Vector2i = _find_first_fit_spot(item.size_w, item.size_h)
		if pos.x < 0:
			push_warning("Warehouse: compact layout failed for %s" % item.item_id)
			continue
		item.grid_x = pos.x
		item.grid_y = pos.y
		_occupy(pos.x, pos.y, item.size_w, item.size_h)


func verify_compact_layout() -> bool:
	if items.is_empty():
		return true
	var min_x: int = grid_w
	var min_y: int = grid_h
	var max_x: int = 0
	var max_y: int = 0
	var occ: Array = []
	for y in grid_h:
		var row: Array = []
		row.resize(grid_w)
		for x in grid_w:
			row[x] = false
		occ.append(row)
	for item in items:
		if item.grid_x < 0 or item.grid_y < 0:
			return false
		min_x = mini(min_x, item.grid_x)
		min_y = mini(min_y, item.grid_y)
		max_x = maxi(max_x, item.grid_x + item.size_w - 1)
		max_y = maxi(max_y, item.grid_y + item.size_h - 1)
		for dy in item.size_h:
			for dx in item.size_w:
				occ[item.grid_y + dy][item.grid_x + dx] = true
	if min_x != 0 or min_y != 0:
		return false
	for y in range(max_y + 1):
		for x in range(max_x + 1):
			if occ[y][x]:
				continue
			if x > 0 and occ[y][x - 1]:
				return false
			if y > 0 and occ[y - 1][x]:
				return false
	return true


func _find_first_fit_spot(sw: int, sh: int) -> Vector2i:
	if sw > grid_w or sh > grid_h:
		return Vector2i(-1, -1)
	for y in grid_h - sh + 1:
		for x in grid_w - sw + 1:
			if _can_place(x, y, sw, sh):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func remove_items_at_indices(indices: Array) -> int:
	var remove_set: Dictionary = {}
	for idx_v in indices:
		var idx: int = int(idx_v)
		if idx >= 0 and idx < items.size():
			remove_set[idx] = true
	if remove_set.is_empty():
		return 0
	var removed_value: int = 0
	var kept_items: Array = []
	var kept_player: Array[bool] = []
	var kept_quality: Array[bool] = []
	var kept_outline: Array[bool] = []
	for i in items.size():
		if remove_set.has(i):
			removed_value += int(items[i].value)
			continue
		kept_items.append(items[i])
		if i < _player_revealed.size():
			kept_player.append(_player_revealed[i])
		if i < _quality_size_revealed.size():
			kept_quality.append(_quality_size_revealed[i])
		if i < _outline_revealed.size():
			kept_outline.append(_outline_revealed[i])
	items = kept_items
	_player_revealed = kept_player
	_quality_size_revealed = kept_quality
	_outline_revealed = kept_outline
	_init_grid()
	for item in items:
		_occupy(item.grid_x, item.grid_y, item.size_w, item.size_h)
	true_total_value = 0
	for item in items:
		true_total_value += int(item.value)
	revealed_count = mini(revealed_count, items.size())
	return removed_value


func _reset_player_revealed() -> void:
	_player_revealed.clear()
	_quality_size_revealed.clear()
	_outline_revealed.clear()
	for _i in items.size():
		_player_revealed.append(false)
		_quality_size_revealed.append(false)
		_outline_revealed.append(false)


func mark_player_revealed(index: int) -> void:
	if index < 0 or index >= _player_revealed.size():
		return
	_player_revealed[index] = true


func mark_quality_size_revealed(index: int) -> void:
	if index < 0 or index >= _quality_size_revealed.size():
		return
	_quality_size_revealed[index] = true


func is_quality_size_revealed(index: int) -> bool:
	return index >= 0 and index < _quality_size_revealed.size() and _quality_size_revealed[index]


func is_player_revealed(index: int) -> bool:
	return index >= 0 and index < _player_revealed.size() and _player_revealed[index]


func mark_outline_revealed(index: int) -> void:
	if index < 0 or index >= _outline_revealed.size():
		return
	_outline_revealed[index] = true


func is_outline_revealed(index: int) -> bool:
	return index >= 0 and index < _outline_revealed.size() and _outline_revealed[index]


func count_quality_size_revealed() -> int:
	var n: int = 0
	for r in _quality_size_revealed:
		if r:
			n += 1
	return n


func get_player_visible_value_total(catalog = null) -> int:
	var total: int = 0
	for i in items.size():
		var item = items[i]
		if is_player_revealed(i):
			total += item.value
		elif is_quality_size_revealed(i):
			total += _min_value_for_known_quality_size(item, catalog)
		elif is_outline_revealed(i):
			total += _min_value_for_outline_only(item, catalog)
	return total


func _min_value_for_known_quality_size(item, catalog) -> int:
	var cells: int = maxi(item.size_w * item.size_h, 1)
	if catalog != null and catalog.is_loaded():
		var from_catalog: int = catalog.get_min_base_price_for_known_item(
			item.quality, item.size_w, item.size_h,
		)
		if from_catalog > 0:
			return from_catalog
	var slot_val: int = int(GameConstants.QUALITY_SLOT_VALUE.get(item.quality, 500))
	return slot_val * cells


func _min_value_for_outline_only(item, catalog) -> int:
	var cells: int = maxi(item.size_w * item.size_h, 1)
	if catalog != null and catalog.is_loaded():
		var from_catalog: int = catalog.get_min_base_price_for_size(item.size_w, item.size_h)
		if from_catalog > 0:
			return from_catalog
	var best: int = 0x7FFFFFFF
	for q in range(GameConstants.QUALITY_COUNT):
		var slot_val: int = int(GameConstants.QUALITY_SLOT_VALUE.get(q, 500))
		best = mini(best, slot_val * cells)
	return best if best < 0x7FFFFFFF else 500 * cells


func get_reveal_order() -> Array[int]:
	var order: Array[int] = []
	for i in items.size():
		order.append(i)
	return order


func reveal_next():
	if revealed_count >= items.size():
		return null
	var item = items[revealed_count]
	revealed_count += 1
	return item


func pick_random_indices(count: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool: Array[int] = []
	for i in items.size():
		pool.append(i)
	var picked: Array[int] = []
	for _n in count:
		if pool.is_empty():
			break
		var at: int = rng.randi_range(0, pool.size() - 1)
		picked.append(pool[at])
		pool.remove_at(at)
	return picked


func get_reveal_order_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in items.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var ia = items[a]
		var ib = items[b]
		if ia.grid_y != ib.grid_y:
			return ia.grid_y < ib.grid_y
		return ia.grid_x < ib.grid_x
	)
	return indices


func get_gold_cell_summary() -> Dictionary:
	var cells: int = 0
	var count: int = 0
	for s in items:
		if s.quality == GameConstants.Quality.GOLD:
			count += 1
			cells += s.size_w * s.size_h
	if count <= 0:
		return {"count": 0, "avg_cells": 0.0, "total_cells": 0}
	return {
		"count": count,
		"total_cells": cells,
		"avg_cells": float(cells) / float(count),
	}


func get_gold_value_summary() -> Dictionary:
	return get_quality_value_summary(GameConstants.Quality.GOLD)


func get_quality_cell_total(quality: int) -> int:
	var cells: int = 0
	for s in items:
		if s.quality == quality:
			cells += s.size_w * s.size_h
	return cells


func get_quality_item_count(quality: int) -> int:
	var count: int = 0
	for s in items:
		if s.quality == quality:
			count += 1
	return count


func get_indices_of_quality(quality: int) -> Array[int]:
	var out: Array[int] = []
	for i in items.size():
		if items[i].quality == quality:
			out.append(i)
	return out


func get_avg_cells_per_item() -> float:
	if items.is_empty():
		return 0.0
	var cells: int = 0
	for s in items:
		cells += s.size_w * s.size_h
	return float(cells) / float(items.size())


func get_quality_avg_cells(quality: int) -> float:
	var count: int = 0
	var cells: int = 0
	for s in items:
		if s.quality == quality:
			count += 1
			cells += s.size_w * s.size_h
	if count <= 0:
		return 0.0
	return float(cells) / float(count)


func get_highest_value_index() -> int:
	if items.is_empty():
		return -1
	var best_i: int = 0
	var best_v: int = items[0].value
	for i in range(1, items.size()):
		if items[i].value > best_v:
			best_v = items[i].value
			best_i = i
	return best_i


func get_quality_value_summary(quality: int) -> Dictionary:
	var values: Array[int] = []
	for s in items:
		if s.quality == quality:
			values.append(s.value)
	if values.is_empty():
		return {"count": 0, "avg": 0, "total": 0}
	var total: int = 0
	for v in values:
		total += v
	return {"count": values.size(), "avg": total / values.size(), "total": total}


func get_intel_summary(for_player_archetype: int, round_index: int) -> Dictionary:
	const CharacterDataScript = preload("res://scripts/data/character_data.gd")
	var counts: Dictionary = _quality_counts()
	var out: Dictionary = {
		"item_count": items.size(),
		"known_total_low": int(true_total_value * 0.55),
		"known_total_high": int(true_total_value * 1.45),
	}
	match for_player_archetype:
		CharacterDataScript.SkillArchetype.VALUATION:
			if round_index >= 2:
				out["purple_count"] = counts[GameConstants.Quality.PURPLE]
				out["gold_count"] = counts[GameConstants.Quality.GOLD]
			if round_index >= 3:
				out["known_total_low"] = int(true_total_value * 0.75)
				out["known_total_high"] = int(true_total_value * 1.25)
		CharacterDataScript.SkillArchetype.INTEL:
			if round_index >= 2:
				out["red_or_gold_hint"] = counts[GameConstants.Quality.RED] + counts[GameConstants.Quality.GOLD] > 0
		_:
			pass
	return out


func get_intel_for_character(skill_id: String, round_index: int) -> Dictionary:
	const CharacterDataScript = preload("res://scripts/data/character_data.gd")
	var counts: Dictionary = _quality_counts()
	var out: Dictionary = {
		"item_count": items.size(),
		"known_total_low": int(true_total_value * 0.55),
		"known_total_high": int(true_total_value * 1.45),
		"skill_id": skill_id,
	}
	match skill_id:
		"night_raven_peek":
			out["purple_count"] = counts[GameConstants.Quality.PURPLE]
			out["gold_count"] = counts[GameConstants.Quality.GOLD]
			out["red_count"] = counts[GameConstants.Quality.RED]
			out["known_total_low"] = int(true_total_value * 0.62)
			out["known_total_high"] = int(true_total_value * 1.28)
		"star_chart_valuation":
			out["known_total_low"] = int(true_total_value * 0.78)
			out["known_total_high"] = int(true_total_value * 1.22)
			if round_index >= 2:
				out["purple_count"] = counts[GameConstants.Quality.PURPLE]
		"holy_bell_shake":
			if round_index >= 1:
				out["purple_count"] = counts[GameConstants.Quality.PURPLE]
			if round_index >= 2:
				out["gold_count"] = counts[GameConstants.Quality.GOLD]
				out["red_or_gold_hint"] = counts[GameConstants.Quality.RED] + counts[GameConstants.Quality.GOLD] > 0
			if round_index >= 3:
				out["known_total_low"] = int(true_total_value * 0.72)
				out["known_total_high"] = int(true_total_value * 1.2)
		"court_announce":
			if round_index >= 2:
				out["red_or_gold_hint"] = counts[GameConstants.Quality.RED] + counts[GameConstants.Quality.GOLD] > 0
			if round_index >= 3:
				out["purple_count"] = counts[GameConstants.Quality.PURPLE]
				out["gold_count"] = counts[GameConstants.Quality.GOLD]
		"black_rose_pressure":
			out["known_total_low"] = int(true_total_value * 0.68)
			out["known_total_high"] = int(true_total_value * 1.38)
		_:
			return get_intel_summary(CharacterDataScript.SkillArchetype.VALUATION, round_index)
	return out


func _quality_counts() -> Dictionary:
	var counts: Dictionary = {}
	for q in range(GameConstants.QUALITY_COUNT):
		counts[q] = 0
	for s in items:
		counts[s.quality] = counts.get(s.quality, 0) + 1
	return counts
