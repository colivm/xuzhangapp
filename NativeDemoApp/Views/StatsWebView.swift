import SwiftUI

// MARK: - Stats View (matching web statsPage)

@MainActor
private enum TraceColors {
    static var primaryText: Color { AppColors.text }
    static var secondaryText: Color { AppColors.subtext }
    static var tertiaryText: Color { AppColors.tertiary }
    static var surfaceWarm: Color { AppColors.paperWarm }
    static var surfaceGlass: Color { AppColors.panel }
    static var surfaceMuted: Color { AppColors.surfaceMuted }
    static var stroke: Color { AppColors.stroke }
}

struct StatsWebView: View {

    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    var openTraceRequestID: UUID? = nil
    var onShowMemberPricing: (() -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedCategory: HomeItem.Category? = nil
    @State private var editingItem: HomeItem?
    @State private var summaryPlayback: SummaryPlayback?
    @State private var summaryQuotaMessage: String?
    @State private var quotaRefreshID = UUID()
    @State private var isFiltersExpanded = false
    @State private var showTraceDetailSheet = false
    @State private var showCategoryFilterSheet = false
    @State private var traceInlineEditingItemID: UUID?
    @State private var handledOpenTraceRequestID: UUID?
    @State private var traceSwipedItemID: UUID?
    @State private var traceDeletingItemID: UUID?
    @State private var traceAutoCommitRequestID: UUID?
    @State private var showTraceCustomDatePanel = false
    @State private var traceViewMode: TraceViewMode = .life
    @State private var traceDeepInsightExpanded = false
    @State private var traceInsightFocusedQuestion: String?
    @State private var lifeInsightRefreshID = UUID()
    private let playbackService = PlaybackService()
    private let momentSelector = PlaybackMomentSelector()
    private let quotaStore = SummaryPlaybackQuotaStore()
    private let lifeInsightService = LifeInsightService.shared

    enum StatsPeriod: String, CaseIterable, Identifiable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
        var id: String { rawValue }
    }

