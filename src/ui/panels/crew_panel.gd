extends VBoxContainer

## Crew screen (spec §15.3 / v0.2 WP-A P0): station slots, localized roster
## rows, and a selected worker's detail card. Full CrewRow/WorkerCard land in W3;
## this panel already uses Loc helpers and opens the card overlay when present.

var _selected_id: String = ""


func _ready() -> void:
	visibility_changed.connect(_maybe_rebuild)
	GameState.roster_changed.connect(_rebuild)
	GameState.worker_changed.connect(func(_id: String): _rebuild())
	Loc.locale_changed.connect(func(_c: String): _rebuild())
	_rebuild()


func _maybe_rebuild() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var header := Label.new()
	header.text = Loc.t("crew.synergy", [GameState.synergy.line_synergy(GameState.assigned_workers())])
	add_child(header)

	for station in ["unload", "move", "store", "support"]:
		add_child(_station_row(station))

	var watch := Button.new()
	watch.text = Loc.t("line.watch")
	watch.pressed.connect(func(): GameState.request_tab("loading"))
	add_child(watch)

	add_child(_spacer())
	for w in GameState.roster:
		add_child(_worker_row(w))

	add_child(_spacer())
	add_child(_detail())


func _station_row(station: String) -> Control:
	var row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = Loc.station_name(station)
	name_lbl.custom_minimum_size = Vector2(72, 0)
	row.add_child(name_lbl)
	for i in int(GameState.STATION_SLOTS.get(station, 0)):
		var slot_id: String = "%s%d" % [station, i]
		var wid: String = GameState.slots.get(slot_id, "")
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "—" if wid == "" else _short(GameState.worker_by_id(wid))
		if wid == "":
			btn.modulate = _slot_color()
		btn.pressed.connect(_on_slot_pressed.bind(slot_id))
		row.add_child(btn)
	return row


func _worker_row(w: Worker) -> Control:
	var row := CrewRow.new()
	row.bind(w)
	row.selected.connect(func(id: String): _select(id))
	row.long_pressed.connect(func(id: String): _open_card(id))
	if w.id == _selected_id:
		row.modulate = row.modulate.lightened(0.25)
	return row


func _open_card(worker_id: String) -> void:
	var sm = get_tree().root.find_child("ScreenManager", true, false)
	if sm != null and sm.has_method("open_worker_card"):
		sm.open_worker_card(worker_id, "crew")


func _detail() -> Control:
	var box := VBoxContainer.new()
	var w: Worker = GameState.worker_by_id(_selected_id)
	if w == null:
		var hint := Label.new()
		hint.text = Loc.t("crew.pick")
		box.add_child(hint)
		return box
	var stats: Dictionary = w.stats(GameState.rules)
	var info := Label.new()
	info.text = "%s | %s | %s | %s | %s" % [
		w.display_name(),
		Loc.rarity_name(w.rarity),
		Loc.class_name_of(w.class_id),
		Loc.species_name(w.species),
		w.star,
	]
	box.add_child(info)
	var stats_lbl := Label.new()
	stats_lbl.text = "СИЛ%d ЛОВ%d ТОЧ%d ВЫН%d СМЕК%d | мораль %d усталость %d" % [
		int(stats["str"]), int(stats["agi"]), int(stats["acc"]), int(stats["end"]), int(stats["wit"]),
		int(w.morale), int(w.fatigue)]
	box.add_child(stats_lbl)

	var open_card := Button.new()
	open_card.text = Loc.t("card.overview")
	open_card.pressed.connect(func(): _open_card(w.id))
	box.add_child(open_card)

	var traits_text: Array = []
	for t in w.traits:
		traits_text.append(String(t["id"]) + ("?" if t["hidden"] else ""))
	var t2 := Label.new()
	t2.text = "Черты: %s" % (", ".join(traits_text) if not traits_text.is_empty() else "—")
	box.add_child(t2)

	var tier: int = GameState.available_skill_tier(w)
	if tier > 0:
		var srow := HBoxContainer.new()
		var sl := Label.new()
		sl.text = "Навык (тир %d):" % tier
		srow.add_child(sl)
		for sid in GameState.skill_options(w, tier):
			var b := Button.new()
			b.text = String(sid)
			b.pressed.connect(func(): GameState.choose_skill(w, tier, String(sid)))
			srow.add_child(b)
		box.add_child(srow)
	return box


func _on_slot_pressed(slot_id: String) -> void:
	if _selected_id != "":
		GameState.assign(slot_id, _selected_id)
		_select("")
	else:
		GameState.clear_slot(slot_id)


func _select(worker_id: String) -> void:
	_selected_id = worker_id
	_rebuild()


func _short(w: Worker) -> String:
	if w == null:
		return "—"
	var n: String = w.callsign if not w.callsign.is_empty() else w.full_name
	if n.length() > 8:
		n = n.substr(0, 7) + "…"
	return n


func _slot_color() -> Color:
	return Color(0.55, 0.55, 0.6, 1.0)


func _spacer() -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, 6)
	return s
