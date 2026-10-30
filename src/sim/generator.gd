class_name Generator
extends RefCounted

## Deterministic worker / candidate generation (spec §6.5, §7.3, §7.4).
##
## Given the same PCG32 stream and draw order, it always produces the same
## workers — so the hire board never rerolls on reload. Pity guarantees are
## tracked across draws on this instance.

var rules: Rules

var _since: Dictionary = { "rare": 0, "epic": 0, "legendary": 0 }
var hires: int = 0


func _init(p_rules: Rules) -> void:
	rules = p_rules


## Draw a rarity tier, honouring the agency odds and pity guarantees.
func next_rarity(rng: PCG32, agency: int) -> int:
	var odds: Array = rules.agency_odds[clampi(agency, 0, rules.agency_odds.size() - 1)]
	var total: float = 0.0
	for w in odds:
		total += float(w)
	var pick: float = rng.next_float() * total
	var acc: float = 0.0
	var tier: int = 0
	for i in odds.size():
		acc += float(odds[i])
		if pick < acc:
			tier = i
			break

	hires += 1
	_since["rare"] += 1
	_since["epic"] += 1
	_since["legendary"] += 1
	if _since["legendary"] >= int(rules.guarantees.get("legendary", 150)):
		tier = maxi(tier, 4)
	if _since["epic"] >= int(rules.guarantees.get("epic", 40)):
		tier = maxi(tier, 3)
	if _since["rare"] >= int(rules.guarantees.get("rare", 12)):
		tier = maxi(tier, 2)
	if tier >= 2:
		_since["rare"] = 0
	if tier >= 3:
		_since["epic"] = 0
	if tier >= 4:
		_since["legendary"] = 0
	return tier


## Build a full Worker of the given rarity tier.
func create_worker(rng: PCG32, tier: int, opts: Dictionary = {}) -> Worker:
	var w := Worker.new()
	w.id = "w_%08x" % rng.next_uint32()
	w.class_id = String(opts.get("class", _pick(rng, rules.class_ids())))
	w.species = String(opts.get("species", _pick(rng, rules.species_ids())))
	w.rarity = clampi(tier, 0, rules.rarities.size() - 1)
	w.star = _pick(rng, rules.star_element.keys())
	w.psycho = _pick(rng, rules.psycho_matrix.keys())

	var rar: Dictionary = rules.rarity_of(w.rarity)
	var stat_sum: float = float(rar.get("stat_sum", 50))
	var weights: Dictionary = rules.class_weights.get(w.class_id, {})
	for s in Rules.STATS:
		var base: float = float(weights.get(s, 0.0)) * stat_sum
		w.point_stats[s] = maxf(1.0, roundf(base) + rng.next_range(-2, 2))

	_make_traits(rng, w, rar)
	_make_name(rng, w)
	w.wage = w.wage_base(rules)
	w.appearance = {
		"body": rng.next_bounded(3),
		"skin": rng.next_bounded(6),
		"hair_style": rng.next_bounded(12),
		"hair_color": rng.next_bounded(16),
		"eyes_style": rng.next_bounded(8),
		"eye_color": rng.next_bounded(12),
		"uniform": rng.next_bounded(3),
		"seed": rng.next_uint32(),
	}
	return w


func _make_traits(rng: PCG32, w: Worker, rar: Dictionary) -> void:
	var lo: int = int(rar.get("traits_min", 0))
	var hi: int = int(rar.get("traits_max", 0))
	var count: int = rng.next_range(lo, hi)
	for i in count:
		var group: String = "positive" if rng.next_float() < 0.8 else "neutral"
		w.traits.append({ "id": _pick(rng, rules.trait_ids_by_group[group]), "hidden": false })
	if rng.next_float() < rules.hidden_negative_chance:
		w.traits.append({ "id": _pick(rng, rules.trait_ids_by_group["hidden"]), "hidden": true })


func _make_name(rng: PCG32, w: Worker) -> void:
	var given: Array = (rules.names.get("given", {}) as Dictionary).get(w.species, ["Безымянная"])
	var surnames: Array = rules.names.get("surnames", ["—"])
	w.full_name = "%s %s" % [_pick(rng, given), _pick(rng, surnames)]
	w.callsign = _pick(rng, rules.names.get("callsigns", [""])) if rng.next_float() < 0.1 else ""


func _pick(rng: PCG32, arr: Array) -> String:
	if arr.is_empty():
		return ""
	return String(arr[rng.next_bounded(arr.size())])