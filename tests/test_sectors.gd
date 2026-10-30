extends TestCase

## Sector grid: upgrade/expand formulas, placement, adjacency (spec §5, §20.A).

var _grid: TerminalGrid


func _g() -> TerminalGrid:
	if _grid == null:
		_grid = TerminalGrid.from_data(load_json("sectors"))
		_grid.starting_setup()
	return _grid


func test_starting_setup() -> void:
	var g := _g()
	assert_eq(g.sectors.size(), 4)
	assert_eq(g.dock_level(), 1)
	assert_eq(g.storage_level(), 1)
	assert_eq(g.expansion_count, 0)


func test_upgrade_cost_formula() -> void:
	var g := TerminalGrid.from_data(load_json("sectors"))
	g.starting_setup()
	var storage: Sector = null
	for s in g.sectors:
		if s.type_id == "storage":
			storage = s
	# storage: build 120, g 1.42 -> L1: 120*0.5 = 60
	assert_close(g.upgrade_cost(storage), 60.0, 1e-4)
	storage.level = 2
	assert_close(g.upgrade_cost(storage), 120.0 * 0.5 * 1.42, 1e-4)
	storage.level = 3
	assert_close(g.upgrade_cost(storage), 120.0 * 0.5 * 1.42 * 1.42, 1e-4)


func test_upgrade_time_instant_below_five() -> void:
	var g := TerminalGrid.from_data(load_json("sectors"))
	g.starting_setup()
	var dock: Sector = g.sectors[0]
	dock.level = 1
	assert_close(g.upgrade_time(dock), 0.0, 1e-9)
	dock.level = 5
	assert_close(g.upgrade_time(dock), 30.0, 1e-6)
	dock.level = 6
	assert_close(g.upgrade_time(dock), 30.0 * 1.3, 1e-4)


func test_timed_upgrade_blocks_while_building() -> void:
	var g := TerminalGrid.from_data(load_json("sectors"))
	g.starting_setup()
	var dock: Sector = g.sectors[0]
	dock.level = 5
	assert_true(g.can_upgrade(dock))
	assert_true(g.upgrade(dock))
	assert_true(dock.is_building())
	assert_eq(dock.level, 5)
	assert_false(g.can_upgrade(dock), "must not re-charge while building")
	assert_false(g.upgrade(dock))
	g.finish_construction(dock)
	assert_eq(dock.level, 6)
	assert_false(dock.is_building())
	assert_true(g.can_upgrade(dock))


func test_dock_and_storage_upgrade_costs_differ() -> void:
	var g := TerminalGrid.from_data(load_json("sectors"))
	g.starting_setup()
	var dock: Sector = null
	var storage: Sector = null
	for s in g.sectors:
		if s.type_id == "dock":
			dock = s
		elif s.type_id == "storage":
			storage = s
	dock.level = 5
	storage.level = 5
	assert_true(g.upgrade_cost(dock) != g.upgrade_cost(storage))
	assert_close(g.upgrade_cost(storage), 244.0, 0.1)


func test_expand_cost_and_rank() -> void:
	var g := TerminalGrid.from_data(load_json("sectors"))
	g.starting_setup()
	assert_close(g.expand_cost(), 400.0, 1e-6)
	assert_eq(g.expand_rank_required(), 2)
	g.expansion_count = 1
	assert_close(g.expand_cost(), 400.0 * 2.1, 1e-4)
	assert_eq(g.expand_rank_required(), 2)
	g.expansion_count = 2
	assert_eq(g.expand_rank_required(), 3)


func test_placement_rules() -> void:
	var g := _g()
	# dock occupies (0,0) and (1,0)
	assert_true(g.cell_occupied(Vector2i(0, 0)))
	assert_true(g.cell_occupied(Vector2i(1, 0)))
	# (2,0) storage, (0,1) office, (1,1) dorm -> (2,1) free
	assert_false(g.cell_occupied(Vector2i(2, 1)))
	assert_true(g.fits(Vector2i(1, 1), 2, 1))
	# outside unlocked area (starting 3x2)
	assert_false(g.fits(Vector2i(1, 1), 3, 0))


func test_find_position_returns_free_cell() -> void:
	var g := _g()
	var pos: Vector2i = g.find_position("canteen")
	assert_eq(pos, Vector2i(2, 1))


func test_roll_offers_deterministic() -> void:
	var panel: Dictionary = load_json("sectors")
	var g1 := TerminalGrid.from_data(panel)
	g1.starting_setup()
	var g2 := TerminalGrid.from_data(panel)
	g2.starting_setup()
	var o1: Array = g1.roll_offers(PCG32.new(5, 1), 5)
	var o2: Array = g2.roll_offers(PCG32.new(5, 1), 5)
	assert_eq(o1.size(), 3)
	assert_eq(o1, o2)


func test_apply_offer_adds_sector() -> void:
	var g := _g()
	var offers: Array = g.roll_offers(PCG32.new(9, 2), 5)
	var before: int = g.sectors.size()
	var placed: Sector = g.apply_offer(offers[0])
	assert_eq(g.sectors.size(), before + 1)
	assert_eq(g.expansion_count, 1)
	assert_eq(placed.level, 1)


func test_adjacency_bonus() -> void:
	var g := _g()
	var dock: Sector = null
	var storage: Sector = null
	for s in g.sectors:
		if s.type_id == "dock":
			dock = s
		if s.type_id == "storage":
			storage = s
	# storage sits at (2,0); dock ends at (1,0) -> share a side
	var bonus: Dictionary = g.adjacency_bonus(dock, storage)
	assert_true(bonus.has("flow"), "dock+storage should give a flow bonus")
	assert_close(float(bonus["flow"]), 0.05, 1e-9)


func test_adjacency_symmetric_and_none_for_far() -> void:
	var g := _g()
	var dock: Sector = null
	var office: Sector = null
	for s in g.sectors:
		if s.type_id == "dock":
			dock = s
		if s.type_id == "office":
			office = s
	# dock (0,0)-(1,0); office (0,1) touches (0,0) -> adjacent but no pair entry
	assert_true(g.adjacent(dock, office))
	assert_eq(g.adjacency_bonus(dock, office), {})