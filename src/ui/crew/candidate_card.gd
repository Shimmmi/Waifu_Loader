extends PanelContainer

## Candidate reveal levels: card / resume / interview (v0.2 §3.6).

var worker_id: String = ""
var _mgr: Node = null
var _level: int = 0  # 0 card, 1 resume, 2 interview
var _root: VBoxContainer


func bind(wid: String, mgr: Node = null) -> void:
	worker_id = wid
	_mgr = mgr
	name = "CandidateCard"
	_build()


func _worker() -> Worker:
	for c in GameState.board.pool:
		if c.id == worker_id:
			return c
	return GameState.worker_by_id(worker_id)


func _build() -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and _mgr:
			_mgr.close_card())
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 20)
	panel.custom_minimum_size = Vector2(400, 220)
	add_child(panel)
	_root = VBoxContainer.new()
	panel.add_child(_root)
	_refresh()


func _refresh() -> void:
	for c in _root.get_children():
		c.queue_free()
	var w: Worker = _worker()
	if w == null:
		return
	var head := HBoxContainer.new()
	_root.add_child(head)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(96, 96)
	tex.texture = PixelAssets.portrait(w, 48, "neutral")
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(tex)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var title := Label.new()
	title.text = "%s · %s · %s" % [w.display_name(), Loc.class_name_of(w.class_id), Loc.species_name(w.species)]
	info.add_child(title)
	var pot := Label.new()
	pot.text = "Потенциал: %s ±1 · ЗП %s" % [Loc.rarity_name(w.rarity), Fmt.num(w.wage)]
	info.add_child(pot)

	var stats_lbl := Label.new()
	if _level == 0:
		stats_lbl.text = "Статы: ??  Черты: ??  Психотип: ??"
	elif _level == 1:
		var st: Dictionary = w.stats(GameState.rules)
		stats_lbl.text = "Статы ≈ СИЛ %d–%d · Звезда %s" % [
			maxi(int(st["str"]) - 3, 1), int(st["str"]) + 3, w.star]
	else:
		var st2: Dictionary = w.stats(GameState.rules)
		var open_trait := "?"
		for t in w.traits:
			if not t.get("hidden", false):
				open_trait = String(t["id"])
				break
		stats_lbl.text = "СИЛ%d ЛОВ%d ТОЧ%d ВЫН%d СМЕК%d · %s · %s · черта %s" % [
			int(st2["str"]), int(st2["agi"]), int(st2["acc"]), int(st2["end"]), int(st2["wit"]),
			w.psycho, w.star, open_trait]
	info.add_child(stats_lbl)

	var reveal := HBoxContainer.new()
	_root.add_child(reveal)
	if _level < 1:
		var r1 := Button.new()
		r1.text = "Резюме (%s ¢)" % Fmt.num(GameState.board.resume_cost(w))
		r1.disabled = GameState.credits < GameState.board.resume_cost(w)
		r1.pressed.connect(func():
			GameState.credits -= GameState.board.resume_cost(w)
			_level = 1
			GameState.stats_changed.emit()
			_refresh())
		reveal.add_child(r1)
	if _level < 2:
		var r2 := Button.new()
		r2.text = "Собеседование (%s ¢)" % Fmt.num(GameState.board.interview_cost(w))
		r2.disabled = GameState.credits < GameState.board.interview_cost(w)
		r2.pressed.connect(func():
			GameState.credits -= GameState.board.interview_cost(w)
			_level = 2
			GameState.stats_changed.emit()
			_refresh())
		reveal.add_child(r2)

	var reason: String = GameState.hire_block_reason(w.id)
	var hire := Button.new()
	hire.text = Loc.t("hire.hire", [Fmt.num(GameState.board.hire_cost(w))])
	hire.disabled = reason != ""
	hire.tooltip_text = reason
	hire.pressed.connect(func():
		if GameState.hire(w.id):
			if _mgr: _mgr.close_card())
	_root.add_child(hire)
	var close_btn := Button.new()
	close_btn.text = Loc.t("card.close")
	close_btn.pressed.connect(func(): if _mgr: _mgr.close_card())
	_root.add_child(close_btn)
