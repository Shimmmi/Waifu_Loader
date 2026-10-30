extends Node

## Autoload "GameState" — the live game model the View observes (spec §2.4).
##
## M2 scope: one line, credits/parts/reputation/rank, a running shift and the
## Rush action. It owns no nodes and never touches the UI; the Terminal screen
## subscribes to `stats_changed`.

signal stats_changed
signal shift_finished(report: Dictionary)
signal roster_changed
signal worker_changed(worker_id: String)
signal board_changed
signal contracts_changed
signal event_shown
signal event_resolved
signal line_event(line_id: int, type: String, payload: Dictionary)
signal tab_requested(tab_id: String)

const SIM_DT: float = 1.0

## Starting wallet. TEMP >0 so the Hire flow is demoable; the spec starts at 0
## and earns via shifts (the economy lands in M4).
var credits: float = 200.0
var parts: float = 0.0
var rep: float = 0.0
var rank: int = 1

var catalog: Catalog
var crew: Crew
var rules: Rules
var generator: Generator
var board: HireBoard
var synergy: Synergy
var grid: TerminalGrid
var contracts: ContractBoard
var events: EventDeck
var chains: Dictionary = {}
var active_contract: Contract = null
var last_contract_result: Dictionary = {}
var active_effects: Array = []       # [{station|flow, mult, expires}]
var event_active: Dictionary = {}
var _event_remaining: float = 0.0
var _contract_base_stored: float = 0.0
var _clock_s: float = 0.0

var tree: CorporateTree
var elevator: Elevator
var ach: Achievements
var dirs: Directives
var chain_runtime: ChainRuntime
var relations: Relations
var directives_board: DirectiveBoard
var shop: Shop
var tokens: float = 0.0
var shares: int = 0
var tree_levels: Dictionary = {}
var achievements_done: Dictionary = {}
var lifetime_tonnes: float = 0.0
var run_tonnes: float = 0.0
var reorg_count: int = 0
var counters: Dictionary = {}
var cosmetics_owned: Array = []
var cosmetics_equipped: Dictionary = {}
var locale: String = "ru"
var muted: bool = false
var anon_stats: bool = true
var tutorial_seen: bool = false
var online: bool = true

var line: LineSim
var shift: Shift
var last_report: Dictionary = {}
var roster: Array = []          # Array[Worker]
## slot id -> worker id ("" = empty). Slots per station (spec §8.2, simplified).
var slots: Dictionary = {}
const STATION_SLOTS: Dictionary = { "unload": 3, "move": 2, "store": 2, "support": 2 }

var _accum: float = 0.0
var _construction_ui_accum: float = 0.0


func _ready() -> void:
	catalog = Catalog.from_dicts(Data.table("cargo"), Data.table("balance"))
	crew = Crew.from_dicts(Data.table("classes"), Data.table("balance"))
	rules = Rules.from_data(Data.table("classes"), Data.table("species"), Data.table("stars"),
		Data.table("psycho"), Data.table("synergy"), Data.table("rarity"),
		Data.table("traits"), Data.table("skills"), Data.table("names"))
	generator = Generator.new(rules)
	synergy = Synergy.new(rules)
	board = HireBoard.new(rules, generator, 0)
	grid = TerminalGrid.from_data(Data.table("sectors"))
	grid.starting_setup()
	contracts = ContractBoard.new(Data.table("contracts"), (Data.table("clients") as Dictionary)["clients"], catalog)
	events = EventDeck.new(Data.table("events"))
	for ch in (Data.table("chains") as Dictionary)["chains"]:
		chains[ch["id"]] = ch
	tree = CorporateTree.from_data(Data.table("tree"))
	elevator = Elevator.from_data(Data.table("elevator"))
	ach = Achievements.from_data(Data.table("achievements"))
	dirs = Directives.from_data(Data.table("directives"))
	chain_runtime = ChainRuntime.from_data(Data.table("chains"))
	relations = Relations.new()
	shop = Shop.from_data(Data.table("cosmetics"))
	directives_board = DirectiveBoard.from_data(dirs, Rng.stream("directive"), 0, 3, 2)
	_load_settings()
	roster = _make_starting_roster()
	board.refresh(6, 0)
	_init_slots()
	_build_line()
	_start_next_shift()
	auto_assign()
	_refresh_contracts()
	_load_state_if_any()


