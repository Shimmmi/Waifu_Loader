extends TestCase

## T7 — ui_scale persistence (TZ §2.14 / §2.12).


func test_persist_roundtrip() -> void:
	SaveSystem.set_setting("ui_scale", 2)
	SaveSystem.store()
	var loaded: Dictionary = SaveSystem.settings()
	assert_eq(int(loaded.get("ui_scale", 0)), 2, "stored 2")
	SaveSystem.set_setting("ui_scale", 3)
	SaveSystem.store()
	assert_eq(int(SaveSystem.settings().get("ui_scale", 0)), 3, "stored 3")
	SaveSystem.set_setting("ui_scale", 1)
	SaveSystem.store()


func test_corrupt_fallback() -> void:
	var us: Node = (load("res://src/core/ui_scale.gd") as GDScript).new()
	us.set("_metrics", us.call("_load_metrics"))
	var root := Control.new()
	us.call("register_root", root)
	us.call("set_scale", 99, false)
	assert_eq(us.get("scale_factor"), 1, "corrupt → 1")
	root.free()
	us.free()
