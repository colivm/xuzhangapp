import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    var onQuickRecord: () -> Void = {}
    var onNavigateStats: (() -> Void)? = nil
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    @State private var showPlayback = false
    @State private var showFirstRecordToast = false
    @State private var todayPlaybackQuotaMessage: String?
    private let dailyQuotaStore = DailyFeatureQuotaStore()

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                homeContent
            }

            if showFirstRecordToast {
                firstRecordToast
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .onAppear {
            handleRouteGuidance(homeViewModel.activeRouteGuidance)
        }
        .onChange(of: homeViewModel.activeRouteGuidance) { _, guidance in
            handleRouteGuidance(guidance)
        }
        .sheet(isPresented: $showPlayback) {
            BillPlaybackSheet(
                onNavigateToSettings: { onNavigateSettings?() },
                onShowMemberPricing: { onShowMemberPricing?() }
            )
                .id(UUID())
                .environmentObject(homeViewModel)
        }
        .alert("今日回放次数已用完", isPresented: Binding(
            get: { todayPlaybackQuotaMessage != nil },
            set: { if !$0 { todayPlaybackQuotaMessage = nil } }
        )) {
            Button("了解会员") {
                todayPlaybackQuotaMessage = nil
                onShowMemberPricing?()
            }
            Button("知道了", role: .cancel) {
                todayPlaybackQuotaMessage = nil
            }
        } message: {
            Text(todayPlaybackQuotaMessage ?? "")
        }
    }

    private var homeContent: some View {
        VStack(spacing: 12) {
            todayStoryHero
            homeActionRow
            routeGuidanceContent
            todayBillsPanel
            lifeRhythmPanel
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var homeActionRow: some View {
        HStack(spacing: 10) {
            homeActionCard(
                title: "记下一笔",
                subtitle: "只输金额也可以",
                systemImage: "plus.circle.fill",
                isPrimary: true,
                action: onQuickRecord
            )
            homeActionCard(
                title: "听今日回放",
                subtitle: homeViewModel.todayItems.isEmpty ? "有记录后可播放" : "十几秒叙完今天",
                systemImage: "play.circle.fill",
                isPrimary: false,
                action: requestTodayPlayback
            )
        }
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
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            todayBillsContent
        }
        .glassPanel(radius: 24, padding: 24)
    }

    @ViewBuilder
    private var todayBillsContent: some View {
        if homeViewModel.recentThreeItems.isEmpty {
            VStack(spacing: 0) {
                emptyStateArt
                    .padding(.vertical, 8)
            }
        } else {
            ForEach(Array(homeViewModel.recentThreeItems.enumerated()), id: \.element.id) { index, item in
                billListItem(item: item, isFirst: index == 0)
            }
        }
    }

    private var lifeRhythmPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("近期生活节奏")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            lifeRhythmContent
        }
        .glassPanel(radius: 24, padding: 24)
    }

    @ViewBuilder
    private var lifeRhythmContent: some View {
        if let card = homeViewModel.latestActionCard, !card.text.isEmpty {
            Text(card.text)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.88))
            Text(card.updatedAt, style: .relative)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.subtext)
        } else if homeViewModel.recentThreeItems.isEmpty {
            Text("随手记几笔，这里会慢慢长出你的生活痕迹。")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.subtext)
        } else {
            lifeRhythmFallback
        }
    }

    private var lifeRhythmFallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            let daysWithRecords = countDaysWithRecords()
            if daysWithRecords > 0 {
                Text("已坚持记录 \(daysWithRecords) 天")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.9))
            }
            Text(lifeRhythmFallbackText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        }
    }

    private var lifeRhythmFallbackText: String {
        homeViewModel.weekTopCategoryText != "暂无"
            ? "最近「\(homeViewModel.weekTopCategoryText)」出现得多一点，像这段日子的一个小主题。"
            : "随手记几笔，这里会慢慢长出你的生活痕迹。"
    }

    private var todayStoryHero: some View {
        let narrative = homeViewModel.todayStoryNarrative
        return VStack(alignment: .leading, spacing: 12) {
            Text("今日小记")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            Text(narrative.title)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(narrative.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.78))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                narrativePill(narrative.todayTotalText)
                narrativePill(narrative.weekTotalText)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanelWithTint(radius: 24, padding: 24)
    }

    private func narrativePill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.subtext.opacity(0.88))
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
                        .foregroundStyle(AppColors.subtext.opacity(0.88))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isPrimary
                                ? [
                                    AppColors.accent.opacity(0.14),
                                    Color.white.opacity(0.70)
                                  ]
                                : [
                                    Color.white.opacity(0.74),
                                    Color.white.opacity(0.62)
                                  ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isPrimary
                            ? AppColors.accent.opacity(0.26)
                            : Color.white.opacity(0.54),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppColors.subtext.opacity(0.08), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func homeActionIconBadge(systemImage: String) -> some View {
        Image(systemName: systemImage == "plus.circle.fill" ? "plus" : "play.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColors.accent.opacity(0.92))
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(AppColors.accent.opacity(0.13))
            )
            .overlay(
                Circle()
                    .stroke(AppColors.accent.opacity(0.20), lineWidth: 1)
            )
    }

    private var firstRecordToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("用十几秒叙一下今天")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text("第一笔已经记好，听一遍今日回放。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext)
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
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 30, height: 30)
                    .background(AppColors.accent.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(guidance.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                    Text(guidance.message)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
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
    }

    private func handleRouteGuidance(_ guidance: HomeViewModel.PlaybackRouteGuidance?) {
        guard guidance == .firstRecordTodayPlayback else { return }
        showFirstRecordToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            requestTodayPlayback()
            showFirstRecordToast = false
            homeViewModel.consumeRouteGuidance(.firstRecordTodayPlayback)
        }
    }

    private func requestTodayPlayback() {
        guard !homeViewModel.todayItems.isEmpty else {
            showPlayback = true
            return
        }
        guard dailyQuotaStore.canPlayTodayPlayback(isMember: homeViewModel.hasMemberAccess) else {
            todayPlaybackQuotaMessage = "今日免费回放次数已用完（1/1）。会员可无限回看今日生活回放。"
            return
        }
        dailyQuotaStore.markTodayPlaybackStarted(isMember: homeViewModel.hasMemberAccess)
        showPlayback = true
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

    private func billListItem(item: HomeItem, isFirst: Bool) -> some View {
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

            if !item.emotionTag.isEmpty {
                Text(item.emotionTag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.74))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.08)))
                    .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.18), lineWidth: 0.7))
                    .padding(.bottom, 4)
            }
            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))

                Text("·").foregroundStyle(AppColors.subtext)

                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(Color.white.opacity(0.30))
                    .frame(height: 1)
                    .padding(.top, -10)
            }
        }
    }

    // MARK: - Helpers

    private func countDaysWithRecords() -> Int {
        let cal = Calendar.current
        let days = Set(homeViewModel.items.map { cal.startOfDay(for: $0.createdAt) })
        return days.count
    }
}

