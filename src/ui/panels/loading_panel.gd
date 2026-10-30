extends VBoxContainer

## «Погрузка» tab host (v0.2 WP-B). Scale-adapted control strip (TZ §2.8).

var _scene: Node = null
var _info: Label
var _adapter = null
var _cam_row: HBoxContainer
var _strip: HBoxContainer
var _line_panel: Control


func _ready() -> void:
	visibility_changed.connect(_on_vis)
	_cam_row = HBoxContainer.new()
	for mode in [["all", "Вся линия"], ["station", "Станция"], ["cine", "Кино"]]:
		var b := Button.new()
		b.text = String(mode[1])
		b.pressed.connect(func(): _set_cam(String(mode[0])))
		_cam_row.add_child(b)
	add_child(_cam_row)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_strip = HBoxContainer.new()
	_strip.visible = false
	var bn := Label.new()
	bn.name = "BnIcon"
	bn.text = "!"
	_strip.add_child(bn)
	var short := Label.new()
	short.name = "ShortInfo"
	short.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	short.clip_text = true
	_strip.add_child(short)
	var gear := Button.new()
	gear.text = "⚙"
	gear.custom_minimum_size = Vector2(12, 12)
	gear.pressed.connect(_open_line_panel)
	_strip.add_child(gear)
	add_child(_strip)
	var script: Script = load("res://src/view/line/line_view_adapter.gd")
	if script != null:
		_adapter = script.new()
	var line_scene: PackedScene = load("res://src/view/line/LineScene.tscn") as PackedScene
	if line_scene != null:
		_scene = line_scene.instantiate()
		_scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scene.custom_minimum_size = Vector2(480, 176)  # ui-lint-allow: line scene physical size TZ §2.8
		add_child(_scene)
	else:
		var stub := ColorRect.new()
		stub.custom_minimum_size = Vector2(480, 176)  # ui-lint-allow: line scene physical size TZ §2.8
		stub.color = Color(0.08, 0.10, 0.14, 1)
		add_child(stub)
	_refresh()
	_apply_layout(UiScale.scale_factor)
	set_process(true)


func apply_scale(s: int) -> void:
	_apply_layout(s)
	_refresh()


func _apply_layout(s: int) -> void:
	_cam_row.visible = s == 1
	_info.visible = s == 1
	# S2: compact strip; S3: same strip (fabs left/right via expand spacer).
	_strip.visible = s >= 2
	_strip.custom_minimum_size.y = 15.0 if s >= 2 else 0.0
	if s == 3:
		var short_lbl: Label = _strip.get_node_or_null("ShortInfo") as Label
		if short_lbl:
			short_lbl.visible = false
	else:
		var short2: Label = _strip.get_node_or_null("ShortInfo") as Label
		if short2:
			short2.visible = true


func _set_cam(mode: String) -> void:
	if _scene and _scene.has_method("set_camera_mode"):
		_scene.set_camera_mode(mode)


func _open_line_panel() -> void:
	if _line_panel == null:
		var scr: Script = load("res://src/ui/overlays/line_panel.gd") as Script
		_line_panel = scr.new() as Control
	var overlays: Control = get_tree().root.find_child("Overlays", true, false) as Control
	if overlays == null:
		overlays = self
	if _line_panel.has_method("bind_and_show"):
		_line_panel.call("bind_and_show", overlays, _info.text if _info else "", Callable(self, "_set_cam"))


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
	var full: String = "%s · %.1f т/мин · +%.1f ¢/мин · %s" % [
		Loc.t("line.bottleneck", [tip]),
		float(snap.get("flows_tps", {}).get("m3", 0.0)) * 60.0,
		float(snap.get("income_pm", 0.0)),
		Loc.t("line.crate_u", [Fmt.num(float(snap.get("crate_u", 1.0)))]),
	]
	_info.text = full
	var short_lbl: Label = _strip.get_node_or_null("ShortInfo") as Label
	if short_lbl:
		short_lbl.text = tip
	if _scene != null and _scene.has_method("apply_snapshot"):
		_scene.apply_snapshot(snap)
