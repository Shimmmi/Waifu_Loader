extends TestCase

## T1 — UiScale API (TZ v0.3 §2.14). Instantiates the autoload script (no global needed).

func _make() -> Node:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	return us


func test_logical_sizes() -> void:
	var us: Node = _make()
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 1, false)
	assert_eq(us.call("logical_size"), Vector2(480, 270), "S1 logical")
	assert_eq(root.scale, Vector2(1, 1), "S1 scale")
	assert_eq(root.size, Vector2(480, 270), "S1 size")
	us.call("set_scale", 2, false)
	assert_eq(us.call("logical_size"), Vector2(240, 135), "S2 logical")
	assert_eq(root.scale, Vector2(2, 2), "S2 scale")
	assert_eq(root.size, Vector2(240, 135), "S2 size")
	us.call("set_scale", 3, false)
	assert_eq(us.call("logical_size"), Vector2(160, 90), "S3 logical")
	assert_eq(root.scale, Vector2(3, 3), "S3 scale")
	assert_eq(root.size, Vector2(160, 90), "S3 size")
	root.free()
	us.free()


func test_invalid_fallback() -> void:
	var us: Node = _make()
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 1, false)
	us.call("set_scale", 0, false)
	assert_eq(us.get("scale_factor"), 1, "0 → 1")
	us.call("set_scale", 4, false)
	assert_eq(us.get("scale_factor"), 1, "4 → 1")
	us.call("set_scale", -1, false)
	assert_eq(us.get("scale_factor"), 1, "-1 → 1")
	root.free()
	us.free()


func test_signal_once_per_change() -> void:
	var us: Node = _make()
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 1, false)
	var hits: Array = []
	var cb := func(s: int) -> void: hits.append(s)
	us.connect("scale_changed", cb)
	us.call("set_scale", 2, false)
	us.call("set_scale", 2, false)
	us.call("set_scale", 3, false)
	assert_eq(hits.size(), 2, "two real changes")
	assert_eq(hits[0], 2)
	assert_eq(hits[1], 3)
	root.free()
	us.free()
