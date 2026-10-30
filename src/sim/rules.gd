class_name Rules
extends RefCounted

## Bundles every HR-related data table and exposes lookups (spec §6, §10).
## Pure data/helper object — no nodes.

const STATS: Array[String] = ["str", "agi", "acc", "end", "wit"]

var class_weights: Dictionary = {}
var class_wage: Dictionary = {}
var class_fit: Dictionary = {}
var species_mult: Dictionary = {}
var species_extras: Dictionary = {}

var star_element: Dictionary = {}
var element_compat: Dictionary = {}
var same_sign_bonus: float = 8.0

var psycho_matrix: Dictionary = {}

var chemistry: Dictionary = {}
var friendship_levels: Array = []
var friendship_bonus: float = 2.0
var pair_min: float = -25.0
var pair_max: float = 30.0
var speed_per_synergy: float = 0.5
var morale_per_synergy_div: float = 10.0
var morale_cap: float = 3.0
var conflict_threshold: float = -15.0
var conflict_chance: float = 0.08

var rarities: Array = []
var agency_odds: Array = []
var guarantees: Dictionary = {}
var hidden_negative_chance: float = 0.2

var traits: Dictionary = {}
var trait_ids_by_group: Dictionary = { "positive": [], "neutral": [], "hidden": [] }
var skills: Dictionary = {}  # class -> tier -> [skill ids]

var names: Dictionary = {}


static func from_data(classes: Dictionary, species: Dictionary, stars: Dictionary, psycho: Dictionary, synergy: Dictionary, rarity: Dictionary, traits_tbl: Dictionary, skills_tbl: Dictionary, names_tbl: Dictionary) -> Rules:
	var r := Rules.new()

	for row in classes.get("classes", []):
		r.class_weights[row["id"]] = row["weights"]
		r.class_wage[row["id"]] = float(row.get("wage", 10))
	r.class_fit = classes.get("class_fit", {})

	for row in species.get("species", []):
		r.species_mult[row["id"]] = row["mult"]
		r.species_extras[row["id"]] = row

	for row in stars.get("stars", []):
		r.star_element[row["id"]] = row["element"]
	r.element_compat = stars.get("element_compat", {})
	r.same_sign_bonus = float(stars.get("same_sign_bonus", 8))

	r.psycho_matrix = psycho.get("matrix", {})

	r.chemistry = synergy.get("class_chemistry", {})
	r.friendship_levels = synergy.get("friendship_levels", [])
	r.friendship_bonus = float(synergy.get("friendship_bonus_per_level", 2))
	r.pair_min = float(synergy.get("pair_min", -25))
	r.pair_max = float(synergy.get("pair_max", 30))
	r.speed_per_synergy = float(synergy.get("speed_per_synergy", 0.5))
	r.morale_per_synergy_div = float(synergy.get("morale_per_synergy_div", 10))
	r.morale_cap = float(synergy.get("morale_cap", 3))
	r.conflict_threshold = float(synergy.get("conflict_threshold", -15))
	r.conflict_chance = float(synergy.get("conflict_chance", 0.08))

	r.rarities = rarity.get("rarities", [])
	r.agency_odds = rarity.get("agency_odds", [])
	r.guarantees = rarity.get("guarantees", {})
	r.hidden_negative_chance = float(rarity.get("hidden_negative_chance", 0.2))

	for row in traits_tbl.get("traits", []):
		r.traits[row["id"]] = row
		var g: String = String(row.get("group", "positive"))
		if r.trait_ids_by_group.has(g):
			r.trait_ids_by_group[g].append(row["id"])

	for row in skills_tbl.get("skills", []):
		var c: String = String(row["class"])
		if not r.skills.has(c):
			r.skills[c] = {}
		var t: int = int(row["tier"])
		if not r.skills[c].has(t):
			r.skills[c][t] = []
		r.skills[c][t].append(row["id"])

	r.names = names_tbl
	return r


func rarity_of(tier: int) -> Dictionary:
	return rarities[clampi(tier, 0, rarities.size() - 1)]


func class_ids() -> Array:
	return class_weights.keys()


func species_ids() -> Array:
	return species_mult.keys()


func class_fit_value(station: String, class_id: String) -> float:
	return float((class_fit.get(station, {}) as Dictionary).get(class_id, 0.2))


func star_pair(a: String, b: String) -> float:
	if a == b:
		return same_sign_bonus
	var ea: String = String(star_element.get(a, ""))
	var eb: String = String(star_element.get(b, ""))
	return float((element_compat.get(ea, {}) as Dictionary).get(eb, 0.0))


func psycho_pair(a: String, b: String) -> float:
	return float((psycho_matrix.get(a, {}) as Dictionary).get(b, 0.0))


func chemistry_value(ca: String, cb: String) -> float:
	var pair: Array = [ca, cb]
	pair.sort()
	return float(chemistry.get(pair[0] + "+" + pair[1], 0.0))