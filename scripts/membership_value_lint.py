#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED = {
    "MEMBERSHIP_VALUE_AND_QUOTA_RULES_v1.md": (
        "省力记",
        "长期回望",
        "DailyFeatureQuotaStore.todayPlaybackFreeLimit = 3",
        "SummaryPlaybackQuotaStore.weeklyFreeLimit = 3",
        "SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit = 10",
        "LifeInsightService.freeMonthlyLimit = 5",
        "共享“长期回望体验”额度池（未实施）",
    ),
    "NativeDemoApp/Views/MemberPricingView.swift": (
        '("省力记"',
        '("长期回望"',
        'Text("会员核心价值")',
        'Text("免费与会员的差别")',
        "具体体验次数只在对应入口显示",
    ),
    "NativeDemoApp/Views/SettingsView.swift": (
        "省力记：OCR 连续导入与批量补记",
        "长期回望：今日回放、周记与月章",
        "完整生活场景与生活线索",
    ),
}


def main() -> int:
    for relative_path, values in REQUIRED.items():
        text = (ROOT / relative_path).read_text(encoding="utf-8")
        for value in values:
            if value not in text:
                print(f"{relative_path}: missing `{value}`")
                return 1
    pricing = (ROOT / "NativeDemoApp/Views/MemberPricingView.swift").read_text(encoding="utf-8")
    if "benefitsExpanded" in pricing:
        print("MemberPricingView.swift: legacy expandable benefit list remains")
        return 1
    print("membership_value_lint: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
