class_name TerminalGrid
extends RefCounted

## The terminal's cross-section grid: sectors, upgrades, roguelike expansion and
## adjacency (spec §5). Pure model — no nodes, headless-testable.

var data: Dictionary = {}          # full sectors.json
var sectors: Array = []            # Array[Sector]
var expansion_count: int = 0

var starting_cols: int = 3
var starting_rows: int = 2
var max_cols: int = 9
var max_rows: int = 7


static func from_data(sectors_tbl: Dictionary) -> TerminalGrid:
	var t := TerminalGrid.new()
	t.data = sectors_tbl
	var sg: Dictionary = sectors_tbl.get("starting_grid", {})
	t.starting_cols = int(sg.get("cols", 3))
	t.starting_rows = int(sg.get("rows", 2))
	var gm: Dictionary = sectors_tbl.get("grid_max", {})
	t.max_cols = int(gm.get("cols", 9))
	t.max_rows = int(gm.get("rows", 7))
	return t


func starting_setup() -> void:
	sectors.clear()
	expansion_count = 0
	add_sector("dock", 0, 0)
	add_sector("storage", 2, 0)
	add_sector("office", 0, 1)
	add_sector("dorm", 1, 1)


# ---------------------------------------------------------------- lookups

func to_state() -> Dictionary:
	var arr: Array = []
	for s in sectors:
		arr.append(s.to_dict())
	return { "sectors": arr, "expansion_count": expansion_count }


func load_state(d: Dictionary) -> void:
	sectors.clear()
	for row in d.get("sectors", []):
		var s := Sector.from_dict(row)
		var type_def: Dictionary = type_row(s.type_id)
		if not type_def.is_empty() and type_def.has("size"):
			var szv: Variant = type_def["size"]
			s.size = szv if szv is Vector2i else Vector2i(int(szv[0]), int(szv[1]))
		sectors.append(s)
	expansion_count = int(d.get("expansion_count", 0))


func type_row(type_id: String) -> Dictionary:
	for row in data.get("sectors", []):
		if row["id"] == type_id:
			return row
	return {}


func modifier_row(modifier_id: String) -> Dictionary:
	for row in data.get("modifiers", []):
		if row["id"] == modifier_id:
			return row
	return {}


func modifier_effect(modifier_id: String) -> Dictionary:
	return modifier_row(modifier_id).get("effect", {})


# ---------------------------------------------------------------- grid

func unlocked_cols() -> int:
	return clampi(starting_cols + int(expansion_count / 2.0), starting_cols, max_cols)


func unlocked_rows() -> int:
	return clampi(starting_rows + int(expansion_count / 3.0), starting_rows, max_rows)


func cell_occupied(cell: Vector2i) -> bool:
	for s in sectors:
		if cell in s.cells():
			return true
	return false


func fits(size: Vector2i, col: int, row: int) -> bool:
	if col < 0 or row < 0:
		return false
	if col + size.x > unlocked_cols() or row + size.y > unlocked_rows():
		return false
	for x in size.x:
		for y in size.y:
			if cell_occupied(Vector2i(col + x, row + y)):
				return false
	return true


func find_position(type_id: String) -> Vector2i:
	var row: Dictionary = type_row(type_id)
	if row.is_empty():
		return Vector2i(-1, -1)
	var size := Vector2i(int(row["size"][0]), int(row["size"][1]))
	for f in unlocked_rows():
		for c in unlocked_cols():
			if fits(size, c, f):
				return Vector2i(c, f)
	return Vector2i(-1, -1)


func add_sector(type_id: String, col: int, row: int, modifier_id: String = "none") -> Sector:
	var row_data: Dictionary = type_row(type_id)
	var size := Vector2i(1, 1)
	if not row_data.is_empty():
		size = Vector2i(int(row_data["size"][0]), int(row_data["size"][1]))
	var s := Sector.new(type_id, col, row, size)
	s.modifier_id = modifier_id
	sectors.append(s)
	return s


# ---------------------------------------------------------------- levels

func dock_level() -> int:
	return maxi(_max_level("dock"), 1)


func storage_level() -> int:
	return maxi(_max_level("storage"), 1)


func _max_level(type_id: String) -> int:
	var lvl: int = 0
	for s in sectors:
		if s.type_id == type_id:
			lvl = maxi(lvl, s.level)
	return lvl


