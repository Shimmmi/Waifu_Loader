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
var _shift_bar: ProgressBar
var _more_btn: Button
var _hud_details: Control
var _fab_build: Button
var _build_panel: Control
var _nav_icons: Dictionary = {}
var _last_shift_line: String = ""


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
	Loc.locale_changed.connect(func(_code: String):
		_retranslate()
		_apply_hud_scale(UiScale.scale_factor)
		_apply_nav_scale(UiScale.scale_factor)
		_refresh()
	)
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
	var overlays: Control = _ui_root.get_node("Overlays")
	UiToast.bind_host(overlays)
	UiTooltip.bind_host(overlays)
	UiConfirm.bind_host(overlays)
	UiSelect.bind_host(overlays)
	_ensure_world_clip()
	# EventBanner + Tutorial stay as Terminal children for now.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## TZ §2.9 — WorldClip outside UiRoot; SectorView becomes its child.
func _ensure_world_clip() -> void:
	if get_node_or_null("World") != null:
		return
	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	var clip := Control.new()
	clip.name = "WorldClip"
	clip.set_script(load("res://src/ui/world_clip.gd"))
	world.add_child(clip)
	# Pull SectorView out of UI Content into the unscaled world clip.
	if _sectors.get_parent():
		_sectors.get_parent().remove_child(_sectors)
	clip.add_child(_sectors)
	_sectors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_world_clip()


func _update_world_clip() -> void:
	var clip: Control = get_node_or_null("World/WorldClip") as Control
	if clip == null:
		return
	var tab: String = _current_tab
	var show_world: bool = tab == "terminal" or tab == "loading"
	clip.visible = show_world
	_sectors.visible = tab == "terminal"
	if not show_world:
		return
	var id: String = "terminal" if tab == "terminal" else "line"
	var r: Rect2 = UiScale.world_rect(id)
	clip.position = r.position
	clip.size = r.size
	if tab == "terminal":
		_sectors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func apply_scale(_s: int) -> void:
	if _ui_root == null:
		return
	var vbox: Control = _ui_root.get_node_or_null("Content/VBox") as Control
	if vbox:
		_apply_content_margins(vbox)
	_apply_hud_scale(_s)
	_apply_nav_scale(_s)
	_apply_toolbar_scale(_s)
	_apply_event_banner_scale(_s)
	_update_world_clip()
	_refresh()
	# Fan-out to tab panels under Content (VBox panels implement apply_scale optionally).
	var center: Node = _ui_root.get_node_or_null("Content/VBox/Center")
	if center:
		for child in center.get_children():
			_fanout_apply_scale(child, _s)


func _apply_hud_scale(s: int) -> void:
	# S1: all; S2: parts stay; S3: parts→HudDetails + More + shift bar.
	_parts.visible = s != 3
	if _rank_bar:
		_rank_bar.visible = s == 1
		_rank_bar.custom_minimum_size = Vector2(48, float(UiScale.metric("bar_h")))
	_shift_label.visible = s != 3
	_rush_button.custom_minimum_size = Vector2(float(UiScale.metric("rush_btn_w")), float(UiScale.metric("btn_h")))
	if s == 3:
		_rush_button.text = "⚡"
	else:
		_rush_button.text = Loc.t("hud.rush")
	if _shift_bar == null:
		_shift_bar = ProgressBar.new()
		_shift_bar.name = "ShiftBar"
		_shift_bar.show_percentage = false
		_shift_bar.max_value = 100.0
		_shift_bar.custom_minimum_size = Vector2(0, 1)
		_shift_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_shift_bar.offset_top = -1
		_hud.add_child(_shift_bar)
	_shift_bar.visible = s == 3
	if _more_btn == null:
		_more_btn = Button.new()
		_more_btn.name = "HudMore"
		_more_btn.custom_minimum_size = Vector2(12, 12)
		_more_btn.pressed.connect(_open_hud_details)
		_hud.get_node("HBox").add_child(_more_btn)
	_more_btn.visible = s == 3
	_more_btn.text = "…"
	_more_btn.custom_minimum_size = Vector2(12, 12)
	_more_btn.clip_text = true
	UiTooltip.attach(_more_btn, Loc.t("HUD_MORE"))
	# S2: tap rank opens details (S3 uses More).
	if s == 2:
		if not _rank.gui_input.is_connected(_on_rank_open_details):
			_rank.gui_input.connect(_on_rank_open_details)
	elif _rank.gui_input.is_connected(_on_rank_open_details):
		_rank.gui_input.disconnect(_on_rank_open_details)


