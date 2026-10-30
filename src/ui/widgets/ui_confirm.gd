class_name UiConfirm
extends Control

## Replaces ConfirmationDialog (TZ §2.10).

signal answered(accepted: bool)

static var _host: Control = null


static func bind_host(host: Control) -> void:
	_host = host


static func ask(title_key: String, body_key: String, ok_key: String = "UI_OK", cancel_key: String = "UI_CANCEL") -> Control:
	var dlg := Control.new()
	dlg.set_script(load("res://src/ui/widgets/ui_confirm.gd"))
	if _host:
		_host.add_child(dlg)
	dlg.call("_build", title_key, body_key, ok_key, cancel_key)
	return dlg


func _build(title_key: String, body_key: String, ok_key: String, cancel_key: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var margin: float = float(UiScale.metric("panel_margin"))
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var ls: Vector2 = UiScale.logical_size()
	var max_w: float = ls.x - 2.0 * margin
	# S2/S3 logical width ≤ 240 → cap confirm at 200 (TZ §2.8); S1 keeps full.
	if ls.x <= 240.0:
		max_w = mini(200.0, max_w)
	panel.custom_minimum_size = Vector2(max_w * 0.85, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiScale.metric("gap"))
	panel.add_child(box)
	var title := Label.new()
	title.text = Loc.t(title_key)
	box.add_child(title)
	var body := Label.new()
	body.text = Loc.t(body_key)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var btns := HFlowContainer.new()
	btns.add_theme_constant_override("h_separation", UiScale.metric("gap"))
	btns.add_theme_constant_override("v_separation", UiScale.metric("gap"))
	var ok := Button.new()
	ok.text = Loc.t(ok_key)
	ok.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	ok.pressed.connect(func(): _finish(true))
	var cancel := Button.new()
	cancel.text = Loc.t(cancel_key)
	cancel.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	cancel.pressed.connect(func(): _finish(false))
	btns.add_child(ok)
	btns.add_child(cancel)
	box.add_child(btns)


func _finish(ok: bool) -> void:
	answered.emit(ok)
	queue_free()
