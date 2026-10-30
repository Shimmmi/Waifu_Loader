extends RefCounted

## Layout + source lint for UI scale (TZ v0.3 §2.14 A1–A8 / T6).


func lint_screen(root: Node) -> Array:
	var hits: Array = []
	if root == null:
		hits.append("null root")
		return hits
	_walk(root, hits)
	return hits


func _walk(n: Node, hits: Array) -> void:
	if n is Control:
		_check_control(n as Control, hits)
	for c in n.get_children():
		_walk(c, hits)


func _check_control(c: Control, hits: Array) -> void:
	if c.has_meta("ui_lint_ignore"):
		return
	if not c.visible:
		return
	if c.tooltip_text != "":
		hits.append("A5 tooltip_text on %s" % c.get_path())
	if c is ScrollContainer:
		var sc: ScrollContainer = c as ScrollContainer
		if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			hits.append("A4 horizontal scroll on %s" % c.get_path())
	var cn: String = c.get_class()
	for bad in ["PopupMenu", "OptionButton", "MenuButton", "AcceptDialog",
			"ConfirmationDialog", "FileDialog"]:
		if cn == bad:
			hits.append("A6 forbidden class %s at %s" % [bad, c.get_path()])


func source_lint() -> Array:
	var hits: Array = []
	_scan_dir("res://src/ui", hits)
	_scan_dir("res://src/view", hits)
	return hits


func _scan_dir(dir_path: String, hits: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var path := dir_path.path_join(f)
		if dir.current_is_dir() and not f.begins_with("."):
			_scan_dir(path, hits)
		elif f.ends_with(".gd") or f.ends_with(".tscn"):
			_scan_file(path, hits)
		f = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String, hits: Array) -> void:
	if path.ends_with("ui_scale.gd") or path.ends_with("ui_lint.gd"):
		return
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var patterns: Array = [
		"PopupMenu", "OptionButton", "MenuButton", "AcceptDialog",
		"ConfirmationDialog", "FileDialog", "popup_centered",
		"content_scale_factor", "content_scale_size", "SubViewport",
		"UiScale.mode ==",
	]
	for i in lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#") or "# ui-lint-allow:" in line:
			continue
		for pat in patterns:
			if pat in line:
				hits.append("%s:%d  %s" % [path, i + 1, stripped])
				break
		if path.ends_with(".gd") and "# ui-lint-allow:" not in line:
			if "Vector2" in line and ("480" in line or "270" in line):
				hits.append("%s:%d  hardcoded canvas size %s" % [path, i + 1, stripped])
