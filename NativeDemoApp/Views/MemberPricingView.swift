import SwiftUI

// MARK: - Member Pricing View (matching web #accountMemberView)

enum MemberPricingEntryContext: Equatable {
    case traceDeepInsight
    case playbackQuota
    case ocrImport
    case scenePack(String?)
    case lifetime
    case aiCommand
    case settings
}

private struct MemberHeroContent {
    let title: String
    let subtitle: String
    let detail: String
    let chips: [String]
}

private struct MemberValuePoint: Identifiable {
    var id: String { title }
    let symbol: String
    let title: String
    let detail: String
}

struct MemberPricingView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var iapService = IAPService.shared
    let highlightPlanId: String?
    let entryContext: MemberPricingEntryContext
    @State private var morePlansExpanded = false
    @State private var purchaseNotice: String?
    @State private var isPurchasing = false
    @State private var didRunInitialRefresh = false
    @State private var didApplyHighlight = false
    @State private var lifetimeArchiveSnapshot: LifetimeArchiveSnapshot = .empty
    @State private var showMemberLoginSheet = false
    @State private var loginContinuation = MemberLoginContinuationState()
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
        ("省力记", "手动记账和基础统计始终免费；会员把 OCR 连续导入、批量补记和完整生活场景接起来。"),
        ("长期回望", "今日回放、周记、月章和生活线索持续可用，多年以后仍能按真实记录回看。"),
    ]

    private let boundaryRows = [
        ("省力记", "手动记账免费，OCR 每日有体验次数", "OCR 连续导入、批量补记和全部生活场景"),
        ("长期回望", "各入口提供今日回放、周记、月章和生活线索体验", "长期回望持续可用，不被次数打断"),
    ]

    init(
        highlightPlanId: String? = nil,
        entryContext: MemberPricingEntryContext = .settings
    ) {
        self.highlightPlanId = highlightPlanId
        self.entryContext = entryContext
    }

    private let freeQuotaFootnote = "手动记账、基础统计和本地保存始终免费。具体体验次数只在对应入口显示；会员核心是省力记和长期回望。"

    private var isMember: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    private var isLifetimeMember: Bool {
        settingsViewModel.memberTier.lowercased() == "lifetime" && isMember
    }

    private var effectiveHighlightPlanID: String? {
        if case .purchase(let planID) = loginContinuation.resumedIntent {
            return planID
        }
        return highlightPlanId
    }

    private var heroContent: MemberHeroContent {
        switch entryContext {
        case .traceDeepInsight:
            return MemberHeroContent(
                title: "把这段记录继续往后查",
                subtitle: "会员会继续整理本周、本月和更长时间的记录，不只停在分类和金额。",
                detail: "雨天通勤、健身恢复、旅行停留、家庭照护这些线索，会按账本里已有的日期、分类、备注和上下文连接起来。",
                chips: ["按日期回看", "周记月章连续", "真实记录"]
            )
        case .playbackQuota:
            return MemberHeroContent(
                title: "想多看几遍，不用等刷新",
                subtitle: "会员适合经常回看今日、周记和月章的人，记录刚有感觉时可以继续整理。",
                detail: "回放不会因为免费次数停住，今天、这一周和这个月都能继续整理。",
                chips: ["不限回看", "周记月章", "持续整理"]
            )
        case .ocrImport:
            return MemberHeroContent(
                title: "连续整理截图账单",
                subtitle: "微信、支付宝截图多的时候，会员可以继续导入，不用等明天刷新。",
                detail: "导入后会继续参与重复账单判断、分类整理、周记和月章，账单不是只进列表里。",
                chips: ["连续导入", "重复整理", "进入回顾"]
            )
        case .scenePack(_):
            return MemberHeroContent(
                title: "把这笔放进更准确的生活场景",
                subtitle: "会员可打开旅行、身体、娃和毛孩等完整场景包，让记录不只停在基础分类。",
                detail: "健身卡、酒店门票、宠物补给、看病买药这些记录，会更容易回到对应生活线里。",
                chips: ["全部场景", "更准文案", "长期线索"]
            )
        case .lifetime:
            return MemberHeroContent(
                title: "把多年记录长期留住",
                subtitle: "永久会员适合想长期保存周记、月章、风格和历史记录的人。",
                detail: "一次开通后，跨月份、跨年份的回看材料会持续保留，也包含 3 款典藏风格。",
                chips: ["长期保存", "典藏风格", "持续回看"]
            )
        case .aiCommand:
            return MemberHeroContent(
                title: "用本机指令台批量整理真实账本",
                subtitle: "按时间、分类、金额和备注查账、对比、核对重复，并生成待确认补记预览。",
                detail: "AI 指令台不联网；批量补记确认后才写入，结果只基于真实记录，不额外编造。",
                chips: ["批量补记", "连续追问", "真实账本"]
            )
        case .settings:
            return MemberHeroContent(
                title: "让账本以后还能看懂",
                subtitle: "多年以后，你未必记得今天花了多少钱，但会想知道那时的自己正在过怎样的生活。",
                detail: "本机规则会按日期、分类、备注和上下文整理；开启联网整理后，今日小记和月度整理可尝试远程模型。",
                chips: ["周记月章", "深度分析", "长期记录"]
            )
        }
    }

    private var memberValuePoints: [MemberValuePoint] {
        switch entryContext {
        case .traceDeepInsight:
            return [
                MemberValuePoint(symbol: "sparkles", title: "看到更多上下文", detail: "雨天通勤、健身恢复、旅行停留会按已有记录继续整理。"),
                MemberValuePoint(symbol: "calendar", title: "周月不断档", detail: "本周、本月和更长周期都能持续整理。"),
                MemberValuePoint(symbol: "text.magnifyingglass", title: "只基于真实账本", detail: "按日期、分类、备注和上下文连接，不额外编造。")
            ]
        case .playbackQuota:
            return [
                MemberValuePoint(symbol: "play.circle", title: "回放不限次", detail: "今日、周记、月章想多看几遍都能继续。"),
                MemberValuePoint(symbol: "clock.arrow.circlepath", title: "不用等刷新", detail: "记录刚有感觉时，不会被免费次数打断。"),
                MemberValuePoint(symbol: "book.closed", title: "保留长期回放", detail: "多次回看会接成周记和月章。")
            ]
        case .ocrImport:
            return [
                MemberValuePoint(symbol: "doc.viewfinder", title: "连续导入截图", detail: "微信、支付宝截图多的时候可以接着整理。"),
                MemberValuePoint(symbol: "checklist", title: "减少重复整理", detail: "导入后的账单继续参与重复判断和分类线索。"),
                MemberValuePoint(symbol: "chart.line.uptrend.xyaxis", title: "导入后能回看", detail: "账单会进入痕迹页、回放和指令台查询。")
            ]
        case .scenePack(_):
            return [
                MemberValuePoint(symbol: "square.grid.2x2", title: "打开全部生活角度", detail: "旅行、身体、家庭照护等场景都能使用。"),
                MemberValuePoint(symbol: "wand.and.stars", title: "文案更贴近场景", detail: "同样一笔钱，会放进更具体的生活语境。"),
                MemberValuePoint(symbol: "link", title: "同类记录更清楚", detail: "同类记录多了，会在痕迹页按时间放在一起。")
            ]
        case .lifetime:
            return [
                MemberValuePoint(symbol: "archivebox", title: "长期保存记录", detail: "适合想把多年记录持续留住的人。"),
                MemberValuePoint(symbol: "paintpalette", title: "典藏风格", detail: "永久会员包含档案馆、观察者、夜读等典藏风格。"),
                MemberValuePoint(symbol: "infinity", title: "一次开通", detail: "不用每年再想订阅是否续上。")
            ]
        case .aiCommand:
            return [
                MemberValuePoint(symbol: "list.bullet.rectangle", title: "批量补记先预览", detail: "通勤这类重复记录会先列出来，确认后才写入账本。"),
                MemberValuePoint(symbol: "terminal", title: "继续追问账本", detail: "本月健身、上一次通勤、第十次咖啡都能接着查。"),
                MemberValuePoint(symbol: "text.magnifyingglass", title: "只基于真实记录", detail: "按日期、分类、备注和上下文整理，不额外编造。")
            ]
        case .settings:
            return [
                MemberValuePoint(symbol: "book.closed", title: "多年以后仍能回看", detail: "金额、备注、天气和地点都能一起看。"),
                MemberValuePoint(symbol: "sparkles", title: "规则帮你整理账本", detail: "按真实记录查看习惯、场景变化和重复记录。"),
                MemberValuePoint(symbol: "clock.arrow.circlepath", title: "长期连续记录", detail: "今日回放、周记、月章和账单整理持续接上。")
            ]
        }
    }

    private var memberProofLine: String {
        let items = homeViewModel.items.filter { $0.amount > 0 && $0.draftMeta == nil }
        guard !items.isEmpty else {
            return "先从第一笔开始，后面会自动整理出周记和月章。"
        }
        let calendar = Calendar.current
        let activeDays = Set(items.map { calendar.startOfDay(for: $0.createdAt) }).count
        let monthCount = Set(items.map { monthKey(for: $0.createdAt, calendar: calendar) }).count
        if monthCount >= 2 {
            return "你的账本已有 \(items.count) 笔记录，跨过 \(monthCount) 个月，适合继续长期保存和回看。"
        }
        return "你的账本已有 \(items.count) 笔记录，分布在 \(activeDays) 天里，可以继续整理成周记和月章。"
    }

    private var lifetimeArchiveItemsSignature: String {
        var hasher = Hasher()
        hasher.combine(homeViewModel.items.count)
        for item in homeViewModel.items {
            hasher.combine(item.id)
            hasher.combine(item.createdAt.timeIntervalSince1970)
            hasher.combine(item.updatedAt.timeIntervalSince1970)
            hasher.combine(item.amount)
            hasher.combine(item.category.rawValue)
            hasher.combine(item.title)
            hasher.combine(item.emotionTag)
            hasher.combine(item.source.rawValue)
            hasher.combine(item.draftMeta?.status.rawValue)
            hasher.combine(item.memoryContext?.weatherKind)
            hasher.combine(item.memoryContext?.cityName)
            hasher.combine(item.memoryContext?.semanticPlace)
            hasher.combine(item.scenePackId)
        }
        return "\(hasher.finalize())"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // ── Hero ──
                        if !isMember {
                            heroSection
                            memberValueSection
                        }

                        // ── Pricing ──
                        if !isMember {
                            if loginContinuation.resumedIntent != nil {
                                memberLoginContinuationCard
                            }
                            pricingSection
                            lifetimeTeaserSection
                        } else {
                            currentMemberBadge
                        }

                        memberBoundarySection
                        benefitsSection
                        lifetimeArchiveSection

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
                    scheduleLifetimeArchiveSnapshotRefresh()
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
                await runInitialRefreshIfNeeded()
            }
            .onChange(of: lifetimeArchiveItemsSignature) { _, _ in
                scheduleLifetimeArchiveSnapshotRefresh()
            }
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.14)
                            .ignoresSafeArea()
                        ComputationLoadingView(
                            message: "正在确认会员状态…",
                            detail: "请不要重复发起购买或恢复",
                            presentation: .card
                        )
                        .frame(maxWidth: 320)
                        .padding(.horizontal, 24)
                    }
                    .transition(.opacity)
                    .zIndex(21)
                } else if let purchaseNotice {
                    purchaseNoticeOverlay(purchaseNotice)
                        .transition(.opacity)
                        .zIndex(20)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: purchaseNotice)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isPurchasing)

        }
        .sheet(isPresented: $showMemberLoginSheet, onDismiss: {
            handleMemberLoginSheetDismissed()
        }) {
            MemberAccountLoginSheet(intent: loginContinuation.pendingLoginIntent)
                .environmentObject(settingsViewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: settingsViewModel.hasCloudSession) { _, hasSession in
            guard hasSession else { return }
            handleMemberLoginSucceeded()
        }
    }


    private func purchaseNoticeOverlay(_ message: String) -> some View {
        ZStack {
            Color.black.opacity(0.20)
                .ignoresSafeArea()
                .onTapGesture { purchaseNotice = nil }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.92))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("会员购买")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(message)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.text.opacity(0.76))
                            .lineSpacing(4)
                    }
                }
                Button("知道了") { purchaseNotice = nil }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppColors.accent.opacity(0.88), in: Capsule(style: .continuous))
                    .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.58), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.16), radius: 28, y: 14)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        let content = heroContent
        return VStack(alignment: .leading, spacing: 8) {
            Text(content.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.text)

            Text(content.subtitle)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(AppColors.subtext)

            Text(content.detail)
                .font(.footnote)
                .lineSpacing(3)
                .foregroundStyle(AppColors.subtext)
                .padding(.top, 2)

            if !isMember {
                Text(memberProofLine)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColors.text.opacity(0.82))
                    .lineSpacing(3)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        memberHeroChips(content.chips)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        memberHeroChips(content.chips)
                    }
                }
                .padding(.top, 4)
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

    @ViewBuilder
    private func memberHeroChips(_ chips: [String]) -> some View {
        ForEach(chips, id: \.self) { chip in
            Text(chip)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.accentDark.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.accent.opacity(0.10))
                )
        }
    }

    private var memberValueSection: some View {
        VStack(spacing: 10) {
            ForEach(memberValuePoints) { point in
                memberValueRow(
                    symbol: point.symbol,
                    title: point.title,
                    detail: point.detail
                )
            }
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
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.text.opacity(0.9))
                Text(detail)
                    .font(.footnote)
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
        .accessibilityElement(children: .combine)
    }

    private var memberBoundarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("免费与会员的差别")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text.opacity(0.9))

            VStack(spacing: 0) {
                ForEach(boundaryRows.indices, id: \.self) { index in
                    let row = boundaryRows[index]
                    ViewThatFits(in: .horizontal) {
                        memberBoundaryHorizontalRow(row)
                        memberBoundaryVerticalRow(row)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.0)，免费：\(row.1)，会员：\(row.2)")

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

    private func memberBoundaryHorizontalRow(_ row: (String, String, String)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.0)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(width: 62, alignment: .leading)
            Text(row.1)
                .font(.footnote)
                .foregroundStyle(AppColors.subtext)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.2)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColors.accent.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func memberBoundaryVerticalRow(_ row: (String, String, String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.0)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)
            Text("免费：\(row.1)")
                .font(.footnote)
                .foregroundStyle(AppColors.subtext)
            Text("会员：\(row.2)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColors.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("会员核心价值")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text.opacity(0.86))

            ForEach(benefits.indices, id: \.self) { idx in
                let (title, desc) = benefits[idx]
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text(desc)
                        .font(.footnote)
                        .foregroundStyle(AppColors.subtext)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.58))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Pricing

    private var memberLoginContinuationCard: some View {
        let content = memberLoginContinuationContent
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(AppColors.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(content.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text(content.detail)
                        .font(.footnote)
                        .foregroundStyle(AppColors.subtext)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(content.actionTitle) {
                continueMemberActionAfterLogin()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(PurposefulCardButtonStyle(radius: 14, depth: 0.8))
            .disabled(isPurchasing)

            Button("暂不继续") {
                loginContinuation.clearResumedIntent()
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(AppColors.subtext)
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var memberLoginContinuationContent: (title: String, detail: String, actionTitle: String) {
        switch loginContinuation.resumedIntent {
        case .purchase(let planID):
            let plan = plans.first(where: { $0.id == planID })
            let name = plan?.name ?? "所选会员"
            let price = plan.map { displayPrice(for: $0) } ?? "购买页价格"
            return (
                "已登录，\(name)还为你保留着",
                "不会自动购买。请再次确认 \(price) 和套餐周期，再由你明确继续。",
                "确认并继续购买"
            )
        case .restorePurchases:
            return (
                "已登录，可以继续恢复购买",
                "恢复只会查询当前 Apple ID 的历史权益，并绑定到刚登录的手机号账号。",
                "继续恢复购买"
            )
        case nil:
            return ("已登录", "会员操作需要你再次确认。", "继续")
        }
    }

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            legalPurchaseNote

            // Featured yearly plan
            featuredPlanButton(plans[0])

            // More plans toggle
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { morePlansExpanded.toggle() }
            } label: {
                HStack {
                    Text("查看更多套餐")
                        .font(.body)
                        .foregroundStyle(AppColors.text.opacity(0.8))
                    Spacer()
                    Image(systemName: morePlansExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.subtext)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 16)
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
                .font(.footnote)
                .foregroundStyle(AppColors.subtext)
                .padding(.top, 4)
        }
    }

    private var lifetimeTeaserSection: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                morePlansExpanded.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.lockGold)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(AppColors.lockGold.opacity(0.14))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("想长期保存记录？")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.text.opacity(0.9))
                    Text("永久会员一次开通，含 3 款典藏风格。")
                        .font(.footnote)
                        .foregroundStyle(AppColors.subtext)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.subtext.opacity(0.7))
                    .rotationEffect(.degrees(morePlansExpanded ? 180 : 0))
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.54))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.lockGold.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(PurposefulCardButtonStyle(radius: 12, depth: 0.65))
    }

    // MARK: - Current Member Badge

    private var currentMemberBadge: some View {
        VStack(spacing: 10) {
            Image(systemName: isLifetimeMember ? "crown.fill" : "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(isLifetimeMember ? AppColors.lockGold : AppColors.accent)
            Text(isLifetimeMember ? "你的永久记录已开启" : "感谢成为 xLife 会员")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.text)
            Text(isLifetimeMember ? "这些日子会随账号长期保留，叙账会按真实记录继续整理。" : "你的周记和月章正在持续整理中")
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
            Text(isLifetimeMember ? "你买下的不是一组功能，而是把生活长期留住的能力。" : "叙账会继续按真实记录整理每一天。")
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

    private var lifetimeArchiveSection: some View {
        let snapshot = lifetimeArchiveSnapshot
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.lockGold)
                Text("永久会员专属")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.lockGold)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(snapshot.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(snapshot.metrics) { metric in
                    lifetimeArchiveMetric(metric.value, metric.label)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                ForEach(snapshot.stages.indices, id: \.self) { index in
                    let stage = snapshot.stages[index]
                    lifetimeStage(stage.value, stage.label)
                    if index < snapshot.stages.count - 1 {
                        lifetimeStageArrow
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.primaryLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                Text(snapshot.closingLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.lockGold.opacity(0.16),
                            Color.white.opacity(0.62),
                            AppColors.accent.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.lockGold.opacity(0.28), lineWidth: 1)
        )
    }

    private func lifetimeArchiveMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.38), lineWidth: 1)
        )
    }

    private func lifetimeStage(_ day: String, _ meaning: String) -> some View {
        VStack(spacing: 3) {
            Text(day)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(meaning)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
    }

    private var lifetimeStageArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(AppColors.lockGold.opacity(0.72))
    }

    private func makeLifetimeArchiveSnapshot() -> LifetimeArchiveSnapshot {
        let positiveItems = homeViewModel.items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
        let calendar = Calendar.current
        guard !positiveItems.isEmpty else {
            return .empty
        }

        let days = Set(positiveItems.map { calendar.startOfDay(for: $0.createdAt) })
        let continuousDays = continuousRecordDays(from: days, calendar: calendar)
        let weekKeys = Set(positiveItems.map { weekKey(for: $0.createdAt, calendar: calendar) })
        let monthKeys = Set(positiveItems.map { monthKey(for: $0.createdAt, calendar: calendar) })
        let activeDays = days.count
        let traceCount = positiveItems.count
        let firstDate = positiveItems.map(\.createdAt).min() ?? Date()
        let latestDate = positiveItems.map(\.createdAt).max() ?? Date()
        let spanDays = max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: firstDate), to: calendar.startOfDay(for: latestDate)).day ?? 0) + 1)
        let marks = LifeMarkService.aggregates(
            for: positiveItems,
            allItems: positiveItems,
            isMember: true,
            limit: 6
        )
        let primaryMark = marks.first
        let title = lifetimeArchiveTitle(
            traceCount: traceCount,
            monthCount: monthKeys.count,
            primaryMark: primaryMark
        )
        let subtitle = lifetimeArchiveSubtitle(
            traceCount: traceCount,
            activeDays: activeDays,
            spanDays: spanDays,
            primaryMark: primaryMark
        )
        let thirdMetric = lifetimeArchiveSceneMetric(
            primaryMark: primaryMark,
            activeDays: activeDays
        )
        let fourthMetric = monthKeys.count > 1
            ? LifetimeArchiveMetric(value: "\(monthKeys.count)个月", label: "月份跨度")
            : LifetimeArchiveMetric(value: "\(weekKeys.count)篇", label: "周记素材")
        return LifetimeArchiveSnapshot(
            title: title,
            subtitle: subtitle,
            metrics: [
                LifetimeArchiveMetric(value: "\(max(1, continuousDays))天", label: "连续记录"),
                LifetimeArchiveMetric(value: "\(traceCount)条", label: "记录条数"),
                thirdMetric,
                fourthMetric
            ],
            stages: lifetimeArchiveStages(activeDays: activeDays),
            primaryLine: lifetimeArchivePrimaryLine(
                primaryMark: primaryMark,
                traceCount: traceCount,
                spanDays: spanDays
            ),
            closingLine: lifetimeArchiveClosingLine(
                primaryMark: primaryMark,
                activeDays: activeDays,
                monthCount: monthKeys.count
            )
        )
    }

    private func refreshLifetimeArchiveSnapshot() {
        lifetimeArchiveSnapshot = makeLifetimeArchiveSnapshot()
    }

    private func scheduleLifetimeArchiveSnapshotRefresh() {
        DispatchQueue.main.async {
            refreshLifetimeArchiveSnapshot()
        }
    }

    private func lifetimeArchiveTitle(
        traceCount: Int,
        monthCount: Int,
        primaryMark: LifeMarkAggregate?
    ) -> String {
        if let primaryMark {
            switch primaryMark.kind {
            case .context:
                return "你的\(primaryMark.label)已经被记住"
            case .milestone:
                return primaryMark.title
            case .streak:
                return "\(primaryMark.label)正在形成节奏"
            case .scene:
                return "\(primaryMark.label)已经有连续记录"
            }
        }
        if monthCount >= 2 {
            return "你的记录已经跨过 \(monthCount) 个月"
        }
        return traceCount >= 10 ? "你的长期记录正在形成" : "这些记录已经有了开头"
    }

    private func lifetimeArchiveSubtitle(
        traceCount: Int,
        activeDays: Int,
        spanDays: Int,
        primaryMark: LifeMarkAggregate?
    ) -> String {
        if let primaryMark {
            return primaryMark.detail
        }
        if spanDays > activeDays {
            return "\(traceCount) 条记录分布在 \(activeDays) 个日子里，时间跨度已经有 \(spanDays) 天。"
        }
        return "\(traceCount) 条记录来自真实账本，后面会继续整理成周记、月章和回放。"
    }

    private func lifetimeArchiveSceneMetric(
        primaryMark: LifeMarkAggregate?,
        activeDays: Int
    ) -> LifetimeArchiveMetric {
        guard let primaryMark, primaryMark.count > 0 else {
            return LifetimeArchiveMetric(value: "\(activeDays)天", label: "有记录的日子")
        }
        return LifetimeArchiveMetric(
            value: "\(primaryMark.count)次",
            label: primaryMark.label
        )
    }

    private func lifetimeArchiveStages(activeDays: Int) -> [LifetimeArchiveStage] {
        let currentDays = max(1, activeDays)
        let nextTarget = [7, 17, 30, 60, 100, 170, 365, 700, 1000, 1700]
            .first { $0 > currentDays } ?? (currentDays + 365)
        let longTarget = max(1700, nextTarget * 3)
        return [
            LifetimeArchiveStage(value: "\(currentDays)天", label: "已记录"),
            LifetimeArchiveStage(value: "\(nextTarget)天", label: "下一站"),
            LifetimeArchiveStage(value: "\(longTarget)天", label: "长期记录")
        ]
    }

    private func lifetimeArchivePrimaryLine(
        primaryMark: LifeMarkAggregate?,
        traceCount: Int,
        spanDays: Int
    ) -> String {
        if let primaryMark {
            return "最近最清楚的是「\(primaryMark.label)」：\(primaryMark.count) 次、合计 \(primaryMark.total.formatted(.cny))，以后能继续和天气、地点、周记和月章连起来。"
        }
        return "\(traceCount) 条账单已经覆盖 \(spanDays) 天。记录越多，本机规则能整理出的日期、分类和场景就越完整。"
    }

    private func lifetimeArchiveClosingLine(
        primaryMark: LifeMarkAggregate?,
        activeDays: Int,
        monthCount: Int
    ) -> String {
        if let primaryMark {
            return "这不是固定文案，会按你账本里的「\(primaryMark.label)」更新。"
        }
        if monthCount >= 2 {
            return "它会从单笔账单，接成跨月份的生活回望。"
        }
        return activeDays >= 7 ? "这些日子已经连起来了，后面会有更多可回看的记录。" : "先把今天记下来，后面会有可回看的记录。"
    }

    private func continuousRecordDays(from days: Set<Date>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor), let latest = days.max() {
            cursor = latest
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    private func weekKey(for date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return "\(year)-\(week)"
    }

    private func monthKey(for date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return "\(year)-\(month)"
    }

    // MARK: - Privacy

    private var privacyNote: some View {
        Text("默认不登录也能记账。开启云端备份后，仅同步金额、分类、备注、日期等账单字段与会员状态；OCR 原始图片和记忆照片都不会上传服务器。")
            .font(.footnote)
            .foregroundStyle(AppColors.subtext)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legalPurchaseNote: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                legalPurchaseLinks
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("购买前请阅读")
                    .foregroundStyle(AppColors.subtext)
                HStack(spacing: 6) {
                    Link("用户协议", destination: termsURL)
                    Text("和")
                        .foregroundStyle(AppColors.subtext)
                    Link("隐私政策", destination: privacyURL)
                }
                .foregroundStyle(AppColors.accentDark)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var legalPurchaseLinks: some View {
        Text("购买前请阅读")
            .foregroundStyle(AppColors.subtext)
        Link("用户协议", destination: termsURL)
            .foregroundStyle(AppColors.accentDark)
        Text("和")
            .foregroundStyle(AppColors.subtext)
        Link("隐私政策", destination: privacyURL)
            .foregroundStyle(AppColors.accentDark)
    }

    private var freeQuotaNote: some View {
        Text(freeQuotaFootnote)
            .font(.footnote)
            .foregroundStyle(AppColors.subtext)
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
                        .font(.caption.weight(.bold))
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
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(plan.dailyHint)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
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
        .buttonStyle(PurposefulCardButtonStyle(radius: 14, depth: 1.05))
        .disabled(isPurchasing)
        .id("member-plan-\(plan.id)")
    }

    private func regularPlanButton(_ plan: MemberPlan) -> some View {
        let isHighlighted = effectiveHighlightPlanID == plan.id
        return Button {
            handlePurchase(plan)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(plan.name)：\(displayPrice(for: plan)) / \(plan.period)")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                Text(plan.dailyHint)
                    .font(.footnote)
                    .foregroundStyle(AppColors.subtext)
                if plan.id == "lifetime" {
                    lifetimeThemeBullet
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.58))
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
        .buttonStyle(PurposefulCardButtonStyle(radius: 12, depth: isHighlighted ? 0.95 : 0.75))
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
        .font(.footnote)
        .lineSpacing(2)
    }

    private func applyHighlightIfNeeded(_ proxy: ScrollViewProxy) {
        guard highlightPlanId == "lifetime", !didApplyHighlight else { return }
        didApplyHighlight = true
        morePlansExpanded = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if !isPurchasing {
                proxy.scrollTo("member-plan-lifetime", anchor: .center)
            }
        }
    }

    private func runInitialRefreshIfNeeded() async {
        guard !didRunInitialRefresh else { return }
        didRunInitialRefresh = true
        await settingsViewModel.refreshCloudAccountProfile()
        guard !Task.isCancelled else { return }
        await settingsViewModel.refreshMemberFromLocalEntitlements()
        guard !Task.isCancelled else { return }
        await loadStoreProducts()
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
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    // MARK: - Purchase Handler

    private func requestMemberLogin(for intent: MemberLoginContinuationIntent) {
        guard !isPurchasing else { return }
        purchaseNotice = nil
        loginContinuation.beginLogin(for: intent)
        settingsViewModel.clearAuthMessage()
        showMemberLoginSheet = true
    }

    private func handleMemberLoginSucceeded() {
        guard loginContinuation.pendingLoginIntent != nil else { return }
        loginContinuation.loginSucceeded()
        showMemberLoginSheet = false
        if isMember {
            loginContinuation.clearResumedIntent()
            purchaseNotice = "已登录，当前账号的会员权益已经同步，不需要重复购买。"
            return
        }
        if case .purchase(let planID) = loginContinuation.resumedIntent,
           planID != "yearly" {
            morePlansExpanded = true
        }
    }

    private func handleMemberLoginSheetDismissed() {
        guard !settingsViewModel.hasCloudSession else { return }
        loginContinuation.loginCancelled()
    }

    private func continueMemberActionAfterLogin() {
        guard let intent = loginContinuation.takeResumedIntent() else { return }
        switch intent {
        case .purchase(let planID):
            guard let plan = plans.first(where: { $0.id == planID }) else { return }
            handlePurchase(plan)
        case .restorePurchases:
            restorePurchases()
        }
    }

    private func handlePurchase(_ plan: MemberPlan) {
        guard settingsViewModel.hasCloudSession else {
            homeViewModel.markMemberPurchaseCompleted(plan: plan.id, outcome: .blocked)
            requestMemberLogin(for: .purchase(planID: plan.id))
            return
        }
        guard let tier = IAPTier(rawValue: plan.id) else { return }
        guard let appAccountToken = UUID(uuidString: settingsViewModel.cloudUserId) else {
            homeViewModel.markMemberPurchaseCompleted(plan: plan.id, outcome: .blocked)
            purchaseNotice = "当前账号状态异常，请重新登录手机号账号后再开通会员。"
            return
        }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let payload = try await iapService.purchase(tier: tier, appAccountToken: appAccountToken)
                try await settingsViewModel.verifyIAPPurchase(payload)
                await iapService.finish(transactionId: payload.transactionId)
                homeViewModel.markMemberPurchaseCompleted(plan: plan.id, outcome: .success)
                purchaseNotice = "会员已开通，回放和导入额度已更新。"
            } catch {
                homeViewModel.markMemberPurchaseCompleted(plan: plan.id, outcome: .failure)
                purchaseNotice = (error as? LocalizedError)?.errorDescription ?? "购买没有完成。请确认支付状态后再试。"
            }
        }
    }

    private func restorePurchases() {
        guard settingsViewModel.hasCloudSession else {
            homeViewModel.markMemberRestoreCompleted(outcome: .blocked)
            requestMemberLogin(for: .restorePurchases)
            return
        }
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                let payloads = try await iapService.restorePurchases()
                guard !payloads.isEmpty else {
                    homeViewModel.markMemberRestoreCompleted(outcome: .empty)
                    purchaseNotice = "暂时没有找到可恢复的购买记录。请确认已登录购买时绑定的手机号账号。"
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
                    homeViewModel.markMemberRestoreCompleted(outcome: .empty)
                    purchaseNotice = "当前账号暂时没有可恢复的会员权益。请确认使用的是购买时的账号。"
                    return
                }
                await iapService.finish(transactionId: restoredPayload.transactionId)
                homeViewModel.markMemberRestoreCompleted(outcome: .success)
                purchaseNotice = "会员权益已恢复，可以继续使用。"
            } catch {
                homeViewModel.markMemberRestoreCompleted(outcome: .failure)
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

private struct MemberAccountLoginSheet: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    let intent: MemberLoginContinuationIntent?
    @FocusState private var focusedField: LoginField?
    private let termsURL = URL(string: "https://xuzhangapp.com/legal/terms.html")!
    private let privacyURL = URL(string: "https://xuzhangapp.com/legal/privacy.html")!

    private enum LoginField {
        case phone
        case code
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("先登录账号", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppColors.text)
                        Text(loginPurposeText)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.subtext)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        loginField("手机号") {
                            TextField("11 位手机号", text: $settingsViewModel.loginPhone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .focused($focusedField, equals: .phone)
                        }

                        loginField("验证码") {
                            HStack(spacing: 10) {
                                TextField("短信验证码", text: $settingsViewModel.loginCode)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .focused($focusedField, equals: .code)

                                Button(sendCodeTitle) {
                                    Task { await settingsViewModel.sendSMSLoginCode() }
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(sendCodeDisabled ? AppColors.subtext : AppColors.accent)
                                .frame(minHeight: 44)
                                .padding(.horizontal, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(AppColors.accent.opacity(sendCodeDisabled ? 0.04 : 0.11))
                                )
                                .buttonStyle(.plain)
                                .disabled(sendCodeDisabled)
                            }
                        }

                        Button(settingsViewModel.isAuthBusy ? "正在验证…" : "验证并登录") {
                            focusedField = nil
                            Task { await settingsViewModel.verifySMSLogin() }
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            loginButtonDisabled ? AppColors.subtext.opacity(0.32) : AppColors.accent,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .buttonStyle(.plain)
                        .disabled(loginButtonDisabled)

                        if let message = settingsViewModel.authMessage, !message.isEmpty {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(AppColors.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                    .padding(15)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.58))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.line.opacity(0.56), lineWidth: 1)
                    )

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) { loginLegalLinks }
                        VStack(alignment: .leading, spacing: 5) { loginLegalLinks }
                    }
                    .font(.footnote)

                    Text("登录成功只会返回会员页并恢复刚才的选择；购买或恢复仍要由你再次明确点击。")
                        .font(.footnote)
                        .foregroundStyle(AppColors.subtext.opacity(0.9))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("账号登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(settingsViewModel.isAuthBusy)
                }
            }
        }
        .interactiveDismissDisabled(settingsViewModel.isAuthBusy)
    }

    private var loginPurposeText: String {
        switch intent {
        case .purchase(let planID):
            let name: String
            switch planID {
            case "yearly": name = "年度会员"
            case "monthly": name = "月度会员"
            case "lifetime": name = "永久会员"
            default: name = "所选会员"
            }
            return "登录后会回到会员页，并保留刚才选择的\(name)。不会自动购买。"
        case .restorePurchases:
            return "登录后会回到会员页，再由你确认是否查询并恢复当前 Apple ID 的历史权益。"
        case nil:
            return "登录后会回到会员页，会员操作仍由你确认。"
        }
    }

    private var phoneIsValid: Bool {
        let phone = settingsViewModel.loginPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        return phone.count == 11 && phone.hasPrefix("1")
    }

    private var sendCodeDisabled: Bool {
        settingsViewModel.isAuthBusy
            || settingsViewModel.smsCooldownRemaining > 0
            || !phoneIsValid
    }

    private var loginButtonDisabled: Bool {
        settingsViewModel.isAuthBusy
            || !phoneIsValid
            || settingsViewModel.loginCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sendCodeTitle: String {
        let remaining = settingsViewModel.smsCooldownRemaining
        return remaining > 0 ? "\(remaining)s 后重发" : "发送验证码"
    }

    private func loginField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppColors.text.opacity(0.82))
            content()
                .font(.body)
                .padding(.horizontal, 13)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(AppColors.line.opacity(0.48), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var loginLegalLinks: some View {
        Text("登录即表示你同意")
            .foregroundStyle(AppColors.subtext)
        Link("用户协议", destination: termsURL)
            .foregroundStyle(AppColors.accentDark)
        Text("和")
            .foregroundStyle(AppColors.subtext)
        Link("隐私政策", destination: privacyURL)
            .foregroundStyle(AppColors.accentDark)
    }
}

