class_name BuildPanel
extends PanelContainer

## S3 terminal build overlay (TZ §2.8).

signal closed

var _box: VBoxContainer
var _dock: Button
var _store: Button
var _expand: Button
var _shift_line: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", UiScale.metric("gap"))
	add_child(_box)
	_dock = Button.new()
	_store = Button.new()
	_expand = Button.new()
	_shift_line = Label.new()
	for b in [_dock, _store, _expand]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = float(UiScale.metric("btn_h"))
		_box.add_child(b)
	_box.add_child(_shift_line)
	var close := Button.new()
	close.text = Loc.t("UI_CLOSE")
	close.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	close.pressed.connect(func():
		visible = false
		closed.emit()
	)
	_box.add_child(close)


func bind_actions(on_dock: Callable, on_store: Callable, on_expand: Callable) -> void:
	_dock.pressed.connect(on_dock)
	_store.pressed.connect(on_store)
	_expand.pressed.connect(on_expand)


func refresh() -> void:
	var margin: float = float(UiScale.metric("panel_margin"))
	var ls: Vector2 = UiScale.logical_size()
	custom_minimum_size = Vector2(ls.x - 2.0 * margin, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	var dock: Sector = GameState.sector_of_type("dock")
	var store: Sector = GameState.sector_of_type("storage")
	if dock:
		_dock.text = Loc.t("action.dock", [dock.level, Fmt.num(GameState.grid.upgrade_cost(dock))])
	if store:
		_store.text = Loc.t("action.storage", [store.level, Fmt.num(GameState.grid.upgrade_cost(store))])
	_expand.text = Loc.t("action.expand", [Fmt.num(GameState.grid.expand_cost())])
	var shift: Shift = GameState.shift
	if shift:
		_shift_line.text = Loc.t("hud.shift", [Fmt.time(maxf(0.0, shift.duration_s - shift.elapsed_s))])
	else:
		_shift_line.text = Loc.t("hud.shift_none")
