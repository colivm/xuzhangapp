import SwiftUI
import UIKit

// MARK: - Insight View

struct InsightWebView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    @State private var monthlyInsightGenerated = false
    @State private var showAdvancedInsight = false
    @State private var monthlyTrialUsed = UserDefaults.standard.integer(forKey: "monthly_trial_used_v1")
    @State private var monthlyReport: HomeViewModel.MonthlyInsightReport?
    @State private var monthlyAIStatus: AIStatusPill?
    @State private var monthlyTrialModal: MonthlyTrialModal?
    private let trialTotal = 5

    private struct AIStatusPill: Equatable {
        enum Kind {
            case live
            case fallback
            case error
        }

        var kind: Kind
        var text: String
    }

    private struct MonthlyTrialModal: Identifiable {
        let id = UUID()
        var title: String
        var body: String
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                // ── 近 7 天生活复盘 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("近 7 天生活复盘")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    let weeklyBlocks = homeViewModel.localWeeklyInsightBlocks()
                    if weeklyBlocks.summary.contains("暂无复盘") {
                        Text(weeklyBlocks.summary)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.subtext)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(weeklyBlocks.summary)
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.text)
                            Text(weeklyBlocks.structure)
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.subtext)
                            Text(weeklyBlocks.advice)
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.subtext)
                        }
                    }

                    // Soft action buttons (matching web weekly-soft-actions)
                    softActionButton("梳理本周节奏") {
                        let text = homeViewModel.buildWeeklyRhythmText()
                        homeViewModel.setLatestActionCard(text, scope: "weekly")
                        homeViewModel.markWeeklyRhythmReviewed()
                    }
                    softActionButton("生成周度分享卡") {
                        homeViewModel.markWeeklyShareGenerated()
                        generateAndShareWeeklyCard()
                    }
                    if !homeViewModel.weekTopCategoryText.isEmpty && homeViewModel.weekTopCategoryText != "暂无" {
                        softActionButton("标记常花类目") {
                            homeViewModel.markWeeklyTag()
                        }
                    }
                }
                .glassPanel(radius: 24, padding: 20)

                // ── 月度生活复盘 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("月度生活复盘")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    let left = max(0, trialTotal - monthlyTrialUsed)
                    let isMember = ["monthly", "yearly", "lifetime"].contains(settingsViewModel.memberTier.lowercased())
                    let exhausted = !isMember && monthlyTrialUsed >= trialTotal

                    if !isMember {
                        Text(exhausted ? "免费试用次数已用完" : "剩余试用次数：\(left)/\(trialTotal)")
                            .font(.system(size: 12))
                            .foregroundStyle(exhausted ? Color.orange.opacity(0.8) : AppColors.subtext)
                    }

                    if exhausted {
                        // Trial exhausted - show upgrade
                        Button {
                            monthlyTrialModal = MonthlyTrialModal(
                                title: "免费次数已用完",
                                body: "您的免费月度复盘次数已用完，升级会员即可解锁无限次月度/季度/年度 AI 复盘，还有更多专属权益等你体验。"
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Text("🔒 开通会员解锁无限复盘")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.6)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            Task {
                                await generateMonthlyInsight(isMember: isMember)
                            }
                        } label: {
                            Text(homeViewModel.isGeneratingMonthlyInsight ? "正在生成月度复盘..." : "生成月度复盘")
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
                    .disabled(homeViewModel.isGeneratingMonthlyInsight)
                        }

                    if let status = monthlyAIStatus ?? defaultMonthlyAIStatus {
                        aiStatusPill(status)
                    }

                    if let error = homeViewModel.insightErrorMessage,
                       monthlyAIStatus?.kind == .error {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.orange.opacity(0.9))
                            .lineLimit(3)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.orange.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                            )
                    }

                    if monthlyInsightGenerated, let report = monthlyReport {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(report.summary)
                                .font(.system(size: 14))
                                .foregroundStyle(AppColors.text)
                            Text(report.structure)
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.subtext)
                            Text(report.advice)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.text)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppColors.accent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
                        )

                        // Monthly soft actions
                        softActionButton("记一句本月收束") {
                            homeViewModel.markMonthlyClosing()
                        }
                        softActionButton("保存月度小结") {
                            homeViewModel.markMonthlySaveSummary()
                        }
                        softActionButton("切换叙述风格") {
                            homeViewModel.regenerateMonthlyInsight()
                        }
                    }

                    // Advanced insight toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAdvancedInsight.toggle()
                        }
                    } label: {
                        Text(showAdvancedInsight ? "收起更多复盘" : "查看更多复盘")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.subtext.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            )
                    }
                    .buttonStyle(.plain)

                    if showAdvancedInsight {
                        if settingsViewModel.memberTier == "free" {
                            Button {
                                onShowMemberPricing?()
                            } label: {
                                lockedReportButton("生成季度复盘")
                            }
                            .buttonStyle(.plain)
                            Button {
                                onShowMemberPricing?()
                            } label: {
                                lockedReportButton("生成年度复盘")
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("季度 / 年度复盘正在打磨中，先从每周和每月慢慢回看。")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.subtext)
                        }
                    }
                }
                .glassPanel(radius: 24, padding: 20)

                // ── 今日生活小记 ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日生活小记")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    if let insight = homeViewModel.todayInsight {
                        Text(insight.summary)
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.text)
                        Text(insight.action)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                        Text(insight.encourage)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.subtext)
                    } else {
                        Text("还没有今日复盘。")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.subtext)
                    }

                    Button("换个轻读版本") {
                        Task {
                            await homeViewModel.regenerateTodayInsight(
                                userName: settingsViewModel.displayName,
                                settings: settingsViewModel.settings
                            )
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.subtext.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
                    .buttonStyle(.plain)

                    if homeViewModel.isGeneratingInsight {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("AI 正在生成中…")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.subtext)
                        }
                        .padding(.top, 4)
                    }

                    if let error = homeViewModel.insightErrorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.subtext)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(red: 255/255, green: 246/255, blue: 222/255).opacity(0.78))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color(red: 228/255, green: 201/255, blue: 134/255).opacity(0.48), lineWidth: 1)
                            )
                    }
                }
                .glassPanel(radius: 24, padding: 20)
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 120)
                .frame(maxWidth: 430)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)

            if let modal = monthlyTrialModal {
                monthlyTrialOverlay(modal)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: monthlyTrialModal?.id)
    }

    private func monthlyTrialOverlay(_ modal: MonthlyTrialModal) -> some View {
        ZStack {
            Color.black.opacity(0.26)
                .ignoresSafeArea()
                .onTapGesture {
                    monthlyTrialModal = nil
                }

            VStack(spacing: 18) {
                Text(modal.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)

                Text(modal.body)
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.subtext)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 14) {
                    Button {
                        monthlyTrialModal = nil
                    } label: {
                        Text("我知道了")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        monthlyTrialModal = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            onShowMemberPricing?()
                        }
                    } label: {
                        Text("解锁无限次复盘")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AppColors.accent.opacity(0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(28)
            .frame(maxWidth: 390)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.panel)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.66), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 22, x: 0, y: 10)
            .padding(.horizontal, 28)
        }
    }

    private var defaultMonthlyAIStatus: AIStatusPill? {
        if homeViewModel.isGeneratingMonthlyInsight {
            return settingsViewModel.useRemoteAI
                ? AIStatusPill(kind: .live, text: "AI 在线，实时分析中")
                : AIStatusPill(kind: .fallback, text: "本地兜底，稳定可用")
        }
        guard settingsViewModel.useRemoteAI else {
            return AIStatusPill(kind: .fallback, text: "本地兜底，稳定可用")
        }
        let endpoint = settingsViewModel.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDirectModelEndpoint = endpoint.isEmpty || endpoint.contains("open.bigmodel.cn")
        if isDirectModelEndpoint && KeychainService.loadAIAPIKey().isEmpty {
            return AIStatusPill(kind: .error, text: "本地计算，AI Key 未配置")
        }
        return AIStatusPill(kind: .live, text: "AI 在线，生成时会尝试实时分析")
    }

    private func aiStatusPill(_ status: AIStatusPill) -> some View {
        let palette: (fg: Color, bg: Color, border: Color)
        switch status.kind {
        case .live:
            palette = (
                AppColors.accent.opacity(0.95),
                AppColors.accent.opacity(0.13),
                AppColors.accent.opacity(0.28)
            )
        case .fallback:
            palette = (
                Color(red: 128/255, green: 98/255, blue: 42/255),
                Color(red: 255/255, green: 246/255, blue: 222/255).opacity(0.82),
                Color(red: 228/255, green: 201/255, blue: 134/255).opacity(0.55)
            )
        case .error:
            palette = (
                Color.orange.opacity(0.88),
                Color.orange.opacity(0.12),
                Color.orange.opacity(0.28)
            )
        }

        return HStack(spacing: 6) {
            Circle()
                .fill(palette.fg)
                .frame(width: 8, height: 8)
            Text(status.text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(palette.fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule(style: .continuous).fill(palette.bg))
        .overlay(
            Capsule(style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private func generateMonthlyInsight(isMember: Bool) async {
        let firstTime = !isMember && monthlyTrialUsed == 0
        monthlyAIStatus = settingsViewModel.useRemoteAI
            ? AIStatusPill(kind: .live, text: "AI 在线，实时分析中")
            : AIStatusPill(kind: .fallback, text: "本地兜底，稳定可用")

        let report = await homeViewModel.generateMonthlyInsight(settings: settingsViewModel.settings)

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.25)) {
                monthlyReport = report
                monthlyInsightGenerated = true
                monthlyAIStatus = aiStatus(for: report.source)
            }

            guard !isMember else { return }
            monthlyTrialUsed += 1
            UserDefaults.standard.set(monthlyTrialUsed, forKey: "monthly_trial_used_v1")
            let left = max(0, trialTotal - monthlyTrialUsed)
            monthlyTrialModal = firstTime
                ? MonthlyTrialModal(
                    title: "🎁 新用户福利",
                    body: "您已获得 5 次免费月度 AI 复盘机会，本次消耗 1 次，剩余 \(left) 次。"
                )
                : MonthlyTrialModal(
                    title: "月度复盘已生成",
                    body: "本次消耗 1 次免费次数，剩余 \(left) 次。"
                )
        }
    }

    private func aiStatus(for source: HomeViewModel.AIInsightSource) -> AIStatusPill {
        switch source {
        case .live:
            return AIStatusPill(kind: .live, text: "AI 在线，已完成实时分析")
        case .fallback:
            return AIStatusPill(kind: .fallback, text: "本地兜底，稳定可用")
        case .errorFallback:
            return AIStatusPill(kind: .error, text: "本地计算，远程 AI 未接通")
        }
    }

    private func softActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.84))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(0.985)
        .animation(.easeOut(duration: 0.1), value: UUID())
    }

    private func lockedReportButton(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text("🔒︎")
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 14))
        }
        .foregroundStyle(AppColors.subtext.opacity(0.86))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Share Card Generation

    private func generateAndShareWeeklyCard() {
        guard let payload = PlaybackService().buildWeeklyShareCardPayload(from: homeViewModel.items) else { return }
        let petMode = settingsViewModel.petCompanionEnabled
        let nick = settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName
        let card = WeeklyShareCardView(
            payload: payload,
            isPetMode: petMode,
            nickname: nick
        )
        guard let img = card.snapshot() else { return }
        let av = UIActivityViewController(activityItems: [img], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController {
            vc.present(av, animated: true)
        }
    }
}

