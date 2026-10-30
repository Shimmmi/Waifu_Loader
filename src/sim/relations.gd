class_name Relations
extends RefCounted

## Client relations (spec §10.5): 0..100 per client, shifted by contract grades.

const MIN := 0
const MAX := 100

var values: Dictionary = {}


static func delta_for_grade(grade: String) -> int:
	match grade:
		"gold":
			return 8
		"silver":
			return 5
		"bronze":
			return 2
		"fail":
			return -10
	return 0


func get_relation(id: String) -> int:
	return int(values.get(id, 0))


func adjust(id: String, delta: int) -> int:
	var v: int = clampi(get_relation(id) + delta, MIN, MAX)
	values[id] = v
	return v


func tier(id: String) -> String:
	var v: int = get_relation(id)
	if v >= 75:
		return "ally"
	if v >= 40:
		return "friendly"
	if v <= 15:
		return "hostile"
	return "neutral"


## Reward multiplier from relations (allies pay a little more).
func reward_bonus(id: String) -> float:
	var v: int = get_relation(id)
	return 1.0 + 0.10 * (float(v) / float(MAX))


func to_dict() -> Dictionary:
	return values.duplicate()


func load_dict(d: Dictionary) -> void:
	values = d.duplicate()