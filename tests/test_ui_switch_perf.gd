extends TestCase

## T8 — scale switch performance (TZ §2.13).


func test_switch_budget() -> void:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 1, false)
	var t0: int = Time.get_ticks_usec()
	us.call("set_scale", 2, false)
	var dt_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	assert_true(dt_ms <= 100.0, "set_scale took %s ms" % dt_ms)
	for i in 20:
		us.call("set_scale", 1 + (i % 3), false)
	assert_eq(us.get("scale_factor"), 1 + (19 % 3), "last scale applied")
	us.call("set_scale", 1, false)
	root.free()
	us.free()
