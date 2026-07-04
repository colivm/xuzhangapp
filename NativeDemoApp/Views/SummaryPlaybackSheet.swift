import SwiftUI
import UIKit

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

struct SummaryPlaybackSheet: View {
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
    @State private var activeIndex = 0
    @State private var isPlaying = true
    @State private var playbackDone = false
    @State private var completionReported = false
    @State private var playbackTask: Task<Void, Never>?
    @State private var isSavingShareCard = false
    @State private var shareSaveMessage: String?
    @State private var memorySaveMessage: String?
    @State private var showShareCardPrivacyConfirm = false

    private var currentChapter: SummaryChapter? {
        guard !playback.chapters.isEmpty else { return nil }
        return playback.chapters[min(activeIndex, playback.chapters.count - 1)]
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
        .animation(.easeInOut(duration: 0.28), value: currentChapter?.id)
        .animation(.easeInOut(duration: 0.20), value: memorySaveMessage)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: showShareCardPrivacyConfirm)
        .onAppear {
            startPlayback()
        }
        .onChange(of: isPlaying) { _, newValue in
            newValue ? startPlayback() : playbackTask?.cancel()
        }
        .onDisappear {
            reportCompletionIfNeeded(progress: progressFraction)
            playbackTask?.cancel()
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
                    showShareCardPrivacyConfirm = false
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

                HStack(spacing: 12) {
                    Button {
                        showShareCardPrivacyConfirm = false
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

                    Button {
                        showShareCardPrivacyConfirm = false
                        saveWeeklyStoryCard()
                    } label: {
                        Label("保存到相册", systemImage: "photo.badge.checkmark")
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
                    .disabled(isSavingShareCard)
                    .opacity(isSavingShareCard ? 0.62 : 1)
                }
            }
            .padding(22)
            .frame(maxWidth: 370)
            .background(shareCardPrivacyCardBackground)
            .overlay(shareCardPrivacyCardBorder)
            .shadow(color: Color(red: 47/255, green: 67/255, blue: 58/255).opacity(0.18), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 24)
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
                    Text(playback.range == .week ? "本周章节" : "本月章节")
                        .font(.system(size: 12, weight: .bold))
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
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text(playback.teaserLine)
                    .font(.system(size: 13, weight: .medium))
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
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
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
        LifeStorySignalService.chapterSignals(from: chapter)
            .map { (symbol: $0.symbol, text: $0.label) }
    }

    @ViewBuilder
    private var memoryAnchorGallery: some View {
        if !playback.memoryAnchors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(playback.range == .week ? "这一周留下的画面" : "这个月的代表画面")
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
                if let uiImage = UIImage(data: anchor.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 206, height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    MemoryAttachmentThumbnail(imageData: anchor.imageData, height: 132, cornerRadius: 18)
                        .frame(width: 206)
                }

                Text(anchor.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color.black.opacity(0.28)))
                    .padding(10)
            }
            .shadow(color: AppColors.subtext.opacity(0.12), radius: 12, x: 0, y: 8)

            Text(anchor.caption)
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
                return "生活印记：\(lifeMarkLine)"
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
                return "生活印记：\(lifeMarkLine)"
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton

                Button {
                    showShareCardPrivacyConfirm = true
                } label: {
                    Label("保存本周故事图", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(weeklySharePayload == nil || isSavingShareCard ? AppColors.subtext.opacity(0.64) : AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
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
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onOpenInsight?()
                    }
                } label: {
                    Text("想多聊一句？")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())
            } else {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton
            }

