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

    static let freeWeeklyLimit = 1

    private enum Keys {
        static let freeWeekKey = "life_insight_free_week_key"
        static let freeWeekUsedCount = "life_insight_free_week_used_count"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func freeRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncWeekIfNeeded(now: now)
        return max(0, Self.freeWeeklyLimit - defaults.integer(forKey: Keys.freeWeekUsedCount))
    }

    func canUseDeepInsight(isMember: Bool, now: Date = Date()) -> Bool {
        freeRemaining(isMember: isMember, now: now) > 0
    }

    func markDeepInsightUsed(isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncWeekIfNeeded(now: now)
        let used = defaults.integer(forKey: Keys.freeWeekUsedCount)
        defaults.set(min(Self.freeWeeklyLimit, used + 1), forKey: Keys.freeWeekUsedCount)
    }

    func buildTraceInsight(items: [HomeItem], periodLabel: String, now: Date = Date()) -> LifeInsightResult {
        let validItems = items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt < $1.createdAt }

        guard !validItems.isEmpty else {
            return LifeInsightResult(
                leadQuestion: "这段账本还在等线索",
                teaser: "先留下几笔，账本会从分类、时间和频次里慢慢多看一层。",
                previewLine: "我会先看哪类反复出现、哪天更密、哪些记录像正在形成的习惯。",
                fullLines: [
                    "现在还不急着解释，先把几笔生活放进账本。",
                    "等记录多一点，我会优先看频次和时间，而不是只盯着金额。",
                    "线索会从分类、日期和重复出现的备注里自然浮出来。"
                ],
                questionChips: ["哪天最不像平时？", "哪些是重复习惯？", "给这段时间起个名字"],
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

        let focusName = top.map { focusName(for: $0.category, items: validItems) } ?? "这段记录"
        let leadQuestion = "要不要顺着「\(focusName)」往下看一层？"

        let teaser: String
        if let top {
            let secondName = second.map { focusName(for: $0.category, items: validItems) }
            if let peak, let secondName {
                teaser = "我会继续看它集中在哪些日子、和「\(secondName)」有没有一起出现，以及它像不像这段时间正在形成的生活节奏。"
            } else if let peak {
                teaser = "我会继续看它为什么在\(peak.label)更密，以及这是不是一段固定生活节奏。"
            } else {
                teaser = "我会继续看它是偶然出现，还是正在变成这一段生活里反复发生的事。"
            }
        } else {
            teaser = "这段记录比较分散，账本会先从日期和频次里找一个值得追问的点。"
        }

        var fullLines: [String] = []
        if let top {
            let name = focusName(for: top.category, items: validItems)
            fullLines.append(deeperReasonLine(for: top.category, name: name))
        }
        if let peak {
            fullLines.append("\(peak.label)是密度最高的节点，适合回头看那天是不是有行程、外出或补给集中在一起。")
        }
        if let second, let top, second.count > 0 {
            let topName = focusName(for: top.category, items: validItems)
            let secondName = focusName(for: second.category, items: validItems)
            fullLines.append("「\(topName)」和「\(secondName)」同时靠前，可以追问它们是不是被同一个生活场景带出来。")
        } else {
            fullLines.append("平均每笔约 \(average.formatted(.cny))，金额只是证据，真正值得看的是它们出现的时间和频次。")
        }
        if activeDays >= 3 {
            fullLines.append("\(activeDays) 天都有记录，这段账本已经能看出一点生活连续性。")
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

    private func syncWeekIfNeeded(now: Date) {
        let key = weekKey(now: now)
        if defaults.string(forKey: Keys.freeWeekKey) != key {
            defaults.set(key, forKey: Keys.freeWeekKey)
            defaults.set(0, forKey: Keys.freeWeekUsedCount)
        }
    }

    private func weekKey(now: Date) -> String {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        let comps = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", comps.weekOfYear ?? 0))"
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
        let label = weekdayLabel(for: entry.key)
        return (label, entry.value.count)
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
            ?? "哪类记录最值得看？"
        let rhythm = peakLabel.map { "\($0)发生了什么？" }
            ?? "哪天最不像平时？"
        let relation: String
        if let top, let second {
            relation = "\(focusName(for: top, items: items))和\(focusName(for: second, items: items))有关吗？"
        } else {
            relation = "哪些是重复习惯？"
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
        return "慢慢浮出线索的\(periodLabel)"
    }

    private func focusName(for category: HomeItem.Category, items: [HomeItem]) -> String {
        let categoryItems = items.filter { $0.category == category }
        let joined = categoryItems.map { "\($0.title) \($0.emotionTag)" }.joined(separator: " ")
        switch category {
        case .transport:
            return containsAny(joined, ["通勤", "上班", "下班", "地铁", "公交"]) ? "通勤交通" : "交通"
        case .health:
            return containsAny(joined, ["健身", "运动", "跑步", "瑜伽", "私教", "游泳"]) ? "运动健身" : "健康"
        case .dining:
            return containsAny(joined, ["咖啡", "奶茶"]) ? "饮品餐饮" : "餐饮"
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
            return "「\(name)」更像这段时间的日程底色：忙的时候靠它续上，松一点的时候也会用它安顿自己。"
        case .transport:
            return "「\(name)」背后通常是移动变多了，账本记录下来的其实是你被生活带去的路线。"
        case .health:
            return "「\(name)」说明身体重新进入日程，不管是训练、恢复还是照顾自己，都值得被单独看见。"
        case .shopping, .daily:
            return "「\(name)」像一轮生活补给，很多小东西一起出现，往往说明这段时间在重新整理秩序。"
        case .entertainment:
            return "「\(name)」不是简单花钱玩，它可能是在给紧绷的日子留一点出口。"
        case .home:
            return "「\(name)」说明注意力回到住处和日常环境，生活在悄悄往稳定处收。"
        case .social:
            return "「\(name)」背后是关系在发生，金额只是痕迹，真正留下来的是见面和往来。"
        case .lodging:
            return "「\(name)」通常意味着位置变化，这段时间可能有旅行、出差或临时停留。"
        case .other:
            return "这些记录还没归进固定分类，但反复出现本身已经说明它们有一个共同主题。"
        }
    }
}
