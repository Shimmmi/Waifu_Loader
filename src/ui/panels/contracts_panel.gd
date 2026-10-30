extends VBoxContainer

## Contracts board (spec §15.4). Lists offers with Accept buttons and shows the
## active contract's progress. Rows are rebuilt in code.


func _ready() -> void:
	visibility_changed.connect(_maybe_rebuild)
	GameState.contracts_changed.connect(_rebuild)
	_rebuild()


func _maybe_rebuild() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	if GameState.rank < 4:
		add_child(_label("Контракты откроются на ранге 4."))
		return

	add_child(_label("Доска контрактов"))

	if GameState.active_contract != null:
		var ac: Contract = GameState.active_contract
		add_child(_label("Активен: %s %s · %.0f/%.0f т · до конца %s" % [
			ac.tier, ac.client_id, ac.delivered, ac.q, Fmt.time(ac.deadline_left() * 60.0)]))

	var refresh := Button.new()
	refresh.text = "Обновить доску"
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
	return l