extends TestCase


func test_body_font_covers_cyrillic_sample() -> void:
	assert_true(ThemeFonts.has_body_font())
	var font: FontFile = ThemeFonts.body_font()
	assert_true(font != null)
	ThemeFonts._tune(font)
	# Spot-check glyphs from the v0.2 §2.1 sample string.
	for ch in ["А", "Я", "ё", "ы", "ь", "0", "¢"]:
		var cp: int = ch.unicode_at(0)
		assert_true(font.has_char(cp), "missing glyph " + ch)


func test_sample_string_constant() -> void:
	assert_true(ThemeFonts.CYRILLIC_SAMPLE.find("АБВГДЕЁ") >= 0)
	assert_true(ThemeFonts.CYRILLIC_SAMPLE.find("ъыьэюя") >= 0)
