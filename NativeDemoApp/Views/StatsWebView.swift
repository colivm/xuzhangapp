import SwiftUI

// MARK: - Stats View (matching web statsPage)

private struct SummaryQuotaPrompt: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let primaryTitle: String
    let opensMember: Bool
}

private struct TraceLifeRingSegment: Identifiable {
    let id: String
    let category: HomeItem.Category
    let start: Double
    let end: Double
    let color: Color
}

private struct TraceMonthHeatDay: Identifiable {
    let id: String
    let date: Date?
    let count: Int
    let isToday: Bool
}

private struct TraceMonthMilestone: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let anchor: SummaryMemoryAnchor?
}

private struct TraceMonthDigest {
    let monthTitle: String
    let activeDays: Int
    let totalDays: Int
    let heatDays: [TraceMonthHeatDay]
    let milestones: [TraceMonthMilestone]

    var accessibilityLabel: String {
        "\(monthTitle)，本月 \(totalDays) 天，记录了 \(activeDays) 天"
    }
}

private struct TraceLifeCardLayout {
    let screenHeight: CGFloat

    private var compactness: CGFloat {
        let normalized = (screenHeight - 700) / 220
        return min(max(normalized, 0), 1)
    }

    var faceSpacing: CGFloat { 10 + compactness * 4 }
    var weekTopPadding: CGFloat { 22 + compactness * 6 }
    var monthTopPadding: CGFloat { 14 + compactness * 4 }
    var bottomPadding: CGFloat { 14 + compactness * 2 }
    var primaryPhotoHeight: CGFloat { 184 + compactness * 44 }
    var secondaryPhotoHeight: CGFloat { 84 + compactness * 24 }
    var monthPhotoHeight: CGFloat { 72 + compactness * 18 }
    var monthHeroHeight: CGFloat { 300 + compactness * 22 }
    var monthDiaryPhotoHeight: CGFloat { 94 + compactness * 10 }
    var monthRingSize: CGFloat { 112 + compactness * 20 }
    var monthRingLineWidth: CGFloat { 14 + compactness * 2 }
    var monthHeatCellSize: CGFloat { 28 + compactness * 3 }
    var monthHeatSpacing: CGFloat { 6 + compactness * 1.5 }
    var milestoneThumb: CGFloat { 34 + compactness * 4 }
    var playButtonHeight: CGFloat { 44 + compactness * 4 }
}

struct TraceDetailListSnapshotKey: Equatable {
    let ledgerRevision: Int
    let periodKey: String
    let categoryKey: String?
    let usesCustomRange: Bool
    let customStartDate: Date
    let customEndDate: Date
}

struct TraceDetailListPreparationInput: @unchecked Sendable {
    let key: TraceDetailListSnapshotKey
    let sourceItems: [HomeItem]
    let dateInterval: DateInterval?
    let category: HomeItem.Category?
    let calendar: Calendar
}

struct TraceDetailListSnapshot: @unchecked Sendable {
    let key: TraceDetailListSnapshotKey
    let items: [HomeItem]
    let itemIDs: [UUID]
    let totalExpense: Double
    let dayGroups: [TraceDayGroup]
}

struct TraceDetailPresentationPayload: Identifiable {
    let id: UUID
    let initialSnapshot: TraceDetailListSnapshot

    init(id: UUID = UUID(), initialSnapshot: TraceDetailListSnapshot) {
        self.id = id
        self.initialSnapshot = initialSnapshot
    }
}

enum TraceDetailPresentationPolicy {
    static func accepts(
        _ candidate: TraceDetailPresentationPayload,
        while current: TraceDetailPresentationPayload?
    ) -> Bool {
        current == nil
    }
}

enum TraceDetailListSnapshotComputation {
    static func make(_ input: TraceDetailListPreparationInput) -> TraceDetailListSnapshot {
        var items: [HomeItem]
        if let dateInterval = input.dateInterval {
            items = input.sourceItems
                .filter { $0.createdAt >= dateInterval.start && $0.createdAt < dateInterval.end }
                .sorted { $0.createdAt > $1.createdAt }
        } else {
            items = input.sourceItems
        }
        if let category = input.category {
            items = items.filter { $0.category == category }
        }
        let groups = Dictionary(grouping: items) { item in
            input.calendar.startOfDay(for: item.createdAt)
        }
        let dayGroups = groups
            .map { day, dayItems in
                TraceDayGroup(
                    id: String(Int(day.timeIntervalSince1970)),
                    date: day,
                    items: dayItems.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.date > $1.date }
        return TraceDetailListSnapshot(
            key: input.key,
            items: items,
            itemIDs: items.map(\.id),
            totalExpense: items.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount },
            dayGroups: dayGroups
        )
    }
}

private enum TracePreparedPiece {
    case week(TraceChapterSnapshot, cacheKey: String)
    case month(TraceChapterSnapshot, cacheKey: String)
    case clue(TraceClueSnapshot, cacheKey: String)
}

