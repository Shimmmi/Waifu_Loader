extends TestCase

## Card values match Worker getters for a sample of employees (v0.2 §3.9).


func test_card_stats_match_worker() -> void:
	var rules: Rules = load_rules()
	var crew: Crew = Crew.from_dicts(load_json("classes"), load_json("balance"))
	var gen := Generator.new(rules)
	var rng := PCG32.new(42, 7)
	for i in 20:
		var w: Worker = gen.create_worker(rng, i % 5)
		var stats: Dictionary = w.stats(rules)
		for s in Rules.STATS:
			var bd: Dictionary = w.stat_breakdown(s, rules)
			assert_close(float(bd["total"]), float(stats[s]), 1e-4)
		assert_true(w.fit("unload", rules) >= 0.0)
		var expr: String = w.expression_state()
		assert_true(
			expr == "neutral" or expr == "happy" or expr == "tired"
			or expr == "annoyed" or expr == "injured" or expr == "panic")
		assert_true(w.wage_base(rules) > 0.0)
