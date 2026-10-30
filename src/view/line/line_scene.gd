extends Control

## Live loading line scene (v0.2 WP-B P0). Reads LineViewState only.

var _snap: Dictionary = {}
var _flow := CrateFlow.new()
var _actors: Dictionary = {}  # worker_id -> WorkerActor
var _bench: HBoxContainer
var _reduce_motion: bool = false
var _camera_mode: String = "all"  # all | station | cine
var _station_focus: int = 0
var _bark_cd: float = 25.0
var _bark: BarkBubble
var _event_fx: String = ""
var _mini_layer: CanvasLayer
var _mini_dim: ColorRect
var _mini_card: Control = null


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(480, 176)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bench = HBoxContainer.new()
	_bench.position = Vector2(4, 152)
	add_child(_bench)
	_bark = BarkBubble.new()
	add_child(_bark)
	_mini_layer = CanvasLayer.new()
	_mini_layer.layer = 30
	add_child(_mini_layer)
	_mini_dim = ColorRect.new()
	_mini_dim.color = Color(0, 0, 0, 0.45)
	_mini_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mini_dim.visible = false
	_mini_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini_dim.gui_input.connect(_on_mini_dim_input)
	_mini_layer.add_child(_mini_dim)
	_reduce_motion = bool(SaveSystem.settings().get("reduce_motion", false))
	if GameState.has_signal("line_event"):
		GameState.line_event.connect(_on_line_event)
	set_process(true)


func apply_snapshot(snap: Dictionary) -> void:
	_snap = snap
	_flow.configure(float(snap.get("crate_u", 1.0)))
	_sync_actors()
	_sync_bench()
	queue_redraw()


func _process(dt: float) -> void:
	if not visible or _snap.is_empty():
		return
	_bark_cd -= dt
	if _bark_cd <= 0.0 and not _reduce_motion and bool(SaveSystem.settings().get("show_barks", true)):
		_try_bark()
		_bark_cd = 20.0 + float(randi() % 20)
	if _reduce_motion:
		return
	var flows: Dictionary = _snap.get("flows_tps", {})
	_flow.step(float(flows.get("m1", 0.0)), dt, Vector2(40, 120), Vector2(196, 120))
	_flow.step(float(flows.get("m2", 0.0)), dt, Vector2(196, 130), Vector2(356, 130))
	_flow.step(float(flows.get("m3", 0.0)), dt, Vector2(356, 120), Vector2(450, 120))
	queue_redraw()


func _on_line_event(_line_id: int, type: String, _payload: Dictionary) -> void:
	_event_fx = type
	queue_redraw()


func _try_bark() -> void:
	if _actors.is_empty() or _bark == null:
		return
	var ids: Array = _actors.keys()
	var wid: String = String(ids[randi() % ids.size()])
	var w: Worker = GameState.worker_by_id(wid)
	var table: Dictionary = Data.table("barks_ru").get("barks", {})
	var pool: Array = table.get(w.class_id if w else "default", table.get("default", ["…"]))
	if pool.is_empty():
		return
	var actor: WorkerActor = _actors[wid]
	_bark.position = actor.position + Vector2(0, -30)
	_bark.say(String(pool[randi() % pool.size()]))


func set_camera_mode(mode: String) -> void:
	_camera_mode = mode
	queue_redraw()


func _sync_actors() -> void:
	var layout: Dictionary = Data.table("stations_view")
	var seen: Dictionary = {}
	for st in _snap.get("stations", []):
		var sid: String = String(st["id"])
		var slots: Array = layout.get(sid, {}).get("slots", [])
		var util: float = float(st.get("util", 0.5))
		var speed: float = clampf(0.6 + 0.8 * util, 0.6, 1.5)
		for winfo in st.get("workers", []):
			var wid: String = String(winfo["id"])
			seen[wid] = true
			var actor: WorkerActor = _actors.get(wid)
			if actor == null:
				actor = WorkerActor.new()
				add_child(actor)
				_actors[wid] = actor
			var slot: int = int(winfo.get("slot", 0))
			var pos := Vector2(100, 140)
			if slot < slots.size():
				var xy: Array = slots[slot]
				pos = Vector2(float(xy[0]), float(xy[1]))
			actor.setup(wid, pos)
			actor.set_state(String(winfo.get("state", "work")), speed)
	# Remove stale.
	for wid in _actors.keys():
		if not seen.has(wid):
			(_actors[wid] as Node).queue_free()
			_actors.erase(wid)


func _sync_bench() -> void:
	for c in _bench.get_children():
		c.queue_free()
	var on_shift: Dictionary = {}
	for st in _snap.get("stations", []):
		for winfo in st.get("workers", []):
			on_shift[String(winfo["id"])] = true
	for w in GameState.roster:
		if on_shift.has(w.id):
			continue
		var b := TextureRect.new()
		b.custom_minimum_size = Vector2(16, 16)
		b.texture = PixelAssets.head_icon(w)
		b.tooltip_text = w.display_name()
		b.gui_input.connect(_bench_input.bind(w.id))
		_bench.add_child(b)


