extends Node

## Autoload "UiScale" — UI scale 1×/2×/3× (TZ v0.3 §2.4).

signal scale_changed(new_scale: int)

const BASE_SIZE: Vector2 = Vector2(480, 270)
const ALLOWED: Array[int] = [1, 2, 3]
const MODES: Dictionary = {1: "S1", 2: "S2", 3: "S3"}
const METRICS_PATH: String = "res://data/ui_scale.json"

var scale_factor: int = 1
var mode: String = "S1"
var ui_root: Control = null
var _metrics: Dictionary = {}


func _ready() -> void:
	_metrics = _load_metrics()
	# Apply persisted scale before screens build (TZ §2.4 rule 5 / §2.12).
	var saved: int = int(_settings().get("ui_scale", 1))
	set_scale(saved, false)


func _settings() -> Dictionary:
	var ss: Node = Engine.get_main_loop().root.get_node_or_null("SaveSystem")
	if ss == null:
		return {}
	return ss.call("settings") as Dictionary


func _persist_scale(v: int) -> void:
	var ss: Node = Engine.get_main_loop().root.get_node_or_null("SaveSystem")
	if ss == null:
		return
	ss.call("set_setting", "ui_scale", v)
	ss.call("store")


func _load_metrics() -> Dictionary:
	var f: FileAccess = FileAccess.open(METRICS_PATH, FileAccess.READ)
	assert(f != null, "ui_scale.json missing")
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	assert(parsed is Dictionary, "ui_scale.json invalid")
	return parsed


func register_root(root: Control) -> void:
	ui_root = root
	_apply_to_root()


func logical_size() -> Vector2:
	return BASE_SIZE / float(scale_factor)


## All UI sizes go through this (logical px).
func metric(key: String) -> int:
	var table: Dictionary = _metrics["scales"][str(scale_factor)]
	assert(table.has(key), "unknown ui metric: " + key)
	return int(table[key])


func set_scale(value: int, persist: bool = true) -> void:
	var v: int = value
	if not ALLOWED.has(v):
		push_warning("UiScale: invalid scale %d, fallback to 1" % value)
		v = 1
	if v == scale_factor and ui_root != null:
		return
	scale_factor = v
	mode = MODES[v]
	_apply_to_root()
	if persist:
		_persist_scale(v)
	scale_changed.emit(v)


func _apply_to_root() -> void:
	if ui_root == null:
		return
	ui_root.pivot_offset = Vector2.ZERO
	ui_root.position = Vector2.ZERO
	ui_root.scale = Vector2(scale_factor, scale_factor)
	ui_root.size = logical_size()


## World rectangle in PHYSICAL px of the base canvas.
func world_rect(tab_id: String) -> Rect2:
	var top: int = metric("hud_h")
	if tab_id == "terminal":
		top += metric("toolbar_h")
	var bottom: int = metric("nav_h")
	var s: int = scale_factor
	return Rect2(0.0, float(top * s), BASE_SIZE.x, BASE_SIZE.y - float((top + bottom) * s))


## Physical rect → logical (linter / tests).
func to_logical(r: Rect2) -> Rect2:
	return Rect2(r.position / float(scale_factor), r.size / float(scale_factor))


func style_scroll(sc: ScrollContainer) -> void:
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.get_v_scroll_bar().custom_minimum_size.x = float(metric("scroll_w"))
