extends TestCase

## View/UI must not reference Rng.stream("sim") / rng_sim (v0.2 §4.5).


func test_no_sim_rng_in_view_sources() -> void:
	var hits: Array[String] = []
	for dir_path in ["res://src/view", "res://src/ui"]:
		_scan(dir_path, hits)
	assert_true(hits.is_empty(), "sim rng refs: " + ", ".join(hits))


func _scan(dir_path: String, hits: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var path := dir_path.path_join(f)
		if dir.current_is_dir() and not f.begins_with("."):
			_scan(path, hits)
		elif f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string(path)
			if 'Rng.stream("sim")' in text or "rng_sim" in text:
				hits.append(path)
		f = dir.get_next()
	dir.list_dir_end()
