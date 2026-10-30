extends ScreenBase

## Terminal screen (spec §15.2 / v0.2). HUD, sector view, Rush, running shift,
## and seven bottom tabs including «Погрузка».

@onready var _credits: Label = $VBox/HUD/HBox/Credits
@onready var _parts: Label = $VBox/HUD/HBox/Parts
@onready var _rank: Label = $VBox/HUD/HBox/Rank
@onready var _shift_label: Label = $VBox/HUD/HBox/Shift
@onready var _rush_button: Button = $VBox/HUD/HBox/Rush
@onready var _report: Label = $VBox/ReportLine
@onready var _sectors: Control = $VBox/Center/SectorView
@onready var _hire_scroll: Control = $VBox/Center/HireScroll
@onready var _crew_scroll: Control = $VBox/Center/CrewScroll
@onready var _contracts_scroll: Control = $VBox/Center/ContractScroll
@onready var _menu_scroll: Control = $VBox/Center/MenuScroll
@onready var _world_scroll: Control = $VBox/Center/WorldScroll
@onready var _event_banner: Control = $EventBanner
@onready var _event_text: Label = $EventBanner/EBVBox/EBText
@onready var _event_choices: Control = $EventBanner/EBVBox/EBChoices
@onready var _action_bar: Control = $VBox/ActionBar
@onready var _action_dock: Button = $VBox/ActionBar/UpDock
@onready var _action_store: Button = $VBox/ActionBar/UpStorage
@onready var _action_expand: Button = $VBox/ActionBar/Expand

var _rank_bar: ProgressBar
var _loading_scroll: Control
var _current_tab: String = "terminal"
var _ui_root: Control
var _nav: HBoxContainer
var _hud: Control


func _ready() -> void:
	ThemeFonts.apply()  # no-op until fonts are placed in assets/fonts/
	_ensure_ui_root()
	_ensure_screen_manager()
	_ensure_rank_bar()
	_ensure_loading_tab()
	_rush_button.pressed.connect(_on_rush)
	GameState.stats_changed.connect(_refresh)
	GameState.shift_finished.connect(_on_shift_finished)
	GameState.tab_requested.connect(_show)
	_nav.get_node("TabTerminal").pressed.connect(func(): _show("terminal"))
	_nav.get_node("TabCrew").pressed.connect(func(): _show("crew"))
	_nav.get_node("TabHire").pressed.connect(func(): _show("hire"))
	_nav.get_node("TabContracts").pressed.connect(func(): _show("contracts"))
	_nav.get_node("TabMenu").pressed.connect(func(): _show("menu"))
	_nav.get_node("TabWorld").pressed.connect(func(): _show("world"))
	GameState.event_shown.connect(_on_event_shown)
	GameState.event_resolved.connect(_on_event_resolved)
	_action_dock.pressed.connect(func(): GameState.upgrade_sector(GameState.sector_of_type("dock")))
	_action_store.pressed.connect(func(): GameState.upgrade_sector(GameState.sector_of_type("storage")))
	_action_expand.pressed.connect(_on_expand)
	_rank.gui_input.connect(_on_rank_input)
	_rank.mouse_filter = Control.MOUSE_FILTER_STOP
	Loc.locale_changed.connect(func(_code: String): _retranslate(); _refresh())
	_retranslate()
	_show("terminal")
	_refresh()
	super._ready()


## TZ v0.3 step 4: Hud + NavBar under UiRoot; Content keeps middle chrome (1× look).
func _ensure_ui_root() -> void:
	if get_node_or_null("UiLayer") != null:
		_ui_root = $UiLayer/UiRoot
		_hud = _ui_root.get_node("Hud").get_child(0) as Control
		_nav = _ui_root.get_node("NavBar").get_child(0) as HBoxContainer
		return
	var vbox: VBoxContainer = $VBox
	_hud = vbox.get_node("HUD") as Control
	_nav = vbox.get_node("Nav") as HBoxContainer
	var layer := CanvasLayer.new()
	layer.name = "UiLayer"
	layer.layer = 10
	add_child(layer)
	var packed: PackedScene = load("res://src/ui/UiRoot.tscn") as PackedScene
	_ui_root = packed.instantiate() as Control
	layer.add_child(_ui_root)
	var content: Control = _ui_root.get_node("Content")
	var hud_slot: Control = _ui_root.get_node("Hud")
	var nav_slot: Control = _ui_root.get_node("NavBar")
	# Reparent HUD into Hud slot (full slot size).
	vbox.remove_child(_hud)
	hud_slot.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Reparent Nav into NavBar slot.
	vbox.remove_child(_nav)
	nav_slot.add_child(_nav)
	_nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Move remaining VBox into Content with chrome margins so 1× layout matches.
	remove_child(vbox)
	content.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_content_margins(vbox)
	# Overlays: EventBanner + Tutorial stay as Terminal children for now (step 6).
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func apply_scale(_s: int) -> void:
	if _ui_root == null:
		return
	var vbox: Control = _ui_root.get_node_or_null("Content/VBox") as Control
	if vbox:
		_apply_content_margins(vbox)


