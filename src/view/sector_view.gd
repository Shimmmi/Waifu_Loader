extends Control

## Cross-section terminal view (spec §5.1 / v0.2 WP-E).
## Camera: drag, wheel, ×1/×2 zoom, autofocus, minimap, edge arrows.

const CELL_W: float = 64.0
const CELL_H: float = 48.0

const COLORS: Dictionary = {
	"dock": Color(0.30, 0.36, 0.52),
	"storage": Color(0.40, 0.34, 0.26),
	"office": Color(0.30, 0.42, 0.36),
	"dorm": Color(0.42, 0.30, 0.42),
	"canteen": Color(0.46, 0.40, 0.24),
	"garage": Color(0.34, 0.34, 0.40),
	"crane": Color(0.30, 0.44, 0.46),
	"workshop": Color(0.44, 0.32, 0.24),
	"lounge": Color(0.38, 0.36, 0.48),
	"trainhall": Color(0.32, 0.40, 0.44),
	"dispatch": Color(0.28, 0.40, 0.50),
	"refrigerator": Color(0.28, 0.38, 0.48),
	"orbital_dock": Color(0.26, 0.32, 0.56),
}

var cam: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var _vel: Vector2 = Vector2.ZERO
var _drag_origin: Vector2 = Vector2.ZERO
var _cam_at_drag: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _press_ms: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _selected: Sector = null
var _minimap: Control
var _arrows: EdgeArrows
var _reduce_motion: bool = false

signal sector_tapped(sector: Sector)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reduce_motion = bool(SaveSystem.settings().get("reduce_motion", false))
	_arrows = EdgeArrows.new()
	_arrows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.arrow_pressed.connect(focus_sector)
	add_child(_arrows)
	_minimap = Control.new()
	_minimap.set_script(load("res://src/view/terminal/terminal_minimap.gd"))
	_minimap.position = Vector2(312, 4)
	_minimap.visible = false
	add_child(_minimap)
	if _minimap.has_signal("jump_to"):
		_minimap.jump_to.connect(func(w):
			cam = w
			_clamp_cam()
			_save_cam()
			_update_overlays()
			queue_redraw())
	GameState.stats_changed.connect(_on_stats)
	Loc.locale_changed.connect(func(_c: String): queue_redraw())
	set_process(true)
	# Size is often 0 in _ready — center after layout.
	call_deferred("_boot_camera")
	queue_redraw()


func _boot_camera() -> void:
	_load_cam()
	_clamp_cam()
	_update_overlays()
	queue_redraw()


func _on_stats() -> void:
	_update_overlays()
	queue_redraw()


func _process(dt: float) -> void:
	if _reduce_motion:
		_vel = Vector2.ZERO
		return
	if _vel.length() > 0.5:
		cam += _vel * dt
		_vel *= 0.9
		_clamp_cam()
		_update_overlays()
		queue_redraw()


func _draw() -> void:
	var grid: TerminalGrid = GameState.grid
	if grid == null:
		return
	var font: Font = ThemeFonts.body_font()
	if font == null:
		font = ThemeDB.fallback_font
	# Sky / ground.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.14))
	var ground_y: float = _world_to_view(Vector2(0, 0)).y
	draw_line(Vector2(0, ground_y), Vector2(size.x, ground_y), Color(0.5, 0.55, 0.4, 0.6), 1.0)

	for s in grid.sectors:
		var rect := _sector_view_rect(s)
		var base: Color = COLORS.get(s.type_id, Color(0.35, 0.35, 0.4))
		if s.build_time_left > 0.0:
			base = base.darkened(0.4)
		if _selected == s:
			base = base.lightened(0.15)
		draw_rect(rect, base, true)
		draw_rect(rect, Color(0.05, 0.05, 0.08, 0.8), false, 1.0)
		var icon := Rect2(rect.position + Vector2(3, 3), Vector2(12, 12))
		draw_rect(icon, base.lightened(0.35), true)
		var name: String = Loc.sector_name(s.type_id)
		if s.modifier_id != "none" and s.modifier_id != "":
			name += " ◈"
		draw_string(font, rect.position + Vector2(18, 12), name,
			HORIZONTAL_ALIGNMENT_LEFT, int(rect.size.x - 20), 8, Color(0.95, 0.95, 1.0))
		var lvl_text: String
		if s.build_time_left > 0.0:
			lvl_text = Loc.t("sector.building_lvl", [s.level, Fmt.time(s.build_time_left)])
		else:
			lvl_text = Loc.t("sector.level", [s.level])
		draw_string(font, rect.position + Vector2(3, 24), lvl_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.85, 0.6))


func _sector_view_rect(s: Sector) -> Rect2:
	var top_left := _world_to_view(Vector2(float(s.col) * CELL_W, -float(s.floor_y + s.size.y) * CELL_H))
	var wh := Vector2(CELL_W * float(s.size.x) - 2.0, CELL_H * float(s.size.y) - 2.0) * zoom
	return Rect2(top_left, wh)


func _world_to_view(world: Vector2) -> Vector2:
	return (world - cam) * zoom + size * 0.5


func _view_to_world(view: Vector2) -> Vector2:
	return (view - size * 0.5) / zoom + cam


