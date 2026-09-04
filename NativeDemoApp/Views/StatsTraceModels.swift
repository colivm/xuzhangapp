import Foundation
import CoreGraphics

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week = "本周"
    case month = "本月"
    case year = "本年"
    var id: String { rawValue }
}

enum CustomDateEndpoint {
    case start
    case end
}

enum TraceCustomRangePreset {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case last7Days
    case last30Days
}

enum TraceViewMode: String, CaseIterable, Identifiable {
    case life = "生活"
    case clues = "线索"

    var id: String { rawValue }
}

enum TraceClueScope: String, Codable, Equatable, Sendable {
    /// Legacy direct callers keep the period-scoped behavior unless the trace
    /// page explicitly opts into the independent continuous scope.
    case period
    case continuous
}

enum TraceClueScopePolicy {
    /// Keep the clue surface continuous while retaining the existing bounded
    /// history contract used by trace echoes (current period + 12 prior ones).
    static let scope: TraceClueScope = .continuous
    static let narrativeScope: LifeNarrativeScope = .continuous
    static let identifier = "rolling-13-weeks-v1"
    static let periodLabel = "生活线索"
    static let lookbackWeekCount = 12
    static let rhythmBucketCount = 6
    static let rhythmBucketDays = 14

    static func window(
        now: Date,
        calendar: Calendar = PlaybackService.isoCalendar
    ) -> DateInterval? {
        guard let current = calendar.dateInterval(of: .weekOfYear, for: now),
              let start = calendar.date(
                  byAdding: .weekOfYear,
                  value: -lookbackWeekCount,
                  to: current.start
              ) else {
            return nil
        }
        return DateInterval(start: start, end: min(current.end, now))
    }

