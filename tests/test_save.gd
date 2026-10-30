extends TestCase

## Save serialization round-trips (spec §2.7).


func test_worker_round_trip() -> void:
	var w := Worker.new()
	w.id = "w1"
	w.full_name = "Тест Тестов"
	w.callsign = "Т"
	w.species = "human"
	w.class_id = "loader"
	w.rarity = 2
	w.level = 5
	w.xp = 12.5
	w.point_stats = { "str": 30, "agi": 20 }
	w.traits = [{ "id": "strong", "hidden": false }]
	w.star = "a"
	w.psycho = "calm"
	w.wage = 25.0
	w.morale = 70.0
	w.fatigue = 8.0
	w.status = "shift"
	w.skills = { "1": "quick_hands" }
	w.equip = "gloves"
	w.pinned = true
	w.appearance = { "hair": 3 }
	w.shifts_worked = 9
	w.friends = { "w2": 4 }
	var back := Worker.from_dict(w.to_dict())
	assert_eq(back.id, "w1")
	assert_eq(back.class_id, "loader")
	assert_eq(back.level, 5)
	assert_close(back.xp, 12.5, 1e-6)
	assert_eq(int(back.point_stats["str"]), 30)
	assert_eq(back.traits.size(), 1)
	assert_true(back.pinned)
	assert_eq(back.skills["1"], "quick_hands")
	assert_eq(int(back.friends["w2"]), 4)
	assert_eq(back.shifts_worked, 9)


func test_sector_round_trip() -> void:
	var s := Sector.new("dock", 2, 1, Vector2i(2, 2))
	s.level = 3
	s.modifier_id = "fast"
	s.build_time_left = 12.5
	s.broken = true
	var back := Sector.from_dict(s.to_dict())
	assert_eq(back.type_id, "dock")
	assert_eq(back.col, 2)
	assert_eq(back.floor_y, 1)
	assert_eq(back.size, Vector2i(2, 2))
	assert_eq(back.level, 3)
	assert_eq(back.modifier_id, "fast")
	assert_close(back.build_time_left, 12.5, 1e-6)
	assert_true(back.broken)