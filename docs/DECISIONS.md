# DECISIONS

Log of design/technical decisions taken where the spec (ТЗ) was ambiguous or
where a course had to be chosen. Format: date — question — choice — reason.

## 2026-??-?? — Toolchain (M0)

- **Question:** Godot version to target.
- **Choice:** Follow the installed stable editor (4.7.x), GDScript, Compatibility
  renderer, web export without threads. Spec A1 said "4.4+ / latest stable".
- **Reason:** the project must build with the editor the user actually runs.

## 2026-??-?? — PRNG

- **Question:** random source.
- **Choice:** custom PCG32 (`src/core/pcg32.gd`), 32-bit output, verified against
  the pcg-c-basic reference vectors in `tests/vectors/pcg32.json`.
- **Reason:** cross-platform determinism between client Sim and headless
  server validator (spec §2.4, §14.6). Godot's RNG is not guaranteed identical.

## 2026-??-?? — Base resolution & pixel-perfect

- **Choice:** 480×270, stretch `viewport`, aspect `keep`, integer scale,
  default texture filter Nearest, 2D pixel snapping on.
- **Reason:** spec §2.2.

## 2026-??-?? — Headless test runs and the global class cache

- **Issue:** scripts created outside the editor (by the agent's file tools)
  are not in `.godot/global_script_class_cache.cfg` until the editor rescans,
  so a headless run (`-s ...`) fails with "Could not find type X".
- **Workaround:** run `godot --headless --path . --import` immediately before a
  headless test/validator run (regenerates the cache). The live editor may
  overwrite the cache with a stale list until its window is focused/rescanned.
- **Runner hardening:** `tests/run.gd` skips any script that fails to load
  instead of hanging (a broken script used to abort `_init` before `quit()`).

## 2026-??-?? — Client↔server: cache-backed async reads

- **Decision:** the UI reads through `Net.api_get()`/`cached()` which return the
  last known response synchronously and refresh in the background; a display
  refresh never issues a fetch, so an incoming response triggering a redraw
  cannot cause a request loop. Mutations/bespoke reads use `post()` /
  `post_cached()`.
- **Decision:** guest authentication happens automatically when the client goes
  online; the token persists in `user://auth.json`.
- **Why:** keeps the panels synchronous and simple while still supporting a real
  backend, and keeps the mock as a first-class offline fallback.

## 2026-??-?? — Online by default; cached reads never blank

- **Decision:** a new player starts **online** (`online` defaults to `true` in
  `GameState` and `Net`), so leaderboards / daily / social work immediately.
- **Decision:** `Net.cached()` and `post_cached()` return mock data when no live
  response has arrived yet, so a panel never renders blank (fresh player, or
  backend unreachable).
- **Why:** the previous offline default silently hid every online feature for new
  players, and an empty cache produced blank panels.
- **How to apply:** reads for display go through `cached()`; network failures
  degrade to mock rather than empty.

## 2026-??-?? — Fonts are drop-in and optional

- **Decision:** `ThemeFonts.apply()` (src/ui/theme/fonts.gd) is called from the
  boot scene and the terminal; it looks for `res://assets/fonts/*.ttf` and, if
  found, sets the project theme's `default_font` (anti-aliasing/sub-pixel off for
  pixel crispness). With no fonts it is a safe no-op and the engine default font
  is used.
- **Why:** fonts are third-party (OFL, logged in ASSETS.md) and must not block a
  build; dropping the files in is the only step needed before re-export.
- **How to apply:** expected names — body `PixelifySans-Regular.ttf`, display
  `PressStart2P-Regular.ttf` (candidates listed in the script).

## 2026-??-?? — Save format: full state JSON, models own their serialization

- **Decision:** each model exposes `to_dict`/`from_dict` (Worker, Sector) or
  `to_state`/`load_state` (TerminalGrid, GameState); `GameState` composes the
  run into `SaveSystem.data["state"]` and rebuilds derived state (line, rates,
  tariff) on load rather than persisting it.
