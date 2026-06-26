import Foundation

struct RecordPrefillInput {
    let amount: Double
    let referenceDate: Date
    let items: [HomeItem]
    let noteDraft: String
    let categoryLocked: Bool
    let merchantBrandId: String?
    let context: RecordContextSignal?

    init(
        amount: Double,
        referenceDate: Date,
        items: [HomeItem],
        noteDraft: String,
        categoryLocked: Bool,
        merchantBrandId: String?,
        context: RecordContextSignal? = nil
    ) {
        self.amount = amount
        self.referenceDate = referenceDate
        self.items = items
        self.noteDraft = noteDraft
        self.categoryLocked = categoryLocked
        self.merchantBrandId = merchantBrandId
        self.context = context
    }
}

struct RecordPrefillResult {
    let category: HomeItem.Category?
    let title: String?
    let emotionTag: String?
    let confidence: Double
    let source: String
}

struct RecordPrefillService {
    private struct SceneHabit {
        let signal: LifeSceneSignal
        let items: [HomeItem]
        let count: Int
        let confidence: Double
        let activeSupport: Double
    }

    private let coldStartThreshold = 6
    private let genericCategoryService = CategoryRecommendService()

    func prefill(input: RecordPrefillInput) -> RecordPrefillResult? {
        guard input.amount > 0 else { return nil }

        if let brand = MerchantBrandCatalog.definition(for: input.merchantBrandId),
           !input.categoryLocked {
            let title = NarrativeCopyResolver.resolveTitle(
                brandId: brand.id,
                fallback: input.noteDraft
            )
            let emotion = NarrativeCopyResolver.resolveEmotionTag(
                context: NarrativeCopyResolver.Context(
                    brandId: brand.id,
                    category: brand.category,
                    amount: input.amount,
                    date: input.referenceDate,
                    seed: title,
                    note: title
                )
            )
            return RecordPrefillResult(
                category: brand.category,
                title: title,
                emotionTag: emotion,
                confidence: 1,
                source: "brand"
            )
        }

        guard !input.categoryLocked else { return nil }

        let historyItems = recentHistory(from: input.items)
        guard historyItems.count >= coldStartThreshold else {
            return genericPrefill(input: input, historyItems: historyItems)
        }

        let candidates = historyItems.filter { item in
            sameHabitContext(item: item, amount: input.amount, referenceDate: input.referenceDate)
        }
        if let sceneHabit = dominantSceneHabit(in: candidates) {
            let title = sceneHabitTitle(
                for: sceneHabit,
                amount: input.amount,
                date: input.referenceDate
            )
            let emotion = sceneHabitRecommendationTier(sceneHabit) == .strong
                ? NarrativeCopyResolver.resolveEmotionTag(
                    context: NarrativeCopyResolver.Context(
                        brandId: nil,
                        category: sceneHabit.signal.category,
                        amount: input.amount,
                        date: input.referenceDate,
                        seed: title ?? sceneHabit.signal.label,
                        note: title ?? sceneHabit.signal.label
                    )
                )
                : nil
            return RecordPrefillResult(
                category: sceneHabit.signal.category,
                title: title,
                emotionTag: emotion,
                confidence: sceneHabit.confidence,
                source: "scene_habit"
            )
        }

        guard let topCategory = rankedCategories(in: candidates).first else {
            return genericPrefill(input: input, historyItems: historyItems)
        }

        let confidence = habitConfidence(for: topCategory, candidates: candidates)
        let topTitle = confidence >= 0.65 ? mostCommonTitle(in: candidates, category: topCategory.category) : nil
        let emotion: String? = confidence >= 0.65
            ? NarrativeCopyResolver.resolveEmotionTag(
                context: NarrativeCopyResolver.Context(
                    brandId: nil,
                    category: topCategory.category,
                    amount: input.amount,
                    date: input.referenceDate,
                    seed: topTitle ?? topCategory.category.rawValue,
                    note: topTitle ?? ""
                )
            )
            : nil

        return RecordPrefillResult(
            category: topCategory.category,
            title: topTitle,
            emotionTag: emotion,
            confidence: confidence,
            source: "habit"
        )
    }

