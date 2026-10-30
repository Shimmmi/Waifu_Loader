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
	var seen: Dictionary = {}
	_discover_dir(TESTS_DIR, out, seen)
	out.sort()
	return out


func _discover_dir(dir_path: String, out: Array[String], seen: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("run.gd: cannot open " + dir_path)
		return
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if f.begins_with("."):
			f = dir.get_next()
			continue
		var path: String = dir_path.path_join(f)
		if dir.current_is_dir():
			_discover_dir(path, out, seen)
		elif f.begins_with("test_") and f.ends_with(".gd"):
			# Prefer first path; skip duplicate basenames (e.g. tests/ui copies).
			if not seen.has(f):
				seen[f] = true
				out.append(path)
		f = dir.get_next()
	dir.list_dir_end()