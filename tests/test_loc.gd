extends TestCase

## Localization tables (spec §15.9): RU primary, EN secondary, keys in sync.


func test_strings_tables_in_sync() -> void:
	var tables: Dictionary = load_json("strings")
	assert_true(tables.has("ru"))
	assert_true(tables.has("en"))
	var ru: Dictionary = tables["ru"]
	var en: Dictionary = tables["en"]
	assert_eq(ru.size(), en.size())
	for key in ru.keys():
		assert_true(en.has(key), "EN missing key: %s" % String(key))
		assert_true(String(ru[key]) != "", "RU empty value: %s" % String(key))
		assert_true(String(en[key]) != "", "EN empty value: %s" % String(key))


func test_key_ui_strings_present() -> void:
	var ru: Dictionary = (load_json("strings"))["ru"]
	for key in ["nav.terminal", "nav.menu", "hud.rush", "menu.settings", "world.title", "TREE_CLEARING"]:
		assert_true(ru.has(key), "missing RU key: %s" % key)