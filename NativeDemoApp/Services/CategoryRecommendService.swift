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
            history * 0.10 + time * 0.20 + amount * 0.45 + note * 0.35
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
            .map { category -> (category: HomeItem.Category, breakdown: ScoreBreakdown, total: Double) in
                let breakdown = scores[category] ?? ScoreBreakdown()
                return (category, breakdown, breakdown.total)
            }
            .sorted { lhs, rhs in
                if lhs.total == rhs.total {
                    return categoryPriority(lhs.category) < categoryPriority(rhs.category)
                }
                return lhs.total > rhs.total
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
        let confidence = min(totalCount / 20, 1)
        let grouped = Dictionary(grouping: historyItems, by: \.category)
        for category in HomeItem.Category.allCases {
            let ratio = Double(grouped[category]?.count ?? 0) / totalCount
            addHistory(ratio * confidence, to: category, scores: &scores)
        }

        let low = input.amount * 0.7
        let high = input.amount * 1.3
        let sameBand = historyItems.filter { $0.amount >= low && $0.amount <= high }
        if sameBand.count >= 4, let top = mostFrequentCategory(in: sameBand) {
            addHistory(0.8, to: top, scores: &scores)
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
            addTime(input.amount <= 35 ? 0.8 : 0.2, to: .dining, scores: &scores)
        }
        if (11..<14).contains(hour) {
            addTime(input.amount <= 80 ? 3 : 0.6, to: .dining, scores: &scores)
        }
        if (17..<20).contains(hour) {
            addTime(input.amount <= 120 ? 2 : 0.5, to: .dining, scores: &scores)
            addTime(1, to: .transport, scores: &scores)
        }
        if hour >= 22 || hour < 6 {
            addTime(input.amount <= 100 ? 2 : 0.5, to: .dining, scores: &scores)
            addTime(1, to: .entertainment, scores: &scores)
        }
        if isWeekend, (14..<22).contains(hour) {
            addTime(2, to: .entertainment, scores: &scores)
            addTime(1, to: .shopping, scores: &scores)
            addTime(0.8, to: .social, scores: &scores)
            addTime(0.6, to: .home, scores: &scores)
        }
    }

    private func applyAmountScores(
        amount: Double,
        scores: inout [HomeItem.Category: ScoreBreakdown]
    ) {
        switch amount {
        case ...20.0:
            addAmount(2.0, to: .transport, scores: &scores)
            addAmount(1.8, to: .dining, scores: &scores)
            addAmount(1.4, to: .daily, scores: &scores)
        case 21.0...50.0:
            addAmount(2.0, to: .shopping, scores: &scores)
            addAmount(1.9, to: .daily, scores: &scores)
            addAmount(1.8, to: .dining, scores: &scores)
            addAmount(1.5, to: .transport, scores: &scores)
        case 51.0...200.0:
            addAmount(3.0, to: .shopping, scores: &scores)
            addAmount(2.6, to: .daily, scores: &scores)
            addAmount(2.2, to: .health, scores: &scores)
            addAmount(1.8, to: .social, scores: &scores)
            addAmount(1.2, to: .home, scores: &scores)
        case 201.0...800.0:
            addAmount(3.0, to: .shopping, scores: &scores)
            addAmount(2.6, to: .home, scores: &scores)
            addAmount(2.2, to: .health, scores: &scores)
            addAmount(2.0, to: .social, scores: &scores)
            addAmount(1.0, to: .lodging, scores: &scores)
        default:
            addAmount(3.0, to: .home, scores: &scores)
            addAmount(2.5, to: .lodging, scores: &scores)
            addAmount(2.2, to: .shopping, scores: &scores)
            addAmount(2.0, to: .other, scores: &scores)
            addAmount(1.8, to: .social, scores: &scores)
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
            (.dining, 4, ["咖啡", "奶茶", "午餐", "晚餐", "夜宵", "宵夜", "外卖", "早餐", "餐", "饭", "面包"]),
            (.shopping, 4.5, ["淘宝", "京东", "拼多多", "商城", "购物", "下单", "快递", "衣服", "鞋", "包", "化妆品", "护肤", "数码", "耳机", "手机", "电脑", "家居", "买了", "购入", "添置"]),
            (.daily, 3, ["超市", "买菜", "日用品", "日化", "纸巾", "洗衣"]),
            (.entertainment, 3, ["电影", "游戏", "ktv", "KTV", "演唱会", "剧本杀"]),
            (.lodging, 4, ["酒店", "民宿", "住宿", "宾馆", "旅店"]),
            (.health, 4, ["药店", "买药", "医院", "挂号", "问诊", "体检", "牙科", "口腔", "诊所", "疫苗", "医保", "康复"]),
            (.home, 4, ["房租", "水电", "电费", "燃气", "物业", "宽带", "家电", "家具", "维修", "家政", "搬家", "保洁"]),
            (.social, 4, ["红包", "礼物", "送礼", "请客", "份子钱", "随礼", "家人", "父母", "生日礼物", "聚会"]),
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
        let counts = HomeItem.Category.allCases
            .map { category -> (category: HomeItem.Category, count: Int, priority: Int) in
                (
                    category: category,
                    count: grouped[category]?.count ?? 0,
                    priority: categoryPriority(category)
                )
            }
            .filter { entry in entry.count > 0 }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.priority < rhs.priority
                }
                return lhs.count > rhs.count
            }

        return counts.first?.category
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
