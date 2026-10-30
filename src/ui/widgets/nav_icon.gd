class_name NavIcon
extends Control

## 12×12 nav glyph or two-letter fallback (TZ §2.8 NavBar).

const FALLBACK: Dictionary = {
	"terminal": "Те",
	"loading": "По",
	"crew": "Бр",
	"hire": "На",
	"contracts": "Ко",
	"world": "Ми",
	"menu": "Ме",
}

var tab_id: String = ""
var _tex: TextureRect
var _lbl: Label


func _ready() -> void:
	custom_minimum_size = Vector2(12, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = TextureRect.new()
	_tex.custom_minimum_size = Vector2(12, 12)
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_tex)
	_lbl = Label.new()
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_lbl)
	_refresh()


func setup(id: String) -> void:
	tab_id = id
	if is_inside_tree():
		_refresh()


func _refresh() -> void:
	var path: String = "res://assets/ui/nav_%s.png" % tab_id
	if ResourceLoader.exists(path):
		_tex.texture = load(path)
		_tex.visible = true
		_lbl.visible = false
	else:
		_tex.visible = false
		_lbl.visible = true
		_lbl.text = String(FALLBACK.get(tab_id, tab_id.substr(0, 2)))