- **Decision:** autosave at meaningful boundaries (shift end, hire, upgrade,
  expansion, tree buy, claim, reorg) rather than every frame.
- **Why:** keeps derived values out of the save (no drift), keeps the save
  readable/debuggable, and avoids per-frame disk writes. The spec's
  gzip+base64+checksum wrapper is deferred but slots in over this dictionary.

## 2026-??-?? — M9 settings persistence & autoload order

- **Decision:** `SaveSystem._ready()` loads the save so that every later
  autoload (Loc, GameState) can read persisted settings during its own `_ready`.
  `Loc` applies the saved locale itself; `GameState` owns the settings bag and
  calls `save_settings()` on change.
- **Why:** autoloads initialise in declaration order, so without an early load
  the locale would not apply on startup; keeping the read in SaveSystem makes the
  ordering explicit and avoids fragile cross-autoload calls.

## 2026-??-?? — M9 balance: rank-scaled reputation

- **Bug:** `Shift._finish` called `_rep(grade, 1)`, so reputation gain was flat
  across the whole game and progression was ~4× slower than §8.13 targets. Now
  `Shift.rank` is set by GameState and rep scales as `table * (1 + 0.1*(rank-1))`,
  matching the formula's intent; the base table was raised (S 10→14 … D 0.5→1).
- **Result:** balance bot rank-10 ratio 4.28 → **1.44** (rank 5 at 1.00).
- **Why:** the spec's targets assume an active player using contracts, Rush and
  multiple lines; the greedy single-line bot remains a conservative lower bound.

## 2026-??-?? — M7 deploy: live on the VPS

- **Decision:** deploy as a self-contained compose project `tupik9` in
  `/opt/tupik9/`, exposing `api` on host **127.0.0.1:8095** (the spec's 8090 was
  already taken by another host service), and add a single `include` line to the
  existing `shimmirpgbot.ru` nginx server block. Configs are backed up before the
  change; nginx is applied with `-t` + `reload`, never restarted.
- **Why:** the host runs ~28 unrelated containers; a separate project + one
  include line is the smallest, most reversible footprint (§14.10).
- **Follow-up:** the client is still mock-first. Enabling the live server
  requires adopting the async response path in `Net`/UI, so the UI keeps working
  when offline.

## 2026-??-?? — M9 localization via Loc autoload + data tables

- **Decision:** all user-facing text goes through `Loc.t(key)` backed by
  `data/strings.json` (RU primary, EN secondary); data rows whose `key` is
  itself a localization key (tree nodes) resolve the same way. Keeping strings
  in a JSON table (not Godot .translation/CSV) matches the rest of the data
  layer and is unit-tested for RU/EN parity.
- **Why:** the spec requires keys, RU primary + EN; this avoids scattered
  literals and makes missing translations visible instead of silent.

## 2026-??-?? — M8 competitive: deterministic models, mock-backed UI

- **Decision:** competitive outcomes are pure node-free models (`Duel`,
  `DailyShift`, `Tender`, `Tactics`) run with PCG32 so the client pre-result and
  the headless validator agree to the byte (spec §13.5–13.6, §14.6). Bots stand
  in for opponents until a server is live.
- **Decision:** the World tab talks to the backend only through `Net`, which is
  mock-first, so the whole competitive flow is playable with no server.
- **Why:** keeps PvP/daily honest (server can re-run the exact same Sim) and
  lets the UI be built and tested before deployment.
- **Gotcha:** never name a GDScript param `seed`, `set`, `floor` or `name` —
  they shadow built-ins and warnings are errors (DoD §2.12).

## 2026-??-?? — M7 backend: FastAPI + Postgres + headless validator

- **Stack:** FastAPI + Pydantic v2 + SQLAlchemy 2 + Alembic + PostgreSQL 16,
  matching spec §14.1. `api` binds only `127.0.0.1:8090`; nginx proxies
  `location /tupik9/api/` to it via a single `include` line inside the existing
  `shimmirpgbot.ru` server block (the same pattern as Elevators/ManaCalc).
  Apply with `nginx -t` + `reload`, never restart; never touch other services.