    private func genericPrefill(
        input: RecordPrefillInput,
        historyItems: [HomeItem]
    ) -> RecordPrefillResult? {
        guard !input.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let result = genericCategoryService.recommend(
            input: CategoryRecommendInput(
                amount: input.amount,
                referenceDate: input.referenceDate,
                items: historyItems,
                noteDraft: input.noteDraft,
                locked: input.categoryLocked,
                context: input.context
            )
        )
        guard let result else { return nil }
        let title = historyItems.count >= coldStartThreshold
            ? supportedHabitTitle(
                for: result.recommended,
                input: input,
                historyItems: historyItems
            )
            : nil
        let emotion = title.map {
            NarrativeCopyResolver.resolveEmotionTag(
                context: NarrativeCopyResolver.Context(
                    brandId: nil,
                    category: result.recommended,
                    amount: input.amount,
                    date: input.referenceDate,
                    seed: $0,
                    note: $0
                )
            )
        }
        return RecordPrefillResult(
            category: result.recommended,
            title: title,
            emotionTag: emotion,
            confidence: title == nil ? 0.56 : 0.64,
            source: title == nil ? "generic" : "habit"
        )
    }

    private func supportedHabitTitle(
        for category: HomeItem.Category,
        input: RecordPrefillInput,
        historyItems: [HomeItem]
    ) -> String? {
        let sameContext = historyItems.filter { item in
            item.category == category
                && sameHabitContext(
                    item: item,
                    amount: input.amount,
                    referenceDate: input.referenceDate
                )
        }
        if sameContext.count >= 2,
           let title = mostCommonTitle(in: sameContext, category: category, minimumScore: 2) {
            return title
        }

        let sameTime = historyItems.filter { item in
            item.category == category
                && hourBucket(for: item.createdAt) == hourBucket(for: input.referenceDate)
                && isWeekend(item.createdAt) == isWeekend(input.referenceDate)
        }
        if sameTime.count >= 3,
           let title = mostCommonTitle(in: sameTime, category: category, minimumScore: 3) {
            return title
        }
        return nil
    }

