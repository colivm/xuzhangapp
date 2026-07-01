import SwiftUI

private struct TodaySwipeDragState: Equatable {
    let itemID: UUID
    let translation: CGFloat
}

private enum TodayPlaybackPrompt: Equatable {
    case firstUse
    case quotaExhausted(String)

    var title: String {
        switch self {
        case .firstUse:
            return "今日回放，适合晚一点听"
        case .quotaExhausted:
            return "今天的免费回放已用完"
        }
    }

    func message(remaining: Int) -> String {
        switch self {
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onQuickRecord: () -> Void = {}
    var onNavigateStats: (() -> Void)? = nil
    var onNavigateWeeklyTrace: (() -> Void)? = nil
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    var onAttachMemoryImage: ((HomeItem) -> Void)? = nil
    @State private var showPlayback = false
    @State private var playbackSheetID = UUID()
    @State private var showFirstRecordToast = false
    @State private var showTodayRecordsSheet = false
    @State private var editingItem: HomeItem?
    @State private var memoryDetailItem: HomeItem?
    @State private var todayInlineEditingItemID: UUID?
    @State private var todaySwipedItemID: UUID?
    @State private var todayDeletingItemID: UUID?
    @State private var todayPlaybackPrompt: TodayPlaybackPrompt?
    @State private var petHint: String = "有一笔就记一笔，晚点也能补。"
    @State private var petBubbleVisible = false
    @State private var todayBillsFocusPulse = false
    @State private var todayBillsFocusTick = 0
    @State private var highlightedSavedItemID: UUID?
    @State private var quickRecordCardDismissedID: String?
    @State private var quickRecordCardAutoCloseID: String?
    @State private var quickRecordCardPulse = false
    @State private var quickRecordRefreshTick = 0
    @State private var quickRecordWeatherRefreshTick = 0
    @GestureState private var todaySwipeDragState: TodaySwipeDragState?
    private let dailyQuotaStore = DailyFeatureQuotaStore()
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

            if showFirstRecordToast {
                firstRecordToast
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(18)
            }

            highConfidenceQuickRecordOverlay
                .zIndex(12)

            if todayPlaybackPrompt != nil {
                todayPlaybackPromptOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(20)
            }

            if settingsViewModel.petCompanionEnabled {
                todayPetStamp
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, 102)
            }

        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .onAppear {
            handleRouteGuidance(homeViewModel.activeRouteGuidance)
            scheduleRecentSaveHighlight()
        }
        .onChange(of: homeViewModel.activeRouteGuidance) { _, guidance in
            handleRouteGuidance(guidance)
        }
        .onChange(of: homeViewModel.recentThreeItems.first?.id) { _, _ in
            scheduleRecentSaveHighlight()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            quickRecordRefreshTick += 1
        }
        .onChange(of: settingsViewModel.petCompanionEnabled) { _, enabled in
            if !enabled {
                petBubbleVisible = false
            }
        }
        .onChange(of: homeViewModel.petMessage) { _, message in
            guard let message, settingsViewModel.petCompanionEnabled else { return }
            petHint = message
            withAnimation(.easeInOut(duration: 0.24)) {
                petBubbleVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    petBubbleVisible = false
                }
            }
            homeViewModel.petMessage = nil
        }
        .sheet(isPresented: $showPlayback) {
            BillPlaybackSheet(
                onNavigateToSettings: { onNavigateSettings?() },
                onShowMemberPricing: { onShowMemberPricing?() }
            )
                .id(playbackSheetID)
                .environmentObject(homeViewModel)
        }
        .sheet(isPresented: $showTodayRecordsSheet) {
            todayRecordsSheet
        }
        .sheet(item: $editingItem) { item in
            editSheet(for: item)
        }
        .sheet(item: $memoryDetailItem) { item in
            memoryRecordDetailSheet(for: item)
        }
    }

    private var homeContent: some View {
        VStack(spacing: 10) {
            todayStoryHero
            homeActionRow
            routeGuidanceContent
            todayBillsPanel
            lifeRhythmPanel
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var homeActionRow: some View {
        HStack(spacing: 10) {
            homeActionCard(
                title: "记下一笔",
                subtitle: homeViewModel.quickRecordNudgeText,
                systemImage: "plus.circle.fill",
                isPrimary: true,
                action: onQuickRecord
            )
            homeActionCard(
                title: "听今日回放",
                subtitle: todayPlaybackActionSubtitle,
                systemImage: "play.circle.fill",
                isPrimary: false,
                action: { requestTodayPlayback() }
            )
        }
    }

    @ViewBuilder
    private var highConfidenceQuickRecordOverlay: some View {
        let _ = quickRecordRefreshTick
        if let suggestion = homeViewModel.highConfidenceQuickRecordSuggestion,
           quickRecordCardDismissedID != suggestion.id {
            HighConfidenceCommuteFloatingCard(
                suggestion: suggestion,
                weatherKind: quickRecordWeatherKind,
                isPulsing: quickRecordCardPulse,
                onClose: { dismissQuickRecordCard(suggestion.id) },
                onSave: {
                    if homeViewModel.addHighConfidenceQuickRecord(suggestion) {
                        dismissQuickRecordCard(suggestion.id)
                    }
                }
            )
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            guard quickRecordCardAutoCloseID == suggestion.id,
                  quickRecordCardDismissedID != suggestion.id else {
                return
            }
            dismissQuickRecordCard(suggestion.id)
        }
    }

    private func dismissQuickRecordCard(_ id: String) {
        withAnimation(.easeInOut(duration: 0.24)) {
            quickRecordCardDismissedID = id
            quickRecordCardAutoCloseID = nil
            quickRecordCardPulse = false
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

    @ViewBuilder
    private var routeGuidanceContent: some View {
        if let guidance = homeViewModel.activeRouteGuidance,
           guidance != .firstRecordTodayPlayback {
            routeGuidanceBar(guidance)
        }
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
            ? "最近「\(homeViewModel.weekTopCategoryText)」这类记录多一点。"
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
            onQuickRecord()
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

    private func scheduleRecentSaveHighlight() {
        guard let item = homeViewModel.recentThreeItems.first,
              item.source == .manual,
              abs(item.updatedAt.timeIntervalSinceNow) <= 4 else {
            return
        }
        highlightSavedItem(item.id)
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

    private var firstRecordToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.readableAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("用十几秒叙一下今天")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text("第一笔已经记好，听一遍今日回放。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.readableSubtext)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.56), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.16), radius: 16, y: 8)
    }

    private func routeGuidanceBar(_ guidance: HomeViewModel.PlaybackRouteGuidance) -> some View {
        Button {
            homeViewModel.consumeRouteGuidance(guidance)
            onNavigateStats?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.readableAccent)
                    .frame(width: 30, height: 30)
                    .background(AppColors.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(guidance.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(guidance.message)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.readableSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.readableSubtext)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.68))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .minimumTapTarget()
    }

    private func handleRouteGuidance(_ guidance: HomeViewModel.PlaybackRouteGuidance?) {
        guard guidance == .firstRecordTodayPlayback else { return }
        showFirstRecordToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            requestTodayPlayback(allowsFirstUsePrompt: false)
            showFirstRecordToast = false
            homeViewModel.consumeRouteGuidance(.firstRecordTodayPlayback)
        }
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
        dailyQuotaStore.markTodayPlaybackStarted(isMember: isMember)
        presentTodayPlaybackSheet()
    }

    private func presentTodayPlaybackSheet() {
        playbackSheetID = UUID()
        showPlayback = true
    }

    private func todayPlaybackRemaining(isMember: Bool? = nil) -> Int {
        let member = isMember ?? settingsViewModel.settings.hasMemberAccess
        return dailyQuotaStore.todayPlaybackRemaining(isMember: member)
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
                        Text(todayPlaybackPrompt?.message(remaining: todayPlaybackRemaining(isMember: false)) ?? "")
                            .font(.system(size: 14, weight: .medium))
                            .lineSpacing(4)
                            .foregroundStyle(AppColors.readableSubtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        dismissTodayPlaybackPrompt()
                    } label: {
                        Text(todayPlaybackPrompt == .firstUse ? "晚点再说" : "知道了")
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
                        Text(todayPlaybackPrompt == .firstUse ? "现在听一遍" : "了解不限回放")
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

    private func dismissTodayPlaybackPrompt() {
        withAnimation(.easeInOut(duration: 0.18)) {
            todayPlaybackPrompt = nil
        }
    }

    private var todayPetStamp: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if petBubbleVisible {
                Text(petHint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.text.opacity(0.9))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.48), lineWidth: 1)
                    )
                    .frame(maxWidth: 210, alignment: .trailing)
                    .transition(.scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.24)) {
                    petBubbleVisible.toggle()
                }
                if petBubbleVisible {
                    Task {
                        if let message = await PetCompanionService.shared.petClickMessage(
                            settings: settingsViewModel.settings,
                            todayItems: homeViewModel.items
                        ) {
                            await MainActor.run {
                                petHint = message
                                petBubbleVisible = true
                            }
                        }
                    }
                }
            } label: {
                Text("🐱")
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.floatingPetPanel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
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
            if let imageData = item.memoryImageData {
                homeMemoryBillCard(item: item, imageData: imageData, isHighlighted: isHighlighted)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.displayTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 10)
                        Text(item.amount.formatted(.cny))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    if shouldShowHomeEmotion(for: item) {
                        let emotionTag = item.displayEmotionTag
                        Text(emotionTag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.readableAccent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.08)))
                            .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.18), lineWidth: 0.7))
                            .padding(.bottom, 4)
                    }
                    if let lifeMarkText = homeLifeMarkText(for: item) {
                        homeLifeMarkChip(lifeMarkText)
                            .padding(.bottom, 3)
                    }
                    HStack(spacing: 6) {
                        Text(item.category.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.readableSubtext)

                        Text("·").foregroundStyle(AppColors.readableSubtext)

                        Text(item.createdAt.zhBillTime)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.readableSubtext)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
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
            if !isFirst {
                PaperCreaseDivider()
                    .padding(.top, -10)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isHighlighted)
    }

    private func homeMemoryBillCard(item: HomeItem, imageData: Data, isHighlighted: Bool) -> some View {
        let accent = AppColors.categoryColor(item.category)
        return ZStack(alignment: .bottom) {
            MemoryAttachmentThumbnail(imageData: imageData, height: 112, cornerRadius: 15)
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

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.88))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .padding(8)
        }
        .padding(.vertical, 8)
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
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Button {
                                    todayInlineEditingItemID = nil
                                    todaySwipedItemID = nil
                                    showTodayRecordsSheet = false
                                } label: {
                                    Text("关闭")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppColors.text.opacity(0.86))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
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
                                .font(.system(size: 27, weight: .bold))
                                .foregroundStyle(AppColors.text)
                                .padding(.top, 8)

                            Text(todayRecordsMetaText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.text.opacity(0.86))

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(homeViewModel.todayItems.enumerated()), id: \.element.id) { index, item in
                                    todayRecordInlineRow(item: item, isFirst: index == 0)
                                }
                            }
                            .opacity(todayInlineEditingItemID == nil ? 1 : 0.34)
                            .scaleEffect(todayInlineEditingItemID == nil ? 1 : 0.985, anchor: .top)
                            .allowsHitTesting(todayInlineEditingItemID == nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 92)
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
        .onDisappear {
            todayInlineEditingItemID = nil
            todaySwipedItemID = nil
        }
    }

    private var todayRecordsMetaText: String {
        let total = homeViewModel.todayItems.reduce(0) { $0 + $1.amount }
        return "\(homeViewModel.todayItems.count) 笔 · 合计 \(total.formatted(.cny)) · 点任一条可调整"
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

            VStack(alignment: .leading, spacing: 8) {
                todayRecordSummary(item, isEditing: isEditing, isFirst: isFirst)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
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
                    if item.memoryImageData != nil {
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.displayTitle)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(todayRecordPrimaryInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isEditing ? 0.50 : 1)

                Spacer(minLength: 8)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(todayRecordAmountInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .opacity(isEditing ? 0.46 : 1)
            }

            if shouldShowHomeEmotion(for: item) {
                let emotionTag = item.displayEmotionTag
                Text(emotionTag)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(todayRecordEmotionInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.13)))
                    .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.28), lineWidth: 0.7))
                    .opacity(isEditing ? 0.52 : 1)
            }
            if let lifeMarkText = homeLifeMarkText(for: item) {
                homeLifeMarkChip(lifeMarkText)
                    .opacity(isEditing ? 0.52 : 1)
            }

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

            if let imageData = item.memoryImageData {
                MemoryAttachmentThumbnail(imageData: imageData, height: 82, cornerRadius: 12)
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
        guard item.amount > 0 else { return nil }
        guard let mark = LifeMarkService.aggregates(
            for: [item],
            allItems: homeViewModel.items,
            isMember: settingsViewModel.settings.hasMemberAccess,
            limit: 1
        ).first else {
            return nil
        }
        switch mark.kind {
        case .scene:
            return "生活印记 · \(mark.label)"
        case .context, .milestone, .streak:
            return "生活印记 · \(mark.title)"
        }
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
        let text = "\(item.title) \(item.emotionTag) \(item.displayEmotionTag)"
        return item.category == .transport
            && (item.memoryContext?.weatherKind == "rain" || text.contains("雨天") || text.contains("下雨"))
    }

    private var todayRecordPrimaryInk: Color {
        AppColors.text
    }

    private var todayRecordAmountInk: Color {
        AppColors.accentDark
    }

    private var todayRecordEmotionInk: Color {
        AppColors.accent
    }

    private var todayRecordsFooterSummary: some View {
        Text(todayRecordsMetaText)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(AppColors.text.opacity(0.94))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 12)
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
            deleteTodayRecord(item)
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

    private func openRecord(_ item: HomeItem) {
        if item.memoryImageData != nil {
            todayInlineEditingItemID = nil
            todaySwipedItemID = nil
            if showTodayRecordsSheet {
                showTodayRecordsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    memoryDetailItem = latestItem(matching: item)
                }
            } else {
                memoryDetailItem = latestItem(matching: item)
            }
        } else {
            editingItem = latestItem(matching: item)
        }
    }

    private func requestAttachMemoryImage(_ item: HomeItem) {
        todayInlineEditingItemID = nil
        todaySwipedItemID = nil
        let target = latestItem(matching: item)
        if showTodayRecordsSheet {
            showTodayRecordsSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                onAttachMemoryImage?(target)
            }
        } else {
            onAttachMemoryImage?(target)
        }
    }

    private func latestItem(matching item: HomeItem) -> HomeItem {
        homeViewModel.items.first { $0.id == item.id } ?? item
    }

    private func memoryRecordDetailSheet(for item: HomeItem) -> some View {
        let current = latestItem(matching: item)
        return MemoryRecordDetailSheet(
            item: current,
            onEditInfo: {
                memoryDetailItem = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    editingItem = latestItem(matching: current)
                }
            },
            onReplaceImage: {
                memoryDetailItem = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    requestAttachMemoryImage(current)
                }
            },
            onRemoveImage: {
                if homeViewModel.removeMemoryImage(from: current.id) {
                    memoryDetailItem = nil
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
            editingItem = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                requestAttachMemoryImage(target)
            }
        }
    }

}

