class_name DirectiveBoard
extends RefCounted

## Directive boards (spec §12.1): a linear tutorial chain plus daily and weekly
## goals. Progress accrues from reported stat events; rewards are claimed once.

var active: Array = []
var progress: Dictionary = {}
var claimed: Dictionary = {}


static func from_data(dirs: Directives, rng: PCG32, linear_index: int = 0, daily_count: int = 3, weekly_count: int = 2) -> DirectiveBoard:
	var b := DirectiveBoard.new()
	if linear_index >= 0 and linear_index < dirs.linear.size():
		b.active.append(dirs.linear[linear_index])
	for e in dirs.pick_daily(rng, daily_count):
		b.active.append(e)
	for e in dirs.pick_weekly(rng, weekly_count):
		b.active.append(e)
	for e in b.active:
		b.progress[e["id"]] = 0.0
	return b


func entry(id: String) -> Dictionary:
	for e in active:
		if e["id"] == id:
			return e
	return {}


func value(id: String) -> float:
	return float(progress.get(id, 0.0))


func is_complete(id: String) -> bool:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return false
	return value(id) >= float((e.get("goal", {}) as Dictionary).get("value", 0))


func is_claimed(id: String) -> bool:
	return claimed.has(id)


## Report `amount` of a stat; returns ids that became complete and unclaimed.
func report(stat_type: String, amount: float) -> Array:
	var done: Array = []
	for e in active:
		var goal: Dictionary = e.get("goal", {})
		if String(goal.get("type", "")) != stat_type:
			continue
		var id: String = e["id"]
		if claimed.has(id):
			continue
		progress[id] = value(id) + amount
		if is_complete(id):
			done.append(id)
	return done


func claim(id: String) -> Dictionary:
	if is_claimed(id) or not is_complete(id):
		return {}
	var e: Dictionary = entry(id)
	claimed[id] = true
	return e.get("reward", {})


func completed_count() -> int:
	var n: int = 0
	for e in active:
		if is_complete(e["id"]):
			n += 1
	return n


func active_linear_complete() -> bool:
	if active.is_empty():
		return false
	return is_complete(String(active[0]["id"]))