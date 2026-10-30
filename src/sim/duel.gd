class_name Duel
extends RefCounted

## Asynchronous Cup duel (spec §13.6): two 3-slot brigades on an identical
## arena, one shared seed. Pure and deterministic so the headless validator
## reproduces the server result exactly.

const DURATION_S := 180.0
const ARENA_DOCK := 6
const ARENA_STORE := 6
const PRICE := 12.0
const STATIONS: Array[String] = ["unload", "move", "store"]

## League stat caps (spec §13.6).
const CAPS := {
	"bronze": 40.0, "silver": 60.0, "gold": 85.0, "platinum": 115.0, "diamond": 150.0,
}


static func cap_for(league: String) -> float:
	return float(CAPS.get(league, 40.0))


## brigade: Array of up to 3 {station, class_id, si}. Returns a side snapshot.
static func score_side(crew: Crew, brigade: Array, tactic: String, cap: float) -> Dictionary:
	var powers: Dictionary = { "unload": 0.0, "move": 0.0, "store": 0.0 }
	for slot in brigade:
		var station: String = String(slot.get("station", "unload"))
		var class_id: String = String(slot.get("class_id", ""))
		var si: float = minf(float(slot.get("si", 25.0)), cap)
		var fit: float = crew.class_fit(station, class_id)
		powers[station] += (si / 25.0) * fit

	var mod: Dictionary = Tactics.modifier(tactic)
	var speed: float = 1.0 + float(mod["speed"])
	var rate: float = minf(powers["unload"], minf(powers["move"], powers["store"])) * speed
	var tonnes: float = rate * DURATION_S
	var defect: float = clampf(0.02 + float(mod["defect"]), 0.0, 0.9)
	var score: float = tonnes * PRICE * (1.0 - defect)
	return { "tonnes": tonnes, "defect": defect, "score": score, "powers": powers, "rate": rate }


## Simulate a duel. Returns { result, scores, seed, rating_delta, replay }.
static func simulate(
	_catalog: Catalog,
	crew: Crew,
	a_brigade: Array,
	b_brigade: Array,
	a_tactic: String,
	b_tactic: String,
	league: String,
	rng_seed: int = 0,
) -> Dictionary:
	var cap: float = cap_for(league)
	var sa: Dictionary = score_side(crew, a_brigade, a_tactic, cap)
	var sb: Dictionary = score_side(crew, b_brigade, b_tactic, cap)

	# Counter bonus (spec §13.6).
	if Tactics.beats(a_tactic, b_tactic):
		sa["score"] = float(sa["score"]) * (1.0 + Tactics.COUNTER_BONUS)
	elif Tactics.beats(b_tactic, a_tactic):
		sb["score"] = float(sb["score"]) * (1.0 + Tactics.COUNTER_BONUS)

	var score_a: float = sa["score"]
	var score_b: float = sb["score"]
	var result: String = "win" if score_a > score_b else ("loss" if score_a < score_b else "draw")

	var replay: Array = _replay(rng_seed, a_tactic, b_tactic, float(sa["rate"]), float(sb["rate"]))
	return {
		"result": result,
		"seed": rng_seed,
		"scores": [int(round(score_a)), int(round(score_b))],
		"rating_delta": _rating_delta(result),
		"replay": replay,
	}


static func _rating_delta(result: String) -> int:
	# Elo, K = 24 attacker (spec §13.6). Defensive K is applied server-side.
	match result:
		"win":
			return 14
		"loss":
			return -14
		_:
			return 0


static func _replay(rng_seed: int, a_tactic: String, b_tactic: String, rate_a: float, rate_b: float) -> Array:
	var rng := PCG32.new(rng_seed, 7)
	var events: Array = [
		{ "t": 0.0, "a": 0, "k": "tactic_bonus" if Tactics.beats(a_tactic, b_tactic) else "start" },
		{ "t": 0.0, "a": 1, "k": "tactic_bonus" if Tactics.beats(b_tactic, a_tactic) else "start" },
	]
	for step in 8:
		var t: float = DURATION_S * float(step + 1) / 9.0
		var actor: int = rng.next_bounded(2)
		var rate: float = rate_a if actor == 0 else rate_b
		events.append({ "t": roundf(t), "a": actor, "k": "store" if rate >= 1.0 else "move" })
	return events