func _on_rank_open_details(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_hud_details()


func _open_hud_details() -> void:
	if _hud_details == null:
		var packed: PackedScene = load("res://src/ui/overlays/HudDetails.tscn") as PackedScene
		_hud_details = packed.instantiate()
	var overlays: Control = _ui_root.get_node("Overlays")
	if _hud_details.has_method("bind_and_show"):
		_hud_details.call("bind_and_show", overlays, _last_shift_line)


func _apply_nav_scale(s: int) -> void:
	var ids: Array = ["terminal", "loading", "crew", "hire", "contracts", "world", "menu"]
	var nodes: Dictionary = {
		"terminal": "TabTerminal", "loading": "TabLoading", "crew": "TabCrew",
		"hire": "TabHire", "contracts": "TabContracts", "world": "TabWorld", "menu": "TabMenu",
	}
	var logical_w: float = UiScale.logical_size().x
	var n_tabs: int = 0
	for id in ids:
		if _nav.get_node_or_null(String(nodes[id])) != null:
			n_tabs += 1
	if s >= 2:
		_nav.add_theme_constant_override("separation", 0)
	else:
		_nav.remove_theme_constant_override("separation")
	var tab_w: float = floor(logical_w / float(maxi(n_tabs, 1)))
	for id in ids:
		var btn: Button = _nav.get_node_or_null(String(nodes[id])) as Button
		if btn == null:
			continue
		var active: bool = String(id) == _current_tab
		if s == 1:
			btn.text = _nav_full_label(String(id))
			if _nav_icons.has(id):
				(_nav_icons[id] as CanvasItem).visible = false
			btn.custom_minimum_size = Vector2(0, float(UiScale.metric("nav_h")))
			btn.remove_theme_stylebox_override("normal")
		else:
			btn.text = ""
			btn.custom_minimum_size = Vector2(tab_w, float(UiScale.metric("nav_h")))
			if not _nav_icons.has(id):
				var icon := Control.new()
				icon.set_script(load("res://src/ui/widgets/nav_icon.gd"))
				if icon.has_method("setup"):
					icon.call("setup", id)
				btn.add_child(icon)
				icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
				_nav_icons[id] = icon
			(_nav_icons[id] as CanvasItem).visible = true
			if active:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(0.25, 0.35, 0.45, 1.0)
				sb.border_color = Color(0.85, 0.75, 0.35, 1.0)
				sb.set_border_width_all(1)
				btn.add_theme_stylebox_override("normal", sb)
			else:
				btn.remove_theme_stylebox_override("normal")


func _nav_full_label(id: String) -> String:
	match id:
		"terminal": return Loc.t("nav.terminal")
		"loading": return Loc.t("nav.loading")
		"crew": return Loc.t("nav.crew")
		"hire": return Loc.t("nav.hire")
		"contracts": return Loc.t("nav.contracts")
		"world": return Loc.t("nav.world")
		"menu": return Loc.t("nav.menu")
	return id


func _apply_toolbar_scale(s: int) -> void:
	# S1/S2: action bar on terminal; S3: FabBuild + BuildPanel.
	var on_term: bool = _current_tab == "terminal"
	if s == 3:
		_action_bar.visible = false
		_report.visible = false
		if _fab_build == null:
			_fab_build = Button.new()
			_fab_build.set_script(load("res://src/ui/widgets/fab_build.gd"))
			_fab_build.pressed.connect(_open_build_panel)
			_ui_root.get_node("Overlays").add_child(_fab_build)
		_fab_build.visible = on_term
		var pad: float = float(UiScale.metric("pad"))
		var wr: Rect2 = UiScale.to_logical(UiScale.world_rect("terminal"))
		_fab_build.position = Vector2(wr.position.x + pad, wr.position.y + pad)
		_fab_build.custom_minimum_size = Vector2(12, 12)
	else:
		_action_bar.visible = on_term
		_report.visible = s == 1 and on_term
		if _fab_build:
			_fab_build.visible = false
		if _build_panel:
			_build_panel.visible = false


func _apply_event_banner_scale(s: int) -> void:
	if _event_banner == null:
		return
	var margin: float = float(UiScale.metric("panel_margin"))
	if s >= 2:
		var lw: float = UiScale.logical_size().x
		_event_banner.custom_minimum_size.x = lw - 2.0 * margin
		_event_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		for c in _event_choices.get_children():
			if c is Button:
				(c as Button).custom_minimum_size.y = float(UiScale.metric("btn_h"))
				(c as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _open_build_panel() -> void:
	if _build_panel == null:
		var packed: PackedScene = load("res://src/ui/overlays/BuildPanel.tscn") as PackedScene
		_build_panel = packed.instantiate()
		_ui_root.get_node("Overlays").add_child(_build_panel)
		if _build_panel.has_method("bind_actions"):
			_build_panel.call("bind_actions",
				func(): GameState.upgrade_sector(GameState.sector_of_type("dock")),
				func(): GameState.upgrade_sector(GameState.sector_of_type("storage")),
				_on_expand)
	if _build_panel.has_method("refresh"):
		_build_panel.call("refresh")
	_build_panel.visible = true


func _fanout_apply_scale(n: Node, s: int) -> void:
	# Only UI panel scripts under src/ui (avoid view nodes with different apply_scale).
	var scr: Script = n.get_script()
	if scr != null and n is Control and n.has_method("apply_scale"):
		var path: String = scr.resource_path
		if path.begins_with("res://src/ui/"):
			n.call("apply_scale", s)
	for c in n.get_children():
		_fanout_apply_scale(c, s)


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
	var s: int = UiScale.scale_factor
	if s == 1:
		_nav.get_node("TabTerminal").text = Loc.t("nav.terminal")
		var tab_loading: Button = _nav.get_node_or_null("TabLoading")
		if tab_loading:
			tab_loading.text = Loc.t("nav.loading")
		_nav.get_node("TabCrew").text = Loc.t("nav.crew")
		_nav.get_node("TabHire").text = Loc.t("nav.hire")
		_nav.get_node("TabContracts").text = Loc.t("nav.contracts")
		_nav.get_node("TabWorld").text = Loc.t("nav.world")
		_nav.get_node("TabMenu").text = Loc.t("nav.menu")
	if s != 3:
		_rush_button.text = Loc.t("hud.rush")
	else:
		_rush_button.text = "⚡"
	if _more_btn:
		_more_btn.text = "…"
		UiTooltip.attach(_more_btn, Loc.t("HUD_MORE"))


func _show(which: String) -> void:
	_current_tab = which
	if _loading_scroll:
		_loading_scroll.visible = which == "loading"
	_hire_scroll.visible = which == "hire"
	_crew_scroll.visible = which == "crew"
	_contracts_scroll.visible = which == "contracts"
	_menu_scroll.visible = which == "menu"
	_world_scroll.visible = which == "world"
	_apply_toolbar_scale(UiScale.scale_factor)
	_apply_nav_scale(UiScale.scale_factor)
	_update_world_clip()
	if UiScale.scale_factor >= 2:
		UiToast.show_text(_nav_full_label(which), 1.2)


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
	_rank.text = Loc.tr_s("hud.rank", [GameState.rank])
	if _rank_bar:
		_rank_bar.value = pct
		var tip: String = Loc.t("hud.rank_tip", [
			GameState.rank + 1, Fmt.num(GameState.rep - cur), Fmt.num(need - cur)])
		_rank_bar.set_meta("ui_tooltip", tip)
		_rank.set_meta("ui_tooltip", tip)
		if not _rank_bar.has_meta("ui_tip_bound"):
			UiTooltip.attach(_rank_bar, tip)
			UiTooltip.attach(_rank, tip)
			_rank_bar.set_meta("ui_tip_bound", true)

	var shift: Shift = GameState.shift
	if shift != null:
		var remaining: float = maxf(0.0, shift.duration_s - shift.elapsed_s)
		_shift_label.text = Loc.tr_s("hud.shift", [Fmt.time(remaining)])
		_rush_button.disabled = not shift.rush_available()
		if _shift_bar:
			_shift_bar.value = 100.0 * (1.0 - remaining / maxf(shift.duration_s, 0.001))
	else:
		_shift_label.text = Loc.t("hud.shift_none")
		_rush_button.disabled = true
		if _shift_bar:
			_shift_bar.value = 0.0

	var s: int = UiScale.scale_factor
	var dock: Sector = GameState.sector_of_type("dock")
	if dock != null:
		if dock.is_building():
			_action_dock.text = Loc.t("action.dock_busy", [dock.level, Fmt.time(dock.build_time_left)])
			_action_dock.disabled = true
		elif s == 2:
			_action_dock.text = Loc.t("TB_DOCK_S2", [Fmt.num(GameState.grid.upgrade_cost(dock))])
			_action_dock.disabled = not GameState.grid.can_upgrade(dock) \
				or GameState.credits < GameState.grid.upgrade_cost(dock)
		else:
			_action_dock.text = Loc.t("action.dock", [dock.level, Fmt.num(GameState.grid.upgrade_cost(dock))])
			_action_dock.disabled = not GameState.grid.can_upgrade(dock) \
				or GameState.credits < GameState.grid.upgrade_cost(dock)
	var store: Sector = GameState.sector_of_type("storage")
	if store != null:
		if store.is_building():
			_action_store.text = Loc.t("action.storage_busy", [store.level, Fmt.time(store.build_time_left)])
			_action_store.disabled = true
		elif s == 2:
			_action_store.text = Loc.t("TB_STORAGE_S2", [Fmt.num(GameState.grid.upgrade_cost(store))])
			_action_store.disabled = not GameState.grid.can_upgrade(store) \
				or GameState.credits < GameState.grid.upgrade_cost(store)
		else:
			_action_store.text = Loc.t("action.storage", [store.level, Fmt.num(GameState.grid.upgrade_cost(store))])
			_action_store.disabled = not GameState.grid.can_upgrade(store) \
				or GameState.credits < GameState.grid.upgrade_cost(store)
	if s == 2:
		_action_expand.text = Loc.t("TB_EXPAND_S2", [Fmt.num(GameState.grid.expand_cost())])
	else:
		_action_expand.text = Loc.t("action.expand", [Fmt.num(GameState.grid.expand_cost())])
	_action_expand.disabled = not GameState.can_expand()
	if _build_panel and _build_panel.visible and _build_panel.has_method("refresh"):
		_build_panel.call("refresh")


func _on_rank_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pass  # tip via UiTooltip; S2 opens HudDetails via _on_rank_open_details


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
	_last_shift_line = "Смена: %s · %s т · %s ¢" % [
		report["grade"], Fmt.num(report["tonnes"]), Fmt.num(report["credits"])]
	_report.text = _last_shift_line


func current_tab() -> String:
	return _current_tab
