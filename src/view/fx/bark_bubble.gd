class_name BarkBubble
extends Node2D

## Speech bubble over a heroine (v0.2 §4.8).

var _label: Label
var _ttl: float = 0.0


func say(text: String, ttl: float = 2.5) -> void:
	if _label == null:
		_label = Label.new()
		_label.add_theme_font_size_override("font_size", 8)
		add_child(_label)
	_label.text = text
	_ttl = ttl
	visible = true


func _process(dt: float) -> void:
	if _ttl <= 0.0:
		visible = false
		return
	_ttl -= dt


func _draw() -> void:
	if not visible or _label == null:
		return
	var r := Rect2(-4, -18, 80, 14)
	draw_rect(r, Color(0.95, 0.95, 0.9, 0.9))
	draw_rect(r, Color(0.1, 0.1, 0.15), false, 1.0)
