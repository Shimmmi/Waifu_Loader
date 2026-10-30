class_name Catalog
extends RefCounted

## Parses the cargo and balance JSON tables into flat, typed arrays that the
## Sim can index cheaply (spec §2.6, §8.3). Pure data — no nodes, no autoloads,
## so it works in headless tests and on the server validator.

var ids: PackedStringArray = []
var price: PackedFloat32Array = []
var phi_unload: PackedFloat32Array = []
var phi_move: PackedFloat32Array = []
var phi_store: PackedFloat32Array = []
var defect: PackedFloat32Array = []

## cargo id -> index
var index: Dictionary = {}
## raw balance table
var balance: Dictionary = {}

## Station names, fixed order.
const STATIONS: Array[String] = ["unload", "move", "store"]


static func from_dicts(cargo: Dictionary, bal: Dictionary) -> Catalog:
	var c := Catalog.new()
	var rows: Array = cargo.get("cargo", [])
	for row in rows:
		var id: String = String(row["id"])
		c.index[id] = c.ids.size()
		c.ids.append(id)
		c.price.append(float(row.get("price", 0.0)))
		var phi: Dictionary = row.get("phi", {})
		c.phi_unload.append(float(phi.get("unload", 1.0)))
		c.phi_move.append(float(phi.get("move", 1.0)))
		c.phi_store.append(float(phi.get("store", 1.0)))
		c.defect.append(float(row.get("defect", 0.0)))
	c.balance = bal
	return c


func size() -> int:
	return ids.size()


## Build a per-type share vector from a {id: fraction} dict.
func mix_from(spec: Dictionary) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(size())
	for id in spec:
		if index.has(id):
			m[index[id]] = float(spec[id])
	return m


## Arrival mix for the free (baseline) flow at a given terminal rank (spec §8.5).
func free_flow_mix(rank: int) -> PackedFloat32Array:
	var normal := 0.85
	var fragile := 0.15
	var heavy := 0.0
	var perishable := 0.0
	var dangerous := 0.0
	var oversize := 0.0
	if rank >= 10:
		heavy = 0.10
		normal -= heavy
	if rank >= 14:
		perishable = 0.10
		normal -= perishable
	if rank >= 18:
		dangerous = 0.08
		normal -= dangerous
	if rank >= 26:
		oversize = 0.06
		normal -= oversize
	return mix_from({
		"normal": maxf(normal, 0.0),
		"fragile": fragile,
		"heavy": heavy,
		"perishable": perishable,
		"dangerous": dangerous,
		"oversize": oversize,
	})


## Baseline arrival rate, t/min (spec §8.5).
func free_flow_lambda(rank: int, dock_level: int) -> float:
	var base: float = float(balance.get("free_flow_base", 6.0))
	var growth: float = float(balance.get("free_flow_growth", 1.1))
	var rank_bonus: float = float(balance.get("free_flow_rank_bonus", 0.02))
	return base * pow(growth, dock_level - 1) * (1.0 + rank_bonus * (rank - 1))


## Income tariff by rank: 1.18^(rank-1) (spec §8.3).
func tariff(rank: int) -> float:
	return pow(float(balance.get("tariff_base", 1.18)), rank - 1)


## Station speed in t/min (spec §8.3):
##   R_s = (auto_s * g^(L-1) + base_s * power_s) * modifier
func station_rate(station: String, dock_level: int, power: float, modifier: float = 1.0) -> float:
	var auto_table: Dictionary = balance.get("auto_rate", {})
	var base_table: Dictionary = balance.get("base_rate", {})
	var growth: float = float(balance.get("auto_rate_growth", 1.12))
	var auto: float = float(auto_table.get(station, 0.0)) * pow(growth, dock_level - 1)
	var base: float = float(base_table.get(station, 0.0)) * power
	return (auto + base) * modifier