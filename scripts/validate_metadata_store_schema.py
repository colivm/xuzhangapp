#!/usr/bin/env python3
"""Execute the SQLite schema and UPSERT SQL embedded in LedgerMetadataStore.swift."""

from __future__ import annotations

import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "NativeDemoApp" / "Services" / "LedgerMetadataStore.swift"


def sql_blocks(source: str) -> list[str]:
    return re.findall(r'"""\n(.*?)\n\s*"""', source, flags=re.DOTALL)


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    blocks = sql_blocks(source)
    schema = next(block for block in blocks if "CREATE TABLE IF NOT EXISTS records" in block)
    record_upsert = next(block for block in blocks if "INSERT INTO records" in block)
    image_insert = next(block for block in blocks if "INSERT INTO image_assets" in block)

    database = sqlite3.connect(":memory:")
    database.execute("PRAGMA foreign_keys = ON")
    database.executescript(schema)
    assert database.execute("PRAGMA user_version").fetchone()[0] == 2

    values = [
        "record-a",
        "测试记录",
        1880,
        18.805,
        "餐饮",
        "manual",
        1.0,
        2.0,
        "日常餐饮",
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        1,
        None,
        None,
        None,
        None,
        "fingerprint-a",
    ]
    assert len(values) == 27
    database.execute(record_upsert, values)

    updated = list(values)
    updated[1] = "修改后的记录"
    updated[-1] = "fingerprint-b"
    database.execute(record_upsert, updated)
    row = database.execute("SELECT title, amount_value, record_fingerprint FROM records").fetchone()
    assert row == ("修改后的记录", 18.805, "fingerprint-b")

    duplicate_path = "images/record-a/same-hash.jpg"
    database.execute(
        image_insert,
        ["asset-a", "record-a", 0, duplicate_path, "same-hash", 10, "image/jpeg"],
    )
    database.execute(
        image_insert,
        ["asset-b", "record-a", 1, duplicate_path, "same-hash", 10, "image/jpeg"],
    )
    assert database.execute("SELECT COUNT(*) FROM image_assets").fetchone()[0] == 2

    database.execute("DELETE FROM records WHERE id = 'record-a'")
    assert database.execute("SELECT COUNT(*) FROM image_assets").fetchone()[0] == 0
    print("metadata_store_schema: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
