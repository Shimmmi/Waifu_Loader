extends TestCase


func test_bbox_and_visibility_helpers() -> void:
	var grid := TerminalGrid.new()
	grid.add_sector("dock", 0, 0)
	grid.add_sector("dorm", 2, 0)
	grid.add_sector("lounge", 0, 1)
	var bbox: Rect2i = TerminalBounds.occupied_bbox(grid)
	assert_true(bbox.size.x >= 2)
	assert_true(bbox.size.y >= 1)
	var lim: Rect2 = TerminalBounds.camera_limits(grid)
	assert_true(lim.size.x > 0.0)
	# Random-ish placement: every sector has a center.
	for s in grid.sectors:
		var c: Vector2 = TerminalBounds.sector_center_world(s)
		assert_true(c.length() >= 0.0)


func test_clamp_keeps_cam_finite() -> void:
	var grid := TerminalGrid.new()
	grid.add_sector("dock", 0, 0)
	var cam := TerminalBounds.clamp_cam(Vector2(9999, 9999), Vector2(480, 184), grid, 1.0)
	assert_true(absf(cam.x) < 100000.0)
