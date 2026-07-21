import Foundation
import Combine

struct AICommandRecordDraft: Identifiable, Equatable {
    enum Status: Equatable {
        case ready
        case conflict(String)
    }

    let id: UUID
    var title: String
    var amount: Double
    var category: HomeItem.Category
    var date: Date
    var status: Status

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: HomeItem.Category,
        date: Date,
        status: Status = .ready
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.date = date
        self.status = status
    }
}

struct RecordFrequentAmountSuggestion: Identifiable, Equatable {
    let amount: Double
    let category: HomeItem.Category
    let count: Int
    let confidence: Double
    let latest: Date

    var id: String {
        "\(Int((amount * 100).rounded()))-\(category.rawValue)"
    }
}

struct RecordInputHistoryKey: Equatable {
    let ledgerRevision: Int
    let referenceContext: String
}

struct RecordInputHistoryPreparationInput: @unchecked Sendable {
    let key: RecordInputHistoryKey
    let items: [HomeItem]
    let referenceDate: Date
    let now: Date
}

struct RecordInputHistorySnapshot: @unchecked Sendable {
    let key: RecordInputHistoryKey
    let prefillItems: [HomeItem]
    let frequentSuggestions: [RecordFrequentAmountSuggestion]
    let frequentTitlesBySuggestionID: [String: String]
}

struct RecordPrefillPreparationKey: Equatable {
    let historyKey: RecordInputHistoryKey
    let amount: Double
    let referenceDate: Date
    let noteDraft: String
    let selectedCategory: HomeItem.Category
    let context: RecordContextSignal?
}

struct RecordPrefillPreparationInput: @unchecked Sendable {
    let key: RecordPrefillPreparationKey
    let history: RecordInputHistorySnapshot
    let amount: Double
    let referenceDate: Date
    let now: Date
    let noteDraft: String
    let selectedCategory: HomeItem.Category
    let context: RecordContextSignal?
}

struct RecordPrefillSnapshot: @unchecked Sendable {
    let key: RecordPrefillPreparationKey
    let amount: Double
    let result: RecordPrefillResult?
    let appliedCategory: HomeItem.Category?
    let categoryGridRecommendation: HomeItem.Category?
}

struct RecordPreviewLifeMarkKey: Equatable {
    let ledgerRevision: Int
    let title: String
    let amount: Double
    let category: HomeItem.Category
    let createdAt: Date
    let emotionTag: String
    let merchantBrandID: String?
    let scenePackID: String?
    let isMember: Bool
}

struct RecordPreviewLifeMarkPreparationInput: @unchecked Sendable {
    let key: RecordPreviewLifeMarkKey
    let draft: HomeItem
    let allItems: [HomeItem]
    let isMember: Bool
}

enum RecordInputAssistanceComputation {
    static func historyKey(
        ledgerRevision: Int,
        referenceDate: Date,
        referenceDateEditedByUser: Bool,
        calendar: Calendar = .current
    ) -> RecordInputHistoryKey {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: referenceDate
        )
        let day = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        let timeContext: String
        if referenceDateEditedByUser {
            timeContext = String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
        } else {
            timeContext = "bucket:\((components.hour ?? 0) / 3)"
        }
        return RecordInputHistoryKey(
            ledgerRevision: ledgerRevision,
            referenceContext: "\(day)|\(timeContext)"
        )
    }

    static func historySnapshot(
        _ input: RecordInputHistoryPreparationInput
    ) -> RecordInputHistorySnapshot {
        let calendar = Calendar.current
        let prefillStart = calendar.date(byAdding: .day, value: -180, to: input.now) ?? .distantPast
        let prefillItems = input.items.filter { item in
            item.amount > 0 && item.createdAt >= prefillStart
        }
        let suggestions = frequentRecordAmountSuggestions(
            items: input.items,
            at: input.referenceDate,
            calendar: calendar
        )
        let titles = suggestions.reduce(into: [String: String]()) { result, suggestion in
            if let title = frequentHabitTitle(
                items: input.items,
                suggestion: suggestion,
                amount: suggestion.amount,
                at: input.referenceDate,
                calendar: calendar
            ) {
                result[suggestion.id] = title
            }
        }
        return RecordInputHistorySnapshot(
            key: input.key,
            prefillItems: prefillItems,
            frequentSuggestions: suggestions,
            frequentTitlesBySuggestionID: titles
        )
    }

    static func prefillSnapshot(
        _ input: RecordPrefillPreparationInput
    ) -> RecordPrefillSnapshot {
        let brand = MerchantBrandCatalog.matchBrand(in: input.noteDraft)
        let semanticCategory = RecordSemanticLexicon.semanticCategory(of: input.noteDraft)
        let frequentSuggestion = input.history.frequentSuggestions.first { suggestion in
            abs(suggestion.amount - input.amount) < 0.005
        }
        let shouldUseBrandPrefill = brand.map { brand in
            !MerchantBrandCatalog.isConvenienceStoreBrand(brand)
                || semanticCategory == nil
                || semanticCategory == brand.category
        } ?? false
        let habitResult = RecordPrefillService().prefill(
            input: RecordPrefillInput(
                amount: input.amount,
                referenceDate: input.referenceDate,
                items: input.history.prefillItems,
                noteDraft: input.noteDraft,
                categoryLocked: false,
                merchantBrandId: shouldUseBrandPrefill ? brand?.id : nil,
                context: input.context
            )
        )

        var result = habitResult
        if habitResult == nil,
           brand == nil,
           semanticCategory == nil,
           let frequentSuggestion,
           frequentSuggestionCanOverrideNote(frequentSuggestion, note: input.noteDraft) {
            let title = input.history.frequentTitlesBySuggestionID[frequentSuggestion.id]
            result = RecordPrefillResult(
                category: frequentSuggestion.category,
                title: title,
                emotionTag: habitEmotionTag(
                    title: title,
                    category: frequentSuggestion.category,
                    amount: input.amount,
                    date: input.referenceDate
                ),
                confidence: frequentSuggestion.confidence,
                source: "frequent"
            )
        }

        let appliedCategory = resolvePrefillCategory(
            brand: brand,
            frequent: frequentSuggestion,
            semanticCategory: semanticCategory,
            habitResult: habitResult
        )
        let displayCategory = appliedCategory ?? input.selectedCategory
        let sanitizedResult = sanitizedPrefillResult(result, for: displayCategory)
        let categoryRecommendationStart = Calendar.current.date(
            byAdding: .day,
            value: -90,
            to: input.now
        ) ?? .distantPast
        let categoryGridRecommendation = categoryGridRecommendation(
            amount: input.amount,
            referenceDate: input.referenceDate,
            noteDraft: input.noteDraft,
            brand: brand,
            semanticCategory: semanticCategory,
            prefillResult: sanitizedResult,
            frequentSuggestion: frequentSuggestion,
            items: input.history.prefillItems.filter { item in
                item.createdAt >= categoryRecommendationStart
            },
            context: input.context
        )
        return RecordPrefillSnapshot(
            key: input.key,
            amount: input.amount,
            result: sanitizedResult,
            appliedCategory: appliedCategory,
            categoryGridRecommendation: categoryGridRecommendation
        )
    }

    static func previewLifeMarkText(
        _ input: RecordPreviewLifeMarkPreparationInput
    ) -> String? {
        guard let mark = LifeMarkService.aggregates(
            for: [input.draft],
            allItems: input.allItems,
            isMember: input.isMember,
            limit: 1
        ).first else {
            return nil
        }
        switch mark.kind {
        case .milestone, .context, .streak:
            return "生活线索 · \(mark.title)"
        case .scene:
            return "会进入「\(mark.label)」印记"
        }
    }

    static func prefillResultsEqual(
        _ lhs: RecordPrefillResult?,
        _ rhs: RecordPrefillResult?
    ) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.category == rhs.category
                && lhs.title == rhs.title
                && lhs.emotionTag == rhs.emotionTag
                && lhs.confidence == rhs.confidence
                && lhs.source == rhs.source
        default:
            return false
        }
    }

    private static func frequentRecordAmountSuggestions(
        items: [HomeItem],
        at date: Date,
        calendar: Calendar
    ) -> [RecordFrequentAmountSuggestion] {
        let start = calendar.date(byAdding: .day, value: -180, to: date) ?? .distantPast
        let recentItems = items.filter { item in
            item.amount > 0 && item.createdAt >= start && item.createdAt <= date
        }
        guard recentItems.count >= 6 else { return [] }

        let targetBucket = hourHabitBucket(for: date, calendar: calendar)
        let targetDayKind = RecordCalendarContext.dayKind(for: date)
        let contextItems = recentItems.filter { item in
            hourHabitBucket(for: item.createdAt, calendar: calendar) == targetBucket
                && RecordCalendarContext.dayKind(for: item.createdAt) == targetDayKind
        }
        guard contextItems.count >= 3 else { return [] }

        let grouped = Dictionary(grouping: contextItems) { item in
            Int((item.amount * 100).rounded())
        }
        let candidates: [RecordFrequentAmountSuggestion] = grouped.compactMap { entry in
            let group = entry.value
            let latestDate = group.map(\.createdAt).max() ?? .distantPast
            guard let category = frequentCategory(in: group) else { return nil }
            return RecordFrequentAmountSuggestion(
                amount: Double(entry.key) / 100,
                category: category.category,
                count: category.count,
                confidence: category.confidence,
                latest: latestDate
            )
        }
        return Array(
            candidates
                .filter { candidate in
                    candidate.count >= 2
                        && candidate.confidence >= 0.75
                        && candidate.amount > 0
                        && candidate.amount <= 9999
                }
                .sorted { lhs, rhs in
                    lhs.count == rhs.count ? lhs.latest > rhs.latest : lhs.count > rhs.count
                }
                .prefix(3)
        )
    }

    private static func frequentHabitTitle(
        items: [HomeItem],
        suggestion: RecordFrequentAmountSuggestion,
        amount: Double,
        at date: Date,
        calendar: Calendar
    ) -> String? {
        let start = calendar.date(byAdding: .day, value: -180, to: date) ?? .distantPast
        let amountCents = Int((amount * 100).rounded())
        let supportItems = items.filter { item in
            item.amount > 0
                && item.createdAt >= start
                && item.createdAt <= date
                && item.category == suggestion.category
                && Int((item.amount * 100).rounded()) == amountCents
                && hourHabitBucket(for: item.createdAt, calendar: calendar) == hourHabitBucket(for: date, calendar: calendar)
                && RecordCalendarContext.dayKind(for: item.createdAt) == RecordCalendarContext.dayKind(for: date)
        }
        guard supportItems.count >= 2 else { return nil }

        let ranked = supportItems.reduce(into: [String: Int]()) { result, item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard RecordPrefillService.isHabitTitle(title, category: suggestion.category),
                  RecordSemanticLexicon.canReuseHabitTitle(
                    title,
                    category: suggestion.category,
                    userEditedTitle: item.userEditedTitle == true
                  ) else {
                return
            }
            result[title, default: 0] += item.userEditedTitle == true ? 2 : 1
        }
        .sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }
        guard let best = ranked.first, best.value >= 2 else { return nil }
        return best.key
    }

    private static func frequentCategory(
        in items: [HomeItem]
    ) -> (category: HomeItem.Category, count: Int, confidence: Double)? {
        if let scene = LifeSceneSemanticService.dominantScene(in: items),
           scene.signal.confidenceTier >= .medium,
           scene.count >= 2 {
            let confidence = Double(scene.count) / Double(max(items.count, 1))
            if confidence >= 0.67 {
                return (scene.signal.category, scene.count, confidence)
            }
        }

        struct CategoryCandidate {
            let category: HomeItem.Category
            let count: Int
            let latest: Date
        }
        let ranked = Dictionary(grouping: items, by: \.category)
            .map { entry in
                CategoryCandidate(
                    category: entry.key,
                    count: entry.value.count,
                    latest: entry.value.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.latest > rhs.latest : lhs.count > rhs.count
            }
        guard let top = ranked.first else { return nil }
        let secondCount = ranked.dropFirst().first?.count ?? 0
        let confidence = Double(top.count) / Double(max(items.count, 1))
        guard top.count >= 2, confidence >= 0.75, top.count >= secondCount + 2 else {
            return nil
        }
        return (top.category, top.count, confidence)
    }

    private static func resolvePrefillCategory(
        brand: MerchantBrandDefinition?,
        frequent: RecordFrequentAmountSuggestion?,
        semanticCategory: HomeItem.Category?,
        habitResult: RecordPrefillResult?
    ) -> HomeItem.Category? {
        if let brand { return brand.category }
        if let semanticCategory { return semanticCategory }
        if let frequent { return frequent.category }
        if let category = habitResult?.category,
           habitResult?.source == "generic" {
            return category
        }
        if let category = habitResult?.category,
           habitResult?.source != "generic",
           (habitResult?.confidence ?? 0) >= 0.55 {
            return category
        }
        return nil
    }

    private static func categoryGridRecommendation(
        amount: Double,
        referenceDate: Date,
        noteDraft: String,
        brand: MerchantBrandDefinition?,
        semanticCategory: HomeItem.Category?,
        prefillResult: RecordPrefillResult?,
        frequentSuggestion: RecordFrequentAmountSuggestion?,
        items: [HomeItem],
        context: RecordContextSignal?
    ) -> HomeItem.Category? {
        if let brand {
            if MerchantBrandCatalog.isConvenienceStoreBrand(brand),
               let semanticCategory,
               semanticCategory != brand.category {
                return semanticCategory
            }
            return brand.category
        }
        if let semanticCategory {
            return semanticCategory
        }
        if let category = prefillResult?.category,
           prefillResult?.source != "generic",
           (prefillResult?.confidence ?? 0) >= 0.55 {
            return category
        }
        if let frequentSuggestion,
           frequentSuggestionCanOverrideNote(frequentSuggestion, note: noteDraft) {
            return frequentSuggestion.category
        }
        if let category = prefillResult?.category,
           prefillResult?.source == "generic" {
            return category
        }
        guard !noteDraft.isEmpty else { return nil }
        return CategoryRecommendService().recommend(
            input: CategoryRecommendInput(
                amount: amount,
                referenceDate: referenceDate,
                items: items,
                noteDraft: noteDraft,
                locked: false,
                context: context
            )
        )?.recommended
    }

    private static func frequentSuggestionCanOverrideNote(
        _ suggestion: RecordFrequentAmountSuggestion,
        note: String
    ) -> Bool {
        guard suggestion.confidence >= 0.67 else { return false }
        let semanticCategories = RecordSemanticLexicon.matchingCategories(in: note)
        return semanticCategories.isEmpty || semanticCategories.contains(suggestion.category)
    }

    private static func sanitizedPrefillResult(
        _ result: RecordPrefillResult?,
        for category: HomeItem.Category
    ) -> RecordPrefillResult? {
        guard let result else { return nil }
        guard let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return result
        }
        guard RecordSemanticLexicon.canDisplayPrefillTitle(
            title,
            category: category,
            source: result.source
        ) else {
            return RecordPrefillResult(
                category: result.category,
                title: nil,
                emotionTag: nil,
                confidence: result.confidence,
                source: result.source
            )
        }
        return result
    }

    private static func habitEmotionTag(
        title: String?,
        category: HomeItem.Category,
        amount: Double,
        date: Date
    ) -> String? {
        guard let title,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return NarrativeCopyResolver.resolveEmotionTag(
            context: NarrativeCopyResolver.Context(
                brandId: nil,
                category: category,
                amount: amount,
                date: date,
                seed: title,
                note: title
            )
        )
    }

    private static func hourHabitBucket(for date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date) / 3
    }
}

