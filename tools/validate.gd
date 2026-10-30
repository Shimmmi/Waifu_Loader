extends SceneTree

## Headless validator interface (spec §14.6). Reads a JSON payload on stdin and
## writes a JSON result on stdout. Usage:
##   godot --headless --path . -s tools/validate.gd <mode>
## modes: power_estimate | duel | daily | tender
##
## The Sim is deterministic (PCG32), so the server's result is authoritative and
## must match the client's for the same plan.

func _init() -> void:
	var mode: String = "power_estimate"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	else:
		# With -s the mode is appended after the script path.
		var all: PackedStringArray = OS.get_cmdline_args()
		if all.size() > 0:
			var last: String = all[all.size() - 1]
			if last in ["power_estimate", "duel", "daily", "tender"]:
				mode = last

	var input_text: String = ""
	if not OS.has_feature("web"):
		var f := FileAccess.open("/dev/stdin", FileAccess.READ)
		if f != null:
			input_text = f.get_as_text()
	if input_text.strip_edges() == "":
		input_text = "{}"

	var payload: Variant = JSON.parse_string(input_text)
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}

	var result: Dictionary = _dispatch(mode, payload as Dictionary)
	print(JSON.stringify(result))
	quit(0)


func _dispatch(mode: String, payload: Dictionary) -> Dictionary:
	match mode:
		"power_estimate":
			return _power_estimate(payload)
		"duel":
			return { "mode": "duel", "sim_version": _sim_version() }
		"daily":
			return { "mode": "daily", "sim_version": _sim_version() }
		"tender":
			return { "mode": "tender", "sim_version": _sim_version() }
	return { "error": "unknown mode", "mode": mode }


## Theoretical max tonnes/min from a power snapshot (spec §13.4). A coarse but
## deterministic estimate used to bound telemetry.
func _power_estimate(payload: Dictionary) -> Dictionary:
	var catalog: Catalog = Catalog.from_dicts(_load_table("cargo"), _load_table("balance"))
	var dock_arr: Array = payload.get("dock", [])
	if dock_arr.is_empty():
		dock_arr = [1]
	var storage_arr: Array = payload.get("storage", [])
	if storage_arr.is_empty():
		storage_arr = [1]
	var dock_level: int = int(dock_arr[0])
	var store_level: int = int(storage_arr[0])

	# Station powers: rough per-slot contribution from crew snapshot.
	var power := { "unload": 1.0, "move": 1.0, "store": 1.0 }
	for c in payload.get("crew", []):
		var cls: String = String(c.get("c", ""))
		var lv: float = float(c.get("lv", 1))
		var contribution: float = lv / 25.0
		if cls == "loader":
			power["unload"] += contribution
		elif cls == "crane_operator" or cls == "driver":
			power["move"] += contribution
		elif cls == "storekeeper":
			power["store"] += contribution

	var tree: Dictionary = payload.get("tree", {})
	var tree_speed: float = 1.0 + 0.05 * float(tree.get("clearing", 0)) + 0.10 * float(tree.get("orbital_quota", 0))

	var unload: float = catalog.station_rate("unload", dock_level, power["unload"]) * tree_speed
	var move: float = catalog.station_rate("move", dock_level, power["move"]) * tree_speed
	var store: float = catalog.station_rate("store", store_level, power["store"]) * tree_speed
	var bottleneck: float = maxf(minf(unload, minf(move, store)), 0.001)

	return { "rate_cap": bottleneck, "sim_version": _sim_version() }


func _sim_version() -> int:
	return int(_load_table("version").get("sim_version", 1))


## Load a data table straight from res:// (autoloads are unavailable under -s).
func _load_table(table_name: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://data/%s.json" % table_name)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}