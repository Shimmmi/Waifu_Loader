class_name EventDeck
extends RefCounted

## Weighted event card draw and eligibility (spec §11.1–11.2).

var events: Array = []

## Recognised effect types (must match the data validator).
const EFFECT_TYPES: Array[String] = [
	"morale", "credits", "credits_per_rank", "parts", "rep", "fatigue",
	"mod_station", "mod_flow", "status", "sector_break", "relation",
	"chain_set", "worker_gain",
]


func _init(data: Dictionary) -> void:
	events = data.get("events", [])


func eligible(rank: int, flags: Dictionary) -> Array:
	var out: Array = []
	var sectors: Array = flags.get("sectors", [])
	var cargo: Array = flags.get("cargo", [])
	var active_contract: bool = bool(flags.get("active_contract", false))
	for e in events:
		var c: Dictionary = e.get("conditions", {})
		if int(c.get("min_rank", 0)) > rank:
			continue
		if c.has("needs_sector") and not sectors.has(String(c["needs_sector"])):
			continue
		if c.has("needs_cargo") and not cargo.has(String(c["needs_cargo"])):
			continue
		if bool(c.get("needs_active_contract", false)) and not active_contract:
			continue
		out.append(e)
	return out


## Pick one eligible card by weight (deterministic for a given rng state).
func draw(rng: PCG32, rank: int, flags: Dictionary) -> Dictionary:
	var pool: Array = eligible(rank, flags)
	if pool.is_empty():
		return {}
	var total: float = 0.0
	for e in pool:
		total += float(e.get("weight", 1))
	var pick: float = rng.next_float() * total
	var acc: float = 0.0
	for e in pool:
		acc += float(e.get("weight", 1))
		if pick < acc:
			return e
	return pool[pool.size() - 1]


func choice_by_id(event: Dictionary, choice_id: String) -> Dictionary:
	for ch in event.get("choices", []):
		if String(ch["id"]) == choice_id:
			return ch
	return {}