extends Node

## Autoload "Net" — API client (spec §2.4, §13, §14).
##
## Always offline-safe: with no backend it routes through a deterministic
## MockBackend so the game never blocks (§13.1). The HTTPRequest path with
## timeout + exponential retries is used only when a real backend is enabled.

const BASE_URL: String = "https://shimmirpgbot.ru/tupik9/api/v1"
const AUTH_PATH: String = "user://auth.json"
const HTTP_TIMEOUT_S: float = 8.0
const MAX_RETRIES: int = 3

signal time_synced(server_unix: float)
signal status_changed(mode: int)
signal response_received(path: String, code: int, body: Dictionary)

enum Mode { OFFLINE, ONLINE }

var mode: Mode = Mode.OFFLINE
## True while running without a real backend.
var is_mock: bool = true

var api: Api
var outbox: Outbox
var mock: MockBackend

var token: String = ""
var player_id: String = ""
var nickname: String = ""

var config: Dictionary = {}
var _telemetry_seq: int = 0
## Last known response per path, served synchronously to the UI while a fresh
## request is in flight (spec §13.13: show cached data with a timestamp).
var _cache: Dictionary = {}
var _inflight: Dictionary = {}


func _ready() -> void:
	var ver: Dictionary = Data.table("version")
	api = Api.new(BASE_URL, String(ver.get("client_version", "0.0.1")), str(int(ver.get("sim_version", 1))))
	outbox = Outbox.new()
	mock = MockBackend.new()
	_load_auth()
	if bool(SaveSystem.settings().get("online", true)):
		enable_backend()
	else:
		_set_mode(Mode.OFFLINE)
	fetch_config()
	fetch_time()


## Switch between the live backend and the offline mock.
func set_online(value: bool) -> void:
	if value:
		enable_backend()
	else:
		is_mock = true
		_cache.clear()
		_inflight.clear()
		_set_mode(Mode.OFFLINE)


# ------------------------------------------------------------- public calls

## Return authoritative server time and sync the Clock (spec §2.4). In mock mode
## this is the local wall clock; online it GETs /time.
func fetch_time() -> float:
	var t: float = float(Time.get_unix_time_from_system())
	if is_mock:
		var r: Dictionary = _mock_request("GET", "time", {})
		t = float(r["body"].get("server_time", t))
	else:
		_request_async("GET", "time", {}, "", Callable(self, "_on_time"))
	if Clock != null:
		Clock.apply_server_time(t)
	time_synced.emit(t)
	return t


func fetch_config() -> Dictionary:
	if is_mock:
		config = _mock_request("GET", "config", {})["body"]
	else:
		_request_async("GET", "config", {}, "", Callable(self, "_on_config"))
	return config


func auth_guest(locale: String = "ru") -> Dictionary:
	var body: Dictionary = Api.guest_body(locale, api.client_version)
	var r: Dictionary = _mock_request("POST", "auth/guest", body) if is_mock else { "code": 0, "body": {} }
	if Api.is_ok(r["body"]) and not r["body"].is_empty():
		player_id = String(r["body"].get("player_id", ""))
		token = String(r["body"].get("token", ""))
		nickname = String(r["body"].get("nickname", ""))
		_save_auth(r["body"])
	return r["body"]


func api_get(path: String) -> Dictionary:
	if is_mock:
		return _mock_request("GET", path, {})["body"]
	_refresh_get(path)
	return _cache.get(path, {}) as Dictionary


## Fetch a GET in the background and cache it; UI re-reads on response_received.
## Return the last known value for a path WITHOUT triggering a fetch (safe to
## call from display code / on every response without looping).
func cached(path: String) -> Dictionary:
	if is_mock:
		return mock.respond("GET", path, {})["body"]
	var c: Dictionary = _cache.get(path, {}) as Dictionary
	if c.is_empty():
		# No live response yet (fresh player, or backend unreachable) — show mock
		# data so panels never render blank (§13.1 offline-safe, §13.13 cached view).
		return mock.respond("GET", path, {})["body"]
	return c


func _refresh_get(path: String) -> void:
	if _inflight.has(path):
		return
	_inflight[path] = true
	var on_done := func(code: int, body: Dictionary) -> void:
		_inflight.erase(path)
		if code == 200 and not body.is_empty():
			_cache[path] = body
		response_received.emit(path, code, body)
	_request_async("GET", path, {}, "", on_done)


func post(path: String, body: Dictionary, idempotent: bool = false) -> Dictionary:
	var key: String = outbox.enqueue(path, "POST", body) if idempotent else ""
	if is_mock:
		var r: Dictionary = _mock_request("POST", path, body)
		if idempotent and Api.is_ok(r["body"]):
			outbox.pop()  # acked
		return r["body"]
	_request_async("POST", path, body, key, Callable(self, "_on_generic"))
	return {}


