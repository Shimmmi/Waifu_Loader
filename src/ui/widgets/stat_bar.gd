class_name StatBar
extends HBoxContainer

## Compact labelled bar with optional (+N) equip bonus (v0.2 §3.4).

var _label: Label
var _bar: ProgressBar
var _value: Label


func _ready() -> void:
	if _label != null:
		return
	_label = Label.new()
	_label.custom_minimum_size = Vector2(36, 0)
	add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(60, 8)
	_bar.max_value = 40
	_bar.show_percentage = false
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_bar)
	_value = Label.new()
	_value.custom_minimum_size = Vector2(40, 0)
	add_child(_value)


func setup(stat_name: String, total: float, bonus: float = 0.0, max_v: float = 40.0) -> void:
	if _label == null:
		_ready()
	_label.text = stat_name
	_bar.max_value = max_v
	_bar.value = total
	if bonus > 0.0:
		_value.text = "%d (+%d)" % [int(total), int(bonus)]
	else:
		_value.text = str(int(total))
