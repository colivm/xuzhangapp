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

enum OCRCommuteScenePolicy {
    static func inferredScenePackID(
        title: String,
        rawText: String,
        merchantBrandID: String?,
        category: HomeItem.Category,
        date: Date,
        historyItems: [HomeItem],
        calendar: Calendar = .current
    ) -> String? {
        guard category == .transport else { return nil }

        let explicitText = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if containsAny(explicitText, strongCommuteCues) {
            return "commute"
        }

        let sourceText = "\(title) \(rawText) \(merchantBrandID ?? "")".lowercased()
        guard merchantBrandID == "metro_transit"
                || containsAny(sourceText, publicTransitCues),
              RecordCalendarContext.isWorkday(date, calendar: calendar),
              let direction = commuteDirection(for: date, calendar: calendar),
              let route = routeEndpoints(from: title) else {
            return nil
        }

        let oldestAcceptedDate = calendar.date(byAdding: .day, value: -120, to: date) ?? .distantPast
        var matchingDays = Set<Date>()
        for item in historyItems where item.amount > 0 && item.category == .transport {
            guard item.createdAt < date,
                  item.createdAt >= oldestAcceptedDate,
                  RecordCalendarContext.isWorkday(item.createdAt, calendar: calendar),
                  commuteDirection(for: item.createdAt, calendar: calendar) == direction,
                  isPublicTransit(item),
                  let historicalRoute = routeEndpoints(from: item.title),
                  routesShareCommuteDestination(route, historicalRoute) else {
                continue
            }
            matchingDays.insert(calendar.startOfDay(for: item.createdAt))
        }
        return matchingDays.count >= 2 ? "commute" : nil
    }

    private enum Direction: Equatable {
        case morning
        case evening
    }

    private struct RouteEndpoints {
        let origin: String
        let destination: String
    }

    private static func commuteDirection(for date: Date, calendar: Calendar) -> Direction? {
        let hour = calendar.component(.hour, from: date)
        if (5..<12).contains(hour) { return .morning }
        if (16..<24).contains(hour) { return .evening }
        return nil
    }

    private static func isPublicTransit(_ item: HomeItem) -> Bool {
        if item.merchantBrandId == "metro_transit" { return true }
        let text = "\(item.title) \(item.scenePackId ?? "")".lowercased()
        return containsAny(text, publicTransitCues)
    }

    private static func routesShareCommuteDestination(
        _ lhs: RouteEndpoints,
        _ rhs: RouteEndpoints
    ) -> Bool {
        (lhs.origin == rhs.origin && lhs.destination == rhs.destination)
            || lhs.destination == rhs.destination
    }

    private static func routeEndpoints(from title: String) -> RouteEndpoints? {
        let normalized = title
            .replacingOccurrences(of: "→", with: ">")
            .replacingOccurrences(of: "->", with: ">")
            .replacingOccurrences(of: "—", with: ">")
            .replacingOccurrences(of: "–", with: ">")
        let components = normalized
            .split(separator: ">", omittingEmptySubsequences: true)
            .map { normalizeStation(String($0)) }
            .filter { !$0.isEmpty }
        guard components.count >= 2 else { return nil }
        return RouteEndpoints(origin: components[0], destination: components[1])
    }

    private static func normalizeStation(_ raw: String) -> String {
        var value = raw
            .folding(options: [.widthInsensitive, .caseInsensitive], locale: Locale(identifier: "zh_CN"))
            .lowercased()
            .replacingOccurrences(of: "地铁站", with: "")
            .replacingOccurrences(of: "轨道交通站", with: "")
            .replacingOccurrences(of: "进站口", with: "")
            .replacingOccurrences(of: "出站口", with: "")
            .replacingOccurrences(of: " ", with: "")
        if let regex = try? NSRegularExpression(pattern: #"\d+\s*号?\s*[进出]?口"#) {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = regex.stringByReplacingMatches(in: value, range: range, withTemplate: "")
        }
        if value.hasSuffix("站") {
            value.removeLast()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static let strongCommuteCues = [
        "通勤", "上班", "下班", "上下班", "到岗", "早高峰", "晚高峰", "公司", "单位", "工位"
    ]

    private static let publicTransitCues = [
        "metro_transit", "地铁", "公交", "轨道交通", "交通卡", "市民卡", "刷卡进站"
    ]
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
    let quickNoteTitlesByContext: [String: [String]]
}

/// Only the optional quick-note chips use this pool. Amount/prefill learning is unchanged.
enum RecordQuickNotePolicy {
    static let historyLimit = 6
    static let displayLimit = 4

    struct PoolKey: Equatable {
        let context: String
        let history: [String]
        let prefill: String?
    }

    struct Evidence {
        let brandID: String?
        let food: DiningCopyEvidencePolicy.SpecificKind?
        let family: SemanticBoundaryGuard.FamilyCareKind?

        init(_ title: String) {
            brandID = MerchantBrandCatalog.matchBrand(in: title)?.id
            food = DiningCopyEvidencePolicy.specificKind(in: title)
            family = SemanticBoundaryGuard.familyCareKind(in: title)
        }

        func accepts(_ candidate: Evidence) -> Bool {
            if let brandID, let other = candidate.brandID, brandID != other { return false }
            if let food, let other = candidate.food, food != other { return false }
            if let family, let other = candidate.family, family != other { return false }
            return true
        }
    }

    struct Pool {
        let personalized: [(title: String, evidence: Evidence)]
        let defaults: [String]
    }

    private struct Support {
        var days: Set<Date> = []
        var latest: Date = .distantPast
        var userEdited = false
    }

    static func contextKey(category: HomeItem.Category, date: Date, calendar: Calendar = .current) -> String {
        let kind = RecordCalendarContext.dayKind(for: date, calendar: calendar)
        let dayKey = kind == .workday ? "workday" : (kind == .holiday ? "holiday" : "weekend")
        return "\(category.rawValue)|\(timeBand(date, calendar: calendar))|\(dayKey)"
    }

    private static func timeBand(_ date: Date, calendar: Calendar) -> Int {
        switch calendar.component(.hour, from: date) {
        case 5..<10: return 0
        case 10..<14: return 1
        case 14..<17: return 2
        case 17..<21: return 3
        default: return 4
        }
    }

    /// One background pass per history snapshot, never a per-keystroke ledger scan.
    /// Group first so validation/semantic matching runs once per repeated title.
    static func historicalTitles(
        items: [HomeItem], at date: Date, calendar: Calendar = .current
    ) -> [String: [String]] {
        let start = calendar.date(byAdding: .day, value: -180, to: date) ?? .distantPast
        var groups: [String: [String: Support]] = [:]
        var categories: [String: HomeItem.Category] = [:]
        for item in items {
            if Task.isCancelled { return [:] }
            guard item.amount > 0, item.draftMeta == nil,
                  item.createdAt >= start, item.createdAt <= date else { continue }
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...12).contains(title.count) else { continue }
            let key = contextKey(category: item.category, date: item.createdAt, calendar: calendar)
            var support = groups[key]?[title] ?? Support()
            support.days.insert(calendar.startOfDay(for: item.createdAt))
            support.latest = max(support.latest, item.createdAt)
            support.userEdited = support.userEdited || item.userEditedTitle == true
            groups[key, default: [:]][title] = support
            categories[key] = item.category
        }
        var result: [String: [String]] = [:]
        for (key, titles) in groups {
            if Task.isCancelled { return [:] }
            guard let category = categories[key] else { continue }
            let ranked = titles.filter { $0.value.days.count >= 2 }.sorted { lhs, rhs in
                if lhs.value.days.count != rhs.value.days.count { return lhs.value.days.count > rhs.value.days.count }
                if lhs.value.latest != rhs.value.latest { return lhs.value.latest > rhs.value.latest }
                return lhs.key < rhs.key
            }
            var accepted: [String] = []
            for (title, support) in ranked {
                if Task.isCancelled { return [:] }
                guard RecordPrefillService.isHabitTitle(title, category: category),
                      RecordSemanticLexicon.canReuseHabitTitle(title, category: category, userEditedTitle: support.userEdited),
                      isCompatible(title, category: category),
                      UserContentRiskService.shared.validateManualNote(title, allowEmpty: false).isAllowed else { continue }
                accepted.append(title)
                if accepted.count == historyLimit { break }
            }
            if !accepted.isEmpty { result[key] = accepted }
        }
        return result
    }

    static func templates(for category: HomeItem.Category, at date: Date, calendar: Calendar = .current) -> [String] {
        switch category {
        case .dining:
            switch timeBand(date, calendar: calendar) {
            case 0: return ["早餐记一笔", "这顿早餐先记下", "早餐花费记下来"]
            case 1: return ["午餐记一笔", "这顿午饭先记下", "午餐花费记下来"]
            case 2: return ["下午餐饮记一笔", "这次餐饮花费", "吃点喝点记下来"]
            case 3: return ["晚餐记一笔", "这顿晚饭先记下", "晚餐花费记下来"]
            default: return ["这顿餐饮记一笔", "吃点东西记下来", "餐饮花费先记下"]
            }
        case .transport: return ["这趟出行记一笔", "路上花费记下来", "出行费用先记下"]
        case .shopping: return ["这次购物记一笔", "购物花费记下来", "添置物品先记下"]
        case .daily: return ["日用品补一笔", "日常用品记下来", "这次日用开销"]
        case .entertainment: return ["休闲娱乐记一笔", "这次娱乐花费", "放松一下的开销"]
        case .lodging: return ["住宿费用记一笔", "这次住宿先记下", "住店花费记下来"]
        case .health: return ["健康开销记一笔", "这次健康花费", "健康事项先记下"]
        case .home: return ["居家开销记一笔", "住处费用记下来", "这次居家花费"]
        case .social: return ["人情往来记一笔", "这份心意先记下", "往来花费记下来"]
        case .other: return ["这笔开销先记下", "零散花费记一笔", "先留一笔记录"]
        }
    }

    static func isCompatible(_ title: String, category: HomeItem.Category) -> Bool {
        guard !title.isEmpty, title.count <= 32,
              RecordSemanticLexicon.isTitle(title, compatibleWith: category) else { return false }
        if let brand = MerchantBrandCatalog.matchBrand(in: title), brand.category != category { return false }
        return true
    }

    /// Keep concrete food/brand/family evidence within the current draft; neutral templates add no new facts.
    static func respectsAnchor(_ title: String, anchor: String) -> Bool {
        Evidence(anchor).accepts(Evidence(title))
    }

    /// Additional filtering only after real handwriting. Defaults based on the
    /// clock/history cannot add a different meal, merchant, food or circumstance.
    static func respectsHandwrittenAnchor(_ title: String, anchor: String) -> Bool {
        let original = Evidence(anchor)
        let candidate = Evidence(title)
        guard candidate.brandID == nil || candidate.brandID == original.brandID,
              candidate.food == nil || candidate.food == original.food,
              candidate.family == nil || candidate.family == original.family,
              RecordSemanticLexicon.matchingEmotionRuleIDs(in: title).isSubset(
                of: RecordSemanticLexicon.matchingEmotionRuleIDs(in: anchor)
              ) else { return false }
        let facts = [
            ["早餐", "早饭"], ["午餐", "午饭"], ["晚餐", "晚饭"], ["夜宵", "宵夜"],
            ["热乎", "热食", "热饭", "热汤"], ["加班"], ["晚归"], ["出差"],
            ["下雨", "雨天", "雨中"], ["下雪", "雪天", "雪中"], ["冷天", "低温"],
            ["热天", "高温"], ["上班"], ["下班"], ["地铁"], ["公交"], ["打车", "网约车"]
        ]
        return facts.allSatisfy { words in
            !words.contains(where: { title.contains($0) }) || words.contains(where: { anchor.contains($0) })
        }
    }

    static func preparePool(
        category: HomeItem.Category, date: Date, history: [String], prefill: String?,
        calendar: Calendar = .current
    ) -> Pool {
        var seen: Set<String> = []
        let personalized = ([prefill].compactMap { $0 } + Array(history.prefix(historyLimit)))
            .filter { seen.insert($0).inserted }
            .filter { isCompatible($0, category: category) }
            .map { (title: $0, evidence: Evidence($0)) }
        return Pool(
            personalized: personalized,
            defaults: templates(for: category, at: date, calendar: calendar).filter { isCompatible($0, category: category) }
        )
    }

    static func suggestions(pool: Pool, anchor: String) -> [String] {
        guard !pool.personalized.isEmpty else { return Array(pool.defaults.prefix(displayLimit)) }
        let evidence = Evidence(anchor)
        let personalized = pool.personalized.filter { evidence.accepts($0.evidence) }.map { $0.title }
        // At most two learned/prefilled notes, leaving room for neutral category templates.
        var result = Array(personalized.prefix(2))
        var seen = Set(result)
        for title in pool.defaults where seen.insert(title).inserted {
            result.append(title)
        }
        return Array(result.prefix(displayLimit))
    }

    static func suggestions(
        category: HomeItem.Category, date: Date, history: [String], prefill: String?, anchor: String,
        calendar: Calendar = .current
    ) -> [String] {
        suggestions(pool: preparePool(category: category, date: date, history: history, prefill: prefill, calendar: calendar), anchor: anchor)
    }
}

struct RecordPrefillPreparationKey: Equatable {
    let historyKey: RecordInputHistoryKey
    let amount: Double
    let referenceDate: Date
    let noteDraft: String
    let selectedCategory: HomeItem.Category
    let context: RecordContextSignal?
}

// Draft-only provenance: generated copy is not a new handwritten fact or a
// user category correction. Date/history changes must not erase its origin.
struct RecordGeneratedNoteContext: Equatable {
    let title: String
    let category: HomeItem.Category

