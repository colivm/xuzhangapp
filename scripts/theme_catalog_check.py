#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

EXPECTED_IDS = [
    "xuzhang_default",
    "paperverse_blank",
    "mood_weather_clear",
    "cyber_neon_abyss",
    "cyber_vector_camouflage",
    "cyber_holographic_dusk",
    "cyber_crystal_overload",
    "cyber_silicon_vesper",
    "mood_weather_dusk",
    "mood_weather_mist",
    "mood_weather_storm",
    "mood_weather_aurora",
    "mood_weather_tide",
    "paperverse_seal",
    "paperverse_ink_wash",
    "paperverse_typecase",
    "paperverse_faint_spectrum",
    "bio_moss_terminal",
    "bio_coral_data",
    "bio_mycelium",
    "bio_photosynth",
    "orbital_window_dawn",
    "orbital_zero_g",
    "orbital_deep_stamp",
    "orbital_sleep_mode",
    "brutal_concrete",
    "brutal_safety_orange",
    "brutal_grid_paper",
    "lifetime_gilded_circuit",
    "lifetime_neon_cathedral",
    "lifetime_archive_gold",
]

REQUIRED_MODE_KEYS = {
    "background",
    "textPrimary",
    "textSecondary",
    "accent",
    "categoryColors",
}

HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def resolve_theme_id(theme_ids: list[str], theme_id: str) -> str:
    return theme_id if theme_id in theme_ids else "xuzhang_default"


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    catalog_path = root / "NativeDemoApp" / "Theme" / "ThemeCatalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    themes = catalog.get("themes", [])
    ids = [theme.get("id") for theme in themes]

    if ids != EXPECTED_IDS:
        fail(f"expected 31 ordered ids, got {len(ids)}: {ids}")
    if len(set(ids)) != 31:
        fail("theme ids must be unique")
    tier_counts = {}
    for theme in themes:
        tier_counts[theme.get("tier")] = tier_counts.get(theme.get("tier"), 0) + 1
    if tier_counts != {"free": 3, "standard": 25, "lifetime": 3}:
        fail(f"unexpected tier counts: {tier_counts}")

    for theme in themes:
        modes = theme.get("modes", {})
        for mode in ("light", "dark"):
            tokens = modes.get(mode)
            if not isinstance(tokens, dict):
                fail(f"{theme['id']} missing {mode} mode")
            missing = REQUIRED_MODE_KEYS - tokens.keys()
            if missing:
                fail(f"{theme['id']} {mode} missing keys: {sorted(missing)}")
            categories = tokens["categoryColors"]
            if len(categories) != 8:
                fail(f"{theme['id']} {mode} categoryColors must contain 8 colors")
            for key, value in tokens.items():
                if key == "categoryColors":
                    for color in value:
                        if not HEX_RE.match(color):
                            fail(f"{theme['id']} {mode} invalid category color {color}")
                elif isinstance(value, str) and not HEX_RE.match(value):
                    fail(f"{theme['id']} {mode} invalid hex token {key}={value}")

    if resolve_theme_id(ids, "missing_theme") != "xuzhang_default":
        fail("unknown id fallback failed")
    if resolve_theme_id(ids, "cyber_neon_abyss") != "cyber_neon_abyss":
        fail("known id resolution failed")

    print("Theme catalog check passed: 31 ids, light/dark modes, category colors, unknown fallback.")


if __name__ == "__main__":
    main()