func _bench_input(event: InputEvent, wid: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Assign to first free slot with best fit.
		var w: Worker = GameState.worker_by_id(wid)
		if w == null:
			return
		var best := ""
		var best_s := -1.0
		for station in ["unload", "move", "store"]:
			var score := w.station_score(station, GameState.rules, GameState.crew)
			for i in int(GameState.STATION_SLOTS.get(station, 0)):
				var sid := "%s%d" % [station, i]
				if String(GameState.slots.get(sid, "")) == "" and score > best_s:
					best_s = score
					best = sid
		if best != "":
			GameState.assign(best, wid)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		for wid in _actors.keys():
			var a: WorkerActor = _actors[wid]
			if Rect2(a.position - Vector2(8, 24), Vector2(16, 24)).has_point(pos):
				_open_mini(wid)
				return


func _close_mini() -> void:
	if _mini_card != null and is_instance_valid(_mini_card):
		_mini_card.queue_free()
	_mini_card = null
	if _mini_dim:
		_mini_dim.visible = false


func _on_mini_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_mini()
		get_viewport().set_input_as_handled()


func _open_mini(wid: String) -> void:
	_close_mini()
	var packed: PackedScene = load("res://src/ui/crew/MiniCard.tscn") as PackedScene
	if packed == null:
		return
	_mini_dim.visible = true
	_mini_dim.move_to_front()
	var card: Control = packed.instantiate()
	_mini_card = card
	card.position = Vector2(156, 36)
	_mini_layer.add_child(card)
	card.move_to_front()
	if card.has_method("bind"):
		card.bind(wid)
	if card.has_signal("closed"):
		card.closed.connect(_close_mini)
	if card.has_signal("open_full"):
		card.open_full.connect(func(id):
			var sm = get_tree().root.find_child("ScreenManager", true, false)
			if sm:
				sm.open_worker_card(id, "crew")
			_close_mini())


func _draw() -> void:
	# Sky / wall / floor.
	draw_rect(Rect2(0, 0, 480, 80), Color(0.05, 0.07, 0.14))
	draw_rect(Rect2(0, 80, 480, 24), Color(0.18, 0.18, 0.22))
	draw_rect(Rect2(0, 104, 480, 72), Color(0.22, 0.22, 0.26))
	# Elevator progress hint in window.
	var elev_pct: float = 0.0
	if GameState.elevator != null:
		elev_pct = float(GameState.elevator.progress(GameState.lifetime_tonnes))
	draw_rect(Rect2(220, 20 + (1.0 - elev_pct) * 40.0, 12, 8), Color(0.7, 0.75, 0.9))

	var layout: Dictionary = Data.table("stations_view")
	_draw_zone(layout.get("shuttle", {"x": 0, "w": 64}), Color(0.25, 0.3, 0.45), "Шаттл")
	_draw_zone(layout.get("unload", {}), Color(0.28, 0.36, 0.42), Loc.station_name("unload"))
	_draw_zone(layout.get("b1", {"x": 176, "w": 40}), Color(0.35, 0.3, 0.22), "B1")
	_draw_zone(layout.get("move", {}), Color(0.32, 0.34, 0.28), Loc.station_name("move"))
	_draw_zone(layout.get("b2", {"x": 336, "w": 40}), Color(0.35, 0.3, 0.22), "B2")
	_draw_zone(layout.get("store", {}), Color(0.30, 0.32, 0.40), Loc.station_name("store"))

	# Buffers fill stages.
	if not _snap.is_empty():
		var qs: Dictionary = _snap.get("queues", {})
		_draw_buffer(196, 110, qs.get("b1", {}))
		_draw_buffer(356, 110, qs.get("b2", {}))
		_draw_buffer(32, 110, qs.get("q0", {}))
		# Station lamps.
		for st in _snap.get("stations", []):
			var x: float = float(layout.get(String(st["id"]), {}).get("x", 100)) + 8
			var col := Color.GREEN
			match String(st.get("state", "ok")):
				"bottleneck":
					col = Color.RED
				"starved":
					col = Color.YELLOW
				_:
					if float(st.get("util", 0)) >= 0.95:
						col = Color.YELLOW
			draw_circle(Vector2(x, 90), 3, col)
			if st.get("auto_active", false):
				draw_string(ThemeDB.fallback_font, Vector2(x + 6, 92), Loc.t("line.auto"),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.8, 0.5))

	# Flying crates.
	if not _reduce_motion:
		for c in _flow.flying:
			var p: Vector2 = c["pos"]
			draw_rect(Rect2(p.x - 4, p.y - 4, 8, 8), Color(0.8, 0.65, 0.35))

	# Event FX (W5 vertical slice).
	match _event_fx:
		"heat":
			draw_rect(Rect2(0, 0, 480, 176), Color(1.0, 0.4, 0.1, 0.08))
		"leak":
			draw_circle(Vector2(240, 100), 6, Color(0.3, 0.5, 0.9, 0.5))
		"cat":
			draw_rect(Rect2(200, 140, 12, 8), Color(0.9, 0.7, 0.3))
		"meteor":
			draw_line(Vector2(40, 10), Vector2(80, 50), Color(1, 1, 0.7), 1.0)
		"break":
			draw_string(ThemeDB.fallback_font, Vector2(200, 40), "Сломан",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.3, 0.3))


func _draw_zone(z: Dictionary, col: Color, label: String) -> void:
	if z.is_empty():
		return
	var x: float = float(z.get("x", 0))
	var w: float = float(z.get("w", 40))
	draw_rect(Rect2(x, 104, w, 48), col)
	draw_string(ThemeDB.fallback_font, Vector2(x + 2, 114), label,
		HORIZONTAL_ALIGNMENT_LEFT, int(w - 2), 8, Color(0.9, 0.9, 1.0))


func _draw_buffer(x: float, y: float, q: Dictionary) -> void:
	var tons: float = float(q.get("tons", 0.0))
	var cap: float = float(q.get("cap", 1.0))
	var stage: int = _flow.stage_for_fill(tons, cap)
	var h: float = 6.0 + float(stage) * 4.0
	var col := Color(0.75, 0.6, 0.3)
	if tons / maxf(cap, 1.0) >= 0.9:
		col = Color(1.0, 0.3, 0.3)
	draw_rect(Rect2(x, y + 20.0 - h, 16, h), col)
