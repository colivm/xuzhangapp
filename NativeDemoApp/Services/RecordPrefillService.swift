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
    private let coldStartThreshold = 15
    private let genericCategoryService = CategoryRecommendService()

    func prefill(input: RecordPrefillInput) -> RecordPrefillResult? {
        guard input.amount > 0 else { return nil }

        if let brand = MerchantBrandCatalog.definition(for: input.merchantBrandId) {
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
                    seed: title
                )
            )
            return RecordPrefillResult(
                category: nil,
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
                    seed: topTitle ?? topCategory.category.rawValue
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
        return RecordPrefillResult(
            category: result.recommended,
            title: nil,
            emotionTag: nil,
            confidence: 0.56,
            source: "generic"
        )
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
        amountBand(for: historyAmount) == amountBand(for: inputAmount)
            || (historyAmount >= inputAmount * 0.7 && historyAmount <= inputAmount * 1.3)
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

    private func mostCommonTitle(in items: [HomeItem], category: HomeItem.Category) -> String? {
        let counts = items
            .filter { $0.category == category }
            .map(\.title)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isHabitTitle($0, category: category) }
            .reduce(into: [String: Int]()) { result, title in
                result[title, default: 0] += 1
            }
        return counts.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key < rhs.key
            }
            return lhs.value > rhs.value
        }
        .first?.key
    }

    private func isHabitTitle(_ title: String, category: HomeItem.Category) -> Bool {
        guard (2...12).contains(title.count) else { return false }
        if title == category.defaultRecordTitle { return false }
        if title.hasSuffix("记录") || title.hasSuffix("消费") { return false }
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
        if noisyTimePatterns.contains(where: { title.range(of: $0, options: .regularExpression) != nil }) {
            return false
        }
        if title.range(of: #"^-?\s*[¥￥]?\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#, options: .regularExpression) != nil {
            return false
        }
        return true
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
