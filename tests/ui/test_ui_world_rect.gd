extends TestCase

## T4 — world_rect vs metrics (TZ §2.5 / IR-15: S1 from inventory, S2/S3 from TZ).

func _make() -> Node:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	return us


func test_world_rect_all_scales() -> void:
	var us: Node = _make()
	var root := Control.new()
	us.call("register_root", root)
	var cases: Array = [
		[1, "terminal", 65.0, 180.0],
		[1, "line", 24.0, 221.0],
		[2, "terminal", 64.0, 174.0],
		[2, "line", 32.0, 206.0],
		[3, "terminal", 36.0, 192.0],
		[3, "line", 36.0, 192.0],
	]
	for c in cases:
		us.call("set_scale", int(c[0]), false)
		var r: Rect2 = us.call("world_rect", String(c[1]))
		assert_eq(r.position.x, 0.0, "%s S%d x" % [c[1], c[0]])
		assert_eq(r.size.x, 480.0, "%s S%d w" % [c[1], c[0]])
		assert_eq(r.position.y, float(c[2]), "%s S%d y" % [c[1], c[0]])
		assert_eq(r.size.y, float(c[3]), "%s S%d h" % [c[1], c[0]])
	root.free()
	us.free()
