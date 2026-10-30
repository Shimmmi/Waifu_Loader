class_name WorldClip
extends Control

## Clips the world view to UiScale.world_rect (TZ §2.9). Lives under World, outside UiRoot.

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
