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
        .alert("今天的免费回放已用完", isPresented: Binding(
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
            todayPlaybackQuotaMessage = "今天的免费回放次数已用完。明天可继续播放，会员可不限次数回看。"
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
                Color(red: 233/255, green: 243/255, blue: 236/255),
                Color(red: 219/255, green: 235/255, blue: 225/255),
                Color(red: 244/255, green: 248/255, blue: 244/255)
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
        return ZStack(alignment: .trailing) {
            if !isEditing {
                todaySwipeActions(for: item, isVisible: isSwiped)
                    .padding(.trailing, 4)
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
            .onTapGesture {
                if !isEditing && !isSwiped {
                    withAnimation(todayEditSpring) {
                        todayInlineEditingItemID = item.id
                    }
                }
            }
            .allowsHitTesting(!isSwiped)

            if !isEditing {
                todaySwipeHandle(for: item, isSwiped: isSwiped)
                    .padding(.trailing, isSwiped ? 82 : 0)
                    .zIndex(2)
            }
        }
        .id(item.id)
        .animation(todayEditSpring, value: isEditing)
        .animation(todayEditSpring, value: isSwiped)
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

    private func todayRecordRowBackground(item: HomeItem, isEditing: Bool) -> some View {
        let accent = todayRecordCategoryAccent(for: item)
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.white.opacity(isEditing ? 0.62 : 0.52))
            )
            .overlay(
                LinearGradient(
                    colors: isEditing
                    ? [
                        Color.white.opacity(0.64),
                        Color(red: 229/255, green: 242/255, blue: 234/255).opacity(0.80),
                        Color(red: 204/255, green: 228/255, blue: 216/255).opacity(0.54)
                    ]
                    : [
                        Color.white.opacity(0.72),
                        Color.white.opacity(0.42),
                        accent.opacity(0.14)
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
                        accent.opacity(isEditing ? 0.14 : 0.18),
                        Color.white.opacity(0.0)
                    ],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: 150
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            )
            .shadow(
                color: Color(red: 43/255, green: 66/255, blue: 58/255).opacity(isEditing ? 0.18 : 0.12),
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

    private func todayRecordRowBorder(item: HomeItem, isEditing: Bool) -> some View {
        let accent = todayRecordCategoryAccent(for: item)
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: isEditing
                    ? [
                        Color.white.opacity(0.88),
                        Color(red: 104/255, green: 157/255, blue: 136/255).opacity(0.54),
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

    private var todayRecordPrimaryInk: Color {
        Color(red: 30/255, green: 39/255, blue: 53/255)
    }

    private var todayRecordAmountInk: Color {
        Color(red: 31/255, green: 59/255, blue: 64/255)
    }

    private var todayRecordEmotionInk: Color {
        Color(red: 74/255, green: 124/255, blue: 104/255)
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
                    .overlay(Color(red: 204/255, green: 231/255, blue: 221/255).opacity(0.44))
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
        .foregroundStyle(Color(red: 82/255, green: 128/255, blue: 105/255).opacity(0.10))
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
        switch item.category {
        case .dining:
            return Color(red: 128/255, green: 166/255, blue: 137/255)
        case .transport, .daily:
            return Color(red: 117/255, green: 149/255, blue: 181/255)
        case .shopping, .social:
            return Color(red: 186/255, green: 151/255, blue: 69/255)
        case .home, .lodging:
            return Color(red: 139/255, green: 159/255, blue: 168/255)
        case .health:
            return Color(red: 132/255, green: 166/255, blue: 151/255)
        case .entertainment:
            return Color(red: 154/255, green: 143/255, blue: 185/255)
        case .other:
            return AppColors.accent
        }
    }

    private var todayEditSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.08)
    }

    private func todaySwipeActions(for item: HomeItem, isVisible: Bool) -> some View {
        Button(role: .destructive) {
            withAnimation(todayEditSpring) {
                todaySwipedItemID = nil
                deleteTodayRecord(item)
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("删除")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 58, height: 62)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(0.82))
            )
            .shadow(color: Color.red.opacity(0.14), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .frame(width: 68, alignment: .trailing)
        .opacity(isVisible ? 1 : 0)
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
        if let idx = homeViewModel.items.firstIndex(where: { $0.id == item.id }) {
            homeViewModel.delete(at: IndexSet(integer: idx))
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
            playbackMomentList
        }
    }

    private var playbackHeader: some View {
        VStack(spacing: 6) {
            Text("今日生活回放")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text("十秒听一遍今天")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var playbackMomentList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(playbackMoments.enumerated()), id: \.element.id) { index, moment in
                        playbackMomentRow(moment, index: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .onChange(of: activeIndex) { _, index in
                guard index >= 0 else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private func playbackMomentRow(_ moment: PlaybackMoment, index: Int) -> some View {
        let isActive = index == activeIndex
        let isRevealed = index <= activeIndex || activeIndex == -1

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(moment.eyebrow)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.accent.opacity(0.82))
                Spacer()
                if let amount = moment.amountText {
                    Text(amount)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text.opacity(0.72))
                }
            }

            Text(moment.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(moment.body)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext.opacity(0.92))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activeMomentBackground(isActive: isActive))
        .overlay(activeMomentBorder(isActive: isActive))
        .scaleEffect(isActive && !playbackDone ? 1.01 : 1.0, anchor: .leading)
        .opacity(isRevealed ? 1 : 0.35)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: activeIndex)
        .id(index)
    }

    @ViewBuilder
    private func activeMomentBackground(isActive: Bool) -> some View {
        if isActive && !playbackDone {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.accent.opacity(0.05))
                )
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.32))
        }
    }

    private func activeMomentBorder(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isActive && !playbackDone ? AppColors.accent.opacity(0.24) : Color.white.opacity(0.32), lineWidth: 1)
    }

    @ViewBuilder
    private var playbackDoneSection: some View {
        if playbackDone {
            Text("今天的记录已回放完毕")
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
        playbackDone ? 1 : CGFloat(max(0, activeIndex)) / CGFloat(max(1, playbackMoments.count - 1))
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
        let total = todayItems.reduce(0) { $0 + $1.amount }
        let topCategory = topCategoryText()
        let dominantScene = LifeSceneSemanticService.dominantScene(in: todayItems)
        let first = todayItems.first
        let representative = representativeItem()
        var moments: [PlaybackMoment] = [
            PlaybackMoment(
                id: "opening",
                eyebrow: "今天",
                title: "今天记了 \(todayItems.count) 笔",
                body: openingBody(total: total, dominantScene: dominantScene),
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
                    eyebrow: "今天多一点",
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
        total: Double,
        dominantScene: (signal: LifeSceneSignal, count: Int, latest: Date)?
    ) -> String {
        let categories = categoryMixText()
        if let dominantScene = dominantScene, dominantScene.count >= 2 {
            switch dominantScene.signal.kind {
            case .commute:
                return "合计 \(total.formatted(.cny))，路上的几笔也算今天的一部分。"
            case .cityRoute:
                return "合计 \(total.formatted(.cny))，今天跑动的地方不少。"
            case .breakfast, .quickMeal, .workMeal:
                return "合计 \(total.formatted(.cny))，吃饭这件小事被好好记下了。"
            case .coffee:
                return "合计 \(total.formatted(.cny))，忙里提神的几口也留下来了。"
            case .convenienceSupply, .groceries, .homeSupply:
                return "合计 \(total.formatted(.cny))，补上的都是今天用得上的。"
            case .medicalVisit, .medicineCare, .fitness, .bodyCare:
                return "合计 \(total.formatted(.cny))，身体这边的事也被记住了。"
            default:
                break
            }
        }
        return "合计 \(total.formatted(.cny))，\(categories)这些小事被收进了今天。"
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
        switch LifeSceneSemanticService.classify(item).kind {
        case .commute:
            return "这笔从路上开始，今天的节奏也跟着动起来。"
        case .cityRoute:
            return "先把这趟路记下，后面回看就知道那会儿在赶路。"
        case .breakfast:
            return "先从早上的一口吃的开始，今天有了开头。"
        case .quickMeal, .workMeal:
            return "先把这一餐记下，忙不忙都算吃过了。"
        case .coffee:
            return "先从这杯提神的开始，今天慢慢往前走。"
        case .convenienceSupply, .groceries, .homeSupply:
            return "先把需要的东西补上，今天少一件惦记的事。"
        case .medicalVisit, .medicineCare, .fitness, .bodyCare:
            return "先把身体这边的安排记下，这笔不只是数字。"
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
            return "今天路上有几笔"
        case .cityRoute:
            return "今天跑动不少"
        case .breakfast, .quickMeal, .workMeal:
            return "今天吃饭这条线比较明显"
        case .coffee:
            return "今天靠几口提神往前走"
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
            return "通勤记了 \(dominantScene.count) 笔，路上花掉的时间也算今天的一部分。"
        case .cityRoute:
            return "出行记了 \(dominantScene.count) 笔，今天确实在城市里来回移动。"
        case .breakfast, .quickMeal, .workMeal:
            return "吃饭记了 \(dominantScene.count) 笔，忙的时候能吃上也挺重要。"
        case .coffee:
            return "咖啡饮品记了 \(dominantScene.count) 笔，清醒也有成本。"
        case .convenienceSupply, .groceries, .homeSupply:
            return "补给记了 \(dominantScene.count) 笔，都是把日子往前推的小东西。"
        case .shopping:
            return "购物记了 \(dominantScene.count) 笔，买到需要的就好。"
        case .medicalVisit, .medicineCare:
            return "健康相关记了 \(dominantScene.count) 笔，辛苦归辛苦，先别漏掉自己。"
        case .fitness, .bodyCare:
            return "身体相关记了 \(dominantScene.count) 笔，今天有在照看自己。"
        case .social:
            return "人情往来记了 \(dominantScene.count) 笔，日子里也有和别人相连的部分。"
        default:
            return "这条线出现了 \(dominantScene.count) 次，今天的轮廓就更清楚一点。"
        }
    }

    private func closingTitle(for item: HomeItem) -> String {
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? playbackTitle(for: item) : tag
    }

    private func closingBody(for item: HomeItem) -> String {
        "最后停在「\(playbackTitle(for: item))」。今天不用讲得很满，记到这里就已经够具体了。"
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
