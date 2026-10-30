extends PanelContainer

## Mini card shown when tapping a heroine on the loading scene (v0.2 §4.10).

signal open_full(worker_id: String)
signal replace_requested(worker_id: String)
signal closed

var worker_id: String = ""


func _ready() -> void:
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_opaque_style()


func _apply_opaque_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.16, 1.0)
	sb.border_color = Color(0.45, 0.50, 0.65, 1.0)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(6)
	sb.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", sb)


func bind(wid: String) -> void:
	worker_id = wid
	for c in get_children():
		c.queue_free()
	_apply_opaque_style()
	var w: Worker = GameState.worker_by_id(wid)
	if w == null:
		return
	custom_minimum_size = Vector2(168, 128)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(48, 48)
	tex.texture = PixelAssets.portrait(w, 48, w.expression_state())
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(tex)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = w.display_name()
	name_lbl.clip_text = true
	info.add_child(name_lbl)
	var class_lbl := Label.new()
	class_lbl.text = Loc.class_name_of(w.class_id)
	info.add_child(class_lbl)
	var stats_lbl := Label.new()
	stats_lbl.text = "Уст.%d  Мор.%d" % [int(w.fatigue), int(w.morale)]
	info.add_child(stats_lbl)
	var b1 := Button.new()
	b1.text = Loc.t("card.overview")
	b1.pressed.connect(func(): open_full.emit(worker_id))
	box.add_child(b1)
	var b2 := Button.new()
	b2.text = Loc.t("card.unassign")
	b2.pressed.connect(func():
		for sid in GameState.slots.keys():
			if GameState.slots[sid] == worker_id:
				GameState.clear_slot(sid)
				break
		_close())
	box.add_child(b2)
	var b3 := Button.new()
	b3.text = "Заменить…"
	b3.pressed.connect(func(): replace_requested.emit(worker_id))
	box.add_child(b3)


func _close() -> void:
	closed.emit()
	queue_free()
