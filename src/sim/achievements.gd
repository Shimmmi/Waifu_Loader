class_name Achievements
extends RefCounted

## Achievement tracking (spec §12.4). Conditions are {type, value} compared
## against a stats dictionary.

var list: Array = []
var by_id: Dictionary = {}


static func from_data(d: Dictionary) -> Achievements:
	var a := Achievements.new()
	a.list = d.get("achievements", [])
	for row in a.list:
		a.by_id[row["id"]] = row
	return a


## Returns the achievement rows newly satisfied (not already in `done`).
func check(stats: Dictionary, done: Dictionary) -> Array:
	var newly: Array = []
	for a in list:
		if done.has(a["id"]):
			continue
		if satisfied(a["condition"], stats):
			newly.append(a)
	return newly


func satisfied(condition: Dictionary, stats: Dictionary) -> bool:
	var t: String = String(condition.get("type", ""))
	return float(stats.get(t, 0.0)) >= float(condition.get("value", 0))


func total() -> int:
	return list.size()