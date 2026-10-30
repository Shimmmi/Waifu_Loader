extends CanvasLayer

## Autoload-style overlay host for worker cards (v0.2 §6.2).
## Added as a child of the Terminal root at runtime if not present.

var _card: Control = null
var _context_list: Array[String] = []
var _index: int = 0


func open_worker_card(worker_id: String, context: String = "crew") -> void:
	_context_list.clear()
	if context == "hire":
		for w in GameState.board.pool:
			_context_list.append(w.id)
	else:
		for w in GameState.roster:
			_context_list.append(w.id)
	_index = _context_list.find(worker_id)
	if _index < 0:
		_index = 0
		_context_list = [worker_id]
	_show_current(context)


func open_candidate_card(worker_id: String) -> void:
	open_worker_card(worker_id, "hire")


func close_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


func _show_current(context: String) -> void:
	close_card()
	if _context_list.is_empty():
		return
	var wid: String = _context_list[_index]
	var scene_path := "res://src/ui/crew/CandidateCard.tscn" if context == "hire" else "res://src/ui/crew/WorkerCard.tscn"
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		# Fallback: build a minimal panel in code.
		_card = _build_fallback(wid, context)
	else:
		_card = packed.instantiate()
	add_child(_card)
	if _card.has_method("bind"):
		_card.bind(wid, self)


func next_card() -> void:
	if _context_list.is_empty():
		return
	_index = (_index + 1) % _context_list.size()
	_show_current("hire" if _card != null and _card.name.begins_with("Candidate") else "crew")


func prev_card() -> void:
	if _context_list.is_empty():
		return
	_index = (_index - 1 + _context_list.size()) % _context_list.size()
	_show_current("hire" if _card != null and _card.name.begins_with("Candidate") else "crew")


func _build_fallback(wid: String, context: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "CandidateCard" if context == "hire" else "WorkerCard"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var script: Script = load("res://src/ui/crew/worker_card.gd")
	if script:
		panel.set_script(script)
	return panel


func _unhandled_input(event: InputEvent) -> void:
	if _card == null:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				close_card()
				get_viewport().set_input_as_handled()
			KEY_Q:
				prev_card()
				get_viewport().set_input_as_handled()
			KEY_E:
				next_card()
				get_viewport().set_input_as_handled()