struct ItemDerivedCachePreparationKey: Equatable {
    let ledgerRevision: Int
    let dayKey: String
}

struct ItemDerivedCachePreparationInput: @unchecked Sendable {
    let key: ItemDerivedCachePreparationKey
    let items: [HomeItem]
    let now: Date
    let itemsAreSortedDescending: Bool
}

struct ItemDerivedCacheSnapshot: Equatable, @unchecked Sendable {
    let key: ItemDerivedCachePreparationKey
    var todayPositiveItems: [HomeItem] = []
    var recentThreeTodayItems: [HomeItem] = []
    var currentWeekItems: [HomeItem] = []
    var currentMonthItems: [HomeItem] = []
    var currentYearItems: [HomeItem] = []
    var homeJourneyLedgerFacts = HomeJourneyLedgerFacts()
    var todayPlayback = PlaybackSnapshot(durationMs: 10_000, entries: [])

    static func empty(for key: ItemDerivedCachePreparationKey) -> ItemDerivedCacheSnapshot {
        ItemDerivedCacheSnapshot(key: key)
    }
}

enum ItemDerivedCacheComputation {
    static func build(_ input: ItemDerivedCachePreparationInput) -> ItemDerivedCacheSnapshot {
        let calendar = Calendar.current
        let sortedItems = input.itemsAreSortedDescending
            ? input.items
            : input.items.sorted { $0.createdAt > $1.createdAt }
        let currentWeekInterval = PlaybackService.isoCalendar.dateInterval(
            of: .weekOfYear,
            for: input.now
        )
        let currentMonthInterval = calendar.dateInterval(of: .month, for: input.now)
        let todayPositiveItems = sortedItems.filter {
            calendar.isDate($0.createdAt, inSameDayAs: input.now) && $0.amount > 0
        }
        let currentWeekItems = sortedItems.filter { item in
            guard let currentWeekInterval else { return false }
            return item.createdAt >= currentWeekInterval.start
                && item.createdAt < currentWeekInterval.end
        }
        let currentMonthItems = sortedItems.filter { item in
            guard let currentMonthInterval else { return false }
            return item.createdAt >= currentMonthInterval.start
                && item.createdAt < currentMonthInterval.end
        }
        let currentYearItems = sortedItems.filter {
            calendar.isDate($0.createdAt, equalTo: input.now, toGranularity: .year)
        }
        return ItemDerivedCacheSnapshot(
            key: input.key,
            todayPositiveItems: todayPositiveItems,
            recentThreeTodayItems: Array(todayPositiveItems.prefix(3)),
            currentWeekItems: currentWeekItems,
            currentMonthItems: currentMonthItems,
            currentYearItems: currentYearItems,
            homeJourneyLedgerFacts: HomeJourneyLedgerFacts.build(
                from: sortedItems,
                currentWeekInterval: currentWeekInterval,
                currentMonthInterval: currentMonthInterval,
                calendar: calendar
            ),
            todayPlayback: PlaybackService().buildTodayPlayback(
                from: sortedItems,
                now: input.now
            )
        )
    }
}

enum ItemDerivedCachePublicationPolicy {
    static let coalescingDelayNanoseconds: UInt64 = 40_000_000

    static func accepts(
        snapshotKey: ItemDerivedCachePreparationKey,
        pendingKey: ItemDerivedCachePreparationKey?,
        currentKey: ItemDerivedCachePreparationKey,
        requestMatches: Bool
    ) -> Bool {
        requestMatches && snapshotKey == pendingKey && snapshotKey == currentKey
    }
}

struct HomeJourneyLedgerFacts: Equatable {
    var totalCommittedRecordCount = 0
    var currentWeekCommittedRecordCount = 0
    var currentWeekActiveDayCount = 0
    var currentMonthCommittedRecordCount = 0
    var currentMonthActiveDayCount = 0

