class_name UiSelect
extends Button

## Replaces OptionButton / PopupMenu (TZ §2.10).

signal item_selected(index: int)

static var _host: Control = null

var _items: PackedStringArray = PackedStringArray()
var _panel: PanelContainer = null


static func bind_host(host: Control) -> void:
	_host = host


func setup(items: PackedStringArray, selected: int = 0) -> void:
	_items = items
	if selected >= 0 and selected < _items.size():
		text = _items[selected]
	if not pressed.is_connected(_open):
		pressed.connect(_open)


func _open() -> void:
	if _host == null or _items.is_empty():
		return
	_close()
	var dim := ColorRect.new()
	dim.name = "UiSelectDim"
	dim.color = Color(0, 0, 0, 0.01)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close()
	)
	_host.add_child(dim)
	_panel = PanelContainer.new()
	_host.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiScale.metric("gap"))
	_panel.add_child(box)
	for i in _items.size():
		var b := Button.new()
		b.text = _items[i]
		b.custom_minimum_size.y = float(UiScale.metric("btn_h"))
		var idx: int = i
		b.pressed.connect(func(): _pick(idx))
		box.add_child(b)
	var gr: Rect2 = get_global_rect()
	var s: float = float(UiScale.scale_factor)
	_panel.position = gr.position / s + Vector2(0, gr.size.y / s)


func _pick(index: int) -> void:
	text = _items[index]
	item_selected.emit(index)
	_close()


func _close() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	if _host:
		var dim: Node = _host.get_node_or_null("UiSelectDim")
		if dim:
			dim.queue_free()
