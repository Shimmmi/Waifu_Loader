class_name Tactics
extends RefCounted

## Cup tactics (spec §13.6): speed/defect modifiers and the counter cycle.

const ASSAULT := "assault"
const METICULOUS := "meticulous"
const BALANCE := "balance"

const ALL: Array[String] = [ASSAULT, METICULOUS, BALANCE]
const COUNTER_BONUS: float = 0.08


static func modifier(tactic: String) -> Dictionary:
	match tactic:
		ASSAULT:
			return { "speed": 0.15, "defect": 0.20, "passive": 0.0 }
		METICULOUS:
			return { "speed": -0.10, "defect": -0.50, "passive": 0.0 }
		_:
			return { "speed": 0.0, "defect": 0.0, "passive": 0.05 }


## True when `a` counters `b` (assault→meticulous→balance→assault).
static func beats(a: String, b: String) -> bool:
	return (a == ASSAULT and b == METICULOUS) \
		or (a == METICULOUS and b == BALANCE) \
		or (a == BALANCE and b == ASSAULT)