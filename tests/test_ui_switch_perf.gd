extends TestCase

## T8 — scale switch performance / no leaks (TZ §2.13).


func test_switch_budget() -> void:
	var root := Control.new()
	UiScale.register_root(root)
	UiScale.set_scale(1, false)
	var t0: int = Time.get_ticks_usec()
	UiScale.set_scale(2, false)
	var dt_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	assert_true(dt_ms <= 100.0, "set_scale took %s ms" % dt_ms)
	var before: int = Engine.get_main_loop().root.get_child_count()
	for i in 20:
		UiScale.set_scale(1 + (i % 3), false)
	var after: int = Engine.get_main_loop().root.get_child_count()
	assert_eq(after, before, "root child count stable after 20 switches")
	UiScale.set_scale(1, false)
	root.free()
