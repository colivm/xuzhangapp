import Foundation
import SwiftUI
import UIKit

// MARK: - Color Constants (matching web CSS variables)

@MainActor
struct AppColors {
    private static var theme: ResolvedThemeTokens { ThemeResolver.current }

    static var accent: Color { theme.accent }
    static var accentDark: Color { theme.accentDark }
    static var bg: Color { theme.background }
    static var bgGradientEnd: Color { theme.backgroundGradientEnd }
    static var panel: Color { theme.panel }
    static var panelStrong: Color { theme.panelStrong }
    static var line: Color { theme.line }
    static var paperWarm: Color { theme.paperWarm }
    static var paperMist: Color { theme.paperMist }
    static var paperBorder: Color { theme.paperBorder }
    static var paperCrease: Color { theme.paperCrease }
    static var surfaceMuted: Color { theme.surfaceMuted }
    static var stroke: Color { theme.stroke }
    static var text: Color { theme.textPrimary }
    static var subtext: Color { theme.textSecondary }
    static var tertiary: Color { theme.textTertiary }
    static var heroGradientPink: Color { theme.heroGradientPink }
    static var heroGradientTeal: Color { theme.heroGradientTeal }
    static var tabActiveBg: Color { theme.tabActiveBg }
    static var lockGold: Color { theme.lockGold }
    static var tabInactiveBg: Color { theme.tabInactiveBg }
    static var tabInactiveGlyph: Color { theme.tabInactiveGlyph }
    static var floatingPetPanel: Color { theme.floatingPetPanel }
    static var settingsIdentityPanel: Color { theme.settingsIdentityPanel }
    static var settingsChapterPanel: Color { theme.settingsChapterPanel }
    static var tracePlaybackButtonBg: Color { theme.tracePlaybackButtonBg }
    static var traceAppendixBg: Color { theme.traceAppendixBg }
    static var monthlyInsightBg: Color { theme.monthlyInsightBg }
    static var settingsEnvelopeIvory: Color { theme.settingsEnvelopeIvory }
    static var settingsEnvelopeWarm: Color { theme.settingsEnvelopeWarm }
    static var settingsEnvelopeMint: Color { theme.settingsEnvelopeMint }
    static var settingsEnvelopeSage: Color { theme.settingsEnvelopeSage }
    static var settingsEnvelopeDeepSage: Color { theme.settingsEnvelopeDeepSage }
    static var categoryColors: [Color] { theme.categoryColors }

    static func categoryColor(_ category: HomeItem.Category) -> Color {
        let index: Int
        switch category {
        case .transport:
            index = 0
        case .dining:
            index = 1
        case .daily:
            index = 2
        case .shopping:
            index = 3
        case .health:
            index = 4
        case .social:
            index = 5
        case .home:
            index = 6
        case .lodging:
            index = 7
        case .entertainment:
            index = 3
        case .other:
            index = 2
        }
        return categoryColors.indices.contains(index) ? categoryColors[index] : accent
    }
}

// MARK: - Glass Panel Modifier

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.panel)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                            startPoint: UnitPoint(x: 0.3, y: 0),
                            endPoint: UnitPoint(x: 0.7, y: 1)
                        )
                    )
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.line, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color(red: 117/255, green: 131/255, blue: 156/255).opacity(0.11), radius: 22, x: 0, y: 8)
    }
}

struct PaperChapterPanel: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 22
    var showsAccentLine: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .padding(.leading, showsAccentLine ? 6 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.paperWarm.opacity(0.84),
                                Color.white.opacity(0.70),
                                AppColors.paperMist.opacity(0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.thinMaterial)
                    )
            )
            .overlay(alignment: .leading) {
                if showsAccentLine {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(AppColors.paperCrease.opacity(0.28))
                        .frame(width: 2)
                        .padding(.vertical, 20)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.paperBorder.opacity(0.28), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color(red: 128/255, green: 106/255, blue: 82/255).opacity(0.10), radius: 22, x: 0, y: 8)
    }
}

struct PaperCreaseDivider: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppColors.paperCrease.opacity(0.12))
                .frame(height: 1)
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.46), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
        }
        .padding(.horizontal, 4)
    }
}

extension View {
    func glassPanel(radius: CGFloat = 24, padding: CGFloat = 24) -> some View {
        modifier(GlassPanel(radius: radius, padding: padding))
    }

