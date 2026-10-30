class_name Contract
extends RefCounted

## A cargo contract (spec §9). Model + KPI grading.

var id: String = ""
var client_id: String = ""
var tier: String = ""
var cargo_mix: Dictionary = {}      # cargo id -> share
var q: float = 0.0                  # required tonnes
var deadline_min: float = 0.0
var diff: int = 1
var kpi_required: Array = []
var kpi_bonus: Array = []
var reward: Dictionary = {}
var penalty: Dictionary = {}
var flags: Dictionary = {}

# runtime
var delivered: float = 0.0
var elapsed_min: float = 0.0
var line: int = -1


func mix_price(cat: Catalog) -> float:
	var p: float = 0.0
	for cargo_id in cargo_mix:
		var idx: int = int(cat.index.get(cargo_id, -1))
		if idx >= 0:
			p += float(cargo_mix[cargo_id]) * float(cat.price[idx])
	return p


func progress() -> float:
	return clampf(delivered / maxf(q, 1e-9), 0.0, 1.0)


func deadline_left() -> float:
	return maxf(0.0, deadline_min - elapsed_min)


## Grade the finished contract (spec §9.4).
func grade(waste_frac: float, incidents: int, synergy: float, classes: Array) -> String:
	if delivered < q or elapsed_min > deadline_min:
		return "fail"
	for k in kpi_required:
		if String(k.get("type", "")) == "deadline":
			continue
		if not _kpi_ok(k, waste_frac, incidents, synergy, classes):
			return "bronze"
	for k in kpi_bonus:
		if not _kpi_ok(k, waste_frac, incidents, synergy, classes):
			return "silver"
	return "gold"


func grade_mult(g: String) -> float:
	match g:
		"gold":
			return 1.5
		"silver":
			return 1.0
		"bronze":
			return 0.6
	return 0.0


func _kpi_ok(k: Dictionary, waste_frac: float, incidents: int, synergy: float, classes: Array) -> bool:
	match String(k.get("type", "")):
		"deadline":
			return true
		"tempo":
			return (delivered / maxf(elapsed_min, 1e-9)) >= float(k.get("min", 0.0))
		"quality":
			return waste_frac <= float(k.get("max_defect", 1.0))
		"safety":
			return incidents <= int(k.get("max_incidents", 0))
		"brigade":
			return synergy >= float(k.get("min", 0.0))
		"crew":
			return classes.has(String(k.get("class", "")))
	return true