import SwiftUI
import UIKit
import PhotosUI
import ImageIO

private extension LifeStoryVisualProfile {
    @MainActor
    var gradientColors: [Color] {
        switch self {
        case .rain:
            return [Color(red: 0.72, green: 0.80, blue: 0.86), Color(red: 0.86, green: 0.90, blue: 0.94), AppColors.bg]
        case .travel:
            return [Color(red: 0.84, green: 0.92, blue: 0.86), Color(red: 0.95, green: 0.94, blue: 0.78), AppColors.bg]
        case .lateCity:
            return [Color(red: 0.72, green: 0.75, blue: 0.88), Color(red: 0.87, green: 0.88, blue: 0.95), AppColors.bg]
        case .warmDaily:
            return [Color(red: 0.99, green: 0.92, blue: 0.84), Color(red: 0.93, green: 0.95, blue: 0.88), AppColors.bg]
        case .fitness:
            return [Color(red: 0.82, green: 0.93, blue: 0.86), Color(red: 0.91, green: 0.97, blue: 0.93), AppColors.bg]
        case .social:
            return [Color(red: 0.99, green: 0.89, blue: 0.80), Color(red: 0.96, green: 0.91, blue: 0.84), AppColors.bg]
        case .defaultSoft:
            return [AppColors.heroGradientPink.opacity(0.34), AppColors.heroGradientTeal.opacity(0.38), AppColors.bg]
        }
    }
}

private struct StoryDynamicBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let profile: LifeStoryVisualProfile
    var opacity: Double = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: profile.gradientColors.map { $0.opacity(0.32 * opacity) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if reduceMotion {
                canvasLayer(time: 0)
            } else {
                TimelineView(.periodic(from: Date(), by: 1.0 / 8.0)) { timeline in
                    canvasLayer(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func canvasLayer(time: TimeInterval) -> some View {
        Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { context, size in
            switch profile {
            case .rain:
                drawRain(in: &context, size: size, time: time)
            case .travel:
                drawTravel(in: &context, size: size, time: time)
            case .lateCity:
                drawLateCity(in: &context, size: size, time: time)
            case .warmDaily:
                drawWarmDaily(in: &context, size: size, time: time)
            case .fitness:
                drawFitness(in: &context, size: size, time: time)
            case .social:
                drawSocial(in: &context, size: size, time: time)
            case .defaultSoft:
                drawPaperFlow(in: &context, size: size, time: time)
            }
        }
        .opacity(opacity)
    }

    private func drawRain(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        context.fill(
            Path(ellipseIn: CGRect(x: -40, y: size.height * 0.06, width: size.width * 0.86, height: size.height * 0.26)),
            with: .color(Color.white.opacity(0.06))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.24, y: size.height * 0.58, width: size.width * 0.66, height: size.height * 0.20)),
            with: .color(Color(red: 0.80, green: 0.88, blue: 0.92).opacity(0.07))
        )
        for index in 0..<48 {
            let seed = Double(index + 1)
            let lane = (seed * 0.073).truncatingRemainder(dividingBy: 1)
            let drift = 36 + seed.truncatingRemainder(dividingBy: 22)
            let speed = 0.42 + seed.truncatingRemainder(dividingBy: 9) / 30
            let progress = (time * speed + seed * 0.041).truncatingRemainder(dividingBy: 1)
            let x = lane * size.width - 22 + progress * drift
            let y = progress * (size.height + 64) - 40
            let length = 14 + seed.truncatingRemainder(dividingBy: 12)
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + length * 0.30, y: y + length))
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.16)),
                style: StrokeStyle(lineWidth: seed.truncatingRemainder(dividingBy: 4) == 0 ? 1.2 : 0.8, lineCap: .round)
            )
        }
        for index in 0..<4 {
            let progress = (time * 0.12 + Double(index) * 0.18).truncatingRemainder(dividingBy: 1)
            let x = size.width * (0.18 + CGFloat(index) * 0.19)
            let y = size.height * (0.70 + CGFloat(progress) * 0.12)
            let ripple = 18 + CGFloat(index) * 8
            context.stroke(
                Path(ellipseIn: CGRect(x: x, y: y, width: ripple, height: ripple * 0.36)),
                with: .color(Color.white.opacity(0.08)),
                style: StrokeStyle(lineWidth: 0.8)
            )
        }
    }

    private func drawTravel(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<4 {
            let offset = CGFloat(index) * size.height * 0.16 + size.height * 0.18
            var path = Path()
            path.move(to: CGPoint(x: -20, y: offset))
            path.addCurve(
                to: CGPoint(x: size.width + 24, y: offset + 8),
                control1: CGPoint(x: size.width * 0.28, y: offset - 34),
                control2: CGPoint(x: size.width * 0.72, y: offset + 42)
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.14)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 10])
            )

            let progress = (time * (0.08 + Double(index) * 0.02)).truncatingRemainder(dividingBy: 1)
            let x = CGFloat(progress) * (size.width + 44) - 22
            let y = offset + CGFloat(sin(time + Double(index))) * 8
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 6, height: 6)),
                with: .color(Color.white.opacity(0.22))
            )
        }
        let nodes = [
            CGPoint(x: size.width * 0.20, y: size.height * 0.24),
            CGPoint(x: size.width * 0.78, y: size.height * 0.36),
            CGPoint(x: size.width * 0.30, y: size.height * 0.62)
        ]
        for node in nodes {
            context.stroke(
                Path(ellipseIn: CGRect(x: node.x, y: node.y, width: 10, height: 10)),
                with: .color(Color.white.opacity(0.16)),
                style: StrokeStyle(lineWidth: 1)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: node.x + 3, y: node.y + 3, width: 4, height: 4)),
                with: .color(Color.white.opacity(0.18))
            )
        }
    }

    private func drawLateCity(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<6 {
            let y = size.height * (0.18 + CGFloat(index) * 0.12)
            let progress = (time * (0.09 + Double(index) * 0.012)).truncatingRemainder(dividingBy: 1)
            let width = size.width * (0.22 + CGFloat(index) * 0.08)
            let x = CGFloat(progress) * (size.width + width) - width
            let rect = CGRect(x: x, y: y, width: width, height: 2.4)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 99),
                with: .color(Color.white.opacity(0.08))
            )
        }
        for index in 0..<18 {
            let seed = Double(index + 1)
            let x = CGFloat((seed * 0.131).truncatingRemainder(dividingBy: 1)) * size.width
            let height = size.height * (0.16 + CGFloat(seed.truncatingRemainder(dividingBy: 5)) * 0.06)
            let progress = (time * (0.10 + seed / 220)).truncatingRemainder(dividingBy: 1)
            let y = CGFloat(progress) * (size.height + height) - height
            let rect = CGRect(x: x, y: y, width: 2.2, height: height)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(Color.white.opacity(0.10))
            )
        }
    }

    private func drawWarmDaily(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.54, y: size.height * 0.54, width: size.width * 0.34, height: size.height * 0.16)),
            with: .color(Color.white.opacity(0.08))
        )
        for index in 0..<5 {
            let baseX = size.width * (0.18 + CGFloat(index) * 0.16)
            let sway = CGFloat(sin(time * 0.8 + Double(index) * 0.7)) * 8
            var path = Path()
            path.move(to: CGPoint(x: baseX, y: size.height * 0.80))
            path.addCurve(
                to: CGPoint(x: baseX + sway, y: size.height * 0.18),
                control1: CGPoint(x: baseX - 18, y: size.height * 0.58),
                control2: CGPoint(x: baseX + 26, y: size.height * 0.36)
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.10)),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
            )
        }
        for index in 0..<7 {
            let y = size.height * (0.16 + CGFloat(index) * 0.10)
            let drift = CGFloat(cos(time * 0.26 + Double(index))) * 5
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.06, y: y))
            path.addCurve(
                to: CGPoint(x: size.width * 0.94, y: y + drift),
                control1: CGPoint(x: size.width * 0.30, y: y - 8),
                control2: CGPoint(x: size.width * 0.74, y: y + 9)
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.05)),
                style: StrokeStyle(lineWidth: 0.9)
            )
        }
    }

    private func drawFitness(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let ringCenter = CGPoint(x: size.width * 0.78, y: size.height * 0.24)
        for index in 0..<3 {
            let radius = 18 + CGFloat(index) * 11 + CGFloat(sin(time * 1.1 + Double(index))) * 1.6
            context.stroke(
                Path(ellipseIn: CGRect(x: ringCenter.x - radius, y: ringCenter.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(Color.white.opacity(0.08 - Double(index) * 0.018)),
                style: StrokeStyle(lineWidth: 1)
            )
        }
        for index in 0..<6 {
            let y = size.height * (0.18 + CGFloat(index) * 0.11)
            let amplitude = CGFloat(8 + index * 2)
            var path = Path()
            for step in 0...8 {
                let x = CGFloat(step) / 8 * (size.width + 20) - 10
                let dy = CGFloat(sin(time * 1.1 + Double(step) * 0.8 + Double(index))) * amplitude
                let point = CGPoint(x: x, y: y + dy)
                if step == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.10)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }
    }

    private func drawSocial(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        var tablePath = Path()
        tablePath.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.74))
        tablePath.addCurve(
            to: CGPoint(x: size.width * 0.90, y: size.height * 0.74),
            control1: CGPoint(x: size.width * 0.28, y: size.height * 0.68),
            control2: CGPoint(x: size.width * 0.72, y: size.height * 0.80)
        )
        context.stroke(
            tablePath,
            with: .color(Color.white.opacity(0.08)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )
        for index in 0..<18 {
            let seed = Double(index + 1)
            let x = CGFloat((seed * 0.217).truncatingRemainder(dividingBy: 1)) * size.width
            let y = CGFloat((seed * 0.143).truncatingRemainder(dividingBy: 1)) * size.height
            let pulse = 0.10 + 0.08 * sin(time * 0.9 + seed)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)),
                with: .color(Color.white.opacity(pulse))
            )
        }
        for index in 0..<4 {
            let glow = CGRect(
                x: size.width * (0.12 + CGFloat(index) * 0.18),
                y: size.height * (0.18 + CGFloat(index % 2) * 0.12),
                width: 18 + CGFloat(index) * 6,
                height: 18 + CGFloat(index) * 6
            )
            context.fill(
                Path(ellipseIn: glow),
                with: .color(Color.white.opacity(0.05))
            )
        }
    }

    private func drawPaperFlow(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<8 {
            let y = size.height * (0.12 + CGFloat(index) * 0.10)
            let drift = CGFloat(cos(time * 0.3 + Double(index))) * 6
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addCurve(
                to: CGPoint(x: size.width, y: y + drift),
                control1: CGPoint(x: size.width * 0.28, y: y - 10),
                control2: CGPoint(x: size.width * 0.72, y: y + 10)
            )
            context.stroke(
                path,
                with: .color(Color.white.opacity(0.08)),
                style: StrokeStyle(lineWidth: 1)
            )
        }
    }
}

struct SummaryPlaybackMemberPitch: Equatable {
    let headline: String
    let detail: String
    let cta: String
}

struct WeeklyStoryShareCardTheme {
    let backgroundStart, backgroundMid, backgroundEnd: Color
    let paper, paperEdge, ink, muted: Color
    let accent, accentDeep, softAccent: Color
    let rainAccent, travelAccent, cityAccent: Color

    static let journal = WeeklyStoryShareCardTheme(
        backgroundStart: Color(hex: "dcebe0"),
        backgroundMid: Color(hex: "f6f8ed"),
        backgroundEnd: Color(hex: "fff2df"),
        paper: Color(hex: "fffdf7"),
        paperEdge: Color(hex: "e8f2e9"),
        ink: Color(hex: "1f2528"),
        muted: Color(hex: "78847c"),
        accent: Color(hex: "7fb39f"),
        accentDeep: Color(hex: "486f5d"),
        softAccent: Color(hex: "e8f2e9"),
        rainAccent: Color(hex: "6a8a96"),
        travelAccent: Color(hex: "80985e"),
        cityAccent: Color(hex: "59638d")
    )

    static func appTheme(_ theme: ResolvedThemeTokens) -> WeeklyStoryShareCardTheme {
        WeeklyStoryShareCardTheme(
            backgroundStart: theme.background,
            backgroundMid: theme.surfaceWarm,
            backgroundEnd: theme.backgroundGradientEnd,
            paper: theme.panelStrong,
            paperEdge: theme.surfaceMuted,
            ink: theme.textPrimary,
            muted: theme.textSecondary,
            accent: theme.accent,
            accentDeep: theme.accentDark,
            softAccent: theme.surfaceMuted,
            rainAccent: theme.accentDark,
            travelAccent: theme.accent,
            cityAccent: theme.readableAccent
        )
    }
}

enum WeeklyShareCardTemplateCapability: Equatable {
    case recordSummary
    case singleMemory
    case weeklyCollage
}

enum WeeklyShareCardTemplateCapabilityPolicy {
    static func recommended(photoCount: Int) -> WeeklyShareCardTemplateCapability {
        switch max(0, photoCount) {
        case 0: return .recordSummary
        case 1: return .singleMemory
        default: return .weeklyCollage
        }
    }

    static func allowed(photoCount: Int) -> [WeeklyShareCardTemplateCapability] {
        switch max(0, photoCount) {
        case 0:
            return [.recordSummary]
        case 1:
            return [.singleMemory, .recordSummary]
        default:
            return [.weeklyCollage, .singleMemory, .recordSummary]
        }
    }
}

private enum LifeSliceShareCardStyle: String, CaseIterable, Identifiable {
    case warmLight
    case magazine
    case appleMemories
    case journal
    case filmStory
    case collageStory
    case cleanTexture
    case fullPhoto
    case customBackground

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmLight: return "单图记忆"
        case .magazine: return "杂志版面"
        case .appleMemories: return "记忆卡片"
        case .journal: return "手账留白"
        case .filmStory: return "胶片故事"
        case .collageStory: return "周记拼页"
        case .cleanTexture: return "记录摘要"
        case .fullPhoto: return "沉浸照片"
        case .customBackground: return "自定义背景"
        }
    }

    var subtitle: String {
        switch self {
        case .warmLight: return "一张照片和对应记录"
        case .magazine: return "杂志排版"
        case .appleMemories: return "记忆卡片"
        case .journal: return "手账留白"
        case .filmStory: return "胶片质感"
        case .collageStory: return "两到三张照片组成一页"
        case .cleanTexture: return "没有照片也能完整回看"
        case .fullPhoto: return "沉浸照片"
        case .customBackground: return "本地相册"
        }
    }

    var icon: String {
        switch self {
        case .warmLight: return "photo.fill"
        case .magazine: return "rectangle.split.2x2"
        case .appleMemories: return "sparkles"
        case .journal: return "book.closed"
        case .filmStory: return "film"
        case .collageStory: return "photo.on.rectangle.angled"
        case .cleanTexture: return "rectangle.split.3x1"
        case .fullPhoto: return "mountain.2.fill"
        case .customBackground: return "plus"
        }
    }

    static func presetCases(photoCount: Int) -> [LifeSliceShareCardStyle] {
        WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: photoCount).map { style(for: $0) }
    }

    func next(in styles: [LifeSliceShareCardStyle]) -> LifeSliceShareCardStyle {
        guard !styles.isEmpty else { return .cleanTexture }
        guard let index = styles.firstIndex(of: self) else { return styles[0] }
        return styles[(index + 1) % styles.count]
    }

    static func recommended(memoryAnchors: [SummaryMemoryAnchor]) -> LifeSliceShareCardStyle {
        style(for: WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: memoryAnchors.count))
    }

    private static func style(
        for capability: WeeklyShareCardTemplateCapability
    ) -> LifeSliceShareCardStyle {
        switch capability {
        case .recordSummary: return .cleanTexture
        case .singleMemory: return .warmLight
        case .weeklyCollage: return .collageStory
        }
    }
}

struct SummaryPlaybackSheet: View {
    private static let doneActionsPeekAnchorID = "summaryPlaybackDoneActionsPeekAnchor"

