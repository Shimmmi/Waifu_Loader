extends TestCase

## Worker derived-value tests (spec §6.4, §6.5, §6.7, §6.8).


func test_species_multiplier_applied() -> void:
	var rules := load_rules()
	var w := Worker.new()
	w.species = "silicate"
	w.class_id = "loader"
	w.point_stats = { "str": 20, "agi": 20, "acc": 20, "end": 20, "wit": 20 }
	var st: Dictionary = w.stats(rules)
	assert_close(st["str"], 20.0 * 1.25, 1e-4)
	assert_close(st["agi"], 20.0 * 0.8, 1e-4)
	assert_close(st["end"], 20.0 * 1.15, 1e-4)


func test_wage_formula() -> void:
	var rules := load_rules()
	var w := Worker.new()
	w.class_id = "loader"   # base 10
	w.rarity = 0            # x1.0
	w.species = "human"     # x1.0
	w.level = 1
	assert_close(w.wage_base(rules), 10.0, 1e-4)
	w.level = 11
	assert_close(w.wage_base(rules), 10.0 * (1.0 + 0.04 * 10), 1e-4)


func test_wage_rarity_and_species() -> void:
	var rules := load_rules()
	var w := Worker.new()
	w.class_id = "loader"
	w.rarity = 2            # rare x2.0
	w.species = "silicate"  # x0.9
	w.level = 1
	assert_close(w.wage_base(rules), 10.0 * 2.0 * 0.9, 1e-4)


func test_morale_and_fatigue_multipliers() -> void:
	var w := Worker.new()
	w.morale = 100.0
	assert_close(w.morale_mult(), 1.2, 1e-6)
	w.morale = 0.0
	assert_close(w.morale_mult(), 0.8, 1e-6)
	w.fatigue = 0.0
	assert_close(w.fatigue_mult(), 1.0, 1e-6)
	w.fatigue = 100.0
	assert_close(w.fatigue_mult(), 0.0, 1e-6)
	w.fatigue = 65.0
	assert_close(w.fatigue_mult(), lerpf(1.0, 0.75, (65.0 - 50.0) / 30.0), 1e-6)


func test_xp_curve_and_level_up() -> void:
	var rules := load_rules()
	var w := Worker.new()
	w.class_id = "loader"
	w.species = "human"
	assert_close(w.xp_needed(1), 40.0, 1e-4)
	assert_close(w.xp_needed(2), 40.0 * 1.3, 1e-4)
	w.level = 1
	w.add_xp(40.0, rules)
	assert_eq(w.level, 2)


func test_as_crew_entry_feeds_station_power() -> void:
	var rules := load_rules()
	var crew := Crew.from_dicts(load_json("classes"), load_json("balance"))
	var w := Worker.new()
	w.species = "human"
	w.class_id = "loader"
	w.morale = 50.0  # morale_mult = 1.0
	w.fatigue = 0.0
	w.point_stats = { "str": 25, "agi": 25, "acc": 25, "end": 25, "wit": 25 }
	var entry: Dictionary = w.as_crew_entry(rules)
	# SI/25 = 1.0, loader unload fit = 1.0 -> power 1.0
	assert_close(crew.station_power("unload", [entry]), 1.0, 1e-6)