    private func dominantSceneHabit(in items: [HomeItem]) -> SceneHabit? {
        guard items.count >= 3 else { return nil }
        let totalSupport = items.reduce(0.0) { $0 + sceneSupportWeight(for: $1) }
        let grouped = Dictionary(grouping: items) { item in
            LifeSceneSemanticService.classify(item).kind
        }
        let ranked = grouped.compactMap { _, rows -> SceneHabit? in
            guard let dominant = LifeSceneSemanticService.dominantScene(in: rows),
                  dominant.signal.confidenceTier >= .medium else {
                return nil
            }
            let support = rows.reduce(0.0) { $0 + sceneSupportWeight(for: $1) }
            let activeSupport = rows.reduce(0.0) { $0 + activeUserSupportWeight(for: $1) }
            return SceneHabit(
                signal: dominant.signal,
                items: rows,
                count: rows.count,
                confidence: support / max(totalSupport, 0.001),
                activeSupport: activeSupport
            )
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.confidence > rhs.confidence
            }
            return lhs.count > rhs.count
        }
        guard let top = ranked.first else { return nil }
        let secondCount = ranked.dropFirst().first?.count ?? 0
        let hasActiveConfirmation = top.activeSupport >= 1.5
        guard (top.count >= 3 || (top.count >= 2 && hasActiveConfirmation)),
              top.confidence >= 0.60,
              top.count >= secondCount + 1 else {
            return nil
        }
        return top
    }

    private func sceneHabitTitle(
        for habit: SceneHabit,
        amount: Double,
        date: Date
    ) -> String? {
        if let title = mostCommonTitle(in: habit.items, category: habit.signal.category) {
            return title
        }
        guard sceneHabitRecommendationTier(habit) == .strong else { return nil }
        return LifeSceneSemanticService.noteSuggestion(
            for: habit.signal,
            amount: amount,
            date: date
        )
    }

    private func sceneHabitRecommendationTier(_ habit: SceneHabit) -> LifeSceneConfidenceTier {
        guard habit.signal.confidenceTier >= .medium else { return .weak }
        if habit.signal.confidenceTier == .strong,
           habit.confidence >= 0.68 {
            return .strong
        }
        if habit.signal.confidenceTier == .strong,
           habit.activeSupport >= 1.5,
           habit.confidence >= 0.60 {
            return .strong
        }
        return .medium
    }

    private func sceneSupportWeight(for item: HomeItem) -> Double {
        var weight = 1.0
        if item.userEditedCategory == true { weight += 1.2 }
        if item.userEditedTitle == true { weight += 0.6 }
        return weight
    }

    private func activeUserSupportWeight(for item: HomeItem) -> Double {
        var weight = 0.0
        if item.userEditedCategory == true { weight += 1.2 }
        if item.userEditedTitle == true { weight += 0.6 }
        return weight
    }

    private func recentHistory(from items: [HomeItem]) -> [HomeItem] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -180, to: Date()) ?? .distantPast
        return items.filter { item in
            item.amount > 0 && item.createdAt >= start
        }
    }

    private func sameHabitContext(item: HomeItem, amount: Double, referenceDate: Date) -> Bool {
        hourBucket(for: item.createdAt) == hourBucket(for: referenceDate)
            && isWeekend(item.createdAt) == isWeekend(referenceDate)
            && sameAmountContext(historyAmount: item.amount, inputAmount: amount)
    }

    private func sameAmountContext(historyAmount: Double, inputAmount: Double) -> Bool {
        let historyCents = Int((historyAmount * 100).rounded())
        let inputCents = Int((inputAmount * 100).rounded())
        if historyCents == inputCents { return true }
        if max(historyAmount, inputAmount) <= 20 { return false }

        let lower = inputAmount * 0.8
        let upper = inputAmount * 1.2
        if historyAmount >= lower, historyAmount <= upper { return true }

        guard inputAmount > 20, historyAmount > 20 else { return false }
        return amountBand(for: historyAmount) == amountBand(for: inputAmount)
            && historyAmount >= inputAmount * 0.7
            && historyAmount <= inputAmount * 1.3
    }

    private func rankedCategories(in items: [HomeItem]) -> [(category: HomeItem.Category, count: Int)] {
        let grouped = Dictionary(grouping: items, by: \.category)
        return HomeItem.Category.allCases
            .map { category in (category: category, count: grouped[category]?.count ?? 0) }
            .filter { $0.count > 0 }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return categoryPriority(lhs.category) < categoryPriority(rhs.category)
                }
                return lhs.count > rhs.count
            }
    }

    private func habitConfidence(
        for top: (category: HomeItem.Category, count: Int),
        candidates: [HomeItem]
    ) -> Double {
        let ranked = rankedCategories(in: candidates)
        let secondCount = ranked.dropFirst().first?.count ?? 0
        let dominance = Double(top.count) / Double(max(top.count + secondCount, 1))
        let support = min(Double(top.count) / 8, 1)
        var confidence = dominance * 0.72 + support * 0.28
        if top.count < 3 || candidates.count < 4 {
            confidence = min(confidence, 0.54)
        }
        return min(max(confidence, 0), 1)
    }

    private func mostCommonTitle(
        in items: [HomeItem],
        category: HomeItem.Category,
        minimumScore: Int = 1
    ) -> String? {
        let counts = items
            .filter { $0.category == category }
            .reduce(into: [String: Int]()) { result, item in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard Self.isHabitTitle(title, category: category),
                      RecordSemanticLexicon.canReuseHabitTitle(
                        title,
                        category: category,
                        userEditedTitle: item.userEditedTitle == true
                      ) else {
                    return
                }
                result[title, default: 0] += item.userEditedTitle == true ? 2 : 1
            }
        let best = counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
        .first
        guard let best = best, best.value >= minimumScore else { return nil }
        return best.key
    }

    static func isHabitTitle(_ title: String, category: HomeItem.Category) -> Bool {
        guard (2...12).contains(title.count) else { return false }
        if title == category.defaultRecordTitle { return false }
        if RecordSemanticLexicon.isSystemGeneratedTitle(title) { return false }
        if title.hasSuffix("记录") || title.hasSuffix("消费") { return false }
        if isDirtyTraceTitle(title) { return false }
        if title.range(of: #"^-?\s*[¥￥]?\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    static func isDirtyTraceTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let month = String(UnicodeScalar(0x6708)!)
        let day = String(UnicodeScalar(0x65E5)!)
        let monthDayPattern = "^\\d{1,2}" + month + "\\d{1,2}" + day + "(?:\\s*\\d{1,2}:?\\d{0,2})?$"
        let noisyTimePatterns = [
            #"^\d{1,2}:\d{2}$"#,
            #"^\d{1,2}:\s*$"#,
            #"^\d{1,2}[-/]\d{1,2}(?:\s+\d{1,2}:?\d{0,2})?$"#,
            #"^\d{4}[-/]\d{1,2}[-/]\d{1,2}(?:\s+\d{1,2}:?\d{0,2})?$"#,
            monthDayPattern,
        ]
        return noisyTimePatterns.contains { trimmed.range(of: $0, options: .regularExpression) != nil }
    }

    private func hourBucket(for date: Date) -> Int {
        Calendar.current.component(.hour, from: date) / 3
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func amountBand(for amount: Double) -> Int {
        switch amount {
        case ...20: return 0
        case ...50: return 1
        case ...120: return 2
        case ...300: return 3
        case ...600: return 4
        default: return 5
        }
    }

    private func categoryPriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .dining: return 0
        case .transport: return 1
        case .shopping: return 2
        case .daily: return 3
        case .entertainment: return 4
        case .lodging: return 5
        case .health: return 6
        case .home: return 7
        case .social: return 8
        case .other: return 9
        }
    }
}
