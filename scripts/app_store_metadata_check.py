#!/usr/bin/env python3
from __future__ import annotations

import json
import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
METADATA_PATH = ROOT / "APP_STORE_METADATA_zh-Hans.json"
LISTING_PATH = ROOT / "APP_STORE_LISTING.md"
IAP_PATH = ROOT / "APP_STORE_IAP_SETUP.md"
PRIVACY_MANIFEST_PATH = ROOT / "NativeDemoApp" / "Resources" / "PrivacyInfo.xcprivacy"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def swift_constant(path: Path, name: str) -> int:
    text = read_text(path)
    match = re.search(rf"static let {re.escape(name)}\s*=\s*(\d+)", text)
    if not match:
        raise ValueError(f"missing Swift constant {name} in {path.relative_to(ROOT)}")
    return int(match.group(1))


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def main() -> int:
    failures: list[str] = []
    metadata = json.loads(read_text(METADATA_PATH))
    listing = read_text(LISTING_PATH)
    iap_doc = read_text(IAP_PATH)
    public_copy = listing + "\n" + iap_doc

    length_limits = {
        "appName": 30,
        "subtitle": 30,
        "promotionalText": 170,
        "description": 4000,
        "keywords": 100,
        "whatsNew": 4000,
    }
    for field, limit in length_limits.items():
        value = metadata.get(field)
        if not isinstance(value, str) or not value.strip():
            fail(f"{field}: missing non-empty string", failures)
            continue
        if len(value) > limit:
            fail(f"{field}: {len(value)} characters exceeds {limit}", failures)

    for field in ("appName", "subtitle", "promotionalText", "description", "keywords", "whatsNew"):
        value = metadata.get(field, "")
        if value and value not in listing:
            fail(f"APP_STORE_LISTING.md does not reproduce metadata field {field} exactly", failures)

    expected_facts = (
        "王义磊（个人）",
        "yilei wang",
        "support@xuzhang.app",
        "hello@xuzhang.app",
        "https://xuzhangapp.com/",
        "https://xuzhangapp.com/legal/privacy.html",
        "https://xuzhangapp.com/legal/terms.html",
        "苏ICP备2026035096号-1",
        "Apple WeatherKit",
        "DeepSeek",
    )
    for fact in expected_facts:
        if fact not in public_copy:
            fail(f"missing current App Store fact: {fact}", failures)

    forbidden = (
        "看看花",
        "生活切片",
        "小 AI 说",
        "账单字段",
        "Open-Meteo",
        "13800138000",
        "123456",
        "每自然周 1 次",
        "终生 3 次",
        "月度会员 ¥10",
        "当前为 501",
        "若构建未接 StoreKit",
    )
    for phrase in forbidden:
        if phrase in public_copy:
            fail(f"stale or unsafe App Store copy remains: {phrase}", failures)

    if re.search(r"(?<!\d)1[3-9]\d{9}(?!\d)", public_copy):
        fail("public App Store docs contain a mainland mobile number", failures)

    playback_path = ROOT / "NativeDemoApp" / "Services" / "PlaybackSupportServices.swift"
    quota_phrases = {
        f"• 今日回放：每天 {swift_constant(playback_path, 'todayPlaybackFreeLimit')} 次",
        f"• 周记：每个自然周 {swift_constant(playback_path, 'weeklyFreeLimit')} 次",
        f"• 月章：共 {swift_constant(playback_path, 'lifetimeMonthFreeLimit')} 次",
        f"• 账单识别：每天 {swift_constant(playback_path, 'ocrDailyFreeLimit')} 次",
        f"• 生活线索：每月 {swift_constant(ROOT / 'NativeDemoApp' / 'Services' / 'LifeInsightService.swift', 'freeMonthlyLimit')} 次",
        f"• 月度整理：共 {swift_constant(ROOT / 'NativeDemoApp' / 'Models' / 'InteractionStateModels.swift', 'monthlyInsightTrialTotal')} 次",
    }
    description = metadata.get("description", "")
    for phrase in sorted(quota_phrases):
        if phrase not in description:
            fail(f"metadata description is missing current quota: {phrase}", failures)

    info = plistlib.loads((ROOT / "NativeDemoApp" / "Info.plist").read_bytes())
    info_keys = {
        "monthly": "IAPMonthlyProductID",
        "yearly": "IAPYearlyProductID",
        "lifetime": "IAPLifetimeProductID",
    }
    member_view = read_text(ROOT / "NativeDemoApp" / "Views" / "MemberPricingView.swift")
    products = metadata.get("iapProducts")
    if not isinstance(products, list) or len(products) != 3:
        fail("iapProducts must contain exactly monthly, yearly and lifetime", failures)
    else:
        seen_tiers: set[str] = set()
        for product in products:
            tier = product.get("tier", "")
            product_id = product.get("productID", "")
            fallback_price = product.get("fallbackPrice", "")
            display_name = product.get("displayName", "")
            seen_tiers.add(tier)
            if tier not in info_keys:
                fail(f"unknown IAP tier in metadata: {tier}", failures)
                continue
            if info.get(info_keys[tier]) != product_id:
                fail(f"{tier} Product ID differs from NativeDemoApp/Info.plist", failures)
            expected_pattern = re.compile(
                rf'MemberPlan\(id: "{re.escape(tier)}", name: "{re.escape(display_name)}", price: "{re.escape(fallback_price)}"'
            )
            if not expected_pattern.search(member_view):
                fail(f"{tier} display name or fallback price differs from MemberPricingView", failures)
            for value in (product_id, fallback_price, display_name):
                if value not in iap_doc:
                    fail(f"IAP document missing {tier} value: {value}", failures)
        if seen_tiers != set(info_keys):
            fail(f"IAP tiers mismatch: {sorted(seen_tiers)}", failures)

    manifest = plistlib.loads(PRIVACY_MANIFEST_PATH.read_bytes())
    if manifest.get("NSPrivacyTracking") is not False:
        fail("PrivacyInfo.xcprivacy must set NSPrivacyTracking=false", failures)
    if manifest.get("NSPrivacyTrackingDomains") != []:
        fail("PrivacyInfo.xcprivacy must have no tracking domains", failures)
    if metadata.get("tracking") is not False or metadata.get("trackingDomains") != []:
        fail("App Store metadata must declare no tracking and no tracking domains", failures)

    manifest_types: dict[str, dict] = {}
    for entry in manifest.get("NSPrivacyCollectedDataTypes", []):
        data_type = entry.get("NSPrivacyCollectedDataType")
        if not data_type:
            fail("privacy manifest has an entry without a data type", failures)
            continue
        if data_type in manifest_types:
            fail(f"duplicate privacy manifest type: {data_type}", failures)
        manifest_types[data_type] = entry

    label_types: dict[str, dict] = {}
    for label in metadata.get("privacyLabels", []):
        data_type = label.get("manifestType")
        if not data_type:
            fail("App Store privacy label has no manifestType", failures)
            continue
        label_types[data_type] = label
        if label.get("usedForTracking") is not False:
            fail(f"privacy label unexpectedly enables tracking: {data_type}", failures)
        manifest_entry = manifest_types.get(data_type)
        if manifest_entry is None:
            fail(f"privacy label missing from PrivacyInfo.xcprivacy: {data_type}", failures)
            continue
        if manifest_entry.get("NSPrivacyCollectedDataTypeLinked") is not label.get("linkedToUser"):
            fail(f"linked-to-user mismatch for {data_type}", failures)
        if manifest_entry.get("NSPrivacyCollectedDataTypeTracking") is not False:
            fail(f"manifest unexpectedly enables tracking for {data_type}", failures)
        purposes = manifest_entry.get("NSPrivacyCollectedDataTypePurposes", [])
        if purposes != ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]:
            fail(f"unexpected manifest purposes for {data_type}: {purposes}", failures)

    if set(manifest_types) != set(label_types):
        fail(
            "privacy label types differ from manifest types: "
            f"manifest={sorted(manifest_types)} labels={sorted(label_types)}",
            failures,
        )

    for required_type in (
        "NSPrivacyCollectedDataTypeOtherFinancialInfo",
        "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypePreciseLocation",
        "NSPrivacyCollectedDataTypeCoarseLocation",
    ):
        if required_type not in label_types:
            fail(f"missing bookkeeping/location privacy type: {required_type}", failures)

    if failures:
        print("app_store_metadata_check: FAILED")
        for message in failures:
            print(f"- {message}")
        return 1

    print(
        "app_store_metadata_check: OK "
        f"name={len(metadata['appName'])}/30 "
        f"subtitle={len(metadata['subtitle'])}/30 "
        f"promo={len(metadata['promotionalText'])}/170 "
        f"description={len(metadata['description'])}/4000 "
        f"keywords={len(metadata['keywords'])}/100 "
        f"privacy_types={len(label_types)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
