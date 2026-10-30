class_name Tender
extends RefCounted

## Weekly Tender competition (spec §9.7). A rule-of-the-week applies a modifier
## to the same scoring as a shift; results are validated server-side.

const DURATION_S := 600.0
const PRICE := 12.0
const RULES: Array[String] = ["standard", "heavy", "fragile", "perishable", "light", "strike"]


static func rule_for(rng_seed: int) -> String:
	return RULES[PCG32.new(rng_seed, 23).next_bounded(RULES.size())]


static func rule_modifier(rule: String) -> Dictionary:
	match rule:
		"heavy":
			return { "speed": -0.05, "defect": 0.0, "price": 1.15 }
		"fragile":
			return { "speed": 0.0, "defect": 1.0, "price": 1.0 }
		"perishable":
			return { "speed": 0.0, "defect": 1.0, "price": 1.0 }
		"light":
			return { "speed": -0.30, "defect": 0.0, "price": 1.0 }
		"strike":
			return { "speed": -0.10, "defect": 0.10, "price": 1.25 }
		_:
			return { "speed": 0.0, "defect": 0.0, "price": 1.0 }


static func run(crew: Crew, brigade: Array, rule: String, rng_seed: int) -> Dictionary:
	var mod: Dictionary = rule_modifier(rule)
	var side: Dictionary = Duel.score_side(crew, brigade, Tactics.BALANCE, 1.0e9)
	var tonnes: float = float(side["tonnes"]) * (1.0 + float(mod["speed"]))
	var defect: float = clampf(float(side["defect"]) * (1.0 + float(mod["defect"])), 0.0, 0.95)
	var score: float = tonnes * PRICE * (1.0 - defect) * float(mod["price"])
	return { "score": score, "tonnes": tonnes, "rule": rule, "seed": rng_seed }