// MARK: - Weekly Share Card

struct WeeklyShareCardView: View {
    let weekTotal: Double
    let topCategory: String
    let recordCount: Int
    let dailyTrend: [(String, Double)]
    let topCategoryRatio: Double
    let headline: String
    let subtitle: String
    let periodText: String
    var isPetMode: Bool = true
    var nickname: String = "叙账用户"

    private var t: ShareCardTheme { isPetMode ? .pet : .neutral }

    struct ShareCardTheme {
        let bgStart, bgEnd: Color; let panelBg, panelBorder: Color
        let accent, accentSoft, titleSub, textMain, textMuted: Color
        let trendBg, trendBorder, ringBg, ringBorder, ringTrack, ringArc: Color
        let footer, footerSub: Color
        static let pet = ShareCardTheme(
            bgStart: Color(hex: "fff3e8"), bgEnd: Color(hex: "ffe9f2"),
            panelBg: Color.white.opacity(0.94), panelBorder: Color(hex: "efd7c7"),
            accent: Color(hex: "d48754"), accentSoft: Color(hex: "e4a57a"),
            titleSub: Color(hex: "b79a86"), textMain: Color(hex: "4a3f37"), textMuted: Color(hex: "957f70"),
            trendBg: Color(hex: "d48754").opacity(0.11), trendBorder: Color(hex: "d48754").opacity(0.28),
            ringBg: Color(hex: "d48754").opacity(0.10), ringBorder: Color(hex: "d48754").opacity(0.24),
            ringTrack: Color(hex: "e4a57a").opacity(0.22), ringArc: Color(hex: "d48754"),
            footer: Color(hex: "887566"), footerSub: Color(hex: "b19c8e"))
        static let neutral = ShareCardTheme(
            bgStart: Color(hex: "f3f6fb"), bgEnd: Color(hex: "edf1f7"),
            panelBg: Color.white.opacity(0.95), panelBorder: Color(hex: "d8deea"),
            accent: Color(hex: "5e708a"), accentSoft: Color(hex: "7788a2"),
            titleSub: Color(hex: "8c96a8"), textMain: Color(hex: "2f3947"), textMuted: Color(hex: "6f7a8d"),
            trendBg: Color(hex: "5e708a").opacity(0.10), trendBorder: Color(hex: "5e708a").opacity(0.24),
            ringBg: Color(hex: "5e708a").opacity(0.10), ringBorder: Color(hex: "5e708a").opacity(0.22),
            ringTrack: Color(hex: "7788a2").opacity(0.22), ringArc: Color(hex: "5e708a"),
            footer: Color(hex: "6b7688"), footerSub: Color(hex: "8f99ab"))
    }

