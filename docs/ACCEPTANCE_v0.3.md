# Acceptance checklist — TZ v0.3 §2.16

Date: 2026-10-30 · Branch: `feat/ui-scale`

| # | Criterion | Status | Notes |
| --- | --- | --- | --- |
| 1 | ScaleRow 1×/2×/3× in Menu between language and sound | OK | Live-verified; `docs/screens/scale_row_s*.png` |
| 2 | Instant switch; tab/scroll/modals preserved | OK | `ScaleRow` + `UiScale.set_scale`; no reload |
| 3 | Persist after restart | OK | `SaveSystem` key `ui_scale`; T7 |
| 4 | S1 byte-equal to Step 1 goldens | OK | `tests/golden/ui_scale/s1/**` unchanged by capture (S2/S3 only) |
| 5 | Pixel doubling at 2×/3× | OK | `UiRoot.scale`; live + goldens S2/S3 |
| 6 | No h-scroll; touch sizes on S2/S3 | Partial | Lint A3/A4 smoke; full screen T2 matrix still light |
| 7 | World unscaled / hittable | OK | `WorldClip` + `world_rect`; T4 |
| 8 | S3 nav glyphs + toast | OK | Live-verified (NavIcon fallbacks + `UiToast`) |
| 9 | HUD S2/S3 + HudDetails | OK | Live-verified |
| 10 | S3 FabBuild + BuildPanel | OK | Live-verified |
| 11 | No native popup/tooltip/dialog | OK | T6 source lint clean |
| 12 | T1–T9 green + screenshots | OK | Headless ALL PASSED; S2/S3 + scale_row shots attached |
| 13 | Sim/save/backend untouched | OK | Scope limited to UI scale |
| 14 | No blocking QUESTIONS | OK | Q-1/Q-2 closed |

Deviations: see `docs/FOUND_ISSUES.md` (D5), `docs/DECISIONS.md` (path mapping, S1 golden DoD).
