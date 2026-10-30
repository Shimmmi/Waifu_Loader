extends Control

## First-run tutorial / FTUE (M9). Shown once; steps are localization keys.

const STEPS: Array[String] = ["TUT_1", "TUT_2", "TUT_3", "TUT_4", "TUT_5"]

var _index: int = 0

@onready var _title: Label = $Panel/VBox/Title
@onready var _text: Label = $Panel/VBox/Text
@onready var _next: Button = $Panel/VBox/Row/Next
@onready var _skip: Button = $Panel/VBox/Row/Skip


func _ready() -> void:
	if GameState.tutorial_seen:
		visible = false
		return
	_next.pressed.connect(_advance)
	_skip.pressed.connect(_finish)
	Loc.locale_changed.connect(func(_c: String): _refresh())
	_refresh()


func _refresh() -> void:
	_title.text = Loc.t("TUT_TITLE")
	_text.text = Loc.t(STEPS[_index])
	_next.text = Loc.t("TUT_NEXT")
	_skip.text = Loc.t("TUT_SKIP")


func _advance() -> void:
	_index += 1
	if _index >= STEPS.size():
		_finish()
	else:
		_refresh()


func _finish() -> void:
	GameState.tutorial_seen = true
	GameState.save_settings()
	visible = false