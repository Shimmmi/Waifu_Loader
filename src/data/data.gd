extends Node

## Autoload "Data" — loads every JSON table from res://data into memory
## (spec §2.6). Tables are keyed by file basename (e.g. "currencies").

const DATA_DIR: String = "res://data"

var _tables: Dictionary = {}
var load_errors: Array[String] = []


func _ready() -> void:
	load_all()


## (Re)load all tables. Safe to call at runtime for hot-reloading in the editor.
func load_all() -> void:
	_tables.clear()
	load_errors.clear()

	var dir: DirAccess = DirAccess.open(DATA_DIR)
	if dir == null:
		load_errors.append("Data: cannot open directory " + DATA_DIR)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var f: String = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.ends_with(".json"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()

	for file in files:
		var path: String = DATA_DIR + "/" + file
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			load_errors.append("Data: empty or unreadable file " + path)
			continue
		var parsed: Variant = JSON.parse_string(text)
		if parsed == null:
			load_errors.append("Data: invalid JSON in " + path)
			continue
		_tables[file.get_basename()] = parsed


## Return a table by basename, or null if it does not exist.
func table(table_name: String) -> Variant:
	return _tables.get(table_name, null)


## All table names currently loaded.
func table_names() -> Array:
	return _tables.keys()