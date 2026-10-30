extends SceneTree

## Balance-bot skeleton (spec §17.2). For now it measures the *steady-state
## rate* of a single line across the rank checkpoints of §8.13, using the free
## flow and a placeholder crew power that scales with rank. Economy-driven
## progression (purchases, upgrades, prestige) is added with M4.
##
## Run:  godot --headless --path <project> -s tools/balance_bot.gd

## rank -> active seconds to reach it (spec §8.13).
const CHECKPOINTS: Dictionary = {
	2: 5 * 60, 3: 12 * 60, 5: 25 * 60, 8: 55 * 60, 10: 90 * 60,
}
const MAX_SECONDS: float = 8 * 3600.0
const SIM_DT: float = 1.0
const SHIFT_S: float = 300.0

var cat: Catalog
var crew: Crew
var rules: Rules
var gen: Generator
var syn: Synergy
var grid: TerminalGrid
var board: HireBoard
var line: LineSim
var shift: Shift
var roster: Array = []
var credits: float = 200.0
var rep: float = 0.0
var rank: int = 1
var reached: Dictionary = {}


func _j(n: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % n))


func _init() -> void:
	cat = Catalog.from_dicts(_j("cargo"), _j("balance"))
	crew = Crew.from_dicts(_j("classes"), _j("balance"))
	rules = Rules.from_data(_j("classes"), _j("species"), _j("stars"), _j("psycho"),
		_j("synergy"), _j("rarity"), _j("traits"), _j("skills"), _j("names"))
	gen = Generator.new(rules)
	syn = Synergy.new(rules)
	grid = TerminalGrid.from_data(_j("sectors"))
	grid.starting_setup()
	board = HireBoard.new(rules, gen, 0)
	board.refresh(6, 0)

	var srng := PCG32.new(1, 999)
	for cls in ["loader", "loader", "driver", "storekeeper"]:
		roster.append(gen.create_worker(srng, gen.next_rarity(srng, 0), { "class": cls }))

	_build_line()
	_start_shift()

	print("=== balance_bot: greedy progression ===")
	var t: float = 0.0
	while t < MAX_SECONDS and rank < 20:
		shift.tick(SIM_DT)
		t += SIM_DT
		if shift.state == Shift.State.REPORT:
			_on_shift()
		if int(t) % 10 == 0:
			_try_buy()
		_record(t)

	print("rank  reached(s)  target(s)  ratio   (targets are §8.13 'active' times)")
	var keys: Array = CHECKPOINTS.keys()
	keys.sort()
	for r in keys:
		if reached.has(r):
			print("  %2d   %8.0f    %6d    %.2f" % [r, reached[r], CHECKPOINTS[r], reached[r] / float(CHECKPOINTS[r])])
		else:
			print("  %2d   NOT REACHED (target %ds)" % [r, CHECKPOINTS[r]])
	print("final: rank %d, credits %s at t=%.0fs" % [rank, Fmt.num(credits), t])
	quit(0)


func _build_line() -> void:
	line = LineSim.create(cat)
	line.q0_cap = float(cat.balance.get("q0_cap", 60.0))


func _recompute() -> void:
	var dock: int = grid.dock_level()
	line.b1_cap = float(cat.balance.get("b1_cap_per_level", 100.0)) * dock
	line.b2_cap = float(cat.balance.get("b2_cap_base", 150.0)) \
		* pow(float(cat.balance.get("b2_cap_growth", 1.18)), grid.storage_level() - 1)
	line.tariff = cat.tariff(rank)
	line.set_inflow(cat.free_flow_lambda(rank, dock), cat.free_flow_mix(rank))
	shift.rank = rank
	var speed: float = syn.speed_mult(syn.line_synergy(roster))
	shift.set_base_rates(
		cat.station_rate("unload", dock, _power("unload")) * speed,
		cat.station_rate("move", dock, _power("move")) * speed,
		cat.station_rate("store", dock, _power("store")) * speed)


func _start_shift() -> void:
	shift = Shift.new(line, SHIFT_S)
	_recompute()
	shift.start()


func _assign(w: Worker) -> String:
	match w.class_id:
		"loader", "crane":
			return "unload"
		"driver":
			return "move"
		"storekeeper":
			return "store"
		_:
			return "unload"


func _power(station: String) -> float:
	var entries: Array = []
	for w in roster:
		if _assign(w) == station:
			entries.append(w.as_crew_entry(rules))
	return crew.station_power(station, entries)


func _sector(type_id: String) -> Sector:
	for s in grid.sectors:
		if s.type_id == type_id:
			return s
	return null


func _on_shift() -> void:
	var report: Dictionary = shift.report()
	credits += report["credits"]
	rep += report["rep"]
	rep += 4.0  # models playing a contract every shift (spec §9 rep driver)
	for w in roster:
		credits -= w.wage
	while rep >= round(12.0 * pow(1.5, rank)):
		rank += 1
	_start_shift()


func _try_buy() -> void:
	var best_kind: String = ""
	var best_cost: float = INF
	var dock: Sector = _sector("dock")
	var store: Sector = _sector("storage")
	if dock != null and grid.can_upgrade(dock) and grid.upgrade_cost(dock) < best_cost:
		best_cost = grid.upgrade_cost(dock)
		best_kind = "dock"
	if store != null and grid.can_upgrade(store) and grid.upgrade_cost(store) < best_cost:
		best_cost = grid.upgrade_cost(store)
		best_kind = "storage"
	if roster.size() < 8 and not board.pool.is_empty():
		var hc: float = board.hire_cost(board.pool[0])
		if hc < best_cost:
			best_cost = hc
			best_kind = "hire"
	if best_kind == "" or credits < best_cost:
		return
	credits -= best_cost
	match best_kind:
		"dock":
			grid.upgrade(dock)
		"storage":
			grid.upgrade(store)
		"hire":
			roster.append(board.take(board.pool[0].id))
	_recompute()


func _record(t: float) -> void:
	for r in range(1, rank + 1):
		if CHECKPOINTS.has(r) and not reached.has(r):
			reached[r] = t