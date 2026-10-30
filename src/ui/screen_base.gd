class_name ScreenBase
extends Control

## Base for tab screens; only place allowed to branch on UiScale.mode (TZ §2.7).

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiScale.scale_changed.connect(_on_scale_changed)
	apply_scale(UiScale.scale_factor)


func _on_scale_changed(new_scale: int) -> void:
	apply_scale(new_scale)


## Override in subclasses. Reading UiScale.mode is allowed only here.
func apply_scale(_s: int) -> void:
	pass