func _process(delta: float) -> void:
	_clock_s += delta
	_tick_construction(delta)
	_tick_effects()
	_tick_event(delta)
	_tick_contract(delta)
	if shift == null or not shift.is_running():
		return
	_accum += delta
	while _accum >= SIM_DT:
		_accum -= SIM_DT
		shift.tick(SIM_DT)
		stats_changed.emit()
		if shift.state == Shift.State.REPORT:
			_on_shift_finished()
			break


func _tick_construction(delta: float) -> void:
	var changed: bool = false
	var building: bool = false
	for s in grid.sectors:
		if s.build_time_left > 0.0:
			building = true
			s.build_time_left = maxf(0.0, s.build_time_left - delta)
			if s.build_time_left == 0.0:
				grid.finish_construction(s)
				changed = true
	if changed:
		_construction_ui_accum = 0.0
		_recompute_line()
		save_game()
		stats_changed.emit()
	elif building:
		# Refresh HUD/tiles so the countdown is visible even between shift ticks.
		_construction_ui_accum += delta
		if _construction_ui_accum >= 0.25:
			_construction_ui_accum = 0.0
			stats_changed.emit()


## Try to trigger the Rush burst. Returns true if it fired.
func rush() -> bool:
	var fired: bool = shift != null and shift.rush()
	if fired:
		_bump("rushes")
		_report("rushes")
		Audio.play_sfx("rush")
		stats_changed.emit()
	return fired


func rep_needed(for_rank: int) -> float:
	return round(12.0 * pow(1.5, for_rank - 1))


func _build_line() -> void:
	line = LineSim.create(catalog)
	line.q0_cap = float(catalog.balance.get("q0_cap", 60.0))
	line.tariff = catalog.tariff(rank)
	shift = Shift.new(line, Config.SHIFT_S)
	_recompute_line()


## Re-apply dock/storage-derived capacities, arrival and station rates.
func _recompute_line() -> void:
	var dock: int = grid.dock_level()
	line.b1_cap = float(catalog.balance.get("b1_cap_per_level", 100.0)) * dock
	line.b2_cap = float(catalog.balance.get("b2_cap_base", 150.0)) \
		* pow(float(catalog.balance.get("b2_cap_growth", 1.18)), grid.storage_level() - 1)
	line.income_mult = 1.0 + tree_effect("income") + Meta.shares_income_bonus(shares)
	if active_contract == null:
		line.set_inflow(catalog.free_flow_lambda(rank, dock) * _flow_mult() * (1.0 + tree_effect("flow")), catalog.free_flow_mix(rank))
	_recompute_rates()


func _make_starting_roster() -> Array:
	var starter: Array = ["loader", "loader", "driver", "storekeeper"]
	var g := Generator.new(rules)
	var rng := PCG32.new(1, 999)
	var out: Array = []
	for cls in starter:
		out.append(g.create_worker(rng, g.next_rarity(rng, 0), { "class": cls }))
	return out


## Best-fit station for a worker's class (spec §6.3).
func _assign(worker: Worker) -> String:
	match worker.class_id:
		"loader", "crane":
			return "unload"
		"driver":
			return "move"
		"storekeeper":
			return "store"
		_:
			return "unload"


func _init_slots() -> void:
	slots.clear()
	for station in STATION_SLOTS:
		for i in int(STATION_SLOTS[station]):
			slots["%s%d" % [station, i]] = ""


func worker_by_id(worker_id: String) -> Worker:
	for w in roster:
		if w.id == worker_id:
			return w
	return null


## Workers currently placed on the line, in slot order.
func assigned_workers() -> Array:
	var out: Array = []
	for slot_id in slots:
		if slots[slot_id] != "":
			var w: Worker = worker_by_id(slots[slot_id])
			if w != null:
				out.append(w)
	return out


func station_workers(station: String) -> Array:
	var out: Array = []
	for i in int(STATION_SLOTS.get(station, 0)):
		var wid: String = slots.get("%s%d" % [station, i], "")
		if wid != "":
			var w: Worker = worker_by_id(wid)
			if w != null:
				out.append(w)
	return out


## Place a worker in a slot (removing them from any other slot).
func assign(slot_id: String, worker_id: String) -> void:
	for k in slots:
		if slots[k] == worker_id:
			slots[k] = ""
	slots[slot_id] = worker_id
	_recompute_line()
	roster_changed.emit()
	stats_changed.emit()


