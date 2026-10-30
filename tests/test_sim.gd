extends TestCase

## LineSim tests (spec §17.1): mass conservation, degenerate cases, monotonicity
## and the harmonic-mean mixture rule.

var _catalog: Catalog


func _cat() -> Catalog:
	if _catalog == null:
		var cargo: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cargo.json"))
		var bal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
		_catalog = Catalog.from_dicts(cargo, bal)
	return _catalog


func _make() -> LineSim:
	return LineSim.create(_cat())


func test_conservation_over_many_steps() -> void:
	var s := _make()
	s.set_inflow(30.0, _cat().mix_from({"normal": 0.7, "fragile": 0.3}))
	s.set_rates(20.0, 25.0, 10.0)
	for i in 600:
		s.step(1.0)
	var lhs: float = s.arrived
	var rhs: float = s.stored + s.waste + s.missed + s.buffer_total()
	assert_close(lhs, rhs, 1e-3, "conservation over 600 steps")


func test_conservation_with_named_cap() -> void:
	# Tight buffers force overflow into `missed`; conservation must still hold.
	var s := _make()
	s.q0_cap = 20.0
	s.b1_cap = 30.0
	s.b2_cap = 40.0
	s.set_inflow(200.0, _cat().mix_from({"normal": 1.0}))
	s.set_rates(60.0, 40.0, 5.0)
	for i in 400:
		s.step(1.0)
	assert_true(s.missed > 0.0, "expected overflow with tiny buffers")
	assert_close(s.arrived, s.stored + s.waste + s.missed + s.buffer_total(), 1e-3)


func test_zero_inflow_gives_zero_income() -> void:
	var s := _make()
	s.set_inflow(0.0, _cat().mix_from({"normal": 1.0}))
	s.set_rates(20.0, 20.0, 20.0)
	for i in 300:
		s.step(1.0)
	assert_close(s.credits, 0.0, 1e-9, "no inflow, no credits")
	assert_close(s.stored, 0.0, 1e-9, "no inflow, nothing stored")


func test_higher_store_rate_gives_more_income() -> void:
	var low := _make()
	low.b1_cap = 1e9
	low.b2_cap = 1e9
	low.q0_cap = 1e9
	low.set_inflow(1000.0, _cat().mix_from({"normal": 1.0}))
	low.set_rates(100.0, 100.0, 5.0)

	var high := _make()
	high.b1_cap = 1e9
	high.b2_cap = 1e9
	high.q0_cap = 1e9
	high.set_inflow(1000.0, _cat().mix_from({"normal": 1.0}))
	high.set_rates(100.0, 100.0, 40.0)

	for i in 120:
		low.step(1.0)
		high.step(1.0)
	assert_true(high.credits > low.credits, "higher store rate should place more cargo")


func test_harmonic_mean_slows_low_phi_cargo() -> void:
	var cat := _cat()
	var s_normal := _make()
	s_normal.set_rates(0.0, 0.0, 30.0)
	var s_oversize := _make()
	s_oversize.set_rates(0.0, 0.0, 30.0)
	# Pre-load 50 t straight into B2.
	s_normal.b2[cat.index["normal"]] = 50.0
	s_oversize.b2[cat.index["oversize"]] = 50.0
	for i in 30:
		s_normal.step(1.0)
		s_oversize.step(1.0)
	assert_true(s_normal.stored > s_oversize.stored,
		"oversize (phi 0.5) should store slower than normal (phi 1.0): %f vs %f" % [s_oversize.stored, s_normal.stored])


func test_mixed_flow_is_slower_than_pure() -> void:
	var cat := _cat()
	var pure := _make()
	pure.set_rates(0.0, 0.0, 30.0)
	pure.b2[cat.index["normal"]] = 50.0
	var mixed := _make()
	mixed.set_rates(0.0, 0.0, 30.0)
	mixed.b2[cat.index["normal"]] = 25.0
	mixed.b2[cat.index["oversize"]] = 25.0
	for i in 30:
		pure.step(1.0)
		mixed.step(1.0)
	assert_true(pure.stored > mixed.stored, "harmonic mean: a mixed batch stores slower than pure")


func test_free_flow_mix_sums_to_one() -> void:
	for rank in [1, 9, 12, 16, 20, 27]:
		var m: PackedFloat32Array = _cat().free_flow_mix(rank)
		var total: float = 0.0
		for v in m:
			total += v
		assert_close(total, 1.0, 1e-5, "mix at rank %d" % rank)


func test_free_flow_lambda_grows() -> void:
	var cat := _cat()
	var a: float = cat.free_flow_lambda(1, 1)
	var b: float = cat.free_flow_lambda(1, 2)
	assert_close(a, 6.0, 1e-6)
	assert_true(b > a, "higher dock level -> higher free flow")


func test_tariff_curve() -> void:
	var cat := _cat()
	assert_close(cat.tariff(1), 1.0, 1e-9)
	assert_close(cat.tariff(2), 1.18, 1e-9)
	assert_close(cat.tariff(3), 1.18 * 1.18, 1e-6)


func test_offline_equivalence_1s_vs_10s() -> void:
	# Spec §8.7: stepping 8 h in 10 s offline chunks must match 1 s online steps
	# within 1%. Use generous buffers and a binding station rate so the min()
	# terms stay linear and the two are analytically equal.
	var cat := _cat()
	var fine := _make()
	var coarse := _make()
	for s in [fine, coarse]:
		s.q0_cap = 1e9
		s.b1_cap = 1e9
		s.b2_cap = 1e9
		s.tariff = 1.0
		s.set_inflow(1000.0, cat.mix_from({"normal": 0.7, "fragile": 0.3}))
		s.set_rates(30.0, 40.0, 25.0)
	var seconds := 8 * 3600
	for i in seconds:
		fine.step(1.0)
	for i in int(seconds / 10):
		coarse.step(10.0)

	var stored_diff: float = absf(fine.stored - coarse.stored) / maxf(fine.stored, 1e-9)
	var credit_diff: float = absf(fine.credits - coarse.credits) / maxf(fine.credits, 1e-9)
	assert_true(stored_diff <= 0.01, "stored differs by %.4f%%" % (stored_diff * 100.0))
	assert_true(credit_diff <= 0.01, "credits differ by %.4f%%" % (credit_diff * 100.0))


func test_station_rate_formula() -> void:
	var cat := _cat()
	# No crew: only the auto rate at dock level 1 (store auto = 8).
	assert_close(cat.station_rate("store", 1, 0.0), 8.0, 1e-6)
	# power 2 at store base 15 -> +30.
	assert_close(cat.station_rate("store", 1, 2.0), 8.0 + 30.0, 1e-6)
	# dock level 2 multiplies the auto term by 1.12.
	assert_close(cat.station_rate("store", 2, 0.0), 8.0 * 1.12, 1e-6)