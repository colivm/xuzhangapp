import SwiftUI

private struct TodaySwipeDragState: Equatable {
    let itemID: UUID
    let translation: CGFloat
}

private enum PetBubbleSource: Equatable {
    case savedRecord
    case tap
    case interactionHint
    case idle

    var isAutomatic: Bool {
        self == .interactionHint || self == .idle
    }
}

private struct PetBubblePresentation: Identifiable, Equatable {
    let id: UUID
    let message: String
    let source: PetBubbleSource
}

private enum TodayPlaybackPrompt: Equatable {
    case firstRecord
    case firstUse
    case quotaExhausted(String)

    var title: String {
        switch self {
        case .firstRecord:
            return "第一笔已经记好"
        case .firstUse:
            return "今日回放，适合晚一点听"
        case .quotaExhausted:
            return "今天的免费回放已用完"
        }
    }

    func message(remaining: Int) -> String {
        switch self {
        case .firstRecord:
            if remaining <= 0 {
                return "第一笔已经放进账本。今天的免费回放次数已用完，仍可以继续记录。"
            }
            return "可以继续记，也可以现在听一遍今天。只有点播放后，才会使用一次今日回放。"
        case .firstUse:
            return ExperienceRuleCopy.todayPlaybackFirstUseMessage(remaining: remaining)
        case .quotaExhausted(let message):
            return message
        }
    }
}

private struct HighConfidenceCommuteFloatingCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let suggestion: HomeViewModel.HighConfidenceQuickRecordSuggestion
    let weatherKind: String?
    let isPulsing: Bool
    let onClose: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Image(suggestion.backgroundImageName)
                .resizable()
                .scaledToFill()
                .saturation(0.42)
                .brightness(0.04)
                .contrast(0.82)
                .opacity(0.52)

            commuteImageScrim
            commuteRouteOverlay

            if let weatherKind {
                CommuteQuickCardWeatherLayer(kind: weatherKind)
            }

            quickCardLightSweep

            HStack(spacing: 12) {
                commuteGlyph

                VStack(alignment: .leading, spacing: 7) {
                    Text(suggestion.headline)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(suggestion.amountSummaryText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.readableAccent)
                        .lineLimit(suggestion.secondaryTitle == nil ? 1 : 2)
                        .minimumScaleFactor(0.82)

                    Text(suggestion.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.readableSubtext)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 2)

                VStack(spacing: 8) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.readableSubtext)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(AppColors.panelStrong.opacity(0.84)))
                            .overlay(Circle().stroke(AppColors.line.opacity(0.52), lineWidth: 1))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")

                    Button(action: onSave) {
                        Text(suggestion.buttonTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.onAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(width: 108, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(AppColors.accent)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
                            )
                            .shadow(color: AppColors.accent.opacity(0.16), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .padding(.vertical, 14)
        }
        .frame(height: 128)
        .background(AppColors.panelStrong)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(quickCardBorder)
        .overlay(quickCardGlint)
        .shadow(color: AppColors.subtext.opacity(0.12), radius: 18, x: 0, y: 10)
        .shadow(color: AppColors.accent.opacity(isMotionPulsing ? 0.12 : 0.03), radius: isMotionPulsing ? 14 : 6, x: 0, y: 0)
        .offset(y: isMotionPulsing ? -2 : 1)
        .scaleEffect(isMotionPulsing ? 1.006 : 0.998)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: isMotionPulsing)
    }

    private var isMotionPulsing: Bool {
        isPulsing && !reduceMotion
    }

    private var commuteGlyph: some View {
        Image(systemName: weatherKind == "rain" ? "cloud.rain.fill" : weatherKind == "snow" ? "snowflake" : "tram.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppColors.readableAccent)
            .frame(width: 44, height: 44)
            .background(Circle().fill(AppColors.panelStrong.opacity(0.82)))
            .overlay(Circle().stroke(AppColors.accent.opacity(0.18), lineWidth: 1))
    }

    private var commuteImageScrim: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.panelStrong.opacity(0.88),
                    AppColors.panel.opacity(0.72),
                    AppColors.paperWarm.opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.34),
                    AppColors.panelStrong.opacity(0.40),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            LinearGradient(
                colors: [
                    AppColors.accent.opacity(0.10),
                    Color.clear,
                    AppColors.bg.opacity(0.14)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
    }

    private var commuteRouteOverlay: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var mainRoute = Path()
            mainRoute.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.70))
            mainRoute.addCurve(
                to: CGPoint(x: size.width * 0.88, y: size.height * 0.28),
                control1: CGPoint(x: size.width * 0.28, y: size.height * 0.44),
                control2: CGPoint(x: size.width * 0.56, y: size.height * 0.86)
            )
            context.stroke(
                mainRoute,
                with: .linearGradient(
                    Gradient(colors: [
                        AppColors.accent.opacity(0.05),
                        AppColors.accent.opacity(0.20),
                        Color.white.opacity(0.08)
                    ]),
                    startPoint: CGPoint(x: 0, y: size.height),
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
            )

            var secondaryRoute = Path()
            secondaryRoute.move(to: CGPoint(x: size.width * 0.18, y: size.height * 0.18))
            secondaryRoute.addCurve(
                to: CGPoint(x: size.width * 0.96, y: size.height * 0.62),
                control1: CGPoint(x: size.width * 0.38, y: size.height * 0.10),
                control2: CGPoint(x: size.width * 0.62, y: size.height * 0.52)
            )
            context.stroke(
                secondaryRoute,
                with: .color(AppColors.readableSubtext.opacity(0.10)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [5, 8])
            )

            for point in [
                CGPoint(x: size.width * 0.18, y: size.height * 0.58),
                CGPoint(x: size.width * 0.48, y: size.height * 0.62),
                CGPoint(x: size.width * 0.76, y: size.height * 0.38)
            ] {
                let outer = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
                let inner = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
                context.fill(Path(ellipseIn: outer), with: .color(AppColors.accent.opacity(0.10)))
                context.fill(Path(ellipseIn: inner), with: .color(AppColors.accent.opacity(0.30)))
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private var quickCardLightSweep: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(isMotionPulsing ? 0.10 : 0.03),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 84)
        .rotationEffect(.degrees(18))
        .offset(x: isMotionPulsing ? 210 : -190)
        .blur(radius: 1.4)
        .allowsHitTesting(false)
    }

    private var quickCardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.58),
                        AppColors.accent.opacity(isMotionPulsing ? 0.24 : 0.14),
                        AppColors.line.opacity(0.46)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var quickCardGlint: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(isMotionPulsing ? 0.20 : 0.06), lineWidth: 1.2)
            .blur(radius: isMotionPulsing ? 0.2 : 1)
            .allowsHitTesting(false)
    }
}

private struct CommuteQuickCardWeatherLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: String

    var body: some View {
        if reduceMotion {
            weatherBody(time: 0)
                .allowsHitTesting(false)
        } else {
            TimelineView(.periodic(from: Date(), by: 1 / 12)) { timeline in
                weatherBody(time: timeline.date.timeIntervalSinceReferenceDate)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func weatherBody(time: TimeInterval) -> some View {
        if kind == "rain" {
            rainLayer(time: time)
                .opacity(reduceMotion ? 0.30 : 0.58)
        } else if kind == "snow" {
            snowLayer(time: time)
                .opacity(reduceMotion ? 0.30 : 0.52)
        }
    }

    private func rainLayer(time: TimeInterval) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for index in 0..<34 {
                let seed = Double(index)
                let lane = (seed * 41).truncatingRemainder(dividingBy: 100) / 100
                let speed = 0.36 + (seed * 11).truncatingRemainder(dividingBy: 17) / 42
                let progress = (time * speed + seed * 0.067).truncatingRemainder(dividingBy: 1)
                let length = 15 + (seed * 7).truncatingRemainder(dividingBy: 14)
                let x = lane * size.width + progress * size.height * 0.18 - 22
                let y = progress * (size.height + 48) - 30
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + length * 0.30, y: y + length))
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(0.30)),
                    style: StrokeStyle(lineWidth: index.isMultiple(of: 4) ? 1.25 : 0.85, lineCap: .round)
                )
            }
        }
    }

    private func snowLayer(time: TimeInterval) -> some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for index in 0..<24 {
                let seed = Double(index)
                let lane = (seed * 29).truncatingRemainder(dividingBy: 100) / 100
                let speed = 0.12 + (seed * 5).truncatingRemainder(dividingBy: 11) / 70
                let progress = (time * speed + seed * 0.053).truncatingRemainder(dividingBy: 1)
                let drift = sin(time * 0.55 + seed) * 8
                let radius = 1.3 + (seed.truncatingRemainder(dividingBy: 4)) * 0.35
                let rect = CGRect(
                    x: lane * size.width + drift,
                    y: progress * (size.height + 36) - 18,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.42)))
            }
        }
    }
}

struct HomeView: View {
    private enum SheetDismissRoute {
        case memoryDetail(HomeItem)
        case attachMemoryImage(HomeItem)
        case memberPricing
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onQuickRecord: (RecordEntryMode) -> Void = { _ in }
    var onNavigateWeeklyTrace: (() -> Void)? = nil
    var onNavigateMonthlyTrace: (() -> Void)? = nil
    var onNavigateInsight: (() -> Void)? = nil
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    var onAttachMemoryImage: ((HomeItem) -> Void)? = nil
    var firstRecordPromptRequestID: UUID? = nil
    var isExternalPostSavePresentationActive = false
    var onFirstRecordPromptCompleted: ((Bool) -> Void)? = nil
    @State private var playbackPresentation: TodayPlaybackPresentationPayload?
    @State private var firstRecordPromptFlowIsActive = false
    @State private var completeFirstRecordPromptAfterPlayback = false
    @State private var showTodayRecordsSheet = false
    @State private var editingItem: HomeItem?
    @State private var memoryDetailItem: HomeItem?
    @State private var playbackDismissRoute: SheetDismissRoute?
    @State private var todayRecordsDismissRoute: SheetDismissRoute?
    @State private var editingDismissRoute: SheetDismissRoute?
    @State private var memoryDetailDismissRoute: SheetDismissRoute?
    @State private var todayInlineEditingItemID: UUID?
    @State private var todaySwipedItemID: UUID?
    @State private var todayDeletingItemID: UUID?
    @State private var todayPendingDeleteItem: HomeItem?
    @State private var showTodayDeleteConfirmation = false
    @State private var todayPlaybackPrompt: TodayPlaybackPrompt?
    @State private var petBubblePresentation: PetBubblePresentation?
    @State private var petBubbleDismissTask: Task<Void, Never>?
    @State private var petMessageRequestTask: Task<Void, Never>?
    @State private var petMessageRequestID: UUID?
    @State private var petAutomaticSpeechTask: Task<Void, Never>?
    @State private var petAutomaticSpeechRequestID: UUID?
    @State private var petAutomaticPresentationCount = 0
    @State private var hasPresentedPetIdleMessageInSession = false
    @State private var pendingPetSavedMessage: String?
    @State private var isHomeVisible = false
    @State private var petTapAnimationTrigger = 0
    @State private var petHiddenNotice: String?
    @State private var petHiddenNoticeID: UUID?
    @State private var todayBillsFocusPulse = false
    @State private var todayBillsFocusTick = 0
    @State private var highlightedSavedItemID: UUID?
    @State private var quickRecordCardDismissedID: String?
    @State private var quickRecordCardAutoCloseID: String?
    @State private var quickRecordCardPulse = false
    @State private var quickRecordSaveMessage: String?
    @State private var quickRecordWeatherRefreshTick = 0
    @GestureState private var todaySwipeDragState: TodaySwipeDragState?
    private let dailyQuotaStore = DailyFeatureQuotaStore()
    private let summaryQuotaStore = SummaryPlaybackQuotaStore()
    private static let todayPlaybackFirstUsePromptSeenKey = "today_playback_first_use_prompt_seen_v1"

    private var todayInlineEditingItem: HomeItem? {
        guard let todayInlineEditingItemID else { return nil }
        return homeViewModel.todayItems.first { $0.id == todayInlineEditingItemID }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    homeContent
                }
                .scrollDisabled(todaySwipeDragState != nil)
                .onChange(of: todayBillsFocusTick) { _, _ in
                    withAnimation(.easeInOut(duration: 0.38)) {
                        proxy.scrollTo("todayBillsPanel", anchor: .center)
                    }
                }
            }

            if shouldShowHighConfidenceQuickRecord {
                highConfidenceQuickRecordOverlay
                    .zIndex(12)
            }

            if todayPlaybackPrompt != nil {
                todayPlaybackPromptOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
            }

            if settingsViewModel.petCompanionEnabled,
               !isExternalPostSavePresentationActive,
               todayPlaybackPrompt == nil {
                MovablePixelPetOverlay(
                    message: petBubblePresentation?.message,
                    isSpeaking: petBubbleVisible,
                    tapTrigger: petTapAnimationTrigger,
                    onTap: handlePetTap,
                    onHide: hidePetCompanion
                )
                    .zIndex(16)
            }