    func paperChapterPanel(radius: CGFloat = 24, padding: CGFloat = 22, showsAccentLine: Bool = true) -> some View {
        modifier(PaperChapterPanel(radius: radius, padding: padding, showsAccentLine: showsAccentLine))
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .today
    @State private var showMemberPricing = false
    @State private var pricingHighlightPlanId: String?
    @State private var pricingEntryContext: MemberPricingEntryContext = .settings
    @State private var statsTraceOpenRequestID: UUID?
    @State private var settingsAppearanceOpenRequestID: UUID?
    @State private var lastMemberStatusRefreshAt: Date?
    @State private var homeLifeMarkRewardPrompt: LifeMarkSceneRewardPrompt?

    enum AppTab: Int, CaseIterable, Identifiable {
        case today
        case record
        case stats
        case insight
        case settings

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .today: return "今天"
            case .record: return "记下"
            case .stats: return "痕迹"
            case .insight: return "复盘"
            case .settings: return "我的"
            }
        }

        var pageTitle: String {
            switch self {
            case .today: return "今日"
            case .record: return "记下这一笔"
            case .stats: return "这一段痕迹"
            case .insight: return "生活复盘"
            case .settings: return "我的叙账"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background (matching web gradient) ──
            bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top Bar ──
                topBar

                // ── Content ──
                contentArea

                // ── Tab Bar ──
                tabBar
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if let homeLifeMarkRewardPrompt {
                lifeMarkSceneRewardOverlay(homeLifeMarkRewardPrompt)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(5)
            }
        }
        .sheet(isPresented: $showMemberPricing) {
            MemberPricingView(
                highlightPlanId: pricingHighlightPlanId,
                entryContext: pricingEntryContext
            )
                .environmentObject(settingsViewModel)
                .environmentObject(homeViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.bg)
                .onDisappear {
                    pricingHighlightPlanId = nil
                    pricingEntryContext = .settings
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            settingsViewModel.refreshThemeAccess(showsMessage: true)
            Task {
                await refreshAccountAndMemberStatusIfNeeded(force: true)
            }
        }
        .task {
            await refreshAccountAndMemberStatusIfNeeded(force: true)
            await homeViewModel.generateDailyInsight(
                userName: settingsViewModel.displayName,
                settings: settingsViewModel.settings
            )
        }
    }

    private func refreshAccountAndMemberStatusIfNeeded(force: Bool = false) async {
        if !force,
           let lastMemberStatusRefreshAt,
           Date().timeIntervalSince(lastMemberStatusRefreshAt) < 900 {
            return
        }
        lastMemberStatusRefreshAt = Date()
        await settingsViewModel.refreshCloudAccountProfile()
        await settingsViewModel.refreshMemberFromLocalEntitlements(syncToCloud: true)
    }

    // MARK: - Background Gradient

    @ViewBuilder
    private var bgGradient: some View {
        ZStack {
            // base
            AppColors.bg

            // pink radial (top-left)
            RadialGradient(
                colors: [AppColors.heroGradientPink.opacity(0.34), .clear],
                center: UnitPoint(x: -0.08, y: -0.15),
                startRadius: 0,
                endRadius: 400
            )

            // teal radial (top-right)
            RadialGradient(
                colors: [AppColors.heroGradientTeal.opacity(0.30), .clear],
                center: UnitPoint(x: 1.06, y: -0.05),
                startRadius: 0,
                endRadius: 400
            )

            // subtle top light
            LinearGradient(
                colors: [Color.white.opacity(0.07), AppColors.bgGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedTab.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.88))

            Text(selectedTab.pageTitle)
                .font(.system(size: 32, weight: .semibold, design: .default))
                .foregroundStyle(AppColors.text)
                .animation(.easeInOut(duration: 0.28), value: selectedTab)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.thinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.43))
                        .frame(height: 1)
                }
        )
    }

    // MARK: - Content Area

    private var contentArea: some View {
        ZStack {
            switch selectedTab {
            case .today:
                HomeView(onQuickRecord: { selectTab(.record) },
                         onNavigateStats: { selectTab(.stats) },
                         onNavigateWeeklyTrace: {
                             statsTraceOpenRequestID = UUID()
                             selectTab(.stats)
                         },
                         onNavigateSettings: { selectTab(.settings) },
                         onShowMemberPricing: {
                             showMemberPricingSheet(entryContext: .playbackQuota)
                         })
            case .record:
                RecordView(
                    onSaved: { prompt in
                        selectTab(.today)
                        if let prompt {
                            showHomeLifeMarkRewardPrompt(prompt)
                        }
                    },
                    onShowMemberPricing: { entryContext in
                        showMemberPricingSheet(entryContext: entryContext)
                    }
                )
            case .stats:
                StatsWebView(
                    openTraceRequestID: statsTraceOpenRequestID,
                    onShowMemberPricing: { entryContext in
                        showMemberPricingSheet(entryContext: entryContext)
                    },
                    onOpenInsight: { selectTab(.insight) }
                )
            case .insight:
                InsightWebView(
                    onNavigateSettings: { selectTab(.settings) },
                    onShowMemberPricing: {
                        showMemberPricingSheet(entryContext: .aiCommand)
                    },
                    onOpenAppearanceSettings: {
                        settingsAppearanceOpenRequestID = UUID()
                        selectTab(.settings)
                    }
                )
            case .settings:
                SettingsView(
                    showMemberPricing: $showMemberPricing,
                    pricingHighlightPlanId: $pricingHighlightPlanId,
                    pricingEntryContext: $pricingEntryContext,
                    openAppearanceRequestID: settingsAppearanceOpenRequestID,
                    onAppearanceRequestHandled: {
                        settingsAppearanceOpenRequestID = nil
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectTab(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
    }

    private func showHomeLifeMarkRewardPrompt(_ prompt: LifeMarkSceneRewardPrompt) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                homeLifeMarkRewardPrompt = prompt
            }
        }
    }

    private func dismissHomeLifeMarkRewardPrompt(_ prompt: LifeMarkSceneRewardPrompt) {
        if case .coldStart = prompt.kind {
            LifeMarkSceneRewardService.shared.markColdStartGuideSeen()
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            homeLifeMarkRewardPrompt = nil
        }
    }

    private func handleHomeLifeMarkRewardPrimary(_ prompt: LifeMarkSceneRewardPrompt) {
        switch prompt.kind {
        case .reward(let reward):
            _ = LifeMarkSceneRewardService.shared.claimReward(reward, from: ScenePackCopyPool.definitions)
            withAnimation(.easeInOut(duration: 0.18)) {
                homeLifeMarkRewardPrompt = nil
            }
            selectTab(.record)
        case .coldStart:
            LifeMarkSceneRewardService.shared.markColdStartGuideSeen()
            withAnimation(.easeInOut(duration: 0.18)) {
                homeLifeMarkRewardPrompt = nil
            }
            selectTab(.record)
        }
    }

    private func lifeMarkSceneRewardOverlay(_ prompt: LifeMarkSceneRewardPrompt) -> some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            TimelineView(.animation) { context in
                lifeMarkRewardAnimatedBackdrop(time: context.date.timeIntervalSinceReferenceDate)
            }
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.13))
                        .frame(width: 58, height: 58)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                }

                VStack(spacing: 7) {
                    Text(prompt.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(prompt.badge)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.accent.opacity(0.12)))
                    Text(prompt.detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        dismissHomeLifeMarkRewardPrompt(prompt)
                    } label: {
                        Text(prompt.secondaryTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.subtext)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppColors.surfaceMuted.opacity(0.72))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        handleHomeLifeMarkRewardPrimary(prompt)
                    } label: {
                        Text(prompt.primaryTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppColors.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.panel.opacity(0.96))
                    .shadow(color: Color.black.opacity(0.18), radius: 28, x: 0, y: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private func lifeMarkRewardAnimatedBackdrop(time: TimeInterval) -> some View {
        let drift = CGFloat(sin(time * 1.15))
        let lift = CGFloat(cos(time * 0.9))
        return ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.accent.opacity(0.18), lineWidth: 1)
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 18) * 4))
                .offset(x: drift * 18, y: lift * 12)

            ForEach(0..<7, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "plus")
                    .font(.system(size: index.isMultiple(of: 2) ? 13 : 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .offset(
                        x: CGFloat(index - 3) * 33 + drift * CGFloat(index + 2),
                        y: CGFloat((index % 3) - 1) * 54 + lift * CGFloat(5 - index)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showMemberPricingSheet(
        highlightPlanId: String? = nil,
        entryContext: MemberPricingEntryContext = .settings
    ) {
        pricingHighlightPlanId = highlightPlanId
        pricingEntryContext = highlightPlanId == "lifetime" ? .lifetime : entryContext
        showMemberPricing = true
        Task {
            await settingsViewModel.refreshMemberFromLocalEntitlements(syncToCloud: true)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectTab(tab)
                } label: {
                    VStack(spacing: 3) {
                        tabIcon(for: tab, isSelected: selectedTab == tab)
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? AppColors.accent.opacity(0.9)
                                    : AppColors.subtext.opacity(0.88)
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(alignment: .topTrailing) {
                        if tab == .stats, shouldShowStatsGuidanceBadge {
                            Circle()
                                .fill(AppColors.lockGold)
                                .frame(width: 8, height: 8)
                                .offset(x: -18, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.thinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.43))
                        .frame(height: 1)
                }
                .shadow(color: AppColors.bg.opacity(0.4), radius: 14, x: 0, y: -8)
        )
    }

    private var shouldShowStatsGuidanceBadge: Bool {
        switch homeViewModel.activeRouteGuidance {
        case .weekSliceReady, .fiveRecordsNeverPlayed:
            return selectedTab != .stats
        default:
            return false
        }
    }

    // MARK: - Tab Icons (custom shapes matching web SVG)

    @ViewBuilder
    private func tabIcon(for tab: AppTab, isSelected: Bool) -> some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isSelected
                    ? AppColors.accent.opacity(0.34)
                    : AppColors.tabInactiveBg
                )
                .frame(width: 24, height: 24)

            // Foreground icon
            Group {
                switch tab {
                case .today:
                    tabTodayGlyph(isSelected: isSelected)
                case .record:
                    tabRecordGlyph(isSelected: isSelected)
                case .stats:
                    tabStatsGlyph(isSelected: isSelected)
                case .insight:
                    tabInsightGlyph(isSelected: isSelected)
                case .settings:
                    tabSettingsGlyph(isSelected: isSelected)
                }
            }
            .frame(width: 24, height: 24)
        }
        .frame(width: 24, height: 24)
    }

    // Today tab — horizon arc with soft sunrise
    private func tabTodayGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.tabInactiveGlyph
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 6.8, y: 14.4))
                p.addCurve(to: CGPoint(x: 12, y: 10.3),
                           control1: CGPoint(x: 7.9, y: 11.6),
                           control2: CGPoint(x: 9.8, y: 10.3))
                p.addCurve(to: CGPoint(x: 17.2, y: 14.4),
                           control1: CGPoint(x: 14.2, y: 10.3),
                           control2: CGPoint(x: 16.1, y: 11.6))
                p.closeSubpath()
            }
            .fill(fg.opacity(0.62))

            Path { p in
                p.move(to: CGPoint(x: 6.2, y: 15.4))
                p.addCurve(to: CGPoint(x: 17.8, y: 15.4),
                           control1: CGPoint(x: 9.8, y: 14.2),
                           control2: CGPoint(x: 14.2, y: 14.2))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            Circle()
                .fill(AppColors.lockGold.opacity(0.72))
                .frame(width: 3.8, height: 3.8)
                .offset(y: -5.4)
        }
    }

    // Record tab — folded note with light writing strokes
    private func tabRecordGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.tabInactiveGlyph
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 7.4, y: 7.4))
                p.addLine(to: CGPoint(x: 15.2, y: 7.4))
                p.addCurve(to: CGPoint(x: 16.8, y: 9),
                           control1: CGPoint(x: 16.1, y: 7.4),
                           control2: CGPoint(x: 16.8, y: 8.1))
                p.addLine(to: CGPoint(x: 16.8, y: 16.6))
                p.addLine(to: CGPoint(x: 8.7, y: 16.6))
                p.addCurve(to: CGPoint(x: 7.1, y: 15),
                           control1: CGPoint(x: 7.8, y: 16.6),
                           control2: CGPoint(x: 7.1, y: 15.9))
                p.addLine(to: CGPoint(x: 7.1, y: 7.7))
                p.addCurve(to: CGPoint(x: 7.4, y: 7.4),
                           control1: CGPoint(x: 7.1, y: 7.5),
                           control2: CGPoint(x: 7.2, y: 7.4))
            }
            .fill(fg)

            Path { p in
                p.move(to: CGPoint(x: 14.9, y: 7.4))
                p.addLine(to: CGPoint(x: 14.9, y: 10.5))
                p.addLine(to: CGPoint(x: 18, y: 10.5))
                p.addCurve(to: CGPoint(x: 14.9, y: 7.4),
                           control1: CGPoint(x: 17.6, y: 9),
                           control2: CGPoint(x: 16.4, y: 7.8))
            }
            .fill(fg.opacity(0.58))

            Path { p in
                p.move(to: CGPoint(x: 9.5, y: 11))
                p.addLine(to: CGPoint(x: 13.6, y: 11))
                p.move(to: CGPoint(x: 9.5, y: 13.2))
                p.addLine(to: CGPoint(x: 12.3, y: 13.2))
                p.move(to: CGPoint(x: 13.8, y: 15.4))
                p.addCurve(to: CGPoint(x: 15.7, y: 14),
                           control1: CGPoint(x: 14.5, y: 15),
                           control2: CGPoint(x: 15.1, y: 14.6))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.25, lineCap: .round))
        }
    }

    // Stats tab — curved trace with soft dots
    private func tabStatsGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.tabInactiveGlyph
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 6.7, y: 15.2))
                p.addCurve(to: CGPoint(x: 17.3, y: 10.8),
                           control1: CGPoint(x: 8.7, y: 10.6),
                           control2: CGPoint(x: 12.2, y: 9.3))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.35, lineCap: .round))

            Circle()
                .fill(fg.opacity(0.58))
                .frame(width: 4.2, height: 4.2)
                .offset(x: -4.1, y: 2.6)

            Circle()
                .fill(fg)
                .frame(width: 4.8, height: 4.8)
                .offset(x: 0.1, y: -0.5)

            Circle()
                .fill(fg.opacity(0.58))
                .frame(width: 4, height: 4)
                .offset(x: 4.4, y: -1.4)
        }
    }

    // Insight tab — slightly opened review pages
    private func tabInsightGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.tabInactiveGlyph
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 6.7, y: 8.6))
                p.addCurve(to: CGPoint(x: 12, y: 9),
                           control1: CGPoint(x: 8.5, y: 7.8),
                           control2: CGPoint(x: 10.3, y: 7.8))
                p.addLine(to: CGPoint(x: 12, y: 17.5))
                p.addCurve(to: CGPoint(x: 6.7, y: 17.1),
                           control1: CGPoint(x: 10.3, y: 16.4),
                           control2: CGPoint(x: 8.5, y: 16.3))
                p.closeSubpath()
            }
            .fill(fg)

            Path { p in
                p.move(to: CGPoint(x: 12, y: 9))
                p.addCurve(to: CGPoint(x: 17.3, y: 8.6),
                           control1: CGPoint(x: 13.7, y: 7.8),
                           control2: CGPoint(x: 15.5, y: 7.8))
                p.addLine(to: CGPoint(x: 17.3, y: 17.1))
                p.addCurve(to: CGPoint(x: 12, y: 17.5),
                           control1: CGPoint(x: 15.5, y: 16.3),
                           control2: CGPoint(x: 13.7, y: 16.4))
                p.closeSubpath()
            }
            .fill(fg.opacity(0.58))

            Path { p in
                p.move(to: CGPoint(x: 9, y: 10.9))
                p.addCurve(to: CGPoint(x: 11.3, y: 11.4),
                           control1: CGPoint(x: 9.8, y: 10.8),
                           control2: CGPoint(x: 10.6, y: 11))
                p.move(to: CGPoint(x: 14.9, y: 10.9))
                p.addCurve(to: CGPoint(x: 12.7, y: 11.4),
                           control1: CGPoint(x: 14.1, y: 10.8),
                           control2: CGPoint(x: 13.4, y: 11))
                p.move(to: CGPoint(x: 12, y: 9.2))
                p.addLine(to: CGPoint(x: 12, y: 17.2))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    // Settings tab — rounded profile silhouette
    private func tabSettingsGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.tabInactiveGlyph
        return ZStack {
            Circle()
                .fill(fg.opacity(0.58))
                .frame(width: 5, height: 5)
                .offset(y: -3)

            Path { p in
                p.move(to: CGPoint(x: 7.2, y: 16.9))
                p.addCurve(to: CGPoint(x: 12, y: 12.9),
                           control1: CGPoint(x: 7.9, y: 14.4),
                           control2: CGPoint(x: 9.7, y: 12.9))
                p.addCurve(to: CGPoint(x: 16.8, y: 16.9),
                           control1: CGPoint(x: 14.3, y: 12.9),
                           control2: CGPoint(x: 16.1, y: 14.4))
                p.addCurve(to: CGPoint(x: 16.1, y: 17.8),
                           control1: CGPoint(x: 16.9, y: 17.4),
                           control2: CGPoint(x: 16.6, y: 17.8))
                p.addLine(to: CGPoint(x: 7.9, y: 17.8))
                p.addCurve(to: CGPoint(x: 7.2, y: 16.9),
                           control1: CGPoint(x: 7.4, y: 17.8),
                           control2: CGPoint(x: 7.1, y: 17.4))
                p.closeSubpath()
            }
            .fill(fg)

            Path { p in
                p.move(to: CGPoint(x: 9.5, y: 16.5))
                p.addCurve(to: CGPoint(x: 14.5, y: 16.5),
                           control1: CGPoint(x: 11.1, y: 17),
                           control2: CGPoint(x: 12.9, y: 17))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }
}

// MARK: - Color Mix Extension

private extension Color {
    /// Linearly interpolates between two Colors in the sRGB color space.
    func mix(with other: Color, by fraction: Double) -> Color {
        let t = max(0, min(1, fraction))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return self
        }
        return Color(
            red: Double(r1 * (1 - t) + r2 * t),
            green: Double(g1 * (1 - t) + g2 * t),
            blue: Double(b1 * (1 - t) + b2 * t),
            opacity: Double(a1 * (1 - t) + a2 * t)
        )
    }
}

