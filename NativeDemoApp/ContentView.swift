import SwiftUI
import PhotosUI
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
    @State private var petHint: String = "记一笔，我会帮你盯着消费节奏。"
    @State private var petBubbleVisible: Bool = false
    @State private var showMemberPricing = false

    enum AppTab: Int, CaseIterable, Identifiable {
        case today
        case record
        case stats
        case insight
        case settings

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .today: return "今日"
            case .record: return "记一笔"
            case .stats: return "看看花"
            case .insight: return "小 AI 说"
            case .settings: return "我的小窝"
            }
        }

        var pageTitle: String {
            switch self {
            case .today: return "今日"
            case .record: return "记账"
            case .stats: return "账单"
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
            if selectedTab == .today {
                petWidget
            }
        }
        .sheet(isPresented: $showMemberPricing) {
            MemberPricingView()
                .environmentObject(settingsViewModel)
        }
        .task {
            await homeViewModel.generateDailyInsight(
                userName: settingsViewModel.displayName,
                settings: settingsViewModel.settings
            )
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .today { petHint = "今天花得怎么样？我帮你看着。" }
            petBubbleVisible = false
        }
        .onChange(of: homeViewModel.petMessage) { _, msg in
            guard let msg else { return }
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
            Text("今天")
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
                SettingsView(showMemberPricing: $showMemberPricing)
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

    // Today tab — house with dot
    private func tabTodayGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 12, y: 7.1))
                p.addLine(to: CGPoint(x: 6.9, y: 11))
                p.addLine(to: CGPoint(x: 6.9, y: 17))
                p.addLine(to: CGPoint(x: 10.1, y: 17))
                p.addLine(to: CGPoint(x: 10.1, y: 13.9))
                p.addLine(to: CGPoint(x: 13.9, y: 13.9))
                p.addLine(to: CGPoint(x: 13.9, y: 17))
                p.addLine(to: CGPoint(x: 17.1, y: 17))
                p.addLine(to: CGPoint(x: 17.1, y: 11))
                p.closeSubpath()
            }
            .fill(fg)

            Circle()
                .fill(Color(red: 1.0, green: 182/255, blue: 200/255)) // pink dot
                .frame(width: 3.5, height: 3.5)
                .offset(x: 6.8, y: -5.2)
        }
    }

    // Record tab — circle with plus cutout
    private func tabRecordGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
        return ZStack {
            Circle()
                .fill(fg.opacity(0.7))
                .frame(width: 10.6, height: 10.6)

            // Plus cross (cutout effect)
            Path { p in
                p.move(to: CGPoint(x: 12, y: 9.3))
                p.addLine(to: CGPoint(x: 12, y: 14.7))
                p.move(to: CGPoint(x: 9.3, y: 12))
                p.addLine(to: CGPoint(x: 14.7, y: 12))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: 10.6, height: 10.6)
        }
    }

    // Stats tab — three hearts
    private func tabStatsGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
        return ZStack {
            // Heart 1 (top)
            HeartShape()
                .fill(fg)
                .frame(width: 8, height: 7)
                .offset(y: -2.5)
            // Heart 2 (left)
            HeartShape()
                .fill(fg)
                .frame(width: 8, height: 7)
                .offset(x: -4.5, y: 3.5)
            // Heart 3 (right)
            HeartShape()
                .fill(fg)
                .frame(width: 8, height: 7)
                .offset(x: 4.5, y: 3.5)
            // Center dot
            Circle()
                .fill(Color.white.opacity(0.84))
                .frame(width: 3, height: 3)
                .offset(y: 0.5)
        }
    }

    // Insight tab — chat bubble with lines
    private func tabInsightGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 7.4, y: 8.7))
                p.addCurve(to: CGPoint(x: 9.2, y: 6.9),
                           control1: CGPoint(x: 7.4, y: 7.7),
                           control2: CGPoint(x: 8.2, y: 6.9))
                p.addLine(to: CGPoint(x: 14.9, y: 6.9))
                p.addCurve(to: CGPoint(x: 16.7, y: 8.7),
                           control1: CGPoint(x: 15.9, y: 6.9),
                           control2: CGPoint(x: 16.7, y: 7.7))
                p.addLine(to: CGPoint(x: 16.7, y: 12.4))
                p.addCurve(to: CGPoint(x: 14.9, y: 14.2),
                           control1: CGPoint(x: 16.7, y: 13.4),
                           control2: CGPoint(x: 15.9, y: 14.2))
                p.addLine(to: CGPoint(x: 11.5, y: 14.2))
                p.addLine(to: CGPoint(x: 9, y: 16.2))
                p.addLine(to: CGPoint(x: 9, y: 14.2))
                p.addLine(to: CGPoint(x: 8.2, y: 14.2))
                p.addCurve(to: CGPoint(x: 7.4, y: 12.4),
                           control1: CGPoint(x: 7.2, y: 14.2),
                           control2: CGPoint(x: 7.4, y: 13.4))
                p.closeSubpath()
            }
            .fill(fg)

            // Chat lines
            Path { p in
                p.move(to: CGPoint(x: 11.2, y: 9.9))
                p.addLine(to: CGPoint(x: 13.5, y: 9.9))
                p.move(to: CGPoint(x: 10.8, y: 12))
                p.addLine(to: CGPoint(x: 13.9, y: 12))
            }
            .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    // Settings tab — house with dot
    private func tabSettingsGlyph(isSelected: Bool) -> some View {
        let fg = isSelected
            ? AppColors.accent.opacity(0.84)
            : AppColors.subtext.opacity(0.74).mix(with: AppColors.accent.opacity(0.26), by: 0.5)
        return ZStack {
            Path { p in
                p.move(to: CGPoint(x: 8.5, y: 17.1))
                p.addLine(to: CGPoint(x: 8.5, y: 12.7))
                p.addLine(to: CGPoint(x: 12, y: 9.5))
                p.addLine(to: CGPoint(x: 15.5, y: 12.7))
                p.addLine(to: CGPoint(x: 15.5, y: 17.1))
                p.addLine(to: CGPoint(x: 13.1, y: 17.1))
                p.addLine(to: CGPoint(x: 13.1, y: 14.4))
                p.addLine(to: CGPoint(x: 10.9, y: 14.4))
                p.addLine(to: CGPoint(x: 10.9, y: 17.1))
                p.closeSubpath()
            }
            .fill(fg)

            Circle()
                .fill(Color(red: 1.0, green: 182/255, blue: 200/255))
                .frame(width: 3.2, height: 3.2)
                .offset(x: -5.7, y: -5.8)
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
                if !petBubbleVisible {
                    petHint = [
                        "慢一点也没关系，先记下来就很棒。",
                        "今天餐饮偏多，明天可以试试自己带饭。",
                        "我在这儿，帮你把钱花明白。",
                        "记一笔，我会帮你盯着消费节奏。"
                    ].randomElement() ?? petHint
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

// MARK: - Heart Shape Helper

private struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w/2, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h*0.3),
                   control1: CGPoint(x: w/2, y: h*0.7),
                   control2: CGPoint(x: 0, y: h*0.55))
        p.addArc(center: CGPoint(x: w*0.25, y: h*0.3),
                 radius: w*0.25,
                 startAngle: .degrees(180),
                 endAngle: .degrees(0),
                 clockwise: false)
        p.addArc(center: CGPoint(x: w*0.75, y: h*0.3),
                 radius: w*0.25,
                 startAngle: .degrees(180),
                 endAngle: .degrees(0),
                 clockwise: false)
        p.addCurve(to: CGPoint(x: w/2, y: h),
                   control1: CGPoint(x: w, y: h*0.55),
                   control2: CGPoint(x: w/2, y: h*0.7))
        return p
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

// MARK: - Record View

struct RecordView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onSaved: (() -> Void)? = nil
    @State private var selectedEntryMode: EntryMode = .manual
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isOCRRecognizing = false
    @State private var ocrProgress = 0.0
    @State private var ocrConfirmDrafts: [OCRReceiptDraft] = []
    @State private var showOCRConfirmSheet = false
    @State private var showRecordDateSheet = false
    @State private var scenePackExpanded = false
    @FocusState private var focusedField: RecordField?

    private enum RecordField {
        case amount
        case note
    }

    private let recordAccent = AppColors.accent
    private let recordInk = AppColors.text

    private let scenePacks = ScenePackCopyPool.definitions

    private var isMember: Bool {
        let tier = settingsViewModel.memberTier.lowercased()
        return ["monthly", "yearly", "lifetime"].contains(tier)
    }

    private func guessScenePackId() -> String {
        let categoryToPackId: [HomeItem.Category: String] = [
            .dining: "food",
            .transport: "commute",
            .daily: "pet",
            .shopping: "travel",
            .entertainment: "travel",
            .lodging: "travel",
            .other: "travel",
        ]
        if let packId = categoryToPackId[homeViewModel.selectedCategory],
           scenePacks.contains(where: { $0.id == packId }) {
            return packId
        }

        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        if amount <= 15 { return "commute" }
        if amount <= 45 { return "food" }
        if amount <= 120 { return "pet" }
        return "travel"
    }

    private func applyScenePack(_ pack: ScenePackDefinition, keepSelectedCategory: Bool = false) {
        dismissKeyboard()
        let amount = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let categoryContext = keepSelectedCategory ? homeViewModel.selectedCategory : pack.category
        homeViewModel.inputTitle = ScenePackCopyPool.note(
            for: pack,
            amount: amount,
            categoryContext: categoryContext,
            petName: settingsViewModel.petNickname,
            historyItems: homeViewModel.items
        )
        if !keepSelectedCategory {
            homeViewModel.selectCategory(pack.category)
        }
    }

    private func scenePackDesc(_ pack: ScenePackDefinition) -> String {
        ScenePackCopyPool.renderPetName(pack.desc, petName: settingsViewModel.petNickname)
    }

    enum EntryMode: String, CaseIterable, Identifiable {
        case manual = "手动录入"
        case ocr = "智能导入"
        var id: String { rawValue }
    }

    private var hasValidAmount: Bool {
        guard let v = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) else { return false }
        return v > 0
    }

    private var hasAmountDraft: Bool {
        !homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowAmountQuickKeys: Bool {
        selectedEntryMode == .manual && (focusedField == .amount || hasAmountDraft)
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // ── Record Panel (matching web recordPage) ──
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("记账")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(recordInk)

                    // Segment control
                    recordModeSegment

                    if selectedEntryMode == .manual {
                        manualForm
                    } else {
                        ocrForm
                    }
                }
                .glassPanel(radius: 24, padding: 24)
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 120)
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    dismissKeyboard()
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                await MainActor.run {
                    isOCRRecognizing = true
                    ocrProgress = 0.12
                }
                let progressTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 180_000_000)
                        await MainActor.run {
                            ocrProgress = min(0.88, ocrProgress + 0.08)
                        }
                    }
                }
                var drafts: [OCRReceiptDraft] = []
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    drafts = await homeViewModel.recognizeOCRDrafts(imageData: data, isMember: isMember)
                }
                progressTask.cancel()
                await MainActor.run {
                    ocrProgress = 1
                    if !drafts.isEmpty {
                        ocrConfirmDrafts = drafts
                        showOCRConfirmSheet = true
                    }
                }
                try? await Task.sleep(nanoseconds: 180_000_000)
                await MainActor.run {
                    isOCRRecognizing = false
                    ocrProgress = 0
                    selectedPhoto = nil
                }
            }
        }
        .onChange(of: homeViewModel.inputAmount) { _, newValue in
            guard selectedEntryMode == .manual else { return }
            guard !homeViewModel.categoryLockedByUser else { return }
            if let category = homeViewModel.recommendCategory(for: newValue) {
                homeViewModel.applyRecommendedCategory(category)
            }
        }
        .sheet(isPresented: $showRecordDateSheet) {
            NavigationStack {
                DatePicker("账单日期", selection: $homeViewModel.selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("补记日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showRecordDateSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showOCRConfirmSheet) {
            OCRConfirmSheet(drafts: ocrConfirmDrafts) { selectedDrafts in
                homeViewModel.importOCRDrafts(selectedDrafts, isMember: isMember)
            }
        }
        .onChange(of: showOCRConfirmSheet) { _, isPresented in
            if !isPresented {
                ocrConfirmDrafts = []
            }
        }
    }

    // MARK: - Segment

    private var recordModeSegment: some View {
        HStack(spacing: 4) {
            ForEach(EntryMode.allCases) { mode in
                Button {
                    dismissKeyboard()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedEntryMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: selectedEntryMode == mode ? .semibold : .regular))
                        .foregroundStyle(recordInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedEntryMode == mode
                                ? Color.white.opacity(0.85)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .shadow(color: selectedEntryMode == mode ? Color.black.opacity(0.08) : .clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.25))
        )
    }

    // MARK: - Manual Form

    @ViewBuilder
    private var manualForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Amount field
            amountField
            // Quick keyboard (show on focus or draft, matching web)
            if shouldShowAmountQuickKeys { amountQuickKeys }
            // Category chips
            if hasValidAmount { categorySection }
            // Note suggestions
            if hasValidAmount { noteSection }
            // Save row — always visible (gray when disabled, matching web .save-btn:disabled)
            saveRow
            // Member scene packs (matching web: show when amount ready + is member)
            if hasValidAmount && isMember { memberScenePackSection }
            // Hints (only visible when amount is valid, matching web)
            if hasValidAmount {
                VStack(alignment: .leading, spacing: 4) {
                    Text("默认今天，如需补记点右侧日历。")
                    Text("数据仅保存在本机，不上传云端。")
                }
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            }
        }
    }

    // MARK: - Amount Field

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("金额")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(recordInk.opacity(0.82))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                HStack(spacing: 0) {
                    Text("¥")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.subtext.opacity(0.74))
                        .padding(.trailing, 2)
                        .offset(y: 1)

                    TextField("0.00", text: $homeViewModel.inputAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(recordInk)
                        .multilineTextAlignment(.leading)
                        .focused($focusedField, equals: .amount)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.35), AppColors.accent.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

            Text("输入金额，我帮你自动归类")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.76))
        }
    }

    // MARK: - Amount Quick Keys

    private var amountQuickKeys: some View {
        HStack(spacing: 8) {
            quickKeyButton(".00") { applyDot00() }
            quickKeyButton("+10元") { applyAmountDelta(10) }
            quickKeyButton("+50元") { applyAmountDelta(50) }
            quickKeyButton("+100元") { applyAmountDelta(100) }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.panelStrong.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.line.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: AppColors.bg.opacity(0.32), radius: 14, x: 0, y: 6)
    }

    private func quickKeyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(recordInk.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.panelStrong.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppColors.line.opacity(0.76), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分类（点一下即可）")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(recordInk.opacity(0.82))

            let recommended = homeViewModel.recommendCategory(for: homeViewModel.inputAmount)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(HomeItem.Category.allCases) { category in
                    categoryChip(category: category, isRecommended: recommended == category)
                }
            }
        }
    }

    private func categoryChip(category: HomeItem.Category, isRecommended: Bool) -> some View {
        let isSelected = homeViewModel.selectedCategory == category
        return Button {
            dismissKeyboard()
            withAnimation(.easeInOut(duration: 0.12)) {
                homeViewModel.selectCategory(category)
            }
        } label: {
            HStack(spacing: 4) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                if isRecommended {
                    Text("推荐")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.subtext)
                }
            }
            .foregroundStyle(isSelected
                ? AppColors.accent.opacity(0.84)
                : recordInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                isSelected
                    ? AppColors.accent.opacity(0.16)
                    : Color.white.opacity(0.62),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isSelected ? AppColors.accent.opacity(0.45) : Color.white.opacity(0.45),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "",
                text: $homeViewModel.inputTitle,
                prompt: Text("已归类到「\(homeViewModel.selectedCategory.label)」，可补充点细节（不填也能保存）")
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            )
            .focused($focusedField, equals: .note)
            .submitLabel(.done)
            .onSubmit { dismissKeyboard() }
            .font(.system(size: 16))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.62))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(homeViewModel.noteSuggestions(for: homeViewModel.selectedCategory), id: \.self) { suggestion in
                        Button(suggestion) {
                            dismissKeyboard()
                            homeViewModel.inputTitle = suggestion
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(recordInk.opacity(0.88))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.thinMaterial)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Save Row

    private var saveRow: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                guard hasValidAmount else { return }
                dismissKeyboard()
                homeViewModel.addManualRecord()
                onSaved?()
            } label: {
                ZStack {
                    if hasValidAmount {
                        LinearGradient(
                            colors: [recordAccent.opacity(0.92), recordAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(Capsule(style: .continuous))
                    } else {
                        Capsule(style: .continuous)
                            .fill(AppColors.panelStrong)
                    }

                    Text("保存")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(hasValidAmount ? Color.white : AppColors.subtext.opacity(0.72))
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(hasValidAmount ? Color.white.opacity(0.36) : AppColors.line, lineWidth: 1)
                )
                .shadow(color: hasValidAmount ? recordAccent.opacity(0.35) : Color.clear, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(!hasValidAmount)

            if hasValidAmount {
                Button {
                    dismissKeyboard()
                    showRecordDateSheet = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(recordAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.white)
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -10)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Member Scene Packs

    @ViewBuilder
    private var memberScenePackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("小宠物的记账小帮手")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(recordInk.opacity(0.88))
                Spacer()
                Text("会员专属")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(AppColors.lockGold))
            }
            Text(scenePackExpanded
                 ? "点选场景包会同步调整分类。"
                 : "金额填好后，可自动补一句备注。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.88))

            // Quick generate button
            let quickPackId = guessScenePackId()
            let quickPack = scenePacks.first(where: { $0.id == quickPackId }) ?? scenePacks[0]
            Button {
                applyScenePack(quickPack, keepSelectedCategory: true)
            } label: {
                HStack(spacing: 4) {
                    Text("✨ 一键生成备注")
                        .font(.system(size: 14, weight: .semibold))
                    Text("保留当前分类")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(recordAccent.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(recordAccent.opacity(0.28), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Expand toggle
            Button {
                dismissKeyboard()
                withAnimation(.easeInOut(duration: 0.2)) { scenePackExpanded.toggle() }
            } label: {
                HStack {
                    Text(scenePackExpanded ? "收起更多场景" : "展开更多场景")
                        .font(.system(size: 13))
                    Text(scenePackExpanded ? "回到简洁输入" : "手动选择备注风格")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(recordInk.opacity(0.74))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.62)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Expanded scene pack list
            if scenePackExpanded {
                ForEach(scenePacks, id: \.id) { pack in
                    Button {
                        applyScenePack(pack)
                    } label: {
                        HStack {
                            Text("\(pack.emoji) \(pack.label)")
                                .font(.system(size: 14, weight: .medium))
                            Text(scenePackDesc(pack))
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.subtext.opacity(0.7))
                                .lineLimit(1)
                            Spacer()
                        }
                        .foregroundStyle(recordInk.opacity(0.88))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.72)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppColors.lockGold.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AppColors.lockGold.opacity(0.2), lineWidth: 1))
    }

    // MARK: - OCR Form

    @ViewBuilder
    private var ocrForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导入微信/支付宝单笔账单详情截图，识别后先确认，再写入账单。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Label("导入账单 / 识别票据", systemImage: "photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        LinearGradient(
                            colors: [recordAccent.opacity(0.92), recordAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: recordAccent.opacity(0.25), radius: 8, y: 4)
            }
            .disabled(isOCRRecognizing)

            if isOCRRecognizing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: ocrProgress)
                        .tint(recordAccent)
                    Text("正在识别账单，请稍候…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.68))
                )
            }

            #if DEBUG
            Button("使用演示 OCR 结果") {
                ocrConfirmDrafts = homeViewModel.makeDemoOCRDrafts()
                showOCRConfirmSheet = true
            }
            .font(.system(size: 14))
            .foregroundStyle(recordAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(recordAccent.opacity(0.5), lineWidth: 1)
            )
            #endif

            if !homeViewModel.ocrStatus.isEmpty {
                Text(homeViewModel.ocrStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.top, 4)
            }

            OCRDraftPanel(
                items: homeViewModel.ocrDraftItems,
                onToggleResolved: { id, isResolved in homeViewModel.updateOCRDraftStatus(id: id, isResolved: isResolved) },
                onCategoryChange: { id, category in homeViewModel.updateOCRDraftCategory(id: id, category: category) },
                onAmountChange: { id, amount in homeViewModel.updateOCRDraftAmount(id: id, amount: amount) },
                onDelete: { id in homeViewModel.deleteOCRDraftItem(id: id) },
                onClearResolved: homeViewModel.clearResolvedOCRDrafts
            )
            .padding(.top, 6)
        }
    }

    // MARK: - Amount helpers

    private func applyAmountDelta(_ delta: Double) {
        let base = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        let next = max(0, base + delta)
        homeViewModel.inputAmount = String(format: "%.2f", next)
    }

    private func applyDot00() {
        let base = Double(homeViewModel.inputAmount.replacingOccurrences(of: ",", with: "")) ?? 0
        homeViewModel.inputAmount = String(format: "%.2f", base)
    }
}

// MARK: - Stats View (matching web statsPage)

struct StatsWebView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onShowMemberPricing: (() -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedCategory: HomeItem.Category? = nil
    @State private var editingItem: HomeItem?
    @State private var summaryPlayback: SummaryPlayback?
    @State private var summaryQuotaMessage: String?
    @State private var quotaRefreshID = UUID()
    private let playbackService = PlaybackService()
    private let quotaStore = SummaryPlaybackQuotaStore()

    enum StatsPeriod: String, CaseIterable, Identifiable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
        var id: String { rawValue }
    }

    private var filteredItems: [HomeItem] {
        var items: [HomeItem]
        if useCustomRange {
            let cal = Calendar.current
            let start = cal.startOfDay(for: customStartDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEndDate)) ?? customEndDate
            items = homeViewModel.items.filter { $0.createdAt >= start && $0.createdAt < end }
        } else {
            switch selectedPeriod {
            case .week: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .weekOfYear) }
            case .month: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
            case .year: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .year) }
            }
        }
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalExpense: Double {
        filteredItems.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var hasMemberAccess: Bool {
        ["monthly", "yearly", "lifetime"].contains(settingsViewModel.memberTier.lowercased())
    }

    @State private var showPeriodSheet = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var useCustomRange = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // ── Filters Panel (matching web bill-filters: grid 1fr 1fr) ──
                VStack(alignment: .leading, spacing: 14) {
                    Text("账单")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    // 2-column grid matching web grid-template-columns: 1fr 1fr
                    HStack(alignment: .top, spacing: 8) {
                        // Time filter (left)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("时间").font(.system(size: 11)).foregroundStyle(AppColors.subtext)
                            Button { showPeriodSheet = true } label: {
                                HStack {
                                    Text(useCustomRange ? "自定义" : selectedPeriod.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppColors.text.opacity(0.88))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(AppColors.subtext.opacity(0.6))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)

                        // Category filter (right)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("分类").font(.system(size: 11)).foregroundStyle(AppColors.subtext)
                            Menu {
                                Button("全部分类") { selectedCategory = nil }
                                ForEach(HomeItem.Category.allCases) { cat in
                                    Button(cat.rawValue) { selectedCategory = cat }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory?.rawValue ?? "全部分类")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppColors.text.opacity(0.88))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(AppColors.subtext.opacity(0.6))
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .glassPanel(radius: 24, padding: 20)

                summarySliceCard

                // ── Overview Panel ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("总览")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("总支出")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.subtext)
                        Text(totalExpense.formatted(.cny))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.accent.opacity(0.86))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.62)))

                    trendChart
                }
                .glassPanel(radius: 24, padding: 20)

                // ── Record List Panel ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("记录列表")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    if filteredItems.isEmpty {
                        Text("当前筛选条件下暂无账单。")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.subtext)
                    } else {
                        ForEach(filteredItems) { item in
                            Button {
                                editingItem = item
                            } label: {
                                billRecordRow(item)
                            }
                            .buttonStyle(.plain)
                        }
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
        .sheet(isPresented: $showPeriodSheet) {
            periodPickerSheet
        }
        .sheet(item: $editingItem) { item in
            RecordEditSheet(item: item) { updated in
                homeViewModel.updateItem(updated)
                editingItem = nil
            } onDelete: {
                if let idx = homeViewModel.items.firstIndex(where: { $0.id == item.id }) {
                    homeViewModel.delete(at: IndexSet(integer: idx))
                }
                editingItem = nil
            }
        }
        .sheet(item: $summaryPlayback) { playback in
            SummaryPlaybackSheet(
                playback: playback,
                petEnabled: settingsViewModel.petCompanionEnabled,
                isMember: hasMemberAccess,
                weeklySharePayload: playback.range == .week
                    ? playbackService.buildWeeklyShareCardPayload(from: homeViewModel.items, summary: playback)
                    : nil,
                shareNickname: settingsViewModel.displayName,
                onCompleted: { progress in
                    quotaStore.markCompleted(playback.range, isMember: hasMemberAccess, progress: progress)
                    if progress >= 0.8 {
                        homeViewModel.markSummaryPlaybackCompleted(playback.range)
                    }
                    quotaRefreshID = UUID()
                },
                onShowMemberPricing: onShowMemberPricing,
                onOpenWeekly: {
                    useCustomRange = false
                    selectedPeriod = .week
                },
                onOpenInsight: onOpenInsight
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .alert("播放次数已用完", isPresented: Binding(
            get: { summaryQuotaMessage != nil },
            set: { if !$0 { summaryQuotaMessage = nil } }
        )) {
            Button("了解会员") {
                let shouldOpenMember = summaryQuotaMessage?.contains("会员") ?? false
                summaryQuotaMessage = nil
                if shouldOpenMember { onShowMemberPricing?() }
            }
            Button("知道了", role: .cancel) {
                summaryQuotaMessage = nil
            }
        } message: {
            Text(summaryQuotaMessage ?? "")
        }
    }

    // MARK: - Summary Playback Card

    @ViewBuilder
    private var summarySliceCard: some View {
        let _ = quotaRefreshID
        if useCustomRange || selectedPeriod == .year {
            EmptyView()
        } else {
            let range = selectedPeriod == .week ? SummaryPlaybackRange.week : .month
            let preview = buildSummaryPreview(for: range)
            let hasData = preview.count > 0
            let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)
            let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(isMonthLocked ? "🔒" : "🎬")
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(range == .week ? "本周生活切片" : "本月生活章")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(summaryCardSubtitle(preview: preview, range: range, hasData: hasData, isMonthLocked: isMonthLocked))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button {
                        handleSummaryPlaybackTap(range: range, preview: preview)
                    } label: {
                        Text(isMonthLocked ? "了解会员" : "播放")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(canPlay ? .white : AppColors.text.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                canPlay ? AppColors.accent : Color.white.opacity(0.64),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(canPlay ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.58), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasData && !isMonthLocked)
                }

                Text(summaryQuotaFootnote(range: range, hasData: hasData))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(range == .month && isMonthLocked ? AppColors.lockGold : AppColors.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassPanel(radius: 24, padding: 20)
        }
    }

    private func buildSummaryPreview(for range: SummaryPlaybackRange) -> SummaryPlayback {
        switch range {
        case .week:
            return playbackService.buildWeekSummary(from: homeViewModel.items)
        case .month:
            return playbackService.buildMonthSummary(from: homeViewModel.items)
        }
    }

    private func summaryCardSubtitle(preview: SummaryPlayback, range: SummaryPlaybackRange, hasData: Bool, isMonthLocked: Bool) -> String {
        guard hasData else { return "这个时间段还没有记录，先记一笔再播放。" }
        if isMonthLocked {
            return "会员专属 · 你的 3 次新用户体验已用完"
        }
        if !preview.teaserLine.isEmpty {
            return preview.teaserLine
        }
        switch range {
        case .week:
            if homeViewModel.items.count >= 5 && !quotaStore.hasCompletedWeekPlaybackEver() {
                return "已记 \(homeViewModel.items.count) 笔，可以讲这周的故事了"
            }
            let category = preview.topCategory.map { "\($0)为主" } ?? "日常为主"
            return "\(preview.count) 笔 · \(preview.total.formatted(.cny)) · \(category)"
        case .month:
            return "\(preview.count) 笔 · \(preview.total.formatted(.cny)) · 6 章看完整月节奏"
        }
    }

    private func summaryQuotaFootnote(range: SummaryPlaybackRange, hasData: Bool) -> String {
        guard hasData else { return "生活切片使用本地模板生成，不依赖 AI 服务。" }
        guard !hasMemberAccess else { return "会员可无限回看周/月生活切片。" }
        switch range {
        case .week:
            let remaining = quotaStore.weekRemaining(isMember: false)
            return remaining > 0 ? "本周剩余 1 次 · 会员可无限" : "本周剩余 0 次 · 下个自然周刷新"
        case .month:
            let remaining = quotaStore.monthRemaining(isMember: false)
            return remaining > 0
                ? "新用户专享剩余 \(remaining)/3 次 · 用完后需会员"
                : "本周切片仍可按周免费播放"
        }
    }

    private func handleSummaryPlaybackTap(range: SummaryPlaybackRange, preview: SummaryPlayback) {
        guard preview.count > 0 else { return }
        guard quotaStore.canPlay(range, isMember: hasMemberAccess) else {
            switch range {
            case .week:
                summaryQuotaMessage = "本周的生活切片已经看完啦。下个自然周会再刷新 1 次免费次数。开通会员可无限回看周/月切片。"
            case .month:
                summaryQuotaMessage = "你的 3 次新用户「本月生活章」已用完。开通会员可无限播放，并享场景备注包与无限 OCR。本周切片仍会在每个自然周刷新 1 次免费次数。"
            }
            return
        }
        summaryPlayback = preview
    }

    // MARK: - Period Picker Sheet

    private var periodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("选择时间范围")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(StatsPeriod.allCases) { period in
                    Button {
                        useCustomRange = false
                        selectedPeriod = period
                        showPeriodSheet = false
                    } label: {
                        HStack {
                            Text(period.rawValue)
                                .font(.system(size: 16, weight: (!useCustomRange && selectedPeriod == period) ? .semibold : .regular))
                            Spacer()
                            if !useCustomRange && selectedPeriod == period {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12).padding(.horizontal, 16)
                        .background(
                            (!useCustomRange && selectedPeriod == period)
                                ? AppColors.accent.opacity(0.1)
                                : Color.white.opacity(0.62),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Custom date range
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义日期").font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.text.opacity(0.8))
                    DatePicker("开始", selection: $customStartDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                    DatePicker("结束", selection: $customEndDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                    Button {
                        useCustomRange = true
                        showPeriodSheet = false
                    } label: {
                        Text("应用自定义日期")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.62)))
            }
            .padding(24)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showPeriodSheet = false }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Simplified Category Filter Chips (no longer used, replaced by Menu)

    private func billRecordRow(_ item: HomeItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }
            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))
                Text("·").foregroundStyle(AppColors.subtext)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.35)).frame(height: 0.8).padding(.top, -4)
        }
    }

    // MARK: - Category Filter Chip

    private func categoryFilterChip(label: String, category: HomeItem.Category?) -> some View {
        let isSelected = selectedCategory == category
        return Button(label) {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        }
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(isSelected ? .white : AppColors.text.opacity(0.82))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AppColors.accent
                : Color.white.opacity(0.72),
            in: Capsule(style: .continuous)
        )
        .shadow(color: isSelected ? AppColors.accent.opacity(0.2) : .clear, radius: 4, y: 2)
    }

    // MARK: - Record List Item

    private func recordListItem(_ item: HomeItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }

            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))

                Text("·")
                    .foregroundStyle(AppColors.subtext)

                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.35))
                .frame(height: 0.8)
                .padding(.top, -4)
        }
    }

    // MARK: - Trend Chart

    @ViewBuilder
    private var trendChart: some View {
        let trendData = computeTrendData()
        VStack(alignment: .leading, spacing: 6) {
            Text("近 30 天支出趋势")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)

            if trendData.isEmpty {
                Text("暂无足够数据绘制趋势图。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.vertical, 20)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 90
                    let maxVal = trendData.map(\.value).max() ?? 1
                    let padding: CGFloat = 8
                    let chartW = w - padding * 2
                    let chartH = h - padding * 2

                    ZStack(alignment: .topLeading) {
                        // Y axis
                        Path { p in
                            p.move(to: CGPoint(x: padding, y: padding))
                            p.addLine(to: CGPoint(x: padding, y: h - padding))
                        }
                        .stroke(AppColors.subtext.opacity(0.3), lineWidth: 1)

                        // X axis
                        Path { p in
                            p.move(to: CGPoint(x: padding, y: h - padding))
                            p.addLine(to: CGPoint(x: w - padding, y: h - padding))
                        }
                        .stroke(AppColors.subtext.opacity(0.3), lineWidth: 1)

                        // Max label
                        Text("\(Int(maxVal))")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.subtext.opacity(0.82))
                            .offset(x: padding + 2, y: 0)

                        // Trend line
                        if trendData.count >= 2 {
                            Path { p in
                                for (i, point) in trendData.enumerated() {
                                    let x = padding + (chartW / CGFloat(max(trendData.count - 1, 1))) * CGFloat(i)
                                    let y = padding + chartH - (CGFloat(point.value) / CGFloat(maxVal)) * chartH
                                    if i == 0 {
                                        p.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        p.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(AppColors.accent.opacity(0.86), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        }

                        // Peak dot
                        if let peak = trendData.max(by: { $0.value < $1.value }),
                           let idx = trendData.firstIndex(where: { $0.id == peak.id }) {
                            let x = padding + (chartW / CGFloat(max(trendData.count - 1, 1))) * CGFloat(idx)
                            let y = padding + chartH - (CGFloat(peak.value) / CGFloat(maxVal)) * chartH
                            Circle()
                                .fill(AppColors.accent.opacity(0.86))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                            Text(peak.value.formatted(.cny))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.text.opacity(0.88))
                                .position(x: min(x + 24, w - 30), y: y - 14)
                        }
                    }
                }
                .frame(height: 92)

                // Trend insight
                Text(trendInsightText(data: trendData))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.top, 2)
            }
        }
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let day: String
        let value: Double
    }

    private func computeTrendData() -> [TrendPoint] {
        let cal = Calendar.current
        var points: [TrendPoint] = []
        for dayOffset in stride(from: 29, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let dayItems = homeViewModel.items.filter { cal.isDate($0.createdAt, inSameDayAs: date) }
            let total = dayItems.reduce(0) { $0 + $1.amount }
            let label = cal.component(.day, from: date)
            points.append(TrendPoint(day: "\(label)", value: total))
        }
        return points
    }

    private func trendInsightText(data: [TrendPoint]) -> String {
        let total = data.reduce(0) { $0 + $1.value }
        let avg = data.isEmpty ? 0 : total / Double(data.count)
        let recent = data.suffix(7)
        let recentAvg = recent.isEmpty ? 0 : recent.reduce(0) { $0 + $1.value } / Double(recent.count)
        if recentAvg > avg * 1.15 {
            return "最近一周支出有所上升，可以稍微留意。"
        } else if recentAvg < avg * 0.85 {
            return "最近一周支出有所下降，节奏不错。"
        }
        return "本月支出整体平稳。"
    }
}

