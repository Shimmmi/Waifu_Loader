class_name Api
extends RefCounted

## Pure API layer (spec §13, §14.5): URL/header building, request bodies,
## response parsing, retry policy and degradation. No nodes, no I/O — so it is
## headless-testable and mirrors exactly what the backend agent implements.

const H_AUTH := "Authorization"
const H_CONTENT_TYPE := "Content-Type"
const H_IDEMPOTENCY := "Idempotency-Key"
const H_CLIENT_VERSION := "X-Client-Version"
const H_SIM_VERSION := "X-Sim-Version"

var base_url: String
var client_version: String
var sim_version: String


func _init(base: String = "", cver: String = "0.0.1", sver: String = "1") -> void:
	base_url = base.trim_suffix("/")
	client_version = cver
	sim_version = sver


func url(path: String) -> String:
	return base_url + "/" + path.trim_prefix("/")


func headers(token: String = "", idempotency_key: String = "") -> PackedStringArray:
	var h := PackedStringArray([
		"%s: application/json" % H_CONTENT_TYPE,
		"%s: %s" % [H_CLIENT_VERSION, client_version],
		"%s: %s" % [H_SIM_VERSION, sim_version],
	])
	if token != "":
		h.append("%s: Bearer %s" % [H_AUTH, token])
	if idempotency_key != "":
		h.append("%s: %s" % [H_IDEMPOTENCY, idempotency_key])
	return h


# ------------------------------------------------------------- body builders

static func guest_body(locale: String, version: String) -> Dictionary:
	return { "client_version": version, "locale": locale }


static func recover_body(code: String) -> Dictionary:
	return { "code": code }


static func save_meta(lifetime_t: float, prestige_count: int, rank: int, playtime_s: float, schema_v: int) -> Dictionary:
	return {
		"lifetime_t": lifetime_t,
		"prestige_count": prestige_count,
		"rank": rank,
		"playtime_s": playtime_s,
		"schema_v": schema_v,
	}


static func save_put_body(base_revision: int, save_b64: String, meta: Dictionary) -> Dictionary:
	return { "base_revision": base_revision, "save_b64": save_b64, "meta": meta }


static func telemetry_body(seq: int, window_start: float, window_end: float, delta_tonnes: float, best_tpm: float, gold_count: int, shifts: int, power_snapshot: Dictionary) -> Dictionary:
	return {
		"seq": seq,
		"window_start": int(window_start),
		"window_end": int(window_end),
		"delta_tonnes": delta_tonnes,
		"best_tpm": best_tpm,
		"gold_count": gold_count,
		"shifts": shifts,
		"power_snapshot": power_snapshot,
	}


static func daily_submit_body(daily_seed: String, assignment: Array, event_choices: Array, mode: String, rush_times: Array) -> Dictionary:
	return {
		"daily_seed": daily_seed,
		"assignment": assignment,
		"event_choices": event_choices,
		"mode": mode,
		"rush_times": rush_times,
	}


static func pvp_attack_body(opponent_id: String, tactic: String) -> Dictionary:
	return { "opponent_id": opponent_id, "tactic": tactic }


static func report_body(target_type: String, target_id: String, reason: String) -> Dictionary:
	return { "target_type": target_type, "target_id": target_id, "reason": reason }


# ------------------------------------------------------------ response checks

## Uniform error envelope (spec §14.5): {error:{code,message}}.
static func error_of(response: Dictionary) -> Dictionary:
	return response.get("error", {})


static func is_ok(response: Dictionary) -> bool:
	return not response.has("error")


## Degradation class for an HTTP status (spec §13.13).
static func classify(code: int) -> String:
	if code == 401:
		return "reauth"
	if code == 426:
		return "update"
	if code == 409:
		return "conflict"
	if code == 0 or code == 429 or code >= 500:
		return "retry"
	return "ok"


static func should_retry(code: int) -> bool:
	return classify(code) == "retry"


## Exponential backoff (spec §13.1: 3 retries). `attempt` is 0-based.
static func retry_delay(attempt: int, max_delay: float = 300.0) -> float:
	return minf(pow(2.0, float(attempt)), max_delay)


## Client-side pre-check mirroring the server (spec §13.4).
static func telemetry_ok(delta_tonnes: float, best_tpm: float, window_s: float, rate_cap: float) -> bool:
	var cap_tonnes: float = rate_cap * (window_s / 60.0) * 1.25 + 50.0
	if delta_tonnes > cap_tonnes:
		return false
	if best_tpm > rate_cap * 1.1:
		return false
	return true


## Save-conflict resolution (spec §13.3): propose the larger lifetime_t.
static func prefer_server(local_meta: Dictionary, server_meta: Dictionary) -> bool:
	return float(server_meta.get("lifetime_t", 0.0)) > float(local_meta.get("lifetime_t", 0.0))