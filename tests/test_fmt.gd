extends TestCase

## Fmt.number / Fmt.time tests (spec §2.8, §17.1).


func test_small_integers() -> void:
	assert_eq(Fmt.num(0.0), "0")
	assert_eq(Fmt.num(1.0), "1")
	assert_eq(Fmt.num(999.0), "999")


func test_suffix_ladder() -> void:
	assert_eq(Fmt.num(1000.0), "1K")
	assert_eq(Fmt.num(1500.0), "1.5K")
	assert_eq(Fmt.num(1_000_000.0), "1M")
	assert_eq(Fmt.num(2_500_000_000.0), "2.5B")
	assert_eq(Fmt.num(1e12), "1T")


func test_negative() -> void:
	assert_eq(Fmt.num(-1500.0), "-1.5K")


func test_rollover() -> void:
	assert_eq(Fmt.num(999_999.0), "1M")


func test_scientific_fallback() -> void:
	var s: String = Fmt.num(1e40)
	assert_true(s.contains("e39") or s.contains("e40"), "unexpected scientific: %s" % s)


func test_time_format() -> void:
	assert_eq(Fmt.time(0.0), "00:00")
	assert_eq(Fmt.time(65.0), "01:05")
	assert_eq(Fmt.time(3661.0), "1:01:01")