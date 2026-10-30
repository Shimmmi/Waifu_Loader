extends VBoxContainer

## Contracts board (spec §15.4). Stub text centered with autowrap on all scales (TZ §2.8).


func _ready() -> void:
	visibility_changed.connect(_maybe_rebuild)
	GameState.contracts_changed.connect(_rebuild)
	_rebuild()


func apply_scale(_s: int) -> void:
	_rebuild()


func _maybe_rebuild() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	if GameState.rank < 4:
		var stub := _label(Loc.t("contracts.locked") if _has("contracts.locked") \
			else "Контракты откроются на ранге 4.")
		stub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(stub)
		return

	add_child(_label(Loc.t("contracts.title") if _has("contracts.title") else "Доска контрактов"))

	if GameState.active_contract != null:
		var ac: Contract = GameState.active_contract
		add_child(_label("%s %s · %.0f/%.0f т · до конца %s" % [
			ac.tier, ac.client_id, ac.delivered, ac.q, Fmt.time(ac.deadline_left() * 60.0)]))

	var refresh := Button.new()
	refresh.text = "Обновить доску"
	refresh.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	refresh.pressed.connect(func(): GameState._refresh_contracts())
	add_child(refresh)

	for c in GameState.contracts.offers:
		add_child(_row(c))


func _row(c: Contract) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("%s · %s · %s · %.0f т · %d мин · %s ¢" % [
		c.tier, c.client_id, _mix(c), c.q, int(c.deadline_min), Fmt.num(float(c.reward["credits"]))]))
	var btn := Button.new()
	btn.text = "Принять"
	btn.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	btn.disabled = GameState.active_contract != null
	btn.pressed.connect(func(): GameState.accept_contract(c.id))
	box.add_child(btn)
	return box


func _mix(c: Contract) -> String:
	var parts: Array = []
	for k in c.cargo_mix:
		parts.append("%s %d%%" % [k, int(float(c.cargo_mix[k]) * 100.0)])
	return ", ".join(parts)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _has(key: String) -> bool:
	return Loc._tables.get(Loc.code, {}).has(key) or Loc._tables.get("ru", {}).has(key)
