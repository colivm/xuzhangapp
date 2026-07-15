#!/usr/bin/env python3
"""Validate DATA-01 fixtures without writing any ledger data."""

from __future__ import annotations

import json
from pathlib import Path

from analyze_legacy_ledger import build_inventory


ROOT = Path(__file__).resolve().parents[1]
SAMPLE_DIR = ROOT / "qa" / "migration_samples"


def comparable_record(record: dict) -> dict:
    keys = [
        "id",
        "amountMinorUnits",
        "amountValue",
        "imageCount",
        "coverImageOrdinal",
        "images",
        "draftStatus",
        "memoryContext",
    ]
    comparable = {key: record.get(key) for key in keys if key in record or key == "coverImageOrdinal"}
    comparable["images"] = record.get("images") or []
    return comparable


def main() -> int:
    legacy = json.loads((SAMPLE_DIR / "legacy_home_items_v1.json").read_text(encoding="utf-8"))
    expected = json.loads((SAMPLE_DIR / "expected_ledger_v2.json").read_text(encoding="utf-8"))
    actual = build_inventory(legacy)

    assert expected["schemaVersion"] == 2
    for key in ["recordCount", "imageCount", "amountMinorUnitTotal", "categoryCounts"]:
        assert actual[key] == expected[key], f"{key}: {actual[key]!r} != {expected[key]!r}"

    actual_by_id = {record["id"]: comparable_record(record) for record in actual["records"]}
    expected_by_id = {record["id"]: comparable_record(record) for record in expected["records"]}
    assert actual_by_id == expected_by_id

    required_cases = {
        "legacy_single_image": any(item.get("memoryImageData") for item in legacy),
        "multi_image": any(len(item.get("memoryImageDatas") or []) > 1 for item in legacy),
        "no_image": any(not item.get("memoryImageData") and not item.get("memoryImageDatas") for item in legacy),
        "ocr_draft": any(item.get("source") == "ocr" and item.get("draftMeta") for item in legacy),
        "memory_context": any(item.get("memoryContext") for item in legacy),
    }
    missing = [name for name, present in required_cases.items() if not present]
    assert not missing, f"missing migration fixture cases: {missing}"

    print("migration_samples: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