    init(
        weekTotal: Double,
        topCategory: String,
        recordCount: Int,
        dailyTrend: [(String, Double)],
        topCategoryRatio: Double,
        headline: String = "这一周你记录得很认真",
        subtitle: String = "温柔回看，不必苛责，按自己的节奏慢慢生活。",
        periodText: String? = nil,
        isPetMode: Bool = true,
        nickname: String = "叙账用户"
    ) {
        self.weekTotal = weekTotal
        self.topCategory = topCategory
        self.recordCount = recordCount
        self.dailyTrend = dailyTrend
        self.topCategoryRatio = topCategoryRatio
        self.headline = headline
        self.subtitle = subtitle
        self.periodText = periodText ?? Self.defaultPeriodText()
        self.isPetMode = isPetMode
        self.nickname = nickname
    }

    init(payload: WeeklyShareCardPayload, isPetMode: Bool = true, nickname: String = "叙账用户") {
        self.init(
            weekTotal: payload.weekTotal,
            topCategory: payload.topCategory,
            recordCount: payload.recordCount,
            dailyTrend: payload.dailyTrend,
            topCategoryRatio: payload.topCategoryRatio,
            headline: payload.headline,
            subtitle: payload.subtitle,
            periodText: payload.periodText,
            isPetMode: isPetMode,
            nickname: nickname
        )
    }

