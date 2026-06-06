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
            if selectedTab == .today, settingsViewModel.petCompanionEnabled {
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
            if tab == .today { petHint = "今天花得怎么样？慢慢记下来就好。" }
            petBubbleVisible = false
        }
        .onChange(of: settingsViewModel.petCompanionEnabled) { _, enabled in
            if !enabled {
                petBubbleVisible = false
            }
        }
        .onChange(of: homeViewModel.petMessage) { _, msg in
            guard let msg, settingsViewModel.petCompanionEnabled else { return }
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
