# UI_INVENTORY (S1 baseline, TZ v0.3 step 1)

Снято с живого `scenes/terminal.tscn` (480×270, scale 1×) 2026-10-30. Шрифт темы: `default_font_size = 12` (Pixelify Sans при наличии файла).

## Фактические метрики S1 (для `ui_scale.json`)

| Ключ | Факт S1 | ТЗ таблица S1 | Примечание |
| --- | ---: | ---: | --- |
| `hud_h` | 24 | 24 | `VBox/HUD` PanelContainer |
| `nav_h` | 25 | 24 | `VBox/Nav` HBoxContainer (кнопки 25) |
| `toolbar_h` | 41 | 38 | ActionBar 25 + ReportLine 16 |
| `btn_h` | 25 | 24 | Nav/ActionBar buttons; Rush внутри HUD = 24 |
| `row_h` | 24 | 24 | `CrewRow.custom_minimum_size.y` |
| `pad` | 6 | 4 | Theme Panel content_margin |
| `gap` | 2 | 4 | Nav/ActionBar separation=2; HUD HBox separation=8 |
| `bar_h` | 8 | 6 | RankBar `custom_minimum_size.y` |
| `scroll_w` | 12 | 8 | дефолт движка (не переопределён) |

IR-15: в `ui_scale.json` для S1 пишутся **фактические** значения.

## Хром → world (факт)

| Величина | Факт физ. px |
| --- | --- |
| HUD | 24 |
| HUD+toolbar (terminal) | 24+41=65 |
| NavBar | 25 |
| Center / SectorView | y=65, h=180 |
| `270 − 65 − 25` | 180 |

## Узлы

| Файл | Узел | Тип | Размер (лог. px) | Шрифт | Абсолютные pos/size | Native popup/tooltip |
| --- | --- | --- | ---: | ---: | --- | --- |
| `scenes/terminal.tscn` | Terminal | Control | 480×270 | — | anchors full | нет |
| `scenes/terminal.tscn` | VBox/HUD | PanelContainer | 480×24 | 12 | layout_mode container | нет |
| `scenes/terminal.tscn` | HUD/…/Credits,Parts,Rank,Shift | Label | ~16h | 12 | нет | нет |
| `scenes/terminal.tscn` | HUD/…/Rush | Button | 53×24 | 12 | нет | нет |
| runtime | HUD/…/RankBar | ProgressBar | 48×8 | — | нет | **да** `tooltip_text` (rank tip) |
| `scenes/terminal.tscn` | VBox/ActionBar | HBoxContainer | 480×25 | 12 | нет | нет |
| `scenes/terminal.tscn` | ActionBar/* | Button | ~158×25 | 12 | нет | нет |
| `scenes/terminal.tscn` | VBox/ReportLine | Label | 480×16 | 12 | нет | нет |
| `scenes/terminal.tscn` | VBox/Center/SectorView | Control | 480×180 | — | anchors full | нет |
| `scenes/terminal.tscn` | *Scroll / *Panel | Scroll/VBox | expand | 12 | anchors full | см. ниже |
| `scenes/terminal.tscn` | VBox/Nav | HBoxContainer | 480×25 | 12 | нет | нет |
| `scenes/terminal.tscn` | Nav/Tab* | Button | ~56–83×25 | 12 | нет | нет |
| `src/ui/crew/crew_row.gd` | CrewRow | HBoxContainer | w×24 | 12 | нет | нет |
| `src/ui/crew/WorkerCard.tscn` | WorkerCard | (overlay) | present | 12 | да (ScreenManager) | tooltip на кнопках |
| `src/ui/crew/CandidateCard.tscn` | CandidateCard | (overlay) | present | 12 | да | tooltip |
| `src/ui/panels/hire_panel.gd` | HirePanel | VBoxContainer | list | 12 | нет | **tooltip_text** на кнопках |
| `src/ui/panels/menu_panel.gd` | MenuPanel | VBoxContainer | list | 12 | нет | нет |
| `src/view/line/LineScene.tscn` | LineScene | (в Погрузке) | world | — | scene | нет |

## Нативные popup / tooltip (к замене на шаге 6)

- `tooltip_text` в: `terminal.gd` (RankBar/Rank), `hire_panel.gd`, `candidate_card.gd`, `worker_card.gd`
- `PopupMenu` / `OptionButton` / `AcceptDialog` / `ConfirmationDialog` / `FileDialog`: в `src/ui` **не найдены** на момент инвентаря

## Эталоны S1

Каталог `tests/golden/ui_scale/s1/`: `hud.png`, `nav.png`, `terminal.png`, `line.png`, `crew.png`, `hire.png`, `contracts.png`, `world.png`, `menu.png` (все 480×270).
