extends VBoxContainer

## Animation gallery (debug / Menu hidden page) — v0.2 §4.13.


func _ready() -> void:
	var title := Label.new()
	title.text = "Галерея анимаций"
	add_child(title)
	var anims: Dictionary = Data.table("animations")
	for clip in anims.get("clips", []):
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s · %df @ %dfps" % [clip["id"], int(clip["frames"]), int(clip["fps"])]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(16, 24)
		preview.texture = PixelAssets.icon("clip_" + String(clip["id"]), 16)
		row.add_child(preview)
		add_child(row)
