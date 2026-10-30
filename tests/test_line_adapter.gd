extends TestCase


func test_crate_accumulator_cap() -> void:
	var flow := CrateFlow.new()
	flow.configure(1.0)
	for i in 30:
		flow.step(5.0, 0.2, Vector2.ZERO, Vector2(100, 0))
	assert_true(flow.flying.size() <= CrateFlow.MAX_FLYING)


func test_buffer_stages() -> void:
	var flow := CrateFlow.new()
	assert_eq(flow.stage_for_fill(0, 100), 0)
	assert_eq(flow.stage_for_fill(15, 100), 1)
	assert_eq(flow.stage_for_fill(95, 100), 5)


func test_adapter_source_exists() -> void:
	# LineViewAdapter references autoloads; headless -s cannot compile it via load().
	# Presence + shape of the contract is checked here instead.
	var text: String = FileAccess.get_file_as_string("res://src/view/line/line_view_adapter.gd")
	assert_true(text.find("func snapshot") >= 0)
	assert_true(text.find("crate_u") >= 0)
	assert_true(text.find("bottleneck") >= 0)