            if let petHiddenNotice {
                Text(petHiddenNotice)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                    .overlay(Capsule(style: .continuous).stroke(AppColors.line.opacity(0.62), lineWidth: 1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 106)
                    .transition(.opacity)
                    .zIndex(17)
            }

        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .onAppear {
            isHomeVisible = true
            petAutomaticPresentationCount = 0
            hasPresentedPetIdleMessageInSession = false
            presentFirstRecordPromptIfNeeded()
            homeViewModel.prepareHomeDashboardSnapshots(
                isMember: settingsViewModel.settings.hasMemberAccess,
                clearsStaleQuickRecord: true
            )
            resumePetMessageFlowIfPossible()
        }
        .onChange(of: homeViewModel.activeRouteGuidance) { _, guidance in
            handleRouteGuidance(guidance)
        }
        .onChange(of: firstRecordPromptRequestID) { _, _ in
            presentFirstRecordPromptIfNeeded()
        }
        .onChange(of: isExternalPostSavePresentationActive) { _, isActive in
            if isActive {
                pausePetMessageFlow()
            } else {
                presentFirstRecordPromptIfNeeded()
                resumePetMessageFlowIfPossible()
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            homeViewModel.prepareHomeDashboardSnapshots(
                isMember: settingsViewModel.settings.hasMemberAccess,
                now: now
            )
        }
        .onChange(of: homeViewModel.homeDashboardRevision) { _, _ in
            homeViewModel.prepareHomeDashboardSnapshots(
                isMember: settingsViewModel.settings.hasMemberAccess
            )
        }
        .onChange(of: settingsViewModel.settings.hasMemberAccess) { _, isMember in
            homeViewModel.prepareHomeDashboardSnapshots(isMember: isMember)
        }
        .onChange(of: settingsViewModel.petCompanionEnabled) { _, enabled in
            if !enabled {
                pendingPetSavedMessage = nil
                pausePetMessageFlow()
            } else {
                resumePetMessageFlowIfPossible()
            }
        }
        .onChange(of: todayPlaybackPrompt) { _, prompt in
            if prompt != nil {
                pausePetMessageFlow()
            } else {
                resumePetMessageFlowIfPossible()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            handleHomeScenePhaseChange(phase)
        }
        .onChange(of: canPresentPetBubble) { _, canPresent in
            if canPresent {
                resumePetMessageFlowIfPossible()
            } else {
                pausePetMessageFlow()
            }
        }
        .onChange(of: voiceOverEnabled) { _, _ in
            restartAutomaticPetSpeechIfNeeded()
        }
        .onChange(of: homeViewModel.petMessage) { _, message in
            guard let message else { return }
            homeViewModel.petMessage = nil
            guard settingsViewModel.petCompanionEnabled else { return }

            if canPresentPetBubble,
               petBubblePresentation?.source.isAutomatic == true {
                dismissPetBubble(resumesMessageFlow: false)
            }
            guard presentPetBubble(message, source: .savedRecord) else {
                pendingPetSavedMessage = message
                cancelAutomaticPetSpeech()
                return
            }
        }
        .onDisappear {
            isHomeVisible = false
            pendingPetSavedMessage = nil
            pausePetMessageFlow(animated: false)
        }
        .sheet(item: $playbackPresentation, onDismiss: {
            let route = playbackDismissRoute
            playbackDismissRoute = nil
            handleSheetDismissRoute(route)
            if completeFirstRecordPromptAfterPlayback {
                completeFirstRecordPromptAfterPlayback = false
                finishFirstRecordPromptFlow(continuesRecording: false)
            }
        }) { presentation in
            BillPlaybackSheet(
                contentSnapshot: presentation.contentSnapshot,
                onNavigateToSettings: { onNavigateSettings?() },
                onShowMemberPricing: {
                    playbackDismissRoute = .memberPricing
                    playbackPresentation = nil
                }
            )
                .environmentObject(homeViewModel)
        }
        .sheet(isPresented: $showTodayRecordsSheet, onDismiss: {
            let route = todayRecordsDismissRoute
            todayRecordsDismissRoute = nil
            handleSheetDismissRoute(route)
        }) {
            todayRecordsSheet
        }
        .sheet(item: $editingItem, onDismiss: {
            let route = editingDismissRoute
            editingDismissRoute = nil
            handleSheetDismissRoute(route)
        }) { item in
            editSheet(for: item)
        }
        .sheet(item: $memoryDetailItem, onDismiss: {
            let route = memoryDetailDismissRoute
            memoryDetailDismissRoute = nil
            handleSheetDismissRoute(route)
        }) { item in
            memoryRecordDetailSheet(for: item)
        }
    }

    private var homeContent: some View {
        VStack(spacing: 10) {
            todayStoryHero
            homeActionRow
            todayBillsPanel
            lifeRhythmPanel
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var homeActionRow: some View {
        let primary = homeJourneyPrimaryAction
        let secondary = HomeJourneyActionPolicy.secondaryAction(
            for: primary,
            hasTodayRecords: !homeViewModel.todayItems.isEmpty
        )
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                homeJourneyActionCard(primary, isPrimary: true)
                if let secondary {
                    homeJourneyActionCard(secondary, isPrimary: false)
                }
            }

            VStack(spacing: 10) {
                homeJourneyActionCard(primary, isPrimary: true)
                if let secondary {
                    homeJourneyActionCard(secondary, isPrimary: false)
                }
            }
        }
    }

    private var homeJourneyPrimaryAction: HomeJourneyAction {
        let now = Date()
        let ledgerFacts = homeViewModel.homeJourneyLedgerFacts
        let hasUnplayedTodayRecords = dailyQuotaStore.hasUnplayedTodayItems(homeViewModel.todayItems, now: now)
        let isMember = settingsViewModel.settings.hasMemberAccess
        let day = Calendar.current.component(.day, from: now)
        let progressionStage = NewUserProgressionPolicy.stage(
            for: NewUserProgressionSnapshot(
                totalRecordCount: ledgerFacts.totalCommittedRecordCount,
                hasUnplayedTodayRecords: hasUnplayedTodayRecords,
                weekRecordCount: ledgerFacts.currentWeekCommittedRecordCount,
                weekActiveDayCount: ledgerFacts.currentWeekActiveDayCount,
                monthRecordCount: ledgerFacts.currentMonthCommittedRecordCount,
                monthActiveDayCount: ledgerFacts.currentMonthActiveDayCount,
                dayOfMonth: day,
                canPlayWeek: summaryQuotaStore.canPlay(.week, isMember: isMember, now: now),
                canPlayMonth: summaryQuotaStore.canPlay(.month, isMember: isMember, now: now),
                hasCompletedCurrentWeekPlayback: summaryQuotaStore.hasCompletedCurrentWeekPlayback(now: now),
                hasCompletedCurrentMonthPlayback: summaryQuotaStore.hasCompletedCurrentMonthPlayback(now: now)
            )
        )
        return HomeJourneyActionPolicy.primaryAction(
            for: HomeJourneySnapshot(
                hasOCRDrafts: !homeViewModel.ocrDraftItems.isEmpty,
                hasManualDraft: !homeViewModel.inputAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                todayRecordCount: homeViewModel.todayItems.count,
                hasUnplayedTodayRecords: hasUnplayedTodayRecords,
                weekTraceReady: progressionStage == .weekTrace,
                monthTraceReady: progressionStage == .monthChapter
            ),
            progressionStage: progressionStage
        )
    }

    private var shouldShowHighConfidenceQuickRecord: Bool {
        guard !isExternalPostSavePresentationActive,
              todayPlaybackPrompt == nil,
              !firstRecordPromptFlowIsActive else {
            return false
        }
        let primaryAction = homeJourneyPrimaryAction
        return primaryAction == .record || primaryAction == .continueRecording
    }

    private func homeJourneyActionCard(_ action: HomeJourneyAction, isPrimary: Bool) -> some View {
        homeActionCard(
            title: homeJourneyTitle(action),
            subtitle: homeJourneySubtitle(action),
            systemImage: homeJourneySystemImage(action),
            isPrimary: isPrimary,
            action: { performHomeJourneyAction(action) }
        )
    }

    private func homeJourneyTitle(_ action: HomeJourneyAction) -> String {
        switch action {
        case .resumeOCR: return "继续整理账单"
        case .continueManualDraft: return "继续这笔草稿"
        case .record: return "记下一笔"
        case .todayPlayback: return "听今日回放"
        case .weekTrace: return "看看本周痕迹"
        case .monthTrace: return "回顾这个月"
        case .review: return "做一次复盘"
        case .continueRecording: return "继续记录"
        }
    }

    private func homeJourneySubtitle(_ action: HomeJourneyAction) -> String {
        switch action {
        case .resumeOCR:
            return "待整理区还有 \(homeViewModel.ocrDraftItems.count) 笔"
        case .continueManualDraft:
            return "金额和已填内容都还在"
        case .record:
            return homeViewModel.quickRecordNudgeText
        case .todayPlayback:
            return todayPlaybackActionSubtitle
        case .weekTrace:
            let count = homeViewModel.homeJourneyLedgerFacts.currentWeekCommittedRecordCount
            return "本周已有 \(count) 笔可回看"
        case .monthTrace:
            return "把这个月整理成一章"
        case .review:
            return "查记录、做对比，或补上遗漏"
        case .continueRecording:
            let facts = homeViewModel.homeJourneyLedgerFacts
            return PlaybackMaturityPolicy.homeRecommendationExplanation(
                weekRecordCount: facts.currentWeekCommittedRecordCount,
                weekActiveDayCount: facts.currentWeekActiveDayCount,
                monthRecordCount: facts.currentMonthCommittedRecordCount,
                monthActiveDayCount: facts.currentMonthActiveDayCount,
                dayOfMonth: Calendar.current.component(.day, from: Date())
            )
        }
    }

    private func homeJourneySystemImage(_ action: HomeJourneyAction) -> String {
        switch action {
        case .resumeOCR: return "tray.full.fill"
        case .continueManualDraft: return "pencil.line"
        case .record, .continueRecording: return "plus.circle.fill"
        case .todayPlayback: return "play.circle.fill"
        case .weekTrace: return "calendar.badge.clock"
        case .monthTrace: return "books.vertical.fill"
        case .review: return "checklist"
        }
    }

    private func performHomeJourneyAction(_ action: HomeJourneyAction) {
        switch action {
        case .resumeOCR:
            onQuickRecord(.ocr)
        case .continueManualDraft, .record, .continueRecording:
            onQuickRecord(.manual)
        case .todayPlayback:
            requestTodayPlayback()
        case .weekTrace:
            onNavigateWeeklyTrace?()
        case .monthTrace:
            onNavigateMonthlyTrace?()
        case .review:
            onNavigateInsight?()
        }
    }

    @ViewBuilder
    private var highConfidenceQuickRecordOverlay: some View {
        if let suggestion = homeViewModel.highConfidenceQuickRecordSuggestion,
           quickRecordCardDismissedID != suggestion.id {
            VStack(spacing: 8) {
                HighConfidenceCommuteFloatingCard(
                    suggestion: suggestion,
                    weatherKind: quickRecordWeatherKind,
                    isPulsing: quickRecordCardPulse,
                    onClose: { dismissQuickRecordCard(suggestion.id) },
                    onSave: {
                        if homeViewModel.addHighConfidenceQuickRecord(suggestion) {
                            quickRecordSaveMessage = "已补到今天的记录里"
                            dismissQuickRecordCard(suggestion.id)
                            todayBillsFocusTick += 1
                        } else {
                            quickRecordSaveMessage = homeViewModel.recordInputMessage ?? "这笔暂时没保存成功"
                            scheduleQuickRecordMessageClear(for: suggestion.id)
                        }
                    }
                )

                if let quickRecordSaveMessage {
                    Text(quickRecordSaveMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.text.opacity(0.86))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.78))
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
                .frame(maxWidth: 430)
                .padding(.horizontal, 12)
                .padding(.top, 206)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .id(suggestion.id)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    armQuickRecordCard(suggestion)
                }
        }
    }

    private var quickRecordWeatherKind: String? {
        _ = quickRecordWeatherRefreshTick
        guard settingsViewModel.settings.weatherCompanionEnabled,
              WeatherCompanionService.shared.hasLocationPermissionReady else {
            return nil
        }
        return RecordMemoryContextService.commuteCardWeatherKindCode(
            from: WeatherCompanionService.shared.cachedSnapshot
        )
    }

    private func armQuickRecordCard(_ suggestion: HomeViewModel.HighConfidenceQuickRecordSuggestion) {
        quickRecordCardAutoCloseID = suggestion.id
        quickRecordCardPulse = false
        if settingsViewModel.settings.weatherCompanionEnabled,
           WeatherCompanionService.shared.hasLocationPermissionReady {
            WeatherCompanionService.shared.refreshWeatherInBackground(refreshGeo: false, forceWeather: true)
            scheduleQuickRecordWeatherRefresh(for: suggestion.id, delay: 1.2)
            scheduleQuickRecordWeatherRefresh(for: suggestion.id, delay: 3.0)
        }
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                quickRecordCardPulse = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 18.0) {
            guard quickRecordCardAutoCloseID == suggestion.id,
                  quickRecordCardDismissedID != suggestion.id else {
                return
            }
            withAnimation(.easeInOut(duration: 0.24)) {
                quickRecordCardPulse = false
            }
        }
    }

    private func dismissQuickRecordCard(_ id: String) {
        withAnimation(.easeInOut(duration: 0.24)) {
            quickRecordCardDismissedID = id
            quickRecordCardAutoCloseID = nil
            quickRecordCardPulse = false
            quickRecordSaveMessage = nil
        }
    }

