extends TestCase

## T7 — ui_scale persistence (TZ §2.14 / §2.12).


func test_corrupt_fallback() -> void:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 99, false)
	assert_eq(us.get("scale_factor"), 1, "corrupt → 1")
	root.free()
	us.free()


func test_setting_key_roundtrip_file() -> void:
	# Settings go through SaveSystem at runtime; here we assert the key shape
	# accepted by UiScale._ready path (int 1..3).
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 2, false)
	assert_eq(us.get("scale_factor"), 2)
	us.call("set_scale", 3, false)
	assert_eq(us.get("scale_factor"), 3)
	us.call("set_scale", 1, false)
	assert_eq(us.get("scale_factor"), 1)
	root.free()
	us.free()