private struct LifetimeArchiveSnapshot {
    let title: String
    let subtitle: String
    let metrics: [LifetimeArchiveMetric]
    let stages: [LifetimeArchiveStage]
    let primaryLine: String
    let closingLine: String

    static let empty = LifetimeArchiveSnapshot(
        title: "从第一笔开始，长期记录会逐步形成",
        subtitle: "永久会员不是一段固定说明，而是把以后每一天的记录都长期保存。",
        metrics: [
            LifetimeArchiveMetric(value: "0天", label: "连续记录"),
            LifetimeArchiveMetric(value: "0条", label: "记录条数"),
            LifetimeArchiveMetric(value: "0天", label: "有记录的日子"),
            LifetimeArchiveMetric(value: "0个月", label: "月份跨度")
        ],
        stages: [
            LifetimeArchiveStage(value: "1天", label: "开始"),
            LifetimeArchiveStage(value: "7天", label: "连起来"),
            LifetimeArchiveStage(value: "30天", label: "月章")
        ],
        primaryLine: "有了真实记录后，这里会自动换成你的连续天数、同类记录、周记和月章素材。",
        closingLine: "它会跟着你的账本长，不是一张固定权益图。"
    )
}

private struct LifetimeArchiveMetric: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}

private struct LifetimeArchiveStage {
    let value: String
    let label: String
}

// MARK: - Preview

struct MemberPricingView_Previews: PreviewProvider {
    static var previews: some View {
        MemberPricingView()
            .environmentObject(SettingsViewModel())
            .environmentObject(HomeViewModel())
    }
}
