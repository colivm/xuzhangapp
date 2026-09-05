from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(relative: str, snippets: list[str]) -> None:
    text = read(relative)
    missing = [snippet for snippet in snippets if snippet not in text]
    if missing:
        raise SystemExit(f"{relative} missing observability guards: {missing}")


def main() -> None:
    contract = read("PRODUCT_OBSERVABILITY_CONTRACT_v1.md")
    for term in ["不联网、不上传", "禁止采集", "最小匿名事件表", "1,000 条", "30 天"]:
        if term not in contract:
            raise SystemExit(f"observability contract missing: {term}")

    service = read("NativeDemoApp/Services/AnalyticsService.swift")
    for required in [
        "enum ProductAnalyticsEvent",
        "enum AnalyticsPropertyKey",
        "ios_product_observability_events_v2",
        "ios_analytics_events_v1",
        "maxEvents = 1_000",
        "retentionDays = 30",
        "sanitizedProperties",
        "countBucket(for count: Int)",
        "durationBucket(for milliseconds: Int)",
        "trackPerformance",
    ]:
        if required not in service:
            raise SystemExit(f"AnalyticsService missing: {required}")

    forbidden_service = ["URLSession", "Network.framework", "import Network", "Firebase", "Mixpanel", "Amplitude"]
    for token in forbidden_service:
        if token in service:
            raise SystemExit(f"AnalyticsService must stay local-only: {token}")

    home = read("NativeDemoApp/ViewModels/HomeViewModel.swift")
    if re.search(r'analyticsService\.track\s*\(\s*"', home):
        raise SystemExit("raw string analytics events are forbidden")
    for sensitive in [
        '"amount":',
        '"title":',
        '"merchant":',
        '"note":',
        '"raw_text":',
        '"image_index":',
        '"category":',
    ]:
        if sensitive in home:
            raise SystemExit(f"sensitive analytics property returned: {sensitive}")

    require(
        "NativeDemoApp/ViewModels/HomeViewModel.swift",
        [
            "markTodayPlaybackPromptShown",
            "markTodayPlaybackStarted",
            "markSummaryPlaybackStarted",
            "markSummaryPlaybackCompleted",
            "markAICommandRun",
            "markMemberEntryOpened",
            "markMemberPurchaseCompleted",
            "markPerformance",
        ],
    )
    require(
        "NativeDemoApp/Views/InsightWebView.swift",
        ["aiCommandAnalyticsKind", "operation: .insightPreparation", "startedAtUptime: performanceStartedAt"],
    )
    require(
        "NativeDemoApp/Views/StatsWebView.swift",
        [
            "TraceFirstScreenPerformanceSignpost.firstInteractive",
            "TraceFirstScreenPerformanceSignpost.fullReady",
            "operation: requestedMode == .life ? .traceLifePreparation",
            "markSummaryPlaybackStarted",
            "operation: range == .week ? .summaryWeek",
        ],
    )
    require(
        "NativeDemoApp/Services/AnalyticsService.swift",
        [
            "import os.signpost",
            "enum TraceFirstScreenPerformanceSignpost",
            'name: "TraceFirstInteractive"',
            '"stage=first-interactive',
            'name: "TraceFullReady"',
            '"stage=full-ready',
        ],
    )
    require(
        "NativeDemoApp/Views/HomeView.swift",
        ["markTodayPlaybackPromptShown", "markTodayPlaybackStarted", "markTodayPlaybackEnded"],
    )
    require(
        "NativeDemoApp/Views/MemberPricingView.swift",
        ["markMemberPurchaseCompleted", "markMemberRestoreCompleted"],
    )
    require(
        "NativeDemoAppTests/StateRegressionTests.swift",
        [
            "final class AnalyticsPrivacyBoundaryTests",
            "testLegacyEventsWithSensitivePropertiesAreRemoved",
            "testOnlyAllowlistedAnonymousPropertiesArePersisted",
            "testCountsAndDurationsUseCoarseBuckets",
            "testEventsExpireAfterThirtyDaysAndHaveNoStableUserIdentifier",
        ],
    )
    print("observability_lint: OK")


if __name__ == "__main__":
    main()
