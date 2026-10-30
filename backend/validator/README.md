# Headless validator

Runs the Godot **Sim** (same commit as the client) to validate competitive
results and to compute `rate_cap` for telemetry (spec §14.6).

- `GET /selftest` — readiness probe.
- `POST /power_estimate` — `{dock, storage, crew, tree}` → `{rate_cap}`.
- `POST /duel` / `POST /daily` / `POST /tender` — run the corresponding Sim mode.

Each request spawns `godot --headless --main-pack /pck/game.pck -s
res://tools/validate.gd <mode>`, writes the JSON payload on stdin and reads the
JSON result from stdout. `tools/validate.gd` lives in the game repository.

Mount the exported PCK of the client commit at `/pck/game.pck`.

Limits (enforced where the backend calls it): 2 s per request, ≤ 4 concurrent
processes, queue ≤ 50 (else the API returns `503 Retry-After`).

Place the PCK under `pck/` locally (gitignored); it is mounted read-only.