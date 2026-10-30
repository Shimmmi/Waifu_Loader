extends VBoxContainer

## Menu tab (M6): Orbital Elevator progress, tokens/shares, achievements,
## the corporate tree (buy nodes with shares) and the Reorganisation button.

var _header: Label
var _elev: Label
var _ach: Label
var _tree_box: VBoxContainer
var _reorg: Button
var _lang_btn: Button
var _mute_btn: Button
var _stats_btn: Button
var _net_btn: Button
var _privacy_lbl: Label
var _help_lbl: Label
var _directive_rows: Array = []
var _shop_rows: Array = []
var _shop_index: Dictionary = {}


func _ready() -> void:
	_header = Label.new()
	_elev = Label.new()
	_ach = Label.new()
	add_child(_header)
	add_child(_elev)
	add_child(_ach)

	var settings_title := Label.new()
	settings_title.set_meta("loc", "menu.settings")
	add_child(settings_title)
	var lang_row := HBoxContainer.new()
	var lang_lbl := Label.new()
	lang_lbl.set_meta("loc", "menu.language")
	lang_row.add_child(lang_lbl)
	_lang_btn = Button.new()
	_lang_btn.pressed.connect(_on_lang)
	lang_row.add_child(_lang_btn)
	add_child(lang_row)
	_mute_btn = Button.new()
	_mute_btn.pressed.connect(_on_mute)
	add_child(_mute_btn)
	_stats_btn = Button.new()
	_stats_btn.pressed.connect(_on_stats)
	add_child(_stats_btn)
	_net_btn = Button.new()
	_net_btn.pressed.connect(_on_net)
	add_child(_net_btn)

	# --- Directives ---
	var dir_title := Label.new()
	dir_title.set_meta("loc", "menu.directives")
	add_child(dir_title)
	for e in GameState.directives_board.active:
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		btn.set_meta("loc", "menu.claim")
		var did: String = String(e["id"])
		btn.pressed.connect(func(): _on_claim(did))
		row.add_child(lbl)
		row.add_child(btn)
		row.set_meta("id", did)
		row.set_meta("label", lbl)
		row.set_meta("button", btn)
		add_child(row)
		_directive_rows.append(row)

	# --- Cosmetics shop ---
	var shop_title := Label.new()
	shop_title.set_meta("loc", "menu.shop")
	add_child(shop_title)
	for cat in GameState.shop.category_names():
		var srow := HBoxContainer.new()
		var pick := Button.new()
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func(): _cycle_shop(String(cat)))
		var buy := Button.new()
		buy.set_meta("loc", "menu.buy")
		buy.pressed.connect(func(): _buy(String(cat)))
		var eq := Button.new()
		eq.set_meta("loc", "menu.equip")
		eq.pressed.connect(func(): _equip(String(cat)))
		srow.add_child(pick)
		srow.add_child(buy)
		srow.add_child(eq)
		srow.set_meta("cat", String(cat))
		srow.set_meta("pick", pick)
		srow.set_meta("buy", buy)
		srow.set_meta("equip", eq)
		add_child(srow)
		_shop_rows.append(srow)
		_shop_index[String(cat)] = 0

	_help_lbl = Label.new()
	_help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_help_lbl)
	_privacy_lbl = Label.new()
	_privacy_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_privacy_lbl)

	var tree_title := Label.new()
	tree_title.set_meta("loc", "menu.tree")
	add_child(tree_title)
	_tree_box = VBoxContainer.new()
	add_child(_tree_box)

	_reorg = Button.new()
	_reorg.pressed.connect(_on_reorg)
	add_child(_reorg)

	var motion_btn := Button.new()
	motion_btn.name = "ReduceMotion"
	motion_btn.pressed.connect(_toggle_reduce_motion)
	add_child(motion_btn)
	var gal_btn := Button.new()
	gal_btn.text = "Галерея"
	gal_btn.pressed.connect(_open_gallery)
	add_child(gal_btn)

	_build_tree()
	Loc.locale_changed.connect(func(_c: String): _retranslate())
	GameState.stats_changed.connect(_refresh)
	_retranslate()
	_refresh()


func _retranslate() -> void:
	for child in get_children():
		if (child is Label or child is Button) and child.has_meta("loc"):
			child.text = Loc.t(String(child.get_meta("loc")))
	_lang_btn.text = Loc.code.to_upper()
	_mute_btn.text = Loc.t("menu.mute", [Loc.t("menu.on") if not GameState.muted else Loc.t("menu.off")])
	_stats_btn.text = Loc.t("menu.stats", [Loc.t("menu.on") if GameState.anon_stats else Loc.t("menu.off")])
	_net_btn.text = Loc.t("menu.net", [Loc.t("menu.online") if GameState.online else Loc.t("menu.offline")])
	_privacy_lbl.text = Loc.t("privacy.text")
	_help_lbl.text = Loc.t("help.text")
	var mb: Button = get_node_or_null("ReduceMotion")
	if mb:
		var on: bool = bool(SaveSystem.settings().get("reduce_motion", false))
		mb.text = Loc.t("settings.reduce_motion", [Loc.t("menu.on") if on else Loc.t("menu.off")])
	_refresh()


func _build_tree() -> void:
	for row in GameState.tree.data.get("nodes", []):
		var id: String = String(row["id"])
		var hb := HBoxContainer.new()
		var lbl := Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var btn := Button.new()
		btn.text = "Купить"
		btn.pressed.connect(func(): _on_buy(id))
		hb.add_child(lbl)
		hb.add_child(btn)
		hb.set_meta("id", id)
		hb.set_meta("label", lbl)
		hb.set_meta("button", btn)
		_tree_box.add_child(hb)


