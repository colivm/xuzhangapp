import Foundation
import PhotosUI
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
    static var readableSubtext: Color { theme.textSecondary }
    static var readableTertiary: Color { theme.textSecondary }
    static var readableAccent: Color { theme.readableAccent }
    static var onAccent: Color { theme.onAccent }
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

extension View {
    func minimumTapTarget(_ size: CGFloat = CGFloat(AccessibilityLayoutPolicy.minimumTapTarget)) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }
}

// MARK: - Theme-Aware Interaction Surfaces

struct ThemedInteractionSurface: ViewModifier {
    var radius: CGFloat = 20
    var tint: Color = .accentColor
    var isSelected = false
    var isDisabled = false
    var glowIntensity: Double = 1

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(surfaceFill)
            .overlay(surfaceRim)
            .overlay(selectedRim)
            .shadow(
                color: AppColors.subtext.opacity(isDisabled ? 0.03 : (isSelected ? 0.10 : 0.07)),
                radius: isSelected ? 14 : 9,
                x: 0,
                y: isSelected ? 7 : 4
            )
            .shadow(
                color: tint.opacity(isSelected && !isDisabled ? 0.15 * boundedGlow : 0.0),
                radius: 16,
                x: 0,
                y: 0
            )
    }

    private var surfaceFill: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(AppColors.panelStrong.opacity(baseOpacity))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(reduceTransparency ? 0.06 : (isDisabled ? 0.10 : 0.25)),
                        AppColors.paperWarm.opacity(isDisabled ? 0.07 : 0.15),
                        tint.opacity(isDisabled ? 0.03 : (isSelected ? 0.14 * boundedGlow : 0.055))
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(alignment: .bottomTrailing) {
                if !reduceTransparency {
                    RadialGradient(
                        colors: [
                            tint.opacity(isDisabled ? 0.02 : (isSelected ? 0.17 * boundedGlow : 0.065)),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: isSelected ? 150 : 112
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
    }

    private var surfaceRim: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isDisabled ? 0.16 : 0.54),
                        tint.opacity(isDisabled ? 0.08 : (isSelected ? 0.34 * boundedGlow : 0.14)),
                        AppColors.line.opacity(isSelected ? 0.70 : 0.50)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 1.15 : 1
            )
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var selectedRim: some View {
        if isSelected && !isDisabled {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(tint.opacity(0.13 * boundedGlow), lineWidth: 3)
                .padding(1.5)
                .allowsHitTesting(false)
        }
    }

    private var baseOpacity: Double {
        if isDisabled {
            return reduceTransparency ? 0.56 : 0.44
        }
        if isSelected {
            return reduceTransparency ? 0.96 : 0.88
        }
        return reduceTransparency ? 0.86 : 0.72
    }

    private var boundedGlow: Double {
        min(max(glowIntensity, 0), 1.4)
    }
}

struct PurposefulCardButtonStyle: ButtonStyle {
    var radius: CGFloat = 18
    var depth: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && isEnabled
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.988 : 1), anchor: .center)
            .offset(y: reduceMotion ? 0 : (pressed ? 0.9 * depth : 0))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(pressed ? 0.16 : 0.0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(pressed ? 0.12 : 0.0),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 42)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .allowsHitTesting(false)
            }
            .shadow(
                color: Color.black.opacity(pressed ? 0.010 : 0.024 * Double(depth)),
                radius: pressed ? 2 : 6,
                x: 0,
                y: pressed ? 1 : 3
            )
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: pressed)
    }
}

struct PressableCardFeedback: ViewModifier {
    var radius: CGFloat = 18
    var depth: CGFloat = 1

    @GestureState private var isPressing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : (isPressing ? 0.987 : 1), anchor: .center)
            .offset(y: reduceMotion ? 0 : (isPressing ? 1.2 * depth : 0))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(isPressing ? 0.20 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.84), value: isPressing)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0, maximumDistance: 8)
                    .updating($isPressing) { value, state, _ in
                        guard value else { return }
                        state = true
                    }
            )
    }
}

