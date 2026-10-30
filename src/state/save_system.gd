extends Node

## Autoload "SaveSystem" — local save load/store (spec §2.7).
##
## M0 scope: plain JSON in user://save_main.json. The full format (gzip -> base64
## string export/import, SHA-256 checksum, two rotating backups, migrations)
## lands with the save milestone.
##
## v0.2: SAVE_VERSION 2 adds ovion→avian species migration (§2.3).

const SAVE_PATH: String = "user://save_main.json"
const SAVE_VERSION: int = 2

## The in-memory save dictionary. Owners mutate this then call store().
var data: Dictionary = {}


func _ready() -> void:
	# Load early so later autoloads (Loc, GameState) can read settings.
	load_save()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Persistent settings bag (locale, muted, anon_stats, tutorial_seen, …).
func settings() -> Dictionary:
	if not data.has("settings") or not (data["settings"] is Dictionary):
		data["settings"] = {}
	return data["settings"]


func set_setting(key: String, value: Variant) -> void:
	settings()[key] = value


## Load the save from disk into `data` (creating a fresh one if none/corrupt).
func load_save() -> Dictionary:
	if not has_save():
		data = _new_save()
		return data
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("SaveSystem: save is corrupt or unreadable; starting fresh")
		data = _new_save()
		return data
	data = parsed as Dictionary
	_migrate()
	return data


## Write `data` to disk. Returns OK on success.
func store() -> Error:
	data["save_version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write save (%d)" % FileAccess.get_open_error())
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


## Delete the save file (used by "reset" flows).
func erase() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	data = _new_save()


func _new_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"created_at": int(Time.get_unix_time_from_system()),
		"state": {},
	}


## Apply versioned migrations in place. Idempotent.
func _migrate() -> void:
	var ver: int = int(data.get("save_version", 1))
	if ver < 2:
		_migrate_v1_to_v2()
		ver = 2
	data["save_version"] = ver


## v1→v2: rename legacy species id `ovion` → `avian` everywhere workers live.
func _migrate_v1_to_v2() -> void:
	_rewrite_species_in(data.get("state", {}))
	# Hire pool snapshots if any.
	if data.has("hire_pool") and data["hire_pool"] is Array:
		for row in data["hire_pool"]:
			if row is Dictionary and String(row.get("species", "")) == "ovion":
				row["species"] = "avian"


func _rewrite_species_in(node: Variant) -> void:
	if node is Dictionary:
		var d: Dictionary = node
		if d.has("species") and String(d["species"]) == "ovion":
			d["species"] = "avian"
		if d.has("roster") and d["roster"] is Array:
			for w in d["roster"]:
				_rewrite_species_in(w)
		if d.has("board") and d["board"] is Dictionary:
			var pool: Variant = d["board"].get("pool", [])
			if pool is Array:
				for w2 in pool:
					_rewrite_species_in(w2)
		if d.has("workers") and d["workers"] is Array:
			for w3 in d["workers"]:
				_rewrite_species_in(w3)
		for k in d.keys():
			var v: Variant = d[k]
			if v is Dictionary or v is Array:
				if k in ["roster", "board", "workers", "pool"]:
					continue
				# shallow walk of nested state bags
				if k == "state" or k.ends_with("_snapshot"):
					_rewrite_species_in(v)
	elif node is Array:
		for item in node:
			_rewrite_species_in(item)


## Apply ovion→avian on a worker dict (also used by Worker.from_dict).
static func normalize_worker_dict(d: Dictionary) -> Dictionary:
	if String(d.get("species", "")) == "ovion":
		d = d.duplicate(true)
		d["species"] = "avian"
	return d