    private func scheduleQuickRecordMessageClear(for id: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard quickRecordCardDismissedID != id else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                quickRecordSaveMessage = nil
            }
        }
    }

    private func scheduleQuickRecordWeatherRefresh(for id: String, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard quickRecordCardAutoCloseID == id,
                  quickRecordCardDismissedID != id else {
                return
            }
            quickRecordWeatherRefreshTick += 1
        }
    }

    private var todayPlaybackActionSubtitle: String {
        guard !homeViewModel.todayItems.isEmpty else { return "有记录后可播放" }
        guard !settingsViewModel.settings.hasMemberAccess else { return "十几秒叙完今天" }
        return ExperienceRuleCopy.todayPlaybackActionSubtitle(remaining: todayPlaybackRemaining(isMember: false))
    }

    private var todayBillsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天留下的痕迹")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AppColors.text)
            todayBillsContent
        }
        .recordSurface(radius: 20, padding: 20, tint: AppColors.accent)
        .overlay(todayBillsFocusOverlay)
        .id("todayBillsPanel")
    }

    @ViewBuilder
    private var todayBillsContent: some View {
        if homeViewModel.recentThreeItems.isEmpty {
            VStack(spacing: 0) {
                emptyStateArt
                    .padding(.vertical, 8)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(homeViewModel.recentThreeItems.enumerated()), id: \.element.id) { index, item in
                    billListItem(
                        item: item,
                        isFirst: index == 0,
                        isHighlighted: highlightedSavedItemID == item.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openRecord(item)
                    }
                }
                if homeViewModel.todayItems.count > homeViewModel.recentThreeItems.count {
                    Button {
                        showTodayRecordsSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("查看今天全部 \(homeViewModel.todayItems.count) 笔")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.readableSubtext)
                        .padding(.top, 8)
                    }
                    .buttonStyle(.plain)
                    .minimumTapTarget()
                }
            }
        }
    }

    private var lifeRhythmPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近的生活")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AppColors.text)
            lifeRhythmContent
        }
        .traceSurface(radius: 18, padding: 18, tint: AppColors.accent)
    }

    @ViewBuilder
    private var lifeRhythmContent: some View {
        if let card = homeViewModel.latestActionCard, !card.text.isEmpty {
            Text(card.text)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.88))
            Text(card.updatedAt, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.readableSubtext)
        } else if homeViewModel.recentThreeItems.isEmpty {
            Text("先记几笔，这里会按时间显示最近记录。")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.readableSubtext)
        } else {
            lifeRhythmFallback
        }
    }

    private var lifeRhythmFallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            let daysWithRecords = countDaysWithRecords()
            if daysWithRecords > 0 {
                Text("已记录 \(daysWithRecords) 天")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.readableSubtext)
            }
            Text(lifeRhythmFallbackText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.readableSubtext)
        }
    }

    private var lifeRhythmFallbackText: String {
        if !homeViewModel.weekLifeThemeText.isEmpty {
            return homeViewModel.weekLifeThemeText
        }
        return homeViewModel.weekTopCategoryText != "暂无"
            ? "最近「\(homeViewModel.weekTopCategoryText)」记得多一点。"
            : "先记几笔，这里会长出最近的生活线索。"
    }

    private var todayStoryHero: some View {
        let narrative = homeViewModel.todayStoryNarrative
        return VStack(alignment: .leading, spacing: 10) {
            Text("今日小记")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.readableSubtext)

            Text(narrative.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(narrative.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.84))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    handleTodayTotalTap()
                } label: {
                    narrativePill(narrative.todayTotalText)
                }
                .buttonStyle(.plain)
                .minimumTapTarget()

                Button {
                    onNavigateWeeklyTrace?()
                } label: {
                    narrativePill(narrative.weekTotalText)
                }
                .buttonStyle(.plain)
                .minimumTapTarget()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .playbackSurface(radius: 22, padding: 22, tint: AppColors.accent)
    }

    private func narrativePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.readableSubtext)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(narrativePillBackground)
            .overlay(narrativePillBorder)
    }

    private var narrativePillBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.58))
    }

    private var narrativePillBorder: some View {
        Capsule(style: .continuous)
            .stroke(Color.white.opacity(0.46), lineWidth: 1)
    }

    private func homeActionCard(
        title: String,
        subtitle: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                homeActionIconBadge(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.readableSubtext)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .appSurface(.action, radius: 18, tint: AppColors.accent, isSelected: isPrimary)
        }
        .buttonStyle(PurposefulCardButtonStyle(radius: 18, depth: isPrimary ? 1.15 : 0.9))
    }

    private func homeActionIconBadge(systemImage: String) -> some View {
        Image(systemName: systemImage == "plus.circle.fill" ? "plus" : "play.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.readableAccent)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(AppColors.accent.opacity(0.16))
            )
            .overlay(
                Circle()
                    .stroke(AppColors.accent.opacity(0.20), lineWidth: 1)
            )
    }

    private var todayBillsFocusOverlay: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        AppColors.accent.opacity(todayBillsFocusPulse ? 0.68 : 0.0),
                        Color.white.opacity(todayBillsFocusPulse ? 0.72 : 0.0),
                        AppColors.accent.opacity(todayBillsFocusPulse ? 0.52 : 0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: todayBillsFocusPulse ? 2 : 0.5
            )
            .shadow(color: AppColors.accent.opacity(todayBillsFocusPulse ? 0.28 : 0), radius: 18, x: 0, y: 0)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.34), value: todayBillsFocusPulse)
    }

    private func handleTodayTotalTap() {
        guard !homeViewModel.todayItems.isEmpty else {
            onQuickRecord(.manual)
            return
        }

        if homeViewModel.todayItems.count > 3 {
            showTodayRecordsSheet = true
            return
        }

        todayBillsFocusTick += 1
        withAnimation(.easeInOut(duration: 0.2)) {
            todayBillsFocusPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeInOut(duration: 0.32)) {
                todayBillsFocusPulse = false
            }
        }
    }

    private func highlightSavedItem(_ itemID: UUID) {
        withAnimation(.easeInOut(duration: 0.22)) {
            highlightedSavedItemID = itemID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            guard highlightedSavedItemID == itemID else { return }
            withAnimation(.easeInOut(duration: 0.32)) {
                highlightedSavedItemID = nil
            }
        }
    }

    private func handleRouteGuidance(_ guidance: HomeViewModel.PlaybackRouteGuidance?) {
        guard guidance == .firstRecordTodayPlayback else { return }
        presentFirstRecordPromptIfNeeded()
    }

    private func presentFirstRecordPromptIfNeeded() {
        let hasPendingFirstRecordPrompt = firstRecordPromptRequestID != nil
            || homeViewModel.activeRouteGuidance == .firstRecordTodayPlayback
        guard hasPendingFirstRecordPrompt else { return }
        guard !homeViewModel.todayItems.isEmpty else {
            homeViewModel.consumeRouteGuidance(.firstRecordTodayPlayback)
            onFirstRecordPromptCompleted?(false)
            return
        }
        guard !isExternalPostSavePresentationActive,
              todayPlaybackPrompt == nil,
              !firstRecordPromptFlowIsActive else {
            return
        }
        firstRecordPromptFlowIsActive = true
        markTodayPlaybackFirstUsePromptSeen()
        homeViewModel.markTodayPlaybackPromptShown("first_record")
        withAnimation(.easeInOut(duration: 0.18)) {
            todayPlaybackPrompt = .firstRecord
        }
    }

    private func handleHomeScenePhaseChange(_ phase: ScenePhase) {
        guard phase == .active else {
            pausePetMessageFlow()
            return
        }
        homeViewModel.prepareHomeDashboardSnapshots(
            isMember: settingsViewModel.settings.hasMemberAccess,
            now: Date(),
            clearsStaleQuickRecord: true
        )
        resumePetMessageFlowIfPossible()
    }

    private func finishFirstRecordPromptFlow(continuesRecording: Bool) {
        guard firstRecordPromptFlowIsActive else { return }
        firstRecordPromptFlowIsActive = false
        homeViewModel.consumeRouteGuidance(.firstRecordTodayPlayback)
        onFirstRecordPromptCompleted?(continuesRecording)
    }

    private func requestTodayPlayback(allowsFirstUsePrompt: Bool = true) {
        guard !homeViewModel.todayItems.isEmpty else {
            presentTodayPlaybackSheet()
            return
        }
        let isMember = settingsViewModel.settings.hasMemberAccess
        let remaining = todayPlaybackRemaining(isMember: isMember)
        guard isMember || remaining > 0 else {
            todayPlaybackPrompt = .quotaExhausted(ExperienceRuleCopy.todayPlaybackExhaustedMessage(remaining: remaining))
            return
        }

        if allowsFirstUsePrompt && shouldShowTodayPlaybackFirstUsePrompt(isMember: isMember) {
            markTodayPlaybackFirstUsePromptSeen()
            homeViewModel.markTodayPlaybackPromptShown("first_use")
            todayPlaybackPrompt = .firstUse
            return
        }

        startTodayPlayback(isMember: isMember)
    }

    private func shouldShowTodayPlaybackFirstUsePrompt(isMember: Bool) -> Bool {
        !isMember && !UserDefaults.standard.bool(forKey: Self.todayPlaybackFirstUsePromptSeenKey)
    }

    private func markTodayPlaybackFirstUsePromptSeen() {
        UserDefaults.standard.set(true, forKey: Self.todayPlaybackFirstUsePromptSeenKey)
    }

    private func startTodayPlayback(isMember: Bool) {
        presentTodayPlaybackSheet(markStarted: true, isMember: isMember)
    }

    private func presentTodayPlaybackSheet(markStarted: Bool = false, isMember: Bool = false) {
        let snapshot = BillPlaybackSheet.makeContentSnapshot(
            allItems: homeViewModel.items,
            sourceRevision: homeViewModel.homeDashboardRevision
        )
        let candidate = TodayPlaybackPresentationPayload(contentSnapshot: snapshot)
        guard TodayPlaybackPresentationPolicy.accepts(candidate, while: playbackPresentation) else { return }

        playbackPresentation = candidate
        guard markStarted, TodayPlaybackPresentationPolicy.consumesQuota(candidate) else { return }
        dailyQuotaStore.markTodayPlaybackStarted(isMember: isMember)
        homeViewModel.markTodayPlaybackStarted()
    }

    private func todayPlaybackRemaining(isMember: Bool? = nil) -> Int {
        let member = isMember ?? settingsViewModel.settings.hasMemberAccess
        return dailyQuotaStore.todayPlaybackRemaining(isMember: member)
    }

    private var canStartTodayPlaybackNow: Bool {
        settingsViewModel.settings.hasMemberAccess || todayPlaybackRemaining(isMember: false) > 0
    }

    private func todayPlaybackQuotaText(remaining: Int? = nil) -> String {
        ExperienceRuleCopy.quotaText(
            remaining: remaining ?? todayPlaybackRemaining(isMember: false),
            limit: DailyFeatureQuotaStore.todayPlaybackFreeLimit
        )
    }

    private var todayPlaybackPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissTodayPlaybackPrompt()
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: todayPlaybackPrompt == .firstUse ? "clock.fill" : "play.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.readableAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(AppColors.accent.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(todayPlaybackPrompt?.title ?? "")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(todayPlaybackPrompt?.message(remaining: todayPlaybackRemaining()) ?? "")
                            .font(.system(size: 14, weight: .medium))
                            .lineSpacing(4)
                            .foregroundStyle(AppColors.readableSubtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        dismissTodayPlaybackPrompt(
                            continuesRecording: todayPlaybackPrompt == .firstRecord
                        )
                    } label: {
                        Text(
                            todayPlaybackPrompt == .firstRecord
                                ? "继续记"
                                : (todayPlaybackPrompt == .firstUse ? "晚点再说" : "知道了")
                        )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.surfaceMuted.opacity(0.78))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(AppColors.line.opacity(0.52), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        switch todayPlaybackPrompt {
                        case .firstRecord:
                            if canStartTodayPlaybackNow {
                                completeFirstRecordPromptAfterPlayback = true
                                dismissTodayPlaybackPrompt(completesFirstRecordFlow: false)
                                startTodayPlayback(isMember: settingsViewModel.settings.hasMemberAccess)
                            } else {
                                dismissTodayPlaybackPrompt()
                                onShowMemberPricing?()
                            }
                        case .firstUse:
                            dismissTodayPlaybackPrompt()
                            startTodayPlayback(isMember: settingsViewModel.settings.hasMemberAccess)
                        case .quotaExhausted:
                            dismissTodayPlaybackPrompt()
                            onShowMemberPricing?()
                        case .none:
                            dismissTodayPlaybackPrompt()
                        }
                    } label: {
                        Text(
                            todayPlaybackPrompt == .firstRecord
                                ? (canStartTodayPlaybackNow ? "听今日回放" : "了解不限回放")
                                : (todayPlaybackPrompt == .firstUse ? "现在听一遍" : "了解不限回放")
                        )
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.onAccent)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.accent)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.panelStrong.opacity(0.94),
                                AppColors.panel.opacity(0.90),
                                AppColors.surfaceMuted.opacity(0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppColors.line.opacity(0.78), lineWidth: 1)
            )
            .shadow(color: AppColors.text.opacity(0.10), radius: 24, y: 14)
            .padding(.horizontal, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: todayPlaybackPrompt != nil)
    }

    private func dismissTodayPlaybackPrompt(
        completesFirstRecordFlow: Bool = true,
        continuesRecording: Bool = false
    ) {
        let shouldCompleteFirstRecordFlow = todayPlaybackPrompt == .firstRecord && completesFirstRecordFlow
        withAnimation(.easeInOut(duration: 0.18)) {
            todayPlaybackPrompt = nil
        }
        if shouldCompleteFirstRecordFlow {
            finishFirstRecordPromptFlow(continuesRecording: continuesRecording)
        }
    }

    private var petBubbleVisible: Bool {
        petBubblePresentation != nil
    }

    private var isPetPresentationBlocked: Bool {
        isExternalPostSavePresentationActive
            || todayPlaybackPrompt != nil
            || firstRecordPromptFlowIsActive
            || playbackPresentation != nil
            || showTodayRecordsSheet
            || editingItem != nil
            || memoryDetailItem != nil
            || todayInlineEditingItemID != nil
            || showTodayDeleteConfirmation
    }

    private var canPresentPetBubble: Bool {
        isHomeVisible
            && settingsViewModel.petCompanionEnabled
            && !isPetPresentationBlocked
            && scenePhase == .active
    }

    private var canStartPetMessageFlow: Bool {
        canPresentPetBubble
            && petBubblePresentation == nil
            && petMessageRequestTask == nil
    }

    @discardableResult
    private func presentPetBubble(_ message: String, source: PetBubbleSource) -> Bool {
        guard canStartPetMessageFlow else { return false }
        petMessageRequestTask?.cancel()
        petMessageRequestTask = nil
        petMessageRequestID = nil
        cancelAutomaticPetSpeech()
        petBubbleDismissTask?.cancel()

        let presentation = PetBubblePresentation(
            id: UUID(),
            message: message,
            source: source
        )
        withAnimation(.easeInOut(duration: 0.24)) {
            petBubblePresentation = presentation
        }
        if source == .interactionHint {
            PetCompanionService.shared.markInteractionHintPresented()
        }
        if source.isAutomatic {
            petAutomaticPresentationCount += 1
            if source == .idle {
                hasPresentedPetIdleMessageInSession = true
            }
        }

        let visibleDuration: UInt64 = voiceOverEnabled ? 7_000_000_000 : 4_000_000_000
        petBubbleDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: visibleDuration)
            } catch {
                return
            }
            guard petBubblePresentation?.id == presentation.id else { return }
            dismissPetBubble(cancelRequest: false)
        }
        return true
    }

    private func dismissPetBubble(
        cancelRequest: Bool = true,
        animated: Bool = true,
        resumesMessageFlow: Bool = true
    ) {
        if cancelRequest {
            petMessageRequestTask?.cancel()
            petMessageRequestTask = nil
            petMessageRequestID = nil
        }
        petBubbleDismissTask?.cancel()
        petBubbleDismissTask = nil
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                petBubblePresentation = nil
            }
        } else {
            petBubblePresentation = nil
        }
        if resumesMessageFlow {
            resumePetMessageFlowIfPossible()
        }
    }

    private func cancelAutomaticPetSpeech() {
        petAutomaticSpeechTask?.cancel()
        petAutomaticSpeechTask = nil
        petAutomaticSpeechRequestID = nil
    }

    private func pausePetMessageFlow(animated: Bool = true) {
        cancelAutomaticPetSpeech()
        petMessageRequestTask?.cancel()
        petMessageRequestTask = nil
        petMessageRequestID = nil
        dismissPetBubble(cancelRequest: false, animated: animated, resumesMessageFlow: false)
    }

    private func restartAutomaticPetSpeechIfNeeded() {
        cancelAutomaticPetSpeech()
        resumePetMessageFlowIfPossible()
    }

    private func resumePetMessageFlowIfPossible() {
        guard canStartPetMessageFlow else { return }
        if let pendingPetSavedMessage {
            self.pendingPetSavedMessage = nil
            if !presentPetBubble(pendingPetSavedMessage, source: .savedRecord) {
                self.pendingPetSavedMessage = pendingPetSavedMessage
            }
            return
        }
        scheduleAutomaticPetSpeechIfNeeded()
    }

    private func scheduleAutomaticPetSpeechIfNeeded() {
        guard petAutomaticSpeechTask == nil,
              PetCompanionAutomaticSpeechPolicy.shouldSchedule(
                  isHomeVisible: isHomeVisible,
                  isSceneActive: scenePhase == .active,
                  isPetEnabled: settingsViewModel.petCompanionEnabled,
                  isPresentationBlocked: isPetPresentationBlocked,
                  hasBubble: petBubblePresentation != nil,
                  hasMessageRequest: petMessageRequestTask != nil,
                  hasPendingSavedMessage: pendingPetSavedMessage != nil
              ),
              let step = PetCompanionAutomaticSpeechPolicy.nextStep(
                  hasPresentedInteractionHint: PetCompanionService.shared.hasPresentedInteractionHint,
                  automaticPresentationCount: petAutomaticPresentationCount,
                  hasPresentedIdleMessageInSession: hasPresentedPetIdleMessageInSession,
                  voiceOverEnabled: voiceOverEnabled
              ) else {
            return
        }

        let requestID = UUID()
        petAutomaticSpeechRequestID = requestID
        petAutomaticSpeechTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: step.delayNanoseconds)
            } catch {
                return
            }
            guard petAutomaticSpeechRequestID == requestID else { return }
            petAutomaticSpeechTask = nil
            petAutomaticSpeechRequestID = nil
            guard canStartPetMessageFlow, pendingPetSavedMessage == nil else {
                resumePetMessageFlowIfPossible()
                return
            }

            let service = PetCompanionService.shared
            let message: String?
            let source: PetBubbleSource
            switch step.kind {
            case .interactionHint:
                message = service.interactionHintMessageIfNeeded(settings: settingsViewModel.settings)
                source = .interactionHint
            case .idle:
                message = service.idleMessage(
                    settings: settingsViewModel.settings,
                    todayItems: homeViewModel.todayItems
                )
                source = .idle
            }
            guard let message else {
                resumePetMessageFlowIfPossible()
                return
            }
            _ = presentPetBubble(message, source: source)
        }
    }

    private func handlePetTap() {
        if petBubblePresentation != nil || petMessageRequestTask != nil {
            dismissPetBubble()
            return
        }
        cancelAutomaticPetSpeech()
        if pendingPetSavedMessage != nil {
            resumePetMessageFlowIfPossible()
            return
        }
        guard canStartPetMessageFlow else { return }

        petTapAnimationTrigger &+= 1
        let service = PetCompanionService.shared
        if let hint = service.interactionHintMessageIfNeeded(settings: settingsViewModel.settings) {
            _ = presentPetBubble(hint, source: .interactionHint)
            return
        }

        let requestID = UUID()
        petMessageRequestID = requestID
        let settings = settingsViewModel.settings
        let items = homeViewModel.todayItems
        petMessageRequestTask = Task { @MainActor in
            let message = await service.petClickMessage(
                settings: settings,
                todayItems: items
            )
            guard !Task.isCancelled, petMessageRequestID == requestID else {
                return
            }
            petMessageRequestTask = nil
            petMessageRequestID = nil
            if pendingPetSavedMessage != nil {
                resumePetMessageFlowIfPossible()
                return
            }
            guard canStartPetMessageFlow, let message else {
                resumePetMessageFlowIfPossible()
                return
            }
            _ = presentPetBubble(message, source: .tap)
        }
    }

    private func hidePetCompanion() {
        pausePetMessageFlow()
        settingsViewModel.petCompanionEnabled = false
        let noticeID = UUID()
        petHiddenNoticeID = noticeID
        withAnimation(.easeInOut(duration: 0.18)) {
            petHiddenNotice = "宠物已休息，可在“我的”里重新开启"
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard petHiddenNoticeID == noticeID else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                petHiddenNotice = nil
            }
            petHiddenNoticeID = nil
        }
    }

    // MARK: - Empty State Art

    private var emptyStateArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.62))
                .frame(width: 68, height: 48)

            // Lines representing text
            Path { p in
                p.move(to: CGPoint(x: 40, y: 36))
                p.addLine(to: CGPoint(x: 80, y: 36))
                p.move(to: CGPoint(x: 40, y: 46))
                p.addLine(to: CGPoint(x: 72, y: 46))
                p.move(to: CGPoint(x: 40, y: 56))
                p.addLine(to: CGPoint(x: 64, y: 56))
            }
            .stroke(AppColors.subtext.opacity(0.26), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

            // Plus icon
            Path { p in
                p.move(to: CGPoint(x: 92, y: 24))
                p.addLine(to: CGPoint(x: 104, y: 24))
                p.move(to: CGPoint(x: 98, y: 18))
                p.addLine(to: CGPoint(x: 98, y: 30))
            }
            .stroke(AppColors.subtext.opacity(0.26), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        .frame(width: 96, height: 64)
        .opacity(0.72)
    }

    // MARK: - Bill List Item

    private func billListItem(item: HomeItem, isFirst: Bool, isHighlighted: Bool = false) -> some View {
        let accent = AppColors.categoryColor(item.category)
        return Group {
            if item.hasMemoryImages {
                homeMemoryBillCardV2(item: item, isHighlighted: isHighlighted)
            } else {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(accent.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)

                        HStack(spacing: 6) {
                            Text(item.category.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.readableSubtext)

                            Text("·")
                                .foregroundStyle(AppColors.readableSubtext)

                            Text(item.createdAt.zhBillTime)
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.readableSubtext)

                            if shouldShowHomeEmotion(for: item) {
                                Text("·")
                                    .foregroundStyle(AppColors.readableSubtext.opacity(0.72))
                                Text(item.displayEmotionTag)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppColors.readableAccent)
                                    .lineLimit(1)
                            }
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                        if let lifeMarkText = homeLifeMarkText(for: item) {
                            homeLifeMarkChip(lifeMarkText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 6)

                    Text(item.amount.formatted(.cny))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(1)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background {
                    if isHighlighted {
                        Color.clear
                            .themedInteractionSurface(
                                radius: 16,
                                tint: accent,
                                isSelected: true,
                                glowIntensity: 0.72
                            )
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if !isFirst && !item.hasMemoryImages {
                PaperCreaseDivider()
                    .padding(.top, -6)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isHighlighted)
    }

    private func homeMemoryBillCardV2(item: HomeItem, isHighlighted: Bool) -> some View {
        let accent = AppColors.categoryColor(item.category)
        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                MemoryAttachmentThumbnail(
                    imageData: item.coverMemoryImageData,
                    imageReference: item.coverMemoryImageReference,
                    height: 96,
                    cornerRadius: 0
                )
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.05),
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 18,
                                bottomLeading: 0,
                                bottomTrailing: 0,
                                topTrailing: 18
                            ),
                            style: .continuous
                        )
                    )

                if item.memoryImageCount > 1 {
                    Label("\(item.memoryImageCount)", systemImage: "photo.on.rectangle")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.34)))
                        .padding(10)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)

                    if shouldShowHomeEmotion(for: item) {
                        Text(item.displayEmotionTag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.readableAccent)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.08)))
                            .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.18), lineWidth: 0.7))
                    }

                    HStack(spacing: 6) {
                        Text(item.category.rawValue)
                        Text("·")
                        Text(item.createdAt.zhBillTime)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.readableSubtext)
                    .lineLimit(1)
                }

                Spacer(minLength: 10)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.86))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 12, y: 5)
        .padding(.vertical, 6)
        .padding(.horizontal, 1)
        .background {
            if isHighlighted {
                Color.clear
                    .themedInteractionSurface(
                        radius: 18,
                        tint: accent,
                        isSelected: true,
                        glowIntensity: 0.72
                    )
            }
        }
    }

    private func homeMemoryBillCard(item: HomeItem, imageData: Data, isHighlighted: Bool) -> some View {
        let accent = AppColors.categoryColor(item.category)
        return ZStack(alignment: .bottom) {
            MemoryAttachmentThumbnail(imageData: imageData, height: 86, cornerRadius: 14)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.10),
                            Color.black.opacity(0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                )

            if item.memoryImageCount > 1 {
                Text("\(item.memoryImageCount) 张")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(Color.black.opacity(0.30)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
            }

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.84)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("\(item.category.rawValue) · \(item.createdAt.zhBillTime)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .padding(7)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
        .background {
            if isHighlighted {
                Color.clear
                    .themedInteractionSurface(
                        radius: 16,
                        tint: accent,
                        isSelected: true,
                        glowIntensity: 0.72
                    )
            }
        }
    }

    private func countDaysWithRecords() -> Int {
        let calendar = Calendar.current
        let days = Set(homeViewModel.items.map { calendar.startOfDay(for: $0.createdAt) })
        return days.count
    }

    private var todayRecordsSheet: some View {
        NavigationStack {
            ZStack {
                todayRecordsGradientBackground
                    .ignoresSafeArea()

                ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button {
                                    todayInlineEditingItemID = nil
                                    todaySwipedItemID = nil
                                    showTodayRecordsSheet = false
                                } label: {
                                    Text("关闭")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppColors.text.opacity(0.86))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.white.opacity(0.78))
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(Color.white.opacity(0.68), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }

                            Text("今天留下的痕迹")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(AppColors.text)

                            Text("点任一条可调整")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.readableSubtext)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(homeViewModel.todayItems.enumerated()), id: \.element.id) { index, item in
                                    todayRecordInlineRow(item: item, isFirst: index == 0)
                                }
                            }
                            .opacity(todayInlineEditingItemID == nil ? 1 : 0.34)
                            .scaleEffect(todayInlineEditingItemID == nil ? 1 : 0.985, anchor: .top)
                            .allowsHitTesting(todayInlineEditingItemID == nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 78)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if todaySwipedItemID != nil {
                                withAnimation(todayEditSpring) {
                                    todaySwipedItemID = nil
                                }
                            }
                        }
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(todaySwipeDragState != nil || todayInlineEditingItemID != nil)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 18).onEnded { value in
                            guard todaySwipedItemID != nil else { return }
                            if abs(value.translation.height) > abs(value.translation.width) {
                                withAnimation(todayEditSpring) {
                                    todaySwipedItemID = nil
                                }
                            }
                        }
                    )

                todayFocusedRecordOverlay
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                todayRecordsFooterSummary
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "删除这条账单？",
            isPresented: $showTodayDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let todayPendingDeleteItem {
                    deleteTodayRecord(todayPendingDeleteItem)
                }
                todayPendingDeleteItem = nil
            }
            Button("取消", role: .cancel) {
                todayPendingDeleteItem = nil
            }
        } message: {
            Text("删除后不会保留在账本里。")
        }
        .onDisappear {
            todayInlineEditingItemID = nil
            todaySwipedItemID = nil
            todayPendingDeleteItem = nil
        }
    }

    private var todayRecordsMetaText: String {
        let total = homeViewModel.todayItems.reduce(0) { $0 + $1.amount }
        return "\(homeViewModel.todayItems.count) 笔 · 合计 \(total.formatted(.cny))"
    }

    private var todayFocusedRecordOverlay: some View {
        VStack(spacing: 0) {
            if let item = todayInlineEditingItem {
                FocusedRecordEditor(
                    item: item,
                    onSave: { updated in
                        let didSave = homeViewModel.updateItem(updated)
                        if didSave {
                            highlightSavedItem(updated.id)
                            withAnimation(todayEditSpring) {
                                todayInlineEditingItemID = nil
                                todaySwipedItemID = nil
                            }
                        }
                        return didSave
                    },
                    onCancel: {
                        withAnimation(todayEditSpring) {
                            todayInlineEditingItemID = nil
                            todaySwipedItemID = nil
                        }
                    },
                    onDelete: {
                        deleteTodayRecord(item)
                    },
                    onAttachMemoryImage: {
                        requestAttachMemoryImage(item, preservesInlineEditor: true)
                    },
                    onAttachMemoryImages: { imageDatas in
                        let didAttach = homeViewModel.attachMemoryImages(
                            imageDatas,
                            to: item.id,
                            coverImageIndex: 0,
                            anchorReason: PhotoMemoryPromptPolicy.anchorReason(for: item)
                        )
                        if didAttach {
                            openMemoryDetailAfterImageAttach(for: item, fromInlineEditor: true)
                        }
                        return didAttach
                    }
                )
                .padding(.horizontal, 26)
                .padding(.top, 86)
                .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                .zIndex(24)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(todayInlineEditingItem != nil)
        .animation(todayEditSpring, value: todayInlineEditingItemID)
    }

    private var todayRecordsGradientBackground: some View {
        LinearGradient(
            colors: [
                AppColors.bg,
                AppColors.surfaceMuted,
                AppColors.paperMist
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.52), Color.white.opacity(0.14), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .topTrailing) {
            todayRecordsBackgroundMark
                .padding(.top, 88)
                .padding(.trailing, 6)
        }
    }

    private func todayRecordInlineRow(item: HomeItem, isFirst: Bool) -> some View {
        let isEditing = todayInlineEditingItemID == item.id
        let isSwiped = todaySwipedItemID == item.id && !isEditing
        let isDeleting = todayDeletingItemID == item.id
        let dragTranslation = todaySwipeDragState?.itemID == item.id ? todaySwipeDragState?.translation ?? 0 : 0
        let restingOffset: CGFloat = isSwiped ? -76 : 0
        let rowOffset = min(0, max(-86, restingOffset + dragTranslation))
        return ZStack(alignment: .trailing) {
            if !isEditing {
                todaySwipeActions(for: item, isVisible: isSwiped)
                    .padding(.trailing, 10)
                    .zIndex(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                todayRecordSummary(item, isEditing: isEditing, isFirst: isFirst)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(todayRecordRowBackground(item: item, isEditing: isEditing))
            .overlay(todayRecordRowBorder(item: item, isEditing: isEditing))
            .overlay(alignment: .trailing) {
                if !isEditing {
                    todayRecordWatermark(for: item)
                        .padding(.trailing, 10)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .offset(x: rowOffset)
            .scaleEffect(isDeleting ? 0.96 : 1, anchor: .trailing)
            .opacity(isDeleting ? 0 : 1)
            .frame(height: isDeleting ? 0 : nil)
            .clipped()
            .onTapGesture {
                if todaySwipedItemID == item.id {
                    withAnimation(todayEditSpring) {
                        todaySwipedItemID = nil
                    }
                } else if todaySwipedItemID != nil {
                    withAnimation(todayEditSpring) {
                        todaySwipedItemID = nil
                    }
                } else if !isEditing {
                    if item.hasMemoryImages {
                        openRecord(item)
                    } else {
                        withAnimation(todayEditSpring) {
                            todayInlineEditingItemID = item.id
                        }
                    }
                }
            }
            .overlay(alignment: .trailing) {
                if !isEditing {
                    todaySwipeHandle(for: item, isSwiped: isSwiped)
                        .zIndex(3)
                }
            }
        }
        .id(item.id)
        .animation(todayEditSpring, value: isSwiped)
        .animation(.easeInOut(duration: 0.45), value: isDeleting)
    }

    private func todayRecordSummary(_ item: HomeItem, isEditing: Bool, isFirst: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(item.displayTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(todayRecordPrimaryInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isEditing ? 0.50 : 1)

                Spacer(minLength: 8)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(todayRecordAmountInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .opacity(isEditing ? 0.46 : 1)
            }

            todayRecordContextBadges(for: item, isEditing: isEditing)

            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(todayRecordCategoryAccent(for: item).opacity(0.96))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(todayRecordCategoryAccent(for: item).opacity(0.20))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(todayRecordCategoryAccent(for: item).opacity(0.16), lineWidth: 0.7)
                    )
                Text("·").foregroundStyle(AppColors.readableSubtext)
                Text(item.createdAt.zhBillTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.readableSubtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer()
            }
            .opacity(isEditing ? 0 : 1)
            .frame(height: isEditing ? 0 : nil)

            if item.hasMemoryImages {
                MemoryAttachmentThumbnail(
                    imageData: item.coverMemoryImageData,
                    imageReference: item.coverMemoryImageReference,
                    height: 82,
                    cornerRadius: 12
                )
                    .padding(.top, 4)
                    .opacity(isEditing ? 0 : 1)
                    .frame(height: isEditing ? 0 : nil)
            }
        }
    }

    private func shouldShowHomeEmotion(for item: HomeItem) -> Bool {
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        return tag != HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
    }

    private func homeLifeMarkText(for item: HomeItem) -> String? {
        homeViewModel.homeLifeMarkTextsByItemID[item.id]
    }

    @ViewBuilder
    private func todayRecordContextBadges(for item: HomeItem, isEditing: Bool) -> some View {
        let emotionText = shouldShowHomeEmotion(for: item) ? item.displayEmotionTag : nil
        let lifeMarkText = homeLifeMarkText(for: item)
        if emotionText != nil || lifeMarkText != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    if let emotionText {
                        todayRecordEmotionChip(emotionText)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    if let lifeMarkText {
                        homeLifeMarkChip(lifeMarkText)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    if let emotionText {
                        todayRecordEmotionChip(emotionText)
                    }
                    if let lifeMarkText {
                        homeLifeMarkChip(lifeMarkText)
                    }
                }
            }
            .opacity(isEditing ? 0.52 : 1)
        }
    }

    private func todayRecordEmotionChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(todayRecordEmotionInk)
            .lineLimit(1)
            .minimumScaleFactor(0.84)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.13)))
            .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.28), lineWidth: 0.7))
    }

    private func homeLifeMarkChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppColors.text.opacity(0.68))
            .lineLimit(1)
            .minimumScaleFactor(0.84)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(AppColors.paperWarm.opacity(0.52))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppColors.line.opacity(0.42), lineWidth: 0.7)
            )
    }

    private func todayRecordRowBackground(item: HomeItem, isEditing: Bool) -> some View {
        let accent = todayRecordCategoryAccent(for: item)
        let rainTint = shouldUseRainMemoryBackground(for: item)
        return RoundedRectangle(cornerRadius: 19, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(rainTint ? Color(red: 0.74, green: 0.82, blue: 0.86).opacity(isEditing ? 0.48 : 0.56) : Color.white.opacity(isEditing ? 0.62 : 0.52))
            )
            .overlay(
                LinearGradient(
                    colors: isEditing
                    ? [
                        Color.white.opacity(0.64),
                        AppColors.surfaceMuted.opacity(0.80),
                        AppColors.accent.opacity(0.18)
                    ]
                    : [
                        rainTint ? Color(red: 0.92, green: 0.96, blue: 0.98).opacity(0.78) : Color.white.opacity(0.72),
                        rainTint ? Color(red: 0.64, green: 0.76, blue: 0.82).opacity(0.30) : Color.white.opacity(0.42),
                        rainTint ? Color(red: 0.38, green: 0.55, blue: 0.64).opacity(0.20) : accent.opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            )
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color.white.opacity(isEditing ? 0.58 : 0.76),
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .overlay(alignment: .bottomTrailing) {
                RadialGradient(
                    colors: [
                        rainTint ? Color(red: 0.38, green: 0.56, blue: 0.65).opacity(isEditing ? 0.16 : 0.22) : accent.opacity(isEditing ? 0.14 : 0.18),
                        Color.white.opacity(0.0)
                    ],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 150
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .overlay {
                if rainTint {
                    todayRecordRainMemoryTexture(isEditing: isEditing)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                todayRecordScenePackBackground(item: item, isEditing: isEditing)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .allowsHitTesting(false)
            }
            .shadow(
                color: AppColors.subtext.opacity(isEditing ? 0.18 : 0.12),
                radius: isEditing ? 20 : 16,
                x: 0,
                y: isEditing ? 12 : 8
            )
            .shadow(
                color: accent.opacity(isEditing ? 0.12 : 0.05),
                radius: isEditing ? 14 : 8,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color.white.opacity(isEditing ? 0.20 : 0.28),
                radius: 7,
                x: -2,
                y: -2
            )
    }

    private func todayRecordRainMemoryTexture(isEditing: Bool) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                Image(systemName: "cloud.rain.fill")
                    .font(.system(size: 42, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(red: 0.36, green: 0.56, blue: 0.66).opacity(0.18))
                    .position(x: width * 0.82, y: height * 0.26)

                ForEach(0..<16, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.72),
                                    Color(red: 0.33, green: 0.53, blue: 0.63).opacity(0.36)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: index.isMultiple(of: 4) ? 1.8 : 1.15,
                            height: todayRainStreakHeight(index)
                        )
                        .rotationEffect(.degrees(16))
                        .position(
                            x: width * todayRainStreakX(index),
                            y: height * todayRainStreakY(index)
                        )
                        .blur(radius: index.isMultiple(of: 5) ? 0.25 : 0)
                }

                ForEach(0..<7, id: \.self) { index in
                    Ellipse()
                        .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.46 : 0.32))
                        .frame(width: 4 + CGFloat(index % 3) * 1.6, height: 2.1)
                        .position(
                            x: width * todayRainDropX(index),
                            y: height * todayRainDropY(index)
                        )
                        .blur(radius: 0.25)
                }

                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color(red: 0.73, green: 0.86, blue: 0.90).opacity(0.36),
                            Color.white.opacity(0.30)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 38)
                    .overlay(alignment: .bottomTrailing) {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.46))
                            .frame(width: min(width * 0.34, 130), height: 2)
                            .padding(.trailing, 36)
                            .padding(.bottom, 10)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.36, green: 0.58, blue: 0.67).opacity(0.22))
                            .frame(width: min(width * 0.26, 100), height: 2)
                            .padding(.leading, 28)
                            .padding(.bottom, 17)
                    }
                }
            }
        }
        .opacity(isEditing ? 0.34 : 0.58)
    }

    private func todayRainStreakX(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [0.08, 0.16, 0.24, 0.35, 0.45, 0.56, 0.66, 0.78, 0.88, 0.95, 0.13, 0.29, 0.51, 0.72, 0.84, 0.40]
        return values[index % values.count]
    }

    private func todayRainStreakY(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [0.08, 0.24, 0.42, 0.17, 0.58, 0.33, 0.12, 0.50, 0.28, 0.66, 0.73, 0.36, 0.80, 0.18, 0.56, 0.69]
        return values[index % values.count]
    }

    private func todayRainStreakHeight(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [24, 18, 29, 21, 34, 23, 27, 19]
        return values[index % values.count]
    }

    private func todayRainDropX(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [0.18, 0.31, 0.48, 0.63, 0.76, 0.86, 0.55]
        return values[index % values.count]
    }

    private func todayRainDropY(_ index: Int) -> CGFloat {
        let values: [CGFloat] = [0.72, 0.83, 0.70, 0.86, 0.76, 0.88, 0.79]
        return values[index % values.count]
    }

    private func todayRecordRowBorder(item: HomeItem, isEditing: Bool) -> some View {
        let accent = todayRecordCategoryAccent(for: item)
        return RoundedRectangle(cornerRadius: 19, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: isEditing
                    ? [
                        Color.white.opacity(0.88),
                        AppColors.accent.opacity(0.34),
                        accent.opacity(0.22)
                    ]
                    : [
                        Color.white.opacity(0.92),
                        Color.white.opacity(0.50),
                        accent.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isEditing ? 1.3 : 1.1
            )
    }

    private func shouldUseRainMemoryBackground(for item: HomeItem) -> Bool {
        let text = "\(item.title) \(item.displayEmotionTag)"
        return item.category == .transport
            && (item.memoryContext?.weatherKind == "rain" || text.contains("雨天") || text.contains("下雨"))
    }

    private var todayRecordPrimaryInk: Color {
        AppColors.text
    }

    private var todayRecordAmountInk: Color {
        AppColors.text
    }

    private var todayRecordEmotionInk: Color {
        AppColors.accent
    }

    private var todayRecordsFooterSummary: some View {
        Text(todayRecordsMetaText)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.text.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(AppColors.accent.opacity(0.12))
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.46))
                    .frame(height: 1)
            }
    }

    private var todayRecordsBackgroundMark: some View {
        ZStack {
            Image(systemName: "leaf")
                .font(.system(size: 96, weight: .ultraLight))
                .rotationEffect(.degrees(-16))
                .offset(x: 62, y: -14)
            Image(systemName: "circle.hexagongrid")
                .font(.system(size: 76, weight: .ultraLight))
                .offset(x: -10, y: 20)
        }
        .foregroundStyle(AppColors.accent.opacity(0.10))
        .frame(width: 180, height: 132)
        .allowsHitTesting(false)
    }

    private func todayRecordWatermark(for item: HomeItem) -> some View {
        let accent = todayRecordCategoryAccent(for: item)
        let symbol = item.scenePackId
            .flatMap { ScenePackVisualStyles.style(for: $0).symbols.first }
            ?? todayRecordWatermarkSymbol(for: item.category)
        return Image(systemName: symbol)
            .font(.system(size: 64, weight: .ultraLight))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accent.opacity(0.22))
            .frame(width: 124, height: 74, alignment: .trailing)
            .offset(x: 8, y: 10)
            .clipped()
    }

    @ViewBuilder
    private func todayRecordScenePackBackground(item: HomeItem, isEditing: Bool) -> some View {
        if let scenePackId = item.scenePackId {
            let style = ScenePackVisualStyles.style(for: scenePackId)
            ScenePackVisualBackdrop(style: style, compact: false, isSubtle: true)
                .opacity(isEditing ? 0.40 : 0.64)
        }
    }

    private func todayRecordWatermarkSymbol(for category: HomeItem.Category) -> String {
        switch category {
        case .dining:
            return "fork.knife"
        case .transport:
            return "tram"
        case .shopping:
            return "bag"
        case .daily:
            return "toothbrush"
        case .home:
            return "bed.double"
        case .lodging:
            return "house"
        case .health:
            return "cross.case"
        case .entertainment:
            return "sparkles"
        case .social:
            return "gift"
        case .other:
            return "leaf"
        }
    }

    private func todayRecordCategoryAccent(for item: HomeItem) -> Color {
        AppColors.categoryColor(item.category)
    }

    private var todayEditSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.08)
    }

    private func todaySwipeActions(for item: HomeItem, isVisible: Bool) -> some View {
        Button(role: .destructive) {
            requestTodayDeleteConfirmation(for: item)
        } label: {
            ZStack {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 54, height: 54)
            .background(
                Circle()
                    .fill(Color.red.opacity(0.82))
            )
            .shadow(color: Color.red.opacity(0.22), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .frame(width: 76, alignment: .trailing)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.82, anchor: .trailing)
        .offset(x: isVisible ? 0 : 18)
        .allowsHitTesting(isVisible)
        .animation(todayEditSpring, value: isVisible)
    }

    private func requestTodayDeleteConfirmation(for item: HomeItem) {
        todayPendingDeleteItem = item
        showTodayDeleteConfirmation = true
    }

    private func todaySwipeHandle(for item: HomeItem, isSwiped: Bool) -> some View {
        Color.clear
            .frame(maxWidth: isSwiped ? .infinity : nil)
            .frame(width: isSwiped ? nil : 42)
            .contentShape(Rectangle())
            .gesture(todayRowSwipeGesture(for: item))
    }

    private func todayRowSwipeGesture(for item: HomeItem) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($todaySwipeDragState) { value, state, _ in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > max(16, abs(vertical) * 1.35) else { return }
                let baseOffset: CGFloat = todaySwipedItemID == item.id ? -76 : 0
                let translation = min(86, max(-86, baseOffset + horizontal)) - baseOffset
                state = TodaySwipeDragState(itemID: item.id, translation: translation)
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let predictedHorizontal = value.predictedEndTranslation.width
                let vertical = value.translation.height
                let predictedVertical = value.predictedEndTranslation.height
                let isHorizontalSwipe = abs(horizontal) > max(34, abs(vertical) * 1.45)
                    || abs(predictedHorizontal) > max(62, abs(predictedVertical) * 1.35)
                if !isHorizontalSwipe {
                    if abs(vertical) > abs(horizontal), todaySwipedItemID == item.id {
                        withAnimation(todayEditSpring) {
                            todaySwipedItemID = nil
                        }
                    }
                    return
                }
                withAnimation(todayEditSpring) {
                    if horizontal < -28 || predictedHorizontal < -56 {
                        todaySwipedItemID = item.id
                    } else if horizontal > 24 || predictedHorizontal > 48 {
                        todaySwipedItemID = nil
                    }
                }
            }
    }

    private func deleteTodayRecord(_ item: HomeItem) {
        if todayInlineEditingItemID == item.id {
            todayInlineEditingItemID = nil
        }
        todaySwipedItemID = nil
        withAnimation(.easeInOut(duration: 0.45)) {
            todayDeletingItemID = item.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if let idx = homeViewModel.items.firstIndex(where: { $0.id == item.id }) {
                homeViewModel.delete(at: IndexSet(integer: idx))
            }
            if todayDeletingItemID == item.id {
                todayDeletingItemID = nil
            }
        }
    }

    private func handleSheetDismissRoute(_ route: SheetDismissRoute?) {
        guard let route else { return }
        switch route {
        case .memoryDetail(let item):
            memoryDetailItem = latestItem(matching: item)
        case .attachMemoryImage(let item):
            requestAttachMemoryImage(item)
        case .memberPricing:
            onShowMemberPricing?()
        }
    }

    private func openRecord(_ item: HomeItem) {
        if item.hasMemoryImages {
            todayInlineEditingItemID = nil
            todaySwipedItemID = nil
            if showTodayRecordsSheet {
                todayRecordsDismissRoute = .memoryDetail(latestItem(matching: item))
                showTodayRecordsSheet = false
            } else {
                memoryDetailItem = latestItem(matching: item)
            }
        } else {
            editingItem = latestItem(matching: item)
        }
    }

    private func requestAttachMemoryImage(_ item: HomeItem, preservesInlineEditor: Bool = false) {
        if !preservesInlineEditor {
            todayInlineEditingItemID = nil
        }
        todaySwipedItemID = nil
        let target = latestItem(matching: item)
        onAttachMemoryImage?(target)
    }

    private func openMemoryDetailAfterImageAttach(for item: HomeItem, fromInlineEditor: Bool = false) {
        if fromInlineEditor {
            withAnimation(todayEditSpring) {
                todayInlineEditingItemID = nil
                todaySwipedItemID = nil
            }
        }
        highlightSavedItem(item.id)
        let target = latestItem(matching: item)
        if showTodayRecordsSheet {
            todayRecordsDismissRoute = .memoryDetail(target)
            showTodayRecordsSheet = false
        } else if editingItem != nil {
            editingDismissRoute = .memoryDetail(target)
            editingItem = nil
        } else {
            memoryDetailItem = target
        }
    }

    private func latestItem(matching item: HomeItem) -> HomeItem {
        homeViewModel.items.first { $0.id == item.id } ?? item
    }

    private func memoryRecordDetailSheet(for item: HomeItem) -> some View {
        let current = latestItem(matching: item)
        return MemoryRecordDetailSheet(
            item: current,
            onSave: { updated in
                let didSave = homeViewModel.updateItem(updated)
                if didSave {
                    highlightSavedItem(updated.id)
                }
                return didSave
            },
            onAddImages: {
                memoryDetailDismissRoute = .attachMemoryImage(current)
                memoryDetailItem = nil
            },
            onRemoveImage: { imageIndex in
                if homeViewModel.removeMemoryImage(at: imageIndex, from: current.id) {
                    memoryDetailItem = nil
                    highlightSavedItem(current.id)
                }
            },
            onSetCoverImage: { imageIndex in
                if homeViewModel.setCoverMemoryImageIndex(imageIndex, for: current.id) {
                    memoryDetailItem = latestItem(matching: current)
                    highlightSavedItem(current.id)
                }
            },
            onDelete: {
                if let idx = homeViewModel.items.firstIndex(where: { $0.id == current.id }) {
                    homeViewModel.delete(at: IndexSet(integer: idx))
                }
                memoryDetailItem = nil
            }
        )
    }

    private func editSheet(for item: HomeItem) -> some View {
        RecordEditSheet(item: item) { updated in
            let didSave = homeViewModel.updateItem(updated)
            if didSave {
                highlightSavedItem(updated.id)
                editingItem = nil
            }
            return didSave
        } onDelete: {
            if let idx = homeViewModel.items.firstIndex(where: { $0.id == item.id }) {
                homeViewModel.delete(at: IndexSet(integer: idx))
            }
            editingItem = nil
        } onAttachMemoryImage: {
            let target = latestItem(matching: item)
            requestAttachMemoryImage(target)
        } onAttachMemoryImages: { imageDatas in
            let didAttach = homeViewModel.attachMemoryImages(
                imageDatas,
                to: item.id,
                coverImageIndex: 0,
                anchorReason: PhotoMemoryPromptPolicy.anchorReason(for: item)
            )
            if didAttach {
                openMemoryDetailAfterImageAttach(for: item)
            }
            return didAttach
        }
    }

}

