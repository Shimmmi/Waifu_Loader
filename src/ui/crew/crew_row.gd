class_name CrewRow
extends HBoxContainer

## Roster row adapted per UiScale (TZ §2.8 / v0.2 §3.2).

signal selected(worker_id: String)
signal long_pressed(worker_id: String)

var worker_id: String = ""
var _icon: TextureRect
var _name: Label
var _meta: Label
var _class_icon: Label
var _level: Label
var _fatigue: ProgressBar
var _status: Label
var _allow_long: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(0, float(UiScale.metric("row_h")))
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
	_class_icon = Label.new()
	_class_icon.custom_minimum_size = Vector2(16, 0)
	add_child(_class_icon)
	_level = Label.new()
	add_child(_level)
	_fatigue = ProgressBar.new()
	_fatigue.show_percentage = false
	_fatigue.max_value = 100.0
	add_child(_fatigue)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(12, 12)
	add_child(_status)
	_meta = Label.new()
	add_child(_meta)
	gui_input.connect(_on_input)


func bind(w: Worker) -> void:
	if _icon == null:
		_ready()
	worker_id = w.id
	_icon.texture = PixelAssets.head_icon(w)
	var max_chars: int = UiScale.metric("max_name_chars")
	_name.text = Fmt.name(w.display_name(), max_chars)
	modulate = PixelAssets.rarity_color(w.rarity)
	var s: int = UiScale.scale_factor
	_allow_long = s == 1
	custom_minimum_size = Vector2(0, float(UiScale.metric("row_h")))
	if s == 1:
		_class_icon.visible = false
		_level.visible = false
		_fatigue.visible = false
		_status.visible = false
		_meta.visible = true
		_meta.text = "%s · %s · %s" % [
			Loc.class_name_of(w.class_id),
			Loc.t("crew.level", [w.level]),
			Loc.t("crew.wage", [Fmt.num(w.wage)]),
		]
	else:
		_meta.visible = false
		_class_icon.visible = s == 2
		_class_icon.text = Loc.class_name_of(w.class_id).substr(0, 2)
		_level.visible = s == 2
		_level.text = Loc.t("crew.level", [w.level])
		_fatigue.visible = true
		_fatigue.custom_minimum_size = Vector2(30.0 if s == 2 else 24.0, float(UiScale.metric("bar_h")))
		_fatigue.value = clampf(float(w.fatigue), 0.0, 100.0)
		_status.visible = true
		_status.text = _status_glyph(w)


func _status_glyph(w: Worker) -> String:
	if w.fatigue >= 80.0:
		return "!"
	if w.morale < 30.0:
		return "↓"
	return "·"


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(worker_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and _allow_long:
			long_pressed.emit(worker_id)
