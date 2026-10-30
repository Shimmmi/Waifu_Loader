extends SceneTree

## Lint: UI scripts must not print raw class/species/rarity/sector ids.
## Run: godot --headless --path . -s tools/ui_lint.gd
## Exit 0 = clean, 1 = findings.

const SCAN_DIRS: PackedStringArray = ["res://src/ui", "res://src/view"]
## Patterns that look like raw-id interpolation in UI (heuristic).
const BAD: PackedStringArray = [
	"w.class_id",
	"w.species",
	".type_id",
	"rarity[\"id\"]",
	"rarity['id']",
]

var _hits: Array[String] = []


func _init() -> void:
	for d in SCAN_DIRS:
		_scan(d)
	print("=== ui_lint ===")
	for h in _hits:
		print("  HIT  " + h)
	if _hits.is_empty():
		print("OK")
		quit(0)
	else:
		print("FAILED (%d)" % _hits.size())
		quit(1)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var path := dir_path.path_join(f)
		if dir.current_is_dir() and not f.begins_with("."):
			_scan(path)
		elif f.ends_with(".gd"):
			_check_file(path)
		f = dir.get_next()
	dir.list_dir_end()


func _check_file(path: String) -> void:
	# Allow sector_view COLORS keyed by type_id (data, not displayed raw).
	if path.ends_with("sector_view.gd"):
		return
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	for i in lines.size():
		var line: String = lines[i]
		if line.strip_edges().begins_with("#"):
			continue
		# Skip lines that already go through Loc helpers.
		if "Loc." in line:
			continue
		for pat in BAD:
			if pat in line and ("text =" in line or "text=" in line or "%" in line):
				_hits.append("%s:%d  %s" % [path, i + 1, line.strip_edges()])
				break
