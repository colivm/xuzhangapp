import PhotosUI
import SwiftUI

// MARK: - Stats View (matching web statsPage)

private struct SummaryQuotaPrompt: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let primaryTitle: String
    let opensMember: Bool
}

struct StatsWebView: View {

    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @Environment(\.appTheme) private var appTheme
    var openTraceRequestID: UUID? = nil
    var onShowMemberPricing: ((MemberPricingEntryContext) -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil
    var onAttachMemoryImage: ((HomeItem) -> Void)? = nil

    @State var selectedPeriod: StatsPeriod = .week
    @State var selectedCategory: HomeItem.Category? = nil
    @State private var editingItem: HomeItem?
    @State private var memoryDetailItem: HomeItem?
    @State private var summaryPlayback: SummaryPlayback?
    @State private var summaryQuotaPrompt: SummaryQuotaPrompt?
    @State private var quotaRefreshID = UUID()
    @State var isFiltersExpanded = false
    @State private var showTraceDetailSheet = false
    @State var showCategoryFilterSheet = false
    @State var traceInlineEditingItemID: UUID?
    @State private var handledOpenTraceRequestID: UUID?
    @State var traceSwipedItemID: UUID?
    @State private var traceDeletingItemID: UUID?
    @State private var tracePendingDeleteItem: HomeItem?
    @State private var showTraceDeleteConfirmation = false
    @State private var traceAutoCommitRequestID: UUID?
    @GestureState private var traceSwipeDragState: TraceSwipeDragState?
    @State var showTraceCustomDatePanel = false
    @State private var traceViewMode: TraceViewMode = .life
    @State private var traceDeepInsightExpanded = false
    @State private var traceInsightFocusedQuestion: String?
    @State private var lifeInsightRefreshID = UUID()
    private let playbackService = PlaybackService()
    private let momentSelector = PlaybackMomentSelector()
    private let quotaStore = SummaryPlaybackQuotaStore()
    private let lifeInsightService = LifeInsightService.shared
    private static var traceChapterSnapshotCache: [String: TraceChapterSnapshot] = [:]
    private static var traceChapterSnapshotCacheOrder: [String] = []
    private static let traceChapterSnapshotCacheLimit = 8
    private static var traceClueSnapshotCache: [String: TraceClueSnapshot] = [:]
    private static var traceClueSnapshotCacheOrder: [String] = []
    private static let traceClueSnapshotCacheLimit = 24

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
        return filteredItems.first { $0.id == traceInlineEditingItemID }
    }

