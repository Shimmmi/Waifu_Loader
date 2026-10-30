extends TestCase

## Synergy matrices and line synergy (spec §10, §17.1).


func test_psycho_matrix_symmetric() -> void:
	var rules := load_rules()
	var ids: Array = rules.psycho_matrix.keys()
	for a in ids:
		for b in ids:
			assert_close(rules.psycho_pair(a, b), rules.psycho_pair(b, a), 1e-9, "%s/%s" % [a, b])


func test_star_pairs() -> void:
	var rules := load_rules()
	assert_close(rules.star_pair("aries", "aries"), 8.0, 1e-9)
	assert_close(rules.star_pair("aries", "gemini"), 15.0, 1e-9)   # fire/air
	assert_close(rules.star_pair("aries", "cancer"), -15.0, 1e-9)  # fire/water
	assert_close(rules.star_pair("aries", "taurus"), -5.0, 1e-9)   # fire/earth


func test_chemistry_is_order_independent() -> void:
	var rules := load_rules()
	assert_close(rules.chemistry_value("crane", "foreman"), 6.0, 1e-9)
	assert_close(rules.chemistry_value("foreman", "crane"), 6.0, 1e-9)
	assert_close(rules.chemistry_value("loader", "crane"), 4.0, 1e-9)


func _w(pid: String, star: String, psycho: String, cls: String) -> Worker:
	var w := Worker.new()
	w.id = pid
	w.star = star
	w.psycho = psycho
	w.class_id = cls
	return w


func test_pair_value_clamped() -> void:
	var rules := load_rules()
	var syn := Synergy.new(rules)
	var a := _w("a", "aries", "workaholic", "loader")
	var b := _w("b", "cancer", "rebel", "loader")
	var v: float = syn.pair_value(a, b)
	assert_true(v >= rules.pair_min and v <= rules.pair_max, "pair out of range: %f" % v)


func test_line_synergy_is_pair_average() -> void:
	var rules := load_rules()
	var syn := Synergy.new(rules)
	var a := _w("a", "aries", "workaholic", "loader")
	var b := _w("b", "leo", "workaholic", "loader")
	var c := _w("c", "leo", "workaholic", "loader")
	var expected: float = (syn.pair_value(a, b) + syn.pair_value(a, c) + syn.pair_value(b, c)) / 3.0
	assert_close(syn.line_synergy([a, b, c]), expected, 1e-6)


func test_single_worker_has_no_synergy() -> void:
	var rules := load_rules()
	var syn := Synergy.new(rules)
	assert_close(syn.line_synergy([_w("a", "leo", "quiet", "loader")]), 0.0, 1e-9)


func test_speed_and_morale_from_synergy() -> void:
	var rules := load_rules()
	var syn := Synergy.new(rules)
	assert_close(syn.speed_mult(0.0), 1.0, 1e-9)
	assert_close(syn.speed_mult(20.0), 1.1, 1e-9)
	assert_close(syn.morale_delta(20.0), 2.0, 1e-9)
	assert_close(syn.morale_delta(100.0), 3.0, 1e-9)
	assert_close(syn.morale_delta(-100.0), -3.0, 1e-9)


func test_friendship_increases_pair() -> void:
	var rules := load_rules()
	var syn := Synergy.new(rules)
	var a := _w("a", "leo", "quiet", "loader")
	var b := _w("b", "leo", "quiet", "loader")
	var base: float = syn.pair_value(a, b)
	# 50 shared shifts -> friendship level 2 -> +4
	a.friends[b.id] = 50
	b.friends[a.id] = 50
	assert_close(syn.pair_value(a, b), base + 4.0, 1e-6)