class_name BotBrain
extends RefCounted

const CharacterDataScript = preload("res://scripts/data/character_data.gd")
const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const ValuationScript = preload("res://scripts/match/valuation.gd")

static func compute_bid(
	player,
	warehouse,
	round_index: int,
	other_bids_last_round: Array[int],
	rng: RandomNumberGenerator,
) -> int:
	var skill_id: String = RosterConfigScript.get_skill_id(player.character_id)
	var intel: Dictionary = warehouse.get_intel_for_character(skill_id, round_index + 1)
	var archetype: int = CharacterDataScript.get_archetype(player.character_id)
	var est: Dictionary = ValuationScript.estimate_from_intel(intel, player.valuation_bias)
	var target: int = int(est["mid"] * (1.0 - player.aggression * 0.25))
	target = maxi(target, int(est["low"] * 0.9))
	var second_best: int = _second_highest(other_bids_last_round)
	match archetype:
		CharacterDataScript.SkillArchetype.BLOCKER:
			if second_best > 0 and rng.randf() < 0.4 + player.aggression * 0.3:
				var crush: int = ValuationScript.bid_for_speed_win(second_best, round_index)
				target = maxi(target, crush)
			else:
				target = int(target * (1.1 + player.aggression * 0.2))
		CharacterDataScript.SkillArchetype.INTEL:
			if second_best > 0:
				target = int((target + second_best * 1.05) * 0.5)
			if round_index >= 3:
				target = int(target * 1.08)
		CharacterDataScript.SkillArchetype.DISRUPT:
			if rng.randf() < player.bluff_rate:
				target = int(est["high"] * 1.2)
		_:
			pass
	if rng.randf() < player.bluff_rate * 0.5:
		target = int(target * rng.randf_range(1.15, 1.35))
	target = clampi(target, 10_000, player.silver)
	if not player.can_afford(target):
		target = player.silver
	return target


static func _second_highest(bids: Array[int]) -> int:
	var sorted: Array[int] = bids.duplicate()
	sorted.sort()
	sorted.reverse()
	if sorted.size() < 2:
		return sorted[0] if not sorted.is_empty() else 0
	return sorted[1]
