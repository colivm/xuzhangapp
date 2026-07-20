#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POOL = ROOT / "NativeDemoApp/Services/PlaybackCopyPool.swift"
SERVICE = ROOT / "NativeDemoApp/Services/PlaybackService.swift"
SHEET = ROOT / "NativeDemoApp/Views/SummaryPlaybackSheet.swift"
TESTS = ROOT / "NativeDemoAppTests/StateRegressionTests.swift"
MATRIX = ROOT / "RELEASE_GATE_AND_DEVICE_MATRIX_v1.md"


def section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    end_index = text.find(end, start_index + len(start))
    if start_index < 0 or end_index < 0:
        raise ValueError(f"missing source section: {start} -> {end}")
    return text[start_index:end_index]


def main() -> int:
    failures: list[str] = []
    pool = POOL.read_text(encoding="utf-8")
    service = SERVICE.read_text(encoding="utf-8")
    sheet = SHEET.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")
    matrix = MATRIX.read_text(encoding="utf-8")

    blocked_templates = [
        "胶片",
        "气味",
        "有画面",
        "生活的开头",
        "这次它又回来了",
        "新的天气",
        "新的路线",
        "{petName} 看到",
    ]
    for phrase in blocked_templates:
        if phrase in pool:
            failures.append(f"PlaybackCopyPool still contains abstract template `{phrase}`")

    if 'warm: ["{mainLine}"]' not in pool or 'plain: ["{mainLine}"]' not in pool:
        failures.append("PlaybackCopyPool must render warm/plain from the same factual mainLine")
    if 'private static let weekTeasers = ["{teaserLine}"]' not in pool:
        failures.append("week teaser must consume an explicit factual teaserLine")
    if 'private static let monthTeasers = ["{teaserLine}"]' not in pool:
        failures.append("month teaser must consume an explicit factual teaserLine")

    try:
        week = section(
            service,
            "func buildWeekSummary(",
            "func buildWeeklyShareCardPayload(",
        )
        month = section(
            service,
            "func buildMonthSummary(",
            "private struct CategoryAmount",
        )
    except ValueError as error:
        failures.append(str(error))
        week = ""
        month = ""

    forbidden_builder_inputs = [
        "displayEmotionTag",
        '"emotionTag"',
        '"sceneMemoryLine"',
        '"scentWords"',
        "LifeMarkService",
        "recurringTraceLine",
    ]
    for name, source in (("week", week), ("month", month)):
        for token in forbidden_builder_inputs:
            if token in source:
                failures.append(f"{name} playback builder exposes C-level signal `{token}`")
        if '"supportLine"' not in source:
            failures.append(f"{name} playback builder must publish explicit supportLine evidence")

    required_week_titles = [
        'title: "这一周"',
        'title: "这一笔"',
        'title: "这周反复出现"',
        'title: "这周先到这里"',
    ]
    required_month_titles = [
        'title: "月初留下的"',
        'title: "后来留下的"',
        'title: "这个月反复出现"',
        'title: "这个月先到这里"',
    ]
    for token in required_week_titles:
        if token not in week:
            failures.append(f"missing weekly role title: {token}")
    for token in required_month_titles:
        if token not in month:
            failures.append(f"missing monthly role title: {token}")

    required_service_boundaries = [
        "monthlyComparisonCopy(allItems: items, currentRows: rows, now: now)",
        "previousEndCandidate",
        "comparableCurrent",
        "safePlaybackTitle(for item: HomeItem)",
        "excludingTitles",
        "evidenceMoneyFormatter",
    ]
    for token in required_service_boundaries:
        if token not in service:
            failures.append(f"missing playback evidence boundary `{token}`")

    required_sheet_boundaries = [
        'chapter.metrics.keys.contains("supportLine")',
        "normalizedPlaybackCopy(support)",
        "normalizedNarration.contains(normalizedSupport)",
        'private func chapterElementChips(for chapter: SummaryChapter)',
        'if chapter.metrics.keys.contains("supportLine") {\n            return []',
    ]
    for token in required_sheet_boundaries:
        if token not in sheet:
            failures.append(f"missing playback support de-dup boundary `{token}`")

    required_tests = [
        "final class PlaybackLivingVoiceCopyTests",
        "testWeekKeepsZeroOneTwoAndMatureChapterCounts",
        "testMatureWeekSeparatesDistributionRecordAndReliableRepeat",
        "testPlaybackNarrationDoesNotExposeAbstractOrInternalCopy",
        "testMonthKeepsSixRolesAndUsesSameDayComparison",
        "testMonthExplicitlyHandlesMissingEarlyLateAndComparisonEvidence",
    ]
    for token in required_tests:
        if token not in tests:
            failures.append(f"missing playback copy regression `{token}`")

    if "FLOW-42" not in matrix or "上月同期" not in matrix:
        failures.append("missing playback living-voice Xcode/iPhone verification matrix")

    for failure in failures:
        print(f"error: {failure}", file=sys.stderr)
    if failures:
        print(f"playback-copy-lint failed: {len(failures)} error(s)", file=sys.stderr)
        return 1

    print("playback-copy-lint passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