func _refresh() -> void:
	_header.text = Loc.t("menu.shares", [GameState.shares, Fmt.num(GameState.tokens)])
	var done: int = GameState.elevator_milestones_done()
	var nxt: Dictionary = GameState.elevator_next()
	if nxt.is_empty():
		_elev.text = Loc.t("menu.elevator_done", [done])
	else:
		_elev.text = Loc.t("menu.elevator", [
			done, Fmt.num(float(nxt["tonnes"])), int(GameState.elevator_progress() * 100.0)])
	_ach.text = Loc.t("menu.achievements", [GameState.achievements_done.size(), GameState.ach.total()])

	for hb in _tree_box.get_children():
		var id: String = String(hb.get_meta("id"))
		var lbl: Label = hb.get_meta("label")
		var btn: Button = hb.get_meta("button")
		var lvl: int = int(GameState.tree_levels.get(id, 0))
		var mx: int = GameState.tree.max_level(id)
		var row: Dictionary = GameState.tree.node(id)
		var node_name: String = Loc.t(String(row.get("key", id)))
		if lvl >= mx:
			lbl.text = "%s L%d/%d (%s)" % [node_name, lvl, mx, Loc.t("menu.max")]
			btn.disabled = true
			btn.text = "—"
		else:
			var c: int = GameState.tree.cost(id, lvl)
			lbl.text = "%s L%d/%d · %d Ш" % [node_name, lvl, mx, c]
			btn.disabled = GameState.shares < c
			btn.text = Loc.t("menu.buy")

	_reorg.disabled = not GameState.can_reorg()
	_reorg.text = Loc.t("menu.reorg", [GameState.reorg_preview()])

	for row in _directive_rows:
		var did: String = String(row.get_meta("id"))
		var e: Dictionary = GameState.directives_board.entry(did)
		var goal: Dictionary = e.get("goal", {})
		var dlbl: Label = row.get_meta("label")
		var dbtn: Button = row.get_meta("button")
		dlbl.text = "%s %d/%d" % [
			Loc.t(String(e.get("key", did))),
			int(GameState.directives_board.value(did)),
			int(goal.get("value", 0)),
		]
		dbtn.text = Loc.t("menu.claim")
		dbtn.disabled = GameState.directives_board.is_claimed(did) or not GameState.directives_board.is_complete(did)

	for row in _shop_rows:
		var cat: String = String(row.get_meta("cat"))
		var items: Array = GameState.shop.items(cat)
		if items.is_empty():
			continue
		var it: Dictionary = items[int(_shop_index.get(cat, 0))]
		var iid: String = String(it["id"])
		var owned: bool = GameState.cosmetics_owned.has(iid)
		var pick: Button = row.get_meta("pick")
		var buy: Button = row.get_meta("buy")
		var eq: Button = row.get_meta("equip")
		pick.text = Loc.t("menu.item", [Loc.t(GameState.shop.key_of(cat, iid)), GameState.shop.price(cat, iid)])
		if owned:
			pick.text += " · " + Loc.t("menu.owned")
		buy.text = Loc.t("menu.buy")
		eq.text = Loc.t("menu.equip")
		buy.disabled = GameState.shop.cost_if_buyable(cat, iid, GameState.cosmetics_owned, GameState.tokens) < 0
		eq.disabled = not owned


func _on_buy(id: String) -> void:
	GameState.buy_tree_node(id)


func _on_reorg() -> void:
	GameState.do_reorg()


func _on_claim(id: String) -> void:
	GameState.claim_directive(id)
	_refresh()


func _cycle_shop(cat: String) -> void:
	var n: int = GameState.shop.items(cat).size()
	if n == 0:
		return
	_shop_index[cat] = (int(_shop_index.get(cat, 0)) + 1) % n
	_refresh()


func _buy(cat: String) -> void:
	var items: Array = GameState.shop.items(cat)
	if items.is_empty():
		return
	var it: Dictionary = items[int(_shop_index.get(cat, 0))]
	var cost: int = GameState.shop.cost_if_buyable(cat, String(it["id"]), GameState.cosmetics_owned, GameState.tokens)
	if cost >= 0:
		GameState.tokens -= float(cost)
		GameState.cosmetics_owned.append(String(it["id"]))
		GameState.stats_changed.emit()


func _equip(cat: String) -> void:
	var items: Array = GameState.shop.items(cat)
	if items.is_empty():
		return
	var it: Dictionary = items[int(_shop_index.get(cat, 0))]
	GameState.shop.equip(cat, String(it["id"]), GameState.cosmetics_equipped, GameState.cosmetics_owned)
	GameState.stats_changed.emit()


func _on_lang() -> void:
	Loc.set_locale("en" if Loc.code == "ru" else "ru")
	GameState.locale = Loc.code
	GameState.save_settings()


func _on_mute() -> void:
	GameState.muted = not GameState.muted
	GameState.save_settings()
	_retranslate()


func _on_stats() -> void:
	GameState.anon_stats = not GameState.anon_stats
	GameState.save_settings()
	_retranslate()


func _on_net() -> void:
	GameState.set_online(not GameState.online)
	_retranslate()

func _toggle_reduce_motion() -> void:
	var on: bool = not bool(SaveSystem.settings().get("reduce_motion", false))
	SaveSystem.set_setting("reduce_motion", on)
	SaveSystem.store()
	_retranslate()


func _open_gallery() -> void:
	var existing := get_node_or_null("GalleryPanel")
	if existing:
		existing.queue_free()
		return
	var g := VBoxContainer.new()
	g.name = "GalleryPanel"
	g.set_script(load("res://src/ui/panels/gallery_panel.gd"))
	add_child(g)
