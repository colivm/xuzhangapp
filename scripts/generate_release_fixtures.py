#!/usr/bin/env python3
"""Generate deterministic RELEASE-01 ledger fixtures.

The output intentionally uses the legacy HomeItem JSON shape so the same files
exercise image externalization and SQLite activation on iOS.
"""

from __future__ import annotations

import base64
import hashlib
import json
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "qa" / "release_fixtures"
SUPPORTED_COUNTS = (100, 1_000, 5_000)
GENERATOR_VERSION = "release-fixture-v1"
APPLE_REFERENCE_DATE = datetime(2001, 1, 1, tzinfo=timezone.utc)

CATEGORIES = (
    ("餐饮", "餐饮记录", "日常餐饮"),
    ("交通", "交通记录", "日常出行"),
    ("购物", "购物记录", "日常添置"),
    ("日用", "日用记录", "日用记录"),
    ("娱乐", "娱乐记录", "轻量娱乐"),
    ("住宿", "住宿记录", "短暂停留"),
    ("健康", "健康记录", "健康记录"),
    ("居家", "居家记录", "居家补给"),
    ("人情", "人情记录", "见面记录"),
    ("其他", "其他记录", "日常记录"),
)

# Three valid 1x1 RGB PNG files. Keeping the payload tiny lets the 5,000-record
# fixture contain real decodable images without becoming unwieldy.
PNG_BASE64_VARIANTS = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mN4l+MLAAPzAajtSvbZAAAAAElFTkSuQmCC",
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mPwbX8HAALnAcN4NVQmAAAAAElFTkSuQmCC",
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNw21IBAAK2AXPQ1ccDAAAAAElFTkSuQmCC",
)


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stable_id(index: int) -> str:
    return f"10000000-0000-4000-8000-{index + 1:012x}"


def amount_minor_units(index: int) -> int:
    return 100 + ((index * 7_919 + 37) % 50_000)


def created_datetime(index: int) -> datetime:
    year = 2024 + (index % 3)
    month = 1 + ((index * 7) % 12)
    day = 1 + ((index * 11) % 28)
    hour = 6 + (index % 16)
    minute = (index * 13) % 60
    return datetime(year, month, day, hour, minute, tzinfo=timezone.utc)


def apple_reference_seconds(value: datetime) -> int:
    return int((value - APPLE_REFERENCE_DATE).total_seconds())


def image_payloads(index: int) -> tuple[list[str], int | None]:
    if index % 13 != 0:
        return [], None
    photo_slot = index // 13
    image_count = 1 + (photo_slot % 3)
    payloads = [PNG_BASE64_VARIANTS[(index + ordinal) % len(PNG_BASE64_VARIANTS)] for ordinal in range(image_count)]
    return payloads, photo_slot % image_count