    let playback: SummaryPlayback
    let petEnabled: Bool
    let isMember: Bool
    var memberPitch: SummaryPlaybackMemberPitch?
    var weeklySharePayload: WeeklyShareCardPayload?
    var shareNickname: String = "叙账用户"
    var shareCardTheme: WeeklyStoryShareCardTheme = .journal
    var onCompleted: (Double) -> Void
    var onShowMemberPricing: (() -> Void)? = nil
    var onOpenWeekly: (() -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil
    var onSaveMemoryLine: ((String, SummaryPlaybackRange) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeIndex = 0
    @State private var isPlaying = true
    @State private var playbackDone = false
    @State private var completionReported = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var isSavingShareCard = false
    @State private var isPreparingShareCard = false
    @State private var preparedShareCardPhotos: PreparedWeeklyShareCardPhotoSet?
    @State private var shareCardSaveTask: Task<Void, Never>?
    @State private var shareSaveMessage: String?
    @State private var memorySaveMessage: String?
    @State private var showShareCardPrivacyConfirm = false
    @State private var isShareStylePickerExpanded = false
    @State private var selectedShareCardStyle: LifeSliceShareCardStyle?
    @State private var customShareBackgroundItem: PhotosPickerItem?
    @State private var customShareBackgroundData: Data?
    @State private var customShareBackgroundImage: UIImage?

    private var currentChapter: SummaryChapter? {
        guard !playback.chapters.isEmpty else { return nil }
        return playback.chapters[min(activeIndex, playback.chapters.count - 1)]
    }

    private var currentShareCardStyle: LifeSliceShareCardStyle {
        guard let selectedShareCardStyle else { return recommendedShareCardStyle }
        if selectedShareCardStyle == .customBackground, customShareBackgroundImage != nil {
            return .customBackground
        }
        return shareCardPresetStyles.contains(selectedShareCardStyle)
            ? selectedShareCardStyle
            : recommendedShareCardStyle
    }

    private var recommendedShareCardStyle: LifeSliceShareCardStyle {
        LifeSliceShareCardStyle.recommended(memoryAnchors: shareCardStyleAnchors)
    }

    private var shareCardStyleAnchors: [SummaryMemoryAnchor] {
        if let preparedShareCardPhotos,
           preparedShareCardPhotos.sourceKey == shareCardPhotoPreparationKey {
            return preparedShareCardPhotos.availableAnchors
        }
        return Array(playback.memoryAnchors.prefix(WeeklyShareCardPhotoPreparationPolicy.maximumPhotoCount))
    }

    private var shareCardPresetStyles: [LifeSliceShareCardStyle] {
        LifeSliceShareCardStyle.presetCases(photoCount: shareCardStyleAnchors.count)
    }

    private var nextShareCardStyle: LifeSliceShareCardStyle {
        currentShareCardStyle.next(in: shareCardPresetStyles)
    }

    private var progressFraction: Double {
        guard !playback.chapters.isEmpty else { return 0 }
        if playbackDone { return 1 }
        return Double(activeIndex + 1) / Double(playback.chapters.count)
    }

    var body: some View {
        ZStack {
            backgroundGradient
                .id(currentChapter?.id ?? "empty")
                .transition(.opacity)
                .ignoresSafeArea()

            ambientBackgroundLights
                .ignoresSafeArea()
                .transition(.opacity)

            StoryDynamicBackdrop(profile: backdropProfile, opacity: 0.9)
                .ignoresSafeArea()
                .transition(.opacity)

            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        Capsule()
                            .fill(Color.white.opacity(0.58))
                            .frame(width: 42, height: 5)
                            .padding(.top, 10)

                        header

                        chapterStage

                        memoryAnchorGallery

                        controls

                        if playbackDone {
                            doneActions
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .onChange(of: playbackDone) { _, done in
                    guard done else { return }
                    if reduceMotion {
                        scrollProxy.scrollTo(Self.doneActionsPeekAnchorID, anchor: UnitPoint(x: 0.5, y: 0.72))
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            withAnimation(.spring(response: 0.44, dampingFraction: 0.90)) {
                                scrollProxy.scrollTo(Self.doneActionsPeekAnchorID, anchor: UnitPoint(x: 0.5, y: 0.72))
                            }
                        }
                    }
                }
            }

            if showShareCardPrivacyConfirm {
                shareCardPrivacyOverlay
                    .transition(.opacity)
                    .zIndex(20)
            }

            if let memorySaveMessage {
                playbackStatusToast(memorySaveMessage)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(12)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: currentChapter?.id)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: memorySaveMessage)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88), value: showShareCardPrivacyConfirm)
        .onAppear {
            startPlayback()
        }
        .onChange(of: isPlaying) { _, newValue in
            newValue ? startPlayback() : playbackTask?.cancel()
        }
        .onDisappear {
            reportCompletionIfNeeded(progress: progressFraction)
            playbackTask?.cancel()
            shareCardSaveTask?.cancel()
            shareCardSaveTask = nil
            preparedShareCardPhotos = nil
            isPreparingShareCard = false
        }
    }

    private var backgroundGradient: LinearGradient {
        let palette = chapterPalette(for: currentChapter, profile: backdropProfile)
        return LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var ambientBackgroundLights: some View {
        ZStack {
            Circle()
                .fill(backdropHighlightColor.opacity(0.24))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: 130, y: -180)

            Circle()
                .fill(Color.white.opacity(0.26))
                .frame(width: 240, height: 240)
                .blur(radius: 46)
                .offset(x: -140, y: 210)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(backdropHighlightColor.opacity(0.10))
                .frame(width: 220, height: 78)
                .blur(radius: 26)
                .rotationEffect(.degrees(-14))
                .offset(x: -88, y: -28)
        }
        .allowsHitTesting(false)
    }

    private var backdropProfile: LifeStoryVisualProfile {
        LifeStorySignalService.visualProfile(
            chapter: currentChapter,
            playback: playback,
            memoryLine: playbackMemoryLine
        )
    }

    private var shareCardPrivacyOverlay: some View {
        ZStack {
            Color(red: 28/255, green: 36/255, blue: 42/255)
                .opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isSavingShareCard else { return }
                    showShareCardPrivacyConfirm = false
                    isShareStylePickerExpanded = false
                }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.92))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(AppColors.accent.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 7) {
                        Text("保存本周故事图")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.text)

                        Text("故事图可能有昵称、金额区间和你写下的回望。保存后先看一眼内容，再发给别人。")
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .foregroundStyle(AppColors.subtext.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                shareCardPreviewPanel

                HStack(spacing: 12) {
                    Button {
                        showShareCardPrivacyConfirm = false
                        isShareStylePickerExpanded = false
                    } label: {
                        Text("先不保存")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .themedInteractionSurface(
                                radius: 14,
                                tint: AppColors.accent,
                                glowIntensity: 0.42
                            )
                    }
                    .buttonStyle(PurposefulCardButtonStyle())
                    .disabled(isSavingShareCard)

                    Button {
                        guard let renderInput = currentPreparedShareCardRenderInput else { return }
                        isShareStylePickerExpanded = false
                        saveWeeklyStoryCard(renderInput)
                    } label: {
                        HStack(spacing: 8) {
                            if isPreparingShareCard || isSavingShareCard {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "photo.badge.checkmark")
                            }
                            Text(shareCardPrimaryActionTitle)
                        }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.92), AppColors.accentDark.opacity(0.90)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(PurposefulCardButtonStyle())
                    .disabled(!isShareCardReadyToSave)
                    .opacity(isShareCardReadyToSave ? 1 : 0.62)
                }
            }
            .padding(22)
            .frame(maxWidth: 370)
            .background(shareCardPrivacyCardBackground)
            .overlay(shareCardPrivacyCardBorder)
            .shadow(color: Color(red: 47/255, green: 67/255, blue: 58/255).opacity(0.18), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 24)
        }
        .task(id: shareCardPhotoPreparationKey) {
            await prepareShareCardPhotos(for: shareCardPhotoPreparationKey)
        }
        .onDisappear {
            guard !isSavingShareCard else { return }
            preparedShareCardPhotos = nil
            isPreparingShareCard = false
        }
    }

    private var shareCardPrivacyCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        AppColors.paperWarm.opacity(0.72),
                        AppColors.paperMist.opacity(0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            )
    }

    private var shareCardPrivacyCardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.82),
                        AppColors.accent.opacity(0.16),
                        AppColors.paperBorder.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: playback.range == .week ? "calendar.badge.clock" : "calendar")
                        .font(.system(size: 12, weight: .bold))
                    Text(playback.range == .week ? "周记" : "月章")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(AppColors.accentDark.opacity(0.82))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.54)))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.46), lineWidth: 0.8)
                )

                Text(playback.title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(playback.teaserLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.subtext)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭回放")
        }
        .padding(.top, 4)
    }

    private var chapterStage: some View {
        ZStack(alignment: .topTrailing) {
            if let chapter = currentChapter {
                chapterFilmRails
                chapterStageSymbol(chapter)
                chapterStageContent(chapter)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .topLeading)
        .themedInteractionSurface(
            radius: 28,
            tint: chapterAccent(for: currentChapter),
            isSelected: isPlaying || playbackDone,
            glowIntensity: 0.78
        )
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    handleChapterSwipe(value.translation.width)
                }
        )
        .animation(.easeInOut(duration: 0.22), value: activeIndex)
    }

    private var chapterFilmRails: some View {
        VStack {
            filmRail
            Spacer()
            filmRail
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .allowsHitTesting(false)
    }

    private var filmRail: some View {
        HStack(spacing: 7) {
            ForEach(0..<10, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.40))
                    .frame(width: 12, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chapterStageSymbol(_ chapter: SummaryChapter) -> some View {
        Image(systemName: chapterSymbol(for: chapter))
            .font(.system(size: 112, weight: .bold))
            .foregroundStyle(chapterAccent(for: chapter).opacity(0.08))
            .offset(x: 18, y: -20)
            .allowsHitTesting(false)
    }

    private func chapterStageContent(_ chapter: SummaryChapter) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            chapterTopLine(chapter)
            chapterRangeLabel(chapter)
            chapterNarration(chapter)
            chapterSupportView(for: chapter)
            chapterElementStrip(for: chapter)
        }
        .id(chapter.id)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private func chapterTopLine(_ chapter: SummaryChapter) -> some View {
        HStack(alignment: .center, spacing: 10) {
            chapterTitle(chapter)
            Spacer(minLength: 8)
            Text("\(min(activeIndex + 1, playback.chapters.count))/\(playback.chapters.count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(chapterAccent(for: chapter))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.48)))
        }
    }

    private func chapterTitle(_ chapter: SummaryChapter) -> some View {
        Text(chapter.title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(chapterAccent(for: chapter))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chapterRangeLabel(_ chapter: SummaryChapter) -> some View {
        if shouldShowRangeLabel(for: chapter), let range = chapter.metrics["range"] {
            Text(range)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext)
        }
    }

    private func chapterNarration(_ chapter: SummaryChapter) -> some View {
        Text(petEnabled ? chapter.narration.warm : chapter.narration.plain)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.text)
            .lineSpacing(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
    }

    @ViewBuilder
    private func chapterSupportView(for chapter: SummaryChapter) -> some View {
        if let text = supportLineText(for: chapter) {
            supportHint(text)
        } else {
            softChapterHint(chapter)
        }
    }

    @ViewBuilder
    private func softChapterHint(_ chapter: SummaryChapter) -> some View {
        if let text = softHintText(for: chapter) {
            supportHint(text)
        } else {
            EmptyView()
        }
    }

    private func supportHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.subtext)
            .lineLimit(3)
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.44))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
            )
    }

    @ViewBuilder
    private func chapterElementStrip(for chapter: SummaryChapter) -> some View {
        let chips = chapterElementChips(for: chapter)
        if !chips.isEmpty {
            HStack(spacing: 7) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    HStack(spacing: 5) {
                        Image(systemName: chip.symbol)
                            .font(.system(size: 10, weight: .bold))
                        Text(chip.text)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .foregroundStyle(chapterAccent(for: chapter).opacity(0.86))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.44))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(chapterAccent(for: chapter).opacity(0.10), lineWidth: 0.8)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chapterElementChips(for chapter: SummaryChapter) -> [(symbol: String, text: String)] {
        if chapter.metrics.keys.contains("supportLine") {
            return []
        }
        return LifeStorySignalService.chapterSignals(from: chapter)
            .map { (symbol: $0.symbol, text: $0.label) }
    }

    @ViewBuilder
    private var memoryAnchorGallery: some View {
        if !playback.memoryAnchors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(playback.range == .week ? "这一周的照片" : "这个月的照片")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(playback.memoryAnchors.count) 张")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.subtext)
                }
                .padding(.horizontal, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(playback.memoryAnchors) { anchor in
                            memoryAnchorCard(anchor)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.48))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.48), lineWidth: 0.8)
            )
        }
    }

    private func memoryAnchorCard(_ anchor: SummaryMemoryAnchor) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                MemoryAttachmentThumbnail(
                    imageData: anchor.imageData,
                    imageReference: anchor.imageReference,
                    height: 132,
                    cornerRadius: 18
                )
                .frame(width: 206)

                Text(anchor.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color.black.opacity(0.28)))
                    .padding(10)
            }
            .shadow(color: AppColors.subtext.opacity(0.12), radius: 12, x: 0, y: 8)

            Text(lifeSliceResolvedPhotoCaption(for: anchor))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(anchor.createdAt.zhBillDateOnly)
                Text("·")
                Text(anchor.amount.formatted(.cny))
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.subtext)
            .lineLimit(1)
        }
        .frame(width: 206, alignment: .leading)
    }

