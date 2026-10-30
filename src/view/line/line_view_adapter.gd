class_name LineViewAdapter
extends RefCounted

## Builds an immutable LineViewState snapshot from GameState/LineSim (v0.2 §4.5).
## View-only: never mutates Sim, never consumes the simulation PRNG.

var crate_u: float = 1.0
var _acc: Dictionary = {"arrive": 0.0, "m1": 0.0, "m2": 0.0, "m3": 0.0}
var _cosmetic: PCG32 = PCG32.new(0xC05E71C0, 1)


func snapshot(line_id: int = 1) -> Dictionary:
	var line: LineSim = GameState.line
	var shift: Shift = GameState.shift
	_pick_crate_u(line)
	var stations: Array = [
		_station("unload", line.rate_unload if line else 0.0),
		_station("move", line.rate_move if line else 0.0),
		_station("store", line.rate_store if line else 0.0),
	]
	var q0_t: float = _buf_sum(line.q0) if line else 0.0
	var b1_t: float = _buf_sum(line.b1) if line else 0.0
	var b2_t: float = _buf_sum(line.b2) if line else 0.0
	var bottleneck := _bottleneck(stations)
	var income_pm: float = 0.0
	if line and line.rate_store > 0.0:
		income_pm = line.rate_store * line.tariff * line.income_mult
	var shift_t: float = shift.elapsed_s if shift else 0.0
	var shift_len: float = shift.duration_s if shift else 300.0
	return {
		"line_id": line_id,
		"shift_t": shift_t,
		"shift_len": shift_len,
		"mode": "normal",
		"auto": true,
		"crate_u": crate_u,
		"stations": stations,
		"queues": {
			"q0": {"tons": q0_t, "cap": line.q0_cap if line else 60.0, "mix": _mix(line.q0 if line else PackedFloat32Array())},
			"b1": {"tons": b1_t, "cap": line.b1_cap if line else 200.0, "mix": _mix(line.b1 if line else PackedFloat32Array())},
			"b2": {"tons": b2_t, "cap": line.b2_cap if line else 450.0, "mix": _mix(line.b2 if line else PackedFloat32Array())},
		},
		"flows_tps": {
			"arrive": (line.lambda if line else 0.0) / 60.0,
			"m1": (line.rate_unload if line else 0.0) / 60.0,
			"m2": (line.rate_move if line else 0.0) / 60.0,
			"m3": (line.rate_store if line else 0.0) / 60.0,
			"missed": 0.0,
			"defect": 0.0,
		},
		"income_pm": income_pm,
		"bottleneck": bottleneck,
		"bottleneck_hint": _hint(bottleneck, stations),
		"events": [],
		"contract": {"id": "", "progress": 0.0, "eta_s": 0},
		"support": {"foreman": _support_id("support"), "mechanic": null},
		"cosmetic_seed": _cosmetic._state,
	}


func rng_cosmetic() -> PCG32:
	return _cosmetic


func _station(id: String, rate: float) -> Dictionary:
	var workers: Array = []
	var slot_i := 0
	for w in GameState.station_workers(id):
		workers.append({
			"id": w.id,
			"slot": slot_i,
			"state": _worker_state(w, rate),
			"fatigue": w.fatigue,
			"morale": w.morale,
		})
		slot_i += 1
	var cap: float = maxf(rate, 0.01)
	var util: float = clampf(rate / cap, 0.0, 1.0) if rate > 0.0 else 0.0
	# Compare against neighbors for util when all rates known.
	var state := "ok"
	if workers.is_empty():
		state = "starved"
		util = 1.0
	return {
		"id": id,
		"rate_tpm": rate,
		"cap_tpm": cap,
		"util": util,
		"state": state,
		"workers": workers,
		"auto_active": workers.is_empty(),
	}


func _worker_state(w: Worker, _rate: float) -> String:
	if w.fatigue >= 100.0:
		return "out"
	if w.fatigue >= 80.0:
		return "tired"
	if w.status == "injured":
		return "injured"
	return "work"


func _bottleneck(stations: Array) -> String:
	var worst_id := ""
	var worst_rate := INF
	for s in stations:
		var r: float = float(s["rate_tpm"])
		if s["workers"].is_empty():
			return String(s["id"])
		if r < worst_rate:
			worst_rate = r
			worst_id = String(s["id"])
	# Mark bottleneck state.
	for s in stations:
		if String(s["id"]) == worst_id and float(s["rate_tpm"]) > 0.0:
			var others_max := 0.0
			for o in stations:
				if o["id"] != worst_id:
					others_max = maxf(others_max, float(o["rate_tpm"]))
			if others_max > 0.0 and float(s["rate_tpm"]) / others_max < 0.95:
				s["state"] = "bottleneck"
				s["util"] = 1.0
	return worst_id


func _hint(bn: String, stations: Array) -> String:
	for s in stations:
		if String(s["id"]) == bn and s["workers"].is_empty():
			if bn == "move":
				return "need_driver"
			if bn == "unload":
				return "need_loader"
			if bn == "store":
				return "need_storekeeper"
	return ""


func _support_id(station: String) -> Variant:
	var ws: Array = GameState.station_workers(station)
	return ws[0].id if not ws.is_empty() else null


func _buf_sum(arr: PackedFloat32Array) -> float:
	var s := 0.0
	for v in arr:
		s += v
	return s


func _mix(arr: PackedFloat32Array) -> Array:
	var total := _buf_sum(arr)
	var out: Array = []
	for i in 7:
		if i < arr.size() and total > 0.0:
			out.append(arr[i] / total)
		else:
			out.append(0.0)
	return out


func _pick_crate_u(line: LineSim) -> void:
	## Smallest U in {0.5,1,2,5,...} keeping median cycle in 1.5–5 s and ≤2.5 crates/s.
	var candidates: Array = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0]
	var flow: float = 0.0
	if line:
		flow = maxf(line.rate_unload, maxf(line.rate_move, line.rate_store)) / 60.0
	crate_u = 1.0
	for u in candidates:
		var cps: float = flow / u if u > 0.0 else 999.0
		if cps <= 2.5:
			crate_u = u
			return
