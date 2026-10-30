class_name WorkerSprite
extends Node2D

## Layered (or P0 capsule) heroine sprite for the loading scene (v0.2 §5.3).

var worker_id: String = ""
var clip: String = "idle_a"
var anim_speed: float = 1.0

@onready var _sprite: Sprite2D = Sprite2D.new()


func _ready() -> void:
	add_child(_sprite)
	_sprite.centered = true
	_sprite.offset = Vector2(0, -12)
	refresh()


func setup(w: Worker) -> void:
	worker_id = w.id if w else ""
	refresh()


func set_clip(name: String, speed: float = 1.0) -> void:
	clip = name
	anim_speed = speed


func refresh() -> void:
	var w: Worker = GameState.worker_by_id(worker_id) if worker_id != "" else null
	var tex: Texture2D = PixelAssets.head_icon(w) if w else PixelAssets.icon("empty", 16)
	if _sprite:
		_sprite.texture = tex
		_sprite.scale = Vector2(1, 1.5)  # 16×16 head stretched toward 16×24 capsule
		_sprite.modulate = PixelAssets.species_color(w.species if w else "human")
