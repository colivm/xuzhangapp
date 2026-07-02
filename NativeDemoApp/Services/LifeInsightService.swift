import Foundation

struct LifeInsightResult {
    let leadQuestion: String
    let teaser: String
    let previewLine: String
    let fullLines: [String]
    let questionChips: [String]
    let periodName: String
}

final class LifeInsightService {
    static let shared = LifeInsightService()

    static let freeMonthlyLimit = 5

    private enum Keys {
        static let freeMonthKey = "life_insight_free_month_key"
        static let freeMonthUsedCount = "life_insight_free_month_used_count"
        static let unlockedTraceKeys = "life_insight_unlocked_trace_keys"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func freeRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncMonthIfNeeded(now: now)
        return max(0, Self.freeMonthlyLimit - defaults.integer(forKey: Keys.freeMonthUsedCount))
    }

    func canUseDeepInsight(isMember: Bool, now: Date = Date()) -> Bool {
        freeRemaining(isMember: isMember, now: now) > 0
    }

    func markDeepInsightUsed(isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncMonthIfNeeded(now: now)
        let used = defaults.integer(forKey: Keys.freeMonthUsedCount)
        defaults.set(min(Self.freeMonthlyLimit, used + 1), forKey: Keys.freeMonthUsedCount)
    }

    func hasUnlockedTrace(_ key: String, isMember: Bool, now: Date = Date()) -> Bool {
        guard !isMember else { return true }
        syncMonthIfNeeded(now: now)
        return unlockedTraceKeys().contains(key)
    }

    func markTraceUnlocked(_ key: String, isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncMonthIfNeeded(now: now)
        var keys = unlockedTraceKeys()
        keys.insert(key)
        defaults.set(Array(keys), forKey: Keys.unlockedTraceKeys)
    }

    func buildTraceInsight(items: [HomeItem], periodLabel: String, now: Date = Date()) -> LifeInsightResult {
        let validItems = items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt < $1.createdAt }

        guard !validItems.isEmpty else {
            return LifeInsightResult(
                leadQuestion: "先从几笔记录看起",
                teaser: "不用急着总结。等这里多几笔，我会把日期、场景和你写下的备注放在一起看。",
                previewLine: "先记下来就好。等同类记录多一些，再看日期和备注会更清楚。",
                fullLines: [
                    "现在还不急着解释，先把生活放进账本。",
                    "等记录多一点，我会看它们出现在哪些日子，而不是只盯着金额。",
                    "如果同类事情反复出现，这里会把它们串成一段能回看的生活。"
                ],
                questionChips: ["哪天最特别？", "什么事出现了好几次？", "给这段时间起个名字"],
                periodName: "\(periodLabel)的线索还在形成"
            )
        }

        let categories = categoryStats(from: validItems)
        let top = categories.first
        let second = categories.dropFirst().first
        let peak = peakDay(from: validItems)
        let activeDays = Set(validItems.map { calendar.startOfDay(for: $0.createdAt) }).count
        let total = validItems.reduce(0) { $0 + $1.amount }
        let average = total / Double(validItems.count)

        let primaryFocusName = top.map { focusName(for: $0.category, items: validItems) } ?? "这段记录"
        let leadQuestion = "「\(primaryFocusName)」为什么在这段时间变明显？"

        let teaser: String
        if let top {
            let secondName = second.map { focusName(for: $0.category, items: validItems) }
            if let peak, let secondName {
                teaser = "\(primaryFocusName)在\(peak.label)最集中，旁边还跟着「\(secondName)」。这不像一笔孤立消费，更像那几天生活在同一个节奏里。"
            } else if let peak {
                teaser = "\(primaryFocusName)在\(peak.label)最明显。回头看那天，可能比只看金额更接近真实原因。"
            } else {
                teaser = "\(primaryFocusName)已经不止出现一次，它可能是这段时间反复发生的一件事。"
            }
        } else {
            teaser = "这段记录还比较散。先看哪天最集中、哪类最常出现。"
        }

        var fullLines: [String] = []
        if let top {
            let name = focusName(for: top.category, items: validItems)
            fullLines.append(deeperReasonLine(for: top.category, name: name))
        }
        if let peak {
            fullLines.append("\(peak.label)记录最集中。可以先回想那天去了哪里、见了谁，或者临时补了什么。")
        }
        if let second, let top, second.count > 0 {
            let topName = focusName(for: top.category, items: validItems)
            let secondName = focusName(for: second.category, items: validItems)
            fullLines.append("「\(topName)」和「\(secondName)」一起靠前，可能是同一段生活带出来的两种开销。")
        } else {
            fullLines.append("平均每笔约 \(average.formatted(.cny))。可以先看它们集中在哪些日期。")
        }
        if activeDays >= 3 {
            fullLines.append("\(activeDays) 天都有记录，这段时间已经不是零散一两笔，而是有了可以回看的连续感。")
        }

