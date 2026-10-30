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


func apply_scale(_s: int) -> void:
	_build()


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
	var margin: float = float(UiScale.metric("panel_margin"))
	var ls: Vector2 = UiScale.logical_size()
	if UiScale.scale_factor == 1:
		panel.custom_minimum_size = Vector2(460, 250)
		panel.position = Vector2(10, 10)
	else:
		panel.custom_minimum_size = Vector2(ls.x - 2.0 * margin, ls.y - 2.0 * margin)
		panel.position = Vector2(margin, margin)
	add_child(panel)

	var root := VBoxContainer.new()
	panel.add_child(root)

	var w: Worker = _worker()
	var head := HBoxContainer.new()
	root.add_child(head)
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(float(UiScale.metric("btn_h")), float(UiScale.metric("btn_h")))
	prev.pressed.connect(func(): if _mgr: _mgr.prev_card())
	head.add_child(prev)
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text = "%s  %s  [%s]" % [
		Fmt.name(w.display_name() if w else "?", UiScale.metric("max_name_chars")),
		Loc.t("crew.level", [w.level if w else 1]),
		Loc.rarity_name(w.rarity if w else 0),
	]
	head.add_child(title)
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(float(UiScale.metric("btn_h")), float(UiScale.metric("btn_h")))
	next.pressed.connect(func(): if _mgr: _mgr.next_card())
	head.add_child(next)
	var more := Button.new()
	more.text = "⋯"
	more.custom_minimum_size = Vector2(12, 12)
	more.pressed.connect(_open_actions_overlay)
	head.add_child(more)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(12, 12)
	close_btn.pressed.connect(_close)
	head.add_child(close_btn)

	if UiScale.scale_factor >= 2:
		var pager := CardPager.new()
		pager.size_flags_vertical = Control.SIZE_EXPAND_FILL
		root.add_child(pager)
		pager.setup(_pager_pages())
		_body = null
		_actions = null
		_portrait = null
	else:
		var mid := HBoxContainer.new()
		root.add_child(mid)
		_portrait = TextureRect.new()
		_portrait.custom_minimum_size = Vector2(float(UiScale.metric("portrait_px")), float(UiScale.metric("portrait_px")))
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


func _pager_pages() -> Array:
	var w: Worker = _worker()
	return [
		{"title": Loc.t("card.overview"), "build": func(box: VBoxContainer): _page_profile(box, w)},
		{"title": "Статы", "build": func(box: VBoxContainer): _page_stats(box, w)},
		{"title": "Состояние", "build": func(box: VBoxContainer): _page_state(box, w)},
		{"title": Loc.t("card.skills"), "build": func(box: VBoxContainer): _page_skills(box, w)},
		{"title": Loc.t("card.traits"), "build": func(box: VBoxContainer): _page_traits(box, w)},
		{"title": Loc.t("card.dossier"), "build": func(box: VBoxContainer): _page_dossier(box, w)},
		{"title": Loc.t("card.history"), "build": func(box: VBoxContainer): _page_history(box, w)},
	]


func _page_profile(box: VBoxContainer, w: Worker) -> void:
	if w == null:
		return
	var row := HBoxContainer.new()
	box.add_child(row)
	var tex := TextureRect.new()
	var px: float = float(UiScale.metric("portrait_px"))
	tex.custom_minimum_size = Vector2(px, px)
	tex.texture = PixelAssets.portrait(w, 48, w.expression_state())
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(tex)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	for line in [
		Fmt.name(w.display_name(), UiScale.metric("max_name_chars")),
		Loc.class_name_of(w.class_id),
		Loc.species_name(w.species),
		Loc.rarity_name(w.rarity),
		Loc.t("crew.level", [w.level]),
	]:
		var l := Label.new()
		l.text = line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(l)


func _page_stats(box: VBoxContainer, w: Worker) -> void:
	if w == null:
		return
	var stats: Dictionary = w.stats(GameState.rules)
	for s in [["СИЛ", "str"], ["ЛОВ", "agi"], ["ТОЧ", "acc"], ["ВЫН", "end"], ["СМЕК", "wit"]]:
		var bar := StatBar.new()
		box.add_child(bar)
		var bd: Dictionary = w.stat_breakdown(s[1], GameState.rules)
		bar.setup(s[0], float(stats[s[1]]), float(bd.get("equip", 0.0)))


func _page_state(box: VBoxContainer, w: Worker) -> void:
	if w == null:
		return
	var fit := Label.new()
	fit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fit.text = "Пригодность: Разгр. %.2f Перем. %.2f Разм. %.2f" % [
		w.station_score("unload", GameState.rules, GameState.crew),
		w.station_score("move", GameState.rules, GameState.crew),
		w.station_score("store", GameState.rules, GameState.crew),
	]
	box.add_child(fit)
	var state := Label.new()
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.text = "Усталость %d  Мораль %d  ЗП %s  XP %d/%d" % [
		int(w.fatigue), int(w.morale), Fmt.num(w.wage), int(w.xp), int(w.xp_needed(w.level))]
	box.add_child(state)


func _page_skills(box: VBoxContainer, w: Worker) -> void:
	var sk := Label.new()
	sk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sk.text = "Навыки: %s" % str(w.skills if w else {})
	box.add_child(sk)


func _page_traits(box: VBoxContainer, w: Worker) -> void:
	var parts: Array = []
	if w:
		for t in w.traits:
			parts.append("?" if t.get("hidden", false) and w.shifts_worked < 3 else String(t["id"]))
	var tr := Label.new()
	tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.text = "Черты: " + (", ".join(parts) if parts else "—")
	box.add_child(tr)


func _page_dossier(box: VBoxContainer, w: Worker) -> void:
	var d := Label.new()
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.text = "Раса %s. Класс %s. Звезда %s. Психотип %s." % [
		Loc.species_name(w.species) if w else "?",
		Loc.class_name_of(w.class_id) if w else "?",
		w.star if w else "?", w.psycho if w else "?"]
	box.add_child(d)


func _page_history(box: VBoxContainer, w: Worker) -> void:
	var h := Label.new()
	h.text = "Смен: %d · статус: %s" % [w.shifts_worked if w else 0, w.status if w else "—"]
	box.add_child(h)


func _open_actions_overlay() -> void:
	var host: Control = get_parent() as Control
	if host == null:
		host = self
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	var margin: float = float(UiScale.metric("panel_margin"))
	overlay.custom_minimum_size = Vector2(UiScale.logical_size().x - 2.0 * margin, 0)
	var box := VBoxContainer.new()
	overlay.add_child(box)
	var w: Worker = _worker()
	if w:
		_add_action_to(box, Loc.t("card.assign"), func(): _assign_best(w), _assign_reason(w))
		_add_action_to(box, Loc.t("card.pin") if not w.pinned else Loc.t("card.unpin"), func():
			w.pinned = not w.pinned
			GameState.worker_changed.emit(w.id)
			GameState.roster_changed.emit()
		, "")
		_add_action_to(box, Loc.t("card.fire"), func():
			GameState.roster.erase(w)
			GameState.roster_changed.emit()
			_close()
		, "")
	var close := Button.new()
	close.text = Loc.t("UI_CLOSE")
	close.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	close.pressed.connect(func(): overlay.queue_free())
	box.add_child(close)
	host.add_child(overlay)


func _add_action_to(parent: Control, text: String, cb: Callable, reason: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = reason != ""
	if reason != "":
		UiTooltip.attach(b, reason)
	else:
		b.pressed.connect(cb)
	parent.add_child(b)


func _add_action(text: String, cb: Callable, reason: String) -> void:
	_add_action_to(_actions, text, cb, reason)


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
