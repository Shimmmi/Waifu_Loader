extends VBoxContainer

## «Масштаб UI» row for Menu → Settings (TZ §2.6).

var _btn1: Button
var _btn2: Button
var _btn3: Button
var _group: ButtonGroup
var _scroll_restore: int = 0


func _ready() -> void:
	_group = ButtonGroup.new()
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", UiScale.metric("gap"))
	row.add_theme_constant_override("v_separation", UiScale.metric("gap"))
	var title := Label.new()
	title.text = Loc.t("SET_UI_SCALE")
	row.add_child(title)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UiScale.metric("gap"))
	_btn1 = _make_btn("SET_UI_SCALE_1", 1)
	_btn2 = _make_btn("SET_UI_SCALE_2", 2)
	_btn3 = _make_btn("SET_UI_SCALE_3", 3)
	buttons.add_child(_btn1)
	buttons.add_child(_btn2)
	buttons.add_child(_btn3)
	row.add_child(buttons)
	add_child(row)
	var hint := Label.new()
	hint.text = Loc.t("SET_UI_SCALE_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.75, 0.78, 0.85, 1)
	add_child(hint)
	_sync(UiScale.scale_factor)
	UiScale.scale_changed.connect(_sync)
	Loc.locale_changed.connect(func(_c: String): _retranslate())


func _make_btn(key: String, scale_n: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group
	b.text = Loc.t(key)
	b.custom_minimum_size = Vector2(float(UiScale.metric("scale_btn_w")), float(UiScale.metric("btn_h")))
	b.pressed.connect(func(): _on_pick(scale_n))
	b.set_meta("scale_n", scale_n)
	b.set_meta("loc", key)
	return b


func _retranslate() -> void:
	_btn1.text = Loc.t("SET_UI_SCALE_1")
	_btn2.text = Loc.t("SET_UI_SCALE_2")
	_btn3.text = Loc.t("SET_UI_SCALE_3")
	if get_child_count() >= 2:
		(get_child(0).get_child(0) as Label).text = Loc.t("SET_UI_SCALE")
		(get_child(1) as Label).text = Loc.t("SET_UI_SCALE_HINT")


func _sync(s: int) -> void:
	_btn1.button_pressed = s == 1
	_btn2.button_pressed = s == 2
	_btn3.button_pressed = s == 3
	for b in [_btn1, _btn2, _btn3]:
		b.custom_minimum_size = Vector2(float(UiScale.metric("scale_btn_w")), float(UiScale.metric("btn_h")))


func _on_pick(n: int) -> void:
	if n == UiScale.scale_factor:
		return
	var sc: ScrollContainer = _find_scroll()
	if sc:
		_scroll_restore = sc.scroll_vertical
	UiScale.set_scale(n)
	await get_tree().process_frame
	await get_tree().process_frame
	if sc:
		sc.scroll_vertical = _scroll_restore
		sc.ensure_control_visible(self)


func _find_scroll() -> ScrollContainer:
	var n: Node = get_parent()
	while n:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null