// MARK: - Bill Playback Sheet

struct TodayPlaybackPresentationPayload: Identifiable {
    let id: UUID
    let contentSnapshot: BillPlaybackSheet.ContentSnapshot

    init(id: UUID = UUID(), contentSnapshot: BillPlaybackSheet.ContentSnapshot) {
        self.id = id
        self.contentSnapshot = contentSnapshot
    }

    var hasPlayableContent: Bool {
        contentSnapshot.isPrepared && !contentSnapshot.todayItems.isEmpty
    }
}

enum TodayPlaybackPresentationPolicy {
    static func accepts(
        _ candidate: TodayPlaybackPresentationPayload,
        while current: TodayPlaybackPresentationPayload?
    ) -> Bool {
        current == nil && candidate.contentSnapshot.isPrepared
    }

    static func consumesQuota(_ presentation: TodayPlaybackPresentationPayload) -> Bool {
        presentation.hasPlayableContent
    }
}

struct BillPlaybackSheet: View {
    struct PlaybackMoment: Equatable, Identifiable {
        let id: String
        let eyebrow: String
        let title: String
        let body: String
        let amountText: String?
    }

    struct ContentSnapshot {
        let sourceRevision: Int
        let dayKey: String
        let todayItems: [HomeItem]
        let playbackMoments: [PlaybackMoment]
        let playbackDuration: TimeInterval
        let narrativePlan: LifeNarrativePlan?
        let narrativeEcho: LifeNarrativeEcho?
        let narrativeRewrite: LifeNarrativeAIRewrite?