            if playback.range == .month {
                Button {
                    onOpenWeekly?()
                    dismiss()
                } label: {
                    Text("先看本周")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
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

            if playback.range == .week {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton

                Button {
                    showShareCardPrivacyConfirm = true
                } label: {
                    Label("保存本周故事图", systemImage: "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(weeklySharePayload == nil || isSavingShareCard ? AppColors.subtext.opacity(0.64) : AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
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

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onOpenInsight?()
                    }
                } label: {
                    Text("想多聊一句？")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())
            } else {
                Button {
                    handlePrimaryDoneAction()
                } label: {
                    Text(primaryDoneTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PurposefulCardButtonStyle())

                memoryLineButton
            }

            if playback.range == .month {
                Button {
                    onOpenWeekly?()
                    dismiss()
                } label: {
                    Text("先看本周")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
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
                    .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
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
        if isMember {
            return playback.range == .week ? "本周回放已完成" : "本月回放已完成"
        }
        return memberPitch?.headline ?? (playback.range == .week ? "本周回放已完成" : "本月回放已完成")
    }

    private var doneDetail: String? {
        guard !isMember else { return nil }
        return memberPitch?.detail
    }

    private var primaryDoneTitle: String {
        if isMember {
            return playback.range == .week ? "下周再来" : "再看一遍"
        }
        return memberPitch?.cta ?? "了解会员"
    }

    private func handlePrimaryDoneAction() {
        if isMember {
            playback.range == .month ? restartPlayback() : dismiss()
        } else {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onShowMemberPricing?()
            }
        }
    }

    private func saveWeeklyStoryCard() {
        guard let payload = weeklySharePayload, !isSavingShareCard else { return }
        let card = WeeklyStoryShareCardView(
            payload: payload,
            memoryAnchors: playback.memoryAnchors,
            isPetMode: petEnabled,
            nickname: shareNickname.isEmpty ? "叙账用户" : shareNickname,
            theme: shareCardTheme
        )
        guard let image = card.snapshot() else { return }
        isSavingShareCard = true
        shareSaveMessage = nil
        Task {
            do {
                try await PhotoLibrarySaveService.shared.saveImageToLibrary(image)
                shareSaveMessage = "已保存到相册。"
            } catch {
                shareSaveMessage = (error as? LocalizedError)?.errorDescription ?? "暂时没保存成功。请检查相册权限后再试。"
            }
            isSavingShareCard = false
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

private struct WeeklyStoryShareCardView: View {
    let payload: WeeklyShareCardPayload
    let memoryAnchors: [SummaryMemoryAnchor]
    var isPetMode: Bool = true
    var nickname: String = "叙账用户"
    var theme: WeeklyStoryShareCardTheme = .journal

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

    var body: some View {
        ZStack {
            lifeSlicePosterBackground

            VStack(alignment: .leading, spacing: 0) {
                lifeSlicePosterHeader
                    .padding(.top, 30)

                lifeSlicePosterTitleBlock
                    .padding(.top, 26)

                lifeSlicePosterPhotoGrid
                    .padding(.top, 18)

                lifeSlicePosterScenePills
                    .padding(.top, 16)

                lifeSlicePosterReasonCard
                    .padding(.top, 16)

                Spacer(minLength: 8)

                lifeSlicePosterFooter
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 28)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipped()
    }

    private var lifeSlicePosterBackground: some View {
        ZStack {
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
        }
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

            Text("生活切片")
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

    private var posterPrimaryPhoto: some View {
        posterPhotoCard(
            anchor: posterAnchor(at: 0),
            fallbackCaption: "和朋友的一次聚会",
            height: 300,
            cornerRadius: 18,
            iconSize: 30
        )
    }

    private func posterSmallPhoto(index: Int) -> some View {
        posterPhotoCard(
            anchor: posterAnchor(at: index),
            fallbackCaption: index == 1 ? "回家路上" : "给家里添的",
            height: 126,
            cornerRadius: 14,
            iconSize: 28
        )
    }

    private func posterPhotoCard(
        anchor: SummaryMemoryAnchor?,
        fallbackCaption: String,
        height: CGFloat,
        cornerRadius: CGFloat,
        iconSize: CGFloat
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            posterImage(anchor)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()

            HStack(alignment: .center, spacing: 8) {
                Text(posterCaption(anchor, fallback: fallbackCaption))
                    .font(.system(size: height > 200 ? 18 : 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)

                posterPhotoIcon(anchor, size: iconSize)
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

    @ViewBuilder
    private func posterImage(_ anchor: SummaryMemoryAnchor?) -> some View {
        if let anchor, let uiImage = UIImage(data: anchor.imageData) {
            ZStack {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .overlay(Color.white.opacity(0.10))

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
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
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .semibold))
                    Text("等待一张生活画面")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(deepGreen.opacity(0.50))
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
                Text("这几张为什么被留下")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ink)
                Text("它们代表这周的几种生活场景。\n每周只留少量画面，方便以后回看与回想。")
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
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(deepGreen.opacity(0.88))
                    .frame(width: 38, height: 38)
                    .overlay(brandLeafMark(size: 24, tint: Color.white.opacity(0.92)))
                Text("来自叙账")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.84))
            }

            Text("|")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(muted.opacity(0.42))

            Text("\(payload.recordCount) 笔记录")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))

            Text("·")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(muted.opacity(0.62))

            Text("\(posterImageCount) 张画面")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(muted.opacity(0.92))

            Text("·")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(muted.opacity(0.62))

            Text(payload.recordCount > 0 ? "周回放" : "回放")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink.opacity(0.80))

            Spacer(minLength: 6)

            appStoreQRCodePlaceholder
        }
    }

    private var appStoreQRCodePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
                .frame(width: 62, height: 62)
                .shadow(color: deepGreen.opacity(0.10), radius: 10, x: 0, y: 5)
            posterQRCodePattern
                .frame(width: 50, height: 50)
        }
        .accessibilityLabel("App Store 下载二维码预留位")
    }

    private var posterQRCodePattern: some View {
        Canvas { context, size in
            let cells = 17
            let cell = size.width / CGFloat(cells)
            let dark = Color.black.opacity(0.88)
            func drawSquare(x: Int, y: Int, w: Int) {
                let rect = CGRect(
                    x: CGFloat(x) * cell,
                    y: CGFloat(y) * cell,
                    width: CGFloat(w) * cell,
                    height: CGFloat(w) * cell
                )
                context.fill(Path(rect), with: .color(dark))
            }
            func finder(x: Int, y: Int) {
                drawSquare(x: x, y: y, w: 5)
                context.fill(
                    Path(CGRect(x: CGFloat(x + 1) * cell, y: CGFloat(y + 1) * cell, width: 3 * cell, height: 3 * cell)),
                    with: .color(Color.white)
                )
                drawSquare(x: x + 2, y: y + 2, w: 1)
            }
            finder(x: 0, y: 0)
            finder(x: 12, y: 0)
            finder(x: 0, y: 12)
            for y in 0..<cells {
                for x in 0..<cells {
                    guard (x > 5 || y > 5),
                          (x < 12 || y > 5),
                          (x > 5 || y < 12) else { continue }
                    if ((x * 7 + y * 11 + x * y) % 5 == 0) || ((x + y) % 11 == 0) {
                        drawSquare(x: x, y: y, w: 1)
                    }
                }
            }
        }
    }

    private var lifeSlicePosterHeadline: String {
        let count = max(1, posterImageCount)
        let period = payload.periodText.contains("月") && !payload.periodText.contains("-") ? "这个月" : "这一周"
        return "\(period)，被\(chineseNumeral(count))张画面留住"
    }

    private var lifeSlicePosterSubtitle: String {
        "有些钱花完就过去了，\n有些会把路上、见面和照护留在账本里。"
    }

    private var posterImageCount: Int {
        3
    }

    private var posterSceneLabels: [String] {
        var labels = memoryAnchors.map(\.label).filter { !$0.isEmpty }
        if labels.isEmpty {
            labels = payload.categorySlices.map(\.label)
        }
        labels.append(contentsOf: ["聚餐", "通勤", "添置"])
        var seen = Set<String>()
        return labels.compactMap { raw in
            let label = posterNormalizedSceneLabel(raw)
            guard !label.isEmpty, seen.insert(label).inserted else { return nil }
            return label
        }
        .prefix(3)
        .map { $0 }
    }

    private func posterAnchor(at index: Int) -> SummaryMemoryAnchor? {
        memoryAnchors.indices.contains(index) ? memoryAnchors[index] : nil
    }

    private func posterCaption(_ anchor: SummaryMemoryAnchor?, fallback: String) -> String {
        guard let anchor else { return fallback }
        let caption = anchor.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return caption.isEmpty ? fallback : caption
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

    private func posterNormalizedSceneLabel(_ raw: String) -> String {
        if raw.contains("餐") || raw.contains("饭") || raw.contains("饮") || raw.contains("咖啡") { return "聚餐" }
        if raw.contains("通勤") || raw.contains("交通") || raw.contains("公交") || raw.contains("地铁") || raw.contains("路") { return "通勤" }
        if raw.contains("家") || raw.contains("居家") || raw.contains("日用") || raw.contains("添") || raw.contains("购物") { return "添置" }
        if raw.contains("健康") || raw.contains("照护") { return "照护" }
        if raw.contains("住宿") || raw.contains("旅行") || raw.contains("出行") { return "出行" }
        if raw.contains("娱乐") || raw.contains("放松") { return "放松" }
        return raw
    }

    private func posterSceneIcon(for label: String) -> String {
        if label.contains("餐") || label.contains("饭") || label.contains("饮") || label.contains("咖啡") { return "fork.knife" }
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

    private func chineseNumeral(_ value: Int) -> String {
        switch value {
        case 1: return "一"
        case 2: return "两"
        case 3: return "三"
        case 4: return "四"
        case 5: return "五"
        case 6: return "六"
        case 7: return "七"
        case 8: return "八"
        case 9: return "九"
        default: return "\(value)"
        }
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
            rows.append("生活印记：\(lifeMark)")
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
