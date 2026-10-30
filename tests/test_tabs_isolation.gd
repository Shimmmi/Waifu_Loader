extends TestCase

## v0.2 §2.5 — each tab host exists as its own node in terminal.tscn.


func test_terminal_scene_has_isolated_tab_hosts() -> void:
	var text: String = FileAccess.get_file_as_string("res://scenes/terminal.tscn")
	assert_true("HireScroll" in text)
	assert_true("CrewScroll" in text)
	assert_true("WorldScroll" in text)
	assert_true("MenuScroll" in text)
	assert_true("ContractScroll" in text)
	# Loading tab is created at runtime; terminal.gd must reference it.
	var script: String = FileAccess.get_file_as_string("res://src/ui/terminal.gd")
	assert_true("_loading_scroll" in script)
	assert_true('which == "loading"' in script)
	assert_true('which == "crew"' in script)


func test_world_assign_label_is_daily_not_crew() -> void:
	# Isolation of meaning: world.assign must not say «Назначение смены» alone.
	var strings: Dictionary = load_json("strings")
	var ru: Dictionary = strings["ru"]
	assert_eq(String(ru.get("world.assign", "")), "Дневная смена")