    private var traceFilteredItemIDs: [UUID] {
        filteredItems.map(\.id)
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

    var currentFilterSummary: String {
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

    @State var showPeriodSheet = false
    @State var customStartDate = Date()
    @State var customEndDate = Date()
    @State var customDateFocus: CustomDateEndpoint = .start
    @State var useCustomRange = false

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
            .sheet(item: $memoryDetailItem) { item in
                memoryRecordDetailSheet(for: item)
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
        ScrollView {
            statsContent
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(traceSwipeDragState != nil)
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

    private func representativeTraceItems(
        from items: [HomeItem],
        maxItems: Int,
        maxPerCategory: Int
    ) -> [HomeItem] {
        guard maxItems > 0 else { return [] }
        let ranked = Array(items.enumerated()).sorted { lhs, rhs in
            let leftScore = traceRepresentativeScore(item: lhs.element, index: lhs.offset)
            let rightScore = traceRepresentativeScore(item: rhs.element, index: rhs.offset)
            if leftScore == rightScore {
                return lhs.element.createdAt > rhs.element.createdAt
            }
            return leftScore > rightScore
        }

        var selected: [HomeItem] = []
        var categoryCounts: [String: Int] = [:]
        for candidate in ranked where selected.count < maxItems {
            let categoryKey = candidate.element.category.rawValue
            let count = categoryCounts[categoryKey, default: 0]
            guard count < maxPerCategory else { continue }
            selected.append(candidate.element)
            categoryCounts[categoryKey] = count + 1
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

    private var traceChapterCard: some View {
        let _ = quotaRefreshID
        let snapshot = buildTraceChapterSnapshot()
        let range = snapshot.range
        let hasData = !snapshot.items.isEmpty
        let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0
        let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)

        return VStack(alignment: .leading, spacing: 14) {
            traceRangeKicker

            traceLifeMarkPillRow(snapshot.marks)

            Text(snapshot.narrative)
                .font(.system(size: 16, weight: .medium))
                .lineSpacing(5)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            if let chapterSummary = snapshot.chapterSummary {
                Text(chapterSummary)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                handleSummaryPlaybackTap(range: range, hasData: hasData)
            } label: {
                tracePlaybackLaunchCard(
                    title: isMonthLocked ? "了解会员" : "听听这一段",
                    subtitle: playbackLaunchSubtitle(
                        range: range,
                        preview: snapshot.preview,
                        hasData: hasData,
                        isMonthLocked: isMonthLocked,
                        primaryMark: snapshot.marks.first
                    ),
                    systemImage: isMonthLocked ? "lock.fill" : "play.fill",
                    isEnabled: canPlay || isMonthLocked
                )
            }
            .buttonStyle(PurposefulCardButtonStyle(radius: 18, depth: 1.05))
            .disabled(!hasData && !isMonthLocked)

            Text(summaryQuotaFootnote(range: range, hasData: hasData))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.top, -4)

            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snapshot.evidenceGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.markLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.subtext.opacity(0.86))

                            ForEach(group.items) { item in
                                Button {
                                    openEditor(for: item)
                                } label: {
                                    traceSlipRow(item)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(PurposefulCardButtonStyle(radius: 12, depth: 0.55))
                            }

                            if group.overflowCount > 0 {
                                Button {
                                    openTraceDetail()
                                } label: {
                                    Text("还有 \(group.overflowCount) 笔同类 · 细查")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AppColors.tertiary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.top, 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .traceSurface(radius: 16, padding: 8)
            } else {
                traceEmptyState
            }
        }
        .paperChapterPanel(radius: 24, padding: 20)
    }

    private func buildTraceChapterSnapshot() -> TraceChapterSnapshot {
        let range = heroRange
        let items = heroScopedItems
        let cacheKey = traceChapterSnapshotCacheKey(items: items, range: range)
        if let cached = Self.traceChapterSnapshotCache[cacheKey] {
            return cached
        }

        let marks = traceLifeMarks(from: items, limit: 2)
        let snapshot = TraceChapterSnapshot(
            range: range,
            items: items,
            marks: marks,
            narrative: heroNarrativeText(from: items, marks: marks),
            chapterSummary: traceChapterSummary(from: items, marks: marks),
            evidenceGroups: traceMarkEvidenceGroups(from: items, marks: marks, maxItems: 3),
            preview: buildSummaryLaunchPreview(for: range, items: items)
        )
        storeTraceChapterSnapshot(snapshot, for: cacheKey)
        return snapshot
    }

    private func traceChapterSnapshotCacheKey(items: [HomeItem], range: SummaryPlaybackRange) -> String {
        [
            range.rawValue,
            selectedPeriod.rawValue,
            useCustomRange ? "custom" : "preset",
            "\(Int(customStartDate.timeIntervalSince1970))",
            "\(Int(customEndDate.timeIntervalSince1970))",
            selectedCategory?.rawValue ?? "all",
            hasMemberAccess ? "member" : "free",
            traceItemsSignature(items),
            traceItemsSignature(homeViewModel.items)
        ].joined(separator: "|")
    }

    private func storeTraceChapterSnapshot(_ snapshot: TraceChapterSnapshot, for key: String) {
        guard Self.traceChapterSnapshotCache[key] == nil else {
            return
        }
        Self.traceChapterSnapshotCache[key] = snapshot
        Self.traceChapterSnapshotCacheOrder.append(key)
        while Self.traceChapterSnapshotCacheOrder.count > Self.traceChapterSnapshotCacheLimit {
            let staleKey = Self.traceChapterSnapshotCacheOrder.removeFirst()
            Self.traceChapterSnapshotCache.removeValue(forKey: staleKey)
        }
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

        let fallbackItems = representativeTraceItems(from: sortedItems, maxItems: maxItems, maxPerCategory: 2)
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
            return "本月章节需要会员继续回看。"
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
            traceViewMode = mode
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
        _ = lifeInsightRefreshID
        return lifeInsightService.buildTraceInsight(
            items: items,
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

    private var traceLockedLifeMarkPreview: LifeMarkAggregate? {
        guard !hasMemberAccess else { return nil }
        return LifeMarkService.lockedPreview(for: traceClueItems, allItems: homeViewModel.items)
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

    private var traceClueInsightLines: [String] {
        traceClueInsightLines(
            items: traceClueItems,
            clues: traceCategoryClues,
            rhythmPoints: traceRhythmPoints,
            marks: traceLifeMarks,
            lockedPreview: traceLockedLifeMarkPreview
        )
    }

    private func traceClueInsightLines(
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint],
        marks: [LifeMarkAggregate],
        lockedPreview: LifeMarkAggregate?
    ) -> [String] {
        guard !items.isEmpty else {
            return [
                "先记几笔，不用急着总结。",
                "等同类事情出现两三次，这里会把它们串起来。",
                "我会优先看日期、场景和你写过的备注。"
            ]
        }
        var lines: [String] = []
        if let contextLine = traceContextualMemoryLine(from: items) {
            lines.append(contextLine)
        }
        if let mark = marks.first {
            lines.append(LifeMarkService.primaryLine(for: mark))
        } else if let locked = lockedPreview, !hasMemberAccess {
            lines.append("这段里还有「\(locked.label)」这类深层印记。会员会按账本里已有的日期、分类、备注和上下文线索整理，不额外编造。")
        }
        if let top = clues.first {
            let percent = Int((top.ratio * 100).rounded())
            lines.append("\(top.category.rawValue)出现 \(top.count) 笔，占这一段 \(percent)%。这是最先浮出来的一面。")
        }
        if let peak = rhythmPoints.max(by: { $0.count < $1.count }), peak.count > 0 {
            lines.append("\(traceRhythmNarrativeLabel(peak))记录最集中，适合回头看\(traceRhythmPeriodReference)具体发生了什么。")
        }
        let total = items.reduce(0) { $0 + $1.amount }
        if items.count >= 2 {
            let average = total / Double(items.count)
            lines.append("这一段共 \(items.count) 笔，平均约 \(average.formatted(.cny))。先看原因，不急着评判金额。")
        } else {
            lines.append("现在只有一笔，先把这个瞬间留住就好。")
        }
        return Array(lines.prefix(3))
    }

    private func traceContextualMemoryLine(from items: [HomeItem]) -> String? {
        let sorted = items.sorted { $0.createdAt > $1.createdAt }
        if let item = sorted.first(where: { $0.category == .transport && $0.memoryContext?.weatherKind == "rain" }) {
            if let city = item.memoryContext?.cityName, item.memoryContext?.semanticPlace == "外地" {
                return "\(city)那次雨天出行有天气和地点信息。"
            }
            return "这段里有一次雨天出行，那笔交通记录带着当天的天气。"
        }
        if let item = sorted.first(where: { $0.memoryContext?.semanticPlace == "外地" }),
           let city = item.memoryContext?.cityName {
            return "有一笔记录留在\(city)。城市变了，这段生活的背景也变了。"
        }
        if let item = sorted.first(where: { $0.memoryContext?.weatherKind == "rain" }) {
            return "\(item.createdAt.zhBillDateTime)那天有雨。这笔记录把天气也一起留下来了。"
        }
        return nil
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

    private var traceClueBoard: some View {
        let snapshot = buildTraceClueSnapshot()
        return VStack(spacing: 16) {
            traceClueHeroCard(
                items: snapshot.items,
                clues: snapshot.clues,
                rhythmPoints: snapshot.rhythmPoints,
                marks: snapshot.marks
            )
            traceClueCompositionCard(items: snapshot.items, clues: snapshot.clues)
            traceLifeMarkCard(marks: snapshot.marks, lockedPreview: snapshot.lockedMark)
            traceClueRhythmCard(rhythmPoints: snapshot.rhythmPoints)
            traceClueInsightCard(
                items: snapshot.items,
                clues: snapshot.clues,
                rhythmPoints: snapshot.rhythmPoints,
                marks: snapshot.marks,
                lockedPreview: snapshot.lockedMark
            )
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
        if let cached = Self.traceClueSnapshotCache[cacheKey] {
            return cached
        }

        let clues = traceCategoryClues(from: items)
        let rhythmPoints = traceRhythmPoints(from: items)
        let insight = traceLifeInsight(from: items)
        let marks = traceLifeMarks(from: items, limit: 6)
        let lockedMark = hasMemberAccess ? nil : LifeMarkService.lockedPreview(for: items, allItems: homeViewModel.items)
        let unlockKey = traceInsightUnlockKey(from: items)
        let freeRemaining = lifeInsightService.freeRemaining(isMember: hasMemberAccess)
        let isUnlocked = lifeInsightService.hasUnlockedTrace(unlockKey, isMember: hasMemberAccess)
        let canUse = !items.isEmpty && (isUnlocked || freeRemaining > 0)
        let snapshot = TraceClueSnapshot(
            items: items,
            clues: clues,
            rhythmPoints: rhythmPoints,
            insight: insight,
            marks: marks,
            lockedMark: lockedMark,
            isDeepInsightUnlocked: isUnlocked,
            canUseDeepInsight: canUse,
            freeInsightRemaining: freeRemaining
        )
        storeTraceClueSnapshot(snapshot, for: cacheKey)
        return snapshot
    }

    private func traceClueSnapshotCacheKey(items: [HomeItem]) -> String {
        [
            selectedPeriod.rawValue,
            useCustomRange ? "custom" : "preset",
            "\(Int(customStartDate.timeIntervalSince1970))",
            "\(Int(customEndDate.timeIntervalSince1970))",
            selectedCategory?.rawValue ?? "all",
            hasMemberAccess ? "member" : "free",
            lifeInsightRefreshID.uuidString,
            traceItemsSignature(items),
            traceItemsSignature(homeViewModel.items)
        ].joined(separator: "|")
    }

    private func traceItemsSignature(_ items: [HomeItem]) -> String {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.createdAt.timeIntervalSince1970)
            hasher.combine(item.updatedAt.timeIntervalSince1970)
            hasher.combine(item.amount)
            hasher.combine(item.category.rawValue)
            hasher.combine(item.title)
            hasher.combine(item.emotionTag)
            hasher.combine(item.source.rawValue)
            hasher.combine(item.draftMeta?.status.rawValue)
            hasher.combine(item.memoryContext?.weatherKind)
            hasher.combine(item.memoryContext?.cityName)
            hasher.combine(item.memoryContext?.semanticPlace)
            hasher.combine(item.scenePackId)
        }
        return "\(hasher.finalize())"
    }

    private func storeTraceClueSnapshot(_ snapshot: TraceClueSnapshot, for key: String) {
        guard Self.traceClueSnapshotCache[key] == nil else {
            return
        }
        Self.traceClueSnapshotCache[key] = snapshot
        Self.traceClueSnapshotCacheOrder.append(key)
        while Self.traceClueSnapshotCacheOrder.count > Self.traceClueSnapshotCacheLimit {
            let staleKey = Self.traceClueSnapshotCacheOrder.removeFirst()
            Self.traceClueSnapshotCache.removeValue(forKey: staleKey)
        }
    }

    private func traceClueHeroCard(
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint],
        marks: [LifeMarkAggregate]
    ) -> some View {
        return VStack(alignment: .leading, spacing: 16) {
            traceRangeKicker

            VStack(alignment: .leading, spacing: 8) {
                Text(traceClueHeadline(items: items, clues: clues, marks: marks))
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(TraceColors.primaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text(traceClueSubline(items: items, clues: clues, rhythmPoints: rhythmPoints, marks: marks))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TraceColors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

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
                Text("生活印记")
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

    private func traceClueRhythmCard(rhythmPoints: [TraceRhythmPoint]) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(selectedPeriod == .week ? "一周节奏" : "这一月的节奏")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TraceColors.primaryText)
                Spacer()
                Text(traceRhythmSummary(rhythmPoints: rhythmPoints))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TraceColors.tertiaryText)
            }

            if rhythmPoints.isEmpty {
                traceQuietCluePlaceholder("多记几天，节奏会自然出来。")
            } else {
                let maxCount = max(rhythmPoints.map(\.count).max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 9) {
                    ForEach(rhythmPoints) { point in
                        traceRhythmColumn(point, maxCount: maxCount)
                    }
                }
                .frame(height: 92)
                .padding(.top, 2)
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
    }

    private func traceClueInsightCard(
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint],
        marks: [LifeMarkAggregate],
        lockedPreview: LifeMarkAggregate?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("变化线索")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TraceColors.primaryText)

            VStack(spacing: 10) {
                ForEach(Array(traceClueInsightLines(
                    items: items,
                    clues: clues,
                    rhythmPoints: rhythmPoints,
                    marks: marks,
                    lockedPreview: lockedPreview
                ).enumerated()), id: \.offset) { index, line in
                    traceClueInsightRow(line, index: index)
                }
            }
        }
        .traceGlassPanel(radius: 20, padding: 18)
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
                    Text(hasMemberAccess ? "把这些记录连成一段生活" : "本月还可展开 \(freeRemaining)/\(LifeInsightService.freeMonthlyLimit) 次")
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
                    traceFocusedInsightAnswer(
                        question: focusedQuestion,
                        insight: insight,
                        items: items,
                        clues: clues,
                        rhythmPoints: rhythmPoints
                    )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Button {
                handleTraceDeepInsightTap()
            } label: {
                let buttonIsOpen = hasMemberAccess || snapshotCanUse || isUnlocked
                if buttonIsOpen {
                    HStack(spacing: 8) {
                        Text(traceDeepInsightButtonTitle(isUnlocked: isUnlocked, canUse: snapshotCanUse, hasData: !items.isEmpty))
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
                        Text(traceDeepInsightButtonTitle(isUnlocked: isUnlocked, canUse: snapshotCanUse, hasData: !items.isEmpty))
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
            .disabled(items.isEmpty)
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

    private func traceFocusedInsightAnswer(
        question: String,
        insight: LifeInsightResult,
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TraceColors.primaryText)
                .lineLimit(2)

            Text(traceInsightAnswer(for: question, insight: insight, items: items, clues: clues, rhythmPoints: rhythmPoints))
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

    private func traceDeepInsightButtonTitle(isUnlocked: Bool, canUse: Bool, hasData: Bool) -> String {
        if !hasData { return "先留下几笔" }
        if hasMemberAccess { return "展开这段生活" }
        if isUnlocked { return "再看一个角度" }
        if canUse { return "试一次多看一层" }
        return "解锁完整解读"
    }

    private func handleTraceDeepInsightTap() {
        guard hasTraceInsightData else { return }
        if hasUnlockedTraceDeepInsight {
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
            onShowMemberPricing?(.traceDeepInsight)
            return
        }

        lifeInsightService.markDeepInsightUsed(isMember: false)
        lifeInsightService.markTraceUnlocked(traceInsightUnlockKey, isMember: false)
        withAnimation(traceEditSpring) {
            traceDeepInsightExpanded = true
            focusNextTraceInsightQuestion()
            lifeInsightRefreshID = UUID()
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

    private func traceInsightAnswer(
        for question: String,
        insight: LifeInsightResult,
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint]
    ) -> String {
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
                    return "\(first.category.rawValue)和\(second.category.rawValue)在 \(overlapDays) 天里同时出现。它们可能不是两件散事，而是同一天的外出、工作节奏或集中补给带出来的。"
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

        if question.contains("为什么") {
            if let top = clues.first {
                return traceWhyCategoryBecameVisible(top, items: items, clues: clues, rhythmPoints: rhythmPoints)
            }
            return insight.previewLine
        }

        return insight.previewLine
    }

    private func traceWhyCategoryBecameVisible(
        _ clue: TraceCategoryClue,
        items: [HomeItem],
        clues: [TraceCategoryClue],
        rhythmPoints: [TraceRhythmPoint]
    ) -> String {
        let categoryItems = items.filter { $0.category == clue.category }
        let peak = rhythmPoints.max(by: { $0.count < $1.count })
        let second = clues.dropFirst().first
        let categoryName = traceCategoryLifeName(for: clue.category, items: categoryItems)
        let base: String
        switch clue.category {
        case .dining:
            base = "「\(categoryName)」变明显，通常不是某一顿特别贵，而是饭点、外卖、咖啡这些小节点把这段日子撑了起来。"
        case .transport:
            base = "「\(categoryName)」变明显，往往说明你在移动：通勤、办事、见人、往返变多了。看的不是车费，是这段时间你去了哪些地方。"
        case .health:
            base = "「\(categoryName)」变明显，主要来自健身、看诊、买药或恢复相关记录。"
        case .shopping, .daily:
            base = "「\(categoryName)」变明显，主要来自买菜、家用、网购或兴趣装备。"
        case .entertainment:
            base = "「\(categoryName)」变明显，娱乐相关记录在这段时间更多。"
        case .home:
            base = "「\(categoryName)」变明显，主要来自修补、布置或家用安排。"
        case .social:
            base = "「\(categoryName)」变明显，主要来自见面、送礼或人情往来。"
        case .lodging:
            base = "「\(categoryName)」变明显，说明这段时间有停留和位置变化，可能是旅行、出差，或临时过夜。"
        case .other:
            base = "这类记录变明显，说明有些记录还没归进固定分类。可以回头看备注。"
        }

        var tails: [String] = []
        if let peak, peak.count > 0 {
            tails.append("\(traceRhythmNarrativeLabel(peak))最集中，原因很可能就在\(traceRhythmPeriodReference)的安排里。")
        }
        if let second {
            tails.append("它还和「\(second.category.rawValue)」一起靠前，可能是同一段生活带出来的两种记录。")
        }
        return ([base] + tails).joined(separator: " ")
    }

    private func traceCategoryLifeName(for category: HomeItem.Category, items: [HomeItem]) -> String {
        let text = items.map { "\($0.title) \($0.emotionTag)" }.joined(separator: " ")
        switch category {
        case .transport:
            return traceContainsAny(text, ["通勤", "上班", "下班", "地铁", "公交"]) ? "通勤交通" : "交通"
        case .health:
            return traceContainsAny(text, ["健身", "运动", "跑步", "瑜伽", "私教", "游泳", "理疗", "恢复"]) ? "健身恢复" : "看病买药"
        case .dining:
            return traceContainsAny(text, ["咖啡", "奶茶"]) ? "饭点饮品" : "饭点外卖"
        case .shopping:
            return traceContainsAny(text, ["渔具", "鱼竿", "路亚", "露营", "骑行", "摄影", "相机", "镜头", "模型", "手办", "乐器", "茶具", "咖啡器具"]) ? "兴趣装备" : "网购添置"
        case .daily:
            return traceContainsAny(text, ["买菜", "生鲜", "盒马", "叮咚", "小象", "京东到家", "朴朴"]) ? "超市买菜" : "家用补货"
        default:
            return category.rawValue
        }
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

    private func traceRhythmColumn(_ point: TraceRhythmPoint, maxCount: Int) -> some View {
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

                        traceDetailFocusedList
                        }
                        .padding(18)
                        .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(traceSwipeDragState != nil || traceInlineEditingItemID != nil)
                .onChange(of: traceFilteredItemIDs) { _, itemIDs in
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
                    Button("关闭") { showTraceDetailSheet = false }
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

    private var traceDetailFocusedList: some View {
        let isFocusing = traceInlineEditingItem != nil
        return VStack(alignment: .leading, spacing: 12) {
            recordListContent(fromTraceDetail: true)
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
                let didAttach = homeViewModel.attachMemoryImages(imageDatas, to: item.id)
                if didAttach {
                    openMemoryDetailAfterImageAttach(for: item, fromInlineEditor: true)
                }
                return didAttach
            }
        )
    }

    private var traceDetailMetaText: String {
        "\(currentFilterSummary) · \(filteredItems.count) 笔 · 合计 \(totalExpense.formatted(.cny))"
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
            let groups = traceDayGroups
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

    private func openEditor(for item: HomeItem, fromTraceDetail: Bool = false) {
        if item.hasMemoryImages {
            traceSwipedItemID = nil
            traceInlineEditingItemID = nil
            if showTraceDetailSheet || fromTraceDetail {
                showTraceDetailSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                    memoryDetailItem = latestItem(matching: item)
                }
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
        editingItem = nil
        let delay: TimeInterval
        if showTraceDetailSheet {
            showTraceDetailSheet = false
            delay = 0.42
        } else {
            delay = 0.35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            memoryDetailItem = latestItem(matching: item)
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
                memoryDetailItem = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    requestAttachMemoryImage(current)
                }
            },
            onRemoveImage: { imageIndex in
                if homeViewModel.removeMemoryImage(at: imageIndex, from: current.id) {
                    memoryDetailItem = nil
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
            let didAttach = homeViewModel.attachMemoryImages(imageDatas, to: item.id)
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
            shareNickname: settingsViewModel.displayName,
            shareCardTheme: settingsViewModel.shareCardUsesAppTheme && settingsViewModel.settings.hasMemberAccess
                ? .appTheme(appTheme)
                : .journal,
            onCompleted: { progress in
                quotaStore.markCompleted(playback.range, isMember: hasMemberAccess, progress: progress)
                if progress >= 0.8 {
                    homeViewModel.markSummaryPlaybackCompleted(playback.range)
                }
                quotaRefreshID = UUID()
            },
            onShowMemberPricing: {
                onShowMemberPricing?(.playbackQuota)
            },
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
                    headline: "这是本周回放的首听。",
                    detail: "这次免费已经能看到本周的基本记录。之后会员会继续整理情绪标签、生活印记和反复出现的场景。",
                    cta: "保留每周生活回放"
                )
            }
            if quotaStore.weekRemaining(isMember: false) <= 1 {
                return SummaryPlaybackMemberPitch(
                    headline: "本周免费回放快用完了。",
                    detail: "这次免费已经生成本周回看。会员可以继续整理周记、月章和生活印记。",
                    cta: "让回放继续留下来"
                )
            }
            return SummaryPlaybackMemberPitch(
                headline: "本周回放已完成",
                detail: "这次免费会先保留基础回看。会员可以继续整理情绪标签、生活印记和反复出现的场景。",
                cta: "继续整理周/月回放"
            )
        case .month:
            if quotaStore.monthRemaining(isMember: false) <= 1 {
                return SummaryPlaybackMemberPitch(
                    headline: "月章体验快用完了。",
                    detail: "这次免费已经生成月章开头。月章是新用户体验额度，不是每月刷新；会员可以继续整理更多月份。",
                    cta: "继续留住月章"
                )
            }
            return SummaryPlaybackMemberPitch(
                headline: "本月回放已完成",
                detail: "这次免费会先保留这一段月章。会员可以继续整理更多月份里的天气、路线、情绪标签和生活印记。",
                cta: "继续整理月度回放"
            )
        }
    }

    private func weeklySharePayload(for playback: SummaryPlayback) -> WeeklyShareCardPayload? {
        guard playback.range == .week else { return nil }
        return playbackService.buildWeeklyShareCardPayload(from: homeViewModel.items, summary: playback)
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
        guard hasData else { return }
        guard quotaStore.canPlay(range, isMember: hasMemberAccess) else {
            switch range {
            case .week:
                summaryQuotaPrompt = SummaryQuotaPrompt(
                    title: "本周回放用完了",
                    message: ExperienceRuleCopy.summaryQuotaExhaustedMessage(range: .week),
                    primaryTitle: "了解连续回放",
                    opensMember: true
                )
            case .month:
                summaryQuotaPrompt = SummaryQuotaPrompt(
                    title: "本月章体验用完了",
                    message: ExperienceRuleCopy.summaryQuotaExhaustedMessage(range: .month),
                    primaryTitle: "继续留住月章",
                    opensMember: true
                )
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

    // MARK: - Simplified Category Filter Chips (no longer used, replaced by Menu)

    @ViewBuilder
    private func billRecordRow(_ item: HomeItem, isFirst: Bool) -> some View {
        if let imageData = item.coverMemoryImageData {
            traceMemoryBillCard(item: item, imageData: imageData)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    traceRecordLeadingMark(item)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.displayTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)

                        traceRecordTagLine(item)

                        if let note = traceRecordNote(item) {
                            Text(note)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.subtext)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(item.amount.formatted(.cny))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(traceListRecordBackground)
            .overlay(traceListRecordBorder)
        }
    }

    private func traceMemoryBillCard(item: HomeItem, imageData: Data) -> some View {
        let accent = traceAccentColor(for: item.category)
        return ZStack(alignment: .bottom) {
            MemoryAttachmentThumbnail(imageData: imageData, height: 92, cornerRadius: 14)
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

            if item.memoryImages.count > 1 {
                Text("\(item.memoryImages.count) 张")
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
            if !item.displayEmotionTag.isEmpty {
                Text("·")
                Text(item.displayEmotionTag)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppColors.accent)
        .lineLimit(1)
    }

    private func traceRecordLeadingMark(_ item: HomeItem) -> some View {
        VStack(spacing: 7) {
            Image(systemName: MemoryAttachmentVisuals.categorySystemImage(item.category))
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(traceAccentColor(for: item.category))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(traceAccentColor(for: item.category).opacity(0.14))
                )

            Text(traceRecordTimeText(item.createdAt))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.subtext)
                .lineLimit(1)
        }
        .frame(width: 44)
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
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.74))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 9, y: 3)
    }

    private var traceListRecordBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
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

    var traceEditSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.90, blendDuration: 0.08)
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

            if let imageData = item.coverMemoryImageData {
                traceDetailMemoryStrip(item: item, imageData: imageData)
                    .opacity(isEditing ? 0 : 1)
                    .frame(height: isEditing ? 0 : nil)
            }
        }
    }

    private func traceDetailMemoryStrip(item: HomeItem, imageData: Data) -> some View {
        ZStack(alignment: .bottomLeading) {
            MemoryAttachmentThumbnail(imageData: imageData, height: 78, cornerRadius: 12)
            Text("\(item.memoryImages.count) 张照片")
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

struct FocusedRecordEditor: View {
    let item: HomeItem
    var autoCommitRequestID: UUID?
    var onSave: (HomeItem) -> Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    var onAttachMemoryImage: (() -> Void)?
    var onAttachMemoryImages: (([Data]) -> Bool)?

    @State private var amountText: String
    @State private var noteText: String
    @State private var selectedCategory: HomeItem.Category
    @State private var selectedDate: Date
    @State private var mode: EditorMode = .editing
    @State private var isDatePanelVisible = false
    @State private var validationMessage: String?
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var didAttachMemoryImage = false
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: FocusedField?

    private enum EditorMode {
        case editing
        case categoryPicking
    }

    private enum FocusedField {
        case amount
        case note
    }

    init(
        item: HomeItem,
        autoCommitRequestID: UUID? = nil,
        onSave: @escaping (HomeItem) -> Bool,
        onCancel: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onAttachMemoryImage: (() -> Void)? = nil,
        onAttachMemoryImages: (([Data]) -> Bool)? = nil
    ) {
        self.item = item
        self.autoCommitRequestID = autoCommitRequestID
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        self.onAttachMemoryImage = onAttachMemoryImage
        self.onAttachMemoryImages = onAttachMemoryImages
        _amountText = State(initialValue: String(format: "%.2f", item.amount))
        _noteText = State(initialValue: item.hasMeaningfulTitle ? item.title : "")
        _selectedCategory = State(initialValue: item.category)
        _selectedDate = State(initialValue: item.createdAt)
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    private var cleanNote: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accent: Color {
        AppColors.accent
    }

    private var categoryAccent: Color {
        AppColors.categoryColor(selectedCategory)
    }

    private var draftDisplayTitle: String {
        cleanNote.isEmpty ? "\(selectedCategory.rawValue) \(selectedDate.zhBillTime)" : cleanNote
    }

    var body: some View {
        ZStack {
            if mode == .editing {
                editCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                categoryPickerCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(editorSpring, value: mode)
        .animation(editorSpring, value: isDatePanelVisible)
        .onChange(of: autoCommitRequestID) { _, requestID in
            guard requestID != nil else { return }
            save()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: photoPickerSelectionLimit,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotos) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                var compressedImages: [Data] = []
                for photo in newValue.prefix(photoPickerSelectionLimit) {
                    if let data = try? await photo.loadTransferable(type: Data.self),
                       let compressedData = MemoryImageCompressor.compressedJPEGData(from: data) {
                        compressedImages.append(compressedData)
                    }
                }
                await MainActor.run {
                    selectedPhotos = []
                    guard !compressedImages.isEmpty else { return }
                    if onAttachMemoryImages?(compressedImages) == true {
                        didAttachMemoryImage = true
                    } else {
                        onAttachMemoryImage?()
                    }
                }
            }
        }
        .confirmationDialog(
            "删除这条账单？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后不会保留在账本里。")
        }
    }

    private var editCard: some View {
        VStack(spacing: 0) {
            headerControls

            VStack(spacing: 9) {
                categoryAvatar

                Text(draftDisplayTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                amountEditor

                if !item.displayEmotionTag.isEmpty {
                    Text(item.displayEmotionTag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(accent.opacity(0.12)))
                }

                Text(selectedCategory.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.subtext)
            }
            .padding(.top, 2)
            .padding(.bottom, 22)

            VStack(spacing: 8) {
                editorActionRow(
                    icon: MemoryAttachmentVisuals.categorySystemImage(selectedCategory),
                    title: "分类",
                    value: selectedCategory.rawValue,
                    isAccent: true
                ) {
                    focusedField = nil
                    isDatePanelVisible = false
                    withAnimation(editorSpring) {
                        mode = .categoryPicking
                    }
                }

                noteRow

                editorActionRow(
                    icon: "clock",
                    title: "时间",
                    value: selectedDate.zhBillDateTime,
                    isAccent: false
                ) {
                    focusedField = nil
                    withAnimation(editorSpring) {
                        isDatePanelVisible.toggle()
                    }
                }

                if isDatePanelVisible {
                    WarmRecordDatePanel(selection: $selectedDate)
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.subtext)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }

            Button {
                save()
            } label: {
                Text("保存")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(saveButtonBackground)
            }
            .buttonStyle(.plain)
            .disabled(parsedAmount <= 0)
            .opacity(parsedAmount <= 0 ? 0.54 : 1)
            .padding(.top, 18)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(editorCardBackground)
        .overlay(editorCardBorder)
        .shadow(color: AppColors.subtext.opacity(0.17), radius: 26, x: 0, y: 18)
        .shadow(color: accent.opacity(0.10), radius: 18, x: 0, y: 10)
        .scaleEffect(1.012, anchor: .top)
    }

    private var categoryPickerCard: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(editorSpring) {
                        mode = .editing
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("选择分类")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.bottom, 12)

            VStack(spacing: 2) {
                ForEach(HomeItem.Category.allCases) { category in
                    categoryPickerRow(category)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(editorCardBackground)
        .overlay(editorCardBorder)
        .shadow(color: AppColors.subtext.opacity(0.15), radius: 24, x: 0, y: 15)
        .scaleEffect(1.01, anchor: .top)
    }

    private var headerControls: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
            }
            .buttonStyle(.plain)

            Spacer()

            Capsule(style: .continuous)
                .fill(AppColors.line.opacity(0.55))
                .frame(width: 38, height: 4)
                .opacity(0.74)

            Spacer()

            HStack(spacing: 8) {
                if canAttachMemoryImage {
                    Menu {
                        Button {
                            attachMemoryImage()
                        } label: {
                            Label("补充图片", systemImage: "photo.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("更多")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppColors.panelStrong.opacity(0.76)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canAttachMemoryImage: Bool {
        !item.hasMemoryImages && !didAttachMemoryImage && (onAttachMemoryImages != nil || onAttachMemoryImage != nil)
    }

    private var photoPickerSelectionLimit: Int {
        max(1, 9 - item.memoryImages.count)
    }

    private func attachMemoryImage() {
        if onAttachMemoryImages != nil {
            showPhotoPicker = true
        } else {
            onAttachMemoryImage?()
        }
    }

    private var categoryAvatar: some View {
        ZStack {
            Circle()
                .fill(categoryAccent.opacity(0.14))
                .frame(width: 68, height: 68)
            Circle()
                .fill(AppColors.panelStrong.opacity(0.84))
                .frame(width: 54, height: 54)
                .shadow(color: categoryAccent.opacity(0.14), radius: 12, x: 0, y: 6)
            Image(systemName: MemoryAttachmentVisuals.categorySystemImage(selectedCategory))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(categoryAccent)
        }
        .padding(.top, -2)
    }

    private var amountEditor: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("¥")
                .font(.system(size: 27, weight: .bold, design: .rounded))
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .focused($focusedField, equals: .amount)
                .onChange(of: amountText) { _, value in
                    amountText = sanitizedAmountText(value)
                    validationMessage = nil
                }
                .frame(width: max(94, min(178, CGFloat(amountText.count) * 19 + 42)))
        }
        .foregroundStyle(AppColors.text)
        .padding(.top, 1)
    }

    private var noteRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.subtext)
                .frame(width: 20)

            Text("备注")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.subtext)

            TextField("这一笔想怎么被记住？", text: $noteText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .note)
                .onChange(of: noteText) { _, value in
                    if value.count > 32 {
                        noteText = String(value.prefix(32))
                    }
                    validationMessage = nil
                }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(editorRowBackground)
    }

    private func editorActionRow(
        icon: String,
        title: String,
        value: String,
        isAccent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isAccent ? categoryAccent : AppColors.subtext)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.subtext)

                Spacer(minLength: 12)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(editorRowBackground)
        }
        .buttonStyle(.plain)
    }

    private func categoryPickerRow(_ category: HomeItem.Category) -> some View {
        let isSelected = selectedCategory == category
        let rowAccent = AppColors.categoryColor(category)
        return Button {
            selectedCategory = category
            validationMessage = nil
            withAnimation(editorSpring) {
                mode = .editing
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: MemoryAttachmentVisuals.categorySystemImage(category))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(rowAccent)
                    .frame(width: 28)

                Text(category.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.11) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var editorCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppColors.panelStrong.opacity(0.88))
            )
            .overlay(
                LinearGradient(
                    colors: [
                        AppColors.monthlyInsightBg.opacity(0.52),
                        AppColors.panelStrong.opacity(0.42),
                        accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var editorCardBorder: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        AppColors.panelStrong.opacity(0.68),
                        accent.opacity(0.22),
                        AppColors.stroke.opacity(0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }

    private var editorRowBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppColors.panelStrong.opacity(0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.34), lineWidth: 0.8)
            )
    }

    private var saveButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.92),
                        AppColors.accentDark.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: accent.opacity(0.28), radius: 14, x: 0, y: 7)
    }

    private var editorSpring: Animation {
        .spring(response: 0.34, dampingFraction: 0.90, blendDuration: 0.06)
    }

    private func save() {
        focusedField = nil
        guard parsedAmount > 0 else {
            validationMessage = "金额先留在这里，补完整再保存。"
            return
        }
        var updated = item
        updated.amount = parsedAmount
        updated.title = cleanNote.isEmpty ? selectedCategory.defaultRecordTitle : cleanNote
        updated.category = selectedCategory
        updated.createdAt = selectedDate
        updated.updatedAt = Date()
        if !onSave(updated) {
            validationMessage = "这句备注里可能有隐私信息，先改成更简单的记录。"
        }
    }

    private func sanitizedAmountText(_ value: String) -> String {
        var output = ""
        var hasDecimalPoint = false
        var decimalCount = 0
        for character in value {
            if character == "." {
                guard !hasDecimalPoint else { continue }
                hasDecimalPoint = true
                output.append(character)
            } else if character.isNumber {
                if hasDecimalPoint {
                    guard decimalCount < 2 else { continue }
                    decimalCount += 1
                }
                output.append(character)
            }
        }
        if output.count > 10 {
            output = String(output.prefix(10))
        }
        return output
    }

}