func clear_slot(slot_id: String) -> void:
	slots[slot_id] = ""
	_recompute_line()
	roster_changed.emit()
	stats_changed.emit()


## Auto-fill slots from the roster by class fit (starting layout).
func auto_assign() -> void:
	_init_slots()
	for w in roster:
		var station: String = _assign(w)
		for i in int(STATION_SLOTS.get(station, 0)):
			var sid: String = "%s%d" % [station, i]
			if slots[sid] == "":
				slots[sid] = w.id
				break
	_recompute_line()
	roster_changed.emit()
	stats_changed.emit()


func available_skill_tier(w: Worker) -> int:
	if w.level >= 30 and not w.skills.has(3):
		return 3
	if w.level >= 15 and not w.skills.has(2):
		return 2
	if w.level >= 5 and not w.skills.has(1):
		return 1
	return 0


func skill_options(w: Worker, tier: int) -> Array:
	var by_class: Dictionary = rules.skills.get(w.class_id, {})
	return by_class.get(tier, [])


func choose_skill(w: Worker, tier: int, skill_id: String) -> void:
	w.skills[tier] = skill_id
	roster_changed.emit()
	stats_changed.emit()


func _recompute_rates() -> void:
	var dock: int = grid.dock_level()
	var speed: float = synergy.speed_mult(synergy.line_synergy(assigned_workers()))
	shift.rank = rank
	var tree_speed: float = 1.0 + tree_effect("station_speed")
	shift.set_base_rates(
		catalog.station_rate("unload", dock, _power("unload")) * speed * _station_mult("unload") * tree_speed,
		catalog.station_rate("move", dock, _power("move")) * speed * _station_mult("move") * tree_speed,
		catalog.station_rate("store", dock, _power("store")) * speed * _station_mult("store") * tree_speed)


func _power(station: String) -> float:
	var entries: Array = []
	for w in station_workers(station):
		entries.append(w.as_crew_entry(rules))
	return crew.station_power(station, entries)


func _start_next_shift() -> void:
	_recompute_rates()
	shift.start()
	_maybe_trigger_event()


## Roster bed capacity from dorm levels (base 5 + 2 per dorm level).
func roster_capacity() -> int:
	var cap: int = 5
	for s in grid.sectors:
		if s.type_id == "dorm" and s.build_time_left <= 0.0:
			cap += 2 * maxi(s.level, 1)
	return cap


## Empty string if hire is allowed; otherwise a localized reason (v0.2 §2.7).
func hire_block_reason(worker_id: String) -> String:
	var w: Worker = null
	for c in board.pool:
		if c.id == worker_id:
			w = c
			break
	if w == null:
		return Loc.t("hire.need_slot")
	if roster.size() >= roster_capacity():
		return Loc.t("hire.roster_full")
	var cost: float = board.hire_cost(w)
	if credits < cost:
		return Loc.t("hire.need_credits", [Fmt.num(cost - credits)])
	return ""


func hire(worker_id: String) -> bool:
	if hire_block_reason(worker_id) != "":
		return false
	var w: Worker = null
	for c in board.pool:
		if c.id == worker_id:
			w = c
			break
	if w == null:
		return false
	var cost: float = board.hire_cost(w)
	credits -= cost
	board.take(worker_id)
	roster.append(w)
	_bump("hires")
	_report("hires")
	Audio.play_sfx("hire")
	_recompute_rates()
	save_game()
	roster_changed.emit()
	worker_changed.emit(w.id)
	board_changed.emit()
	stats_changed.emit()
	return true


## Open a bottom-nav tab by id (terminal/loading/crew/hire/contracts/world/menu).
func request_tab(tab_id: String) -> void:
	tab_requested.emit(tab_id)


func post_advert() -> void:
	var cost: float = board.posting_cost(rank)
	if credits < cost:
		return
	credits -= cost
	board.paid_refreshes_this_hour += 1
	board.refresh(6, 0)
	board_changed.emit()
	stats_changed.emit()


func upgrade_sector(s: Sector) -> bool:
	if s == null or not grid.can_upgrade(s):
		return false
	var cost: float = grid.upgrade_cost(s)
	if credits < cost:
		return false
	credits -= cost
	grid.upgrade(s)
	_bump("upgrades")
	_report("upgrades")
	_recompute_line()
	save_game()
	stats_changed.emit()
	return true