## Queue a progress packet (spec §13.4). Returns the packet body.
func send_telemetry(delta_tonnes: float, best_tpm: float, gold_count: int, shifts: int, window_start: float, window_end: float, power_snapshot: Dictionary) -> Dictionary:
	_telemetry_seq += 1
	var body: Dictionary = Api.telemetry_body(_telemetry_seq, window_start, window_end, delta_tonnes, best_tpm, gold_count, shifts, power_snapshot)
	return post("telemetry/progress", body, true)


func is_online() -> bool:
	return mode == Mode.ONLINE and not is_mock


## Enable the real backend (used once a server URL is confirmed reachable).
func enable_backend() -> void:
	is_mock = false
	_set_mode(Mode.ONLINE)
	if token == "":
		# Guest account (spec §13.2) so authed reads work.
		_request_async("POST", "auth/guest", Api.guest_body(OS.get_locale_language(), api.client_version), "", Callable(self, "_on_guest"))


func _on_guest(code: int, body: Dictionary) -> void:
	if code == 200 and body.has("token"):
		player_id = String(body.get("player_id", ""))
		token = String(body.get("token", ""))
		nickname = String(body.get("nickname", ""))
		_save_auth(body)
		response_received.emit("auth/guest", code, body)


## POST that also caches its result so the UI can read it (e.g. pvp/opponents).
func post_cached(path: String, body: Dictionary) -> Dictionary:
	if is_mock:
		return _mock_request("POST", path, body)["body"]
	if not _inflight.has(path):
		_inflight[path] = true
		_request_async("POST", path, body, "", func(code: int, resp: Dictionary) -> void:
			_inflight.erase(path)
			if code == 200 and not resp.is_empty():
				_cache[path] = resp
			response_received.emit(path, code, resp))
	var c: Dictionary = _cache.get(path, {}) as Dictionary
	if c.is_empty():
		return _mock_request("POST", path, body)["body"]
	return c


# --------------------------------------------------------------- internals

func _mock_request(method: String, path: String, body: Dictionary) -> Dictionary:
	var r: Dictionary = mock.respond(method, path, body)
	response_received.emit(path, int(r["code"]), r["body"])
	return r


func _on_time(code: int, body: Dictionary) -> void:
	if code == 200:
		var t: float = float(body.get("server_time", 0.0))
		if Clock != null and t > 0.0:
			Clock.apply_server_time(t)
		time_synced.emit(t)


func _on_config(code: int, body: Dictionary) -> void:
	if code == 200:
		config = body


func _on_generic(_code: int, body: Dictionary) -> void:
	if Api.is_ok(body):
		var idem: String = String(body.get("_idempotency", ""))
		if idem != "" and outbox.contains_key(idem):
			outbox.pop()


## Real HTTP path with timeout + exponential backoff (dormant while offline).
func _request_async(method: String, path: String, body: Dictionary, idem_key: String, cb: Callable) -> void:
	var attempt: int = 0
	while true:
		var code: int = 0
		var resp: Dictionary = {}
		var req := HTTPRequest.new()
		add_child(req)
		req.timeout = HTTP_TIMEOUT_S
		var hdrs: PackedStringArray = api.headers(token, idem_key)
		var payload: String = "" if method == "GET" else JSON.stringify(body)
		var http_method: int = HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
		var err: int = req.request(api.url(path), hdrs, http_method, payload)
		if err == OK:
			var res: Array = await req.request_completed
			code = int(res[1])
			var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
			if text != "":
				var parsed: Variant = JSON.parse_string(text)
				if typeof(parsed) == TYPE_DICTIONARY:
					resp = parsed
		req.queue_free()
		response_received.emit(path, code, resp)
		if not Api.should_retry(code) or attempt >= MAX_RETRIES:
			cb.call(code, resp)
			return
		attempt += 1
		await get_tree().create_timer(Api.retry_delay(attempt - 1)).timeout


func _load_auth() -> void:
	if not FileAccess.file_exists(AUTH_PATH):
		return
	var f: FileAccess = FileAccess.open(AUTH_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		token = String(parsed.get("token", ""))
		player_id = String(parsed.get("player_id", ""))
		nickname = String(parsed.get("nickname", ""))


func _save_auth(body: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(AUTH_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"token": token, "player_id": player_id, "nickname": nickname,
		"recovery_code": String(body.get("recovery_code", "")),
	}))


func _set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	status_changed.emit(mode)