- **Separate compose project** named `tupik9` so the host's ~28 other
  containers are untouched.
- **Validator** is its own container wrapping a headless Godot run of the
  client commit's PCK (`tools/validate.gd`, stdio JSON). Keeping the Sim in one
  codebase avoids client/server drift (§14.6).
- **Router prefix `/v1`** because nginx strips `/tupik9/api/`; the app also
  serves an unversioned `/health` for the docker healthcheck.
- **Sequencing:** scaffold + verify locally first (chosen by the user), deploy
  only on a later explicit confirmation.

## 2026-??-?? — M7 networking: mock-first, pure API layer

- **Decision:** split the network code into pure `RefCounted` layers
  (`Api` = URLs/headers/bodies/parsing/degradation, `Outbox` = idempotency
  queue, `MockBackend` = canned offline responses) and keep only I/O in the
  `Net` autoload. `Net` is mock-first: with no backend it never blocks
  (spec §13.1) and every higher-level call already works.
- **Why:** the whole request/response contract is testable headless with no
  server, and the real HTTPRequest path (8 s timeout, 3 exponential retries)
  can be switched on via `Net.enable_backend()` once a server answers.
- **Backend itself:** a separate work package (FastAPI + PostgreSQL). It is
  blocked on VPS SSH access (§14.10). Contract frozen in `docs/API.md`.

## 2026-??-?? — Fonts

- **Status:** OPEN. Spec §2.2 requires Pixelify Sans + Press Start 2P (OFL) with
  verified Cyrillic coverage. Not yet added (needs font files). Using Godot's
  default font for now; must be replaced before UI milestone M2 is "done".
## 2026-10-29 — Fonts (v0.2 W1)

- **Status:** CLOSED. Pixelify Sans is the single body font for all UI (full Cyrillic). Press Start 2P stays latin-only. `ThemeFonts._tune` disables AA/hinting/subpixel/mipmaps, oversampling=1.

## 2026-10-29 — v0.2 open questions (defaults locked)

- **Q1:** «Погрузка» is the 7th bottom-nav tab (after Terminal). Hotkeys 1–7.
- **Q3:** Canonical species id is `avian`; `ovion` migrates on save load (v1→v2).
- **Q4:** Currency display names stay «Осколки» / «Жетоны» (map to ТЗ Акции/Талоны). Source: `data/currencies.json` + Loc.
- **Q10:** Terminal zoom is integer ×1 / ×2 only.
- **Q11:** Minimap auto-shows when grid exceeds the terminal viewport.
- **Terminal reach root cause (WP-E):** `SectorView` drew cells in screen space with no camera/clip; expansion cells fell under the nav bar. Fix: clip_contents + camera offset + TerminalBounds.

## 2026-10-30 � v0.3 Scale UI: path / API mapping (no duplicates)

- **Question:** TZ v0.3 names `settings.gd`, `i18n/*.csv`, separate `Hud.tscn`/`NavBar.tscn`; repo differs.
- **Choice:** Map, do not duplicate (�2.3):
  - Settings > `SaveSystem.set_setting` / `SaveSystem.settings()` (+ `GameState.save_settings`); key `ui_scale`.
  - i18n > `data/strings.json` via `Loc.t` / new `Loc.tr_s` (no CSV).
  - Hud / NavBar > nodes under `scenes/terminal.tscn` (`VBox/HUD`, `VBox/Nav`); reparent under `UiRoot` in steps 4+.
  - Existing `tools/ui_lint.gd` (raw-id lint) kept; if v0.3 layout lint needs the same path, move old lint to `tools/ui_raw_id_lint.gd` and note here.
- **Reason:** IR-9/IR-10 + �2.3 find existing, don't create duplicate.

## 2026-10-30 � v0.3: git repo was missing

- **Choice:** `git init` locally, branch `feat/ui-scale`. Baseline commit of pre-task tree, then one commit per TZ step (IR-7).
- **Reason:** Step 0 / IR-7 require a branch and per-step commits; only `.gitignore` existed. Remote/origin still open in `QUESTIONS.md` Q-1.
