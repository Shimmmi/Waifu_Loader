class_name Worker
extends RefCounted

## A terminal employee (spec §6.1). Pure data + derived values; no nodes.
## v0.2: fit/stat_breakdown/expression_state getters.
## M3 scope: identity, stats, traits, star/psycho, wage, morale/fatigue,
## skills, equipment, pinning. Deep trait/skill effects come later.

var id: String = ""
var full_name: String = ""     # given + surname
var callsign: String = ""
var species: String = ""
var class_id: String = ""
var rarity: int = 0
var level: int = 1
var xp: float = 0.0

## Stat points before species multipliers.
var point_stats: Dictionary = {}
## [{id: String, hidden: bool}]
var traits: Array = []
var star: String = ""
var psycho: String = ""

var wage: float = 0.0
var morale: float = 60.0
var fatigue: float = 0.0
var wear: float = 0.0            # androids instead of fatigue
var status: String = "bench"     # bench/shift/rest/injured/training/market
var skills: Dictionary = {}      # tier -> skill id
var equip: String = ""
var pinned: bool = false
var appearance: Dictionary = {}
var shifts_worked: int = 0
## other worker id -> number of shared shifts
var friends: Dictionary = {}


func display_name() -> String:
	if callsign.is_empty():
		return full_name
	return "%s «%s»" % [full_name, callsign]


## Effective stats after species multipliers (spec §6.4).
func stats(rules: Rules) -> Dictionary:
	var mult: Dictionary = rules.species_mult.get(species, {})
	var out: Dictionary = {}
	for s in Rules.STATS:
		out[s] = float(point_stats.get(s, 0)) * float(mult.get(s, 1.0))
	return out


func contrib(rules: Rules, crew: Crew) -> float:
	return crew.contrib(class_id, stats(rules))


func morale_mult() -> float:
	return 0.8 + 0.4 * (morale / 100.0)


func fatigue_mult() -> float:
	if fatigue >= 100.0:
		return 0.0
	if fatigue <= 50.0:
		return 1.0
	if fatigue <= 80.0:
		return lerpf(1.0, 0.75, (fatigue - 50.0) / 30.0)
	return 0.75


## Combined worker multiplier used inside station power (spec §8.3).
func m() -> float:
	return morale_mult() * fatigue_mult()


func as_crew_entry(rules: Rules) -> Dictionary:
	return { "class": class_id, "stats": stats(rules), "m": m() }


func xp_needed(for_level: int) -> float:
	return 40.0 * pow(1.30, for_level - 1)


## Wage per shift (spec §6.7): base(class) x rarity x species x (1+0.04*(L-1)).
func wage_base(rules: Rules) -> float:
	var base: float = float(rules.class_wage.get(class_id, 10.0))
	var rar: Dictionary = rules.rarity_of(rarity)
	var rar_mult: float = float(rar.get("wage_mult", 1.0))
	var spc: Dictionary = rules.species_extras.get(species, {})
	var spc_mult: float = float(spc.get("wage_mult", 1.0))
	return base * rar_mult * spc_mult * (1.0 + 0.04 * (level - 1))


## Add XP and level up while the threshold is met. Pass `rules` to keep wage in
## sync with the new level.
func add_xp(amount: float, rules: Rules = null) -> void:
	xp += amount
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
	if rules != null:
		wage = wage_base(rules)


func to_dict() -> Dictionary:
	return {
		"id": id, "full_name": full_name, "callsign": callsign, "species": species,
		"class_id": class_id, "rarity": rarity, "level": level, "xp": xp,
		"point_stats": point_stats.duplicate(), "traits": traits.duplicate(true),
		"star": star, "psycho": psycho, "wage": wage, "morale": morale,
		"fatigue": fatigue, "wear": wear, "status": status,
		"skills": skills.duplicate(), "equip": equip, "pinned": pinned,
		"appearance": appearance.duplicate(true), "shifts_worked": shifts_worked,
		"friends": friends.duplicate(),
	}


static func from_dict(d: Dictionary) -> Worker:
	var w := Worker.new()
	w.id = String(d.get("id", ""))
	w.full_name = String(d.get("full_name", ""))
	w.callsign = String(d.get("callsign", ""))
	# Legacy alias ovion → avian (v0.2 §2.3); keep pure so headless tests work.
	var sp: String = String(d.get("species", ""))
	w.species = "avian" if sp == "ovion" else sp
	w.class_id = String(d.get("class_id", ""))
	w.rarity = int(d.get("rarity", 0))
	w.level = int(d.get("level", 1))
	w.xp = float(d.get("xp", 0.0))
	w.point_stats = (d.get("point_stats", {}) as Dictionary).duplicate()
	w.traits = (d.get("traits", []) as Array).duplicate(true)
	w.star = String(d.get("star", ""))
	w.psycho = String(d.get("psycho", ""))
	w.wage = float(d.get("wage", 0.0))
	w.morale = float(d.get("morale", 60.0))
	w.fatigue = float(d.get("fatigue", 0.0))
	w.wear = float(d.get("wear", 0.0))
	w.status = String(d.get("status", "bench"))
	w.skills = (d.get("skills", {}) as Dictionary).duplicate()
	w.equip = String(d.get("equip", ""))
	w.pinned = bool(d.get("pinned", false))
	w.appearance = (d.get("appearance", {}) as Dictionary).duplicate(true)
	w.shifts_worked = int(d.get("shifts_worked", 0))
	w.friends = (d.get("friends", {}) as Dictionary).duplicate()
	return w


func has_trait(trait_id: String) -> bool:
	for t in traits:
		if t["id"] == trait_id:
			return true
	return false


## Station fitness = class_fit for this worker's class (v0.2 §3.4).
func fit(station_id: String, rules: Rules) -> float:
	var row: Dictionary = rules.class_fit.get(station_id, {})
	return float(row.get(class_id, 0.2))


## Contribution × fit for a station.
func station_score(station_id: String, rules: Rules, crew: Crew) -> float:
	return contrib(rules, crew) * fit(station_id, rules)


## Breakdown of one stat into base / level / equip / species (read-only).
func stat_breakdown(stat: String, rules: Rules) -> Dictionary:
	var base: float = float(point_stats.get(stat, 0))
	var level_gain: float = 0.0  # level gains folded into point_stats in generator
	var equip_bonus: float = 0.0
	var mult: float = float(rules.species_mult.get(species, {}).get(stat, 1.0))
	var total: float = (base + level_gain + equip_bonus) * mult
	return {
		"base": base,
		"level": level_gain,
		"equip": equip_bonus,
		"species_mult": mult,
		"total": total,
	}


## Portrait emotion key from morale / fatigue / status (v0.2 §3.4).
func expression_state() -> String:
	if status == "injured":
		return "injured"
	if fatigue >= 80.0 or (species == "android" and wear >= 80.0):
		return "tired"
	if morale <= 30.0:
		return "annoyed"
	if morale >= 70.0:
		return "happy"
	return "neutral"