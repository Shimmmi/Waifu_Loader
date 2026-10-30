class_name Synergy
extends RefCounted

## Pair and line synergy (spec §10). Pure functions over Workers + Rules.

var rules: Rules


func _init(p_rules: Rules) -> void:
	rules = p_rules


## Alias used by UI (v0.2 §6.2).
func pair(a: Worker, b: Worker) -> float:
	return pair_value(a, b)


## Hypothetical line synergy if `roster` were assigned (read-only).
func line(line_id: int, hypothetical_roster: Array) -> float:
	return line_synergy(hypothetical_roster)


## Pair value P(a,b) = star + psycho + 2*friendship + class chemistry,
## clamped to [pair_min, pair_max] (spec §10.3).
func pair_value(a: Worker, b: Worker) -> float:
	var v: float = rules.star_pair(a.star, b.star) \
		+ rules.psycho_pair(a.psycho, b.psycho) \
		+ rules.chemistry_value(a.class_id, b.class_id) \
		+ rules.friendship_bonus * float(friendship_level(a, b))
	return clampf(v, rules.pair_min, rules.pair_max)


func friendship_level(a: Worker, b: Worker) -> int:
	var shared: int = mini(int(a.friends.get(b.id, 0)), int(b.friends.get(a.id, 0)))
	var level: int = 0
	for threshold in rules.friendship_levels:
		if shared >= int(threshold):
			level += 1
	return level


## Average pair value across all pairs on a line (spec §10.3).
func line_synergy(workers: Array) -> float:
	var n: int = workers.size()
	if n < 2:
		return 0.0
	var sum: float = 0.0
	var pairs: int = 0
	for i in n:
		for j in range(i + 1, n):
			sum += pair_value(workers[i], workers[j])
			pairs += 1
	return sum / float(maxi(pairs, 1))


## Station-speed multiplier from synergy (category D), ±(12.5%..15%).
func speed_mult(s: float) -> float:
	return 1.0 + s / 100.0 * rules.speed_per_synergy


## Morale delta per shift from synergy, capped at ±morale_cap.
func morale_delta(s: float) -> float:
	return clampf(s / rules.morale_per_synergy_div, -rules.morale_cap, rules.morale_cap)


func is_conflict(a: Worker, b: Worker) -> bool:
	return pair_value(a, b) <= rules.conflict_threshold