func sector_of_type(type_id: String) -> Sector:
	for s in grid.sectors:
		if s.type_id == type_id:
			return s
	return null


func can_expand() -> bool:
	return rank >= grid.expand_rank_required() and credits >= grid.expand_cost()


func expand_offers() -> Array:
	var rng := PCG32.new(7919 * (grid.expansion_count + 1) + 5, grid.expansion_count + 1)
	return grid.roll_offers(rng, rank, 3)


func apply_expansion(offer: Dictionary) -> bool:
	if rank < grid.expand_rank_required() or credits < grid.expand_cost():
		return false
	credits -= grid.expand_cost()
	grid.apply_offer(offer)
	_bump("expansions")
	_report("expansions")
	_recompute_line()
	save_game()
	stats_changed.emit()
	return true


# ---------------------------------------------------------------- contracts

func _grid_max_level(type_id: String) -> int:
	var lvl: int = 0
	for s in grid.sectors:
		if s.type_id == type_id:
			lvl = maxi(lvl, s.level)
	return lvl


func _flow_est() -> float:
	var dock: int = grid.dock_level()
	var r1: float = catalog.station_rate("unload", dock, _power("unload")) * _station_mult("unload")
	var r2: float = catalog.station_rate("move", dock, _power("move")) * _station_mult("move")
	var r3: float = catalog.station_rate("store", dock, _power("store")) * _station_mult("store")
	return maxf(1.0, minf(line.lambda, minf(r1, minf(r2, r3))))


func _refresh_contracts() -> void:
	var count: int = 4 + int(floor(_grid_max_level("dispatch") / 2.0))
	contracts.refresh(Rng.stream("contract"), rank, catalog.tariff(rank), _flow_est(), count)
	contracts_changed.emit()


func accept_contract(contract_id: String) -> bool:
	if active_contract != null:
		return false
	var c: Contract = contracts.take(contract_id)
	if c == null:
		return false
	c.delivered = 0.0
	c.elapsed_min = 0.0
	active_contract = c
	contracts.active.append(c)
	_contract_base_stored = line.stored
	var lam: float = c.q / (0.7 * maxf(c.deadline_min, 1.0))
	line.set_inflow(lam, catalog.mix_from(c.cargo_mix))
	contracts_changed.emit()
	stats_changed.emit()
	return true


func _tick_contract(delta: float) -> void:
	if active_contract == null:
		return
	active_contract.delivered = line.stored - _contract_base_stored
	active_contract.elapsed_min += delta / 60.0
	if active_contract.delivered >= active_contract.q:
		_finish_contract()
	elif active_contract.elapsed_min >= active_contract.deadline_min:
		_finish_contract()


func _finish_contract() -> void:
	var c: Contract = active_contract
	var crew_list: Array = assigned_workers()
	var classes: Array = []
	for w in crew_list:
		classes.append(w.class_id)
	var syn: float = synergy.line_synergy(crew_list)
	var waste_frac: float = line.waste / maxf(line.stored + line.waste, 1e-9)
	var g: String = c.grade(waste_frac, 0, syn, classes)
	var mult: float = c.grade_mult(g)
	if g == "fail":
		rep = maxf(rep_needed(rank), rep - float(c.penalty["rep"]))
		credits -= float(c.penalty["credits"])
	else:
		credits += float(c.reward["credits"]) * mult
		rep += float(c.reward["rep"]) * mult
		parts += float(c.reward["parts"]) * mult
	last_contract_result = { "grade": g, "id": c.id, "mult": mult }
	_bump("contracts_done")
	_report("contracts_done")
	if g == "gold":
		_bump("gold_contracts")
		_report("gold_contracts")
	if c.client_id != "":
		relations.adjust(c.client_id, Relations.delta_for_grade(g))
	_check_achievements()
	active_contract = null
	contracts.active.erase(c)
	_restore_free_flow()
	contracts_changed.emit()
	stats_changed.emit()


func _restore_free_flow() -> void:
	line.set_inflow(catalog.free_flow_lambda(rank, grid.dock_level()) * _flow_mult() * (1.0 + tree_effect("flow")), catalog.free_flow_mix(rank))


# ---------------------------------------------------------------- events

