extends VBoxContainer

## World tab (M8): leaderboards, the Orbital-Elevator build, Daily Shift, Cup
## duels and social actions. Talks to the backend through Net (mock offline).

var _global_lbl: Label
var _boards_lbl: Label
var _daily_lbl: Label
var _cup_lbl: Label
var _social_lbl: Label
var _board_list_lbl: Label
var _replay_lbl: Label
var _tactic_btn: Button
var _daily_slots: Array = []
var _daily_assign: Array = [-1, -1, -1, -1, -1, -1]
var _daily_seed: int = 0
var _cup_slots: Array = []
var _cup_assign: Array = ["", "", ""]
var _cup_tactic: int = 0
var _opponent_buttons: Array = []
var _opponent_ids: Array = []
var _opponent_index: int = 0
var _replay: Array = []
var _replay_step: int = 0
var _replay_timer: Timer
var _board_btn: Button
var _entries_lbl: Label
var _friend_edit: LineEdit
var _donate_btn: Button
var _board_index: int = 0
var _fetch_timer: Timer
var _opponents_box: VBoxContainer
var _section_idx: int = 0
var _pager: HBoxContainer
var _section_hosts: Array = []
const BOARD_IDS: Array[String] = ["tonnes_weekly", "tonnes_alltime", "best_tpm_weekly", "gold_weekly", "reorg_alltime"]
const CUP_STATIONS: Array[String] = ["unload", "move", "store"]
const SECTION_KEYS: Array[String] = ["world.build", "world.board", "world.assign", "world.brigade", "world.opponents"]


func _ready() -> void:
	var title := Label.new()
	title.set_meta("loc", "world.title")
	add_child(title)

	_global_lbl = Label.new()
	add_child(_global_lbl)
	_boards_lbl = Label.new()
	add_child(_boards_lbl)
	_board_list_lbl = Label.new()
	add_child(_board_list_lbl)
	var brow := HBoxContainer.new()
	_board_btn = Button.new()
	_board_btn.pressed.connect(_cycle_board)
	brow.add_child(_board_btn)
	_entries_lbl = Label.new()
	brow.add_child(_entries_lbl)
	add_child(brow)

	# --- Daily assignment strip (6 slots over 8 temp employees) ---
	var assign_title := Label.new()
	assign_title.set_meta("loc", "world.assign")
	add_child(assign_title)
	_daily_seed = int(Time.get_unix_time_from_system() / 86400.0)
	for i in DailyShift.SLOT_COUNT:
		var sb := Button.new()
		sb.pressed.connect(func(): _cycle_daily(i))
		_daily_slots.append(sb)
		add_child(sb)
	var run_btn := Button.new()
	run_btn.set_meta("loc", "world.run")
	run_btn.pressed.connect(_on_daily)
	add_child(run_btn)
	_daily_lbl = Label.new()
	add_child(_daily_lbl)

	# --- Cup brigade + tactic + replay ---
	var brig_title := Label.new()
	brig_title.set_meta("loc", "world.brigade")
	add_child(brig_title)
	for i in 3:
		var cb := Button.new()
		cb.pressed.connect(func(): _cycle_cup(i))
		_cup_slots.append(cb)
		add_child(cb)
	_tactic_btn = Button.new()
	_tactic_btn.pressed.connect(_cycle_tactic)
	add_child(_tactic_btn)
	var fight_btn := Button.new()
	fight_btn.set_meta("loc", "world.fight")
	fight_btn.pressed.connect(_on_fight)
	add_child(fight_btn)
	_replay_lbl = Label.new()
	add_child(_replay_lbl)
	_cup_lbl = Label.new()
	add_child(_cup_lbl)

	# --- Cup opponents ---
	var opp_title := Label.new()
	opp_title.set_meta("loc", "world.opponents")
	add_child(opp_title)
	_opponents_box = VBoxContainer.new()
	add_child(_opponents_box)
	_build_opponents()

	_replay_timer = Timer.new()
	_replay_timer.wait_time = 0.35
	_replay_timer.timeout.connect(_on_replay_tick)
	add_child(_replay_timer)

	var ubtn := Button.new()
	ubtn.set_meta("loc", "world.union_btn")
	ubtn.pressed.connect(_on_union)
	add_child(ubtn)
	var fbtn := Button.new()
	fbtn.set_meta("loc", "world.friends_btn")
	fbtn.pressed.connect(_on_friends)
	add_child(fbtn)
	_social_lbl = Label.new()
	add_child(_social_lbl)

	var frow := HBoxContainer.new()
	var flbl := Label.new()
	flbl.set_meta("loc", "world.friend_code")
	frow.add_child(flbl)
	_friend_edit = LineEdit.new()
	_friend_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(_friend_edit)
	var req := Button.new()
	req.set_meta("loc", "world.request")
	req.pressed.connect(_on_request)
	frow.add_child(req)
	add_child(frow)
	_donate_btn = Button.new()
	_donate_btn.set_meta("loc", "world.union_donate")
	_donate_btn.pressed.connect(_on_donate)
	add_child(_donate_btn)

	Loc.locale_changed.connect(func(_c: String): _retranslate())
	# Online: responses arrive asynchronously; re-render when they do. Display
	# reads use Net.cached (no fetch), so this cannot loop.
	Net.response_received.connect(func(p: String, _c: int, _b: Dictionary) -> void:
		if p == "auth/guest":
			_fetch()  # now authorised: retry the authed reads
		_refresh())
	_fetch_timer = Timer.new()
	_fetch_timer.wait_time = 30.0
	_fetch_timer.autostart = true
	_fetch_timer.timeout.connect(_fetch)
	add_child(_fetch_timer)
	_fetch()
	_retranslate()
	_refresh()
	_ensure_pager()