extension View {
    func themedInteractionSurface(
        radius: CGFloat = 20,
        tint: Color = .accentColor,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        glowIntensity: Double = 1
    ) -> some View {
        modifier(ThemedInteractionSurface(
            radius: radius,
            tint: tint,
            isSelected: isSelected,
            isDisabled: isDisabled,
            glowIntensity: glowIntensity
        ))
    }

    func pressableCardFeedback(radius: CGFloat = 18, depth: CGFloat = 1) -> some View {
        modifier(PressableCardFeedback(radius: radius, depth: depth))
    }
}

// MARK: - Semantic Surface Modifiers

enum AppSurfaceRole: Equatable {
    case record
    case playback
    case trace
    case metric
    case action
    case share
    case quiet
}

struct AppSemanticSurface: ViewModifier {
    var role: AppSurfaceRole
    var radius: CGFloat = 20
    var padding: CGFloat = 0
    var tint: Color = .accentColor
    var isSelected = false
    var isDisabled = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surfaceBackground)
            .overlay(roleAccent)
            .overlay(surfaceRim)
            .shadow(color: primaryShadowColor, radius: primaryShadowRadius, x: 0, y: primaryShadowY)
            .shadow(color: secondaryShadowColor, radius: secondaryShadowRadius, x: 0, y: 0)
    }

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(baseFill)
            .overlay(surfaceWash.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous)))
            .overlay(sceneHighlight.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous)))
    }

    private var baseFill: Color {
        switch role {
        case .record:
            return AppColors.panelStrong.opacity(reduceTransparency ? 0.96 : 0.78)
        case .playback:
            return reduceTransparency ? AppColors.panelStrong : AppColors.monthlyInsightBg
        case .trace:
            return AppColors.panel.opacity(reduceTransparency ? 0.94 : 0.72)
        case .metric:
            return AppColors.surfaceMuted.opacity(reduceTransparency ? 0.96 : 0.80)
        case .action:
            return AppColors.panelStrong.opacity(isSelected ? 0.92 : 0.76)
        case .share:
            return reduceTransparency ? AppColors.panelStrong : AppColors.paperMist
        case .quiet:
            return AppColors.panel.opacity(reduceTransparency ? 0.92 : 0.68)
        }
    }

    private var surfaceWash: LinearGradient {
        LinearGradient(
            colors: washColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var washColors: [Color] {
        switch role {
        case .record:
            return [
                Color.white.opacity(0.48),
                AppColors.panelStrong.opacity(0.18),
                tint.opacity(0.055)
            ]
        case .playback:
            return [
                Color.white.opacity(0.42),
                AppColors.tracePlaybackButtonBg.opacity(0.34),
                tint.opacity(0.08)
            ]
        case .trace:
            return [
                Color.white.opacity(0.30),
                AppColors.surfaceMuted.opacity(0.34),
                tint.opacity(0.035)
            ]
        case .metric:
            return [
                Color.white.opacity(0.34),
                AppColors.surfaceMuted.opacity(0.42),
                Color.white.opacity(0.16)
            ]
        case .action:
            return [
                Color.white.opacity(isSelected ? 0.42 : 0.30),
                tint.opacity(isSelected ? 0.16 : 0.065),
                AppColors.panelStrong.opacity(0.22)
            ]
        case .share:
            return [
                Color.white.opacity(0.42),
                AppColors.tracePlaybackButtonBg.opacity(0.24),
                tint.opacity(0.075)
            ]
        case .quiet:
            return [
                Color.white.opacity(0.22),
                AppColors.surfaceMuted.opacity(0.24),
                Color.white.opacity(0.08)
            ]
        }
    }

    @ViewBuilder
    private var sceneHighlight: some View {
        if role == .record || role == .playback || role == .share {
            RadialGradient(
                colors: [
                    tint.opacity(role == .record ? 0.075 : 0.055),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: role == .record ? 154 : 188
            )
        }
    }

    @ViewBuilder
    private var roleAccent: some View {
        switch role {
        case .playback:
            EmptyView()
        case .trace:
            Rectangle()
                .fill(AppColors.line.opacity(0.34))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 1)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        case .metric:
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(tint.opacity(0.34))
                .frame(width: 34, height: 3)
                .padding(.top, 13)
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
        case .record, .action, .share, .quiet:
            EmptyView()
        }
    }

    private var surfaceRim: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: rimColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 1.15 : 1
            )
            .allowsHitTesting(false)
    }

    private var rimColors: [Color] {
        switch role {
        case .record:
            return [Color.white.opacity(0.66), AppColors.line.opacity(0.46), tint.opacity(0.13)]
        case .playback:
            return [Color.white.opacity(0.58), tint.opacity(0.16), AppColors.stroke.opacity(0.20)]
        case .trace:
            return [Color.white.opacity(0.46), AppColors.stroke.opacity(0.46), tint.opacity(0.08)]
        case .metric:
            return [Color.white.opacity(0.48), AppColors.stroke.opacity(0.48), tint.opacity(0.10)]
        case .action:
            return [Color.white.opacity(0.56), tint.opacity(isSelected ? 0.30 : 0.14), AppColors.line.opacity(0.48)]
        case .share:
            return [Color.white.opacity(0.62), tint.opacity(0.14), AppColors.stroke.opacity(0.20)]
        case .quiet:
            return [Color.white.opacity(0.40), AppColors.line.opacity(0.50), AppColors.stroke.opacity(0.26)]
        }
    }

    private var primaryShadowColor: Color {
        switch role {
        case .record:
            return AppColors.subtext.opacity(isDisabled ? 0.03 : 0.075)
        case .playback, .share:
            return AppColors.subtext.opacity(0.055)
        case .trace:
            return AppColors.subtext.opacity(0.050)
        case .metric:
            return AppColors.subtext.opacity(0.045)
        case .action:
            return AppColors.subtext.opacity(isSelected ? 0.080 : 0.050)
        case .quiet:
            return AppColors.subtext.opacity(0.040)
        }
    }

    private var primaryShadowRadius: CGFloat {
        switch role {
        case .playback, .share:
            return 16
        case .record:
            return 12
        case .action:
            return isSelected ? 13 : 9
        case .trace, .metric, .quiet:
            return 10
        }
    }

    private var primaryShadowY: CGFloat {
        switch role {
        case .playback, .share:
            return 7
        case .record:
            return 5
        case .action:
            return isSelected ? 6 : 4
        case .trace, .metric, .quiet:
            return 4
        }
    }

    private var secondaryShadowColor: Color {
        guard isSelected && !isDisabled else { return .clear }
        return tint.opacity(role == .action ? 0.12 : 0.06)
    }

    private var secondaryShadowRadius: CGFloat {
        isSelected ? 14 : 0
    }
}