    static func build(
        from items: [HomeItem],
        currentWeekInterval: DateInterval?,
        currentMonthInterval: DateInterval?,
        calendar: Calendar = .current
    ) -> HomeJourneyLedgerFacts {
        var facts = HomeJourneyLedgerFacts()
        var weekDays = Set<Date>()
        var monthDays = Set<Date>()
        for item in items {
            guard item.amount > 0, item.draftMeta == nil else { continue }
            facts.totalCommittedRecordCount += 1
            if let currentWeekInterval,
               item.createdAt >= currentWeekInterval.start,
               item.createdAt < currentWeekInterval.end {
                facts.currentWeekCommittedRecordCount += 1
                weekDays.insert(calendar.startOfDay(for: item.createdAt))
            }
            if let currentMonthInterval,
               item.createdAt >= currentMonthInterval.start,
               item.createdAt < currentMonthInterval.end {
                facts.currentMonthCommittedRecordCount += 1
                monthDays.insert(calendar.startOfDay(for: item.createdAt))
            }
        }
        facts.currentWeekActiveDayCount = weekDays.count
        facts.currentMonthActiveDayCount = monthDays.count
        return facts
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    enum Period: String, CaseIterable, Identifiable {
        case week = "本周"
        case month = "本月"

        var id: String { rawValue }
    }

    typealias FrequentRecordAmountSuggestion = RecordFrequentAmountSuggestion

    @Published var inputTitle: String = ""
    @Published var inputAmount: String = ""
    @Published var selectedCategory: HomeItem.Category = .other
    @Published private(set) var categoryLockedByUser: Bool = false
    @Published var selectedDate: Date = .now
    @Published private(set) var selectedDateEditedByUser: Bool = false
    @Published var selectedPeriod: Period = .month
    @Published private(set) var ocrStatus: String = ""
    @Published private(set) var isGeneratingInsight: Bool = false
    @Published private(set) var isGeneratingMonthlyInsight: Bool = false
    @Published private(set) var insightErrorMessage: String?
    @Published private(set) var insights: [DailyInsight] = []
    @Published private(set) var items: [HomeItem] = [] {
        didSet {
            recordInputAssistanceRevision &+= 1
            homeDashboardRevision &+= 1
            invalidateRecordInputHistorySnapshot()
            invalidateHomeDashboardSnapshots()
            prepareItemDerivedCacheIfNeeded(now: Date())
        }
    }
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var isSyncingCloudLedger: Bool = false
    @Published private(set) var isRestoringLocalBackup: Bool = false
    private(set) var latestPlayback: PlaybackSnapshot?
    @Published private(set) var latestActionCard: ActionCardData?
    @Published private(set) var activeRouteGuidance: PlaybackRouteGuidance?
    @Published private(set) var currentWeekTraceSeenKey: String?
    @Published private(set) var recordPrefillResult: RecordPrefillResult?
    @Published private(set) var recordWarmupSuggestions: [FrequentRecordAmountSuggestion] = []
    @Published private(set) var recordRecommendedCategory: HomeItem.Category?
    private(set) var recordInputAssistanceRevision: Int = 0
    private(set) var homeDashboardRevision: Int = 0
    var homeLifeMarkTextsByItemID: [UUID: String] = [:]
    var homeTodayLifeMarkLine: String?
    var highConfidenceQuickRecordSuggestionSnapshot: HomeHighConfidenceQuickRecordSuggestion?
    @Published private(set) var recordInputMessage: String?
    @Published var petMessage: String? = nil

    enum PlaybackRouteGuidance: String, Identifiable, Hashable {
        case firstRecordTodayPlayback

        var id: String { rawValue }

        var title: String {
            "用十几秒叙一下今天"
        }

        var message: String {
            "第一笔已经记好，听一遍今日回放。"
        }
    }

    struct ActionCardData: Codable, Equatable {
        var text: String
        var updatedAt: Date
        var scope: String // "weekly", "monthly", "none"
    }

    struct TodayStoryNarrative: Equatable {
        var title: String
        var subtitle: String
        var todayTotalText: String
        var weekTotalText: String
    }

    enum AIInsightSource: Equatable {
        case live
        case fallback
        case errorFallback

        var analyticsValue: String {
            switch self {
            case .live: return "live"
            case .fallback: return "local_fallback"
            case .errorFallback: return "error_fallback"
            }
        }
    }

    struct MonthlyInsightReport: Equatable {
        var summary: String
        var structure: String
        var advice: String
        var source: AIInsightSource
    }

    private let ocrService = OCRService()
    private let aiReportService = AIReportService()
    private let analyticsService = AnalyticsService()
    private let categoryRecommendService = CategoryRecommendService()
    private let petCompanionService = PetCompanionService.shared
    private let routeQuotaStore = SummaryPlaybackQuotaStore()
    private let dailyQuotaStore = DailyFeatureQuotaStore()
    private static let routeGuidanceHandledDefaultsKey = "route_guidance_handled_v1"
    private static let currentWeekTraceSeenDefaultsKey = "current_week_trace_seen_key_v1"
    private var emittedRouteGuidanceKeys: Set<String> = []
    private var recordPrefillAmount: Double?
    private var recordInputHistorySnapshot: RecordInputHistorySnapshot?
    private var recordInputHistoryPreparationKey: RecordInputHistoryKey?
    private var recordInputHistoryPreparationTask: Task<Void, Never>?
    private var recordInputHistoryRequestID = UUID()
    private var recordPrefillPreparationKey: RecordPrefillPreparationKey?
    private var recordPrefillPreparationTask: Task<Void, Never>?
    private var recordPrefillRequestID = UUID()
    var homeLifeMarkSnapshotKey: HomeLifeMarkSnapshotKey?
    var homeLifeMarkPreparationTask: Task<Void, Never>?
    var homeLifeMarkRequestID = UUID()
    var homeQuickRecordSnapshotKey: HomeQuickRecordSnapshotKey?
    var homeQuickRecordPreparationTask: Task<Void, Never>?
    var homeQuickRecordRequestID = UUID()
    var pendingHomeDashboardPreparationRequest: HomeDashboardPreparationRequest?
    private var lastAutoRecommendedCategory: HomeItem.Category?
    private var pendingCategoryCorrectionFrom: HomeItem.Category?
    private var itemDerivedCache = ItemDerivedCacheSnapshot.empty(
        for: ItemDerivedCachePreparationKey(ledgerRevision: -1, dayKey: "")
    )
    private var itemDerivedCachePreparationKey: ItemDerivedCachePreparationKey?
    private var itemDerivedCachePreparationTask: Task<Void, Never>?
    private var itemDerivedCacheRequestID = UUID()
    private(set) var itemDerivedCacheRevision = -1
    private var localLedgerWritesBlocked = false

    init() {
        currentWeekTraceSeenKey = UserDefaults.standard.string(
            forKey: Self.currentWeekTraceSeenDefaultsKey
        )
        let ledgerLoadStartedAt = ProcessInfo.processInfo.systemUptime
        let ledgerLoadResult = LocalStore.loadHomeItemsResult()
        items = ledgerLoadResult.items.sorted { $0.createdAt > $1.createdAt }
        analyticsService.trackPerformance(
            operation: .ledgerColdStart,
            startedAtUptime: ledgerLoadStartedAt,
            itemCount: items.count
        )
        #if DEBUG
        if ReleaseFixtureLaunchConfiguration.resolve()?.photoProfile == .realistic {
            let elapsedMs = Int(
                ((ProcessInfo.processInfo.systemUptime - ledgerLoadStartedAt) * 1_000).rounded()
            )
            print("PERF-04 ledger metadata cold start: \(elapsedMs)ms, records=\(items.count)")
        }
        #endif
        localLedgerWritesBlocked = ledgerLoadResult.writesBlocked
        if let issueMessage = ledgerLoadResult.issueMessage {
            syncStatusMessage = issueMessage
            if ledgerLoadResult.writesBlocked {
                recordInputMessage = issueMessage
            }
        }
        let initialDerivedNow = Date()
        let initialDerivedInput = ItemDerivedCachePreparationInput(
            key: ItemDerivedCachePreparationKey(
                ledgerRevision: homeDashboardRevision,
                dayKey: Self.dayKey(for: initialDerivedNow)
            ),
            items: items,
            now: initialDerivedNow,
            itemsAreSortedDescending: true
        )
        itemDerivedCache = ItemDerivedCacheComputation.build(initialDerivedInput)
        itemDerivedCacheRevision = initialDerivedInput.key.ledgerRevision
        latestPlayback = itemDerivedCache.todayPlayback
        insights = LocalStore.loadDailyInsights().sorted { $0.createdAt > $1.createdAt }
        if let data = UserDefaults.standard.data(forKey: "latest_action_card_v1"),
           let card = try? JSONDecoder().decode(ActionCardData.self, from: data) {
            // Expire cards based on scope
            let calendar = Calendar.current
            let daysSince = calendar.dateComponents([.day], from: card.updatedAt, to: Date()).day ?? 999
            let expired: Bool = {
                switch card.scope {
                case "weekly": return daysSince > 7
                case "monthly": return daysSince > 30
                default: return false
                }
            }()
            if !expired, !Self.isLowValueActionCardText(card.text) { latestActionCard = card }
        }
        analyticsService.track(
            .appOpened,
            props: [.ledgerSizeBucket: AnalyticsService.countBucket(for: items.count)]
        )
    }

    @discardableResult
    func addManualRecord(
        userEditedTitle: Bool = false,
        preserveEmptyTitle: Bool = false,
        categoryLockedForSave: Bool? = nil,
        scenePackId: String? = nil
    ) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else { return false }
        let wasEmpty = items.isEmpty
        let shouldLockCategory = categoryLockedForSave ?? categoryLockedByUser
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        guard noteResult.isAllowed else {
            recordInputMessage = noteResult.message
            return false
        }
        recordInputMessage = nil
        let trimmed = noteResult.value
        let titleWasIntentionallyBlank = preserveEmptyTitle && trimmed.isEmpty
        let prefillTitle = compatiblePrefillTitleForSave(category: selectedCategory)
        let baseTitle: String
        if titleWasIntentionallyBlank {
            baseTitle = RecordSemanticLexicon.emptyNoteTitle
        } else if trimmed.isEmpty, let prefillTitle {
            baseTitle = prefillTitle
        } else {
            baseTitle = trimmed.isEmpty ? selectedCategory.defaultRecordTitle : trimmed
        }
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: baseTitle,
                fallbackCategory: selectedCategory,
                amount: amount,
                date: selectedDate,
                merchantBrandId: MerchantBrandCatalog.matchBrand(in: baseTitle)?.id,
                categoryLockedByUser: shouldLockCategory,
                userEditedTitle: userEditedTitle || titleWasIntentionallyBlank,
                source: "manual",
                scenePackId: scenePackId
            )
        )
        let emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: amount,
            date: selectedDate,
            baseEmotionTag: resolution.emotionTag
        )
        let memoryContext = memoryContextForRecord(date: selectedDate)
        let newItem = HomeItem(
            title: resolution.title,
            amount: amount,
            category: resolution.category,
            source: .manual,
            createdAt: selectedDate,
            updatedAt: Date(),
            emotionTag: emotionTag,
            merchantBrandId: resolution.merchantBrandId,
            userEditedTitle: userEditedTitle && resolution.title == baseTitle ? true : nil,
            userEditedCategory: shouldLockCategory ? true : nil,
            categoryCorrectionFrom: shouldLockCategory ? pendingCategoryCorrectionFrom : nil,
            memoryContext: memoryContext,
            scenePackId: scenePackId
        )
        items.insert(newItem, at: 0)
        guard persistItems(upserting: [newItem]) else { return false }
        resetInput()
        schedulePostManualRecordWork(for: newItem, wasEmpty: wasEmpty)
        return true
    }

    private func schedulePostManualRecordWork(for newItem: HomeItem, wasEmpty: Bool) {
        Task { @MainActor in
            await Task.yield()
            analyticsService.track(
                .recordSaved,
                props: [
                    .source: "manual",
                    .isFirst: wasEmpty ? "true" : "false",
                    .ledgerSizeBucket: AnalyticsService.countBucket(for: items.count),
                ]
            )
            if wasEmpty {
                analyticsService.track(.firstRecordSaved, props: [.source: "manual"])
            }
            refreshTodayPlayback()
            if wasEmpty {
                emitRouteGuidance(.firstRecordTodayPlayback)
            }
            enqueuePetMessage(for: newItem)
            Task { await syncUpsertToCloud(newItem) }
        }
    }

    private func compatiblePrefillTitleForSave(category: HomeItem.Category) -> String? {
        guard let result = recordPrefillResult,
              let recordPrefillAmount,
              let currentAmount = Double(inputAmount.replacingOccurrences(of: ",", with: "")),
              abs(recordPrefillAmount - currentAmount) < 0.005,
              result.category == nil || result.category == category,
              let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty,
              RecordSemanticLexicon.canDisplayPrefillTitle(
                title,
                category: category,
                source: result.source
              ) else {
            return nil
        }
        return title
    }

    var ocrDraftItems: [HomeItem] {
        items
            .filter { $0.source == .ocr && $0.draftMeta != nil }
            .sorted {
                let left = $0.draftMeta?.importedAt ?? $0.createdAt
                let right = $1.draftMeta?.importedAt ?? $1.createdAt
                return left > right
            }
    }

    func makeDemoOCRDrafts() -> [OCRReceiptDraft] {
        [
            OCRReceiptDraft(
                title: "瑞幸咖啡",
                amount: 18.9,
                date: .now,
                category: .dining,
                confidence: 0.96,
                rawText: "微信支付\n商户全称 瑞幸咖啡\n金额 -¥18.90\n支付时间 \(Self.dayKey(for: .now)) 09:24:00",
                provider: .wechat
            ),
            OCRReceiptDraft(
                title: "便利店日用品",
                amount: 32.5,
                date: .now,
                category: .daily,
                confidence: 0.94,
                rawText: "支付宝\n商品说明 便利店日用品\n金额 ¥32.50\n付款时间 \(Self.dayKey(for: .now)) 19:06:00",
                provider: .alipay
            ),
        ]
    }

    func recognizeOCRDrafts(imageData: Data, isMember: Bool) async -> [OCRReceiptDraft] {
        guard dailyQuotaStore.canUseOCR(isMember: isMember) else {
            ocrStatus = ExperienceRuleCopy.ocrQuotaExhaustedMessage()
            return []
        }
        do {
            let rawDrafts = try await ocrService.recognizeReceipt(from: imageData)
            let drafts = rawDrafts.map { reviewedOCRDraft($0) }
            let count = drafts.count
            let total = drafts.reduce(0) { $0 + $1.amount }
            let message = "识别到 \(count) 条，合计 \(formatCurrency(total))。请确认后导入。"
            ocrStatus = message
            return drafts
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "这张图暂时没识别出来。可以再试一次，或手动记一笔。"
            ocrStatus = message
            return []
        }
    }

    func importOCRDrafts(_ drafts: [OCRReceiptDraft], isMember: Bool, sendToDrafts: Bool = true) -> Int {
        guard ensureLedgerWritesAllowed() else { return 0 }
        let validDrafts = drafts.filter { $0.amount > 0 }
        guard !validDrafts.isEmpty else {
            ocrStatus = "未选择可导入的账单。"
            return 0
        }
        guard dailyQuotaStore.canUseOCR(isMember: isMember) else {
            ocrStatus = ExperienceRuleCopy.ocrQuotaExhaustedMessage()
            return 0
        }

        let now = Date()
        let batchId = UUID().uuidString
        let wasEmpty = items.isEmpty
        var memorySeedItems = items
        let importedItems = validDrafts.map { rawDraft in
            let draft = reviewedOCRDraft(rawDraft)
            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: draft.title,
                    fallbackCategory: draft.category,
                    amount: draft.amount,
                    date: draft.date,
                    merchantBrandId: draft.merchantBrandId,
                    categoryLockedByUser: draft.userEditedCategory == true,
                    userEditedTitle: false,
                    source: "ocr"
                )
            )
            let emotionTag = memoryEnhancedEmotionTag(
                title: resolution.title,
                category: resolution.category,
                amount: draft.amount,
                date: draft.date,
                baseEmotionTag: resolution.emotionTag,
                existingItems: memorySeedItems
            )
            let memoryContext = memoryContextForRecord(date: draft.date)
            let item = HomeItem(
                title: resolution.title,
                amount: draft.amount,
                category: resolution.category,
                source: .ocr,
                createdAt: draft.date,
                updatedAt: now,
                emotionTag: emotionTag,
                merchantBrandId: resolution.merchantBrandId,
                draftMeta: sendToDrafts
                    ? HomeItem.DraftMeta(
                        batchId: batchId,
                        importedAt: now,
                        status: .pending
                    )
                    : nil,
                userEditedCategory: draft.userEditedCategory == true ? true : nil,
                categoryCorrectionFrom: draft.categoryCorrectionFrom,
                memoryContext: memoryContext
            )
            memorySeedItems.insert(item, at: 0)
            return item
        }
        items.insert(contentsOf: importedItems, at: 0)
        guard persistItems(upserting: importedItems) else { return 0 }
        dailyQuotaStore.markOCRImported(isMember: isMember)
        analyticsService.track(
            .ocrRecordsImported,
            props: [
                .countBucket: AnalyticsService.countBucket(for: importedItems.count),
                .destination: sendToDrafts ? "drafts" : "ledger",
            ]
        )
        if wasEmpty {
            analyticsService.track(.firstRecordSaved, props: [.source: "ocr"])
        }
        refreshTodayPlayback()
        updateOCRSuccessStatus(
            prefix: sendToDrafts ? "已导入 \(importedItems.count) 条，进入待整理" : "已直接导入 \(importedItems.count) 条",
            isMember: isMember
        )
        if let firstItem = importedItems.first {
            enqueuePetMessage(for: firstItem)
        }
        Task {
            for item in importedItems {
                await syncUpsertToCloud(item)
            }
        }
        return importedItems.count
    }

    @discardableResult
    func importAICommandDrafts(_ drafts: [AICommandRecordDraft]) -> Int {
        guard ensureLedgerWritesAllowed() else { return 0 }
        let validDrafts = drafts.filter {
            guard $0.amount > 0 else { return false }
            if case .conflict = $0.status { return false }
            return true
        }
        guard !validDrafts.isEmpty else { return 0 }

        let wasEmpty = items.isEmpty
        let now = Date()
        var memorySeedItems = items
        let importedItems = validDrafts.map { draft in
            let resolution = RecordDraftResolutionService.resolve(
                RecordDraftResolutionInput(
                    rawTitle: draft.title,
                    fallbackCategory: draft.category,
                    amount: draft.amount,
                    date: draft.date,
                    merchantBrandId: MerchantBrandCatalog.matchBrand(in: draft.title)?.id,
                    categoryLockedByUser: true,
                    userEditedTitle: true,
                    source: "ai_command"
                )
            )
            let emotionTag = memoryEnhancedEmotionTag(
                title: resolution.title,
                category: resolution.category,
                amount: draft.amount,
                date: draft.date,
                baseEmotionTag: resolution.emotionTag,
                existingItems: memorySeedItems
            )
            let item = HomeItem(
                title: resolution.title,
                amount: draft.amount,
                category: resolution.category,
                source: .manual,
                createdAt: draft.date,
                updatedAt: now,
                emotionTag: emotionTag,
                merchantBrandId: resolution.merchantBrandId,
                userEditedTitle: true,
                userEditedCategory: true,
                memoryContext: memoryContextForRecord(date: draft.date)
            )
            memorySeedItems.insert(item, at: 0)
            return item
        }

        items.insert(contentsOf: importedItems, at: 0)
        guard persistItems(upserting: importedItems) else { return 0 }
        analyticsService.track(
            .aiCommandRecordsSaved,
            props: [
                .countBucket: AnalyticsService.countBucket(for: importedItems.count),
            ]
        )
        if wasEmpty {
            analyticsService.track(.firstRecordSaved, props: [.source: "ai_command"])
        }
        refreshTodayPlayback()
        if wasEmpty {
            emitRouteGuidance(.firstRecordTodayPlayback)
        }
        if let firstItem = importedItems.first {
            enqueuePetMessage(for: firstItem)
        }
        Task {
            for item in importedItems {
                await syncUpsertToCloud(item)
            }
        }
        return importedItems.count
    }

    private func updateOCRSuccessStatus(prefix: String, isMember: Bool) {
        let remaining = dailyQuotaStore.ocrRemaining(isMember: false)
        ocrStatus = ExperienceRuleCopy.ocrSuccessMessage(
            prefix: prefix,
            remaining: remaining,
            isMember: isMember
        )
    }

    func updateOCRDraftStatus(id: UUID, isResolved: Bool) {
        guard ensureLedgerWritesAllowed() else { return }
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        var updated = items[idx]
        updated.draftMeta?.status = isResolved ? .resolved : .pending
        updated.updatedAt = Date()
        items[idx] = updated
        guard persistItems(upserting: [updated]) else { return }
        clearOCRStatusIfNoPendingDrafts()
        Task { await syncUpsertToCloud(updated) }
    }

    private func clearOCRStatusIfNoPendingDrafts() {
        guard !items.contains(where: { $0.source == .ocr && $0.draftMeta?.status == .pending }) else { return }
        ocrStatus = ""
    }

    func clearOCRRecognitionStatus() {
        ocrStatus = ""
    }

    private func brandCategory(for brandId: String?) -> HomeItem.Category? {
        MerchantBrandCatalog.definition(for: brandId)?.category
    }

    private func reviewedOCRDraft(_ draft: OCRReceiptDraft) -> OCRReceiptDraft {
        var reviewed = draft
        let brand = MerchantBrandCatalog.definition(for: draft.merchantBrandId)
            ?? MerchantBrandCatalog.matchOCRBrand(in: "\(draft.title)\n\(draft.rawText)")
        if reviewed.merchantBrandId == nil {
            reviewed.merchantBrandId = brand?.id
        }
        guard reviewed.userEditedCategory != true else { return reviewed }

        if let brand {
            reviewed.category = brand.category
            return reviewed
        }

        let semanticCandidate = HomeItem(
            title: "\(draft.title)\n\(draft.rawText)",
            amount: draft.amount,
            category: draft.category,
            source: .ocr,
            createdAt: draft.date,
            merchantBrandId: reviewed.merchantBrandId
        )
        let scene = LifeSceneSemanticService.classify(semanticCandidate)
        if scene.confidenceTier == .strong {
            reviewed.category = scene.category
        }
        return reviewed
    }

    func updateOCRDraftCategory(id: UUID, category: HomeItem.Category) {
        guard ensureLedgerWritesAllowed() else { return }
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        let originalCategory = items[idx].category
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: items[idx].title,
                fallbackCategory: category,
                amount: items[idx].amount,
                date: items[idx].createdAt,
                merchantBrandId: items[idx].merchantBrandId,
                categoryLockedByUser: true,
                userEditedTitle: items[idx].userEditedTitle == true,
                source: "ocrCategory"
            )
        )
        var updated = items[idx]
        updated.title = resolution.title
        updated.category = resolution.category
        updated.emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: updated.amount,
            date: updated.createdAt,
            baseEmotionTag: resolution.emotionTag,
            excluding: updated.id
        )
        updated.merchantBrandId = resolution.merchantBrandId
        updated.userEditedCategory = true
        if updated.memoryContext == nil {
            updated.memoryContext = memoryContextForRecord(date: updated.createdAt)
        }
        if originalCategory != resolution.category {
            updated.categoryCorrectionFrom = originalCategory
        }
        updated.updatedAt = Date()
        items[idx] = updated
        guard persistItems(upserting: [updated]) else { return }
        Task { await syncUpsertToCloud(updated) }
    }

    func updateOCRDraftAmount(id: UUID, amount: Double) {
        guard ensureLedgerWritesAllowed() else { return }
        guard amount > 0,
              let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].draftMeta != nil else { return }
        var updated = items[idx]
        updated.amount = amount
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: updated.title,
                fallbackCategory: updated.category,
                amount: amount,
                date: updated.createdAt,
                merchantBrandId: updated.merchantBrandId,
                categoryLockedByUser: true,
                userEditedTitle: updated.userEditedTitle == true,
                source: "ocrAmount"
            )
        )
        updated.title = resolution.title
        updated.category = resolution.category
        updated.emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: amount,
            date: updated.createdAt,
            baseEmotionTag: resolution.emotionTag,
            excluding: updated.id
        )
        updated.merchantBrandId = resolution.merchantBrandId
        updated.userEditedCategory = updated.userEditedCategory == true ? true : nil
        if updated.memoryContext == nil {
            updated.memoryContext = memoryContextForRecord(date: updated.createdAt)
        }
        updated.updatedAt = Date()
        items[idx] = updated
        guard persistItems(upserting: [updated]) else { return }
        Task { await syncUpsertToCloud(updated) }
    }

    func updateOCRDraftTitle(id: UUID, title: String) {
        guard ensureLedgerWritesAllowed() else { return }
        guard let idx = items.firstIndex(where: { $0.id == id }),
              items[idx].draftMeta != nil else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty,
              cleanTitle != items[idx].title else { return }
        var updated = items[idx]
        updated.title = cleanTitle
        updated.userEditedTitle = true
        _ = updateItem(updated)
    }

    func deleteOCRDraftItem(id: UUID) {
        guard ensureLedgerWritesAllowed() else { return }
        guard let idx = items.firstIndex(where: { $0.id == id }), items[idx].draftMeta != nil else { return }
        items.remove(at: idx)
        guard persistItems(deleting: [id]) else { return }
        clearOCRStatusIfNoPendingDrafts()
        analyticsService.track(.ocrDraftDeleted)
        refreshTodayPlayback()
        Task { await syncDeleteFromCloud(id: id) }
    }

    func clearResolvedOCRDrafts() {
        guard ensureLedgerWritesAllowed() else { return }
        var nextItems = items
        var changedItems: [HomeItem] = []
        let updatedAt = Date()
        for idx in nextItems.indices where nextItems[idx].draftMeta?.status == .resolved {
            var updated = nextItems[idx]
            updated.draftMeta = nil
            updated.updatedAt = updatedAt
            nextItems[idx] = updated
            changedItems.append(updated)
        }
        guard !changedItems.isEmpty else { return }
        items = nextItems
        clearOCRStatusIfNoPendingDrafts()
        guard persistItems(upserting: changedItems) else { return }
        analyticsService.track(
            .ocrDraftsResolved,
            props: [.countBucket: AnalyticsService.countBucket(for: changedItems.count)]
        )
        Task {
            for item in changedItems {
                await syncUpsertToCloud(item)
            }
        }
    }

    func resolveAllPendingOCRDrafts() {
        guard ensureLedgerWritesAllowed() else { return }
        var nextItems = items
        var changedItems: [HomeItem] = []
        let updatedAt = Date()
        for idx in nextItems.indices where nextItems[idx].draftMeta?.status == .pending {
            var updated = nextItems[idx]
            updated.draftMeta?.status = .resolved
            updated.updatedAt = updatedAt
            nextItems[idx] = updated
            changedItems.append(updated)
        }
        guard !changedItems.isEmpty else { return }
        items = nextItems
        guard persistItems(upserting: changedItems) else { return }
        clearOCRStatusIfNoPendingDrafts()
        analyticsService.track(
            .ocrDraftsResolveAll,
            props: [.countBucket: AnalyticsService.countBucket(for: changedItems.count)]
        )
        Task {
            for item in changedItems {
                await syncUpsertToCloud(item)
            }
        }
    }

    func delete(at offsets: IndexSet) {
        guard ensureLedgerWritesAllowed() else { return }
        let deletedIDs = offsets.compactMap { items.indices.contains($0) ? items[$0].id : nil }
        items.remove(atOffsets: offsets)
        guard persistItems(deleting: Set(deletedIDs)) else { return }
        analyticsService.track(
            .recordDeletedBatch,
            props: [.countBucket: AnalyticsService.countBucket(for: deletedIDs.count)]
        )
        refreshTodayPlayback()
        Task {
            for id in deletedIDs {
                await syncDeleteFromCloud(id: id)
            }
        }
    }

    @discardableResult
    func updateItem(_ updated: HomeItem) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return false }
        let original = items[idx]
        var resolved = updated
        let titleResult = UserContentRiskService.shared.validateManualNote(updated.title, allowEmpty: false)
        guard titleResult.isAllowed else {
            recordInputMessage = titleResult.message
            return false
        }
        recordInputMessage = nil
        let cleanTitle = titleResult.value
        let matchedBrand = MerchantBrandCatalog.matchBrand(in: cleanTitle)
        let brandId = matchedBrand?.id ?? updated.merchantBrandId
        let categoryWasEdited = updated.category != original.category
        let categoryOverridesBrand = brandCategory(for: brandId).map { updated.category != $0 } ?? false
        let titleWasEdited = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            != original.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldTreatTitleAsUserEdited = resolved.userEditedTitle == true || titleWasEdited
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: cleanTitle,
                fallbackCategory: updated.category,
                amount: resolved.amount,
                date: resolved.createdAt,
                merchantBrandId: brandId,
                categoryLockedByUser: categoryWasEdited || categoryOverridesBrand,
                userEditedTitle: shouldTreatTitleAsUserEdited,
                source: "edit"
            )
        )
        resolved.title = resolution.title
        resolved.category = resolution.category
        if resolved.memoryContext == nil,
           Calendar.current.isDate(resolved.createdAt, inSameDayAs: original.createdAt) {
            resolved.memoryContext = original.memoryContext
        }
        resolved.emotionTag = memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: resolved.amount,
            date: resolved.createdAt,
            baseEmotionTag: resolution.emotionTag,
            existingItems: items,
            excluding: resolved.id,
            weatherOverride: storedWeatherSnapshot(from: resolved.memoryContext),
            allowLiveWeather: false
        )
        resolved.merchantBrandId = resolution.merchantBrandId
        if resolved.userEditedTitle == true || titleWasEdited {
            resolved.userEditedTitle = true
        }
        if original.userEditedCategory == true || categoryWasEdited {
            resolved.userEditedCategory = true
        }
        if categoryWasEdited {
            resolved.categoryCorrectionFrom = original.category
            resolved.scenePackId = nil
        } else if original.categoryCorrectionFrom != nil {
            resolved.categoryCorrectionFrom = original.categoryCorrectionFrom
        }
        resolved.updatedAt = Date()
        items[idx] = resolved
        guard persistItems(upserting: [resolved]) else { return false }
        analyticsService.track(.recordUpdated)
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(resolved) }
        return true
    }

    @discardableResult
    func attachMemoryImage(_ imageData: Data, to itemID: UUID) -> Bool {
        attachMemoryImages([imageData], to: itemID)
    }

    @discardableResult
    func attachMemoryImages(
        _ imageDatas: [Data],
        to itemID: UUID,
        coverImageIndex: Int? = nil,
        anchorReason: PhotoMemoryPromptReason? = nil
    ) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return false }
        let originalCount = items[idx].memoryImageCount
        let availableSlots = max(0, 9 - originalCount)
        let cleanImages = Array(imageDatas.filter { !$0.isEmpty }.prefix(availableSlots))
        guard !cleanImages.isEmpty else { return false }
        var updated = items[idx]
        updated.appendMemoryImages(cleanImages)
        let selectedNewIndex = min(max(coverImageIndex ?? 0, 0), cleanImages.count - 1)
        if originalCount == 0 || updated.coverMemoryImageIndex == nil {
            updated.coverMemoryImageIndex = originalCount + selectedNewIndex
        }
        let reason = anchorReason ?? PhotoMemoryPromptPolicy.anchorReason(for: updated)
        updated.memoryAnchorRole = reason.assetRole
        updated.memoryAnchorSceneHint = reason.sceneHint
        updated.memoryAnchorCaption = reason.memoryAnchorCaption
        updated.memoryAnchorCreatedAt = updated.memoryAnchorCreatedAt ?? Date()
        updated.updatedAt = Date()
        items[idx] = updated
        guard persistItems(upserting: [updated]) else { return false }
        analyticsService.track(
            .recordMemoryImageAttached,
            props: [.imageCountBucket: AnalyticsService.countBucket(for: cleanImages.count)]
        )
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(updated) }
        return true
    }

    @discardableResult
    func removeMemoryImage(from itemID: UUID) -> Bool {
        removeMemoryImage(at: 0, from: itemID)
    }

    @discardableResult
    func removeMemoryImage(at imageIndex: Int, from itemID: UUID) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return false }
        guard (0..<items[idx].memoryImageCount).contains(imageIndex) else { return false }
        var updated = items[idx]
        updated.removeMemoryImage(at: imageIndex)
        let remainingImageCount = updated.memoryImageCount
        if remainingImageCount == 0 {
            updated.coverMemoryImageIndex = nil
            updated.memoryAnchorRole = nil
            updated.memoryAnchorSceneHint = nil
            updated.memoryAnchorCaption = nil
            updated.memoryAnchorCreatedAt = nil
        } else {
            let currentCover = updated.coverMemoryImageIndex ?? 0
            if imageIndex < currentCover {
                updated.coverMemoryImageIndex = currentCover - 1
            } else if imageIndex == currentCover {
                updated.coverMemoryImageIndex = min(currentCover, remainingImageCount - 1)
            }
        }
        updated.updatedAt = Date()
        items[idx] = updated
        guard persistItems(upserting: [updated]) else { return false }
        analyticsService.track(
            .recordMemoryImageRemoved,
            props: [.imageCountBucket: AnalyticsService.countBucket(for: updated.memoryImageCount)]
        )
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(updated) }
        return true
    }

    @discardableResult
    func setCoverMemoryImageIndex(_ imageIndex: Int, for itemID: UUID) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        guard let idx = items.firstIndex(where: { $0.id == itemID }),
              (0..<items[idx].memoryImageCount).contains(imageIndex) else { return false }
        var updated = items[idx]
        updated.coverMemoryImageIndex = imageIndex
        if updated.memoryAnchorRole == nil || updated.memoryAnchorSceneHint == nil {
            let reason = PhotoMemoryPromptPolicy.anchorReason(for: updated)
            updated.memoryAnchorRole = reason.assetRole
            updated.memoryAnchorSceneHint = reason.sceneHint
            updated.memoryAnchorCaption = updated.memoryAnchorCaption ?? reason.memoryAnchorCaption
            updated.memoryAnchorCreatedAt = updated.memoryAnchorCreatedAt ?? Date()
        }
        updated.updatedAt = Date()
        items[idx] = updated
        guard persistItems(upserting: [updated]) else { return false }
        analyticsService.track(.recordMemoryCoverSelected)
        refreshTodayPlayback()
        Task { await syncUpsertToCloud(updated) }
        return true
    }

    func syncCloudLedgerNow() async {
        guard !LocalStore.isReleaseFixtureMode else {
            syncStatusMessage = "QA 发布夹具使用隔离账本，已停用云端同步；R-11 请使用专用测试账号单独验证。"
            return
        }
        guard ensureLedgerWritesAllowed() else {
            syncStatusMessage = recordInputMessage
            return
        }
        let context = cloudContext()
        guard let context else {
            syncStatusMessage = "当前只保存在本机。登录并开启云端备份后，只同步账单字段；记忆照片仍在本机。"
            return
        }
        isSyncingCloudLedger = true
        defer { isSyncingCloudLedger = false }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            let remoteItems = try await service.fetchAll().sorted { $0.createdAt > $1.createdAt }
            let merged = mergeLedgers(local: items, remote: remoteItems).sorted { $0.createdAt > $1.createdAt }
            let changes = ledgerChanges(from: items, to: merged)
            items = merged
            guard persistItems(upserting: changes.upserts, deleting: changes.deletedIDs) else {
                syncStatusMessage = "同步结果没有写入本机，原账本仍保留。请重启后再试。"
                return
            }
            // Re-upload merged result to converge both sides (idempotent upsert).
            for item in merged {
                do {
                    try await service.upload(item)
                } catch {
                    guard CloudSessionFailurePolicy.shouldInvalidateSession(for: error) else {
                        continue
                    }
                    CloudSessionInvalidationService.invalidate()
                    syncStatusMessage = CloudSessionInvalidationService.userMessage
                    return
                }
            }
            syncStatusMessage = "账单字段已同步；记忆照片仍只在本机。重复记录已保留最新版本。"
        } catch {
            if CloudSessionFailurePolicy.shouldInvalidateSession(for: error) {
                CloudSessionInvalidationService.invalidate()
                syncStatusMessage = CloudSessionInvalidationService.userMessage
            } else {
                syncStatusMessage = "同步没有完成，请稍后再试。你的本机记录已保留。"
            }
        }
    }

    @discardableResult
    func restoreLocalBackup(
        _ preparedImport: LedgerLocalBackupPreparedImport
    ) async -> LedgerLocalBackupRestoreSummary? {
        guard ensureLedgerWritesAllowed() else { return nil }
        guard !isRestoringLocalBackup else { return nil }
        guard !isSyncingCloudLedger else {
            syncStatusMessage = "云端账本仍在合并，请稍后再恢复本地备份。"
            return nil
        }

        let plan: LedgerLocalBackupRestorePlan
        do {
            plan = try LedgerLocalBackupRestorePlanner.makePlan(
                localItems: items,
                backupItems: preparedImport.items
            )
        } catch {
            syncStatusMessage = (error as? LocalizedError)?.errorDescription
                ?? "这份备份暂时无法恢复，本机原账本仍保留。"
            return nil
        }

        guard !plan.changes.isEmpty else {
            return plan.summary
        }

        isRestoringLocalBackup = true
        defer { isRestoringLocalBackup = false }
        let didPersist = await Task.detached(priority: .userInitiated) {
            LocalStore.saveHomeItemChanges(
                plan.changes,
                currentItemsForFallback: plan.mergedItems
            )
        }.value
        guard didPersist else {
            let message = "这次恢复没有写入本机，本机原账本和照片仍保留。请稍后再试。"
            recordInputMessage = message
            syncStatusMessage = message
            return nil
        }

        items = plan.mergedItems
        refreshTodayPlayback()
        return plan.summary
    }

    func generateMonthlyInsight(settings: AppSettings) async -> MonthlyInsightReport {
        let performanceStartedAt = ProcessInfo.processInfo.systemUptime
        isGeneratingMonthlyInsight = true
        insightErrorMessage = nil
        defer { isGeneratingMonthlyInsight = false }

        await Task.yield()

        let input = InsightComputationInput(
            items: items,
            isMember: hasMemberAccess,
            now: Date()
        )
        let preparation = await withTaskGroup(
            of: MonthlyInsightPreparation.self,
            returning: MonthlyInsightPreparation.self
        ) { group in
            group.addTask(priority: .userInitiated) {
                InsightComputationService.monthlyPreparation(input)
            }
            return await group.next()!
        }
        let local = preparation.blocks
        var report = MonthlyInsightReport(
            summary: local.summary,
            structure: local.structure,
            advice: local.advice,
            source: .fallback
        )

        if settings.useRemoteAI {
            let apiKey = KeychainService.loadAIAPIKey()
            let endpoint = settings.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            let isDirectModelEndpoint = endpoint.isEmpty || endpoint.contains("open.bigmodel.cn")
            if AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit),
               !(isDirectModelEndpoint && apiKey.isEmpty) {
                do {
                    let payload = try await aiReportService.generateInsight(
                        snapshot: preparation.snapshot,
                        endpoint: endpoint,
                        apiKey: apiKey,
                        tone: settings.aiTone,
                        model: settings.aiModel,
                        feature: "monthly"
                    )
                    report = MonthlyInsightReport(
                        summary: payload.summary,
                        structure: payload.action,
                        advice: payload.encourage,
                        source: .live
                    )
                    _ = AIUsageLimiter.consumeOnce(limitPerMonth: settings.remoteAIMonthlyLimit)
                } catch {
                    insightErrorMessage = remoteAIInsightFallbackMessage(for: error)
                    report.source = .errorFallback
                }
            } else {
                insightErrorMessage = !AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit)
                    ? "本月远程模型调用额度已达上限。"
                    : "直连模型需要 API Key，已使用本地规则。"
                report.source = .errorFallback
            }
        }

        analyticsService.track(
            .aiMonthlyGenerated,
            props: [
                .mode: report.source.analyticsValue,
                .ledgerSizeBucket: AnalyticsService.countBucket(for: input.items.count),
                .outcome: AnalyticsOutcome.success.rawValue,
            ]
        )
        analyticsService.trackPerformance(
            operation: .monthlyInsight,
            startedAtUptime: performanceStartedAt,
            itemCount: input.items.count
        )
        return report
    }

    var recordLearningHint: String? {
        let normalizedAmount = inputAmount.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else { return nil }

        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""

        if categoryLockedByUser {
            return "这次按「\(selectedCategory.label)」放好。"
        }
        if MerchantBrandCatalog.matchBrand(in: trimmedNote) != nil {
            return nil
        }
        if semanticCategory(from: trimmedNote) != nil {
            return nil
        }
        guard let result = recordPrefillResult,
              let recordPrefillAmount,
              abs(recordPrefillAmount - amount) < 0.005 else {
            return items.count < 6 ? "先帮你放到合适分类。" : nil
        }

        switch result.source {
        case "scene_habit":
            if result.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return "这个时间附近常这样记。"
            }
            if let category = result.category {
                if category == .other {
                    return "还没看出明确场景，先放到「其他」。"
                }
                return "这个时间附近常是「\(category.label)」。"
            }
            return nil
        case "habit":
            if let category = result.category {
                if category == .other {
                    return "还没看出明确场景，先放到「其他」。"
                }
                return "这个时间附近常是「\(category.label)」。"
            }
            return nil
        case "frequent":
            if let category = result.category {
                if category == .other {
                    return "还没看出明确场景，先放到「其他」。"
                }
                return "这个时间附近常是「\(category.label)」。"
            }
            return nil
        case "generic":
            return items.count < 6
                ? "先帮你放到合适分类。"
                : nil
        case "brand":
            return nil
        default:
            return nil
        }
    }

    private func enqueuePetMessage(for record: HomeItem) {
        let settings = LocalStore.loadSettings()
        guard settings.petCompanionEnabled else {
            petMessage = nil
            return
        }
        let currentItems = items
        let cachedWeather = WeatherCompanionService.shared.cachedSnapshot
        Task {
            let message = await petCompanionService.buildContextualMessage(
                record: record,
                weather: cachedWeather,
                settings: settings,
                todayItems: currentItems
            )
            if let message, LocalStore.loadSettings().petCompanionEnabled {
                petMessage = message
            }
            if settings.weatherCompanionEnabled {
                WeatherCompanionService.shared.refreshWeatherInBackground(refreshGeo: false)
            }
        }
    }

    func recommendCategory(for amountText: String) -> HomeItem.Category? {
        recommendCategoryResult(for: amountText)?.recommended
    }

    func recommendCategoryResult(for amountText: String) -> CategoryRecommendResult? {
        let normalizedAmount = amountText.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else { return nil }
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""
        let brand = MerchantBrandCatalog.matchBrand(in: trimmedNote)
        let noteSemanticCategory = semanticCategory(from: trimmedNote)
        if !categoryLockedByUser {
            if let brand {
                if MerchantBrandCatalog.isConvenienceStoreBrand(brand),
                   let noteSemanticCategory,
                   noteSemanticCategory != brand.category {
                    return CategoryRecommendResult(recommended: noteSemanticCategory, reasonTag: "semantic")
                }
                return CategoryRecommendResult(recommended: brand.category, reasonTag: "brand")
            }
            if let noteSemanticCategory {
                return CategoryRecommendResult(recommended: noteSemanticCategory, reasonTag: "semantic")
            }
        }
        if !categoryLockedByUser,
           let category = recordPrefillResult?.category,
           recordPrefillResult?.source != "generic",
           let recordPrefillAmount,
           abs(recordPrefillAmount - amount) < 0.005,
           (recordPrefillResult?.confidence ?? 0) >= 0.55 {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        if let frequentSuggestion = frequentRecordAmountSuggestion(for: amount, at: selectedDate),
           frequentSuggestionCanOverrideNote(frequentSuggestion, note: trimmedNote),
           !categoryLockedByUser {
            return CategoryRecommendResult(recommended: frequentSuggestion.category, reasonTag: "frequent")
        }
        if !categoryLockedByUser,
           let category = recordPrefillResult?.category,
           recordPrefillResult?.source == "generic",
           let recordPrefillAmount,
           abs(recordPrefillAmount - amount) < 0.005 {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        guard !trimmedNote.isEmpty else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        return categoryRecommendService.recommend(
            input: CategoryRecommendInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: trimmedNote,
                locked: categoryLockedByUser,
                context: currentRecordContextSignal()
            )
        )
    }

    private func currentRecordContextSignal() -> RecordContextSignal {
        let settings = LocalStore.loadSettings()
        // Coarse local context only: cached weather plus time bands, no location trail or POI.
        let weather = settings.weatherCompanionEnabled && shouldAttachLiveContext(to: selectedDate)
            ? WeatherCompanionService.shared.cachedSnapshot
            : nil
        return RecordContextSignal(referenceDate: selectedDate, weather: weather)
    }

    private func memoryContextForRecord(date: Date) -> HomeItem.MemoryContext? {
        let settings = LocalStore.loadSettings()
        guard settings.weatherCompanionEnabled,
              shouldAttachLiveContext(to: date) else {
            return nil
        }
        let weather = WeatherCompanionService.shared.cachedSnapshot
        let city = WeatherCompanionService.shared.cachedCitySemanticSnapshot
        let context = HomeItem.MemoryContext(
            weatherKind: RecordMemoryContextService.weatherKindCode(from: weather),
            temperatureCelsius: weather?.temp,
            cityName: city?.cityName,
            semanticPlace: city?.semanticPlace
        )
        let hasValue = context.weatherKind != nil
            || context.temperatureCelsius != nil
            || context.cityName != nil
            || context.semanticPlace != nil
        return hasValue ? context : nil
    }

    private func memoryEnhancedEmotionTag(
        title: String,
        category: HomeItem.Category,
        amount: Double,
        date: Date,
        baseEmotionTag: String,
        existingItems: [HomeItem]? = nil,
        excluding excludedID: UUID? = nil,
        weatherOverride: WeatherSnapshot? = nil,
        allowLiveWeather: Bool = true
    ) -> String {
        let settings = LocalStore.loadSettings()
        let weather = weatherOverride ?? (allowLiveWeather && settings.weatherCompanionEnabled && shouldAttachLiveContext(to: date)
            ? WeatherCompanionService.shared.cachedSnapshot
            : nil)
        let memoryItems = (existingItems ?? items).filter { item in
            guard let excludedID else { return true }
            return item.id != excludedID
        }
        return RecordMemoryContextService.enhancedEmotionTag(
            input: RecordMemoryContextInput(
                title: title,
                category: category,
                amount: amount,
                date: date,
                baseEmotionTag: baseEmotionTag,
                existingItems: memoryItems,
                weather: weather
            )
        )
    }

    private func storedWeatherSnapshot(from context: HomeItem.MemoryContext?) -> WeatherSnapshot? {
        guard let context else { return nil }
        let code: Int?
        switch context.weatherKind {
        case "rain":
            code = 61
        case "snow":
            code = 71
        case "hot", "cold", "normal":
            code = nil
        default:
            code = nil
        }
        guard code != nil || context.temperatureCelsius != nil else { return nil }
        return WeatherSnapshot(
            temp: context.temperatureCelsius,
            weatherCode: code,
            ts: Date()
        )
    }

    private func shouldAttachLiveContext(to date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }

    func refreshRecordPrefill() {
        let now = Date()
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: recordInputAssistanceRevision,
            referenceDate: selectedDate,
            referenceDateEditedByUser: selectedDateEditedByUser
        )

        if recordInputHistorySnapshot?.key != historyKey {
            prepareRecordInputHistorySnapshot(key: historyKey, now: now)
        }

        let normalizedAmount = inputAmount.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else {
            invalidateRecordPrefillSnapshot()
            return
        }
        guard !categoryLockedByUser else {
            invalidateRecordPrefillSnapshot()
            return
        }
        guard let history = recordInputHistorySnapshot,
              history.key == historyKey else {
            invalidateRecordPrefillSnapshot()
            return
        }

        prepareRecordPrefillSnapshot(
            amount: amount,
            history: history
        )
    }

    func refreshRecordWarmupSuggestions() {
        let key = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: recordInputAssistanceRevision,
            referenceDate: selectedDate,
            referenceDateEditedByUser: selectedDateEditedByUser
        )
        guard recordInputHistorySnapshot?.key != key else { return }
        prepareRecordInputHistorySnapshot(key: key, now: Date())
    }

    func cancelRecordInputAssistancePreparation() {
        recordInputHistoryPreparationTask?.cancel()
        recordInputHistoryPreparationTask = nil
        recordInputHistoryPreparationKey = nil
        recordInputHistoryRequestID = UUID()
        let hadPendingPrefill = recordPrefillPreparationTask != nil
        recordPrefillPreparationTask?.cancel()
        recordPrefillPreparationTask = nil
        recordPrefillRequestID = UUID()
        if hadPendingPrefill {
            recordPrefillPreparationKey = nil
        }
    }

    private func prepareRecordInputHistorySnapshot(
        key: RecordInputHistoryKey,
        now: Date
    ) {
        guard recordInputHistoryPreparationKey != key else { return }

        recordInputHistoryPreparationTask?.cancel()
        recordInputHistoryRequestID = UUID()
        let requestID = recordInputHistoryRequestID
        recordInputHistoryPreparationKey = key
        recordWarmupSuggestions = []
        invalidateRecordPrefillSnapshot()

        let input = RecordInputHistoryPreparationInput(
            key: key,
            items: items,
            referenceDate: selectedDate,
            now: now
        )
        recordInputHistoryPreparationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, recordInputHistoryRequestID == requestID else { return }
            let snapshot = await withTaskGroup(
                of: RecordInputHistorySnapshot?.self,
                returning: RecordInputHistorySnapshot?.self
            ) { group in
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else { return nil }
                    return RecordInputAssistanceComputation.historySnapshot(input)
                }
                return await group.next() ?? nil
            }
            guard let snapshot,
                  !Task.isCancelled,
                  recordInputHistoryRequestID == requestID,
                  RecordInputAssistanceComputation.historyKey(
                    ledgerRevision: recordInputAssistanceRevision,
                    referenceDate: selectedDate,
                    referenceDateEditedByUser: selectedDateEditedByUser
                  ) == key else {
                return
            }
            recordInputHistorySnapshot = snapshot
            recordInputHistoryPreparationKey = nil
            recordInputHistoryPreparationTask = nil
            if recordWarmupSuggestions != snapshot.frequentSuggestions {
                recordWarmupSuggestions = snapshot.frequentSuggestions
            }
            refreshRecordPrefill()
        }
    }

    private func prepareRecordPrefillSnapshot(
        amount: Double,
        history: RecordInputHistorySnapshot
    ) {
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""
        let context = currentRecordContextSignal()
        if let existingKey = recordPrefillPreparationKey,
           existingKey.historyKey == history.key,
           existingKey.amount == amount,
           existingKey.referenceDate == selectedDate,
           existingKey.noteDraft == trimmedNote,
           existingKey.context == context {
            return
        }
        applyProvisionalRecordCategory(
            for: trimmedNote,
            amount: amount,
            history: history
        )
        let key = RecordPrefillPreparationKey(
            historyKey: history.key,
            amount: amount,
            referenceDate: selectedDate,
            noteDraft: trimmedNote,
            selectedCategory: selectedCategory,
            context: context
        )
        guard recordPrefillPreparationKey != key else { return }

        recordPrefillPreparationTask?.cancel()
        recordPrefillRequestID = UUID()
        let requestID = recordPrefillRequestID
        recordPrefillPreparationKey = key
        if recordPrefillResult != nil {
            recordPrefillResult = nil
        }
        recordPrefillAmount = nil
        if recordRecommendedCategory != nil {
            recordRecommendedCategory = nil
        }
        let input = RecordPrefillPreparationInput(
            key: key,
            history: history,
            amount: amount,
            referenceDate: selectedDate,
            now: Date(),
            noteDraft: trimmedNote,
            selectedCategory: selectedCategory,
            context: context
        )
        recordPrefillPreparationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, recordPrefillRequestID == requestID else { return }
            let snapshot = await withTaskGroup(
                of: RecordPrefillSnapshot?.self,
                returning: RecordPrefillSnapshot?.self
            ) { group in
                group.addTask(priority: .userInitiated) {
                    guard !Task.isCancelled else { return nil }
                    return RecordInputAssistanceComputation.prefillSnapshot(input)
                }
                return await group.next() ?? nil
            }
            guard let snapshot,
                  !Task.isCancelled,
                  recordPrefillRequestID == requestID,
                  !categoryLockedByUser,
                  recordInputHistorySnapshot?.key == history.key else {
                return
            }
            applyRecordPrefillSnapshot(snapshot)
            recordPrefillPreparationTask = nil
        }
    }

    private func applyRecordPrefillSnapshot(_ snapshot: RecordPrefillSnapshot) {
        guard recordPrefillPreparationKey == snapshot.key else { return }
        if let category = snapshot.appliedCategory {
            applyRecommendedCategory(category)
        }
        if !RecordInputAssistanceComputation.prefillResultsEqual(recordPrefillResult, snapshot.result) {
            recordPrefillResult = snapshot.result
        }
        recordPrefillAmount = snapshot.amount
        if recordRecommendedCategory != snapshot.categoryGridRecommendation {
            recordRecommendedCategory = snapshot.categoryGridRecommendation
        }
        if let category = snapshot.appliedCategory,
           category != snapshot.key.selectedCategory {
            recordPrefillPreparationKey = RecordPrefillPreparationKey(
                historyKey: snapshot.key.historyKey,
                amount: snapshot.key.amount,
                referenceDate: snapshot.key.referenceDate,
                noteDraft: snapshot.key.noteDraft,
                selectedCategory: category,
                context: snapshot.key.context
            )
        }
    }

    private func applyProvisionalRecordCategory(
        for note: String,
        amount: Double,
        history: RecordInputHistorySnapshot
    ) {
        let brand = MerchantBrandCatalog.matchBrand(in: note)
        let semanticCategory = RecordSemanticLexicon.semanticCategory(of: note)
        let frequentCategory = history.frequentSuggestions.first { suggestion in
            abs(suggestion.amount - amount) < 0.005
        }?.category
        if let category = brand?.category ?? semanticCategory ?? frequentCategory {
            applyRecommendedCategory(category)
            return
        }
        guard !categoryLockedByUser,
              let lastAutoRecommendedCategory,
              selectedCategory == lastAutoRecommendedCategory else {
            return
        }
        selectedCategory = .other
        self.lastAutoRecommendedCategory = nil
    }

    private func invalidateRecordPrefillSnapshot() {
        recordPrefillPreparationTask?.cancel()
        recordPrefillPreparationTask = nil
        recordPrefillPreparationKey = nil
        recordPrefillRequestID = UUID()
        if recordPrefillResult != nil {
            recordPrefillResult = nil
        }
        recordPrefillAmount = nil
        if recordRecommendedCategory != nil {
            recordRecommendedCategory = nil
        }
    }

    private func invalidateRecordInputHistorySnapshot() {
        recordInputHistoryPreparationTask?.cancel()
        recordInputHistoryPreparationTask = nil
        recordInputHistoryPreparationKey = nil
        recordInputHistoryRequestID = UUID()
        recordInputHistorySnapshot = nil
        if !recordWarmupSuggestions.isEmpty {
            recordWarmupSuggestions = []
        }
        invalidateRecordPrefillSnapshot()
    }

    private func semanticCategory(from note: String) -> HomeItem.Category? {
        RecordSemanticLexicon.semanticCategory(of: note)
    }

    private func frequentSuggestionCanOverrideNote(
        _ suggestion: FrequentRecordAmountSuggestion,
        note: String
    ) -> Bool {
        guard suggestion.confidence >= 0.67 else { return false }
        let semanticCategories = RecordSemanticLexicon.matchingCategories(in: note)
        guard !semanticCategories.isEmpty else { return true }
        return semanticCategories.contains(suggestion.category)
    }

    func clearRecordInputMessage() {
        guard recordInputMessage != nil else { return }
        recordInputMessage = nil
    }

    func clearLocalLedgerData() {
        guard ensureLedgerWritesAllowed() else { return }
        let deletedIDs = Set(items.map(\.id))
        items = []
        guard persistItems(deleting: deletedIDs) else { return }
        insights = []
        latestPlayback = nil
        latestActionCard = nil
        activeRouteGuidance = nil
        currentWeekTraceSeenKey = nil
        invalidateRecordPrefillSnapshot()
        petMessage = nil
        LocalStore.saveDailyInsights([])
        UserDefaults.standard.removeObject(forKey: "latest_action_card_v1")
        UserDefaults.standard.removeObject(forKey: Self.currentWeekTraceSeenDefaultsKey)
    }

    func selectCategory(_ category: HomeItem.Category) {
        rememberCategoryCorrectionIfNeeded(to: category)
        selectedCategory = category
        categoryLockedByUser = true
        invalidateRecordPrefillSnapshot()
    }

    func preferNoteSemanticsForCurrentDraft() {
        guard categoryLockedByUser || pendingCategoryCorrectionFrom != nil else { return }
        categoryLockedByUser = false
        pendingCategoryCorrectionFrom = nil
    }

    func applyScenePackDraft(title: String, category: HomeItem.Category) {
        rememberCategoryCorrectionIfNeeded(to: category)
        inputTitle = title
        selectedCategory = category
        categoryLockedByUser = true
        invalidateRecordPrefillSnapshot()
        recordInputMessage = nil
    }

    func applyScenePackCategory(_ category: HomeItem.Category) {
        rememberCategoryCorrectionIfNeeded(to: category)
        selectedCategory = category
        categoryLockedByUser = true
        invalidateRecordPrefillSnapshot()
        recordInputMessage = nil
    }

    func applyRecommendedCategory(_ category: HomeItem.Category) {
        guard !categoryLockedByUser else { return }
        selectedCategory = category
        lastAutoRecommendedCategory = category
    }

    private func rememberCategoryCorrectionIfNeeded(to category: HomeItem.Category) {
        guard !categoryLockedByUser else { return }
        let previous = lastAutoRecommendedCategory ?? selectedCategory
        guard previous != .other, previous != category else { return }
        pendingCategoryCorrectionFrom = previous
    }

    func updateSelectedDate(_ date: Date, userInitiated: Bool) {
        selectedDate = date
        if userInitiated {
            selectedDateEditedByUser = true
        }
    }

    func refreshDraftSelectedDate(now: Date = .now, force: Bool = false) {
        guard !selectedDateEditedByUser else { return }
        guard force || abs(now.timeIntervalSince(selectedDate)) >= 30 else { return }
        selectedDate = now
    }

    func noteSuggestions(for category: HomeItem.Category, at date: Date = .now) -> [String] {
        let defaults: [String]
        let isWorkday = RecordCalendarContext.isWorkday(date)
        let nonWorkdayPrefix = RecordCalendarContext.dayKind(for: date) == .holiday ? "假期" : "休息日"
        switch category {
        case .dining:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<10:
                defaults = isWorkday
                    ? ["早餐路上买点吃的", "早班前续一杯咖啡", "出门前吃一口热的"]
                    : ["早上买点吃的", "\(nonWorkdayPrefix)早餐先记下", "出门前吃一口热的"]
            case 10..<14:
                defaults = isWorkday
                    ? ["午间简单吃一顿", "食堂一份热饭", "饭点买杯喝的"]
                    : ["午间简单吃一顿", "\(nonWorkdayPrefix)午饭记一笔", "饭点买杯喝的"]
            case 14..<17:
                defaults = isWorkday
                    ? ["下午续一杯咖啡", "便利店买点轻食", "忙到一半补一口"]
                    : ["下午续一杯咖啡", "便利店买点轻食", "\(nonWorkdayPrefix)下午垫一口"]
            case 17..<21:
                defaults = isWorkday
                    ? ["晚餐吃一顿热饭", "下班后吃点热乎的", "和人一起吃晚饭"]
                    : ["晚餐吃一顿热饭", "\(nonWorkdayPrefix)晚饭记一下", "和人一起吃晚饭"]
            default:
                defaults = isWorkday
                    ? ["加班后吃点热乎的", "晚归路上的一口热食", "深夜买点小食"]
                    : ["夜里吃点热乎的", "晚归路上的一口热食", "深夜买点小食"]
            }
        case .transport:
            defaults = ["地铁到站，路上这一段", "打车走完这一程", "停车和油费记一笔"]
        case .shopping:
            defaults = ["下单一个需要的", "买到常用的小东西", "快递路上记一笔"]
        case .daily:
            defaults = ["便利店补一袋日常", "超市买点家里要用的", "日用品刚好补上"]
        case .entertainment:
            defaults = RecordCalendarContext.isNonWorkday(date)
                ? ["买了这场电影票", "游戏里充了一笔", "\(nonWorkdayPrefix)出去坐一会儿"]
                : ["买了这场电影票", "游戏里充了一笔", "下班后放松一下"]
        case .lodging:
            defaults = isWorkday
                ? ["今晚住在这里", "出差住宿记一笔", "短住一晚记下"]
                : ["今晚住在这里", "短住一晚记下", "这晚住宿记下来"]
        case .health:
            defaults = healthNoteSuggestions()
        case .home:
            defaults = ["水电燃气交上了", "家里添个要用的", "修修补补记一笔"]
        case .social:
            defaults = ["见面带点东西", "和朋友吃了一顿", "探望时买点东西"]
        case .other:
            defaults = ["临时花了一笔", "还没想好归哪类", "先把这笔记下"]
        }
        guard let prefill = compatiblePrefillTitleForSave(category: category) else {
            return defaults
        }
        return uniqueNoteSuggestions([prefill] + defaults)
    }

    private func healthNoteSuggestions() -> [String] {
        let title = inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if containsFitnessCue(title) {
            return ["运动前小准备", "运动后补给一下", "一场运动记下来"]
        }
        return ["药店补点常备药", "问诊挂号记一笔", "体检项目记下来"]
    }

    private func containsFitnessCue(_ text: String) -> Bool {
        let cues = ["运动", "健身", "锻炼", "训练", "跑步", "瑜伽", "游泳", "球场", "课程", "护具", "运动鞋", "运动服", "补给", "恢复", "能量", "月卡", "年卡"]
        return cues.contains { text.contains($0) }
    }

    private func uniqueNoteSuggestions(_ suggestions: [String]) -> [String] {
        var seen = Set<String>()
        return suggestions.filter { suggestion in
            let trimmed = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { return false }
            seen.insert(trimmed)
            return true
        }
    }

    func frequentRecordAmounts(at date: Date = .now) -> [Double] {
        frequentRecordAmountSuggestions(at: date).map(\.amount)
    }

    func frequentRecordAmountSuggestions(at date: Date = .now) -> [FrequentRecordAmountSuggestion] {
        let key = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: recordInputAssistanceRevision,
            referenceDate: date,
            referenceDateEditedByUser: selectedDateEditedByUser
        )
        guard let snapshot = recordInputHistorySnapshot,
              snapshot.key == key else {
            return []
        }
        return snapshot.frequentSuggestions
    }

    private func frequentRecordAmountSuggestion(for amount: Double, at date: Date) -> FrequentRecordAmountSuggestion? {
        frequentRecordAmountSuggestions(at: date).first { suggestion in
            abs(suggestion.amount - amount) < 0.005
        }
    }

    var todayItems: [HomeItem] {
        itemDerivedCacheForRead().todayPositiveItems
    }

    var homeJourneyLedgerFacts: HomeJourneyLedgerFacts {
        itemDerivedCacheForRead().homeJourneyLedgerFacts
    }

    var recentThreeItems: [HomeItem] {
        itemDerivedCacheForRead().recentThreeTodayItems
    }

    var currentYearItems: [HomeItem] {
        itemDerivedCacheForRead().currentYearItems
    }

    var periodItems: [HomeItem] {
        filteredItems(in: selectedPeriod)
    }

    var categorySummary: [(category: HomeItem.Category, amount: Double, ratio: Double)] {
        let targetItems = periodItems
        let total = targetItems.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }

        let grouped = Dictionary(grouping: targetItems, by: \.category)
            .map { key, value in
                let amount = value.reduce(0) { $0 + $1.amount }
                return (category: key, amount: amount, ratio: amount / total)
            }
            .sorted { $0.amount > $1.amount }
        return grouped
    }

    var todayInsight: DailyInsight? {
        let key = Self.dayKey(for: .now)
        return insights.first(where: { $0.dayKey == key })
    }

    func generateDailyInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) }
        let snapshotSignature = dailyInsightSnapshotSignature(for: todayItems, dayKey: key)
        if let existing = insights.first(where: { $0.dayKey == key }),
           existing.snapshotSignature == snapshotSignature {
            return
        }
        guard !isGeneratingInsight else { return }
        insights.removeAll { $0.dayKey == key }
        persistInsights()

        isGeneratingInsight = true
        insightErrorMessage = nil

        let todayTotal = todayItems.reduce(0) { $0 + $1.amount }
        let weeklyAverage = weeklyAverageExpense()
        let topCategory = todayItems
            .reduce(into: [HomeItem.Category: Double]()) { partialResult, item in
                partialResult[item.category, default: 0] += item.amount
            }
            .max(by: { $0.value < $1.value })?.key.rawValue ?? "无"

        if settings.useRemoteAI {
            let apiKey = KeychainService.loadAIAPIKey()
            let isDirectModelEndpoint = settings.aiEndpoint.isEmpty || settings.aiEndpoint.contains("open.bigmodel.cn")
            if !AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit) {
                insightErrorMessage = "本月远程模型调用额度已达上限，已使用本地规则。"
            } else if isDirectModelEndpoint && apiKey.isEmpty {
                insightErrorMessage = "直连模型需要 API Key，已使用本地规则。"
            } else {
            let snapshot = AISnapshot(
                date: key,
                todayTotal: todayTotal,
                weekAverage: weeklyAverage,
                monthTotal: monthExpenseTotal,
                topCategories: categorySummary.prefix(3).map(\.category.rawValue)
            )
            do {
                let payload = try await aiReportService.generateInsight(
                    snapshot: snapshot,
                    endpoint: settings.aiEndpoint,
                    apiKey: apiKey,
                    tone: settings.aiTone,
                    model: settings.aiModel,
                    feature: "daily"
                )
                let remoteInsight = DailyInsight(
                    dayKey: key,
                    summary: payload.summary,
                    action: payload.action,
                    encourage: payload.encourage,
                    snapshotSignature: snapshotSignature
                )
                insights.insert(remoteInsight, at: 0)
                persistInsights()
                _ = AIUsageLimiter.consumeOnce(limitPerMonth: settings.remoteAIMonthlyLimit)
                analyticsService.track(
                    .aiDailyGenerated,
                    props: [
                        .mode: "live",
                        .ledgerSizeBucket: AnalyticsService.countBucket(for: todayItems.count),
                        .outcome: AnalyticsOutcome.success.rawValue,
                    ]
                )
                isGeneratingInsight = false
                return
            } catch {
                insightErrorMessage = remoteAIInsightFallbackMessage(for: error)
            }
            }
        }

        let displayName = dailyInsightDisplayName(from: userName)
        let summary = settings.aiTone == .gentle
            ? "\(displayName.map { "\($0)，" } ?? "")今天的记录里「\(topCategory)」最常出现。"
            : "今天更常记录到「\(topCategory)」。"

        let action: String
        if todayTotal > weeklyAverage && weeklyAverage > 0 {
            action = "今天的记录比平时多一点，先把明细留清楚。"
        } else {
            action = "今天这几笔已经留在账本里，明天有新花费再继续记。"
        }

        let encourage = settings.aiTone == .gentle
            ? "先按今天这些记录看，日常会更清楚。"
            : "继续记录，会更容易看清自己的日常。"

        let insight = DailyInsight(
            dayKey: key,
            summary: summary,
            action: action,
            encourage: encourage,
            snapshotSignature: snapshotSignature
        )
        insights.insert(insight, at: 0)
        persistInsights()
        analyticsService.track(
            .aiDailyGenerated,
            props: [
                .mode: "local_fallback",
                .ledgerSizeBucket: AnalyticsService.countBucket(for: todayItems.count),
                .outcome: AnalyticsOutcome.success.rawValue,
            ]
        )
        isGeneratingInsight = false
    }

    private func dailyInsightDisplayName(from userName: String) -> String? {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "叙账用户" else { return nil }
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        if compact.hasPrefix("用户") {
            let suffix = compact.dropFirst(2)
            if !suffix.isEmpty, suffix.allSatisfy(\.isNumber) {
                return nil
            }
        }
        return trimmed
    }

    private func remoteAIInsightFallbackMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("内容保护") || message.contains("隐私") || message.contains("链接") {
            return "远程模型已跳过，已使用本地规则。"
        }
        return "远程模型暂时不可用，已使用本地规则。"
    }

    func markWeeklyShareGenerated() {
        analyticsService.track(.weeklyShareCardGenerated)
    }

    func markWeeklyRhythmReviewed() {
        analyticsService.track(.weeklyRhythmReviewed)
    }

    func markPlaybackCompleted() {
        analyticsService.track(.todayPlaybackCompleted, props: [.progressBucket: "80_plus"])
    }

    func markTodayPlaybackPromptShown(_ prompt: String) {
        analyticsService.track(.todayPlaybackPromptShown, props: [.prompt: prompt])
    }

    func markTodayPlaybackStarted() {
        let isFirst = !analyticsService.loadEvents().contains { $0.name == .todayPlaybackStarted }
        analyticsService.track(.todayPlaybackStarted, props: [.isFirst: isFirst ? "true" : "false"])
    }

    func markTodayPlaybackEnded(progress: Double) {
        analyticsService.track(
            .todayPlaybackCompleted,
            props: [.progressBucket: progress >= 0.8 ? "80_plus" : "under_80"]
        )
    }

    func markSummaryPlaybackStarted(_ range: SummaryPlaybackRange) {
        analyticsService.track(.summaryPlaybackStarted, props: [.range: range.rawValue])
    }

    func markAICommandRun(
        resultKind: String,
        outcome: AnalyticsOutcome,
        startedAtUptime: TimeInterval,
        itemCount: Int
    ) {
        analyticsService.track(
            .aiCommandRunCompleted,
            props: [
                .resultKind: resultKind,
                .outcome: outcome.rawValue,
                .ledgerSizeBucket: AnalyticsService.countBucket(for: itemCount),
            ]
        )
        analyticsService.trackPerformance(
            operation: .aiCommand,
            startedAtUptime: startedAtUptime,
            itemCount: itemCount,
            outcome: outcome
        )
    }

    func markMemberEntryOpened(scene: String) {
        analyticsService.track(.memberEntryOpened, props: [.scene: scene])
    }

    func markMemberPurchaseCompleted(plan: String, outcome: AnalyticsOutcome) {
        analyticsService.track(
            .memberPurchaseCompleted,
            props: [.plan: plan, .outcome: outcome.rawValue]
        )
    }

    func markMemberRestoreCompleted(outcome: AnalyticsOutcome) {
        analyticsService.track(
            .memberRestoreCompleted,
            props: [.plan: "unknown", .outcome: outcome.rawValue]
        )
    }

    func markPerformance(
        operation: AnalyticsOperation,
        startedAtUptime: TimeInterval,
        itemCount: Int,
        outcome: AnalyticsOutcome = .success
    ) {
        analyticsService.trackPerformance(
            operation: operation,
            startedAtUptime: startedAtUptime,
            itemCount: itemCount,
            outcome: outcome
        )
    }

    func consumeRouteGuidance(_ guidance: PlaybackRouteGuidance? = nil) {
        guard let activeRouteGuidance else {
            if let guidance {
                persistRouteGuidanceHandled(guidance)
            }
            return
        }
        if let guidance, guidance != activeRouteGuidance { return }
        persistRouteGuidanceHandled(activeRouteGuidance)
        self.activeRouteGuidance = nil
    }

    func shouldShowCurrentWeekTraceBadge(
        isMember: Bool,
        now: Date = Date()
    ) -> Bool {
        let facts = homeJourneyLedgerFacts
        let currentWeekKey = routeQuotaStore.currentWeekKey(now: now)
        return WeekTraceDiscoveryPolicy.shouldShowBadge(
            for: WeekTraceDiscoverySnapshot(
                recordCount: facts.currentWeekCommittedRecordCount,
                activeDayCount: facts.currentWeekActiveDayCount,
                canPlay: routeQuotaStore.canPlay(.week, isMember: isMember, now: now),
                hasCompletedPlayback: routeQuotaStore.hasCompletedCurrentWeekPlayback(now: now),
                hasSeenTrace: currentWeekTraceSeenKey == currentWeekKey
            )
        )
    }

    func markCurrentWeekTraceSeenIfEligible(
        recordCount: Int,
        activeDayCount: Int,
        hasVisibleCurrentWeekSnapshot: Bool,
        now: Date = Date()
    ) {
        let currentWeekKey = routeQuotaStore.currentWeekKey(now: now)
        guard WeekTraceDiscoveryPolicy.shouldMarkSeen(
            recordCount: recordCount,
            activeDayCount: activeDayCount,
            hasVisibleCurrentWeekSnapshot: hasVisibleCurrentWeekSnapshot,
            hasSeenTrace: currentWeekTraceSeenKey == currentWeekKey
        ) else { return }
        markCurrentWeekTraceSeen(now: now)
    }

    private func markCurrentWeekTraceSeen(now: Date) {
        let key = routeQuotaStore.currentWeekKey(now: now)
        guard currentWeekTraceSeenKey != key else { return }
        currentWeekTraceSeenKey = key
        UserDefaults.standard.set(key, forKey: Self.currentWeekTraceSeenDefaultsKey)
    }

    func markSummaryPlaybackCompleted(_ range: SummaryPlaybackRange, progress: Double) {
        analyticsService.track(
            .summaryPlaybackCompleted,
            props: [
                .range: range.rawValue,
                .progressBucket: progress >= 0.8 ? "80_plus" : "under_80",
            ]
        )
        if range == .week, progress >= 0.8 {
            markCurrentWeekTraceSeen(now: Date())
        }
    }

    private func refreshTodayPlayback() {
        prepareItemDerivedCacheIfNeeded(now: Date())
    }

    private func emitRouteGuidance(_ guidance: PlaybackRouteGuidance) {
        let key = routeGuidanceHandledKey(for: guidance)
        guard !emittedRouteGuidanceKeys.contains(key) else { return }
        guard !hasHandledRouteGuidance(guidance) else { return }
        activeRouteGuidance = guidance
        emittedRouteGuidanceKeys.insert(key)
        persistRouteGuidanceHandled(guidance)
        analyticsService.track(.routeGuidanceShown, props: [.route: guidance.rawValue])
    }

    private func hasHandledRouteGuidance(_ guidance: PlaybackRouteGuidance) -> Bool {
        let key = routeGuidanceHandledKey(for: guidance)
        return Set(UserDefaults.standard.stringArray(forKey: Self.routeGuidanceHandledDefaultsKey) ?? []).contains(key)
    }

    private func persistRouteGuidanceHandled(_ guidance: PlaybackRouteGuidance) {
        let key = routeGuidanceHandledKey(for: guidance)
        var handled = Set(UserDefaults.standard.stringArray(forKey: Self.routeGuidanceHandledDefaultsKey) ?? [])
        guard handled.insert(key).inserted else { return }
        UserDefaults.standard.set(Array(handled), forKey: Self.routeGuidanceHandledDefaultsKey)
    }

    private func routeGuidanceHandledKey(for guidance: PlaybackRouteGuidance) -> String {
        "\(guidance.rawValue):once"
    }

    func regenerateTodayInsight(userName: String, settings: AppSettings) async {
        let key = Self.dayKey(for: .now)
        insights.removeAll { $0.dayKey == key }
        await generateDailyInsight(userName: userName, settings: settings)
    }

    func refreshTodayInsightIfNeeded(userName: String, settings: AppSettings) async {
        await generateDailyInsight(userName: userName, settings: settings)
    }

    nonisolated static func promptTemplate(todayTotal: Double, weeklyAverage: Double, monthlyTotal: Double, topCategories: String) -> String {
        """
        [System]
        你是“叙账”的生活记录整理助手。请根据账本里的真实记录，输出简短回望和一条自然收束或邀请继续记录/下月再看，不说教、不批判、不提供投资买卖建议。
        「议」只谈已经发生的生活：可复述时间、分类、金额和用户写下的具体细节，不替用户解释情绪。
        可以有一点理解和鼓励，但必须贴着真实记录说；像“这一周已经留下几笔可以回看的记录”，不要写成泛泛安慰、心理分析或夸奖。
        禁止：下月/下周金额目标、预算上限、减少支出比例、达成率、任何管控式省钱建议。
        action 字段应像账本页脚的一句自然收束或轻鼓励，不是理财计划，也不是空泛安慰话术。

        [User]
        日期：\(dayKey(for: .now))
        今日总支出：\(todayTotal) 元
        近7日平均日支出：\(weeklyAverage) 元
        本月累计支出：\(monthlyTotal) 元
        TOP分类：\(topCategories)

        请输出 JSON：
        {"summary":"不超过80字","action":"不超过50字","encourage":"不超过30字"}
        """
    }

    func filteredItems(in period: Period) -> [HomeItem] {
        let cache = itemDerivedCacheForRead()
        switch period {
        case .week:
            return cache.currentWeekItems
        case .month:
            return cache.currentMonthItems
        }
    }

    func items(in dateInterval: DateInterval) -> [HomeItem] {
        items
            .filter { $0.createdAt >= dateInterval.start && $0.createdAt < dateInterval.end }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func isItemDerivedCacheCurrent(now: Date) -> Bool {
        itemDerivedCache.key == itemDerivedCacheKey(now: now)
    }

    func prepareItemDerivedCacheIfNeeded(now: Date) {
        let key = itemDerivedCacheKey(now: now)
        guard itemDerivedCache.key != key else { return }
        guard itemDerivedCachePreparationKey != key else { return }

        itemDerivedCachePreparationTask?.cancel()
        itemDerivedCacheRequestID = UUID()
        let requestID = itemDerivedCacheRequestID
        itemDerivedCachePreparationKey = key
        let input = ItemDerivedCachePreparationInput(
            key: key,
            items: items,
            now: now,
            itemsAreSortedDescending: false
        )
        itemDerivedCachePreparationTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: ItemDerivedCachePublicationPolicy.coalescingDelayNanoseconds
            )
            guard !Task.isCancelled, itemDerivedCacheRequestID == requestID else { return }
            let snapshot = await withTaskGroup(
                of: ItemDerivedCacheSnapshot?.self,
                returning: ItemDerivedCacheSnapshot?.self
            ) { group in
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else { return nil }
                    return ItemDerivedCacheComputation.build(input)
                }
                return await group.next() ?? nil
            }
            guard let snapshot,
                  !Task.isCancelled,
                  ItemDerivedCachePublicationPolicy.accepts(
                    snapshotKey: snapshot.key,
                    pendingKey: itemDerivedCachePreparationKey,
                    currentKey: itemDerivedCacheKey(now: now),
                    requestMatches: itemDerivedCacheRequestID == requestID
                  ) else {
                return
            }
            objectWillChange.send()
            itemDerivedCache = snapshot
            latestPlayback = snapshot.todayPlayback
            itemDerivedCacheRevision = key.ledgerRevision
            itemDerivedCachePreparationKey = nil
            itemDerivedCachePreparationTask = nil
            resumePendingHomeDashboardPreparationIfNeeded()
        }
    }

    private func itemDerivedCacheForRead(now: Date = Date()) -> ItemDerivedCacheSnapshot {
        let key = itemDerivedCacheKey(now: now)
        guard itemDerivedCache.key != key else { return itemDerivedCache }
        prepareItemDerivedCacheIfNeeded(now: now)
        guard itemDerivedCache.key.dayKey == key.dayKey else {
            return .empty(for: key)
        }
        return itemDerivedCache
    }

    private func itemDerivedCacheKey(now: Date) -> ItemDerivedCachePreparationKey {
        ItemDerivedCachePreparationKey(
            ledgerRevision: homeDashboardRevision,
            dayKey: Self.dayKey(for: now)
        )
    }

    private func weeklyAverageExpense() -> Double {
        let weeklyItems = filteredItems(in: .week)
        guard !weeklyItems.isEmpty else { return 0 }
        let total = weeklyItems.reduce(0) { $0 + $1.amount }
        return total / 7
    }

    private func resetInput() {
        inputTitle = ""
        inputAmount = ""
        selectedDate = .now
        selectedDateEditedByUser = false
        selectedCategory = .other
        categoryLockedByUser = false
        invalidateRecordPrefillSnapshot()
        lastAutoRecommendedCategory = nil
        pendingCategoryCorrectionFrom = nil
    }

    private func ensureLedgerWritesAllowed() -> Bool {
        guard !isRestoringLocalBackup else {
            let message = "正在安全合并本地备份，请稍候。"
            recordInputMessage = message
            syncStatusMessage = message
            return false
        }
        guard !localLedgerWritesBlocked else {
            let message = "本机账本暂时无法读取，原文件已保留。请重启后再试，暂时不要新增或修改记录。"
            recordInputMessage = message
            syncStatusMessage = message
            return false
        }
        return true
    }

    @discardableResult
    private func persistItems(
        upserting: [HomeItem] = [],
        deleting: Set<UUID> = []
    ) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        let changes = LedgerHomeItemsChangeSet(upserts: upserting, deletedIDs: deleting)
        guard LocalStore.saveHomeItemChanges(changes, currentItemsForFallback: items) else {
            let reloadResult = LocalStore.loadHomeItemsResult()
            items = reloadResult.items.sorted { $0.createdAt > $1.createdAt }
            localLedgerWritesBlocked = reloadResult.writesBlocked
            let message = reloadResult.issueMessage
                ?? "这次修改没有写入本机，原账本仍保留。请重启后再试。"
            recordInputMessage = message
            syncStatusMessage = message
            return false
        }
        return true
    }

    private func ledgerChanges(from oldItems: [HomeItem], to newItems: [HomeItem]) -> LedgerHomeItemsChangeSet {
        let oldByID = Dictionary(uniqueKeysWithValues: oldItems.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: newItems.map { ($0.id, $0) })
        let upserts = newItems.filter { item in
            guard let oldItem = oldByID[item.id] else { return true }
            return oldItem != item
        }
        let deletedIDs = Set(oldByID.keys).subtracting(newByID.keys)
        return LedgerHomeItemsChangeSet(upserts: upserts, deletedIDs: deletedIDs)
    }

    private func persistInsights() {
        LocalStore.saveDailyInsights(insights)
    }

    private func cloudContext() -> (baseURL: String, accessToken: String)? {
        let settings = LocalStore.loadSettings()
        let baseURL = settings.backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = KeychainService.loadAccessToken()
        guard settings.syncEnabled, !baseURL.isEmpty, !token.isEmpty else { return nil }
        return (baseURL, token)
    }

    private func syncUpsertToCloud(_ item: HomeItem) async {
        guard !LocalStore.isReleaseFixtureMode else { return }
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.upload(item)
            syncStatusMessage = "账单字段已同步；照片仍只在本机。"
        } catch {
            if CloudSessionFailurePolicy.shouldInvalidateSession(for: error) {
                CloudSessionInvalidationService.invalidate()
                syncStatusMessage = CloudSessionInvalidationService.userMessage
            } else {
                syncStatusMessage = "这笔记录已保存在本机，云端暂时没同步成功。"
            }
        }
    }

    private func syncDeleteFromCloud(id: UUID) async {
        guard !LocalStore.isReleaseFixtureMode else { return }
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.delete(id: id)
            syncStatusMessage = "云端账单字段已删除；本机照片不受影响。"
        } catch {
            if CloudSessionFailurePolicy.shouldInvalidateSession(for: error) {
                CloudSessionInvalidationService.invalidate()
                syncStatusMessage = CloudSessionInvalidationService.userMessage
            } else {
                syncStatusMessage = "本机已更新，云端暂时没同步删除。"
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        value.formatted(.cny.precision(.fractionLength(2)))
    }

    func shortAmountText(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.005 {
            return value.formatted(.cny.precision(.fractionLength(0)))
        }
        return value.formatted(.cny.precision(.fractionLength(2)))
    }

    private func mergeLedgers(local: [HomeItem], remote: [HomeItem]) -> [HomeItem] {
        var map: [UUID: HomeItem] = [:]
        for item in remote {
            map[item.id] = item
        }
        for item in local {
            if let existing = map[item.id] {
                map[item.id] = item.updatedAt >= existing.updatedAt ? item : existing
            } else {
                map[item.id] = item
            }
        }
        return Array(map.values)
    }

    private nonisolated static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dailyInsightSnapshotSignature(for todayItems: [HomeItem], dayKey: String) -> String {
        let rows = todayItems
            .filter { $0.amount > 0 }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { item in
                [
                    item.id.uuidString,
                    String(format: "%.2f", item.amount),
                    item.category.rawValue,
                    item.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    String(Int(item.updatedAt.timeIntervalSince1970))
                ].joined(separator: "#")
            }
        return ([dayKey, "\(rows.count)"] + rows).joined(separator: "|")
    }

    private nonisolated static func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    // MARK: - Insight Actions (matching web insight buttons)

    func setLatestActionCard(_ text: String, scope: String = "none") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !Self.isLowValueActionCardText(trimmed) else { return }
        latestActionCard = ActionCardData(text: trimmed, updatedAt: Date(), scope: scope)
        persistActionCard()
    }

    func buildWeeklyRhythmText() -> String {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else {
            return "这周的记录还不够完整，先继续记几笔。"
        }
        let weekItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return "这周还没有足够账单，先不用急着复盘。多记几笔后，节奏会更清楚。"
        }
        let top = weekTopCategoryText
        let activeDays = Set(weekItems.map { cal.startOfDay(for: $0.createdAt) }).count
        let rhythm = activeDays >= 5 ? "这周几乎每天都有记录" : "这周的记录主要落在 \(activeDays) 天里"
        if let sceneLine = lifeSceneMemoryLine(from: weekItems, minimumCount: 2) {
            return "\(rhythm)，\(sceneLine)。"
        }
        if top == "暂无" {
            return "\(rhythm)，先把这一周放在这里。"
        }
        return "\(rhythm)，「\(top)」记得更多一点。先把这一周放在这里。"
    }

    func markWeeklyTag() {
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        let top = weekTopCategoryText
        let result: String
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            let theme = LifeSceneSemanticService.displayTheme(for: scene.signal)
            result = "\(LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count))，先把「\(theme)」这条生活线留下。"
        } else {
            result = "这周更常记录到「\(top)」，先把这个生活主题留下。"
        }
        setLatestActionCard(result, scope: "weekly")
        analyticsService.track(.weeklyTagMarked)
    }

    func buildMonthlyClosingText() -> String {
        let total = monthExpenseTotal
        let top = monthTopCategoryText
        guard total > 0 else {
            return "这个月还没有足够账单，先继续记几笔，月章会更像你的日子。"
        }
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        if let scene = LifeSceneSemanticService.dominantScene(in: monthItems),
           scene.count >= 2 {
            return "\(LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count))。月末再回看会更完整。"
        }
        return "这个月「\(top)」出现得比较多，先把这条线索留在这里。月末再回看会更完整。"
    }

    func markMonthlyClosing() {
        let result = buildMonthlyClosingText()
        setLatestActionCard(result, scope: "monthly")
        analyticsService.track(.monthlyClosingSaved)
    }

    func markMonthlySaveSummary() {
        let blocks = localMonthlyInsightBlocks()
        let result = "月度小结：\(blocks.summary)"
        setLatestActionCard(result, scope: "monthly")
        analyticsService.track(.monthlySummarySaved)
    }

    func markPlaybackMemoryLine(_ line: String, range: SummaryPlaybackRange) {
        let scope = range == .week ? "weekly" : "monthly"
        setLatestActionCard(line, scope: scope)
        analyticsService.track(.playbackMemoryLineSaved, props: [.range: range.rawValue])
    }

    func regenerateMonthlyInsight() {
        monthlyInsightGenerationCount += 1
    }

    private(set) var monthlyInsightGenerationCount: Int = 0

    private func persistActionCard() {
        guard let card = latestActionCard, let data = try? JSONEncoder().encode(card) else { return }
        UserDefaults.standard.set(data, forKey: "latest_action_card_v1")
    }

    private static func isLowValueActionCardText(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoted = trimmed
            .replacingOccurrences(of: "这周留下：", with: "")
            .replacingOccurrences(of: "这个月留下：", with: "")
            .replacingOccurrences(of: "这周留下了一笔", with: "")
            .replacingOccurrences(of: "这个月留下了一笔", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "「」『』“”\"' 。."))
        let separators = CharacterSet(charactersIn: "/／、· ")
        let parts = quoted
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return false }
        let lowValueWords = Set(["公交", "地铁", "交通", "餐饮", "吃饭", "早餐", "购物", "日用", "居家", "健康", "放松", "住宿", "出行"])
        return parts.allSatisfy { word in
            lowValueWords.contains(word)
                || HomeItem.Category.allCases.contains(where: { category in
                    category.rawValue == word || category.label == word
                })
        }
    }
}
