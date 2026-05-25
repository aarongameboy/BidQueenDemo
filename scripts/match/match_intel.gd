class_name MatchIntel
extends RefCounted
## 每轮随机情报（可扩展类型池）

enum IntelType {
	QUALITY_AVG_CELLS,
	WAREHOUSE_AVG_CELLS,
	RANDOM_SAMPLE_AVG,
	RANDOM_FULL_INFO,
	QUALITY_ALL_SIZE,
	HIGHEST_VALUE_FULL,
	WAREHOUSE_QUALITY_ROSTER,
	WAREHOUSE_META,
	ALL_OUTLINES,
	HIGHEST_QUALITY_ONE,
	QUALITY_TOTAL_CELLS,
}

const RANDOM_FULL_MIN: int = 1
const RANDOM_FULL_MAX: int = 3
const SAMPLE_COUNT_MIN: int = 2
const SAMPLE_COUNT_MAX: int = 10

const TYPE_WEIGHTS: Dictionary = {
	IntelType.QUALITY_AVG_CELLS: 12,
	IntelType.WAREHOUSE_AVG_CELLS: 10,
	IntelType.RANDOM_SAMPLE_AVG: 12,
	IntelType.RANDOM_FULL_INFO: 10,
	IntelType.QUALITY_ALL_SIZE: 11,
	IntelType.HIGHEST_VALUE_FULL: 3,
	IntelType.WAREHOUSE_QUALITY_ROSTER: 11,
	IntelType.WAREHOUSE_META: 9,
	IntelType.ALL_OUTLINES: 8,
	IntelType.HIGHEST_QUALITY_ONE: 7,
	IntelType.QUALITY_TOTAL_CELLS: 10,
}


static func get_registered_types() -> Array[int]:
	var out: Array[int] = []
	for k in TYPE_WEIGHTS.keys():
		out.append(int(k))
	return out


const DEDUP_MAX_ATTEMPTS: int = 16


static func roll_random_intel(
	warehouse,
	rng: RandomNumberGenerator,
	round_index: int,
	recent_signatures: Array[String] = [],
) -> Dictionary:
	if warehouse == null or warehouse.items.is_empty():
		return _empty_intel(round_index)
	var banned_types: Array[int] = []
	for attempt in DEDUP_MAX_ATTEMPTS:
		var picked: int = _pick_weighted_type(rng, banned_types)
		var intel: Dictionary = _build_intel(picked, warehouse, rng, round_index)
		if not _is_duplicate_intel(intel, recent_signatures):
			return intel
		if not banned_types.has(picked):
			banned_types.append(picked)
	return _roll_intel_fallback(warehouse, rng, round_index, recent_signatures)


static func intel_signature(intel: Dictionary) -> String:
	var body: String = format_effect_line(intel).strip_edges()
	if not body.is_empty():
		return body
	return "type:%d" % int(intel.get("type", -1))


static func _is_duplicate_intel(intel: Dictionary, recent_signatures: Array[String]) -> bool:
	if recent_signatures.is_empty():
		return false
	var sig: String = intel_signature(intel)
	if sig.is_empty():
		return false
	return recent_signatures.has(sig)


static func format_cinematic_headline(intel: Dictionary) -> String:
	return format_effect_line(intel)


static func format_cinematic_detail(intel: Dictionary) -> String:
	var extra: String = str(intel.get("detail", "")).strip_edges()
	if not extra.is_empty():
		return extra
	return ""


static func format_effect_line(effect: Dictionary) -> String:
	var body: String = _strip_warehouse_prefix(str(effect.get("body", "")).strip_edges())
	if not body.is_empty():
		return body
	return _strip_warehouse_prefix(str(effect.get("title", "")).strip_edges())


static func build_teaser_effect(intel: Dictionary) -> Dictionary:
	return {
		"title": "即将揭示情报",
		"body": str(intel.get("teaser_body", "即将公布一条仓库情报…")),
		"icon_kind": "warehouse",
		"is_teaser": true,
		"sort_order": -100,
		"round_index": int(intel.get("round_index", 0)),
	}


static func clone_as_round_intel(source: Dictionary, round_index: int) -> Dictionary:
	if source.is_empty():
		return _empty_intel(round_index)
	var intel: Dictionary = source.duplicate(true)
	intel["round_index"] = round_index
	return intel


static func build_warehouse_meta_intel(warehouse, round_index: int) -> Dictionary:
	return _intel_warehouse_meta(warehouse, round_index)


