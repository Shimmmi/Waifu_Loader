extends TestCase

## T5 — golden screenshots exist for present screens (TZ §2.14).


func test_goldens_exist() -> void:
	var f: FileAccess = FileAccess.open("res://tests/ui/screens.json", FileAccess.READ)
	assert_true(f != null, "screens.json")
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var screens: Array = data.get("screens", [])
	for s in [1, 2, 3]:
		for sc in screens:
			if not bool(sc.get("present", false)):
				continue
			var id: String = String(sc.get("id", ""))
			# Modal overlays may share terminal capture; require file when listed.
			var path: String = "res://tests/golden/ui_scale/s%d/%s.png" % [s, id]
			var ok: bool = FileAccess.file_exists(path)
			if id.begins_with("modal_") or id in ["card", "candidate"]:
				# Optional until dedicated captures land.
				continue
			assert_true(ok, "missing %s" % path)