// MARK: - Glass Panel with Hero Tint

private extension View {
    func glassPanelWithTint(radius: CGFloat = 24, padding: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.08), Color.white.opacity(0.06)],
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

// MARK: - Bill Playback Sheet

struct BillPlaybackSheet: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @State private var activeIndex = -1
    @State private var isPlaying = false
    @State private var playbackDone = false
    @State private var showMemberNudge = false
    @Environment(\.dismiss) private var dismiss
    var onNavigateToSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    private let duration: TimeInterval = 10.0
    private let nudgeService = MemberNudgePolicyService()

    private var todayItems: [HomeItem] {
        homeViewModel.items.filter {
            Calendar.current.isDateInToday($0.createdAt)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            if todayItems.isEmpty {
                emptyPlaybackState
            } else {
                playbackContent
                Spacer()
                playbackDoneSection
                playbackControls
            }
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title3)
                    .foregroundStyle(AppColors.subtext.opacity(0.5))
            }.padding(12)
        }
        .presentationDetents([.height(360)])
        .presentationBackground(.clear)
        .presentationCornerRadius(24)
        .onAppear {
            activeIndex = -1; playbackDone = false; isPlaying = false; showMemberNudge = false
            if !todayItems.isEmpty { isPlaying = true }
        }
        .onChange(of: isPlaying) { _, playing in
            guard playing, !todayItems.isEmpty, !playbackDone else { return }
            let count = todayItems.count
            Task {
                let interval = duration / Double(count)
                for i in 0..<count {
                    guard self.isPlaying, !self.playbackDone else { break }
                    self.activeIndex = i
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                if self.isPlaying {
                    self.playbackDone = true
                    self.isPlaying = false
                    if !homeViewModel.hasMemberAccess && nudgeService.canShow(scene: "playback_complete") {
                        self.showMemberNudge = true
                        nudgeService.markShown(scene: "playback_complete")
                    }
                }
            }
        }
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
                .foregroundStyle(AppColors.subtext)
        }
        .frame(maxHeight: .infinity)
    }

    private var playbackContent: some View {
        VStack(spacing: 0) {
            playbackHeader
            playbackTimeline
        }
    }

    private var playbackHeader: some View {
        VStack(spacing: 6) {
            Text("今日生活回放")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text("10 秒看完今天的生活节奏")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var playbackTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(todayItems.enumerated()), id: \.element.id) { index, item in
                        playbackTimelineRow(item: item, index: index)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: activeIndex) { _, index in
                guard index >= 0 else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func playbackTimelineRow(item: HomeItem, index: Int) -> some View {
        let isActive = index == activeIndex
        let isRevealed = index <= activeIndex || activeIndex == -1

        return VStack(spacing: 0) {
            playbackTimelineMainRow(item: item, index: index, isActive: isActive)
            playbackTimelineNoteRow(item: item)
        }
        .padding(.vertical, isActive ? 10 : 7)
        .padding(.horizontal, 20)
        .background(activeTimelineBackground(isActive: isActive))
        .scaleEffect(isActive && !playbackDone ? 1.01 : 1.0, anchor: .leading)
        .opacity(isRevealed ? 1 : 0.35)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: activeIndex)
        .id(index)
        .overlay(alignment: .top) {
            if index > 0 {
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 0.6)
                    .padding(.horizontal, 12)
            }
        }
    }

    private func playbackTimelineMainRow(item: HomeItem, index: Int, isActive: Bool) -> some View {
        let isRevealed = index <= activeIndex
        let textColor = isRevealed ? AppColors.text : AppColors.subtext
        let dotColor = isRevealed ? AppColors.accent : Color.white.opacity(0.4)
        let categoryWeight: Font.Weight = isActive ? .semibold : .regular

        return HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 5) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                Text(formatClockTime(item.createdAt))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor)
                Text("·")
                    .foregroundStyle(AppColors.subtext.opacity(0.35))
                Text(item.category.rawValue)
                    .font(.system(size: 14, weight: categoryWeight))
                    .foregroundStyle(textColor)
            }
            Spacer()
            Text(item.amount.formatted(.cny))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
        }
    }

    private func playbackTimelineNoteRow(item: HomeItem) -> some View {
        HStack(spacing: 4) {
            Text(item.title)
                .font(.system(size: 11))
            if !item.emotionTag.isEmpty {
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.subtext.opacity(0.4))
                Text(item.emotionTag)
                    .font(.system(size: 11))
            }
            Spacer()
        }
        .foregroundStyle(AppColors.subtext.opacity(0.6))
        .padding(.top, 2)
    }

    @ViewBuilder
    private func activeTimelineBackground(isActive: Bool) -> some View {
        if isActive && !playbackDone {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.accent.opacity(0.05))
                )
        }
    }

    @ViewBuilder
    private var playbackDoneSection: some View {
        if playbackDone {
            Text("今天的生活节奏已记录完毕✨")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.8))
                .padding(.bottom, 8)

            if showMemberNudge {
                memberPlaybackNudge
            }
        }
    }

    private var memberPlaybackNudge: some View {
        VStack(spacing: 10) {
            Text("把这周的生活轨迹长期留住，回看会更温柔。")
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
                    .foregroundStyle(AppColors.subtext.opacity(0.7))
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
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

        return Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.text.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
            )
    }

    private var replayPlaybackControlLabel: some View {
        let title = playbackDone ? "再看一遍" : "重播"

        return Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule(style: .continuous).fill(AppColors.accent))
    }

    private var progressFraction: CGFloat {
        playbackDone ? 1 : CGFloat(max(0, activeIndex)) / CGFloat(max(1, todayItems.count - 1))
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
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(HomeViewModel())
            .environmentObject(SettingsViewModel())
    }
}