    func matches(title: String, category: HomeItem.Category) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && trimmed == self.title.trimmingCharacters(in: .whitespacesAndNewlines)
            && category == self.category
    }
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
        _ input: RecordInputHistoryPreparationInput,
        includeQuickNoteHistory: Bool = true
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
            guard !Task.isCancelled else { return }
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
            frequentTitlesBySuggestionID: titles,
            quickNoteTitlesByContext: includeQuickNoteHistory && !Task.isCancelled
                ? RecordQuickNotePolicy.historicalTitles(items: input.items, at: input.referenceDate)
                : [:]
        )
    }

    static func prefillSnapshot(
        _ input: RecordPrefillPreparationInput
    ) -> RecordPrefillSnapshot {
        let brand = MerchantBrandCatalog.matchBrand(in: input.noteDraft)
        let semanticCategory = RecordSemanticLexicon.semanticCategory(of: input.noteDraft)
        let frequentSuggestion = input.history.frequentSuggestions.first { suggestion in
            Int((suggestion.amount * 100).rounded()) == Int((input.amount * 100).rounded())
        }
        let frequentCanOverride = frequentSuggestion.map { suggestion in
            RecordHabitOverridePolicy.allows(
                note: input.noteDraft,
                suggestedCategory: suggestion.category,
                supportingItems: input.history.prefillItems
            ) && suggestion.confidence >= 0.67
        } ?? false
        let shouldUseBrandPrefill = brand.map { brand in
            semanticCategory == nil
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

        let result = adoptedPrefillResult(
            habitResult: habitResult,
            frequentSuggestion: frequentSuggestion,
            frequentCanOverride: frequentCanOverride,
            frequentTitle: frequentSuggestion.flatMap { input.history.frequentTitlesBySuggestionID[$0.id] },
            amount: input.amount,
            referenceDate: input.referenceDate
        )
        return RecordPrefillSnapshot(
            key: input.key,
            amount: input.amount,
            result: result,
            appliedCategory: result?.category,
            categoryGridRecommendation: result?.category
        )
    }

    static func matchesCurrentDraft(
        _ key: RecordPrefillPreparationKey,
        historyKey: RecordInputHistoryKey,
        amount: Double?,
        referenceDate: Date,
        noteDraft: String,
        selectedCategory: HomeItem.Category,
        categoryLockedByUser: Bool,
        generatedNoteContext: RecordGeneratedNoteContext?
    ) -> Bool {
        !categoryLockedByUser
            && generatedNoteContext?.matches(title: noteDraft, category: selectedCategory) != true
            && key.historyKey == historyKey
            && key.amount == amount
            && key.referenceDate == referenceDate
            && key.noteDraft == noteDraft
            && key.selectedCategory == selectedCategory
    }

    static func canDescribeAdoptedRecommendation(
        _ result: RecordPrefillResult,
        selectedCategory: HomeItem.Category
    ) -> Bool {
        result.category == selectedCategory
            && (result.source == "generic" || result.confidence >= 0.55)
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
        guard !Task.isCancelled, recentItems.count >= 6 else { return [] }

        let targetBucket = hourHabitBucket(for: date, calendar: calendar)
        let targetDayKind = RecordCalendarContext.dayKind(for: date)
        let contextItems = recentItems.filter { item in
            !Task.isCancelled
                && hourHabitBucket(for: item.createdAt, calendar: calendar) == targetBucket
                && RecordCalendarContext.dayKind(for: item.createdAt) == targetDayKind
        }
        guard contextItems.count >= 3 else { return [] }

        let grouped = Dictionary(grouping: contextItems) { item in
            Int((item.amount * 100).rounded())
        }
        let candidates: [RecordFrequentAmountSuggestion] = grouped.compactMap { entry in
            guard !Task.isCancelled else { return nil }
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
        let targetBucket = hourHabitBucket(for: date, calendar: calendar)
        let targetDayKind = RecordCalendarContext.dayKind(for: date)
        let supportItems = items.filter { item in
            !Task.isCancelled && item.amount > 0
                && item.createdAt >= start
                && item.createdAt <= date
                && item.category == suggestion.category
                && Int((item.amount * 100).rounded()) == amountCents
                && hourHabitBucket(for: item.createdAt, calendar: calendar) == targetBucket
                && RecordCalendarContext.dayKind(for: item.createdAt) == targetDayKind
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

    static func adoptedPrefillResult(
        habitResult: RecordPrefillResult?,
        frequentSuggestion: RecordFrequentAmountSuggestion?,
        frequentCanOverride: Bool,
        frequentTitle: String?,
        amount: Double,
        referenceDate: Date
    ) -> RecordPrefillResult? {
        // The service resolves brand/explicit semantics/entity history first.
        // Keep that authority, then exact-amount history, then ordinary habits.
        if let habitResult,
           let category = habitResult.category,
           ["brand", "semantic", "entity_history"].contains(habitResult.source) {
            return sanitizedPrefillResult(habitResult, for: category)
        }
        if let frequentSuggestion, frequentCanOverride {
            // Never carry a defeated candidate's title into the winning category.
            let stableTitle = frequentTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let compatibleHabitTitle = habitResult?.category == frequentSuggestion.category
                && habitResult?.source != "generic" ? habitResult?.title : nil
            let title = stableTitle?.isEmpty == false ? stableTitle : compatibleHabitTitle
            let result = RecordPrefillResult(
                category: frequentSuggestion.category,
                title: title,
                emotionTag: habitEmotionTag(
                    title: title,
                    category: frequentSuggestion.category,
                    amount: amount,
                    date: referenceDate
                ),
                confidence: frequentSuggestion.confidence,
                source: "frequent"
            )
            return sanitizedPrefillResult(result, for: frequentSuggestion.category)
        }
        guard let habitResult,
              let category = habitResult.category,
              habitResult.source == "generic" || habitResult.confidence >= 0.55 else {
            return nil
        }
        return sanitizedPrefillResult(habitResult, for: category)
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
        // Merchant compatibility alone is insufficient (e.g. 罗森纸巾):
        // explicit product meaning must not reclassify this title at save time.
        let titleCategory = RecordSemanticLexicon.semanticCategory(of: title)
        guard titleCategory == nil || titleCategory == category,
              RecordSemanticLexicon.canDisplayPrefillTitle(
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
    var key: ItemDerivedCachePreparationKey
    var ledgerDisplayFingerprint = ""
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

    mutating func replaceItems(with replacements: [UUID: HomeItem]) {
        func replace(_ rows: [HomeItem]) -> [HomeItem] {
            rows.map { replacements[$0.id] ?? $0 }
        }
        todayPositiveItems = replace(todayPositiveItems)
        recentThreeTodayItems = replace(recentThreeTodayItems)
        currentWeekItems = replace(currentWeekItems)
        currentMonthItems = replace(currentMonthItems)
        currentYearItems = replace(currentYearItems)
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
            ledgerDisplayFingerprint: LedgerDisplayFingerprintPolicy.make(items: sortedItems),
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

enum ItemDerivedCacheImmediateMutationPolicy {
    static func adding(
        _ added: HomeItem,
        in snapshot: ItemDerivedCacheSnapshot,
        now: Date,
        calendar: Calendar = .current
    ) -> ItemDerivedCacheSnapshot {
        replacing(added, in: snapshot, now: now, calendar: calendar)
    }

    static func removing(
        ids: Set<UUID>,
        from snapshot: ItemDerivedCacheSnapshot
    ) -> ItemDerivedCacheSnapshot {
        guard !ids.isEmpty else { return snapshot }
        var projected = snapshot
        projected.todayPositiveItems.removeAll { ids.contains($0.id) }
        projected.recentThreeTodayItems = Array(projected.todayPositiveItems.prefix(3))
        projected.currentWeekItems.removeAll { ids.contains($0.id) }
        projected.currentMonthItems.removeAll { ids.contains($0.id) }
        projected.currentYearItems.removeAll { ids.contains($0.id) }
        return projected
    }

    static func rekeying(
        _ snapshot: ItemDerivedCacheSnapshot,
        ledgerRevision: Int,
        now: Date
    ) -> ItemDerivedCacheSnapshot {
        var projected = snapshot
        projected.key = ItemDerivedCachePreparationKey(
            ledgerRevision: ledgerRevision,
            dayKey: HomeViewModel.dayKey(for: now)
        )
        return projected
    }

    static func replacing(
        _ updated: HomeItem,
        in snapshot: ItemDerivedCacheSnapshot,
        now: Date,
        calendar: Calendar = .current
    ) -> ItemDerivedCacheSnapshot {
        var projected = snapshot
        let weekInterval = PlaybackService.isoCalendar.dateInterval(
            of: .weekOfYear,
            for: now
        )
        let monthInterval = calendar.dateInterval(of: .month, for: now)

        projected.todayPositiveItems = replacing(
            updated,
            in: snapshot.todayPositiveItems,
            includes: calendar.isDate(updated.createdAt, inSameDayAs: now) && updated.amount > 0
        )
        projected.recentThreeTodayItems = Array(projected.todayPositiveItems.prefix(3))
        projected.currentWeekItems = replacing(
            updated,
            in: snapshot.currentWeekItems,
            includes: weekInterval.map { interval in
                updated.createdAt >= interval.start && updated.createdAt < interval.end
            } ?? false
        )
        projected.currentMonthItems = replacing(
            updated,
            in: snapshot.currentMonthItems,
            includes: monthInterval.map { interval in
                updated.createdAt >= interval.start && updated.createdAt < interval.end
            } ?? false
        )
        projected.currentYearItems = replacing(
            updated,
            in: snapshot.currentYearItems,
            includes: calendar.isDate(updated.createdAt, equalTo: now, toGranularity: .year)
        )
        return projected
    }

    private static func replacing(
        _ updated: HomeItem,
        in rows: [HomeItem],
        includes: Bool
    ) -> [HomeItem] {
        let existingIndex = rows.firstIndex { $0.id == updated.id }
        guard includes else {
            guard let existingIndex else { return rows }
            var result = rows
            result.remove(at: existingIndex)
            return result
        }

        if let existingIndex,
           rows[existingIndex].createdAt == updated.createdAt {
            var result = rows
            result[existingIndex] = updated
            return result
        }

        var result = rows
        if let existingIndex {
            result.remove(at: existingIndex)
        }
        let insertionIndex = result.firstIndex { row in
            if row.createdAt == updated.createdAt {
                return row.id.uuidString > updated.id.uuidString
            }
            return row.createdAt < updated.createdAt
        } ?? result.endIndex
        result.insert(updated, at: insertionIndex)
        return result
    }
}

enum ItemDerivedCachePublicationPolicy {
    static let coalescingDelayNanoseconds: UInt64 = 120_000_000

    static func accepts(
        snapshotKey: ItemDerivedCachePreparationKey,
        pendingKey: ItemDerivedCachePreparationKey?,
        currentKey: ItemDerivedCachePreparationKey,
        requestMatches: Bool
    ) -> Bool {
        requestMatches && snapshotKey == pendingKey && snapshotKey == currentKey
    }
}

enum LedgerRapidInteractionPolicy {
    static let traceCoalescingDelayNanoseconds: UInt64 = 90_000_000
    static let homeSnapshotCoalescingDelayNanoseconds: UInt64 = 80_000_000
}

actor LedgerBackgroundComputationLane {
    static let shared = LedgerBackgroundComputationLane()

    func buildItemDerived(
        _ input: ItemDerivedCachePreparationInput
    ) -> ItemDerivedCacheSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = ItemDerivedCacheComputation.build(input)
        guard !Task.isCancelled else { return nil }
        return value
    }

    func buildHomeLifeMark(
        _ input: HomeLifeMarkPreparationInput
    ) -> HomeLifeMarkSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = HomeDashboardSnapshotComputation.lifeMarkSnapshot(input)
        guard !Task.isCancelled else { return nil }
        return value
    }

    func buildHomeQuickRecord(
        _ input: HomeQuickRecordPreparationInput
    ) -> HomeQuickRecordSnapshot? {
        guard !Task.isCancelled else { return nil }
        let suggestion = HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
            items: input.items,
            at: input.now
        )
        guard !Task.isCancelled else { return nil }
        return HomeQuickRecordSnapshot(key: input.key, suggestion: suggestion)
    }

    func buildTraceChapter(
        _ input: TraceChapterComputationInput
    ) -> TraceChapterSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = TraceSnapshotComputation.buildChapter(input)
        guard !Task.isCancelled else { return nil }
        return value
    }

    func buildProgressiveTraceChapter(
        _ input: TraceChapterProgressiveInput
    ) -> TraceChapterSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = TraceSnapshotComputation.buildProgressiveChapter(input)
        guard !Task.isCancelled else { return nil }
        return value
    }

    func buildTraceClue(
        _ input: TraceClueComputationInput
    ) -> TraceClueSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = TraceSnapshotComputation.buildClueIfCurrent(input)
        guard !Task.isCancelled else { return nil }
        return value
    }

    func buildProgressiveTraceClue(
        _ input: TraceClueProgressiveInput
    ) -> TraceClueSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = TraceSnapshotComputation.buildProgressiveClue(input)
        guard !Task.isCancelled else { return nil }
        return value
    }

    func buildTraceDetailList(
        _ input: TraceDetailListPreparationInput
    ) -> TraceDetailListSnapshot? {
        guard !Task.isCancelled else { return nil }
        let value = TraceDetailListSnapshotComputation.make(input)
        guard !Task.isCancelled else { return nil }
        return value
    }
}

