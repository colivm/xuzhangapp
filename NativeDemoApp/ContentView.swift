import SwiftUI
import UIKit

// MARK: - Color Constants (matching web CSS variables)

struct AppColors {
    static let accent = Color(red: 127/255, green: 179/255, blue: 162/255)          // #7fb3a2
    static let accentDark = Color(red: 120/255, green: 174/255, blue: 158/255)        // #78ae9e
    static let bg = Color(red: 238/255, green: 240/255, blue: 244/255)                // #eef0f4
    static let panel = Color.white.opacity(0.62)
    static let panelStrong = Color.white.opacity(0.82)
    static let line = Color.white.opacity(0.52)
    static let text = Color(red: 37/255, green: 48/255, blue: 65/255)                 // #253041
    static let subtext = Color(red: 111/255, green: 123/255, blue: 143/255)           // #6f7b8f
    static let heroGradientPink = Color(red: 1.0, green: 0.77, blue: 0.87)            // pink tint
    static let heroGradientTeal = Color(red: 0.69, green: 0.88, blue: 0.86)           // teal tint
    static let tabActiveBg = Color(red: 0.67, green: 0.87, blue: 0.75).opacity(0.42)
    static let lockGold = Color(red: 201/255, green: 166/255, blue: 74/255)           // #c9a64a
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

extension View {
    func glassPanel(radius: CGFloat = 24, padding: CGFloat = 24) -> some View {
        modifier(GlassPanel(radius: radius, padding: padding))
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var selectedTab: AppTab = .today
    @State private var petHint: String = "我在这儿陪你，慢慢记就好。"
    @State private var petBubbleVisible: Bool = false
    @State private var showMemberPricing = false
    @State private var showMinimalOnboarding = false

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
            case .stats: return "账单与切片"
            case .insight: return "生活复盘"
            case .settings: return "设置"
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

            // ── Pet Widget ──
            if selectedTab == .today, settingsViewModel.petCompanionEnabled {
                petWidget
            }
        }
        .sheet(isPresented: $showMemberPricing) {
            MemberPricingView()
                .environmentObject(settingsViewModel)
        }
        .sheet(isPresented: $showMinimalOnboarding) {
            MinimalOnboardingSheet(
                onStartFirstRecord: {
                    showMinimalOnboarding = false
                    withAnimation(.easeInOut(duration: 0.32)) {
                        selectedTab = .record
                    }
                },
                onSkip: {
                    showMinimalOnboarding = false
                }
            )
            .presentationDetents([.height(360), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
            .presentationCornerRadius(28)
        }
        .onAppear {
            if !MinimalOnboardingStore.hasCompleted {
                showMinimalOnboarding = true
            }
        }
        .task {
            await homeViewModel.generateDailyInsight(
                userName: settingsViewModel.displayName,
                settings: settingsViewModel.settings
            )
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .today { petHint = "今天花得怎么样？慢慢记下来就好。" }
            petBubbleVisible = false
        }
        .onChange(of: settingsViewModel.petCompanionEnabled) { _, enabled in
            if !enabled {
                petBubbleVisible = false
            }
        }
        .onChange(of: homeViewModel.petMessage) { _, msg in
            guard let msg, settingsViewModel.petCompanionEnabled, !showMinimalOnboarding else { return }
            petHint = msg
            petBubbleVisible = true
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                petBubbleVisible = false
            }
            homeViewModel.petMessage = nil
        }
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
                colors: [Color.white.opacity(0.07), AppColors.bg],
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
                .foregroundStyle(AppColors.subtext)

            Text(selectedTab.pageTitle)
                .font(.system(size: 33, weight: .semibold, design: .default))
                .foregroundStyle(AppColors.text)
                .animation(.easeInOut(duration: 0.28), value: selectedTab)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
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
                HomeView(onQuickRecord: { selectedTab = .record },
                         onNavigateStats: { selectedTab = .stats },
                         onNavigateSettings: { selectedTab = .settings },
                         onShowMemberPricing: { showMemberPricing = true })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading).combined(with: .offset(y: 8))),
                        removal: .opacity.combined(with: .offset(y: 8))
                    ))
            case .record:
                RecordView(onSaved: { selectedTab = .today })
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity.combined(with: .offset(y: 8))
                ))
            case .stats:
                StatsWebView(
                    onShowMemberPricing: { showMemberPricing = true },
                    onOpenInsight: { selectedTab = .insight }
                )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity.combined(with: .offset(y: 8))
                    ))
            case .insight:
                InsightWebView(onNavigateSettings: { selectedTab = .settings },
                               onShowMemberPricing: { showMemberPricing = true })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity.combined(with: .offset(y: 8))
                    ))
            case .settings:
                SettingsView(
                    showMemberPricing: $showMemberPricing,
                    onShowMinimalOnboarding: {
                        showMinimalOnboarding = true
                    }
                )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity.combined(with: .offset(y: 8))
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: selectedTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.42)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        tabIcon(for: tab, isSelected: selectedTab == tab)
                        Text(tab.title)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? AppColors.accent.opacity(0.9)
                                    : AppColors.subtext
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(alignment: .topTrailing) {
                        if tab == .stats, shouldShowStatsGuidanceBadge {
                            Circle()
                                .fill(Color(red: 1.0, green: 110/255, blue: 136/255))
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
                    : Color.white.opacity(0.42).mix(with: AppColors.accent.opacity(0.18), by: 0.5)
                )
                .frame(width: 30, height: 30)

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
            .frame(width: 18, height: 18)
        }
        .frame(width: 30, height: 30)
    }

    // Today tab — horizon arc with soft sunrise
    private func tabTodayGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
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
                .fill(Color(red: 1.0, green: 181/255, blue: 159/255))
                .frame(width: 3.8, height: 3.8)
                .offset(y: -5.4)
        }
    }

    // Record tab — folded note with light writing strokes
    private func tabRecordGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
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
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
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
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
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
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
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

    // MARK: - Pet Widget

    private var petWidget: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if petBubbleVisible {
                Text(petHint)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
                    .frame(maxWidth: 220, alignment: .trailing)
                    .transition(.scale.combined(with: .opacity))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.28)) {
                    petBubbleVisible.toggle()
                }
                if petBubbleVisible {
                    Task {
                        if let message = await PetCompanionService.shared.petClickMessage(
                            settings: settingsViewModel.settings,
                            todayItems: homeViewModel.items
                        ) {
                            petHint = message
                            petBubbleVisible = true
                        }
                    }
                }
            } label: {
                Text("🐱")
                    .font(.system(size: 26))
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.panel.mix(with: AppColors.accent.opacity(0.12), by: 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(.trailing, 16)
        .padding(.bottom, 102)
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
    @State private var calendarMonth: Date

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }

    init(selection: Binding<Date>) {
        self._selection = selection
        self._calendarMonth = State(initialValue: Self.monthStart(for: selection.wrappedValue))
    }

    static func monthStart(for date: Date) -> Date {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value.date(from: value.dateComponents([.year, .month], from: date)) ?? date
    }

    private var monthTitle: String {
        calendarMonth.formatted(.dateTime.year().month())
    }

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
        return Button {
            setDay(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.text : AppColors.subtext)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.20) : Color.white.opacity(0.38))
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? AppColors.accent.opacity(0.36) : Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
    }

    private func setHour(_ hour: Int) {
        var components = calendar.dateComponents([.year, .month, .day, .minute], from: selection)
        components.hour = hour
        selection = calendar.date(from: components) ?? selection
    }

    private func setMinute(_ minute: Int) {
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: selection)
        components.minute = minute
        selection = calendar.date(from: components) ?? selection
    }
}

