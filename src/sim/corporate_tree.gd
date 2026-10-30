class_name CorporateTree
extends RefCounted

## Corporate tree: node costs and aggregate effects (spec §12.3).

var data: Dictionary = {}
var nodes: Dictionary = {}      # id -> row
var cost_growth: float = 1.6


static func from_data(d: Dictionary) -> CorporateTree:
	var t := CorporateTree.new()
	t.data = d
	t.cost_growth = float(d.get("cost_growth", 1.6))
	for row in d.get("nodes", []):
		t.nodes[row["id"]] = row
	return t


func node(id: String) -> Dictionary:
	return nodes.get(id, {})


func max_level(id: String) -> int:
	return int(node(id).get("max", 1))


## Shares cost to buy the next level when currently at `level` (base * 1.6^level).
func cost(id: String, level: int) -> int:
	return int(ceil(float(node(id).get("base", 1)) * pow(cost_growth, level)))


## Summed effect for `effect_key` over purchased levels ({id: level}).
func effect_total(levels: Dictionary, effect_key: String) -> float:
	var total: float = 0.0
	for id in levels:
		var eff: Dictionary = node(id).get("effect", {})
		if eff.has(effect_key):
			total += float(eff[effect_key]) * int(levels[id])
	return total