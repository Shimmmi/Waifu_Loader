extends TestCase

## Meta formulas, tree, elevator, achievements, directives (spec §12, §17.1).


func test_shares_formula() -> void:
	assert_eq(Meta.shares(1e7), 31)
	assert_eq(Meta.shares(1e5), 4)
	assert_eq(Meta.shares(0.0), 0)


func test_rep_needed_formula() -> void:
	assert_close(Meta.rep_needed(2), 18.0, 1e-6)
	assert_close(Meta.rep_needed(5), 61.0, 1e-6)


func test_shares_income_bonus_cap() -> void:
	assert_close(Meta.shares_income_bonus(100), 1.0, 1e-9)
	assert_close(Meta.shares_income_bonus(1000), 3.0, 1e-9)


func test_tree_cost_formula() -> void:
	var tree := CorporateTree.from_data(load_json("tree"))
	# clearing: base 2 -> level0 cost 2, level1 ceil(2*1.6)=4, level2 ceil(2*2.56)=6
	assert_eq(tree.cost("clearing", 0), 2)
	assert_eq(tree.cost("clearing", 1), 4)
	assert_eq(tree.cost("clearing", 2), 6)


func test_tree_effect_total() -> void:
	var tree := CorporateTree.from_data(load_json("tree"))
	var levels := { "clearing": 3, "orbital_quota": 2 }
	assert_close(tree.effect_total(levels, "station_speed"), 0.15, 1e-6)
	assert_close(tree.effect_total(levels, "flow"), 0.20, 1e-6)


func test_elevator_milestones() -> void:
	var elev := Elevator.from_data(load_json("elevator"))
	assert_eq(elev.completed(5e3), 0)
	assert_eq(elev.completed(1e5), 2)
	assert_eq(int(elev.next(1e5)["n"]), 3)
	assert_close(elev.progress(5.5e4), 0.5, 1e-3)
	assert_close(elev.progress(1e15), 1.0, 1e-9)


func test_achievements_check() -> void:
	var ach := Achievements.from_data(load_json("achievements"))
	assert_eq(ach.total(), 41)
	var stats := { "tonnes_total": 1000.0, "hires": 0.0 }
	var newly: Array = ach.check(stats, {})
	var ids: Array = []
	for a in newly:
		ids.append(a["id"])
	assert_true(ids.has("first_tonne"))
	assert_true(ids.has("thousand"))
	assert_false(ids.has("million"))
	# already-done achievements are skipped
	var again: Array = ach.check(stats, { "first_tonne": true })
	for a in again:
		assert_true(a["id"] != "first_tonne")


func test_directives_pick_deterministic() -> void:
	var dirs := Directives.from_data(load_json("directives"))
	assert_eq(dirs.linear.size(), 20)
	assert_eq(dirs.weekly.size(), 12)
	var a: Array = dirs.pick_daily(PCG32.new(11, 2), 3)
	var b: Array = dirs.pick_daily(PCG32.new(11, 2), 3)
	assert_eq(a.size(), 3)
	assert_eq(a, b)