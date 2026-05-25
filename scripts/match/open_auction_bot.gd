class_name OpenAuctionBot
extends RefCounted

const RosterConfigScript = preload("res://scripts/data/roster_config.gd")
const ValuationScript = preload("res://scripts/match/valuation.gd")


static func should_raise(
    player,
    warehouse,
    board,
    rng: RandomNumberGenerator,
    max_rounds: int,
) -> bool:
    if board == null or warehouse == null:
        return false
    if player.passed_this_round:
        return false
    var est: Dictionary = _estimate(player, warehouse, board)
    var mid: int = int(est.get("mid", 1))
    var gap: int = mid - board.current_highest_bid
    var urgency: float = clampf(float(gap) / float(maxi(mid, 1)), 0.0, 1.0)
    var round_boost: float = float(board.round_index) / float(maxi(max_rounds, 1))
    var chance: float = 0.42 + urgency * 0.48 + round_boost * 0.12
    chance += player.aggression * 0.2 + player.raise_tendency * 0.15
    if board.current_leader_seat == player.seat_index:
        chance *= 0.55
    if board.current_highest_bid <= 0:
        chance += 0.2
    # 远低于预估时几乎必出价
    if urgency > 0.65:
        chance = maxf(chance, 0.88)
    return rng.randf() < clampf(chance, 0.05, 0.98)


static func pick_bid(
    player,
    board,
    warehouse,
    rng: RandomNumberGenerator,
    max_rounds: int,
    cfg_min_raise: int,
) -> int:
    if board == null or warehouse == null:
        return 1
    var est: Dictionary = _estimate(player, warehouse, board)
    var low: int = int(est.get("low", board.min_next_bid))
    var mid: int = int(est.get("mid", low))
    var round_t: float = float(board.round_index - 1) / float(maxi(max_rounds - 1, 1))
    round_t = clampf(round_t, 0.0, 1.0)
    # 随轮次逐步提高目标：从约 25% 预估追到中后期逼近/略超预估下限
    var chase_low: float = 0.22 + round_t * 0.38 + player.aggression * 0.12
    var chase_mid: float = 0.08 + round_t * 0.2 + player.raise_tendency * 0.1
    var target: int = int(low * chase_low + mid * chase_mid)
    if board.current_highest_bid > 0 and rng.randf() < 0.45 + player.aggression * 0.2:
        target = maxi(target, int(board.current_highest_bid * rng.randf_range(1.02, 1.12)))
    elif board.current_highest_bid > 0 and rng.randf() < 0.25:
        target = int(board.current_highest_bid * rng.randf_range(0.82, 0.98))
    if rng.randf() < 0.35 + player.aggression * 0.2:
        target += rng.randi_range(1, 3) * maxi(cfg_min_raise, int(mid * 0.01))
    if rng.randf() < player.bluff_rate:
        target = int(target * rng.randf_range(1.04, 1.15))
    var cap: int = int(mid * player.max_chase_ratio)
    target = mini(target, cap)
    target = mini(target, player.silver)
    return maxi(target, 1)


static func _estimate(player, warehouse, board) -> Dictionary:
    if board == null or warehouse == null:
        return {"low": 1, "mid": 1, "high": 1}
    var skill_id: String = RosterConfigScript.get_skill_id(player.character_id)
    var intel: Dictionary = warehouse.get_intel_for_character(skill_id, board.round_index)
    return ValuationScript.estimate_from_intel(intel, player.valuation_bias)
