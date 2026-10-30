class_name Sector
extends RefCounted

## One built terminal cell group (spec §5). Data only.

var type_id: String = ""
var level: int = 1
var modifier_id: String = "none"
var col: int = 0
var floor_y: int = 0
var size: Vector2i = Vector2i.ONE
var build_time_left: float = 0.0
var broken: bool = false


func _init(p_type: String = "", p_col: int = 0, p_floor: int = 0, p_size: Vector2i = Vector2i.ONE) -> void:
	type_id = p_type
	col = p_col
	floor_y = p_floor
	size = p_size


## Every grid cell this sector occupies.
func cells() -> Array:
	var out: Array = []
	for x in size.x:
		for y in size.y:
			out.append(Vector2i(col + x, floor_y + y))
	return out


func is_building() -> bool:
	return build_time_left > 0.0


func to_dict() -> Dictionary:
	return {
		"type_id": type_id, "level": level, "modifier_id": modifier_id,
		"col": col, "floor_y": floor_y, "size": [size.x, size.y],
		"build_time_left": build_time_left, "broken": broken,
	}


static func from_dict(d: Dictionary) -> Sector:
	var size_arr: Array = d.get("size", [1, 1])
	var sz := Vector2i(int(size_arr[0]), int(size_arr[1]))
	var s := Sector.new(String(d.get("type_id", "")), int(d.get("col", 0)), int(d.get("floor_y", 0)), sz)
	s.level = int(d.get("level", 1))
	s.modifier_id = String(d.get("modifier_id", "none"))
	s.build_time_left = float(d.get("build_time_left", 0.0))
	s.broken = bool(d.get("broken", false))
	return s