    private static func defaultPeriodText() -> String {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else { return "" }
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"
        return "\(f.string(from: start)) ~ \(f.string(from: Date()))"
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(colors: [t.bgStart, t.bgEnd], startPoint: .top, endPoint: .bottom)

            // Panel card
            RoundedRectangle(cornerRadius: 18).fill(t.panelBg)
                .shadow(color: t.accent.opacity(0.18), radius: 12, y: 3)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(t.panelBorder, lineWidth: 1))
                .padding(28)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text("叙账 · 周度分享卡")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(t.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(periodText)
                    .font(.system(size: 12))
                    .foregroundStyle(t.titleSub)
                    .padding(.top, 3)

                Text("你好，\(nickname)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.textMain)
                    .padding(.top, 20)
                Text(headline)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(t.textMain)
                    .padding(.top, 3)
                    .lineLimit(3)
                    .minimumScaleFactor(0.76)

                // Stats
                HStack(spacing: 8) {
                    storyMetric("记录", "\(recordCount) 笔")
                    storyMetric("支出", weekTotal.formatted(.cny))
                    storyMetric("主料", topCategory)
                }
                .padding(.top, 20)

                // Charts stacked vertically (HStack overflows at 390pt)
                VStack(alignment: .leading, spacing: 10) {
                    trendChart
                    ringChart
                }
                .padding(.top, 15)

                Spacer(minLength: 12)

                // Footer
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(t.footer)
                    .frame(maxWidth: .infinity)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("来自 叙账 · 温柔回看每一周")
                    .font(.system(size: 10))
                    .foregroundStyle(t.footerSub)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 42)
        }
        .overlay(alignment: .topTrailing) {
            cornerDec
                .frame(width: 52, height: 36)
                .padding(.top, 32)
                .padding(.trailing, 32)
        }
        .frame(width: 390, height: 580)
        .clipped()
    }

    private func storyMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(t.textMuted)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(t.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Corner decoration

    @ViewBuilder private var cornerDec: some View {
        if isPetMode {
            Path { p in
                p.move(to: CGPoint(x: 12, y: 20)); p.addLine(to: CGPoint(x: 10, y: 2)); p.addLine(to: CGPoint(x: 20, y: 14))
                p.move(to: CGPoint(x: 38, y: 20)); p.addLine(to: CGPoint(x: 40, y: 2)); p.addLine(to: CGPoint(x: 30, y: 14))
                p.addEllipse(in: CGRect(x: 10, y: 14, width: 30, height: 22))
            }.stroke(t.accent.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        } else {
            VStack(spacing: 4) { ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 2).fill(t.accent.opacity(0.72 - Double(i)*0.1)).frame(width: 38-CGFloat(i)*6, height: 4)
            }}.rotationEffect(.degrees(12)).offset(y: -6)
        }
    }

    // MARK: - Trend chart

    private var trendChart: some View {
        let maxV = max(dailyTrend.map(\.1).max() ?? 1, 1)
        let peak = dailyTrend.map(\.1).max() ?? 0
        let barW: CGFloat = 16; let gap: CGFloat = 4; let chartH: CGFloat = 64

        return VStack(alignment: .leading, spacing: 0) {
            Text("近7天小趋势")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(t.textMuted)
                .padding(.leading, 8).padding(.top, 6)

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(dailyTrend.enumerated()), id: \.offset) { idx, pt in
                    let h = max(3, (pt.1 / maxV) * chartH)
                    VStack(spacing: 2) {
                        if pt.1 > 0 && pt.1 == peak {
                            RoundedRectangle(cornerRadius: 4).fill(t.accent).frame(width: barW, height: h)
                                .shadow(color: t.accent.opacity(0.35), radius: 3, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: barW - 6, height: 3)
                                        .offset(y: -(h - 6) / 2)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(pt.1 > 0 ? t.accent.opacity(0.7) : t.accent.opacity(0.22))
                                .frame(width: barW, height: h)
                        }
                        Text(pt.0).font(.system(size: 6)).foregroundStyle(t.titleSub)
                    }
                }
            }
            .frame(height: chartH + 12)
            .padding(.horizontal, 8).padding(.bottom, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 10).fill(t.trendBg)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.trendBorder, lineWidth: 1))
        )
    }

    // MARK: - Ring chart

    private var ringChart: some View {
        let ratio = max(0, min(1, topCategoryRatio))
        let ratioPct = Int(round(ratio * 100))

        return HStack(spacing: 10) {
            ZStack {
                Circle().stroke(t.ringTrack, lineWidth: 7).frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: CGFloat(ratio))
                    .stroke(t.ringArc, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(ratioPct)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(t.accent)
                    Text("TOP")
                        .font(.system(size: 6))
                        .foregroundStyle(t.textMuted)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                legend(t.accent, "\(topCategory)占比最高")
                legend(t.accent.opacity(0.5), "本周记录节奏平稳")
                legend(t.accent.opacity(0.2), "继续按笔记录更好")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(t.ringBg)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.ringBorder, lineWidth: 1))
        )
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(c).frame(width: 4, height: 4)
            Text(t).font(.system(size: 8)).foregroundStyle(self.t.textMuted)
        }
    }

    func snapshot() -> UIImage? {
        let size = CGSize(width: 390, height: 580)
        let host = UIHostingController(rootView: self.frame(width: size.width, height: size.height))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .clear
        let win = UIWindow(frame: CGRect(origin: .zero, size: size))
        win.rootViewController = host
        win.isHidden = false
        win.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 3.0
        let renderer = UIGraphicsImageRenderer(size: size, format: fmt)
        let img = renderer.image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        win.isHidden = true
        return img
    }
}

// Color hex helper
extension Color {
    init(hex: String) {
        let r, g, b: Double
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0; Scanner(string: s).scanHexInt64(&n)
        r = Double((n >> 16) & 0xFF) / 255.0
        g = Double((n >> 8) & 0xFF) / 255.0
        b = Double(n & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