extension View {
    func appSurface(
        _ role: AppSurfaceRole,
        radius: CGFloat = 20,
        padding: CGFloat = 0,
        tint: Color = .accentColor,
        isSelected: Bool = false,
        isDisabled: Bool = false
    ) -> some View {
        modifier(AppSemanticSurface(
            role: role,
            radius: radius,
            padding: padding,
            tint: tint,
            isSelected: isSelected,
            isDisabled: isDisabled
        ))
    }

    func recordSurface(radius: CGFloat = 18, padding: CGFloat = 0, tint: Color = .accentColor) -> some View {
        appSurface(.record, radius: radius, padding: padding, tint: tint)
    }

    func playbackSurface(radius: CGFloat = 22, padding: CGFloat = 0, tint: Color = .accentColor) -> some View {
        appSurface(.playback, radius: radius, padding: padding, tint: tint)
    }

    func traceSurface(radius: CGFloat = 18, padding: CGFloat = 0, tint: Color = .accentColor) -> some View {
        appSurface(.trace, radius: radius, padding: padding, tint: tint)
    }

    func metricSurface(radius: CGFloat = 16, padding: CGFloat = 0, tint: Color = .accentColor) -> some View {
        appSurface(.metric, radius: radius, padding: padding, tint: tint)
    }
}

