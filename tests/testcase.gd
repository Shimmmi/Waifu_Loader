class_name TestCase
extends RefCounted

## Minimal test base class. Subclasses live in res://tests/test_*.gd and define
## methods named test_*. Each such method is invoked by run_all() and may call
## the assert_* helpers below. Reloaded for v0.2.

var _failures: Array[String] = []
var _checks: int = 0


func assert_true(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	_checks += 1
	if condition:
		_fail("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_checks += 1
	if actual != expected:
		_fail("expected %s, got %s" % [str(expected), str(actual)], message)


func assert_close(actual: float, expected: float, eps: float = 1e-9, message: String = "") -> void:
	_checks += 1
	if absf(actual - expected) > eps:
		_fail("expected %s ± %s, got %s" % [expected, eps, actual], message)


func assert_between(actual: float, low: float, high: float, message: String = "") -> void:
	_checks += 1
	if actual < low or actual > high:
		_fail("expected in [%s, %s], got %s" % [low, high, actual], message)


## Load a data table from res://data/<name>.json.
func load_json(table_name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % table_name))


## Build the Rules bundle from every HR data table.
func load_rules() -> Rules:
	return Rules.from_data(
		load_json("classes"), load_json("species"), load_json("stars"),
		load_json("psycho"), load_json("synergy"), load_json("rarity"),
		load_json("traits"), load_json("skills"), load_json("names"))


## Invoke every test_* method and return {failures: Array[String], checks: int}.
func run_all() -> Dictionary:
	_failures.clear()
	_checks = 0
	for m in get_method_list():
		var mname: String = m["name"]
		if mname.begins_with("test_") and (m["args"] as Array).is_empty():
			callv(mname, [])
	return {"failures": _failures.duplicate(), "checks": _checks}


func _fail(what: String, message: String) -> void:
	var where: String = get_script().resource_path.get_file()
	var suffix: String = (" — " + message) if not message.is_empty() else ""
	_failures.append("%s: %s%s" % [where, what, suffix])