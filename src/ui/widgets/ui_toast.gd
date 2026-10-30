class_name UiToast
extends PanelContainer

## Toast inside Overlays (TZ §2.10 / §2.8).

const MAX_VISIBLE: int = 3
const DEFAULT_SEC: float = 1.5

static var _host: Control = null
static var _active: Array[Control] = []


static func bind_host(host: Control) -> void:
	_host = host


static func show_text(text: String, sec: float = DEFAULT_SEC) -> void:
	if _host == null:
		return
	while _active.size() >= MAX_VISIBLE:
		var old: Control = _active.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var toast := PanelContainer.new()
	toast.set_script(load("res://src/ui/widgets/ui_toast.gd"))
	_host.add_child(toast)
	_active.append(toast)
	toast.call("_present", text, sec)


func _present(text: String, sec: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(lbl)
	var ls: Vector2 = UiScale.logical_size()
	custom_minimum_size = Vector2(ls.x - 8.0, 0)
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_top = float(UiScale.metric("hud_h") + UiScale.metric("pad"))
	offset_left = 4.0
	offset_right = -4.0
	await get_tree().create_timer(sec).timeout
	if is_instance_valid(self):
		_active.erase(self)
		queue_free()
