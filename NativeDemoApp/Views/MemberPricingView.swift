import SwiftUI

// MARK: - Member Pricing View (matching web #accountMemberView)

struct MemberPricingView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var iapService = IAPService.shared
    let highlightPlanId: String?
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
        ("无限生活回放", "过去的每一天都值得被记住。通勤、聚餐、旅行、看病、送礼、养宠……生活轨迹持续保留，随时回看。"),
        ("AI 深度生活分析", "看见那些你自己都没察觉的规律：哪些支出正在悄悄增加、最近压力最大的时间段、什么事情最值得你投入时间和金钱、生活节奏正在发生哪些变化。"),
        ("持续生成生活故事", "不只是记账，而是记录成长。周记、月记、年度故事自动串联，多年以后依然能翻阅今天。"),
        ("账单连续整理", "把重复整理交给 AI。微信、支付宝截图可以连续导入，一年账单也能快速变成可回看的生活档案。"),
        ("全部生活场景", "你的生活，不只有消费。日常生活、旅行、健身运动、宝宝成长、宠物记录、人情往来与自定义主题，都能从不同角度重新认识自己。"),
        ("今日无限回放", "睡前重新看看今天。重要的事、见过的人、花过的钱，让每一天都有痕迹。"),
        ("25+ 生活风格", "让记录变得更有温度。纸境、档案馆、夜读、观察者、旅行手账和博物馆，打造属于自己的生活记录本。"),
    ]

    private let boundaryRows = [
        ("生活场景", "轻度记录常用角度", "完整打开旅行、运动、宝宝、宠物、人情等生活面"),
        ("生活回放", "基础体验最近片段", "持续保存周/月/年度故事，不让生活断档"),
        ("账单整理", "适合少量截图", "大段账单也能连续整理成可回看的档案"),
    ]

    init(highlightPlanId: String? = nil) {
        self.highlightPlanId = highlightPlanId
    }

    private let freeQuotaFootnote = "免费版适合轻度记录。会员适合希望长期保存生活轨迹、获得 AI 深度分析与持续回顾的用户。所有账单数据均由你掌控。"

    private var isMember: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    private var isLifetimeMember: Bool {
        settingsViewModel.memberTier.lowercased() == "lifetime" && isMember
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                .onAppear {
                    applyHighlightIfNeeded(proxy)
                }
            }
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
            Text("把流水变成故事，把记录变成回忆")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.text)

            Text("多年以后，你未必记得今天花了多少钱，但会想知道，那时的自己正在过怎样的生活。")
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(AppColors.subtext)

            Text("会员让 AI 持续整理你的生活脉络，帮你看见消费背后的习惯、情绪和变化。")
                .font(.system(size: 12))
                .lineSpacing(3)
                .foregroundStyle(AppColors.subtext.opacity(0.88))
                .padding(.top, 2)

            if !isMember {
                legalPurchaseNote
                    .padding(.top, 2)

                Button {
                    handlePurchase(plans[0]) // yearly default
                } label: {
                    Text("开启完整生活档案")
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
                symbol: "book.closed",
                title: "多年以后，你未必记得今天花了多少钱",
                detail: "但你会想知道，那时的自己正在过怎样的生活。"
            )
            memberValueRow(
                symbol: "sparkles",
                title: "AI 帮你看懂生活",
                detail: "发现消费习惯、情绪变化和生活节奏，而不只是记录每一笔账。"
            )
            memberValueRow(
                symbol: "clock.arrow.circlepath",
                title: "长期连续记录",
                detail: "回放、故事和账单整理持续接上，生活脉络不会因为额度断档。"
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
            Text("完整生活档案包含")
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
                    Text("你会得到什么")
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
        VStack(spacing: 10) {
            Image(systemName: isLifetimeMember ? "crown.fill" : "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(isLifetimeMember ? AppColors.lockGold : AppColors.accent)
            Text(isLifetimeMember ? "你的永久生活档案已开启" : "感谢成为 xLife 会员")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.text)
            Text(isLifetimeMember ? "这些日子会随账号长期保留，AI 会继续替你整理和连接。" : "你的生活故事正在持续整理中")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let validity = settingsViewModel.settings.memberValidityText {
                Text(validity)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.72))
            } else if isLifetimeMember {
                Text("永久有效")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "8B6F38"))
            }
            Text(isLifetimeMember ? "你买下的不是一组功能，而是把生活长期留住的能力。" : "AI 将继续为你整理和连接每一天。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isLifetimeMember ? [
                            AppColors.lockGold.opacity(0.14),
                            Color.white.opacity(0.52),
                            AppColors.accent.opacity(0.06)
                        ] : [
                            AppColors.accent.opacity(0.08),
                            AppColors.accent.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isLifetimeMember ? AppColors.lockGold.opacity(0.42) : AppColors.accent.opacity(0.22), lineWidth: isLifetimeMember ? 1.2 : 1)
        )
    }

    // MARK: - Privacy

    private var privacyNote: some View {
        Text("默认不登录也能记账。开启云端备份后，仅同步必要账单数据与会员状态；OCR 原始图片不会上传服务器。")
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
        let isHighlighted = highlightPlanId == plan.id
        return Button {
            handlePurchase(plan)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(plan.name)：\(displayPrice(for: plan)) / \(plan.period)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                Text(plan.dailyHint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
                if plan.id == "lifetime" {
                    lifetimeThemeBullet
                        .padding(.top, 2)
                }
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
                    .stroke(
                        isHighlighted ? Color(hex: "A68445").opacity(0.58) : Color.white.opacity(0.35),
                        lineWidth: isHighlighted ? 1.4 : 1
                    )
            )
            .shadow(color: isHighlighted ? AppColors.lockGold.opacity(0.16) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
        .id("member-plan-\(plan.id)")
    }

    private var lifetimeThemeBullet: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("✦ 3 款永久典藏风格（档案馆 / 观察者 / 夜读）")
                .foregroundStyle(Color(hex: "A68445"))
            Text("随账号永久保留，年度会员不可用")
                .foregroundStyle(AppColors.subtext)
        }
        .font(.system(size: 11))
        .lineSpacing(2)
    }

    private func applyHighlightIfNeeded(_ proxy: ScrollViewProxy) {
        guard highlightPlanId == "lifetime" else { return }
        morePlansExpanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo("member-plan-lifetime", anchor: .center)
            }
        }
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
