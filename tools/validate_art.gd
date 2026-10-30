extends SceneTree

## Validate art pack / animations.json against required clips (v0.2 §5.2).

func _init() -> void:
	var errs: Array[String] = []
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_manifest.json"))
	var anims: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animations.json"))
	if manifest == null or anims == null:
		errs.append("missing manifest or animations.json")
	else:
		var have: Dictionary = {}
		for c in anims.get("clips", []):
			have[String(c["id"])] = true
			var fr: Array = c.get("frame", [16, 24])
			if fr.size() != 2:
				errs.append("clip %s bad frame size" % c["id"])
		for req in manifest.get("required_clips", []):
			if not have.has(String(req)):
				errs.append("missing required clip: " + String(req))
	print("=== validate_art ===")
	for e in errs:
		print("  ERROR " + e)
	if errs.is_empty():
		print("OK (P0 fallback allowed)")
		quit(0)
	else:
		quit(1)
