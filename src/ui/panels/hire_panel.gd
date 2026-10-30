extends VBoxContainer

## Job exchange screen (spec §15.4 / v0.2 §2.7, §3.6). Scale-adapted (TZ §2.8).


func _ready() -> void:
	visibility_changed.connect(_maybe_rebuild)
	GameState.board_changed.connect(_rebuild)
	GameState.stats_changed.connect(_refresh_affordability)
	Loc.locale_changed.connect(func(_c: String): _rebuild())
	_rebuild()


func apply_scale(_s: int) -> void:
	_rebuild()


func _maybe_rebuild() -> void:
	if visible:
		_rebuild()


func _refresh_affordability() -> void:
	if not visible:
		return
	for row in get_children():
		if row is HBoxContainer and row.has_meta("hire_btn"):
			var btn: Button = row.get_meta("hire_btn")
			var worker_id: String = String(btn.get_meta("worker_id", ""))
			if worker_id != "":
				var reason: String = GameState.hire_block_reason(worker_id)
				btn.disabled = reason != ""
				btn.set_meta("ui_tooltip", reason)
				UiTooltip.attach(btn, reason if reason != "" else Loc.t("hire.hire", [""]))


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var s: int = UiScale.scale_factor
	if s != 3:
		var title := Label.new()
		title.text = Loc.tr_s("hire.title", [GameState.board.pool.size()])
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(title)

	for w in GameState.board.pool:
		add_child(_row(w, s))

	var refresh := Button.new()
	refresh.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	refresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if s == 3:
		refresh.text = Loc.t("HIRE_AD_S3", [Fmt.num(GameState.board.posting_cost(GameState.rank))])
	else:
		refresh.text = Loc.tr_s("hire.post", [Fmt.num(GameState.board.posting_cost(GameState.rank))])
	refresh.disabled = GameState.credits < GameState.board.posting_cost(GameState.rank)
	if refresh.disabled:
		var need: String = Loc.t("hire.need_credits", [
			Fmt.num(GameState.board.posting_cost(GameState.rank) - GameState.credits)])
		UiTooltip.attach(refresh, need)
	refresh.pressed.connect(func(): GameState.post_advert())
	add_child(refresh)


func _row(w: Worker, s: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiScale.metric("gap"))
	row.custom_minimum_size.y = float(UiScale.metric("row_h"))
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.texture = PixelAssets.head_icon(w)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	if s >= 2:
		var cls := Label.new()
		cls.text = Loc.class_name_of(w.class_id).substr(0, 2)
		cls.custom_minimum_size = Vector2(16, 0)
		row.add_child(cls)
		var price := Button.new()
		price.flat = true
		price.alignment = HORIZONTAL_ALIGNMENT_LEFT
		price.text = "%s¢" % Fmt.num(GameState.board.hire_cost(w))
		price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		price.modulate = PixelAssets.rarity_color(w.rarity)
		price.pressed.connect(func(): _open_card(w.id))
		row.add_child(price)
	else:
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
		if reason != "":
			UiTooltip.attach(btn, reason)
		btn.pressed.connect(func(): GameState.hire(w.id))
		row.add_child(btn)
		row.set_meta("hire_btn", btn)
	return row


func _open_card(worker_id: String) -> void:
	var sm = get_tree().root.find_child("ScreenManager", true, false)
	if sm != null and sm.has_method("open_candidate_card"):
		sm.open_candidate_card(worker_id)
