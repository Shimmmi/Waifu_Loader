extends SceneTree

## Validates res://data/*.json against expected schemas (spec §2.6, §17.1).
## Run:  godot --headless --path <project> -s src/tools/validate_data.gd
## Exits 0 if clean, 1 if any error. Warnings do not fail the run.

const DATA_DIR: String = "res://data"

var _errors: Array[String] = []
var _warnings: Array[String] = []


func _init() -> void:
	var tables := _load_tables()
	_check_version(tables.get("version"))
	_check_currencies(tables.get("currencies"))
	_check_cargo(tables.get("cargo"))
	_check_balance(tables.get("balance"), tables.get("cargo"))
	_check_classes(tables.get("classes"))
	_check_species(tables.get("species"))
	_check_hr(tables)

	print("=== validate_data ===")
	print("tables: " + str(tables.keys()))
	for w in _warnings:
		print("  WARN  " + w)
	for e in _errors:
		print("  ERROR " + e)
	if _errors.is_empty():
		print("OK (%d warning(s))" % _warnings.size())
		quit(0)
	else:
		print("FAILED (%d error(s))" % _errors.size())
		quit(1)


func _load_tables() -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		_error("cannot open " + DATA_DIR)
		return out
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			var text: String = FileAccess.get_file_as_string(DATA_DIR + "/" + f)
			var parsed: Variant = JSON.parse_string(text)
			if parsed == null:
				_error("invalid JSON: " + f)
			else:
				out[f.get_basename()] = parsed
		f = dir.get_next()
	dir.list_dir_end()
	return out


func _check_version(v: Variant) -> void:
	if v == null:
		_error("version.json missing")
		return
	_require_keys(v, ["client_version", "sim_version", "save_version"], "version")
	if v.has("sim_version") and not _is_number(v["sim_version"]):
		_error("version.sim_version must be a number")


func _check_currencies(v: Variant) -> void:
	if v == null:
		_error("currencies.json missing")
		return
	if not (v is Dictionary) or not v.has("currencies"):
		_error("currencies.json must have a 'currencies' array")
		return
	var list: Array = v["currencies"]
	if list.is_empty():
		_error("currencies list is empty")
	var seen: Dictionary = {}
	for row in list:
		var id: String = String(row.get("id", ""))
		if id.is_empty():
			_error("currency without id")
		elif seen.has(id):
			_error("duplicate currency id: " + id)
		seen[id] = true
		if not row.has("sign"):
			_error("currency %s missing 'sign'" % id)


func _check_cargo(v: Variant) -> void:
	if v == null:
		_error("cargo.json missing")
		return
	var rows: Array = v.get("cargo", [])
	if rows.size() != 7:
		_error("cargo.json: expected 7 types, found %d" % rows.size())
	var seen: Dictionary = {}
	for row in rows:
		var id: String = String(row.get("id", ""))
		if id.is_empty():
			_error("cargo row without id")
			continue
		if seen.has(id):
			_error("duplicate cargo id: " + id)
		seen[id] = true
		if not (row.get("price", 0.0) as float > 0.0):
			_error("cargo %s: price must be > 0" % id)
		var phi: Variant = row.get("phi", null)
		if not (phi is Dictionary):
			_error("cargo %s: missing phi dict" % id)
			continue
		for station in Catalog.STATIONS:
			if not phi.has(station):
				_error("cargo %s: phi missing '%s'" % [id, station])
			elif not ((phi[station] as float) > 0.0):
				_error("cargo %s: phi.%s must be > 0" % [id, station])


func _check_balance(v: Variant, cargo: Variant) -> void:
	if v == null:
		_error("balance.json missing")
		return
	_require_keys(v, ["sim_dt", "offline_chunk_s", "q0_cap", "stations", "auto_rate", "base_rate", "tariff_base"], "balance")
	for key in ["auto_rate", "base_rate"]:
		var table: Variant = v.get(key, null)
		if table is Dictionary:
			for station in Catalog.STATIONS:
				if not (table as Dictionary).has(station):
					_error("balance.%s missing station '%s'" % [key, station])


