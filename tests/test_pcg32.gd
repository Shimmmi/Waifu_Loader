extends TestCase

## PCG32 determinism and correctness tests (spec §17.1).


func test_reference_vectors() -> void:
	var vectors: Array = _load_vectors()
	assert_true(vectors.size() > 0, "no vectors loaded")
	for v in vectors:
		var rng := PCG32.new(int(v["seed"]), int(v["seq"]))
		var outputs: Array = []
		for i in int(v["count"]):
			outputs.append("%08x" % rng.next_uint32())
		assert_eq(outputs, v["outputs"], "seed=%s seq=%s" % [v["seed"], v["seq"]])


func test_same_seed_is_deterministic() -> void:
	var a := PCG32.new(12345, 7)
	var b := PCG32.new(12345, 7)
	for i in 200:
		assert_eq(a.next_uint32(), b.next_uint32(), "index %d" % i)


func test_different_streams_diverge() -> void:
	var a := PCG32.new(1, 1)
	var b := PCG32.new(1, 2)
	var equal: int = 0
	for i in 200:
		if a.next_uint32() == b.next_uint32():
			equal += 1
	assert_true(equal < 8, "streams nearly identical (%d equal)" % equal)


func test_bounded_range() -> void:
	var rng := PCG32.new(99, 3)
	for i in 2000:
		var v: int = rng.next_bounded(10)
		assert_true(v >= 0 and v < 10, "value out of range: %d" % v)


func test_bounded_one_is_zero() -> void:
	var rng := PCG32.new(1, 1)
	assert_eq(rng.next_bounded(1), 0)


func test_range_inclusive() -> void:
	var rng := PCG32.new(4, 4)
	var seen_lo: bool = false
	var seen_hi: bool = false
	for i in 2000:
		var v: int = rng.next_range(5, 9)
		assert_true(v >= 5 and v <= 9, "value out of range: %d" % v)
		if v == 5:
			seen_lo = true
		if v == 9:
			seen_hi = true
	assert_true(seen_lo and seen_hi, "range endpoints never produced")


func test_float_range() -> void:
	var rng := PCG32.new(5, 5)
	for i in 2000:
		var f: float = rng.next_float()
		assert_true(f >= 0.0 and f < 1.0, "float out of range: %f" % f)


func test_bounded_distribution_is_roughly_uniform() -> void:
	var rng := PCG32.new(2024, 11)
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var n: int = 100000
	for i in n:
		counts[rng.next_bounded(10)] += 1
	var expected: float = n / 10.0
	for c in counts:
		assert_close(float(c), expected, expected * 0.1, "bucket %d count %d" % [c, c])


func _load_vectors() -> Array:
	var text: String = FileAccess.get_file_as_string("res://tests/vectors/pcg32.json")
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		return []
	return parsed["vectors"]