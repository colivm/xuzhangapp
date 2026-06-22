import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var onQuickRecord: () -> Void = {}
    var onNavigateStats: (() -> Void)? = nil
    var onNavigateWeeklyTrace: (() -> Void)? = nil
    var onNavigateSettings: (() -> Void)? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    @State private var showPlayback = false
    @State private var showFirstRecordToast = false
    @State private var showTodayRecordsSheet = false
    @State private var editingItem: HomeItem?
    @State private var todayInlineEditingItemID: UUID?
    @State private var todaySwipedItemID: UUID?
    @State private var todayDeletingItemID: UUID?
    @State private var todayPlaybackQuotaMessage: String?
    @State private var petHint: String = "有一笔就记一笔，晚点也能补。"
    @State private var petBubbleVisible = false
    @State private var todayBillsFocusPulse = false
    @State private var todayBillsFocusTick = 0
    @State private var highlightedSavedItemID: UUID?
    private let dailyQuotaStore = DailyFeatureQuotaStore()

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    homeContent
                }
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
                .id(UUID())
                .environmentObject(homeViewModel)
        }
        .sheet(isPresented: $showTodayRecordsSheet) {
            todayRecordsSheet
        }
        .sheet(item: $editingItem) { item in
            editSheet(for: item)
        }
        .alert("今天先手动记也可以", isPresented: Binding(
            get: { todayPlaybackQuotaMessage != nil },
            set: { if !$0 { todayPlaybackQuotaMessage = nil } }
        )) {
            Button("让回放不中断") {
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
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AppColors.text)
            todayBillsContent
        }
        .glassPanel(radius: 24, padding: 22)
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
                    Button {
                        editingItem = item
                    } label: {
                        billListItem(
                            item: item,
                            isFirst: index == 0,
                            isHighlighted: highlightedSavedItemID == item.id
                        )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
                        .foregroundStyle(AppColors.subtext.opacity(0.9))
                        .padding(.top, 8)
                    }
                    .buttonStyle(.plain)
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
        .glassPanel(radius: 24, padding: 22)
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
            Text("先记几笔，这里会慢慢长出最近的生活线索。")
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
                Text("已记录 \(daysWithRecords) 天")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.9))
            }
            Text(lifeRhythmFallbackText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        }
    }

    private var lifeRhythmFallbackText: String {
        if !homeViewModel.weekLifeThemeText.isEmpty {
            return homeViewModel.weekLifeThemeText
        }
        return homeViewModel.weekTopCategoryText != "暂无"
            ? "最近「\(homeViewModel.weekTopCategoryText)」这类记录多一点，像这段日子的一个小主题。"
            : "先记几笔，这里会长出最近的生活线索。"
    }

    private var todayStoryHero: some View {
        let narrative = homeViewModel.todayStoryNarrative
        return VStack(alignment: .leading, spacing: 10) {
            Text("今日小记")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.88))

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

                Button {
                    onNavigateWeeklyTrace?()
                } label: {
                    narrativePill(narrative.weekTotalText)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanelWithTint(radius: 24, padding: 22)
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
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
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
                    .fill(AppColors.accent.opacity(0.16))
            )
            .overlay(
                Circle()
                    .stroke(AppColors.accent.opacity(0.20), lineWidth: 1)
            )
    }

    private var todayBillsFocusOverlay: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
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
        let isMember = settingsViewModel.settings.hasMemberAccess
        guard dailyQuotaStore.canPlayTodayPlayback(isMember: isMember) else {
            todayPlaybackQuotaMessage = "今日免费回放剩余 0/1 次。明天可继续播放；会员适合晚上反复整理当天记录，不用等刷新。"
            return
        }
        dailyQuotaStore.markTodayPlaybackStarted(isMember: isMember)
        showPlayback = true
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }

            if shouldShowHomeEmotion(for: item) {
                let emotionTag = item.displayEmotionTag
                Text(emotionTag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.74))
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
                    .foregroundStyle(AppColors.subtext.opacity(0.9))

                Text("·").foregroundStyle(AppColors.subtext)

                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.92))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHighlighted ? AppColors.accent.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHighlighted ? AppColors.accent.opacity(0.22) : Color.clear, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if !isFirst {
                PaperCreaseDivider()
                    .padding(.top, -10)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: isHighlighted)
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

                ScrollViewReader { proxy in
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 92)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: todayInlineEditingItemID) { _, itemID in
                        guard let itemID else { return }
                        scrollTodayEditorIntoView(itemID, proxy: proxy, delay: 0.34)
                    }
                }
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
        return ZStack(alignment: .trailing) {
            if !isEditing {
                todaySwipeActions(for: item, isVisible: isSwiped)
                    .padding(.trailing, 10)
                    .zIndex(2)
            }

            VStack(alignment: .leading, spacing: isEditing ? 10 : 8) {
                todayRecordSummary(item, isEditing: isEditing, isFirst: isFirst)
                if isEditing {
                    TraceInlineRecordEditor(
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
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isEditing ? 14 : 16)
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
            .offset(x: isSwiped ? -76 : 0)
            .scaleEffect(isDeleting ? 0.96 : 1, anchor: .trailing)
            .opacity(isDeleting ? 0 : 1)
            .frame(height: isDeleting ? 0 : nil)
            .clipped()
            .onTapGesture {
                if !isEditing && !isSwiped {
                    withAnimation(todayEditSpring) {
                        todayInlineEditingItemID = item.id
                    }
                }
            }

            if !isEditing && !isSwiped {
                todaySwipeHandle(for: item, isSwiped: isSwiped)
                    .zIndex(3)
            }
        }
        .id(item.id)
        .animation(todayEditSpring, value: isEditing)
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
                    .opacity(isEditing ? 0.50 : 1)

                Spacer(minLength: 8)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(todayRecordAmountInk)
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
                Text("·").foregroundStyle(AppColors.subtext)
                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext.opacity(0.96))
                Spacer()
            }
            .opacity(isEditing ? 0 : 1)
            .frame(height: isEditing ? 0 : nil)
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
            allItems: nil,
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
            .shadow(
                color: AppColors.subtext.opacity(isEditing ? 0.18 : 0.12),
                radius: isEditing ? 20 : 16,
                x: 0,
                y: isEditing ? 12 : 8
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
        return Image(systemName: todayRecordWatermarkSymbol(for: item.category))
            .font(.system(size: 64, weight: .ultraLight))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(accent.opacity(0.22))
            .frame(width: 124, height: 74, alignment: .trailing)
            .offset(x: 8, y: 10)
            .clipped()
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
        DragGesture(minimumDistance: 22, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                let isHorizontalSwipe = abs(horizontal) > max(44, abs(vertical) * 1.35)
                guard isHorizontalSwipe else { return }
                withAnimation(todayEditSpring) {
                    todaySwipedItemID = horizontal < 0 ? item.id : nil
                }
            }
    }

    private func scrollTodayEditorIntoView(_ itemID: UUID, proxy: ScrollViewProxy, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard todayInlineEditingItemID == itemID else { return }
            withAnimation(todayEditSpring) {
                proxy.scrollTo(itemID, anchor: .center)
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
        }
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
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
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

    private var playbackMoments: [PlaybackMoment] {
        buildPlaybackMoments()
    }

    private var currentPlaybackMoment: PlaybackMoment? {
        guard !playbackMoments.isEmpty else { return nil }
        if activeIndex < 0 { return playbackMoments.first }
        return playbackMoments[min(activeIndex, playbackMoments.count - 1)]
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
                    .foregroundStyle(AppColors.subtext.opacity(0.76))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.64), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .presentationDetents([.height(todayItems.isEmpty ? 320 : 620)])
        .presentationBackground(.clear)
        .presentationCornerRadius(30)
        .onAppear {
            activeIndex = -1; playbackDone = false; isPlaying = false; showMemberNudge = false
            if !todayItems.isEmpty { isPlaying = true }
        }
        .onChange(of: isPlaying) { _, playing in
            guard playing, !todayItems.isEmpty, !playbackDone else { return }
            let count = playbackMoments.count
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
                    if !settingsViewModel.settings.hasMemberAccess && nudgeService.canShow(scene: "playback_complete") {
                        self.showMemberNudge = true
                        nudgeService.markShown(scene: "playback_complete")
                    }
                }
            }
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
                .foregroundStyle(AppColors.subtext)
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
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(todayItems.count) 笔")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.58)))
        }
        .padding(.top, 8)
    }

    private var todayPlaybackSubtitle: String {
        if playbackDone { return "今天的几笔已经播完" }
        if isPlaying { return "正在把今天读成一段胶片" }
        return "暂停在这一格"
    }

    private var playbackStage: some View {
        let moment = currentPlaybackMoment
        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 7) {
                    ForEach(playbackMoments.indices, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index <= max(activeIndex, 0) ? AppColors.accent.opacity(0.82) : Color.white.opacity(0.55))
                            .frame(height: 4)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(moment?.eyebrow ?? "今天")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.accentDark.opacity(0.82))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule(style: .continuous).fill(Color.white.opacity(0.54)))
                        if let amount = moment?.amountText {
                            Text(amount)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.text.opacity(0.72))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule(style: .continuous).fill(Color.white.opacity(0.42)))
                        }
                    }

                    Text(moment?.title ?? "今天的记录")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineSpacing(5)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)

                    Text(moment?.body ?? "先留下几笔，晚上再回来看。")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.94))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(systemName: playbackDone ? "checkmark.circle.fill" : "waveform")
                        .font(.system(size: 14, weight: .bold))
                    Text(playbackDone ? "今日胶片已放完" : "轻轻播放中")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppColors.accent.opacity(0.88))
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 286, alignment: .leading)
            .background(todayPlaybackStageBackground)
            .overlay(todayPlaybackStageBorder)
            .shadow(color: AppColors.subtext.opacity(0.14), radius: 22, x: 0, y: 12)

            Image(systemName: playbackStageSymbol)
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.08))
                .offset(x: 6, y: 4)
        }
        .animation(.easeInOut(duration: 0.24), value: activeIndex)
    }

    private var playbackStageSymbol: String {
        guard let moment = currentPlaybackMoment else { return "play.rectangle.fill" }
        if moment.id.contains("first") { return "sunrise.fill" }
        if moment.id.contains("theme") { return "sparkles" }
        if moment.id.contains("close") { return "moon.stars.fill" }
        return "rectangle.stack.fill"
    }

    private var todayPlaybackStageBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.60))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var todayPlaybackStageBorder: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.74), AppColors.accent.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var playbackFilmStrip: some View {
        HStack(spacing: 8) {
            ForEach(Array(playbackMoments.enumerated()), id: \.element.id) { index, moment in
                Button {
                    activeIndex = index
                    playbackDone = false
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(moment.eyebrow)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(index == activeIndex ? AppColors.accent : AppColors.subtext)
                            .lineLimit(1)
                        Text(moment.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.text.opacity(index <= max(activeIndex, 0) ? 0.92 : 0.54))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(index == activeIndex ? Color.white.opacity(0.70) : Color.white.opacity(0.32))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(index == activeIndex ? AppColors.accent.opacity(0.25) : Color.white.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var playbackDoneSection: some View {
        if playbackDone {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("今天的记录已回放完毕")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppColors.accent.opacity(0.86))
            .padding(.bottom, 8)

            if showMemberNudge {
                memberPlaybackNudge
            }
        }
    }

    private var memberPlaybackNudge: some View {
        VStack(spacing: 10) {
            Text("把这周记录长期留住，之后还能回来听。")
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

        return HStack(spacing: 7) {
            Image(systemName: playbackDone ? "xmark" : (isPlaying ? "pause.fill" : "play.fill"))
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
        }
            .foregroundStyle(AppColors.text.opacity(0.82))
            .frame(maxWidth: .infinity)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
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
            .aggregates(for: todayItems, allItems: todayItems, isMember: true, limit: 1)
            .first
        let first = todayItems.first
        let representative = representativeItem()
        var moments: [PlaybackMoment] = [
            PlaybackMoment(
                id: "opening",
                eyebrow: "今日回放",
                title: "今天留下 \(todayItems.count) 格",
                body: openingBody(dominantScene: dominantScene, lifeMark: lifeMark),
                amountText: nil
            )
        ]

        if let first {
            moments.append(
                PlaybackMoment(
                    id: "first-\(first.id)",
                    eyebrow: formatClockTime(first.createdAt),
                    title: playbackTitle(for: first),
                    body: firstMomentBody(for: first),
                    amountText: first.amount.formatted(.cny)
                )
            )
        }

        if todayItems.count > 1 {
            moments.append(
                PlaybackMoment(
                    id: "theme",
                    eyebrow: "今天的主线",
                    title: themeTitle(topCategory: topCategory, dominantScene: dominantScene),
                    body: themeBody(topCategory: topCategory, dominantScene: dominantScene),
                    amountText: nil
                )
            )
        }

        if todayItems.count > 1, let representative {
            moments.append(
                PlaybackMoment(
                    id: "close-\(representative.id)",
                    eyebrow: "收尾",
                    title: closingTitle(for: representative),
                    body: closingBody(for: representative),
                    amountText: representative.amount.formatted(.cny)
                )
            )
        }

        return Array(moments.prefix(4))
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

    private func representativeItem() -> HomeItem? {
        todayItems.last ?? todayItems.first
    }

    private func openingBody(
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?,
        lifeMark: LifeMarkAggregate?
    ) -> String {
        let categories = categoryMixText()
        if let lifeMark {
            let detail = LifeMarkService.primaryLine(for: lifeMark)
            if !detail.isEmpty {
                return "\(detail) 今天先不急着算总账，先把这段生活留住。"
            }
        }
        if let dominantScene = dominantScene, dominantScene.count >= 2 {
            switch dominantScene.signal.kind {
            case .commute:
                return "今天反复出现的是路上。出门、等待、到达，这些不只属于交通分类。"
            case .cityRoute:
                return "今天像是在城市里挪了几个位置，回头看会知道自己去过哪些地方。"
            case .breakfast, .quickMeal, .workMeal:
                return "今天先从几次吃饭看起。忙也好、赶饭点也好，身体总要被照顾到。"
            case .coffee:
                return "今天有几杯饮品留下来，它们更像日子中间的小停顿。"
            case .convenienceSupply, .groceries, .homeSupply:
                return "今天像是给生活补了一点库存，少几件惦记的事。"
            case .medicalVisit, .medicineCare, .fitness, .bodyCare:
                return "今天身体这边被认真记了一下，这类记录本来就不该只剩金额。"
            default:
                break
            }
        }
        return "\(categories)这些小事被收进了今天。以后再翻回来，看到的会是这一天的几个片段。"
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

    private func playbackTitle(for item: HomeItem) -> String {
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func firstMomentBody(for item: HomeItem) -> String {
        if let weatherLine = weatherPlaybackLine(for: item) {
            return weatherLine
        }
        let hour = Calendar.current.component(.hour, from: item.createdAt)
        switch LifeSceneSemanticService.classify(item).kind {
        case .commute:
            if hour < 12 {
                return "这笔落在上班路上，清晨出门这件事也被留下了一格。"
            }
            if hour >= 17 {
                return "这笔落在下班路上，到家的那一段也算今天的一部分。"
            }
            return "这笔落在通勤路上，是今天在城市里移动过的证据。"
        case .cityRoute:
            return "先把这趟路记下，后面回看就知道那会儿去了哪里。"
        case .breakfast:
            return "先从早上的一口吃的开始，今天有了开头。"
        case .quickMeal, .workMeal:
            return "这一餐不需要被说得很重，它只是把今天中间那一段稳住了。"
        case .coffee:
            if (11..<14).contains(hour) {
                return "这杯更像工作日中间的一次停顿，和路上的事没什么关系。"
            }
            if hour < 11 {
                return "早上的这杯先把人叫醒一点，今天从这里慢慢展开。"
            }
            if hour >= 17 {
                return "傍晚这杯像给后半天留一点余量，不只是提神。"
            }
            return "这杯饮品被留下来，像今天中间一小段喘气的时间。"
        case .convenienceSupply, .groceries, .homeSupply:
            return "先把需要的东西补上，今天少一件惦记的事。"
        case .medicalVisit, .medicineCare, .fitness, .bodyCare:
            return "先把身体这边的安排记下，这笔以后看起来会比数字更具体。"
        default:
            return "这笔先开了个头，今天就从这里被记住。"
        }
    }

    private func themeTitle(
        topCategory: String,
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?
    ) -> String {
        guard let dominantScene = dominantScene, dominantScene.count >= 2 else {
            return "\(topCategory)多一点"
        }
        switch dominantScene.signal.kind {
        case .commute:
            return "今天路上有几格"
        case .cityRoute:
            return "今天在城市里移动过"
        case .breakfast, .quickMeal, .workMeal:
            return "今天吃饭这条线清楚"
        case .coffee:
            return "今天有几次小停顿"
        case .convenienceSupply, .groceries, .homeSupply:
            return "今天补了些需要的"
        case .shopping:
            return "今天买到了一些东西"
        case .medicalVisit, .medicineCare:
            return "今天身体这边没落下"
        case .fitness, .bodyCare:
            return "今天也照顾了一下自己"
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
            return "不是要总结什么大道理，只是今天「\(topCategory)」出现得更清楚。"
        }
        switch dominantScene.signal.kind {
        case .commute:
            return "通勤出现了 \(dominantScene.count) 次。它不只是上班两个字，也包括出门、等车、到达和回来的那段时间。"
        case .cityRoute:
            return "出行出现了 \(dominantScene.count) 次，今天确实在城市里换过几个位置。"
        case .breakfast, .quickMeal, .workMeal:
            return "吃饭出现了 \(dominantScene.count) 次。它不是消费主题，是今天被照顾到的几段时间。"
        case .coffee:
            return "咖啡饮品出现了 \(dominantScene.count) 次。它们更像小停顿，不必都被解释成路上匆忙或硬撑。"
        case .convenienceSupply, .groceries, .homeSupply:
            return "补给出现了 \(dominantScene.count) 次，都是让今天少一点缺口的小东西。"
        case .shopping:
            return "添置出现了 \(dominantScene.count) 次，可能是需要，也可能是兴趣里的一点投入。"
        case .medicalVisit, .medicineCare:
            return "健康相关出现了 \(dominantScene.count) 次，辛苦归辛苦，至少没有把自己漏掉。"
        case .fitness, .bodyCare:
            return "身体相关出现了 \(dominantScene.count) 次，今天有在照看自己，也给恢复留了位置。"
        case .social:
            return "人情往来出现了 \(dominantScene.count) 次，日子里也有和别人相连的部分。"
        default:
            return "这条线出现了 \(dominantScene.count) 次，今天的轮廓就更清楚一点。"
        }
    }

    private func closingTitle(for item: HomeItem) -> String {
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? playbackTitle(for: item) : tag
    }

    private func closingBody(for item: HomeItem) -> String {
        if let weather = item.memoryContext?.weatherKind,
           weather.contains("雨") || weather.lowercased().contains("rain") {
            return "最后停在「\(playbackTitle(for: item))」。以后翻回来，会知道这一天不只有金额，还有当时的雨。"
        }
        return "最后停在「\(playbackTitle(for: item))」。今天不用讲得很满，能留下这些片段就已经够具体了。"
    }

    private func weatherPlaybackLine(for item: HomeItem) -> String? {
        let weather = item.memoryContext?.weatherKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rainy = weather.contains("雨") || weather.lowercased().contains("rain")
        guard rainy else { return nil }
        switch LifeSceneSemanticService.classify(item).kind {
        case .commute:
            return "这笔落在雨天通勤里。以后再看，会知道那天上班路上有雨，路也可能不太好走。"
        case .cityRoute:
            return "这趟路带着雨天背景，回头看会知道那会儿不是普通出门。"
        default:
            return "这笔旁边有雨天背景。以后再看，会知道今天的空气和天气也在场。"
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