func _maybe_trigger_event() -> void:
	if rank < 6 or not event_active.is_empty():
		return
	_start_chains()
	var ce: Dictionary = _chain_event()
	if not ce.is_empty():
		event_active = ce
		_event_remaining = float(ce.get("auto_resolve_s", 60))
		_bump("events_seen")
		event_shown.emit()
		return
	var flags: Dictionary = { "sectors": [], "cargo": [], "active_contract": active_contract != null }
	for s in grid.sectors:
		flags["sectors"].append(s.type_id)
	var e: Dictionary = events.draw(Rng.stream("event"), rank, flags)
	if e.is_empty():
		return
	event_active = e
	_event_remaining = float(e.get("auto_resolve_s", 60))
	_bump("events_seen")
	event_shown.emit()


func event_choice(choice_id: String) -> void:
	if event_active.is_empty():
		return
	if String(event_active.get("id", "")).begins_with("chain_"):
		_resolve_chain_choice(String(event_active["id"]).substr(6), choice_id)
		return
	var ch: Dictionary = events.choice_by_id(event_active, choice_id)
	if ch.is_empty():
		ch = events.choice_by_id(event_active, String(event_active.get("default_choice", "")))
	if not ch.is_empty() and _pay_cost(ch.get("cost", {})):
		if _passes_check(ch.get("check", {})):
			_apply_effects(ch.get("effects", []))
	event_active = {}
	_recompute_line()
	event_resolved.emit()
	stats_changed.emit()


func _tick_event(delta: float) -> void:
	if event_active.is_empty():
		return
	_event_remaining -= delta
	if _event_remaining <= 0.0:
		event_choice(String(event_active.get("default_choice", "")))


func _tick_effects() -> void:
	if active_effects.is_empty():
		return
	var keep: Array = []
	var changed: bool = false
	for e in active_effects:
		if float(e.get("expires", 0.0)) > _clock_s:
			keep.append(e)
		else:
			changed = true
	if changed:
		active_effects = keep
		_recompute_line()


func _station_mult(station: String) -> float:
	var m: float = 1.0
	for e in active_effects:
		if e.has("station") and (String(e["station"]) == "all" or String(e["station"]) == station):
			m *= float(e["mult"])
	return m


func _flow_mult() -> float:
	var m: float = 1.0
	for e in active_effects:
		if e.has("flow"):
			m *= float(e["mult"])
	return m


func _pay_cost(cost: Dictionary) -> bool:
	if cost.is_empty():
		return true
	if cost.has("credits_per_rank"):
		var cc: float = float(cost["credits_per_rank"]) * rank
		if credits < cc:
			return false
		credits -= cc
	if cost.has("credits_frac"):
		credits -= credits * float(cost["credits_frac"])
	if cost.has("parts"):
		var p: float = float(cost["parts"])
		if parts < p:
			return false
		parts -= p
	return true


func _passes_check(check: Dictionary) -> bool:
	if check.is_empty():
		return true
	var stat: String = String(check.get("stat", ""))
	var dc: float = float(check.get("dc", 0))
	var best: float = 0.0
	for w in assigned_workers():
		best = maxf(best, float(w.stats(rules).get(stat, 0.0)))
	var p: float = clampf(0.5 + (best - dc) / 100.0, 0.05, 0.95)
	return Rng.stream("event").next_float() < p


func _apply_effects(effects: Array) -> void:
	for e in effects:
		match String(e.get("type", "")):
			"morale":
				_delta_morale(String(e.get("target", "all")), float(e.get("delta", 0)))
			"credits":
				credits += float(e.get("delta", 0))
			"credits_per_rank":
				credits += float(e.get("value", 0)) * rank
			"parts":
				parts += float(e.get("delta", 0))
			"rep":
				rep += float(e.get("delta", 0))
			"fatigue":
				_delta_fatigue(String(e.get("target", "all")), float(e.get("delta", 0)))
			"mod_station":
				active_effects.append({ "station": String(e.get("station", "all")), "mult": float(e.get("mult", 1.0)), "expires": _clock_s + float(e.get("dur", 60)) })
			"mod_flow":
				active_effects.append({ "flow": true, "mult": float(e.get("mult", 1.0)), "expires": _clock_s + float(e.get("dur", 60)) })
			"sector_break":
				_break_sector(String(e.get("sector", "random")))
			"status":
				_status(String(e.get("target", "random")), String(e.get("status", "injured")))
			"worker_gain":
				_grant_worker(int(e.get("rarity", 2)))
			_:
				pass


