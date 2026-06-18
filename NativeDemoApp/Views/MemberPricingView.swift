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
                   badge: nil, dailyHint: "一次拥有，长期陪伴"),
    ]

    private let benefits = [
        ("周/月生活回放无限", "通勤、吃饭、跑医院、给家里补东西，这些线索可以持续回看。"),
        ("每月生活章持续整理", "免费 10 次用完后，后面的月份也能继续接上，不让生活脉络断掉。"),
        ("今日回放不限次", "当天记录可以反复听，适合晚上把今天多整理几遍。"),
        ("OCR 导入不限次", "微信/支付宝账单截图可继续本地识别，经常导入也不用被次数打断。"),
        ("AI 回顾问得更深", "可以继续追问：哪几天最累、哪些小支出重复出现、这个月节奏哪里变了。"),
        ("全部生活场景换角度", "旅行、运动、宠物、宝宝、人情等场景都能打开，不只停在 3 个常用角度。"),
        ("25+ 色彩主题 + 分享图同款", "痕迹、今天、复盘页统一换肤；永久会员再享 3 款限定主题。"),
        ("分享图持续生成", "周记、月章和故事图可以连续留下来，适合长期回看和分享。"),
    ]

    private let boundaryRows = [
        ("记账场景", "免费 3 个常用角度", "会员打开全部生活场景"),
        ("回放整理", "基础额度可体验", "会员周/月/今日持续回看"),
        ("截图导入", "每日 3 次 OCR", "会员经常导入也不中断"),
    ]

    private let freeQuotaFootnote = "免费版已经可以完整记账、手动整理，并体验基础回放和 3 个常用场景。会员另可解锁 25+ 界面色彩主题；永久会员再享 3 款专属皮肤。"

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
                        memberValueSection
                        memberBoundarySection
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
                await settingsViewModel.refreshCloudAccountProfile()
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
            Text("让账本不只记金额，也记得你在过怎样的生活")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.text)

            Text("免费版已经能好好记录。会员更像一层持续的理解力：把记录串成回望，把同一笔钱放回生活语境里。")
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(AppColors.subtext)

            if !isMember {
                legalPurchaseNote
                    .padding(.top, 2)

                Button {
                    handlePurchase(plans[0]) // yearly default
                } label: {
                    Text("让账本更懂我的生活")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppColors.accentDark.opacity(0.96),
                                    AppColors.accent.opacity(0.94),
                                    AppColors.lockGold.opacity(0.72)
                                ],
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

    private var memberValueSection: some View {
        VStack(spacing: 10) {
            memberValueRow(
                symbol: "calendar.badge.clock",
                title: "连续性",
                detail: "周记、月章和分享图可以一直延展，不用因为次数停在刚有感觉的时候。"
            )
            memberValueRow(
                symbol: "sparkles",
                title: "理解力",
                detail: "会员会继续打开健康、购物、旅行、社交等更多生活语境，不只是多一个分类。"
            )
            memberValueRow(
                symbol: "bolt.heart",
                title: "不打断",
                detail: "OCR、今日回放和 AI 回顾不用反复算额度，想到就继续整理。"
            )
        }
    }

    private func memberValueRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.92))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(AppColors.accent.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.9))
                Text(detail)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .foregroundStyle(AppColors.subtext.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
    }

    private var memberBoundarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("免费已经能用，会员打开连续性")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.9))

            VStack(spacing: 0) {
                ForEach(boundaryRows.indices, id: \.self) { index in
                    let row = boundaryRows[index]
                    HStack(alignment: .top, spacing: 10) {
                        Text(row.0)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.text.opacity(0.74))
                            .frame(width: 62, alignment: .leading)
                        Text(row.1)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.2)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.accent.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 9)

                    if index < boundaryRows.count - 1 {
                        Divider()
                            .background(AppColors.line.opacity(0.45))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.42), lineWidth: 1)
        )
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { benefitsExpanded.toggle() }
            } label: {
                HStack {
                    Text("查看会员具体包含什么")
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
            Text("会员增量权益已开启，感谢你的信任与陪伴。")
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
                    colors: [
                        AppColors.accentDark.opacity(0.96),
                        AppColors.accent.opacity(0.94),
                        AppColors.lockGold.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: AppColors.lockGold.opacity(0.18), radius: 10, y: 5)
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
                purchaseNotice = "会员已开通，回放和导入额度已更新。"
            } catch {
                purchaseNotice = (error as? LocalizedError)?.errorDescription ?? "购买没有完成。请确认支付状态后再试。"
            }
        }
    }

    private func restorePurchases() {
        guard settingsViewModel.hasCloudSession else {
            purchaseNotice = "请先在设置页登录账号，再恢复购买，这样能确认你的会员权益。"
            return
        }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let payloads = try await iapService.restorePurchases()
                guard !payloads.isEmpty else {
                    purchaseNotice = "暂时没有找到可恢复的购买记录。请确认使用的是购买时的 Apple ID。"
                    return
                }
                var restoredPayload: IAPPurchaseVerification?
                for payload in payloads {
                    do {
                        try await settingsViewModel.verifyIAPPurchase(payload)
                        restoredPayload = payload
                        break
                    } catch {
                        continue
                    }
                }
                guard let restoredPayload else {
                    purchaseNotice = "当前账号暂时没有可恢复的会员权益。请确认使用的是购买时的账号。"
                    return
                }
                await iapService.finish(transactionId: restoredPayload.transactionId)
                purchaseNotice = "会员权益已恢复，可以继续使用。"
            } catch {
                purchaseNotice = (error as? LocalizedError)?.errorDescription ?? "恢复购买没有完成，请稍后再试。"
            }
        }
    }

    private func loadStoreProducts() async {
        do {
            try await iapService.loadProducts()
        } catch {
            purchaseNotice = "会员价格暂时没加载出来，请稍后再试。"
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
