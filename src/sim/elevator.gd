class_name Elevator
extends RefCounted

## Orbital Elevator goal milestones (spec §12.2), driven by lifetime tonnes.

var milestones: Array = []


static func from_data(d: Dictionary) -> Elevator:
	var e := Elevator.new()
	e.milestones = d.get("milestones", [])
	return e


func completed(tonnes: float) -> int:
	var n: int = 0
	for m in milestones:
		if tonnes >= float(m["tonnes"]):
			n += 1
	return n


func next(tonnes: float) -> Dictionary:
	for m in milestones:
		if tonnes < float(m["tonnes"]):
			return m
	return {}


## Progress within the current milestone band, 0..1.
func progress(tonnes: float) -> float:
	var nxt: Dictionary = next(tonnes)
	if nxt.is_empty():
		return 1.0
	var prev: float = 0.0
	for m in milestones:
		if float(m["tonnes"]) <= tonnes:
			prev = float(m["tonnes"])
	return clampf((tonnes - prev) / maxf(float(nxt["tonnes"]) - prev, 1e-9), 0.0, 1.0)