def build_record(index: int) -> dict[str, Any]:
    category_index = index % len(CATEGORIES)
    category, title_prefix, emotion_tag = CATEGORIES[category_index]
    created_at = created_datetime(index)
    amount_minor = amount_minor_units(index)
    source = "ocr" if index % 11 == 0 else "manual"
    record: dict[str, Any] = {
        "id": stable_id(index),
        "title": f"{title_prefix} · 发布夹具 {index + 1:04d}",
        "amount": amount_minor / 100,
        "category": category,
        "source": source,
        "createdAt": apple_reference_seconds(created_at),
        "updatedAt": apple_reference_seconds(created_at + timedelta(minutes=index % 5)),
        "emotionTag": emotion_tag,
    }

    if source == "ocr":
        ocr_slot = index // 11
        record["draftMeta"] = {
            "batchId": f"release-ocr-{ocr_slot // 4:04d}",
            "importedAt": apple_reference_seconds(created_at + timedelta(seconds=30)),
            "status": "pending" if ocr_slot % 2 == 0 else "resolved",
        }

    if index % 4 == 0:
        record["userEditedTitle"] = True
    if index % 7 == 0:
        record["userEditedCategory"] = True
    if index % 29 == 0:
        record["categoryCorrectionFrom"] = CATEGORIES[(category_index - 1) % len(CATEGORIES)][0]
    if index % 17 == 0:
        record["memoryContext"] = {
            "weatherKind": ("sunny", "rain", "cloudy")[(index // 17) % 3],
            "temperatureCelsius": 18.5 + (index % 15),
            "cityName": ("杭州", "上海", "成都")[(index // 17) % 3],
            "semanticPlace": ("公司附近", "家附近", "路上")[(index // 17) % 3],
        }
    if index % 19 == 0:
        record["scenePackId"] = ("commute", "family", "travel")[(index // 19) % 3]
    if index % 23 == 0:
        record["merchantBrandId"] = f"qa-brand-{(index // 23) % 5}"

    images, cover_index = image_payloads(index)
    if images:
        photo_slot = index // 13
        if len(images) == 1 and photo_slot % 2 == 0:
            record["memoryImageData"] = images[0]
        else:
            record["memoryImageDatas"] = images
        record["coverMemoryImageIndex"] = cover_index
        record["memoryAnchorRole"] = ("moment", "place", "object")[photo_slot % 3]
        record["memoryAnchorSceneHint"] = ("experience", "travel", "importantPurchase")[photo_slot % 3]
        record["memoryAnchorCaption"] = f"发布夹具照片顺序 {photo_slot + 1}。"
        record["memoryAnchorCreatedAt"] = apple_reference_seconds(created_at + timedelta(minutes=2))

    return record


def build_records(count: int) -> list[dict[str, Any]]:
    if count not in SUPPORTED_COUNTS:
        raise ValueError(f"unsupported fixture count: {count}")
    return [build_record(index) for index in range(count)]


def normalized_images(record: dict[str, Any]) -> list[str]:
    images = record.get("memoryImageDatas") or []
    if images:
        return list(images)
    single = record.get("memoryImageData")
    return [single] if single else []


def fixture_summary(file_name: str, records: list[dict[str, Any]]) -> dict[str, Any]:
    category_counts = Counter(record["category"] for record in records)
    ocr_counts = Counter(
        record["draftMeta"]["status"]
        for record in records
        if record.get("source") == "ocr" and record.get("draftMeta")
    )
    image_entries: list[str] = []
    cover_entries: list[str] = []
    image_count = 0
    photo_record_count = 0
    for record in records:
        images = normalized_images(record)
        if not images:
            continue
        photo_record_count += 1
        image_count += len(images)
        image_hashes = [sha256_hex(base64.b64decode(image, validate=True)) for image in images]
        image_entries.extend(
            f"{record['id']}:{ordinal}:{digest}"
            for ordinal, digest in enumerate(image_hashes)
        )
        cover_index = record["coverMemoryImageIndex"]
        cover_entries.append(f"{record['id']}:{cover_index}:{image_hashes[cover_index]}")

    years = sorted({created_datetime(index).year for index in range(len(records))})
    return {
        "file": file_name,
        "recordCount": len(records),
        "amountMinorUnitTotal": sum(amount_minor_units(index) for index in range(len(records))),
        "categoryCounts": {category: category_counts[category] for category, _, _ in CATEGORIES},
        "years": years,
        "photoRecordCount": photo_record_count,
        "imageCount": image_count,
        "ocrDraftCounts": {
            "pending": ocr_counts["pending"],
            "resolved": ocr_counts["resolved"],
            "total": ocr_counts["pending"] + ocr_counts["resolved"],
        },
        "firstRecordID": records[0]["id"],
        "lastRecordID": records[-1]["id"],
        "recordDigestSha256": sha256_hex(canonical_json(records)),
        "imageSequenceDigestSha256": sha256_hex("\n".join(image_entries).encode("utf-8")),
        "coverSelectionDigestSha256": sha256_hex("\n".join(cover_entries).encode("utf-8")),
    }


def build_manifest(fixtures: list[dict[str, Any]]) -> dict[str, Any]:
    fixture_set_digest = sha256_hex(canonical_json(fixtures))
    return {
        "schemaVersion": 1,
        "generatorVersion": GENERATOR_VERSION,
        "dateEncoding": "secondsSinceAppleReferenceDateUTC",
        "supportedRecordCounts": list(SUPPORTED_COUNTS),
        "requiredCategories": [category for category, _, _ in CATEGORIES],
        "fixtures": fixtures,
        "fixtureSetDigestSha256": fixture_set_digest,
    }


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> int:
    fixture_summaries: list[dict[str, Any]] = []
    for count in SUPPORTED_COUNTS:
        file_name = f"ledger_{count}.json"
        records = build_records(count)
        write_json(OUTPUT_DIR / file_name, records)
        fixture_summaries.append(fixture_summary(file_name, records))
    write_json(OUTPUT_DIR / "manifest.json", build_manifest(fixture_summaries))
    print(f"release_fixtures: generated {', '.join(str(value) for value in SUPPORTED_COUNTS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
