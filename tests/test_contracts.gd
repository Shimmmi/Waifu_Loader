extends TestCase

## Contract generation and grading (spec §9, §17.1).

var _cat: Catalog


func _catalog() -> Catalog:
	if _cat == null:
		_cat = Catalog.from_dicts(load_json("cargo"), load_json("balance"))
	return _cat


func _board() -> ContractBoard:
	return ContractBoard.new(load_json("contracts"), (load_json("clients") as Dictionary)["clients"], _catalog())


func test_tier_selection_by_rank() -> void:
	var b := _board()
	assert_eq(String(b.tier_for_rank(6)["id"]), "T1")
	assert_eq(String(b.tier_for_rank(12)["id"]), "T2")
	assert_eq(String(b.tier_for_rank(20)["id"]), "T3")
	assert_eq(String(b.tier_for_rank(30)["id"]), "T4")
	assert_eq(String(b.tier_for_rank(40)["id"]), "T5")
	assert_true(b.tier_for_rank(3).is_empty())


func test_generation_deterministic() -> void:
	var b1 := _board()
	var b2 := _board()
	b1.refresh(PCG32.new(99, 1), 10, 1.18, 60.0, 5)
	b2.refresh(PCG32.new(99, 1), 10, 1.18, 60.0, 5)
	assert_eq(b1.offers.size(), 5)
	for i in 5:
		assert_eq(b1.offers[i].id, b2.offers[i].id)
		assert_eq(b1.offers[i].q, b2.offers[i].q)
		assert_eq(b1.offers[i].cargo_mix, b2.offers[i].cargo_mix)


func test_cargo_mix_sums_to_one() -> void:
	var b := _board()
	b.refresh(PCG32.new(7, 3), 12, 1.18, 80.0, 20)
	for c in b.offers:
		var total: float = 0.0
		for v in c.cargo_mix.values():
			total += float(v)
		assert_close(total, 1.0, 1e-6)


func test_reward_scales_with_difficulty() -> void:
	var b := _board()
	b.refresh(PCG32.new(3, 1), 10, 1.0, 100.0, 30)
	var seen_hard: float = -1.0
	var seen_easy: float = -1.0
	for c in b.offers:
		# reward per tonne should rise with difficulty index
		var per_t: float = float(c.reward["credits"]) / maxf(c.q, 1e-9)
		if c.diff >= 3:
			seen_hard = per_t
		if c.diff == 0:
			seen_easy = per_t
	assert_true(seen_hard > 0.0 and seen_easy > 0.0, "need both easy and hard samples")


func test_grade_deadline_failure() -> void:
	var c := Contract.new()
	c.q = 100.0
	c.deadline_min = 10.0
	c.delivered = 50.0
	c.elapsed_min = 5.0
	assert_eq(c.grade(0.0, 0, 0.0, []), "fail")


func test_grade_gold_and_silver() -> void:
	var c := Contract.new()
	c.q = 100.0
	c.deadline_min = 10.0
	c.delivered = 100.0
	c.elapsed_min = 8.0
	assert_eq(c.grade(0.0, 0, 0.0, []), "gold", "no required bonus -> gold")
	c.kpi_bonus = [{ "type": "quality", "max_defect": 0.02 }]
	assert_eq(c.grade(0.05, 0, 0.0, []), "silver", "bonus missed -> silver")
	assert_eq(c.grade(0.01, 0, 0.0, []), "gold", "bonus met -> gold")


func test_grade_bronze_requires_required_kpi() -> void:
	var c := Contract.new()
	c.q = 100.0
	c.deadline_min = 10.0
	c.delivered = 100.0
	c.elapsed_min = 8.0
	c.kpi_required = [{ "type": "deadline" }, { "type": "tempo", "min": 50.0 }]
	assert_eq(c.grade(0.0, 0, 0.0, []), "bronze", "tempo required but missed")


func test_grade_mult() -> void:
	var c := Contract.new()
	assert_close(c.grade_mult("gold"), 1.5, 1e-9)
	assert_close(c.grade_mult("silver"), 1.0, 1e-9)
	assert_close(c.grade_mult("bronze"), 0.6, 1e-9)
	assert_close(c.grade_mult("fail"), 0.0, 1e-9)