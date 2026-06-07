class_name CharacterSkills
extends RefCounted
## 出战角色的局内技能逻辑

const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")

const MIA_INITIAL_REVEAL: int = 5
const MIA_PER_ROUND_REVEAL: int = 2
const ARIA_PER_ROUND_FULL: int = 2

const KEEN_SIGHT_MAX_ROUND: int = 4
const FINAL_SEIZURE_ROUND: int = 5


static func _empty_skill_indices() -> Dictionary:
	return {"revealed_indices": [], "quality_size_indices": [], "outline_indices": []}


static func pick_round_skill_indices(
	warehouse,
	rng: RandomNumberGenerator,
	skill_id: String,
	round_index: int,
) -> Dictionary:
	var out: Dictionary = _empty_skill_indices()
	if warehouse == null or skill_id.is_empty():
		return out
	match skill_id:
		"court_announce":
			out["revealed_indices"] = _pick_unrevealed_full(warehouse, rng, ARIA_PER_ROUND_FULL)
		"holy_bell_shake":
			out["quality_size_indices"] = _pick_unrevealed_quality(
				warehouse, rng, MIA_PER_ROUND_REVEAL,
			)
		"keen_sight":
			out["outline_indices"] = _pick_outlines_for_quality_round(warehouse, round_index)
		"final_seizure":
			if round_index >= FINAL_SEIZURE_ROUND:
				out["outline_indices"] = _all_item_indices(warehouse)
				out["quality_size_indices"] = _pick_unrevealed_quality(
					warehouse, rng, warehouse.items.size(),
				)
		_:
			pass
	return out


static func build_match_start_effects(
	warehouse,
	cfg: Dictionary,
	character_id: String,
	indices_mia_start: Array[int],
) -> Array[Dictionary]:
	var skill_id: String = RosterConfigScript.get_skill_id(character_id)
	var effects: Array[Dictionary] = []
	match skill_id:
		"night_raven_peek":
			var e: Dictionary = _build_night_raven_effect(warehouse, character_id)
			if not e.is_empty():
				effects.append(e)
		"iron_pact":
			var ie: Dictionary = _build_iron_pact_effect(warehouse, character_id)
			if not ie.is_empty():
				effects.append(ie)
		"star_chart_valuation":
			var se: Dictionary = _build_star_chart_effect(warehouse, cfg, character_id)
			if not se.is_empty():
				effects.append(se)
		"amber_scale":
			var ae: Dictionary = _build_amber_scale_effect(warehouse, character_id)
			if not ae.is_empty():
				effects.append(ae)
		"holy_bell_shake":
			var me: Dictionary = _build_holy_bell_start_effect(
				warehouse, character_id, indices_mia_start.size(),
			)
			if not me.is_empty():
				effects.append(me)
		"art_golden_eye":
			var ge: Dictionary = _build_art_golden_eye_effect(warehouse, character_id)
			if not ge.is_empty():
				effects.append(ge)
	return effects


