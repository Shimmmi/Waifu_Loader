extends TestCase

## ThemeFonts — bundled OFL pixel fonts (spec §16.3, assets/ASSETS.md).
## Fonts ship with the game, so the loader must find and apply them; Cyrillic
## coverage is required because RU is the primary locale.


func test_body_font_is_bundled() -> void:
	assert_true(ThemeFonts.has_body_font(), "assets/fonts/PixelifySans-Regular.ttf should ship")


func test_body_font_has_cyrillic() -> void:
	var font: FontFile = ThemeFonts._first(ThemeFonts.BODY_CANDIDATES)
	assert_true(font != null, "body font must load")
	# А Я ё — RU is primary, so tofu here would break the whole UI.
	assert_true(font.has_char(0x0410), "missing А")
	assert_true(font.has_char(0x042F), "missing Я")
	assert_true(font.has_char(0x0451), "missing ё")
	assert_true(font.has_char(65), "missing latin A")
	assert_true(font.has_char(48), "missing digit 0")


func test_apply_sets_theme_default_font() -> void:
	assert_true(ThemeFonts.apply(), "apply() should succeed with a bundled font")
	var theme: Theme = ThemeDB.get_project_theme()
	if theme != null:
		assert_true(theme.default_font != null, "theme default_font should be set")
		assert_eq(theme.default_font, ThemeFonts._first(ThemeFonts.BODY_CANDIDATES))


func test_pixel_tuning() -> void:
	var font: FontFile = ThemeFonts._first(ThemeFonts.BODY_CANDIDATES)
	ThemeFonts._tune(font)
	assert_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE)
	assert_eq(font.subpixel_positioning, TextServer.SUBPIXEL_POSITIONING_DISABLED)
	assert_false(font.multichannel_signed_distance_field)


func test_candidates_are_ttf() -> void:
	for name in ThemeFonts.BODY_CANDIDATES:
		assert_true(name.ends_with(".ttf"), "body candidate must be a .ttf: %s" % name)
	assert_eq(ThemeFonts.FONT_DIR, "res://assets/fonts")