// MARK: - Insight View (matching web insightPage)

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
                        softActionButton("柔和下月参考") {
                            homeViewModel.markMonthlySoftPlan()
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

// MARK: - Record Edit Sheet

struct RecordEditSheet: View {
    let item: HomeItem
    var onSave: (HomeItem) -> Void
    var onDelete: () -> Void

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Amount
                    VStack(alignment: .leading, spacing: 6) {
                        Text("金额").font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                        HStack(spacing: 2) {
                            Text("¥").font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.subtext.opacity(0.74))
                            TextField("0.00", text: $amountText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.text)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.78)))
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类").font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 140), spacing: 8)], spacing: 8) {
                            ForEach(HomeItem.Category.allCases) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat.displayName)
                                        .font(.system(size: 14, weight: selectedCategory == cat ? .semibold : .regular))
                                        .foregroundStyle(selectedCategory == cat ? .white : AppColors.text.opacity(0.82))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedCategory == cat ? AppColors.accent : Color.white.opacity(0.72),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Date
                    VStack(alignment: .leading, spacing: 6) {
                        Text("日期").font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .datePickerStyle(.graphical)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.62)))
                    }

                    // Note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("备注").font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                        TextField("补充细节", text: $titleText)
                            .font(.system(size: 16))
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.72)))
                    }

                    // Save
                    Button {
                        var updated = item
                        updated.amount = parsedAmount
                        updated.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "\(selectedCategory.rawValue)消费" : titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.category = selectedCategory
                        updated.createdAt = selectedDate
                        updated.updatedAt = Date()
                        onSave(updated)
                        dismiss()
                    } label: {
                        Text("保存修改")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [AppColors.accent.opacity(0.92), AppColors.accent],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(parsedAmount <= 0)

                    // Delete
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("删除账单")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("编辑账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
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
