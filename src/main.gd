extends Control

## Boot / title screen placeholder. Confirms the autoload singletons and the
## data tables come up cleanly. Replaced by the real Terminal screen in M2.

@onready var _info: Label = $VBox/Info


func _ready() -> void:
	var font_applied: bool = ThemeFonts.apply()  # optional: assets/fonts/
	var version: Variant = Data.table("version")
	var currencies: Variant = Data.table("currencies")

	var lines: Array[String] = []
	lines.append(Config.GAME_TITLE)
	lines.append(Config.TERMINAL_NAME)
	lines.append("")
	lines.append("client v%s  ·  sim v%s  ·  save v%s" % [
		version.get("client_version", "?"),
		version.get("sim_version", "?"),
		version.get("save_version", "?"),
	])
	lines.append("data tables: %d  ·  currencies: %d" % [
		Data.table_names().size(),
		(currencies["currencies"] as Array).size() if currencies != null else 0,
	])
	lines.append("rng.hire[0] = %d" % Rng.stream("hire").next_uint32())

	# Persistence smoke: increment a launch counter and write it back.
	SaveSystem.load_save()
	var launches: int = int(SaveSystem.data.get("launches", 0)) + 1
	SaveSystem.data["launches"] = launches
	SaveSystem.store()

	var server_now: float = Net.fetch_time()
	lines.append("launches: %d  ·  net: %s" % [launches, "mock" if Net.is_mock else "live"])
	lines.append("font: %s" % ("pixel" if font_applied else "default"))
	lines.append("server time: %d  ·  clock synced: %s" % [int(server_now), str(Clock.synced)])
	if not Data.load_errors.is_empty():
		lines.append("")
		lines.append("DATA ERRORS:")
		for e in Data.load_errors:
			lines.append("  " + e)

	_info.text = "\n".join(lines)
	print("[boot] " + _info.text)
	$VBox/StartButton.pressed.connect(_on_start)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/terminal.tscn")