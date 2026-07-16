#!/usr/bin/env python3
"""Generate deterministic phone-sized JPEG resources for PERF-04."""

from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "NativeDemoApp" / "Resources" / "QARealPhotos"
MANIFEST_PATH = ROOT / "qa" / "real_photo_fixtures" / "manifest.json"
FIXTURES = (
    ("qa_real_01.jpg", 3024, 4032, 1101),
    ("qa_real_02.jpg", 4032, 3024, 2202),
    ("qa_real_03.jpg", 3024, 4032, 3303),
)


def make_image(width: int, height: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    scale = 6
    small_width = width // scale
    small_height = height // scale
    pixels: list[tuple[int, int, int]] = []
    for y in range(small_height):
        for x in range(small_width):
            wave = ((x * 17 + y * 29 + seed) ^ (x * y + seed * 13)) & 0xFF
            noise = rng.randrange(0, 48)
            pixels.append(
                (
                    (42 + wave + noise + x // 3) % 256,
                    (68 + wave // 2 + noise * 2 + y // 2) % 256,
                    (96 + wave * 2 + noise + (x + y) // 4) % 256,
                )
            )
    small = Image.new("RGB", (small_width, small_height))
    small.putdata(pixels)
    image = small.resize((width, height), Image.Resampling.BICUBIC)

    draw = ImageDraw.Draw(image, "RGBA")
    for index in range(320):
        x = rng.randrange(-200, width)
        y = rng.randrange(-200, height)
        w = rng.randrange(80, 620)
        h = rng.randrange(80, 620)
        color = (
            rng.randrange(30, 230),
            rng.randrange(30, 230),
            rng.randrange(30, 230),
            rng.randrange(18, 72),
        )
        if index % 3 == 0:
            draw.ellipse((x, y, x + w, y + h), fill=color)
        else:
            draw.rounded_rectangle((x, y, x + w, y + h), radius=min(w, h) // 5, fill=color)
    return image


def main() -> int:
    RESOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for filename, width, height, seed in FIXTURES:
        path = RESOURCE_DIR / filename
        image = make_image(width, height, seed)
        image.save(path, format="JPEG", quality=90, optimize=True, progressive=True)
        data = path.read_bytes()
        rows.append(
            {
                "file": filename,
                "width": width,
                "height": height,
                "byteCount": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
            }
        )
    MANIFEST_PATH.write_text(
        json.dumps({"schemaVersion": 1, "fixtures": rows}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for row in rows:
        print(
            f"{row['file']}: {row['width']}x{row['height']} "
            f"{row['byteCount'] / 1024 / 1024:.2f} MiB {row['sha256'][:12]}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
