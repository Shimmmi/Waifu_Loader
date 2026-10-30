extends TestCase

## T6 — forbidden UI patterns (TZ §2.14).


func test_source_lint_clean() -> void:
	var lint: RefCounted = (load("res://src/core/ui_lint.gd") as GDScript).new()
	assert_true(lint != null, "ui_lint.gd loads")
	var hits: Array = lint.call("source_lint")
	assert_eq(hits.size(), 0, "source lint hits: %s" % str(hits))