    static func windowKey(
        now: Date,
        calendar: Calendar = PlaybackService.isoCalendar
    ) -> String {
        guard let start = window(now: now, calendar: calendar)?.start else {
            return "unknown"
        }
        let components = calendar.dateComponents([.year, .month, .day], from: start)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func items(
        from allItems: [HomeItem],
        category: HomeItem.Category? = nil,
        now: Date,
        calendar: Calendar = PlaybackService.isoCalendar
    ) -> [HomeItem] {
        let interval = window(now: now, calendar: calendar)
        return allItems
            .filter { item in
                guard item.amount > 0,
                      item.draftMeta == nil,
                      category == nil || item.category == category else {
                    return false
                }
                guard let interval else { return true }
                return interval.contains(item.createdAt)
            }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func rhythmPoints(
        from items: [HomeItem],
        now: Date,
        calendar: Calendar = PlaybackService.isoCalendar
    ) -> [TraceRhythmPoint] {
        guard let interval = window(now: now, calendar: calendar), !items.isEmpty else {
            return []
        }
        return (0..<rhythmBucketCount).compactMap { index -> TraceRhythmPoint? in
            guard let start = calendar.date(
                byAdding: .day,
                value: index * rhythmBucketDays,
                to: interval.start
            ) else {
                return nil
            }
            let rawEnd = calendar.date(
                byAdding: .day,
                value: rhythmBucketDays,
                to: start
            ) ?? start
            let end = min(rawEnd, interval.end)
            guard start < end else { return nil }
            let count = items.filter { $0.createdAt >= start && $0.createdAt < end }.count
            let endLabelDate = calendar.date(byAdding: .day, value: -1, to: end) ?? start
            let startLabel = shortDate(start, calendar: calendar)
            let endLabel = shortDate(endLabelDate, calendar: calendar)
            return TraceRhythmPoint(
                label: startLabel == endLabel ? startLabel : "\(startLabel)-\(endLabel)",
                count: count,
                isToday: now >= start && now < end,
                startDate: start
            )
        }
    }

    private static func shortDate(_ date: Date, calendar: Calendar) -> String {
        "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))"
    }
}

enum TraceLifePreparationPolicy {
    static let prewarmDelayNanoseconds: UInt64 = 250_000_000

    static func prewarmRange(after visibleRange: SummaryPlaybackRange) -> SummaryPlaybackRange {
        visibleRange == .week ? .month : .week
    }

    static func hasVisibleSnapshot(
        selectedRange: SummaryPlaybackRange,
        hasWeek: Bool,
        hasMonth: Bool
    ) -> Bool {
        switch selectedRange {
        case .week:
            return hasWeek
        case .month:
            return hasMonth
        }
    }

    static func needsPrimaryPreparation(
        selectedRange: SummaryPlaybackRange,
        weekNeedsRefresh: Bool,
        monthNeedsRefresh: Bool,
        hasWeek: Bool,
        hasMonth: Bool
    ) -> Bool {
        switch selectedRange {
        case .week:
            return weekNeedsRefresh || !hasWeek
        case .month:
            return monthNeedsRefresh || !hasMonth
        }
    }
}

enum TraceSnapshotVisibilityPolicy {
    static func representsSelectedLifeRange(
        range: SummaryPlaybackRange,
        selectedPeriod: StatsPeriod,
        usesCustomRange: Bool
    ) -> Bool {
        !usesCustomRange && TraceRangeContextPolicy.period(for: range) == selectedPeriod
    }

    static func canDisplayChapter(
        selectedRange: SummaryPlaybackRange,
        snapshotRange: SummaryPlaybackRange?,
        publishedKey: String?,
        expectedKey: String
    ) -> Bool {
        snapshotRange == selectedRange && publishedKey == expectedKey
    }

    static func canDisplayColdStart(
        publishedScopeKey: String?,
        expectedScopeKey: String
    ) -> Bool {
        publishedScopeKey == expectedScopeKey
    }
}

enum TraceDeferredScrollPolicy {
    static let lifeChapterAnchorID = "trace-life-card"

    static func requiresAnchorReset(
        currentAnchorID: String?,
        targetAnchorID: String
    ) -> Bool {
        currentAnchorID == targetAnchorID
    }
}

struct TraceLoadingPresentation: Equatable, Sendable {
    let message: String
    let detail: String
    let delayNanoseconds: UInt64
}

enum TraceLoadingPresentationPolicy {
    static let refreshDelayNanoseconds: UInt64 = 150_000_000

    static func make(
        viewMode: TraceViewMode,
        selectedPeriod: StatsPeriod,
        lifeRange: SummaryPlaybackRange,
        usesCustomRange: Bool,
        hasCompleteSnapshot: Bool
    ) -> TraceLoadingPresentation {
        let message: String
        switch viewMode {
        case .life:
            message = lifeRange == .month
                ? "正在整理本月痕迹…"
                : "正在整理本周痕迹…"
        case .clues:
            message = "正在整理生活线索…"
        }

        return TraceLoadingPresentation(
            message: message,
            detail: hasCompleteSnapshot
                ? "整理完成前会暂时保留当前内容"
                : "整理好后会一次完整呈现",
            delayNanoseconds: hasCompleteSnapshot ? refreshDelayNanoseconds : 0
        )
    }
}

enum TraceSnapshotLifecycleKeyPolicy {
    static func chapterKey(
        range: SummaryPlaybackRange,
        ledgerRevision: Int,
        periodKey: String,
        isMember: Bool,
        contentRevision: Int
    ) -> String {
        [
            "chapter-v3",
            range.rawValue,
            String(ledgerRevision),
            periodKey,
            isMember ? "member" : "free",
            String(contentRevision)
        ].joined(separator: "|")
    }

    static func clueKey(
        period: StatsPeriod,
        ledgerRevision: Int,
        isMember: Bool,
        usesCustomRange: Bool,
        customStartDate: Date,
        customEndDate: Date,
        category: HomeItem.Category?,
        freeRemaining: Int,
        isUnlocked: Bool,
        dayKey: String,
        contentRevision: Int,
        calendar: Calendar = .current
    ) -> String {
        var parts = [
            "clue-v2",
            period.rawValue,
            String(ledgerRevision),
            isMember ? "member" : "free",
            usesCustomRange ? "custom" : "preset",
            category?.rawValue ?? "all",
            String(freeRemaining),
            isUnlocked ? "unlocked" : "locked",
            dayKey,
            String(contentRevision)
        ]
        if usesCustomRange {
            parts.append(String(Int(calendar.startOfDay(for: customStartDate).timeIntervalSince1970)))
            parts.append(String(Int(calendar.startOfDay(for: customEndDate).timeIntervalSince1970)))
        }
        return parts.joined(separator: "|")
    }

    static func continuousClueKey(
        ledgerRevision: Int,
        isMember: Bool,
        category: HomeItem.Category?,
        freeRemaining: Int,
        isUnlocked: Bool,
        dayKey: String,
        windowKey: String,
        contentRevision: Int
    ) -> String {
        [
            "clue-v3",
            TraceClueScopePolicy.identifier,
            String(ledgerRevision),
            isMember ? "member" : "free",
            category?.rawValue ?? "all",
            String(freeRemaining),
            isUnlocked ? "unlocked" : "locked",
            dayKey,
            windowKey,
            String(contentRevision)
        ].joined(separator: "|")
    }

    static func coldStartScopeKey(
        viewMode: TraceViewMode,
        lifeRange: SummaryPlaybackRange,
        period: StatsPeriod,
        usesCustomRange: Bool,
        customStartDate: Date,
        customEndDate: Date,
        category: HomeItem.Category?,
        calendar: Calendar = .current
    ) -> String {
        if viewMode == .life {
            return "life|\(lifeRange.rawValue)"
        }
        var parts = [
            "clue",
            period.rawValue,
            usesCustomRange ? "custom" : "preset",
            category?.rawValue ?? "all"
        ]
        if usesCustomRange {
            parts.append(String(Int(calendar.startOfDay(for: customStartDate).timeIntervalSince1970)))
            parts.append(String(Int(calendar.startOfDay(for: customEndDate).timeIntervalSince1970)))
        }
        return parts.joined(separator: "|")
    }

    static func continuousClueColdStartScopeKey(
        category: HomeItem.Category?
    ) -> String {
        "clue|\(TraceClueScopePolicy.identifier)|\(category?.rawValue ?? "all")"
    }
}

struct TraceColdStartDisplayEntry: Codable, Equatable {
    let scopeKey: String
    let savedAt: Date
    let title: String
    let summary: String
    let periodLabel: String
    let recordCount: Int
    let activeDayCount: Int
    let total: Double
    let topCategory: String?
}

struct TraceColdStartDisplayContext: Codable, Equatable {
    let ledgerFingerprint: String
    let dayKey: String
    let isMember: Bool
}

struct TraceColdStartDisplayCache: Codable, Equatable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let context: TraceColdStartDisplayContext
    var entries: [String: TraceColdStartDisplayEntry]
}

struct StatsTabState {
    var selectedPeriod: StatsPeriod = .week
    var selectedCategory: HomeItem.Category?
    var customStartDate = Date()
    var customEndDate = Date()
    var customDateFocus: CustomDateEndpoint = .start
    var useCustomRange = false
    var showsCustomDatePanel = false
    var viewMode: TraceViewMode = .life
    var lifeCardRange: SummaryPlaybackRange = .week
    var deepInsightExpanded = false
    var focusedInsightQuestion: String?
    var scrollAnchorID: String?
    var pendingLifeChapterScrollRange: SummaryPlaybackRange?
    var snapshotStore = TraceSnapshotStore()
    var preparedWeekSnapshot: TraceChapterSnapshot?
    var preparedMonthSnapshot: TraceChapterSnapshot?
    var preparedClueSnapshot: TraceClueSnapshot?
    var preparedWeekSnapshotKey: String?
    var preparedMonthSnapshotKey: String?
    var preparedClueSnapshotKey: String?
    var chapterContentRevision = 0
    var clueContentRevision = 0
    var coldStartLedgerRevision: Int?
    var coldStartDayKey: String?
    var coldStartLedgerFingerprint: String?
    var coldStartDisplay: TraceColdStartDisplayEntry?

