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

        let topText = top.map { "\($0.category.rawValue)出现 \($0.count) 笔" } ?? "记录比较分散"
        let leadQuestion = "这段时间，\(topText)，要不要看看它说明了什么？"

        let teaser: String
        if let top {
            teaser = "\(top.category.rawValue)是最清楚的线索，账本还能继续看：它是偶然出现，还是正在变成这一段生活的固定节奏。"
        } else {
            teaser = "这段记录比较分散，账本会先从日期和频次里找一个值得追问的点。"
        }

        var fullLines: [String] = []
        if let top {
            let ratio = Int((Double(top.count) / Double(validItems.count) * 100).rounded())
            fullLines.append("\(top.category.rawValue)占了 \(ratio)%，更像这段时间最稳定出现的生活面。")
        }
        if let peak {
            fullLines.append("\(peak.label)留下 \(peak.count) 笔，是这段时间最密的一天，可以回头看看那天发生了什么。")
        }
        if let second, let top, second.count > 0 {
            fullLines.append("\(top.category.rawValue)和\(second.category.rawValue)一起出现，说明这段生活不是单一开销，而是几条节奏叠在一起。")
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
            questionChips: questionChips(for: top?.category, peakLabel: peak?.label),
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

    private func questionChips(for category: HomeItem.Category?, peakLabel: String?) -> [String] {
        var chips = ["哪天最不像平时？", "哪些是重复习惯？", "给这段时间起个名字"]
        if let category {
            chips.insert("\(category.rawValue)为什么变明显？", at: 0)
        } else if let peakLabel {
            chips.insert("\(peakLabel)为什么更密？", at: 0)
        }
        return Array(chips.prefix(4))
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
}