func _check_classes(v: Variant) -> void:
	if v == null:
		_error("classes.json missing")
		return
	var rows: Array = v.get("classes", [])
	if rows.size() != 6:
		_error("classes.json: expected 6 classes, found %d" % rows.size())
	var ids: Dictionary = {}
	for row in rows:
		var id: String = String(row.get("id", ""))
		ids[id] = true
		var w: Variant = row.get("weights", null)
		if not (w is Dictionary):
			_error("class %s: missing weights" % id)
			continue
		var total: float = 0.0
		for s in Crew.STATS:
			if not (w as Dictionary).has(s):
				_error("class %s: weights missing '%s'" % [id, s])
			else:
				total += float((w as Dictionary)[s])
		if absf(total - 1.0) > 1e-6:
			_error("class %s: weights sum to %.4f (expected 1.0)" % [id, total])

	var fit: Variant = v.get("class_fit", null)
	if not (fit is Dictionary):
		_error("classes.json: missing class_fit")
		return
	for station in Catalog.STATIONS:
		var row_fit: Variant = (fit as Dictionary).get(station, null)
		if not (row_fit is Dictionary):
			_error("class_fit missing station '%s'" % station)
			continue
		for id in ids.keys():
			if not (row_fit as Dictionary).has(id):
				_error("class_fit.%s missing class '%s'" % [station, id])


func _check_species(v: Variant) -> void:
	if v == null:
		_error("species.json missing")
		return
	var allowed: Dictionary = {"human": true, "silicate": true, "android": true, "gel": true, "avian": true}
	var rows: Array = v.get("species", [])
	if rows.size() != 5:
		_error("species.json: expected 5 species, found %d" % rows.size())
	for row in rows:
		var id: String = String(row.get("id", ""))
		if id == "ovion":
			_error("species id 'ovion' is legacy; use 'avian'")
		elif not allowed.has(id):
			_error("species id outside whitelist: " + id)
		var mult: Variant = row.get("mult", null)
		if not (mult is Dictionary):
			_error("species %s: missing mult" % id)
			continue
		for s in Crew.STATS:
			if not (mult as Dictionary).has(s):
				_error("species %s: mult missing '%s'" % [id, s])


func _check_hr(t: Dictionary) -> void:
	var stars: Variant = t.get("stars")
	if stars == null or (stars.get("stars", []) as Array).size() != 12:
		_error("stars.json: expected 12 signs")

	var psycho: Variant = t.get("psycho")
	if psycho == null or (psycho.get("psycho", []) as Array).size() != 6:
		_error("psycho.json: expected 6 psychotypes")
	if psycho != null:
		var m: Dictionary = psycho.get("matrix", {})
		var ids: Array = m.keys()
		for a in ids:
			for b in ids:
				var ab: float = float((m[a] as Dictionary).get(b, 0))
				var ba: float = float((m[b] as Dictionary).get(a, 0))
				if not is_equal_approx(ab, ba):
					_error("psycho matrix asymmetric: %s/%s (%s vs %s)" % [a, b, ab, ba])

	var rarity: Variant = t.get("rarity")
	if rarity != null:
		for row in rarity.get("agency_odds", []):
			if (row as Array).size() != 5:
				_error("rarity.agency_odds rows must have 5 values")

	var traits: Variant = t.get("traits")
	if traits != null and (traits.get("traits", []) as Array).size() < 20:
		_error("traits.json: expected >= 20 traits")

	var skills: Variant = t.get("skills")
	if skills != null:
		var classes: Dictionary = {}
		for row in skills.get("skills", []):
			classes[row["class"]] = true
		if classes.size() != 6:
			_error("skills.json: expected skills for 6 classes, found %d" % classes.size())


func _require_keys(dict: Variant, keys: Array, where: String) -> void:
	if not (dict is Dictionary):
		_error("%s must be an object" % where)
		return
	for k in keys:
		if not (dict as Dictionary).has(k):
			_error("%s missing key '%s'" % [where, k])


func _is_number(v: Variant) -> bool:
	return v is int or v is float


func _error(msg: String) -> void:
	_errors.append(msg)