func _delta_morale(target: String, delta: float) -> void:
	if target == "all":
		for w in roster:
			w.morale = clampf(w.morale + delta, 0.0, 100.0)
	elif target == "random" and not roster.is_empty():
		var w: Worker = roster[Rng.stream("event").next_bounded(roster.size())]
		w.morale = clampf(w.morale + delta, 0.0, 100.0)


func _delta_fatigue(target: String, delta: float) -> void:
	if target == "all":
		for w in roster:
			w.fatigue = clampf(w.fatigue + delta, 0.0, 100.0)
	elif target == "random" and not roster.is_empty():
		var w: Worker = roster[Rng.stream("event").next_bounded(roster.size())]
		w.fatigue = clampf(w.fatigue + delta, 0.0, 100.0)


func _break_sector(type_id: String) -> void:
	if grid.sectors.is_empty():
		return
	if type_id == "random" or type_id == "":
		grid.sectors[Rng.stream("event").next_bounded(grid.sectors.size())].broken = true
	else:
		for s in grid.sectors:
			if s.type_id == type_id:
				s.broken = true
				break


func _status(target: String, status: String) -> void:
	var pool: Array = roster if target == "all" else []
	if target == "random" and not roster.is_empty():
		pool = [roster[Rng.stream("event").next_bounded(roster.size())]]
	for w in pool:
		w.status = status
		if status == "injured":
			w.fatigue = 100.0


func _grant_worker(rarity: int) -> void:
	var w: Worker = generator.create_worker(Rng.stream("hire"), rarity)
	roster.append(w)
	roster_changed.emit()


func _on_shift_finished() -> void:
	last_report = shift.report()
	credits += last_report["credits"]
	rep += last_report["rep"]
	lifetime_tonnes += float(last_report["tonnes"])
	run_tonnes += float(last_report["tonnes"])
	_bump("shifts_total")
	_report("shifts_total")
	if String(last_report["grade"]) == "S":
		_bump("grade_s")
		_report("grade_s")
	_advance_rank()
	var wage_bill: float = 0.0
	for w in roster:
		wage_bill += w.wage
		w.fatigue = clampf(w.fatigue + 6.0, 0.0, 100.0)
		w.shifts_worked += 1
		w.add_xp(20.0 * (1.0 + 0.2 * rank), rules)
	credits -= wage_bill  # wages paid at end of shift (spec §6.7)
	Audio.play_sfx("shift_end")
	_check_achievements()
	save_game()
	shift_finished.emit(last_report)
	_start_next_shift()
	stats_changed.emit()


func _advance_rank() -> void:
	while rep >= rep_needed(rank + 1):
		rank += 1
		line.tariff = catalog.tariff(rank)
		line.set_inflow(catalog.free_flow_lambda(rank, 1), catalog.free_flow_mix(rank))


# ---------------------------------------------------------------- M5/M6 extras

func _report(stat: String, amount: float = 1.0) -> void:
	if directives_board != null:
		directives_board.report(stat, amount)


func _start_chains() -> void:
	if rank >= 6:
		chain_runtime.start("smuggling")
	if rank >= 8:
		chain_runtime.start("union")
	if rank >= 12:
		chain_runtime.start("secret")


func _chain_event() -> Dictionary:
	for id in chain_runtime.active_ids():
		var chs: Array = chain_runtime.current_choices(id)
		if not chs.is_empty():
			return {
				"id": "chain_" + String(id),
				"key": chain_runtime.current_key(String(id)),
				"choices": chs,
				"auto_resolve_s": 60,
			}
	return {}


func _resolve_chain_choice(chain_id: String, choice_id: String) -> void:
	var idx: int = -1
	var chs: Array = event_active.get("choices", [])
	for i in chs.size():
		if String((chs[i] as Dictionary).get("id", "")) == choice_id:
			idx = i
	if idx >= 0:
		var ch: Dictionary = chs[idx]
		if _pay_cost(ch.get("cost", {})) and _passes_check(ch.get("check", {})):
			_apply_effects(ch.get("effects", []))
		if chain_runtime.advance(chain_id, idx):
			_bump("chains_done")
			_check_achievements()
	event_active = {}
	_recompute_line()
	event_resolved.emit()
	stats_changed.emit()