static func _pick_weighted_type(rng: RandomNumberGenerator, exclude_types: Array[int] = []) -> int:
	var entries: Array[Dictionary] = []
	for t in TYPE_WEIGHTS.keys():
		var type_id: int = int(t)
		if type_id in exclude_types:
			continue
		entries.append({"type": type_id, "weight": int(TYPE_WEIGHTS[t])})
	if entries.is_empty():
		return _pick_weighted_type(rng, [])
	var picked: Variant = _weighted_pick(entries, "weight", rng)
	if picked == null:
		return IntelType.RANDOM_SAMPLE_AVG
	return int(picked.get("type", IntelType.RANDOM_SAMPLE_AVG))


static func _roll_intel_fallback(
	warehouse,
	rng: RandomNumberGenerator,
	round_index: int,
	recent_signatures: Array[String],
) -> Dictionary:
	for t in TYPE_WEIGHTS.keys():
		var intel: Dictionary = _build_intel(int(t), warehouse, rng, round_index)
		if not _is_duplicate_intel(intel, recent_signatures):
			return intel
	# 仍冲突时优先随机全显（文案随道具变化），避免连续两条完全相同
	for _try in 4:
		var intel: Dictionary = _intel_random_full_info(warehouse, rng, round_index)
		if not _is_duplicate_intel(intel, recent_signatures):
			return intel
	var last: Dictionary = _build_intel(
		IntelType.RANDOM_SAMPLE_AVG, warehouse, rng, round_index,
	)
	if _is_duplicate_intel(last, recent_signatures):
		last["body"] = str(last.get("body", "")) + "（补充探测）"
		last["teaser_body"] = last["body"]
	return last


static func _weighted_pick(entries: Array, weight_key: String, rng: RandomNumberGenerator) -> Variant:
	if entries.is_empty():
		return null
	const SCALE: float = 10000.0
	var total: int = 0
	for e in entries:
		total += int(float(e.get(weight_key, 0.0)) * SCALE)
	if total <= 0:
		return entries[rng.randi_range(0, entries.size() - 1)]
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for e in entries:
		acc += int(float(e.get(weight_key, 0.0)) * SCALE)
		if roll <= acc:
			return e
	return entries[entries.size() - 1]


