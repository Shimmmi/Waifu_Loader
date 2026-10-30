class_name ThemeFonts
extends RefCounted

## Optional bundled pixel fonts (spec §16.3 — third-party assets, logged in
## assets/ASSETS.md). If the files exist in res://assets/fonts/ they are applied
## to the project theme; otherwise the engine default font is kept, so the game
## runs fine before the fonts are dropped in. Safe to call more than once.
##
## v0.2 §2.1: one body font with full Cyrillic for the whole UI. Display font
## (Press Start 2P) is available for latin-only accents but must NOT be mixed
## into body text (incomplete Cyrillic coverage).

const FONT_DIR: String = "res://assets/fonts"

## Body font, in preference order (Cyrillic-complete).
const BODY_CANDIDATES: PackedStringArray = [
	"PixelifySans-VariableFont_wght.ttf",
	"PixelifySans-Regular.ttf",
	"PixelifySans.ttf",
]

## Display font (menus / headings), latin-leaning — do not use for RU body.
const DISPLAY_CANDIDATES: PackedStringArray = [
	"PressStart2P-Regular.ttf",
	"PressStart2P.ttf",
]

## Cyrillic coverage sample for screenshot / lint tests (v0.2 §2.1).
const CYRILLIC_SAMPLE: String = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ абвгдеёжзийклмнопрстуфхцчшщъыьэюя 0123456789 ¢%+−×·«»"


## Apply the bundled fonts to the project theme. Returns true if a body font
## was found and applied.
static func apply() -> bool:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return false
	var body: FontFile = _first(BODY_CANDIDATES)
	if body == null:
		return false
	_tune(body)
	theme.default_font = body
	return true


## True when the bundled body font is present on disk.
static func has_body_font() -> bool:
	return _first(BODY_CANDIDATES) != null


static func body_font() -> FontFile:
	return _first(BODY_CANDIDATES)


static func _first(candidates: PackedStringArray) -> FontFile:
	for file_name in candidates:
		var path: String = FONT_DIR + "/" + file_name
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is FontFile:
				return res
	return null


## Pixel fonts must not be smoothed, anti-aliased, or sub-pixel positioned.
static func _tune(font: FontFile) -> void:
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.multichannel_signed_distance_field = false
	font.generate_mipmaps = false
	font.oversampling = 1.0
