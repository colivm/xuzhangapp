import SwiftUI

// MARK: - Member Pricing View (matching web #accountMemberView)

struct MemberPricingView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var iapService = IAPService.shared
    @State private var benefitsExpanded = false
    @State private var morePlansExpanded = false
    @State private var purchaseNotice: String?
    @State private var isPurchasing = false
    private let termsURL = URL(string: "https://xuzhangapp.com/legal/terms.html")!
    private let privacyURL = URL(string: "https://xuzhangapp.com/legal/privacy.html")!

    private let plans = [
        MemberPlan(id: "yearly", name: "年度会员", price: "¥88", period: "年", featured: true,
                   badge: "✨ 推荐", dailyHint: "平均每天不到 1 毛钱，最划算"),
        MemberPlan(id: "monthly", name: "月度会员", price: "¥9", period: "月", featured: false,
                   badge: nil, dailyHint: "首月推介 ¥6，按月订阅，随时可取消"),
        MemberPlan(id: "lifetime", name: "永久会员", price: "¥168", period: "永久", featured: false,
                   badge: nil, dailyHint: "一次解锁，终身陪伴"),
    ]

    private let benefits = [
        ("🎬 周/月生活回放无限", "每周、每月都能继续听，不受免费次数限制。"),
        ("📖 每月生活章持续解锁", "免费 10 次用完后，会员可继续回看更多月份。"),
        ("🌤 今日回放不限次", "当天记录可以反复听，适合晚上回看今天。"),
        ("📷 OCR 导入不限次", "微信/支付宝账单截图可继续本地识别，导入前仍可确认。"),
        ("💬 AI 回顾额度提升", "想多问一句时，可以继续生成温和的回顾建议。"),
        ("🧭 场景包换角度", "同一笔记录可以切换通勤、吃喝、购物、旅行、健康、居家等生活视角。"),
        ("📚 回望内容长期保留", "周记、月章和故事图更适合连续回看。"),
    ]

    private let freeQuotaFootnote = "免费体验：本周回放每自然周 3 次 · 本月回放终生 10 次 · OCR 每日 3 次 · 今日回放每日 1 次。开通会员后，周/月/今日回放与 OCR 可不限次使用。"

    private var isMember: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // ── Hero ──
                    if !isMember {
                        heroSection
                    }

                    // ── Benefits ──
                    benefitsSection

                    // ── Pricing ──
                    if !isMember {
                        pricingSection
                    } else {
                        currentMemberBadge
                    }

                    // ── Privacy ──
                    freeQuotaNote
                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle(isMember ? "会员详情" : "会员方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await settingsViewModel.refreshMemberFromLocalEntitlements()
                await loadStoreProducts()
            }
            .alert("会员购买", isPresented: Binding(
                get: { purchaseNotice != nil },
                set: { if !$0 { purchaseNotice = nil } }
            )) {
                Button("知道了", role: .cancel) {
                    purchaseNotice = nil
                }
            } message: {
                Text(purchaseNotice ?? "")
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("让周记和月记一直可回看")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.text)

            Text("会员解锁周/月/今日回放、OCR 不限次和 AI 回顾额度提升。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            if !isMember {
                legalPurchaseNote
                    .padding(.top, 2)

                Button {
                    handlePurchase(plans[0]) // yearly default
                } label: {
                    Text("立即开通年度会员（推荐）")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Text("订阅可随时在 App Store 账户设置中取消。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.8))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { benefitsExpanded.toggle() }
            } label: {
                HStack {
                    Text("查看会员权益详情")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.text.opacity(0.86))
                    Spacer()
                    Text(benefitsExpanded ? "收起" : "展开")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if benefitsExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits.indices, id: \.self) { idx in
                        let (title, desc) = benefits[idx]
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.text)
                            Text(desc)
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.subtext)
                                .lineSpacing(2)
                        }
                    }
                }
                .padding(14)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            legalPurchaseNote

            // Featured yearly plan
            featuredPlanButton(plans[0])

            // More plans toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { morePlansExpanded.toggle() }
            } label: {
                HStack {
                    Text("查看更多套餐")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.text.opacity(0.8))
                    Spacer()
                    Image(systemName: morePlansExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.subtext)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .buttonStyle(.plain)

            if morePlansExpanded {
                regularPlanButton(plans[1])
                regularPlanButton(plans[2])
            }

            restorePurchaseButton

            Text("订阅可随时在 App Store 账户设置中取消。新用户首月优惠以购买页显示为准。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.8))
                .padding(.top, 4)
        }
    }

    // MARK: - Current Member Badge

    private var currentMemberBadge: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.accent)
            Text("你已开通\(AppSettings.memberTierDisplayName(settingsViewModel.memberTier))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.text)
            if let validity = settingsViewModel.settings.memberValidityText {
                Text(validity)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.72))
            }
            Text("会员增量权益已解锁，感谢你的信任与陪伴。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Privacy

    private var privacyNote: some View {
        Text("默认不登录也能记账。开启云端备份后，仅同步必要账单数据与会员状态；OCR 原图不会上传。")
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext.opacity(0.75))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legalPurchaseNote: some View {
        HStack(spacing: 4) {
            Text("购买前请阅读")
                .foregroundStyle(AppColors.subtext.opacity(0.78))
            Link("用户协议", destination: termsURL)
                .foregroundStyle(AppColors.accentDark.opacity(0.9))
            Text("和")
                .foregroundStyle(AppColors.subtext.opacity(0.78))
            Link("隐私政策", destination: privacyURL)
                .foregroundStyle(AppColors.accentDark.opacity(0.9))
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var freeQuotaNote: some View {
        Text(freeQuotaFootnote)
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext.opacity(0.75))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Plan Buttons

    private func featuredPlanButton(_ plan: MemberPlan) -> some View {
        Button {
            handlePurchase(plan)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                if let badge = plan.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.lockGold)
                        )
                        .padding(.bottom, 2)
                }
                Text("\(plan.name)：\(displayPrice(for: plan)) / \(plan.period)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(plan.dailyHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private func regularPlanButton(_ plan: MemberPlan) -> some View {
        Button {
            handlePurchase(plan)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(plan.name)：\(displayPrice(for: plan)) / \(plan.period)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                Text(plan.dailyHint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private var restorePurchaseButton: some View {
        Button {
            restorePurchases()
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                Text(isPurchasing ? "处理中…" : "恢复购买")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppColors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    // MARK: - Purchase Handler

    private func handlePurchase(_ plan: MemberPlan) {
        guard settingsViewModel.hasCloudSession else {
            purchaseNotice = "请先在设置页登录账号，再开通会员。这样换机后也能恢复你的会员状态。"
            return
        }
        guard let tier = IAPTier(rawValue: plan.id) else { return }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let payload = try await iapService.purchase(tier: tier)
                try await settingsViewModel.verifyIAPPurchase(payload)
                await iapService.finish(transactionId: payload.transactionId)
                purchaseNotice = "购买成功，会员状态已更新。"
            } catch {
                purchaseNotice = error.localizedDescription
            }
        }
    }

    private func restorePurchases() {
        guard settingsViewModel.hasCloudSession else {
            purchaseNotice = "请先在设置页登录账号，再恢复购买。"
            return
        }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let payloads = try await iapService.restorePurchases()
                guard !payloads.isEmpty else {
                    purchaseNotice = "没有找到可恢复的会员购买。"
                    return
                }
                for payload in payloads {
                    try await settingsViewModel.verifyIAPPurchase(payload)
                    await iapService.finish(transactionId: payload.transactionId)
                }
                purchaseNotice = "已恢复购买，会员状态已更新。"
            } catch {
                purchaseNotice = error.localizedDescription
            }
        }
    }

    private func loadStoreProducts() async {
        do {
            try await iapService.loadProducts()
        } catch {
            purchaseNotice = error.localizedDescription
        }
    }

    private func displayPrice(for plan: MemberPlan) -> String {
        guard let tier = IAPTier(rawValue: plan.id) else { return plan.price }
        return iapService.displayPrice(for: tier, fallback: plan.price)
    }

}

// MARK: - Member Plan Model

private struct MemberPlan: Identifiable {
    let id: String
    let name: String
    let price: String
    let period: String
    let featured: Bool
    let badge: String?
    let dailyHint: String
}

// MARK: - Preview

struct MemberPricingView_Previews: PreviewProvider {
    static var previews: some View {
        MemberPricingView()
            .environmentObject(SettingsViewModel())
    }
}
