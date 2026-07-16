#!/usr/bin/env python3
"""Validate RELEASE-01 fixtures and orchestrate the release automation gate."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import shutil
import sqlite3
import struct
import subprocess
import sys
import zlib
from collections import Counter
from pathlib import Path
from typing import Any

from generate_release_fixtures import (
    CATEGORIES,
    GENERATOR_VERSION,
    OUTPUT_DIR,
    SUPPORTED_COUNTS,
    amount_minor_units,
    build_manifest,
    build_records,
    canonical_json,
    created_datetime,
    fixture_summary,
    normalized_images,
    sha256_hex,
    stable_id,
)


ROOT = Path(__file__).resolve().parents[1]
REAL_PHOTO_RESOURCE_DIR = ROOT / "NativeDemoApp" / "Resources" / "QARealPhotos"
REAL_PHOTO_MANIFEST_PATH = ROOT / "qa" / "real_photo_fixtures" / "manifest.json"


def validate_png(data: bytes) -> None:
    assert data.startswith(b"\x89PNG\r\n\x1a\n"), "image is not a PNG"
    position = 8
    saw_header = False
    saw_end = False
    compressed = bytearray()
    while position < len(data):
        assert position + 12 <= len(data), "truncated PNG chunk"
        length = struct.unpack(">I", data[position : position + 4])[0]
        kind = data[position + 4 : position + 8]
        payload_start = position + 8
        payload_end = payload_start + length
        crc_end = payload_end + 4
        assert crc_end <= len(data), "truncated PNG payload"
        payload = data[payload_start:payload_end]
        expected_crc = struct.unpack(">I", data[payload_end:crc_end])[0]
        actual_crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
        assert expected_crc == actual_crc, "PNG CRC mismatch"
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            assert (width, height, bit_depth, color_type) == (1, 1, 8, 2)
            assert (compression, filter_method, interlace) == (0, 0, 0)
            saw_header = True
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            assert length == 0
            saw_end = True
        position = crc_end
    assert position == len(data)
    assert saw_header and saw_end and compressed
    assert len(zlib.decompress(bytes(compressed))) == 4, "unexpected 1x1 RGB PNG payload"


def jpeg_dimensions(data: bytes) -> tuple[int, int]:
    assert data.startswith(b"\xff\xd8"), "image is not a JPEG"
    position = 2
    while position + 4 <= len(data):
        assert data[position] == 0xFF, "invalid JPEG marker"
        while position < len(data) and data[position] == 0xFF:
            position += 1
        marker = data[position]
        position += 1
        if marker in {0xD8, 0xD9}:
            continue
        length = struct.unpack(">H", data[position : position + 2])[0]
        assert length >= 2 and position + length <= len(data), "truncated JPEG segment"
        if marker in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
            height, width = struct.unpack(">HH", data[position + 3 : position + 7])
            return width, height
        position += length
    raise AssertionError("JPEG dimensions not found")


def validate_real_photo_fixtures() -> None:
    manifest = json.loads(REAL_PHOTO_MANIFEST_PATH.read_text(encoding="utf-8"))
    assert manifest["schemaVersion"] == 1
    fixtures = manifest["fixtures"]
    assert len(fixtures) >= 3
    for fixture in fixtures:
        path = REAL_PHOTO_RESOURCE_DIR / fixture["file"]
        data = path.read_bytes()
        width, height = jpeg_dimensions(data)
        assert (width, height) == (fixture["width"], fixture["height"])
        assert width * height >= 12_000_000, f"{path.name} is below 12 MP"
        assert len(data) == fixture["byteCount"]
        assert len(data) >= 2_000_000, f"{path.name} is too small to model a real phone photo"
        assert sha256_hex(data) == fixture["sha256"]
        print(f"real photo {path.name}: {width}x{height} bytes={len(data)}")
    print("real_photo_fixture_set: OK")


def exact_minor_units(amount: Any) -> int:
    text = str(amount)
    whole, dot, fraction = text.partition(".")
    fraction = (fraction + "00")[:2]
    assert not dot or len(text.partition(".")[2]) <= 2, f"amount has more than two decimals: {text}"
    return int(whole) * 100 + int(fraction)


def validate_fixture(count: int, manifest_entry: dict[str, Any]) -> None:
    path = OUTPUT_DIR / manifest_entry["file"]
    assert path == OUTPUT_DIR / f"ledger_{count}.json"
    records = json.loads(path.read_text(encoding="utf-8"))
    expected = build_records(count)
    assert records == expected, f"{path.name} differs from deterministic generator output"
    assert len(records) == count

    ids = [record["id"] for record in records]
    assert len(set(ids)) == count
    assert ids == [stable_id(index) for index in range(count)]

    total_minor_units = sum(exact_minor_units(record["amount"]) for record in records)
    assert total_minor_units == sum(amount_minor_units(index) for index in range(count))

    required_categories = [category for category, _, _ in CATEGORIES]
    category_counts = Counter(record["category"] for record in records)
    assert list(manifest_entry["categoryCounts"]) == sorted(required_categories)
    assert set(category_counts) == set(required_categories)
    assert all(category_counts[category] > 0 for category in required_categories)

    years = sorted({created_datetime(index).year for index in range(count)})
    assert years == [2024, 2025, 2026]

    pending = 0
    resolved = 0
    image_count = 0
    photo_record_count = 0
    for record in records:
        draft_meta = record.get("draftMeta")
        if record["source"] == "ocr":
            assert draft_meta is not None
            assert draft_meta["status"] in {"pending", "resolved"}
            if draft_meta["status"] == "pending":
                pending += 1
            else:
                resolved += 1
        else:
            assert draft_meta is None

        images = normalized_images(record)
        assert not (record.get("memoryImageData") and record.get("memoryImageDatas"))
        if not images:
            assert record.get("coverMemoryImageIndex") is None
            continue
        photo_record_count += 1
        image_count += len(images)
        cover_index = record.get("coverMemoryImageIndex")
        assert isinstance(cover_index, int) and 0 <= cover_index < len(images)
        for encoded in images:
            validate_png(base64.b64decode(encoded, validate=True))

    actual_summary = fixture_summary(path.name, records)
    assert actual_summary == manifest_entry
    assert actual_summary["recordCount"] == count
    assert actual_summary["amountMinorUnitTotal"] == total_minor_units
    assert actual_summary["imageCount"] == image_count
    assert actual_summary["photoRecordCount"] == photo_record_count
    assert actual_summary["ocrDraftCounts"] == {
        "pending": pending,
        "resolved": resolved,
        "total": pending + resolved,
    }
    assert actual_summary["recordDigestSha256"] == sha256_hex(canonical_json(records))
    print(
        f"fixture {count}: records={count} minorTotal={total_minor_units} "
        f"images={image_count} ocr={pending + resolved} digest={actual_summary['recordDigestSha256'][:12]}"
    )


def validate_fixtures() -> None:
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["schemaVersion"] == 1
    assert manifest["generatorVersion"] == GENERATOR_VERSION
    assert manifest["dateEncoding"] == "secondsSinceAppleReferenceDateUTC"
    assert manifest["supportedRecordCounts"] == list(SUPPORTED_COUNTS)
    assert manifest["requiredCategories"] == [category for category, _, _ in CATEGORIES]
    entries = manifest["fixtures"]
    assert [entry["recordCount"] for entry in entries] == list(SUPPORTED_COUNTS)
    for count, entry in zip(SUPPORTED_COUNTS, entries, strict=True):
        validate_fixture(count, entry)
    assert manifest == build_manifest(entries)
    print(f"release_fixture_set: OK {manifest['fixtureSetDigestSha256']}")
    validate_real_photo_fixtures()


def run_command(label: str, command: list[str]) -> None:
    print(f"\n=== {label} ===", flush=True)
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if completed.returncode != 0:
        raise SystemExit(f"{label} failed with exit code {completed.returncode}")


def powershell_command(script: str) -> list[str]:
    executable = shutil.which("pwsh") or shutil.which("powershell")
    if not executable:
        raise SystemExit("PowerShell is required for the repository static checks")
    return [executable, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script]


def run_repository_checks() -> None:
    validate_fixtures()
    commands = (
        ("git diff --check", ["git", "diff", "--check"]),
        ("life semantic regression", [sys.executable, "scripts/life_semantic_regression.py"]),
        ("experience static check", powershell_command("scripts/experience_static_check.ps1")),
        ("copy experience check", powershell_command("scripts/check_copy_experience.ps1")),
        ("copy lint", [sys.executable, "scripts/copy_lint.py"]),
        ("migration fixtures", [sys.executable, "scripts/validate_migration_samples.py"]),
        ("metadata schema", [sys.executable, "scripts/validate_metadata_store_schema.py"]),
    )
    for label, command in commands:
        run_command(label, command)
    print("\nrelease_repository_gate: OK")


def run_xcode_checks(destination: str) -> None:
    if sys.platform != "darwin" or not shutil.which("xcodebuild"):
        raise SystemExit("Xcode gate requires macOS with xcodebuild installed")
    base = ["xcodebuild", "-project", "NativeDemoApp.xcodeproj", "-scheme", "NativeDemoApp"]
    run_command("Xcode Debug build", base + ["-configuration", "Debug", "build"])
    run_command("Xcode Release build", base + ["-configuration", "Release", "build"])
    run_command("XCTest", base + ["-destination", destination, "test"])
    print("\nrelease_xcode_gate: OK")


def find_device_database(container_root: Path, expected_count: int, photo_profile: str) -> Path:
    candidates = [
        path
        for path in container_root.rglob("ledger-v2.sqlite")
        if f"ledger_{expected_count}_{photo_profile}" in path.parts
    ]
    if len(candidates) != 1:
        formatted = "\n".join(str(path) for path in candidates) or "(none)"
        raise SystemExit(
            f"expected exactly one ledger_{expected_count}_{photo_profile} device database, "
            f"found {len(candidates)}:\n{formatted}"
        )
    return candidates[0]


def audit_device_container(container_root: Path, expected_count: int, photo_profile: str) -> None:
    database_path = find_device_database(container_root.resolve(), expected_count, photo_profile)
    store_root = database_path.parent.resolve()
    expected_records = build_records(expected_count)
    expected_by_id = {record["id"]: record for record in expected_records}

    database = sqlite3.connect(f"file:{database_path.as_posix()}?mode=ro", uri=True)
    try:
        assert database.execute("PRAGMA quick_check(1)").fetchone()[0] == "ok"
        assert database.execute("PRAGMA user_version").fetchone()[0] == 2
        record_rows = database.execute(
            """
            SELECT id, amount_minor_units, category, source, created_at, draft_status, cover_image_ordinal
            FROM records
            ORDER BY lower(id)
            """
        ).fetchall()
        assert len(record_rows) == expected_count
        assert sum(row[1] for row in record_rows) == sum(amount_minor_units(index) for index in range(expected_count))
        assert Counter(row[2] for row in record_rows) == Counter(record["category"] for record in expected_records)

        for record_id, amount_minor, category, source, created_at, draft_status, cover_ordinal in record_rows:
            normalized_id = record_id.lower()
            expected = expected_by_id[normalized_id]
            assert amount_minor == exact_minor_units(expected["amount"])
            assert category == expected["category"]
            assert source == expected["source"]
            assert int(created_at) == expected["createdAt"]
            assert draft_status == (expected.get("draftMeta") or {}).get("status")
            assert cover_ordinal == expected.get("coverMemoryImageIndex")

        image_rows = database.execute(
            """
            SELECT record_id, ordinal, relative_path, sha256, byte_count
            FROM image_assets
            ORDER BY lower(record_id), ordinal
            """
        ).fetchall()
        expected_images: list[tuple[str, int, str]] = []
        real_photo_data = [
            (REAL_PHOTO_RESOURCE_DIR / f"qa_real_{index:02d}.jpg").read_bytes()
            for index in range(1, 4)
        ]
        for record_index, record in enumerate(expected_records):
            for ordinal, encoded in enumerate(normalized_images(record)):
                data = (
                    real_photo_data[(record_index + ordinal) % len(real_photo_data)]
                    if photo_profile == "realistic"
                    else base64.b64decode(encoded, validate=True)
                )
                expected_images.append(
                    (record["id"], ordinal, sha256_hex(data))
                )
        assert len(image_rows) == len(expected_images)
        for row, expected in zip(image_rows, expected_images, strict=True):
            record_id, ordinal, relative_path, digest, byte_count = row
            assert (record_id.lower(), ordinal, digest) == expected
            image_path = (store_root / relative_path).resolve()
            assert image_path.is_relative_to(store_root), f"image path escapes store root: {relative_path}"
            data = image_path.read_bytes()
            assert len(data) == byte_count
            assert sha256_hex(data) == digest
            if photo_profile == "realistic":
                width, height = jpeg_dimensions(data)
                assert width * height >= 12_000_000
            else:
                validate_png(data)
    finally:
        database.close()

    manifest_path = store_root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    assert manifest["schemaVersion"] == 2
    assert manifest["activeStore"] == "metadataV2"
    assert manifest["recordCount"] == expected_count
    assert manifest["imageCount"] == len(expected_images)
    assert manifest["amountMinorUnitTotal"] == sum(amount_minor_units(index) for index in range(expected_count))
    print(
        f"release_device_container: OK records={expected_count} images={len(expected_images)} "
        f"database={database_path}"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--phase",
        choices=("fixtures", "windows", "xcode", "device-audit", "all"),
        default="fixtures",
        help="fixtures only, repository checks, Xcode checks, or repository plus Xcode",
    )
    parser.add_argument(
        "--simulator-destination",
        default="platform=iOS Simulator,name=iPhone 15",
    )
    parser.add_argument("--device-container", type=Path)
    parser.add_argument("--expected-count", type=int, choices=SUPPORTED_COUNTS)
    parser.add_argument("--photo-profile", choices=("tiny", "realistic"), default="tiny")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.phase == "fixtures":
        validate_fixtures()
    elif args.phase == "windows":
        run_repository_checks()
    elif args.phase == "xcode":
        run_xcode_checks(args.simulator_destination)
    elif args.phase == "device-audit":
        if args.device_container is None or args.expected_count is None:
            raise SystemExit("device-audit requires --device-container and --expected-count")
        audit_device_container(args.device_container, args.expected_count, args.photo_profile)
    else:
        run_repository_checks()
        run_xcode_checks(args.simulator_destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
