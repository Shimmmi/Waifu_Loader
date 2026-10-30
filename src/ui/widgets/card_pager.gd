class_name CardPager
extends VBoxContainer

## Paged worker/candidate card body for S2/S3 (TZ §2.8).

signal page_changed(index: int)

var _pages: Array = []  # Array of {title: String, build: Callable}
var _index: int = 0
var _title: Label
var _dots: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _swipe_origin: Vector2 = Vector2.ZERO
var _swiping: bool = false


func setup(pages: Array) -> void:
	_pages = pages
	_index = 0
	_rebuild_chrome()
	_show_page(0)


func _rebuild_chrome() -> void:
	for c in get_children():
		c.queue_free()
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", UiScale.metric("gap"))
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(float(UiScale.metric("btn_h")), float(UiScale.metric("btn_h")))
	prev.pressed.connect(func(): _show_page(_index - 1))
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(float(UiScale.metric("btn_h")), float(UiScale.metric("btn_h")))
	next.pressed.connect(func(): _show_page(_index + 1))
	nav.add_child(prev)
	nav.add_child(_title)
	nav.add_child(next)
	add_child(nav)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_dots)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiScale.style_scroll(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	add_child(_scroll)
	gui_input.connect(_on_swipe)
	_scroll.gui_input.connect(_on_swipe)


func _show_page(i: int) -> void:
	if _pages.is_empty():
		return
	_index = clampi(i, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_index]
	_title.text = String(page.get("title", ""))
	for c in _body.get_children():
		c.queue_free()
	for c in _dots.get_children():
		c.queue_free()
	for di in _pages.size():
		var d := Label.new()
		d.text = "●" if di == _index else "○"
		_dots.add_child(d)
	var builder: Callable = page.get("build", Callable())
	if builder.is_valid():
		builder.call(_body)
	page_changed.emit(_index)


func _on_swipe(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_swipe_origin = event.position
			_swiping = true
		elif not event.pressed and _swiping:
			_swiping = false
			var delta: Vector2 = event.position - _swipe_origin
			if absf(delta.x) > 12.0 and absf(delta.x) > absf(delta.y):
				if delta.x < 0.0:
					_show_page(_index + 1)
				else:
					_show_page(_index - 1)
