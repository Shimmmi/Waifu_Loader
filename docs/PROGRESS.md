# PROGRESS

Tracks milestone status against the plan (spec §18). Update after each step:
what was done, what was verified, what is next.

Legend: [ ] not started · [~] in progress · [x] done.

## Milestones

- [~] **M0 Framework** — settings, structure, docs, autoloads
  (Config/Data/Clock/Rng/SaveSystem/Net), base Theme, boot scene, mock `Net`,
  SaveSystem persistence — all done and verified. Remaining: fonts (Pixelify
  Sans + Press Start 2P, Cyrillic) ⚠ needs font files; Web export + itch.io
  draft ⚠ needs itch account.
- [x] **M1 Core Sim** — PCG32 + Fmt; `Catalog`; `LineSim` (conservation +
  harmonic-mean mix); `Crew` (SI / contrib / class_fit / station power);
  `validate_data.gd` (cargo/balance/classes/species); offline equivalence;
  `tools/sim_cli.gd`; `tools/balance_bot.gd` skeleton; data tables
  cargo/balance/classes/species. **6264 checks green.**
- [~] **M2 Terminal & shift** — Shift loop + `GameState`; Terminal screen with
  HUD (¢/Зч/rank/shift timer/Rush), sector grid, action bar, bottom nav,
  menu→terminal flow; Hire/Crew panels. Remaining: worker sprite markers,
  Auto-shift toggle, shift-report modal.
- [x] **M3 HR** — Worker model, `Rules`, deterministic `Generator` (rarity +
  pity), `HireBoard`, `Synergy`, data tables (rarity/stars/psycho/synergy/
  traits/skills/equipment/names). Hire screen; Crew screen with station slots
  (tap worker → tap slot), per-slot synergy colour highlighting, and a worker
  detail card with skill picks. All verified live.
- [~] **M4 Economy & expansion** — `sectors.json` (13 sectors + 12 modifiers +
  adjacency), `Sector` + `TerminalGrid` (upgrade/expand/adjacency formulas),
  grid-driven line capacities, sector upgrades, expansion, wages paid per shift,
  construction timers, action bar (Причал+/Склад+/Расширить). Progression bot
  `tools/balance_bot.gd` reaches rank 10. **Blocker:** §8.13 rank-time targets
  need contracts/multi-line (M5) — rep-per-shift is the gate, so balance tuning
  continues after M5.
- [~] **M5 Contracts & events** — `clients.json` (24), `contracts.json`
  (tiers/KPI/diffs/rewards), `events.json` (36 cards), `chains.json` (3);
  `Contract`, `ContractBoard`, `EventDeck` models; contracts bound to the line
  (arrival profile, delivered/Q, deadline, KPI grading), events drawn per shift
  (rank ≥ 6) with a banner + choices, timed station/flow modifiers. Contracts
  panel + event banner UI. Verified live at rank 5 (accept → active contract).
  Remaining: chain progression runtime, client relations, tender/urgent flags.
- [ ] M6 Meta
- [ ] M7 Backend + client net
- [ ] M8 Competitive
- [ ] M9 Polish

## Notes

- Server/back-end milestones (M7/M8 server side) and itch.io/VPS deployment are
  blocked on external access (itch account, VPS SSH). Client-side work proceeds
  independently.

## Changelog

### Step 1 — skeleton + core (M0/M1 start)

- Project settings: 480×270 viewport, `viewport` stretch, integer scale,
  aspect keep, nearest texture filter, 2D pixel snapping on.
- `src/core/`: `pcg32.gd` (PCG32), `fmt.gd` (number/time formatting),
  `config.gd`, `clock.gd`, `rng.gd` (named streams) — the latter three registered
  as autoloads Config / Clock / Rng.
- `src/data/data.gd` autoload loads every `data/*.json` into memory.
- `data/`: `version.json`, `currencies.json`.
- `tests/`: `testcase.gd` base, `run.gd` runner, `test_pcg32.gd`,
  `test_fmt.gd`, `vectors/pcg32.json`. **6231 checks green.**
- `scenes/main.tscn` + `src/main.gd`: boot/title placeholder (set as main scene).
- `docs/DECISIONS.md`, `docs/PROGRESS.md`, `assets/ASSETS.md` created.

