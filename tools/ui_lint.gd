extends SceneTree

## CLI: source lint (TZ v0.3 §2.14 T6).
## Run: godot --headless --path . -s tools/ui_lint.gd

func _init() -> void:
	var lint: RefCounted = (load("res://src/core/ui_lint.gd") as GDScript).new()
	var hits: Array = lint.call("source_lint")
	print("=== ui_lint (source) ===")
	for h in hits:
		print("  HIT  " + h)
	if hits.is_empty():
		print("OK")
		quit(0)
	else:
		print("FAILED (%d)" % hits.size())
		quit(1)
