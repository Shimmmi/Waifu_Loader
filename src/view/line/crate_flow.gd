class_name CrateFlow
extends RefCounted

## Turns flow_tps into on-screen crates with accumulator (v0.2 §4.5).

const MAX_FLYING: int = 12

var u: float = 1.0
var acc: float = 0.0
var flying: Array = []  # [{pos, target, type, t}]


func configure(crate_u: float) -> void:
	u = maxf(crate_u, 0.5)


func step(flow_tps: float, dt: float, from: Vector2, to: Vector2, cargo_type: int = 0) -> void:
	acc += flow_tps * dt / u
	while acc >= 1.0 and flying.size() < MAX_FLYING:
		acc -= 1.0
		flying.append({"pos": from, "target": to, "type": cargo_type, "t": 0.0})
	# Advance flying crates.
	var keep: Array = []
	for c in flying:
		c["t"] = float(c["t"]) + dt
		var t: float = clampf(float(c["t"]) / 1.2, 0.0, 1.0)
		c["pos"] = Vector2(c["pos"]).lerp(Vector2(c["target"]), t) if false else lerp_vec(c, t)
		if t < 1.0:
			keep.append(c)
	flying = keep


func lerp_vec(c: Dictionary, t: float) -> Vector2:
	# Re-store start on first frame via target-only path: approximate from current.
	return Vector2(c["pos"]).lerp(Vector2(c["target"]), t)


func stage_for_fill(tons: float, cap: float) -> int:
	if cap <= 0.0:
		return 0
	var pct: float = clampf(tons / cap, 0.0, 1.0) * 100.0
	if pct <= 0.0:
		return 0
	if pct <= 20.0:
		return 1
	if pct <= 40.0:
		return 2
	if pct <= 60.0:
		return 3
	if pct <= 80.0:
		return 4
	return 5
