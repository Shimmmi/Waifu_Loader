class_name HudDetails
extends PanelContainer

## HUD overflow overlay for S2/S3 (TZ §2.8).

signal closed

var _box: VBoxContainer
var _last_shift: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(120, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", UiScale.metric("gap"))
	add_child(_box)


func bind_and_show(host: Control, last_shift: String = "") -> void:
	_last_shift = last_shift
	if get_parent() != host:
		if get_parent():
			get_parent().remove_child(self)
		host.add_child(self)
	_rebuild()
	visible = true
	position = Vector2(
		UiScale.logical_size().x - 120.0 - float(UiScale.metric("pad")),
		float(UiScale.metric("hud_h")))


func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(_line("Зч " + Fmt.num(GameState.parts)))
	var shift: Shift = GameState.shift
	if shift:
		var rem: float = maxf(0.0, shift.duration_s - shift.elapsed_s)
		_box.add_child(_line(Loc.t("hud.shift", [Fmt.time(rem)])))
	else:
		_box.add_child(_line(Loc.t("hud.shift_none")))
	_box.add_child(_line(Loc.t("hud.rank", [GameState.rank])))
	var need: float = GameState.rep_needed(GameState.rank + 1)
	var cur: float = GameState.rep_needed(GameState.rank)
	var pct: int = int(100.0 * clampf((GameState.rep - cur) / maxf(need - cur, 1.0), 0.0, 1.0))
	_box.add_child(_line("%d%%" % pct))
	_box.add_child(_line(Loc.t("menu.net", [
		Loc.t("menu.online") if GameState.online else Loc.t("menu.offline")])))
	if not _last_shift.is_empty():
		_box.add_child(_line(_last_shift))
	var close := Button.new()
	close.text = Loc.t("UI_CLOSE")
	close.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	close.pressed.connect(func():
		visible = false
		closed.emit()
	)
	_box.add_child(close)


func _line(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
