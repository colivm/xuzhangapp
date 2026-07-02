# Theme Contrast Report

Phase: T9

Scope: `ThemeCatalog.json` 31 themes x light/dark modes.

## Summary

- 31 theme ids present.
- 62 mode token sets present.
- Every mode has 8 `categoryColors`.
- Cyber theme category colors use Morandi palette D, not neon RGB.
- Lifetime themes use the explicit `6.1-L` token values.
- Dark mode `textSecondary` on `surface` minimum contrast: 5.09:1.
- `textPrimary` on `background` minimum contrast: 10.86:1.

## Notes

- `lockGold` follows the prompt source hierarchy used for T1.5: standard/free themes use `#C9A64A`; lifetime themes keep the explicit `6.1-L` values.
- Light `mood_weather_clear` secondary text on surface is approximately 4.34:1. Primary text remains above 10:1; keep this as a real-device visual check item.
- T9 visual checks still need final confirmation on iPhone because blur/material compositing can alter perceived contrast.

## 2026-06-18 收尾复核

- `scripts/theme_catalog_check.py` passed after UI-T8.1 / ATTRACT 收尾。
- `lifetime_gilded_circuit` / `lifetime_archive_gold` / `lifetime_neon_cathedral` remain present with light/dark modes.
- Lifetime themes keep §6.1-L explicit bronze/gold/amber token values; no neon palette is used as the permanent selling point.
- Standard/free theme `lockGold` remains `#C9A64A`; lifetime modes keep their explicit §6.1-L values by design.
- Remaining true-device checks: `mood_weather_clear` light secondary text, lifetime Vault gold border on low brightness, and default dark body text inside glass panels.
