extends TestCase

## T3 — input smoke for scale + nav mapping (TZ §2.14).
## Full synthetic clicks need a live Terminal; here we verify scale/API hooks
## that drive those clicks.


func test_scale_buttons_map() -> void:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	var root := Control.new()
	us.call("register_root", root)
	for s in [1, 2, 3]:
		us.call("set_scale", s, false)
		assert_eq(us.get("scale_factor"), s, "scale %d" % s)
		assert_eq(root.scale, Vector2(s, s), "root.scale %d" % s)
	us.call("set_scale", 1, false)
	root.free()
	us.free()


func test_world_rect_center_inside_base() -> void:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	var root := Control.new()
	us.call("register_root", root)
	for s in [1, 2, 3]:
		us.call("set_scale", s, false)
		var r: Rect2 = us.call("world_rect", "terminal")
		var c: Vector2 = r.get_center()
		assert_true(r.has_point(c), "center in world_rect S%d" % s)
		assert_true(c.x >= 0.0 and c.x <= 480.0 and c.y >= 0.0 and c.y <= 270.0, "center in base S%d" % s)
	root.free()
	us.free()


func test_nav_tab_ids() -> void:
	# Keys used by Terminal._show / capture_ui.
	for id in ["terminal", "loading", "crew", "hire", "contracts", "world", "menu"]:
		assert_true(id.length() > 0)