## Claim a completed directive's reward.
func claim_directive(id: String) -> Dictionary:
	if directives_board == null:
		return {}
	var r: Dictionary = directives_board.claim(id)
	if r.is_empty():
		return r
	credits += float(r.get("credits_mult", 0)) * 50.0 * float(rank)
	rep += float(r.get("rep", 0))
	tokens += float(r.get("tokens", 0))
	save_game()
	stats_changed.emit()
	return r


# ---------------------------------------------------------------- meta (M6)

func tree_effect(effect_key: String) -> float:
	return tree.effect_total(tree_levels, effect_key)


## Load user settings (spec §15.9) from the save.
func _load_settings() -> void:
	var s: Dictionary = SaveSystem.settings()
	locale = String(s.get("locale", "ru"))
	muted = bool(s.get("muted", false))
	anon_stats = bool(s.get("anon_stats", true))
	tutorial_seen = bool(s.get("tutorial_seen", false))
	online = bool(s.get("online", true))
	if Net != null:
		Net.set_online(online)


## Toggle the live backend (persisted).
func set_online(value: bool) -> void:
	online = value
	SaveSystem.set_setting("online", value)
	SaveSystem.store()
	if Net != null:
		Net.set_online(value)
	stats_changed.emit()


## Persist user settings to the save file.
func save_settings() -> void:
	SaveSystem.set_setting("locale", locale)
	SaveSystem.set_setting("muted", muted)
	SaveSystem.set_setting("anon_stats", anon_stats)
	SaveSystem.set_setting("tutorial_seen", tutorial_seen)
	SaveSystem.set_setting("online", online)
	SaveSystem.store()


# ---------------------------------------------------------------- save state

## Serialize the full run (spec §2.7).
func to_state() -> Dictionary:
	var roster_arr: Array = []
	for w in roster:
		roster_arr.append(w.to_dict())
	return {
		"credits": credits, "parts": parts, "rep": rep, "rank": rank,
		"roster": roster_arr, "slots": slots.duplicate(),
		"grid": grid.to_state(),
		"tokens": tokens, "shares": shares, "tree_levels": tree_levels.duplicate(),
		"achievements_done": achievements_done.duplicate(),
		"lifetime_tonnes": lifetime_tonnes, "run_tonnes": run_tonnes,
		"reorg_count": reorg_count, "counters": counters.duplicate(),
		"cosmetics_owned": cosmetics_owned.duplicate(),
		"cosmetics_equipped": cosmetics_equipped.duplicate(),
		"relations": relations.to_dict(), "chains": chain_runtime.to_dict(),
		"directives": {
			"active": directives_board.active.duplicate(true),
			"progress": directives_board.progress.duplicate(),
			"claimed": directives_board.claimed.duplicate(),
		},
	}


func load_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	credits = float(d.get("credits", credits))
	parts = float(d.get("parts", parts))
	rep = float(d.get("rep", rep))
	rank = int(d.get("rank", rank))
	roster = []
	for row in d.get("roster", []):
		roster.append(Worker.from_dict(row))
	slots = (d.get("slots", {}) as Dictionary).duplicate()
	grid.load_state(d.get("grid", {}))
	tokens = float(d.get("tokens", 0.0))
	shares = int(d.get("shares", 0))
	tree_levels = (d.get("tree_levels", {}) as Dictionary).duplicate()
	achievements_done = (d.get("achievements_done", {}) as Dictionary).duplicate()
	lifetime_tonnes = float(d.get("lifetime_tonnes", 0.0))
	run_tonnes = float(d.get("run_tonnes", 0.0))
	reorg_count = int(d.get("reorg_count", 0))
	counters = (d.get("counters", {}) as Dictionary).duplicate()
	cosmetics_owned = (d.get("cosmetics_owned", []) as Array).duplicate()
	cosmetics_equipped = (d.get("cosmetics_equipped", {}) as Dictionary).duplicate()
	relations.load_dict(d.get("relations", {}))
	chain_runtime.load_dict(d.get("chains", {}))
	var ds: Dictionary = d.get("directives", {})
	if not ds.is_empty():
		directives_board.active = (ds.get("active", directives_board.active) as Array).duplicate(true)
		directives_board.progress = (ds.get("progress", {}) as Dictionary).duplicate()
		directives_board.claimed = (ds.get("claimed", {}) as Dictionary).duplicate()
	# Rebuild derived state and begin a fresh shift.
	line.tariff = catalog.tariff(rank)
	_build_line()
	_recompute_line()
	_start_next_shift()
	stats_changed.emit()


