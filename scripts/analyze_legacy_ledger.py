#!/usr/bin/env python3
"""Read-only inventory for a legacy home_items_v1.json ledger."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
from collections import Counter
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from typing import Any


def amount_minor_units(value: Any) -> int:
    return int((Decimal(str(value or 0)) * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def normalized_images(item: dict[str, Any]) -> list[bytes]:
    encoded_images = item.get("memoryImageDatas") or []
    if not encoded_images and item.get("memoryImageData"):
        encoded_images = [item["memoryImageData"]]
    return [base64.b64decode(value, validate=True) for value in encoded_images]


def normalized_cover(index: Any, image_count: int) -> int | None:
    if image_count <= 0:
        return None
    if index is None:
        return 0
    return min(max(int(index), 0), image_count - 1)


def build_inventory(items: list[dict[str, Any]]) -> dict[str, Any]:
    categories: Counter[str] = Counter()
    records: list[dict[str, Any]] = []
    image_count = 0
    amount_total = 0
    all_fields: set[str] = set()

    for item in items:
        all_fields.update(item.keys())
        categories[str(item.get("category", "其他"))] += 1
        minor_units = amount_minor_units(item.get("amount"))
        amount_total += minor_units
        images = normalized_images(item)
        image_count += len(images)
        record_id = str(item.get("id", "")).lower()
        image_rows = []
        for ordinal, data in enumerate(images):
            digest = hashlib.sha256(data).hexdigest()
            image_rows.append(
                {
                    "ordinal": ordinal,
                    "relativePath": f"images/{record_id}/{digest}.jpg",
                    "sha256": digest,
                    "byteCount": len(data),
                }
            )
        record = {
            "id": str(item.get("id", "")),
            "amountMinorUnits": minor_units,
            "amountValue": float(item.get("amount") or 0),
            "category": item.get("category", "其他"),
            "source": item.get("source", "manual"),
            "imageCount": len(images),
            "coverImageOrdinal": normalized_cover(item.get("coverMemoryImageIndex"), len(images)),
            "images": image_rows,
        }
        if item.get("draftMeta"):
            record["draftStatus"] = item["draftMeta"].get("status")
        if item.get("memoryContext"):
            record["memoryContext"] = item["memoryContext"]
        records.append(record)

    return {
        "recordCount": len(items),
        "imageCount": image_count,
        "amountMinorUnitTotal": amount_total,
        "categoryCounts": dict(sorted(categories.items())),
        "fieldInventory": sorted(all_fields),
        "records": records,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ledger", type=Path, help="Path to legacy home_items_v1.json")
    args = parser.parse_args()

    items = json.loads(args.ledger.read_text(encoding="utf-8"))
    if not isinstance(items, list):
        raise SystemExit("legacy ledger root must be a JSON array")
    print(json.dumps(build_inventory(items), ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
