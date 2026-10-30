extends TestCase

## T9 — §2.6 keys + Loc.tr_s (TZ §2.14).


func test_scale_keys_present() -> void:
	var keys: Array[String] = [
		"SET_UI_SCALE", "SET_UI_SCALE_1", "SET_UI_SCALE_2", "SET_UI_SCALE_3",
		"SET_UI_SCALE_HINT", "HUD_MORE", "UI_CLOSE", "UI_OK", "UI_CANCEL",
		"UI_YES", "UI_NO",
	]
	for code in ["ru", "en"]:
		var table: Dictionary = Loc._tables.get(code, {})
		for k in keys:
			assert_true(table.has(k), "%s missing in %s" % [k, code])


func test_tr_s_suffix() -> void:
	# Force S2 via UiScale if available.
	var prev: int = UiScale.scale_factor
	UiScale.set_scale(2, false)
	var short: String = Loc.tr_s("hud.rank", [5])
	assert_true(short == "Р5" or short == "R5", "tr_s hud.rank_S2 got %s" % short)
	UiScale.set_scale(1, false)
	var full: String = Loc.tr_s("hud.rank", [5])
	assert_true(full.contains("5"), "base hud.rank")
	UiScale.set_scale(prev, false)
