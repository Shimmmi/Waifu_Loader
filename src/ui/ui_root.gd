extends Control

## Scalable UI root (TZ v0.3 §2.3 / §2.4). Children: Content, Hud, NavBar, Overlays.

@onready var content: Control = $Content
@onready var hud: Control = $Hud
@onready var nav_bar: Control = $NavBar
@onready var overlays: Control = $Overlays


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	UiScale.register_root(self)
	_layout_chrome()
	if not UiScale.scale_changed.is_connected(_on_scale_changed):
		UiScale.scale_changed.connect(_on_scale_changed)


func _on_scale_changed(_s: int) -> void:
	_layout_chrome()


func _layout_chrome() -> void:
	var ls: Vector2 = UiScale.logical_size()
	var hud_h: float = float(UiScale.metric("hud_h"))
	var nav_h: float = float(UiScale.metric("nav_h"))
	# Content full rect
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Hud top
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 0.0
	hud.offset_right = 0.0
	hud.offset_top = 0.0
	hud.offset_bottom = hud_h
	# NavBar bottom
	nav_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav_bar.offset_left = 0.0
	nav_bar.offset_right = 0.0
	nav_bar.offset_top = -nav_h
	nav_bar.offset_bottom = 0.0
	# Overlays full
	overlays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ensure size matches logical (UiScale also sets scale/size).
	size = ls