static func build_round_skill_effect(
	warehouse,
	character_id: String,
	skill_indices: Dictionary,
	round_index: int,
	catalog = null,
) -> Dictionary:
	var skill_id: String = RosterConfigScript.get_skill_id(character_id)
	var name: String = RosterConfigScript.get_skill_name(character_id)
	match skill_id:
		"court_announce":
			var indices: Array = skill_indices.get("revealed_indices", [])
			if indices.is_empty():
				return {}
			var item_lines: Dictionary = _format_court_announce_items(warehouse, indices, catalog)
			return {
				"title": "%s：%s" % [RosterConfigScript.get_display_name(character_id), name],
				"body": "王庭宣价：本轮翻开 %d 件藏品全部信息。" % indices.size(),
				"detail": str(item_lines.get("plain", "")),
				"body_bbcode": str(item_lines.get("bbcode", "")),
				"icon_kind": "character",
				"character_id": character_id,
				"sort_order": 1000,
				"round_index": round_index,
				"revealed_indices": indices.duplicate(),
			}
		"holy_bell_shake":
			var qs: Array = skill_indices.get("quality_size_indices", [])
			if qs.is_empty():
				return {}
			var hint: String = "初探 %d 件。" % MIA_INITIAL_REVEAL if round_index <= 1 else "再探 %d 件。" % MIA_PER_ROUND_REVEAL
			return {
				"title": "%s：%s" % [RosterConfigScript.get_display_name(character_id), name],
				"body": "圣铃摇晃：%s 已探测 %d/%d 件品质与占格。" % [
					hint,
					warehouse.count_quality_size_revealed() + qs.size(),
					warehouse.items.size(),
				],
				"icon_kind": "character",
				"character_id": character_id,
				"sort_order": 1000,
				"round_index": round_index,
				"quality_size_indices": qs.duplicate(),
			}
		"keen_sight":
			var outlines: Array = skill_indices.get("outline_indices", [])
			if outlines.is_empty() or round_index > KEEN_SIGHT_MAX_ROUND:
				return {}
			var quality: int = round_index - 1
			var q_name: String = _quality_name(quality)
			return {
				"title": "%s：%s" % [RosterConfigScript.get_display_name(character_id), name],
				"body": "慧眼：第 %d 轮揭示所有%s品质藏品轮廓（共 %d 件）。" % [
					round_index, q_name, outlines.size(),
				],
				"icon_kind": "character",
				"character_id": character_id,
				"sort_order": 1000,
				"round_index": round_index,
				"outline_indices": outlines.duplicate(),
			}
		"final_seizure":
			if round_index < FINAL_SEIZURE_ROUND:
				return {}
			var outline_all: Array = skill_indices.get("outline_indices", [])
			var qs_all: Array = skill_indices.get("quality_size_indices", [])
			if outline_all.is_empty() and qs_all.is_empty():
				return {}
			return {
				"title": "%s：%s" % [RosterConfigScript.get_display_name(character_id), name],
				"body": "终局查没：第 %d 轮开始时揭示全部 %d 件藏品的品质与轮廓。" % [
					round_index, warehouse.items.size(),
				],
				"icon_kind": "character",
				"character_id": character_id,
				"sort_order": 1000,
				"round_index": round_index,
				"outline_indices": outline_all.duplicate(),
				"quality_size_indices": qs_all.duplicate(),
			}
		_:
			return {}


static func build_persistent_skill_chip(
	warehouse,
	character_id: String,
	round_index: int,
) -> Dictionary:
	var skill_id: String = RosterConfigScript.get_skill_id(character_id)
	var name: String = RosterConfigScript.get_skill_name(character_id)
	match skill_id:
		"holy_bell_shake":
			if warehouse == null:
				return {}
			return {
				"title": "%s：%s" % [RosterConfigScript.get_display_name(character_id), name],
				"body": "已探测 %d/%d 件品质与占格。" % [
					warehouse.count_quality_size_revealed(),
					warehouse.items.size(),
				],
				"icon_kind": "character",
				"character_id": character_id,
				"sort_order": 1000,
				"round_index": round_index,
			}
		_:
			return {}


static func _build_amber_scale_effect(warehouse, character_id: String) -> Dictionary:
	if warehouse == null:
		return {}
	var bands: Array[int] = [
		GameConstants.Quality.WHITE,
		GameConstants.Quality.GREEN,
		GameConstants.Quality.BLUE,
	]
	var lines: PackedStringArray = []
	for q in bands:
		var stats: Dictionary = _quality_count_and_value(warehouse, q)
		var count: int = int(stats.get("count", 0))
		if count <= 0:
			continue
		lines.append("%s品质 %d 件，总值 %s" % [
			_quality_name(q),
			count,
			_format_silver(int(stats.get("value", 0))),
		])
	var body: String = "；".join(lines) if lines.size() > 0 else "本局无白/绿/蓝品质藏品。"
	return {
		"title": "%s：琥珀秤" % RosterConfigScript.get_display_name(character_id),
		"body": body,
		"icon_kind": "character",
		"character_id": character_id,
		"sort_order": 900,
		"round_index": 1,
	}


static func _build_iron_pact_effect(warehouse, character_id: String) -> Dictionary:
	if warehouse == null:
		return {}
	var purple: int = 0
	var gold: int = 0
	var red: int = 0
	for s in warehouse.items:
		match s.quality:
			GameConstants.Quality.PURPLE:
				purple += 1
			GameConstants.Quality.GOLD:
				gold += 1
			GameConstants.Quality.RED:
				red += 1
	var parts: PackedStringArray = []
	if purple > 0:
		parts.append("%d 件紫色" % purple)
	if gold > 0:
		parts.append("%d 件金色" % gold)
	if red > 0:
		parts.append("%d 件红色" % red)
	var body: String = "本局共有 %s品质藏品。" % "、".join(parts) if parts.size() > 0 else "本局无紫/金/红品质藏品。"
	return {
		"title": "%s：铁契" % RosterConfigScript.get_display_name(character_id),
		"body": body,
		"icon_kind": "character",
		"character_id": character_id,
		"sort_order": 900,
		"round_index": 1,
	}