    mutating func selectViewMode(_ mode: TraceViewMode) {
        viewMode = mode
        guard mode == .life else { return }
        selectedPeriod = TraceRangeContextPolicy.period(for: lifeCardRange)
        useCustomRange = false
        showsCustomDatePanel = false
    }

    mutating func openLifeChapter(_ range: SummaryPlaybackRange) {
        viewMode = .life
        lifeCardRange = range
        selectedPeriod = range == .week ? .week : .month
        useCustomRange = false
        pendingLifeChapterScrollRange = range
    }
}

struct SummaryPlaybackPreparationInput: @unchecked Sendable {
    let range: SummaryPlaybackRange
    let items: [HomeItem]
    let preparedFacts: PeriodExperienceFacts?
    let copySeed: String
    let sourceRevision: Int
    let isMember: Bool
    let now: Date
}

struct SummaryPlaybackPresentation: Identifiable, @unchecked Sendable {
    let playback: SummaryPlayback
    let sourceRevision: Int
    let weeklyShareSnapshot: WeeklyShareCardSnapshot?

    var id: String {
        "\(playback.id)|\(sourceRevision)"
    }
}

enum SummaryPlaybackPreparationComputation {
    static func build(
        _ input: SummaryPlaybackPreparationInput
    ) -> SummaryPlaybackPresentation? {
        guard !Task.isCancelled else { return nil }
        let service = PlaybackService()
        let periodFacts: PeriodExperienceFacts
        if let preparedFacts = input.preparedFacts,
           preparedFacts.matches(
            range: input.range,
            sourceRevision: input.sourceRevision,
            isMember: input.isMember,
            now: input.now
           ) {
            periodFacts = preparedFacts
        } else {
            periodFacts = service.preparePeriodExperienceFacts(
                from: input.items,
                range: input.range,
                now: input.now,
                sourceRevision: input.sourceRevision,
                isMember: input.isMember
            )
        }

        guard !Task.isCancelled else { return nil }
        let playback: SummaryPlayback
        switch input.range {
        case .week:
            playback = service.buildWeekSummary(
                from: periodFacts,
                copySeed: input.copySeed
            )
        case .month:
            playback = service.buildMonthSummary(
                from: periodFacts,
                copySeed: input.copySeed
            )
        }
        let weeklyShareSnapshot = input.range == .week
            ? service.prepareWeeklyShareCardSnapshot(
                from: periodFacts,
                summary: playback,
                evidenceItemIDs: PlaybackService.weeklyShareEvidenceItemIDs(
                    from: input.items,
                    now: input.now
                )
            )
            : nil
        guard !Task.isCancelled else { return nil }
        return SummaryPlaybackPresentation(
            playback: playback,
            sourceRevision: input.sourceRevision,
            weeklyShareSnapshot: weeklyShareSnapshot
        )
    }
}

enum TraceInsightQuestionFocusPolicy {
    static func nextQuestion(in questions: [String], after current: String?) -> String? {
        guard !questions.isEmpty else { return nil }
        guard let current,
              let index = questions.firstIndex(of: current) else {
            return questions[0]
        }
        return questions[(index + 1) % questions.count]
    }
}

struct TraceDayGroup: Identifiable {
    let id: String
    let date: Date
    let items: [HomeItem]
}

struct TraceMarkEvidenceGroup: Identifiable {
    let id: String
    let markLabel: String
    let items: [HomeItem]
    let overflowCount: Int
}

struct TraceChapterCoverFacts: Equatable {
    let title: String
    let supportLine: String
    let monthTitle: String
    let recordCount: Int
    let activeDays: Int
    let longestStreak: Int
    let topCategory: HomeItem.Category?
    let topCategoryCount: Int
    let topCategoryRecordSharePercent: Int
    let representativeItemID: UUID?
    let coverAnchorID: UUID?
    let coverItemID: UUID?
    let coverCaption: String?
    let monthLeadingBlankCount: Int
    let monthDayCounts: [Int]
    let currentMonthDay: Int?
}

enum TraceChapterCoverPolicy {
    static func make(
        range: SummaryPlaybackRange,
        items: [HomeItem],
        anchors: [SummaryMemoryAnchor],
        now: Date,
        calendar: Calendar = .current
    ) -> TraceChapterCoverFacts {
        let sortedItems = items.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let activeDayValues = Set(sortedItems.map { calendar.startOfDay(for: $0.createdAt) }).sorted()
        let categoryRows = Dictionary(grouping: sortedItems, by: \.category)
            .map { category, categoryItems in
                (
                    category: category,
                    count: categoryItems.count,
                    total: categoryItems.reduce(0) { $0 + $1.amount }
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.category.rawValue < rhs.category.rawValue
            }
        let topCategoryRow = categoryRows.first
        let representativeItem = anchors.first
            .flatMap { anchor in sortedItems.first { $0.id == anchor.itemID } }
            ?? TraceRepresentative.items(from: sortedItems, maxItems: 1, maxPerCategory: 1).first
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let monthStart = monthInterval?.start ?? now
        let monthTitle = "\(calendar.component(.month, from: monthStart))月"
        let monthDayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 0
        let monthLeadingBlankCount = (calendar.component(.weekday, from: monthStart) + 5) % 7
        let countsByDay = Dictionary(grouping: sortedItems) { item in
            calendar.component(.day, from: item.createdAt)
        }
        .mapValues(\.count)
        let monthDayCounts = monthDayCount > 0
            ? (1...monthDayCount).map { countsByDay[$0, default: 0] }
            : []
        let currentMonthDay: Int?
        if let monthInterval, monthInterval.contains(now) {
            currentMonthDay = calendar.component(.day, from: now)
        } else {
            currentMonthDay = nil
        }
        let recordCount = sortedItems.count
        let topCategoryCount = topCategoryRow?.count ?? 0
        let topCategoryRecordSharePercent = recordCount > 0
            ? Int((Double(topCategoryCount) / Double(recordCount) * 100).rounded())
            : 0
        let coverAnchor = range == .month ? anchors.first : nil
        let coverItem = coverAnchor.flatMap { anchor in sortedItems.first { $0.id == anchor.itemID } }
        let coverCaption = (coverItem ?? representativeItem).map {
            "\(shortDate($0.createdAt, calendar: calendar)) · \(conciseRecordTitle(for: $0))"
        }

        return TraceChapterCoverFacts(
            title: title(
                range: range,
                representativeItem: representativeItem,
                topCategory: topCategoryRow?.category,
                monthTitle: monthTitle,
                calendar: calendar
            ),
            supportLine: supportLine(
                range: range,
                recordCount: recordCount,
                activeDays: activeDayValues.count,
                topCategory: topCategoryRow?.category,
                topCategoryCount: topCategoryCount,
                topCategoryRecordSharePercent: topCategoryRecordSharePercent
            ),
            monthTitle: monthTitle,
            recordCount: recordCount,
            activeDays: activeDayValues.count,
            longestStreak: longestStreak(days: activeDayValues, calendar: calendar),
            topCategory: topCategoryRow?.category,
            topCategoryCount: topCategoryCount,
            topCategoryRecordSharePercent: topCategoryRecordSharePercent,
            representativeItemID: representativeItem?.id,
            coverAnchorID: coverAnchor?.id,
            coverItemID: coverItem?.id,
            coverCaption: coverCaption,
            monthLeadingBlankCount: monthLeadingBlankCount,
            monthDayCounts: monthDayCounts,
            currentMonthDay: currentMonthDay
        )
    }

    private static func title(
        range: SummaryPlaybackRange,
        representativeItem: HomeItem?,
        topCategory: HomeItem.Category?,
        monthTitle: String,
        calendar: Calendar
    ) -> String {
        switch range {
        case .week:
            guard let representativeItem else { return "这一周还没有记录" }
            return "\(longDate(representativeItem.createdAt, calendar: calendar))，\(conciseRecordTitle(for: representativeItem))"
        case .month:
            guard let topCategory else { return "\(monthTitle)还没有记录" }
            return "\(monthTitle)，\(topCategory.rawValue)出现得最多"
        }
    }

    private static func supportLine(
        range: SummaryPlaybackRange,
        recordCount: Int,
        activeDays: Int,
        topCategory: HomeItem.Category?,
        topCategoryCount: Int,
        topCategoryRecordSharePercent: Int
    ) -> String {
        guard recordCount > 0 else {
            return range == .week
                ? "记下第一笔后，这里会选出一个具体片段。"
                : "记下第一笔后，这里会按日期和分类整理。"
        }
        guard let topCategory else {
            return "\(recordCount)笔记录分布在\(activeDays)天。"
        }
        if range == .week {
            return "\(recordCount)笔记录分布在\(activeDays)天，\(topCategory.rawValue)最多，共\(topCategoryCount)笔。"
        }
        return "\(recordCount)笔记录分布在\(activeDays)天，\(topCategory.rawValue)共\(topCategoryCount)笔，占本月记录\(topCategoryRecordSharePercent)%。"
    }

    private static func conciseRecordTitle(for item: HomeItem) -> String {
        if item.category == .health { return "一笔健康记录" }
        let trimmed = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard item.hasMeaningfulTitle,
              !RecordSemanticLexicon.isSystemGeneratedTitle(trimmed) else {
            return "一笔\(item.category.rawValue)记录"
        }
        let withoutMerchantSuffix = ["（", "("].reduce(trimmed) { current, separator in
            guard let marker = separator.first,
                  let index = current.firstIndex(of: marker),
                  index > current.startIndex else {
                return current
            }
            let prefix = current[..<index].trimmingCharacters(in: .whitespacesAndNewlines)
            return prefix.count >= 2 ? prefix : current
        }
        let limit = 16
        return withoutMerchantSuffix.count > limit
            ? "\(withoutMerchantSuffix.prefix(limit))…"
            : withoutMerchantSuffix
    }

    private static func longDate(_ date: Date, calendar: Calendar) -> String {
        "\(calendar.component(.month, from: date))月\(calendar.component(.day, from: date))日"
    }

    private static func shortDate(_ date: Date, calendar: Calendar) -> String {
        "\(calendar.component(.month, from: date))/\(calendar.component(.day, from: date))"
    }

    private static func longestStreak(days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<days.count {
            let distance = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day
            if distance == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}

enum TraceMonthDiaryPolicy {
    static let maximumPhotoCount = 6
    static let selectionLimitIncludingCover = maximumPhotoCount + 1

    static func anchors(
        from anchors: [SummaryMemoryAnchor],
        excludingCoverItemID coverItemID: UUID?,
        limit: Int = maximumPhotoCount
    ) -> [SummaryMemoryAnchor] {
        Array(anchors.filter { $0.itemID != coverItemID }.prefix(max(0, limit)))
    }
}

enum TracePhotoEvidenceBindingPolicy {
    static func item(
        for itemID: UUID?,
        in items: [HomeItem]
    ) -> HomeItem? {
        guard let itemID else { return nil }
        return items.first { $0.id == itemID }
    }

    static func item(
        for anchor: SummaryMemoryAnchor?,
        in items: [HomeItem]
    ) -> HomeItem? {
        item(for: anchor?.itemID, in: items)
    }

    static func primaryCategory(
        anchor: SummaryMemoryAnchor?,
        items: [HomeItem]
    ) -> HomeItem.Category {
        item(for: anchor, in: items)?.category ?? items.first?.category ?? .other
    }
}

struct TraceChapterSnapshot: @unchecked Sendable {
    let range: SummaryPlaybackRange
    let items: [HomeItem]
    let periodFacts: PeriodExperienceFacts
    let marks: [LifeMarkAggregate]
    let memoryAnchors: [SummaryMemoryAnchor]
    let monthDiaryAnchors: [SummaryMemoryAnchor]
    let coverFacts: TraceChapterCoverFacts
    let narrativePlan: LifeNarrativePlan
    let narrativeRewrite: LifeNarrativeAIRewrite?
    let narrative: String
    let chapterSummary: String?
    let evidenceGroups: [TraceMarkEvidenceGroup]
    let preview: SummaryLaunchPreview
}

struct TraceCategoryClue: Identifiable {
    let category: HomeItem.Category
    let count: Int
    let total: Double
    let ratio: Double

    var id: String { category.rawValue }
}

struct TraceRhythmPoint: Identifiable {
    let label: String
    let count: Int
    let isToday: Bool
    let startDate: Date? = nil

    var id: String { label }
}

struct TraceClueSnapshot: @unchecked Sendable {
    let items: [HomeItem]
    let clues: [TraceCategoryClue]
    let rhythmPoints: [TraceRhythmPoint]
    let journeyFact: LifeJourneyFact?
    let discover: DiscoverSnapshot
    let insight: LifeInsightResult
    let narrativePlan: LifeNarrativePlan?
    let narrativeRewrite: LifeNarrativeAIRewrite?
    let marks: [LifeMarkAggregate]
    let lockedMark: LifeMarkAggregate?
    let isDeepInsightUnlocked: Bool
    let canUseDeepInsight: Bool
    let freeInsightRemaining: Int

    var narrativeHeadline: String? {
        guard narrativePlan != nil else { return nil }
        return insight.leadQuestion
    }

    var narrativeSummary: String? {
        guard narrativePlan != nil else { return nil }
        return insight.previewLine
    }

    var photoEvidenceItem: HomeItem? {
        guard let itemID = insight.highlightedItemID,
              let item = TracePhotoEvidenceBindingPolicy.item(for: itemID, in: items),
              item.hasMemoryImages else {
            return nil
        }
        if let lead = narrativePlan?.signalsByRole[.lead]?.first {
            return lead.kind == .photo && lead.evidenceItemIDs.contains(itemID) ? item : nil
        }
        return insight.theme == .memory ? item : nil
    }
}

enum DiscoverCardKind: String, Codable, Equatable, Sendable {
    case discovery
    case pattern
    case asset
    case echo
}

struct DiscoverCard: Identifiable, Codable, Equatable, @unchecked Sendable {
    let id: String
    let kind: DiscoverCardKind
    let title: String
    let summary: String
    let evidenceItemIDs: [UUID]
    let novelty: Int
    let confidence: Int
    let storyValue: Int
    let latestDate: Date

    var editorialScore: Int {
        novelty * confidence * storyValue
    }

    var hasEvidence: Bool {
        !evidenceItemIDs.isEmpty
    }
}

struct DiscoverSnapshot: Equatable, @unchecked Sendable {
    let sourceRevision: Int
    let recentDiscoveries: [DiscoverCard]
    let lifePatterns: [DiscoverCard]
    let sceneAssets: [DiscoverCard]
    let echoes: [DiscoverCard]

    static let empty = DiscoverSnapshot(
        sourceRevision: 0,
        recentDiscoveries: [],
        lifePatterns: [],
        sceneAssets: [],
        echoes: []
    )

    var isEmpty: Bool {
        recentDiscoveries.isEmpty
            && lifePatterns.isEmpty
            && sceneAssets.isEmpty
            && echoes.isEmpty
    }
}

struct SummaryLaunchPreview {
    let count: Int
    let total: Double
    let chapterCount: Int
    let topCategory: String?
}
