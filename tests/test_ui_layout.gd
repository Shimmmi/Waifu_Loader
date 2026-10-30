extends TestCase

## T2 — UiLint.lint_screen on present screens (smoke; full golden capture in step 11).


func test_lint_uiscale_root() -> void:
	var root := Control.new()
	root.name = "UiRoot"
	root.size = UiScale.logical_size()
	UiScale.register_root(root)
	for s in [1, 2, 3]:
		UiScale.set_scale(s, false)
		root.size = UiScale.logical_size()
		var hits: Array = UiLint.lint_screen(root)
		# Empty root should be clean.
		assert_eq(hits.size(), 0, "empty root S%d hits=%s" % [s, str(hits)])
	UiScale.set_scale(1, false)
	root.free()