// MARK: - Record Edit Sheet

struct RecordEditSheet: View {
    let item: HomeItem
    var onSave: (HomeItem) -> Void
    var onDelete: () -> Void

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var noteEditorExpanded = false
    @State private var categoryPanelExpanded = false
    @State private var datePanelExpanded = false
    @Environment(\.dismiss) private var dismiss

    init(item: HomeItem, onSave: @escaping (HomeItem) -> Void, onDelete: @escaping () -> Void) {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    amountStage
                    editPreviewCard
                    saveButton
                    editQuietActions
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("调整这一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
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
            VStack(alignment: .leading, spacing: 7) {
                Text(previewTitle)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(HomeItem.inferEmotionTag(category: selectedCategory, amount: parsedAmount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.95))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .stroke(AppColors.accent.opacity(0.28), lineWidth: 1)
                    )

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

            Divider().opacity(0.36)

            HStack(spacing: 9) {
                quietLink("自己写一句") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        noteEditorExpanded.toggle()
                    }
                }
                Text("|").foregroundStyle(AppColors.subtext.opacity(0.32))
                quietLink("改日期") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        datePanelExpanded.toggle()
                    }
                }
                Spacer()
                Text(parsedAmount.formatted(.cny.precision(.fractionLength(2))))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            }

            if noteEditorExpanded {
                TextField("这一笔想怎么被记住？", text: $titleText)
                    .font(.system(size: 16))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.68))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if categoryPanelExpanded {
                categoryGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if datePanelExpanded {
                WarmRecordDatePanel(selection: $selectedDate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.09), radius: 16, x: 0, y: 7)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82, maximum: 128), spacing: 8)], spacing: 8) {
            ForEach(HomeItem.Category.allCases) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    Text(cat.displayName)
                        .font(.system(size: 13, weight: selectedCategory == cat ? .semibold : .regular))
                        .foregroundStyle(selectedCategory == cat ? AppColors.text : AppColors.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedCategory == cat ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.58))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selectedCategory == cat ? AppColors.accent.opacity(0.34) : Color.white.opacity(0.38), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
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
            onSave(updated)
            dismiss()
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
