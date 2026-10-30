class_name DailyShift
extends RefCounted

## Daily Shift / «Эталонная смена» (spec §13.5): a fixed-line challenge independent
## of progression. Same preset for everyone on a given day seed. Pure so the
## headless validator reproduces the score.

const DURATION_S := 300.0
const DOCK := 8
const STORE := 8
const PRICE := 12.0
const SLOT_COUNT := 6
const SLOT_STATIONS: Array[String] = ["unload", "unload", "move", "move", "store", "store"]
const TEMP_CLASSES: Array[String] = [
	"loader", "crane_operator", "driver", "storekeeper",
	"loader", "crane_operator", "storekeeper", "mechanic",
]


## The preset: 6 slots and 8 temporary employees, identical for all players.
static func preset(rng_seed: int) -> Dictionary:
	var rng := PCG32.new(rng_seed, 3)
	var employees: Array = []
	for i in TEMP_CLASSES.size():
		employees.append({
			"class_id": TEMP_CLASSES[i],
			"si": 30.0 + float(rng.next_bounded(40)),
			"star": ["", "a", "b", "c", "d"][rng.next_bounded(5)],
		})
	return {
		"seed": rng_seed,
		"dock": DOCK,
		"store": STORE,
		"stations": SLOT_STATIONS.duplicate(),
		"employees": employees,
	}


## assignment[i] = employee index in slot i, or -1 for empty.
static func run(_catalog: Catalog, crew: Crew, assignment: Array, rng_seed: int) -> Dictionary:
	var data: Dictionary = preset(rng_seed)
	var brigade: Array = []
	for i in SLOT_STATIONS.size():
		var idx: int = int(assignment[i]) if i < assignment.size() else -1
		if idx < 0 or idx >= (data["employees"] as Array).size():
			continue
		var emp: Dictionary = (data["employees"] as Array)[idx]
		brigade.append({
			"station": SLOT_STATIONS[i],
			"class_id": emp["class_id"],
			"si": emp["si"],
		})
	var side: Dictionary = Duel.score_side(crew, brigade, Tactics.BALANCE, 1.0e9)
	var kpi: Dictionary = _kpi(rng_seed)
	var score: float = float(side["score"]) * (1.0 + float(kpi["bonus"])) - float(kpi["penalty"])
	return {
		"score": score,
		"tonnes": side["tonnes"],
		"kpi": kpi,
		"brigade": brigade,
	}


## Seed-chosen KPI outcome from the day's 4 events (spec §13.5).
static func _kpi(rng_seed: int) -> Dictionary:
	var rng := PCG32.new(rng_seed, 11)
	var roll: int = rng.next_bounded(100)
	if roll < 45:
		return { "bonus": 0.10, "penalty": 0.0 }
	if roll < 80:
		return { "bonus": 0.25, "penalty": 0.0 }
	return { "bonus": 0.0, "penalty": 200.0 }