/*
    private func supportLineText(for chapter: SummaryChapter) -> String? {
        if hasNoSupportLine(chapter) {
            return nil
        }
        if isScentChapter(chapter),
           let lifeMarkLine = chapter.metrics["lifeMarkLine"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lifeMarkLine.isEmpty {
            return "照护印记：\(lifeMarkLine)"
        }
        if let scene = chapter.metrics["sceneMemoryLine"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !scene.isEmpty {
            return "这一格最具体：\(scene)"
        }
        if isVoiceChapter(chapter), let title = voiceTitle(for: chapter) {
            if let day = chapter.metrics["day"], !day.isEmpty {
                return "\(day) 记录了「\(title)」"
            }
            return "这一句记录下来：\(title)"
        }
        if isScentChapter(chapter), let words = chapter.metrics["scentWords"] {
            let cleaned = words
                .split(separator: "、")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "、")
            return cleaned.isEmpty ? nil : "这一段反复出现：\(cleaned)"
        }
        if isPresenceChapter(chapter) {
            if let lifeMarkLine = chapter.metrics["lifeMarkLine"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !lifeMarkLine.isEmpty {
                return "生活线索：\(lifeMarkLine)"
            }
            let count = chapter.metrics["count"] ?? "\(playback.count)"
            let total = chapter.metrics["total"] ?? playback.total.formatted(.cny)
            return "\(playback.rangeLabel) · \(count) 笔 · \(total)"
        }
        if isCategoryChapter(chapter) {
            let category = chapter.metrics["category"] ?? "生活"
            return "生活主料：\(category)"
        }
        if isHighlightChapter(chapter), let title = chapter.metrics["title"]?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if let day = chapter.metrics["day"], !day.isEmpty {
                return "\(day) 记成了「\(title)」"
            }
            return "这一格记成了「\(title)」"
        }
        return nil
    }

    private func softHintText(for chapter: SummaryChapter) -> String? {
        if isIntroChapter(chapter) {
            return chapter.metrics["range"] ?? playback.rangeLabel
        }
        if isRhythmChapter(chapter), let busiest = chapter.metrics["busiestDay"] {
            return "\(busiest) 更热闹一点"
        }
        if let middle = chapter.metrics["middle"], let late = chapter.metrics["late"], let leading = chapter.metrics["leading"] {
            if middle == late {
                return "中旬和下旬差不多安静"
            }
            return "\(leading) 更热闹一点"
        }
        return nil
    }

*/

    private func supportLineText(for chapter: SummaryChapter) -> String? {
        if hasNoSupportLine(chapter) {
            return nil
        }
        if chapter.metrics.keys.contains("supportLine") {
            let support = chapter.metrics["supportLine"]?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !support.isEmpty else { return nil }
            let narration = petEnabled ? chapter.narration.warm : chapter.narration.plain
            let normalizedSupport = normalizedPlaybackCopy(support)
            let normalizedNarration = normalizedPlaybackCopy(narration)
            guard !normalizedSupport.isEmpty,
                  normalizedSupport != normalizedNarration,
                  !normalizedNarration.contains(normalizedSupport) else {
                return nil
            }
            return support
        }
        if let scene = chapter.metrics["sceneMemoryLine"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !scene.isEmpty {
            return "这一格最具体：\(scene)"
        }
        if isVoiceChapter(chapter), let title = voiceTitle(for: chapter) {
            if let day = chapter.metrics["day"], !day.isEmpty {
                return "\(day) 记录了「\(title)」"
            }
            return "这一句记录下来：\(title)"
        }
        if isScentChapter(chapter), let words = chapter.metrics["scentWords"] {
            let cleaned = words
                .split(separator: "、")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "、")
            return cleaned.isEmpty ? nil : "这一段反复出现：\(cleaned)"
        }
        if isPresenceChapter(chapter) {
            if let lifeMarkLine = chapter.metrics["lifeMarkLine"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !lifeMarkLine.isEmpty {
                return "生活线索：\(lifeMarkLine)"
            }
            let count = chapter.metrics["count"] ?? "\(playback.count)"
            let total = chapter.metrics["total"] ?? playback.total.formatted(.cny)
            return "\(playback.rangeLabel) · \(count) 笔 · \(total)"
        }
        if isCategoryChapter(chapter) {
            let category = chapter.metrics["category"] ?? "生活"
            return "生活主线：\(category)"
        }
        if isHighlightChapter(chapter), let title = chapter.metrics["title"]?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if let day = chapter.metrics["day"], !day.isEmpty {
                return "\(day) 记成了「\(title)」"
            }
            return "这一格记成了「\(title)」"
        }
        return nil
    }

    private func softHintText(for chapter: SummaryChapter) -> String? {
        if chapter.metrics.keys.contains("supportLine") {
            return nil
        }
        if isIntroChapter(chapter) {
            return chapter.metrics["range"] ?? playback.rangeLabel
        }
        if isRhythmChapter(chapter), let busiest = chapter.metrics["busiestDay"] {
            return "\(busiest) 更热闹一点"
        }
        if let middle = chapter.metrics["middle"], let late = chapter.metrics["late"], let leading = chapter.metrics["leading"] {
            if middle == late {
                return "中段和后段的节奏差不多平稳"
            }
            return "\(leading) 更热闹一点"
        }
        return nil
    }

    private func normalizedPlaybackCopy(_ text: String) -> String {
        text
            .lowercased()
            .filter { character in
                !character.isWhitespace && !"，。；：、·/「」『』（）()".contains(character)
            }
    }

    private func shouldShowRangeLabel(for chapter: SummaryChapter) -> Bool {
        chapter.id == "week-intro" || chapter.id == "week-presence" || chapter.id == "month-opening"
    }

    private func isIntroChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("intro") || isPresenceChapter(chapter)
    }

    private func isRhythmChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("rhythm")
    }

    private func isCategoryChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("category")
    }

    private func isHighlightChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("highlight")
    }

    private func isVoiceChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id == "week-voices"
            || chapter.id == "month-early-voice"
            || chapter.id == "month-late-voice"
    }

    private func isScentChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id == "week-scent" || chapter.id == "month-scent"
    }

    private func isPresenceChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id == "week-presence" || chapter.id == "month-opening"
    }

    private func isOutroChapter(_ chapter: SummaryChapter) -> Bool {
        chapter.id.contains("outro")
    }

    private func hasNoSupportLine(_ chapter: SummaryChapter) -> Bool {
        isOutroChapter(chapter)
    }

    private func voiceTitle(for chapter: SummaryChapter) -> String? {
        ["voiceTitle1", "earlyVoiceTitle", "lateVoiceTitle", "title"]
            .compactMap { chapter.metrics[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func chapterAccent(for chapter: SummaryChapter?) -> Color {
        guard let chapter else { return AppColors.accent }
        if isScentChapter(chapter) || isCategoryChapter(chapter) { return AppColors.accentDark }
        if isRhythmChapter(chapter) { return Color(red: 0.22, green: 0.50, blue: 0.58) }
        if isVoiceChapter(chapter) || isHighlightChapter(chapter) { return Color(red: 0.70, green: 0.36, blue: 0.28) }
        if isOutroChapter(chapter) { return Color(red: 0.42, green: 0.46, blue: 0.64) }
        return AppColors.accent
    }

    private func chapterSymbol(for chapter: SummaryChapter) -> String {
        if isScentChapter(chapter) { return "text.quote" }
        if isCategoryChapter(chapter) { return "chart.pie.fill" }
        if isRhythmChapter(chapter) { return "waveform.path.ecg" }
        if isVoiceChapter(chapter) || isHighlightChapter(chapter) { return "quote.bubble.fill" }
        if isOutroChapter(chapter) { return "sparkles" }
        return "calendar"
    }

    private func chapterPalette(for chapter: SummaryChapter?, profile: LifeStoryVisualProfile) -> [Color] {
        let warmBase: [Color]
        let coolBase: [Color]
        if profile == .rain {
            warmBase = [Color(red: 0.76, green: 0.83, blue: 0.88), Color(red: 0.88, green: 0.92, blue: 0.95), AppColors.bg]
            coolBase = [Color(red: 0.71, green: 0.77, blue: 0.84), Color(red: 0.84, green: 0.89, blue: 0.93), AppColors.bg]
        } else if profile == .travel {
            warmBase = [Color(red: 0.89, green: 0.95, blue: 0.86), Color(red: 0.99, green: 0.93, blue: 0.80), AppColors.bg]
            coolBase = [Color(red: 0.83, green: 0.90, blue: 0.86), Color(red: 0.93, green: 0.95, blue: 0.88), AppColors.bg]
        } else if profile == .lateCity {
            warmBase = [Color(red: 0.84, green: 0.86, blue: 0.96), Color(red: 0.90, green: 0.91, blue: 0.98), AppColors.bg]
            coolBase = [Color(red: 0.75, green: 0.78, blue: 0.90), Color(red: 0.87, green: 0.89, blue: 0.96), AppColors.bg]
        } else if profile == .warmDaily {
            warmBase = [Color(red: 0.99, green: 0.92, blue: 0.84), Color(red: 0.94, green: 0.96, blue: 0.88), AppColors.bg]
            coolBase = [Color(red: 0.95, green: 0.91, blue: 0.86), Color(red: 0.97, green: 0.95, blue: 0.90), AppColors.bg]
        } else if profile == .fitness {
            warmBase = [Color(red: 0.84, green: 0.95, blue: 0.87), Color(red: 0.92, green: 0.98, blue: 0.93), AppColors.bg]
            coolBase = [Color(red: 0.80, green: 0.91, blue: 0.86), Color(red: 0.90, green: 0.96, blue: 0.92), AppColors.bg]
        } else if profile == .social {
            warmBase = [Color(red: 0.99, green: 0.89, blue: 0.80), Color(red: 0.98, green: 0.93, blue: 0.86), AppColors.bg]
            coolBase = [Color(red: 0.95, green: 0.86, blue: 0.81), Color(red: 0.97, green: 0.92, blue: 0.87), AppColors.bg]
        } else if let chapter, isRhythmChapter(chapter) {
            warmBase = [Color(red: 0.88, green: 0.97, blue: 0.96), Color(red: 1.00, green: 0.93, blue: 0.86), AppColors.bg]
            coolBase = [Color(red: 0.86, green: 0.93, blue: 0.96), Color(red: 0.94, green: 0.97, blue: 0.98), AppColors.bg]
        } else if let chapter, isScentChapter(chapter) || isCategoryChapter(chapter) {
            warmBase = [Color(red: 1.00, green: 0.94, blue: 0.84), Color(red: 0.92, green: 0.97, blue: 0.90), AppColors.bg]
            coolBase = [Color(red: 0.91, green: 0.94, blue: 0.89), Color(red: 0.95, green: 0.97, blue: 0.94), AppColors.bg]
        } else if let chapter, isVoiceChapter(chapter) || isHighlightChapter(chapter) {
            warmBase = [Color(red: 1.00, green: 0.90, blue: 0.86), Color(red: 1.00, green: 0.95, blue: 0.88), AppColors.bg]
            coolBase = [Color(red: 0.93, green: 0.90, blue: 0.88), Color(red: 0.97, green: 0.95, blue: 0.93), AppColors.bg]
        } else if let chapter, isOutroChapter(chapter) {
            warmBase = [Color(red: 0.97, green: 0.90, blue: 0.98), Color(red: 0.91, green: 0.96, blue: 0.98), AppColors.bg]
            coolBase = [Color(red: 0.89, green: 0.91, blue: 0.96), Color(red: 0.95, green: 0.96, blue: 0.98), AppColors.bg]
        } else {
            warmBase = [AppColors.heroGradientPink.opacity(0.34), AppColors.heroGradientTeal.opacity(0.38), AppColors.bg]
            coolBase = [Color(red: 0.86, green: 0.90, blue: 0.95), Color(red: 0.94, green: 0.96, blue: 0.98), AppColors.bg]
        }
        return petEnabled ? warmBase : coolBase
    }

    private var backdropHighlightColor: Color {
        switch backdropProfile {
        case .rain:
            return Color(red: 0.50, green: 0.63, blue: 0.73)
        case .travel:
            return Color(red: 0.70, green: 0.75, blue: 0.48)
        case .lateCity:
            return Color(red: 0.55, green: 0.56, blue: 0.80)
        case .warmDaily:
            return Color(red: 0.88, green: 0.66, blue: 0.44)
        case .fitness:
            return Color(red: 0.43, green: 0.72, blue: 0.57)
        case .social:
            return Color(red: 0.87, green: 0.59, blue: 0.44)
        case .defaultSoft:
            return AppColors.accent
        }
    }

/*
    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: playbackDone ? "sparkles" : (isPlaying ? "play.fill" : "pause.fill"))
                    .font(.system(size: 10, weight: .bold))
                Text(playbackDone ? "这一段已经收好" : (isPlaying ? "自动播放中" : "停在这一格"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(min(activeIndex + 1, max(playback.chapters.count, 1)))/\(max(playback.chapters.count, 1))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(AppColors.subtext.opacity(0.82))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.54))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [chapterAccent(for: currentChapter), backdropHighlightColor.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(progressFraction)))
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                ForEach(playback.chapters.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(index <= activeIndex ? chapterAccent(for: currentChapter) : Color.white.opacity(0.54))
                        .frame(width: index == activeIndex ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: activeIndex)
                }
                Spacer()
                Button {
                    restartPlayback()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.64), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("重新播放")

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppColors.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
            }
            .foregroundStyle(AppColors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.44))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private var doneActions: some View {
        VStack(spacing: 10) {
            Text(doneHeadline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail = doneDetail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if playback.range == .week {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton

                Button {
                    isShareStylePickerExpanded = false
                    showShareCardPrivacyConfirm = true
                } label: {
                    Label("保存本周故事图", systemImage: "square.and.arrow.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(weeklySharePayload == nil || isSavingShareCard ? AppColors.subtext.opacity(0.64) : AppColors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .themedInteractionSurface(
                            radius: 16,
                            tint: AppColors.accent,
                            isSelected: weeklySharePayload != nil && !isSavingShareCard,
                            isDisabled: weeklySharePayload == nil || isSavingShareCard,
                            glowIntensity: 0.58
                        )
                }
                .buttonStyle(PurposefulCardButtonStyle())
                .disabled(weeklySharePayload == nil || isSavingShareCard)

                if let shareSaveMessage {
                    Text(shareSaveMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    if let onOpenInsight {
                        onOpenInsight()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("继续问")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())
            } else {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton
            }

            if playback.range == .month {
                Button {
                    if let onOpenWeekly {
                        onOpenWeekly()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("先看本周")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .themedInteractionSurface(radius: 16, tint: AppColors.accent, glowIntensity: 0.48)
                }
                .buttonStyle(PurposefulCardButtonStyle())
            }

        }
    }

    @ViewBuilder
    private var memoryLineButton: some View {
        if let line = playbackMemoryLine, onSaveMemoryLine != nil {
            Button {
                onSaveMemoryLine?(line, playback.range)
                showMemorySaveMessage("已放到首页「最近的生活」。")
            } label: {
                Text("留下这一句到首页")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .themedInteractionSurface(radius: 16, tint: AppColors.accent, glowIntensity: 0.48)
            }
            .buttonStyle(PurposefulCardButtonStyle())
        }
    }


*/

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: playbackDone ? "sparkles" : (isPlaying ? "play.fill" : "pause.fill"))
                    .font(.system(size: 10, weight: .bold))
                Text(playbackDone ? "这一段已经收好了" : (isPlaying ? "自动播放中" : "停在这一格"))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(min(activeIndex + 1, max(playback.chapters.count, 1)))/\(max(playback.chapters.count, 1))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(AppColors.subtext.opacity(0.82))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.54))
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [chapterAccent(for: currentChapter), backdropHighlightColor.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(progressFraction)))
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                ForEach(playback.chapters.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(index <= activeIndex ? chapterAccent(for: currentChapter) : Color.white.opacity(0.54))
                        .frame(width: index == activeIndex ? 20 : 8, height: 8)
                        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: activeIndex)
                }
                Spacer()
                Button {
                    restartPlayback()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.64), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("重新播放")

                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppColors.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "暂停" : "播放")
            }
            .foregroundStyle(AppColors.text)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.44))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private var doneActions: some View {
        VStack(spacing: 10) {
            Text(doneHeadline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail = doneDetail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Color.clear
                .frame(height: 1)
                .id(Self.doneActionsPeekAnchorID)

            if playback.range == .week {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton

                Button {
                    isShareStylePickerExpanded = false
                    showShareCardPrivacyConfirm = true
                } label: {
                    Label("保存本周故事图", systemImage: "square.and.arrow.down")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(weeklySharePayload == nil || isSavingShareCard ? AppColors.subtext.opacity(0.64) : AppColors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .themedInteractionSurface(
                            radius: 16,
                            tint: AppColors.accent,
                            isSelected: weeklySharePayload != nil && !isSavingShareCard,
                            isDisabled: weeklySharePayload == nil || isSavingShareCard,
                            glowIntensity: 0.58
                        )
                }
                .buttonStyle(PurposefulCardButtonStyle())
                .disabled(weeklySharePayload == nil || isSavingShareCard)

                if let shareSaveMessage {
                    Text(shareSaveMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                reviewContinuationButton
            } else {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton

                reviewContinuationButton
            }

            if playback.range == .month {
                Button {
                    if let onOpenWeekly {
                        onOpenWeekly()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("先看本周")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            memberContinuationButton
        }
    }

    @ViewBuilder
    private var reviewContinuationButton: some View {
        if let onOpenInsight {
            Button {
                onOpenInsight()
            } label: {
                Text("继续问")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PurposefulCardButtonStyle())
            .accessibilityHint("进入复盘查记录、做对比或补遗漏")
        }
    }

    @ViewBuilder
    private var memberContinuationButton: some View {
        if PlaybackCompletionPolicy.showsMemberContinuation(
            isMember: isMember,
            hasMemberPitch: memberPitch != nil
        ), let memberPitch, let onShowMemberPricing {
            Button {
                onShowMemberPricing()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                    Text(memberPitch.cta)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accentDark.opacity(0.88))
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .accessibilityHint(memberPitch.detail)
        }
    }

    @ViewBuilder
    private var memoryLineButton: some View {
        if let line = playbackMemoryLine, onSaveMemoryLine != nil {
            Button {
                onSaveMemoryLine?(line, playback.range)
                showMemorySaveMessage("已放到首页「最近的生活」。")
            } label: {
                Text("留下这一句到首页")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var shareCardPreviewPanel: some View {
        if weeklySharePayload != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    Group {
                        if let renderInput = currentPreparedShareCardRenderInput {
                            WeeklyStoryShareCardView(renderInput: renderInput)
                                .scaleEffect(0.18, anchor: .topLeading)
                        } else {
                            shareCardPreparationPreview
                        }
                    }
                    .frame(width: 97, height: 173, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.70), lineWidth: 1)
                    )
                    .shadow(color: AppColors.text.opacity(0.10), radius: 16, x: 0, y: 10)

                    VStack(alignment: .leading, spacing: 12) {
                        shareCardPreviewFeature(
                            icon: currentShareCardStyle == .customBackground ? "photo.on.rectangle.angled" : currentShareCardStyle.icon,
                            title: selectedShareCardStyle == nil ? "自动生成" : "手动样式",
                            detail: currentShareCardStyle.title
                        )
                        shareCardPreviewFeature(icon: "shield.checkered", title: "保护隐私", detail: "不展示金额和敏感信息")
                        shareCardPreviewFeature(icon: "square.and.arrow.down", title: "一键保存", detail: "保存后再决定分享")
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedShareCardStyle = nextShareCardStyle
                            isShareStylePickerExpanded = false
                        }
                    } label: {
                        Label("换一版", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.accentDark.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(shareCardPresetStyles.count <= 1)
                    .opacity(shareCardPresetStyles.count <= 1 ? 0.52 : 1)

                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            isShareStylePickerExpanded.toggle()
                        }
                    } label: {
                        Label(isShareStylePickerExpanded ? "收起" : "手动换", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.text.opacity(0.86))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if isShareStylePickerExpanded {
                    shareCardStylePicker
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let preparationNotice = shareCardPreparationNotice {
                    Label(preparationNotice, systemImage: "photo.badge.exclamationmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let shareSaveMessage, !shareSaveMessage.isEmpty {
                    Text(shareSaveMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.54), lineWidth: 0.8)
            )
            .allowsHitTesting(!isSavingShareCard)
        }
    }

    private func shareCardPreviewFeature(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.accentDark.opacity(0.88))
                .frame(width: 27, height: 27)
                .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    @ViewBuilder
    private var shareCardStylePicker: some View {
        if weeklySharePayload != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("更多样式")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.text.opacity(0.86))
                    Spacer()
                    if selectedShareCardStyle != nil {
                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                                selectedShareCardStyle = nil
                            }
                        } label: {
                            Label("自动", systemImage: "wand.and.stars")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.accentDark.opacity(0.88))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedShareCardStyle = nextShareCardStyle
                        }
                    } label: {
                        Label("换一换", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.accentDark.opacity(0.88))
                    }
                    .buttonStyle(.plain)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(shareCardPresetStyles) { style in
                            shareCardStyleChip(style)
                                .frame(width: 116)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollIndicators(.hidden)

                customShareBackgroundCard
            }
            .padding(12)
            .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.52), lineWidth: 0.8)
            )
        }
    }

    private func shareCardStyleChip(_ style: LifeSliceShareCardStyle) -> some View {
        let isSelected = currentShareCardStyle == style
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                selectedShareCardStyle = style
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: style.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : AppColors.accentDark.opacity(0.86))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : AppColors.accent.opacity(0.12))
                    )
                Text(style.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.text.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(style.subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? AppColors.accent.opacity(0.13) : Color.white.opacity(0.56))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.62) : Color.white.opacity(0.46), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customShareBackgroundCard: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(
                selection: $customShareBackgroundItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack(alignment: .leading) {
                    if let image = customShareBackgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 86)
                            .clipped()
                            .overlay(Color.black.opacity(0.28))
                    } else {
                        LinearGradient(
                            colors: [
                                AppColors.accent.opacity(0.13),
                                Color.white.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(customShareBackgroundData == nil ? 0.72 : 0.92))
                                .frame(width: 42, height: 42)
                            Image(systemName: customShareBackgroundData == nil ? "plus" : "photo.on.rectangle.angled")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppColors.accentDark.opacity(0.90))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(customShareBackgroundData == nil ? "用相册照片做背景" : "已选择自定义背景")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(customShareBackgroundData == nil ? AppColors.text : Color.white)
                                .lineLimit(1)
                            Text(customShareBackgroundData == nil ? "点这里选一张本地图片" : "保存图会使用这张图片做背景")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(customShareBackgroundData == nil ? AppColors.subtext : Color.white.opacity(0.86))
                                .lineLimit(1)
                        }

                        Spacer()

                        if currentShareCardStyle == .customBackground, customShareBackgroundData != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.white)
                                .padding(.trailing, 28)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            currentShareCardStyle == .customBackground && customShareBackgroundData != nil
                                ? AppColors.accent.opacity(0.82)
                                : Color.white.opacity(0.54),
                            lineWidth: 1.2
                        )
                )
            }

            if customShareBackgroundData != nil {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.88)) {
                        customShareBackgroundItem = nil
                        customShareBackgroundData = nil
                        customShareBackgroundImage = nil
                        if currentShareCardStyle == .customBackground {
                            selectedShareCardStyle = nil
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.text.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.58), lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("移除自定义背景")
            }
        }
        .buttonStyle(.plain)
        .onChange(of: customShareBackgroundItem) { _, newValue in
            guard let newValue else { return }
            Task { @MainActor in
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let normalized = normalizedShareBackground(data) {
                    customShareBackgroundData = normalized.data
                    customShareBackgroundImage = normalized.image
                    selectedShareCardStyle = .customBackground
                }
            }
        }
    }

    private func showMemorySaveMessage(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            memorySaveMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard memorySaveMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                memorySaveMessage = nil
            }
        }
    }

    private func playbackStatusToast(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.text.opacity(0.78))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.52), lineWidth: 0.8)
            )
            .shadow(color: AppColors.subtext.opacity(0.12), radius: 12, x: 0, y: 6)
            .allowsHitTesting(false)
    }

    private var playbackMemoryLine: String? {
        if let primarySignal = LifeStorySignalService.playbackPrimarySignalLine(from: playback) {
            let text = normalizedMemoryText(primarySignal)
            if let sentence = cleanMemorySentence(text) {
                return playback.range == .week
                    ? "这周留下：\(sentence)"
                    : "这个月留下：\(sentence)"
            }
            if let phrase = cleanMemoryPhrase(text) {
                return playback.range == .week
                    ? "这周留下了一笔「\(phrase)」。"
                    : "这个月留下了一笔「\(phrase)」。"
            }
        }

        if let sceneLine = playback.chapters
            .compactMap({ $0.metrics["sceneMemoryLine"]?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }),
           let cleaned = cleanMemorySentence(sceneLine) {
            return playback.range == .week
                ? "这周留下：\(cleaned)"
                : "这个月留下：\(cleaned)"
        }

        let narrationCandidates = playback.chapters
            .filter { !$0.id.contains("presence") && !$0.id.contains("outro") }
            .flatMap { chapter in
                [chapter.narration.warm, chapter.narration.plain]
            }

        if let sentence = narrationCandidates.compactMap(cleanMemorySentence).first {
            return playback.range == .week
                ? "这周留下：\(sentence)"
                : "这个月留下：\(sentence)"
        }

        let phraseCandidates = playback.chapters.flatMap { chapter in
            [
                chapter.metrics["voiceTitle1"],
                chapter.metrics["earlyVoiceTitle"],
                chapter.metrics["lateVoiceTitle"],
                chapter.metrics["busiestTitle"]
            ]
        }

        guard let phrase = phraseCandidates.compactMap(cleanMemoryPhrase).first else { return nil }
        return playback.range == .week
            ? "这周留下了一笔「\(phrase)」。"
            : "这个月留下了一笔「\(phrase)」。"
    }

    private func cleanMemorySentence(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let text = normalizedMemoryText(raw)
        guard (8...48).contains(text.count),
              !isLowConfidenceMemoryPhrase(text),
              !isCategoryOnlyMemoryPhrase(text),
              !EchoAnchorService.shared.isDirtyTraceTitle(text) else {
            return nil
        }
        return text
    }

    private func cleanMemoryPhrase(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let text = normalizedMemoryText(raw)
        guard (4...18).contains(text.count),
              !isLowConfidenceMemoryPhrase(text),
              !isCategoryOnlyMemoryPhrase(text),
              !EchoAnchorService.shared.isDirtyTraceTitle(text) else {
            return nil
        }
        return text
    }

    private func normalizedMemoryText(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "「」『』“”\"' "))
    }

    private func isLowConfidenceMemoryPhrase(_ text: String) -> Bool {
        let lows = ["几笔记录", "记录还少", "还没有", "没有足够", "暂无", "数据不足"]
        return lows.contains { text.contains($0) }
    }

    private func isCategoryOnlyMemoryPhrase(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if HomeItem.Category.allCases.contains(where: { trimmed == $0.rawValue || trimmed == $0.label }) {
            return true
        }
        let separators = CharacterSet(charactersIn: "/／、· ")
        let parts = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return false }
        let categoryLikeWords = Set(["公交", "地铁", "交通", "餐饮", "吃饭", "早餐", "购物", "日用", "居家", "健康", "放松", "住宿", "出行"])
        return parts.allSatisfy { word in
            categoryLikeWords.contains(word)
                || HomeItem.Category.allCases.contains(where: { category in
                    category.rawValue == word || category.label == word
                })
        }
    }

    private var doneHeadline: String {
        playback.range == .week ? "周记已完成" : "月章已完成"
    }

    private var doneDetail: String? {
        playback.range == .week
            ? "这段回看已经完成；想继续查、比、补，可以进入复盘。"
            : "这个月已经整理成章；可以完成返回，也可以继续复盘。"
    }

    private var primaryDoneTitle: String {
        PlaybackCompletionPolicy.primaryTitle(
            isMember: isMember,
            memberTitle: memberPitch?.cta
        )
    }

    private func handlePrimaryDoneAction() {
        switch PlaybackCompletionPolicy.primaryAction(isMember: isMember) {
        case .dismiss:
            dismiss()
        }
    }

    private var shareCardPreparationPreview: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.paperWarm, AppColors.paperMist],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                ProgressView()
                    .tint(AppColors.accentDark)
                Text("正在准备分享图")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .frame(width: 97, height: 173)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在准备分享图")
    }

    private var shareCardPrimaryActionTitle: String {
        if isSavingShareCard { return "正在保存" }
        if isPreparingShareCard || currentPreparedShareCardRenderInput == nil { return "正在准备" }
        return "保存到相册"
    }

    private var isShareCardReadyToSave: Bool {
        !isPreparingShareCard && !isSavingShareCard && currentPreparedShareCardRenderInput != nil
    }

    private var shareCardPreparationNotice: String? {
        guard let unavailableCount = preparedShareCardPhotos?.unavailablePhotoCount,
              unavailableCount > 0 else { return nil }
        return "有 \(unavailableCount) 张照片暂不可用，本次按可用记录生成。"
    }

    private var shareCardPhotoPreparationKey: String {
        playback.memoryAnchors
            .prefix(WeeklyShareCardPhotoPreparationPolicy.maximumPhotoCount)
            .map { anchor in
                [
                    anchor.id.uuidString,
                    anchor.imageReference ?? "inline",
                    String(anchor.imageData.count),
                    String(anchor.imageByteCount ?? 0)
                ]
                .joined(separator: ":")
            }
            .joined(separator: "|")
    }

    private var currentPreparedShareCardRenderInput: PreparedWeeklyShareCardRenderInput? {
        guard let payload = weeklySharePayload,
              let preparedShareCardPhotos,
              preparedShareCardPhotos.sourceKey == shareCardPhotoPreparationKey else {
            return nil
        }
        return PreparedWeeklyShareCardRenderInput(
            payload: payload,
            memoryAnchors: preparedShareCardPhotos.availableAnchors,
            preparedImagesByAnchorID: preparedShareCardPhotos.imagesByAnchorID,
            unavailablePhotoCount: preparedShareCardPhotos.unavailablePhotoCount,
            isPetMode: petEnabled,
            nickname: shareNickname.isEmpty ? "叙账用户" : shareNickname,
            theme: shareCardTheme,
            style: currentShareCardStyle,
            customBackgroundImage: customShareBackgroundImage
        )
    }

    @MainActor
    private func prepareShareCardPhotos(for sourceKey: String) async {
        shareSaveMessage = nil
        isPreparingShareCard = true
        preparedShareCardPhotos = nil

        let requestedAnchors = Array(
            playback.memoryAnchors.prefix(WeeklyShareCardPhotoPreparationPolicy.maximumPhotoCount)
        )
        let requests = requestedAnchors.map { WeeklyShareCardPhotoPreparationRequest(anchor: $0) }
        let preparedPhotos = await WeeklyShareCardImagePreparer.prepare(requests)
        guard !Task.isCancelled, sourceKey == shareCardPhotoPreparationKey else { return }

        var imagesByAnchorID: [UUID: UIImage] = [:]
        for preparedPhoto in preparedPhotos where imagesByAnchorID[preparedPhoto.anchorID] == nil {
            imagesByAnchorID[preparedPhoto.anchorID] = preparedPhoto.image
        }
        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: requestedAnchors.map(\.id),
            loadedAnchorIDs: Set(imagesByAnchorID.keys)
        )
        let availableIDSet = Set(resolution.availableAnchorIDs)
        preparedShareCardPhotos = PreparedWeeklyShareCardPhotoSet(
            sourceKey: sourceKey,
            availableAnchors: requestedAnchors.filter { availableIDSet.contains($0.id) },
            imagesByAnchorID: imagesByAnchorID,
            unavailablePhotoCount: resolution.unavailablePhotoCount
        )
        if let selectedShareCardStyle,
           selectedShareCardStyle != .customBackground,
           !LifeSliceShareCardStyle.presetCases(photoCount: resolution.availableAnchorIDs.count)
            .contains(selectedShareCardStyle) {
            self.selectedShareCardStyle = nil
        }
        isPreparingShareCard = false
    }

    private func saveWeeklyStoryCard(_ renderInput: PreparedWeeklyShareCardRenderInput) {
        guard !isSavingShareCard, shareCardSaveTask == nil else { return }
        isSavingShareCard = true
        shareSaveMessage = nil

        shareCardSaveTask = Task { @MainActor in
            defer {
                isSavingShareCard = false
                shareCardSaveTask = nil
            }
            guard !Task.isCancelled else { return }
            let card = WeeklyStoryShareCardView(renderInput: renderInput)
            guard let image = card.snapshot() else {
                shareSaveMessage = "分享图暂时没有生成成功，请稍后再试。"
                return
            }
            guard !Task.isCancelled else { return }
            do {
                try await PhotoLibrarySaveService.shared.saveImageToLibrary(image)
                guard !Task.isCancelled else { return }
                shareSaveMessage = renderInput.unavailablePhotoCount > 0
                    ? "已保存到相册；有 \(renderInput.unavailablePhotoCount) 张照片暂不可用，本次按可用记录生成。"
                    : "已保存到相册。"
                showShareCardPrivacyConfirm = false
                preparedShareCardPhotos = nil
            } catch {
                guard !Task.isCancelled else { return }
                shareSaveMessage = (error as? LocalizedError)?.errorDescription ?? "暂时没保存成功。请检查相册权限后再试。"
            }
        }
    }

    private func startPlayback() {
        guard !playback.chapters.isEmpty, isPlaying else { return }
        playbackTask?.cancel()
        playbackTask = Task {
            while !Task.isCancelled && isPlaying && activeIndex < playback.chapters.count {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    if activeIndex < playback.chapters.count - 1 {
                        activeIndex += 1
                    } else {
                        playbackDone = true
                        isPlaying = false
                        reportCompletionIfNeeded(progress: 1)
                    }
                }
            }
        }
    }

    private func handleChapterSwipe(_ width: CGFloat) {
        guard abs(width) > 44 else { return }
        let shouldResume = isPlaying
        playbackTask?.cancel()
        if width < 0 {
            moveToChapter(activeIndex + 1)
        } else {
            moveToChapter(activeIndex - 1)
        }
        if shouldResume && !playbackDone {
            startPlayback()
        }
    }

    private func moveToChapter(_ index: Int) {
        guard !playback.chapters.isEmpty else { return }
        let lastIndex = playback.chapters.count - 1
        let nextIndex = min(max(index, 0), lastIndex)
        activeIndex = nextIndex
        playbackDone = nextIndex == lastIndex
        if playbackDone {
            isPlaying = false
            reportCompletionIfNeeded(progress: 1)
        }
    }

    private func restartPlayback() {
        playbackTask?.cancel()
        activeIndex = 0
        playbackDone = false
        isPlaying = true
        startPlayback()
    }

    private func reportCompletionIfNeeded(progress: Double) {
        guard !completionReported, progress >= 0.8 else { return }
        completionReported = true
        onCompleted(progress)
    }
}


