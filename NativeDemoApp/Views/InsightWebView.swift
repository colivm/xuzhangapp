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
    @State private var isSavingWeeklyShareCard = false
    @State private var weeklyShareSaveMessage: String?
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
                insightContent
            }
            .scrollIndicators(.hidden)

            if let modal = monthlyTrialModal {
                monthlyTrialOverlay(modal)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: monthlyTrialModal?.id)
    }

    private var insightContent: some View {
        VStack(spacing: 12) {
            weeklyInsightSection
            monthlyInsightSection
            todayInsightSection
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var weeklyInsightSection: some View {
        let weeklyBlocks = homeViewModel.localWeeklyInsightBlocks()

        return VStack(alignment: .leading, spacing: 12) {
            Text("近 7 天生活复盘")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            weeklyInsightText(weeklyBlocks)

            softActionButton("梳理本周节奏") {
                let text = homeViewModel.buildWeeklyRhythmText()
                homeViewModel.setLatestActionCard(text, scope: "weekly")
                homeViewModel.markWeeklyRhythmReviewed()
            }
            softActionButton("生成周度分享卡") {
                homeViewModel.markWeeklyShareGenerated()
                generateAndShareWeeklyCard()
            }
            if let weeklyShareSaveMessage {
                Text(weeklyShareSaveMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }
            if !homeViewModel.weekTopCategoryText.isEmpty && homeViewModel.weekTopCategoryText != "暂无" {
                softActionButton("标记常花类目") {
                    homeViewModel.markWeeklyTag()
                }
            }
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private func weeklyInsightText(_ weeklyBlocks: (summary: String, structure: String, advice: String)) -> some View {
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
    }

    private var monthlyInsightSection: some View {
        let left = max(0, trialTotal - monthlyTrialUsed)
        let tier = settingsViewModel.memberTier.lowercased()
        let isMember = ["monthly", "yearly", "lifetime"].contains(tier)
        let exhausted = !isMember && monthlyTrialUsed >= trialTotal

        return VStack(alignment: .leading, spacing: 12) {
            Text("月度生活复盘")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            monthlyTrialText(left: left, isMember: isMember, exhausted: exhausted)
            monthlyGenerateControl(isMember: isMember, exhausted: exhausted)
            monthlyAIStatusView
            monthlyErrorView
            monthlyReportView
            advancedInsightToggle
            advancedInsightContent
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private func monthlyTrialText(left: Int, isMember: Bool, exhausted: Bool) -> some View {
        if !isMember {
            let text = exhausted ? "免费试用次数已用完" : "剩余试用次数：\(left)/\(trialTotal)"
            let color = exhausted ? Color.orange.opacity(0.8) : AppColors.subtext

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func monthlyGenerateControl(isMember: Bool, exhausted: Bool) -> some View {
        if exhausted {
            Button {
                monthlyTrialModal = MonthlyTrialModal(
                    title: "免费次数已用完",
                    body: "您的免费月度复盘次数已用完，升级会员即可解锁无限次月度/季度/年度 AI 复盘，还有更多专属权益等你体验。"
                )
            } label: {
                monthlyUpgradeButtonLabel
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Task {
                    await generateMonthlyInsight(isMember: isMember)
                }
            } label: {
                monthlyGenerateButtonLabel
            }
            .buttonStyle(.plain)
            .disabled(homeViewModel.isGeneratingMonthlyInsight)
        }
    }

    private var monthlyUpgradeButtonLabel: some View {
        HStack(spacing: 6) {
            Text("🔒 开通会员解锁无限复盘")
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.orange.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
    }

    private var monthlyGenerateButtonLabel: some View {
        let title = homeViewModel.isGeneratingMonthlyInsight ? "正在生成月度复盘..." : "生成月度复盘"

        return Text(title)
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

    @ViewBuilder
    private var monthlyAIStatusView: some View {
        if let status = monthlyAIStatus ?? defaultMonthlyAIStatus {
            aiStatusPill(status)
        }
    }

    @ViewBuilder
    private var monthlyErrorView: some View {
        if let error = homeViewModel.insightErrorMessage,
           monthlyAIStatus?.kind == .error {
            monthlyErrorText(error)
        }
    }

    private func monthlyErrorText(_ error: String) -> some View {
        let foreground = Color.orange.opacity(0.9)
        let fill = Color.orange.opacity(0.08)
        let stroke = Color.orange.opacity(0.22)

        return Text(error)
            .font(.system(size: 11))
            .foregroundStyle(foreground)
            .lineLimit(3)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var monthlyReportView: some View {
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
    }

    private var advancedInsightToggle: some View {
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
    }

    @ViewBuilder
    private var advancedInsightContent: some View {
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

    private var todayInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日生活小记")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)

            todayInsightText
            todayRegenerateButton
            todayInsightLoading
            todayInsightError
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private var todayInsightText: some View {
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
    }

    private var todayRegenerateButton: some View {
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
    }

    @ViewBuilder
    private var todayInsightLoading: some View {
        if homeViewModel.isGeneratingInsight {
            HStack(spacing: 8) {
                ProgressView()
                Text("AI 正在生成中…")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var todayInsightError: some View {
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
        guard !isSavingWeeklyShareCard,
              let payload = PlaybackService().buildWeeklyShareCardPayload(from: homeViewModel.items) else { return }
        let petMode = settingsViewModel.petCompanionEnabled
        let nick = settingsViewModel.displayName.isEmpty ? "叙账用户" : settingsViewModel.displayName
        let card = WeeklyShareCardView(
            payload: payload,
            isPetMode: petMode,
            nickname: nick
        )
        guard let img = card.snapshot() else { return }
        isSavingWeeklyShareCard = true
        weeklyShareSaveMessage = nil
        Task {
            do {
                try await PhotoLibrarySaveService.shared.saveImageToLibrary(img)
                weeklyShareSaveMessage = "已保存到相册。"
            } catch {
                weeklyShareSaveMessage = (error as? LocalizedError)?.errorDescription ?? "保存失败，请稍后再试。"
            }
            isSavingWeeklyShareCard = false
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
    let anchorLine: String?
    let periodText: String
    var isPetMode: Bool = true
    var nickname: String = "叙账用户"

    private var t: ShareCardTheme { isPetMode ? .pet : .neutral }

    struct ShareCardTheme {
        let bgStart, bgEnd: Color; let panelBg, panelBorder: Color
        let accent, titleSub, textMain, textMuted: Color
        let footer, footerSub: Color
        static let pet = ShareCardTheme(
            bgStart: Color(hex: "fff3e8"), bgEnd: Color(hex: "ffe9f2"),
            panelBg: Color.white.opacity(0.94), panelBorder: Color(hex: "efd7c7"),
            accent: Color(hex: "d48754"),
            titleSub: Color(hex: "b79a86"), textMain: Color(hex: "4a3f37"), textMuted: Color(hex: "957f70"),
            footer: Color(hex: "887566"), footerSub: Color(hex: "b19c8e"))
        static let neutral = ShareCardTheme(
            bgStart: Color(hex: "f3f6fb"), bgEnd: Color(hex: "edf1f7"),
            panelBg: Color.white.opacity(0.95), panelBorder: Color(hex: "d8deea"),
            accent: Color(hex: "5e708a"),
            titleSub: Color(hex: "8c96a8"), textMain: Color(hex: "2f3947"), textMuted: Color(hex: "6f7a8d"),
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
        anchorLine: String? = nil,
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
        self.anchorLine = anchorLine
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
            anchorLine: payload.anchorLine,
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
            LinearGradient(colors: [t.bgStart, t.bgEnd], startPoint: .top, endPoint: .bottom)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(t.panelBg.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(t.panelBorder.opacity(0.52), lineWidth: 0.8)
                )
                .padding(.horizontal, 26)
                .padding(.vertical, 24)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(periodText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(t.titleSub)
                        .lineLimit(1)
                    Spacer()
                    Text("叙账")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(t.accent.opacity(0.72))
                }

                Text(displayNickname)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(t.textMuted.opacity(0.82))
                    .lineLimit(1)
                    .padding(.top, 34)

                Text(displayHeadline)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(t.textMain)
                    .lineSpacing(7)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 10)
                    .frame(minHeight: 148, alignment: .topLeading)

                Text(displaySubtitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(t.footer)
                    .lineSpacing(5)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 20)

                if let anchor = displayAnchorLine {
                    Text(anchor)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(t.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.top, 18)
                }

                Text(auxiliaryLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(t.textMuted)
                    .padding(.top, displayAnchorLine == nil ? 18 : 12)

                Spacer(minLength: 18)

                rhythmTexture
                    .padding(.bottom, 24)

                Text("来自 叙账 · 温柔回看每一周")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(t.footerSub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 38)
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

    private var displayNickname: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "这一周" : "\(trimmed)的这一周"
    }

    private var displayHeadline: String {
        headline
            .replacingOccurrences(of: "，([^，。]+)约占\\d+%", with: "，$1出现得比较多", options: .regularExpression)
            .replacingOccurrences(of: "约占\\d+%", with: "出现得比较多", options: .regularExpression)
            .replacingOccurrences(of: " 笔记录", with: " 次记录")
    }

    private var displaySubtitle: String {
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "温柔回看，不必苛责。" }
        if trimmed.contains("建议") || trimmed.contains("数据不足") {
            return "这周先留下了一点痕迹，慢慢来就好。"
        }
        return trimmed
            .replacingOccurrences(of: "¥\\s?[0-9,]+(\\.[0-9]+)?", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
    }

    private var displayAnchorLine: String? {
        guard let anchor = anchorLine?.trimmingCharacters(in: .whitespacesAndNewlines),
              !anchor.isEmpty else { return nil }
        return anchor
    }

    private var auxiliaryLine: String {
        if recordCount <= 2 {
            return "这周刚留下 \(recordCount) 段小痕迹。"
        }
        return "这周记了 \(recordCount) 次。"
    }

    private var rhythmTexture: some View {
        let maxV = max(dailyTrend.map(\.1).max() ?? 1, 1)
        let chartH: CGFloat = 34
        return HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(dailyTrend.enumerated()), id: \.offset) { idx, pt in
                let h = max(4, (pt.1 / maxV) * chartH)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(t.accent.opacity(pt.1 > 0 ? 0.34 : 0.16))
                    .frame(width: 24, height: h)
                    .accessibilityLabel("\(idx)")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .bottomLeading)
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
