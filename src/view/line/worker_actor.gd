class_name WorkerActor
extends Node2D

## Heroine actor on the loading scene (v0.2 §4.6).

const MIN_STATE_S: float = 0.5

var worker_id: String = ""
var state: String = "idle_a"
var _state_t: float = 0.0
var _sprite: Sprite2D
var anim_speed: float = 1.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.offset = Vector2(0, -12)
	add_child(_sprite)
	z_index = int(position.y)


func setup(wid: String, slot_pos: Vector2) -> void:
	worker_id = wid
	position = slot_pos
	_refresh_tex()


func set_state(s: String, speed: float = 1.0) -> void:
	if s == state and _state_t < MIN_STATE_S:
		return
	if _state_t < MIN_STATE_S and s != state:
		return
	state = s
	_state_t = 0.0
	anim_speed = speed
	_refresh_tex()


func _process(dt: float) -> void:
	_state_t += dt
	z_index = int(position.y)
	if state == "tired":
		position.y += sin(Time.get_ticks_msec() * 0.005) * 0.02


func _refresh_tex() -> void:
	var w: Worker = GameState.worker_by_id(worker_id)
	if _sprite:
		_sprite.texture = PixelAssets.head_icon(w)
		_sprite.scale = Vector2(1.0, 1.5)
		match state:
			"tired", "out":
				_sprite.modulate = Color(0.7, 0.7, 0.75)
			"rush":
				_sprite.modulate = Color(1.2, 1.1, 0.8)
			"blocked":
				_sprite.modulate = Color(1.0, 0.9, 0.5)
			_:
				_sprite.modulate = PixelAssets.species_color(w.species if w else "human")


func _draw() -> void:
	# State bubble.
	if state in ["starved", "blocked"]:
		draw_string(ThemeDB.fallback_font, Vector2(-6, -28), "…" if state == "starved" else "Ⅱ",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.YELLOW)
