extends TestCase

## T2 — lint_screen smoke (TZ §2.14).


func _make_scale() -> Node:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	return us


func test_lint_empty_root() -> void:
	var us: Node = _make_scale()
	var lint: RefCounted = (load("res://src/core/ui_lint.gd") as GDScript).new()
	var root := Control.new()
	root.name = "UiRoot"
	us.call("register_root", root)
	assert_true(lint != null)
	for s in [1, 2, 3]:
		us.call("set_scale", s, false)
		assert_eq(us.call("logical_size"), Vector2(480.0 / float(s), 270.0 / float(s)), "logical S%d" % s)
		var hits: Array = lint.call("lint_screen", root)
		assert_eq(hits.size(), 0, "empty root S%d hits=%s" % [s, str(hits)])
	root.free()
	us.free()
