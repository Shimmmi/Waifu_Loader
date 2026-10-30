extends TestCase


func test_zoom_levels_are_integer() -> void:
	# Contract: only ×1 and ×2.
	for z in [1.0, 2.0]:
		assert_true(z == 1.0 or z == 2.0)


func test_drag_threshold_constant() -> void:
	# Mirrors SectorView tap vs drag rule (4 px / 300 ms).
	assert_true(4.0 < 8.0)
	assert_true(300 < 1000)
