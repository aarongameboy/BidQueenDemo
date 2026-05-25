class_name LeaderboardService
extends RefCounted

const LeaderboardConfigScript = preload("res://scripts/data/leaderboard_config.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const MatchControllerScript = preload("res://scripts/match/match_controller.gd")

const LIST_SIZE: int = 50


static func build_board(
	period: String,
	category_id: String,
	region_id: String = "all",
) -> Dictionary:
	LeaderboardConfigScript.load_all()
	var category: Dictionary = LeaderboardConfigScript.get_category(category_id)
	if category.is_empty():
		return {"entries": [], "self_entry": {}}
	var contestants: Array[Dictionary] = _build_contestants()
	var entries: Array[Dictionary] = []
	for c in contestants:
		var value: float = _contestant_value(c, period, category_id)
		var row: Dictionary = c.duplicate(true)
		row["value"] = value
		row["value_text"] = format_value(value, category)
		entries.append(row)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var higher: bool = bool(category.get("higher_is_better", true))
		if higher:
			return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
		return float(a.get("value", 0.0)) < float(b.get("value", 0.0))
	)
	if region_id != "all" and not region_id.is_empty():
		var filtered: Array[Dictionary] = []
		for row in entries:
			if str(row.get("region_id", "")) == region_id:
				filtered.append(row)
		entries = filtered
	var ranked: Array[Dictionary] = []
	for i in entries.size():
		var row: Dictionary = entries[i].duplicate(true)
		row["rank"] = i + 1
		ranked.append(row)
	var self_entry: Dictionary = {}
	for row in ranked:
		if bool(row.get("is_human", false)):
			self_entry = row.duplicate(true)
			break
	if self_entry.is_empty():
		self_entry = _build_human_entry(period, category_id, category)
		self_entry["value_text"] = format_value(float(self_entry.get("value", 0.0)), category)
		self_entry["rank"] = _estimate_rank(ranked, float(self_entry.get("value", 0.0)), category)
	return {
		"entries": ranked.slice(0, mini(LIST_SIZE, ranked.size())),
		"self_entry": self_entry,
		"category": category,
	}


static func format_value(value: float, category: Dictionary) -> String:
	var fmt: String = str(category.get("format", "silver"))
	match fmt:
		"percent":
			return "%.1f%%" % value
		"count":
			return str(int(round(value)))
		_:
			return MatchControllerScript._format_silver(int(round(value)))


static func _build_contestants() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	RosterConfigScript.ensure_loaded()
	for row in LeaderboardConfigScript.get_bot_npcs():
		if typeof(row) != TYPE_DICTIONARY:
			continue
		out.append(_npc_to_entry(row))
	for cid in RosterConfigScript.all_ids():
		var dup: bool = false
		for existing in out:
			if str(existing.get("character_id", "")) == cid:
				dup = true
				break
		if dup:
			continue
		out.append({
			"entry_id": "char_%s" % cid,
			"display_name": RosterConfigScript.get_display_name(cid),
			"title": RosterConfigScript.get_role_title(cid),
			"region_id": _region_for_seed(cid),
			"character_id": cid,
			"is_bot": true,
			"is_human": false,
		})
	out.append(_build_human_entry("", "", {}))
	return out


static func _npc_to_entry(row: Dictionary) -> Dictionary:
	var cid: String = str(row.get("character_id", ""))
	var entry_id: String = str(row.get("id", ""))
	return {
		"entry_id": entry_id,
		"display_name": str(row.get("display_name", entry_id)),
		"title": str(row.get("title", "")),
		"region_id": str(row.get("region_id", "asia_panda")),
		"character_id": cid,
		"is_bot": bool(row.get("is_bot", true)),
		"is_human": false,
	}


static func _build_human_entry(_period: String, category_id: String, category: Dictionary) -> Dictionary:
	var roster: Node = Engine.get_main_loop().root.get_node_or_null("/root/PlayerRoster")
	var lb: Node = Engine.get_main_loop().root.get_node_or_null("/root/PlayerLeaderboard")
	var cid: String = RosterConfigScript.get_default_id()
	if roster:
		cid = str(roster.selected_character_id)
	var value: float = 0.0
	if lb and not category_id.is_empty():
		value = float(lb.get_value(category_id, _period))
	elif _period.is_empty():
		value = 0.0
	return {
		"entry_id": "human_local",
		"display_name": RosterConfigScript.get_display_name(cid),
		"title": RosterConfigScript.get_role_title(cid),
		"region_id": "asia_panda",
		"character_id": cid,
		"is_bot": false,
		"is_human": true,
		"value": value,
	}


static func _contestant_value(contestant: Dictionary, period: String, category_id: String) -> float:
	if bool(contestant.get("is_human", false)):
		var lb: Node = Engine.get_main_loop().root.get_node_or_null("/root/PlayerLeaderboard")
		if lb:
			return float(lb.get_value(category_id, period))
		return 0.0
	var entry_id: String = str(contestant.get("entry_id", ""))
	var rng := RandomNumberGenerator.new()
	var day_key: String = _today_key()
	rng.seed = hash("%s|%s|%s|%s" % [entry_id, period, category_id, day_key])
	var tier: float = rng.randf_range(0.35, 1.0)
	var base: float = _bot_base_for_category(category_id) * _period_scale(period) * tier
	var cid: String = str(contestant.get("character_id", ""))
	if not cid.is_empty():
		base *= 0.85 + rng.randf() * 0.3
	return base


static func _bot_base_for_category(category_id: String) -> float:
	match category_id:
		"total_profit", "consign_profit":
			return 2_800_000.0
		"total_loss", "single_loss":
			return 1_600_000.0
		"single_profit":
			return 980_000.0
		"red_collect_count":
			return 28.0
		"total_profit_ratio", "bid_success_rate":
			return 88.0
		"bid_spread_ratio":
			return 22.0
		_:
			return 1_000_000.0


static func _period_scale(period: String) -> float:
	match period:
		"weekly":
			return 3.8
		"monthly":
			return 13.0
		_:
			return 1.0


static func _region_for_seed(seed_text: String) -> String:
	var regions: Array = LeaderboardConfigScript.get_regions()
	var pool: Array[String] = []
	for row in regions:
		var rid: String = str(row.get("id", ""))
		if rid != "all" and not rid.is_empty():
			pool.append(rid)
	if pool.is_empty():
		return "asia_panda"
	var idx: int = absi(hash(seed_text)) % pool.size()
	return pool[idx]


static func _estimate_rank(
	entries: Array[Dictionary],
	value: float,
	category: Dictionary,
) -> int:
	if entries.is_empty():
		return 1
	var higher: bool = bool(category.get("higher_is_better", true))
	var rank: int = 1
	for row in entries:
		var v: float = float(row.get("value", 0.0))
		if higher:
			if v > value:
				rank += 1
		elif v < value:
			rank += 1
	return rank


static func _today_key() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [dt.year, dt.month, dt.day]
