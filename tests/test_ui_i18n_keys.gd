extends TestCase

## T9 — §2.6 keys + Loc.tr_s (TZ §2.14).


func test_scale_keys_present() -> void:
	var tables: Dictionary = load_json("strings")
	var keys: Array[String] = [
		"SET_UI_SCALE", "SET_UI_SCALE_1", "SET_UI_SCALE_2", "SET_UI_SCALE_3",
		"SET_UI_SCALE_HINT", "HUD_MORE", "UI_CLOSE", "UI_OK", "UI_CANCEL",
		"UI_YES", "UI_NO",
	]
	for code in ["ru", "en"]:
		var table: Dictionary = tables.get(code, {})
		for k in keys:
			assert_true(table.has(k), "%s missing in %s" % [k, code])


func test_tr_s_suffix_lookup() -> void:
	var tables: Dictionary = load_json("strings")
	var ru: Dictionary = tables["ru"]
	assert_true(ru.has("hud.rank_S2"), "hud.rank_S2 present")
	assert_eq(String(ru["hud.rank_S2"]), "Р%d")
	assert_true(ru.has("TB_DOCK_S2"), "TB_DOCK_S2 present")