func apply_scale(s: int) -> void:
	_ensure_pager()
	if _pager:
		_pager.visible = s >= 2
	_apply_section_visibility()
	_global_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boards_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_daily_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cup_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_social_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board_btn.custom_minimum_size.y = float(UiScale.metric("btn_h"))
	# Board cycle already uses a button (not OptionButton) — S2/S3: ◀ ▶ label.
	if s >= 2:
		_board_btn.text = "◀ %s ▶" % Loc.board_name(BOARD_IDS[_board_index])


func _ensure_pager() -> void:
	if _pager != null:
		return
	_pager = HBoxContainer.new()
	_pager.name = "SectionPager"
	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(float(UiScale.metric("btn_h")), float(UiScale.metric("btn_h")))
	prev.pressed.connect(func():
		_section_idx = (_section_idx - 1 + SECTION_KEYS.size()) % SECTION_KEYS.size()
		_apply_section_visibility()
	)
	var title := Label.new()
	title.name = "PagerTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(float(UiScale.metric("btn_h")), float(UiScale.metric("btn_h")))
	next.pressed.connect(func():
		_section_idx = (_section_idx + 1) % SECTION_KEYS.size()
		_apply_section_visibility()
	)
	_pager.add_child(prev)
	_pager.add_child(title)
	_pager.add_child(next)
	add_child(_pager)
	move_child(_pager, 0)
	_pager.visible = false


func _apply_section_visibility() -> void:
	# On S1 show all; on S2/S3 keep layout intact but mark pager title (D5 block stays).
	if _pager == null:
		return
	var title: Label = _pager.get_node_or_null("PagerTitle") as Label
	if title:
		var key: String = SECTION_KEYS[_section_idx]
		title.text = Loc.t(key) if key != "world.build" else Loc.t("world.title")
	if UiScale.scale_factor < 2:
		return


## Kick off background GETs for every path this panel shows.
func _fetch() -> void:
	for p in ["global", "boards/" + BOARD_IDS[_board_index], "boards/tonnes_weekly/me", "daily", "pvp/me", "friends"]:
		Net.api_get(p)
	Net.post_cached("pvp/opponents", {})


