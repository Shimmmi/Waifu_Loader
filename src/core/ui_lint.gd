class_name UiLint
extends RefCounted

## Layout + source lint for UI scale (TZ v0.3 §2.14 A1–A8 / T6).


static func lint_screen(root: Node) -> Array[String]:
	var hits: Array[String] = []
	if root == null:
		hits.append("null root")
		return hits
	_walk(root, hits)
	return hits


static func _walk(n: Node, hits: Array[String]) -> void:
	if n is Control:
		_check_control(n as Control, hits)
	for c in n.get_children():
		_walk(c, hits)


static func _check_control(c: Control, hits: Array[String]) -> void:
	if c.has_meta("ui_lint_ignore"):
		return
	if not c.visible:
		return
	var ls: Vector2 = UiScale.logical_size()
	var logical: Rect2 = UiScale.to_logical(c.get_global_rect())
	# A1 — inside logical screen (skip ScrollContainer contents).
	var in_scroll: bool = false
	var p: Node = c.get_parent()
	while p:
		if p is ScrollContainer:
			in_scroll = true
			break
		p = p.get_parent()
	if not in_scroll:
		var screen := Rect2(Vector2.ZERO, ls).grow(0.5)
		if not screen.encloses(logical) and not screen.intersects(logical):
			hits.append("A1 %s outside logical screen %s" % [c.get_path(), logical])
	# A5 — no native tooltip text.
	if c.tooltip_text != "":
		hits.append("A5 tooltip_text on %s" % c.get_path())
	# A3 — touch min on S2/S3 buttons.
	if c is BaseButton and UiScale.scale_factor >= 2:
		var tmin: float = float(UiScale.metric("touch_min"))
		if c.size.x + 0.5 < tmin or c.size.y + 0.5 < tmin:
			hits.append("A3 touch_min %s size=%s" % [c.get_path(), c.size])
	# A4 — scroll containers.
	if c is ScrollContainer:
		var sc: ScrollContainer = c as ScrollContainer
		if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			hits.append("A4 horizontal scroll on %s" % c.get_path())
	# A6 — forbidden native classes.
	var cn: String = c.get_class()
	for bad in ["PopupMenu", "OptionButton", "MenuButton", "AcceptDialog",
			"ConfirmationDialog", "FileDialog"]:
		if cn == bad:
			hits.append("A6 forbidden class %s at %s" % [bad, c.get_path()])
	# A2 — label fit (best-effort).
	if c is Label:
		var lbl: Label = c as Label
		if lbl.autowrap_mode == TextServer.AUTOWRAP_OFF:
			if lbl.get_minimum_size().x > lbl.size.x + 0.5 and lbl.size.x > 0.0:
				hits.append("A2 label overflow %s" % c.get_path())


static func source_lint() -> Array[String]:
	var hits: Array[String] = []
	for d in ["res://src/ui", "res://src/view"]:
		_scan_dir(d, hits)
	return hits


static func _scan_dir(dir_path: String, hits: Array[String]) -> void:
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


static func _scan_file(path: String, hits: Array[String]) -> void:
	if path.ends_with("ui_scale.gd") or path.ends_with("ui_lint.gd"):
		return
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var patterns: Array[String] = [
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
		if path.ends_with(".gd") and (("Vector2(480" in line or "Vector2(270" in line)) and "# ui-lint-allow:" not in line):
			hits.append("%s:%d  hardcoded canvas size %s" % [path, i + 1, stripped])
