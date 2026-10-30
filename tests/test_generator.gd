extends TestCase

## Worker generation: determinism, rarity tiers, pity guarantees (spec §17.1).


func test_deterministic_pool() -> void:
	var rules := load_rules()
	var g1 := Generator.new(rules)
	var g2 := Generator.new(rules)
	var r1 := PCG32.new(42, 1)
	var r2 := PCG32.new(42, 1)
	for i in 10:
		var a: Worker = g1.create_worker(r1, g1.next_rarity(r1, 0))
		var b: Worker = g2.create_worker(r2, g2.next_rarity(r2, 0))
		assert_eq(a.id, b.id)
		assert_eq(a.full_name, b.full_name)
		assert_eq(a.class_id, b.class_id)
		assert_eq(a.point_stats, b.point_stats)
		assert_eq(a.traits, b.traits)


func test_rarity_stat_sum_increases() -> void:
	var rules := load_rules()
	var g := Generator.new(rules)
	var rng := PCG32.new(9, 2)
	var sums: Array = []
	for tier in 5:
		var w: Worker = g.create_worker(rng, tier)
		var total: float = 0.0
		for s in Rules.STATS:
			total += float(w.point_stats[s])
		sums.append(total)
	for i in range(1, 5):
		assert_true(float(sums[i]) > float(sums[i - 1]),
			"tier %d sum %.0f <= tier %d sum %.0f" % [i, sums[i], i - 1, sums[i - 1]])


func test_pity_guarantees_rare() -> void:
	var rules := load_rules()
	var g := Generator.new(rules)
	var rng := PCG32.new(7, 3)
	var got: bool = false
	for i in 12:
		if g.next_rarity(rng, 0) >= 2:
			got = true
	assert_true(got, "no rare+ within 12 draws (pity failed)")


func test_pity_guarantees_legendary_eventually() -> void:
	var rules := load_rules()
	var g := Generator.new(rules)
	var rng := PCG32.new(11, 4)
	var got: bool = false
	for i in 150:
		if g.next_rarity(rng, 0) >= 4:
			got = true
	assert_true(got, "no legendary within 150 draws (pity failed)")


func test_distribution_common_dominates() -> void:
	var rules := load_rules()
	var g := Generator.new(rules)
	var rng := PCG32.new(2026, 5)
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var n: int = 5000
	for i in n:
		counts[g.next_rarity(rng, 0)] += 1
	assert_true(counts[0] > counts[1], "common should outnumber uncommon")
	assert_true(float(counts[0]) > float(n) * 0.4, "common share too low: %d/%d" % [counts[0], n])


func test_hire_board_deterministic() -> void:
	var rules := load_rules()
	var b1 := HireBoard.new(rules, Generator.new(rules), 12345)
	var b2 := HireBoard.new(rules, Generator.new(rules), 12345)
	b1.refresh(6, 0)
	b2.refresh(6, 0)
	assert_eq(b1.pool.size(), 6)
	for i in 6:
		assert_eq(b1.pool[i].id, b2.pool[i].id, "slot %d" % i)


func test_hire_board_take_removes() -> void:
	var rules := load_rules()
	var board := HireBoard.new(rules, Generator.new(rules), 777)
	board.refresh(4, 0)
	var first: Worker = board.pool[0]
	var taken: Worker = board.take(first.id)
	assert_true(taken != null)
	assert_eq(board.pool.size(), 3)