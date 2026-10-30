extends TestCase

## Shift loop tests (spec §8.1, §8.8, §8.9).

var _catalog: Catalog


func _cat() -> Catalog:
	if _catalog == null:
		var cargo: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cargo.json"))
		var bal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
		_catalog = Catalog.from_dicts(cargo, bal)
	return _catalog


func _make_shift(duration: float = 300.0) -> Shift:
	var line := LineSim.create(_cat())
	line.q0_cap = 1e9
	line.b1_cap = 1e9
	line.b2_cap = 1e9
	line.tariff = 1.0
	line.set_inflow(1000.0, _cat().mix_from({"normal": 1.0}))
	var shift := Shift.new(line, duration)
	shift.set_base_rates(30.0, 40.0, 25.0)
	return shift


func test_shift_completes_after_duration() -> void:
	var shift := _make_shift(300.0)
	shift.start()
	assert_true(shift.is_running())
	for i in 299:
		shift.tick(1.0)
	assert_true(shift.is_running(), "still running before duration")
	shift.tick(1.0)
	assert_eq(shift.state, Shift.State.REPORT)
	assert_true(shift.tonnes > 0.0, "should have stored cargo")


func test_idle_shift_does_nothing() -> void:
	var shift := _make_shift()
	shift.tick(10.0)
	assert_close(shift.elapsed_s, 0.0, 1e-9)
	assert_eq(shift.state, Shift.State.IDLE)


func test_rush_increases_output() -> void:
	var plain := _make_shift()
	var rushed := _make_shift()
	plain.start()
	rushed.start()
	assert_true(rushed.rush(), "rush should be available at start")
	for i in 300:
		plain.tick(1.0)
		rushed.tick(1.0)
	assert_true(rushed.credits > plain.credits,
		"rushed shift should out-earn plain (%f vs %f)" % [rushed.credits, plain.credits])


func test_rush_cooldown() -> void:
	var shift := _make_shift()
	shift.start()
	assert_true(shift.rush())
	assert_false(shift.rush_available(), "on cooldown right after rush")
	assert_false(shift.rush(), "second rush should be refused")
	for i in 46:
		shift.tick(1.0)
	assert_true(shift.rush_available(), "cooldown should have expired")


func test_grade_from_ratio() -> void:
	var shift := _make_shift()
	assert_eq(shift._grade(1.30), "S")
	assert_eq(shift._grade(1.10), "A")
	assert_eq(shift._grade(0.90), "B")
	assert_eq(shift._grade(0.65), "C")
	assert_eq(shift._grade(0.10), "D")