func focus_sector(s: Sector, _animated: bool = true) -> void:
	if s == null:
		return
	_selected = s
	cam = TerminalBounds.sector_center_world(s)
	_clamp_cam()
	_save_cam()
	_update_overlays()
	queue_redraw()


func focus_cell(cx: int, cy: int, _animated: bool = true) -> void:
	cam = Vector2(float(cx) * CELL_W, -float(cy) * CELL_H)
	_clamp_cam()
	_save_cam()
	queue_redraw()


func fit_all() -> void:
	var lim := TerminalBounds.camera_limits(GameState.grid)
	cam = lim.position + lim.size * 0.5
	zoom = 1.0
	_clamp_cam()
	_save_cam()
	_update_overlays()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and size.x > 1.0:
		_clamp_cam()
		_update_overlays()
		queue_redraw()


func _clamp_cam() -> void:
	cam = TerminalBounds.clamp_cam(cam, size, GameState.grid, zoom)


func _update_overlays() -> void:
	var lim := TerminalBounds.camera_limits(GameState.grid)
	var needs_map: bool = lim.size.x > size.x / zoom or lim.size.y > size.y / zoom
	if _minimap:
		_minimap.visible = needs_map
		_minimap.cam = cam
		_minimap.view_size = size
		_minimap.zoom = zoom
		_minimap.queue_redraw()
	if _arrows:
		_arrows.update_targets(GameState.grid, cam, size, zoom)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_dragging = true
				_drag_origin = mb.position
				_cam_at_drag = cam
				_press_ms = Time.get_ticks_msec()
				_press_pos = mb.position
				_vel = Vector2.ZERO
			else:
				var moved: float = _press_pos.distance_to(mb.position)
				var held: int = Time.get_ticks_msec() - _press_ms
				_dragging = false
				if moved < 4.0 and held < 300 and mb.button_index == MOUSE_BUTTON_LEFT:
					_handle_tap(mb.position)
				else:
					if not _reduce_motion:
						_vel = (_cam_at_drag - cam) * 0.0  # inertia from last delta preferred
				_save_cam()
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if Input.is_key_pressed(KEY_CTRL):
				_set_zoom(2.0, mb.position)
			elif Input.is_key_pressed(KEY_SHIFT):
				cam.x -= 24.0 / zoom
			else:
				cam.y -= 24.0 / zoom
			_clamp_cam(); _save_cam(); _update_overlays(); queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if Input.is_key_pressed(KEY_CTRL):
				_set_zoom(1.0, mb.position)
			elif Input.is_key_pressed(KEY_SHIFT):
				cam.x += 24.0 / zoom
			else:
				cam.y += 24.0 / zoom
			_clamp_cam(); _save_cam(); _update_overlays(); queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = (mm.position - _drag_origin) / zoom
		cam = _cam_at_drag - delta
		if not _reduce_motion:
			_vel = -mm.relative / zoom * 60.0
		_clamp_cam()
		_update_overlays()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var step := 240.0 * get_process_delta_time() / zoom
		match event.keycode:
			KEY_LEFT, KEY_A: cam.x -= step; _clamp_cam(); queue_redraw()
			KEY_RIGHT, KEY_D: cam.x += step; _clamp_cam(); queue_redraw()
			KEY_UP, KEY_W: cam.y -= step; _clamp_cam(); queue_redraw()
			KEY_DOWN, KEY_S: cam.y += step; _clamp_cam(); queue_redraw()
			KEY_HOME: fit_all()
			KEY_F:
				var dock := GameState.sector_of_type("dock")
				if dock: focus_sector(dock)
			KEY_M:
				if _minimap: _minimap.visible = not _minimap.visible


func _set_zoom(z: float, pivot: Vector2) -> void:
	var before := _view_to_world(pivot)
	zoom = 2.0 if z >= 1.5 else 1.0
	var after := _view_to_world(pivot)
	cam += before - after
	_clamp_cam()
	_save_cam()
	_update_overlays()
	queue_redraw()


func _handle_tap(pos: Vector2) -> void:
	var grid: TerminalGrid = GameState.grid
	if grid == null:
		return
	for s in grid.sectors:
		if _sector_view_rect(s).has_point(pos):
			_selected = s
			sector_tapped.emit(s)
			if s.type_id == "dock":
				GameState.request_tab("loading")
			queue_redraw()
			return


func _save_cam() -> void:
	var ui: Dictionary = SaveSystem.settings().get("ui", {})
	if typeof(ui) != TYPE_DICTIONARY:
		ui = {}
	# schema 2: cam = view center (fixes mismatch with minimap / old top-left saves)
	ui["terminal_camera"] = {"x": cam.x, "y": cam.y, "zoom": zoom, "schema": 2}
	SaveSystem.set_setting("ui", ui)


func _load_cam() -> void:
	var ui: Dictionary = SaveSystem.settings().get("ui", {})
	var tc: Dictionary = ui.get("terminal_camera", {}) if typeof(ui) == TYPE_DICTIONARY else {}
	var schema: int = int(tc.get("schema", 1))
	if tc.has("x") and schema >= 2:
		cam = Vector2(float(tc.get("x", 0)), float(tc.get("y", 0)))
		zoom = 2.0 if float(tc.get("zoom", 1.0)) >= 1.5 else 1.0
		_clamp_cam()
	else:
		# Old / missing saves treated cam as top-left — recenter on grid.
		fit_all()