// MARK: - Glass Panel Modifier

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .appSurface(.quiet, radius: radius, padding: padding, tint: AppColors.accent)
    }
}

struct PaperChapterPanel: ViewModifier {
    var radius: CGFloat = 24
    var padding: CGFloat = 22
    var showsAccentLine: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(.leading, showsAccentLine ? 6 : 0)
            .appSurface(showsAccentLine ? .playback : .share, radius: radius, padding: padding, tint: AppColors.accent)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab: AppTab = .today
    @StateObject private var recordTabSession = RecordTabSession()
    @State private var statsTabState = StatsTabState()
    @State private var insightTabState = InsightTabState()
    @State private var showMemberPricing = false
    @State private var pricingHighlightPlanId: String?
    @State private var pricingEntryContext: MemberPricingEntryContext = .settings
    @State private var statsTraceOpenRequestID: UUID?
    @State private var settingsAppearanceOpenRequestID: UUID?
    @State private var lastMemberStatusRefreshAt: Date?
    @State private var homeLifeMarkRewardPrompt: LifeMarkSceneRewardPrompt?
    @State private var pendingHomeLifeMarkRewardPrompts = UniqueFIFOQueue<LifeMarkSceneRewardPrompt>()
    @State private var memoryPromptItem: HomeItem?
    @State private var memoryPromptReason: PhotoMemoryPromptReason?
    @State private var pendingPostSaveMemoryPrompts = UniqueFIFOQueue<PostSaveMemoryPrompt>()
    @State private var firstRecordPlaybackPromptRequestID: UUID?
    @State private var memorySourceItem: HomeItem?
    @State private var memoryPreviewItem: HomeItem?
    @State private var selectedMemoryPhotos: [PhotosPickerItem] = []
    @State private var pendingMemoryImageDatas: [Data] = []
    @State private var showMemoryPhotoPicker = false
    @State private var memoryPreviewReselectItem: HomeItem?
    @State private var memoryAttachMode: MemoryAttachMode = .preview
    private let postSavePromptBudgetStore = PostSavePromptBudgetStore()

    private enum MemoryAttachMode {
        case preview
        case direct
    }

    private struct PostSaveMemoryPrompt: Identifiable {
        let item: HomeItem
        let reason: PhotoMemoryPromptReason

        var id: UUID { item.id }
    }

    private var hasActivePostSavePresentation: Bool {
        homeLifeMarkRewardPrompt != nil
            || memoryPromptItem != nil
            || memorySourceItem != nil
            || memoryPreviewItem != nil
            || showMemoryPhotoPicker
            || showMemberPricing
    }

    private var memoryPhotoPickerSelectionLimit: Int {
        guard let item = memorySourceItem else { return 1 }
        return max(1, 9 - item.memoryImageCount)
    }

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

