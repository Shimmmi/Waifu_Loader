extends SceneTree

## Convert assets_src/**/*.pxa text grids into indexed PNGs (v0.2 §5.2).
## Run: godot --headless --path . -s tools/pxa2png.gd

const SRC: String = "res://assets_src"
const OUT: String = "res://assets/packs/placeholder"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var count := _walk(SRC)
	print("pxa2png: converted %d sheets -> %s" % [count, OUT])
	quit(0)


func _walk(dir_path: String) -> int:
	var n := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var path := dir_path.path_join(f)
		if dir.current_is_dir() and not f.begins_with("."):
			n += _walk(path)
		elif f.ends_with(".pxa"):
			if _convert(path):
				n += 1
		f = dir.get_next()
	dir.list_dir_end()
	return n


func _convert(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var fw := 8
	var fh := 8
	var frames := 1
	var legend: Dictionary = {".": 0}
	var frame_rows: Array = []
	var cur: PackedStringArray = []
	for line in text.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("#") or s.is_empty():
			continue
		if s.begins_with("@sheet"):
			# @sheet name frame=WxH frames=N
			for part in s.split(" "):
				if part.begins_with("frame="):
					var wh := part.substr(6).split("x")
					fw = int(wh[0])
					fh = int(wh[1]) if wh.size() > 1 else fw
				elif part.begins_with("frames="):
					frames = int(part.substr(7))
		elif s.begins_with("@legend"):
			for part in s.substr(7).split("|"):
				var kv := part.strip_edges().split("=")
				if kv.size() == 2:
					legend[kv[0].strip_edges()] = int(kv[1].strip_edges())
		elif s.begins_with("@frame"):
			if not cur.is_empty():
				frame_rows.append(cur)
			cur = PackedStringArray()
		else:
			cur.append(s)
	if not cur.is_empty():
		frame_rows.append(cur)
	if frame_rows.is_empty():
		return false
	var img := Image.create(fw * frame_rows.size(), fh, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for fi in frame_rows.size():
		var rows: PackedStringArray = frame_rows[fi]
		for y in mini(rows.size(), fh):
			var row: String = rows[y]
			for x in mini(row.length(), fw):
				var ch := row.substr(x, 1)
				var idx: int = int(legend.get(ch, 0))
				var a: float = 0.0 if idx == 0 else 1.0
				img.set_pixel(fi * fw + x, y, Color(float(idx) / 31.0, 0, 0, a))
	var rel := path.trim_prefix(SRC).trim_prefix("/").get_basename() + ".png"
	var out_path := OUT.path_join(rel)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(out_path))
	return true
