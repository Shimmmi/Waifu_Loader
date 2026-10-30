class_name MockBackend
extends RefCounted

## Offline mock backend (spec §14.5 shapes). Serves deterministic canned
## responses so the client, UI and tests work with no server. Every response
## has the { code, body } shape the real HTTPRequest path also produces.

var _players: int = 0


## Returns { code:int, body:Dictionary } for a request.
func respond(method: String, path: String, body: Dictionary) -> Dictionary:
	var p: String = path.trim_prefix("/")
	match p:
		"time":
			return _ok({ "server_time": float(Time.get_unix_time_from_system()) })
		"config":
			return _ok({
				"min_client_version": "0.0.1",
				"sim_versions_supported": [1],
				"global_scale": 1.0,
				"features": { "daily": true, "tender": true, "pvp": true, "unions": true },
			})
		"health":
			return _ok({ "status": "ok" })
		"auth/guest":
			_players += 1
			return _ok({
				"player_id": "p_%04d" % _players,
				"token": "mock-token-%04d" % _players,
				"nickname": "Грузчик#%04d" % (1000 + _players),
				"recovery_code": "MOCKCODE%04d" % _players,
			})
		"save":
			if method == "PUT":
				return _ok({ "revision": int(body.get("base_revision", 0)) + 1 })
			return _ok({ "revision": 1, "save_b64": "", "meta": {}, "updated_at": 0 })
		"telemetry/progress":
			return _ok({ "accepted": true, "hold": false, "server_time": float(Time.get_unix_time_from_system()), "global": { "stage": 1, "progress": 0.0 } })
		"news":
			return _ok({ "news": [] })
		"daily":
			return _ok({ "daily_seed": "mock-daily", "preset": {}, "attempts_left": 3 })
		"tender":
			return _ok({ "tender_id": "mock-tender", "rule": "standard", "attempts_left": 3 })
		"pvp/me":
			return _ok({ "rating": 1000, "league": "bronze", "passes": 5, "wins": 0, "losses": 0, "defense": {}, "defense_tactic": "balance" })
		"pvp/opponents":
			return _ok({ "opponents": [
				{ "id": "bot_1", "nickname": "Манекен 1", "rating": 1000, "is_bot": true },
				{ "id": "bot_2", "nickname": "Манекен 2", "rating": 975, "is_bot": true },
				{ "id": "bot_3", "nickname": "Манекен 3", "rating": 1030, "is_bot": true },
			] })
		"unions":
			return _ok({ "unions": [] })
		"friends":
			return _ok({ "friends": [], "pending": [] })
		"save/put":
			return _ok({ "revision": int(body.get("base_revision", 0)) + 1 })
		"report":
			return _ok({ "reported": true })
		"daily/submit":
			return _ok({ "provisional": float(body.get("score", 0.0)), "valid": true, "result": {} })
		"tender/submit":
			return _ok({ "valid": true, "result": {} })
		"pvp/attack":
			return _ok({ "result": "win", "scores": [1000, 900], "rating_delta": 14, "passes_left": 4, "replay": [] })
		"friends/request":
			return _ok({ "requested": true })
		"boards":
			return _ok({ "board_id": String(body.get("id", "")), "entries": [], "updated_at": 0 })
		"global":
			return _ok({ "stage": 1, "stages": 10, "progress": 0.0, "goal": 1.0e9 })
		"inbox":
			return _ok({ "items": [] })
	if p.begins_with("unions/"):
		if p.ends_with("/donate"):
			return _ok({ "fund": 5000 })
		return _ok({ "id": p.trim_prefix("unions/"), "name": "Космо-грузчики", "emblem": 0, "member_count": 1, "fund": 0, "upgrades": {} })
	if p.begins_with("boards/"):
		return _ok({ "board_id": p.trim_prefix("boards/"), "entries": [], "updated_at": 0 })
	if p.begins_with("profile/"):
		return _ok({ "profile": { "code": p.trim_prefix("profile/") } })
	if p.begins_with("inbox/"):
		return _ok({ "claimed": true })
	return _err(404, "not_found", "Mock has no handler for %s" % p)


func _ok(b: Dictionary) -> Dictionary:
	return { "code": 200, "body": b }


func _err(code: int, err: String, msg: String) -> Dictionary:
	return { "code": code, "body": { "error": { "code": err, "message": msg } } }