            if let memoryPromptItem {
                memorySuccessOverlay(memoryPromptItem)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(6)
            }
        }
        .photosPicker(
            isPresented: $showMemoryPhotoPicker,
            selection: $selectedMemoryPhotos,
            maxSelectionCount: memoryPhotoPickerSelectionLimit,
            matching: .images,
            photoLibrary: .shared()
        )
        .sheet(item: $memoryPreviewItem, onDismiss: {
            if let item = memoryPreviewReselectItem {
                memoryPreviewReselectItem = nil
                openMemoryPhotoPicker(for: item)
                return
            }
            guard !pendingMemoryImageDatas.isEmpty else { return }
            closeMemoryFlow()
        }) { item in
            if !pendingMemoryImageDatas.isEmpty {
                MemoryPreviewSheet(
                    item: item,
                    imageDatas: pendingMemoryImageDatas,
                    onConfirm: { coverIndex in
                        let reason = PhotoMemoryPromptPolicy.anchorReason(for: item)
                        if homeViewModel.attachMemoryImages(
                            pendingMemoryImageDatas,
                            to: item.id,
                            coverImageIndex: coverIndex,
                            anchorReason: reason
                        ) {
                            closeMemoryFlow()
                        }
                    },
                    onReselect: {
                        memoryPreviewReselectItem = item
                        pendingMemoryImageDatas = []
                        memoryPreviewItem = nil
                    }
                )
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
        .onChange(of: showMemberPricing) { _, isPresented in
            if !isPresented {
                presentNextPostSavePromptIfPossible()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            settingsViewModel.refreshThemeAccess(showsMessage: true)
            Task {
                await refreshAccountAndMemberStatusIfNeeded(force: true)
            }
        }
        .onChange(of: selectedMemoryPhotos) { _, newValue in
            guard !newValue.isEmpty, let item = memorySourceItem else { return }
            Task {
                var compressedImages: [Data] = []
                for photo in newValue.prefix(9) {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let compressedData = MemoryImageCompressor.compressedJPEGData(from: data) {
                        compressedImages.append(compressedData)
                    }
                }
                await MainActor.run {
                    guard !compressedImages.isEmpty else {
                        selectedMemoryPhotos = []
                        memorySourceItem = nil
                        showMemoryPhotoPicker = false
                        memoryAttachMode = .preview
                        presentNextPostSavePromptIfPossible()
                        return
                    }
                    pendingMemoryImageDatas = compressedImages
                    selectedMemoryPhotos = []
                    if memoryAttachMode == .direct {
                        _ = homeViewModel.attachMemoryImages(
                            compressedImages,
                            to: item.id,
                            coverImageIndex: 0,
                            anchorReason: PhotoMemoryPromptPolicy.anchorReason(for: item)
                        )
                        memorySourceItem = nil
                        pendingMemoryImageDatas = []
                        showMemoryPhotoPicker = false
                        memoryAttachMode = .preview
                        Task { @MainActor in
                            await Task.yield()
                            presentNextPostSavePromptIfPossible()
                        }
                    } else {
                        memorySourceItem = nil
                        memoryPreviewItem = item
                    }
                }
            }
        }
        .onChange(of: showMemoryPhotoPicker) { _, isPresented in
            guard !isPresented else { return }
            Task { @MainActor in
                await Task.yield()
                guard selectedMemoryPhotos.isEmpty,
                      memoryPreviewItem == nil,
                      memorySourceItem != nil else {
                    return
                }
                memorySourceItem = nil
                memoryAttachMode = .preview
                presentNextPostSavePromptIfPossible()
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(AppColors.panelStrong)
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
                HomeView(onQuickRecord: { mode in
                             recordTabSession.selectedEntryMode = mode
                             selectTab(.record)
                         },
                         onNavigateStats: { selectTab(.stats) },
                         onNavigateWeeklyTrace: {
                             statsTraceOpenRequestID = UUID()
                             selectTab(.stats)
                         },
                          onNavigateMonthlyTrace: {
                              statsTabState.openLifeChapter(.month)
                              selectTab(.stats)
                          },
                          onNavigateInsight: { selectTab(.insight) },
                          onNavigateSettings: { selectTab(.settings) },
                         onShowMemberPricing: {
                             showMemberPricingSheet(entryContext: .playbackQuota)
                         },
                         onAttachMemoryImage: { item in
                             memoryPromptItem = nil
                             memoryPromptReason = nil
                             memoryPreviewItem = nil
                             pendingMemoryImageDatas = []
                             selectedMemoryPhotos = []
                             openMemoryPhotoPicker(for: item, mode: .direct)
                         },
                         firstRecordPromptRequestID: firstRecordPlaybackPromptRequestID,
                         isExternalPostSavePresentationActive: hasActivePostSavePresentation,
                         onFirstRecordPromptCompleted: completeFirstRecordPlaybackPrompt)
            case .record:
                RecordView(
                    tabSession: recordTabSession,
                    onSaved: { prompt in
                        handleManualRecordSaved(prompt: prompt)
                    },
                    onShowMemberPricing: { entryContext in
                        showMemberPricingSheet(entryContext: entryContext)
                    }
                )
            case .stats:
                StatsWebView(
                    tabState: $statsTabState,
                    openTraceRequestID: statsTraceOpenRequestID,
                    onShowMemberPricing: { entryContext in
                        showMemberPricingSheet(entryContext: entryContext)
                    },
                    onOpenInsight: { selectTab(.insight) },
                    onAttachMemoryImage: { item in
                        memoryPromptItem = nil
                        memoryPromptReason = nil
                        memoryPreviewItem = nil
                        pendingMemoryImageDatas = []
                        selectedMemoryPhotos = []
                        openMemoryPhotoPicker(for: item, mode: .direct)
                    }
                )
            case .insight:
                InsightWebView(
                    onStartRecording: {
                        recordTabSession.selectedEntryMode = .manual
                        selectTab(.record)
                    },
                    onNavigateSettings: { selectTab(.settings) },
                    onShowMemberPricing: {
                        showMemberPricingSheet(entryContext: .aiCommand)
                    },
                    onOpenAppearanceSettings: {
                        settingsAppearanceOpenRequestID = UUID()
                        selectTab(.settings)
                    },
                    onOpenTrace: { range in
                        statsTabState.openLifeChapter(range)
                        selectTab(.stats)
                    },
                    tabState: $insightTabState
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
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func selectTab(_ tab: AppTab) {
        guard selectedTab != tab else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectedTab = tab
        }
        if tab == .today {
            Task { @MainActor in
                await Task.yield()
                presentNextPostSavePromptIfPossible()
            }
        }
    }

    private func handleManualRecordSaved(prompt: LifeMarkSceneRewardPrompt?) {
        guard let savedItem = homeViewModel.items.first else { return }
        let isFirstTodayRecord = homeViewModel.items.count == 1
            && Calendar.current.isDateInToday(savedItem.createdAt)
        selectTab(.today)

        if isFirstTodayRecord {
            if postSavePromptBudgetStore.reserve(.firstPlayback) {
                firstRecordPlaybackPromptRequestID = UUID()
            }
            return
        }

        if let prompt {
            if postSavePromptBudgetStore.reserve(.sceneReward) {
                enqueueHomeLifeMarkRewardPrompt(prompt)
            }
            return
        }

        if let reason = PhotoMemoryPromptPolicy.reason(
            for: savedItem,
            existingItems: homeViewModel.items
        ), postSavePromptBudgetStore.reserve(.memoryPhoto) {
            enqueuePostSaveMemoryPrompt(for: savedItem, reason: reason)
        }
    }

    private func enqueuePostSaveMemoryPrompt(for item: HomeItem, reason: PhotoMemoryPromptReason) {
        guard memoryPromptItem?.id != item.id,
              !pendingPostSaveMemoryPrompts.contains(id: item.id) else {
            return
        }
        pendingPostSaveMemoryPrompts.enqueue(PostSaveMemoryPrompt(item: item, reason: reason))
        presentNextPostSavePromptIfPossible()
    }

    private func enqueueHomeLifeMarkRewardPrompt(_ prompt: LifeMarkSceneRewardPrompt) {
        guard homeLifeMarkRewardPrompt?.id != prompt.id,
              !pendingHomeLifeMarkRewardPrompts.contains(id: prompt.id) else {
            return
        }
        pendingHomeLifeMarkRewardPrompts.enqueue(prompt)
        presentNextPostSavePromptIfPossible()
    }

    private func completeFirstRecordPlaybackPrompt(continuesRecording: Bool) {
        firstRecordPlaybackPromptRequestID = nil
        if continuesRecording {
            selectTab(.record)
        }
        Task { @MainActor in
            await Task.yield()
            presentNextPostSavePromptIfPossible()
        }
    }

    private func presentNextPostSavePromptIfPossible() {
        guard firstRecordPlaybackPromptRequestID == nil,
              selectedTab == .today,
              !hasActivePostSavePresentation else {
            return
        }
        if let pendingPostSaveMemoryPrompt = pendingPostSaveMemoryPrompts.dequeue() {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                memoryPromptReason = pendingPostSaveMemoryPrompt.reason
                memoryPromptItem = pendingPostSaveMemoryPrompt.item
            }
            return
        }
        if let pendingHomeLifeMarkRewardPrompt = pendingHomeLifeMarkRewardPrompts.dequeue() {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                homeLifeMarkRewardPrompt = pendingHomeLifeMarkRewardPrompt
            }
        }
    }

    private func closeMemoryFlow() {
        withAnimation(.easeInOut(duration: 0.18)) {
            memoryPromptItem = nil
        }
        memoryPromptReason = nil
        memorySourceItem = nil
        memoryPreviewItem = nil
        showMemoryPhotoPicker = false
        pendingMemoryImageDatas = []
        selectedMemoryPhotos = []
        memoryPreviewReselectItem = nil
        memoryAttachMode = .preview
        Task { @MainActor in
            await Task.yield()
            presentNextPostSavePromptIfPossible()
        }
    }

    private func openMemoryPhotoPicker(for item: HomeItem, mode: MemoryAttachMode = .preview) {
        guard item.memoryImageCount < 9 else { return }
        memoryAttachMode = mode
        memorySourceItem = item
        showMemoryPhotoPicker = true
    }

    private func memorySuccessOverlay(_ item: HomeItem) -> some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    closeMemoryFlow()
                }

            MemorySuccessCard(
                item: item,
                reason: memoryPromptReason,
                onAddImage: {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        memoryPromptItem = nil
                        memoryPromptReason = nil
                    }
                    openMemoryPhotoPicker(for: item)
                },
                onSkip: closeMemoryFlow
            )
            .padding(.horizontal, 22)
        }
    }

    private func dismissHomeLifeMarkRewardPrompt(_ prompt: LifeMarkSceneRewardPrompt) {
        if case .coldStart = prompt.kind {
            LifeMarkSceneRewardService.shared.markColdStartGuideSeen()
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            homeLifeMarkRewardPrompt = nil
        }
        Task { @MainActor in
            await Task.yield()
            presentNextPostSavePromptIfPossible()
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

            Group {
                if reduceMotion {
                    lifeMarkRewardAnimatedBackdrop(time: 0)
                } else {
                    TimelineView(.periodic(from: Date(), by: 1.0 / 12.0)) { context in
                        lifeMarkRewardAnimatedBackdrop(time: context.date.timeIntervalSinceReferenceDate)
                    }
                }
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
        homeViewModel.markMemberEntryOpened(scene: memberAnalyticsScene(for: entryContext))
        pricingHighlightPlanId = highlightPlanId
        pricingEntryContext = highlightPlanId == "lifetime" ? .lifetime : entryContext
        showMemberPricing = true
        Task {
            await settingsViewModel.refreshMemberFromLocalEntitlements(syncToCloud: true)
        }
    }

    private func memberAnalyticsScene(for context: MemberPricingEntryContext) -> String {
        switch context {
        case .traceDeepInsight: return "trace_deep_insight"
        case .playbackQuota: return "playback_quota"
        case .ocrImport: return "ocr_import"
        case .scenePack(_): return "scene_pack"
        case .lifetime: return "lifetime"
        case .aiCommand: return "ai_command"
        case .settings: return "settings"
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
                            .font(.system(
                                .caption,
                                design: .default,
                                weight: selectedTab == tab ? .semibold : .regular
                            ))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? AppColors.accent.opacity(0.9)
                                    : AppColors.subtext.opacity(0.88)
                            )
                            .lineLimit(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                    .overlay(alignment: .topTrailing) {
                        if tab == .stats, shouldShowStatsGuidanceBadge {
                            Circle()
                                .fill(AppColors.lockGold)
                                .frame(width: 8, height: 8)
                                .offset(x: -18, y: 4)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selectedTab == tab ? "已选中" : "")
                .accessibilityHint("切换到\(tab.pageTitle)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(AppColors.panelStrong)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.43))
                        .frame(height: 1)
                }
                .shadow(color: AppColors.bg.opacity(0.28), radius: 10, x: 0, y: -6)
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

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsViewModel())
            .environmentObject(HomeViewModel())
    }
}
