class_name ContractBoard
extends RefCounted

## The contract board (spec §9). Deterministic offer generation.

var data: Dictionary = {}
var clients: Array = []
var cat: Catalog
var offers: Array = []     # Array[Contract]
var active: Array = []     # Array[Contract]


func _init(p_data: Dictionary, p_clients: Array, p_cat: Catalog) -> void:
	data = p_data
	clients = p_clients
	cat = p_cat


## Highest tier whose rank range contains `rank`, or {} if none (rank < 4).
func tier_for_rank(rank: int) -> Dictionary:
	var best: Dictionary = {}
	for t in data.get("tiers", []):
		var r: Array = t["ranks"]
		if rank >= int(r[0]) and rank <= int(r[1]):
			best = t
	return best


func refresh(rng: PCG32, rank: int, tariff: float, flow_est: float, count: int) -> void:
	offers.clear()
	var tier: Dictionary = tier_for_rank(rank)
	if tier.is_empty():
		return
	for i in maxi(count, 1):
		offers.append(_generate(rng, rank, tariff, flow_est, tier))


func take(contract_id: String) -> Contract:
	for i in offers.size():
		if offers[i].id == contract_id:
			return offers.pop_at(i)
	return null


func _generate(rng: PCG32, rank: int, tariff: float, flow_est: float, tier: Dictionary) -> Contract:
	var c := Contract.new()
	c.id = "c_%08x" % rng.next_uint32()
	c.tier = String(tier["id"])
	c.client_id = String(clients[rng.next_bounded(clients.size())]["id"])

	var diffs: Array = data.get("diffs", [])
	var d: Dictionary = diffs[rng.next_bounded(diffs.size())]
	c.diff = int(d["id"])
	c.deadline_min = float(rng.next_range(int(tier["deadline_min"][0]), int(tier["deadline_min"][1])))

	# Cargo mix: 1..2 types with random shares summing to 1.
	var chosen: Array = []
	var pool: Array = (tier["cargo"] as Array).duplicate()
	var n: int = 1 + rng.next_bounded(mini(2, pool.size()))
	for i in n:
		if pool.is_empty():
			break
		var idx: int = rng.next_bounded(pool.size())
		chosen.append(pool[idx])
		pool.remove_at(idx)
	var weights: Array = []
	var total_w: float = 0.0
	for cid in chosen:
		var w: float = 1.0 + rng.next_float() * 2.0
		weights.append(w)
		total_w += w
	for i in chosen.size():
		c.cargo_mix[chosen[i]] = weights[i] / total_w

	c.q = maxf(10.0, flow_est * c.deadline_min * float(d["mult"]))
	var price: float = c.mix_price(cat)
	var base: float = c.q * price * tariff * (1.4 + 0.5 * c.diff)
	c.reward = {
		"credits": base,
		"rep": 2.0 * (1.0 + c.diff) * (1.0 + 0.1 * (rank - 1)),
		"parts": 0.0,
	}
	c.penalty = { "rep": 0.5 * float(c.reward["rep"]), "credits": 0.1 * base }
	c.kpi_required = [{ "type": "deadline" }]
	c.kpi_bonus = _roll_bonus(rng, flow_est)
	return c


func _roll_bonus(rng: PCG32, flow_est: float) -> Array:
	var pool: Array = ["tempo", "quality", "safety", "brigade"]
	var bonus: Array = []
	var bn: int = rng.next_bounded(3)
	for i in bn:
		if pool.is_empty():
			break
		var idx: int = rng.next_bounded(pool.size())
		var t: String = pool[idx]
		pool.remove_at(idx)
		match t:
			"tempo":
				bonus.append({ "type": "tempo", "min": flow_est * 0.8 })
			"quality":
				bonus.append({ "type": "quality", "max_defect": 0.05 })
			"safety":
				bonus.append({ "type": "safety", "max_incidents": 0 })
			"brigade":
				bonus.append({ "type": "brigade", "min": 10.0 })
	return bonus