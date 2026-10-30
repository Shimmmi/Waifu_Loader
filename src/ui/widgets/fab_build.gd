class_name FabBuild
extends Button

## Floating build button for Terminal on S3 (TZ §2.8).

signal open_build


func _ready() -> void:
	custom_minimum_size = Vector2(12, 12)
	text = "⚒"
	pressed.connect(func(): open_build.emit())
