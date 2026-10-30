class_name Crew
extends RefCounted

## Crew contribution math (spec §6.3, §6.4).
##
## Pure functions over plain data so they run in headless tests. A "worker" is
## represented here as {class: String, stats: Dictionary, m: float} where `m`
## is the combined morale/fatigue/trait multiplier. The full Worker model
## arrives with M3; LineSim only needs the resulting station power.

const STATS: Array[String] = ["str", "agi", "acc", "end", "wit"]

## class id -> {stat: weight}
var weights: Dictionary = {}
## station -> {class id: fit}
var fit: Dictionary = {}
var contrib_divisor: float = 25.0


static func from_dicts(classes: Dictionary, balance: Dictionary) -> Crew:
	var c := Crew.new()
	for row in classes.get("classes", []):
		c.weights[row["id"]] = row["weights"]
	c.fit = classes.get("class_fit", {})
	c.contrib_divisor = float(balance.get("contrib_divisor", 25.0))
	return c


## Skill index SI = sum(w_i * stat_i) for a worker's class weights (spec §6.3).
func skill_index(class_id: String, stats: Dictionary) -> float:
	var w: Dictionary = weights.get(class_id, {})
	var si: float = 0.0
	for s in STATS:
		si += float(w.get(s, 0.0)) * float(stats.get(s, 0.0))
	return si


## Contribution to station speed: contrib = SI / 25 (spec §6.3).
func contrib(class_id: String, stats: Dictionary) -> float:
	return skill_index(class_id, stats) / contrib_divisor


## Class-to-station fit (spec §6.3). Defaults to 0.2 (mismatched class).
func class_fit(station: String, class_id: String) -> float:
	var row: Dictionary = fit.get(station, {})
	return float(row.get(class_id, 0.2))


## Total station power = sum over workers of contrib * fit * m (spec §8.3).
func station_power(station: String, workers: Array) -> float:
	var power: float = 0.0
	for w in workers:
		var class_id: String = String(w.get("class", ""))
		var stats: Dictionary = w.get("stats", {})
		var m: float = float(w.get("m", 1.0))
		power += contrib(class_id, stats) * class_fit(station, class_id) * m
	return power