func _load_state_if_any() -> void:
	var st: Variant = SaveSystem.data.get("state", {})
	if st is Dictionary and not (st as Dictionary).is_empty():
		load_state(st as Dictionary)


func save_game() -> void:
	SaveSystem.data["state"] = to_state()
	SaveSystem.store()


func _bump(k: String, n: int = 1) -> void:
	counters[k] = int(counters.get(k, 0)) + n


func _docks() -> int:
	var n: int = 0
	for s in grid.sectors:
		if s.type_id == "dock":
			n += 1
	return n


func _classes_on_line() -> int:
	var seen: Dictionary = {}
	for w in assigned_workers():
		seen[w.class_id] = true
	return seen.size()


func _species_count() -> int:
	var seen: Dictionary = {}
	for w in roster:
		seen[w.species] = true
	return seen.size()


func _legendary_count() -> int:
	var n: int = 0
	for w in roster:
		if w.rarity >= 4:
			n += 1
	return n


func _max_worker_level() -> int:
	var m: int = 0
	for w in roster:
		m = maxi(m, w.level)
	return m


func _max_friendship() -> int:
	var m: int = 0
	for w in roster:
		for f in w.friends.values():
			m = maxi(m, int(f))
	return m


## Snapshot of every tracked stat, keyed by achievement condition type.
func achievement_stats() -> Dictionary:
	var s: Dictionary = counters.duplicate()
	s["tonnes_total"] = lifetime_tonnes
	s["rank"] = rank
	s["reorg_count"] = reorg_count
	s["elevator_milestones"] = elevator.completed(lifetime_tonnes)
	s["slots_filled"] = assigned_workers().size()
	s["synergy"] = synergy.line_synergy(assigned_workers())
	s["parts_owned"] = parts
	s["sectors"] = grid.sectors.size()
	s["docks"] = _docks()
	s["dock_level"] = grid.dock_level()
	s["classes_on_line"] = _classes_on_line()
	s["species_all"] = _species_count()
	s["legendary_owned"] = _legendary_count()
	s["worker_level"] = _max_worker_level()
	s["friendship"] = _max_friendship()
	return s


func _check_achievements() -> void:
	var st: Dictionary = achievement_stats()
	var newly: Array = ach.check(st, achievements_done)
	for a in newly:
		achievements_done[a["id"]] = true
		var r: Dictionary = a.get("reward", {})
		tokens += float(r.get("tokens", 0))
		if r.has("title"):
			cosmetics_owned.append(String(r["title"]))
		if r.has("frame"):
			cosmetics_owned.append(String(r["frame"]))
		if r.has("skin"):
			cosmetics_owned.append(String(r["skin"]))
	if not newly.is_empty():
		stats_changed.emit()


## Orbital Elevator helpers (spec §12.2).
func elevator_milestones_done() -> int:
	return elevator.completed(lifetime_tonnes)


func elevator_next() -> Dictionary:
	return elevator.next(lifetime_tonnes)


func elevator_progress() -> float:
	return elevator.progress(lifetime_tonnes)


func buy_tree_node(id: String) -> bool:
	var lvl: int = int(tree_levels.get(id, 0))
	if lvl >= tree.max_level(id):
		return false
	var c: int = tree.cost(id, lvl)
	if shares < c:
		return false
	shares -= c
	tree_levels[id] = lvl + 1
	_recompute_line()
	save_game()
	stats_changed.emit()
	return true


func can_reorg() -> bool:
	return rank >= 20 or run_tonnes >= 1e7


func reorg_preview() -> int:
	return Meta.shares(run_tonnes)


## Reorganisation / prestige (spec §12.3): bank shares, reset the run.
func do_reorg() -> void:
	shares += Meta.shares(run_tonnes)
	reorg_count += 1
	_report("reorg_count")
	credits = 200.0
	parts = 0.0
	rep = 0.0
	rank = 1
	run_tonnes = 0.0
	active_contract = null
	active_effects.clear()
	event_active.clear()
	grid.starting_setup()
	roster = _make_starting_roster()
	board.refresh(6, 0)
	_init_slots()
	auto_assign()
	_recompute_line()
	_restore_free_flow()
	_start_next_shift()
	_check_achievements()
	save_game()
	stats_changed.emit()