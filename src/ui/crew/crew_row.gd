class_name CrewRow
extends HBoxContainer

## 24 px roster row (v0.2 §3.2).

signal selected(worker_id: String)
signal long_pressed(worker_id: String)

var worker_id: String = ""
var _icon: TextureRect
var _name: Label
var _meta: Label


func _ready() -> void:
	custom_minimum_size = Vector2(0, 24)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _icon != null:
		return
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	add_child(_name)
	_meta = Label.new()
	add_child(_meta)
	gui_input.connect(_on_input)


func bind(w: Worker) -> void:
	if _icon == null:
		_ready()
	worker_id = w.id
	_icon.texture = PixelAssets.head_icon(w)
	_name.text = w.display_name()
	_meta.text = "%s · %s · %s" % [
		Loc.class_name_of(w.class_id),
		Loc.t("crew.level", [w.level]),
		Loc.t("crew.wage", [Fmt.num(w.wage)]),
	]
	modulate = PixelAssets.rarity_color(w.rarity)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(worker_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			long_pressed.emit(worker_id)