struct StatsWebView: View {
    private enum SheetDismissRoute {
        case memoryDetail(HomeItem)
        case attachMemoryImage(HomeItem)
        case memberPricing(MemberPricingEntryContext)
        case openWeekly
        case openInsight
    }

    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.appTheme) private var appTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var tabState: StatsTabState
    var openTraceRequestID: UUID? = nil
    var onShowMemberPricing: ((MemberPricingEntryContext) -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil
    var onAttachMemoryImage: ((HomeItem) -> Void)? = nil

    @State private var editingItem: HomeItem?
    @State private var memoryDetailItem: HomeItem?
    @State private var summaryPlayback: SummaryPlayback?
    @State private var summaryPlaybackTask: Task<Void, Never>?
    @State private var preparingSummaryRange: SummaryPlaybackRange?
    @State private var summaryQuotaPrompt: SummaryQuotaPrompt?
    @State private var quotaRefreshID = UUID()
    @State private var traceDetailPresentation: TraceDetailPresentationPayload?
    @State private var traceDetailDismissRoute: SheetDismissRoute?
    @State private var editingDismissRoute: SheetDismissRoute?
    @State private var memoryDetailDismissRoute: SheetDismissRoute?
    @State private var summaryPlaybackDismissRoute: SheetDismissRoute?
    @State var showCategoryFilterSheet = false
    @State var traceInlineEditingItemID: UUID?
    @State private var handledOpenTraceRequestID: UUID?
    @State var traceSwipedItemID: UUID?
    @State private var traceDeletingItemID: UUID?
    @State private var tracePendingDeleteItem: HomeItem?
    @State private var showTraceDeleteConfirmation = false
    @State private var traceDetailListSnapshot: TraceDetailListSnapshot?
    @State private var traceAutoCommitRequestID: UUID?
    @GestureState private var traceSwipeDragState: TraceSwipeDragState?
    @State private var isPreparingTrace = false
    @State private var tracePreparationTask: Task<Void, Never>?
    @State private var tracePreparationGate = LatestRequestGate()
    @State private var visibleTraceLoadingPresentation: TraceLoadingPresentation?
    @State private var traceLoadingPresentationTask: Task<Void, Never>?
    @State private var tracePendingScrollTask: Task<Void, Never>?
    private let playbackService = PlaybackService()
    private let momentSelector = PlaybackMomentSelector()
    private let quotaStore = SummaryPlaybackQuotaStore()
    private let lifeInsightService = LifeInsightService.shared

    var selectedPeriod: StatsPeriod {
        get { tabState.selectedPeriod }
        nonmutating set { tabState.selectedPeriod = newValue }
    }

    var selectedCategory: HomeItem.Category? {
        get { tabState.selectedCategory }
        nonmutating set { tabState.selectedCategory = newValue }
    }

    var customStartDate: Date {
        get { tabState.customStartDate }
        nonmutating set { tabState.customStartDate = newValue }
    }

    var customEndDate: Date {
        get { tabState.customEndDate }
        nonmutating set { tabState.customEndDate = newValue }
    }

    var customDateFocus: CustomDateEndpoint {
        get { tabState.customDateFocus }
        nonmutating set { tabState.customDateFocus = newValue }
    }

    var useCustomRange: Bool {
        get { tabState.useCustomRange }
        nonmutating set { tabState.useCustomRange = newValue }
    }

    var showTraceCustomDatePanel: Bool {
        get { tabState.showsCustomDatePanel }
        nonmutating set { tabState.showsCustomDatePanel = newValue }
    }

    private var traceViewMode: TraceViewMode {
        get { tabState.viewMode }
        nonmutating set { tabState.viewMode = newValue }
    }

    var traceLifeCardRange: SummaryPlaybackRange {
        get { tabState.lifeCardRange }
        nonmutating set { tabState.lifeCardRange = newValue }
    }

    private var traceDeepInsightExpanded: Bool {
        get { tabState.deepInsightExpanded }
        nonmutating set { tabState.deepInsightExpanded = newValue }
    }

    private var traceInsightFocusedQuestion: String? {
        get { tabState.focusedInsightQuestion }
        nonmutating set { tabState.focusedInsightQuestion = newValue }
    }

    private var traceSnapshotStore: TraceSnapshotStore {
        tabState.snapshotStore
    }

    private var preparedWeekSnapshot: TraceChapterSnapshot? {
        get { tabState.preparedWeekSnapshot }
        nonmutating set { tabState.preparedWeekSnapshot = newValue }
    }

    private var preparedMonthSnapshot: TraceChapterSnapshot? {
        get { tabState.preparedMonthSnapshot }
        nonmutating set { tabState.preparedMonthSnapshot = newValue }
    }

    private var preparedClueSnapshot: TraceClueSnapshot? {
        get { tabState.preparedClueSnapshot }
        nonmutating set { tabState.preparedClueSnapshot = newValue }
    }

    private var preparedWeekSnapshotKey: String? {
        get { tabState.preparedWeekSnapshotKey }
        nonmutating set { tabState.preparedWeekSnapshotKey = newValue }
    }

    private var preparedMonthSnapshotKey: String? {
        get { tabState.preparedMonthSnapshotKey }
        nonmutating set { tabState.preparedMonthSnapshotKey = newValue }
    }

    private var preparedClueSnapshotKey: String? {
        get { tabState.preparedClueSnapshotKey }
        nonmutating set { tabState.preparedClueSnapshotKey = newValue }
    }

    private var chapterContentRevision: Int {
        get { tabState.chapterContentRevision }
        nonmutating set { tabState.chapterContentRevision = newValue }
    }

    private var clueContentRevision: Int {
        get { tabState.clueContentRevision }
        nonmutating set { tabState.clueContentRevision = newValue }
    }

    private func discardPreparedClueSnapshot() {
        preparedClueSnapshot = nil
        preparedClueSnapshotKey = nil
    }

    private func discardAllPreparedTraceSnapshots() {
        preparedWeekSnapshot = nil
        preparedMonthSnapshot = nil
        preparedClueSnapshot = nil
        preparedWeekSnapshotKey = nil
        preparedMonthSnapshotKey = nil
        preparedClueSnapshotKey = nil
        tabState.coldStartDisplay = nil
    }

    var filteredItems: [HomeItem] {
        var items: [HomeItem]
        if useCustomRange {
            let cal = Calendar.current
            let start = cal.startOfDay(for: customStartDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEndDate)) ?? customEndDate
            items = start < end ? homeViewModel.items(in: DateInterval(start: start, end: end)) : []
        } else {
            switch selectedPeriod {
            case .week:
                items = homeViewModel.filteredItems(in: .week)
            case .month:
                items = homeViewModel.filteredItems(in: .month)
            case .year:
                items = homeViewModel.currentYearItems
            }
        }
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        return items
    }

    private var traceInlineEditingItem: HomeItem? {
        guard let traceInlineEditingItemID else { return nil }
        return traceDetailListSnapshot?.items.first { $0.id == traceInlineEditingItemID }
    }

    private var emptyRecordListText: String {
        if homeViewModel.items.isEmpty {
            return "这一段还没有痕迹，先去记下一笔。"
        }
        return "这一段没有匹配的痕迹，可以换个时间或分类看看。"
    }

    private var hasMemberAccess: Bool {
        settingsViewModel.settings.hasMemberAccess
    }

    var currentFilterSummary: String {
        let periodText = useCustomRange ? "自定义时间" : selectedPeriod.rawValue
        let categoryText = selectedCategory?.rawValue ?? "全部分类"
        return "\(periodText) · \(categoryText)"
    }

    private var traceDetailListSnapshotKey: TraceDetailListSnapshotKey {
        TraceDetailListSnapshotKey(
            ledgerRevision: homeViewModel.homeDashboardRevision,
            periodKey: selectedPeriod.rawValue,
            categoryKey: selectedCategory?.rawValue,
            usesCustomRange: useCustomRange,
            customStartDate: customStartDate,
            customEndDate: customEndDate
        )
    }

    @discardableResult
    private func prepareTraceDetailListSnapshot() -> TraceDetailListSnapshot {
        let key = traceDetailListSnapshotKey
        if let traceDetailListSnapshot, traceDetailListSnapshot.key == key {
            return traceDetailListSnapshot
        }

        let sourceItems: [HomeItem]
        let dateInterval: DateInterval?
        if useCustomRange {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: customEndDate)
            ) ?? customEndDate
            if start < end {
                sourceItems = homeViewModel.items
                dateInterval = DateInterval(start: start, end: end)
            } else {
                sourceItems = []
                dateInterval = nil
            }
        } else {
            dateInterval = nil
            switch selectedPeriod {
            case .week:
                sourceItems = homeViewModel.filteredItems(in: .week)
            case .month:
                sourceItems = homeViewModel.filteredItems(in: .month)
            case .year:
                sourceItems = homeViewModel.currentYearItems
            }
        }
        let snapshot = TraceDetailListSnapshotComputation.make(
            TraceDetailListPreparationInput(
                key: key,
                sourceItems: sourceItems,
                dateInterval: dateInterval,
                category: selectedCategory,
                calendar: .current
            )
        )
        traceDetailListSnapshot = snapshot
        return snapshot
    }

    @State var showPeriodSheet = false

    var body: some View {
        statsScrollView
            .sheet(isPresented: $showPeriodSheet) {
                periodPickerSheet
            }
            .sheet(isPresented: $showCategoryFilterSheet) {
                categoryFilterSheet
            }
            .sheet(item: $traceDetailPresentation, onDismiss: {
                let route = traceDetailDismissRoute
                traceDetailDismissRoute = nil
                handleSheetDismissRoute(route)
            }) { presentation in
                traceDetailSheet(initialSnapshot: presentation.initialSnapshot)
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
            .sheet(item: $summaryPlayback, onDismiss: {
                let route = summaryPlaybackDismissRoute
                summaryPlaybackDismissRoute = nil
                handleSheetDismissRoute(route)
            }) { playback in
                summaryPlaybackSheet(playback)
            }
            .onAppear {
                handleOpenTraceRequestIfNeeded()
                restoreTraceColdStartDisplayIfNeeded()
                prepareTraceIfNeeded()
            }
            .onDisappear {
                tracePreparationTask?.cancel()
                tracePreparationTask = nil
                tracePreparationGate.invalidate()
                summaryPlaybackTask?.cancel()
                summaryPlaybackTask = nil
                preparingSummaryRange = nil
                traceLoadingPresentationTask?.cancel()
                traceLoadingPresentationTask = nil
                tracePendingScrollTask?.cancel()
                tracePendingScrollTask = nil
                updateTraceLoadingPresentation(nil, animated: false)
                isPreparingTrace = false
            }
            .onChange(of: openTraceRequestID) { _, _ in
                handleOpenTraceRequestIfNeeded()
                prepareTraceIfNeeded()
            }
            .onChange(of: homeViewModel.homeDashboardRevision) { _, _ in
                traceSnapshotStore.invalidateAll()
                tabState.coldStartDisplay = nil
                tabState.coldStartLedgerRevision = nil
                restoreTraceColdStartDisplayIfNeeded()
                scheduleTracePreparation()
                if traceDetailPresentation != nil {
                    prepareTraceDetailListSnapshot()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .narrativeAIRewriteDidChange)) { _ in
                traceSnapshotStore.invalidateAll()
                chapterContentRevision &+= 1
                clueContentRevision &+= 1
            }
            .onChange(of: selectedPeriod) { _, _ in
                if let range = TraceRangeContextPolicy.lifeRange(for: selectedPeriod),
                   !useCustomRange {
                    traceLifeCardRange = range
                }
                if traceViewMode == .clues {
                    discardPreparedClueSnapshot()
                    restoreTraceColdStartDisplayIfNeeded()
                    scheduleTracePreparation()
                } else {
                    prepareTraceIfNeeded()
                }
                if traceDetailPresentation != nil {
                    prepareTraceDetailListSnapshot()
                }
            }
            .onChange(of: useCustomRange) { _, _ in
                if traceViewMode == .clues {
                    discardPreparedClueSnapshot()
                    restoreTraceColdStartDisplayIfNeeded()
                    scheduleTracePreparation()
                }
                if traceDetailPresentation != nil {
                    prepareTraceDetailListSnapshot()
                }
            }
            .onChange(of: customStartDate) { _, _ in
                if traceViewMode == .clues, useCustomRange {
                    discardPreparedClueSnapshot()
                    restoreTraceColdStartDisplayIfNeeded()
                    scheduleTracePreparation()
                }
                if traceDetailPresentation != nil, useCustomRange {
                    prepareTraceDetailListSnapshot()
                }
            }
            .onChange(of: customEndDate) { _, _ in
                if traceViewMode == .clues, useCustomRange {
                    discardPreparedClueSnapshot()
                    restoreTraceColdStartDisplayIfNeeded()
                    scheduleTracePreparation()
                }
                if traceDetailPresentation != nil, useCustomRange {
                    prepareTraceDetailListSnapshot()
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                if traceViewMode == .clues {
                    discardPreparedClueSnapshot()
                    restoreTraceColdStartDisplayIfNeeded()
                    scheduleTracePreparation()
                }
                if traceDetailPresentation != nil {
                    prepareTraceDetailListSnapshot()
                }
            }
            .onChange(of: hasMemberAccess) { _, _ in
                traceSnapshotStore.invalidateAll()
                discardAllPreparedTraceSnapshots()
                restoreTraceColdStartDisplayIfNeeded()
                scheduleTracePreparation()
            }
            .onChange(of: clueContentRevision) { _, _ in
                scheduleTracePreparation()
            }
            .onChange(of: traceViewMode) { _, mode in
                if mode == .clues, clueTraceNeedsRefresh {
                    discardPreparedClueSnapshot()
                }
                restoreTraceColdStartDisplayIfNeeded()
                prepareTraceIfNeeded()
            }
            .overlay {
                if let summaryQuotaPrompt {
                    summaryQuotaOverlay(summaryQuotaPrompt)
                        .transition(.opacity)
                        .zIndex(30)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: summaryQuotaPrompt)
    }

    private var statsScrollView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                tracePinnedControls

                ZStack {
                    ScrollView {
                        statsContent(availableHeight: proxy.size.height)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDisabled(traceSwipeDragState != nil || visibleTraceLoadingPresentation != nil)
                    .scrollPosition(id: $tabState.scrollAnchorID, anchor: .top)
                    .accessibilityHidden(visibleTraceLoadingPresentation != nil)

                    if let presentation = visibleTraceLoadingPresentation {
                        traceLoadingOverlay(presentation)
                            .transition(.opacity)
                            .zIndex(20)
                    }
                }
            }
        }
    }

    private var tracePinnedControls: some View {
        VStack(spacing: 10) {
            traceViewModeKicker
            if traceViewMode == .life {
                traceLifeRangeKicker
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: traceViewMode == .life ? 560 : 430)
        .frame(maxWidth: .infinity)
        .background(AppColors.bg.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TraceColors.stroke.opacity(0.45))
                .frame(height: 0.5)
        }
        .zIndex(30)
    }

    private func traceLoadingOverlay(_ presentation: TraceLoadingPresentation) -> some View {
        ZStack {
            AppColors.bg
                .opacity(0.82)
                .contentShape(Rectangle())

            ComputationLoadingView(
                message: presentation.message,
                detail: presentation.detail,
                presentation: .card
            )
            .frame(maxWidth: 310)
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private func statsContent(availableHeight: CGFloat) -> some View {
        let layout = TraceLifeCardLayout(screenHeight: max(availableHeight, UIScreen.main.bounds.height))
        let lifeSnapshot = visiblePreparedLifeSnapshot
        let coldStartDisplay = visibleTraceColdStartDisplay
        return VStack(spacing: 16) {
            if traceViewMode == .life,
               let lifeSnapshot {
                traceChapterCard(
                    layout: layout,
                    snapshot: lifeSnapshot
                )
                .id(TraceDeferredScrollPolicy.lifeChapterAnchorID)
                .transition(.opacity)
            } else if traceViewMode == .clues,
                      let preparedClueSnapshot {
                traceClueBoard(snapshot: preparedClueSnapshot)
                    .id("trace-clue-board")
                    .transition(.opacity)
            } else if let coldStartDisplay {
                traceColdStartDisplayCard(coldStartDisplay)
                    .transition(.opacity)
            } else {
                traceTargetPreparationSurface(availableHeight: availableHeight)
            }
        }
        .scrollTargetLayout()
        .padding(.horizontal, traceViewMode == .life ? 6 : 12)
        .padding(.top, 6)
        .padding(.bottom, 120)
        .frame(maxWidth: traceViewMode == .life ? 560 : 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func traceTargetPreparationSurface(availableHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(TraceColors.surfaceMuted.opacity(0.34))
            .overlay {
                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.52))
                        .frame(width: 112, height: 12)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.42))
                        .frame(height: 72)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.30))
                        .frame(height: 44)
                }
                .padding(24)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(minHeight: max(280, availableHeight - 190))
            .accessibilityHidden(true)
    }

    private func traceColdStartDisplayCard(_ display: TraceColdStartDisplayEntry) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(display.periodLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.accentDark)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.accent.opacity(0.10)))
                Spacer()
                if isPreparingTrace {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.accent)
                        .accessibilityLabel("正在后台更新")
                }
            }

            Text(display.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(TraceColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(display.summary)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TraceColors.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("\(display.recordCount) 笔")
                Text("·")
                Text("\(display.activeDayCount) 天有记录")
                Text("·")
                Text(display.total.formatted(.cny))
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(TraceColors.tertiaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)

            if let topCategory = display.topCategory, !topCategory.isEmpty {
                Label(topCategory, systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark)
            }
        }
        .traceWarmPanel(radius: 26, padding: 24)
        .accessibilityElement(children: .combine)
        .accessibilityHint("这是上次整理的同一账本内容，最新快照正在后台更新")
    }

    private var currentTraceColdStartScopeKey: String {
        TraceSnapshotLifecycleKeyPolicy.coldStartScopeKey(
            viewMode: traceViewMode,
            lifeRange: traceLifeCardRange,
            period: selectedPeriod,
            usesCustomRange: useCustomRange,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            category: selectedCategory
        )
    }

    private var visibleTraceColdStartDisplay: TraceColdStartDisplayEntry? {
        guard let display = tabState.coldStartDisplay,
              traceViewMode != .life || TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: traceLifeCardRange,
                selectedPeriod: selectedPeriod,
                usesCustomRange: useCustomRange
              ),
              TraceSnapshotVisibilityPolicy.canDisplayColdStart(
                publishedScopeKey: display.scopeKey,
                expectedScopeKey: currentTraceColdStartScopeKey
              ) else { return nil }
        return display
    }

    private var visiblePreparedLifeSnapshot: TraceChapterSnapshot? {
        guard TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
            range: traceLifeCardRange,
            selectedPeriod: selectedPeriod,
            usesCustomRange: useCustomRange
        ) else { return nil }
        return preparedLifeSnapshot(for: traceLifeCardRange)
    }

    private func preparedLifeSnapshot(
        for range: SummaryPlaybackRange,
        now: Date = Date()
    ) -> TraceChapterSnapshot? {
        let snapshot: TraceChapterSnapshot?
        let publishedKey: String?
        switch range {
        case .week:
            snapshot = preparedWeekSnapshot
            publishedKey = preparedWeekSnapshotKey
        case .month:
            snapshot = preparedMonthSnapshot
            publishedKey = preparedMonthSnapshotKey
        }
        let expectedKey = traceChapterSnapshotCacheKey(range: range, now: now)
        guard TraceSnapshotVisibilityPolicy.canDisplayChapter(
            selectedRange: range,
            snapshotRange: snapshot?.range,
            publishedKey: publishedKey,
            expectedKey: expectedKey
        ) else { return nil }
        return snapshot
    }

    private var weekTraceNeedsRefresh: Bool {
        preparedLifeSnapshot(for: .week) == nil
    }

    private var monthTraceNeedsRefresh: Bool {
        preparedLifeSnapshot(for: .month) == nil
    }

    private var clueTraceNeedsRefresh: Bool {
        let items = traceClueItems
        return preparedClueSnapshot == nil
            || preparedClueSnapshotKey != traceClueSnapshotCacheKey(items: items)
    }

    private var currentTraceNeedsRefresh: Bool {
        switch traceViewMode {
        case .life:
            return TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: traceLifeCardRange,
                weekNeedsRefresh: weekTraceNeedsRefresh,
                monthNeedsRefresh: monthTraceNeedsRefresh,
                hasWeek: preparedLifeSnapshot(for: .week) != nil,
                hasMonth: preparedLifeSnapshot(for: .month) != nil
            )
        case .clues:
            return clueTraceNeedsRefresh || preparedClueSnapshot == nil
        }
    }

    private func lifeTraceNeedsRefresh(for range: SummaryPlaybackRange) -> Bool {
        switch range {
        case .week:
            return weekTraceNeedsRefresh
        case .month:
            return monthTraceNeedsRefresh
        }
    }

    private func prepareTraceIfNeeded() {
        restoreTraceColdStartDisplayIfNeeded()
        guard currentTraceNeedsRefresh else {
            tracePreparationTask?.cancel()
            tracePreparationTask = nil
            traceLoadingPresentationTask?.cancel()
            traceLoadingPresentationTask = nil
            updateTraceLoadingPresentation(nil, animated: true)
            isPreparingTrace = false
            markVisibleCurrentWeekTraceSeenIfEligible()
            schedulePendingTraceScrollIfPossible()
            return
        }
        scheduleTracePreparation()
    }

    private func restoreTraceColdStartDisplayIfNeeded(now: Date = Date()) {
        let context = traceColdStartDisplayContext(now: now)
        let scopeKey = TraceSnapshotLifecycleKeyPolicy.coldStartScopeKey(
            viewMode: traceViewMode,
            lifeRange: traceLifeCardRange,
            period: selectedPeriod,
            usesCustomRange: useCustomRange,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            category: selectedCategory
        )
        tabState.coldStartDisplay = TraceColdStartDisplayStore.shared.entry(
            for: context,
            scopeKey: scopeKey
        )
    }

    private func traceColdStartDisplayContext(now: Date = Date()) -> TraceColdStartDisplayContext {
        let revision = homeViewModel.homeDashboardRevision
        let dayKey = LedgerDisplayFingerprintPolicy.dayKey(for: now)
        if tabState.coldStartLedgerRevision != revision
            || tabState.coldStartDayKey != dayKey
            || tabState.coldStartLedgerFingerprint == nil {
            tabState.coldStartLedgerRevision = revision
            tabState.coldStartDayKey = dayKey
            tabState.coldStartLedgerFingerprint = LedgerDisplayFingerprintPolicy.make(
                items: homeViewModel.items
            )
            tabState.coldStartDisplay = nil
        }
        return TraceColdStartDisplayContext(
            ledgerFingerprint: tabState.coldStartLedgerFingerprint ?? "empty",
            dayKey: dayKey,
            isMember: hasMemberAccess
        )
    }

    private func storeTraceColdStartDisplay(
        chapter snapshot: TraceChapterSnapshot,
        now: Date
    ) {
        let scopeKey = TraceSnapshotLifecycleKeyPolicy.coldStartScopeKey(
            viewMode: .life,
            lifeRange: snapshot.range,
            period: snapshot.range == .week ? .week : .month,
            usesCustomRange: false,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            category: nil
        )
        let display = TraceColdStartDisplayEntry(
            scopeKey: scopeKey,
            savedAt: now,
            title: snapshot.coverFacts.title,
            summary: snapshot.chapterSummary ?? snapshot.coverFacts.supportLine,
            periodLabel: snapshot.range == .week ? "本周痕迹" : "本月痕迹",
            recordCount: snapshot.coverFacts.recordCount,
            activeDayCount: snapshot.coverFacts.activeDays,
            total: snapshot.preview.total,
            topCategory: snapshot.preview.topCategory
        )
        TraceColdStartDisplayStore.shared.store(
            display,
            context: traceColdStartDisplayContext(now: now)
        )
    }

    private func storeTraceColdStartDisplay(
        clue snapshot: TraceClueSnapshot,
        scopeKey: String,
        now: Date
    ) {
        let activeDays = Set(snapshot.items.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
        let display = TraceColdStartDisplayEntry(
            scopeKey: scopeKey,
            savedAt: now,
            title: snapshot.narrativeHeadline ?? snapshot.insight.leadQuestion,
            summary: snapshot.narrativeSummary ?? snapshot.insight.previewLine,
            periodLabel: useCustomRange ? "这段线索" : "\(selectedPeriod.rawValue)线索",
            recordCount: snapshot.items.count,
            activeDayCount: activeDays,
            total: snapshot.items.reduce(0) { $0 + $1.amount },
            topCategory: snapshot.clues.first?.category.rawValue
        )
        TraceColdStartDisplayStore.shared.store(
            display,
            context: traceColdStartDisplayContext(now: now)
        )
    }

    private func markVisibleCurrentWeekTraceSeenIfEligible(now: Date = Date()) {
        guard traceViewMode == .life,
              traceLifeCardRange == .week,
              selectedPeriod == .week,
              !useCustomRange,
              !weekTraceNeedsRefresh,
              let snapshot = preparedWeekSnapshot else { return }
        homeViewModel.markCurrentWeekTraceSeenIfEligible(
            recordCount: snapshot.coverFacts.recordCount,
            activeDayCount: snapshot.coverFacts.activeDays,
            hasVisibleCurrentWeekSnapshot: true,
            now: now
        )
    }

    private func traceChapterPreparation(
        for range: SummaryPlaybackRange,
        allItems: [HomeItem],
        memberAccess: Bool,
        now: Date
    ) -> (cached: TraceChapterSnapshot?, input: (TraceChapterComputationInput, String)?) {
        let items = traceLifeScopedItems(for: range)
        let cacheKey = traceChapterSnapshotCacheKey(range: range, now: now)
        if let cached = traceSnapshotStore.chapterSnapshot(for: cacheKey) {
            return (cached, nil)
        }
        let periodKey = range == .week
            ? quotaStore.currentWeekKey()
            : EchoAnchorService.shared.periodKeyForMonth()
        return (
            nil,
            (
                TraceChapterComputationInput(
                    range: range,
                    items: items,
                    allItems: allItems,
                    isMember: memberAccess,
                    prioritizeRecurringMarks: range == .month,
                    periodKey: periodKey,
                    usesEchoAnchor: true,
                    sourceRevision: homeViewModel.homeDashboardRevision,
                    now: now
                ),
                cacheKey
            )
        )
    }

    private func scheduleTracePreparation() {
        restoreTraceColdStartDisplayIfNeeded()
        tracePreparationTask?.cancel()
        let requestID = tracePreparationGate.begin()
        let performanceStartedAt = ProcessInfo.processInfo.systemUptime
        traceLoadingPresentationTask?.cancel()
        traceLoadingPresentationTask = nil
        let needsLife = traceViewMode == .life
        let needsClues = traceViewMode == .clues
        let hasPreparedSnapshot = needsLife
            ? TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: traceLifeCardRange,
                hasWeek: preparedLifeSnapshot(for: .week) != nil,
                hasMonth: preparedLifeSnapshot(for: .month) != nil
            )
            : preparedClueSnapshot != nil
        let hasVisibleSnapshot = hasPreparedSnapshot || visibleTraceColdStartDisplay != nil
        let loadingPresentation = TraceLoadingPresentationPolicy.make(
            viewMode: traceViewMode,
            selectedPeriod: selectedPeriod,
            lifeRange: traceLifeCardRange,
            usesCustomRange: useCustomRange,
            hasVisibleSnapshot: hasVisibleSnapshot
        )
        isPreparingTrace = true

        if hasVisibleSnapshot {
            updateTraceLoadingPresentation(nil, animated: false)
        } else if loadingPresentation.delayNanoseconds == 0 || visibleTraceLoadingPresentation != nil {
            updateTraceLoadingPresentation(loadingPresentation, animated: true)
        } else {
            traceLoadingPresentationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: loadingPresentation.delayNanoseconds)
                guard !Task.isCancelled,
                      isPreparingTrace,
                      tracePreparationGate.accepts(requestID) else { return }
                updateTraceLoadingPresentation(loadingPresentation, animated: true)
            }
        }

        let allItems = homeViewModel.items
        let memberAccess = hasMemberAccess
        let now = Date()
        let primaryLifeRange = traceLifeCardRange
        var cachedWeek: TraceChapterSnapshot?
        var cachedMonth: TraceChapterSnapshot?
        var cachedClue: TraceClueSnapshot?
        var weekInput: (TraceChapterComputationInput, String)?
        var monthInput: (TraceChapterComputationInput, String)?
        var clueInput: (TraceClueComputationInput, String)?
        var weekPublicationKey: String?
        var monthPublicationKey: String?
        var cluePublicationKey: String?
        let clueColdStartScopeKey = TraceSnapshotLifecycleKeyPolicy.coldStartScopeKey(
            viewMode: .clues,
            lifeRange: traceLifeCardRange,
            period: selectedPeriod,
            usesCustomRange: useCustomRange,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            category: selectedCategory
        )

        if needsLife {
            switch traceLifeCardRange {
            case .week:
                weekPublicationKey = traceChapterSnapshotCacheKey(range: .week, now: now)
                let prepared = traceChapterPreparation(
                    for: .week,
                    allItems: allItems,
                    memberAccess: memberAccess,
                    now: now
                )
                cachedWeek = prepared.cached
                weekInput = prepared.input
            case .month:
                monthPublicationKey = traceChapterSnapshotCacheKey(range: .month, now: now)
                let prepared = traceChapterPreparation(
                    for: .month,
                    allItems: allItems,
                    memberAccess: memberAccess,
                    now: now
                )
                cachedMonth = prepared.cached
                monthInput = prepared.input
            }
        }

        if needsClues {
            let items = traceClueItems
            let clueKey = traceClueSnapshotCacheKey(items: items)
            cluePublicationKey = clueKey
            cachedClue = traceSnapshotStore.clueSnapshot(for: clueKey)
            if cachedClue == nil {
                let unlockKey = traceInsightUnlockKey(from: items)
                let freeRemaining = lifeInsightService.freeRemaining(isMember: memberAccess, now: now)
                let narrativeScope: LifeNarrativeScope? = useCustomRange
                    ? nil
                    : (selectedPeriod == .week ? .week : (selectedPeriod == .month ? .month : nil))
                clueInput = (
                    TraceClueComputationInput(
                        items: items,
                        allItems: allItems,
                        period: selectedPeriod,
                        periodLabel: traceInsightPeriodLabel,
                        isMember: memberAccess,
                        freeRemaining: freeRemaining,
                        storedUnlock: lifeInsightService.hasUnlockedTrace(unlockKey, isMember: memberAccess, now: now),
                        sourceRevision: homeViewModel.homeDashboardRevision,
                        narrativeScope: narrativeScope,
                        allowsNarrativeRewrite: narrativeScope != nil,
                        now: now
                    ),
                    clueKey
                )
            }
        }

        let initialWeekSnapshot = cachedWeek
        let initialMonthSnapshot = cachedMonth
        let initialClueSnapshot = cachedClue
        let pendingWeekInput = weekInput
        let pendingMonthInput = monthInput
        let pendingClueInput = clueInput
        let publishedWeekKey = weekPublicationKey
        let publishedMonthKey = monthPublicationKey
        let publishedClueKey = cluePublicationKey

        tracePreparationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, tracePreparationGate.accepts(requestID) else { return }

            var weekSnapshot = initialWeekSnapshot
            var monthSnapshot = initialMonthSnapshot
            var clueSnapshot = initialClueSnapshot

            await withTaskGroup(of: TracePreparedPiece.self) { group in
                if let (input, cacheKey) = pendingWeekInput {
                    group.addTask(priority: .userInitiated) {
                        .week(TraceSnapshotComputation.buildChapter(input), cacheKey: cacheKey)
                    }
                }
                if let (input, cacheKey) = pendingMonthInput {
                    group.addTask(priority: .userInitiated) {
                        .month(TraceSnapshotComputation.buildChapter(input), cacheKey: cacheKey)
                    }
                }
                if let (input, cacheKey) = pendingClueInput {
                    group.addTask(priority: .userInitiated) {
                        .clue(TraceSnapshotComputation.buildClue(input), cacheKey: cacheKey)
                    }
                }

                for await piece in group {
                    guard !Task.isCancelled else {
                        group.cancelAll()
                        return
                    }
                    switch piece {
                    case let .week(snapshot, cacheKey):
                        weekSnapshot = snapshot
                        traceSnapshotStore.storeChapterSnapshot(snapshot, for: cacheKey)
                    case let .month(snapshot, cacheKey):
                        monthSnapshot = snapshot
                        traceSnapshotStore.storeChapterSnapshot(snapshot, for: cacheKey)
                    case let .clue(snapshot, cacheKey):
                        clueSnapshot = snapshot
                        traceSnapshotStore.storeClueSnapshot(snapshot, for: cacheKey)
                    }
                }
            }

            guard !Task.isCancelled, tracePreparationGate.accepts(requestID) else { return }
            traceLoadingPresentationTask?.cancel()
            traceLoadingPresentationTask = nil
            var snapshotTransaction = Transaction(animation: nil)
            snapshotTransaction.disablesAnimations = true
            withTransaction(snapshotTransaction) {
                if let weekSnapshot {
                    preparedWeekSnapshot = weekSnapshot
                    preparedWeekSnapshotKey = publishedWeekKey
                }
                if let monthSnapshot {
                    preparedMonthSnapshot = monthSnapshot
                    preparedMonthSnapshotKey = publishedMonthKey
                }
                if let clueSnapshot {
                    preparedClueSnapshot = clueSnapshot
                    preparedClueSnapshotKey = publishedClueKey
                    if let focusedQuestion = traceInsightFocusedQuestion,
                       !clueSnapshot.insight.questionChips.contains(focusedQuestion) {
                        traceInsightFocusedQuestion = clueSnapshot.insight.questionChips.first
                    }
                }
                isPreparingTrace = false
            }
            if let weekSnapshot {
                storeTraceColdStartDisplay(chapter: weekSnapshot, now: now)
            }
            if let monthSnapshot {
                storeTraceColdStartDisplay(chapter: monthSnapshot, now: now)
            }
            if let clueSnapshot {
                storeTraceColdStartDisplay(
                    clue: clueSnapshot,
                    scopeKey: clueColdStartScopeKey,
                    now: now
                )
            }
            tabState.coldStartDisplay = nil
            updateTraceLoadingPresentation(nil, animated: true)
            markVisibleCurrentWeekTraceSeenIfEligible(now: now)
            schedulePendingTraceScrollIfPossible()
            homeViewModel.markPerformance(
                operation: needsLife ? .traceLifePreparation : .traceCluePreparation,
                startedAtUptime: performanceStartedAt,
                itemCount: allItems.count
            )

            if needsLife {
                try? await Task.sleep(
                    nanoseconds: TraceLifePreparationPolicy.prewarmDelayNanoseconds
                )
                guard !Task.isCancelled,
                      tracePreparationGate.accepts(requestID) else { return }
                await prewarmTraceChapter(
                    range: TraceLifePreparationPolicy.prewarmRange(after: primaryLifeRange),
                    requestID: requestID,
                    allItems: allItems,
                    memberAccess: memberAccess,
                    now: now
                )
            }
            guard tracePreparationGate.accepts(requestID) else { return }
            tracePreparationTask = nil
        }
    }

    private func updateTraceLoadingPresentation(
        _ presentation: TraceLoadingPresentation?,
        animated: Bool
    ) {
        if animated && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.16)) {
                visibleTraceLoadingPresentation = presentation
            }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visibleTraceLoadingPresentation = presentation
            }
        }
    }

    @MainActor
    private func prewarmTraceChapter(
        range: SummaryPlaybackRange,
        requestID: UUID,
        allItems: [HomeItem],
        memberAccess: Bool,
        now: Date
    ) async {
        guard lifeTraceNeedsRefresh(for: range),
              !Task.isCancelled,
              tracePreparationGate.accepts(requestID) else { return }
        await Task.yield()
        guard !Task.isCancelled, tracePreparationGate.accepts(requestID) else { return }

        let prepared = traceChapterPreparation(
            for: range,
            allItems: allItems,
            memberAccess: memberAccess,
            now: now
        )
        if let cached = prepared.cached {
            if range == .week {
                preparedWeekSnapshot = cached
                preparedWeekSnapshotKey = traceChapterSnapshotCacheKey(range: .week, now: now)
            } else {
                preparedMonthSnapshot = cached
                preparedMonthSnapshotKey = traceChapterSnapshotCacheKey(range: .month, now: now)
            }
            storeTraceColdStartDisplay(chapter: cached, now: now)
            return
        }
        guard let (input, cacheKey) = prepared.input else { return }

        let piece = await withTaskGroup(of: TracePreparedPiece.self, returning: TracePreparedPiece?.self) { group in
            group.addTask(priority: .utility) {
                let snapshot = TraceSnapshotComputation.buildChapter(input)
                return range == .week
                    ? .week(snapshot, cacheKey: cacheKey)
                    : .month(snapshot, cacheKey: cacheKey)
            }
            return await group.next()
        }
        guard let piece,
              !Task.isCancelled,
              tracePreparationGate.accepts(requestID) else { return }
        switch piece {
        case let .week(snapshot, cacheKey):
            traceSnapshotStore.storeChapterSnapshot(snapshot, for: cacheKey)
            preparedWeekSnapshot = snapshot
            preparedWeekSnapshotKey = cacheKey
            storeTraceColdStartDisplay(chapter: snapshot, now: now)
        case let .month(snapshot, cacheKey):
            traceSnapshotStore.storeChapterSnapshot(snapshot, for: cacheKey)
            preparedMonthSnapshot = snapshot
            preparedMonthSnapshotKey = cacheKey
            storeTraceColdStartDisplay(chapter: snapshot, now: now)
        case .clue:
            break
        }
    }

    private var heroScopedItems: [HomeItem] {
        if useCustomRange || selectedPeriod == .year {
            return filteredItems
        }
        let items: [HomeItem]
        switch selectedPeriod {
        case .week:
            items = homeViewModel.filteredItems(in: .week)
        case .month:
            items = homeViewModel.filteredItems(in: .month)
        case .year:
            items = []
        }
        return items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var traceRepresentativeItems: [HomeItem] {
        TraceRepresentative.items(from: heroScopedItems)
    }

    private var heroNarrativeText: String {
        heroNarrativeText(from: heroScopedItems)
    }

    private func heroNarrativeText(from items: [HomeItem]) -> String {
        heroNarrativeText(from: items, marks: traceLifeMarks(from: items, limit: 2))
    }

    private func heroNarrativeText(from items: [HomeItem], marks: [LifeMarkAggregate]) -> String {
        guard !items.isEmpty else {
            return selectedPeriod == .week
                ? "这一周还没有记录。先留下几笔，之后会整理成一段场记。"
                : "这个月还没有记录。先留下几笔，之后会整理成一段场记。"
        }
        if let primaryMark = marks.first {
            if selectedPeriod == .week {
                return "\(traceMarkDisplayLabel(primaryMark))，是这周的主线"
            }
            return "这个月 · \(traceMarkDisplayLabel(primaryMark))"
        }
        if let voice = heroMomentSelection(from: items).primary?.text {
            return selectedPeriod == .week
                ? "这一周先记住「\(voice)」"
                : "这个月先记住「\(voice)」"
        }
        return "这一段还散，多记几笔会收成一章。"
    }

    private var heroMomentSelection: PlaybackMomentSelection {
        heroMomentSelection(from: heroScopedItems)
    }

    private func heroMomentSelection(from items: [HomeItem]) -> PlaybackMomentSelection {
        let periodKey = heroMomentPeriodKey(itemCount: items.count)
        let echoAnchor = heroMomentEchoAnchor(periodKey: periodKey, items: items)
        return momentSelector.select(
            from: items,
            periodKey: periodKey,
            range: heroRange,
            now: .now,
            echoAnchor: echoAnchor
        )
    }

    private var heroMomentPeriodKey: String {
        heroMomentPeriodKey(itemCount: heroScopedItems.count)
    }

    private func heroMomentPeriodKey(itemCount: Int) -> String {
        if useCustomRange || selectedPeriod == .year {
            return "trace-\(selectedPeriod.rawValue)-\(itemCount)"
        }
        switch heroRange {
        case .week:
            return quotaStore.currentWeekKey()
        case .month:
            return EchoAnchorService.shared.periodKeyForMonth()
        }
    }

    private func heroMomentEchoAnchor(periodKey: String) -> EchoAnchor? {
        heroMomentEchoAnchor(periodKey: periodKey, items: heroScopedItems)
    }

    private func heroMomentEchoAnchor(periodKey: String, items: [HomeItem]) -> EchoAnchor? {
        guard !useCustomRange, selectedPeriod != .year else { return nil }
        return EchoAnchorService.shared.pickEchoAnchor(items: items, periodKey: periodKey)
    }

    private var heroRange: SummaryPlaybackRange {
        selectedPeriod == .week ? .week : .month
    }

    private func traceChapterCard(
        layout: TraceLifeCardLayout,
        snapshot: TraceChapterSnapshot
    ) -> some View {
        let _ = quotaRefreshID
        let showsMonth = snapshot.range == .month
        return ZStack {
            Group {
                if showsMonth {
                    traceLifeMonthCardFace(snapshot: snapshot, layout: layout)
                        .transition(.opacity)
                } else {
                    traceLifeSliceCardFace(snapshot: snapshot, layout: layout)
                        .transition(.opacity)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityValue(snapshot.range == .month ? "本月" : "本周")
    }

    private func traceLifeSliceCardFace(snapshot: TraceChapterSnapshot, layout: TraceLifeCardLayout) -> some View {
        let range = snapshot.range
        let hasData = !snapshot.items.isEmpty
        let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0
        let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)

        return VStack(alignment: .center, spacing: layout.faceSpacing) {
            traceLifeSliceHeader(snapshot: snapshot)

            traceLifeSlicePhotoStory(snapshot: snapshot, layout: layout)

            traceLifeSliceScenePills(snapshot: snapshot)

            Button {
                handleSummaryPlaybackTap(range: range, hasData: hasData)
            } label: {
                traceLifeSlicePlayButton(
                    isMonthLocked: isMonthLocked,
                    isEnabled: canPlay || isMonthLocked,
                    height: layout.playButtonHeight,
                    isPreparing: preparingSummaryRange == range
                )
            }
            .buttonStyle(PurposefulCardButtonStyle(radius: 24, depth: 1.05))
            .disabled((!hasData && !isMonthLocked) || preparingSummaryRange != nil)

            traceLifeSliceFooter(snapshot: snapshot)
        }
        .padding(.horizontal, 16)
        .padding(.top, layout.weekTopPadding)
        .padding(.bottom, layout.bottomPadding)
        .background(traceLifeSliceCardBackground)
        .overlay(traceLifeSliceCardBorder)
        .shadow(color: AppColors.subtext.opacity(0.06), radius: 18, x: 0, y: 8)
    }


    private var traceLifeSliceCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.88))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.62),
                        AppColors.paperWarm.opacity(0.18),
                        AppColors.accent.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var traceLifeSliceCardBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Color.white.opacity(0.68), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private func setTraceLifeCardRange(_ range: SummaryPlaybackRange) {
        let period = TraceRangeContextPolicy.period(for: range)
        let rangeChanged = traceLifeCardRange != range
        guard rangeChanged || useCustomRange || selectedPeriod != period else { return }
        tabState.pendingLifeChapterScrollRange = nil
        tracePendingScrollTask?.cancel()
        tracePendingScrollTask = nil
        if rangeChanged {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.16)
            ) {
                traceLifeCardRange = range
            }
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            useCustomRange = false
            selectedPeriod = period
        }
        prepareTraceIfNeeded()
    }

    private func traceLifeMonthCardFace(snapshot: TraceChapterSnapshot, layout: TraceLifeCardLayout) -> some View {
        let range = snapshot.range
        let hasData = !snapshot.items.isEmpty
        let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0
        let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)
        return VStack(alignment: .center, spacing: 11) {
            traceLifeMonthEditorialHero(snapshot: snapshot, layout: layout)

            traceLifeMonthKeywordSection(snapshot: snapshot)

            traceLifeMonthDiaryStrip(snapshot: snapshot, layout: layout)

            Button {
                handleSummaryPlaybackTap(range: range, hasData: hasData)
            } label: {
                traceLifeSlicePlayButton(
                    isMonthLocked: isMonthLocked,
                    isEnabled: canPlay || isMonthLocked,
                    height: layout.playButtonHeight,
                    title: "回顾这个月",
                    isPreparing: preparingSummaryRange == range
                )
            }
            .buttonStyle(PurposefulCardButtonStyle(radius: 24, depth: 1.05))
            .disabled((!hasData && !isMonthLocked) || preparingSummaryRange != nil)

            traceLifeSliceFooter(snapshot: snapshot)
        }
        .padding(.horizontal, 16)
        .padding(.top, layout.monthTopPadding)
        .padding(.bottom, layout.bottomPadding)
        .background(traceLifeSliceCardBackground)
        .overlay(traceLifeSliceCardBorder)
        .shadow(color: AppColors.subtext.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private func traceLifeMonthHeatmapCard(digest: TraceMonthDigest, layout: TraceLifeCardLayout) -> some View {
        let columns = Array(
            repeating: GridItem(.fixed(layout.monthHeatCellSize), spacing: layout.monthHeatSpacing),
            count: 7
        )
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(digest.monthTitle) · 记录了 \(digest.activeDays) 天")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 8)
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.74))
            }

            VStack(spacing: 8) {
                HStack(spacing: layout.monthHeatSpacing) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(weekday)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.subtext.opacity(0.64))
                            .frame(width: layout.monthHeatCellSize)
                    }
                }

                LazyVGrid(columns: columns, spacing: layout.monthHeatSpacing) {
                    ForEach(digest.heatDays) { day in
                        traceLifeMonthHeatCell(day)
                            .frame(width: layout.monthHeatCellSize, height: layout.monthHeatCellSize)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if digest.activeDays == 0 {
                Text("这个月还空着，记下第一笔，月历就会亮起来。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.80))
                .shadow(color: AppColors.subtext.opacity(0.035), radius: 10, x: 0, y: 5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(digest.accessibilityLabel)
    }

    private func traceLifeMonthHeatCell(_ day: TraceMonthHeatDay) -> some View {
        ZStack {
            if day.date == nil {
                Color.clear
            } else if day.count == 0 {
                Circle()
                    .fill(AppColors.subtext.opacity(0.13))
                    .frame(width: 5, height: 5)
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(AppColors.accent.opacity(traceLifeMonthHeatOpacity(for: day.count)))
            }

            if day.isToday {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppColors.accentDark.opacity(0.82), lineWidth: 1)
                    .padding(1)
            }
        }
    }

    private func traceLifeMonthMilestonesCard(
        digest: TraceMonthDigest,
        snapshot: TraceChapterSnapshot,
        layout: TraceLifeCardLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本月里程碑")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.text)

            if digest.milestones.isEmpty {
                Text(snapshot.items.isEmpty ? "有记录之后，这里会留下本月最值得回看的几件事。" : "这个月的线索还很轻，再多几笔会更清楚。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(digest.milestones) { milestone in
                        traceLifeMonthMilestoneRow(milestone, layout: layout)
                    }
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.78))
                .shadow(color: AppColors.subtext.opacity(0.032), radius: 10, x: 0, y: 5)
        )
    }

    private func traceLifeMonthMilestoneRow(_ milestone: TraceMonthMilestone, layout: TraceLifeCardLayout) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: milestone.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.text.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                if let subtitle = milestone.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: 8)

            traceLifeMonthMilestoneMedia(milestone, size: layout.milestoneThumb)
        }
        .frame(minHeight: layout.milestoneThumb)
    }

    @ViewBuilder
    private func traceLifeMonthMilestoneMedia(_ milestone: TraceMonthMilestone, size: CGFloat) -> some View {
        if let anchor = milestone.anchor {
            traceLifeSliceFramedImage(anchor: anchor, height: size)
                .frame(width: size)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(TraceColors.surfaceMuted.opacity(0.92))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: milestone.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.accentDark.opacity(0.62))
                )
        }
    }

    private func traceLifeMonthDigest(snapshot: TraceChapterSnapshot) -> TraceMonthDigest {
        let calendar = Calendar.current
        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now),
              let dayRange = calendar.range(of: .day, in: .month, for: monthInterval.start) else {
            return TraceMonthDigest(
                monthTitle: traceLifeSlicePeriodText(for: .month),
                activeDays: 0,
                totalDays: 0,
                heatDays: [],
                milestones: []
            )
        }

        let dayCounts = Dictionary(grouping: snapshot.items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        .mapValues { $0.count }
        let activeDays = dayCounts.values.filter { $0 > 0 }.count
        let totalDays = dayRange.count
        let heatDays = traceLifeMonthHeatDays(
            monthStart: monthInterval.start,
            totalDays: totalDays,
            dayCounts: dayCounts,
            calendar: calendar,
            now: now
        )

        return TraceMonthDigest(
            monthTitle: traceLifeMonthTitle(for: monthInterval.start),
            activeDays: activeDays,
            totalDays: totalDays,
            heatDays: heatDays,
            milestones: traceLifeMonthMilestones(
                snapshot: snapshot,
                monthStart: monthInterval.start,
                calendar: calendar
            )
        )
    }

    private func traceLifeMonthHeatDays(
        monthStart: Date,
        totalDays: Int,
        dayCounts: [Date: Int],
        calendar: Calendar,
        now: Date
    ) -> [TraceMonthHeatDay] {
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingBlankCount = (firstWeekday + 5) % 7
        var days: [TraceMonthHeatDay] = (0..<leadingBlankCount).map { index in
            TraceMonthHeatDay(id: "blank-leading-\(index)", date: nil, count: 0, isToday: false)
        }

        for offset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: monthStart) else { continue }
            let day = calendar.startOfDay(for: date)
            days.append(
                TraceMonthHeatDay(
                    id: "day-\(offset)",
                    date: day,
                    count: dayCounts[day, default: 0],
                    isToday: calendar.isDate(day, inSameDayAs: now)
                )
            )
        }

        while days.count % 7 != 0 {
            days.append(TraceMonthHeatDay(id: "blank-trailing-\(days.count)", date: nil, count: 0, isToday: false))
        }
        return days
    }

    private func traceLifeMonthMilestones(
        snapshot: TraceChapterSnapshot,
        monthStart: Date,
        calendar: Calendar
    ) -> [TraceMonthMilestone] {
        guard !snapshot.items.isEmpty else { return [] }

        let anchorsByItemID = Dictionary(grouping: snapshot.memoryAnchors, by: \.itemID)
        let itemIndex = Dictionary(uniqueKeysWithValues: snapshot.items.enumerated().map { ($0.element.id, $0.offset) })
        var milestones: [TraceMonthMilestone] = []

        if let busiest = traceLifeMonthBusiestDayMilestone(
            items: snapshot.items,
            anchorsByItemID: anchorsByItemID,
            itemIndex: itemIndex,
            calendar: calendar
        ) {
            milestones.append(busiest)
        }

        if let fresh = traceLifeMonthFreshOrFallbackMilestone(
            items: snapshot.items,
            monthStart: monthStart,
            anchorsByItemID: anchorsByItemID,
            itemIndex: itemIndex,
            calendar: calendar
        ) {
            milestones.append(fresh)
        }

        if let quote = traceLifeMonthQuoteMilestone(
            snapshot: snapshot,
            anchorsByItemID: anchorsByItemID,
            itemIndex: itemIndex
        ) {
            milestones.append(quote)
        }

        return Array(milestones.prefix(3))
    }

    private func traceLifeMonthBusiestDayMilestone(
        items: [HomeItem],
        anchorsByItemID: [UUID: [SummaryMemoryAnchor]],
        itemIndex: [UUID: Int],
        calendar: Calendar
    ) -> TraceMonthMilestone? {
        let groups = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }

        guard let best = groups
            .map({ (day: $0.key, items: $0.value, total: $0.value.reduce(0) { $0 + $1.amount }) })
            .sorted(by: { lhs, rhs in
                if lhs.items.count != rhs.items.count { return lhs.items.count > rhs.items.count }
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.day > rhs.day
            })
            .first,
            best.items.count >= 2 else {
            return nil
        }

        return TraceMonthMilestone(
            id: "busiest-day",
            title: "\(traceLifeMonthShortDate(best.day)) 最热闹 · \(best.items.count) 笔",
            subtitle: "这一天留下 \(best.total.formatted(.cny))",
            icon: "flame.fill",
            anchor: traceLifeMonthBestAnchor(for: best.items, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
        )
    }

    private func traceLifeMonthFreshOrFallbackMilestone(
        items: [HomeItem],
        monthStart: Date,
        anchorsByItemID: [UUID: [SummaryMemoryAnchor]],
        itemIndex: [UUID: Int],
        calendar: Calendar
    ) -> TraceMonthMilestone? {
        let previousItems = homeViewModel.items
            .filter { $0.amount > 0 && $0.draftMeta == nil && $0.createdAt < monthStart }
        let previousScenes = Set(previousItems.map(traceLifeMonthSceneLabel(for:)))
        let monthSceneRows = items.map { item in
            (item: item, label: traceLifeMonthSceneLabel(for: item))
        }
        let freshGroups = Dictionary(grouping: monthSceneRows.filter { !previousScenes.contains($0.label) }) { row in
            row.label
        }

        if let fresh = freshGroups
            .map({ (label: $0.key, rows: $0.value, firstDate: $0.value.map { $0.item.createdAt }.min() ?? .distantFuture) })
            .sorted(by: { lhs, rhs in
                if lhs.rows.count != rhs.rows.count { return lhs.rows.count > rhs.rows.count }
                return lhs.firstDate < rhs.firstDate
            })
            .first {
            let relatedItems = fresh.rows.map { $0.item }
            return TraceMonthMilestone(
                id: "fresh-scene",
                title: "新出现「\(fresh.label)」",
                subtitle: "\(traceLifeMonthShortDate(fresh.firstDate)) 开始被记下",
                icon: "sparkles",
                anchor: traceLifeMonthBestAnchor(for: relatedItems, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            )
        }

        let streak = traceLifeMonthLongestStreak(items: items, calendar: calendar)
        if streak >= 3 {
            return TraceMonthMilestone(
                id: "streak",
                title: "连续记录 \(streak) 天",
                subtitle: "这一段记录连续起来了",
                icon: "calendar.badge.checkmark",
                anchor: nil
            )
        }

        if let bestItem = items.sorted(by: {
            traceLifeMonthRecordValueScore($0, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            > traceLifeMonthRecordValueScore($1, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
        }).first {
            return TraceMonthMilestone(
                id: "best-record",
                title: "最用心的一笔「\(traceLifeMonthShortTitle(bestItem.displayTitle))」",
                subtitle: traceLifeMonthShortDate(bestItem.createdAt),
                icon: "sparkles",
                anchor: traceLifeMonthBestAnchor(for: [bestItem], anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            )
        }

        if let frequent = Dictionary(grouping: monthSceneRows, by: { row in row.label })
            .map({ (label: $0.key, rows: $0.value) })
            .sorted(by: { lhs, rhs in
                if lhs.rows.count != rhs.rows.count { return lhs.rows.count > rhs.rows.count }
                return lhs.label < rhs.label
            })
            .first {
            return TraceMonthMilestone(
                id: "frequent-scene",
                title: "最常去 \(frequent.label) · \(frequent.rows.count) 次",
                subtitle: "这个月反复出现的线索",
                icon: "mappin.and.ellipse",
                anchor: traceLifeMonthBestAnchor(for: frequent.rows.map { $0.item }, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            )
        }

        return nil
    }

    private func traceLifeMonthQuoteMilestone(
        snapshot: TraceChapterSnapshot,
        anchorsByItemID: [UUID: [SummaryMemoryAnchor]],
        itemIndex: [UUID: Int]
    ) -> TraceMonthMilestone? {
        if let item = snapshot.items
            .filter({ traceLifeMonthIsQuoteWorthy($0.title, item: $0) })
            .sorted(by: {
                traceLifeMonthRecordValueScore($0, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
                > traceLifeMonthRecordValueScore($1, anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            })
            .first {
            return TraceMonthMilestone(
                id: "quote",
                title: "“\(traceLifeMonthShortTitle(item.title, limit: 20))”",
                subtitle: "你在 \(traceLifeMonthShortDate(item.createdAt)) 写下",
                icon: "quote.opening",
                anchor: traceLifeMonthBestAnchor(for: [item], anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            )
        }

        if let moment = heroMomentSelection(from: snapshot.items).primary,
           traceLifeMonthIsQuoteWorthy(moment.text, item: moment.item) {
            return TraceMonthMilestone(
                id: "voice",
                title: "“\(traceLifeMonthShortTitle(moment.text, limit: 20))”",
                subtitle: "你在 \(traceLifeMonthShortDate(moment.item.createdAt)) 写下",
                icon: "quote.opening",
                anchor: traceLifeMonthBestAnchor(for: [moment.item], anchorsByItemID: anchorsByItemID, itemIndex: itemIndex)
            )
        }

        return nil
    }

    private func traceLifeMonthBestAnchor(
        for items: [HomeItem],
        anchorsByItemID: [UUID: [SummaryMemoryAnchor]],
        itemIndex: [UUID: Int]
    ) -> SummaryMemoryAnchor? {
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return items
            .flatMap { anchorsByItemID[$0.id] ?? [] }
            .sorted { lhs, rhs in
                guard let leftItem = itemByID[lhs.itemID],
                      let rightItem = itemByID[rhs.itemID] else {
                    return lhs.createdAt > rhs.createdAt
                }
                return traceLifeMonthImageValueScore(lhs, item: leftItem, itemIndex: itemIndex)
                    > traceLifeMonthImageValueScore(rhs, item: rightItem, itemIndex: itemIndex)
            }
            .first
    }

    private func traceLifeMonthRecordValueScore(
        _ item: HomeItem,
        anchorsByItemID: [UUID: [SummaryMemoryAnchor]],
        itemIndex: [UUID: Int]
    ) -> Int {
        let index = itemIndex[item.id] ?? 0
        var score = TraceRepresentative.score(item: item, index: index)
        if anchorsByItemID[item.id]?.isEmpty == false { score += 25 }
        if traceLifeMonthIsHighArousalEmotion(item.displayEmotionTag) { score += 12 }
        return score
    }

    private func traceLifeMonthImageValueScore(
        _ anchor: SummaryMemoryAnchor,
        item: HomeItem,
        itemIndex: [UUID: Int]
    ) -> Int {
        var score = traceLifeMonthRecordValueScore(item, anchorsByItemID: [item.id: [anchor]], itemIndex: itemIndex)
        if item.coverMemoryImageIndex != nil { score += 30 }
        if traceLifeMonthLabelIsMeaningful(anchor.label) || traceLifeMonthLabelIsMeaningful(anchor.caption) { score += 15 }
        return score
    }

    private func traceLifeMonthSceneLabel(for item: HomeItem) -> String {
        let signal = LifeSceneSemanticService.classify(item)
        if signal.kind == .general || signal.confidenceTier == .weak {
            return item.category.rawValue
        }
        return signal.label
    }

    private func traceLifeMonthLongestStreak(items: [HomeItem], calendar: Calendar) -> Int {
        let days = Set(items.map { calendar.startOfDay(for: $0.createdAt) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<days.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: days[index - 1])
            if let expected = expected, calendar.isDate(expected, inSameDayAs: days[index]) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    private func traceLifeMonthHeatOpacity(for count: Int) -> Double {
        if count <= 0 { return 0.12 }
        if count == 1 { return 0.35 }
        if count <= 3 { return 0.60 }
        return 0.90
    }

    private func traceLifeMonthIsHighArousalEmotion(_ emotion: String) -> Bool {
        let text = emotion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        return ["惊喜", "开心", "心动", "难忘", "累", "焦虑", "赶", "庆祝", "远一点", "认真"].contains { text.contains($0) }
    }

    private func traceLifeMonthLabelIsMeaningful(_ label: String) -> Bool {
        let text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return false }
        let generic = ["现场", "记录", "票据", "当时拍下的一张图", "这条记录的照片"]
        return !generic.contains(text)
    }

    private func traceLifeMonthIsQuoteWorthy(_ raw: String, item: HomeItem) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (6...24).contains(text.count) else { return false }
        guard text != item.category.defaultRecordTitle else { return false }
        guard !text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "¥" || $0 == "￥" }) else { return false }
        let blocked = ["消费", "预算", "优化", "占比", "建议关注", "记录了", "支出"]
        return !blocked.contains { text.contains($0) }
    }

    private func traceLifeMonthShortTitle(_ title: String, limit: Int = 18) -> String {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        return "\(text.prefix(limit))…"
    }

    private func traceLifeMonthTitle(for date: Date) -> String {
        "\(Calendar.current.component(.month, from: date))月"
    }

    private func traceLifeMonthShortDate(_ date: Date) -> String {
        let calendar = Calendar.current
        return "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))"
    }

    private func traceLifeMonthEditorialHero(snapshot: TraceChapterSnapshot, layout: TraceLifeCardLayout) -> some View {
        let facts = snapshot.coverFacts
        let coverAnchor = facts.coverAnchorID.flatMap { anchorID in
            snapshot.memoryAnchors.first { $0.id == anchorID }
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Text("月章 · \(traceLifeSlicePeriodText(for: .month))")
                Spacer(minLength: 8)
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.subtext.opacity(0.74))

            if let coverAnchor {
                HStack(alignment: .top, spacing: 14) {
                    traceLifeMonthEditorialCopy(snapshot: snapshot)
                    Spacer(minLength: 0)
                    traceLifeMonthCoverPhoto(
                        anchor: coverAnchor,
                        facts: facts,
                        narrativePlan: snapshot.narrativePlan,
                        layout: layout
                    )
                }
            } else {
                traceLifeMonthEditorialCopy(snapshot: snapshot)
                traceLifeMonthCoverHeatmap(facts: facts)
            }

            traceLifeMonthCoverMetrics(facts: facts)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(minHeight: layout.monthHeroHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            AppColors.paperWarm.opacity(0.48),
                            AppColors.accent.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.075), radius: 16, x: 0, y: 9)
    }

    private func traceLifeMonthEditorialCopy(snapshot: TraceChapterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(snapshot.narrative)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text(snapshot.chapterSummary ?? snapshot.narrativePlan.summary)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("按记录笔数整理")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppColors.accentDark.opacity(0.76))
                .padding(.horizontal, 9)
                .frame(minHeight: 24)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.accent.opacity(0.12))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func traceLifeMonthCoverPhoto(
        anchor: SummaryMemoryAnchor,
        facts: TraceChapterCoverFacts,
        narrativePlan: LifeNarrativePlan,
        layout: TraceLifeCardLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            traceLifeSliceFramedImage(anchor: anchor, height: 142 + (layout.monthPhotoHeight - 72) * 0.35)
                .frame(width: 112)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.82), lineWidth: 1)
                )

            Text(
                traceLifeVisualCaption(
                    anchor: anchor,
                    base: facts.coverCaption ?? "本月的一条记录",
                    range: .month,
                    narrativePlan: narrativePlan
                )
            )
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(width: 112, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("月章封面，\(facts.coverCaption ?? "本月记录")")
    }

    private func traceLifeMonthCoverHeatmap(facts: TraceChapterCoverFacts) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        let cells = Array(repeating: -1, count: facts.monthLeadingBlankCount) + facts.monthDayCounts
        let weekdays = ["一", "二", "三", "四", "五", "六", "日"]
        return VStack(alignment: .leading, spacing: 8) {
            Text("记录日分布")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.text.opacity(0.82))

            HStack(spacing: 6) {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppColors.subtext.opacity(0.62))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, count in
                    let day = index - facts.monthLeadingBlankCount + 1
                    ZStack {
                        if count < 0 {
                            Color.clear
                        } else if count == 0 {
                            Circle()
                                .fill(AppColors.subtext.opacity(0.13))
                                .frame(width: 5, height: 5)
                        } else {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(AppColors.accent.opacity(traceLifeMonthHeatOpacity(for: count)))
                        }

                        if count >= 0, facts.currentMonthDay == day {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(AppColors.accentDark.opacity(0.78), lineWidth: 1)
                        }
                    }
                    .frame(height: 13)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.68))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(facts.monthTitle)，\(facts.activeDays)天有记录，最长连续\(facts.longestStreak)天")
    }

    private func traceLifeMonthCoverMetrics(facts: TraceChapterCoverFacts) -> some View {
        HStack(spacing: 0) {
            traceLifeMonthCoverMetric(title: "记录", value: "\(facts.recordCount)笔")
            traceLifeMonthCoverMetric(title: "记录日", value: "\(facts.activeDays)天")
            traceLifeMonthCoverMetric(
                title: "最长连续",
                value: facts.longestStreak > 0 ? "\(facts.longestStreak)天" : "—"
            )
        }
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.76))
        )
    }

    private func traceLifeMonthCoverMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.70))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func traceLifeMonthSoftSectionBackground(cornerRadius: CGFloat = 18) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.82))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.70),
                        AppColors.paperWarm.opacity(0.14),
                        AppColors.accent.opacity(0.045)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: AppColors.subtext.opacity(0.045), radius: 12, x: 0, y: 6)
    }

    private func traceLifeMonthKeywordSection(snapshot: TraceChapterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("本月生活关键词")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.text)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(traceLifeMonthKeywords(snapshot: snapshot), id: \.self) { keyword in
                        traceLifeMonthKeywordPill(keyword)
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(traceLifeMonthSoftSectionBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.76), lineWidth: 1)
        )
    }

    private func traceLifeMonthKeywordPill(_ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: traceLifeSlicePillIcon(for: label))
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(AppColors.accentDark.opacity(0.84))
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            Capsule(style: .continuous)
                .fill(TraceColors.surfaceMuted.opacity(0.86))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
    }

    private func traceLifeMonthDiaryStrip(snapshot: TraceChapterSnapshot, layout: TraceLifeCardLayout) -> some View {
        let coverItemID = snapshot.coverFacts.coverItemID
        let anchors = TraceMonthDiaryPolicy.anchors(
            from: snapshot.memoryAnchors,
            excludingCoverItemID: coverItemID
        )
        let anchorItemIDs = Set(anchors.map(\.itemID)).union(coverItemID.map { [$0] } ?? [])
        let items = TraceRepresentative.items(from: snapshot.items, maxItems: 10, maxPerCategory: 2)
            .filter { !anchorItemIDs.contains($0.id) }
        let count = min(anchors.count + items.count, 6)
        return VStack(alignment: .leading, spacing: 9) {
            Text("本月日记")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.text)

            if count > 0 {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(0..<count, id: \.self) { index in
                            let anchor = anchors.indices.contains(index) ? anchors[index] : nil
                            let fallbackIndex = index - anchors.count
                            let fallbackItem = fallbackIndex >= 0 && items.indices.contains(fallbackIndex)
                                ? items[fallbackIndex]
                                : nil
                            let item = traceLifeItem(for: anchor, in: snapshot.items, fallback: fallbackItem)
                            traceLifeMonthDiaryCard(anchor: anchor, item: item, index: index, layout: layout)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.hidden)
            } else {
                Text(
                    coverItemID == nil
                        ? "这个月还没有适合放进日记的记录。"
                        : "封面记录已经放在上方，更多记录会继续排进本月日记。"
                )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.74))
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(traceLifeMonthSoftSectionBackground())
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.76), lineWidth: 1)
        )
    }

    private func traceLifeMonthDiaryCard(
        anchor: SummaryMemoryAnchor?,
        item: HomeItem?,
        index: Int,
        layout: TraceLifeCardLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                Group {
                    if anchor != nil {
                        traceLifeSliceFramedImage(anchor: anchor, height: layout.monthDiaryPhotoHeight)
                            .saturation(0.84)
                            .contrast(0.94)
                            .brightness(0.025)
                    } else {
                        traceLifeMonthDiaryRecordCover(item: item, index: index, height: layout.monthDiaryPhotoHeight)
                    }
                }
                .frame(width: 108)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear,
                        AppColors.text.opacity(0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: 108, height: layout.monthDiaryPhotoHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1)
            )
            .shadow(color: AppColors.subtext.opacity(0.06), radius: 10, x: 0, y: 5)

            Text(traceLifeMonthDiaryCaption(anchor: anchor, item: item, index: index))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.text.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 108, alignment: .leading)

            Text(traceLifeMonthDiaryAmountText(item: item))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 108, alignment: .leading)
        }
    }

    private func traceLifeMonthOverview(snapshot: TraceChapterSnapshot, layout: TraceLifeCardLayout) -> some View {
        let clues = traceCategoryClues(from: snapshot.items)
        let total = snapshot.items.reduce(0) { $0 + $1.amount }
        let segments = traceLifeMonthRingSegments(clues)

        return HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(TraceColors.surfaceMuted, lineWidth: layout.monthRingLineWidth)
                    .frame(width: layout.monthRingSize, height: layout.monthRingSize)

                ForEach(segments) { segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: layout.monthRingLineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: layout.monthRingSize, height: layout.monthRingSize)
                }

                VStack(spacing: 4) {
                    Text("总支出")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.72))
                    Text(total.formatted(.cny))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .frame(width: 86)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(clues.prefix(5).enumerated()), id: \.element.id) { index, clue in
                    traceLifeMonthCategoryRow(clue, index: index, total: max(total, 1))
                }
                if clues.isEmpty {
                    Text("本月还在等几笔记录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.subtext)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.64))
        )
    }

    private func traceLifeMonthCategoryRow(_ clue: TraceCategoryClue, index: Int, total: Double) -> some View {
        let percent = Int((clue.total / total * 100).rounded())
        return HStack(spacing: 8) {
            Circle()
                .fill(traceLifeMonthCategoryColor(index: index, category: clue.category))
                .frame(width: 7, height: 7)
            Text(clue.category.rawValue)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(clue.total.formatted(.cny))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text("\(percent)%")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.subtext.opacity(0.66))
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func traceLifeMonthHighlights(snapshot: TraceChapterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月亮点")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(Array(traceLifeMonthHighlightRows(snapshot: snapshot).enumerated()), id: \.offset) { index, row in
                HStack(alignment: .top, spacing: 10) {
                    traceLifeSliceRoundIcon(
                        systemName: row.icon,
                        size: 30,
                        iconSize: 13
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColors.text.opacity(0.88))
                            .lineLimit(1)
                        Text(row.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.subtext.opacity(0.80))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }

    private func traceLifeSliceHeader(snapshot: TraceChapterSnapshot) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(traceLifeSlicePeriodText(for: snapshot.range))
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.subtext.opacity(0.74))

            HStack(alignment: .center, spacing: 8) {
                Text(snapshot.narrative)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accent.opacity(0.70))
                    .offset(y: 3)
            }

            Text(snapshot.chapterSummary ?? snapshot.narrativePlan.summary)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func traceLifeSlicePhotoStory(snapshot: TraceChapterSnapshot, layout: TraceLifeCardLayout) -> some View {
        let photoCount = snapshot.memoryAnchors.count
        switch photoCount {
        case 0:
            traceLifeSliceRecordCanvas(snapshot: snapshot)
                .padding(.top, 2)
        case 1:
            traceLifeSlicePrimaryPhoto(
                snapshot: snapshot,
                height: layout.primaryPhotoHeight + 30
            )
            .padding(.top, 2)
        case 2:
            traceLifeSliceTwoPhotoStory(
                snapshot: snapshot,
                height: layout.primaryPhotoHeight * 0.72
            )
            .padding(.top, 2)
        default:
            VStack(spacing: 10) {
                traceLifeSlicePrimaryPhoto(snapshot: snapshot, height: layout.primaryPhotoHeight)
                traceLifeSliceSecondaryPhotos(snapshot: snapshot, height: layout.secondaryPhotoHeight)
            }
            .padding(.top, 2)
        }
    }

    private func traceLifeMonthDiaryRecordCover(item: HomeItem?, index: Int, height: CGFloat) -> some View {
        let category = item?.category ?? .other
        let baseColors = traceLifeSliceFallbackColors(for: category, index: index)
        let colors = index.isMultiple(of: 2)
            ? baseColors
            : Array(baseColors.dropFirst()) + Array(baseColors.prefix(1))
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: MemoryAttachmentVisuals.categorySystemImage(category))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.accentDark.opacity(0.66))
                    Spacer(minLength: 4)
                    Text(traceLifeMonthDiaryDateText(item: item))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accentDark.opacity(0.54))
                }

                Spacer(minLength: 0)

                Text(traceLifeMonthDiaryCoverTitle(item: item, index: index))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.text.opacity(0.82))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)

                Text(category.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
            }
            .padding(10)
        }
        .frame(width: 108, height: height)
    }

    private func traceLifeMonthDiaryDateText(item: HomeItem?) -> String {
        guard let item else { return "本月" }
        let month = Calendar.current.component(.month, from: item.createdAt)
        let day = Calendar.current.component(.day, from: item.createdAt)
        return "\(month)/\(day)"
    }

    private func traceLifeMonthDiaryCoverTitle(item: HomeItem?, index: Int) -> String {
        guard let item else { return "这个月的一笔" }
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty,
           title != item.category.defaultRecordTitle,
           !RecordSemanticLexicon.isSystemGeneratedTitle(title) {
            return title
        }
        return traceLifeMonthPhotoCaption(anchor: nil, item: item, index: index)
    }

    private func traceLifeMonthDiaryCaption(
        anchor: SummaryMemoryAnchor?,
        item: HomeItem?,
        index: Int
    ) -> String {
        if anchor != nil {
            return traceLifeMonthPhotoCaption(anchor: anchor, item: item, index: index)
        }
        guard let item else { return "本月记录" }
        return "\(item.category.rawValue) · \(item.createdAt.zhBillTime)"
    }

    private func traceLifeSliceRecordCanvas(snapshot: TraceChapterSnapshot) -> some View {
        let items = TraceRepresentative.items(from: snapshot.items, maxItems: 3, maxPerCategory: 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.accentDark.opacity(0.76))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(items.isEmpty ? "这一周还在等记录" : "这一周的生活片段")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Text(items.isEmpty ? "先记下一笔，这里会逐渐有内容。" : "没有照片也没关系，记录本身已经留下了现场。")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))
                }
                Spacer(minLength: 0)
            }

            if items.isEmpty {
                Text("再记下几笔，这里会自动整理出适合回看的片段。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        traceLifeSliceRecordCanvasRow(item)
                    }
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            AppColors.paperWarm.opacity(0.48),
                            AppColors.accent.opacity(0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.80), lineWidth: 1)
        )
    }

    private func traceLifeSliceRecordCanvasRow(_ item: HomeItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.accent.opacity(0.09))
                    .frame(width: 34, height: 34)
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                Text("\(item.createdAt.zhBillDateTime) · \(item.category.rawValue)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(item.amount.formatted(.cny))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text.opacity(0.84))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.70))
        )
    }

    private func traceLifeSliceTwoPhotoStory(snapshot: TraceChapterSnapshot, height: CGFloat) -> some View {
        let anchors = Array(snapshot.memoryAnchors.prefix(2))
        return HStack(spacing: 10) {
            ForEach(Array(anchors.enumerated()), id: \.offset) { index, anchor in
                let item = traceLifeItem(for: anchor, in: snapshot.items, fallback: nil)
                traceLifeSliceSmallPhoto(anchor: anchor, item: item, index: index, height: height)
            }
        }
    }

    private func traceLifeSlicePhotoMosaic(_ anchors: [SummaryMemoryAnchor]) -> some View {
        ZStack(alignment: .topTrailing) {
            if let primary = anchors.first {
                traceLifeSliceImage(anchor: primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                traceLifeSliceEmptyBackdrop
            }

            if anchors.count > 1 {
                VStack(spacing: 8) {
                    ForEach(Array(anchors.dropFirst().prefix(2))) { anchor in
                        traceLifeSliceThumbnail(anchor)
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func traceLifeSlicePrimaryPhoto(snapshot: TraceChapterSnapshot, height: CGFloat) -> some View {
        let anchor = snapshot.memoryAnchors.first
        return ZStack(alignment: .bottomLeading) {
            traceLifeSliceFramedImage(anchor: anchor, height: height)

            HStack(alignment: .center, spacing: 8) {
                Text(traceLifeSlicePrimaryCaption(snapshot: snapshot))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                traceLifeSliceRoundIcon(
                    systemName: MemoryAttachmentVisuals.categorySystemImage(
                        traceLifeSlicePrimaryCategory(snapshot: snapshot)
                    )
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.82), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.08), radius: 14, x: 0, y: 8)
    }

    private func traceLifeSliceSecondaryPhotos(snapshot: TraceChapterSnapshot, height: CGFloat) -> some View {
        let anchors = Array(snapshot.memoryAnchors.dropFirst().prefix(2))
        let fallbackItems = Array(snapshot.items.dropFirst().prefix(2))
        return HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                let anchor = anchors.indices.contains(index) ? anchors[index] : nil
                let fallbackItem = fallbackItems.indices.contains(index) ? fallbackItems[index] : nil
                let item = traceLifeItem(for: anchor, in: snapshot.items, fallback: fallbackItem)
                traceLifeSliceSmallPhoto(anchor: anchor, item: item, index: index, height: height)
            }
        }
    }

    private func traceLifeSliceSmallPhoto(
        anchor: SummaryMemoryAnchor?,
        item: HomeItem?,
        index: Int,
        height: CGFloat
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let anchor {
                traceLifeSliceFramedImage(anchor: anchor, height: height)
            } else {
                traceLifeSliceFallbackTile(item: item, index: index, height: height)
            }

            HStack(alignment: .center, spacing: 7) {
                Text(traceLifeSliceSmallCaption(anchor: anchor, item: item, index: index))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 4)

                traceLifeSliceRoundIcon(
                    systemName: MemoryAttachmentVisuals.categorySystemImage(item?.category ?? .daily),
                    size: 22,
                    iconSize: 10
                )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.91))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private func traceLifeSliceFallbackTile(item: HomeItem?, index: Int, height: CGFloat) -> some View {
        let category = item?.category ?? (index == 0 ? .transport : .daily)
        let amount = item.map { $0.amount.formatted(.cny) } ?? traceLifeSlicePeriodText(for: .week)
        let colors = traceLifeSliceFallbackColors(for: category, index: index)
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let line = Color.white.opacity(0.20)
                for row in 0..<4 {
                    let y = size.height * (0.20 + CGFloat(row) * 0.17)
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.10, y: y))
                    path.addCurve(
                        to: CGPoint(x: size.width * 0.88, y: y + CGFloat(row % 2 == 0 ? 7 : -5)),
                        control1: CGPoint(x: size.width * 0.30, y: y - 8),
                        control2: CGPoint(x: size.width * 0.66, y: y + 9)
                    )
                    context.stroke(path, with: .color(line), lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(category))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.22))
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.54))
                    .lineLimit(1)
                Text(amount)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.accentDark.opacity(0.52))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private func traceLifeSliceFallbackColors(for category: HomeItem.Category, index: Int) -> [Color] {
        switch category {
        case .transport:
            return [Color(hex: "edf4f5"), Color(hex: "dcebe8"), Color(hex: "f8f1e2")]
        case .dining:
            return [Color(hex: "fff3df"), Color(hex: "f4dfc4"), Color(hex: "edf0df")]
        case .shopping, .daily, .home:
            return [Color(hex: "f5eee4"), Color(hex: "eadcc8"), Color(hex: "e4eee6")]
        case .social, .entertainment:
            return [Color(hex: "f7eee7"), Color(hex: "ead8d1"), Color(hex: "e8efe5")]
        case .health:
            return [Color(hex: "eef4ec"), Color(hex: "dcecdf"), Color(hex: "f6efe1")]
        case .lodging:
            return [Color(hex: "edf1f5"), Color(hex: "dce5ef"), Color(hex: "f5eadf")]
        case .other:
            return index.isMultiple(of: 2)
                ? [Color(hex: "f6efe2"), Color(hex: "e5efe8"), Color(hex: "f7f4ea")]
                : [Color(hex: "edf2ee"), Color(hex: "f2e7d6"), Color(hex: "f8f4e8")]
        }
    }

    @ViewBuilder
    private func traceLifeSliceFramedImage(anchor: SummaryMemoryAnchor?, height: CGFloat) -> some View {
        if let anchor {
            ZStack {
                MemoryAttachmentThumbnail(
                    imageData: anchor.imageData,
                    imageReference: anchor.imageReference,
                    height: height,
                    cornerRadius: 0
                )
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.clear,
                        AppColors.text.opacity(0.08),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()
        } else {
            traceLifeSliceEmptyBackdrop
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipped()
        }
    }

    @ViewBuilder
    private func traceLifeSliceImage(anchor: SummaryMemoryAnchor?) -> some View {
        if let anchor {
            MemoryAttachmentThumbnail(
                imageData: anchor.imageData,
                imageReference: anchor.imageReference,
                height: nil,
                cornerRadius: 0
            )
        } else {
            traceLifeSliceEmptyBackdrop
        }
    }

    private func traceLifeSliceThumbnail(_ anchor: SummaryMemoryAnchor) -> some View {
        ZStack(alignment: .bottomLeading) {
            traceLifeSliceImage(anchor: anchor)
                .frame(width: 104, height: 78)
                .clipped()

            Text(anchor.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule(style: .continuous).fill(Color.black.opacity(0.34)))
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 6)
    }

    private var traceLifeSliceEmptyBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.accent.opacity(0.18),
                    Color(hex: "f6efe2"),
                    Color(hex: "dfeee7")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.34))
                Text("按记录整理")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.accentDark.opacity(0.62))
                Text("分类、金额和时间都在")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.accentDark.opacity(0.46))
            }
        }
    }

    private func traceLifeSlicePlayButton(
        isMonthLocked: Bool,
        isEnabled: Bool,
        height: CGFloat,
        title: String = "回看这一段",
        isPreparing: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isEnabled ? 0.92 : 0.58))
                    .frame(width: 26, height: 26)
                if isPreparing {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(AppColors.accentDark)
                } else {
                    Image(systemName: isMonthLocked ? "lock.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isEnabled ? AppColors.accentDark : AppColors.subtext.opacity(0.72))
                        .offset(x: isMonthLocked ? 0 : 1.5)
                }
            }
            Text(isPreparing ? "正在整理…" : (isMonthLocked ? "了解会员" : title))
                .font(.headline.weight(.bold))
                .foregroundStyle(isEnabled ? Color.white : AppColors.subtext.opacity(0.74))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(44, height))
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isEnabled
                            ? [AppColors.accent.opacity(0.92), AppColors.accentDark.opacity(0.88)]
                            : [TraceColors.surfaceMuted, TraceColors.surfaceMuted.opacity(0.82)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: isEnabled ? AppColors.accent.opacity(0.14) : .clear, radius: 10, x: 0, y: 5)
    }

    private func traceLifeSliceScenePills(snapshot: TraceChapterSnapshot) -> some View {
        let labels = traceLifeSliceLabels(snapshot: snapshot)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                ForEach(labels, id: \.self) { label in
                    traceLifeSliceScenePill(label)
                }
            }

            VStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    traceLifeSliceScenePill(label)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func traceLifeSliceScenePill(_ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: traceLifeSlicePillIcon(for: label))
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.footnote.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(AppColors.accentDark.opacity(0.86))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(TraceColors.surfaceMuted.opacity(0.78))
        )
    }

    private func traceLifeSliceFooter(snapshot: TraceChapterSnapshot) -> some View {
        Button {
            openTraceDetail(for: snapshot.range)
        } label: {
            HStack(spacing: 8) {
                Text("细查这一段 · \(snapshot.items.count) 笔")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.subtext.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.subtext.opacity(0.74))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.74))
                    .shadow(color: AppColors.subtext.opacity(0.04), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }

    private func traceLifeSliceLabels(snapshot: TraceChapterSnapshot) -> [String] {
        let anchorLabels = snapshot.memoryAnchors.map(\.label)
        let markLabels = snapshot.narrativePlan.markLabels
        let categoryLabels = snapshot.items.map(\.category.rawValue)
        let labels = anchorLabels + markLabels + categoryLabels + ["添置", "生活"]
        var seen = Set<String>()
        var result: [String] = []
        for label in labels where !label.isEmpty && seen.insert(label).inserted {
            result.append(label)
            if result.count >= 3 { break }
        }
        return result
    }

    private func traceLifeMonthKeywords(snapshot: TraceChapterSnapshot) -> [String] {
        let clueLabels = traceCategoryClues(from: snapshot.items)
            .prefix(5)
            .map { $0.category.rawValue }
        let labels = Array(clueLabels) + traceLifeSliceLabels(snapshot: snapshot)
        var seen = Set<String>()
        var result: [String] = []
        for label in labels where !label.isEmpty && seen.insert(label).inserted {
            result.append(label)
            if result.count >= 6 { break }
        }
        return result.isEmpty ? ["日常", "现场", "回看"] : result
    }

    private func traceLifeMonthDiaryAmountText(item: HomeItem?) -> String {
        guard let item else { return "留在这个月里" }
        return "花费 \(item.amount.formatted(.cny))"
    }

    private func traceLifeSlicePeriodText(for range: SummaryPlaybackRange) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        guard let interval = traceLifeDateInterval(for: range),
              let end = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) else {
            return range == .week ? "本周" : "本月"
        }
        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: end))"
    }

    private func traceLifeSlicePrimaryCaption(snapshot: TraceChapterSnapshot) -> String {
        if let firstAnchor = snapshot.memoryAnchors.first {
            let item = snapshot.items.first { $0.id == firstAnchor.itemID }
            let base = snapshot.coverFacts.coverCaption ?? traceLifeResolvedAnchorCaption(
                anchor: firstAnchor,
                item: item,
                fallback: "这周的一条记录"
            )
            return traceLifeVisualCaption(
                anchor: firstAnchor,
                base: base,
                range: snapshot.range,
                narrativePlan: snapshot.narrativePlan
            )
        }
        if let first = snapshot.items.first {
            return traceLifeSliceCaption(for: first)
        }
        return "这周的一条记录"
    }

    private func traceLifeVisualCaption(
        anchor: SummaryMemoryAnchor,
        base: String,
        range: SummaryPlaybackRange,
        narrativePlan: LifeNarrativePlan
    ) -> String {
        guard let lead = narrativePlan.signalsByRole[.lead]?.first,
              lead.kind == .photo || lead.kind == .userText || lead.kind == .change,
              lead.evidenceItemIDs.contains(anchor.itemID) else {
            return "\(range == .week ? "本周画面" : "本月画面") · \(base)"
        }
        return base
    }

    private func traceLifeSliceSmallCaption(
        anchor: SummaryMemoryAnchor?,
        item: HomeItem?,
        index: Int
    ) -> String {
        if let anchor, !anchor.caption.isEmpty {
            return traceLifeResolvedAnchorCaption(anchor: anchor, item: item, fallback: nil)
        }
        if let item {
            return traceLifeSliceCaption(for: item)
        }
        return index == 0 ? "回家路上" : "给家里添的"
    }

    private func traceLifeItem(
        for anchor: SummaryMemoryAnchor?,
        in items: [HomeItem],
        fallback: HomeItem?
    ) -> HomeItem? {
        guard let anchor else { return fallback }
        return items.first { $0.id == anchor.itemID } ?? fallback
    }

    private func traceLifeSliceCaption(for item: HomeItem) -> String {
        if traceLifeIsBeverageOrSnack(item) {
            return traceLifeBeverageCaption(for: item)
        }
        switch item.category {
        case .transport:
            return traceLifeTransportCaption(for: item)
        case .dining:
            return traceLifeLooksLikeGathering(item)
                ? traceLifeGatheringCaption(for: item)
                : "这一顿饭"
        case .daily, .home:
            return "给家里买的"
        case .shopping:
            return traceLifeShoppingCaption(for: item)
        case .social:
            return traceLifeGatheringCaption(for: item)
        case .health:
            return "身体相关的一张记录"
        case .lodging:
            return "住下来的那晚"
        case .entertainment:
            return "放松的一段"
        case .other:
            return "这一笔也留着"
        }
    }

    private func traceLifeSlicePrimaryCategory(snapshot: TraceChapterSnapshot) -> HomeItem.Category {
        TracePhotoEvidenceBindingPolicy.primaryCategory(
            anchor: snapshot.memoryAnchors.first,
            items: snapshot.items
        )
    }

    private func traceLifeSliceRoundIcon(
        systemName: String,
        size: CGFloat = 30,
        iconSize: CGFloat = 14
    ) -> some View {
        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(0.16))
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(AppColors.accentDark.opacity(0.78))
        }
    }

    private func traceLifeSlicePillIcon(for label: String) -> String {
        if label.contains("餐") || label.contains("饭") || label.contains("饮") { return "fork.knife" }
        if label.contains("通勤") || label.contains("交通") || label.contains("路") { return "bus.fill" }
        if label.contains("家") || label.contains("日用") || label.contains("添") { return "house.fill" }
        if label.contains("购物") || label.contains("买") { return "bag.fill" }
        if label.contains("健康") || label.contains("照护") { return "cross.case.fill" }
        if label.contains("社交") || label.contains("见面") { return "person.2.fill" }
        if label.contains("住宿") || label.contains("旅行") { return "bed.double.fill" }
        if label.contains("娱乐") { return "sparkles" }
        return "leaf.fill"
    }

    private func traceLifeMonthRingSegments(_ clues: [TraceCategoryClue]) -> [TraceLifeRingSegment] {
        var cursor = 0.0
        return clues.prefix(5).enumerated().compactMap { index, clue in
            guard clue.ratio > 0 else { return nil }
            let start = cursor
            let end = min(cursor + clue.ratio, 1)
            cursor = end
            return TraceLifeRingSegment(
                id: clue.category.rawValue,
                category: clue.category,
                start: start,
                end: end,
                color: traceLifeMonthCategoryColor(index: index, category: clue.category)
            )
        }
    }

    private func traceLifeResolvedAnchorCaption(
        anchor: SummaryMemoryAnchor,
        item: HomeItem?,
        fallback: String?
    ) -> String {
        let caption = anchor.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item,
           traceLifeIsOverclaimedGatheringCaption(caption),
           !traceLifeLooksLikeGathering(item) {
            return traceLifeSliceCaption(for: item)
        }
        if let item,
           traceLifeShouldRewriteAwkwardPhotoCaption(caption) {
            return traceLifeSliceCaption(for: item)
        }
        if !caption.isEmpty {
            return caption
        }
        if let item {
            return traceLifeSliceCaption(for: item)
        }
        return fallback ?? "这条记录的照片"
    }

    private func traceLifeIsOverclaimedGatheringCaption(_ caption: String) -> Bool {
        caption.localizedCaseInsensitiveContains("见面")
            || caption.localizedCaseInsensitiveContains("聚餐")
    }

    private func traceLifeShouldRewriteAwkwardPhotoCaption(_ caption: String) -> Bool {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let awkwardFragments = [
            "当时拍下的一张图",
            "这条记录的照片",
            "这张图把",
            "留住了",
            "留了下来",
            "代表了那笔",
            "代表这笔",
            "这件东西代表",
            "当时留了下来"
        ]
        return awkwardFragments.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func traceLifeGatheringCaption(for item: HomeItem) -> String {
        let text = traceLifeSemanticText(for: item)
        if text.localizedCaseInsensitiveContains("朋友") {
            return "和朋友的一次聚会"
        }
        if text.localizedCaseInsensitiveContains("同学") {
            return "和同学的一次聚会"
        }
        if text.localizedCaseInsensitiveContains("生日") {
            return "一次生日聚会"
        }
        if text.localizedCaseInsensitiveContains("家庭") || text.localizedCaseInsensitiveContains("家人") {
            return "和家里人的一顿饭"
        }
        if item.category == .social {
            return "和人见了一面"
        }
        return "一次聚餐"
    }

    private func traceLifeBeverageCaption(for item: HomeItem) -> String {
        let text = traceLifeSemanticText(for: item)
        if text.localizedCaseInsensitiveContains("可乐") { return "买了一瓶可乐" }
        if text.localizedCaseInsensitiveContains("矿泉水") || text.localizedCaseInsensitiveContains("瓶装水") || text.localizedCaseInsensitiveContains("纯净水") {
            return "买了几瓶水"
        }
        if text.localizedCaseInsensitiveContains("咖啡") { return "喝了一杯咖啡" }
        if text.localizedCaseInsensitiveContains("奶茶") { return "喝了一杯奶茶" }
        return "买了点喝的"
    }

    private func traceLifeTransportCaption(for item: HomeItem) -> String {
        let text = traceLifeSemanticText(for: item)
        if text.localizedCaseInsensitiveContains("下班") || text.localizedCaseInsensitiveContains("回家") {
            return "下班回家路上"
        }
        if text.localizedCaseInsensitiveContains("上班") || text.localizedCaseInsensitiveContains("通勤") {
            return "上班路上"
        }
        return "路上的一段"
    }

    private func traceLifeShoppingCaption(for item: HomeItem) -> String {
        let text = traceLifeSemanticText(for: item)
        if text.localizedCaseInsensitiveContains("快递") {
            return "收到的快递"
        }
        if text.localizedCaseInsensitiveContains("衣服")
            || text.localizedCaseInsensitiveContains("鞋")
            || text.localizedCaseInsensitiveContains("包包")
            || text.localizedCaseInsensitiveContains("背包") {
            return "买了件穿用的"
        }
        return "这次买的东西"
    }

    private func traceLifeLooksLikeGathering(_ item: HomeItem) -> Bool {
        let text = traceLifeSemanticText(for: item)
        guard item.category == .dining || item.category == .social || item.category == .entertainment else {
            return false
        }
        if traceLifeIsBeverageOrSnack(item) { return false }
        let gatheringKeywords = ["聚餐", "请客", "约饭", "朋友", "同学", "饭局", "见面", "火锅", "烧烤", "生日", "KTV", "ktv"]
        if gatheringKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
            return true
        }
        let routineKeywords = ["早餐", "午餐", "晚餐", "外卖", "便当", "食堂", "咖啡", "奶茶", "饮品", "可乐", "矿泉水", "瓶装水"]
        return item.category == .dining
            && item.amount >= 120
            && !routineKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) })
    }

    private func traceLifeIsBeverageOrSnack(_ item: HomeItem) -> Bool {
        let text = traceLifeSemanticText(for: item)
        let keywords = [
            "可乐", "无糖", "饮料", "饮品", "矿泉水", "瓶装水", "纯净水", "苏打水",
            "咖啡", "奶茶", "茶饮", "果汁", "汽水", "冰红茶", "便利店"
        ]
        return keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func traceLifeSemanticText(for item: HomeItem) -> String {
        [
            item.title,
            item.displayTitle,
            item.displayEmotionTag,
            item.category.rawValue,
            item.category.label,
            item.merchantBrandId ?? ""
        ]
        .joined(separator: " ")
    }

    private func traceLifeMonthCategoryColor(index: Int, category: HomeItem.Category) -> Color {
        let palette = [
            AppColors.accent,
            Color(hex: "6f9fe8"),
            Color(hex: "f0b85a"),
            Color(hex: "db7f75"),
            Color(hex: "8fc7a3")
        ]
        guard palette.indices.contains(index) else {
            return traceAccentColor(for: category)
        }
        return palette[index]
    }

    private func traceLifeMonthHighlightRows(snapshot: TraceChapterSnapshot) -> [(icon: String, title: String, subtitle: String)] {
        let clues = traceCategoryClues(from: snapshot.items)
        let total = snapshot.items.reduce(0) { $0 + $1.amount }
        let activeDays = traceActiveDayCount(from: snapshot.items)
        var rows: [(icon: String, title: String, subtitle: String)] = []

        if let top = clues.first {
            rows.append((
                icon: MemoryAttachmentVisuals.categorySystemImage(top.category),
                title: "\(top.category.rawValue)最常出现",
                subtitle: "本月 \(top.count) 笔，合计 \(top.total.formatted(.cny))"
            ))
        }

        rows.append((
            icon: "calendar",
            title: "\(activeDays) 天有记录",
            subtitle: "\(snapshot.items.count) 笔账单，合计 \(total.formatted(.cny))"
        ))

        if snapshot.memoryAnchors.isEmpty {
            rows.append((
                icon: "text.alignleft",
                title: "按记录整理",
                subtitle: "用分类、金额和时间进入月回看"
            ))
        } else {
            rows.append((
                icon: "photo.on.rectangle.angled",
                title: "\(snapshot.memoryAnchors.count) 张画面",
                subtitle: "它们会作为这个月的回看入口"
            ))
        }

        return Array(rows.prefix(3))
    }

    private func traceLifeMonthPhotoCaption(anchor: SummaryMemoryAnchor?, item: HomeItem?, index: Int) -> String {
        if let anchor {
            let caption = traceLifeResolvedAnchorCaption(anchor: anchor, item: item, fallback: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !caption.isEmpty { return caption }
            if !anchor.label.isEmpty { return anchor.label }
        }
        if let item {
            switch item.category {
            case .dining:
                if traceLifeIsBeverageOrSnack(item) { return "饮品补给" }
                return traceLifeLooksLikeGathering(item)
                    ? (index == 0 ? "最常去的店" : "见面日常")
                    : "日常一餐"
            case .transport:
                return "通勤日常"
            case .shopping, .daily, .home:
                return "本月添置"
            case .health:
                return "照护记录"
            case .lodging:
                return "住下来的夜晚"
            case .entertainment:
                return "放松片刻"
            case .social:
                return "见面留下"
            case .other:
                return "这个月的一笔"
            }
        }
        return index == 0 ? "最常去的店" : (index == 1 ? "通勤日常" : "本月添置")
    }

    private func buildTraceChapterSnapshot(for range: SummaryPlaybackRange) -> TraceChapterSnapshot {
        let items = traceLifeScopedItems(for: range)
        let cacheKey = traceChapterSnapshotCacheKey(range: range)
        if let cached = traceSnapshotStore.chapterSnapshot(for: cacheKey) {
            return cached
        }

        let now = Date()
        let snapshot = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: range,
                items: items,
                allItems: homeViewModel.items,
                isMember: hasMemberAccess,
                prioritizeRecurringMarks: range == .month,
                periodKey: range == .week
                    ? quotaStore.currentWeekKey()
                    : EchoAnchorService.shared.periodKeyForMonth(),
                usesEchoAnchor: true,
                sourceRevision: homeViewModel.homeDashboardRevision,
                now: now
            )
        )
        traceSnapshotStore.storeChapterSnapshot(snapshot, for: cacheKey)
        return snapshot
    }

    private func traceLifeScopedItems(for range: SummaryPlaybackRange) -> [HomeItem] {
        guard let interval = traceLifeDateInterval(for: range) else { return [] }
        return homeViewModel.items(in: interval)
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func traceLifeDateInterval(for range: SummaryPlaybackRange, now: Date = Date()) -> DateInterval? {
        switch range {
        case .week:
            return PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now)
        case .month:
            return Calendar.current.dateInterval(of: .month, for: now)
        }
    }

    private func traceLifeSliceMemoryAnchors(
        for range: SummaryPlaybackRange,
        items: [HomeItem]
    ) -> [SummaryMemoryAnchor] {
        MemoryAnchorSelectionPolicy.selectAnchors(
            from: items,
            range: range,
            limit: 3,
            label: traceLifeMemoryAnchorLabel(role:sceneHint:),
            caption: traceLifeMemoryAnchorCaption(role:sceneHint:)
        )
    }

    private func traceLifeMemoryAnchorLabel(
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint
    ) -> String {
        switch sceneHint {
        case .gathering: return "见面"
        case .travel, .travelTransport: return "出门"
        case .vehicleCare, .healthRecord: return role == .receipt ? "票据" : "记录"
        case .homeLife: return "家里"
        case .careRecord: return "照护"
        case .experience: return role == .receipt ? "票据" : "现场"
        case .giftMoment: return "心意"
        case .importantPurchase: return "添置"
        }
    }

    private func traceLifeMemoryAnchorCaption(
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint
    ) -> String {
        switch role {
        case .moment:
            return sceneHint == .gathering ? "和朋友的一次聚会。" : "这条记录的照片。"
        case .receipt:
            return "这张图以后查起来更清楚。"
        case .place:
            return "路上拍下的一张图。"
        case .object:
            return "这次买的东西。"
        case .careRecord:
            return "照护相关的一张记录。"
        }
    }

    private func traceChapterSnapshotCacheKey(
        range: SummaryPlaybackRange,
        now: Date = Date()
    ) -> String {
        let periodKey = range == .week
            ? quotaStore.currentWeekKey()
            : EchoAnchorService.shared.periodKeyForMonth()
        let dayKey = LedgerDisplayFingerprintPolicy.dayKey(for: now)
        return TraceSnapshotLifecycleKeyPolicy.chapterKey(
            range: range,
            ledgerRevision: homeViewModel.homeDashboardRevision,
            periodKey: "\(periodKey)|\(dayKey)",
            isMember: hasMemberAccess,
            contentRevision: chapterContentRevision
        )
    }

    private func traceLifeMarks(from items: [HomeItem], limit: Int) -> [LifeMarkAggregate] {
        let rawMarks = LifeMarkService.aggregates(
            for: items,
            allItems: homeViewModel.items,
            isMember: hasMemberAccess,
            limit: max(limit, 8)
        )
        return prioritizedTraceLifeMarks(rawMarks, items: items)
            .prefix(limit)
            .map { $0 }
    }

    private func prioritizedTraceLifeMarks(
        _ marks: [LifeMarkAggregate],
        items: [HomeItem]
    ) -> [LifeMarkAggregate] {
        guard !useCustomRange, selectedPeriod == .month, items.count >= 8 else {
            return marks
        }
        let recurringMarks = marks.filter { $0.count >= 2 && $0.kind != .milestone }
        let oneOffMarks = marks.filter { $0.count < 2 || $0.kind == .milestone }
        let ordered = recurringMarks + oneOffMarks
        return ordered.isEmpty ? marks : ordered
    }

    private func traceMarkDisplayLabel(_ mark: LifeMarkAggregate) -> String {
        switch mark.kind {
        case .scene:
            return mark.label
        case .context, .milestone, .streak:
            return mark.title
        }
    }

    @ViewBuilder
    private func traceLifeMarkPillRow(_ marks: [LifeMarkAggregate]) -> some View {
        let visibleMarks = marks.enumerated().compactMap { index, mark in
            if index == 0, mark.count >= 1 { return mark }
            if index == 1, mark.count >= 2 { return mark }
            return nil
        }
        if !visibleMarks.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(visibleMarks) { mark in
                        Text("\(traceLifeMarkIcon(for: mark)) \(traceMarkDisplayLabel(mark)) · \(mark.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.text.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.paperWarm.opacity(0.50))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(AppColors.line.opacity(0.42), lineWidth: 0.7)
                            )
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func traceChapterSummary(from items: [HomeItem], marks: [LifeMarkAggregate]) -> String? {
        guard !items.isEmpty else { return nil }
        guard let primaryMark = marks.first else { return nil }
        return LifeMarkService.primaryLine(for: primaryMark)
    }

    private func traceMarkEvidenceGroups(
        from items: [HomeItem],
        marks: [LifeMarkAggregate],
        maxItems: Int
    ) -> [TraceMarkEvidenceGroup] {
        guard maxItems > 0 else { return [] }
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        var groups: [TraceMarkEvidenceGroup] = []
        var usedItemIDs = Set<UUID>()
        var remainingSlots = maxItems

        for (index, mark) in marks.enumerated() where remainingSlots > 0 {
            if index == 1, mark.count < 2 { continue }
            let markItemIDs = Set(mark.itemIDs)
            let matchingItems = sortedItems.filter { markItemIDs.contains($0.id) }
            guard !matchingItems.isEmpty else { continue }
            let groupLimit = index == 0 ? min(2, remainingSlots) : remainingSlots
            let visibleItems = matchingItems
                .filter { !usedItemIDs.contains($0.id) }
                .prefix(groupLimit)
            guard !visibleItems.isEmpty else { continue }

            let visibleArray = Array(visibleItems)
            visibleArray.forEach { usedItemIDs.insert($0.id) }
            remainingSlots -= visibleArray.count
            groups.append(
                TraceMarkEvidenceGroup(
                    id: mark.id,
                    markLabel: traceMarkDisplayLabel(mark),
                    items: visibleArray,
                    overflowCount: max(matchingItems.count - visibleArray.count, 0)
                )
            )
        }

        if !groups.isEmpty {
            return groups
        }

        let fallbackItems = TraceRepresentative.items(from: sortedItems, maxItems: maxItems, maxPerCategory: 2)
        guard !fallbackItems.isEmpty else { return [] }
        return [
            TraceMarkEvidenceGroup(
                id: "fallback",
                markLabel: "这一段里的笔笔",
                items: fallbackItems,
                overflowCount: max(sortedItems.count - fallbackItems.count, 0)
            )
        ]
    }

    private func tracePlaybackLaunchCard(
        title: String,
        subtitle: String,
        systemImage: String,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(isEnabled ? 0.16 : 0.08))
                    .frame(width: 42, height: 42)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isEnabled ? AppColors.accent : AppColors.subtext.opacity(0.64))
                    .offset(x: systemImage == "play.fill" ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isEnabled ? AppColors.text : AppColors.subtext.opacity(0.72))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.58))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(.action, radius: 18, tint: AppColors.accent, isSelected: isEnabled, isDisabled: !isEnabled)
    }

    private func playbackLaunchSubtitle(
        range: SummaryPlaybackRange,
        preview: SummaryLaunchPreview,
        hasData: Bool,
        isMonthLocked: Bool,
        primaryMark: LifeMarkAggregate?
    ) -> String {
        if isMonthLocked {
            return "月章需要会员继续回看。"
        }
        guard hasData else {
            return "先记几笔，这里会把它们读成一段。"
        }
        let chapterCount = preview.chapterCount
        let rangeName = range == .week ? "这周" : "这个月"
        if let primaryMark {
            return "\(rangeName) \(preview.count) 笔，把「\(traceMarkDisplayLabel(primaryMark))」读成 \(chapterCount) 个章节。"
        }
        return "\(rangeName) \(preview.count) 笔，整理成 \(chapterCount) 个章节。"
    }

    private func buildSummaryLaunchPreview(
        for range: SummaryPlaybackRange,
        items: [HomeItem]
    ) -> SummaryLaunchPreview {
        let rows = items.filter { $0.amount > 0 && $0.draftMeta == nil }
        let total = rows.reduce(0) { $0 + $1.amount }
        let topCategory = Dictionary(grouping: rows, by: \.category)
            .map { (category: $0.key.rawValue, count: $0.value.count, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted {
                if $0.count == $1.count { return $0.amount > $1.amount }
                return $0.count > $1.count
            }
            .first?.category
        let chapterCount: Int
        if rows.isEmpty {
            chapterCount = 0
        } else if range == .week {
            chapterCount = rows.count >= 3 ? 4 : 3
        } else {
            chapterCount = 6
        }
        return SummaryLaunchPreview(
            count: rows.count,
            total: total,
            chapterCount: chapterCount,
            topCategory: topCategory
        )
    }

    private var traceRangeKicker: some View {
        HStack(spacing: 4) {
            traceRangeTab("本周", period: .week)
            traceRangeTab("本月", period: .month)
        }
        .padding(4)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
    }

    private var traceViewModeKicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                traceViewModeTab(.life)
                traceViewModeTab(.clues)
            }
            .frame(height: 44)

            GeometryReader { proxy in
                let tabWidth = proxy.size.width / 2
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)

                    Capsule(style: .continuous)
                        .fill(AppColors.accent.opacity(0.82))
                        .frame(width: tabWidth, height: 2)
                        .offset(x: traceViewMode == .clues ? tabWidth : 0)
                        .animation(traceEditSpring, value: traceViewMode)
                }
            }
            .frame(height: 2)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 2)
    }

    private func traceViewModeTab(_ mode: TraceViewMode) -> some View {
        let isSelected = traceViewMode == mode
        return Button {
            tabState.pendingLifeChapterScrollRange = nil
            tracePendingScrollTask?.cancel()
            tracePendingScrollTask = nil
            tabState.selectViewMode(mode)
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? TraceColors.primaryText : TraceColors.tertiaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func traceRangeTab(_ title: String, period: StatsPeriod) -> some View {
        let isSelected = !useCustomRange && selectedPeriod == period
        return Button {
            applyTraceRangePeriod(period)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? TraceColors.primaryText : TraceColors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.92) : Color.clear)
                        .shadow(color: isSelected ? AppColors.subtext.opacity(0.06) : .clear, radius: 8, x: 0, y: 3)
                )
        }
        .buttonStyle(.plain)
    }

    private func applyTraceRangePeriod(_ period: StatsPeriod) {
        guard useCustomRange || selectedPeriod != period || showTraceCustomDatePanel else {
            return
        }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            useCustomRange = false
            selectedPeriod = period
            showTraceCustomDatePanel = false
            traceInlineEditingItemID = nil
            traceSwipedItemID = nil
        }
    }

    private func traceSlipRow(_ item: HomeItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(traceAccentColor(for: item.category))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.displayTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                    Spacer()
                    Text(item.amount.formatted(.cny))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.subtext.opacity(0.92))
                }
                if shouldShowTraceSlipEmotion(for: item) {
                    Text(item.displayEmotionTag)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext.opacity(0.78))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(item.category.rawValue)
                    Text("·")
                    Text(item.createdAt.zhBillDateTime)
                }
                .font(.system(size: 12))
                .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 58)
        .traceSurface(radius: 12, padding: 0, tint: traceAccentColor(for: item.category))
    }

    private func shouldShowTraceSlipEmotion(for item: HomeItem) -> Bool {
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return false }
        return tag != HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
    }

    private func traceAccentColor(for category: HomeItem.Category) -> Color {
        AppColors.categoryColor(category).opacity(0.78)
    }

    private var traceClueMist: Color {
        AppColors.accent.opacity(0.42)
    }

    private var traceClueItems: [HomeItem] {
        heroScopedItems.filter { $0.amount > 0 && $0.draftMeta == nil }
    }

    private var traceInsightPeriodLabel: String {
        selectedPeriod == .week ? "这一周" : "这个月"
    }

    private var traceLifeInsight: LifeInsightResult {
        traceLifeInsight(from: traceClueItems)
    }

    private func traceLifeInsight(from items: [HomeItem]) -> LifeInsightResult {
        _ = clueContentRevision
        return lifeInsightService.buildTraceInsight(
            items: items,
            historyItems: homeViewModel.items,
            periodLabel: traceInsightPeriodLabel
        )
    }

    private var traceLifeInsightFreeRemaining: Int {
        return lifeInsightService.freeRemaining(isMember: hasMemberAccess)
    }

    private var traceInsightUnlockKey: String {
        traceInsightUnlockKey(from: traceClueItems)
    }

    private func traceInsightUnlockKey(from items: [HomeItem]) -> String {
        let sorted = items.sorted { $0.createdAt < $1.createdAt }
        let first = Int((sorted.first?.createdAt.timeIntervalSince1970 ?? 0).rounded())
        let last = Int((sorted.last?.createdAt.timeIntervalSince1970 ?? 0).rounded())
        let cents = Int((items.reduce(0) { $0 + $1.amount } * 100).rounded())
        return [
            selectedPeriod.rawValue,
            traceInsightPeriodLabel,
            "\(items.count)",
            "\(first)",
            "\(last)",
            "\(cents)"
        ].joined(separator: "|")
    }

    private var hasUnlockedTraceDeepInsight: Bool {
        lifeInsightService.hasUnlockedTrace(traceInsightUnlockKey, isMember: hasMemberAccess)
    }

    private var hasTraceInsightData: Bool {
        !traceClueItems.isEmpty
    }

    private var canUseTraceDeepInsight: Bool {
        hasTraceInsightData && (hasUnlockedTraceDeepInsight || traceLifeInsightFreeRemaining > 0)
    }

    private var traceCategoryClues: [TraceCategoryClue] {
        traceCategoryClues(from: traceClueItems)
    }

    private var traceLifeMarks: [LifeMarkAggregate] {
        traceLifeMarks(from: traceClueItems, limit: 6)
    }

    private func traceCategoryClues(from items: [HomeItem]) -> [TraceCategoryClue] {
        guard !items.isEmpty else { return [] }
        let totalCount = Double(items.count)
        return Dictionary(grouping: items, by: \.category)
            .map { category, groupedItems in
                TraceCategoryClue(
                    category: category,
                    count: groupedItems.count,
                    total: groupedItems.reduce(0) { $0 + $1.amount },
                    ratio: Double(groupedItems.count) / totalCount
                )
            }
            .sorted {
                if $0.count == $1.count { return $0.total > $1.total }
                return $0.count > $1.count
            }
    }

    private var traceClueHeadline: String {
        traceClueHeadline(items: traceClueItems, clues: traceCategoryClues, marks: traceLifeMarks)
    }

    private func traceClueHeadline(
        items: [HomeItem],
        clues: [TraceCategoryClue],
        marks: [LifeMarkAggregate]
    ) -> String {
        guard !items.isEmpty else { return "线索还在等第一笔记录" }
        guard let top = clues.first else {
            return "这一段的记录还比较分散"
        }
        if let mark = marks.first, mark.kind != .scene || mark.count >= 2 {
            return "\(traceNarrativePeriodPrefix)，\(mark.label)变成了一条线索"
        }
        let period = traceNarrativePeriodPrefix
        switch top.category {
        case .transport:
            return "\(period)，你主要在奔波"
        case .dining:
            return "\(period)，吃饭留下了最多痕迹"
        case .shopping:
            return "\(period)，网购添置更常出现"
        case .daily:
            return "\(period)，超市买菜和家用占了不少"
        case .health:
            return "\(period)，健康相关记录更明显"
        case .lodging:
            return "\(period)，停留和住宿更明显"
        case .entertainment:
            return "\(period)，休闲时刻更常出现"
        case .home:
            return "\(period)，家里的安排更集中"
        case .social:
            return "\(period)，人情往来更清楚"
        case .other:
            return "\(period)，有一条线索正在变清楚"
        }
    }

    private var traceClueSubline: String {
        traceClueSubline(
            items: traceClueItems,
            clues: traceCategoryClues,
            rhythmPoints: traceRhythmPoints,
            marks: traceLifeMarks
        )
    }

    private func traceClueSubline(
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint],
        marks: [LifeMarkAggregate]
    ) -> String {
        guard !items.isEmpty else { return "先记几笔，这里会按日期和分类整理。" }
        if let mark = marks.first {
            return LifeMarkService.primaryLine(for: mark)
        }
        if let top = clues.first {
            let percent = Int((top.ratio * 100).rounded())
            if let peak = rhythmPoints.max(by: { $0.count < $1.count }), peak.count >= 2 {
                return "\(top.category.rawValue)记录占 \(percent)%，\(traceRhythmNarrativeLabel(peak))是最忙的一天。"
            }
            return "\(top.category.rawValue)记录占 \(percent)%，是这一段最清楚的生活线索。"
        }
        let total = items.reduce(0) { $0 + $1.amount }
        let activeDays = traceActiveDayCount(from: items)
        return "\(items.count) 笔记录，合计 \(total.formatted(.cny))，有 \(activeDays) 天留下痕迹。"
    }

    private var traceNarrativePeriodPrefix: String {
        if useCustomRange { return "这一段" }
        switch selectedPeriod {
        case .week:
            return "这一周"
        case .month:
            return "这个月"
        case .year:
            return "这一年"
        }
    }

    private var traceHeroMetaParts: (count: String, activeDays: String, total: String)? {
        traceHeroMetaParts(items: traceClueItems)
    }

    private func traceHeroMetaParts(items: [HomeItem]) -> (count: String, activeDays: String, total: String)? {
        guard !items.isEmpty else { return nil }
        let total = items.reduce(0) { $0 + $1.amount }
        let activeDays = traceActiveDayCount(from: items)
        return ("\(items.count) 笔", "\(activeDays) 天有痕迹", "合计 \(total.formatted(.cny))")
    }

    private var tracePrimaryEvidence: String {
        tracePrimaryEvidence(clues: traceCategoryClues)
    }

    private func tracePrimaryEvidence(clues: [TraceCategoryClue]) -> String {
        if let top = clues.first {
            return "\(top.category.rawValue) \(top.count) 笔"
        }
        return "暂无分类线索"
    }

    private var traceSecondaryEvidence: String {
        traceSecondaryEvidence(items: traceClueItems)
    }

    private func traceSecondaryEvidence(items: [HomeItem]) -> String {
        let activeDays = traceActiveDayCount(from: items)
        return "\(activeDays) 天有记录"
    }

    private var traceTertiaryEvidence: String {
        traceTertiaryEvidence(rhythmPoints: traceRhythmPoints)
    }

    private func traceTertiaryEvidence(rhythmPoints: [TraceRhythmPoint]) -> String {
        guard let peak = rhythmPoints.max(by: { $0.count < $1.count }), peak.count > 0 else {
            return "节奏未形成"
        }
        return "\(traceRhythmNarrativeLabel(peak))最集中"
    }

    private var traceRhythmSummary: String {
        traceRhythmSummary(rhythmPoints: traceRhythmPoints)
    }

    private func traceRhythmSummary(rhythmPoints: [TraceRhythmPoint]) -> String {
        let active = rhythmPoints.filter { $0.count > 0 }.count
        guard active > 0 else { return "还在形成" }
        return selectedPeriod == .week ? "\(active) 天有记录" : "\(active) 周有记录"
    }

    private var traceRhythmPoints: [TraceRhythmPoint] {
        traceRhythmPoints(from: traceClueItems)
    }

    private func traceRhythmPoints(from items: [HomeItem]) -> [TraceRhythmPoint] {
        guard !items.isEmpty else { return [] }
        let calendar = Calendar.current
        if selectedPeriod == .month, let interval = calendar.dateInterval(of: .month, for: Date()) {
            let today = Date()
            let end = min(interval.end, today)
            let labels = ["第1周", "第2周", "第3周", "第4周", "末段"]
            return labels.indices.compactMap { index in
                guard let start = calendar.date(byAdding: .day, value: index * 7, to: interval.start) else { return nil }
                let rawEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                let pointEnd = min(rawEnd, end)
                guard start < pointEnd else { return nil }
                let count = items.filter { $0.createdAt >= start && $0.createdAt < pointEnd }.count
                return TraceRhythmPoint(
                    label: labels[index],
                    count: count,
                    isToday: today >= start && today < pointEnd
                )
            }
        }

        guard let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return labels.indices.compactMap { index in
            guard let day = Calendar.current.date(byAdding: .day, value: index, to: interval.start),
                  let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) else { return nil }
            let count = items.filter { $0.createdAt >= day && $0.createdAt < nextDay }.count
            return TraceRhythmPoint(
                label: labels[index],
                count: count,
                isToday: Calendar.current.isDateInToday(day)
            )
        }
    }

    private func traceActiveDayCount(from items: [HomeItem]) -> Int {
        let calendar = Calendar.current
        return Set(items.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    private func traceClueColor(for category: HomeItem.Category) -> Color {
        AppColors.categoryColor(category)
    }

    private var traceEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✦")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.accent.opacity(0.7))
            Text(emptyRecordListText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.32))
        )
    }

    private var traceAppendixStrip: some View {
        Button {
            openTraceDetail()
        } label: {
            HStack(spacing: 7) {
                Text("细查这一段")
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .foregroundStyle(TraceColors.tertiaryText)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func traceClueBoard(snapshot: TraceClueSnapshot) -> some View {
        VStack(spacing: 16) {
            traceClueHeroCard(
                items: snapshot.items,
                clues: snapshot.clues,
                rhythmPoints: snapshot.rhythmPoints,
                marks: snapshot.marks,
                narrativeHeadline: snapshot.narrativeHeadline,
                narrativeSummary: snapshot.narrativeSummary,
                photoEvidenceItem: snapshot.photoEvidenceItem
            )
            traceClueCompositionCard(items: snapshot.items, clues: snapshot.clues)
            traceLifeMarkCard(marks: snapshot.marks, lockedPreview: snapshot.lockedMark)
            traceDeepInsightCard(
                insight: snapshot.insight,
                items: snapshot.items,
                clues: snapshot.clues,
                rhythmPoints: snapshot.rhythmPoints,
                isUnlocked: snapshot.isDeepInsightUnlocked,
                canUseDeepInsight: snapshot.canUseDeepInsight,
                freeRemaining: snapshot.freeInsightRemaining
            )
            traceAppendixStrip
        }
    }

    private func buildTraceClueSnapshot() -> TraceClueSnapshot {
        let items = traceClueItems
        let cacheKey = traceClueSnapshotCacheKey(items: items)
        if let cached = traceSnapshotStore.clueSnapshot(for: cacheKey) {
            return cached
        }

        let unlockKey = traceInsightUnlockKey(from: items)
        let freeRemaining = lifeInsightService.freeRemaining(isMember: hasMemberAccess)
        let storedUnlock = lifeInsightService.hasUnlockedTrace(unlockKey, isMember: hasMemberAccess)
        let narrativeScope: LifeNarrativeScope? = useCustomRange
            ? nil
            : (selectedPeriod == .week ? .week : (selectedPeriod == .month ? .month : nil))
        let snapshot = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: items,
                allItems: homeViewModel.items,
                period: selectedPeriod,
                periodLabel: traceInsightPeriodLabel,
                isMember: hasMemberAccess,
                freeRemaining: freeRemaining,
                storedUnlock: storedUnlock,
                sourceRevision: homeViewModel.homeDashboardRevision,
                narrativeScope: narrativeScope,
                allowsNarrativeRewrite: narrativeScope != nil,
                now: Date()
            )
        )
        traceSnapshotStore.storeClueSnapshot(snapshot, for: cacheKey)
        return snapshot
    }

    private func traceClueSnapshotCacheKey(items: [HomeItem]) -> String {
        let unlockKey = traceInsightUnlockKey(from: items)
        return TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: selectedPeriod,
            ledgerRevision: homeViewModel.homeDashboardRevision,
            isMember: hasMemberAccess,
            usesCustomRange: useCustomRange,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            category: selectedCategory,
            freeRemaining: lifeInsightService.freeRemaining(isMember: hasMemberAccess),
            isUnlocked: lifeInsightService.hasUnlockedTrace(unlockKey, isMember: hasMemberAccess),
            dayKey: LedgerDisplayFingerprintPolicy.dayKey(for: Date()),
            contentRevision: clueContentRevision
        )
    }

    private func traceClueHeroCard(
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint],
        marks: [LifeMarkAggregate],
        narrativeHeadline: String?,
        narrativeSummary: String?,
        photoEvidenceItem: HomeItem?
    ) -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            traceRangeKicker

            VStack(alignment: .leading, spacing: 8) {
                Text(narrativeHeadline ?? traceClueHeadline(items: items, clues: clues, marks: marks))
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(TraceColors.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(narrativeSummary ?? traceClueSubline(items: items, clues: clues, rhythmPoints: rhythmPoints, marks: marks))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TraceColors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let photoEvidenceItem {
                    traceCluePhotoEvidence(item: photoEvidenceItem)
                        .padding(.top, 3)
                }

                if let meta = traceHeroMetaParts(items: items) {
                    HStack(spacing: 6) {
                        Text(meta.count)
                        Text("·")
                        Text(meta.activeDays)
                        Text("·")
                        Text(meta.total)
                    }
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(TraceColors.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
            }

            HStack(spacing: 8) {
                traceClueEvidenceChip(tracePrimaryEvidence(clues: clues), isPrimary: true)
                traceClueEvidenceChip(traceSecondaryEvidence(items: items))
                traceClueEvidenceChip(traceTertiaryEvidence(rhythmPoints: rhythmPoints))
            }

            if items.isEmpty {
                Text("先记几笔，这里会按日期和分类整理。")
                    .font(.system(size: 13))
                    .foregroundStyle(TraceColors.secondaryText)
                    .padding(.top, 2)
            }
        }
        .traceWarmPanel(radius: 26, padding: 24)
    }

    private func traceClueCompositionCard(items: [HomeItem], clues: [TraceCategoryClue]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("生活构成")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TraceColors.primaryText)
                Spacer()
                Text("\(items.count) 笔")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
            }

            if clues.isEmpty {
                traceQuietCluePlaceholder("还没有足够记录形成构成。")
            } else {
                traceCompositionRibbon(clues: clues)
                VStack(spacing: 8) {
                    ForEach(Array(clues.prefix(4))) { clue in
                        traceCategoryClueRow(clue, topCategory: clues.first?.category)
                    }
                }
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private func traceCompositionRibbon(clues: [TraceCategoryClue]) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 3) {
                ForEach(Array(clues.prefix(4))) { clue in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(traceClueColor(for: clue.category).opacity(0.65))
                        .frame(width: max(10, width * clue.ratio))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule(style: .continuous))
        .background(
            Capsule(style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
    }

    private func traceLifeMarkCard(
        marks: [LifeMarkAggregate],
        lockedPreview: LifeMarkAggregate?
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center) {
                Text("生活线索")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TraceColors.primaryText)
                Spacer()
                Text(hasMemberAccess ? "场景资产" : "基础可看")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
            }

            if marks.isEmpty {
                traceQuietCluePlaceholder("多留下几笔，运动、补给、旅行、家账这些印记会自然出现。")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(marks.prefix(4))) { mark in
                        traceLifeMarkRow(mark)
                    }
                }
            }

            if let lockedPreview {
                Button {
                    onShowMemberPricing?(.traceDeepInsight)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.lockGold)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(AppColors.lockGold.opacity(0.12))
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("解锁更深的生活记忆")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TraceColors.primaryText)
                            Text("雨天通勤、第一次、第 10 次、连续记录、异地城市，会按账本里已有的日期、分类、备注和上下文线索整理。")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(TraceColors.tertiaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.lockGold.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private func traceLifeMarkRow(_ mark: LifeMarkAggregate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(traceLifeMarkIcon(for: mark))
                .font(.system(size: 15))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(traceClueColor(for: mark.category).opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mark.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TraceColors.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if mark.access == .member {
                        Text("会员")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppColors.lockGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(AppColors.lockGold.opacity(0.10))
                            )
                    }
                }
                Text(mark.detail)
                    .font(.system(size: 12, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(TraceColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(mark.count) 次")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TraceColors.primaryText)
                Text(mark.total.formatted(.cny))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TraceColors.stroke, lineWidth: 1)
        )
    }

    private func traceLifeMarkIcon(for mark: LifeMarkAggregate) -> String {
        let semanticText = "\(mark.id) \(mark.label) \(mark.title) \(mark.detail)"
        if mark.id == "medical_care" {
            if traceContainsAny(semanticText, ["医院", "门诊", "挂号", "问诊", "体检", "检查", "拍片", "验血"]) {
                return "🏥"
            }
            if traceContainsAny(semanticText, ["护理", "理疗", "康复", "创可贴", "牙科", "口腔"]) {
                return "🩹"
            }
            return "💊"
        }
        if mark.id == "fitness" {
            return "🏋️"
        }
        if traceContainsAny(semanticText, ["看病", "买药", "医院", "门诊", "挂号", "问诊", "体检", "检查", "药"]) {
            return traceContainsAny(semanticText, ["医院", "门诊", "挂号", "问诊", "体检", "检查"]) ? "🏥" : "💊"
        }
        if traceContainsAny(semanticText, ["健身", "运动", "跑步", "瑜伽", "普拉提", "游泳", "训练"]) {
            return "🏋️"
        }
        switch mark.category {
        case .transport:
            return mark.id.contains("rain") ? "🌧️" : "🚇"
        case .dining:
            return "🍵"
        case .daily:
            return mark.id.contains("baby") ? "🍼" : "🧺"
        case .health:
            return "🏃"
        case .home:
            return "🏠"
        case .entertainment:
            return "🎡"
        case .lodging:
            return "🏨"
        case .social:
            return "👥"
        case .shopping:
            return "🛍️"
        case .other:
            return "✦"
        }
    }

    private func traceDeepInsightCard(
        insight: LifeInsightResult,
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint],
        isUnlocked snapshotUnlocked: Bool,
        canUseDeepInsight snapshotCanUse: Bool,
        freeRemaining: Int
    ) -> some View {
        let isUnlocked = snapshotUnlocked || traceDeepInsightExpanded
        let supportingLines = traceDeepInsightSupportingLines(insight)
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(traceInsightThemeColor(insight.theme).opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: traceInsightThemeIcon(insight.theme))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(traceInsightThemeColor(insight.theme).opacity(0.88))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(traceInsightThemeTitle(insight.theme))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(TraceColors.primaryText)
                    Text(isUnlocked ? insight.periodName : "本月还可展开 \(freeRemaining)/\(LifeInsightService.freeMonthlyLimit) 次")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TraceColors.tertiaryText)
                }

                Spacer()
            }

            Text(insight.leadQuestion)
                .font(.title3.weight(.bold))
                .foregroundStyle(TraceColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(isUnlocked ? insight.previewLine : insight.teaser)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(TraceColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if isUnlocked {
                Divider()
                    .overlay(TraceColors.surfaceMuted)
                    .padding(.top, 2)

                traceInsightRhythmOverview(insight: insight, rhythmPoints: rhythmPoints)

                if !supportingLines.isEmpty {
                    Text("为什么这样说")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TraceColors.tertiaryText)

                    VStack(spacing: 8) {
                        ForEach(Array(supportingLines.enumerated()), id: \.offset) { index, line in
                            traceDeepInsightLine(line, index: index)
                        }
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }

                Text("继续问")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TraceColors.tertiaryText)
                traceContinueInReviewButton
                    .transition(.opacity)
            }

            if !isUnlocked {
                Button {
                    handleTraceDeepInsightTap()
                } label: {
                    let buttonIsOpen = snapshotCanUse
                    if buttonIsOpen {
                        HStack(spacing: 8) {
                            Text(traceDeepInsightButtonTitle(canUse: snapshotCanUse, hasData: !items.isEmpty))
                                .font(.headline.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .background(traceDeepCTAButtonBackground(isOpen: true))
                    } else {
                        HStack(spacing: 7) {
                            Text(traceDeepInsightButtonTitle(canUse: snapshotCanUse, hasData: !items.isEmpty))
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(AppColors.lockGold)
                        .padding(.horizontal, 12)
                        .background(traceDeepCTAButtonBackground(isOpen: false))
                    }
                }
                .buttonStyle(.plain)
                .disabled(items.isEmpty)
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private func traceCluePhotoEvidence(item: HomeItem) -> some View {
        HStack(spacing: 10) {
            MemoryAttachmentThumbnail(
                imageData: item.coverMemoryImageData,
                imageReference: item.coverMemoryImageReference,
                height: 58,
                cornerRadius: 11
            )
            .frame(width: 72)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TraceColors.primaryText)
                    .lineLimit(1)
                Text("\(item.createdAt.zhBillDateTime) · \(item.category.rawValue)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(item.amount.formatted(.cny))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(TraceColors.primaryText)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(TraceColors.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("照片对应记录，\(item.displayTitle)，\(item.amount.formatted(.cny))，\(item.createdAt.zhBillDateTime)")
    }

    private var traceLifeRangeKicker: some View {
        HStack(spacing: 4) {
            traceLifeRangeTab("本周", range: .week)
            traceLifeRangeTab("本月", range: .month)
        }
        .padding(4)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
        .padding(.horizontal, 18)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("痕迹时间范围")
    }

    private func traceLifeRangeTab(_ title: String, range: SummaryPlaybackRange) -> some View {
        let isSelected = traceLifeCardRange == range
        return Button {
            setTraceLifeCardRange(range)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? TraceColors.primaryText : TraceColors.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.92) : Color.clear)
                        .shadow(color: isSelected ? AppColors.subtext.opacity(0.06) : .clear, radius: 8, x: 0, y: 3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "已选中" : "")
    }

    private func traceInsightThemeTitle(_ theme: LifeInsightTheme) -> String {
        switch theme {
        case .forming: return "线索还在形成"
        case .steady: return "这段日子很平稳"
        case .change: return "有一处变化"
        case .effort: return "你付出的这些时间"
        case .day: return "被记完整的一天"
        case .memory: return "一条具体记录"
        case .relation: return "两条生活线"
        }
    }

    private func traceInsightThemeIcon(_ theme: LifeInsightTheme) -> String {
        switch theme {
        case .forming: return "ellipsis"
        case .steady: return "water.waves"
        case .change: return "waveform.path.ecg"
        case .effort: return "sunrise.fill"
        case .day: return "calendar"
        case .memory: return "photo.fill"
        case .relation: return "link"
        }
    }

    private func traceInsightThemeColor(_ theme: LifeInsightTheme) -> Color {
        switch theme {
        case .forming: return AppColors.subtext
        case .steady: return AppColors.accent.opacity(0.72)
        case .change: return AppColors.accentDark
        case .effort: return Color(hex: "c08a4b")
        case .day: return Color(hex: "7d8fa6")
        case .memory: return Color(hex: "9b7bb8")
        case .relation: return Color(hex: "5d8fa3")
        }
    }

    @ViewBuilder
    private func traceInsightRhythmOverview(
        insight: LifeInsightResult,
        rhythmPoints: [TraceRhythmPoint]
    ) -> some View {
        if !rhythmPoints.isEmpty {
            let maxCount = max(rhythmPoints.map(\.count).max() ?? 1, 1)
            let highlightedIndex = traceInsightHighlightedRhythmIndex(insight: insight, pointCount: rhythmPoints.count)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedPeriod == .week ? "这一周的节奏" : "这个月的节奏")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TraceColors.primaryText)
                    Spacer()
                    Text(traceRhythmSummary(rhythmPoints: rhythmPoints))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(TraceColors.tertiaryText)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(rhythmPoints.enumerated()), id: \.offset) { index, point in
                        traceInsightRhythmColumn(
                            point,
                            maxCount: maxCount,
                            isHighlighted: highlightedIndex == index,
                            tint: traceInsightThemeColor(insight.theme)
                        )
                    }
                }
                .frame(height: 112)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(selectedPeriod == .week ? "这一周" : "这个月")的节奏，\(traceRhythmSummary(rhythmPoints: rhythmPoints))")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TraceColors.surfaceMuted.opacity(0.72))
            )
        }
    }

    private func traceInsightRhythmColumn(
        _ point: TraceRhythmPoint,
        maxCount: Int,
        isHighlighted: Bool,
        tint: Color
    ) -> some View {
        let ratio = CGFloat(point.count) / CGFloat(maxCount)
        let barHeight = max(8, 70 * ratio)
        return VStack(spacing: 7) {
            Spacer(minLength: 0)
            Text(point.count > 0 ? "\(point.count)" : "")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(isHighlighted ? tint : TraceColors.tertiaryText)
                .frame(height: 11)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(
                    point.count > 0
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    tint.opacity(isHighlighted ? 0.90 : 0.56),
                                    AppColors.accent.opacity(isHighlighted ? 0.32 : 0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.52))
                )
                .frame(width: isHighlighted ? 20 : 16, height: barHeight)

            Text(point.label)
                .font(.system(size: 10, weight: isHighlighted ? .semibold : .medium))
                .foregroundStyle(isHighlighted ? tint : TraceColors.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func traceInsightHighlightedRhythmIndex(insight: LifeInsightResult, pointCount: Int) -> Int? {
        guard let date = insight.highlightedDate, pointCount > 0 else { return nil }
        if selectedPeriod == .month {
            let day = Calendar.current.component(.day, from: date)
            return min(max((day - 1) / 7, 0), pointCount - 1)
        }
        let weekday = Calendar.current.component(.weekday, from: date)
        return min(max((weekday + 5) % 7, 0), pointCount - 1)
    }

    private func traceDeepInsightSupportingLines(_ insight: LifeInsightResult) -> [String] {
        var seen = Set<String>()
        seen.insert(insight.previewLine.trimmingCharacters(in: .whitespacesAndNewlines))
        return insight.fullLines.compactMap { line in
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return line
        }
        .prefix(2)
        .map { $0 }
    }

    private func traceDeepInsightLine(_ text: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: index == 0 ? "quote.opening" : "circle.fill")
                .font(.system(size: index == 0 ? 10 : 5, weight: .semibold))
                .foregroundStyle(index == 0 ? AppColors.accentDark : TraceColors.tertiaryText)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(index == 0 ? AppColors.accent.opacity(0.10) : TraceColors.surfaceMuted)
                )
            Text(text)
                .font(.subheadline.weight(.medium))
                .lineSpacing(3)
                .foregroundStyle(TraceColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
    }

    private func traceInsightQuestionChips(_ chips: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        handleTraceInsightQuestionTap(chip)
                    } label: {
                        Text(chip)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(traceInsightFocusedQuestion == chip ? AppColors.accentDark : TraceColors.secondaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(traceInsightFocusedQuestion == chip ? AppColors.accent.opacity(0.12) : TraceColors.surfaceMuted)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(
                                        traceInsightFocusedQuestion == chip ? AppColors.accent.opacity(0.20) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func traceFocusedInsightAnswer(
        question: String,
        insight: LifeInsightResult,
        items: [HomeItem],
        clues: [TraceCategoryClue]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TraceColors.primaryText)
                .lineLimit(2)

            Text(traceInsightAnswer(for: question, insight: insight, items: items, clues: clues))
                .font(.system(size: 13, weight: .medium))
                .lineSpacing(3)
                .foregroundStyle(TraceColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TraceColors.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TraceColors.stroke, lineWidth: 1)
        )
    }

    private func traceDeepCTAButtonBackground(isOpen: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isOpen ? AppColors.accent : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOpen ? Color.clear : AppColors.lockGold.opacity(0.34), lineWidth: 1)
            )
    }

    private func traceDeepInsightButtonTitle(canUse: Bool, hasData: Bool) -> String {
        if !hasData { return "先留下几笔" }
        if canUse { return "展开这条线索" }
        return "解锁完整解读"
    }

    private var traceContinueInReviewButton: some View {
        Button {
            onOpenInsight?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("去复盘查账、对比或继续问")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(AppColors.accentDark)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.accent.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("打开复盘页继续提问")
    }

    private func handleTraceDeepInsightTap() {
        guard hasTraceInsightData else { return }
        if hasUnlockedTraceDeepInsight {
            withAnimation(traceEditSpring) {
                traceDeepInsightExpanded = true
                focusNextTraceInsightQuestion()
                clueContentRevision &+= 1
            }
            return
        }

        if traceDeepInsightExpanded {
            withAnimation(traceEditSpring) {
                focusNextTraceInsightQuestion()
            }
            return
        }

        guard canUseTraceDeepInsight else {
            onShowMemberPricing?(.traceDeepInsight)
            return
        }

        lifeInsightService.markDeepInsightUsed(isMember: false)
        lifeInsightService.markTraceUnlocked(traceInsightUnlockKey, isMember: false)
        withAnimation(traceEditSpring) {
            traceDeepInsightExpanded = true
            focusNextTraceInsightQuestion()
            clueContentRevision &+= 1
        }
    }

    private func handleTraceInsightQuestionTap(_ question: String) {
        guard hasTraceInsightData else { return }
        if hasUnlockedTraceDeepInsight || traceDeepInsightExpanded {
            withAnimation(traceEditSpring) {
                traceInsightFocusedQuestion = question
            }
            return
        }

        guard canUseTraceDeepInsight else {
            onShowMemberPricing?(.traceDeepInsight)
            return
        }

        lifeInsightService.markDeepInsightUsed(isMember: false)
        lifeInsightService.markTraceUnlocked(traceInsightUnlockKey, isMember: false)
        withAnimation(traceEditSpring) {
            traceDeepInsightExpanded = true
            traceInsightFocusedQuestion = question
            clueContentRevision &+= 1
        }
    }

    private func focusNextTraceInsightQuestion() {
        let chips = traceLifeInsight.questionChips
        guard !chips.isEmpty else { return }
        guard let current = traceInsightFocusedQuestion,
              let index = chips.firstIndex(of: current) else {
            traceInsightFocusedQuestion = chips[0]
            return
        }
        traceInsightFocusedQuestion = chips[(index + 1) % chips.count]
    }

    private func traceInsightAnswer(
        for question: String,
        insight: LifeInsightResult,
        items: [HomeItem],
        clues: [TraceCategoryClue]
    ) -> String {
        if question.contains("早晨") {
            let earlyItems = items.filter {
                let hour = Calendar.current.component(.hour, from: $0.createdAt)
                return (5..<9).contains(hour)
            }
            let days = Set(earlyItems.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
            guard days > 0 else { return insight.previewLine }
            return "有 \(days) 天在 9 点前留下记录。这里想保留的不是早起次数，而是你在那些早晨已经开始处理出行、饭点或一天的准备。"
        }

        if question.contains("晚一些") || question.contains("晚归") {
            let lateItems = items.filter {
                let hour = Calendar.current.component(.hour, from: $0.createdAt)
                return hour >= 21 || hour < 3
            }
            let days = Set(lateItems.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
            guard days > 0 else { return insight.previewLine }
            return "有 \(days) 天在 21 点后仍有记录。它们可能是晚归、晚些吃饭或临时安排，不需要被评价，只适合被记住。"
        }

        if question.contains("这笔记录") {
            if let item = traceSpecificInsightRecord(items: items, highlightedDate: insight.highlightedDate) {
                return "\(traceCalendarDayNarrativeLabel(item.createdAt)) \(item.createdAt.zhBillTime)，你写下了「\(item.displayTitle)」，金额是 \(item.amount.formatted(.cny))。这条具体备注本身，就是它和普通分类最不同的地方。"
            }
            return insight.previewLine
        }

        if question.contains("照片") || question.contains("现场") {
            if let item = tracePhotoInsightRecord(
                items: items,
                highlightedItemID: insight.highlightedItemID,
                highlightedDate: insight.highlightedDate
            ) {
                let photoCount = item.memoryImageCount
                let countText = photoCount > 1 ? "\(photoCount) 张照片" : "一张照片"
                return "对应的是\(traceCalendarDayNarrativeLabel(item.createdAt)) \(item.createdAt.zhBillTime)的「\(item.displayTitle)」，金额为 \(item.amount.formatted(.cny))，附有\(countText)。"
            }
            return insight.previewLine
        }

        if question.hasPrefix("回到"), let highlightedDate = insight.highlightedDate {
            let dayItems = items
                .filter { Calendar.current.isDate($0.createdAt, inSameDayAs: highlightedDate) }
                .sorted { $0.createdAt < $1.createdAt }
            if !dayItems.isEmpty {
                let timeline = dayItems.prefix(4).map { "\($0.createdAt.zhBillTime) \($0.displayTitle)" }
                let remaining = max(dayItems.count - timeline.count, 0)
                let tail = remaining > 0 ? "，另有 \(remaining) 笔" : ""
                return "\(traceCalendarDayNarrativeLabel(highlightedDate))共留下 \(dayItems.count) 笔：\(timeline.joined(separator: "、"))\(tail)。按时间读，比只看其中一笔更接近那天的安排。"
            }
            return insight.previewLine
        }

        if question.contains("哪天") || question.contains("不太像") || question.contains("更密") || question.contains("发生了什么") {
            if let peakDay = tracePeakCalendarDay(from: items) {
                return "\(traceCalendarDayNarrativeLabel(peakDay.date))留下 \(peakDay.count) 笔，是这一段最集中的一天。先回头看那天去了哪里、见了谁，很多原因会比金额本身更清楚。"
            }
            return "这一段还没有特别突出的日子。再多几笔之后，哪天不太一样会更容易看出来。"
        }

        if question.contains("有关吗") || question.contains("一起") || question.contains("同一段事") || question.contains("同天") {
            let topClues = Array(clues.prefix(2))
            if topClues.count == 2 {
                let first = topClues[0]
                let second = topClues[1]
                let overlapDays = traceDaysContaining(categories: [first.category, second.category], items: items)
                if overlapDays > 0 {
                    return "\(first.category.rawValue)和\(second.category.rawValue)在 \(overlapDays) 天里同时出现。可以先把它们放到同一天的外出、工作节奏或集中补给里一起看。"
                }
                return "\(first.category.rawValue)和\(second.category.rawValue)都靠前，但不太落在同一天。可以分开看这两类记录。"
            }
            return insight.previewLine
        }

        if question.contains("重复") || question.contains("习惯") || question.contains("好几次") {
            if let top = clues.first {
                return "\(top.category.rawValue)出现 \(top.count) 笔，是这一段最稳定的重复项。"
            }
            return "现在重复还不明显。等同类记录连续出现，这里会更容易看出习惯。"
        }

        if question.contains("名字") {
            return insight.periodName
        }

        return insight.previewLine
    }

    private func tracePhotoInsightRecord(
        items: [HomeItem],
        highlightedItemID: UUID?,
        highlightedDate: Date?
    ) -> HomeItem? {
        if let highlightedItemID,
           let exact = items.first(where: { $0.id == highlightedItemID && $0.hasMemoryImages }) {
            return exact
        }
        return items
            .filter { $0.hasMemoryImages }
            .sorted { lhs, rhs in
                let leftHighlighted = highlightedDate.map { Calendar.current.isDate(lhs.createdAt, inSameDayAs: $0) } ?? false
                let rightHighlighted = highlightedDate.map { Calendar.current.isDate(rhs.createdAt, inSameDayAs: $0) } ?? false
                if leftHighlighted != rightHighlighted { return leftHighlighted }
                if lhs.memoryImageCount != rhs.memoryImageCount {
                    return lhs.memoryImageCount > rhs.memoryImageCount
                }
                return lhs.createdAt > rhs.createdAt
            }
            .first
    }

    private func traceSpecificInsightRecord(items: [HomeItem], highlightedDate: Date?) -> HomeItem? {
        items
            .filter { item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return item.userEditedTitle == true
                    && !title.isEmpty
                    && title != item.category.defaultRecordTitle
                    && !RecordSemanticLexicon.isSystemGeneratedTitle(title)
            }
            .sorted { lhs, rhs in
                let leftHighlighted = highlightedDate.map { Calendar.current.isDate(lhs.createdAt, inSameDayAs: $0) } ?? false
                let rightHighlighted = highlightedDate.map { Calendar.current.isDate(rhs.createdAt, inSameDayAs: $0) } ?? false
                if leftHighlighted != rightHighlighted { return leftHighlighted }
                if lhs.title.count != rhs.title.count { return lhs.title.count > rhs.title.count }
                return lhs.createdAt > rhs.createdAt
            }
            .first
    }

    private func traceContainsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func traceDaysContaining(categories: [HomeItem.Category], items: [HomeItem]) -> Int {
        guard !categories.isEmpty else { return 0 }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        return grouped.values.filter { dayItems in
            let dayCategories = Set(dayItems.map(\.category))
            return categories.allSatisfy { dayCategories.contains($0) }
        }.count
    }

    private func traceRhythmNarrativeLabel(_ point: TraceRhythmPoint) -> String {
        if selectedPeriod == .week, point.label.count == 1 {
            return "周\(point.label)"
        }
        return point.label
    }

    private var traceRhythmPeriodReference: String {
        selectedPeriod == .week ? "那天" : "那一周"
    }

    private func tracePeakCalendarDay(from items: [HomeItem]) -> (date: Date, count: Int)? {
        guard !items.isEmpty else { return nil }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        guard let peak = grouped.max(by: { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.key < rhs.key
            }
            return lhs.value.count < rhs.value.count
        }) else { return nil }
        return (peak.key, peak.value.count)
    }

    private func traceCalendarDayNarrativeLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if selectedPeriod == .week {
            return weekdayText(for: date)
        }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日（\(weekdayText(for: date))）"
    }

    private func traceClueEvidenceChip(_ text: String, isPrimary: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12, weight: isPrimary ? .semibold : .medium))
            .foregroundStyle(isPrimary ? TraceColors.primaryText : TraceColors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(isPrimary ? AppColors.accent.opacity(0.12) : TraceColors.surfaceMuted)
            )
    }

    private func traceCategoryClueRow(_ clue: TraceCategoryClue, topCategory: HomeItem.Category?) -> some View {
        let isTop = topCategory == clue.category
        return HStack(spacing: 9) {
            Circle()
                .fill(traceClueColor(for: clue.category).opacity(0.82))
                .frame(width: 7, height: 7)
            Text(clue.category.rawValue)
                .font(.system(size: 13, weight: isTop ? .semibold : .regular))
                .foregroundStyle(TraceColors.secondaryText)
            Spacer()
            Text("\(clue.count) 笔")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TraceColors.tertiaryText)
            Text("\(Int((clue.ratio * 100).rounded()))%")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(TraceColors.tertiaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func traceQuietCluePlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppColors.subtext)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.32))
            )
    }

    private func openTraceDetail() {
        traceInlineEditingItemID = nil
        let candidate = TraceDetailPresentationPayload(initialSnapshot: prepareTraceDetailListSnapshot())
        guard TraceDetailPresentationPolicy.accepts(candidate, while: traceDetailPresentation) else { return }
        traceDetailPresentation = candidate
    }

    private func openTraceDetail(for range: SummaryPlaybackRange) {
        useCustomRange = false
        traceLifeCardRange = range
        selectedPeriod = TraceRangeContextPolicy.period(for: range)
        selectedCategory = nil
        traceInlineEditingItemID = nil
        traceSwipedItemID = nil
        let candidate = TraceDetailPresentationPayload(initialSnapshot: prepareTraceDetailListSnapshot())
        guard TraceDetailPresentationPolicy.accepts(candidate, while: traceDetailPresentation) else { return }
        traceDetailPresentation = candidate
    }

    private func handleOpenTraceRequestIfNeeded() {
        guard let openTraceRequestID,
              handledOpenTraceRequestID != openTraceRequestID
        else { return }
        handledOpenTraceRequestID = openTraceRequestID
        useCustomRange = false
        selectedPeriod = .week
        traceLifeCardRange = .week
        selectedCategory = nil
        withAnimation(traceEditSpring) {
            traceViewMode = .life
        }
        tabState.pendingLifeChapterScrollRange = .week
    }

    private func schedulePendingTraceScrollIfPossible() {
        let targetAnchorID = TraceDeferredScrollPolicy.lifeChapterAnchorID
        guard let pendingRange = tabState.pendingLifeChapterScrollRange,
              traceViewMode == .life,
              traceLifeCardRange == pendingRange,
              selectedPeriod == TraceRangeContextPolicy.period(for: pendingRange),
              !useCustomRange,
              preparedLifeSnapshot(for: pendingRange) != nil else { return }
        tracePendingScrollTask?.cancel()
        tracePendingScrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled,
                  tabState.pendingLifeChapterScrollRange == pendingRange,
                  traceViewMode == .life,
                  traceLifeCardRange == pendingRange,
                  selectedPeriod == TraceRangeContextPolicy.period(for: pendingRange),
                  !useCustomRange,
                  preparedLifeSnapshot(for: pendingRange) != nil else { return }
            if TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: tabState.scrollAnchorID,
                targetAnchorID: targetAnchorID
            ) {
                var resetTransaction = Transaction(animation: nil)
                resetTransaction.disablesAnimations = true
                withTransaction(resetTransaction) {
                    tabState.scrollAnchorID = nil
                }
                await Task.yield()
                guard !Task.isCancelled,
                      tabState.pendingLifeChapterScrollRange == pendingRange,
                      traceViewMode == .life,
                      traceLifeCardRange == pendingRange,
                      selectedPeriod == TraceRangeContextPolicy.period(for: pendingRange),
                      !useCustomRange,
                      preparedLifeSnapshot(for: pendingRange) != nil else { return }
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                tabState.pendingLifeChapterScrollRange = nil
                tabState.scrollAnchorID = targetAnchorID
            }
            tracePendingScrollTask = nil
        }
    }

    private func resolvedTraceDetailSnapshot(
        initialSnapshot: TraceDetailListSnapshot
    ) -> TraceDetailListSnapshot {
        if let traceDetailListSnapshot,
           traceDetailListSnapshot.key == traceDetailListSnapshotKey {
            return traceDetailListSnapshot
        }
        return initialSnapshot
    }

    private func traceDetailSheet(initialSnapshot: TraceDetailListSnapshot) -> some View {
        let snapshot = resolvedTraceDetailSnapshot(initialSnapshot: initialSnapshot)
        return NavigationStack {
            ZStack {
                AppColors.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("细查这一段")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)

                        Text(traceDetailMetaText(snapshot: snapshot))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                tracePeriodFilter
                                traceCategoryFilter
                            }

                            if showTraceCustomDatePanel {
                                traceCustomDatePanel
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        traceDetailFocusedList(snapshot: snapshot)
                        }
                        .padding(18)
                        .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(traceSwipeDragState != nil || traceInlineEditingItemID != nil)
                .onChange(of: snapshot.itemIDs) { _, itemIDs in
                    guard let editingID = traceInlineEditingItemID,
                          !itemIDs.contains(editingID)
                    else { return }
                    withAnimation(traceEditSpring) {
                        traceInlineEditingItemID = nil
                        traceSwipedItemID = nil
                    }
                }

                traceDetailEditorOverlay
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { traceDetailPresentation = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .confirmationDialog(
            "删除这条账单？",
            isPresented: $showTraceDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let tracePendingDeleteItem {
                    deleteRecord(tracePendingDeleteItem)
                }
                tracePendingDeleteItem = nil
            }
            Button("取消", role: .cancel) {
                tracePendingDeleteItem = nil
            }
        } message: {
            Text("删除后不会保留在账本里。")
        }
        .onDisappear {
            tracePendingDeleteItem = nil
        }
    }

    private var traceDetailEditorOverlay: some View {
        VStack(spacing: 0) {
            if let item = traceInlineEditingItem {
                traceFocusedRecordEditorCard(item)
                    .padding(.horizontal, 26)
                    .padding(.top, 96)
                    .transition(.scale(scale: 0.96, anchor: .top).combined(with: .opacity))
                    .zIndex(30)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(traceInlineEditingItem != nil)
        .animation(traceEditSpring, value: traceInlineEditingItemID)
    }

    private func traceDetailFocusedList(snapshot: TraceDetailListSnapshot) -> some View {
        let isFocusing = traceInlineEditingItem != nil
        return VStack(alignment: .leading, spacing: 12) {
            recordListContent(snapshot: snapshot, fromTraceDetail: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(traceDetailListBackground)
        .overlay(traceDetailListBorder)
        .opacity(isFocusing ? 0.34 : 1)
        .scaleEffect(isFocusing ? 0.985 : 1, anchor: .top)
        .allowsHitTesting(!isFocusing)
        .animation(traceEditSpring, value: traceInlineEditingItemID)
    }

    private func traceFocusedRecordEditorCard(_ item: HomeItem) -> some View {
        FocusedRecordEditor(
            item: item,
            autoCommitRequestID: traceAutoCommitRequestID,
            onSave: { updated in
                let didSave = homeViewModel.updateItem(updated)
                if didSave {
                    withAnimation(traceEditSpring) {
                        traceInlineEditingItemID = nil
                        traceSwipedItemID = nil
                    }
                }
                return didSave
            },
            onCancel: {
                withAnimation(traceEditSpring) {
                    traceInlineEditingItemID = nil
                    traceSwipedItemID = nil
                }
            },
            onDelete: {
                deleteRecord(item)
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
    }

    private func traceDetailMetaText(snapshot: TraceDetailListSnapshot) -> String {
        "\(currentFilterSummary) · \(snapshot.items.count) 笔 · 合计 \(snapshot.totalExpense.formatted(.cny))"
    }

    private var traceDetailListBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.58),
                        AppColors.paperWarm.opacity(0.20),
                        Color.white.opacity(0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var traceDetailListBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.55), lineWidth: 1)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func recordListContent(
        snapshot: TraceDetailListSnapshot,
        fromTraceDetail: Bool = false
    ) -> some View {
        if snapshot.items.isEmpty {
            Text(emptyRecordListText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        } else {
            let groups = snapshot.dayGroups
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groups) { group in
                    Section {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            let isFirst = index == 0
                            let isLast = index == group.items.count - 1
                            if fromTraceDetail {
                                traceDetailBillRecordRow(item, isFirst: isFirst, isLast: isLast)
                            } else {
                                Button {
                                    openEditor(for: item)
                                } label: {
                                    timelineBillRecordRow(item, isFirst: isFirst, isLast: isLast)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        traceDayHeader(group)
                    }
                }
            }
        }
    }

    private func traceDayHeader(_ group: TraceDayGroup) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(traceDayRailTitle(group.date))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)

                    if let subtitle = traceDayRailSubtitle(group.date) {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.subtext.opacity(0.82))
                            .lineLimit(1)
                    }
                }

                Text(traceDaySubtitle(group))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.accent.opacity(0.84))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.accent.opacity(0.08))
                )
        }
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(traceDayHeaderBackground)
        .zIndex(1)
    }

    private var traceDayHeaderBackground: some View {
        Rectangle()
            .fill(AppColors.bg.opacity(0.92))
            .background(.ultraThinMaterial)
            .padding(.horizontal, -18)
    }

    private func traceDayRailTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        return "\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日"
    }

    private func traceDayRailSubtitle(_ date: Date) -> String? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            return nil
        }
        return weekdayText(for: date)
    }

    private func traceDaySubtitle(_ group: TraceDayGroup) -> String {
        let total = group.items.reduce(0) { $0 + $1.amount }
        return "\(group.items.count) 笔 · 共消费 \(total.formatted(.cny))"
    }

    func weekdayText(for date: Date) -> String {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        default: return "周六"
        }
    }

    private func handleSheetDismissRoute(_ route: SheetDismissRoute?) {
        guard let route else { return }
        switch route {
        case .memoryDetail(let item):
            memoryDetailItem = latestItem(matching: item)
        case .attachMemoryImage(let item):
            requestAttachMemoryImage(item)
        case .memberPricing(let context):
            onShowMemberPricing?(context)
        case .openWeekly:
            useCustomRange = false
            selectedPeriod = .week
        case .openInsight:
            onOpenInsight?()
        }
    }

    private func openEditor(for item: HomeItem, fromTraceDetail: Bool = false) {
        if item.hasMemoryImages {
            traceSwipedItemID = nil
            traceInlineEditingItemID = nil
            if traceDetailPresentation != nil || fromTraceDetail {
                traceDetailDismissRoute = .memoryDetail(latestItem(matching: item))
                traceDetailPresentation = nil
            } else {
                memoryDetailItem = latestItem(matching: item)
            }
            return
        }

        if fromTraceDetail {
            withAnimation(traceEditSpring) {
                traceSwipedItemID = nil
                traceInlineEditingItemID = item.id
            }
        } else {
            editingItem = latestItem(matching: item)
        }
    }

    private func requestAttachMemoryImage(_ item: HomeItem, preservesInlineEditor: Bool = false) {
        if !preservesInlineEditor {
            traceInlineEditingItemID = nil
        }
        traceSwipedItemID = nil
        let target = latestItem(matching: item)
        onAttachMemoryImage?(target)
    }

    private func openMemoryDetailAfterImageAttach(for item: HomeItem, fromInlineEditor: Bool = false) {
        if fromInlineEditor {
            withAnimation(traceEditSpring) {
                traceInlineEditingItemID = nil
                traceSwipedItemID = nil
            }
        }
        let target = latestItem(matching: item)
        if traceDetailPresentation != nil {
            traceDetailDismissRoute = .memoryDetail(target)
            traceDetailPresentation = nil
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
                homeViewModel.updateItem(updated)
            },
            onAddImages: {
                memoryDetailDismissRoute = .attachMemoryImage(current)
                memoryDetailItem = nil
            },
            onRemoveImage: { imageIndex in
                if homeViewModel.removeMemoryImage(at: imageIndex, from: current.id) {
                    memoryDetailItem = nil
                }
            },
            onSetCoverImage: { imageIndex in
                if homeViewModel.setCoverMemoryImageIndex(imageIndex, for: current.id) {
                    memoryDetailItem = latestItem(matching: current)
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

    private func deleteRecord(_ item: HomeItem) {
        if traceInlineEditingItemID == item.id {
            traceInlineEditingItemID = nil
        }
        traceSwipedItemID = nil
        withAnimation(.easeInOut(duration: 0.45)) {
            traceDeletingItemID = item.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if let idx = homeViewModel.items.firstIndex(where: { $0.id == item.id }) {
                homeViewModel.delete(at: IndexSet(integer: idx))
            }
            if traceDeletingItemID == item.id {
                traceDeletingItemID = nil
            }
        }
    }

    private func summaryPlaybackSheet(_ playback: SummaryPlayback) -> some View {
        SummaryPlaybackSheet(
            playback: playback,
            petEnabled: settingsViewModel.petCompanionEnabled,
            isMember: hasMemberAccess,
            memberPitch: summaryMemberPitch(for: playback),
            weeklySharePayload: weeklySharePayload(for: playback),
            shareSourceRevision: homeViewModel.homeDashboardRevision,
            shareEvidenceItemIDs: weeklyShareEvidenceItemIDs(),
            shareNickname: settingsViewModel.displayName,
            shareCardTheme: settingsViewModel.shareCardUsesAppTheme && settingsViewModel.settings.hasMemberAccess
                ? .appTheme(appTheme)
                : .journal,
            remoteAIDirectorEnabled: settingsViewModel.useRemoteAI
                && settingsViewModel.hasCloudSession,
            remoteAIMonthlyLimit: settingsViewModel.settings.remoteAIMonthlyLimit,
            onCompleted: { progress in
                quotaStore.markCompleted(playback.range, isMember: hasMemberAccess, progress: progress)
                homeViewModel.markSummaryPlaybackCompleted(playback.range, progress: progress)
                quotaRefreshID = UUID()
            },
            onShowMemberPricing: {
                summaryPlaybackDismissRoute = .memberPricing(.playbackQuota)
                summaryPlayback = nil
            },
            onOpenWeekly: {
                summaryPlaybackDismissRoute = .openWeekly
                summaryPlayback = nil
            },
            onOpenInsight: {
                summaryPlaybackDismissRoute = .openInsight
                summaryPlayback = nil
            },
            onSaveMemoryLine: { line, range in
                homeViewModel.markPlaybackMemoryLine(line, range: range)
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private func summaryMemberPitch(for playback: SummaryPlayback) -> SummaryPlaybackMemberPitch? {
        guard !hasMemberAccess else { return nil }
        switch playback.range {
        case .week:
            guard quotaStore.weekRemaining(isMember: false) <= 1 else { return nil }
            return SummaryPlaybackMemberPitch(
                headline: "周记本周免费次数快用完了。",
                detail: "这次免费会先保留基础回看。会员可以继续整理情绪标签、生活线索和反复出现的场景。",
                cta: "了解持续回看"
            )
        case .month:
            guard quotaStore.monthRemaining(isMember: false) <= 1 else { return nil }
            return SummaryPlaybackMemberPitch(
                headline: "月章体验快用完了。",
                detail: "这次免费已经生成月章；会员可以继续整理更多月份里的天气、路线和生活线索。",
                cta: "了解持续回看"
            )
        }
    }

    private func weeklySharePayload(for playback: SummaryPlayback) -> WeeklyShareCardPayload? {
        guard playback.range == .week else { return nil }
        return playbackService.buildWeeklyShareCardPayload(
            from: homeViewModel.items,
            summary: playback,
            sourceRevision: homeViewModel.homeDashboardRevision
        )
    }

    private func weeklyShareEvidenceItemIDs(now: Date = Date()) -> [UUID] {
        let calendar = PlaybackService.isoCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }
        return homeViewModel.items.compactMap { item in
            guard item.amount > 0,
                  item.createdAt >= interval.start,
                  item.createdAt < interval.end else {
                return nil
            }
            return item.id
        }
    }

    private func summaryQuotaOverlay(_ prompt: SummaryQuotaPrompt) -> some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSummaryQuotaPrompt()
                }

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.92))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(AppColors.accent.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(prompt.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(prompt.message)
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.text.opacity(0.76))
                            .lineSpacing(4)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        dismissSummaryQuotaPrompt()
                    } label: {
                        Text("知道了")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(Color.white.opacity(0.72), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        let shouldOpenMember = prompt.opensMember
                        dismissSummaryQuotaPrompt()
                        if shouldOpenMember {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                onShowMemberPricing?(.playbackQuota)
                            }
                        }
                    } label: {
                        Text(prompt.primaryTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(AppColors.accent.opacity(0.88), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 28, y: 14)
            .padding(.horizontal, 24)
        }
    }

    private func dismissSummaryQuotaPrompt() {
        withAnimation(.easeInOut(duration: 0.18)) {
            summaryQuotaPrompt = nil
        }
    }

    private func summaryQuotaFootnote(range: SummaryPlaybackRange, hasData: Bool) -> String {
        ExperienceRuleCopy.summaryQuotaFootnote(
            range: range,
            remaining: range == .week
                ? quotaStore.weekRemaining(isMember: false)
                : quotaStore.monthRemaining(isMember: false),
            hasData: hasData,
            isMember: hasMemberAccess
        )
    }

    private func handleSummaryPlaybackTap(range: SummaryPlaybackRange, hasData: Bool) {
        guard hasData, preparingSummaryRange == nil else { return }
        guard quotaStore.canPlay(range, isMember: hasMemberAccess) else {
            switch range {
            case .week:
                summaryQuotaPrompt = SummaryQuotaPrompt(
                    title: "周记本周次数已用完",
                    message: ExperienceRuleCopy.summaryQuotaExhaustedMessage(range: .week),
                    primaryTitle: "了解连续回放",
                    opensMember: true
                )
            case .month:
                summaryQuotaPrompt = SummaryQuotaPrompt(
                    title: "月章体验用完了",
                    message: ExperienceRuleCopy.summaryQuotaExhaustedMessage(range: .month),
                    primaryTitle: "继续留住月章",
                    opensMember: true
                )
            }
            return
        }
        let copySeed = nextSummaryCopySeed(for: range)
        let items = homeViewModel.items
        let sourceRevision = homeViewModel.homeDashboardRevision
        let performanceStartedAt = ProcessInfo.processInfo.systemUptime
        homeViewModel.markSummaryPlaybackStarted(range)
        summaryPlaybackTask?.cancel()
        preparingSummaryRange = range
        summaryPlaybackTask = Task { @MainActor in
            await Task.yield()
            let playback = await withTaskGroup(of: SummaryPlayback.self) { group -> SummaryPlayback? in
                group.addTask(priority: .userInitiated) {
                    let service = PlaybackService()
                    switch range {
                    case .week:
                        return service.buildWeekSummary(
                            from: items,
                            copySeed: copySeed,
                            sourceRevision: sourceRevision
                        )
                    case .month:
                        return service.buildMonthSummary(
                            from: items,
                            copySeed: copySeed,
                            sourceRevision: sourceRevision
                        )
                    }
                }
                return await group.next()
            }
            guard !Task.isCancelled, preparingSummaryRange == range else { return }
            summaryPlaybackTask = nil
            preparingSummaryRange = nil
            summaryPlayback = playback
            homeViewModel.markPerformance(
                operation: range == .week ? .summaryWeek : .summaryMonth,
                startedAtUptime: performanceStartedAt,
                itemCount: items.count,
                outcome: playback == nil ? .empty : .success
            )
        }
    }

    private func nextSummaryCopySeed(for range: SummaryPlaybackRange) -> String {
        let period = summaryCopyPeriodKey(for: range)
        let key = "summary_copy_variant_\(range.rawValue)_\(period)"
        let defaults = UserDefaults.standard
        let next = defaults.integer(forKey: key) + 1
        defaults.set(next, forKey: key)
        return "open-\(next)"
    }

    private func summaryCopyPeriodKey(for range: SummaryPlaybackRange) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch range {
        case .week:
            formatter.dateFormat = "yyyy-'W'ww"
        case .month:
            formatter.dateFormat = "yyyy-MM"
        }
        return formatter.string(from: .now)
    }

    // MARK: - Simplified Category Filter Chips (no longer used, replaced by Menu)

    @ViewBuilder
    private func billRecordRow(_ item: HomeItem, isFirst: Bool) -> some View {
        if item.hasMemoryImages {
            traceMemoryBillCard(item: item)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 9) {
                    traceRecordLeadingMark(item)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)

                        traceRecordTagLine(item)

                        if let note = traceRecordNote(item) {
                            Text(note)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.subtext)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(item.amount.formatted(.cny))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(traceListRecordBackground)
            .overlay(traceListRecordBorder)
        }
    }

    private func traceMemoryBillCard(item: HomeItem) -> some View {
        let accent = traceAccentColor(for: item.category)
        return ZStack(alignment: .bottom) {
            MemoryAttachmentThumbnail(
                imageData: item.coverMemoryImageData,
                imageReference: item.coverMemoryImageReference,
                height: 92,
                cornerRadius: 14
            )
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .frame(width: 23, height: 23)
                    .background(Circle().fill(Color.white.opacity(0.86)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
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
        .padding(.horizontal, 2)
        .padding(.vertical, 5)
    }

    private func traceRecordTagLine(_ item: HomeItem) -> some View {
        HStack(spacing: 5) {
            Text(item.category.rawValue)
            Text("·")
            Text(traceRecordTimeText(item.createdAt))
            if !item.displayEmotionTag.isEmpty {
                Text("·")
                Text(item.displayEmotionTag)
            }
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(AppColors.accent)
        .lineLimit(1)
    }

    private func traceRecordLeadingMark(_ item: HomeItem) -> some View {
        VStack(spacing: 0) {
            Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(traceAccentColor(for: item.category))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(traceAccentColor(for: item.category).opacity(0.14))
                )
        }
        .frame(width: 30)
        .padding(.top, 1)
    }

    private func traceRecordNote(_ item: HomeItem) -> String? {
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty,
              raw != title,
              raw != item.category.defaultRecordTitle else {
            return nil
        }
        return raw
    }

    private func traceRecordTimeText(_ date: Date) -> String {
        date.zhBillTime
    }

    private var traceListRecordBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.74))
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 7, y: 2)
    }

    private var traceListRecordBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.58), lineWidth: 1)
    }

    private func timelineBillRecordRow(_ item: HomeItem, isFirst: Bool, isLast: Bool) -> some View {
        billRecordRow(item, isFirst: isFirst)
            .padding(.bottom, isLast ? 0 : 12)
    }

    private func traceDetailBillRecordRow(_ item: HomeItem, isFirst: Bool, isLast: Bool) -> some View {
        let isEditing = traceInlineEditingItemID == item.id
        let canSwipe = traceInlineEditingItemID == nil
        let isSwiped = traceSwipedItemID == item.id && canSwipe
        let isDeleting = traceDeletingItemID == item.id
        let dragTranslation = traceSwipeDragState?.itemID == item.id ? traceSwipeDragState?.translation ?? 0 : 0
        let restingOffset: CGFloat = isSwiped ? -76 : 0
        let rowOffset = min(0, max(-86, restingOffset + dragTranslation))
        return ZStack(alignment: .trailing) {
            if canSwipe {
                traceSwipeActions(for: item, isVisible: isSwiped)
                    .padding(.trailing, 10)
                    .zIndex(2)
            }

            VStack(alignment: .leading, spacing: 8) {
                traceDetailRecordSummary(item, isEditing: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(traceDetailRecordBackground(isEditing: false))
            .overlay(traceDetailRecordBorder(isEditing: false))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .offset(x: rowOffset)
            .scaleEffect(isDeleting ? 0.96 : 1, anchor: .trailing)
            .opacity(isDeleting ? 0 : 1)
            .frame(height: isDeleting ? 0 : nil)
            .clipped()
            .onTapGesture {
                if traceSwipedItemID == item.id {
                    withAnimation(traceEditSpring) {
                        traceSwipedItemID = nil
                    }
                } else if !isEditing {
                    openEditor(for: item, fromTraceDetail: true)
                }
            }
            .overlay(alignment: .trailing) {
                if canSwipe {
                    traceSwipeHandle(for: item, isSwiped: isSwiped)
                        .zIndex(3)
                }
            }
        }
        .id(item.id)
        .padding(.bottom, isLast || isDeleting ? 0 : 12)
        .animation(traceEditSpring, value: isSwiped)
        .animation(.easeInOut(duration: 0.45), value: isDeleting)
    }

    private func traceTimelineRail(isFirst: Bool, isLast: Bool, isActive: Bool) -> some View {
        EmptyView()
            .frame(width: 0)
    }

    var traceEditSpring: Animation? {
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.08)
    }

    private func traceDetailRecordSummary(_ item: HomeItem, isEditing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                traceRecordLeadingMark(item)
                    .opacity(isEditing ? 0.28 : 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .opacity(isEditing ? 0.28 : 1)

                    traceRecordTagLine(item)
                        .opacity(isEditing ? 0.35 : 1)

                    if let note = traceRecordNote(item) {
                        Text(note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .lineLimit(1)
                            .opacity(isEditing ? 0 : 1)
                    }
                }

                Spacer(minLength: 8)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 1)
                    .opacity(isEditing ? 0.24 : 1)
            }

            if item.hasMemoryImages {
                traceDetailMemoryStrip(item: item)
                    .opacity(isEditing ? 0 : 1)
                    .frame(height: isEditing ? 0 : nil)
            }
        }
    }

    private func traceDetailMemoryStrip(item: HomeItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            MemoryAttachmentThumbnail(
                imageData: item.coverMemoryImageData,
                imageReference: item.coverMemoryImageReference,
                height: 78,
                cornerRadius: 12
            )
            Text("\(item.memoryImageCount) 张照片")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppColors.text.opacity(0.78))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.84))
                        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                )
                .padding(7)
        }
        .padding(.leading, 56)
        .padding(.top, 2)
    }

    private func traceDetailRecordBackground(isEditing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(isEditing ? 0.56 : 0.78))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(isEditing ? 0.0 : 0.035), radius: 9, y: 3)
    }

    private func traceDetailRecordBorder(isEditing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(AppColors.accent.opacity(isEditing ? 0.24 : 0.08), lineWidth: 1)
            .allowsHitTesting(false)
    }

    /*
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accentDark)
            }

            let emotionTag = item.displayEmotionTag
            if !emotionTag.isEmpty {
                Text(emotionTag)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.accent.opacity(0.74))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
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
                PaperCreaseDivider()
                    .padding(.top, -10)
            }
        }
    }
    */

    private func legacyTimelineBillRecordRowWithRail(_ item: HomeItem, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            legacyTraceTimelineRail(isFirst: isFirst, isLast: isLast, isActive: false)
            billRecordRow(item, isFirst: false)
                .padding(.bottom, isLast ? 0 : 2)
        }
        .padding(.top, isFirst ? 2 : 0)
    }

    private func legacyTraceDetailBillRecordRow(_ item: HomeItem, isFirst: Bool, isLast: Bool) -> some View {
        let isEditing = traceInlineEditingItemID == item.id
        let canSwipe = traceInlineEditingItemID == nil
        let isSwiped = traceSwipedItemID == item.id && canSwipe
        let isDeleting = traceDeletingItemID == item.id
        let dragTranslation = traceSwipeDragState?.itemID == item.id ? traceSwipeDragState?.translation ?? 0 : 0
        let restingOffset: CGFloat = isSwiped ? -76 : 0
        let rowOffset = min(0, max(-86, restingOffset + dragTranslation))
        return HStack(alignment: .top, spacing: 8) {
            legacyTraceTimelineRail(isFirst: isFirst, isLast: isLast, isActive: isSwiped || isEditing)

            ZStack(alignment: .trailing) {
                if canSwipe {
                    traceSwipeActions(for: item, isVisible: isSwiped)
                        .padding(.trailing, 10)
                        .zIndex(2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    legacyTraceDetailRecordSummary(item, isEditing: false)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(legacyTraceDetailRecordBackground(isEditing: false))
                .overlay(legacyTraceDetailRecordBorder(isEditing: false))
                .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .offset(x: rowOffset)
                .scaleEffect(isDeleting ? 0.96 : 1, anchor: .trailing)
                .opacity(isDeleting ? 0 : 1)
                .frame(height: isDeleting ? 0 : nil)
                .clipped()
                .onTapGesture {
                    if traceSwipedItemID == item.id {
                        withAnimation(traceEditSpring) {
                            traceSwipedItemID = nil
                        }
                    } else if !isEditing {
                        openEditor(for: item, fromTraceDetail: true)
                    }
                }
                .overlay(alignment: .trailing) {
                    if canSwipe {
                        traceSwipeHandle(for: item, isSwiped: isSwiped)
                            .zIndex(3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(item.id)
        .padding(.bottom, isLast || isDeleting ? 0 : 5)
        .animation(traceEditSpring, value: isSwiped)
        .animation(.easeInOut(duration: 0.45), value: isDeleting)
    }

    private func legacyTraceTimelineRail(isFirst: Bool, isLast: Bool, isActive: Bool) -> some View {
        let isEmphasized = isActive || isFirst
        return VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : AppColors.line.opacity(0.42))
                .frame(width: 1, height: 10)

            ZStack {
                Circle()
                    .fill(isEmphasized ? AppColors.accent.opacity(isActive ? 0.20 : 0.12) : AppColors.paperWarm.opacity(0.72))
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(isEmphasized ? AppColors.accent.opacity(isActive ? 0.72 : 0.46) : AppColors.line.opacity(0.68), lineWidth: isEmphasized ? 1.25 : 1)
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(isActive ? AppColors.accent : AppColors.accent.opacity(isFirst ? 0.72 : 0.52))
                    .frame(width: isEmphasized ? 6.5 : 6, height: isEmphasized ? 6.5 : 6)
            }

            Rectangle()
                .fill(isLast ? Color.clear : AppColors.line.opacity(0.42))
                .frame(width: 1, height: 58)
        }
        .frame(width: 30)
        .frame(minHeight: 70)
    }

    var legacyTraceEditSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.08)
    }

    private func legacyTraceDetailRecordSummary(_ item: HomeItem, isEditing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.displayTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(2)
                    .opacity(isEditing ? 0.28 : 1)
                    .offset(y: isEditing ? -2 : 0)

                Spacer(minLength: 8)

                Text(item.amount.formatted(.cny))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .opacity(isEditing ? 0.24 : 1)
                    .offset(x: isEditing ? -10 : 0, y: isEditing ? 5 : 0)
            }

            if !item.displayEmotionTag.isEmpty {
                Text(item.displayEmotionTag)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule(style: .continuous).fill(AppColors.accent.opacity(0.13)))
                    .overlay(Capsule(style: .continuous).stroke(AppColors.accent.opacity(0.28), lineWidth: 0.7))
                    .opacity(isEditing ? 0.35 : 1)
            }

            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))
                Text("·").foregroundStyle(AppColors.subtext)
                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                Spacer()
            }
            .opacity(isEditing ? 0 : 1)
            .offset(y: isEditing ? -5 : 0)
            .frame(height: isEditing ? 0 : nil)
        }
    }

    private func legacyTraceDetailRecordBackground(isEditing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.white.opacity(isEditing ? 0.48 : 0.40))
            )
            .overlay(
                LinearGradient(
                    colors: isEditing
                    ? [AppColors.accent.opacity(0.12), Color.white.opacity(0.48), AppColors.paperWarm.opacity(0.18)]
                    : [Color.white.opacity(0.54), Color.white.opacity(0.28), AppColors.accent.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            )
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color.white.opacity(isEditing ? 0.52 : 0.68), Color.white.opacity(0.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .shadow(color: AppColors.subtext.opacity(isEditing ? 0.14 : 0.09), radius: isEditing ? 16 : 12, x: 0, y: isEditing ? 9 : 6)
    }

    private func legacyTraceDetailRecordBorder(isEditing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: isEditing
                    ? [Color.white.opacity(0.82), AppColors.accent.opacity(0.28), AppColors.paperBorder.opacity(0.14)]
                    : [Color.white.opacity(0.76), Color.white.opacity(0.36), AppColors.accent.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isEditing ? 1.2 : 1
            )
    }

    private func traceSwipeActions(for item: HomeItem, isVisible: Bool) -> some View {
        Button(role: .destructive) {
            requestTraceDeleteConfirmation(for: item)
        } label: {
            traceSwipeActionLabel("删除", systemImage: "trash", tint: Color.red.opacity(0.82))
        }
        .buttonStyle(.plain)
        .frame(width: 76, alignment: .trailing)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.82, anchor: .trailing)
        .offset(x: isVisible ? 0 : 18)
        .allowsHitTesting(isVisible)
        .animation(traceEditSpring, value: isVisible)
    }

    private func requestTraceDeleteConfirmation(for item: HomeItem) {
        tracePendingDeleteItem = item
        showTraceDeleteConfirmation = true
    }

    private func traceSwipeActionLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        ZStack {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 54, height: 54)
        .background(
            Circle()
                .fill(tint)
        )
        .shadow(color: tint.opacity(0.22), radius: 12, y: 6)
    }

    private func traceSwipeHandle(for item: HomeItem, isSwiped: Bool) -> some View {
        Color.clear
            .frame(maxWidth: isSwiped ? .infinity : nil)
            .frame(width: isSwiped ? nil : 42)
            .contentShape(Rectangle())
            .gesture(traceRowSwipeGesture(for: item))
    }

    private func traceRowSwipeGesture(for item: HomeItem) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($traceSwipeDragState) { value, state, _ in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > max(16, abs(vertical) * 1.35) else { return }
                let baseOffset: CGFloat = traceSwipedItemID == item.id ? -76 : 0
                let translation = min(86, max(-86, baseOffset + horizontal)) - baseOffset
                state = TraceSwipeDragState(itemID: item.id, translation: translation)
            }
            .onEnded { value in
                let horizontal = value.translation.width
                let predictedHorizontal = value.predictedEndTranslation.width
                let vertical = value.translation.height
                let predictedVertical = value.predictedEndTranslation.height
                let isHorizontalSwipe = abs(horizontal) > max(34, abs(vertical) * 1.45)
                    || abs(predictedHorizontal) > max(62, abs(predictedVertical) * 1.35)
                if !isHorizontalSwipe {
                    if abs(vertical) > abs(horizontal), traceSwipedItemID == item.id {
                        withAnimation(traceEditSpring) {
                            traceSwipedItemID = nil
                        }
                    }
                    return
                }
                withAnimation(traceEditSpring) {
                    if horizontal < -28 || predictedHorizontal < -56 {
                        traceSwipedItemID = item.id
                    } else if horizontal > 24 || predictedHorizontal > 48 {
                        traceSwipedItemID = nil
                    }
                }
            }
    }

    // MARK: - Category Filter Chip

    private func categoryFilterChip(label: String, category: HomeItem.Category?) -> some View {
        let isSelected = selectedCategory == category
        return Button(label) {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        }
        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(isSelected ? .white : AppColors.text.opacity(0.82))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            isSelected
                ? AppColors.accent
                : Color.white.opacity(0.72),
            in: Capsule(style: .continuous)
        )
        .shadow(color: isSelected ? AppColors.accent.opacity(0.2) : .clear, radius: 4, y: 2)
    }

    // MARK: - Record List Item

    private func recordListItem(_ item: HomeItem) -> some View {
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

            HStack(spacing: 6) {
                Text(item.category.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext.opacity(0.82))

                Text("·")
                    .foregroundStyle(AppColors.subtext)

                Text(item.createdAt.zhBillDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) {
            PaperCreaseDivider()
                .padding(.top, -4)
        }
    }

}
