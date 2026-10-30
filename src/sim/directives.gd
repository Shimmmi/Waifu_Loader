class_name Directives
extends RefCounted

## Directive boards (spec §12.1): a linear tutorial chain, plus daily/weekly
## boards drawn deterministically.

var linear: Array = []
var daily: Array = []
var weekly: Array = []


static func from_data(d: Dictionary) -> Directives:
	var dirs := Directives.new()
	dirs.linear = d.get("linear", [])
	dirs.daily = d.get("daily", [])
	dirs.weekly = d.get("weekly", [])
	return dirs


func pick_daily(rng: PCG32, count: int) -> Array:
	return _pick(rng, daily, count)


func pick_weekly(rng: PCG32, count: int) -> Array:
	return _pick(rng, weekly, count)


func _pick(rng: PCG32, pool: Array, count: int) -> Array:
	var copy: Array = pool.duplicate()
	var out: Array = []
	for i in mini(count, copy.size()):
		var idx: int = rng.next_bounded(copy.size())
		out.append(copy[idx])
		copy.remove_at(idx)
	return out