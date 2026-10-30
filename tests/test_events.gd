extends TestCase

## Event/deck data validation and draw (spec §11, §17.1).


func test_has_36_events() -> void:
	var deck := EventDeck.new(load_json("events"))
	assert_eq(deck.events.size(), 36)


func test_every_event_is_well_formed() -> void:
	var deck := EventDeck.new(load_json("events"))
	for e in deck.events:
		var id: String = String(e["id"])
		assert_true(float(e.get("weight", 0)) > 0.0, "%s weight" % id)
		var choices: Array = e.get("choices", [])
		assert_true(not choices.is_empty(), "%s has choices" % id)
		var ids: Array = []
		for ch in choices:
			ids.append(String(ch["id"]))
		assert_true(ids.has(String(e.get("default_choice", ""))), "%s default_choice in choices" % id)


func test_effect_types_are_known() -> void:
	var deck := EventDeck.new(load_json("events"))
	for e in deck.events:
		for ch in e.get("choices", []):
			for eff in ch.get("effects", []):
				assert_true(EventDeck.EFFECT_TYPES.has(String(eff["type"])),
					"unknown effect %s in %s" % [eff["type"], e["id"]])


func test_all_events_have_default_effects_are_optional() -> void:
	# sanity: each choice is either a cost, a check, or plain effects
	var deck := EventDeck.new(load_json("events"))
	for e in deck.events:
		for ch in e.get("choices", []):
			assert_true(ch.has("id"), "%s choice id" % e["id"])


func test_draw_deterministic() -> void:
	var deck := EventDeck.new(load_json("events"))
	var a: Dictionary = deck.draw(PCG32.new(5, 5), 12, {})
	var b: Dictionary = deck.draw(PCG32.new(5, 5), 12, {})
	assert_eq(a.get("id", ""), b.get("id", ""))


func test_eligibility_min_rank() -> void:
	var deck := EventDeck.new(load_json("events"))
	var low: Array = deck.eligible(1, {})
	for e in low:
		assert_eq(int((e.get("conditions", {}) as Dictionary).get("min_rank", 0)), 0,
			"rank-1 pool must only contain rankless events")
	# a rank-30 pool is larger than a rank-1 pool
	assert_true(deck.eligible(30, {"active_contract": true}).size() > low.size())


func test_chains_well_formed() -> void:
	var chains: Array = (load_json("chains") as Dictionary)["chains"]
	assert_eq(chains.size(), 3)
	for ch in chains:
		assert_eq((ch["step_keys"] as Array).size(), int(ch["steps"]), "%s step_keys" % ch["id"])
		assert_true(not (ch["choices"] as Array).is_empty(), "%s choices" % ch["id"])
		for c in ch["choices"]:
			if c.has("next"):
				var nxt: int = int(c["next"])
				assert_true(nxt >= 1 and nxt <= int(ch["steps"]), "%s next in range" % ch["id"])