struct HomeJourneyLedgerFacts: Equatable {
    var allRecordDayCount = 0
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
        var allRecordDays = Set<Date>()
        var weekDays = Set<Date>()
        var monthDays = Set<Date>()
        for item in items {
            allRecordDays.insert(calendar.startOfDay(for: item.createdAt))
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
        facts.allRecordDayCount = allRecordDays.count
        facts.currentWeekActiveDayCount = weekDays.count
        facts.currentMonthActiveDayCount = monthDays.count
        return facts
    }
}

enum LedgerCloudUploadCompletionPolicy {
    static func requiresCompensatingDelete(
        uploadedItemID: UUID,
        currentItemIDs: Set<UUID>
    ) -> Bool {
        !currentItemIDs.contains(uploadedItemID)
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

    @Published var inputTitle: String = "" {
        didSet {
            guard inputTitle != oldValue else { return }
            if !isApplyingRecordTitleEvent {
                recordHandwrittenAnchor = nil
                recordNoteIsHandwritten = false
                if recordExplicitIntent.categorySource == .handwritten {
                    recordExplicitIntent = RecordExplicitIntentState(
                        category: selectedCategory, userSelectedCategory: categoryLockedByUser
                    )
                }
            }
            if recordGeneratedNoteContext?.matches(title: inputTitle, category: selectedCategory) != true {
                recordGeneratedNoteContext = nil
            }
            // Do not leave the old request alive during the view's typing debounce.
            invalidateRecordPrefillSnapshot()
        }
    }
    @Published var inputAmount: String = "" {
        didSet {
            guard inputAmount != oldValue else { return }
            invalidateRecordPrefillSnapshot()
            scheduleRecordAmountInput()
        }
    }
    @Published private(set) var isRecordAmountInputPending = false
    private var recordAmountInputGate = RecordAmountInputGate()
    private var recordAmountInputTask: Task<Void, Never>?
    @Published var selectedCategory: HomeItem.Category = .other
    @Published private(set) var recordExplicitIntent = RecordExplicitIntentState(category: .other)
    var categoryLockedByUser: Bool { recordExplicitIntent.categoryWasSelectedByUser }
    @Published private(set) var recordHandwrittenAnchor: String?
    private var recordNoteIsHandwritten = false
    private var isApplyingRecordTitleEvent = false

    var hasExplicitRecordCategoryDecision: Bool { recordExplicitIntent.preventsAutomaticCategoryChanges }
    var hasHandwrittenRecordNote: Bool { recordHandwrittenAnchor?.isEmpty == false }
    var isCurrentRecordNoteHandwritten: Bool { recordNoteIsHandwritten && hasHandwrittenRecordNote }
    var hasCurrentHandwrittenCategoryConflict: Bool {
        recordHandwrittenAnchor.map {
            RecordExplicitIntentPolicy.hasCategoryConflict(note: $0, category: selectedCategory)
        } ?? false
    }
    @Published var selectedDate: Date = .now {
        didSet {
            guard selectedDate != oldValue else { return }
            invalidateRecordPrefillSnapshot()
        }
    }
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
            itemDerivedCacheNeedsFullRefresh = true
            invalidateRecordInputHistorySnapshot()
            invalidateHomeDashboardSnapshots()
            prepareItemDerivedCacheIfNeeded(now: Date())
            scheduleNarrativeAIPrecompute(now: Date())
        }
    }
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var syncNeedsNetworkHelp = false
    @Published private(set) var syncHasPendingFailures = false
    @Published private(set) var isPersistingLedger: Bool = false
    @Published private(set) var isSyncingCloudLedger: Bool = false
    @Published private(set) var isRestoringLocalBackup: Bool = false
    private(set) var latestPlayback: PlaybackSnapshot?
    @Published private(set) var latestActionCard: ActionCardData?
    @Published private(set) var activeRouteGuidance: PlaybackRouteGuidance?
    @Published private(set) var currentWeekTraceSeenKey: String?
    @Published private(set) var recordPrefillResult: RecordPrefillResult?
    @Published private(set) var recordWarmupSuggestions: [FrequentRecordAmountSuggestion] = []
    @Published private(set) var recordQuickNoteTitlesByContext: [String: [String]] = [:]
    @Published private(set) var recordRecommendedCategory: HomeItem.Category?
    private(set) var recordInputAssistanceRevision: Int = 0
    private(set) var homeDashboardRevision: Int = 0
    var homeLifeMarkTextsByItemID: [UUID: String] = [:]
    var homeLifeMarkSemanticSignaturesByItemID: [UUID: HomeLifeMarkSemanticSignature] = [:]
    var homeTodayLifeMarkLine: String?
    var homeWeekLifeThemeText = ""
    var homeQuickRecordNudgeText: String?
    var homeWeekTopCategoryText = "暂无"
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
    private var recordQuickNotePoolCache: (key: RecordQuickNotePolicy.PoolKey, pool: RecordQuickNotePolicy.Pool)?
    private var recordInputHistoryPreparationKey: RecordInputHistoryKey?
    private var recordInputHistoryPreparationTask: Task<Void, Never>?
    private var recordInputHistoryRequestID = UUID()
    private var recordQuickNoteHistoryKey: RecordInputHistoryKey?
    private var recordQuickNoteHistoryInput: RecordInputHistoryPreparationInput?
    private var recordQuickNoteHistoryPreparationKey: RecordInputHistoryKey?
    private var recordQuickNoteHistoryPreparationTask: Task<Void, Never>?
    private var recordQuickNoteHistoryRequestID = UUID()
    private var recordPrefillPreparationKey: RecordPrefillPreparationKey?
    private var recordPrefillPreparationTask: Task<Void, Never>?
    private var recordPrefillRequestID = UUID()
    private var recordGeneratedNoteContext: RecordGeneratedNoteContext?
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
    private var itemDerivedCacheNeedsFullRefresh = false
    private var narrativeAIPreparationTask: Task<Void, Never>?
    private var narrativeAIPreparationRevision = -1
    private var narrativeAIConfigurationCancellable: AnyCancellable?
    private var localLedgerWritesBlocked = false
    private let persistenceWriter = LedgerPersistenceWriter()
    private var persistenceRevision: UInt64 = 0
    private var pendingPersistenceTasks: [UInt64: Task<LedgerPersistenceSaveResult, Never>] = [:]
    private var pendingPersistenceRevisionByID: [UUID: UInt64] = [:]
    /// Latest revision ever submitted for each record. This outlives the
    /// pending map so a late completion from an older write cannot overwrite
    /// a newer write that already finished.
    private var latestPersistenceRevisionByID: [UUID: UInt64] = [:]
    private var completedPersistenceResults: [UInt64: Bool] = [:]
    private var completedPersistenceResultByID: [UUID: Bool] = [:]

    init() {
        currentWeekTraceSeenKey = UserDefaults.standard.string(
            forKey: Self.currentWeekTraceSeenDefaultsKey
        )
        let ledgerLoadStartedAt = ProcessInfo.processInfo.systemUptime
        let ledgerLoadResult = LocalStore.loadHomeItemsResult()
        items = ledgerLoadResult.items.sorted { $0.createdAt > $1.createdAt }
        let recentPhotoItems = Array(items.prefix(24).filter { !$0.memoryImageReferences.isEmpty })
        if !recentPhotoItems.isEmpty {
            Task.detached(priority: .utility) {
                LocalStore.prewarmMemoryImageThumbnails(for: recentPhotoItems)
            }
        }
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
        itemDerivedCacheNeedsFullRefresh = false
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
        narrativeAIConfigurationCancellable = NotificationCenter.default
            .publisher(for: .narrativeAIConfigurationDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshNarrativeAIConfiguration()
                }
            }
        scheduleNarrativeAIPrecompute(now: initialDerivedNow)
    }

    @discardableResult
    func addManualRecord(
        userEditedTitle: Bool = false,
        preserveEmptyTitle: Bool = false,
        categoryLockedForSave: Bool? = nil,
        scenePackId: String? = nil,
        emotionSelection: RecordEmotionSelection? = nil
    ) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else { return false }
        flushPendingRecordAmountInput()
        let wasEmpty = items.isEmpty
        let userEditedTitle = userEditedTitle || isCurrentRecordNoteHandwritten
        let shouldLockCategory = categoryLockedForSave ?? categoryLockedByUser
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        guard noteResult.isAllowed else {
            recordInputMessage = noteResult.message
            return false
        }
        recordInputMessage = nil
        let draft = resolvedManualRecordDraft(
            normalizedTitle: noteResult.value, amount: amount,
            userEditedTitle: userEditedTitle, preserveEmptyTitle: preserveEmptyTitle,
            categoryLockedForSave: shouldLockCategory, scenePackId: scenePackId
        )
        let baseTitle = draft.baseTitle
        let resolution = draft.resolution
        let automaticEmotionTag = hasCurrentHandwrittenCategoryConflict ? "" : memoryEnhancedEmotionTag(
            title: resolution.title,
            category: resolution.category,
            amount: amount,
            date: selectedDate,
            baseEmotionTag: resolution.emotionTag
        )
        let emotionTag = RecordEmotionScenePolicy.validatedTag(
            selection: emotionSelection, resolution: resolution,
            amount: amount, date: selectedDate, scenePackID: scenePackId,
            automaticEmotionTag: automaticEmotionTag
        ) ?? automaticEmotionTag
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
            userEditedTitle: userEditedTitle && !isCurrentRecordNoteGenerated && resolution.title == baseTitle ? true : nil,
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

    /// The emotion chooser must use exactly the same normalization, blank-note,
    /// prefill and explicit-intent rules as manual save, without changing the draft.
    func resolvedManualRecordDraft(
        normalizedTitle: String, amount: Double, userEditedTitle: Bool,
        preserveEmptyTitle: Bool, categoryLockedForSave: Bool, scenePackId: String?
    ) -> (baseTitle: String, resolution: RecordDraftResolution) {
        let titleWasIntentionallyBlank = preserveEmptyTitle && normalizedTitle.isEmpty
        let prefillTitle = compatiblePrefillTitleForSave(category: selectedCategory)
        let baseTitle: String
        if titleWasIntentionallyBlank {
            baseTitle = RecordSemanticLexicon.emptyNoteTitle
        } else if normalizedTitle.isEmpty, let prefillTitle {
            baseTitle = prefillTitle
        } else {
            baseTitle = normalizedTitle.isEmpty ? selectedCategory.defaultRecordTitle : normalizedTitle
        }
        let resolution = RecordDraftResolutionService.resolve(
            RecordDraftResolutionInput(
                rawTitle: baseTitle, fallbackCategory: selectedCategory,
                amount: amount, date: selectedDate,
                merchantBrandId: MerchantBrandCatalog.matchBrand(in: baseTitle)?.id,
                categoryLockedByUser: categoryLockedForSave,
                userEditedTitle: isCurrentRecordNoteHandwritten || userEditedTitle || titleWasIntentionallyBlank,
                source: "manual", scenePackId: scenePackId,
                generatedNoteContext: currentRecordGeneratedNoteContext,
                categoryIsSettled: hasExplicitRecordCategoryDecision,
                preserveConfirmedTitle: hasHandwrittenRecordNote && !normalizedTitle.isEmpty,
                manualNoteAnchor: recordHandwrittenAnchor
            )
        )
        return (baseTitle, resolution)
    }

    func automaticRecordEmotionTag(
        for resolution: RecordDraftResolution, amount: Double, weatherCompanionEnabled: Bool
    ) -> String {
        guard !hasCurrentHandwrittenCategoryConflict else { return "" }
        // The preview already owns the observed settings; do not decode persisted
        // settings on every SwiftUI body evaluation. Save still revalidates them.
        return RecordMemoryContextService.enhancedEmotionTag(
            input: RecordMemoryContextInput(
                title: resolution.title, category: resolution.category,
                amount: amount, date: selectedDate, baseEmotionTag: resolution.emotionTag,
                weather: weatherCompanionEnabled && shouldAttachLiveContext(to: selectedDate)
                    ? WeatherCompanionService.shared.cachedSnapshot : nil
            )
        )
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
              Int((recordPrefillAmount * 100).rounded()) == Int((currentAmount * 100).rounded()),
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
                baseEmotionTag: resolution.emotionTag
            )
            let memoryContext = memoryContextForRecord(date: draft.date)
            let scenePackId = OCRCommuteScenePolicy.inferredScenePackID(
                title: resolution.title,
                rawText: draft.rawText,
                merchantBrandID: resolution.merchantBrandId,
                category: resolution.category,
                date: draft.date,
                historyItems: memorySeedItems
            )
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
                memoryContext: memoryContext,
                scenePackId: scenePackId
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
                baseEmotionTag: resolution.emotionTag
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

        // OCR 原文包含收单机构、支付方式和交易号等元数据；它们不是消费场景。
        // 只用商品/商户字段复核，避免“股份有限公司”被当成通勤“公司”。
        reviewed.category = OCRCategoryEvidencePolicy.resolve(
            title: reviewed.title,
            rawText: reviewed.rawText,
            fallback: reviewed.category
        )
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
            baseEmotionTag: resolution.emotionTag
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
            baseEmotionTag: resolution.emotionTag
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
        let deletionUserId = cloudContext()?.userId ?? LocalStore.loadLocalLedgerOwnerUserId()
        if !deletionUserId.isEmpty {
            LocalStore.enqueueCloudLedgerDeletion(id: id, deletedAt: Date(), for: deletionUserId)
        }
        items.remove(at: idx)
        guard persistItems(deleting: [id]) else {
            if !deletionUserId.isEmpty { LocalStore.removeCloudLedgerDeletion(id: id, for: deletionUserId) }
            return
        }
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
        let deletedIDs = Set(offsets.compactMap { items.indices.contains($0) ? items[$0].id : nil })
        _ = deleteItems(ids: deletedIDs)
    }

    @discardableResult
    func deleteItem(id: UUID) -> Bool {
        deleteItems(ids: Set([id]))
    }

    @discardableResult
    private func deleteItems(ids requestedIDs: Set<UUID>) -> Bool {
        guard ensureLedgerWritesAllowed() else { return false }
        let existingIDs = Set(items.lazy.map(\.id)).intersection(requestedIDs)
        guard !existingIDs.isEmpty else { return false }
        let deletionUserId = cloudContext()?.userId ?? LocalStore.loadLocalLedgerOwnerUserId()
        let deletedAt = Date()
        if !deletionUserId.isEmpty {
            for id in existingIDs {
                LocalStore.enqueueCloudLedgerDeletion(id: id, deletedAt: deletedAt, for: deletionUserId)
            }
        }
        items.removeAll { existingIDs.contains($0.id) }
        guard persistItems(deleting: existingIDs) else {
            if !deletionUserId.isEmpty {
                for id in existingIDs { LocalStore.removeCloudLedgerDeletion(id: id, for: deletionUserId) }
            }
            return false
        }
        analyticsService.track(
            .recordDeletedBatch,
            props: [.countBucket: AnalyticsService.countBucket(for: existingIDs.count)]
        )
        refreshTodayPlayback()
        Task {
            for id in existingIDs {
                await syncDeleteFromCloud(id: id)
            }
        }
        return true
    }

    @discardableResult
    func updateItem(_ updated: HomeItem, editIntent: RecordEditIntent? = nil) -> Bool {
        guard let idx = items.firstIndex(where: { $0.id == updated.id }) else { return false }
        let original = items[idx]
        var candidate = updated
        candidate.updatedAt = original.updatedAt
        if let editIntent {
            guard editIntent.baseline.id == original.id else { return false }
            candidate = RecordEditPolicy.applying(updated, intent: editIntent, to: original)
        }
        // No new ledger revision, timestamp, analytics, playback or upload for a
        // form that did not change this record. Also guards non-editor callers.
        if candidate == original { return true }
        guard ensureLedgerWritesAllowed() else { return false }
        var resolved = candidate
        let titleResult = UserContentRiskService.shared.validateManualNote(candidate.title, allowEmpty: false)
        guard titleResult.isAllowed else {
            recordInputMessage = titleResult.message
            return false
        }
        recordInputMessage = nil
        if editIntent == nil {
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
            resolved = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
                original: original,
                updated: resolved
            )
            if let trustedMomentTag = TrustedUserMomentNarrativePolicy.emotionTag(for: resolved) {
                resolved.emotionTag = trustedMomentTag
            }
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
        if let reason {
            updated.memoryAnchorRole = reason.assetRole
            updated.memoryAnchorSceneHint = reason.sceneHint
            updated.memoryAnchorCaption = reason.memoryAnchorCaption
            updated.memoryAnchorCreatedAt = updated.memoryAnchorCreatedAt ?? Date()
        } else if originalCount == 0 || PhotoMemoryPromptPolicy.isAutomaticallyAssignedAnchor(updated) {
            updated.memoryAnchorRole = nil
            updated.memoryAnchorSceneHint = nil
            updated.memoryAnchorCaption = nil
            updated.memoryAnchorCreatedAt = nil
        }
        if let trustedMomentTag = TrustedUserMomentNarrativePolicy.emotionTag(for: updated) {
            updated.emotionTag = trustedMomentTag
        }
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
        let trustedMomentTagBeforeRemoval = TrustedUserMomentNarrativePolicy.emotionTag(for: updated)
        updated.removeMemoryImage(at: imageIndex)
        let remainingImageCount = updated.memoryImageCount
        if remainingImageCount == 0 {
            updated.coverMemoryImageIndex = nil
            updated.memoryAnchorRole = nil
            updated.memoryAnchorSceneHint = nil
            updated.memoryAnchorCaption = nil
            updated.memoryAnchorCreatedAt = nil
            if let trustedMomentTagBeforeRemoval,
               updated.emotionTag == trustedMomentTagBeforeRemoval {
                let baseEmotionTag = NarrativeCopyResolver.resolveEmotionTag(
                    context: NarrativeCopyResolver.Context(
                        brandId: updated.merchantBrandId,
                        category: updated.category,
                        amount: updated.amount,
                        date: updated.createdAt,
                        seed: "memory-remove|\(updated.id.uuidString)",
                        note: updated.title,
                        scenePackId: updated.scenePackId
                    )
                )
                updated.emotionTag = memoryEnhancedEmotionTag(
                    title: updated.title,
                    category: updated.category,
                    amount: updated.amount,
                    date: updated.createdAt,
                    baseEmotionTag: baseEmotionTag,
                    weatherOverride: storedWeatherSnapshot(from: updated.memoryContext),
                    allowLiveWeather: false
                )
            }
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
            if let reason = PhotoMemoryPromptPolicy.anchorReason(for: updated) {
                updated.memoryAnchorRole = reason.assetRole
                updated.memoryAnchorSceneHint = reason.sceneHint
                updated.memoryAnchorCaption = updated.memoryAnchorCaption ?? reason.memoryAnchorCaption
                updated.memoryAnchorCreatedAt = updated.memoryAnchorCreatedAt ?? Date()
            }
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
        // 设置页 onAppear 与登录态变化可能同时触发；一次只允许一个全量合并。
        guard !isSyncingCloudLedger else { return }
        let context = cloudContext()
        guard let context else {
            syncStatusMessage = "当前只保存在本机。登录并开启后，金额、分类、备注和日期会自动备份；照片仍保存在本机。"
            return
        }
        isSyncingCloudLedger = true
        syncNeedsNetworkHelp = false
        syncHasPendingFailures = false
        syncStatusMessage = nil
        defer { isSyncingCloudLedger = false }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        var outcome = LedgerSyncAttemptOutcome()
        do {
            let pendingDeletes = LocalStore.loadCloudLedgerDeletionIntents(for: context.userId)
            for intent in pendingDeletes {
                do {
                    try await service.delete(id: intent.id, deletedAt: intent.deletedAt)
                    LocalStore.removeCloudLedgerDeletion(id: intent.id, for: context.userId)
                } catch {
                    guard CloudSessionFailurePolicy.shouldInvalidateSession(for: error) else {
                        outcome.recordDeletionFailure(error)
                        continue
                    }
                    CloudSessionInvalidationService.invalidate()
                    syncStatusMessage = CloudSessionInvalidationService.userMessage
                    return
                }
            }
            let snapshot = try await service.fetchSnapshot()
            let journalTombstones = pendingDeletes.map {
                CloudLedgerMergePolicy.Tombstone(id: $0.id, deletedAt: $0.deletedAt)
            }
            let mergeResult = CloudLedgerMergePolicy.merge(
                local: items,
                remote: snapshot.items,
                tombstones: snapshot.tombstones + journalTombstones
            )
            let merged = mergeResult.merged.sorted { $0.createdAt > $1.createdAt }
            let changes = ledgerChanges(from: items, to: merged)
            items = merged
            guard persistItems(upserting: changes.upserts, deleting: changes.deletedIDs) else {
                syncHasPendingFailures = true
                syncStatusMessage = "同步结果没有写入本机，原账本仍保留。请重启后再试。"
                return
            }
            // The writer runs asynchronously.  Do not upload a merged record
            // until its local metadata/image externalization has completed;
            // otherwise a fast cloud upload can race a later local failure or
            // leave the two stores observing different revisions.
            let persistedIDs = Set(changes.upserts.map(\.id)).union(changes.deletedIDs)
            guard await waitForPersistence(of: persistedIDs) else {
                syncHasPendingFailures = true
                syncStatusMessage = "同步结果没有写入本机，原账本仍保留。请重启后再试。"
                return
            }
            markLocalLedgerOwner(context.userId)
            // 只回传本机更新或云端缺失的记录；云端已是最新的记录不重复上传。
            let pendingIDs = Set(LocalStore.loadCloudLedgerDeletionIntents(for: context.userId).map(\.id))
            for item in mergeResult.uploads where !pendingIDs.contains(item.id) {
                do {
                    try await service.upload(item)
                } catch {
                    guard CloudSessionFailurePolicy.shouldInvalidateSession(for: error) else {
                        outcome.recordUploadFailure(error)
                        continue
                    }
                    CloudSessionInvalidationService.invalidate()
                    syncStatusMessage = CloudSessionInvalidationService.userMessage
                    return
                }
            }
            if !mergeResult.deletedByRemote.isEmpty {
                refreshTodayPlayback()
            }
            // A concurrent automatic mutation may have failed while this batch
            // was suspended. Its failure must not be replaced by batch success.
            syncNeedsNetworkHelp = syncNeedsNetworkHelp || outcome.needsNetworkHelp
            if !outcome.isComplete {
                syncHasPendingFailures = true
                syncStatusMessage = outcome.message
            } else if syncHasPendingFailures {
                syncStatusMessage = "备份尚未完成，有新的修改未同步。请检查网络后重试，本机记录已保留。"
            } else {
                syncStatusMessage = outcome.message
            }
        } catch {
            syncHasPendingFailures = true
            if CloudSessionFailurePolicy.shouldInvalidateSession(for: error) {
                CloudSessionInvalidationService.invalidate()
                syncStatusMessage = CloudSessionInvalidationService.userMessage
            } else {
                syncNeedsNetworkHelp = CloudNetworkFailureGuidance.message(for: error) != nil
                syncStatusMessage = CloudNetworkFailureGuidance.message(for: error)
                    .map { "\($0)同步没有完成，本机记录已保留。" }
                    ?? "同步没有完成，请稍后再试。你的本机记录已保留。"
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

        isRestoringLocalBackup = true
        defer { isRestoringLocalBackup = false }

        // A restore must be ordered after every outstanding local write. The
        // writer actor is serial, but planning from an in-memory snapshot
        // while an earlier edit is still queued could otherwise resurrect
        // stale fields from the backup.
        let pendingRestoreIDs = Set(pendingPersistenceRevisionByID.keys)
        if !pendingRestoreIDs.isEmpty,
           !(await waitForPersistence(of: pendingRestoreIDs)) {
            let message = "本机仍有上一笔修改没有写入完成，请稍后再恢复备份。"
            recordInputMessage = message
            syncStatusMessage = message
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

        // Keep the currently visible ledger until the writer has committed.
        // Publishing the planned snapshot before the asynchronous write made
        // a failed restore appear successful (and briefly exposed all backup
        // image Data on the main actor). The change set already carries the
        // complete backup records, so the writer does not need this projection
        // to be installed first.
        let changedIDs = Set(plan.changes.upserts.map(\.id)).union(plan.changes.deletedIDs)
        guard persistItems(
            upserting: plan.changes.upserts,
            deleting: plan.changes.deletedIDs,
            allowDuringRestore: true
        ) else {
            let message = "这次恢复没有写入本机，本机原账本和照片仍保留。请稍后再试。"
            recordInputMessage = message
            syncStatusMessage = message
            return nil
        }

        guard await waitForPersistence(of: changedIDs) else {
            let message = "这次恢复没有写入本机，本机原账本和照片仍保留。请稍后再试。"
            recordInputMessage = message
            syncStatusMessage = message
            return nil
        }

        // Reload the committed metadata projection so the restored backup does
        // not leave full image Data resident in HomeViewModel.items.
        let persisted = await Task.detached(priority: .utility) {
            LocalStore.loadHomeItemsResult()
        }.value
        guard !persisted.writesBlocked else {
            let message = persisted.issueMessage
                ?? "这次恢复没有写入本机，本机原账本和照片仍保留。请稍后再试。"
            recordInputMessage = message
            syncStatusMessage = message
            return nil
        }

        items = persisted.items.sorted { $0.createdAt > $1.createdAt }
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
            let canUseRemoteAI = AIUsageLimiter.canUseRemoteAI(
                limitPerMonth: settings.remoteAIMonthlyLimit
            )
            let hasCloudSession = !KeychainService.loadAccessToken().isEmpty
            if canUseRemoteAI, hasCloudSession {
                do {
                    let payload = try await aiReportService.generateInsight(
                        snapshot: preparation.snapshot,
                        tone: settings.aiTone,
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
                insightErrorMessage = !canUseRemoteAI
                    ? "本月远程模型调用额度已达上限。"
                    : "未登录，已使用本地规则。"
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

    var hasCurrentRecordCategoryRecommendation: Bool {
        guard !isRecordAmountInputPending,
              let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0,
              let recordPrefillAmount, amount == recordPrefillAmount,
              let result = recordPrefillResult else { return false }
        return RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(
            result, selectedCategory: selectedCategory
        )
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
              Int((recordPrefillAmount * 100).rounded()) == Int((amount * 100).rounded()) else {
            return items.count < 6 ? "先帮你放到合适分类。" : nil
        }
        guard RecordInputAssistanceComputation.canDescribeAdoptedRecommendation(
            result,
            selectedCategory: selectedCategory
        ) else { return nil }

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
        guard !hasExplicitRecordCategoryDecision else { return nil }
        let normalizedAmount = amountText.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else { return nil }
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""
        let brand = MerchantBrandCatalog.matchBrand(in: trimmedNote)
        let noteSemanticCategory = semanticCategory(from: trimmedNote)
        let habitStart = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? .distantPast
        let habitSupportingItems = recordInputHistorySnapshot?.prefillItems ?? items.filter { item in
            item.amount > 0 && item.createdAt >= habitStart
        }
        if !categoryLockedByUser {
            if let brand {
                if let noteSemanticCategory,
                   noteSemanticCategory != brand.category {
                    return CategoryRecommendResult(recommended: noteSemanticCategory, reasonTag: "semantic")
                }
                return CategoryRecommendResult(recommended: brand.category, reasonTag: "brand")
            }
            if let noteSemanticCategory {
                return CategoryRecommendResult(recommended: noteSemanticCategory, reasonTag: "semantic")
            }
            if let learnedCategory = RecordHabitOverridePolicy.learnedCategory(
                for: trimmedNote,
                from: habitSupportingItems
            ) {
                return CategoryRecommendResult(recommended: learnedCategory, reasonTag: "entity_history")
            }
        }
        if !categoryLockedByUser,
           let category = recordPrefillResult?.category,
           recordPrefillResult?.source != "generic",
           let recordPrefillAmount,
           Int((recordPrefillAmount * 100).rounded()) == Int((amount * 100).rounded()),
           (recordPrefillResult?.confidence ?? 0) >= 0.55,
           RecordHabitOverridePolicy.allows(
               note: trimmedNote,
               suggestedCategory: category,
               supportingItems: habitSupportingItems
           ) {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        if let frequentSuggestion = frequentRecordAmountSuggestion(for: amount, at: selectedDate),
           frequentSuggestion.confidence >= 0.67,
           RecordHabitOverridePolicy.allows(
               note: trimmedNote,
               suggestedCategory: frequentSuggestion.category,
               supportingItems: habitSupportingItems
           ),
           !categoryLockedByUser {
            return CategoryRecommendResult(recommended: frequentSuggestion.category, reasonTag: "frequent")
        }
        if !categoryLockedByUser,
           let category = recordPrefillResult?.category,
           recordPrefillResult?.source == "generic",
           let recordPrefillAmount,
           Int((recordPrefillAmount * 100).rounded()) == Int((amount * 100).rounded()),
           RecordHabitOverridePolicy.allows(
               note: trimmedNote,
               suggestedCategory: category,
               supportingItems: habitSupportingItems
           ) {
            return CategoryRecommendResult(recommended: category, reasonTag: recordPrefillResult?.source)
        }
        guard !trimmedNote.isEmpty else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        let result = categoryRecommendService.recommend(
            input: CategoryRecommendInput(
                amount: amount,
                referenceDate: selectedDate,
                items: recentItems,
                noteDraft: trimmedNote,
                locked: categoryLockedByUser,
                context: currentRecordContextSignal()
            )
        )
        guard let result,
              RecordHabitOverridePolicy.allows(
                  note: trimmedNote,
                  suggestedCategory: result.recommended,
                  supportingItems: habitSupportingItems
              ) else {
            return nil
        }
        return result
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
        weatherOverride: WeatherSnapshot? = nil,
        allowLiveWeather: Bool = true
    ) -> String {
        let settings = LocalStore.loadSettings()
        let weather = weatherOverride ?? (allowLiveWeather && settings.weatherCompanionEnabled && shouldAttachLiveContext(to: date)
            ? WeatherCompanionService.shared.cachedSnapshot
            : nil)
        return RecordMemoryContextService.enhancedEmotionTag(
            input: RecordMemoryContextInput(
                title: title,
                category: category,
                amount: amount,
                date: date,
                baseEmotionTag: baseEmotionTag,
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

    private func scheduleRecordAmountInput() {
        recordAmountInputTask?.cancel()
        guard let amount = Double(inputAmount.replacingOccurrences(of: ",", with: "")), amount > 0 else {
            cancelPendingRecordAmountInput()
            return
        }
        let request = recordAmountInputGate.begin()
        if !isRecordAmountInputPending { isRecordAmountInputPending = true }
        recordAmountInputTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: RecordAmountInputGate.delayNanoseconds)
            guard !Task.isCancelled, recordAmountInputGate.finish(request) else { return }
            recordAmountInputTask = nil
            isRecordAmountInputPending = false
            refreshRecordPrefill()
        }
    }

    /// Explicit actions consume only pending amount work. Full prefill stays asynchronous.
    func flushPendingRecordAmountInput() {
        guard let request = recordAmountInputGate.pending,
              recordAmountInputGate.finish(request) else { return }
        recordAmountInputTask?.cancel()
        recordAmountInputTask = nil
        isRecordAmountInputPending = false
        refreshRecordPrefill()
    }

    func cancelPendingRecordAmountInput() {
        recordAmountInputGate.cancel()
        recordAmountInputTask?.cancel()
        recordAmountInputTask = nil
        if isRecordAmountInputPending { isRecordAmountInputPending = false }
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
        } else {
            prepareRecordQuickNoteHistorySnapshot(key: historyKey)
        }

        // History completion and title/focus observers must not bypass amount settling.
        guard !isRecordAmountInputPending else { return }

        let normalizedAmount = inputAmount.replacingOccurrences(of: ",", with: "")
        guard let amount = Double(normalizedAmount), amount > 0 else {
            invalidateRecordPrefillSnapshot()
            return
        }
        guard !categoryLockedByUser, !hasExplicitRecordCategoryDecision else {
            invalidateRecordPrefillSnapshot()
            return
        }
        guard !isCurrentRecordNoteGenerated else {
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
        guard recordInputHistorySnapshot?.key != key else {
            prepareRecordQuickNoteHistorySnapshot(key: key)
            return
        }
        prepareRecordInputHistorySnapshot(key: key, now: Date())
    }

    func cancelRecordInputAssistancePreparation() {
        cancelPendingRecordAmountInput()
        cancelRecordQuickNoteHistoryPreparation()
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
        cancelRecordQuickNoteHistoryPreparation()
        recordQuickNoteHistoryKey = nil
        recordQuickNotePoolCache = nil
        if !recordQuickNoteTitlesByContext.isEmpty {
            recordQuickNoteTitlesByContext = [:]
        }
        invalidateRecordPrefillSnapshot()

        let input = RecordInputHistoryPreparationInput(
            key: key,
            items: items,
            referenceDate: selectedDate,
            now: now
        )
        recordQuickNoteHistoryInput = input
        recordInputHistoryPreparationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, recordInputHistoryRequestID == requestID else { return }
            let snapshot = await withTaskGroup(
                of: RecordInputHistorySnapshot?.self,
                returning: RecordInputHistorySnapshot?.self
            ) { group in
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else { return nil }
                    return RecordInputAssistanceComputation.historySnapshot(input, includeQuickNoteHistory: false)
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

    /// Optional quick-note history must not delay the category recommendation.
    /// A cancelled view can resume this independently of an already-ready history snapshot.
    private func prepareRecordQuickNoteHistorySnapshot(key: RecordInputHistoryKey) {
        guard recordInputHistorySnapshot?.key == key,
              let input = recordQuickNoteHistoryInput, input.key == key,
              recordQuickNoteHistoryKey != key,
              recordQuickNoteHistoryPreparationKey != key else { return }
        cancelRecordQuickNoteHistoryPreparation()
        let requestID = recordQuickNoteHistoryRequestID
        recordQuickNoteHistoryPreparationKey = key
        recordQuickNoteHistoryPreparationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, recordQuickNoteHistoryRequestID == requestID else { return }
            let titles = await withTaskGroup(
                of: [String: [String]]?.self,
                returning: [String: [String]]?.self
            ) { group in
                group.addTask(priority: .utility) {
                    guard !Task.isCancelled else { return nil }
                    let result = RecordQuickNotePolicy.historicalTitles(items: input.items, at: input.referenceDate)
                    return Task.isCancelled ? nil : result
                }
                return await group.next() ?? nil
            }
            guard !Task.isCancelled, recordQuickNoteHistoryRequestID == requestID else { return }
            recordQuickNoteHistoryPreparationTask = nil
            recordQuickNoteHistoryPreparationKey = nil
            guard let titles,
                  let history = recordInputHistorySnapshot, history.key == key,
                  RecordInputAssistanceComputation.historyKey(
                    ledgerRevision: recordInputAssistanceRevision,
                    referenceDate: selectedDate,
                    referenceDateEditedByUser: selectedDateEditedByUser
                  ) == key else { return }
            let snapshot = RecordInputHistorySnapshot(
                key: history.key,
                prefillItems: history.prefillItems,
                frequentSuggestions: history.frequentSuggestions,
                frequentTitlesBySuggestionID: history.frequentTitlesBySuggestionID,
                quickNoteTitlesByContext: titles
            )
            recordInputHistorySnapshot = snapshot
            recordQuickNoteHistoryKey = key
            recordQuickNoteHistoryInput = nil
            if recordQuickNoteTitlesByContext != snapshot.quickNoteTitlesByContext {
                recordQuickNoteTitlesByContext = snapshot.quickNoteTitlesByContext
            }
        }
    }

    private func cancelRecordQuickNoteHistoryPreparation() {
        recordQuickNoteHistoryPreparationTask?.cancel()
        recordQuickNoteHistoryPreparationTask = nil
        recordQuickNoteHistoryPreparationKey = nil
        recordQuickNoteHistoryRequestID = UUID()
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
           existingKey.selectedCategory == selectedCategory,
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
                  !hasExplicitRecordCategoryDecision,
                  recordInputHistorySnapshot?.key == history.key else {
                return
            }
            applyRecordPrefillSnapshot(snapshot)
            recordPrefillPreparationTask = nil
        }
    }

    private func applyRecordPrefillSnapshot(_ snapshot: RecordPrefillSnapshot) {
        let noteResult = UserContentRiskService.shared.validateManualNote(inputTitle, allowEmpty: true)
        let trimmedNote = noteResult.isAllowed ? noteResult.value : ""
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: recordInputAssistanceRevision,
            referenceDate: selectedDate,
            referenceDateEditedByUser: selectedDateEditedByUser
        )
        guard !hasExplicitRecordCategoryDecision,
              recordPrefillPreparationKey == snapshot.key,
              RecordInputAssistanceComputation.matchesCurrentDraft(
                snapshot.key,
                historyKey: historyKey,
                amount: Double(inputAmount.replacingOccurrences(of: ",", with: "")),
                referenceDate: selectedDate,
                noteDraft: trimmedNote,
                selectedCategory: selectedCategory,
                categoryLockedByUser: categoryLockedByUser,
                generatedNoteContext: recordGeneratedNoteContext
              ) else { return }
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
        let learnedCategory = RecordHabitOverridePolicy.learnedCategory(
            for: note,
            from: history.prefillItems
        )
        let frequentSuggestion = history.frequentSuggestions.first { suggestion in
            Int((suggestion.amount * 100).rounded()) == Int((amount * 100).rounded())
        }
        let brandCategory: HomeItem.Category? = brand.flatMap { brand in
            if let semanticCategory,
               semanticCategory != brand.category {
                return nil
            }
            return brand.category
        }
        let frequentCategory: HomeItem.Category? = frequentSuggestion.flatMap { suggestion -> HomeItem.Category? in
            guard suggestion.confidence >= 0.67,
                  RecordHabitOverridePolicy.allows(
                      note: note,
                      suggestedCategory: suggestion.category,
                      supportingItems: history.prefillItems
                  ) else {
                return nil
            }
            return suggestion.category
        }
        if let category = brandCategory ?? semanticCategory ?? learnedCategory ?? frequentCategory {
            applyRecommendedCategory(category)
            return
        }
        guard !categoryLockedByUser, !hasExplicitRecordCategoryDecision,
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
        cancelRecordQuickNoteHistoryPreparation()
        recordQuickNoteHistoryKey = nil
        recordQuickNoteHistoryInput = nil
        recordInputHistoryPreparationTask?.cancel()
        recordInputHistoryPreparationTask = nil
        recordInputHistoryPreparationKey = nil
        recordInputHistoryRequestID = UUID()
        recordInputHistorySnapshot = nil
        recordQuickNotePoolCache = nil
        if !recordQuickNoteTitlesByContext.isEmpty {
            recordQuickNoteTitlesByContext = [:]
        }
        if !recordWarmupSuggestions.isEmpty {
            recordWarmupSuggestions = []
        }
        invalidateRecordPrefillSnapshot()
    }

    private func semanticCategory(from note: String) -> HomeItem.Category? {
        RecordSemanticLexicon.semanticCategory(of: note)
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
        LocalStore.saveLocalLedgerOwnerUserId(CloudLedgerOwnershipPolicy.ownerAfterClearingLocalLedger())
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
        flushPendingRecordAmountInput()
        rememberCategoryCorrectionIfNeeded(to: category)
        let wasGenerated = isCurrentRecordNoteGenerated
        recordExplicitIntent.selectCategory(category)
        selectedCategory = category
        // A category click is not handwriting; keep generated provenance too.
        recordGeneratedNoteContext = wasGenerated
            ? RecordGeneratedNoteContext(title: inputTitle, category: category) : nil
        invalidateRecordPrefillSnapshot()
    }

    /// Called only from a committed text-input event, never from an observer.
    func applyUserRecordTitle(_ title: String) {
        let committedTitle = String(title.prefix(32))
        guard committedTitle != inputTitle else { return }
        isApplyingRecordTitleEvent = true
        defer { isApplyingRecordTitleEvent = false }
        recordExplicitIntent.adoptAutomaticCategory(selectedCategory)
        recordGeneratedNoteContext = nil
        recordNoteIsHandwritten = !committedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        recordHandwrittenAnchor = recordNoteIsHandwritten ? committedTitle : nil
        let meaningChanged = committedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            != inputTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        inputTitle = committedTitle
        let validation = UserContentRiskService.shared.validateManualNote(committedTitle, allowEmpty: true)
        if meaningChanged, validation.isAllowed, let category = recordExplicitIntent.writeNote(validation.value) {
            selectedCategory = category
            pendingCategoryCorrectionFrom = nil
            lastAutoRecommendedCategory = nil
        }
        invalidateRecordPrefillSnapshot()
    }

    var isCurrentRecordNoteGenerated: Bool {
        recordGeneratedNoteContext?.matches(title: inputTitle, category: selectedCategory) == true
    }

    var currentRecordGeneratedNoteContext: RecordGeneratedNoteContext? {
        isCurrentRecordNoteGenerated ? recordGeneratedNoteContext : nil
    }

    func applyGeneratedRecordTitle(_ title: String, preservingHandwrittenAnchor: Bool = false) {
        isApplyingRecordTitleEvent = true
        defer { isApplyingRecordTitleEvent = false }
        let category = selectedCategory
        let normalizedTitle = UserContentRiskService.shared.normalizedManualNote(title)
        if !preservingHandwrittenAnchor { recordHandwrittenAnchor = nil }
        recordNoteIsHandwritten = false
        inputTitle = normalizedTitle
        recordGeneratedNoteContext = RecordGeneratedNoteContext(title: normalizedTitle, category: category)
        invalidateRecordPrefillSnapshot()
    }

    /// Undo an expression change without replaying the original note as new intent.
    func restoreHandwrittenRecordTitle() {
        guard let anchor = recordHandwrittenAnchor else { return }
        isApplyingRecordTitleEvent = true
        defer { isApplyingRecordTitleEvent = false }
        recordGeneratedNoteContext = nil
        recordNoteIsHandwritten = true
        inputTitle = anchor
        invalidateRecordPrefillSnapshot()
    }

    func applyScenePackDraft(title: String, category: HomeItem.Category) {
        flushPendingRecordAmountInput()
        rememberCategoryCorrectionIfNeeded(to: category)
        recordExplicitIntent.selectCategory(category)
        selectedCategory = category
        applyGeneratedRecordTitle(title)
        recordInputMessage = nil
    }

    func applyScenePackCategory(_ category: HomeItem.Category) {
        flushPendingRecordAmountInput()
        rememberCategoryCorrectionIfNeeded(to: category)
        let wasGenerated = isCurrentRecordNoteGenerated
        recordExplicitIntent.selectCategory(category)
        selectedCategory = category
        recordGeneratedNoteContext = wasGenerated
            ? RecordGeneratedNoteContext(title: inputTitle, category: category) : nil
        invalidateRecordPrefillSnapshot()
        recordInputMessage = nil
    }

    func applyRecommendedCategory(_ category: HomeItem.Category) {
        guard !categoryLockedByUser, !hasExplicitRecordCategoryDecision else { return }
        if category != selectedCategory {
            recordGeneratedNoteContext = nil
        }
        selectedCategory = category
        recordExplicitIntent.adoptAutomaticCategory(category)
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
        guard !hasCurrentHandwrittenCategoryConflict else { return [] }
        let key = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: recordInputAssistanceRevision, referenceDate: date,
            referenceDateEditedByUser: selectedDateEditedByUser
        )
        let history = recordInputHistorySnapshot?.key == key
            ? recordQuickNoteTitlesByContext[RecordQuickNotePolicy.contextKey(category: category, date: date)] ?? []
            : []
        let poolKey = RecordQuickNotePolicy.PoolKey(
            context: RecordQuickNotePolicy.contextKey(category: category, date: date),
            history: history, prefill: compatiblePrefillTitleForSave(category: category)
        )
        if recordQuickNotePoolCache?.key != poolKey {
            recordQuickNotePoolCache = (poolKey, RecordQuickNotePolicy.preparePool(
                category: category, date: date, history: history, prefill: poolKey.prefill
            ))
        }
        guard let pool = recordQuickNotePoolCache?.pool else { return [] }
        let suggestions = RecordQuickNotePolicy.suggestions(pool: pool, anchor: inputTitle)
        guard let anchor = recordHandwrittenAnchor else { return suggestions }
        return suggestions.filter { RecordQuickNotePolicy.respectsHandwrittenAnchor($0, anchor: anchor) }
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
            Int((suggestion.amount * 100).rounded()) == Int((amount * 100).rounded())
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
        let snapshotSignature = dailyInsightSnapshotSignature(
            for: todayItems,
            dayKey: key,
            settings: settings
        )
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
            if !AIUsageLimiter.canUseRemoteAI(limitPerMonth: settings.remoteAIMonthlyLimit) {
                insightErrorMessage = "本月远程模型调用额度已达上限，已使用本地规则。"
            } else if KeychainService.loadAccessToken().isEmpty {
                insightErrorMessage = "未登录，已使用本地规则。"
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
                        tone: settings.aiTone,
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
        let now = Date()
        prepareItemDerivedCacheIfNeeded(now: now)
        scheduleNarrativeAIPrecompute(now: now)
    }

    private func scheduleNarrativeAIPrecompute(now: Date) {
        let settings = LocalStore.loadSettings()
        guard settings.useRemoteAI,
              !items.isEmpty,
              !LocalStore.isReleaseFixtureMode,
              narrativeAIPreparationRevision != homeDashboardRevision else { return }
        narrativeAIPreparationRevision = homeDashboardRevision
        narrativeAIPreparationTask?.cancel()
        let snapshotItems = items
        let sourceRevision = homeDashboardRevision
        narrativeAIPreparationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await LifeNarrativeAIPrecomputeCoordinator.shared.prepare(
                items: snapshotItems,
                sourceRevision: sourceRevision,
                now: now,
                settings: settings
            )
        }
    }

    private func refreshNarrativeAIConfiguration() {
        narrativeAIPreparationTask?.cancel()
        narrativeAIPreparationRevision = -1
        narrativeAIPreparationTask = Task { @MainActor [weak self] in
            await LifeNarrativeAIPrecomputeCoordinator.shared.invalidatePendingRewrites()
            guard let self, !Task.isCancelled else { return }
            self.narrativeAIPreparationTask = nil
            self.scheduleNarrativeAIPrecompute(now: Date())
        }
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

    func ledgerDisplayFingerprint(now: Date = Date()) -> String? {
        let key = itemDerivedCacheKey(now: now)
        guard itemDerivedCache.key == key,
              !itemDerivedCache.ledgerDisplayFingerprint.isEmpty else { return nil }
        return itemDerivedCache.ledgerDisplayFingerprint
    }

    func prepareItemDerivedCacheIfNeeded(now: Date) {
        let key = itemDerivedCacheKey(now: now)
        guard itemDerivedCache.key != key || itemDerivedCacheNeedsFullRefresh else { return }
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
            let snapshot = await LedgerBackgroundComputationLane.shared.buildItemDerived(input)
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
            itemDerivedCacheNeedsFullRefresh = false
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
        recordGeneratedNoteContext = nil
        recordHandwrittenAnchor = nil
        recordNoteIsHandwritten = false
        recordExplicitIntent = RecordExplicitIntentState(category: .other)
        inputTitle = ""
        inputAmount = ""
        selectedDate = .now
        selectedDateEditedByUser = false
        selectedCategory = .other
        invalidateRecordPrefillSnapshot()
        lastAutoRecommendedCategory = nil
        pendingCategoryCorrectionFrom = nil
    }

    private func ensureLedgerWritesAllowed(allowDuringRestore: Bool = false) -> Bool {
        guard allowDuringRestore || !isRestoringLocalBackup else {
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
        deleting: Set<UUID> = [],
        allowDuringRestore: Bool = false
    ) -> Bool {
        guard ensureLedgerWritesAllowed(allowDuringRestore: allowDuringRestore) else { return false }
        let changes = LedgerHomeItemsChangeSet(upserts: upserting, deletedIDs: deleting)
        guard !changes.isEmpty else { return true }

        persistenceRevision &+= 1
        let revision = persistenceRevision
        let fallback = items
        isPersistingLedger = true
        let task = Task { [persistenceWriter] in
            await persistenceWriter.saveChanges(
                changes,
                currentItemsForFallback: fallback
            )
        }
        pendingPersistenceTasks[revision] = task
        for id in Set(upserting.map(\.id)).union(deleting) {
            pendingPersistenceRevisionByID[id] = revision
            latestPersistenceRevisionByID[id] = revision
            // A previous completion may still be buffered for this record;
            // it belongs to the old revision and must not satisfy a wait for
            // this newly submitted write.
            completedPersistenceResultByID.removeValue(forKey: id)
        }
        publishImmediateItemDerivedProjection(
            upserting: upserting,
            deleting: deleting,
            now: Date()
        )
        Task { @MainActor [weak self] in
            let result = await task.value
            await self?.completePersistence(
                revision: revision,
                recordIDs: Set(upserting.map(\.id)).union(deleting),
                result: result
            )
        }
        return true
    }

    private func completePersistence(
        revision: UInt64,
        recordIDs: Set<UUID>,
        result: LedgerPersistenceSaveResult
    ) async {
        let success = result.success
        completedPersistenceResults[revision] = success
        pendingPersistenceTasks.removeValue(forKey: revision)
        for id in recordIDs {
            guard LedgerPersistenceRevisionPolicy.ownsRecordCompletion(
                completionRevision: revision,
                latestRevisionForRecord: latestPersistenceRevisionByID[id]
            ) else {
                continue
            }
            if pendingPersistenceRevisionByID[id] == revision {
                pendingPersistenceRevisionByID.removeValue(forKey: id)
            }
            completedPersistenceResultByID[id] = success
        }
        if completedPersistenceResults.count > 32 {
            let oldest = completedPersistenceResults.keys.sorted().prefix(completedPersistenceResults.count - 32)
            for key in oldest { completedPersistenceResults.removeValue(forKey: key) }
        }
        isPersistingLedger = !pendingPersistenceTasks.isEmpty

        if success {
            // The writer has externalized any image bytes and returned a
            // metadata-only projection. Replace only records for which this
            // revision is still the latest write. A newer write to an
            // unrelated record must not prevent us from releasing image Data
            // for this record from memory.
            if !result.persistedItems.isEmpty {
                let persistedByID: [UUID: HomeItem] = Dictionary(uniqueKeysWithValues: result.persistedItems.compactMap { item in
                    guard latestPersistenceRevisionByID[item.id] == revision else { return nil }
                    return (item.id, item)
                })
                guard !persistedByID.isEmpty else { return }
                items = items.map { persistedByID[$0.id] ?? $0 }
                itemDerivedCache.replaceItems(with: persistedByID)
                if let history = recordInputHistorySnapshot {
                    recordInputHistorySnapshot = RecordInputHistorySnapshot(
                        key: history.key,
                        prefillItems: history.prefillItems.map { persistedByID[$0.id] ?? $0 },
                        frequentSuggestions: history.frequentSuggestions,
                        frequentTitlesBySuggestionID: history.frequentTitlesBySuggestionID,
                        quickNoteTitlesByContext: history.quickNoteTitlesByContext
                    )
                }
            }
            return
        }

        guard LedgerPersistenceRevisionPolicy.acceptsCompletion(
            completionRevision: revision,
            currentRevision: persistenceRevision
        ) else {
            // A revision can touch several records. Retry only the records
            // still owned by this completion; another record in the same
            // batch may already have a newer edit and must not be submitted
            // a third time from this stale failure path.
            let retryIDs = recordIDs.filter { id in
                guard let latest = latestPersistenceRevisionByID[id] else { return true }
                return latest <= revision
            }
            guard !retryIDs.isEmpty else { return }
            let currentIDs = Set(items.map(\.id))
            let retryUpserts = retryIDs.compactMap { id in
                items.first(where: { $0.id == id })
            }
            let retryDeletes = retryIDs.subtracting(currentIDs)
            _ = persistItems(upserting: retryUpserts, deleting: retryDeletes)
            for item in retryUpserts {
                Task { await syncUpsertToCloud(item) }
            }
            for id in retryDeletes {
                Task { await syncDeleteFromCloud(id: id) }
            }
            return
        }

        let reloadResult = await Task.detached(priority: .utility) {
            LocalStore.loadHomeItemsResult()
        }.value
        guard LedgerPersistenceRevisionPolicy.acceptsCompletion(
            completionRevision: revision,
            currentRevision: persistenceRevision
        ) else { return }
        items = reloadResult.items.sorted { $0.createdAt > $1.createdAt }
        localLedgerWritesBlocked = reloadResult.writesBlocked
        let message = reloadResult.issueMessage
            ?? "这次修改没有写入本机，原账本仍保留。请重启后再试。"
        recordInputMessage = message
        syncStatusMessage = message
    }

    private func waitForPersistence(of recordIDs: Set<UUID>) async -> Bool {
        for id in recordIDs {
            if let completed = completedPersistenceResultByID.removeValue(forKey: id) {
                guard completed else { return false }
                continue
            }
            while let revision = pendingPersistenceRevisionByID[id] {
                if let result = completedPersistenceResults[revision] {
                    let ownsRevision = pendingPersistenceRevisionByID[id] == revision
                    if ownsRevision {
                        pendingPersistenceRevisionByID.removeValue(forKey: id)
                        completedPersistenceResultByID.removeValue(forKey: id)
                    }
                    if !pendingPersistenceRevisionByID.values.contains(revision) {
                        completedPersistenceResults.removeValue(forKey: revision)
                    }
                    // A newer write superseded this completion while the
                    // caller was suspended. Keep waiting for that revision;
                    // an older failure must not make a newer successful edit
                    // report failure.
                    guard ownsRevision else { continue }
                    guard result else { return false }
                    continue
                }
                guard let task = pendingPersistenceTasks[revision] else {
                    if pendingPersistenceRevisionByID[id] == revision {
                        pendingPersistenceRevisionByID.removeValue(forKey: id)
                    }
                    continue
                }
                let result = await task.value
                let ownsRevision = pendingPersistenceRevisionByID[id] == revision
                if ownsRevision {
                    pendingPersistenceRevisionByID.removeValue(forKey: id)
                    completedPersistenceResultByID.removeValue(forKey: id)
                }
                guard ownsRevision else { continue }
                guard result.success else { return false }
            }
        }
        isPersistingLedger = !pendingPersistenceTasks.isEmpty
        return true
    }

    private func publishImmediateItemDerivedProjection(
        upserting: [HomeItem],
        deleting: Set<UUID>,
        now: Date
    ) {
        let dayKey = Self.dayKey(for: now)
        var projected: ItemDerivedCacheSnapshot
        if itemDerivedCache.key.dayKey == dayKey,
           itemDerivedCache.key.ledgerRevision >= 0 {
            projected = itemDerivedCache
        } else {
            projected = ItemDerivedCacheComputation.build(
                ItemDerivedCachePreparationInput(
                    key: ItemDerivedCachePreparationKey(
                        ledgerRevision: homeDashboardRevision,
                        dayKey: dayKey
                    ),
                    items: items,
                    now: now,
                    itemsAreSortedDescending: false
                )
            )
        }
        projected = ItemDerivedCacheImmediateMutationPolicy.removing(
            ids: deleting,
            from: projected
        )
        for item in upserting {
            projected = ItemDerivedCacheImmediateMutationPolicy.adding(
                item,
                in: projected,
                now: now
            )
        }
        itemDerivedCache = ItemDerivedCacheImmediateMutationPolicy.rekeying(
            projected,
            ledgerRevision: homeDashboardRevision,
            now: now
        )
        itemDerivedCacheRevision = homeDashboardRevision
        itemDerivedCacheNeedsFullRefresh = true
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

    private func cloudContext() -> (baseURL: String, accessToken: String, userId: String)? {
        let settings = LocalStore.loadSettings()
        let baseURL = settings.backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = KeychainService.loadAccessToken()
        guard settings.syncEnabled, !baseURL.isEmpty, !token.isEmpty else { return nil }
        return (baseURL, token, settings.cloudUserId)
    }

    /// 本机账本一旦同步到某个账号，就记下归属；登出时保留，换账号登录时用于提示。
    private func markLocalLedgerOwner(_ userId: String) {
        let owner = CloudLedgerOwnershipPolicy.ownerAfterEnablingSync(currentUserId: userId)
        guard !owner.isEmpty, LocalStore.loadLocalLedgerOwnerUserId() != owner else { return }
        LocalStore.saveLocalLedgerOwnerUserId(owner)
    }

    private func syncUpsertToCloud(_ item: HomeItem) async {
        guard !LocalStore.isReleaseFixtureMode else { return }
        guard await waitForPersistence(of: [item.id]) else { return }
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        do {
            try await service.upload(item)
            markLocalLedgerOwner(context.userId)
            if LedgerCloudUploadCompletionPolicy.requiresCompensatingDelete(
                uploadedItemID: item.id,
                currentItemIDs: Set(items.lazy.map(\.id))
            ) {
                try await service.delete(id: item.id)
                if !isSyncingCloudLedger && !syncHasPendingFailures {
                    syncNeedsNetworkHelp = false
                    syncStatusMessage = "这笔云端备份已删除；本机照片不受影响。"
                }
                return
            }
            if !isSyncingCloudLedger && !syncHasPendingFailures {
                syncNeedsNetworkHelp = false
                syncStatusMessage = "这笔记录已备份；照片仍保存在本机。"
            }
        } catch {
            syncHasPendingFailures = true
            if CloudSessionFailurePolicy.shouldInvalidateSession(for: error) {
                CloudSessionInvalidationService.invalidate()
                syncStatusMessage = CloudSessionInvalidationService.userMessage
            } else {
                syncNeedsNetworkHelp = CloudNetworkFailureGuidance.message(for: error) != nil
                syncStatusMessage = CloudNetworkFailureGuidance.message(for: error)
                    .map { "\($0)这笔记录已保存在本机。" }
                    ?? "这笔记录已保存在本机，云端暂时没同步成功。"
            }
        }
    }

    private func syncDeleteFromCloud(id: UUID) async {
        guard !LocalStore.isReleaseFixtureMode else { return }
        guard await waitForPersistence(of: [id]) else { return }
        guard let context = cloudContext() else { return }
        let service = LedgerSyncService(baseURL: context.baseURL, accessToken: context.accessToken)
        let intent = LocalStore.loadCloudLedgerDeletionIntents(for: context.userId).first(where: { $0.id == id })
        do {
            try await service.delete(id: id, deletedAt: intent?.deletedAt)
            LocalStore.removeCloudLedgerDeletion(id: id, for: context.userId)
            if !isSyncingCloudLedger && !syncHasPendingFailures {
                syncNeedsNetworkHelp = false
                syncStatusMessage = "这笔云端备份已删除；本机照片不受影响。"
            }
        } catch {
            syncHasPendingFailures = true
            if CloudSessionFailurePolicy.shouldInvalidateSession(for: error) {
                CloudSessionInvalidationService.invalidate()
                syncStatusMessage = CloudSessionInvalidationService.userMessage
            } else {
                syncNeedsNetworkHelp = CloudNetworkFailureGuidance.message(for: error) != nil
                syncStatusMessage = CloudNetworkFailureGuidance.message(for: error)
                    .map { "\($0)本机已更新，云端暂时没同步删除。" }
                    ?? "本机已更新，云端暂时没同步删除。"
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

    fileprivate nonisolated static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func dailyInsightSnapshotSignature(
        for todayItems: [HomeItem],
        dayKey: String,
        settings: AppSettings
    ) -> String {
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
        let remoteState: String
        if !settings.useRemoteAI {
            remoteState = "disabled"
        } else {
            remoteState = KeychainService.loadAccessToken().isEmpty ? "proxy-signed-out" : "proxy-ready"
        }
        let presentationIdentity = [
            "tone=\(settings.aiTone.rawValue)",
            "remote=\(remoteState)"
        ]
        return ([dayKey, "\(rows.count)"] + presentationIdentity + rows).joined(separator: "|")
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