### Step 2 — M0 theme/save/net + M1 simulation core

- Base `Theme` (`src/ui/theme/game_theme.tres`), set as project default.
- Autoloads `SaveSystem` (JSON local save with a launch counter — verified it
  increments across runs) and `Net` (offline mock; `fetch_time()` syncs `Clock`).
- `data/`: `cargo.json` (7 types with φ + defect), `balance.json` (station
  rates, growth, tariffs).
- `src/sim/catalog.gd` (`Catalog`) — parses cargo/balance into typed arrays;
  provides `free_flow_mix/lambda`, `tariff`, `station_rate`.
- `src/sim/line_sim.gd` (`LineSim`) — full line pipeline with mass conservation
  and the harmonic-mean mixture rule.
- `src/tools/validate_data.gd` — schema + cross-reference checks (green).
- `tests/test_sim.gd` — conservation (incl. overflow), zero-inflow, monotonicity,
  harmonic mean, free-flow mix, tariffs, station rates, offline equivalence.
- `tools/sim_cli.gd` — 8 h headless simulation with conservation check.
- **6255 checks green.** `validate_data` OK.

### Step 3 — M1 finished + M2 shift loop started

- `data/classes.json` (6 classes, weights, class_fit), `data/species.json`
  (5 species, stat multipliers).
- `src/sim/crew.gd` (`Crew`) — skill index, contrib (SI/25), class_fit, station
  power aggregation.
- `src/tools/validate_data.gd` extended for classes/species.
- `tests/test_crew.gd` (9 checks).
- `tools/balance_bot.gd` — steady-state rate per §8.13 checkpoint (skeleton;
  crew power placeholder; early signal shows the high-rank curve needs tuning).
- `src/sim/shift.gd` (`Shift`) + `tests/test_shift.gd` — shift timing, Rush
  (10 s ×1.5, 45 s cooldown), end-of-shift grading S/A/B/C/D and reputation.
- **6264 checks green.**

### Step 4 — M2 visible terminal

- `src/state/game_state.gd` autoload `GameState` — credits/parts/rep/rank, one
  line, per-second shift ticking, rank-up curve, `rush()`.
- `src/view/sector_view.gd` — cross-section placeholder grid drawn in code.
- `src/ui/terminal.gd` + `scenes/terminal.tscn` — HUD (¢, Зч, rank %, shift
  timer, Rush button), sector grid, bottom nav.
- `scenes/main.tscn` rebuilt as a title menu with "Начать смену" → terminal.
- Verified live: menu→terminal click works, shift counts down, no errors or
  warnings. (Editor's live analyzer still shows stale "Identifier not found"
  lines until it rescans — cosmetic, headless is clean.)

### Step 5 — M3 HR core

- Data: `rarity.json` (tiers + agency odds + pity), `stars.json` (12 signs +
  element matrix), `psycho.json` (6 types + symmetric matrix), `synergy.json`
  (class chemistry + friendship), `traits.json` (24), `skills.json` (36),
  `equipment.json`, `names.json` (per-species names + shared pools).
- `src/sim/rules.gd` (`Rules`) — bundles HR data + lookups (star/psycho/chem).
- `src/state/worker.gd` (`Worker`) — spec §6.1 model + derived stats/wage/
  morale/fatigue/xp; `as_crew_entry()` feeds `LineSim`.
- `src/sim/generator.gd` (`Generator`) — deterministic workers, rarity draw
  with pity; `src/sim/hire_board.gd` (`HireBoard`) — deterministic pool + costs.
- `src/sim/synergy.gd` (`Synergy`) — pair value, line synergy, speed/morale.
- `GameState` now holds `rules/generator/board/synergy` + a real `roster`
  (starting crew generated deterministically); station rates use real workers
  and synergy.
- UI: `src/ui/panels/hire_panel.gd` + `crew_panel.gd`; nav switches panels.
- Tests: `test_worker`, `test_generator` (67), `test_synergy` (52). Validator
  extended to all HR tables. **6415 checks green.**

### Step 6 — M4 economy & expansion core

- `data/sectors.json`: sector catalogue (§5.2), 12 modifiers (§5.3), adjacency
  (§5.5), expansion + upgrade constants.
