extends SceneTree

## Capture UI goldens at S1/S2/S3 (TZ §2.14).
## Run: godot --path . -s tools/capture_ui.gd
## Writes tests/golden/ui_scale/s{1,2,3}/{id}.png and docs/screens/scale_row_s{1,2,3}.png
## Autoloads are resolved at runtime (no compile-time UiScale/GameState ids).

const OUT_ROOT: String = "res://tests/golden/ui_scale"
const DOCS_SCREENS: String = "res://docs/screens"
const TERMINAL_SCENE: String = "res://scenes/terminal.tscn"

const TAB_FOR: Dictionary = {
	"hud": "terminal",
	"nav": "terminal",
	"terminal": "terminal",
	"line": "loading",
	"crew": "crew",
	"hire": "hire",
	"contracts": "contracts",
	"world": "world",
	"menu": "menu",
}


func _ui_scale() -> Node:
	return root.get_node_or_null("UiScale")


func _game_state() -> Node:
	return root.get_node_or_null("GameState")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	change_scene_to_file(TERMINAL_SCENE)
	await process_frame
	await process_frame
	await process_frame
	var f: FileAccess = FileAccess.open("res://tests/ui/screens.json", FileAccess.READ)
	if f == null:
		push_error("screens.json missing")
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var screens: Array = data.get("screens", [])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOCS_SCREENS))
	var us: Node = _ui_scale()
	if us == null:
		push_error("UiScale autoload missing")
		quit(1)
		return
	# Default: capture S2/S3 only — S1 goldens are the Step 1 byte baselines (TZ §2.16 #4).
	# Pass -- --s1 to also refresh S1 (rare; breaks golden byte-diff until re-baselined).
	var scales: Array = [2, 3]
	for a in OS.get_cmdline_user_args():
		if String(a) == "--s1":
			scales = [1, 2, 3]
			break
	for s in scales:
		us.call("set_scale", int(s), false)
		await process_frame
		await process_frame
		await process_frame
		var dir: String = OUT_ROOT.path_join("s%d" % s)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for sc in screens:
			if not bool(sc.get("present", false)):
				continue
			var id: String = String(sc.get("id", "screen"))
			if id.begins_with("modal_") or id in ["card", "candidate"]:
				continue
			var tab: String = String(TAB_FOR.get(id, "terminal"))
			_show_tab(tab)
			await process_frame
			await process_frame
			await process_frame
			_save_viewport(dir.path_join("%s.png" % id))
		_show_tab("menu")
		await process_frame
		await process_frame
		await process_frame
		_save_viewport(DOCS_SCREENS.path_join("scale_row_s%d.png" % s))
	print("capture_ui done")
	quit(0)


func _show_tab(tab: String) -> void:
	var term: Node = root.get_node_or_null("Terminal")
	if term != null and term.has_method("_show"):
		term.call("_show", tab)
		return
	var gs: Node = _game_state()
	if gs != null and gs.has_method("request_tab"):
		gs.call("request_tab", tab)


func _save_viewport(res_path: String) -> void:
	var tex: ViewportTexture = root.get_viewport().get_texture()
	if tex == null:
		push_warning("no viewport texture for " + res_path)
		return
	var img: Image = tex.get_image()
	if img == null:
		push_warning("no image for " + res_path)
		return
	if img.get_width() != 480 or img.get_height() != 270:
		img.resize(480, 270, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(res_path))
	print("wrote ", res_path)