static func _build_intel(type: int, warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	match type:
		IntelType.QUALITY_AVG_CELLS:
			return _intel_quality_avg_cells(warehouse, rng, round_index)
		IntelType.WAREHOUSE_AVG_CELLS:
			return _intel_warehouse_avg_cells(warehouse, round_index)
		IntelType.RANDOM_SAMPLE_AVG:
			return _intel_sample_avg(warehouse, rng, round_index)
		IntelType.RANDOM_FULL_INFO:
			return _intel_random_full_info(warehouse, rng, round_index)
		IntelType.QUALITY_ALL_SIZE:
			return _intel_quality_all_size(warehouse, rng, round_index)
		IntelType.HIGHEST_VALUE_FULL:
			return _intel_highest_value_full(warehouse, round_index)
		IntelType.WAREHOUSE_QUALITY_ROSTER:
			return _intel_warehouse_quality_roster(warehouse, round_index)
		IntelType.WAREHOUSE_META:
			return _intel_warehouse_meta(warehouse, round_index)
		IntelType.ALL_OUTLINES:
			return _intel_all_outlines(warehouse, round_index)
		IntelType.HIGHEST_QUALITY_ONE:
			return _intel_highest_quality_one(warehouse, rng, round_index)
		IntelType.QUALITY_TOTAL_CELLS:
			return _intel_quality_total_cells(warehouse, rng, round_index)
		_:
			return _empty_intel(round_index)


static func _empty_intel(round_index: int) -> Dictionary:
	return _make_intel(
		-1,
		round_index,
		"仓库情报不足。",
		{"teaser_body": "情报信号微弱，暂无有效探测。", "icon_kind": "hint"},
	)


static func _make_intel(type: int, round_index: int, body: String, extra: Dictionary = {}) -> Dictionary:
	var intel: Dictionary = {
		"type": type,
		"title": "",
		"body": body,
		"teaser_body": body,
		"icon_kind": "warehouse",
		"round_index": round_index,
	}
	for k in extra.keys():
		intel[k] = extra[k]
	return intel


static func _intel_quality_avg_cells(warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var q: int = _pick_random_quality_present(warehouse, rng)
	var avg_cells: float = warehouse.get_quality_avg_cells(q)
	var q_name: String = _quality_name(q)
	return _make_intel(
		IntelType.QUALITY_AVG_CELLS,
		round_index,
		"%s品质藏品平均占用的格子数量约为 %.1f 格。" % [q_name, avg_cells],
		{"quality": q, "avg_cells": avg_cells},
	)


static func _intel_warehouse_avg_cells(warehouse, round_index: int) -> Dictionary:
	var avg_cells: float = warehouse.get_avg_cells_per_item()
	return _make_intel(
		IntelType.WAREHOUSE_AVG_CELLS,
		round_index,
		"每件藏品平均占用的格子数量约为 %.1f 格。" % avg_cells,
		{"avg_cells": avg_cells},
	)


static func _intel_sample_avg(warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var n_items: int = warehouse.items.size()
	var pick_n: int = clampi(rng.randi_range(SAMPLE_COUNT_MIN, SAMPLE_COUNT_MAX), 1, n_items)
	var indices: Array[int] = warehouse.pick_random_indices(pick_n, rng)
	var total: int = 0
	for idx in indices:
		total += warehouse.items[idx].value
	var avg: int = total / pick_n if pick_n > 0 else 0
	return _make_intel(
		IntelType.RANDOM_SAMPLE_AVG,
		round_index,
		"随机选择的 %d 件藏品，平均价值约为 %s。" % [pick_n, _format_silver(avg)],
		{"sample_count": pick_n, "sample_avg": avg, "sample_indices": indices},
	)


static func _intel_random_full_info(warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var n_items: int = warehouse.items.size()
	var pick_n: int = clampi(rng.randi_range(RANDOM_FULL_MIN, RANDOM_FULL_MAX), 1, n_items)
	var indices: Array[int] = warehouse.pick_random_indices(pick_n, rng)
	var revealed_items: Array[Dictionary] = []
	for idx in indices:
		var it = warehouse.items[idx]
		revealed_items.append({
			"name": it.item_name,
			"quality_color": GameConstants.get_quality_text_color_hex(it.quality),
		})
	var names_bb: String = _join_colored_item_names(revealed_items)
	return _make_intel(
		IntelType.RANDOM_FULL_INFO,
		round_index,
		"随机显示 %d 件藏品的全部信息：%s。" % [pick_n, "、".join(_item_names_plain(indices, warehouse))],
		{
			"body_bbcode": "随机显示 %d 件藏品的全部信息：%s。" % [pick_n, names_bb],
			"revealed_indices": indices,
			"revealed_items": revealed_items,
		},
	)


static func _intel_quality_all_size(warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var q: int = _pick_random_quality_present(warehouse, rng)
	var indices: Array[int] = warehouse.get_indices_of_quality(q)
	var q_name: String = _quality_name(q)
	var cell_total: int = warehouse.get_quality_cell_total(q)
	return _make_intel(
		IntelType.QUALITY_ALL_SIZE,
		round_index,
		"展示全部 %s 品质藏品的格子信息（共 %d 件，合计 %d 格）。" % [
			q_name, indices.size(), cell_total,
		],
		{"quality": q, "quality_size_indices": indices},
	)


static func _intel_highest_value_full(warehouse, round_index: int) -> Dictionary:
	var idx: int = warehouse.get_highest_value_index()
	if idx < 0:
		return _empty_intel(round_index)
	var it = warehouse.items[idx]
	var revealed_items: Array[Dictionary] = [{
		"name": it.item_name,
		"quality_color": GameConstants.get_quality_text_color_hex(it.quality),
	}]
	return _make_intel(
		IntelType.HIGHEST_VALUE_FULL,
		round_index,
		"本场最高价值藏品：%s（%s，%s）。" % [
			it.item_name, _quality_name(it.quality), _format_silver(it.value),
		],
		{
			"body_bbcode": "本场最高价值藏品：%s（%s，%s）。" % [
				_join_colored_item_names(revealed_items),
				_quality_name(it.quality),
				_format_silver(it.value),
			],
			"revealed_indices": [idx],
			"revealed_items": revealed_items,
		},
	)


static func _intel_warehouse_quality_roster(warehouse, round_index: int) -> Dictionary:
	var parts: PackedStringArray = []
	for q in range(GameConstants.QUALITY_COUNT):
		var cnt: int = warehouse.get_quality_item_count(q)
		if cnt <= 0:
			continue
		parts.append("%s品质 %d 件" % [_quality_name(q), cnt])
	var roster: String = "、".join(parts) if not parts.is_empty() else "暂无"
	var color_n: int = parts.size()
	return _make_intel(
		IntelType.WAREHOUSE_QUALITY_ROSTER,
		round_index,
		"本场拍卖共有 %d 种品质藏品：%s。" % [color_n, roster],
	)


static func _intel_warehouse_meta(warehouse, round_index: int) -> Dictionary:
	return _make_intel(
		IntelType.WAREHOUSE_META,
		round_index,
		"本局仓库共 %d 件藏品（格位 %dx%d）。" % [
			warehouse.items.size(), warehouse.grid_w, warehouse.grid_h,
		],
	)


static func _intel_highest_quality_one(warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var max_q: int = -1
	for item in warehouse.items:
		max_q = maxi(max_q, item.quality)
	var pool: Array[int] = []
	for i in warehouse.items.size():
		if warehouse.items[i].quality == max_q:
			pool.append(i)
	var idx: int = pool[rng.randi_range(0, pool.size() - 1)]
	var wh_item = warehouse.items[idx]
	var q_name: String = _quality_name(max_q)
	var revealed_items: Array[Dictionary] = [{
		"name": wh_item.item_name,
		"quality_color": GameConstants.get_quality_text_color_hex(wh_item.quality),
	}]
	return _make_intel(
		IntelType.HIGHEST_QUALITY_ONE,
		round_index,
		"随机显示 1 件最高品质（%s）藏品：%s。" % [q_name, wh_item.item_name],
		{
			"body_bbcode": "随机显示 1 件最高品质（%s）藏品：%s。" % [
				q_name, _join_colored_item_names(revealed_items),
			],
			"revealed_indices": [idx],
			"revealed_items": revealed_items,
		},
	)


static func _intel_all_outlines(warehouse, round_index: int) -> Dictionary:
	var indices: Array[int] = []
	for i in warehouse.items.size():
		indices.append(i)
	return _make_intel(
		IntelType.ALL_OUTLINES,
		round_index,
		"显示所有道具的轮廓（共 %d 件）。" % indices.size(),
		{"outline_indices": indices},
	)


static func _intel_quality_total_cells(warehouse, rng: RandomNumberGenerator, round_index: int) -> Dictionary:
	var q: int = _pick_random_quality_present(warehouse, rng)
	var total_cells: int = warehouse.get_quality_cell_total(q)
	var q_name: String = _quality_name(q)
	return _make_intel(
		IntelType.QUALITY_TOTAL_CELLS,
		round_index,
		"%s品质总占用的格子数量为 %d 格。" % [q_name, total_cells],
		{"quality": q, "quality_cell_total": total_cells},
	)


static func _pick_random_quality_present(warehouse, rng: RandomNumberGenerator) -> int:
	var present: Array[int] = []
	var seen: Dictionary = {}
	for item in warehouse.items:
		if seen.has(item.quality):
			continue
		seen[item.quality] = true
		present.append(item.quality)
	if present.is_empty():
		return GameConstants.Quality.WHITE
	return present[rng.randi_range(0, present.size() - 1)]


static func _quality_name(quality: int) -> String:
	if quality >= 0 and quality < GameConstants.QUALITY_NAMES.size():
		return GameConstants.QUALITY_NAMES[quality]
	return "?"


static func _item_names_plain(indices: Array, warehouse) -> PackedStringArray:
	var parts: PackedStringArray = []
	for idx_v in indices:
		parts.append(warehouse.items[int(idx_v)].item_name)
	return parts


static func _join_colored_item_names(revealed_items: Array) -> String:
	var parts: PackedStringArray = []
	for it in revealed_items:
		var color_hex: String = str(it.get("quality_color", "#FFFFFF"))
		var name: String = str(it.get("name", ""))
		parts.append("[color=%s]%s[/color]" % [color_hex, name])
	return "、".join(parts)


static func _strip_warehouse_prefix(text: String) -> String:
	var t: String = text.strip_edges()
	for prefix in ["未知仓库：竞拍信息", "潮牌仓库：竞拍信息", "未知仓库：", "潮牌仓库："]:
		if t.begins_with(prefix):
			t = t.substr(prefix.length()).strip_edges()
	return t


static func _format_silver(amount: int) -> String:
	if abs(amount) >= 1_000_000:
		return "%.2fM" % (float(amount) / 1_000_000.0)
	if abs(amount) >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)