private struct RatioRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.62), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 48, height: 48)
        }
        .shadow(color: AppColors.accent.opacity(0.16), radius: 12, y: 6)
    }
}

private func lifeSliceResolvedPhotoCaption(
    for anchor: SummaryMemoryAnchor?,
    fallback: String = "当时拍下的一张图"
) -> String {
    guard let anchor else { return fallback }
    let caption = anchor.caption.trimmingCharacters(in: .whitespacesAndNewlines)
    if !caption.isEmpty, !lifeSliceShouldRewritePhotoCaption(caption) {
        return caption
    }
    return lifeSliceConcretePhotoCaption(for: anchor, fallback: fallback)
}

func lifeSliceSafeSharePhotoCaption(
    for anchor: SummaryMemoryAnchor,
    fallback: String
) -> String {
    switch anchor.sceneHint {
    case .careRecord:
        return "一条照护记录"
    case .healthRecord:
        return "一条健康记录"
    default:
        return lifeSliceResolvedPhotoCaption(for: anchor, fallback: fallback)
    }
}

private func lifeSliceShouldRewritePhotoCaption(_ caption: String) -> Bool {
    let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return false }
    let awkwardFragments = [
        "这张图把",
        "留住了",
        "留了下来",
        "被留下",
        "代表这笔",
        "代表了那笔",
        "这件东西代表",
        "这类图不用好看",
        "这几张为什么"
    ]
    return awkwardFragments.contains { text.localizedCaseInsensitiveContains($0) }
}

