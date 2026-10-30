extends TestCase

## Progress systems (spec §10.5, §11.4, §12.1, §12.5): chains, relations,
## directive boards, cosmetics shop.


func test_chain_runtime_progression() -> void:
	var cr := ChainRuntime.from_data(load_json("chains"))
	assert_true(cr.ids().size() == 3)
	assert_eq(cr.step_of("smuggling"), 0)
	cr.start("smuggling")
	assert_eq(cr.step_of("smuggling"), 1)
	assert_eq(cr.current_key("smuggling"), "CHAIN_SMUGGLING_1")
	assert_true(cr.is_active("smuggling"))
	# choice index 1 = "hide" with next:2 -> jumps to step 2
	cr.advance("smuggling", 1)
	assert_eq(cr.step_of("smuggling"), 2)
	# plain advance walks forward
	cr.advance("smuggling", -1)
	assert_eq(cr.step_of("smuggling"), 3)
	cr.advance("smuggling", -1)
	assert_eq(cr.step_of("smuggling"), 4)
	assert_true(cr.is_active("smuggling"))
	cr.advance("smuggling", -1)
	assert_true(cr.is_finished("smuggling"))
	assert_eq(cr.finished_count(), 1)


func test_relations_clamp_and_tiers() -> void:
	var r := Relations.new()
	assert_eq(r.get_relation("x"), 0)
	assert_eq(r.adjust("x", 8), 8)
	assert_eq(r.tier("x"), "hostile")
	r.adjust("x", 40)
	assert_eq(r.get_relation("x"), 48)
	assert_eq(r.tier("x"), "friendly")
	r.adjust("x", 100)
	assert_eq(r.get_relation("x"), 100)
	assert_eq(r.tier("x"), "ally")
	r.adjust("x", -500)
	assert_eq(r.get_relation("x"), 0)
	assert_eq(Relations.delta_for_grade("gold"), 8)
	assert_eq(Relations.delta_for_grade("fail"), -10)
	assert_true(r.reward_bonus("x") >= 1.0)


func test_directive_board_flow() -> void:
	var dirs := Directives.from_data(load_json("directives"))
	var board := DirectiveBoard.from_data(dirs, PCG32.new(7, 1), 0, 3, 2)
	assert_eq(board.active.size(), 6)  # 1 linear + 3 daily + 2 weekly
	var linear_id: String = String(board.active[0]["id"])
	assert_eq(linear_id, "lin1")
	# lin1 goal is {hires, 1}
	var done: Array = board.report("hires", 1.0)
	assert_true(done.has("lin1"))
	assert_true(board.is_complete("lin1"))
	assert_true(not board.is_claimed("lin1"))
	var reward: Dictionary = board.claim("lin1")
	assert_true(reward.has("tokens"))
	assert_true(board.is_claimed("lin1"))
	assert_true(board.claim("lin1").is_empty())  # cannot double-claim
	# unrelated stat does nothing
	assert_true(board.report("duels_won", 1.0).is_empty())


func test_shop_buy_rules() -> void:
	var shop := Shop.from_data(load_json("cosmetics"))
	assert_eq(shop.price("skin", "neon"), 300)
	assert_eq(shop.key_of("skin", "neon"), "COS_SKIN_NEON")
	assert_eq(shop.cost_if_buyable("skin", "neon", [], 500.0), 300)
	assert_eq(shop.cost_if_buyable("skin", "neon", [], 100.0), -1)  # too poor
	assert_eq(shop.cost_if_buyable("skin", "neon", ["neon"], 500.0), -1)  # owned
	assert_eq(shop.cost_if_buyable("skin", "classic", [], 500.0), -1)  # price 0
	var equipped := {}
	assert_true(shop.equip("skin", "classic", equipped, ["classic"]))
	assert_eq(equipped["skin"], "classic")
	assert_false(shop.equip("skin", "gold", equipped, []))  # not owned