func _apply_content_margins(vbox: Control) -> void:
	var hud_h: float = float(UiScale.metric("hud_h"))
	var nav_h: float = float(UiScale.metric("nav_h"))
	vbox.offset_top = hud_h
	vbox.offset_bottom = -nav_h
	vbox.offset_left = 0.0
	vbox.offset_right = 0.0


func _ensure_screen_manager() -> void:
	if get_node_or_null("ScreenManager") != null:
		return
	var sm := CanvasLayer.new()
	sm.name = "ScreenManager"
	sm.layer = 20
	sm.set_script(load("res://src/ui/screen_manager.gd"))
	add_child(sm)


func _ensure_rank_bar() -> void:
	if _rank_bar != null:
		return
	_rank_bar = ProgressBar.new()
	_rank_bar.name = "RankBar"
	_rank_bar.custom_minimum_size = Vector2(48, 8)
	_rank_bar.max_value = 100.0
	_rank_bar.show_percentage = false
	_rank_bar.tooltip_text = ""
	var hbox: Node = _hud.get_node("HBox")
	var rank_idx: int = _rank.get_index()
	hbox.add_child(_rank_bar)
	hbox.move_child(_rank_bar, rank_idx + 1)


func _ensure_loading_tab() -> void:
	# Insert «Погрузка» tab button after Terminal if missing.
	if _nav.get_node_or_null("TabLoading") == null:
		var btn := Button.new()
		btn.name = "TabLoading"
		btn.text = Loc.t("nav.loading")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _show("loading"))
		_nav.add_child(btn)
		_nav.move_child(btn, 1)
	# Loading panel host.
	var center: Control = _ui_root.get_node("Content/VBox/Center")
	_loading_scroll = center.get_node_or_null("LoadingScroll")
	if _loading_scroll == null:
		_loading_scroll = ScrollContainer.new()
		_loading_scroll.name = "LoadingScroll"
		_loading_scroll.visible = false
		_loading_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.add_child(_loading_scroll)
		var panel_script: Script = load("res://src/ui/panels/loading_panel.gd")
		var panel := VBoxContainer.new()
		panel.name = "LoadingPanel"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if panel_script != null:
			panel.set_script(panel_script)
		_loading_scroll.add_child(panel)


func _retranslate() -> void:
	_nav.get_node("TabTerminal").text = Loc.t("nav.terminal")
	var tab_loading: Button = _nav.get_node_or_null("TabLoading")
	if tab_loading:
		tab_loading.text = Loc.t("nav.loading")
	_nav.get_node("TabCrew").text = Loc.t("nav.crew")
	_nav.get_node("TabHire").text = Loc.t("nav.hire")
	_nav.get_node("TabContracts").text = Loc.t("nav.contracts")
	_nav.get_node("TabWorld").text = Loc.t("nav.world")
	_nav.get_node("TabMenu").text = Loc.t("nav.menu")
	_rush_button.text = Loc.t("hud.rush")


func _show(which: String) -> void:
	_current_tab = which
	_sectors.visible = which == "terminal"
	if _loading_scroll:
		_loading_scroll.visible = which == "loading"
	_hire_scroll.visible = which == "hire"
	_crew_scroll.visible = which == "crew"
	_contracts_scroll.visible = which == "contracts"
	_menu_scroll.visible = which == "menu"
	_world_scroll.visible = which == "world"
	_action_bar.visible = which == "terminal"
	# Isolation: inactive tabs stay out of scroll (v0.2 §2.5).
	for child in _ui_root.get_node("Content/VBox/Center").get_children():
		if child is ScrollContainer or child == _sectors:
			continue


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = event.keycode
		var map := {
			KEY_1: "terminal", KEY_2: "loading", KEY_3: "crew", KEY_4: "hire",
			KEY_5: "contracts", KEY_6: "world", KEY_7: "menu",
		}
		if map.has(k):
			_show(map[k])
			get_viewport().set_input_as_handled()
		elif k == KEY_SPACE:
			_on_rush()
			get_viewport().set_input_as_handled()