static func _build_art_golden_eye_effect(warehouse, character_id: String) -> Dictionary:
	if warehouse == null:
		return {}
	var outline_indices: Array[int] = []
	var quality_indices: Array[int] = []
	for i in warehouse.items.size():
		if not _is_art_item(warehouse, i):
			continue
		outline_indices.append(i)
		if not warehouse.is_quality_size_revealed(i):
			quality_indices.append(i)
	if outline_indices.is_empty():
		return {
			"title": "%s：藏品金瞳" % RosterConfigScript.get_display_name(character_id),
			"body": "本局无艺术藏品类型道具。",
			"icon_kind": "character",
			"character_id": character_id,
			"sort_order": 900,
			"round_index": 1,
		}
	return {
		"title": "%s：藏品金瞳" % RosterConfigScript.get_display_name(character_id),
		"body": "金瞳锁定 %d 件艺术藏品的品质与轮廓。" % outline_indices.size(),
		"icon_kind": "character",
		"character_id": character_id,
		"sort_order": 900,
		"round_index": 1,
		"outline_indices": outline_indices,
		"quality_size_indices": quality_indices,
	}


static func _build_night_raven_effect(warehouse, character_id: String) -> Dictionary:
	if warehouse == null:
		return {}
	var purple: int = 0
	var gold: int = 0
	var red: int = 0
	for s in warehouse.items:
		match s.quality:
			GameConstants.Quality.PURPLE:
				purple += 1
			GameConstants.Quality.GOLD:
				gold += 1
			GameConstants.Quality.RED:
				red += 1
	var parts: PackedStringArray = []
	if purple > 0:
		parts.append("%d 件紫色" % purple)
	if gold > 0:
		parts.append("%d 件金色" % gold)
	if red > 0:
		parts.append("%d 件红色" % red)
	var body: String = "本局共有 %s品质道具。" % "、".join(parts) if parts.size() > 0 else "本局无高价值品质道具。"
	return {
		"title": "%s：夜鸦窥价" % RosterConfigScript.get_display_name(character_id),
		"body": body,
		"icon_kind": "character",
		"character_id": character_id,
		"sort_order": 900,
		"round_index": 1,
	}


static func _build_star_chart_effect(warehouse, cfg: Dictionary, character_id: String) -> Dictionary:
	if warehouse == null:
		return {}
	var total: int = warehouse.true_total_value
	var start_bid: int = maxi(int(cfg.get("starting_bid", 10000)), 1)
	var items_n: int = maxi(warehouse.items.size(), 1)
	var per_item_start: int = start_bid * items_n
	var ratio: float = float(total) / float(maxi(per_item_start, 1))
	var label: String = "合理"
	if ratio < 0.75:
		label = "偏低"
	elif ratio > 1.35:
		label = "偏高"
	var low_pct: int = int(ratio * 85.0)
	var high_pct: int = int(ratio * 115.0)
	return {
		"title": "%s：星盘估值" % RosterConfigScript.get_display_name(character_id),
		"body": "战利品总估值倾向「%s」；相对起拍合计约 %d%%～%d%%。" % [label, low_pct, high_pct],
		"icon_kind": "character",
		"character_id": character_id,
		"sort_order": 900,
		"round_index": 1,
	}


static func _build_holy_bell_start_effect(
	warehouse,
	character_id: String,
	revealed_n: int,
) -> Dictionary:
	if warehouse == null:
		return {}
	return {
		"title": "%s：圣铃摇晃" % RosterConfigScript.get_display_name(character_id),
		"body": "开局圣铃回响，已探测 %d 件品质与占格（共 %d 件）。" % [
			revealed_n, warehouse.items.size(),
		],
		"icon_kind": "character",
		"character_id": character_id,
		"sort_order": 900,
		"round_index": 1,
	}


static func _quality_count_and_value(warehouse, quality: int) -> Dictionary:
	var count: int = 0
	var value: int = 0
	for item in warehouse.items:
		if item.quality != quality:
			continue
		count += 1
		value += int(item.value)
	return {"count": count, "value": value}


