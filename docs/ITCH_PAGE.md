# itch.io publishing kit — «Космо-грузчицы» (tupik9)

Everything below is ready to copy-paste. The only file you upload is
`build/tupik9-web.zip` (10.0 MB).

---

## 1. Project settings

| Field | Value |
| --- | --- |
| Title | `Космо-грузчицы` |
| Project URL | `tupik9` (→ tupik9.itch.io/...) or `kosmo-gruzchitsy` |
| Kind of project | **HTML** |
| Upload | `build/tupik9-web.zip` |
| ☑ This file will be played in the browser | **tick this** |
| Viewport / embed | leave default (game is 480×270, scales to fit) |
| Mobile friendly | optional — works, but designed for desktop |

## 2. Short description (itch "Short description / tagline")

**RU:**
> Пиксельный идл-симулятор грузового терминала в тупике девятого сектора: смены, бригада, контракты, лифт на орбиту.

**EN:**
> A pixel idle-sim of a cargo terminal stuck in Sector Nine: shifts, crew, contracts, and an elevator to orbit.

## 3. Description (itch long description)

```markdown
# Космо-грузчицы

Пиксельный идл/менеджмент про грузовой терминал, застрявший в тупике девятого сектора.
Вкалывай смены, собирай бригаду, бери контракты, качай лифт до орбиты — и постарайся,
чтобы этот тупик стал твоим трамплином.

## Что внутри
- **Смены и «Рывок»** — разгружай линии, ловите оценку S и держите поток.
- **Бригада** — найм, редкости, синергии, характеры, звёздные знаки и навыки.
- **Экономика** — причал, склад, расширение секторов, апгрейды, зарплаты.
- **Контракты и КПЭ** — 5 тиров, 4 сложности, отношения с 24 клиентами, цепочки событий.
- **Мета** — 41 достижение, 12 этажей лифта, корпоративное древо, реорганизация.
- **Онлайн** — таблицы лидеров, ежедневная смена, кубок бригад, тендеры, профсоюз, друзья
  (игра работает и полностью офлайн).
- **Юмор 18+** — производственный, без эротики.

## Языки
Русский (основной) и English — переключается в **Меню → Настройки**.

## Управление
Мышь. Всё — кнопки и вкладки: Терминал · Бригада · Найм · Контракты · Мир · Меню.

## Технически
Godot 4, 480×270, пиксель-арт, веб-сборка без потоков. Прогресс сохраняется локально,
онлайн-фичи подключаются автоматически.
```

**EN version of the description:**

```markdown
# Cosmo Loaders

A pixel idle/management game about a cargo terminal stuck at the dead end of Sector Nine.
Work shifts, build a crew, take contracts, and push the elevator to orbit — try to make
this dead end your launchpad.

## Inside
- **Shifts & Rush** — clear the lines, chase an S grade, keep the flow.
- **Crew** — hiring, rarities, synergies, personalities, zodiac signs and skills.
- **Economy** — dock, storage, sector expansion, upgrades, wages.
- **Contracts & KPIs** — 5 tiers, 4 difficulties, relations with 24 clients, event chains.
- **Meta** — 41 achievements, a 12-floor elevator, a corporate tree, reorganization.
- **Online** — leaderboards, daily shift, cup duels, tenders, union, friends
  (the game is fully playable offline too).
- **18+ humour** — workplace, not erotic.

## Languages
Russian (primary) and English — switch in **Menu → Settings**.

## Controls
Mouse only. Everything is buttons and tabs: Terminal · Crew · Hire · Contracts · World · Menu.

## Tech
Godot 4, 480×270, pixel art, threads-free web build. Progress saves locally;
online features connect automatically.
```

## 4. Genre & tags

- **Genre:** Simulation · **Sub-genre:** Management (Idle also fits)
- **Tags:** `idle`, `management`, `pixel-art`, `godot`, `sci-fi`, `tycoon`,
  `singleplayer`, `multiplayer`, `2d`, `funny`, `russian`

## 5. Content warnings

- **Mature content** — tick **Sexual themes / humour** if itch asks; the humour is
  workplace innuendo, no explicit content.

## 6. Publish checklist

- [ ] Create project: kind **HTML**.
- [ ] Upload `build/tupik9-web.zip`.
- [ ] Tick **"This file will be played in the browser"**.
- [ ] Paste the title + short + long description above.
- [ ] Add genres, tags, content warning.
- [ ] Set the page to **Public**.
- [ ] Open the game once, then confirm the backend saw the request (see below).

## 7. After publishing — verify the live client

Play once, then on the VPS:

```bash
ssh rocketcloud-vps 'cd /opt/tupik9 && docker compose logs api --since 10m | grep -E "GET /v1|POST /v1" | tail -20'
```

Expected: `/v1/health`, `/v1/config`, `/v1/time`, `POST /v1/auth/guest` (200) and then
`/v1/global`, `/v1/boards/*` (200). CORS for `html-classic.itch.zone` is already verified,
so browser requests should go through without any config change.