// MARK: - Bill Playback Sheet

struct BillPlaybackSheet: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @State private var activeIndex = -1
    @State private var isPlaying = false
    @State private var playbackDone = false
    @State private var showMemberNudge = false
    @State private var playbackTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    var onNavigateToSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    private let nudgeService = MemberNudgePolicyService()
    private let dailyQuotaStore = DailyFeatureQuotaStore()

    private var todayItems: [HomeItem] {
        homeViewModel.items.filter {
            Calendar.current.isDateInToday($0.createdAt)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    private var playbackMoments: [PlaybackMoment] {
        buildPlaybackMoments()
    }

    private var currentPlaybackMoment: PlaybackMoment? {
        guard !playbackMoments.isEmpty else { return nil }
        if activeIndex < 0 { return playbackMoments.first }
        return playbackMoments[min(activeIndex, playbackMoments.count - 1)]
    }

    private var playbackDuration: TimeInterval {
        max(10, min(34, Double(max(1, playbackMoments.count)) * 2.6))
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
                    if !settingsViewModel.settings.hasMemberAccess && nudgeService.canShow(scene: "playback_complete") {
                        self.showMemberNudge = true
                        nudgeService.markShown(scene: "playback_complete")
                    }
                }
            }
        }
        .onDisappear {
            playbackTask?.cancel()
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
                Text("今日生活回放")
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
                dismiss()
            } label: {
                Text("稍后再说")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.readableSubtext)
                    .minimumTapTarget()
            }
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onShowMemberPricing?()
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

    private func formatClockTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private struct PlaybackMoment: Identifiable {
        let id: String
        let eyebrow: String
        let title: String
        let body: String
        let amountText: String?
    }

    private func buildPlaybackMoments() -> [PlaybackMoment] {
        guard !todayItems.isEmpty else { return [] }
        let topCategory = topCategoryText()
        let dominantScene = LifeSceneSemanticService.dominantScene(in: todayItems)
        let lifeMark = LifeMarkService
            .aggregates(for: todayItems, allItems: homeViewModel.items, isMember: true, limit: 1)
            .first
        if todayItems.count > 8 {
            return densePlaybackMoments(
                topCategory: topCategory,
                dominantScene: dominantScene,
                lifeMark: lifeMark
            )
        }

        var moments: [PlaybackMoment] = []

        if todayItems.count >= 3 {
            moments.append(
                PlaybackMoment(
                    id: "summary-opening",
                    eyebrow: "先看一眼",
                    title: "今天记了 \(todayItems.count) 笔",
                    body: openingBody(dominantScene: dominantScene, lifeMark: lifeMark),
                    amountText: todayItems.reduce(0) { $0 + $1.amount }.formatted(.cny)
                )
            )
        }

        moments += todayItems.prefix(12).map { item in
            PlaybackMoment(
                id: "item-\(item.id)",
                eyebrow: momentEyebrow(for: item),
                title: playbackTitle(for: item),
                body: itemMomentBody(for: item),
                amountText: item.amount.formatted(.cny)
            )
        }

        if todayItems.count >= 4 {
            moments.append(
                PlaybackMoment(
                    id: "summary-close",
                    eyebrow: "看完今天",
                    title: themeTitle(topCategory: topCategory, dominantScene: dominantScene),
                    body: themeBody(topCategory: topCategory, dominantScene: dominantScene),
                    amountText: nil
                )
            )
        }

        return moments
    }

    private func topCategoryText() -> String {
        Dictionary(grouping: todayItems, by: \.category)
            .map { (category: $0.key, count: $0.value.count, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted {
                if $0.count == $1.count { return $0.amount > $1.amount }
                return $0.count > $1.count
            }
            .first?.category.rawValue ?? "日常"
    }

    private func densePlaybackMoments(
        topCategory: String,
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?,
        lifeMark: LifeMarkAggregate?
    ) -> [PlaybackMoment] {
        var moments: [PlaybackMoment] = [
            PlaybackMoment(
                id: "summary-opening",
                eyebrow: "先看一眼",
                title: "今天记了 \(todayItems.count) 笔",
                body: openingBody(dominantScene: dominantScene, lifeMark: lifeMark),
                amountText: todayItems.reduce(0) { $0 + $1.amount }.formatted(.cny)
            )
        ]

        moments += todayTimeBlocks().compactMap { block in
            guard !block.items.isEmpty else { return nil }
            let total = block.items.reduce(0) { $0 + $1.amount }
            return PlaybackMoment(
                id: "time-\(block.id)",
                eyebrow: block.label,
                title: "\(block.label)有 \(block.items.count) 笔",
                body: timeBlockBody(label: block.label, items: block.items),
                amountText: total.formatted(.cny)
            )
        }

        moments.append(
            PlaybackMoment(
                id: "summary-close",
                eyebrow: "看完今天",
                title: themeTitle(topCategory: topCategory, dominantScene: dominantScene),
                body: themeBody(topCategory: topCategory, dominantScene: dominantScene),
                amountText: nil
            )
        )

        return moments
    }

    private func openingBody(
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?,
        lifeMark: LifeMarkAggregate?
    ) -> String {
        let categories = categoryMixText()
        if let lifeMark {
            let detail = LifeMarkService.primaryLine(for: lifeMark)
            if !detail.isEmpty {
                return "\(detail) 今天照着发生的顺序听一遍，会更贴近当天。"
            }
        }
        if let dominantScene = dominantScene, dominantScene.count >= 2 {
            switch dominantScene.signal.kind {
            case .commute:
                return "今天路上的记录比较多。出门、等待、到达，都算在今天里。"
            case .cityRoute:
                return "今天在城市里换过几个位置，路上的时间也算今天的一部分。"
            case .breakfast, .quickMeal, .workMeal:
                return "今天几次吃饭都在记录里，饭点串起来，今天就清楚了。"
            case .coffee:
                return "今天有几杯喝的，可能是提神，也可能只是解渴。"
            case .convenienceSupply, .groceries, .homeSupply:
                return "今天补了一些日用或家里会用到的东西，都是会派上用场的。"
            case .medicalVisit, .medicineCare, .fitness, .bodyCare:
                return "今天有几笔健康或身体相关记录，先把安排记清楚。"
            default:
                break
            }
        }
        return "\(categories)这些记录都在今天。先照着发生的顺序听一遍。"
    }

    private func categoryMixText() -> String {
        let ranked = Dictionary(grouping: todayItems, by: \.category)
            .map { (category: $0.key, count: $0.value.count, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted {
                if $0.count == $1.count { return $0.amount > $1.amount }
                return $0.count > $1.count
            }
            .prefix(2)
            .map { $0.category.rawValue }
        guard !ranked.isEmpty else { return "日常" }
        return ranked.joined(separator: "、")
    }

    private func todayTimeBlocks() -> [(id: String, label: String, items: [HomeItem])] {
        [
            ("morning", "上午", todayItems.filter { Calendar.current.component(.hour, from: $0.createdAt) < 12 }),
            ("afternoon", "下午", todayItems.filter {
                let hour = Calendar.current.component(.hour, from: $0.createdAt)
                return hour >= 12 && hour < 18
            }),
            ("evening", "晚上", todayItems.filter { Calendar.current.component(.hour, from: $0.createdAt) >= 18 })
        ]
    }

    private func timeBlockBody(label: String, items: [HomeItem]) -> String {
        let categories = Dictionary(grouping: items, by: \.category)
            .map { (category: $0.key, count: $0.value.count, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted {
                if $0.count == $1.count { return $0.amount > $1.amount }
                return $0.count > $1.count
            }
            .prefix(2)
            .map { $0.category.rawValue }
            .joined(separator: "、")
        let first = items.first.map { playbackTitle(for: $0) } ?? "一笔记录"
        if items.count == 1 {
            return "\(label)主要是「\(first)」。这笔放在今天的位置很清楚。"
        }
        if categories.isEmpty {
            return "\(label)有 \(items.count) 笔，先照着发生的顺序看。"
        }
        return "\(label)留下 \(items.count) 笔，主要和\(categories)有关。先看发生了什么。"
    }

    private func playbackTitle(for item: HomeItem) -> String {
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lateTitle = HomeItem.lateWorkCommutePlaybackTitle(for: item),
           ["下班", "通勤", "通勤路上", "日常出行", "公共交通一段", "下班路上这一程"].contains(title) {
            return lateTitle
        }
        let hour = Calendar.current.component(.hour, from: item.createdAt)
        let replacements: [String: String] = [
            "上班路上的一段车程": hour < 12 ? "早上路上这一程" : "路上这一程",
            "下班路上的一段车程": "下班路上这一程",
            "公共交通一段": "公交地铁这一趟",
            "早间路线走完了": "早上这趟路走完了",
            "晚间通勤完成": "下班这趟路到家了"
        ]
        return replacements[title] ?? title
    }

    private func momentEyebrow(for item: HomeItem) -> String {
        "\(formatClockTime(item.createdAt)) · \(item.category.label)"
    }

    private func itemMomentBody(for item: HomeItem) -> String {
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
        let hour = Calendar.current.component(.hour, from: item.createdAt)
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
            return "买了点需要的东西。"
        case .medicalVisit, .medicineCare, .fitness, .bodyCare:
            return "今天身体这边有笔安排。"
        default:
            return "这笔记录先放进今天。"
        }
    }

    private func playbackContainsDrinkCue(_ text: String) -> Bool {
        ["咖啡", "拿铁", "美式", "奶茶", "饮品", "饮料", "喝的", "茶饮", "可乐", "雪碧", "汽水", "果汁", "柠檬茶", "水溶", "c100", "维c", "维C", "维他"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private func playbackContainsLuweiCue(_ text: String) -> Bool {
        ["绝味", "鸭脖", "鸭货", "卤味", "周黑鸭", "煌上煌"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private func playbackContainsNightMarketCue(_ text: String) -> Bool {
        ["夜市", "夜摊", "大排档", "生蚝", "烤生蚝", "鱿鱼", "铁板鱿鱼", "烧烤", "烤串", "串串"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private func playbackContainsRoastDuckCue(_ text: String) -> Bool {
        ["烤鸭", "烧鸭", "卤鸭", "鸭肉"].contains {
            text.localizedCaseInsensitiveContains($0)
        }
    }

    private func themeTitle(
        topCategory: String,
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?
    ) -> String {
        guard let dominantScene = dominantScene, dominantScene.count >= 2 else {
            return "\(topCategory)多一些"
        }
        switch dominantScene.signal.kind {
        case .commute:
            return "今天路上有几格"
        case .cityRoute:
            return "今天在城市里移动过"
        case .breakfast, .quickMeal, .workMeal:
            return "今天吃饭这条线清楚"
        case .coffee:
            return "今天买了几次喝的"
        case .convenienceSupply, .groceries, .homeSupply:
            return "今天补了些需要的"
        case .shopping:
            return "今天买到了一些东西"
        case .medicalVisit, .medicineCare:
            return "今天身体这边没落下"
        case .fitness, .bodyCare:
            return "今天有身体相关记录"
        case .social:
            return "今天有一点人情往来"
        default:
            return "\(topCategory)多一点"
        }
    }

    private func themeBody(
        topCategory: String,
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?
    ) -> String {
        guard let dominantScene = dominantScene, dominantScene.count >= 2 else {
            return "今天「\(topCategory)」出现得多一些。记到这里就够了。"
        }
        switch dominantScene.signal.kind {
        case .commute:
            return "通勤出现了 \(dominantScene.count) 次。它不只是上班两个字，也包括出门、等车、到达和回来的那段时间。"
        case .cityRoute:
            return "出行出现了 \(dominantScene.count) 次，今天确实在城市里换过几个位置。"
        case .breakfast, .quickMeal, .workMeal:
            return "吃饭出现了 \(dominantScene.count) 次，按时间能看到今天的饭点。"
        case .coffee:
            return "咖啡饮品出现了 \(dominantScene.count) 次。有的是提神，有的是解渴，先照着发生的顺序放好。"
        case .convenienceSupply, .groceries, .homeSupply:
            return "补给出现了 \(dominantScene.count) 次，都是让今天少一点缺口的小东西。"
        case .shopping:
            return "添置出现了 \(dominantScene.count) 次，可能是需要，也可能是兴趣里的一点投入。"
        case .medicalVisit, .medicineCare:
            return "健康相关出现了 \(dominantScene.count) 次，看诊、用药或检查都先记清楚。"
        case .fitness, .bodyCare:
            return "身体相关出现了 \(dominantScene.count) 次，训练、护理或恢复都在今天的位置上。"
        case .social:
            return "人情往来出现了 \(dominantScene.count) 次，日子里也有和别人相连的部分。"
        default:
            return "这类记录出现了 \(dominantScene.count) 次，今天的主要内容更清楚。"
        }
    }

    private func weatherPlaybackLine(for item: HomeItem) -> String? {
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