## Static (keyed) labels: labels/buttons that carry a "loc" meta key.
func _retranslate() -> void:
	for child in get_children():
		if (child is Label or child is Button) and child.has_meta("loc"):
			child.text = Loc.t(String(child.get_meta("loc")))
	_tactic_btn.text = Loc.t("world.tactic", [Loc.t("tactic." + Tactics.ALL[_cup_tactic])])
	_refresh_slots()


## Slot button labels (daily employee assignment, Cup brigade).
func _refresh_slots() -> void:
	var emps: Array = DailyShift.preset(_daily_seed)["employees"]
	for i in _daily_slots.size():
		var idx: int = int(_daily_assign[i])
		var who: String = Loc.t("world.none")
		if idx >= 0 and idx < emps.size():
			var e: Dictionary = emps[idx]
			who = "%s %d" % [String(e["class_id"]), int(e["si"])]
		(_daily_slots[i] as Button).text = Loc.t("world.slot", [i + 1, who])
	for i in _cup_slots.size():
		var wid: String = String(_cup_assign[i])
		var who: String = Loc.t("world.none")
		if wid != "":
			var w: Worker = GameState.worker_by_id(wid)
			if w != null:
				who = w.display_name()
		(_cup_slots[i] as Button).text = "%s: %s" % [CUP_STATIONS[i], who]


func _refresh() -> void:
	var g: Dictionary = Net.cached("global")
	var goal: float = maxf(float(g.get("goal", 1.0)), 1.0)
	_global_lbl.text = Loc.t("world.build", [
		int(g.get("stage", 1)), int(g.get("stages", 10)),
		int(100.0 * float(g.get("progress", 0.0)) / goal),
	])
	var me: Dictionary = Net.cached("boards/tonnes_weekly/me")
	var rank: String = Loc.t("world.none") if me.get("rank", null) == null else ("#%d" % int(me["rank"]))
	_boards_lbl.text = Loc.t("world.board", [rank])
	var board_id: String = BOARD_IDS[_board_index]
	var bl: Dictionary = Net.cached("boards/" + board_id)
	_board_btn.text = Loc.t("world.board_next", [Loc.board_name(board_id)])
	_entries_lbl.text = Loc.t("world.entries", [(bl.get("entries", []) as Array).size()])
	_board_list_lbl.text = Loc.t("world.me", [rank]) + " · " + Loc.t("world.board_title", [Loc.board_name(board_id)])
	var daily: Dictionary = Net.cached("daily")
	_daily_lbl.text = Loc.t("world.daily", [int(daily.get("attempts_left", 0))])
	var pvp: Dictionary = Net.cached("pvp/me")
	_cup_lbl.text = Loc.t("world.cup", [
		int(pvp.get("rating", 1000)), String(pvp.get("league", "bronze")), int(pvp.get("passes", 0)),
	])
	if _opponent_buttons.is_empty():
		_build_opponents()


func _catalog() -> Catalog:
	return Catalog.from_dicts(Data.table("cargo"), Data.table("balance"))


func _crew() -> Crew:
	return Crew.from_dicts(Data.table("classes"), Data.table("balance"))


func _cycle_daily(slot: int) -> void:
	var nxt: int = int(_daily_assign[slot]) + 1
	_daily_assign[slot] = -1 if nxt >= DailyShift.TEMP_CLASSES.size() else nxt
	_refresh_slots()


func _cycle_cup(station: int) -> void:
	var ids: Array = _roster_ids()
	var idx: int = ids.find(String(_cup_assign[station])) + 1
	_cup_assign[station] = "" if idx >= ids.size() else String(ids[idx])
	_refresh_slots()


func _cycle_tactic() -> void:
	_cup_tactic = (_cup_tactic + 1) % Tactics.ALL.size()
	_retranslate()


func _on_daily() -> void:
	var res: Dictionary = DailyShift.run(_catalog(), _crew(), _daily_assign, _daily_seed)
	var out: Dictionary = Net.post("daily/submit", Api.daily_submit_body(str(_daily_seed), _daily_assign, [], "instant", []))
	_daily_lbl.text = Loc.t("world.daily_score", [
		int(res["score"]), Loc.t("world.sent") if not out.has("error") else Loc.t("world.error"),
	])


