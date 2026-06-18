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
