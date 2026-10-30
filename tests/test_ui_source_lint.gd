extends TestCase

## T6 — forbidden UI patterns (TZ §2.14).


func test_source_lint_clean() -> void:
	var hits: Array = UiLint.source_lint()
	assert_eq(hits.size(), 0, "source lint hits: %s" % str(hits))
