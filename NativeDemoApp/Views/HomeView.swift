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
                VStack(spacing: 12) {
                // ── Hero Card (matching web .hero) ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日已花")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.subtext)

                    Text(homeViewModel.todayExpenseTotal.formatted(.cny))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .tracking(-0.01 * 44)

                    Text(homeViewModel.todayHeroSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.subtext.opacity(0.88))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanelWithTint(radius: 24, padding: 24)

                // ── Quick Record Button (matching web .mega-btn) ──
                Button("＋ 快速记账") {
                    onQuickRecord()
                }
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.92),
                            AppColors.accent.opacity(0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: AppColors.accent.opacity(0.30), radius: 16, x: 0, y: 6)
                .buttonStyle(.plain)

                if let guidance = homeViewModel.activeRouteGuidance,
                   guidance != .firstRecordTodayPlayback {
                    routeGuidanceBar(guidance)
                }

                // ── Today's Bills Panel ──
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("今日账单")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Button("账单回放") {
                            requestTodayPlayback()
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.accent.opacity(0.84))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.72))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(AppColors.accent.opacity(0.28), lineWidth: 1)
                        )
                        .buttonStyle(.plain)
                    }

                    if homeViewModel.recentThreeItems.isEmpty {
                        // Empty state art (matching web SVG)
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
                .glassPanel(radius: 24, padding: 24)

                // ── Life Rhythm Card (matching web homeActionCard) ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("近期生活节奏")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

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
                        let daysWithRecords = countDaysWithRecords()
                        if daysWithRecords > 0 {
                            Text("已坚持记录 \(daysWithRecords) 天")
                                .font(.system(size: 12))
                                .foregroundStyle(AppColors.subtext.opacity(0.9))
                        }
                        Text(homeViewModel.weekTopCategoryText != "暂无"
                             ? "最近「\(homeViewModel.weekTopCategoryText)」类消费较多，可以稍微留意平衡。"
                             : "随手记几笔，这里会慢慢长出你的生活痕迹。")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.subtext)
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

    private var firstRecordToast: some View {
        HStack(spacing: 10) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("用 10 秒叙一下今天")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text("第一笔已经记好，马上听一遍今日回放。")
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

                Text(item.createdAt.formatted(date: .numeric, time: .shortened))
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
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8).padding(.bottom, 4)

            if todayItems.isEmpty {
                VStack(spacing: 12) {
                    Text("📭").font(.system(size: 40))
                    Text("今天还没有记录，先记一笔吧。")
                        .font(.system(size: 14)).foregroundStyle(AppColors.subtext)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Title matching web: 今日生活回放 + 10秒看完...
                VStack(spacing: 6) {
                    Text("今日生活回放").font(.system(size: 18, weight: .bold)).foregroundStyle(AppColors.text)
                    Text("10 秒看完今天的生活节奏").font(.system(size: 12)).foregroundStyle(AppColors.subtext)
                }.padding(.top, 10).padding(.bottom, 6)

                // Timeline
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(todayItems.enumerated()), id: \.element.id) { idx, item in
                                VStack(spacing: 0) {
                                    // Row 1: time·category on left, amount on right (dark/large)
                                    HStack(alignment: .firstTextBaseline) {
                                        HStack(spacing: 5) {
                                            Circle()
                                                .fill(idx <= activeIndex ? AppColors.accent : Color.white.opacity(0.4))
                                                .frame(width: 7, height: 7)
                                            Text(formatClockTime(item.createdAt))
                                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                                .foregroundStyle(idx <= activeIndex ? AppColors.text : AppColors.subtext)
                                            Text("·").foregroundStyle(AppColors.subtext.opacity(0.35))
                                            Text(item.category.rawValue)
                                                .font(.system(size: 14, weight: idx == activeIndex ? .semibold : .regular))
                                                .foregroundStyle(idx <= activeIndex ? AppColors.text : AppColors.subtext)
                                        }
                                        Spacer()
                                        Text(item.amount.formatted(.cny))
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppColors.text)
                                    }
                                    // Row 2: title·emotionTag (light/pale)
                                    HStack(spacing: 4) {
                                        Text(item.title).font(.system(size: 11))
                                        if !item.emotionTag.isEmpty {
                                            Text("·").font(.system(size: 11)).foregroundStyle(AppColors.subtext.opacity(0.4))
                                            Text(item.emotionTag).font(.system(size: 11))
                                        }
                                        Spacer()
                                    }
                                    .foregroundStyle(AppColors.subtext.opacity(0.6))
                                    .padding(.top, 2)
                                }
                                .padding(.vertical, idx == activeIndex ? 10 : 7)
                                .padding(.horizontal, 20)
                                .background(
                                    idx == activeIndex && !playbackDone
                                        ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                            .overlay(RoundedRectangle(cornerRadius: 14).fill(AppColors.accent.opacity(0.05)))
                                        : nil
                                )
                                .scaleEffect(idx == activeIndex && !playbackDone ? 1.01 : 1.0, anchor: .leading)
                                .opacity(idx <= activeIndex || activeIndex == -1 ? 1 : 0.35)
                                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: activeIndex)
                                .id(idx)
                                .overlay(alignment: .top) {
                                    if idx > 0 { Rectangle().fill(Color.white.opacity(0.25)).frame(height: 0.6).padding(.horizontal, 12) }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: activeIndex) { _, idx in
                        if idx >= 0 {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                    }
                }

                Spacer()

                if playbackDone {
                    Text("今天的生活节奏已记录完毕✨")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.accent.opacity(0.8))
                        .padding(.bottom, 8)

                    // Member nudge card — floating glass layer above controls
                    if showMemberNudge {
                        VStack(spacing: 10) {
                            Text("把这周的生活轨迹长期留住，回看会更温柔。")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.text.opacity(0.88))
                                .multilineTextAlignment(.center)
                            HStack(spacing: 20) {
                                Button { dismiss() } label: {
                                    Text("稍后再说").font(.system(size: 12))
                                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                                }
                                Button {
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onShowMemberPricing?()
                                    }
                                } label: {
                                    Text("✨ 了解会员").font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .background(Capsule(style: .continuous).fill(AppColors.accent))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.5), lineWidth: 0.8)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 16).padding(.bottom, 10)
                        .transition(.opacity.combined(with: .scale(scale: 0.95).combined(with: .offset(y: 8))))
                    }
                }

                // Controls: grid-template-columns 1fr 1fr
                VStack(spacing: 10) {
                    // 2-column grid matching web .bill-playback-actions
                    HStack(spacing: 8) {
                        Button {
                            if playbackDone { dismiss() }
                            else { isPlaying.toggle() }
                        } label: {
                            Text(playbackDone ? "关闭" : (isPlaying ? "暂停" : "播放"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppColors.text.opacity(0.8))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.35), lineWidth: 0.6))
                        }
                        Button { restartPlayback() } label: {
                            Text(playbackDone ? "再看一遍" : "重播").font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(Capsule(style: .continuous).fill(AppColors.accent))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20).padding(.bottom, 16)
                }
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
