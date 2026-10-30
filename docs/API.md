# Backend API contract — «Космо-грузчицы» (tupik9)

Status: **client side implemented (M7, offline mock-first).** The server itself
(FastAPI + PostgreSQL on the VPS) is a separate work package and is **blocked on
SSH access to the VPS** (spec §14.10). This document is the frozen contract the
client already speaks; the backend agent implements it.

- Base URL: `https://shimmirpgbot.ru/tupik9/api/v1`
- Reference spec sections: §13 (multiplayer), §14 (backend), §17 (tests).

## 1. Transport & headers

Every request carries:

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `X-Client-Version` | `data/version.json:client_version` (e.g. `0.0.1`) |
| `X-Sim-Version` | `data/version.json:sim_version` (e.g. `1`) |
| `Authorization` | `Bearer <token>` (once authenticated) |
| `Idempotency-Key` | 16 hex chars on every mutation (safe retries, 48 h replay) |

- Timeout 8 s, 3 retries with exponential backoff (`2^n` s, cap 300 s). No
  network condition ever blocks the game (spec §13.1).
- CORS `allow_origin_regex`: `^https://([a-z0-9-]+\.)*(itch\.io|itch\.zone|hwcdn\.net)$`
  plus `https://shimmirpgbot.ru` and `http://localhost:*`. Methods
  `GET/POST/PUT/DELETE/OPTIONS`; allowed headers as above. **The backend agent
  must confirm the real itch.io `Origin` from the logs after the first upload
  and pin it.**
- Error envelope: `{"error":{"code":<str>,"message":<str>}}`.
- Body ≤ 1 MiB (save ≤ 600 KiB). Standard rate limit 60 req/min per token.
- `GET /config` → `{min_client_version, sim_versions_supported, global_scale,
  features}`. A client below `min_client_version` gets **426**.

## 2. Endpoints (spec §14.5)

| Group | Methods & paths | Limit |
| --- | --- | --- |
| Common | `GET /config`, `GET /time`, `GET /news`, `GET /health` | 60/min |
| Account | `POST /auth/guest`, `POST /auth/recover`, `POST /auth/rename`, `POST /auth/recovery-code`, `GET /me`, `DELETE /me` | 10/h |
| Save | `GET /save`, `PUT /save` | 12/h per PUT |
| Telemetry | `POST /telemetry/progress` | 1 / 30 s |
| Leaderboards | `GET /boards`, `GET /boards/{id}`, `GET /boards/{id}/me` | 30/min |
| Profile | `GET /profile/{code}`, `PUT /profile`, `POST /profile/{code}/respect` | 20/min |
| Friends | `GET /friends`, `POST /friends/request`, `POST /friends/{id}/accept`, `DELETE /friends/{id}`, `POST /friends/{id}/gift` | 30/min |
| Daily Shift | `GET /daily`, `POST /daily/submit` | 6/day |
| Tender | `GET /tender`, `POST /tender/submit` | 3/week |
| Cup (PvP) | `GET /pvp/me`, `PUT /pvp/defense`, `POST /pvp/opponents`, `POST /pvp/attack`, `GET /pvp/history`, `GET /pvp/ladder` | attack 10/min |
| Unions | `GET/POST /unions`, `GET/PUT /unions/{id}`, `POST /unions/{id}/join`, `/leave`, `/invite`, `/donate`, `/upgrade`, `GET/POST /unions/{id}/board`, `POST /unions/{id}/members/{pid}/role`, `/kick` | 30/min |
| Elevator build | `GET /global` | 30/min |
| Inbox | `GET /inbox`, `POST /inbox/{id}/claim` | 30/min |
| Reports | `POST /report` | 10/day |

## 3. Key payloads

```jsonc
// POST /auth/guest  → {player_id, token, nickname, recovery_code?}
{ "client_version": "0.0.1", "locale": "ru" }

// PUT /save  → 200 {revision}  |  409 {revision, server_meta}
{ "base_revision": 7, "save_b64": "<gzip+base64>",
  "meta": { "lifetime_t": 1234567, "prestige_count": 2, "rank": 14,
            "playtime_s": 12000, "schema_v": 1 } }

// POST /telemetry/progress  → {accepted, hold, server_time, global:{stage,progress}}
{ "seq": 412, "window_start": 1767000000, "window_end": 1767000090,
  "delta_tonnes": 840.5, "best_tpm": 12.3, "gold_count": 0, "shifts": 1,
  "power_snapshot": { "dock": [14], "storage": [9],
                      "crew": [{"c":"loader","lv":18,"r":2}], "tree": {"L1": 4} } }

// POST /daily/submit (validated by the headless validator, §13.5)
{ "daily_seed": "...", "assignment": [...], "event_choices": [...],
  "mode": "x1|x4|instant", "rush_times": [...] }

// POST /pvp/attack  → {result, scores, rating_delta, passes_left, replay[]}
{ "opponent_id": "p_8fk2", "tactic": "assault" }
```

Server-side validation of telemetry (spec §13.4): `seq` strictly increasing;
window ≤ 15 min; `delta_tonnes ≤ rate_cap × window_s/60 × 1.25 + 50`;
`best_tpm ≤ rate_cap × 1.1`. `rate_cap` comes from the headless
`power_estimate`. Failing packets go to **shadow-hold** (not shown in public
boards, no error to the player).

## 4. Headless validator (spec §14.6)

Container `validator` bundles a headless Godot binary and the project PCK **of
the same commit** as the client. Interface `tools/validate.gd`: reads JSON on
stdin, writes JSON on stdout. Modes `duel`, `daily`, `tender`, `power_estimate`.
Limits 2 s / 256 MiB / ≤ 4 processes / queue ≤ 50 (else `503 Retry-After`).
`sim_version` from `data/version.json`; the server keeps the last two versions.

## 5. Client status (what already works offline)

- `src/net/api.gd` (`Api`) — URL/headers, request bodies, error envelope,
  degradation classes (401 reauth / 426 update / 409 conflict / retry),
  backoff, telemetry pre-check, save-conflict preference.
- `src/net/outbox.gd` (`Outbox`) — idempotency keyed queue, persisted in the save.
- `src/net/mock_backend.gd` (`MockBackend`) — deterministic offline responses
  for every endpoint used so far.
- `src/net/net.gd` (autoload `Net`) — mock-first router + dormant HTTPRequest
  path (8 s timeout, 3 retries), token storage in `user://auth.json`, `/time`
  syncing `Clock`, `/config` fetch.
- Tests: `tests/test_net.gd` (48 checks) cover the API layer, outbox dedupe /
  serialization, and the mock backend.

## 6. Deployment prerequisites (blocked)

1. SSH access to the VPS as user `deploy` (key, non-root), working only in
   `/opt/tupik9/` and docker project `tupik9` (spec §14.10).
2. Before any change: `nginx -t`, config backup, list of running containers.
   Do **not** touch the owner's existing services (`/elevators/`, bots).
3. nginx: separate `conf.d/tupik9.conf`, applied via `nginx -t` + `reload`.
4. Docker Compose services: `api` (host **127.0.0.1:8095**; spec's 8090 was
   already occupied on this host), `db`, `validator`, `cron`.