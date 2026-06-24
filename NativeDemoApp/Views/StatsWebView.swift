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
    var openTraceRequestID: UUID? = nil
    var onShowMemberPricing: ((MemberPricingEntryContext) -> Void)? = nil
    var onOpenInsight: (() -> Void)? = nil

    @State var selectedPeriod: StatsPeriod = .week
    @State var selectedCategory: HomeItem.Category? = nil
    @State private var editingItem: HomeItem?
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
    @State private var traceAutoCommitRequestID: UUID?
    @State var showTraceCustomDatePanel = false
    @State private var traceViewMode: TraceViewMode = .life
    @State private var traceDeepInsightExpanded = false
    @State private var traceInsightFocusedQuestion: String?
    @State private var lifeInsightRefreshID = UUID()
    private let playbackService = PlaybackService()
    private let momentSelector = PlaybackMomentSelector()
    private let quotaStore = SummaryPlaybackQuotaStore()
    private let lifeInsightService = LifeInsightService.shared
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
        let range = heroRange
        let items = heroScopedItems
        let hasData = !items.isEmpty
        let marks = traceLifeMarks(from: items, limit: 2)
        let narrative = heroNarrativeText(from: items, marks: marks)
        let chapterSummary = traceChapterSummary(from: items, marks: marks)
        let evidenceGroups = traceMarkEvidenceGroups(from: items, marks: marks, maxItems: 3)
        let preview = buildSummaryLaunchPreview(for: range, items: items)
        let isMonthLocked = range == .month && !hasMemberAccess && quotaStore.monthRemaining(isMember: false) <= 0
        let canPlay = hasData && quotaStore.canPlay(range, isMember: hasMemberAccess)

        return VStack(alignment: .leading, spacing: 14) {
            traceRangeKicker

            traceLifeMarkPillRow(marks)

            Text(narrative)
                .font(.system(size: 16, weight: .medium))
                .lineSpacing(5)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            if let chapterSummary {
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
                        preview: preview,
                        hasData: hasData,
                        isMonthLocked: isMonthLocked,
                        primaryMark: marks.first
                    ),
                    systemImage: isMonthLocked ? "lock.fill" : "play.fill",
                    isEnabled: canPlay || isMonthLocked
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasData && !isMonthLocked)

            Text(summaryQuotaFootnote(range: range, hasData: hasData))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.subtext.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.top, -4)

            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(evidenceGroups) { group in
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
                                .buttonStyle(.plain)
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

    private func traceLifeMarks(from items: [HomeItem], limit: Int) -> [LifeMarkAggregate] {
        LifeMarkService.aggregates(
            for: items,
            allItems: homeViewModel.items,
            isMember: hasMemberAccess,
            limit: limit
        )
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.tracePlaybackButtonBg.opacity(isEnabled ? 0.92 : 0.46))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.accent.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
        )
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
        LifeMarkService.aggregates(
            for: traceClueItems,
            allItems: homeViewModel.items,
            isMember: hasMemberAccess,
            limit: 6
        )
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
        guard !items.isEmpty else { return "先留下几笔，账本会把生活里的走向慢慢标出来。" }
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
                return "\(city)那次雨天出行被记下来了。以后再看，会知道那天是在外地路上。"
            }
            return "这段里有一次雨天出行。那笔交通不是孤零零的金额，也带着当天的天气。"
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
        let marks = LifeMarkService.aggregates(
            for: items,
            allItems: homeViewModel.items,
            isMember: hasMemberAccess,
            limit: 6
        )
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
                Text("先留下几笔，线索会慢慢浮出来。")
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
                return "\(first.category.rawValue)和\(second.category.rawValue)都靠前，但不太落在同一天。它们更像这段时间同时存在的两件事。"
            }
            return insight.previewLine
        }

        if question.contains("重复") || question.contains("习惯") || question.contains("好几次") {
            if let top = clues.first {
                return "\(top.category.rawValue)出现 \(top.count) 笔，是这一段最稳定的重复项。它不一定是问题，更像这段时间经常发生的一件事。"
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
            base = "「\(categoryName)」变明显，更像你把身体放回了日程里：健身、看诊、买药或恢复，都不只是消费。"
        case .shopping, .daily:
            base = "「\(categoryName)」变明显，像是在给生活补库存：买菜、家用、网购和兴趣装备一起冒出来。"
        case .entertainment:
            base = "「\(categoryName)」变明显，说明这段时间你给自己留了松动空间。它不一定是浪费，也可能是在给压力找出口。"
        case .home:
            base = "「\(categoryName)」变明显，像是注意力回到住处：修补、布置、家用安排开始占据生活。"
        case .social:
            base = "「\(categoryName)」变明显，背后通常是关系在发生：见面、送礼、人情往来，比金额本身更重要。"
        case .lodging:
            base = "「\(categoryName)」变明显，说明这段时间有停留和位置变化，可能是旅行、出差，或临时过夜。"
        case .other:
            base = "这类记录变明显，说明有些事还没被归进固定分类。回头看看备注，里面可能藏着真正的主题。"
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
                    headline: "这是你的第一段周记。",
                    detail: "之后每周都可以把情绪标签、生活印记和反复出现的场景继续接上，不只看金额。",
                    cta: "保留每周生活回放"
                )
            }
            if quotaStore.weekRemaining(isMember: false) <= 1 {
                return SummaryPlaybackMemberPitch(
                    headline: "这周的免费回放快用完了。",
                    detail: "会员会让周记和月章持续留下来，情绪标签和生活印记也会一起进入回放。",
                    cta: "让回放继续留下"
                )
            }
            return SummaryPlaybackMemberPitch(
                headline: "像不像你的这一周？",
                detail: "会员会把情绪标签、生活印记和反复出现的场景接着整理进周/月回放，不只停在分类和金额。",
                cta: "让账本继续读懂我"
            )
        case .month:
            if quotaStore.monthRemaining(isMember: false) <= 1 {
                return SummaryPlaybackMemberPitch(
                    headline: "月章体验快用完了。",
                    detail: "月章是新用户体验额度，不是每月刷新。会员可以继续整理更多月份，形成更长的生活脉络。",
                    cta: "继续留住月章"
                )
            }
            return SummaryPlaybackMemberPitch(
                headline: "像不像你的这个月？",
                detail: "会员会把更多月份里的天气、路线、情绪标签和生活印记串起来，整理成连续生活章。",
                cta: "让账本继续读懂我"
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

    private func handleSummaryPlaybackTap(range: SummaryPlaybackRange, hasData: Bool) {
        guard hasData else { return }
        guard quotaStore.canPlay(range, isMember: hasMemberAccess) else {
            switch range {
            case .week:
                summaryQuotaPrompt = SummaryQuotaPrompt(
                    title: "本周回放用完了",
                    message: "本周免费回放剩余 0/\(SummaryPlaybackQuotaStore.weeklyFreeLimit) 次。下个自然周会刷新。会员可以连续回看周/月生活节奏。",
                    primaryTitle: "了解连续回放",
                    opensMember: true
                )
            case .month:
                summaryQuotaPrompt = SummaryQuotaPrompt(
                    title: "本月章体验用完了",
                    message: "新用户月章剩余 0/\(SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit) 次。月章额度不是每月刷新。会员可以继续整理更多月份。",
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

    var traceEditSpring: Animation {
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

}
