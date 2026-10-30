extends VBoxContainer

## Job exchange screen (spec §15.4 / v0.2 §2.7, §3.6). Lists the candidate
## pool with localized labels, hire reasons on disabled buttons, and a posting
## button. Rows are rebuilt in code.


func _ready() -> void:
	visibility_changed.connect(_maybe_rebuild)
	GameState.board_changed.connect(_rebuild)
	GameState.stats_changed.connect(_refresh_affordability)
	Loc.locale_changed.connect(func(_c: String): _rebuild())
	_rebuild()


func _maybe_rebuild() -> void:
	if visible:
		_rebuild()


func _refresh_affordability() -> void:
	if not visible:
		return
	for row in get_children():
		if row is HBoxContainer and row.get_child_count() >= 2:
			var btn := row.get_child(1) as Button
			if btn == null:
				continue
			var worker_id: String = String(btn.get_meta("worker_id", ""))
			if worker_id != "":
				var reason: String = GameState.hire_block_reason(worker_id)
				btn.disabled = reason != ""
				btn.tooltip_text = reason


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var title := Label.new()
	title.text = Loc.t("hire.title", [GameState.board.pool.size()])
	add_child(title)

	for w in GameState.board.pool:
		add_child(_row(w))

	var refresh := Button.new()
	refresh.text = Loc.t("hire.post", [Fmt.num(GameState.board.posting_cost(GameState.rank))])
	refresh.disabled = GameState.credits < GameState.board.posting_cost(GameState.rank)
	if refresh.disabled:
		refresh.tooltip_text = Loc.t("hire.need_credits", [
			Fmt.num(GameState.board.posting_cost(GameState.rank) - GameState.credits)])
	refresh.pressed.connect(func(): GameState.post_advert())
	add_child(refresh)


func _row(w: Worker) -> Control:
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.texture = PixelAssets.head_icon(w)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var lbl := Button.new()
	lbl.flat = true
	lbl.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.text = "%s · %s · %s · %s" % [
		Loc.rarity_name(w.rarity),
		Loc.class_name_of(w.class_id),
		Loc.species_name(w.species),
		Loc.t("crew.wage", [Fmt.num(w.wage)]),
	]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.pressed.connect(func(): _open_card(w.id))
	row.add_child(lbl)
	var btn := Button.new()
	var cost: float = GameState.board.hire_cost(w)
	btn.text = Loc.t("hire.hire", [Fmt.num(cost)])
	btn.set_meta("worker_id", w.id)
	var reason: String = GameState.hire_block_reason(w.id)
	btn.disabled = reason != ""
	btn.tooltip_text = reason
	btn.pressed.connect(func(): GameState.hire(w.id))
	row.add_child(btn)
	return row


func _open_card(worker_id: String) -> void:
	var sm = get_tree().root.find_child("ScreenManager", true, false)
	if sm != null and sm.has_method("open_candidate_card"):
		sm.open_candidate_card(worker_id)