# ---------------------------------------------------------------- upgrades

func upgrade_cost(sector: Sector) -> float:
	var row: Dictionary = type_row(sector.type_id)
	var base: float = float(row.get("build_cost", 0))
	var g: float = float(row.get("g", 1.5))
	var cost: float = base * 0.5 * pow(g, sector.level - 1)
	var eff: Dictionary = modifier_effect(sector.modifier_id)
	cost *= (1.0 + float(eff.get("upgrade_discount", 0.0)))
	return cost


func upgrade_time(sector: Sector) -> float:
	var up: Dictionary = data.get("upgrade", {})
	if sector.level < int(up.get("instant_below", 5)):
		return 0.0
	return float(up.get("time_base", 30.0)) * pow(float(up.get("time_growth", 1.3)), sector.level - 5)


func max_level(sector: Sector) -> int:
	return int(type_row(sector.type_id).get("max_level", 30))


func can_upgrade(sector: Sector) -> bool:
	if sector == null:
		return false
	# Already under construction — do not charge again / reset the timer.
	if sector.is_building():
		return false
	return sector.level < max_level(sector) and not sector.broken


## Returns true if the upgrade was paid for. Timers are applied by the caller.
func upgrade(sector: Sector) -> bool:
	if not can_upgrade(sector):
		return false
	var t: float = upgrade_time(sector)
	if t > 0.0:
		sector.build_time_left = t
		return true
	sector.level += 1
	return true


func finish_construction(sector: Sector) -> void:
	sector.level += 1
	sector.build_time_left = 0.0


# ---------------------------------------------------------------- expansion

func expand_cost() -> float:
	var ex: Dictionary = data.get("expansion", {})
	var base: float = float(ex.get("base_cost", 400))
	var growth: float = float(ex.get("growth", 2.1))
	return base * pow(growth, expansion_count)


func expand_rank_required() -> int:
	var ex: Dictionary = data.get("expansion", {})
	var base: int = int(ex.get("rank_base", 2))
	var div: int = int(ex.get("rank_div", 2))
	return base + int(expansion_count / float(div))


func reroll_cost(reroll_index: int) -> float:
	var ex: Dictionary = data.get("expansion", {})
	return float(ex.get("reroll_base", 0.15)) * expand_cost() * pow(float(ex.get("reroll_growth", 2.0)), reroll_index)


## Deterministic set of expansion offers (type + modifier + position).
func roll_offers(rng: PCG32, rank: int, count: int = 3) -> Array:
	var unlocked: Array = []
	for row in data.get("sectors", []):
		if int(row.get("rank", 1)) <= rank:
			unlocked.append(row)
	var offers: Array = []
	if unlocked.is_empty():
		return offers
	for i in count:
		var row: Dictionary = unlocked[rng.next_bounded(unlocked.size())]
		var mod_id: String = _roll_modifier(rng)
		var pos: Vector2i = find_position(row["id"])
		offers.append({
			"type_id": row["id"], "modifier_id": mod_id,
			"col": pos.x, "floor": pos.y,
		})
	return offers


func apply_offer(offer: Dictionary) -> Sector:
	var s := add_sector(offer["type_id"], int(offer["col"]), int(offer["floor"]), offer.get("modifier_id", "none"))
	expansion_count += 1
	return s


func _roll_modifier(rng: PCG32) -> String:
	var list: Array = data.get("modifiers", [])
	var total: float = 0.0
	for row in list:
		total += float(row.get("weight", 1))
	var pick: float = rng.next_float() * total
	var acc: float = 0.0
	for row in list:
		acc += float(row.get("weight", 1))
		if pick < acc:
			return String(row["id"])
	return "none"


# ---------------------------------------------------------------- adjacency

func adjacent(a: Sector, b: Sector) -> bool:
	for ca in a.cells():
		for cb in b.cells():
			if absi(ca.x - cb.x) + absi(ca.y - cb.y) == 1:
				return true
	return false


func adjacency_bonus(a: Sector, b: Sector) -> Dictionary:
	if not adjacent(a, b):
		return {}
	var pair: Array = [a.type_id, b.type_id]
	pair.sort()
	return data.get("adjacency", {}).get(pair[0] + "+" + pair[1], {})