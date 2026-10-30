extends TestCase

## Competitive models (spec §13.5, §13.6, §9.7): tactics, Cup duel, Daily Shift,
## Tender. All deterministic via PCG32.


func _catalog() -> Catalog:
	return Catalog.from_dicts(load_json("cargo"), load_json("balance"))


func _crew() -> Crew:
	return Crew.from_dicts(load_json("classes"), load_json("balance"))


func _brigade(si: float, cls: String = "loader") -> Array:
	return [
		{ "station": "unload", "class_id": cls, "si": si },
		{ "station": "move", "class_id": cls, "si": si },
		{ "station": "store", "class_id": cls, "si": si },
	]


func test_tactics_modifiers_and_counters() -> void:
	assert_close(float(Tactics.modifier("assault")["speed"]), 0.15, 1e-6)
	assert_close(float(Tactics.modifier("meticulous")["speed"]), -0.10, 1e-6)
	assert_close(float(Tactics.modifier("balance")["passive"]), 0.05, 1e-6)
	assert_true(Tactics.beats("assault", "meticulous"))
	assert_true(Tactics.beats("meticulous", "balance"))
	assert_true(Tactics.beats("balance", "assault"))
	assert_false(Tactics.beats("assault", "balance"))


func test_duel_stronger_wins_and_deterministic() -> void:
	var d1: Dictionary = Duel.simulate(_catalog(), _crew(), _brigade(60.0), _brigade(25.0), "balance", "balance", "gold", 42)
	var d2: Dictionary = Duel.simulate(_catalog(), _crew(), _brigade(60.0), _brigade(25.0), "balance", "balance", "gold", 42)
	assert_eq(d1["result"], "win")
	assert_eq(d1["scores"], d2["scores"])
	assert_eq(d1["replay"], d2["replay"])
	assert_true(int(d1["scores"][0]) > int(d1["scores"][1]))


func test_duel_counter_bonus_flips_equal_match() -> void:
	# Equal brigades: the counter should decide it.
	var d: Dictionary = Duel.simulate(_catalog(), _crew(), _brigade(50.0), _brigade(50.0), "assault", "meticulous", "gold", 1)
	assert_eq(d["result"], "win")


func test_duel_league_cap_lowers_score() -> void:
	var bronze: Dictionary = Duel.simulate(_catalog(), _crew(), _brigade(200.0), _brigade(25.0), "balance", "balance", "bronze", 5)
	var diamond: Dictionary = Duel.simulate(_catalog(), _crew(), _brigade(200.0), _brigade(25.0), "balance", "balance", "diamond", 5)
	assert_true(int(bronze["scores"][0]) < int(diamond["scores"][0]))


func test_daily_shift_preset_and_score() -> void:
	var p: Dictionary = DailyShift.preset(123)
	assert_eq((p["employees"] as Array).size(), 8)
	assert_eq((p["stations"] as Array).size(), 6)
	var crew := _crew()
	var cat := _catalog()
	var a: Dictionary = DailyShift.run(cat, crew, [0, 1, 2, 3, 4, 5], 123)
	var b: Dictionary = DailyShift.run(cat, crew, [0, 1, 2, 3, 4, 5], 123)
	assert_close(float(a["score"]), float(b["score"]), 1e-6)
	assert_true(float(a["score"]) > 0.0)
	# A different assignment changes the score.
	var c: Dictionary = DailyShift.run(cat, crew, [7, 6, 5, 4, 3, 2], 123)
	assert_true(not is_equal_approx(float(a["score"]), float(c["score"])))


func test_tender_rule_and_run() -> void:
	assert_eq(Tender.rule_for(9), Tender.rule_for(9))
	var r: String = Tender.rule_for(9)
	assert_true(r in Tender.RULES)
	var crew := _crew()
	var t1: Dictionary = Tender.run(crew, _brigade(50.0), r, 9)
	var t2: Dictionary = Tender.run(crew, _brigade(50.0), r, 9)
	assert_close(float(t1["score"]), float(t2["score"]), 1e-6)
	assert_true(float(t1["score"]) > 0.0)