    private var filteredItems: [HomeItem] {
        var items: [HomeItem]
        if useCustomRange {
            let cal = Calendar.current
            let start = cal.startOfDay(for: customStartDate)
            let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: customEndDate)) ?? customEndDate
            items = homeViewModel.items.filter { $0.createdAt >= start && $0.createdAt < end }
        } else {
            switch selectedPeriod {
            case .week:
                if let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: .now) {
                    items = homeViewModel.items.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
                } else {
                    items = []
                }
            case .month: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
            case .year: items = homeViewModel.items.filter { Calendar.current.isDate($0.createdAt, equalTo: .now, toGranularity: .year) }
            }
        }
        if let cat = selectedCategory {
            items = items.filter { $0.category == cat }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private var totalExpense: Double {
        filteredItems.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
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

    private var currentFilterSummary: String {
        let periodText = useCustomRange ? "自定义时间" : selectedPeriod.rawValue
        let categoryText = selectedCategory?.rawValue ?? "全部分类"
        return "\(periodText) · \(categoryText)"
    }

    private var overviewNarrativeText: String {
        let count = filteredItems.count
        guard count > 0 else {
            return "这一段还没有记录。先留下几笔，之后会整理成一段场记。"
        }
        let trendData = computeTrendData()
        let trendText = trendData.isEmpty ? "多记几天，节奏会更清楚。" : trendInsightText(data: trendData)
        return "这一段留下 \(count) 笔，合计 \(totalExpense.formatted(.cny))。\(trendText)"
    }

    @State private var showPeriodSheet = false
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var customDateFocus: CustomDateEndpoint = .start
    @State private var useCustomRange = false

    private enum CustomDateEndpoint {
        case start
        case end
    }

    private enum TraceViewMode: String, CaseIterable, Identifiable {
        case life = "生活"
        case clues = "线索"

        var id: String { rawValue }
    }

    private struct TraceCategoryClue: Identifiable {
        let id = UUID()
        let category: HomeItem.Category
        let count: Int
        let total: Double
        let ratio: Double
    }

    private struct TraceRhythmPoint: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let isToday: Bool
    }

    var body: some View {
        statsScrollView
            .sheet(isPresented: $showPeriodSheet) {
                periodPickerSheet
            }
            .sheet(isPresented: $showCategoryFilterSheet) {
                categoryFilterSheet
            }
            .sheet(isPresented: $showTraceDetailSheet) {
                traceDetailSheet
            }
            .sheet(item: $editingItem) { item in
                editSheet(for: item)
            }
            .sheet(item: $summaryPlayback) { playback in
                summaryPlaybackSheet(playback)
            }
            .onAppear {
                handleOpenTraceRequestIfNeeded()
            }
            .onChange(of: openTraceRequestID) { _, _ in
                handleOpenTraceRequestIfNeeded()
            }
            .alert("播放次数已用完", isPresented: summaryQuotaAlertBinding) {
                summaryQuotaAlertActions
            } message: {
                Text(summaryQuotaMessage ?? "")
            }
    }

    private var statsScrollView: some View {
        ScrollView {
            statsContent
        }
        .scrollIndicators(.hidden)
    }

    private var statsContent: some View {
        VStack(spacing: 16) {
            traceViewModeKicker
            if traceViewMode == .life {
                traceChapterCard
                traceAppendixStrip
            } else {
                traceClueBoard
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 120)
        .frame(maxWidth: 430)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var heroScopedItems: [HomeItem] {
        if useCustomRange || selectedPeriod == .year {
            return filteredItems
        }
        let calendar = Calendar.current
        let items: [HomeItem]
        switch selectedPeriod {
        case .week:
            if let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: .now) {
                items = homeViewModel.items.filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
            } else {
                items = []
            }
        case .month:
            items = homeViewModel.items.filter { calendar.isDate($0.createdAt, equalTo: .now, toGranularity: .month) }
        case .year:
            items = []
        }
        return items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var traceRepresentativeItems: [HomeItem] {
        representativeTraceItems(from: heroScopedItems)
    }

    private func representativeTraceItems(from items: [HomeItem]) -> [HomeItem] {
        guard items.count > 3 else { return items }
        let ranked = Array(items.enumerated()).sorted { lhs, rhs in
            let leftScore = traceRepresentativeScore(item: lhs.element, index: lhs.offset)
            let rightScore = traceRepresentativeScore(item: rhs.element, index: rhs.offset)
            if leftScore == rightScore {
                return lhs.element.createdAt > rhs.element.createdAt
            }
            return leftScore > rightScore
        }

        var selected: [HomeItem] = []
        var selectedCategories = Set<String>()
        for candidate in ranked where selected.count < 3 {
            let categoryKey = candidate.element.category.rawValue
            guard !selectedCategories.contains(categoryKey) else { continue }
            selected.append(candidate.element)
            selectedCategories.insert(categoryKey)
        }
        for candidate in ranked where selected.count < 3 {
            guard !selected.contains(where: { $0.id == candidate.element.id }) else { continue }
            selected.append(candidate.element)
        }
        return selected.sorted { $0.createdAt > $1.createdAt }
    }

    private func traceRepresentativeScore(item: HomeItem, index: Int) -> Int {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultTitle = item.category.defaultRecordTitle
        let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
        let emotion = item.displayEmotionTag
        var score = 0
        if !emotion.isEmpty && emotion != defaultEmotion { score += 40 }
        if item.userEditedTitle == true { score += 30 }
        if title != defaultTitle && (4...18).contains(title.count) { score += 20 }
        if case .manual = item.source { score += 6 }
        score += min(index, 6) * 2
        if title == defaultTitle { score -= 12 }
        return score
    }

    private var heroNarrativeText: String {
        let items = heroScopedItems
        guard !items.isEmpty else {
            return selectedPeriod == .week
                ? "这一周还没有记录。先留下几笔，之后会整理成一段场记。"
                : "这个月还没有记录。先留下几笔，之后会整理成一段场记。"
        }
        if let voice = heroMomentSelection.primary?.text {
            return selectedPeriod == .week
                ? "这一周先记住「\(voice)」。数字放在旁边，生活句留在前面。"
                : "这个月先记住「\(voice)」。统计放在旁边，生活句留在前面。"
        }
        let grouped = Dictionary(grouping: items, by: \.category)
        let topCategory = grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
            .first?.category.rawValue ?? "日常"
        return "这一段还没有具体备注，先看到「\(topCategory)」出现得多一点。"
    }

    private var heroMomentSelection: PlaybackMomentSelection {
        let periodKey = heroMomentPeriodKey
        let echoAnchor = heroMomentEchoAnchor(periodKey: periodKey)
        return momentSelector.select(
            from: heroScopedItems,
            periodKey: periodKey,
            range: heroRange,
            now: .now,
            echoAnchor: echoAnchor
        )
    }

    private var heroMomentPeriodKey: String {
        if useCustomRange || selectedPeriod == .year {
            return "trace-\(selectedPeriod.rawValue)-\(heroScopedItems.count)"
        }
        switch heroRange {
        case .week:
            return quotaStore.currentWeekKey()
        case .month:
            return EchoAnchorService.shared.periodKeyForMonth()
        }
    }

    private func heroMomentEchoAnchor(periodKey: String) -> EchoAnchor? {
        guard !useCustomRange, selectedPeriod != .year else { return nil }
        return EchoAnchorService.shared.pickEchoAnchor(items: heroScopedItems, periodKey: periodKey)
    }

    private var heroRange: SummaryPlaybackRange {
        selectedPeriod == .week ? .week : .month
    }

    private var traceChapterCard: some View {
        let _ = quotaRefreshID
        let range = heroRange
        let preview = buildSummaryPreview(for: range)
        let hasData = !heroScopedItems.isEmpty
        let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0
        let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)

        return VStack(alignment: .leading, spacing: 14) {
            traceRangeKicker

            Text(heroNarrativeText)
                .font(.system(size: 16, weight: .medium))
                .lineSpacing(5)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(summaryCardSubtitle(preview: preview, range: range, hasData: hasData, isMonthLocked: isMonthLocked))
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                handleSummaryPlaybackTap(range: range, preview: preview)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isMonthLocked ? "lock.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppColors.accent.opacity(canPlay ? 0.16 : 0.08)))
                    Text(isMonthLocked ? "了解会员" : "听听这一段")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(canPlay || isMonthLocked ? AppColors.accent.opacity(0.9) : AppColors.subtext.opacity(0.82))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(AppColors.tracePlaybackButtonBg)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.accent.opacity(canPlay || isMonthLocked ? 0.24 : 0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasData && !isMonthLocked)

            if hasData {
                VStack(spacing: 8) {
                    ForEach(Array(traceRepresentativeItems.enumerated()), id: \.element.id) { _, item in
                        Button {
                            openEditor(for: item)
                        } label: {
                            traceSlipRow(item)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.26))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.accent.opacity(0.10), lineWidth: 1)
                )
            } else {
                traceEmptyState
            }
        }
        .paperChapterPanel(radius: 24, padding: 20)
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
            .frame(height: 42)

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
            withAnimation(traceEditSpring) {
                traceViewMode = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? TraceColors.primaryText : TraceColors.tertiaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func traceRangeTab(_ title: String, period: StatsPeriod) -> some View {
        let isSelected = !useCustomRange && selectedPeriod == period
        return Button {
            applyTracePeriod(period)
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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.40))
        )
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
        _ = lifeInsightRefreshID
        return lifeInsightService.buildTraceInsight(
            items: traceClueItems,
            periodLabel: traceInsightPeriodLabel
        )
    }

    private var traceLifeInsightFreeRemaining: Int {
        return lifeInsightService.freeRemaining(isMember: hasMemberAccess)
    }

    private var hasTraceInsightData: Bool {
        !traceClueItems.isEmpty
    }

    private var canUseTraceDeepInsight: Bool {
        hasTraceInsightData && (hasMemberAccess || traceLifeInsightFreeRemaining > 0)
    }

    private var traceCategoryClues: [TraceCategoryClue] {
        let items = traceClueItems
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
        let items = traceClueItems
        guard !items.isEmpty else { return "线索还在等第一笔记录" }
        guard let top = traceCategoryClues.first else {
            return "这一段的记录还比较分散"
        }
        let period = traceNarrativePeriodPrefix
        switch top.category {
        case .transport:
            return "\(period)，你主要在奔波"
        case .dining:
            return "\(period)，吃饭留下了最多痕迹"
        case .shopping:
            return "\(period)，添置东西更常出现"
        case .daily:
            return "\(period)，日常补给占了不少"
        case .health:
            return "\(period)，你在照顾身体"
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
        let items = traceClueItems
        guard !items.isEmpty else { return "先留下几笔，账本会把生活里的走向慢慢标出来。" }
        if let top = traceCategoryClues.first {
            let percent = Int((top.ratio * 100).rounded())
            if let peak = traceRhythmPoints.max(by: { $0.count < $1.count }), peak.count >= 2 {
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
        let items = traceClueItems
        guard !items.isEmpty else { return nil }
        let total = items.reduce(0) { $0 + $1.amount }
        let activeDays = traceActiveDayCount(from: items)
        return ("\(items.count) 笔", "\(activeDays) 天有痕迹", "合计 \(total.formatted(.cny))")
    }

    private var tracePrimaryEvidence: String {
        if let top = traceCategoryClues.first {
            return "\(top.category.rawValue) \(top.count) 笔"
        }
        return "暂无分类线索"
    }

    private var traceSecondaryEvidence: String {
        let activeDays = traceActiveDayCount(from: traceClueItems)
        return "\(activeDays) 天有记录"
    }

    private var traceTertiaryEvidence: String {
        guard let peak = traceRhythmPoints.max(by: { $0.count < $1.count }), peak.count > 0 else {
            return "节奏未形成"
        }
        return "\(traceRhythmNarrativeLabel(peak))最集中"
    }

    private var traceRhythmSummary: String {
        let active = traceRhythmPoints.filter { $0.count > 0 }.count
        guard active > 0 else { return "还在形成" }
        return "\(active) 天有记录"
    }

    private var traceClueInsightLines: [String] {
        let items = traceClueItems
        guard !items.isEmpty else {
            return [
                "先留下几笔，线索会先从分类、时间和频次里浮出来。",
                "这里先列事实证据，不急着解释原因。",
                "多记几天后，会看到哪类更多、哪天更密。"
            ]
        }
        var lines: [String] = []
        if let top = traceCategoryClues.first {
            let percent = Int((top.ratio * 100).rounded())
            lines.append("\(top.category.rawValue)占 \(percent)%，共 \(top.count) 笔，是占比最高的分类。")
        }
        if let peak = traceRhythmPoints.max(by: { $0.count < $1.count }), peak.count > 0 {
            lines.append("\(traceRhythmNarrativeLabel(peak))留下 \(peak.count) 笔，是记录最密的时间点。")
        }
        let total = items.reduce(0) { $0 + $1.amount }
        if items.count >= 2 {
            let average = total / Double(items.count)
            lines.append("共 \(items.count) 笔，平均每笔约 \(average.formatted(.cny))。")
        } else {
            lines.append("现在只有一笔，先不做趋势判断。")
        }
        return Array(lines.prefix(3))
    }

    private var traceRhythmPoints: [TraceRhythmPoint] {
        let items = traceClueItems
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

    private var traceClueBoard: some View {
        VStack(spacing: 16) {
            traceClueHeroCard
            traceClueCompositionCard
            traceClueRhythmCard
            traceClueInsightCard
            traceDeepInsightCard
            traceAppendixStrip
        }
    }

    private var traceClueHeroCard: some View {
        let items = traceClueItems
        return VStack(alignment: .leading, spacing: 16) {
            traceRangeKicker

            VStack(alignment: .leading, spacing: 8) {
                Text(traceClueHeadline)
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(TraceColors.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(traceClueSubline)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TraceColors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let meta = traceHeroMetaParts {
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
                traceClueEvidenceChip(tracePrimaryEvidence, isPrimary: true)
                traceClueEvidenceChip(traceSecondaryEvidence)
                traceClueEvidenceChip(traceTertiaryEvidence)
            }

            if items.isEmpty {
                Text("先留下几笔，线索会慢慢浮出来。")
                    .font(.system(size: 13))
                    .foregroundStyle(TraceColors.secondaryText)
                    .padding(.top, 2)
            }
        }
        .traceWarmPanel(radius: 26, padding: 24)
    }

    private var traceClueCompositionCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("生活构成")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TraceColors.primaryText)
                Spacer()
                Text("\(traceClueItems.count) 笔")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
            }

            if traceCategoryClues.isEmpty {
                traceQuietCluePlaceholder("还没有足够记录形成构成。")
            } else {
                traceCompositionRibbon
                VStack(spacing: 8) {
                    ForEach(Array(traceCategoryClues.prefix(4))) { clue in
                        traceCategoryClueRow(clue)
                    }
                }
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private var traceCompositionRibbon: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 3) {
                ForEach(Array(traceCategoryClues.prefix(4))) { clue in
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

    private var traceClueRhythmCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(selectedPeriod == .week ? "一周节奏" : "这一月的节奏")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TraceColors.primaryText)
                Spacer()
                Text(traceRhythmSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
            }

            if traceRhythmPoints.isEmpty {
                traceQuietCluePlaceholder("多记几天，节奏会自然出来。")
            } else {
                HStack(alignment: .bottom, spacing: 9) {
                    ForEach(traceRhythmPoints) { point in
                        traceRhythmColumn(point)
                    }
                }
                .frame(height: 92)
                .padding(.top, 2)
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private var traceClueInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("变化线索")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TraceColors.primaryText)

            VStack(spacing: 10) {
                ForEach(Array(traceClueInsightLines.enumerated()), id: \.offset) { index, line in
                    traceClueInsightRow(line, index: index)
                }
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private var traceDeepInsightCard: some View {
        let insight = traceLifeInsight
        let isUnlocked = hasMemberAccess || traceDeepInsightExpanded
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.10))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.accent.opacity(0.80))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("多看一层")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TraceColors.primaryText)
                    Text(hasMemberAccess ? "会员可继续追问这段账本" : "本周免费 \(traceLifeInsightFreeRemaining)/\(LifeInsightService.freeWeeklyLimit) 次")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(TraceColors.tertiaryText)
                }

                Spacer()
            }

            Text(insight.leadQuestion)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TraceColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(isUnlocked ? insight.previewLine : insight.teaser)
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(TraceColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if isUnlocked {
                Divider()
                    .overlay(TraceColors.surfaceMuted)
                    .padding(.top, 2)

                VStack(spacing: 8) {
                    ForEach(Array(insight.fullLines.enumerated()), id: \.offset) { index, line in
                        traceDeepInsightLine(line, index: index)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                traceInsightQuestionChips(insight.questionChips)
                    .transition(.opacity)

                if let focusedQuestion = traceInsightFocusedQuestion {
                    traceFocusedInsightAnswer(question: focusedQuestion, insight: insight)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Button {
                handleTraceDeepInsightTap()
            } label: {
                let buttonIsOpen = hasMemberAccess || canUseTraceDeepInsight || isUnlocked
                if buttonIsOpen {
                    HStack(spacing: 8) {
                        Text(traceDeepInsightButtonTitle(isUnlocked: isUnlocked))
                            .font(.system(size: 14, weight: .semibold))
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
                        Text(traceDeepInsightButtonTitle(isUnlocked: isUnlocked))
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(minHeight: 36)
                    .foregroundStyle(AppColors.lockGold)
                    .padding(.horizontal, 12)
                    .background(traceDeepCTAButtonBackground(isOpen: false))
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasTraceInsightData)
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private func traceDeepInsightLine(_ text: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(index == 0 ? AppColors.accentDark : TraceColors.secondaryText)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(index == 0 ? AppColors.accent.opacity(0.10) : TraceColors.surfaceMuted)
                )
            Text(text)
                .font(.system(size: 13, weight: .medium))
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
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(traceInsightFocusedQuestion == chip ? AppColors.accent.opacity(0.12) : TraceColors.surfaceMuted)
                            )
                            .overlay(
                                Capsule(style: .continuous)
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

    private func traceFocusedInsightAnswer(question: String, insight: LifeInsightResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TraceColors.primaryText)
                .lineLimit(2)

            Text(traceInsightAnswer(for: question, insight: insight))
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

    private func traceDeepInsightButtonTitle(isUnlocked: Bool) -> String {
        if !hasTraceInsightData { return "先留下几笔" }
        if hasMemberAccess { return "继续追问这段账本" }
        if isUnlocked { return "本周体验已展开" }
        if canUseTraceDeepInsight { return "试一次多看一层" }
        return "解锁完整线索"
    }

    private func handleTraceDeepInsightTap() {
        guard hasTraceInsightData else { return }
        if hasMemberAccess {
            withAnimation(traceEditSpring) {
                traceDeepInsightExpanded = true
                focusNextTraceInsightQuestion()
                lifeInsightRefreshID = UUID()
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
            onShowMemberPricing?()
            return
        }

        lifeInsightService.markDeepInsightUsed(isMember: false)
        withAnimation(traceEditSpring) {
            traceDeepInsightExpanded = true
            focusNextTraceInsightQuestion()
            lifeInsightRefreshID = UUID()
        }
    }

    private func handleTraceInsightQuestionTap(_ question: String) {
        guard hasTraceInsightData else { return }
        if hasMemberAccess || traceDeepInsightExpanded {
            withAnimation(traceEditSpring) {
                traceInsightFocusedQuestion = question
            }
            return
        }

        guard canUseTraceDeepInsight else {
            onShowMemberPricing?()
            return
        }

        lifeInsightService.markDeepInsightUsed(isMember: false)
        withAnimation(traceEditSpring) {
            traceDeepInsightExpanded = true
            traceInsightFocusedQuestion = question
            lifeInsightRefreshID = UUID()
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

    private func traceInsightAnswer(for question: String, insight: LifeInsightResult) -> String {
        if question.contains("哪天") || question.contains("不太像") || question.contains("更密") || question.contains("发生了什么") {
            if let peak = traceRhythmPoints.max(by: { $0.count < $1.count }), peak.count > 0 {
                return "\(traceRhythmNarrativeLabel(peak))留下 \(peak.count) 笔，是这一段里最密的一天。可以从那天的备注往回看，它更像一个具体生活节点。"
            }
            return "这一段还没有明显峰值，先让记录再多一点，哪天不太一样会更容易浮出来。"
        }

        if question.contains("有关吗") || question.contains("一起") {
            let clues = Array(traceCategoryClues.prefix(2))
            if clues.count == 2 {
                let first = clues[0]
                let second = clues[1]
                let overlapDays = traceDaysContaining(categories: [first.category, second.category])
                if overlapDays > 0 {
                    return "\(first.category.rawValue)和\(second.category.rawValue)在 \(overlapDays) 天里同时出现，说明它们可能被同一种生活安排带出来，比如外出、工作日节奏或某次集中补给。"
                }
                return "\(first.category.rawValue)和\(second.category.rawValue)都靠前，但没有明显落在同一天，更像两条并行的生活线索。"
            }
            return insight.previewLine
        }

        if question.contains("重复") || question.contains("习惯") {
            if let top = traceCategoryClues.first {
                return "\(top.category.rawValue)出现 \(top.count) 笔，是当前最稳定的重复线索。它不一定是问题，更像这段时间反复出现的生活面。"
            }
            return "现在重复还不明显，等同类记录连续出现，账本会更容易看出习惯。"
        }

        if question.contains("名字") {
            return insight.periodName
        }

        if question.contains("为什么") {
            if let top = traceCategoryClues.first {
                return traceWhyCategoryBecameVisible(top)
            }
            return insight.previewLine
        }

        return insight.previewLine
    }

    private func traceWhyCategoryBecameVisible(_ clue: TraceCategoryClue) -> String {
        let categoryItems = traceClueItems.filter { $0.category == clue.category }
        let peak = traceRhythmPoints.max(by: { $0.count < $1.count })
        let second = traceCategoryClues.dropFirst().first
        let categoryName = traceCategoryLifeName(for: clue.category, items: categoryItems)
        let base: String
        switch clue.category {
        case .dining:
            base = "「\(categoryName)」变明显，通常不是因为某一顿特别贵，而是这一段生活被吃饭、外卖、咖啡这些小节点不断打断或撑住了。它更像日程密度的影子。"
        case .transport:
            base = "「\(categoryName)」变明显，往往说明你在移动：通勤、办事、见人、往返变多了。它背后看的不是车费，而是这段时间你被拉去哪些地方。"
        case .health:
            base = "「\(categoryName)」变明显，更像你开始把身体放回日程里：可能是健身、看诊、买药或恢复性的安排，不只是消费变多。"
        case .shopping, .daily:
            base = "「\(categoryName)」变明显，像是生活在补库存：添置、日用、临时需要一起冒出来。它通常对应某个阶段的整理、消耗或重新准备。"
        case .entertainment:
            base = "「\(categoryName)」变明显，说明这段时间你给自己留了更多松动空间。它不一定是浪费，可能是在给压力找出口。"
        case .home:
            base = "「\(categoryName)」变明显，像是注意力回到居住环境：修补、布置、家用安排开始占据生活。"
        case .social:
            base = "「\(categoryName)」变明显，背后通常是关系在发生：见面、送礼、人情往来比金额本身更重要。"
        case .lodging:
            base = "「\(categoryName)」变明显，说明这段时间有停留和位置变化，可能是旅行、出差或临时过夜安排。"
        case .other:
            base = "这类记录变明显，说明有些事还没被归进固定生活面。可以回头看看备注，里面可能藏着真正的主题。"
        }

        var tails: [String] = []
        if let peak, peak.count > 0 {
            tails.append("尤其\(traceRhythmNarrativeLabel(peak))最密，原因可能就在那天的行程里。")
        }
        if let second {
            tails.append("它还和「\(second.category.rawValue)」一起靠前，像是同一段生活场景带出来的两条痕迹。")
        }
        return ([base] + tails).joined(separator: " ")
    }

    private func traceCategoryLifeName(for category: HomeItem.Category, items: [HomeItem]) -> String {
        let text = items.map { "\($0.title) \($0.emotionTag)" }.joined(separator: " ")
        switch category {
        case .transport:
            return traceContainsAny(text, ["通勤", "上班", "下班", "地铁", "公交"]) ? "通勤交通" : "交通"
        case .health:
            return traceContainsAny(text, ["健身", "运动", "跑步", "瑜伽", "私教", "游泳"]) ? "运动健身" : "健康"
        case .dining:
            return traceContainsAny(text, ["咖啡", "奶茶"]) ? "饮品餐饮" : "餐饮"
        default:
            return category.rawValue
        }
    }

    private func traceContainsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func traceDaysContaining(categories: [HomeItem.Category]) -> Int {
        guard !categories.isEmpty else { return 0 }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: traceClueItems) { item in
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

    private func traceCategoryClueRow(_ clue: TraceCategoryClue) -> some View {
        let isTop = traceCategoryClues.first?.category == clue.category
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

    private func traceRhythmColumn(_ point: TraceRhythmPoint) -> some View {
        let maxCount = max(traceRhythmPoints.map(\.count).max() ?? 1, 1)
        let ratio = CGFloat(point.count) / CGFloat(maxCount)
        let barHeight = max(8, 54 * ratio)
        return VStack(spacing: 7) {
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(
                        point.count > 0
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(point.isToday ? 0.82 : 0.64), traceClueMist.opacity(0.54)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(TraceColors.surfaceMuted)
                    )
                    .frame(width: point.isToday ? 18 : 16, height: barHeight)

                if point.isToday && point.count > 0 {
                    Circle()
                        .fill(TraceColors.primaryText)
                        .frame(width: 2.5, height: 2.5)
                        .offset(y: 3)
                }
            }
            Text(point.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(point.isToday ? AppColors.accentDark : TraceColors.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func traceClueInsightRow(_ text: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(TraceColors.tertiaryText)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(TraceColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
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
        showTraceDetailSheet = true
    }

    private func handleOpenTraceRequestIfNeeded() {
        guard let openTraceRequestID,
              handledOpenTraceRequestID != openTraceRequestID
        else { return }
        handledOpenTraceRequestID = openTraceRequestID
        useCustomRange = false
        selectedPeriod = .week
        selectedCategory = nil
        withAnimation(traceEditSpring) {
            traceViewMode = .life
        }
    }

    private var traceDetailSheet: some View {
        NavigationStack {
            ZStack {
                AppColors.bg.ignoresSafeArea()
                ScrollViewReader { traceProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                        Text("细查这一段")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)

                        Text(traceDetailMetaText)
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

                        VStack(alignment: .leading, spacing: 12) {
                            recordListContent(fromTraceDetail: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(traceDetailListBackground)
                        .overlay(traceDetailListBorder)
                        }
                        .padding(18)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: traceInlineEditingItemID) { _, itemID in
                        guard let itemID else { return }
                        scrollTraceEditorIntoView(itemID, proxy: traceProxy, delay: 0.34)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showTraceDetailSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var traceDetailMetaText: String {
        "\(currentFilterSummary) · \(filteredItems.count) 笔 · 合计 \(totalExpense.formatted(.cny))"
    }

    private var filtersPanel: some View {
        VStack(alignment: .leading, spacing: isFiltersExpanded ? 14 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isFiltersExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("细查时间与分类")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.text.opacity(0.82))
                        Text(currentFilterSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.subtext)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.subtext.opacity(0.7))
                        .rotationEffect(.degrees(isFiltersExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isFiltersExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("时间与分类")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.subtext)

                    HStack(alignment: .top, spacing: 8) {
                        periodFilter
                        categoryFilter
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassPanel(radius: 18, padding: isFiltersExpanded ? 16 : 14)
    }

    private var periodFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("时间")
            Button {
                showPeriodSheet = true
            } label: {
                filterButtonLabel(useCustomRange ? "自定义" : selectedPeriod.rawValue)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("分类")
            Button {
                showCategoryFilterSheet = true
            } label: {
                filterButtonLabel(selectedCategory?.rawValue ?? "全部分类")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var tracePeriodFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("时间")
            Menu {
                Button("本周") {
                    applyTracePeriod(.week)
                }
                Button("本月") {
                    applyTracePeriod(.month)
                }
                Button("本年") {
                    applyTracePeriod(.year)
                }
                Button("具体时间段") {
                    withAnimation(traceEditSpring) {
                        showTraceCustomDatePanel.toggle()
                        traceInlineEditingItemID = nil
                        traceSwipedItemID = nil
                    }
                }
            } label: {
                filterButtonLabel(useCustomRange ? "具体时间段" : selectedPeriod.rawValue)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var traceCategoryFilter: some View {
        VStack(alignment: .leading, spacing: 4) {
            filterLabel("分类")
            Menu {
                Button("全部分类") {
                    applyTraceCategory(nil)
                }
                ForEach(HomeItem.Category.allCases) { category in
                    Button(category.displayName) {
                        applyTraceCategory(category)
                    }
                }
            } label: {
                filterButtonLabel(selectedCategory?.rawValue ?? "全部分类")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var traceCustomDatePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            traceQuickRangeGrid

            HStack(spacing: 8) {
                traceInlineDatePicker(title: "开始", selection: $customStartDate)
                traceInlineDatePicker(title: "结束", selection: $customEndDate)
            }

            HStack(spacing: 8) {
                Button("取消") {
                    withAnimation(traceEditSpring) {
                        showTraceCustomDatePanel = false
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.45))
                )

                Button("应用") {
                    withAnimation(traceEditSpring) {
                        if customStartDate > customEndDate {
                            let start = customStartDate
                            customStartDate = customEndDate
                            customEndDate = start
                        }
                        useCustomRange = true
                        showTraceCustomDatePanel = false
                        traceInlineEditingItemID = nil
                        traceSwipedItemID = nil
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.accent.opacity(0.86))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.46), lineWidth: 1)
        )
    }

    private var traceQuickRangeGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 7)], spacing: 7) {
            traceQuickRangeButton("今天") {
                setTraceCustomRange(.today)
            }
            traceQuickRangeButton("昨天") {
                setTraceCustomRange(.yesterday)
            }
            traceQuickRangeButton("本周") {
                setTraceCustomRange(.thisWeek)
            }
            traceQuickRangeButton("本月") {
                setTraceCustomRange(.thisMonth)
            }
            traceQuickRangeButton("近7天") {
                setTraceCustomRange(.last7Days)
            }
            traceQuickRangeButton("近30天") {
                setTraceCustomRange(.last30Days)
            }
        }
    }

    private func traceQuickRangeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.78))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.52))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private enum TraceCustomRangePreset {
        case today
        case yesterday
        case thisWeek
        case thisMonth
        case last7Days
        case last30Days
    }

    private func setTraceCustomRange(_ preset: TraceCustomRangePreset) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let range: (Date, Date)

        switch preset {
        case .today:
            range = (today, today)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            range = (yesterday, yesterday)
        case .thisWeek:
            let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now)
            range = (interval?.start ?? today, today)
        case .thisMonth:
            let interval = calendar.dateInterval(of: .month, for: now)
            range = (interval?.start ?? today, today)
        case .last7Days:
            range = (calendar.date(byAdding: .day, value: -6, to: today) ?? today, today)
        case .last30Days:
            range = (calendar.date(byAdding: .day, value: -29, to: today) ?? today, today)
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            customStartDate = range.0
            customEndDate = range.1
        }
    }

    private func traceInlineDatePicker(title: String, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            HStack(spacing: 6) {
                traceDateStepButton(systemName: "chevron.left") {
                    shiftTraceDate(selection, by: -1)
                }

                Text(traceCompactDateText(selection.wrappedValue))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity)

                traceDateStepButton(systemName: "chevron.right") {
                    shiftTraceDate(selection, by: 1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.46), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.34))
        )
    }

    private func traceDateStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.86))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(AppColors.accent.opacity(0.09))
                )
        }
        .buttonStyle(.plain)
    }

    private func shiftTraceDate(_ selection: Binding<Date>, by days: Int) {
        let next = Calendar.current.date(byAdding: .day, value: days, to: selection.wrappedValue) ?? selection.wrappedValue
        withAnimation(.easeInOut(duration: 0.16)) {
            selection.wrappedValue = next
        }
    }

    private func traceCompactDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日 \(weekdayText(for: date))"
    }

    private func applyTracePeriod(_ period: StatsPeriod) {
        withAnimation(traceEditSpring) {
            useCustomRange = false
            selectedPeriod = period
            showTraceCustomDatePanel = false
            traceInlineEditingItemID = nil
            traceSwipedItemID = nil
        }
    }

    private func applyTraceCategory(_ category: HomeItem.Category?) {
        withAnimation(traceEditSpring) {
            selectedCategory = category
            traceInlineEditingItemID = nil
            traceSwipedItemID = nil
        }
    }

    private func filterLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(AppColors.subtext)
    }

    private func filterButtonLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.88))
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppColors.subtext.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(filterControlBackground)
        .overlay(filterControlBorder)
    }

    private var filterControlBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
    }

    private var filterControlBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
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
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.thinMaterial)
            )
    }

    private var traceDetailListBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(Color.white.opacity(0.55), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这一段")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text(overviewNarrativeText)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            totalExpenseCard
            trendChart
        }
        .glassPanel(radius: 24, padding: 20)
    }

    private var totalExpenseCard: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("合计")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)
            Spacer()
            Text(totalExpense.formatted(.cny))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.54))
        )
    }

    private var recordListPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一段里的笔笔")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            recordListContent()
        }
        .glassPanel(radius: 24, padding: 20)
    }

    @ViewBuilder
    private func recordListContent(fromTraceDetail: Bool = false) -> some View {
        if filteredItems.isEmpty {
            Text(emptyRecordListText)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.subtext)
        } else {
            ForEach(traceDayGroups) { group in
                traceDayHeader(group)
                    .padding(.top, group.id == traceDayGroups.first?.id ? 0 : 6)

                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    if fromTraceDetail {
                        traceDetailBillRecordRow(item, isFirst: index == 0)
                    } else {
                        Button {
                            openEditor(for: item)
                        } label: {
                            billRecordRow(item, isFirst: index == 0)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private struct TraceDayGroup: Identifiable {
        let id: String
        let date: Date
        let items: [HomeItem]
    }

    private var traceDayGroups: [TraceDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredItems) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        return groups
            .map { day, items in
                TraceDayGroup(
                    id: String(Int(day.timeIntervalSince1970)),
                    date: day,
                    items: items.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func traceDayHeader(_ group: TraceDayGroup) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(traceDayTitle(group.date))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.text.opacity(0.82))
            Text(traceDaySubtitle(group))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.82))
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
        .padding(.horizontal, 2)
    }

    private func traceDayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日 · \(weekdayText(for: date))"
    }

    private func traceDaySubtitle(_ group: TraceDayGroup) -> String {
        let total = group.items.reduce(0) { $0 + $1.amount }
        return "\(group.items.count) 笔 · \(total.formatted(.cny))"
    }

    private func weekdayText(for date: Date) -> String {
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

    private func openEditor(for item: HomeItem, fromTraceDetail: Bool = false) {
        if fromTraceDetail {
            withAnimation(traceEditSpring) {
                traceInlineEditingItemID = item.id
            }
        } else {
            editingItem = item
        }
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
            shareNickname: settingsViewModel.displayName,
            onCompleted: { progress in
                quotaStore.markCompleted(playback.range, isMember: hasMemberAccess, progress: progress)
                if progress >= 0.8 {
                    homeViewModel.markSummaryPlaybackCompleted(playback.range)
                }
                quotaRefreshID = UUID()
            },
            onShowMemberPricing: onShowMemberPricing,
            onOpenWeekly: {
                useCustomRange = false
                selectedPeriod = .week
            },
            onOpenInsight: onOpenInsight,
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
            if !quotaStore.hasCompletedWeekPlaybackEver() {
                return SummaryPlaybackMemberPitch(
                    headline: "这是你的第一段周记。",
                    detail: "下周还想继续这样回看，就可以把每周生活回放长期留住。",
                    cta: "保留每周生活回放"
                )
            }
            if quotaStore.weekRemaining(isMember: false) <= 1 {
                return SummaryPlaybackMemberPitch(
                    headline: "这周的免费回放快用完了。",
                    detail: "会员会让周记和月章持续留下来，不用等下个自然周刷新。",
                    cta: "让回放继续留下"
                )
            }
            return SummaryPlaybackMemberPitch(
                headline: "像不像你的这周？",
                detail: "这类回看会随着记录变多更贴近你。",
                cta: "让账本更懂我"
            )
        case .month:
            if quotaStore.monthRemaining(isMember: false) <= 1 {
                return SummaryPlaybackMemberPitch(
                    headline: "10 次月章已经听到最后一次。",
                    detail: "后面的月份也可以继续被整理出来，形成一段更长的生活脉络。",
                    cta: "继续留下月章"
                )
            }
            return SummaryPlaybackMemberPitch(
                headline: "像不像你的这个月？",
                detail: "会员可以把更多月份继续整理成生活章。",
                cta: "让账本更懂我"
            )
        }
    }

    private func weeklySharePayload(for playback: SummaryPlayback) -> WeeklyShareCardPayload? {
        guard playback.range == .week else { return nil }
        return playbackService.buildWeeklyShareCardPayload(from: homeViewModel.items, summary: playback)
    }

    private var summaryQuotaAlertBinding: Binding<Bool> {
        Binding(
            get: { summaryQuotaMessage != nil },
            set: { if !$0 { summaryQuotaMessage = nil } }
        )
    }

    @ViewBuilder
    private var summaryQuotaAlertActions: some View {
            Button("让回放不中断") {
                let shouldOpenMember = summaryQuotaMessage?.contains("会员") ?? false
                summaryQuotaMessage = nil
                if shouldOpenMember { onShowMemberPricing?() }
            }
            Button("知道了", role: .cancel) {
                summaryQuotaMessage = nil
            }
    }

    // MARK: - Summary Playback Card

    @ViewBuilder
    private var summarySliceCard: some View {
        let _ = quotaRefreshID
        if useCustomRange || selectedPeriod == .year {
            EmptyView()
        } else {
            let range = selectedPeriod == .week ? SummaryPlaybackRange.week : .month
            let preview = buildSummaryPreview(for: range)
            let hasData = preview.count > 0
            let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)
            let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Text(isMonthLocked ? "🔒" : "🎬")
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(range == .week ? "本周回放" : "本月回放")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(summaryCardSubtitle(preview: preview, range: range, hasData: hasData, isMonthLocked: isMonthLocked))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }

                let playbackButtonTitle = isMonthLocked ? "了解会员" : "听听这一段"
                let playbackForeground = canPlay ? Color.white : AppColors.text.opacity(0.72)
                let playbackFill = canPlay ? AppColors.accent : Color.white.opacity(0.64)
                let playbackStroke = canPlay ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.58)

                HStack(spacing: 12) {
                    Button {
                        handleSummaryPlaybackTap(range: range, preview: preview)
                    } label: {
                        Text(playbackButtonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(playbackForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(playbackFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(playbackStroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasData && !isMonthLocked)
                }

                Text(summaryQuotaFootnote(range: range, hasData: hasData))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(range == .month && isMonthLocked ? AppColors.lockGold : AppColors.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .glassPanel(radius: 24, padding: 20)
        }
    }

    private func buildSummaryPreview(for range: SummaryPlaybackRange) -> SummaryPlayback {
        switch range {
        case .week:
            return playbackService.buildWeekSummary(from: homeViewModel.items)
        case .month:
            return playbackService.buildMonthSummary(from: homeViewModel.items)
        }
    }

    private func summaryCardSubtitle(preview: SummaryPlayback, range: SummaryPlaybackRange, hasData: Bool, isMonthLocked: Bool) -> String {
        guard hasData else { return "先留下几笔，这里就能讲出这一段。" }
        if isMonthLocked {
            return "会员专属 · 你的 10 次新用户体验已用完"
        }
        if !preview.teaserLine.isEmpty {
            return preview.teaserLine
        }
        switch range {
        case .week:
            if homeViewModel.items.count >= 5 && !quotaStore.hasCompletedWeekPlaybackEver() {
                return "已记 \(homeViewModel.items.count) 笔，可以讲这周的故事了"
            }
            let category = preview.topCategory.map { "\($0)为主" } ?? "日常为主"
            return "\(preview.count) 笔 · \(preview.total.formatted(.cny)) · \(category)"
        case .month:
            return "\(preview.count) 笔 · \(preview.total.formatted(.cny)) · 分段看完整月节奏"
        }
    }

    private func summaryQuotaFootnote(range: SummaryPlaybackRange, hasData: Bool) -> String {
        guard hasData else { return "回放使用本地模板生成，不依赖 AI 服务。" }
        guard !hasMemberAccess else { return "会员可无限回看周/月回放。" }
        switch range {
        case .week:
            let remaining = quotaStore.weekRemaining(isMember: false)
            return remaining > 0
                ? "本周回放剩余 \(remaining)/\(SummaryPlaybackQuotaStore.weeklyFreeLimit) 次 · 会员可连续回看周/月节奏"
                : "本周回放剩余 0/\(SummaryPlaybackQuotaStore.weeklyFreeLimit) 次 · 下个自然周刷新"
        case .month:
            let remaining = quotaStore.monthRemaining(isMember: false)
            return remaining > 0
                ? "新用户月章剩余 \(remaining)/\(SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit) 次 · 会员可继续整理更多月份"
                : "新用户月章剩余 0/\(SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit) 次 · 会员可继续整理更多月份"
        }
    }

    private func handleSummaryPlaybackTap(range: SummaryPlaybackRange, preview: SummaryPlayback) {
        guard preview.count > 0 else { return }
        guard quotaStore.canPlay(range, isMember: hasMemberAccess) else {
            switch range {
            case .week:
                summaryQuotaMessage = "本周回放剩余 0/3 次。下个自然周会刷新；会员适合想连续回看周/月生活节奏的人。"
            case .month:
                summaryQuotaMessage = "新用户月章剩余 0/10 次。会员可以继续整理更多月份，也让 OCR 和 AI 回顾不被次数打断。本周回放仍会在每个自然周刷新 3 次。"
            }
            return
        }
        let copySeed = nextSummaryCopySeed(for: range)
        summaryPlayback = buildSummaryPlayback(for: range, copySeed: copySeed)
    }

    private func buildSummaryPlayback(for range: SummaryPlaybackRange, copySeed: String) -> SummaryPlayback {
        switch range {
        case .week:
            return playbackService.buildWeekSummary(from: homeViewModel.items, copySeed: copySeed)
        case .month:
            return playbackService.buildMonthSummary(from: homeViewModel.items, copySeed: copySeed)
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

    // MARK: - Period Picker Sheet

    private var periodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("选择时间范围")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(StatsPeriod.allCases) { period in
                    periodOptionButton(period)
                }

                // Custom date range
                customDateRangePicker
            }
            .padding(24)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("时间范围")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showPeriodSheet = false }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func periodOptionButton(_ period: StatsPeriod) -> some View {
        let isSelected = !useCustomRange && selectedPeriod == period
        return Button {
            useCustomRange = false
            selectedPeriod = period
            showPeriodSheet = false
        } label: {
            periodOptionLabel(period, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func periodOptionLabel(_ period: StatsPeriod, isSelected: Bool) -> some View {
        HStack {
            Text(period.rawValue)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .foregroundStyle(AppColors.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(periodOptionBackground(isSelected: isSelected))
    }

    private func periodOptionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.1) : Color.white.opacity(0.62))
    }

    private var customDateRangePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自定义日期")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.text.opacity(0.8))

            HStack(spacing: 8) {
                customDateEndpointButton("开始", date: customStartDate, endpoint: .start)
                customDateEndpointButton("结束", date: customEndDate, endpoint: .end)
            }

            if customDateFocus == .start {
                WarmRecordDatePanel(selection: $customStartDate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                WarmRecordDatePanel(selection: $customEndDate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            applyCustomDateButton
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
    }

    private func customDateEndpointButton(_ title: String, date: Date, endpoint: CustomDateEndpoint) -> some View {
        let isSelected = customDateFocus == endpoint
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                customDateFocus = endpoint
            }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                Spacer(minLength: 4)
                Text(date.zhBillDateOnly)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(customDateEndpointBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func customDateEndpointBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.14) : Color.white.opacity(0.62))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.4), lineWidth: 1)
            )
    }

    private var categoryFilterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("选择分类")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColors.text)

                    Button {
                        selectedCategory = nil
                        showCategoryFilterSheet = false
                    } label: {
                        categorySheetOptionLabel(
                            title: "全部分类",
                            subtitle: "看这一段完整的生活记录",
                            emoji: "✨",
                            isSelected: selectedCategory == nil
                        )
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                        ForEach(HomeItem.Category.allCases) { category in
                            Button {
                                selectedCategory = category
                                showCategoryFilterSheet = false
                            } label: {
                                categorySheetOptionLabel(
                                    title: category.label,
                                    subtitle: category.rawValue,
                                    emoji: category.emoji,
                                    isSelected: selectedCategory == category
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(22)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.bg.ignoresSafeArea())
            .navigationTitle("分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showCategoryFilterSheet = false }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func categorySheetOptionLabel(title: String, subtitle: String, emoji: String, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.56))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
            }

            Spacer(minLength: 4)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(categorySheetOptionBackground(isSelected: isSelected))
    }

    private func categorySheetOptionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.12) : Color.white.opacity(0.66))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.28) : Color.white.opacity(0.46), lineWidth: 1)
            )
    }

    private var applyCustomDateButton: some View {
        Button {
            useCustomRange = true
            showPeriodSheet = false
        } label: {
            Text("应用自定义日期")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Simplified Category Filter Chips (no longer used, replaced by Menu)

    private func billRecordRow(_ item: HomeItem, isFirst: Bool) -> some View {
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

    private func traceDetailBillRecordRow(_ item: HomeItem, isFirst: Bool) -> some View {
        let isEditing = traceInlineEditingItemID == item.id
        let isSwiped = traceSwipedItemID == item.id && !isEditing
        let isDeleting = traceDeletingItemID == item.id
        return ZStack(alignment: .trailing) {
            if !isEditing {
                traceSwipeActions(for: item, isVisible: isSwiped)
                    .padding(.trailing, 10)
                    .zIndex(2)
            }

            VStack(alignment: .leading, spacing: isEditing ? 10 : 8) {
                traceDetailRecordSummary(item, isEditing: isEditing)
                if traceInlineEditingItemID == item.id {
                    TraceInlineRecordEditor(
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
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, isEditing ? 14 : 12)
            .background(traceDetailRecordBackground(isEditing: isEditing))
            .overlay(traceDetailRecordBorder(isEditing: isEditing))
            .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            .offset(x: isSwiped ? -76 : 0)
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
                if !isEditing && !isSwiped {
                    traceSwipeHandle(for: item, isSwiped: isSwiped)
                        .zIndex(3)
                }
            }
        }
        .id(item.id)
        .animation(traceEditSpring, value: isEditing)
        .animation(traceEditSpring, value: isSwiped)
        .animation(.easeInOut(duration: 0.45), value: isDeleting)
    }

    private var traceEditSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.08)
    }

    private func traceDetailRecordSummary(_ item: HomeItem, isEditing: Bool) -> some View {
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

    private func traceDetailRecordBackground(isEditing: Bool) -> some View {
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

    private func traceDetailRecordBorder(isEditing: Bool) -> some View {
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

    private func scrollTraceEditorIntoView(_ itemID: UUID, proxy: ScrollViewProxy, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard traceInlineEditingItemID == itemID else { return }
            withAnimation(traceEditSpring) {
                proxy.scrollTo(itemID, anchor: .center)
            }
        }
    }

    private func traceSwipeActions(for item: HomeItem, isVisible: Bool) -> some View {
        Button(role: .destructive) {
            deleteRecord(item)
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

    private func traceSwipeHandle(for item: HomeItem, isSwiped: Bool) -> some View {
        Color.clear
            .frame(maxWidth: isSwiped ? .infinity : nil)
            .frame(width: isSwiped ? nil : 42)
            .contentShape(Rectangle())
            .gesture(traceRowSwipeGesture(for: item))
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

    private func traceRowSwipeGesture(for item: HomeItem) -> some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                let isHorizontalSwipe = abs(horizontal) > max(44, abs(vertical) * 1.35)
                guard isHorizontalSwipe else { return }
                withAnimation(traceEditSpring) {
                    if horizontal < 0 {
                        traceSwipedItemID = item.id
                    } else {
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

    // MARK: - Trend Chart

    @ViewBuilder
    private var trendChart: some View {
        let trendData = computeTrendData()
        let activeData = trendData.filter { $0.value > 0 }
        VStack(alignment: .leading, spacing: 6) {
            Text(activeData.count >= 2 ? "一点走势" : "暂时不画走势")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            if trendData.isEmpty {
                Text("这一段还没有能连起来看的记录。")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.subtext)
                    .padding(.vertical, 12)
            } else if activeData.count < 2 {
                traceTrendQuietSummary(activeData.first)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h: CGFloat = 48
                    let maxVal = trendData.map(\.value).max() ?? 1
                    let padding: CGFloat = 8
                    let chartW = w - padding * 2
                    let chartH = h - padding * 2

                    ZStack(alignment: .topLeading) {
                        // Y axis
                        Path { p in
                            p.move(to: CGPoint(x: padding, y: padding))
                            p.addLine(to: CGPoint(x: padding, y: h - padding))
                        }
                        .stroke(AppColors.subtext.opacity(0.3), lineWidth: 1)

                        // X axis
                        Path { p in
                            p.move(to: CGPoint(x: padding, y: h - padding))
                            p.addLine(to: CGPoint(x: w - padding, y: h - padding))
                        }
                        .stroke(AppColors.subtext.opacity(0.3), lineWidth: 1)

                        // Max label
                        Text("\(Int(maxVal))")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.subtext.opacity(0.82))
                            .offset(x: padding + 2, y: 0)

                        // Trend line
                        if trendData.count >= 2 {
                            Path { p in
                                for (i, point) in trendData.enumerated() {
                                    let x = padding + (chartW / CGFloat(max(trendData.count - 1, 1))) * CGFloat(i)
                                    let y = padding + chartH - (CGFloat(point.value) / CGFloat(maxVal)) * chartH
                                    if i == 0 {
                                        p.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        p.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(AppColors.accent.opacity(0.86), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        }

                        // Peak dot
                        if let peak = trendData.max(by: { $0.value < $1.value }),
                           let idx = trendData.firstIndex(where: { $0.id == peak.id }) {
                            let x = padding + (chartW / CGFloat(max(trendData.count - 1, 1))) * CGFloat(idx)
                            let y = padding + chartH - (CGFloat(peak.value) / CGFloat(maxVal)) * chartH
                            Circle()
                                .fill(AppColors.accent.opacity(0.86))
                                .frame(width: 6, height: 6)
                                .position(x: x, y: y)
                            Text(peak.value.formatted(.cny))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppColors.text.opacity(0.88))
                                .position(x: min(x + 24, w - 30), y: y - 14)
                        }
                    }
                }
                .frame(height: 52)
            }
        }
    }

    private func traceTrendQuietSummary(_ point: TrendPoint?) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(AppColors.accent.opacity(0.68))
                .frame(width: 8, height: 8)
            Text(point.map { "这一段只有 \($0.day) 有记录，先等多几天再看走势。" } ?? "多留下几天，走势会自然出来。")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.text.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.38))
        )
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let day: String
        let value: Double
    }

    private func computeTrendData() -> [TrendPoint] {
        let cal = Calendar.current
        let trendItems = filteredItems.filter { $0.amount > 0 && $0.draftMeta == nil }
        guard !trendItems.isEmpty else { return [] }

        if !useCustomRange, selectedPeriod == .year {
            let currentYear = cal.component(.year, from: Date())
            let points = (1...12).map { month -> TrendPoint in
                let total = trendItems
                    .filter {
                        cal.component(.year, from: $0.createdAt) == currentYear &&
                        cal.component(.month, from: $0.createdAt) == month
                    }
                    .reduce(0) { $0 + $1.amount }
                return TrendPoint(day: "\(month)月", value: total)
            }
            return points.contains { $0.value > 0 } ? points : []
        }

        guard let interval = trendDateInterval(calendar: cal) else { return [] }
        let startDay = cal.startOfDay(for: interval.start)
        let inclusiveEnd = cal.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        let endDay = cal.startOfDay(for: inclusiveEnd)
        let dayCount = max(cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0, 0)
        let points = (0...dayCount).compactMap { offset -> TrendPoint? in
            guard let date = cal.date(byAdding: .day, value: offset, to: startDay) else { return nil }
            let total = trendItems
                .filter { cal.isDate($0.createdAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.amount }
            return TrendPoint(day: "\(cal.component(.day, from: date))", value: total)
        }
        return points.contains { $0.value > 0 } ? points : []
    }

    private func trendDateInterval(calendar cal: Calendar) -> DateInterval? {
        if useCustomRange {
            let start = cal.startOfDay(for: min(customStartDate, customEndDate))
            let endBase = cal.startOfDay(for: max(customStartDate, customEndDate))
            let end = cal.date(byAdding: .day, value: 1, to: endBase) ?? endBase
            return DateInterval(start: start, end: end)
        }

        switch selectedPeriod {
        case .week:
            return PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: Date())
        case .month:
            guard let month = cal.dateInterval(of: .month, for: Date()) else { return nil }
            return DateInterval(start: month.start, end: min(month.end, Date()))
        case .year:
            return cal.dateInterval(of: .year, for: Date())
        }
    }

    private func trendInsightText(data: [TrendPoint]) -> String {
        let active = data.filter { $0.value > 0 }
        guard let peak = active.max(by: { $0.value < $1.value }) else {
            return "这一段还没有能连起来看的记录。"
        }
        if active.count == 1 {
            return "这一段只有 \(peak.day) 有记录，先不用急着看走势。"
        }
        let firstHalf = data.prefix(max(data.count / 2, 1)).reduce(0) { $0 + $1.value }
        let secondHalf = data.suffix(max(data.count - data.count / 2, 1)).reduce(0) { $0 + $1.value }
        if secondHalf > firstHalf * 1.18 {
            return "这一段后半更密一些。"
        } else if firstHalf > secondHalf * 1.18 {
            return "这一段前半更密一些。"
        }
        return "\(peak.day) 最明显，其余日子比较分散。"
    }
}

private extension View {
    func traceGlassPanel(radius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(TraceColors.surfaceGlass)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(TraceColors.stroke, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color(red: 0.561, green: 0.659, blue: 0.604).opacity(0.06), radius: 14, x: 0, y: 4)
    }

    func traceWarmPanel(radius: CGFloat = 26, padding: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TraceColors.surfaceWarm,
                                Color.white.opacity(0.76),
                                AppColors.paperMist.opacity(0.44)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(AppColors.paperCrease.opacity(0.18))
                    .frame(width: 2)
                    .padding(.vertical, 20)
                    .padding(.leading, 14)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.paperBorder.opacity(0.18), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct TraceInlineRecordEditor: View {
    let item: HomeItem
    var autoCommitRequestID: UUID?
    var onSave: (HomeItem) -> Bool
    var onCancel: () -> Void

    @State private var amountText: String
    @State private var titleText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var validationMessage: String?
    @State private var isCategoryPanelExpanded = false
    @State private var isDatePopoverVisible = false
    @State private var isSpecificDatePanelVisible = false
    @FocusState private var focusedField: InlineEditField?

    private enum InlineEditField {
        case amount
        case title
    }

    init(
        item: HomeItem,
        autoCommitRequestID: UUID? = nil,
        onSave: @escaping (HomeItem) -> Bool,
        onCancel: @escaping () -> Void
    ) {
        self.item = item
        self.autoCommitRequestID = autoCommitRequestID
        self.onSave = onSave
        self.onCancel = onCancel
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _titleText = State(initialValue: item.title)
        _selectedCategory = State(initialValue: item.category)
        _selectedDate = State(initialValue: item.createdAt)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var cleanTitle: String {
        titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                amountField
                categorySelector
            }

            TextField("这一笔想怎么被记住？", text: $titleText)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(inlineFieldChrome)
                .focused($focusedField, equals: .title)
                .onChange(of: titleText) { _, value in
                    if value.count > 32 {
                        titleText = String(value.prefix(32))
                    }
                    validationMessage = nil
                }

            inlineDateSelector

            if isCategoryPanelExpanded {
                categoryGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 94/255, green: 108/255, blue: 119/255))
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("取消") {
                    onCancel()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 82/255, green: 94/255, blue: 104/255))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(inlineSecondaryButtonBackground)

                Button {
                    save()
                } label: {
                    Text("保存")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(
                            AppColors.accent,
                            in: Capsule(style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(parsedAmount <= 0)
                .opacity(parsedAmount <= 0 ? 0.55 : 1)
            }
        }
        .padding(.top, -6)
        .onChange(of: autoCommitRequestID) { _, requestID in
            guard requestID != nil else { return }
            softCommitAndCollapse()
        }
    }

    private var amountField: some View {
        HStack(spacing: 3) {
            Text("¥")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 85/255, green: 99/255, blue: 110/255))
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .focused($focusedField, equals: .amount)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(inlineFieldChrome)
    }

    private var categorySelector: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isDatePopoverVisible = false
                isSpecificDatePanelVisible = false
                isCategoryPanelExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedCategory.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(AppColors.text.opacity(0.92))
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(inlineFieldChrome)
        }
        .buttonStyle(.plain)
    }

    private var inlineDateSelector: some View {
        Button {
            withAnimation(traceInlinePopoverSpring) {
                isCategoryPanelExpanded = false
                isSpecificDatePanelVisible = false
                isDatePopoverVisible.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Text("时间")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 85/255, green: 99/255, blue: 110/255))
                Spacer()
                Text(selectedDate.zhBillDateTime)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 85/255, green: 99/255, blue: 110/255))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(inlineFieldChrome)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if isDatePopoverVisible {
                traceDatePopover
                    .offset(x: -2, y: -118)
                    .zIndex(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
        }
        .zIndex(isDatePopoverVisible ? 20 : 0)
    }

    private var traceDatePopover: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                traceDateQuickButton("今天") {
                    applyQuickDate(.today)
                }
                traceDateQuickButton("昨天") {
                    applyQuickDate(.yesterday)
                }
                traceDateQuickButton("现在") {
                    selectedDate = Date()
                    closeDatePopover()
                }
            }

            Button {
                withAnimation(traceInlinePopoverSpring) {
                    isSpecificDatePanelVisible.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                    Text("具体时间")
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isSpecificDatePanelVisible ? 180 : 0))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.80))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.56))
                )
            }
            .buttonStyle(.plain)

            if isSpecificDatePanelVisible {
                WarmRecordDatePanel(selection: $selectedDate)
                    .frame(width: 250)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
            }
        }
        .padding(10)
        .frame(width: isSpecificDatePanelVisible ? 274 : 238, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(AppColors.paperWarm.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: AppColors.subtext.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    private func traceDateQuickButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.text.opacity(0.82))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.62))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(AppColors.accent.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private enum TraceQuickDate {
        case today
        case yesterday
    }

    private func applyQuickDate(_ quickDate: TraceQuickDate) {
        let calendar = Calendar.current
        let currentComponents = calendar.dateComponents([.hour, .minute, .second], from: selectedDate)
        let base: Date
        switch quickDate {
        case .today:
            base = Date()
        case .yesterday:
            base = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        }
        let day = calendar.startOfDay(for: base)
        selectedDate = calendar.date(
            bySettingHour: currentComponents.hour ?? calendar.component(.hour, from: Date()),
            minute: currentComponents.minute ?? calendar.component(.minute, from: Date()),
            second: currentComponents.second ?? 0,
            of: day
        ) ?? base
        closeDatePopover()
    }

    private func closeDatePopover() {
        withAnimation(traceInlinePopoverSpring) {
            isDatePopoverVisible = false
            isSpecificDatePanelVisible = false
        }
    }

    private var traceInlinePopoverSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.06)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82, maximum: 128), spacing: 8)], spacing: 8) {
            ForEach(HomeItem.Category.allCases) { category in
                categoryGridButton(category)
            }
        }
    }

    private func categoryGridButton(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            withAnimation(.easeInOut(duration: 0.18)) {
                isCategoryPanelExpanded = false
            }
        } label: {
            Text(category.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.text : AppColors.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(categoryGridButtonBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    private func categoryGridButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? AppColors.accent.opacity(0.18) : Color.white.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? AppColors.accent.opacity(0.34) : Color.white.opacity(0.38), lineWidth: 1)
            )
    }

    private var inlineFieldChrome: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.74))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.86), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.accent.opacity(0.28))
                    .frame(height: 1)
                    .padding(.horizontal, 10)
            }
    }

    private var inlineSecondaryButtonBackground: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.76))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.80), lineWidth: 1)
            )
            .shadow(color: AppColors.subtext.opacity(0.07), radius: 7, x: 0, y: 3)
    }

    private func save() {
        var updated = item
        updated.amount = parsedAmount
        updated.title = cleanTitle.isEmpty ? selectedCategory.defaultRecordTitle : cleanTitle
        updated.category = selectedCategory
        updated.createdAt = selectedDate
        updated.updatedAt = Date()
        if !onSave(updated) {
            validationMessage = "这句备注里可能有隐私信息，先改成更简单的记录。"
        }
    }

    private func softCommitAndCollapse() {
        focusedField = nil
        guard parsedAmount > 0 else {
            validationMessage = "金额先留在这里，补完整再收起。"
            return
        }
        save()
    }
}