// MARK: - Warm Record Date Panel

struct WarmRecordDatePanel: View {
    @Binding var selection: Date
    var onSelectionChanged: () -> Void = {}
    @State private var calendarMonth: Date

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }

    init(selection: Binding<Date>, onSelectionChanged: @escaping () -> Void = {}) {
        self._selection = selection
        self.onSelectionChanged = onSelectionChanged
        self._calendarMonth = State(initialValue: Self.monthStart(for: selection.wrappedValue))
    }

    static func monthStart(for date: Date) -> Date {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value.date(from: value.dateComponents([.year, .month], from: date)) ?? date
    }

    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: calendarMonth)
    }

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: calendarMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else { return [] }

        var days: [Date?] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(calendar.isDate(cursor, equalTo: calendarMonth, toGranularity: .month) ? cursor : nil)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? lastWeek.end
        }
        return days
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accent)

                Spacer()

                Text(monthTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.accent)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 6) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                        .frame(height: 20)
                }
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { pair in
                    if let date = pair.element {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            HStack(spacing: 10) {
                timeStepper(title: "时", value: calendar.component(.hour, from: selection), range: 0...23) { setHour($0) }
                timeStepper(title: "分", value: calendar.component(.minute, from: selection), range: 0...59) { setMinute($0) }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.accent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.accent.opacity(0.14), lineWidth: 1)
        )
    }

    private func dayButton(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let dayText = String(calendar.component(.day, from: date))
        return Button {
            setDay(date)
        } label: {
            dayButtonLabel(dayText, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func dayButtonLabel(_ title: String, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let foreground: Color = isSelected ? AppColors.text : AppColors.subtext
        return Text(title)
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(dayButtonBackground(isSelected: isSelected))
            .overlay(dayButtonBorder(isSelected: isSelected))
    }

    private func dayButtonBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(0.20) : Color.white.opacity(0.38)
        return Circle().fill(fill)
    }

    private func dayButtonBorder(isSelected: Bool) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(0.36) : Color.white.opacity(0.18)
        return Circle().stroke(stroke, lineWidth: 1)
    }

    private func timeStepper(title: String, value: Int, range: ClosedRange<Int>, onSet: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            Button {
                onSet(value == range.lowerBound ? range.upperBound : value - 1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.accent)

            Text(String(format: "%02d", value))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .frame(width: 30)

            Button {
                onSet(value == range.upperBound ? range.lowerBound : value + 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
    }

    private func shiftMonth(_ value: Int) {
        calendarMonth = calendar.date(byAdding: .month, value: value, to: calendarMonth) ?? calendarMonth
    }

    private func setDay(_ date: Date) {
        var selectedComponents = calendar.dateComponents([.hour, .minute], from: selection)
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        selectedComponents.year = dayComponents.year
        selectedComponents.month = dayComponents.month
        selectedComponents.day = dayComponents.day
        selection = calendar.date(from: selectedComponents) ?? selection
        onSelectionChanged()
    }

    private func setHour(_ hour: Int) {
        var components = calendar.dateComponents([.year, .month, .day, .minute], from: selection)
        components.hour = hour
        selection = calendar.date(from: components) ?? selection
        onSelectionChanged()
    }

    private func setMinute(_ minute: Int) {
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: selection)
        components.minute = minute
        selection = calendar.date(from: components) ?? selection
        onSelectionChanged()
    }
}

// MARK: - Record Edit Sheet

struct RecordEditSheet: View {
    let item: HomeItem
    var onSave: (HomeItem) -> Bool
    var onDelete: () -> Void

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var noteEditorExpanded = false
    @State private var categoryPanelExpanded = false
    @State private var datePanelExpanded = false
    @State private var safetyMessage: String?
    @FocusState private var isNoteFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(item: HomeItem, onSave: @escaping (HomeItem) -> Bool, onDelete: @escaping () -> Void) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _titleText = State(initialValue: item.title)
        _selectedCategory = State(initialValue: item.category)
        _selectedDate = State(initialValue: item.createdAt)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var cleanTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewTitle: String {
        cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
    }

    private var previewEmotion: String {
        if editFieldsUnchanged {
            return item.displayEmotionTag
        }
        return editPreviewResolution.emotionTag
    }

    private var editFieldsUnchanged: Bool {
        abs(parsedAmount - item.amount) < 0.005
            && cleanTitle == item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            && selectedCategory == item.category
            && abs(selectedDate.timeIntervalSince(item.createdAt)) < 1
    }

    private var editPreviewResolution: RecordDraftResolution {
        let title = cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
        let matchedBrand = MerchantBrandCatalog.matchBrand(in: title)
        let categoryOverridesBrand = matchedBrand.map { selectedCategory != $0.category } ?? false
        // 用户改了标题时，判断旧品牌是否仍匹配新标题；不匹配就清掉，避免沿用旧品牌文案/分类。
        let userEdited = title != item.title
        let oldBrandId = userEdited ? item.merchantBrandId : nil
        let oldBrandStillMatches: Bool = {
            guard let oldBrandId, let oldBrand = MerchantBrandCatalog.definition(for: oldBrandId) else { return false }
            if MerchantBrandCatalog.matchBrand(in: title)?.id == oldBrand.id { return true }
            return oldBrand.aliases.contains { alias in
                title.localizedCaseInsensitiveContains(alias)
            }
        }()
        let effectiveBrandId: String?
        if userEdited, !oldBrandStillMatches {
            effectiveBrandId = nil
        } else {
            effectiveBrandId = matchedBrand?.id ?? item.merchantBrandId
        }
        return RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: title,
                fallbackCategory: selectedCategory,
                amount: parsedAmount,
                date: selectedDate,
                merchantBrandId: effectiveBrandId,
                categoryLockedByUser: selectedCategory != item.category || categoryOverridesBrand,
                userEditedTitle: userEdited,
                source: "edit_preview"
            )
        )
    }

    private var editContentBottomPadding: CGFloat {
        isNoteFieldFocused ? 340 : 40
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        amountStage
                        editPreviewCard
                        saveButton
                        editQuietActions
                    }
                    .padding(20)
                    .padding(.bottom, editContentBottomPadding)
                }
                .scrollIndicators(.hidden)
                .background(AppColors.bg.ignoresSafeArea())
                .navigationTitle("调整这一笔")
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: titleText) { _, newValue in
                    if newValue.count > 32 {
                        titleText = String(newValue.prefix(32))
                        return
                    }
                    safetyMessage = nil
                }
                .onChange(of: noteEditorExpanded) { _, isExpanded in
                    if isExpanded {
                        focusEditNoteField(scrollProxy)
                    } else {
                        isNoteFieldFocused = false
                    }
                }
                .onChange(of: isNoteFieldFocused) { _, isFocused in
                    guard isFocused else { return }
                    scrollEditNoteFieldIntoView(scrollProxy)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                }
            }
        }
    }

    private var amountStage: some View {
        HStack(spacing: 4) {
            Text("¥")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.72))
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        )
    }

    private var editPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            editPreviewHeader

            Divider().opacity(0.36)

            editPreviewActions

            editPreviewExpandedSections
        }
        .padding(18)
        .background(editPreviewBackground)
        .overlay(editPreviewBorder)
        .shadow(color: AppColors.subtext.opacity(0.09), radius: 16, x: 0, y: 7)
    }

    private var editPreviewHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(previewTitle)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            editPreviewEmotionPill
            editPreviewMetaRow
        }
    }

    private var editPreviewEmotionPill: some View {
        Text(previewEmotion)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.accent.opacity(0.95))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(editPreviewEmotionBorder)
    }

    private var editPreviewEmotionBorder: some View {
        Capsule(style: .continuous)
            .stroke(AppColors.accent.opacity(0.28), lineWidth: 1)
    }

    private var editPreviewMetaRow: some View {
        HStack(spacing: 7) {
            Text("\(selectedCategory.displayName) · \(selectedDate.zhBillDateTime)")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            Button("改") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    categoryPanelExpanded.toggle()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.accent.opacity(0.9))
            .buttonStyle(.plain)
        }
    }

    private var editPreviewActions: some View {
        HStack(spacing: 9) {
            quietLink("自己写一句") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    noteEditorExpanded.toggle()
                }
            }
            Text("|").foregroundStyle(AppColors.subtext.opacity(0.32))
            quietLink(selectedDate.zhBillDateTime) {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) {
                    datePanelExpanded.toggle()
                }
            }
            Spacer()
            Text(parsedAmount.formatted(.cny.precision(.fractionLength(2))))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.72))
        }
    }

    @ViewBuilder
    private var editPreviewExpandedSections: some View {
        if noteEditorExpanded {
            editPreviewNoteField
        }

        if let safetyMessage {
            Text(safetyMessage)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
                .transition(.opacity)
        }

        if categoryPanelExpanded {
            categoryGrid
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        if datePanelExpanded {
            WarmRecordDatePanel(selection: $selectedDate) {
                dismissKeyboard()
            }
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var editPreviewNoteField: some View {
        TextField("这一笔想怎么被记住？", text: $titleText)
            .focused($isNoteFieldFocused)
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.68))
            )
            .id("recordEditNoteField")
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var editPreviewBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.68))
    }

    private var editPreviewBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.56), lineWidth: 1)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82, maximum: 128), spacing: 8)], spacing: 8) {
            ForEach(HomeItem.Category.allCases) { cat in
                categoryGridButton(cat)
            }
        }
    }

    private func categoryGridButton(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectCategory(category)
        } label: {
            categoryGridButtonLabel(category, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func categoryGridButtonLabel(_ category: HomeItem.Category, isSelected: Bool) -> some View {
        let weight: Font.Weight = isSelected ? .semibold : .regular
        let foreground: Color = isSelected ? AppColors.text : AppColors.subtext
        return Text(category.displayName)
            .font(.system(size: 13, weight: weight))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(categoryGridButtonBackground(isSelected: isSelected))
            .overlay(categoryGridButtonBorder(isSelected: isSelected))
    }

    private func categoryGridButtonBackground(isSelected: Bool) -> some View {
        let fill = isSelected ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.58)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
    }

    private func categoryGridButtonBorder(isSelected: Bool) -> some View {
        let stroke = isSelected ? AppColors.accent.opacity(0.34) : Color.white.opacity(0.38)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(stroke, lineWidth: 1)
    }

    private func selectCategory(_ category: HomeItem.Category) {
        selectedCategory = category
        titleText = editNoteSuggestion(for: category)
        dismissKeyboard()
        withAnimation(.easeInOut(duration: 0.18)) {
            categoryPanelExpanded = false
        }
    }

    private func editNoteSuggestion(for category: HomeItem.Category) -> String {
        guard let pack = ScenePackCopyPool.definitions.first(where: { $0.category == category }) else {
            return category.defaultRecordTitle
        }
        return ScenePackCopyPool.note(
            for: pack,
            amount: parsedAmount,
            date: selectedDate,
            categoryContext: category,
            petName: "",
            historyItems: [],
            allowPetCopy: false
        )
    }

    private func dismissKeyboard() {
        isNoteFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func focusEditNoteField(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            isNoteFieldFocused = true
            scrollEditNoteFieldIntoView(proxy)
        }
    }

    private func scrollEditNoteFieldIntoView(_ proxy: ScrollViewProxy) {
        scrollEditNoteFieldIntoView(proxy, delay: 0.18)
        scrollEditNoteFieldIntoView(proxy, delay: 0.42)
    }

    private func scrollEditNoteFieldIntoView(_ proxy: ScrollViewProxy, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isNoteFieldFocused else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                proxy.scrollTo("recordEditNoteField", anchor: .center)
            }
        }
    }

    private var saveButton: some View {
        Button {
            var updated = item
            updated.amount = parsedAmount
            updated.title = cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
            updated.category = selectedCategory
            updated.createdAt = selectedDate
            updated.updatedAt = Date()
            // 用编辑预览解析出的品牌/情绪标签覆盖，确保改了标题后旧品牌绑定被清掉。
            updated.merchantBrandId = editPreviewResolution.merchantBrandId
            updated.emotionTag = editPreviewResolution.emotionTag
            if onSave(updated) {
                dismiss()
            } else {
                safetyMessage = "这句备注里可能有隐私信息，先改成更简单的记录。"
                withAnimation(.easeInOut(duration: 0.16)) {
                    noteEditorExpanded = true
                }
            }
        } label: {
            Text("更新这一笔")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .shadow(color: AppColors.accent.opacity(0.22), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(parsedAmount <= 0)
        .opacity(parsedAmount <= 0 ? 0.56 : 1)
    }

    private var editQuietActions: some View {
        HStack(spacing: 8) {
            Spacer()
            Button(role: .destructive) {
                onDelete()
                dismiss()
            } label: {
                Text("删除这一笔")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.72))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.top, 2)
    }

    private func quietLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.9))
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsViewModel())
            .environmentObject(HomeViewModel())
    }
}
