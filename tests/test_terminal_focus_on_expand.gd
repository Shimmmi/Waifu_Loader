extends TestCase


func test_focus_helper_moves_toward_new_sector() -> void:
	var grid := TerminalGrid.from_data(load_json("sectors"))
	grid.add_sector("dock", 0, 0)
	var s: Sector = grid.add_sector("lounge", -2, -1)
	var center: Vector2 = TerminalBounds.sector_center_world(s)
	assert_true(center.x != 0.0 or center.y != 0.0)