- `src/state/sector.gd` (`Sector`), `src/state/terminal_grid.gd` (`TerminalGrid`):
  placement, `upgrade_cost`/`upgrade_time`, `expand_cost`/`expand_rank_required`,
  deterministic `roll_offers`, adjacency bonuses.
- `GameState` now drives dock/storage capacity + station rates from the grid,
  pays wages each shift, ticks construction, and offers `upgrade_sector` /
  `expand_offers` / `apply_expansion`.
- Terminal UI: real sector grid + action bar (Причал+/Склад+/Расширить),
  verified live (dock+storage → L2, credits 200→65).
- `tools/balance_bot.gd` rebuilt as a greedy progression sim; reaches rank 10.
- Tests: `test_sectors.gd` (30). **6445 checks green.** Validator covers 15 tables.

### Step 7 — deferred M2/M3 UI

- `GameState`: explicit per-station slots (unload×3, move×2, store×2, support×2),
  `assign`/`clear_slot`/`auto_assign` + skill pick/eligibility; station power and
  line synergy use assigned slots.
- Crew screen rebuilt: slot rows, tap worker → tap slot (spec §15.7), empty slots
  tint green/red by synergy change, worker detail card (stats/traits/star/
  psycho/skills/equipment) with skill-pick buttons.
- Hire/Crew in ScrollContainers; action bar hidden off the terminal tab.
- Verified live: select (green highlight) + move Галка unload0 → unload2.
- **6445 checks green.**

### Step 8 — M5 contracts & events core

- Data: `clients.json` (24 clients/quirk), `contracts.json` (5 tiers, KPI types,
  4 difficulties, reward/penalty), `events.json` (36 cards), `chains.json` (3).
- `src/sim/contract.gd` (`Contract`) + `src/sim/contract_board.gd`
  (`ContractBoard`): deterministic offers, tier-by-rank, KPI grading
  gold/silver/bronze/fail.
- `src/sim/event_deck.gd` (`EventDeck`): weighted eligibility + draw.
- `GameState`: contracts bound to the line (arrival profile, delivered/Q,
  deadline, rewards/penalties, restore free flow), events drawn at shift start
  (rank ≥ 6) with timed station/flow modifiers, effect application
  (morale/credits/parts/rep/fatigue/mod/status/sector-break/worker-gain).
- UI: Contracts panel (offers + accept + active progress) and an event banner
  with choice buttons.
- Tests: `test_contracts.gd` (52), `test_events.gd` (243). **6740 checks green.**
- Verified live (rank 5): board offers + accept → active contract shown.

### Step 9 — M6 meta core

- Data: `achievements.json` (41), `elevator.json` (12 milestones), `tree.json`
  (3 branches × 8 = 24 nodes), `cosmetics.json` (skins/frames/titles/banners/
  avatars), `directives.json` (linear 20 + daily 12 + weekly 12).
- Models: `Meta` (shares/rep formulas), `CorporateTree` (cost `base·1.6^lvl`,
  aggregate effects), `Elevator` (milestone completion + band progress),
  `Achievements` (condition vs stats), `Directives` (deterministic draw).
- `GameState`: tokens/shares/tree_levels/achievements_done/lifetime_tonnes/
  run_tonnes/reorg_count/counters, `achievement_stats()` snapshot,
  `_check_achievements()` (token + cosmetic rewards), `buy_tree_node`,
  `tree_effect` wired into rates/income/flow, `do_reorg()` (prestige),
  elevator helpers. Lifetime tonnes accrue at each shift end.
- UI: **Меню** tab (elevator progress, tokens/shares, achievements count,
  tree nodes with Buy buttons, Reorganisation button).
- Tests: `test_meta.gd` (26). **6766 checks green.**
- Verified live: tree node bought (TREE_CLEARING L0→L1, cost 2→4 Ш,
  shares 20→18), panel renders.

### Step 10 — M7 client networking (backend contract)

- `src/net/api.gd` (`Api`): URL/header building (`X-Client-Version`,
  `X-Sim-Version`, `Authorization`, `Idempotency-Key`), request-body builders,
  error-envelope parsing, degradation classes (401/426/409/retry), exponential
  backoff, telemetry pre-check, save-conflict preference.
- `src/net/outbox.gd` (`Outbox`): idempotency-keyed mutation queue, dedupe,
  serialization for the save file.
