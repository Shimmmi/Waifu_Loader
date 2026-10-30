extends VBoxContainer

## «Погрузка» tab host (v0.2 WP-B). Embeds LineScene when available; otherwise
## shows a P0 placeholder driven by LineViewAdapter snapshots.

var _scene: Node = null
var _info: Label
var _adapter = null


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	var cam_row := HBoxContainer.new()
	for mode in [["all", "Вся линия"], ["station", "Станция"], ["cine", "Кино"]]:
		var b := Button.new()
		b.text = String(mode[1])
		b.pressed.connect(func():
			if _scene and _scene.has_method("set_camera_mode"):
				_scene.set_camera_mode(String(mode[0])))
		cam_row.add_child(b)
	add_child(cam_row)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	var script: Script = load("res://src/view/line/line_view_adapter.gd")
	if script != null:
		_adapter = script.new()
	var line_scene: PackedScene = load("res://src/view/line/LineScene.tscn") as PackedScene
	if line_scene != null:
		_scene = line_scene.instantiate()
		_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scene.custom_minimum_size = Vector2(480, 176)
		add_child(_scene)
	else:
		var stub := ColorRect.new()
		stub.custom_minimum_size = Vector2(480, 176)
		stub.color = Color(0.08, 0.10, 0.14, 1)
		add_child(stub)
	_refresh()
	set_process(true)


func _on_vis() -> void:
	set_process(visible)
	if visible:
		_refresh()


func _process(_dt: float) -> void:
	if not visible:
		return
	_refresh()


func _refresh() -> void:
	if _adapter == null:
		_info.text = Loc.t("nav.loading")
		return
	var snap: Dictionary = _adapter.snapshot(1)
	var bn: String = String(snap.get("bottleneck", ""))
	var tip: String = Loc.station_name(bn) if bn != "" else "—"
	_info.text = "%s · %.1f т/мин · +%.1f ¢/мин · %s" % [
		Loc.t("line.bottleneck", [tip]),
		float(snap.get("flows_tps", {}).get("m3", 0.0)) * 60.0,
		float(snap.get("income_pm", 0.0)),
		Loc.t("line.crate_u", [Fmt.num(float(snap.get("crate_u", 1.0)))]),
	]
	if _scene != null and _scene.has_method("apply_snapshot"):
		_scene.apply_snapshot(snap)
