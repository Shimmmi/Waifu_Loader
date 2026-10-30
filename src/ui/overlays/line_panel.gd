class_name LinePanel
extends PanelContainer

## Loading-line controls overlay for S2/S3 (TZ §2.8).

signal closed

var _box: VBoxContainer
var _info: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", UiScale.metric("gap"))
	add_child(_box)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_info)
	for mode in [["all", "Вся линия"], ["station", "Станция"], ["cine", "Кино"]]:
		var b := Button.new()
		b.text = String(mode[1])
		b.custom_minimum_size.y = float(UiScale.metric("btn_h"))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("cam", String(mode[0]))
		_box.add_child(b)
	var close := Button.new()
	close.text = Loc.t("UI_CLOSE")
	close.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	close.pressed.connect(func():
		visible = false
		closed.emit()
	)
	_box.add_child(close)


func bind_and_show(host: Control, info_text: String, on_cam: Callable) -> void:
	if get_parent() != host:
		if get_parent():
			get_parent().remove_child(self)
		host.add_child(self)
	var margin: float = float(UiScale.metric("panel_margin"))
	var ls: Vector2 = UiScale.logical_size()
	var w: float = 200.0 if UiScale.scale_factor == 2 else ls.x - 2.0 * margin
	custom_minimum_size = Vector2(w, 0)
	position = Vector2(margin, float(UiScale.metric("hud_h")) + margin)
	_info.text = info_text
	for c in _box.get_children():
		if c is Button and c.has_meta("cam"):
			var cam_id: String = String(c.get_meta("cam"))
			for conn in c.pressed.get_connections():
				c.pressed.disconnect(conn["callable"])
			c.pressed.connect(func(): on_cam.call(cam_id))
	visible = true