- `src/net/mock_backend.gd` (`MockBackend`): deterministic offline responses for
  every endpoint used so far.
- `src/net/net.gd` (autoload `Net`) rewritten: mock-first router, `/config` +
  `/time` fetch, `Clock` sync, `user://auth.json` token storage, `post()` /
  `send_telemetry()`, dormant HTTPRequest path (8 s timeout, 3 retries).
- `docs/API.md`: frozen client↔server contract for the backend agent.
- Tests: `test_net.gd` (48). **6814 checks green.**
- Verified: terminal + main boot clean with the new Net.

### Step 11 — M7 backend scaffold (FastAPI + Postgres + validator)

Local-only scaffold under `backend/` (deploy is a later, confirmed step):

- `app/main.py` FastAPI app: CORS (§14.2), uniform error envelope, global
  client-version gate (426), `/health`; all endpoint groups mounted under `/v1`
  (nginx strips `/tupik9/api/`).
- `app/models.py` — full ORM per §14.4 (players, saves, progress_windows,
  board_entries, profiles, friends, unions*, pvp_*, daily_*, global_*, inbox,
  reports, idempotency_keys). `app/schemas.py` — Pydantic v2 request models.
- Routers: common, auth (guest/recover/rename/me/delete), save (optimistic
  revisions + 409 conflict), telemetry (seq/window/rate validation + shadow
  hold + global-goal feed), boards, profile (+respect), friends, daily, tender,
  pvp, unions, global_goal, inbox (+report).
- `app/validator.py` + `validator/` container (FastAPI wrapper over a headless
  Godot run); `tools/validate.gd` in the game repo implements the stdio modes
  (`power_estimate|duel|daily|tender`). Verified: `power_estimate` → `rate_cap`.
- `app/scheduler.py` (APScheduler, §14.7), `app/manage.py` (admin CLI),
  Alembic (`migrations/`), `Dockerfile`, `docker-compose.yml` (api on
  `127.0.0.1:8090`, db, validator), `nginx.conf.snippet` (drop-in include).
- Verified: all modules `py_compile`; imports clean (**54 routes**); OpenAPI
  generated; `/health`, `/v1/config`, `/v1/time` → 200; unauth `/v1/save` → 401
  envelope; old client → 426.

Deploying this (copy to `/opt/tupik9`, `docker compose up`, nginx `-t`+reload)
is a separate confirmed step (§14.10) — the client already runs on the mock.

### Step 12 — M8 competitive core (client surfaces)

- Models (node-free, deterministic): `Tactics` (Cup tactics + counter cycle),
  `Duel` (3v3 arena, league caps, counter bonus, Elo delta, replay),
  `DailyShift` (fixed preset: 6 slots, 8 temp employees, seed KPI),
  `Tender` (rule-of-the-week modifiers).
- `Net.api_get()` + mock routes for `global`, `boards/{id}/me`, `daily`,
  `daily/submit`, `tender`, `pvp/me`, `pvp/attack`, `unions`, `friends`.
- UI: **Мир** tab (`world_panel.gd`) — elevator-build progress, weekly board
  rank, Daily Shift (run + submit), Cup duel (vs bot), union create, friends.
- Tests: `test_competitive.gd` (22). **6836 checks green.**
- Verified live: World tab renders; Daily Shift → **3520 очков (отправлено)**;
  Cup → **win 909:762**; elevator «этап 1/10 — 0%».

Remaining M8: Daily Shift assignment UI (6 slots), Cup opponents/brigade
selection + replay playback, union/friends screens, lobby/league boards.

### Step 13 — M9 localization & settings (polish)

- `data/strings.json` — RU/EN tables (~70 keys: nav, HUD, actions, menu, world,
  tree node names).
- `src/core/loc.gd` (autoload `Loc`): `t(key, args)`, `set_locale`,
  `locale_changed`, RU fallback, visible-key-on-missing.
- Terminal / Menu / World panels now render through `Loc.t`; switching RU↔EN
  retranslates nav, HUD, action buttons and panels live.
- Menu gains a **Settings** section: language toggle, sound on/off, anonymous
  stats toggle, plus Privacy and Help text (accessibility-friendly autowrap).
  `GameState` holds `locale`/`muted`/`anon_stats`.
