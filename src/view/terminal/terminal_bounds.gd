class_name TerminalBounds
extends RefCounted

## Pure geometry helper for the terminal grid camera (v0.2 §10.2).
## ``cam`` is the world-space point shown at the **center** of the viewport.

const CELL_W: float = 64.0
const CELL_H: float = 48.0
const PAD_CELLS: int = 1


static func occupied_bbox(grid: TerminalGrid) -> Rect2i:
	if grid == null or grid.sectors.is_empty():
		return Rect2i(0, 0, 2, 1)
	var min_c := 999
	var max_c := -999
	var min_f := 999
	var max_f := -999
	for s in grid.sectors:
		min_c = mini(min_c, s.col)
		max_c = maxi(max_c, s.col + s.size.x)
		min_f = mini(min_f, s.floor_y)
		max_f = maxi(max_f, s.floor_y + s.size.y)
	return Rect2i(min_c, min_f, max_c - min_c, max_f - min_f)


static func camera_limits(grid: TerminalGrid) -> Rect2:
	var b := occupied_bbox(grid)
	b = b.grow(PAD_CELLS)
	return Rect2(
		Vector2(float(b.position.x) * CELL_W, -float(b.position.y + b.size.y) * CELL_H),
		Vector2(float(b.size.x) * CELL_W, float(b.size.y) * CELL_H))


static func sector_center_world(s: Sector) -> Vector2:
	return Vector2(
		(float(s.col) + float(s.size.x) * 0.5) * CELL_W,
		-(float(s.floor_y) + float(s.size.y) * 0.5) * CELL_H)


static func lim_center(grid: TerminalGrid) -> Vector2:
	var lim := camera_limits(grid)
	return lim.position + lim.size * 0.5


## Clamp camera center so the view stays over the grid (+ pad).
static func clamp_cam(cam: Vector2, view_size: Vector2, grid: TerminalGrid, zoom: float) -> Vector2:
	if grid == null or view_size.x <= 1.0 or view_size.y <= 1.0:
		return cam
	var lim := camera_limits(grid)
	var half := view_size * 0.5 / maxf(zoom, 0.001)
	# Grid smaller than viewport → lock to lim center.
	if lim.size.x <= view_size.x / zoom:
		cam.x = lim.position.x + lim.size.x * 0.5
	else:
		cam.x = clampf(cam.x, lim.position.x + half.x, lim.position.x + lim.size.x - half.x)
	if lim.size.y <= view_size.y / zoom:
		cam.y = lim.position.y + lim.size.y * 0.5
	else:
		cam.y = clampf(cam.y, lim.position.y + half.y, lim.position.y + lim.size.y - half.y)
	return cam


static func is_sector_visible(s: Sector, cam: Vector2, view_size: Vector2, zoom: float) -> bool:
	var center := sector_center_world(s)
	var screen := (center - cam) * zoom + view_size * 0.5
	return Rect2(Vector2.ZERO, view_size).grow(8.0).has_point(screen)
