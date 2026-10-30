class_name UiTooltip
extends PanelContainer

## Replaces Control.tooltip_text (TZ §2.10).

static var _instance: Control = null
static var _host: Control = null

var _label: Label


static func bind_host(host: Control) -> void:
	_host = host
	if _instance == null:
		_instance = PanelContainer.new()
		_instance.set_script(load("res://src/ui/widgets/ui_tooltip.gd"))
		_host.add_child(_instance)
		_instance.visible = false


static func attach(control: Control, text_or_key: String) -> void:
	control.set_meta("ui_tooltip", text_or_key)
	control.tooltip_text = ""
	if not control.mouse_entered.is_connected(_on_enter_bound.bind(control)):
		control.mouse_entered.connect(_on_enter_bound.bind(control))
		control.mouse_exited.connect(hide_tip)
		control.gui_input.connect(_on_gui_bound.bind(control))


static func _on_enter_bound(control: Control) -> void:
	if _instance and _instance.has_method("_schedule"):
		_instance.call("_schedule", control)


static func _on_gui_bound(_control: Control, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_tip()


static func hide_tip() -> void:
	if _instance:
		_instance.visible = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)


func _schedule(control: Control) -> void:
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var raw: String = String(control.get_meta("ui_tooltip", ""))
	if raw.is_empty():
		return
	var text: String = Loc.t(raw) if Loc._tables.get(Loc.code, {}).has(raw) else raw
	_show_at(control, text)


func _show_at(control: Control, text: String) -> void:
	_label.text = text
	var ls: Vector2 = UiScale.logical_size()
	var max_w: float = mini(120.0, ls.x - 8.0)
	custom_minimum_size = Vector2(max_w, 0)
	visible = true
	await get_tree().process_frame
	var gr: Rect2 = control.get_global_rect()
	var s: float = float(UiScale.scale_factor)
	var local_pos: Vector2 = gr.position / s
	position = Vector2(local_pos.x, local_pos.y - size.y - 2.0)
	position.x = clampf(position.x, 0.0, ls.x - size.x)
	position.y = clampf(position.y, 0.0, ls.y - size.y)
