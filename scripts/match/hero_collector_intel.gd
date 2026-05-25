class_name HeroCollectorIntel
extends RefCounted
## 主角「巅峰收藏家」：揭示品质与占格，不揭示名称与价值

const INITIAL_REVEAL_COUNT: int = 5
const PER_ROUND_REVEAL_COUNT: int = 2


static func pick_reveals(warehouse, rng: RandomNumberGenerator, round_index: int) -> Array[int]:
	if warehouse == null or warehouse.items.is_empty():
		return []
	var want: int = INITIAL_REVEAL_COUNT if round_index <= 1 else PER_ROUND_REVEAL_COUNT
	var pool: Array[int] = []
	for i in warehouse.items.size():
		if not warehouse.is_quality_size_revealed(i):
			pool.append(i)
	var picked: Array[int] = []
	for _n in want:
		if pool.is_empty():
			break
		var at: int = rng.randi_range(0, pool.size() - 1)
		picked.append(pool[at])
		pool.remove_at(at)
	return picked


static func build_skill_effect(revealed_count: int, total_items: int, round_index: int) -> Dictionary:
	var round_hint: String = ""
	if round_index <= 1:
		round_hint = "本轮初探 %d 件。" % INITIAL_REVEAL_COUNT
	else:
		round_hint = "本轮再探 %d 件。" % PER_ROUND_REVEAL_COUNT
	return {
		"title": "巅峰收藏家：情报技能",
		"body": "%s 已探测 %d/%d 件品质与占格（名称、价值未知，见右侧战利品）。" % [
			round_hint, revealed_count, total_items,
		],
		"icon_kind": "character",
		"sort_order": 1000,
		"round_index": round_index,
	}