private func lifeSliceConcretePhotoCaption(
    for anchor: SummaryMemoryAnchor,
    fallback: String
) -> String {
    let text = [anchor.label, anchor.title, anchor.caption]
        .joined(separator: " ")

    if lifeSliceContainsAny(text, ["可乐", "饮料", "饮品", "矿泉水", "瓶装水", "咖啡", "奶茶"]) {
        if text.localizedCaseInsensitiveContains("可乐") { return "买了一瓶可乐" }
        if text.localizedCaseInsensitiveContains("咖啡") { return "喝了一杯咖啡" }
        if text.localizedCaseInsensitiveContains("奶茶") { return "喝了一杯奶茶" }
        return "买了点喝的"
    }

    switch anchor.sceneHint {
    case .gathering:
        if text.localizedCaseInsensitiveContains("同学") { return "和同学的一次聚会" }
        if text.localizedCaseInsensitiveContains("家人") || text.localizedCaseInsensitiveContains("家庭") {
            return "和家里人的一顿饭"
        }
        return "和朋友的一次聚会"
    case .travel, .travelTransport:
        if text.localizedCaseInsensitiveContains("回家") { return "回家路上" }
        if text.localizedCaseInsensitiveContains("上班") || text.localizedCaseInsensitiveContains("通勤") { return "上班路上" }
        return "路上的一段"
    case .homeLife:
        return "给家里买的"
    case .importantPurchase:
        return "这次买的东西"
    case .careRecord:
        return "照护相关的一张记录"
    case .healthRecord:
        return "身体相关的一张记录"
    case .giftMoment:
        return "这次带去的心意"
    case .vehicleCare:
        return "车辆相关的一张记录"
    case .experience:
        if lifeSliceContainsAny(text, ["电影", "影院"]) { return "看了一场电影" }
        if lifeSliceContainsAny(text, ["展览", "美术馆", "博物馆"]) { return "看了一场展览" }
        if lifeSliceContainsAny(text, ["演唱会", "音乐节", "live", "剧场", "话剧"]) { return "一场演出" }
        if lifeSliceContainsAny(text, ["桌游", "剧本杀", "密室"]) { return "一起玩的一次" }
        if lifeSliceContainsAny(text, ["景区", "门票", "露营"]) { return "出去玩的一次" }
        return "一次现场体验"
    }

    if lifeSliceContainsAny(text, ["朋友", "同学", "约饭", "见面", "生日"]) {
        return "和朋友的一次聚会"
    }
    if lifeSliceContainsAny(text, ["早餐", "午餐", "晚餐", "外卖", "饭", "餐", "火锅", "烧烤", "饭局"]) {
        return "这一餐"
    }
    if lifeSliceContainsAny(text, ["通勤", "公交", "地铁", "打车", "路上", "回家", "上班"]) {
        return text.localizedCaseInsensitiveContains("回家") ? "回家路上" : "路上的一段"
    }
    if lifeSliceContainsAny(text, ["购物", "添置", "快递", "下单", "衣服", "鞋", "背包", "数码", "盲盒", "手办"]) {
        return "这次买的东西"
    }

    return lifeSliceShouldRewritePhotoCaption(fallback) ? "当时拍下的一张图" : fallback
}

private func lifeSliceContainsAny(_ text: String, _ keywords: [String]) -> Bool {
    keywords.contains { text.localizedCaseInsensitiveContains($0) }
}

struct NormalizedShareBackground {
    let data: Data
    let image: UIImage
}

func normalizedShareBackground(_ data: Data) -> NormalizedShareBackground? {
    guard let image = UIImage(data: data) else { return nil }
    let maxSide: CGFloat = 1600
    let longest = max(image.size.width, image.size.height)
    guard longest > maxSide else {
        let normalizedData = image.jpegData(compressionQuality: 0.84) ?? data
        return NormalizedShareBackground(
            data: normalizedData,
            image: UIImage(data: normalizedData) ?? image
        )
    }
    let scale = maxSide / longest
    let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
    guard let normalizedData = resized.jpegData(compressionQuality: 0.84) else { return nil }
    return NormalizedShareBackground(
        data: normalizedData,
        image: UIImage(data: normalizedData) ?? resized
    )
}

struct WeeklyShareCardPhotoPreparationResolution: Equatable {
    let availableAnchorIDs: [UUID]
    let unavailablePhotoCount: Int
}

enum WeeklyShareCardPhotoPreparationPolicy {
    static let maximumPhotoCount = 3

    static func resolve(
        requestedAnchorIDs: [UUID],
        loadedAnchorIDs: Set<UUID>
    ) -> WeeklyShareCardPhotoPreparationResolution {
        let limitedIDs = Array(requestedAnchorIDs.prefix(maximumPhotoCount))
        let availableIDs = limitedIDs.filter { loadedAnchorIDs.contains($0) }
        return WeeklyShareCardPhotoPreparationResolution(
            availableAnchorIDs: availableIDs,
            unavailablePhotoCount: limitedIDs.count - availableIDs.count
        )
    }
}

private struct WeeklyShareCardPhotoPreparationRequest: Sendable {
    let anchorID: UUID
    let imageReference: String?
    let inlineData: Data

    init(anchor: SummaryMemoryAnchor) {
        anchorID = anchor.id
        imageReference = anchor.imageReference
        inlineData = anchor.imageData
    }
}

private struct WeeklyShareCardPreparedPhoto: @unchecked Sendable {
    let anchorID: UUID
    let image: UIImage
}

private enum WeeklyShareCardImagePreparer {
    private static let exportMaxPixelSize = 2_880

    static func prepare(
        _ requests: [WeeklyShareCardPhotoPreparationRequest]
    ) async -> [WeeklyShareCardPreparedPhoto] {
        guard !requests.isEmpty else { return [] }
        return await Task.detached(priority: .userInitiated) {
            var prepared: [WeeklyShareCardPreparedPhoto] = []
            prepared.reserveCapacity(requests.count)
            for request in requests {
                guard !Task.isCancelled else { break }
                let referencedData = request.imageReference.flatMap {
                    LocalStore.loadMemoryImageData(reference: $0, variant: .original)
                        ?? LocalStore.loadMemoryImageData(reference: $0, variant: .thumbnail)
                }
                let data = referencedData ?? (request.inlineData.isEmpty ? nil : request.inlineData)
                guard let data,
                      let image = decodeForExport(data) else { continue }
                prepared.append(
                    WeeklyShareCardPreparedPhoto(anchorID: request.anchorID, image: image)
                )
            }
            return prepared
        }.value
    }

    private static func decodeForExport(_ data: Data) -> UIImage? {
        if let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: exportMaxPixelSize
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return UIImage(cgImage: cgImage)
            }
        }
        guard let image = UIImage(data: data) else { return nil }
        return image.preparingForDisplay() ?? image
    }
}

private struct PreparedWeeklyShareCardPhotoSet {
    let sourceKey: String
    let availableAnchors: [SummaryMemoryAnchor]
    let imagesByAnchorID: [UUID: UIImage]
    let unavailablePhotoCount: Int
}

private struct PreparedWeeklyShareCardRenderInput {
    let payload: WeeklyShareCardPayload
    let memoryAnchors: [SummaryMemoryAnchor]
    let preparedImagesByAnchorID: [UUID: UIImage]
    let unavailablePhotoCount: Int
    let isPetMode: Bool
    let nickname: String
    let theme: WeeklyStoryShareCardTheme
    let style: LifeSliceShareCardStyle
    let customBackgroundImage: UIImage?
}

private struct WeeklyStoryShareCardView: View {
    let renderInput: PreparedWeeklyShareCardRenderInput

    private var payload: WeeklyShareCardPayload { renderInput.payload }
    private var memoryAnchors: [SummaryMemoryAnchor] { renderInput.memoryAnchors }
    private var preparedImagesByAnchorID: [UUID: UIImage] { renderInput.preparedImagesByAnchorID }
    private var isPetMode: Bool { renderInput.isPetMode }
    private var nickname: String { renderInput.nickname }
    private var theme: WeeklyStoryShareCardTheme { renderInput.theme }
    private var style: LifeSliceShareCardStyle { renderInput.style }
    private var customBackgroundImage: UIImage? { renderInput.customBackgroundImage }

    private let cardSize = CGSize(width: 540, height: 960)
    private var paper: Color { theme.paper }
    private var ink: Color { theme.ink }
    private var muted: Color { theme.muted }
    private var green: Color { theme.accent }
    private var deepGreen: Color { theme.accentDeep }
    private var softGreen: Color { theme.softAccent }
    private var rainGreen: Color { theme.rainAccent }
    private var travelGold: Color { theme.travelAccent }
    private var cityIndigo: Color { theme.cityAccent }

    private enum PosterVisualItem {
        case photo(SummaryMemoryAnchor)
        case story(String)
        case keywords([String])
        case rhythm(String)
    }

    private struct PosterCopyModel {
        let period: String
        let shortPeriod: String
        let imageText: String
        let imageCount: Int
        let recordCount: Int
        let title: String
        let subtitle: String
        let tagline: String
        let sceneLabel: String
        let body: String

        init(
            payload: WeeklyShareCardPayload,
            memoryAnchors: [SummaryMemoryAnchor],
            imageCount: Int,
            sceneLabels: [String]
        ) {
            period = payload.periodText.contains("月") && !payload.periodText.contains("-") ? "这个月" : "这一周"
            shortPeriod = payload.periodText.contains("月") && !payload.periodText.contains("-") ? "这个月" : "这周"
            imageText = Self.imageText(imageCount)
            self.imageCount = imageCount
            recordCount = payload.recordCount
            let activeDayCount = max(
                payload.recordCount > 0 ? 1 : 0,
                payload.dailyCountTrend.filter { $0.1 > 0 }.count
            )
            let firstScene = sceneLabels.first(where: { !Self.isWeakLabel($0) }) ?? Self.normalizedLabel(payload.topCategory)
            let safeScene = Self.isWeakLabel(firstScene) ? "" : firstScene
            let photoLine = memoryAnchors.first.flatMap(Self.safeAnchorLine)
            let factualHeadline = Self.safeLine(payload.headline)
            let recordHeadline = "\(period)，\(payload.recordCount)笔记录"
            if imageCount == 1, let firstAnchor = memoryAnchors.first {
                title = Self.singlePhotoTitle(firstAnchor) ?? factualHeadline ?? recordHeadline
            } else {
                title = factualHeadline ?? recordHeadline
            }
            subtitle = Self.firstDistinctLine(
                [payload.insight.fact, payload.subtitle, payload.contextLine, payload.anchorLine],
                excluding: [title, photoLine]
            ) ?? "\(shortPeriod)共有 \(payload.recordCount) 笔记录，分布在 \(activeDayCount) 个记录日。"

            if !safeScene.isEmpty {
                sceneLabel = safeScene
                tagline = "\(payload.recordCount)笔记录 · \(safeScene)"
            } else {
                sceneLabel = "\(payload.recordCount)笔记录"
                tagline = imageCount > 0 ? "\(payload.recordCount)笔记录 · \(imageText)" : "\(payload.recordCount)笔记录"
            }

            let bodyLines = Self.distinctLines([
                Self.safeLine(payload.anchorLine),
                Self.safeLine(payload.contextLine),
                Self.safeLine(payload.insight.care),
                photoLine
            ], excluding: [title, subtitle])
            if bodyLines.isEmpty {
                body = "\(shortPeriod)有 \(payload.recordCount) 笔记录。\n\(imageCount > 0 ? imageText : "这些记录")按时间整理在一起。"
            } else {
                body = bodyLines.prefix(2).joined(separator: "\n")
            }
        }

        func title(for style: LifeSliceShareCardStyle) -> String {
            switch style {
            case .filmStory:
                return "\(period)，\(imageText)入卷"
            case .magazine:
                return "\(period)的记录版面"
            case .fullPhoto:
                return title
            case .journal:
                return "\(period)，\(recordCount)笔记录"
            default:
                return title
            }
        }

        func subtitle(for style: LifeSliceShareCardStyle) -> String {
            switch style {
            case .filmStory:
                if imageCount > 0 {
                    return "\(shortPeriod)有 \(recordCount) 笔记录，\(imageText)排进胶片。"
                }
                return "\(shortPeriod)有 \(recordCount) 笔记录，按时间排进胶片。"
            case .magazine:
                if imageCount > 0 {
                    return "\(shortPeriod)有 \(recordCount) 笔记录，按照片、分类和时间排成这一页。"
                }
                return "\(shortPeriod)有 \(recordCount) 笔记录，按分类和时间排成这一页。"
            case .fullPhoto:
                return subtitle
            case .journal:
                return body
            default:
                return subtitle
            }
        }

        private static func imageText(_ count: Int) -> String {
            switch count {
            case 0: return "几段记录"
            case 1: return "一张照片"
            case 2: return "两张照片"
            case 3: return "三张照片"
            default: return "\(count)张照片"
            }
        }

        private static func safeAnchorLine(_ anchor: SummaryMemoryAnchor) -> String? {
            safeLine(lifeSliceSafeSharePhotoCaption(for: anchor, fallback: ""))
                ?? (isWeakLabel(anchor.label) ? nil : "\(anchor.label)对应其中一笔记录。")
        }

        private static func singlePhotoTitle(_ anchor: SummaryMemoryAnchor) -> String? {
            guard let line = safeAnchorLine(anchor) else { return nil }
            let cleanLine = line.trimmingCharacters(in: CharacterSet(charactersIn: "。！？!?，,"))
            guard !cleanLine.isEmpty else { return nil }
            return "\(anchor.createdAt.zhBillDateOnly)，\(cleanLine)"
        }

        private static func firstDistinctLine(
            _ candidates: [String?],
            excluding excludedLines: [String?]
        ) -> String? {
            distinctLines(candidates.map { safeLine($0) }, excluding: excludedLines).first
        }

        private static func distinctLines(
            _ candidates: [String?],
            excluding excludedLines: [String?]
        ) -> [String] {
            let excluded = Set(excludedLines.compactMap { safeLine($0) })
            var seen = Set<String>()
            return candidates.compactMap { safeLine($0) }.filter { line in
                guard !excluded.contains(line), seen.insert(line).inserted else { return false }
                return true
            }
        }

        private static func safeLine(_ raw: String?) -> String? {
            let text = raw?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ") ?? ""
            guard !text.isEmpty else { return nil }
            let blocked = [
                "记" + "得我",
                "也在" + "记得",
                "也在" + "这周",
                "值" + "得",
                "小小",
                "认真" + "发生",
                "生活" + "不是赶路",
                "刚好" + "是",
                "照片" + "不多",
                "照片" + "不够",
                "这一周" + "，一张照片",
                "当时拍下" + "的一张图",
                "空" + "占位",
                "留下"
            ]
            guard !blocked.contains(where: { text.localizedCaseInsensitiveContains($0) }) else { return nil }
            return text.count > 34 ? "\(text.prefix(34))" : text
        }

        private static func normalizedLabel(_ raw: String) -> String {
            if raw.contains("可乐") || raw.contains("饮料") || raw.contains("饮品") || raw.contains("咖啡") || raw.contains("奶茶") { return "饮品" }
            if raw.contains("餐") || raw.contains("饭") || raw.contains("菜") || raw.contains("面") || raw.contains("食堂") { return "餐食" }
            if raw.contains("公交") || raw.contains("地铁") || raw.contains("打车") || raw.contains("交通") || raw.contains("通勤") { return "出行" }
            if raw.contains("购物") || raw.contains("添置") || raw.contains("日用") || raw.contains("快递") { return "添置" }
            if raw.contains("朋友") || raw.contains("见面") || raw.contains("聚会") { return "见面" }
            return raw
        }

        private static func isWeakLabel(_ label: String) -> Bool {
            ["", "体验", "日常", "生活", "现场", "记录", "回看", "其他", "通勤"].contains(label)
        }
    }

    private var posterCopy: PosterCopyModel {
        PosterCopyModel(
            payload: payload,
            memoryAnchors: memoryAnchors,
            imageCount: posterImageCount,
            sceneLabels: posterSceneLabels
        )
    }

