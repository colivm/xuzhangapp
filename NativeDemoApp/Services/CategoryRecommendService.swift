import Foundation

struct CategoryRecommendInput {
    let amount: Double
    let referenceDate: Date
    let items: [HomeItem]
    let noteDraft: String
    let locked: Bool
}

struct CategoryRecommendResult: Equatable {
    let recommended: HomeItem.Category
    let reasonTag: String?
}

struct CategoryRecommendService {
    private struct ScoreBreakdown {
        var history: Double = 0
        var time: Double = 0
        var amount: Double = 0
        var note: Double = 0

        var total: Double {
            history * 0.40 + time * 0.35 + amount * 0.15 + note * 0.10
        }
    }

    func recommend(input: CategoryRecommendInput) -> CategoryRecommendResult? {
        guard !input.locked, input.amount > 0 else { return nil }

        var scores = Dictionary(
            uniqueKeysWithValues: HomeItem.Category.allCases.map { ($0, ScoreBreakdown()) }
        )
        applyHistoryScores(input: input, scores: &scores)
        applyTimeScores(input: input, scores: &scores)
        applyAmountScores(amount: input.amount, scores: &scores)
        applyNoteScores(note: input.noteDraft, scores: &scores)

        let ranked = HomeItem.Category.allCases
            .map { category in (category, breakdown: scores[category] ?? ScoreBreakdown()) }
            .sorted { lhs, rhs in
                if lhs.breakdown.total == rhs.breakdown.total {
                    return categoryPriority(lhs.category) < categoryPriority(rhs.category)
                }
                return lhs.breakdown.total > rhs.breakdown.total
            }

        guard let best = ranked.first else { return nil }
        return CategoryRecommendResult(
            recommended: best.category,
            reasonTag: dominantReason(for: best.breakdown)
        )
    }

    private func applyHistoryScores(
        input: CategoryRecommendInput,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let historyItems = input.items.filter { $0.amount > 0 }
        guard !historyItems.isEmpty else { return }

        let totalCount = Double(historyItems.count)
        let grouped = Dictionary(grouping: historyItems, by: \.category)
        for category in HomeItem.Category.allCases {
            let ratio = Double(grouped[category]?.count ?? 0) / totalCount
            addHistory(ratio * 4, to: category, scores: &scores)
        }

        let low = input.amount * 0.7
        let high = input.amount * 1.3
        let sameBand = historyItems.filter { $0.amount >= low && $0.amount <= high }
        if let top = mostFrequentCategory(in: sameBand) {
            addHistory(1.5, to: top, scores: &scores)
        } else if let top = mostFrequentCategory(in: historyItems) {
            addHistory(0.6, to: top, scores: &scores)
        }
    }

    private func applyTimeScores(
        input: CategoryRecommendInput,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: input.referenceDate)
        let weekday = calendar.component(.weekday, from: input.referenceDate)
        let isWeekend = weekday == 1 || weekday == 7

        if !isWeekend, (7..<10).contains(hour) {
            addTime(input.amount <= 30 ? 3.4 : 3, to: .transport, scores: &scores)
            addTime(1, to: .dining, scores: &scores)
        }
        if (11..<14).contains(hour) {
            addTime(3, to: .dining, scores: &scores)
        }
        if (17..<20).contains(hour) {
            addTime(2, to: .dining, scores: &scores)
            addTime(1, to: .transport, scores: &scores)
        }
        if hour >= 22 || hour < 6 {
            addTime(2, to: .dining, scores: &scores)
            addTime(1, to: .entertainment, scores: &scores)
        }
        if isWeekend, (14..<22).contains(hour) {
            addTime(2, to: .entertainment, scores: &scores)
            addTime(1, to: .shopping, scores: &scores)
        }
    }

    private func applyAmountScores(
        amount: Double,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        switch amount {
        case ...20.0:
            addAmount(1, to: .dining, scores: &scores)
            addAmount(1, to: .transport, scores: &scores)
        case 21.0...50.0:
            addAmount(1, to: .dining, scores: &scores)
            addAmount(1, to: .transport, scores: &scores)
        case 51.0...200.0:
            addAmount(1, to: .daily, scores: &scores)
            addAmount(1, to: .shopping, scores: &scores)
        default:
            addAmount(1, to: .shopping, scores: &scores)
            addAmount(1, to: .other, scores: &scores)
        }
    }

    private func applyNoteScores(
        note: String,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        let normalized = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }

        let rules: [(HomeItem.Category, Double, [String])] = [
            (.transport, 4, ["地铁", "公交", "打车", "停车", "加油", "出租", "网约车", "高铁", "机票"]),
            (.dining, 4, ["咖啡", "奶茶", "午餐", "晚餐", "外卖", "早餐", "餐", "饭", "面包"]),
            (.daily, 3, ["超市", "买菜", "日用品", "日化", "药店", "纸巾", "洗衣"]),
            (.entertainment, 3, ["电影", "游戏", "ktv", "KTV", "演唱会", "剧本杀"]),
            (.lodging, 4, ["酒店", "民宿", "住宿", "宾馆", "旅店"]),
        ]

        for (category, score, keywords) in rules {
            if keywords.contains(where: { normalized.contains($0.lowercased()) }) {
                addNote(score, to: category, scores: &scores)
            }
        }
    }

    private func addHistory(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.history += value
        scores[category] = score
    }

    private func addTime(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.time += value
        scores[category] = score
    }

    private func addAmount(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.amount += value
        scores[category] = score
    }

    private func addNote(
        _ value: Double,
        to category: HomeItem.Category,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        var score = scores[category] ?? ScoreBreakdown()
        score.note += value
        scores[category] = score
    }

    private func mostFrequentCategory(in items: [HomeItem]) -> HomeItem.Category? {
        let grouped = Dictionary(grouping: items, by: \.category)
        return HomeItem.Category.allCases
            .map { category in (category, count: grouped[category]?.count ?? 0) }
            .filter { $0.count > 0 }
            .sorted {
                if $0.count == $1.count {
                    return categoryPriority($0.category) < categoryPriority($1.category)
                }
                return $0.count > $1.count
            }
            .first?.category
    }

    private func dominantReason(for breakdown: ScoreBreakdown) -> String? {
        let parts = [
            ("history", breakdown.history * 0.40),
            ("time", breakdown.time * 0.35),
            ("amount", breakdown.amount * 0.15),
            ("note", breakdown.note * 0.10),
        ]
        return parts.max(by: { $0.1 < $1.1 })?.0
    }

    private func categoryPriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .dining: return 0
        case .transport: return 1
        case .daily: return 2
        case .shopping: return 3
        case .entertainment: return 4
        case .lodging: return 5
        case .other: return 6
        }
    }
}
