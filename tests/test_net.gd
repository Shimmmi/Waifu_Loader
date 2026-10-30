extends TestCase

## API layer, outbox and mock backend (spec §13, §14.5).


func test_url_and_headers() -> void:
	var api := Api.new("https://example.test/tupik9/api/v1/", "0.0.1", "1")
	assert_eq(api.url("/time"), "https://example.test/tupik9/api/v1/time")
	assert_eq(api.url("boards/tonnes_weekly"), "https://example.test/tupik9/api/v1/boards/tonnes_weekly")
	var h: PackedStringArray = api.headers("")
	assert_true(h.has("Content-Type: application/json"))
	assert_true(h.has("X-Client-Version: 0.0.1"))
	assert_true(h.has("X-Sim-Version: 1"))
	assert_false(h.has("Authorization: Bearer x"))
	var h2: PackedStringArray = api.headers("tok", "key1")
	assert_true(h2.has("Authorization: Bearer tok"))
	assert_true(h2.has("Idempotency-Key: key1"))


func test_body_builders() -> void:
	var g: Dictionary = Api.guest_body("ru", "0.0.1")
	assert_eq(g["locale"], "ru")
	var t: Dictionary = Api.telemetry_body(5, 100.0, 160.0, 12.5, 3.0, 1, 2, { "dock": [1] })
	assert_eq(int(t["seq"]), 5)
	assert_eq(int(t["window_end"]), 160)
	assert_close(float(t["delta_tonnes"]), 12.5, 1e-6)
	var p: Dictionary = Api.pvp_attack_body("p_1", "assault")
	assert_eq(p["tactic"], "assault")


func test_degradation_and_retry() -> void:
	assert_eq(Api.classify(200), "ok")
	assert_eq(Api.classify(401), "reauth")
	assert_eq(Api.classify(426), "update")
	assert_eq(Api.classify(409), "conflict")
	assert_eq(Api.classify(500), "retry")
	assert_eq(Api.classify(0), "retry")
	assert_true(Api.should_retry(503))
	assert_false(Api.should_retry(401))
	assert_close(Api.retry_delay(0), 1.0, 1e-6)
	assert_close(Api.retry_delay(1), 2.0, 1e-6)
	assert_close(Api.retry_delay(2), 4.0, 1e-6)
	assert_close(Api.retry_delay(20), 300.0, 1e-6)


func test_telemetry_validation() -> void:
	# rate_cap 10 t/min, window 60 s -> cap = 10*1*1.25 + 50 = 62.5
	assert_true(Api.telemetry_ok(60.0, 10.0, 60.0, 10.0))
	assert_false(Api.telemetry_ok(70.0, 10.0, 60.0, 10.0))
	assert_false(Api.telemetry_ok(10.0, 12.0, 60.0, 10.0))


func test_save_conflict_preference() -> void:
	assert_true(Api.prefer_server({ "lifetime_t": 100.0 }, { "lifetime_t": 200.0 }))
	assert_false(Api.prefer_server({ "lifetime_t": 300.0 }, { "lifetime_t": 200.0 }))


func test_error_envelope() -> void:
	assert_true(Api.is_ok({ "server_time": 1.0 }))
	assert_false(Api.is_ok({ "error": { "code": "x", "message": "y" } }))
	assert_eq(Api.error_of({ "error": { "code": "x" } })["code"], "x")


func test_outbox_dedupe_and_order() -> void:
	var ob := Outbox.new()
	var k1: String = ob.enqueue("telemetry/progress", "POST", { "seq": 1 })
	var k2: String = ob.enqueue("telemetry/progress", "POST", { "seq": 2 })
	assert_eq(ob.size(), 2)
	assert_true(k1 != k2)
	# same key -> no duplicate
	ob.enqueue("telemetry/progress", "POST", { "seq": 1 }, k1)
	assert_eq(ob.size(), 2)
	assert_true(ob.contains_key(k1))
	var first: Dictionary = ob.pop()
	assert_eq(first["key"], k1)
	assert_eq(ob.size(), 1)
	assert_eq(ob.peek()["key"], k2)


func test_outbox_serialization() -> void:
	var ob := Outbox.new()
	ob.enqueue("save", "PUT", { "base_revision": 1 })
	ob.enqueue("save", "PUT", { "base_revision": 2 })
	var arr: Array = ob.to_array()
	var ob2 := Outbox.new()
	ob2.load_array(arr)
	assert_eq(ob2.size(), 2)
	assert_eq(ob2.peek()["path"], "save")


func test_mock_backend() -> void:
	var mb := MockBackend.new()
	var cfg: Dictionary = mb.respond("GET", "/config", {})
	assert_eq(int(cfg["code"]), 200)
	assert_eq(cfg["body"]["min_client_version"], "0.0.1")
	var g1: Dictionary = mb.respond("POST", "/auth/guest", {})
	var g2: Dictionary = mb.respond("POST", "/auth/guest", {})
	assert_true(g1["body"]["player_id"] != g2["body"]["player_id"])
	var t: Dictionary = mb.respond("GET", "/time", {})
	assert_eq(int(t["code"]), 200)
	var bad: Dictionary = mb.respond("GET", "/does-not-exist", {})
	assert_eq(int(bad["code"]), 404)
	assert_false(Api.is_ok(bad["body"]))