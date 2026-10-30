# UI Scale — how to add a new screen

1. Inherit `ScreenBase` (or implement `apply_scale(s: int)` and connect to `UiScale.scale_changed`).
2. Place the screen under `UiRoot/Content` (tabs) or `UiRoot/Overlays` (modals). Never put UI under `World`.
3. Take all sizes, gaps, and margins from `UiScale.metric(key)` — no raw `480`/`270` in UI code.
4. Use `ScaleVisibility` (or rebuild in `apply_scale`) to hide columns on S2/S3; do not delete nodes for scale.
5. Disable horizontal scroll: `UiScale.style_scroll(scroll)`.
6. No native `tooltip_text`, `PopupMenu`, `OptionButton`, `AcceptDialog` — use `UiTooltip` / `UiSelect` / `UiConfirm` / `UiToast`.
7. Short copy via `Loc.tr_s("key")` with optional `key_S2` / `key_S3` in `data/strings.json`.
8. Names: `Fmt.name(s, UiScale.metric("max_name_chars"))`. Numbers must not ellipsis-trim.
9. Register the screen in `tests/ui/screens.json` (`present: true` when ready).
10. Capture goldens with `tools/capture_ui.gd` and keep T2 (`UiLint.lint_screen`) green on 1×/2×/3×.
