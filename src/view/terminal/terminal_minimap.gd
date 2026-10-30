extends Control

## Overview minimap for the terminal grid (v0.2 §10.3).
## ``cam`` is the world point at the **center** of the main viewport (same as SectorView).

signal jump_to(world: Vector2)

var cam: Vector2 = Vector2.ZERO
var view_size: Vector2 = Vector2(480, 184)
var zoom: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(160, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	GameState.stats_changed.connect(queue_redraw)


func _draw() -> void:
	var grid: TerminalGrid = GameState.grid
	if grid == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.09, 0.85))
	var bbox := TerminalBounds.occupied_bbox(grid)
	var sx: float = size.x / maxf(float(bbox.size.x), 1.0)
	var sy: float = size.y / maxf(float(bbox.size.y), 1.0)
	var scale_v: float = minf(sx, sy)
	# Center the grid drawing inside the minimap.
	var drawn := Vector2(float(bbox.size.x) * scale_v, float(bbox.size.y) * scale_v)
	var origin := (size - drawn) * 0.5
	for s in grid.sectors:
		var r := Rect2(
			origin + Vector2(
				float(s.col - bbox.position.x) * scale_v,
				float(bbox.position.y + bbox.size.y - (s.floor_y + s.size.y)) * scale_v),
			Vector2(float(s.size.x) * scale_v - 1.0, float(s.size.y) * scale_v - 1.0))
		draw_rect(r, Color(0.4, 0.45, 0.6))
	# Viewport frame: cam is view center → top-left = cam - half_view_world.
	var lim := TerminalBounds.camera_limits(grid)
	var half_w := view_size * 0.5 / maxf(zoom, 0.001)
	var view_tl := cam - half_w
	var vx: float = origin.x + (view_tl.x - lim.position.x) / maxf(lim.size.x, 1.0) * drawn.x
	var vy: float = origin.y + (view_tl.y - lim.position.y) / maxf(lim.size.y, 1.0) * drawn.y
	var vw: float = (view_size.x / zoom) / maxf(lim.size.x, 1.0) * drawn.x
	var vh: float = (view_size.y / zoom) / maxf(lim.size.y, 1.0) * drawn.y
	draw_rect(Rect2(vx, vy, vw, vh), Color(1, 1, 0.4, 0.9), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var grid: TerminalGrid = GameState.grid
		var lim := TerminalBounds.camera_limits(grid)
		var bbox := TerminalBounds.occupied_bbox(grid)
		var sx: float = size.x / maxf(float(bbox.size.x), 1.0)
		var sy: float = size.y / maxf(float(bbox.size.y), 1.0)
		var scale_v: float = minf(sx, sy)
		var drawn := Vector2(float(bbox.size.x) * scale_v, float(bbox.size.y) * scale_v)
		var origin := (size - drawn) * 0.5
		var local: Vector2 = event.position - origin
		var world := lim.position + Vector2(
			local.x / maxf(drawn.x, 1.0) * lim.size.x,
			local.y / maxf(drawn.y, 1.0) * lim.size.y)
		jump_to.emit(world)
