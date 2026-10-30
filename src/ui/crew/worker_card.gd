extends PanelContainer

## Full worker card modal (v0.2 §3.3–3.5). Built in code for P0.

var worker_id: String = ""
var _mgr: Node = null
var _tab: String = "overview"
var _portrait: TextureRect
var _body: VBoxContainer
var _actions: HBoxContainer


func bind(wid: String, mgr: Node = null) -> void:
	worker_id = wid
	_mgr = mgr
	_build()
	GameState.worker_changed.connect(_on_worker_changed)


func _exit_tree() -> void:
	if GameState.worker_changed.is_connected(_on_worker_changed):
		GameState.worker_changed.disconnect(_on_worker_changed)


func _on_worker_changed(id: String) -> void:
	if id == worker_id:
		_rebuild_body()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 250)
	panel.position = Vector2(10, 10)
	add_child(panel)

	var root := VBoxContainer.new()
	panel.add_child(root)

	var w: Worker = _worker()
	var head := HBoxContainer.new()
	root.add_child(head)
	var prev := Button.new()
	prev.text = "<"
	prev.pressed.connect(func(): if _mgr: _mgr.prev_card())
	head.add_child(prev)
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "%s  %s  [%s]" % [
		w.display_name() if w else "?",
		Loc.t("crew.level", [w.level if w else 1]),
		Loc.rarity_name(w.rarity if w else 0),
	]
	head.add_child(title)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(func(): if _mgr: _mgr.next_card())
	head.add_child(next)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.pressed.connect(_close)
	head.add_child(close_btn)

	var mid := HBoxContainer.new()
	root.add_child(mid)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture = PixelAssets.portrait(w, 48, w.expression_state() if w else "neutral")
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mid.add_child(_portrait)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_body)

	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	for t in ["overview", "skills", "traits", "dossier", "history"]:
		var b := Button.new()
		b.text = Loc.t("card." + t)
		b.pressed.connect(_set_tab.bind(t))
		tabs.add_child(b)

	_actions = HBoxContainer.new()
	root.add_child(_actions)
	_rebuild_body()
	_rebuild_actions()


func _set_tab(t: String) -> void:
	_tab = t
	_rebuild_body()


func _rebuild_body() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	var w: Worker = _worker()
	if w == null:
		return
	if _portrait:
		_portrait.texture = PixelAssets.portrait(w, 48, w.expression_state())
	var id_lbl := Label.new()
	id_lbl.text = "%s · %s · %s · %s" % [
		Loc.species_name(w.species), Loc.class_name_of(w.class_id), w.star, w.psycho]
	_body.add_child(id_lbl)
	var stats: Dictionary = w.stats(GameState.rules)
	for s in [["СИЛ", "str"], ["ЛОВ", "agi"], ["ТОЧ", "acc"], ["ВЫН", "end"], ["СМЕК", "wit"]]:
		var bar := StatBar.new()
		_body.add_child(bar)
		var bd: Dictionary = w.stat_breakdown(s[1], GameState.rules)
		bar.setup(s[0], float(stats[s[1]]), float(bd.get("equip", 0.0)))
	var fit_lbl := Label.new()
	fit_lbl.text = "Пригодность: Разгр. %.2f Перем. %.2f Разм. %.2f" % [
		w.station_score("unload", GameState.rules, GameState.crew),
		w.station_score("move", GameState.rules, GameState.crew),
		w.station_score("store", GameState.rules, GameState.crew),
	]
	_body.add_child(fit_lbl)
	var state := Label.new()
	state.text = "Усталость %d  Мораль %d  ЗП %s  XP %d/%d" % [
		int(w.fatigue), int(w.morale), Fmt.num(w.wage), int(w.xp), int(w.xp_needed(w.level))]
	_body.add_child(state)

	match _tab:
		"skills":
			var sk := Label.new()
			sk.text = "Навыки: %s" % str(w.skills)
			_body.add_child(sk)
		"traits":
			var parts: Array = []
			for t in w.traits:
				if t.get("hidden", false) and w.shifts_worked < 3:
					parts.append("?")
				else:
					parts.append(String(t["id"]))
			var tr := Label.new()
			tr.text = "Черты: " + (", ".join(parts) if parts else "—")
			_body.add_child(tr)
		"dossier":
			var d := Label.new()
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.text = "Раса %s. Класс %s. Звезда %s. Психотип %s." % [
				Loc.species_name(w.species), Loc.class_name_of(w.class_id), w.star, w.psycho]
			_body.add_child(d)
		"history":
			var h := Label.new()
			h.text = "Смен: %d · статус: %s" % [w.shifts_worked, w.status]
			_body.add_child(h)
		_:
			var ov := Label.new()
			ov.text = "Синергия линии: %.1f" % GameState.synergy.line_synergy(GameState.assigned_workers())
			_body.add_child(ov)


func _rebuild_actions() -> void:
	if _actions == null:
		return
	for c in _actions.get_children():
		c.queue_free()
	var w: Worker = _worker()
	if w == null:
		return
	_add_action(Loc.t("card.assign"), func(): _assign_best(w), _assign_reason(w))
	_add_action(Loc.t("card.unassign"), func(): _bench(w), "" if w.status == "shift" else "—")
	_add_action(Loc.t("card.pin") if not w.pinned else Loc.t("card.unpin"), func():
		w.pinned = not w.pinned
		GameState.worker_changed.emit(w.id)
		GameState.roster_changed.emit()
	, "")
	_add_action(Loc.t("card.fire"), func():
		GameState.roster.erase(w)
		GameState.roster_changed.emit()
		_close()
	, "")


func _add_action(text: String, cb: Callable, reason: String) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = reason != ""
	b.tooltip_text = reason
	if reason == "":
		b.pressed.connect(cb)
	_actions.add_child(b)


func _assign_reason(w: Worker) -> String:
	if w.status == "injured":
		return "Больничный"
	for station in ["unload", "move", "store", "support"]:
		for i in int(GameState.STATION_SLOTS.get(station, 0)):
			var sid := "%s%d" % [station, i]
			if String(GameState.slots.get(sid, "")) == "":
				return ""
	return "Нет свободных слотов"


func _assign_best(w: Worker) -> void:
	var best_slot := ""
	var best_score := -1.0
	for station in ["unload", "move", "store"]:
		var score: float = w.station_score(station, GameState.rules, GameState.crew)
		for i in int(GameState.STATION_SLOTS.get(station, 0)):
			var sid := "%s%d" % [station, i]
			if String(GameState.slots.get(sid, "")) == "" and score > best_score:
				best_score = score
				best_slot = sid
	if best_slot != "":
		GameState.assign(best_slot, w.id)


func _bench(w: Worker) -> void:
	for sid in GameState.slots.keys():
		if GameState.slots[sid] == w.id:
			GameState.clear_slot(sid)
			return


func _worker() -> Worker:
	var w: Worker = GameState.worker_by_id(worker_id)
	if w == null:
		for c in GameState.board.pool:
			if c.id == worker_id:
				return c
	return w


func _close() -> void:
	if _mgr and _mgr.has_method("close_card"):
		_mgr.close_card()
	else:
		queue_free()