        static var empty: ContentSnapshot {
            ContentSnapshot(
                sourceRevision: -1,
                dayKey: "",
                todayItems: [],
                playbackMoments: [],
                playbackDuration: 10,
                narrativePlan: nil,
                narrativeEcho: nil,
                narrativeRewrite: nil
            )
        }

        var isPrepared: Bool {
            sourceRevision >= 0 && !dayKey.isEmpty
        }
    }

    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var activeIndex = -1
    @State private var isPlaying = false
    @State private var playbackDone = false
    @State private var showMemberNudge = false
    @State private var playbackTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    let contentSnapshot: ContentSnapshot
    var onNavigateToSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    private let nudgeService = MemberNudgePolicyService()
    private let dailyQuotaStore = DailyFeatureQuotaStore()

    static func makeContentSnapshot(
        allItems: [HomeItem],
        sourceRevision: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ContentSnapshot {
        let todayItems = allItems
            .filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            .sorted { $0.createdAt < $1.createdAt }
        let dayStart = calendar.startOfDay(for: now)
        let previousDayStart = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
        let previousDayItems = allItems.filter {
            $0.createdAt >= previousDayStart && $0.createdAt < dayStart
        }
        let narrativePlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .day,
                sourceRevision: sourceRevision,
                items: todayItems,
                previousItems: previousDayItems,
                now: now,
                recentLeadSignalIDs: LifeNarrativeSignalPolicy.recentStableSignalIDs(from: previousDayItems)
            )
        )
        let narrativeEcho = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .day,
                sourceRevision: sourceRevision,
                items: allItems,
                now: now,
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        let narrativeRewrite = LifeNarrativeAIRewriteStore.shared.rewrite(
            for: LifeNarrativeAIPreparationPolicy.key(
                scope: .day,
                sourceRevision: sourceRevision,
                now: now,
                calendar: calendar
            )
        )
        let playbackMoments = buildPlaybackMoments(
            todayItems: todayItems,
            narrativePlan: narrativePlan,
            narrativeEcho: narrativeEcho,
            narrativeRewrite: narrativeRewrite,
            calendar: calendar
        )
        let playbackDuration = max(10, min(34, Double(max(1, playbackMoments.count)) * 2.6))
        return ContentSnapshot(
            sourceRevision: sourceRevision,
            dayKey: HomeDashboardSnapshotComputation.dayKey(for: now, calendar: calendar),
            todayItems: todayItems,
            playbackMoments: playbackMoments,
            playbackDuration: playbackDuration,
            narrativePlan: narrativePlan,
            narrativeEcho: narrativeEcho,
            narrativeRewrite: narrativeRewrite
        )
    }

    private var todayItems: [HomeItem] {
        contentSnapshot.todayItems
    }

    private var playbackMoments: [PlaybackMoment] {
        contentSnapshot.playbackMoments
    }

    private var currentPlaybackMoment: PlaybackMoment? {
        guard !playbackMoments.isEmpty else { return nil }
        if activeIndex < 0 { return playbackMoments.first }
        return playbackMoments[min(activeIndex, playbackMoments.count - 1)]
    }

    private var playbackDuration: TimeInterval {
        contentSnapshot.playbackDuration
    }

    private var playbackProgressFraction: Double {
        guard !playbackMoments.isEmpty else { return 0 }
        if playbackDone { return 1 }
        return Double(max(activeIndex, 0) + 1) / Double(playbackMoments.count)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            todayPlaybackBackdrop
                .ignoresSafeArea()

            VStack(spacing: 0) {
                dragHandle
                if todayItems.isEmpty {
                    emptyPlaybackState
                } else {
                    playbackContent
                    Spacer(minLength: 10)
                    playbackDoneSection
                    playbackControls
                }
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.readableSubtext)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.64), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .presentationDetents([.height(todayPlaybackSheetHeight)])
        .presentationBackground(.clear)
        .presentationCornerRadius(30)
        .onAppear {
            activeIndex = -1; playbackDone = false; isPlaying = false; showMemberNudge = false
            if !todayItems.isEmpty { isPlaying = true }
        }
        .onChange(of: isPlaying) { _, playing in
            playbackTask?.cancel()
            guard playing, !todayItems.isEmpty, !playbackDone else { return }
            let count = playbackMoments.count
            playbackTask = Task {
                let interval = playbackDuration / Double(max(1, count))
                for i in 0..<count {
                    guard !Task.isCancelled, self.isPlaying, !self.playbackDone else { break }
                    self.activeIndex = i
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                if !Task.isCancelled, self.isPlaying {
                    self.playbackDone = true
                    self.isPlaying = false
                    if !settingsViewModel.settings.hasMemberAccess,
                       nudgeService.canShow(scene: "playback_complete", source: .automatic) {
                        self.showMemberNudge = true
                        nudgeService.markShown(scene: "playback_complete")
                    }
                }
            }
        }
        .onDisappear {
            playbackTask?.cancel()
            let progress = playbackProgressFraction
            dailyQuotaStore.markTodayPlaybackCompleted(items: todayItems, progress: progress)
            homeViewModel.markTodayPlaybackEnded(progress: progress)
        }
    }

    private var todayPlaybackBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.heroGradientPink.opacity(0.34),
                    AppColors.heroGradientTeal.opacity(0.28),
                    AppColors.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .background(.ultraThinMaterial)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var emptyPlaybackState: some View {
        VStack(spacing: 12) {
            Text("📭")
                .font(.system(size: 40))
            Text("今天还没有记录，先记一笔吧。")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.readableSubtext)
        }
        .frame(maxHeight: .infinity)
    }

    private var playbackContent: some View {
        VStack(spacing: 14) {
            playbackHeader
            playbackStage
            playbackFilmStrip
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var playbackHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日回放")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text(todayPlaybackSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.readableSubtext)
                    .lineLimit(1)
                if let hint = todayPlaybackUsageHint {
                    Text(hint)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.readableSubtext)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(todayItems.count) 笔")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.readableAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.58)))
        }
        .padding(.top, 8)
    }

    private var todayPlaybackSubtitle: String {
        if playbackDone { return "今天的记录已经看完" }
        if isPlaying { return "按时间翻一遍今天" }
        return "暂停在这里"
    }

    private var todayPlaybackUsageHint: String? {
        guard !settingsViewModel.settings.hasMemberAccess else { return nil }
        return ExperienceRuleCopy.todayPlaybackUsageHint(remaining: dailyQuotaStore.todayPlaybackRemaining(isMember: false))
    }

    private func todayPlaybackQuotaText() -> String {
        ExperienceRuleCopy.quotaText(
            remaining: dailyQuotaStore.todayPlaybackRemaining(isMember: false),
            limit: DailyFeatureQuotaStore.todayPlaybackFreeLimit
        )
    }

    private var todayPlaybackSheetHeight: CGFloat {
        guard !todayItems.isEmpty else { return 320 }
        return todayItems.count >= 5 ? 660 : 620
    }

    private var playbackStage: some View {
        let moment = currentPlaybackMoment
        let isFocused = isPlaying || playbackDone || activeIndex >= 0
        return ZStack(alignment: .topTrailing) {
            playbackDepthStack

            VStack(alignment: .leading, spacing: 18) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(AppColors.line.opacity(0.50))
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.accent.opacity(0.92),
                                        AppColors.accentDark.opacity(0.90)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * playbackProgressFraction)
                            .shadow(color: AppColors.accent.opacity(0.22), radius: 7, x: 0, y: 0)
                    }
                }
                .frame(height: 6)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(moment?.eyebrow ?? "今天")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.accentDark.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.13)))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(AppColors.accent.opacity(0.18), lineWidth: 0.8)
                            )
                        if let amount = moment?.amountText {
                            Text(amount)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.text.opacity(0.72))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.48)))
                        }
                    }

                    Text(moment?.title ?? "今天的记录")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineSpacing(5)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)

                    Text(moment?.body ?? "先留下几笔，晚上再回来看。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.readableSubtext)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(systemName: playbackDone ? "checkmark.circle.fill" : "waveform")
                        .font(.system(size: 14, weight: .bold))
                    Text(playbackDone ? "今天看完了" : "正在翻今天")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 12)
                    Text(playbackStepText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.accentDark.opacity(0.72))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.12)))
                }
                .foregroundStyle(AppColors.readableAccent)
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 286, alignment: .leading)
            .themedInteractionSurface(
                radius: 28,
                tint: AppColors.accent,
                isSelected: isFocused,
                glowIntensity: playbackDone ? 1.02 : 0.88
            )
            .overlay(alignment: .top) {
                playbackStageTopRail
            }
            .overlay(alignment: .leading) {
                playbackStageSideRail
            }
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppColors.accent.opacity(isFocused ? 0.24 : 0.12), lineWidth: isFocused ? 1.2 : 0.8)
                    .allowsHitTesting(false)
            )
            .rotation3DEffect(
                .degrees(isFocused ? -4.5 : -2.0),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                anchor: .center,
                perspective: 0.58
            )
            .offset(x: isFocused ? 4 : 0, y: isFocused ? -2 : 0)
            .shadow(color: AppColors.text.opacity(isFocused ? 0.12 : 0.06), radius: isFocused ? 24 : 14, x: 0, y: 14)

            Image(systemName: playbackStageSymbol)
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.105))
                .offset(x: 4, y: 2)
        }
        .animation(.easeInOut(duration: 0.24), value: activeIndex)
    }

    private var playbackDepthStack: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                playbackDepthCard(index: index)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 286)
        .allowsHitTesting(false)
    }

    private func playbackDepthCard(index: Int) -> some View {
        let progress = max(activeIndex, 0)
        let offsetY = CGFloat(index + 1) * 16
        let offsetX = CGFloat(index + 1) * 12
        return RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColors.panel.opacity(0.22 - Double(index) * 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.26 - Double(index) * 0.05), lineWidth: 0.8)
            )
            .frame(maxWidth: .infinity, minHeight: 246 - CGFloat(index) * 14)
            .scaleEffect(0.94 - CGFloat(index) * 0.045, anchor: .center)
            .rotation3DEffect(
                .degrees(-9.0 - Double(index) * 4.0),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                anchor: .center,
                perspective: 0.72
            )
            .offset(x: offsetX, y: offsetY)
            .opacity(max(0.12, 0.34 - Double(index) * 0.08))
            .blur(radius: CGFloat(index) * 0.35)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: progress)
    }

    private var playbackStepText: String {
        guard !playbackMoments.isEmpty else { return "0 / 0" }
        let current = min(max(activeIndex, 0) + 1, playbackMoments.count)
        return "\(current) / \(playbackMoments.count)"
    }

    private var playbackStageTopRail: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.56),
                        AppColors.accent.opacity(0.50),
                        AppColors.accentDark.opacity(0.34)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 3)
            .padding(.horizontal, 26)
            .padding(.top, 1.5)
            .allowsHitTesting(false)
    }

    private var playbackStageSideRail: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.accent.opacity(0.86),
                        AppColors.accentDark.opacity(0.50)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: 92)
            .padding(.leading, 1.5)
            .allowsHitTesting(false)
    }

    private var playbackStageSymbol: String {
        guard let moment = currentPlaybackMoment else { return "play.rectangle.fill" }
        if moment.id.contains("first") { return "sunrise.fill" }
        if moment.id.contains("summary") { return "sparkles" }
        if moment.id.contains("close") { return "moon.stars.fill" }
        return "note.text"
    }

    private var playbackFilmStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(playbackMoments.enumerated()), id: \.element.id) { index, moment in
                        Button {
                            isPlaying = false
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                activeIndex = index
                                playbackDone = false
                            }
                        } label: {
                            playbackFilmStripCard(moment: moment, index: index)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, 1)
            }
            .frame(height: 70)
            .onChange(of: activeIndex) { newValue in
                guard newValue >= 0 else { return }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                let initial = max(activeIndex, 0)
                DispatchQueue.main.async {
                    proxy.scrollTo(initial, anchor: .center)
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in
                        if isPlaying {
                            isPlaying = false
                        }
                    }
            )
        }
    }

    private func playbackFilmStripCard(moment: PlaybackMoment, index: Int) -> some View {
        let isActive = index == activeIndex
        let isSeen = index <= max(activeIndex, 0)
        return ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? AppColors.accent : AppColors.line)
                        .frame(width: 5, height: 5)
                    Text(moment.eyebrow)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isActive ? AppColors.accentDark : AppColors.subtext)
                        .lineLimit(1)
                }
                Text(moment.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.text.opacity(isSeen ? 0.94 : 0.54))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
            .padding(10)

            if isActive {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDark.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 7)
            }
        }
        .frame(width: 112, height: 62, alignment: .topLeading)
        .themedInteractionSurface(
            radius: 13,
            tint: AppColors.accent,
            isSelected: isActive,
            isDisabled: !isSeen,
            glowIntensity: isActive ? 0.74 : 0.40
        )
        .scaleEffect(isActive ? 1.02 : 0.96)
        .opacity(isActive ? 1 : (isSeen ? 0.72 : 0.48))
        .animation(.spring(response: 0.26, dampingFraction: 0.88), value: activeIndex)
    }

    @ViewBuilder
    private var playbackDoneSection: some View {
        if playbackDone {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("今天的记录已经看完")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppColors.readableAccent)
            .padding(.bottom, 8)

            if showMemberNudge {
                memberPlaybackNudge
            }
        }
    }

    private var memberPlaybackNudge: some View {
        VStack(spacing: 10) {
            Text("晚上想多看几遍，会员可以不等明天。")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.88))
                .multilineTextAlignment(.center)
            memberPlaybackNudgeActions
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(memberPlaybackNudgeBackground)
        .overlay(memberPlaybackNudgeBorder)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .transition(.opacity.combined(with: .scale(scale: 0.95).combined(with: .offset(y: 8))))
    }

    private var memberPlaybackNudgeActions: some View {
        HStack(spacing: 20) {
            Button {
                nudgeService.markDismissed(scene: "playback_complete")
                showMemberNudge = false
                dismiss()
            } label: {
                Text("稍后再说")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.readableSubtext)
                    .minimumTapTarget()
            }
            Button {
                if let onShowMemberPricing {
                    onShowMemberPricing()
                } else {
                    dismiss()
                }
            } label: {
                memberPlaybackNudgePrimaryLabel
            }
        }
        .buttonStyle(.plain)
    }

    private var memberPlaybackNudgePrimaryLabel: some View {
        Text("✨ 了解会员")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppColors.onAccent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Capsule(style: .continuous).fill(AppColors.accent))
    }

    private var memberPlaybackNudgeBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var memberPlaybackNudgeBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
    }

    private var playbackControls: some View {
        HStack(spacing: 8) {
            Button {
                if playbackDone {
                    dismiss()
                } else {
                    isPlaying.toggle()
                }
            } label: {
                primaryPlaybackControlLabel
            }
            Button {
                restartPlayback()
            } label: {
                replayPlaybackControlLabel
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private var primaryPlaybackControlLabel: some View {
        let title = playbackDone ? "关闭" : (isPlaying ? "暂停" : "播放")

        return HStack(spacing: 7) {
            Image(systemName: playbackDone ? "xmark" : (isPlaying ? "pause.fill" : "play.fill"))
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
            .foregroundStyle(AppColors.text)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.58)))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
            )
    }

    private var replayPlaybackControlLabel: some View {
        let title = playbackDone ? "再看一遍" : "重播"

        return HStack(spacing: 7) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
            .foregroundStyle(AppColors.onAccent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(AppColors.accent))
    }

    private func restartPlayback() {
        activeIndex = -1
        playbackDone = false
        isPlaying = true
    }

    private static func formatClockTime(_ date: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private static func buildPlaybackMoments(
        todayItems: [HomeItem],
        narrativePlan: LifeNarrativePlan,
        narrativeEcho: LifeNarrativeEcho?,
        narrativeRewrite: LifeNarrativeAIRewrite?,
        calendar: Calendar
    ) -> [PlaybackMoment] {
        guard !todayItems.isEmpty else { return [] }
        if todayItems.count > 8 {
            return densePlaybackMoments(
                todayItems: todayItems,
                narrativePlan: narrativePlan,
                narrativeEcho: narrativeEcho,
                narrativeRewrite: narrativeRewrite,
                calendar: calendar
            )
        }

        var moments: [PlaybackMoment] = []

        if todayItems.count >= 3 {
            moments.append(
                PlaybackMoment(
                    id: "summary-opening",
                    eyebrow: "先看一眼",
                    title: "今天记了 \(todayItems.count) 笔",
                    body: openingBody(
                        todayItems: todayItems,
                        narrativePlan: narrativePlan
                    ),
                    amountText: todayItems.reduce(0) { $0 + $1.amount }.formatted(.cny)
                )
            )
        }

        moments += todayItems.prefix(12).map { item in
            PlaybackMoment(
                id: "item-\(item.id)",
                eyebrow: momentEyebrow(for: item, calendar: calendar),
                title: playbackTitle(for: item, calendar: calendar),
                body: itemMomentBody(for: item, calendar: calendar),
                amountText: item.amount.formatted(.cny)
            )
        }

        if todayItems.count >= 4 {
            moments.append(
                PlaybackMoment(
                    id: "summary-close",
                    eyebrow: "看完今天",
                    title: closingTitle(from: narrativePlan),
                    body: closingBody(
                        recordCount: todayItems.count,
                        echo: narrativeEcho,
                        rewrite: narrativeRewrite
                    ),
                    amountText: nil
                )
            )
        }

        return moments
    }

    private static func densePlaybackMoments(
        todayItems: [HomeItem],
        narrativePlan: LifeNarrativePlan,
        narrativeEcho: LifeNarrativeEcho?,
        narrativeRewrite: LifeNarrativeAIRewrite?,
        calendar: Calendar
    ) -> [PlaybackMoment] {
        var moments: [PlaybackMoment] = [
            PlaybackMoment(
                id: "summary-opening",
                eyebrow: "先看一眼",
                title: "今天记了 \(todayItems.count) 笔",
                body: openingBody(
                    todayItems: todayItems,
                    narrativePlan: narrativePlan
                ),
                amountText: todayItems.reduce(0) { $0 + $1.amount }.formatted(.cny)
            )
        ]

        moments += todayTimeBlocks(todayItems: todayItems, calendar: calendar).compactMap { block in
            guard !block.items.isEmpty else { return nil }
            let total = block.items.reduce(0) { $0 + $1.amount }
            return PlaybackMoment(
                id: "time-\(block.id)",
                eyebrow: block.label,
                title: "\(block.label)有 \(block.items.count) 笔",
                body: timeBlockBody(label: block.label, items: block.items, calendar: calendar),
                amountText: total.formatted(.cny)
            )
        }

        moments.append(
            PlaybackMoment(
                id: "summary-close",
                eyebrow: "看完今天",
                title: closingTitle(from: narrativePlan),
                body: closingBody(
                    recordCount: todayItems.count,
                    echo: narrativeEcho,
                    rewrite: narrativeRewrite
                ),
                amountText: nil
            )
        )

        return moments
    }

    private static func openingBody(
        todayItems: [HomeItem],
        narrativePlan: LifeNarrativePlan
    ) -> String {
        if let lead = narrativePlan.signalsByRole[.lead]?.first {
            if lead.kind == .userText || lead.kind == .photo {
                return narrativePlan.summary
            }
            if let sceneLine = plannedDailySceneLine(for: lead) {
                return sceneLine
            }
            if lead.kind == .change {
                return narrativePlan.summary
            }
        }
        if leadIsRoutine(narrativePlan) {
            return "从早到晚，这些记录按发生顺序排在一起。"
        }
        return "今天的 \(todayItems.count) 笔，按发生顺序排在这里。"
    }

    private static func plannedDailySceneLine(for signal: LifeNarrativeSignal) -> String? {
        guard signal.kind == .change || signal.kind == .structuredScene else { return nil }
        let label = signal.label
        if label.contains("咖啡") || label.contains("饮品") || label.contains("饮料") {
            return "今天有几笔喝的，按时间排在记录里。"
        }
        if label.contains("餐") || label.contains("早餐") || label.contains("饭") {
            return "今天几次吃饭都在记录里，饭点串起来，今天就清楚了。"
        }
        if label.contains("日用") || label.contains("居家") || label.contains("买菜") || label.contains("采购") {
            return "今天补了一些日用或家里会用到的东西，都是会派上用场的。"
        }
        if label.contains("通勤") || label.contains("路线") || label.contains("出行") {
            return "今天路上的记录比较多，来回按时间排在一起。"
        }
        return nil
    }

    private static func leadIsRoutine(_ plan: LifeNarrativePlan) -> Bool {
        guard let kind = plan.signalsByRole[.lead]?.first?.kind else { return true }
        return kind == .rhythm || kind == .stableMark || kind == .structuredScene
    }

    private static func closingTitle(from plan: LifeNarrativePlan) -> String {
        guard let kind = plan.signalsByRole[.lead]?.first?.kind else { return "今天先记到这里" }
        switch kind {
        case .userText: return "今天有一句自己的话"
        case .photo: return "今天有一张具体照片"
        case .change: return "今天有一处变化"
        default: return "今天先记到这里"
        }
    }

    private static func closingBody(
        recordCount: Int,
        echo: LifeNarrativeEcho?,
        rewrite: LifeNarrativeAIRewrite?
    ) -> String {
        let closing = "今天的 \(recordCount) 笔都看过了，先停在这里。"
        if let echo { return "\(closing)\n\(echo.line)" }
        if let rewrite { return "\(closing)\n\(rewrite.summary)" }
        return closing
    }

    private static func todayTimeBlocks(
        todayItems: [HomeItem],
        calendar: Calendar
    ) -> [(id: String, label: String, items: [HomeItem])] {
        [
            ("morning", "上午", todayItems.filter { calendar.component(.hour, from: $0.createdAt) < 12 }),
            ("afternoon", "下午", todayItems.filter {
                let hour = calendar.component(.hour, from: $0.createdAt)
                return hour >= 12 && hour < 18
            }),
            ("evening", "晚上", todayItems.filter { calendar.component(.hour, from: $0.createdAt) >= 18 })
        ]
    }

    private static func timeBlockBody(
        label: String,
        items: [HomeItem],
        calendar: Calendar
    ) -> String {
        let categories = Dictionary(grouping: items, by: \.category)
            .map { (category: $0.key, count: $0.value.count, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted {
                if $0.count == $1.count { return $0.amount > $1.amount }
                return $0.count > $1.count
            }
            .prefix(2)
            .map { $0.category.rawValue }
            .joined(separator: "、")
        let first = items.first.map { playbackTitle(for: $0, calendar: calendar) } ?? "一笔记录"
        if items.count == 1 {
            return "\(label)主要是「\(first)」。这笔放在今天的位置很清楚。"
        }
        if categories.isEmpty {
            return "\(label)有 \(items.count) 笔，先照着发生的顺序看。"
        }
        return "\(label)留下 \(items.count) 笔，主要和\(categories)有关。先看发生了什么。"
    }

    private static func playbackTitle(for item: HomeItem, calendar: Calendar) -> String {
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lateTitle = HomeItem.lateWorkCommutePlaybackTitle(for: item),
           ["下班", "通勤", "通勤路上", "日常出行", "公共交通一段", "下班路上这一程"].contains(title) {
            return lateTitle
        }
        let hour = calendar.component(.hour, from: item.createdAt)
        let replacements: [String: String] = [
            "上班路上的一段车程": hour < 12 ? "早上路上这一程" : "路上这一程",
            "下班路上的一段车程": "下班路上这一程",
            "公共交通一段": "公交地铁这一趟",
            "早间路线走完了": "早上这趟路走完了",
            "晚间通勤完成": "下班这趟路到家了"
        ]
        return replacements[title] ?? title
    }

    private static func momentEyebrow(for item: HomeItem, calendar: Calendar) -> String {
        "\(formatClockTime(item.createdAt, calendar: calendar)) · \(item.category.label)"
    }

    private static func itemMomentBody(for item: HomeItem, calendar: Calendar) -> String {
        if let lateCommuteLine = HomeItem.lateWorkCommutePlaybackLine(for: item) {
            return lateCommuteLine
        }
        if let weatherLine = weatherPlaybackLine(for: item) {
            return weatherLine
        }
        if let brand = MerchantBrandCatalog.definition(for: item.merchantBrandId)
            ?? MerchantBrandCatalog.matchBrand(in: item.title) {
            switch brand.id {
            case "haidilao":
                return "今天认真吃了顿火锅。"
            case "laoxiangji":
                return "今天吃了口家常热饭。"
            case "tastien":
                return "今天吃了顿汉堡快餐。"
            case "cotti":
                return "今天买了杯咖啡。"
            case "juewei":
                return "今天带了点卤味小食。"
            case "yuanjiyunjiao":
                return "今天吃了份热乎水饺。"
            case "saizeriya":
                return "今天坐下来吃了顿简餐。"
            case "samsclub", "yonghui", "rtmart", "qiandama":
                return "今天给家里补了点吃用。"
            case "huaxiaozhu":
                return "今天打车走完一程。"
            case "sgcc_online":
                return "今天把家里账单处理了。"
            default:
                break
            }
        }
        let hour = calendar.component(.hour, from: item.createdAt)
        let itemText = "\(item.title) \(item.displayTitle) \(item.displayEmotionTag)"
        if playbackContainsNightMarketCue(itemText) {
            if hour >= 21 || hour < 5 {
                return "夜里买了点夜市小吃。"
            }
            return "买了点夜市小吃。"
        }
        if playbackContainsLuweiCue(itemText) {
            return "今天带了点卤味小食。"
        }
        if playbackContainsDrinkCue(itemText) {
            if (11..<14).contains(hour) {
                return "中午买了瓶喝的。"
            }
            if hour < 11 {
                return "早上买了瓶喝的。"
            }
            if hour >= 17 {
                return "傍晚买了瓶喝的。"
            }
            return "今天买了瓶喝的。"
        }
        if playbackContainsRoastDuckCue(itemText) {
            return "今天吃了点烤鸭。"
        }
        switch LifeSceneSemanticService.classify(item).kind {
        case .commute:
            if hour < 12 {
                return "早上上班路上的一笔。"
            }
            if hour >= 17 {
                return "下班回家路上的一笔。"
            }
            return "今天在路上的一段。"
        case .cityRoute:
            return "今天出门办了点事。"
        case .breakfast:
            return "早上先吃了口东西。"
        case .quickMeal, .workMeal:
            if (11..<14).contains(hour) {
                return "中午这顿先记下。"
            }
            if (17..<21).contains(hour) {
                return "晚饭这顿先记下。"
            }
            if hour >= 21 || hour < 5 {
                return "夜里补了点吃的。"
            }
            return "这份吃的记下来了。"
        case .coffee:
            if (11..<14).contains(hour) {
                return "中午买了杯喝的。"
            }
            if hour < 11 {
                return "早上买了杯喝的。"
            }
            if hour >= 17 {
                return "傍晚买了杯喝的。"
            }
            return "今天买了杯喝的。"
        case .convenienceSupply, .groceries, .homeSupply:
            return "家里常用的补上了。"
        case .medicalVisit, .medicineCare, .fitness, .bodyCare:
            return "今天身体这边有笔安排。"
        default:
            return "这笔记录先放进今天。"
        }
    }

    private static func playbackContainsDrinkCue(_ text: String) -> Bool {
        ["咖啡", "拿铁", "美式", "奶茶", "饮品", "饮料", "喝的", "茶饮", "可乐", "雪碧", "汽水", "果汁", "柠檬茶", "水溶", "c100", "维c", "维C", "维他"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func playbackContainsLuweiCue(_ text: String) -> Bool {
        ["绝味", "鸭脖", "鸭货", "卤味", "周黑鸭", "煌上煌"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func playbackContainsNightMarketCue(_ text: String) -> Bool {
        ["夜市", "夜摊", "大排档", "生蚝", "烤生蚝", "鱿鱼", "铁板鱿鱼", "烧烤", "烤串", "串串"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func playbackContainsRoastDuckCue(_ text: String) -> Bool {
        ["烤鸭", "烧鸭", "卤鸭", "鸭肉"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private static func weatherPlaybackLine(for item: HomeItem) -> String? {
        let weather = item.memoryContext?.weatherKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rainy = weather.contains("雨") || weather.lowercased().contains("rain")
        guard rainy else { return nil }
        switch LifeSceneSemanticService.classify(item).kind {
        case .commute:
            return "这笔在雨天通勤里。路上可能慢一点，也更费一点心。"
        case .cityRoute:
            return "这趟路带着雨天背景，不是很普通的一次出门。"
        default:
            return "这笔旁边有雨天背景。今天的天气也在这条记录里。"
        }
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(HomeViewModel())
            .environmentObject(SettingsViewModel())
    }
}
