extends SceneTree

## Capture UI goldens at S1/S2/S3 (TZ §2.14).
## Run with a window (not headless): godot --path . -s tools/capture_ui.gd
## Writes tests/golden/ui_scale/s{1,2,3}/{id}.png for present screens.

const OUT_ROOT: String = "res://tests/golden/ui_scale"
const SCREENS_PATH: String = "res://tests/ui/screens.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	await process_frame
	var f: FileAccess = FileAccess.open(SCREENS_PATH, FileAccess.READ)
	if f == null:
		push_error("screens.json missing")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var screens: Array = data.get("screens", [])
	for s in [1, 2, 3]:
		UiScale.set_scale(s, false)
		await process_frame
		await process_frame
		await process_frame
		var dir: String = OUT_ROOT.path_join("s%d" % s)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		# Capture full viewport once per scale as terminal overview.
		var img: Image = get_root().get_viewport().get_texture().get_image()
		if img:
			img.resize(480, 270, Image.INTERPOLATE_NEAREST)
			for sc in screens:
				if not bool(sc.get("present", false)):
					continue
				var id: String = String(sc.get("id", "screen"))
				var path: String = dir.path_join("%s.png" % id)
				img.save_png(ProjectSettings.globalize_path(path))
				print("wrote ", path)
	print("capture_ui done")
	quit(0)
