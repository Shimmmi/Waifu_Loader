class_name EdgeArrows
extends Control

## Arrows at viewport edges pointing to off-screen sectors (v0.2 §10.4).

signal arrow_pressed(sector: Sector)

var _targets: Array = []  # [{dir: Vector2, sector: Sector}]


func update_targets(grid: TerminalGrid, cam: Vector2, view_size: Vector2, zoom: float) -> void:
	_targets.clear()
	if grid == null:
		queue_redraw()
		return
	for s in grid.sectors:
		if TerminalBounds.is_sector_visible(s, cam, view_size, zoom):
			continue
		var center := TerminalBounds.sector_center_world(s)
		var screen := (center - cam) * zoom + view_size * 0.5
		var dir := Vector2.ZERO
		if screen.x < 0:
			dir.x = -1
		elif screen.x > view_size.x:
			dir.x = 1
		if screen.y < 0:
			dir.y = -1
		elif screen.y > view_size.y:
			dir.y = 1
		if dir != Vector2.ZERO:
			_targets.append({"dir": dir, "sector": s})
	queue_redraw()


func _draw() -> void:
	for t in _targets:
		var dir: Vector2 = t["dir"]
		var pos := size * 0.5
		if dir.x < 0:
			pos.x = 8
		elif dir.x > 0:
			pos.x = size.x - 8
		if dir.y < 0:
			pos.y = 8
		elif dir.y > 0:
			pos.y = size.y - 8
		draw_circle(pos, 6, Color(1, 0.85, 0.3, 0.9))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for t in _targets:
			var dir: Vector2 = t["dir"]
			var pos := size * 0.5
			if dir.x < 0: pos.x = 8
			elif dir.x > 0: pos.x = size.x - 8
			if dir.y < 0: pos.y = 8
			elif dir.y > 0: pos.y = size.y - 8
			if pos.distance_to(event.position) < 12.0:
				arrow_pressed.emit(t["sector"])
				return
