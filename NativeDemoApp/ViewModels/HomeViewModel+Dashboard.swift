import Foundation

@MainActor
extension HomeViewModel {
    var hasMemberAccess: Bool {
        LocalStore.loadSettings().hasMemberAccess
    }

    var monthExpenseTotal: Double {
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        return monthItems.reduce(0) { $0 + $1.amount }
    }

    var todayExpenseTotal: Double {
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) && $0.amount > 0 }
        return todayItems.reduce(0) { $0 + $1.amount }
    }

    var todayHeroSubtitle: String {
        let todayItems = items.filter { Calendar.current.isDateInToday($0.createdAt) && $0.amount > 0 }
        let total = todayItems.reduce(0) { $0 + $1.amount }
        let topCategory = todayItems
            .reduce(into: [HomeItem.Category: Double]()) { result, item in
                result[item.category, default: 0] += item.amount
            }
            .max(by: { $0.value < $1.value })?.key.rawValue ?? "无"
        guard total > 0 else {
            return "今天还没记支出，先从一笔小额开始就很好。"
        }
        return "今天的记录里，「\(topCategory)」最常出现，日子又多了一点细节。"
    }

    var weekExpenseTotal: Double {
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        return weekItems.reduce(0) { $0 + $1.amount }
    }

    var todayStoryNarrative: TodayStoryNarrative {
        let records = todayItems
        let count = records.count
        let totalText = todayExpenseTotal.formatted(.cny)
        let weekText = weekExpenseTotal.formatted(.cny)
        let topCategory = topCategoryLabel(from: records)
        let todaySceneLine = lifeSceneMemoryLine(from: records, minimumCount: 2)

        let title: String
        let subtitle: String
        switch count {
        case 0:
            let emptyCopy = emptyTodayStoryCopy()
            title = emptyCopy.title
            subtitle = emptyCopy.subtitle
        case 1:
            title = "今天的第一笔记录"
            let emotion = records.first?.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            subtitle = "\(!emotion.isEmpty ? emotion : "这笔生活被记下来了")，这一天刚翻开第一页。"
        case 2:
            title = "今天已记下 2 笔"
            subtitle = todaySceneLine ?? "主要在「\(topCategory)」上，记录变得具体。"
        case 3:
            title = "今天记下了 3 笔"
            subtitle = todaySceneLine ?? "合计 \(totalText)，今天的记录已经成形。"
        default:
            title = "今天记下了 \(count) 笔"
            subtitle = todaySceneLine ?? "「\(topCategory)」居多，今天的记录已经清楚。"
        }

        return TodayStoryNarrative(
            title: title,
            subtitle: subtitle,
            todayTotalText: count == 0 ? "今日还没记录" : "今日合计 \(totalText)",
            weekTotalText: "本周累计 \(weekText)"
        )
    }

    private func emptyTodayStoryCopy(now: Date = Date()) -> (title: String, subtitle: String) {
        if let suggestion = frequentRecordAmountSuggestions(at: now).first {
            return (
                "今天可能从这一笔开始",
                "这个时间你常记 \(shortAmountText(suggestion.amount)) · \(suggestion.category.label)，不确定也可以只输金额。"
            )
        }

        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            return (
                "今天也先留一笔",
                "这周「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」出现得多，今天想到哪笔就先放进来。"
            )
        }

        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<10:
            return ("早上先留个开头", "早餐、通勤、路上的小花费，有一笔就先记一笔。")
        case 10..<14:
            return ("午间先记一下", "饭点和路上的小支出最容易忘，先放一笔也好。")
        case 17..<21:
            return ("晚上回头补一笔", "晚饭、回家路上、临时买的东西，都可以先记下来。")
        case 21...23, 0..<5:
            return ("今天还有哪笔没放进来？", "睡前补一笔，明天再看今天会清楚一点。")
        default:
            return ("今天先记下来", "不用整理得很完整，有一笔就先放进账本。")
        }
    }

    var monthTopCategoryText: String {
        topCategoryLabel(in: .month)
    }

    var weekTopCategoryText: String {
        topCategoryLabel(in: .week)
    }

    var weekLifeThemeText: String {
        lifeSceneMemoryLine(from: filteredItems(in: .week), minimumCount: 2) ?? ""
    }

    var quickRecordNudgeText: String {
        if todayItems.isEmpty {
            if let suggestion = frequentRecordAmountSuggestions(at: Date()).first {
                return "常记 \(shortAmountText(suggestion.amount)) · \(suggestion.category.label)"
            }
            if let scene = LifeSceneSemanticService.dominantScene(in: filteredItems(in: .week).filter({ $0.amount > 0 })),
               scene.count >= 2 {
                return "接着留下「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」"
            }
            return "只输金额也可以"
        }
        if let scene = LifeSceneSemanticService.dominantScene(in: todayItems),
           scene.count >= 2 {
            return "今天已有 \(todayItems.count) 笔 · \(LifeSceneSemanticService.displayTheme(for: scene.signal))"
        }
        return "今天已记 \(todayItems.count) 笔"
    }

    /// 近 7 日内生成的复盘记录（按时间新到旧）。
    var insightsLast7Days: [DailyInsight] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return insights
            .filter { $0.createdAt >= start }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 本地 7 天聚合复盘（与 web rangeInsightPayload(7) 对齐：一条总结而非逐日）。
    func localWeeklyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else {
            return ("近 7 天暂无复盘。", "", "")
        }
        let weekItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return ("近 7 天暂无复盘。多记几笔，就能看到更完整的消费节奏啦。", "", "")
        }
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            let copy = LifeSceneSemanticService.weeklyCopy(for: scene.signal, count: scene.count)
            let summary = LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
            let structure = "这一周更明显的是「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」这条线。"
            let advice = weekItems.count >= 8
                ? "继续按笔记下去，下周回放会更贴近真实记录。"
                : copy.cares.dropFirst().first ?? "再多记几笔，这一周会更容易回头看。"
            return (summary, structure, advice)
        }

        let topCategory = topCategoryLabel(from: weekItems)
        let summary = "近 7 天里，「\(topCategory)」这类记录多一些。"
        let structure = "这一周的记录已经分出几段。"
        let advice = weekItems.count >= 8
            ? "继续按笔记下去，下周回放会更贴近真实记录。"
            : "再多记几笔，这一周会更容易回头看。"
        return (summary, structure, advice)
    }

    /// 本地月度小结文案（与 web 预览结构对齐：摘要 / 结构 / 建议）。
    func localMonthlyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let total = monthExpenseTotal
        let top = monthTopCategoryText
        let summary: String
        if total <= 0 {
            summary = "本月还没有足够账单，多记几笔再来生成月度复盘吧。"
        } else if let scene = LifeSceneSemanticService.dominantScene(in: filteredItems(in: .month).filter { $0.amount > 0 }),
                  scene.count >= 2 {
            summary = LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
        } else {
            summary = "这个月的记录里，「\(top)」出现得比较多。"
        }
        let structure = total <= 0
            ? "等本月多几笔记录，再整理这段时间的变化。"
            : monthlyStructureText(fallbackTop: top)
        let advice = total <= 0
            ? "先记下一周，复盘会更有内容。"
            : "这个月已经有一些记录，继续记几天，月记会更完整。"
        return (summary, structure, advice)
    }

    private func topCategoryLabel(in period: Period) -> String {
        let target = filteredItems(in: period)
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { $0.value.count < $1.value.count })?.key else {
            return "暂无"
        }
        return top.rawValue
    }

    private func topCategoryLabel(from target: [HomeItem]) -> String {
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { lhs, rhs in
            let left = lhs.value.reduce(0) { $0 + $1.amount }
            let right = rhs.value.reduce(0) { $0 + $1.amount }
            return left < right
        })?.key else {
            return "生活"
        }
        return top.label
    }

    func lifeSceneMemoryLine(from target: [HomeItem], minimumCount: Int) -> String? {
        let positive = target.filter { $0.amount > 0 }
        guard let scene = LifeSceneSemanticService.dominantScene(in: positive),
              scene.count >= minimumCount else {
            return nil
        }
        return LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
    }

    private func monthlyStructureText(fallbackTop: String) -> String {
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        if let scene = LifeSceneSemanticService.dominantScene(in: monthItems),
           scene.count >= 2 {
            return "这个月更明显的是「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」这条线。"
        }
        return "「\(fallbackTop)」是这个月比较明显的一类。"
    }
}