        return LifeInsightResult(
            leadQuestion: leadQuestion,
            teaser: teaser,
            previewLine: fullLines.first ?? teaser,
            fullLines: Array(fullLines.prefix(3)),
            questionChips: questionChips(
                top: top?.category,
                second: second?.category,
                peakLabel: peak?.label,
                items: validItems
            ),
            periodName: periodName(top: top?.category, peakLabel: peak?.label, periodLabel: periodLabel)
        )
    }

    private func syncMonthIfNeeded(now: Date) {
        let key = monthKey(now: now)
        if defaults.string(forKey: Keys.freeMonthKey) != key {
            defaults.set(key, forKey: Keys.freeMonthKey)
            defaults.set(0, forKey: Keys.freeMonthUsedCount)
            defaults.set([], forKey: Keys.unlockedTraceKeys)
        }
    }

    private func unlockedTraceKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Keys.unlockedTraceKeys) ?? [])
    }

    private func monthKey(now: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: now)
        return "\(comps.year ?? 0)-\(String(format: "%02d", comps.month ?? 0))"
    }

    private func categoryStats(from items: [HomeItem]) -> [(category: HomeItem.Category, count: Int, total: Double)] {
        Dictionary(grouping: items, by: \.category)
            .map { category, grouped in
                (category: category, count: grouped.count, total: grouped.reduce(0) { $0 + $1.amount })
            }
            .sorted {
                if $0.count == $1.count { return $0.total > $1.total }
                return $0.count > $1.count
            }
    }

    private func peakDay(from items: [HomeItem]) -> (label: String, count: Int)? {
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        guard let entry = grouped.max(by: { $0.value.count < $1.value.count }) else { return nil }
        let label = calendarDayLabel(for: entry.key)
        return (label, entry.value.count)
    }

    private func calendarDayLabel(for date: Date) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日（\(weekdayLabel(for: date))）"
    }

    private func weekdayLabel(for date: Date) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        default: return "周六"
        }
    }

    private func questionChips(
        top: HomeItem.Category?,
        second: HomeItem.Category?,
        peakLabel: String?,
        items: [HomeItem]
    ) -> [String] {
        let primary = top.map { "\(focusName(for: $0, items: items))为什么变明显？" }
            ?? "哪类记录最明显？"
        let rhythm = peakLabel.map { "\($0)发生了什么？" }
            ?? "哪天最特别？"
        let relation: String
        if let top, let second {
            relation = "\(focusName(for: top, items: items))和\(focusName(for: second, items: items))同天出现了吗？"
        } else {
            relation = "什么事出现了好几次？"
        }
        return [primary, rhythm, relation]
    }

    private func periodName(top: HomeItem.Category?, peakLabel: String?, periodLabel: String) -> String {
        if let top, let peakLabel {
            return "\(top.rawValue)和\(peakLabel)撑起来的\(periodLabel)"
        }
        if let top {
            return "\(top.rawValue)更明显的\(periodLabel)"
        }
        return "记录逐步变多的\(periodLabel)"
    }

    private func focusName(for category: HomeItem.Category, items: [HomeItem]) -> String {
        let categoryItems = items.filter { $0.category == category }
        let joined = categoryItems.map { "\($0.title) \($0.emotionTag)" }.joined(separator: " ")
        switch category {
        case .transport:
            return containsAny(joined, ["通勤", "上班", "下班", "地铁", "公交"]) ? "通勤交通" : "交通"
        case .health:
            return containsAny(joined, ["健身", "运动", "跑步", "瑜伽", "私教", "游泳", "理疗", "恢复"]) ? "健身恢复" : "看病买药"
        case .dining:
            return containsAny(joined, ["咖啡", "奶茶"]) ? "饭点饮品" : "饭点外卖"
        case .shopping:
            return containsAny(joined, ["渔具", "鱼竿", "路亚", "露营", "骑行", "摄影", "相机", "镜头", "模型", "手办", "乐器", "茶具", "咖啡器具"]) ? "兴趣装备" : "网购添置"
        case .daily:
            return containsAny(joined, ["买菜", "生鲜", "盒马", "叮咚", "小象", "京东到家", "朴朴"]) ? "超市买菜" : "家用补货"
        default:
            return category.rawValue
        }
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func deeperReasonLine(for category: HomeItem.Category, name: String) -> String {
        switch category {
        case .dining:
            return "「\(name)」变多，常常说明这段时间的日子被饭点、外卖、咖啡这些小节点撑着走。"
        case .transport:
            return "「\(name)」变多，通常来自通勤、办事、见人或往返记录。"
        case .health:
            return "「\(name)」变多，主要来自训练、恢复、看诊或身体相关记录。"
        case .shopping, .daily:
            return "「\(name)」变多，主要来自买菜、家用、网购或兴趣装备。"
        case .entertainment:
            return "「\(name)」变多，娱乐相关记录在这段时间更多。"
        case .home:
            return "「\(name)」变多，主要来自住处、修补、布置或家用安排。"
        case .social:
            return "「\(name)」变多，主要来自见面、送礼或人情往来。"
        case .lodging:
            return "「\(name)」通常意味着位置变了。这段时间可能有旅行、出差，或者一段临时停留。"
        case .other:
            return "这些记录还没归进固定分类，但它们反复出现，可以回头看备注。"
        }
    }
}