- Tests: `test_loc.gd` (222). **7058 checks green.**
- Verified live: Menu shows localized tree names; clicking RU switches the whole
  UI to English.

Remaining M9: audio hooks, tutorial/FTUE, EN coverage for data keys, full balance
pass, web-export matrix, itch.io page (export/itch need the user).

### Step 14 — M7 deploy: backend LIVE on the VPS

- `/opt/tupik9/` (compose project `tupik9`): `api` on host **127.0.0.1:8095**
  (spec's 8090 was occupied by another host service), `db` (postgres:16-alpine).
  `validator` defined but not started (needs an exported game PCK).
- `.env` written with a random SECRET_KEY; `alembic upgrade head` ran
  (0001_initial).
- nginx: one `include /opt/tupik9/nginx.conf.snippet;` line added to the
  `shimmirpgbot.ru` server block; applied with `nginx -t` + `reload`. Original
  config backed up to `/root/tupik9-backup/`.
- **Verified public:** `GET /tupik9/api/v1/health` → 200, `/config` → 200,
  `/time` → 200, unauth `/save` → 401 envelope, old client → 426, CORS preflight
  from `https://itch.io` → 204. Neighbour apps (`/elevators/` → 200, `/` → 302)
  untouched.

The client still runs **mock-first**; wiring it to the live server needs the
async response path adopted in the UI (next step).

### Step 15 — M8 extras (World surfaces)

- `world_panel.gd` restructured: leaderboard status + board list at the top,
  then the interactive strips, so controls are reachable without deep scrolling.
- **Daily Shift assignment UI**: six slot buttons cycling the eight temp
  employees (empty → loader 30 → … → empty), plus a Run button that scores the
  chosen assignment and submits it.
- **Cup**: three brigade slots cycling the roster, a tactic cycler
  (assault/meticulous/balance), a Fight button (vs a bot brigade, uses `Duel`),
  and a replay-step label.
- **Union/Friends** buttons; **board list** line.
- New RU/EN keys for slots, brigade, tactic names, replay.
- Tests still green: **7097 checks** (15 files).
- Verified live: World tab shows the elevator bar, board rank, board list and
  the Daily assignment strip cycling slots.

Remaining depth: Cup opponent list, replay *playback* animation, scrolling the
full leaderboard, friend-code entry, union member/donation screens.

### Step 16 — M5/M6 extras (chains, relations, directives, shop)

- `src/sim/chain_runtime.gd` (`ChainRuntime`) — per-chain step machine with
  explicit `next` jumps; `start`/`advance`/`is_finished`.
- `src/sim/relations.gd` (`Relations`) — 0..100 client relations, grade deltas,
  tiers (hostile/neutral/friendly/ally), reward bonus.
- `src/sim/directive_board.gd` (`DirectiveBoard`) — active linear + daily +
  weekly goals, progress from reported stats, one-shot claims.
- `src/sim/shop.gd` (`Shop`) — cosmetics catalog, buyable-cost check, equip.
- `GameState`: owns all four; chains auto-start at ranks 6/8/12 and surface as
  events (choices advance the chain, `chains_done` bumped); contract grades
  shift client relations; actions report stats to the directive board
  (`hires`, `shifts_total`, `upgrades`, `expansions`, `rushes`, `grade_s`,
  `contracts_done`, `gold_contracts`, `reorg_count`); `claim_directive()` pays
  credits/rep/tokens.
- UI: **Menu** now lists **Директивы** (name + progress + Забрать) and a
  **Магазин** (per-category item cycler + Купить/Надеть, shows owned).
- Strings: directive names (44 keys). Tests: `test_progress.gd` (40).
  **7287 checks green.**
- Verified live: Menu shows localized directives with progress and claim buttons.

### Step 17 — M8 depth (Cup opponents, replay playback, boards, social)

- **Cup opponents**: list drawn from `pvp/opponents` (mock returns 3), each a
  button showing nickname + rating; the selection is sent with the attack.
- **Replay playback**: a `Timer` steps through `Duel`'s replay array, showing
  «Повтор n/N · kind» per tick.
- **Board selector**: cycles `tonnes_weekly / tonnes_alltime / best_tpm_weekly /
  gold_weekly / reorg_alltime`, refreshing entries count and the "Вы" line
  (distinct text from the button so taps hit the button).
- **Social**: a friend-code `LineEdit` + request button, and a union donate
  button showing union info/fund.
- Mock routes added: `pvp/opponents`, `unions/{id}`, `unions/{id}/donate`.
- Strings added in RU/EN. Tests: **7314 checks green.**
- Verified live: World tab renders the elevator bar, board selector (cycles
  boards), and the Daily assignment strip.

### Step 18 — M9 polish (audio, tutorial, EN data keys, balance)

- **Audio** (`src/core/audio.gd`, autoload): creates SFX/Music buses, an 8-voice
  player pool, a name→stream registry, and mute-aware `play_sfx`/`play_music`.
  With no audio files present everything is a silent no-op. Hooks: rush, hire,
  shift end.
- **Tutorial/FTUE** (`src/ui/tutorial.gd` + a node in `terminal.tscn`): a 5-step
  overlay shown once (`GameState.tutorial_seen`), RU/EN, Далее/Пропустить.
- **EN data keys**: cargo (7), classes (6), species (5) localized in RU/EN.
  RU/EN parity still enforced by `test_loc`.
- **Balance pass**: fixed a real bug — shift reputation ignored rank
  (`_rep(grade, 1)`); now `Shift.rank` is set by GameState and the rep table was
  raised (S 10→14 … D 0.5→1). The balance bot now hits: rank 5 **1.00×**,
  rank 8 1.18×, rank 10 **1.44×** target (was 4.28×), reaching rank 13 in 8 h.
  The bot still ignores Rush/contracts/multi-line, so real play is faster.
- Verified live: the tutorial overlay appears on first run and advances.
  Tests: **7392 checks green**; validator OK.

### Step 19 — Persist settings through SaveSystem

- `SaveSystem` now calls `load_save()` in `_ready` (so later autoloads can read
  settings) and exposes `settings()` / `set_setting()` over a `settings` bag.
- `Loc._ready` applies the saved locale; `GameState._load_settings()` reads
  locale/muted/anon_stats/tutorial_seen, and `save_settings()` writes them back
  and stores.
- Menu toggles (language/sound/stats) and the tutorial's finish now call
  `save_settings()`.
- Menu reordered so language/sound/stats sit at the **top** (reachable without
  scrolling); help/privacy stay lower.
- Verified: switching to EN wrote `settings.locale="en"` and
  `tutorial_seen=true` to `user://save_main.json`; a fresh launch booted in
  English with the tutorial already dismissed.

### Step 20 — Full player-state save

- Serialization added to the models: `Worker.to_dict/from_dict`,
  `Sector.to_dict/from_dict`, `TerminalGrid.to_state/load_state`.
- `GameState.to_state()/load_state()` cover credits, parts, rep, rank, roster,
  slots, grid/expansions, meta (tokens, shares, tree levels, achievements done,
  lifetime/run tonnes, reorg count, counters, cosmetics), relations, chain
  progress and directive board state. Derived state (line, rates, tariff) is
  rebuilt and a fresh shift starts on load.
- Autosave (`save_game()`) on: shift end, hire, upgrade, expansion, tree-node
  buy, directive claim, reorg. Save is loaded automatically at startup.
- Tests: `test_save.gd` (18) covers Worker/Sector round-trips.
  **7410 checks green.**
- Verified live: upgrading the dock (credits 200→125, dock L2) then relaunching
  restored **credits 125 and dock L2** exactly.

### Step 21 — Client wired to the live backend

- `Net` async response cache: `api_get()` returns the last known value and
  triggers a background fetch; `cached()` is display-only (no fetch, so a
  response-triggered refresh cannot loop); `post_cached()` for POST-shaped reads.
  `response_received` drives UI re-render; the World panel re-fetches every 30 s
  and right after guest auth.
- **Online/offline toggle** in the Menu (`Сеть: онлайн/оффлайн`), persisted.
- **Guest auth** (spec §13.2) on going online; token saved to `user://auth.json`.
- Fixed a contract mismatch: `pvp/opponents` is POST (client sent GET → 405).
- `tools/net_probe.gd` added as an HTTP diagnostic.
- Verified against the LIVE server (docker logs): `auth/guest`, `global`,
  `boards`, `boards/*/me`, `daily`, `friends`, `pvp/me`, `pvp/opponents` → **200**.
  Tests: **7419 checks green.**

### Step 22 — Go-live prep

- **Web export preset created** (`export_presets.cfg`): platform Web,
  `variant/thread_support=false` (spec §16), output `build/web/index.html`,
  `all_resources`. Export currently blocked only by the missing 4.7.2 templates
  (`web_nothreads_debug/release.zip`) — machine only has `4.5.1.stable.mono`.
- **Localization**: added RU+EN names for all **24 clients** (`CLI_*`), completing
  the client data-key group. `data/strings.json` now **196 keys** per locale.
- Remaining to ship: export templates, `assets/fonts/` (user), optional
  `assets/audio/*.ogg`, itch.io upload (user), then pin the itch `Origin` in CORS.
- Tests: **7491 checks green**; validator OK.

### Step 23 — Web build produced

- Installed the **4.7.2 export templates** (extracted only `web_nothreads_*` +
  `web_*` from the official 1.28 GB tpz into the user template dir).
- **Export succeeded**: `build/web/` = `index.html`, `index.js` (280 KB),
  `index.wasm` (39.5 MB), `index.pck` (265 KB), worklets + icons. Preset uses
  `variant/thread_support=false`; `exclude_filter` drops tests/tools/docs/backend/info.
- Packaged `build/tupik9-web.zip` (**9.9 MB**) ready for itch.io HTML upload.
- **Verified the exported pack** by running the native binary against
  `build/web/index.pck`: boots clean — `client v0.0.1 · sim v1.0`, `data tables: 25`,
  **`net: live`**, **`clock synced: true`** (reached the live backend from the export).
- Still user-side: fonts → `assets/fonts/`, then re-export; itch page + upload;
  pin the itch `Origin` in CORS after the first online play.

### Step 24 — Release-readiness defaults

- **Online by default** for new players: `GameState.online` and `Net` now default
  to `true`, so leaderboards / daily / social work out of the box (previously a
  fresh player started offline). Verified: with **no save file**, boot prints
  `net: live` + `clock synced: true` (dev save moved aside, then restored).
- **Never-blank UI**: `Net.cached()` / `post_cached()` fall back to mock data when
  no live response has arrived yet (fresh player or backend unreachable), per
  §13.1 offline-safe / §13.13 cached view.
- **CORS pre-checked**: the live backend regex
  `^https://([a-z0-9-]+\.)*(itch\.io|itch\.zone|hwcdn\.net)$` already allows
  `itch.io`, `html-classic.itch.zone` and `*.hwcdn.net`, so the itch iframe needs
  no extra pinning (kept as a post-launch confirmation).
- **Web build rebuilt** with these changes: `build/web` + `build/tupik9-web.zip`
  (9.9 MB). Pack smoke test: `net: live`, `clock synced: true`.
- Tests: **7491 checks green.**

### Step 25 — Fonts are drop-in

- New `src/ui/theme/fonts.gd` (`ThemeFonts.apply()`): applies
  `res://assets/fonts/PixelifySans-Regular.ttf` to the project theme when present
  (anti-aliasing/sub-pixel off), otherwise a safe no-op. Called from `main.gd`
  and `terminal.gd`; `main.gd` prints `font: pixel|default`.
- Verified both paths: with a TTF in `assets/fonts/` → `font: pixel`; after
  removing it → `font: default` (test font cleaned up, dir empty).
- `assets/ASSETS.md` documents the exact filenames + OFL links.
- New `tests/test_fonts.gd` (7 checks). Total **7498 checks green**, 18 files.
- Web build re-exported; pack smoke test `net: live`, `font: default` (no fonts
  shipped yet).

### Step 26 — Bundled fonts (OFL)

- Fetched the two OFL fonts from **google/fonts** into `assets/fonts/`:
  `PixelifySans-Regular.ttf` (body) and `PressStart2P-Regular.ttf` (display).
  Logged with author/license/link in `assets/ASSETS.md`.
- **Cyrillic verified before use** (`has_char` for `А`, `Я`, `ё` → true on both),
  since RU is primary and a missing glyph would tofu the whole UI.
- `tests/test_fonts.gd` updated to the bundled-font reality (17 checks): presence,
  Cyrillic coverage, theme default_font is set, pixel tuning applied.
- **Visually verified live**: terminal renders `Терминал / Бригада / Найм /
  Контракты / Мир / Меню`, `Смена 04:58`, `Рывок`, `Причал L2 +112.5` in the pixel
  font, no tofu. Engine logged "Pixel font detected, disabling subpixel positioning".
- Web build re-exported: `index.pck` 265→361 KB, `build/tupik9-web.zip` **10.0 MB**;
  pack smoke test now `font: pixel`, `net: live`.
- Total **7508 checks green** (18 files).
- Only remaining go-live step: itch.io upload + post-launch `Origin` confirmation.

### Step 27 — itch CORS pre-verified

Tested the LIVE backend with real preflight + GET requests:
`html-classic.itch.zone`, `html.itch.zone`, `itch.zone`, `itch.io` all receive
`Access-Control-Allow-Origin: <origin>` (preflight 204, GET 200); a foreign origin
(`evil.example.com`) receives no ACAO header, so the browser blocks it. The itch
iframe origin therefore needs no further pinning after upload.

### Step 28 — Localization completed (all data keys)

- Found and filled every remaining unlocalized data key across all tables:
  **events (36)**, **achievements (41)**, currencies (6), rarity (5), psycho (6),
  zodiac stars (12), elevator floors (12), contract difficulties (4), chains (3),
  skills (36), traits (24), sectors (13), sector modifiers (12), cosmetics (40).
- `data/strings.json` is now **446 keys per locale**, RU/EN **symmetric**, with a
  recursive scan reporting **0 missing** keys anywhere in `data/`.
  (Literal choice labels `A`/`B` are intentionally excluded.)
- Visually confirmed: the Menu renders `Осколки / Жетоны`,
  `Космический лифт: 0/12 · след. 10K т (0%)`, `Достижения: 0/41`, `Настройки`,
  `Звук: вкл`, `Анонимная статистика: вкл`, `Сеть: онлайн` — no raw keys.
- Web build re-exported (`index.pck` 361→381 KB, zip **10.0 MB**); pack smoke test
  `font: pixel · net: live`.
- Tests: **8258 checks green** (18 files); validator OK.

### Step 29 — Pre-launch balance check (no changes)

`tools/balance_bot.gd` (greedy, **does not model contracts**, so these are
pessimistic upper bounds) against §8.13 "active" targets:

| Rank | reached | target | ratio |
| --- | --- | --- | --- |
| 2 | 600s | 300s | 2.00 |
| 3 | 900s | 720s | 1.25 |
| 5 | 1500s | 1500s | 1.00 |
| 8 | 3900s | 3300s | 1.18 |
| 10 | 7800s | 5400s | 1.44 |

Reaches rank 13, 4.7K credits at t=28800s. No balance changed — the rank-2 ratio
is the item to watch (a new player's first rank-up). Noted for a balance pass.
- `docs/ITCH_PAGE.md` added: ready-to-paste itch title/short/long description
  (RU+EN), tags, content warning, publish checklist, and the post-publish
  log-verification command.
### v0.3 Scale UI � Step 0

- Branch `feat/ui-scale` (local `git init`; see QUESTIONS Q-1).
- Created `docs/QUESTIONS.md`, `docs/FOUND_ISSUES.md`; path mapping in `DECISIONS.md`.
- Status: done. Prompts file still missing (Q-1).

### v0.3 Scale UI � Step 1

- Golden S1 screenshots in `tests/golden/ui_scale/s1/` (9 screens, 480?270).
- `docs/UI_INVENTORY.md` with live metrics; S1 fact vs TZ: nav_h 25, toolbar_h 41, btn_h 25, pad 6, gap 2, bar_h 8, scroll_w 12.
- Status: done.

### v0.3 Scale UI � Step 2

- Proto `tmp/ui_scale_proto.tscn`: UiRoot.scale=s, NEAREST, mouse_filter IGNORE.
- Desktop: crisp pixel doubling; btn counter; world `_unhandled_input`; scroll wheel; no console errors/warnings.
- Web export (proto as temporary main): load OK; 1?>2?; btn click increments.
- Screenshots `docs/screens/ui_proto_s{1,2,3}.png`. Scene deleted after gate.
- Status: done (gate passed).