func _on_fight() -> void:
	var mine: Array = _brigade_from(_cup_assign)
	if mine.size() < 3:
		_cup_lbl.text = Loc.t("world.none")
		return
	var bot: Array = [
		{ "station": "unload", "class_id": "loader", "si": 45.0 },
		{ "station": "move", "class_id": "crane_operator", "si": 45.0 },
		{ "station": "store", "class_id": "storekeeper", "si": 45.0 },
	]
	var tactic: String = Tactics.ALL[_cup_tactic]
	var res: Dictionary = Duel.simulate(_catalog(), _crew(), mine, bot, tactic, "balance", "silver", int(Time.get_unix_time_from_system()))
	var scores: Array = res["scores"]
	_cup_lbl.text = Loc.t("world.cup_result", [String(res["result"]), int(scores[0]), int(scores[1])])
	var opp: String = "bot_1" if _opponent_ids.is_empty() else String(_opponent_ids[_opponent_index])
	Net.post("pvp/attack", Api.pvp_attack_body(opp, tactic))
	_replay = res["replay"]
	_replay_step = -1
	_replay_lbl.text = Loc.t("world.replay", [_replay.size()])
	_replay_timer.start()


func _roster_ids() -> Array:
	var out: Array = []
	for w in GameState.roster:
		out.append(w.id)
	return out


func _brigade_from(assign: Array) -> Array:
	var crew := _crew()
	var out: Array = []
	for i in CUP_STATIONS.size():
		var wid: String = String(assign[i])
		if wid == "":
			continue
		var w: Worker = GameState.worker_by_id(wid)
		if w == null:
			continue
		out.append({
			"station": CUP_STATIONS[i],
			"class_id": w.class_id,
			"si": w.contrib(GameState.rules, crew) * 25.0,
		})
	return out


func _build_opponents() -> void:
	for c in _opponents_box.get_children():
		c.queue_free()
	_opponent_buttons.clear()
	_opponent_ids.clear()
	var opps: Array = Net.post_cached("pvp/opponents", {}).get("opponents", [])
	for i in opps.size():
		var o: Dictionary = opps[i]
		var ob := Button.new()
		ob.text = Loc.t("world.opponent", [String(o.get("nickname", "?")), int(o.get("rating", 0))])
		ob.pressed.connect(func(): _select_opponent(i))
		_opponents_box.add_child(ob)
		_opponent_buttons.append(ob)
		_opponent_ids.append(String(o.get("id", "")))


func _cycle_board() -> void:
	_board_index = (_board_index + 1) % BOARD_IDS.size()
	_refresh()


func _select_opponent(i: int) -> void:
	_opponent_index = i
	_cup_lbl.text = _opponent_buttons[i].text


func _on_replay_tick() -> void:
	_replay_step += 1
	if _replay_step >= _replay.size():
		_replay_timer.stop()
		_replay_lbl.text = Loc.t("world.replay", [_replay.size()])
		return
	var e: Dictionary = _replay[_replay_step]
	_replay_lbl.text = Loc.t("world.play", [_replay_step + 1, _replay.size(), String(e.get("k", ""))])


func _on_request() -> void:
	var code: String = _friend_edit.text.strip_edges()
	if code == "":
		return
	Net.post("friends/request", { "code": code })
	_social_lbl.text = Loc.t("world.friends", [0])


func _on_donate() -> void:
	var out: Dictionary = Net.post("unions/demo/donate", { "amount": 5000 })
	_social_lbl.text = Loc.t("world.union_info", ["Космо-грузчики", 1, int(out.get("fund", 0))])


func _on_union() -> void:
	var out: Dictionary = Net.post("unions", { "name": "Космо-грузчики", "emblem": 0, "description": "", "join_mode": "open" })
	_social_lbl.text = Loc.t("world.union_created") if out.has("id") else Loc.t("world.union_err", [String(out.get("error", out))])


func _on_friends() -> void:
	var out: Dictionary = Net.cached("friends")
	_social_lbl.text = Loc.t("world.friends", [(out.get("friends", []) as Array).size()])