    var body: some View {
        ZStack {
            lifeSlicePosterBackground

            posterContent
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipped()
    }

    @ViewBuilder
    private var posterContent: some View {
        switch style {
        case .warmLight:
            heroStoryPosterContent
        case .magazine:
            magazinePosterContent
        case .appleMemories:
            warmLightPosterContent
        case .journal:
            journalPosterContent
        case .filmStory:
            filmStoryPosterContent
        case .collageStory:
            collagePosterContent
        case .cleanTexture:
            cleanPosterContent
        case .fullPhoto:
            fullPhotoPosterContent
        case .customBackground:
            customBackgroundPosterContent
        }
    }

    private var heroStoryPosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 34)
                .padding(.horizontal, 34)

            Text(posterPeriodTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.78))
                .padding(.top, 42)
                .padding(.horizontal, 34)

            Text(warmLightPosterHeadline)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(2)
                .lineSpacing(5)
                .minimumScaleFactor(0.70)
                .padding(.top, 18)
                .padding(.horizontal, 34)

            Text(warmLightPosterSubtitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ink.opacity(0.76))
                .lineSpacing(6)
                .lineLimit(3)
                .minimumScaleFactor(0.78)
                .padding(.top, 18)
                .padding(.horizontal, 34)

            posterVisualImage(posterVisualItem(at: 0), index: 0)
                .frame(height: 430)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    singlePhotoCaptionBadge
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.78), lineWidth: 1.5)
                )
                .shadow(color: deepGreen.opacity(0.10), radius: 18, x: 0, y: 10)
                .padding(.top, 26)
                .padding(.horizontal, 34)

            Spacer(minLength: 14)

            warmLightMetricBar
                .padding(.horizontal, 34)
                .padding(.bottom, 20)

            lifeSlicePosterBrandFooter
        }
    }

    private var magazinePosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 32)

            Text(posterPeriodTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.78))
                .padding(.top, 34)

            Text(lifeSlicePosterHeadline)
                .font(.system(size: 37, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(2)
                .lineSpacing(4)
                .minimumScaleFactor(0.72)
                .padding(.top, 12)

            Text(magazinePosterSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))
                .lineSpacing(4)
                .lineLimit(2)
                .padding(.top, 10)

            HStack(spacing: 14) {
                posterVisualImage(posterVisualItem(at: 0), index: 0)
                    .frame(width: 304, height: 428)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 14) {
                    posterVisualImage(posterVisualItem(at: 1), index: 1)
                        .frame(height: 207)
                    posterVisualImage(posterVisualItem(at: 2), index: 2)
                        .frame(height: 207)
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 24)

            Text(magazinePosterTagline)
                .font(.system(size: 19, weight: .medium, design: .serif))
                .foregroundStyle(ink.opacity(0.82))
                .padding(.top, 18)

            Spacer(minLength: 10)

            lifeSlicePosterFooter
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 28)
    }

    private var journalPosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 34)
                .padding(.horizontal, 34)

            Text(payload.periodText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.74))
                .padding(.top, 42)
                .padding(.horizontal, 34)

            Text(journalPosterHeadline)
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(2)
                .lineSpacing(5)
                .minimumScaleFactor(0.72)
                .padding(.top, 18)
                .padding(.horizontal, 34)

            Text(journalPosterBody)
                .font(chineseHandwritingFont(size: 20))
                .foregroundStyle(ink.opacity(0.82))
                .lineSpacing(11)
                .lineLimit(4)
                .padding(.top, 42)
                .padding(.horizontal, 64)

            Spacer(minLength: 22)

            HStack(spacing: 13) {
                ForEach(0..<3, id: \.self) { index in
                    posterVisualImage(posterVisualItem(at: index), index: index)
                        .frame(width: 138, height: 126)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.70), lineWidth: 1)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 34)

            Spacer(minLength: 24)

            lifeSlicePosterFooter
                .padding(.horizontal, 34)
                .padding(.bottom, 28)
        }
    }

    private var filmStoryPosterContent: some View {
        ZStack {
            filmGrainOverlay

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "b88b48").opacity(0.46), lineWidth: 1)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)

            HStack(spacing: 0) {
                filmSideRail(mark: "KODAK PORTRA 400", alignLeading: true)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        HStack(spacing: 7) {
                            brandLeafMark(size: 15, tint: Color(hex: "d6b876"))
                            Text("叙账")
                                .font(.system(size: 15, weight: .bold))
                        }

                        Spacer()

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(hex: "f7efe3").opacity(0.88))
                            .frame(width: 22, height: 14)
                    }
                    .foregroundStyle(Color(hex: "d6b876").opacity(0.88))
                    .padding(.top, 28)

                    Rectangle()
                        .fill(Color(hex: "b88b48").opacity(0.34))
                        .frame(height: 1)
                        .padding(.top, 13)

                    Text(payload.periodText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "d6b876").opacity(0.82))
                        .padding(.top, 18)

                    Text(filmPosterHeadline)
                        .font(.system(size: 33, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: "f7efe3"))
                        .lineLimit(2)
                        .lineSpacing(3)
                        .minimumScaleFactor(0.70)
                        .padding(.top, 16)

                    posterVisualImage(posterVisualItem(at: 0), index: 0)
                        .frame(width: 350, height: 262)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color(hex: "f7efe3").opacity(0.12), lineWidth: 1)
                        )
                        .padding(.top, 22)
                        .frame(maxWidth: .infinity)

                    Text(filmPosterSubtitle)
                        .font(chineseHandwritingFont(size: 17))
                        .foregroundStyle(Color(hex: "f7efe3").opacity(0.86))
                        .lineSpacing(6)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                        .padding(.top, 20)
                        .padding(.horizontal, 5)

                    Spacer(minLength: 18)

                    Rectangle()
                        .fill(Color(hex: "b88b48").opacity(0.42))
                        .frame(height: 1)

                    filmPosterFooter
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 18)

                filmSideRail(mark: "43", alignLeading: false)
            }
            .padding(.horizontal, 20)
        }
    }

    private var fullPhotoPosterContent: some View {
        ZStack(alignment: .bottomLeading) {
            posterVisualImage(posterVisualItem(at: 0), index: 0)
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.06),
                    Color.black.opacity(0.24),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 14) {
                Text(posterPeriodTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.80))

                Text(fullPhotoPosterHeadline)
                    .font(.system(size: 39, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(2)
                    .lineSpacing(5)
                    .minimumScaleFactor(0.72)

                Text(fullPhotoPosterSubtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineSpacing(5)
                    .lineLimit(2)

                filmPosterFooter
                    .padding(.top, 18)
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 34)
        }
    }

    private var warmLightPosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 34)
                .padding(.horizontal, 34)

            Text(payload.periodText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.78))
                .padding(.top, 38)
                .padding(.horizontal, 34)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(warmLightPosterHeadline)
                    .font(.system(size: 39, weight: .bold, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .lineSpacing(5)
                    .minimumScaleFactor(0.70)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(deepGreen.opacity(0.72))
                    .offset(y: -2)
            }
            .padding(.top, 18)
            .padding(.horizontal, 34)

            warmLightQuoteBlock
                .padding(.top, 26)
                .padding(.horizontal, 34)

            warmLightSceneRibbon
                .padding(.top, 24)
                .padding(.horizontal, 34)

            warmLightPhotoTriptych
                .padding(.top, 18)
                .padding(.horizontal, 24)

            warmLightHandwrittenLine
                .padding(.top, 22)
                .padding(.horizontal, 42)

            warmLightMetricBar
                .padding(.top, 24)
                .padding(.horizontal, 34)

            Spacer(minLength: 18)

            lifeSlicePosterBrandFooter
        }
    }

    private var collagePosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 30)

            Text(posterPeriodTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.78))
                .padding(.top, 32)

            Text(lifeSlicePosterHeadline)
                .font(.system(size: 36, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(2)
                .lineSpacing(4)
                .minimumScaleFactor(0.76)
                .padding(.top, 10)

            Text(collagePosterSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))
                .lineSpacing(4)
                .lineLimit(2)
                .padding(.top, 12)

            ZStack {
                collageTape(width: 74)
                    .offset(x: -86, y: -174)
                    .rotationEffect(.degrees(-8))
                collageTape(width: 66)
                    .offset(x: 118, y: -12)
                    .rotationEffect(.degrees(10))

                collagePhoto(
                    index: 0,
                    fallback: "这一餐",
                    size: CGSize(width: 356, height: 260),
                    rotation: -4,
                    offset: CGSize(width: -22, height: -58)
                )

                collagePhoto(
                    index: 1,
                    fallback: "回家路上",
                    size: CGSize(width: 214, height: 168),
                    rotation: 5,
                    offset: CGSize(width: -112, height: 148)
                )

                collagePhoto(
                    index: 2,
                    fallback: "这次买的东西",
                    size: CGSize(width: 214, height: 168),
                    rotation: -3,
                    offset: CGSize(width: 116, height: 146)
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 488)
            .padding(.top, 8)

            Text(collagePosterTagline)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(ink.opacity(0.82))
                .padding(.top, 6)

            Spacer(minLength: 10)

            lifeSlicePosterFooter
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 28)
    }

    private var cleanPosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 30)

            HStack(alignment: .firstTextBaseline) {
                Text(posterPeriodTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(deepGreen.opacity(0.78))
                Spacer()
                Text(style.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(muted.opacity(0.78))
            }
            .padding(.top, 30)

            Text(lifeSlicePosterHeadline)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 12)

            Text(cleanPosterSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))
                .lineSpacing(4)
                .lineLimit(2)
                .padding(.top, 10)

            VStack(spacing: 14) {
                cleanPhotoRow(index: 0, fallback: "这一餐")
                cleanPhotoRow(index: 1, fallback: "回家路上")
                cleanPhotoRow(index: 2, fallback: "这次买的东西")
            }
            .padding(.top, 24)

            HStack(spacing: 12) {
                lifeSlicePosterMetric(icon: "pencil", value: "\(payload.recordCount)", label: "笔记录")
                lifeSlicePosterMetric(icon: "calendar", value: "\(posterActiveDayCount)", label: "个记录日")
                lifeSlicePosterMetric(icon: posterImageMetricIcon, value: posterImageMetricValue, label: posterImageMetricLabel)
            }
            .padding(.top, 18)

            lifeSlicePosterReasonCard
                .padding(.top, 16)

            Spacer(minLength: 10)

            lifeSlicePosterFooter
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 28)
    }

    private var customBackgroundPosterContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            lifeSlicePosterHeader
                .padding(.top, 30)

            Text(posterPeriodTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.82))
                .padding(.top, 28)

            Text(lifeSlicePosterHeadline)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.top, 10)

            Text(customBackgroundPosterSubtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted.opacity(0.94))
                .lineSpacing(4)
                .lineLimit(2)
                .padding(.top, 10)

            lifeSlicePosterPhotoGrid
                .padding(.top, 22)

            HStack(spacing: 12) {
                lifeSlicePosterMetric(icon: "pencil", value: "\(payload.recordCount)", label: "笔记录")
                lifeSlicePosterMetric(icon: "calendar", value: "\(posterActiveDayCount)", label: "个记录日")
                lifeSlicePosterMetric(icon: posterImageMetricIcon, value: posterImageMetricValue, label: posterImageMetricLabel)
            }
            .padding(.top, 18)

            lifeSlicePosterReasonCard
                .padding(.top, 16)

            Spacer(minLength: 10)

            lifeSlicePosterFooter
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 28)
    }

    private var lifeSlicePosterBackground: some View {
        ZStack {
            switch style {
            case .warmLight:
                Color(hex: "fbfaf4")
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.94),
                        theme.backgroundMid.opacity(0.68),
                        theme.backgroundEnd.opacity(0.76)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [
                        green.opacity(0.10),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.02, y: 0.24),
                    startRadius: 0,
                    endRadius: 320
                )
                RadialGradient(
                    colors: [
                        Color(hex: "ead8bd").opacity(0.24),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.92, y: 0.06),
                    startRadius: 0,
                    endRadius: 260
                )
                warmLightLeafShadow
            case .magazine:
                Color(hex: "f7f5ee")
                LinearGradient(
                    colors: [Color(hex: "fbfaf4"), Color(hex: "edf2ed"), Color(hex: "f7f5ee")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                warmLightLeafShadow.opacity(0.50)
            case .appleMemories:
                Color(hex: "f1f6ee")
                LinearGradient(
                    colors: [Color(hex: "eef5ed"), Color(hex: "f8f3e8"), Color(hex: "e6f0e9")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                warmLightLeafShadow
            case .journal:
                Color(hex: "f8f1e4")
                LinearGradient(
                    colors: [Color(hex: "fbf4e7"), Color(hex: "f3eadb"), Color(hex: "fbf7ee")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Canvas { context, size in
                    let inkLine = ink.opacity(0.18)
                    var flower = Path()
                    flower.move(to: CGPoint(x: size.width * 0.76, y: size.height * 0.33))
                    flower.addCurve(
                        to: CGPoint(x: size.width * 0.72, y: size.height * 0.56),
                        control1: CGPoint(x: size.width * 0.70, y: size.height * 0.42),
                        control2: CGPoint(x: size.width * 0.78, y: size.height * 0.48)
                    )
                    context.stroke(flower, with: .color(inkLine), lineWidth: 1)
                    for offset in [0.0, 0.04, 0.08] {
                        context.stroke(
                            Path(ellipseIn: CGRect(x: size.width * (0.74 + offset), y: size.height * (0.34 + offset), width: 28, height: 18)),
                            with: .color(inkLine),
                            lineWidth: 0.9
                        )
                    }
                }
            case .filmStory:
                Color(hex: "10100d")
                LinearGradient(
                    colors: [Color(hex: "15130f"), Color(hex: "090908"), Color(hex: "17130d")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color(hex: "b98f53").opacity(0.18), Color.clear],
                    center: UnitPoint(x: 0.92, y: 0.18),
                    startRadius: 0,
                    endRadius: 240
                )
            case .collageStory:
                Color(hex: "fbf5e8")
                LinearGradient(
                    colors: [
                        Color(hex: "fff8ec"),
                        Color(hex: "f1e7d2"),
                        Color(hex: "fbf5e8")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Canvas { context, size in
                    let line = Color(hex: "d9c9ad").opacity(0.18)
                    for index in 0..<11 {
                        let y = CGFloat(index) * 78 + 42
                        var path = Path()
                        path.move(to: CGPoint(x: 34, y: y))
                        path.addLine(to: CGPoint(x: size.width - 34, y: y + CGFloat(index % 2) * 3))
                        context.stroke(path, with: .color(line), lineWidth: 1)
                    }
                }
                RadialGradient(
                    colors: [Color(hex: "e7cfa5").opacity(0.24), Color.clear],
                    center: UnitPoint(x: 0.14, y: 0.16),
                    startRadius: 0,
                    endRadius: 320
                )
            case .cleanTexture:
                Color(hex: "f8fbf7")
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color(hex: "edf6ef"),
                        Color(hex: "f9fbf6")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [green.opacity(0.12), Color.clear],
                    center: UnitPoint(x: 0.98, y: 0.18),
                    startRadius: 0,
                    endRadius: 300
                )
            case .fullPhoto:
                Color(hex: "1c241f")
            case .customBackground:
                if let uiImage = customBackgroundImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardSize.width, height: cardSize.height)
                        .clipped()
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.88),
                            Color.white.opacity(0.72),
                            Color.white.opacity(0.84)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Color(hex: "f9fbf6").opacity(0.28)
                } else {
                    Color(hex: "f8fbf7")
                    LinearGradient(
                        colors: [Color.white.opacity(0.96), Color(hex: "edf6ef"), Color(hex: "f9fbf6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
    }

    private var warmLightLeafShadow: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Image(systemName: "leaf.fill")
                    .font(.system(size: CGFloat([44, 34, 28, 52, 24, 36, 30][index]), weight: .semibold))
                    .foregroundStyle(deepGreen.opacity(index < 3 ? 0.12 : 0.08))
                    .blur(radius: index < 3 ? 5 : 7)
                    .rotationEffect(.degrees(Double([18, -24, 42, -8, 28, -38, 12][index])))
                    .offset(
                        x: CGFloat([190, 224, 166, 238, 120, 204, 250][index]),
                        y: CGFloat([-396, -342, -302, -250, -214, -168, -110][index])
                    )
            }

            Circle()
                .fill(Color.white.opacity(0.34))
                .frame(width: 260, height: 260)
                .blur(radius: 42)
                .offset(x: 190, y: -312)
        }
        .allowsHitTesting(false)
    }

    private var lifeSlicePosterHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                brandLeafMark(size: 25, tint: deepGreen)
                Text("叙账")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.92))
            }

            Rectangle()
                .fill(muted.opacity(0.32))
                .frame(width: 1, height: 20)

            Text("生活记录")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(deepGreen.opacity(0.86))

            Spacer()
        }
    }

    private var lifeSlicePosterTitleBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(payload.periodText)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.86))

            Text(lifeSlicePosterHeadline)
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .fixedSize(horizontal: false, vertical: true)

            Text(lifeSlicePosterSubtitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))
                .lineSpacing(4)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
    }

    private var lifeSlicePosterPhotoGrid: some View {
        VStack(spacing: 14) {
            posterPrimaryPhoto
            HStack(spacing: 14) {
                posterSmallPhoto(index: 1)
                posterSmallPhoto(index: 2)
            }
        }
    }

    private var warmLightQuoteBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("“")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundStyle(deepGreen.opacity(0.35))
                .offset(y: -8)

            Text(warmLightPosterSubtitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ink.opacity(0.78))
                .lineSpacing(7)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            Text("”")
                .font(.system(size: 38, weight: .bold, design: .serif))
                .foregroundStyle(deepGreen.opacity(0.35))
                .offset(y: 34)
        }
    }

    private var warmLightSceneRibbon: some View {
        HStack(spacing: 8) {
            Text(warmLightSceneLabel)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Image(systemName: "leaf.fill")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.white.opacity(0.96))
        .padding(.horizontal, 22)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(deepGreen.opacity(0.84))
        )
        .frame(maxWidth: .infinity)
    }

    private var warmLightPhotoTriptych: some View {
        HStack(spacing: 13) {
            ForEach(0..<3, id: \.self) { index in
                posterVisualImage(posterVisualItem(at: index), index: index)
                    .frame(width: 150, height: 235)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.76), lineWidth: 1.4)
                    )
                    .shadow(color: deepGreen.opacity(0.08), radius: 13, x: 0, y: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var warmLightHandwrittenLine: some View {
        VStack(spacing: 6) {
            Text(warmLightPosterTagline)
                .font(chineseHandwritingFont(size: 21))
                .foregroundStyle(ink.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 6, y: size.height * 0.58))
                path.addCurve(
                    to: CGPoint(x: size.width - 8, y: size.height * 0.36),
                    control1: CGPoint(x: size.width * 0.28, y: size.height * 0.82),
                    control2: CGPoint(x: size.width * 0.72, y: size.height * 0.08)
                )
                context.stroke(path, with: .color(deepGreen.opacity(0.28)), lineWidth: 1.4)
            }
            .frame(height: 13)
        }
    }

    private var warmLightMetricBar: some View {
        HStack(spacing: 0) {
            warmLightMetricItem(icon: "pencil", value: "\(payload.recordCount)", label: "笔记录")
            warmLightMetricItem(icon: "calendar", value: "\(posterActiveDayCount)", label: "个记录日")
            warmLightMetricItem(icon: posterImageMetricIcon, value: posterImageMetricValue, label: posterImageMetricLabel)
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.66))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: deepGreen.opacity(0.07), radius: 14, x: 0, y: 8)
    }

    private func warmLightMetricItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.78))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ink.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    private var filmGrainOverlay: some View {
        Canvas { context, size in
            let fleck = Color.white.opacity(0.035)
            for index in 0..<90 {
                let x = CGFloat((index * 47) % 100) / 100 * size.width
                let y = CGFloat((index * 71) % 100) / 100 * size.height
                let rect = CGRect(x: x, y: y, width: CGFloat(index % 3 + 1), height: CGFloat(index % 2 + 1))
                context.fill(Path(ellipseIn: rect), with: .color(fleck))
            }
        }
        .allowsHitTesting(false)
    }

    private func filmSideRail(mark: String, alignLeading: Bool) -> some View {
        VStack(spacing: 12) {
            Text(mark)
                .font(.system(size: mark.count > 3 ? 9 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "c99a4f").opacity(0.88))
                .rotationEffect(.degrees(alignLeading ? -90 : 90))
                .frame(width: 22, height: 88)

            Spacer(minLength: 10)

            VStack(spacing: 12) {
                ForEach(0..<10, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(hex: "f7efe3").opacity(0.90))
                        .frame(width: 20, height: 12)
                }
            }

            Spacer(minLength: 10)

            Image(systemName: "triangle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "c99a4f").opacity(0.90))
                .rotationEffect(.degrees(alignLeading ? 0 : 180))
        }
        .frame(width: 36)
        .padding(.vertical, 34)
    }

    private var filmPerforation: some View {
        HStack {
            VStack(spacing: 11) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(hex: "f7efe3").opacity(0.78))
                        .frame(width: 11, height: 16)
                }
            }
            .padding(.leading, 10)

            Spacer(minLength: 0)

            VStack(spacing: 11) {
                ForEach(0..<7, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(hex: "f7efe3").opacity(0.78))
                        .frame(width: 11, height: 16)
                }
            }
            .padding(.trailing, 10)
        }
        .padding(.vertical, 18)
        .allowsHitTesting(false)
    }

    private var filmPosterFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 13, weight: .semibold))
            Text(posterSummaryMetricText)
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white.opacity(0.84))
    }

    @ViewBuilder
    private var singlePhotoCaptionBadge: some View {
        if let anchor = memoryAnchors.first {
            Text("\(anchor.createdAt.zhBillDateOnly) · \(posterCaption(anchor, fallback: "这天的一张记录"))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.58), Color.black.opacity(0.20)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(14)
        }
    }

    private var posterPrimaryPhoto: some View {
        posterPhotoCard(
            index: 0,
            fallbackCaption: "这一餐",
            height: 300,
            cornerRadius: 18,
            iconSize: 30
        )
    }

    private func posterSmallPhoto(index: Int) -> some View {
        posterPhotoCard(
            index: index,
            fallbackCaption: index == 1 ? "回家路上" : "这次买的东西",
            height: 126,
            cornerRadius: 14,
            iconSize: 28
        )
    }

    private func posterPhotoCard(
        index: Int,
        fallbackCaption: String,
        height: CGFloat,
        cornerRadius: CGFloat,
        iconSize: CGFloat
    ) -> some View {
        let item = posterVisualItem(at: index)
        return ZStack(alignment: .bottomLeading) {
            posterVisualImage(item, index: index)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            HStack(alignment: .center, spacing: 8) {
                Text(posterVisualCaption(item, fallback: fallbackCaption))
                    .font(.system(size: height > 200 ? 18 : 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                posterVisualIcon(item, size: iconSize)
            }
            .padding(.horizontal, height > 200 ? 18 : 14)
            .padding(.vertical, height > 200 ? 13 : 10)
            .background(Color.white.opacity(0.94))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 2)
        )
        .shadow(color: deepGreen.opacity(0.08), radius: 16, x: 0, y: 9)
    }

    private func collagePhoto(
        index: Int,
        fallback: String,
        size: CGSize,
        rotation: Double,
        offset: CGSize
    ) -> some View {
        let item = posterVisualItem(at: index)
        return VStack(alignment: .leading, spacing: 9) {
            posterVisualImage(item, index: index)
                .frame(width: size.width, height: size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(posterVisualCaption(item, fallback: fallback))
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(ink.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(10)
        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 9)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
    }

    private func collageTape(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(hex: "d8c099").opacity(0.58))
            .frame(width: width, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.white.opacity(0.36), lineWidth: 0.8)
            )
    }

    private func cleanPhotoRow(index: Int, fallback: String) -> some View {
        let item = posterVisualItem(at: index)
        return HStack(spacing: 12) {
            posterVisualImage(item, index: index)
                .frame(width: 178, height: 116)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(posterCleanRowTitle(item, fallback: fallback))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(posterCleanRowDetail(item))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(muted.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(height: 136)
        .background(Color.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: deepGreen.opacity(0.05), radius: 12, x: 0, y: 7)
    }

    private func posterCleanRowTitle(_ item: PosterVisualItem, fallback: String) -> String {
        switch item {
        case .photo:
            return posterVisualCaption(item, fallback: fallback)
        case .story:
            return "按记录整理"
        case .keywords:
            return "本期关键词"
        case .rhythm:
            return "记录节奏"
        }
    }

    private func posterCleanRowDetail(_ item: PosterVisualItem) -> String {
        switch item {
        case .photo(let anchor):
            return anchor.createdAt.zhBillDateOnly
        case .story(let text), .rhythm(let text):
            return text
        case .keywords(let labels):
            return labels.prefix(3).joined(separator: " / ")
        }
    }

    private func lifeSlicePosterMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.82))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(muted.opacity(0.82))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func posterImage(_ anchor: SummaryMemoryAnchor?) -> some View {
        if let anchor, let preparedImage = preparedImagesByAnchorID[anchor.id] {
            ZStack {
                Image(uiImage: preparedImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .overlay(Color.white.opacity(0.10))

                Image(uiImage: preparedImage)
                    .resizable()
                    .scaledToFit()
            }
            .clipped()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        green.opacity(0.20),
                        Color(hex: "f4eadc"),
                        Color(hex: "e6f0e9")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 10) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 34, weight: .semibold))
                    Text("按记录整理")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(deepGreen.opacity(0.50))
            }
        }
    }

    @ViewBuilder
    private func posterVisualImage(_ item: PosterVisualItem, index: Int) -> some View {
        switch item {
        case .photo(let anchor):
            posterImage(anchor)
        case .story(let text):
            posterVisualTile(text: text, eyebrow: "记录片段", icon: "text.alignleft", index: index)
        case .keywords(let labels):
            posterKeywordTile(labels, index: index)
        case .rhythm(let text):
            posterVisualTile(text: text, eyebrow: periodLeadShort, icon: "calendar", index: index)
        }
    }

    private func posterVisualTile(text: String, eyebrow: String, icon: String, index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            posterVisualTileBackground(index: index)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .textCase(.uppercase)
                }
                .foregroundStyle(deepGreen.opacity(0.58))

                Spacer(minLength: 4)

                Text(text)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.86))
                    .lineSpacing(4)
                    .lineLimit(4)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private func posterKeywordTile(_ labels: [String], index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            posterVisualTileBackground(index: index)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .semibold))
                    Text("关键词")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .textCase(.uppercase)
                }
                .foregroundStyle(deepGreen.opacity(0.58))

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(labels.prefix(3), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ink.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private func posterVisualTileBackground(index: Int) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: index.isMultiple(of: 2) ? "f7efe2" : "edf4ed"),
                    green.opacity(index.isMultiple(of: 2) ? 0.12 : 0.18),
                    Color.white.opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                for line in 0..<5 {
                    let y = size.height * (0.18 + CGFloat(line) * 0.16)
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.10, y: y))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.92, y: y + CGFloat(line % 2 == 0 ? 6 : -5)),
                        control1: CGPoint(x: size.width * 0.34, y: y - 8),
                        control2: CGPoint(x: size.width * 0.68, y: y + 9)
                    )
                    context.stroke(path, with: .color(Color.white.opacity(0.18)), lineWidth: 1)
                }
            }
        }
    }

    private var lifeSlicePosterScenePills: some View {
        HStack(spacing: 30) {
            ForEach(posterSceneLabels, id: \.self) { label in
                HStack(spacing: 8) {
                    Image(systemName: posterSceneIcon(for: label))
                        .font(.system(size: 15, weight: .semibold))
                    Text(label)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(deepGreen.opacity(0.84))
                .padding(.horizontal, 15)
                .frame(height: 32)
                .background(Capsule(style: .continuous).fill(softGreen.opacity(0.62)))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var lifeSlicePosterReasonCard: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(Color(hex: "c3a36d"))
                .frame(width: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text("这张卡片怎么来的")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ink)
                Text(lifeSlicePosterReasonText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(muted.opacity(0.92))
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: deepGreen.opacity(0.05), radius: 16, x: 0, y: 8)
    }

    private var lifeSlicePosterFooter: some View {
        HStack(alignment: .center, spacing: 8) {
            Capsule(style: .continuous)
                .fill(deepGreen.opacity(0.54))
                .frame(width: 24, height: 4)
            Text(posterSummaryMetricText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))
            Spacer(minLength: 0)
        }
    }

    private var lifeSlicePosterBrandFooter: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 14, weight: .semibold))
            Text(posterSummaryMetricText)
                .font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white.opacity(0.90))
        .padding(.horizontal, 34)
        .frame(height: 64)
        .background(
            LinearGradient(
                colors: [
                    deepGreen.opacity(0.94),
                    green.opacity(0.86)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var lifeSlicePosterHeadline: String {
        posterCopy.title(for: style)
    }

    private var lifeSlicePosterSubtitle: String {
        posterCopy.subtitle(for: style)
    }

    private var warmLightPosterHeadline: String {
        posterCopy.title(for: style)
    }

    private var warmLightPosterSubtitle: String {
        posterCopy.subtitle(for: style)
    }

    private var warmLightPosterTagline: String {
        posterCopy.tagline
    }

    private var warmLightSceneLabel: String {
        posterCopy.sceneLabel
    }

    private var posterEvidenceText: String {
        memoryAnchors
            .map { anchor in
                [
                    anchor.title,
                    anchor.caption
                ].joined(separator: " ")
            }
            .joined(separator: " ")
    }

    private func chineseHandwritingFont(size: CGFloat) -> Font {
        let candidates = [
            "HanziPenSC-W3",
            "HanziPenSC-W5",
            "HanziPen SC",
            "KaitiSC-Regular",
            "Kaiti SC",
            "STKaiti"
        ]
        if let name = candidates.first(where: { UIFont(name: $0, size: size) != nil }) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .regular, design: .serif)
    }

    private var collagePosterSubtitle: String {
        posterCopy.subtitle(for: .collageStory)
    }

    private var magazinePosterSubtitle: String {
        posterCopy.subtitle(for: .magazine)
    }

    private var magazinePosterTagline: String {
        posterCopy.tagline
    }

    private var journalPosterHeadline: String {
        posterCopy.title(for: .journal)
    }

    private var journalPosterBody: String {
        posterCopy.subtitle(for: .journal)
    }

    private var filmPosterSubtitle: String {
        posterCopy.subtitle(for: .filmStory)
    }

    private var filmPosterHeadline: String {
        posterCopy.title(for: .filmStory).replacingOccurrences(of: "，", with: "，\n")
    }

    private var fullPhotoPosterHeadline: String {
        posterCopy.title(for: .fullPhoto)
    }

    private var fullPhotoPosterSubtitle: String {
        posterCopy.subtitle(for: .fullPhoto)
    }

    private var collagePosterTagline: String {
        posterCopy.tagline
    }

    private var cleanPosterSubtitle: String {
        posterCopy.subtitle(for: .cleanTexture)
    }

    private var customBackgroundPosterSubtitle: String {
        posterCopy.subtitle(for: .customBackground)
    }

    private var posterImageCount: Int {
        min(memoryAnchors.count, 3)
    }

    private var posterActiveDayCount: Int {
        let countedDays = payload.dailyCountTrend.filter { $0.1 > 0 }.count
        return max(payload.recordCount > 0 ? 1 : 0, countedDays)
    }

    private var posterPeriodTitle: String {
        let normalizedPeriod = payload.periodText
            .replacingOccurrences(of: " ~ ", with: "—")
            .replacingOccurrences(of: "~", with: "—")
        let kind = payload.periodText.contains("月") && !payload.periodText.contains("-") ? "月章" : "周记"
        return "\(kind) · \(normalizedPeriod)"
    }

    private var posterSummaryMetricText: String {
        "\(payload.recordCount) 笔记录 · \(posterActiveDayCount) 个记录日 · \(posterImageCount) 张照片"
    }

    private var posterImageMetricIcon: String {
        posterImageCount > 0 ? "photo" : "text.alignleft"
    }

    private var posterImageMetricValue: String {
        "\(posterImageCount)"
    }

    private var posterImageMetricLabel: String {
        "张照片"
    }

    private var posterImageMetricText: String {
        "\(posterImageCount) 张照片"
    }

    private var periodLeadShort: String {
        payload.periodText.contains("月") && !payload.periodText.contains("-") ? "这个月" : "这周"
    }

    private var posterVisualItems: [PosterVisualItem] {
        var items = memoryAnchors.prefix(3).map { PosterVisualItem.photo($0) }
        for tile in posterFallbackTiles {
            guard items.count < 3 else { break }
            items.append(tile)
        }
        return Array(items.prefix(3))
    }

    private var posterFallbackTiles: [PosterVisualItem] {
        let keywords = Array(posterSceneLabels.prefix(3))
        let keywordTile = PosterVisualItem.keywords(keywords.isEmpty ? posterRecordKeywordLabels : keywords)
        let storyTile = PosterVisualItem.story(posterFactStoryText)
        let rhythmTile = PosterVisualItem.rhythm(posterRhythmText)

        switch posterImageCount {
        case 0:
            return [storyTile, rhythmTile, keywordTile]
        case 1:
            return [storyTile, keywordTile, rhythmTile]
        case 2:
            return [storyTile, keywordTile]
        default:
            return []
        }
    }

    private var posterFactStoryText: String {
        let label = posterSceneLabels.first ?? ""
        if label == "饮料" { return "\(periodLeadShort)买过的一瓶饮料。" }
        if label == "一餐" { return "\(periodLeadShort)吃过的一餐。" }
        if label == "通勤" { return "\(periodLeadShort)路上的一段。" }
        if label == "添置" { return "\(periodLeadShort)买过的一件东西。" }
        if label == "聚会" { return "\(periodLeadShort)见过的人和事。" }
        if !label.isEmpty { return "\(periodLeadShort)的\(label)记录。" }
        return "\(periodLeadShort)共 \(payload.recordCount) 笔记录。"
    }

    private var posterRhythmText: String {
        let activeDays = payload.dailyCountTrend.filter { $0.1 > 0 }.count
        if activeDays > 0 {
            return "\(periodLeadShort)有 \(activeDays) 天，留下了记录。"
        }
        if payload.recordCount > 0 {
            return "\(periodLeadShort)有 \(payload.recordCount) 笔记录。"
        }
        return "\(periodLeadShort)暂时还没有记录。"
    }

    private var posterSceneLabels: [String] {
        let labels = memoryAnchors.map(\.label).filter { !$0.isEmpty } + payload.categorySlices.map(\.label)
        var seen = Set<String>()
        return labels.compactMap { raw in
            let label = posterNormalizedSceneLabel(raw)
            guard !label.isEmpty,
                  !posterIsWeakSceneLabel(label),
                  seen.insert(label).inserted else { return nil }
            return label
        }
        .prefix(3)
        .map { $0 }
    }

    private var posterRecordKeywordLabels: [String] {
        let activeDays = payload.dailyCountTrend.filter { $0.1 > 0 }.count
        var labels: [String] = []
        if payload.recordCount > 0 {
            labels.append("\(payload.recordCount)笔记录")
        }
        if activeDays > 0 {
            labels.append("\(activeDays)天有记录")
        }
        let top = posterNormalizedSceneLabel(payload.topCategory)
        if !top.isEmpty && !posterIsWeakSceneLabel(top) {
            labels.append(top)
        }
        return Array(labels.prefix(3))
    }

    private func posterVisualItem(at index: Int) -> PosterVisualItem {
        let items = posterVisualItems
        if items.indices.contains(index) {
            return items[index]
        }
        return .story(posterFactStoryText)
    }

    private func posterCaption(_ anchor: SummaryMemoryAnchor?, fallback: String) -> String {
        guard let anchor else { return fallback }
        return lifeSliceSafeSharePhotoCaption(for: anchor, fallback: fallback)
    }

    private func posterVisualCaption(_ item: PosterVisualItem, fallback: String) -> String {
        switch item {
        case .photo(let anchor):
            return posterCaption(anchor, fallback: fallback)
        case .story(let text), .rhythm(let text):
            return text
        case .keywords(let labels):
            return labels.prefix(3).joined(separator: " / ")
        }
    }

    private func posterVisualFootnote(_ item: PosterVisualItem) -> String {
        switch item {
        case .photo(let anchor):
            return anchor.createdAt.zhBillDateOnly
        case .story:
            return "记录片段"
        case .keywords:
            return "本期关键词"
        case .rhythm:
            return payload.periodText
        }
    }

    private var lifeSlicePosterReasonText: String {
        let scenes = posterSceneLabels.prefix(3).joined(separator: "、")
        guard !scenes.isEmpty else {
            return "这张卡片来自\(periodLeadShort)的 \(payload.recordCount) 笔记录。\n系统按类别、日期和画面自动排版。"
        }
        return "这张卡片来自\(periodLeadShort)的记录：\(scenes)。\n系统按照片、类别和记录时间自动排版。"
    }

    private func posterPhotoIcon(_ anchor: SummaryMemoryAnchor?, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(green.opacity(0.18))
                .frame(width: size, height: size)
            Image(systemName: posterSceneIcon(for: anchor?.label ?? "生活"))
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(deepGreen.opacity(0.76))
        }
    }

    @ViewBuilder
    private func posterVisualIcon(_ item: PosterVisualItem, size: CGFloat) -> some View {
        switch item {
        case .photo(let anchor):
            posterPhotoIcon(anchor, size: size)
        case .story:
            posterPhotoIcon(nil, size: size)
        case .keywords:
            ZStack {
                Circle()
                    .fill(green.opacity(0.18))
                    .frame(width: size, height: size)
                Image(systemName: "tag.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(deepGreen.opacity(0.76))
            }
        case .rhythm:
            ZStack {
                Circle()
                    .fill(green.opacity(0.18))
                    .frame(width: size, height: size)
                Image(systemName: "calendar")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(deepGreen.opacity(0.76))
            }
        }
    }

    private func posterNormalizedSceneLabel(_ raw: String) -> String {
        if raw.contains("可乐") || raw.contains("饮料") || raw.contains("饮品") || raw.contains("咖啡") || raw.contains("奶茶") { return "饮料" }
        if raw.contains("餐") || raw.contains("饭") || raw.contains("菜") || raw.contains("面") || raw.contains("食堂") { return "一餐" }
        if raw.contains("见面") || raw.contains("朋友") || raw.contains("聚会") { return "聚会" }
        if raw.contains("现场") || raw.contains("体验") { return "体验" }
        if raw.contains("通勤") || raw.contains("交通") || raw.contains("公交") || raw.contains("地铁") || raw.contains("路") { return "通勤" }
        if raw.contains("家") || raw.contains("居家") || raw.contains("日用") || raw.contains("添") || raw.contains("购物") { return "添置" }
        if raw.contains("健康") || raw.contains("照护") { return "照护" }
        if raw.contains("住宿") || raw.contains("旅行") || raw.contains("出行") { return "出行" }
        if raw.contains("娱乐") || raw.contains("放松") { return "放松" }
        return raw
    }

    private func posterIsWeakSceneLabel(_ label: String) -> Bool {
        ["体验", "日常", "生活", "现场", "记录", "回看"].contains(label)
    }

    private func posterSceneIcon(for label: String) -> String {
        if label.contains("饮料") || label.contains("饮品") || label.contains("咖啡") || label.contains("奶茶") { return "cup.and.saucer.fill" }
        if label.contains("餐") || label.contains("饭") || label.contains("菜") || label.contains("面") { return "fork.knife" }
        if label.contains("见面") || label.contains("朋友") || label.contains("聚会") { return "person.2.fill" }
        if label.contains("现场") || label.contains("体验") { return "ticket.fill" }
        if label.contains("通勤") || label.contains("交通") || label.contains("公交") || label.contains("地铁") || label.contains("路") { return "bus.fill" }
        if label.contains("家") || label.contains("居家") || label.contains("日用") || label.contains("添") || label.contains("购物") { return "bag" }
        if label.contains("健康") || label.contains("照护") { return "cross.case.fill" }
        if label.contains("住宿") || label.contains("旅行") || label.contains("出行") { return "figure.walk" }
        if label.contains("娱乐") || label.contains("放松") { return "sparkles" }
        return "leaf.fill"
    }

    private func brandLeafMark(size: CGFloat, tint: Color) -> some View {
        Image(systemName: "leaf")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(tint.opacity(0.92))
            .rotationEffect(.degrees(-18))
    }

    private var storySelection: SignalSelectionPolicyResult {
        LifeStorySignalService.selectionPolicy(for: payload)
    }

    private var backdropProfile: LifeStoryVisualProfile {
        LifeStorySignalService.shareVisualProfile(from: payload)
    }

    private var storyGradient: LinearGradient {
        let colors: [Color]
        switch backdropProfile {
        case .rain:
            colors = [theme.rainAccent.opacity(0.22), theme.backgroundMid, theme.backgroundEnd]
        case .travel:
            colors = [theme.travelAccent.opacity(0.22), theme.backgroundMid, theme.backgroundEnd]
        case .lateCity:
            colors = [theme.cityAccent.opacity(0.20), theme.backgroundMid, theme.backgroundEnd]
        case .warmDaily:
            colors = [theme.accent.opacity(0.18), theme.backgroundMid, theme.backgroundEnd]
        case .fitness:
            colors = [theme.accent.opacity(0.20), theme.backgroundMid, theme.backgroundEnd]
        case .social:
            colors = [theme.accentDeep.opacity(0.17), theme.backgroundMid, theme.backgroundEnd]
        case .defaultSoft:
            colors = [theme.backgroundStart, theme.backgroundMid, theme.backgroundEnd]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var storyProfileHalo: some View {
        ZStack {
            switch backdropProfile {
            case .rain:
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 180, height: 180)
                    .blur(radius: 38)
                    .offset(x: 104, y: -118)
            case .travel:
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 220, height: 96)
                    .blur(radius: 28)
                    .rotationEffect(.degrees(-16))
                    .offset(x: 90, y: -96)
            case .lateCity:
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 160, height: 160)
                    .blur(radius: 44)
                    .offset(x: 112, y: -132)
            case .warmDaily:
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 200, height: 200)
                    .blur(radius: 42)
                    .offset(x: -96, y: -90)
            case .fitness:
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 170, height: 170)
                    .blur(radius: 36)
                    .offset(x: 96, y: -84)
            case .social:
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 230, height: 104)
                    .blur(radius: 30)
                    .rotationEffect(.degrees(10))
                    .offset(x: -82, y: -88)
            case .defaultSoft:
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .offset(x: 88, y: -104)
            }
        }
        .allowsHitTesting(false)
    }

    private var storyPaperStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "e9f1e8").opacity(0.70))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(deepGreen.opacity(0.08), lineWidth: 1)
                )
                .rotationEffect(.degrees(-3.2))
                .offset(x: -18, y: 24)
                .shadow(color: deepGreen.opacity(0.10), radius: 18, x: 0, y: 10)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "f0f5ea").opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.56), lineWidth: 1)
                )
                .rotationEffect(.degrees(2.6))
                .offset(x: 17, y: 17)
                .shadow(color: deepGreen.opacity(0.09), radius: 16, x: 0, y: 9)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: "fbfaf1").opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(deepGreen.opacity(0.07), lineWidth: 1)
                )
                .rotationEffect(.degrees(-0.9))
                .offset(x: -7, y: 9)
                .shadow(color: deepGreen.opacity(0.08), radius: 14, x: 0, y: 7)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(paper.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.70), lineWidth: 1)
                )
                .shadow(color: deepGreen.opacity(0.16), radius: 26, x: 0, y: 16)
        }
    }

    private var storyFactSlip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周最强信号")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(storyAccent.opacity(0.76))

            Text(storyHeadlineText)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineSpacing(5)
                .lineLimit(3)
                .minimumScaleFactor(0.64)
                .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(.share, radius: 22, tint: storyAccent)
        .rotationEffect(.degrees(-1.2))
    }

    private var storyHeroPanel: some View {
        ZStack(alignment: .bottomTrailing) {
            storyFactSlip
                .padding(.trailing, 10)

            if shouldShowStoryCareSlip {
                storyCareSlip
                    .frame(width: 232, alignment: .leading)
                    .offset(x: 4, y: 14)
            }
        }
        .padding(.bottom, shouldShowStoryCareSlip ? 18 : 0)
    }

    private var storyCareSlip: some View {
        Text(storySceneLine)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(deepGreen.opacity(0.92))
            .lineSpacing(4)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurface(.trace, radius: 20, tint: storyAccent)
            .rotationEffect(.degrees(1.4))
    }

    private var storySignalPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("留下来的线索")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(muted.opacity(0.82))
            if !shouldShowStoryCareSlip,
               let anchor = storyPictureLine,
               !anchor.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("这周最具体的一格")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(muted.opacity(0.82))
                    Text(anchor)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.82))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }

            HStack(spacing: 8) {
                ForEach(Array(storySignals.enumerated()), id: \.offset) { _, signal in
                    storySignalPill(signal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(backdropProfile == .lateCity ? 0.38 : 0.44))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(storyAccent.opacity(0.18), lineWidth: 1)
        )
    }

    private var storyHeadlineText: String {
        LifeStorySignalService.shareHeadline(from: payload)
    }

    private var storyPictureLine: String? {
        LifeStorySignalService.sharePictureLine(from: payload)
    }

    private var storySceneLine: String {
        storyPictureLine ?? payload.insight.care
    }

    private var shouldShowStoryCareSlip: Bool {
        guard let picture = storyPictureLine else { return false }
        return !storyHeadlineText.contains(picture) && picture.count <= 36
    }

    private var storySignals: [LifeStorySignal] {
        var ranked: [LifeStorySignal] = []
        if let primary = storySelection.primary?.signal {
            ranked.append(primary)
        }
        ranked.append(contentsOf: storySelection.supports.map(\.signal))
        if ranked.isEmpty {
            ranked = storySignalSource
        }
        if storyPictureLine != nil {
            return ranked.filter { $0.kind != .scene }.prefix(3).map { $0 }
        }
        return ranked.prefix(3).map { $0 }
    }

    private var storySignalSource: [LifeStorySignal] {
        LifeStorySignalService.weeklyShareSignals(from: payload, limit: 5)
    }

    private func storySignalPill(_ signal: LifeStorySignal) -> some View {
        HStack(spacing: 5) {
            if signal.symbol.count == 1 || signal.symbol.count == 2 {
                Text(signal.symbol)
                    .font(.system(size: 11))
            } else {
                Image(systemName: signal.symbol)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(signal.label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(storyAccent.opacity(backdropProfile == .rain ? 0.98 : 0.94))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(backdropProfile == .lateCity ? 0.50 : 0.56))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(storyAccent.opacity(0.14), lineWidth: 0.8)
        )
    }

    private var storyDataRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(storyDetailRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(green.opacity(0.44))
                        .frame(width: 7, height: 7)
                    Text(row)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.40))
                )
            }
        }
    }

    private var storyDataPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("真实证据")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(muted.opacity(0.82))
            storyDataRows
        }
    }

    private var storyDetailRows: [String] {
        let activeDays = max(1, payload.dailyCountTrend.filter { $0.1 > 0 }.count)
        let topRatio = Int((payload.topCategoryRatio * 100).rounded())
        var rows: [String] = [
            "\(activeDays) 天有记录",
            "\(payload.topCategory) 占比 \(topRatio)%"
        ]

        if storySelection.primary?.signal.kind != .lifeMark,
           let lifeMark = normalizedShareLine(payload.lifeMarkLine) {
            rows.append("生活线索：\(lifeMark)")
        }
        if storySelection.primary?.signal.kind != .emotion,
           let emotion = normalizedShareLine(payload.emotionLine) {
            rows.append("情绪标签：\(emotion)")
        }
        if let firstTag = payload.insight.tags
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") })
            .first(where: { !$0.isEmpty }) {
            rows.append(firstTag)
        }

        var seen = Set<String>()
        return rows.filter { row in
            if let picture = storyPictureLine, row.contains(picture) {
                return false
            }
            guard !seen.contains(row) else { return false }
            seen.insert(row)
            return true
        }
        .prefix(3)
        .map { $0 }
    }

    private var storyAccent: Color {
        switch backdropProfile {
        case .rain:
            return rainGreen
        case .travel:
            return travelGold
        case .lateCity:
            return cityIndigo
        case .warmDaily:
            return deepGreen
        case .fitness:
            return Color(hex: "5c9d74")
        case .social:
            return Color(hex: "af7b61")
        case .defaultSoft:
            return deepGreen
        }
    }

    private func normalizedShareLine(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let text = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "这周留下：", with: "")
            .replacingOccurrences(of: "这个月留下：", with: "")
            .replacingOccurrences(of: "这周留下了一笔「", with: "")
            .replacingOccurrences(of: "这个月留下了一笔「", with: "")
            .replacingOccurrences(of: "」。", with: "")
            .replacingOccurrences(of: "」", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    func snapshot() -> UIImage? {
        let size = cardSize
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
