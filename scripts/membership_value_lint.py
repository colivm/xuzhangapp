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
        'title: "省力记"',
        'title: "长期回望"',
        'Text("免费与会员")',
        'Text("已解锁")',
        "MembershipDetailPresentationPolicy",
        "memberDataBoundarySection",
        "具体体验次数只在对应入口显示",
        "订阅不会自动取消",
        "不会自动抵扣或退款",
        "取消原订阅不影响永久权益",
        'subscriptionManagementButton(title: "检查原有订阅")',
        'subscriptionManagementButton(title: "在 App Store 管理订阅")',
        'subscriptionManagementButton(title: "管理原有订阅")',
        ".manageSubscriptionsSheet(isPresented: $showSubscriptionManagement)",
        "IAPEntitlementSelection.verifyFirstAvailable(in: payloads)",
    ),
    "NativeDemoApp/Views/SettingsView.swift": (
        "省力记：OCR 连续导入与批量补记",
        "长期回望：今日回放、周记与月章",
        "完整生活场景与生活线索",
        'Label("升级永久会员", systemImage: "crown.fill")',
        'Text("续费或升级")',
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
    for duplicate_surface in ("benefitsSection", "memberBoundarySection", 'Text("会员核心价值")'):
        if duplicate_surface in pricing:
            print(f"MemberPricingView.swift: duplicate member value surface remains `{duplicate_surface}`")
            return 1
    view_start = pricing.find("struct MemberPricingView: View {")
    view_end = pricing.find("// MARK: - Member Plan Model", view_start)
    if view_start < 0 or view_end < 0:
        print("MemberPricingView.swift: cannot locate member pricing view scope")
        return 1
    view_scope = pricing[view_start:view_end]
    if "private var lifetimeArchiveSectionTitle: String" not in view_scope:
        print("MemberPricingView.swift: lifetime archive title escaped MemberPricingView scope")
        return 1
    computation_start = pricing.find("enum LifetimeArchiveSnapshotComputation")
    computation_scope = pricing[computation_start:] if computation_start >= 0 else ""
    if "membershipPresentationPolicy" in computation_scope:
        print("MemberPricingView.swift: view presentation state leaked into archive computation scope")
        return 1
    login_start = view_scope.find("private func handleMemberLoginSucceeded()")
    login_end = view_scope.find("private func handleMemberLoginSheetDismissed()", login_start)
    if login_start < 0 or login_end < 0:
        print("MemberPricingView.swift: cannot locate login continuation scope")
        return 1
    login_scope = view_scope[login_start:login_end]
    if "if isMember {" in login_scope:
        print("MemberPricingView.swift: login must not discard upgrade/restore intents solely for membership")
        return 1
    for automatic_action in ("handlePurchase(", "restorePurchases(", "continueMemberActionAfterLogin("):
        if automatic_action in login_scope:
            print("MemberPricingView.swift: login success must wait for an explicit continuation action")
            return 1
    confirmation_wiring = (
        '.alert("开通永久会员", isPresented: $showLifetimePurchaseConfirmation)',
        "handlePurchase(plans[2], confirmsLifetimePurchase: true)",
        "if tier == .lifetime {",
        "showLifetimePurchaseConfirmation = true",
    )
    for value in confirmation_wiring:
        if value not in view_scope:
            print(f"MemberPricingView.swift: lifetime purchase confirmation is disconnected `{value}`")
            return 1
    if "apps.apple.com/account/subscriptions" in view_scope:
        print("MemberPricingView.swift: subscription management must use the native StoreKit sheet")
        return 1
    print("membership_value_lint: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
