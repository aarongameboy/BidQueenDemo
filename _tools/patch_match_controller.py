from pathlib import Path

p = Path(r"D:\bidKingDemo\scripts\match\match_controller.gd")
t = p.read_text(encoding="utf-8")

old1 = """func start_match(seed_override: int = -1) -> void:
\tif _running:
\t\treturn"""

new1 = """func restart_match(seed_override: int = -1) -> void:
\t_running = false
\tstart_match(seed_override)


func start_match(seed_override: int = -1) -> void:
\tif _running:
\t\treturn"""

if old1 not in t:
    raise SystemExit("start_match block not found")
t = t.replace(old1, new1, 1)

old2 = """func _resolve_round_bids(min_raise: int) -> void:
\tvar bids: Array[Dictionary] = []
\tfor p in _players:
\t\tvar seat: int = p.seat_index
\t\tvar amount: int = int(_round_seat_peak_bid.get(seat, 0))
\t\tif amount > 0:
\t\t\tbids.append({"seat": seat, "bid": amount})
\tbids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
\t\treturn int(a.get("bid", 0)) < int(b.get("bid", 0))
\t)
\tfor entry in bids:
\t\t_try_apply_bid(int(entry.get("seat", -1)), int(entry.get("bid", 0)), min_raise)"""

new2 = """func _resolve_round_bids(min_raise: int) -> void:
\tvar best_seat: int = -1
\tvar best_bid: int = 0
\tfor p in _players:
\t\tvar seat: int = p.seat_index
\t\tvar amount: int = int(_round_seat_peak_bid.get(seat, 0))
\t\tif amount <= 0:
\t\t\tcontinue
\t\tvar check: Dictionary = OpenAuctionRulesScript.can_raise(
\t\t\t_board, seat, amount, p.silver, false,
\t\t)
\t\tif not check.get("ok", false):
\t\t\tcontinue
\t\tif amount > best_bid:
\t\t\tbest_bid = amount
\t\t\tbest_seat = seat
\tif best_seat >= 0:
\t\t_try_apply_bid(best_seat, best_bid, min_raise)"""

if old2 not in t:
    raise SystemExit("resolve block not found")
t = t.replace(old2, new2, 1)

p.write_text(t, encoding="utf-8", newline="\n")
print("patched ok")