static func _pick_outlines_for_quality_round(warehouse, round_index: int) -> Array[int]:
	if round_index < 1 or round_index > KEEN_SIGHT_MAX_ROUND:
		return []
	var quality: int = round_index - 1
	var out: Array[int] = []
	for i in warehouse.items.size():
		var item = warehouse.items[i]
		if item.quality != quality:
			continue
		if warehouse.is_outline_revealed(i):
			continue
		out.append(i)
	return out


static func _all_item_indices(warehouse) -> Array[int]:
	var out: Array[int] = []
	for i in warehouse.items.size():
		out.append(i)
	return out


static func _is_art_item(warehouse, index: int) -> bool:
	if index < 0 or index >= warehouse.items.size():
		return false
	var item = warehouse.items[index]
	var item_id: String = str(item.item_id)
	var catalog := ItemCatalogScript.new()
	if catalog.load_all():
		var row: Dictionary = catalog.get_item(item_id)
		if not row.is_empty():
			return str(row.get("item_type", "")) == ItemCatalogScript.TYPE_ART
	return ItemCatalogScript.resolve_item_type(item_id) == ItemCatalogScript.TYPE_ART


static func _pick_unrevealed_full(warehouse, rng: RandomNumberGenerator, count: int) -> Array[int]:
	var pool: Array[int] = []
	for i in warehouse.items.size():
		if not warehouse.is_player_revealed(i):
			pool.append(i)
	return _pick_from_pool(pool, rng, count)


static func _pick_unrevealed_quality(warehouse, rng: RandomNumberGenerator, count: int) -> Array[int]:
	var pool: Array[int] = []
	for i in warehouse.items.size():
		if not warehouse.is_quality_size_revealed(i):
			pool.append(i)
	return _pick_from_pool(pool, rng, count)


static func _format_court_announce_items(warehouse, indices: Array, catalog) -> Dictionary:
	var plain_parts: PackedStringArray = []
	var bb_parts: PackedStringArray = []
	for idx_v in indices:
		var idx: int = int(idx_v)
		if idx < 0 or idx >= warehouse.items.size():
			continue
		var item = warehouse.items[idx]
		var q_name: String = _quality_name(item.quality)
		var type_label: String = _item_type_label(catalog, str(item.item_id))
		var cells: int = item.size_w * item.size_h
		var desc_bits: PackedStringArray = PackedStringArray([
			"%s品质" % q_name,
			"%d×%d格" % [item.size_w, item.size_h],
		])
		if not type_label.is_empty():
			desc_bits.append(type_label)
		desc_bits.append("估值 %s" % _format_silver(item.value))
		var desc: String = "，".join(desc_bits)
		plain_parts.append("· %s（%s）" % [item.item_name, desc])
		bb_parts.append(
			"· [color=%s]%s[/color]（%s）" % [item.quality_color, item.item_name, desc],
		)
	var plain: String = "\n".join(plain_parts)
	var bbcode: String = "王庭宣价：本轮翻开 %d 件藏品全部信息。" % indices.size()
	if not bb_parts.is_empty():
		bbcode += "\n" + "\n".join(bb_parts)
	return {"plain": plain, "bbcode": bbcode}


static func _quality_name(quality: int) -> String:
	if quality >= 0 and quality < GameConstants.QUALITY_NAMES.size():
		return GameConstants.QUALITY_NAMES[quality]
	return "?"


static func _item_type_label(catalog, item_id: String) -> String:
	if catalog == null or item_id.is_empty():
		return ""
	var row: Dictionary = catalog.get_item(item_id)
	if row.is_empty():
		return ""
	var type_key: String = str(row.get("item_type", ""))
	return str(ItemCatalogScript.TYPE_LABELS.get(type_key, ""))


static func _format_silver(amount: int) -> String:
	var n: int = absi(amount)
	if n >= 1_000_000:
		return "%.2fM" % (float(n) / 1_000_000.0)
	if n >= 1_000:
		return "%.1fK" % (float(n) / 1_000.0)
	return str(n)


static func _pick_from_pool(pool: Array[int], rng: RandomNumberGenerator, count: int) -> Array[int]:
	var picked: Array[int] = []
	for _n in count:
		if pool.is_empty():
			break
		var at: int = rng.randi_range(0, pool.size() - 1)
		picked.append(pool[at])
		pool.remove_at(at)
	return picked
