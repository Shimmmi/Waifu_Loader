extends SceneTree

## Test runner. Usage:
##   godot --headless --path <project> -s tests/run.gd
## Discovers res://tests/test_*.gd, runs them, prints a summary and exits with
## code 0 (all passed) or 1 (any failure).

const TESTS_DIR: String = "res://tests"


func _init() -> void:
	var files: Array[String] = _discover()
	var total_checks: int = 0
	var total_failures: int = 0

	print("=== Running %d test file(s) ===" % files.size())
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			total_failures += 1
			print("  FAIL  %-28s (script failed to load)" % path.get_file())
			continue
		var tc: TestCase = script.new()
		var result: Dictionary = tc.run_all()
		var failures: Array = result["failures"]
		total_checks += result["checks"]
		if failures.is_empty():
			print("  PASS  %-28s (%d checks)" % [path.get_file(), result["checks"]])
		else:
			total_failures += failures.size()
			print("  FAIL  %-28s" % path.get_file())
			for msg in failures:
				print("          " + msg)

	print("")
	print("%d check(s), %d failure(s)" % [total_checks, total_failures])
	if total_failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("TESTS FAILED")
		quit(1)


func _discover() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("run.gd: cannot open " + TESTS_DIR)
		return out
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.begins_with("test_") and f.ends_with(".gd"):
			out.append(TESTS_DIR + "/" + f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out