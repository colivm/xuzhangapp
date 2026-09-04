from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(relative: str, snippets: list[str]) -> None:
    text = read(relative)
    missing = [snippet for snippet in snippets if snippet not in text]
    if missing:
        joined = "\n  - ".join(missing)
        raise SystemExit(f"{relative} missing accessibility guards:\n  - {joined}")


def forbid(relative: str, snippets: list[str]) -> None:
    text = read(relative)
    found = [snippet for snippet in snippets if snippet in text]
    if found:
        joined = "\n  - ".join(found)
        raise SystemExit(f"{relative} contains regressed accessibility patterns:\n  - {joined}")


def main() -> None:
    require(
        "ACCESSIBILITY_READABILITY_CONTRACT_v1.md",
        ["44 × 44 pt", "Dynamic Type", "VoiceOver", "Reduce Motion", "冻结边界"],
    )
    require(
        "NativeDemoApp/Models/InteractionStateModels.swift",
        [
            "enum AccessibilityLayoutPolicy",
            "minimumTapTarget: Double = 44",
            "minimumReadableTextOpacity: Double = 0.72",
            "shouldStackPrimaryActions",
            "allowsDecorativeMotion",
        ],
    )
    require(
        "NativeDemoApp/ContentView.swift",
        [
            "AccessibilityLayoutPolicy.minimumTapTarget",
            ".font(.system(\n                                .caption,",
            ".frame(maxWidth: .infinity, minHeight: 56)",
            ".accessibilityValue(selectedTab == tab ? \"已选中\" : \"\")",
        ],
    )
    require(
        "NativeDemoApp/Views/InsightWebView.swift",
        [
            "@Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            "@Environment(\\.dynamicTypeSize) private var dynamicTypeSize",
            "ViewThatFits(in: .horizontal)",
            "if dynamicTypeSize.isAccessibilitySize",
            ".accessibilityValue(isSelected ? \"已选择\" : \"\")",
            "本机规则，确认后写入",
            ".accessibilityLabel(\"比前七天",
            ".accessibilityHint(\"打开这条记录的详情预览\")",
        ],
    )
    require(
        "NativeDemoApp/Views/StatsWebView.swift",
        [
            "return ViewThatFits(in: .horizontal)",
            ".frame(maxWidth: .infinity, minHeight: 44)",
            ".accessibilityLabel(\"这段时间的节奏，",
            "var traceEditSpring: Animation?",
            "reduceMotion ? nil : .spring",
        ],
    )
    require(
        "NativeDemoApp/Views/MemberPricingView.swift",
        [
            "membershipValueVerticalRow",
            "legalPurchaseLinks",
            "withAnimation(reduceMotion ? nil",
            ".font(.footnote)",
            ".accessibilityLabel(\"\\(value.title)，免费：",
        ],
    )
    require(
        "NativeDemoApp/Views/RecordView.swift",
        [
            "@Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            ".accessibilityValue(isSelected ? \"已选中\" : \"\")",
            ".accessibilityLabel(\"账单识别\")",
            "recordDateQuietActions",
            ".accessibilityLabel(\"修改时间，当前",
            ".animation(reduceMotion ? nil : .spring",
        ],
    )
    require(
        "NativeDemoApp/Views/OCRConfirmSheet.swift",
        ["secondaryImportActions", "minHeight: 44", "关闭确认页，不导入账单"],
    )
    require(
        "NativeDemoApp/Views/SummaryPlaybackSheet.swift",
        [
            "@Environment(\\.accessibilityReduceMotion) private var reduceMotion",
            ".frame(width: 44, height: 44)",
            ".accessibilityLabel(\"关闭回放\")",
            ".animation(reduceMotion ? nil",
        ],
    )
    require(
        "NativeDemoAppTests/StateRegressionTests.swift",
        [
            "final class AccessibilityLayoutPolicyTests",
            "testCoreTapTargetNeverDropsBelowFortyFourPoints",
            "testPrimaryActionsStackForAccessibilityTextOrNarrowWidths",
            "testReduceMotionDisablesDecorativeMotion",
        ],
    )
    forbid(
        "NativeDemoApp/ContentView.swift",
        [".font(.system(size: 11, weight: selectedTab == tab"],
    )
    forbid(
        "NativeDemoApp/Views/RecordView.swift",
        [".frame(height: 17, alignment: .leading)"],
    )
    print("accessibility_lint: OK")


if __name__ == "__main__":
    main()
