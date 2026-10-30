extends TestCase

## Crew contribution tests (spec §6.3, §17.1).

var _crew: Crew
var _classes: Dictionary


func _load_crew() -> Crew:
	if _crew == null:
		_classes = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes.json"))
		var bal: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
		_crew = Crew.from_dicts(_classes, bal)
	return _crew


func test_class_weights_sum_to_one() -> void:
	for row in _classes.get("classes", []):
		var total: float = 0.0
		for v in (row["weights"] as Dictionary).values():
			total += float(v)
		assert_close(total, 1.0, 1e-6, "class %s weights" % row["id"])


func test_skill_index_weighted_sum() -> void:
	var crew := _load_crew()
	var stats := {"str": 20.0, "agi": 10.0, "acc": 10.0, "end": 20.0, "wit": 10.0}
	# loader weights: .35/.15/.10/.30/.10
	var expected: float = 0.35 * 20 + 0.15 * 10 + 0.10 * 10 + 0.30 * 20 + 0.10 * 10
	assert_close(crew.skill_index("loader", stats), expected, 1e-6)


func test_contrib_is_si_over_25() -> void:
	var crew := _load_crew()
	var stats := {"str": 25.0, "agi": 25.0, "acc": 25.0, "end": 25.0, "wit": 25.0}
	# all weights sum to 1, so SI = 25, contrib = 1.0
	assert_close(crew.contrib("loader", stats), 1.0, 1e-6)


func test_class_fit_values() -> void:
	var crew := _load_crew()
	assert_close(crew.class_fit("unload", "loader"), 1.0, 1e-6)
	assert_close(crew.class_fit("move", "driver"), 1.0, 1e-6)
	assert_close(crew.class_fit("store", "storekeeper"), 1.0, 1e-6)
	assert_close(crew.class_fit("move", "crane"), 0.2, 1e-6)
	# unknown class defaults to 0.2
	assert_close(crew.class_fit("unload", "nobody"), 0.2, 1e-6)


func test_station_power_aggregates_workers() -> void:
	var crew := _load_crew()
	var stats := {"str": 25.0, "agi": 25.0, "acc": 25.0, "end": 25.0, "wit": 25.0}
	var workers: Array = [
		{"class": "loader", "stats": stats, "m": 1.0},
		{"class": "loader", "stats": stats, "m": 0.5},
	]
	# unload fit for loader is 1.0 -> 1.0*1.0 + 1.0*0.5 = 1.5
	assert_close(crew.station_power("unload", workers), 1.5, 1e-6)


func test_station_power_uses_fit() -> void:
	var crew := _load_crew()
	var stats := {"str": 25.0, "agi": 25.0, "acc": 25.0, "end": 25.0, "wit": 25.0}
	# a loader contributes to store at fit 0.5 -> 0.5
	var workers: Array = [{"class": "loader", "stats": stats, "m": 1.0}]
	assert_close(crew.station_power("store", workers), 0.5, 1e-6)