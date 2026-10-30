class_name ScaleVisibility
extends Node

## Show/hide parent CanvasItem by UI scale mode (TZ §2.7).

@export var show_s1: bool = true
@export var show_s2: bool = true
@export var show_s3: bool = true


func _ready() -> void:
	UiScale.scale_changed.connect(_apply)
	_apply(UiScale.scale_factor)


func _apply(s: int) -> void:
	var target: CanvasItem = get_parent() as CanvasItem
	if target == null:
		return
	target.visible = (s == 1 and show_s1) or (s == 2 and show_s2) or (s == 3 and show_s3)