func _on_event_shown() -> void:
	var e: Dictionary = GameState.event_active
	if e.is_empty():
		return
	_event_text.text = "Событие: %s" % String(e.get("key", ""))
	for c in _event_choices.get_children():
		c.queue_free()
	for ch in e.get("choices", []):
		var b := Button.new()
		b.text = String(ch.get("label_key", ch.get("id", "?")))
		var cid: String = String(ch["id"])
		b.pressed.connect(func(): GameState.event_choice(cid))
		_event_choices.add_child(b)
	_event_banner.visible = true


func _on_event_resolved() -> void:
	_event_banner.visible = false


func _refresh() -> void:
	_credits.text = "¢ " + Fmt.num(GameState.credits)
	_parts.text = "Зч " + Fmt.num(GameState.parts)
	var need: float = GameState.rep_needed(GameState.rank + 1)
	var cur: float = GameState.rep_needed(GameState.rank)
	var pct: int = int(100.0 * clampf((GameState.rep - cur) / maxf(need - cur, 1.0), 0.0, 1.0))
	_rank.text = Loc.t("hud.rank", [GameState.rank])
	if _rank_bar:
		_rank_bar.value = pct
		_rank_bar.tooltip_text = Loc.t("hud.rank_tip", [
			GameState.rank + 1, Fmt.num(GameState.rep - cur), Fmt.num(need - cur)])

	var shift: Shift = GameState.shift
	if shift != null:
		var remaining: float = maxf(0.0, shift.duration_s - shift.elapsed_s)
		_shift_label.text = Loc.t("hud.shift", [Fmt.time(remaining)])
		_rush_button.disabled = not shift.rush_available()
	else:
		_shift_label.text = Loc.t("hud.shift_none")
		_rush_button.disabled = true

	var dock: Sector = GameState.sector_of_type("dock")
	if dock != null:
		if dock.is_building():
			_action_dock.text = Loc.t("action.dock_busy", [dock.level, Fmt.time(dock.build_time_left)])
			_action_dock.disabled = true
		else:
			_action_dock.text = Loc.t("action.dock", [dock.level, Fmt.num(GameState.grid.upgrade_cost(dock))])
			_action_dock.disabled = not GameState.grid.can_upgrade(dock) \
				or GameState.credits < GameState.grid.upgrade_cost(dock)
	var store: Sector = GameState.sector_of_type("storage")
	if store != null:
		if store.is_building():
			_action_store.text = Loc.t("action.storage_busy", [store.level, Fmt.time(store.build_time_left)])
			_action_store.disabled = true
		else:
			_action_store.text = Loc.t("action.storage", [store.level, Fmt.num(GameState.grid.upgrade_cost(store))])
			_action_store.disabled = not GameState.grid.can_upgrade(store) \
				or GameState.credits < GameState.grid.upgrade_cost(store)
	_action_expand.text = Loc.t("action.expand", [Fmt.num(GameState.grid.expand_cost())])
	_action_expand.disabled = not GameState.can_expand()


func _on_rank_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _rank_bar:
			_rank.tooltip_text = _rank_bar.tooltip_text


func _on_rush() -> void:
	GameState.rush()


func _on_expand() -> void:
	var offers: Array = GameState.expand_offers()
	if offers.is_empty():
		return
	GameState.apply_expansion(offers[0])
	# Autofocus new sector if SectorView supports it.
	if _sectors.has_method("focus_sector") and GameState.grid.sectors.size() > 0:
		_sectors.focus_sector(GameState.grid.sectors.back())


func _on_shift_finished(report: Dictionary) -> void:
	_report.text = "Смена: %s · %s т · %s ¢" % [
		report["grade"], Fmt.num(report["tonnes"]), Fmt.num(report["credits"])]


func current_tab() -> String:
	return _current_tab
