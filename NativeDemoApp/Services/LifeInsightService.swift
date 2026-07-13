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

    private struct TraceInsightSignal {
        let kind: LifeSceneKind
        let category: HomeItem.Category
        let title: String
        let teaser: String
        let detail: String
        let supportLine: String
        let question: String
        let periodName: String
        let score: Double
        let anchorDate: Date?
    }

    private struct TraceInsightRow {
        let item: HomeItem
        let signal: LifeSceneSignal
    }

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

        let signals = rankedTraceSignals(from: validItems, periodLabel: periodLabel)
        if let primary = signals.first {
            let secondary = signals.dropFirst().first
            var fullLines = [primary.detail, primary.supportLine]
            if let secondary {
                fullLines.append(secondary.detail)
            }
            let chips = followUpQuestionChips(from: signals, periodLabel: periodLabel)
            return LifeInsightResult(
                leadQuestion: primary.title,
                teaser: primary.teaser,
                previewLine: primary.detail,
                fullLines: Array(fullLines.prefix(3)),
                questionChips: chips,
                periodName: primary.periodName
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
                teaser = "\(primaryFocusName)在\(peak.label)最集中，旁边还跟着「\(secondName)」。这几笔可以放在同一天的节奏里一起看。"
            } else if let peak {
                teaser = "\(primaryFocusName)在\(peak.label)最明显。回头看那天，会比只看金额更容易想起原因。"
            } else {
                teaser = "\(primaryFocusName)已经不止出现一次，可以当作这段时间反复发生的一件事来看。"
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
            fullLines.append("「\(topName)」和「\(secondName)」一起靠前，可以放在同一段生活里看。")
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
                items: validItems,
                periodLabel: periodLabel
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

    private func rankedTraceSignals(from items: [HomeItem], periodLabel: String) -> [TraceInsightSignal] {
        guard !items.isEmpty else { return [] }
        let rows = items.map { TraceInsightRow(item: $0, signal: LifeSceneSemanticService.classify($0)) }
        var signals: [TraceInsightSignal] = []
        signals += repeatedSceneSignals(from: rows, periodLabel: periodLabel)
        if let peak = denseDaySignal(from: rows, periodLabel: periodLabel) {
            signals.append(peak)
        }
        if let relation = relationSignal(from: rows, periodLabel: periodLabel) {
            signals.append(relation)
        }
        if let personal = personalNoteSignal(from: rows, periodLabel: periodLabel) {
            signals.append(personal)
        }

        var usedKeys = Set<String>()
        return signals
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) < 0.001 {
                    return (lhs.anchorDate ?? .distantPast) > (rhs.anchorDate ?? .distantPast)
                }
                return lhs.score > rhs.score
            }
            .filter { signal in
                let key = "\(signal.kind.rawValue)|\(signal.category.rawValue)"
                guard !usedKeys.contains(key) else { return false }
                usedKeys.insert(key)
                return true
            }
    }

    private func repeatedSceneSignals(from rows: [TraceInsightRow], periodLabel: String) -> [TraceInsightSignal] {
        let grouped = Dictionary(grouping: rows, by: { $0.signal.kind })
        return grouped.compactMap { _, entries -> TraceInsightSignal? in
            guard entries.count >= 2,
                  let strongest = entries.map({ $0.signal }).max(by: { $0.score < $1.score }) else {
                return nil
            }
            let sceneItems = entries.map({ $0.item }).sorted { $0.createdAt < $1.createdAt }
            let activeDays = Set(sceneItems.map { calendar.startOfDay(for: $0.createdAt) }).count
            let userEditedCount = sceneItems.filter { $0.userEditedTitle == true }.count
            let imageCount = sceneItems.filter { $0.hasMemoryImages }.count
            let amountSpread = amountSpreadText(for: sceneItems)
            let timeHint = sceneTimeHint(for: sceneItems)
            let label = readableSceneLabel(for: strongest, items: sceneItems)
            let count = sceneItems.count
            let score = Double(count) * 12
                + Double(activeDays) * 8
                + Double(userEditedCount) * 10
                + Double(imageCount) * 8
                + (strongest.confidenceTier == .strong ? 8 : 0)

            return TraceInsightSignal(
                kind: strongest.kind,
                category: strongest.category,
                title: "「\(label)」为什么反复出现？",
                teaser: "\(label)出现了 \(count) 次。它不只是分类变多了，背后是\(sceneLifeSummary(for: strongest.kind, activeDays: activeDays))。",
                detail: repeatedSceneDetail(label: label, count: count, activeDays: activeDays, timeHint: timeHint, amountSpread: amountSpread),
                supportLine: sceneSupportLine(items: sceneItems, label: label),
                question: "\(label)为什么变明显？",
                periodName: "\(label)撑起来的\(periodLabel)",
                score: score,
                anchorDate: sceneItems.last?.createdAt
            )
        }
    }

    private func denseDaySignal(from rows: [TraceInsightRow], periodLabel: String) -> TraceInsightSignal? {
        let grouped = Dictionary(grouping: rows) { calendar.startOfDay(for: $0.item.createdAt) }
        guard let entry = grouped.max(by: { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.value.reduce(0) { $0 + $1.item.amount } < rhs.value.reduce(0) { $0 + $1.item.amount }
            }
            return lhs.value.count < rhs.value.count
        }),
              entry.value.count >= 2 else {
            return nil
        }
        let dayRows = entry.value.sorted { $0.item.createdAt < $1.item.createdAt }
        let dayItems = dayRows.map(\.item)
        let sceneLabels = distinctSceneLabels(from: dayRows, limit: 3)
        let label = calendarDayLabel(for: entry.key)
        let sceneText = sceneLabels.isEmpty ? "几笔记录" : sceneLabels.joined(separator: "、")
        let score = Double(dayItems.count) * 14 + Double(sceneLabels.count) * 9
        return TraceInsightSignal(
            kind: .general,
            category: dayItems.first?.category ?? .other,
            title: "\(label)为什么值得回头看？",
            teaser: "\(label)不只是多了几笔，\(sceneText)都落在这一天。",
            detail: "\(label)留下 \(dayItems.count) 笔，里面有\(sceneText)。回头看这一天，比只看哪类花得多更有用。",
            supportLine: sceneSupportLine(items: dayItems, label: label),
            question: "\(label)发生了什么？",
            periodName: "\(label)撑起来的\(periodLabel)",
            score: score,
            anchorDate: entry.key
        )
    }

    private func relationSignal(from rows: [TraceInsightRow], periodLabel: String) -> TraceInsightSignal? {
        let groupedByDay = Dictionary(grouping: rows) { calendar.startOfDay(for: $0.item.createdAt) }
        let candidates = groupedByDay.compactMap { day, entries -> (Date, [LifeSceneSignal], [HomeItem])? in
            let uniqueSignals = Array(Dictionary(grouping: entries.map { $0.signal }, by: { $0.kind }).values.compactMap { signals in
                signals.max { $0.score < $1.score }
            })
            guard uniqueSignals.count >= 2 else { return nil }
            return (day, uniqueSignals.sorted { $0.priority < $1.priority }, entries.map { $0.item })
        }
        guard let best = candidates.sorted(by: { lhs, rhs in
            if lhs.1.count == rhs.1.count { return lhs.0 > rhs.0 }
            return lhs.1.count > rhs.1.count
        }).first else {
            return nil
        }
        let first = best.1[0]
        let second = best.1[1]
        let firstLabel = readableSceneLabel(for: first, items: best.2)
        let secondLabel = readableSceneLabel(for: second, items: best.2)
        let dayLabel = calendarDayLabel(for: best.0)
        return TraceInsightSignal(
            kind: first.kind,
            category: first.category,
            title: "\(firstLabel)和\(secondLabel)是同一段事吗？",
            teaser: "\(dayLabel)，\(firstLabel)和\(secondLabel)一起出现，像是同一天安排带出来的两条线。",
            detail: "\(dayLabel)同时有\(firstLabel)和\(secondLabel)。它们不一定要分开看，可以先当作同一天外出、工作节奏或临时安排的一部分。",
            supportLine: sceneSupportLine(items: best.2, label: dayLabel),
            question: "\(firstLabel)和\(secondLabel)同天出现了吗？",
            periodName: "\(firstLabel)和\(secondLabel)交叠的\(periodLabel)",
            score: 38 + Double(best.1.count) * 8 + Double(best.2.count) * 5,
            anchorDate: best.0
        )
    }

    private func personalNoteSignal(from rows: [TraceInsightRow], periodLabel: String) -> TraceInsightSignal? {
        let candidates = rows
            .filter { row in
                let title = row.item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return row.item.userEditedTitle == true
                    && !title.isEmpty
                    && title != row.item.category.defaultRecordTitle
                    && !RecordSemanticLexicon.isSystemGeneratedTitle(title)
            }
            .sorted { lhs, rhs in
                personalSignalScore(lhs.item) > personalSignalScore(rhs.item)
            }
        guard let row = candidates.first else { return nil }
        let item = row.item
        let signal = row.signal
        let label = readableSceneLabel(for: signal, items: [item])
        let dayLabel = calendarDayLabel(for: item.createdAt)
        let summary = personalNoteSummary(for: item, label: label)
        return TraceInsightSignal(
            kind: signal.kind,
            category: item.category,
            title: "这笔为什么值得留意？",
            teaser: "\(dayLabel)这笔写得更具体，像是你当时有意想把它留下来。",
            detail: summary,
            supportLine: "\(dayLabel) \(item.createdAt.zhBillTime)，\(item.amount.formatted(.cny))。不用复述原备注，记住它比默认记录更有现场感就够了。",
            question: "哪条备注最值得回看？",
            periodName: "有具体备注的\(periodLabel)",
            score: personalSignalScore(item),
            anchorDate: item.createdAt
        )
    }

    private func personalSignalScore(_ item: HomeItem) -> Double {
        var score = 30.0
        if item.hasMemoryImages { score += 16 }
        if item.memoryContext?.weatherKind != nil { score += 8 }
        if item.memoryContext?.semanticPlace != nil { score += 8 }
        if item.userEditedCategory == true { score += 8 }
        score += min(Double(item.title.count), 18)
        return score
    }

    private func repeatedSceneDetail(
        label: String,
        count: Int,
        activeDays: Int,
        timeHint: String?,
        amountSpread: String?
    ) -> String {
        var parts = ["\(label)留下 \(count) 笔"]
        if activeDays > 1 {
            parts.append("分布在 \(activeDays) 天")
        }
        if let timeHint {
            parts.append(timeHint)
        }
        if let amountSpread {
            parts.append(amountSpread)
        }
        return parts.joined(separator: "，") + "。它比单看分类更能说明这段日子怎么过的。"
    }

    private func sceneSupportLine(items: [HomeItem], label: String) -> String {
        let anchors = representativeSupportItems(from: items).map { item in
            "\(calendarDayLabel(for: item.createdAt)) \(item.createdAt.zhBillTime) \(item.amount.formatted(.cny))"
        }
        guard !anchors.isEmpty else { return "\(label)的记录还不多，再多几笔会看得更准。" }
        return "能对应上的记录：\(anchors.joined(separator: "；"))。"
    }

    private func representativeSupportItems(from items: [HomeItem]) -> [HomeItem] {
        let sorted = items.sorted { lhs, rhs in
            if lhs.userEditedTitle == rhs.userEditedTitle {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.userEditedTitle == true
        }
        var days = Set<String>()
        var result: [HomeItem] = []
        for item in sorted {
            let key = dayKey(for: item.createdAt)
            guard !days.contains(key) || result.count < 1 else { continue }
            result.append(item)
            days.insert(key)
            if result.count >= 3 { break }
        }
        return result
    }

    private func amountSpreadText(for items: [HomeItem]) -> String? {
        let amounts = items.map(\.amount).filter { $0 > 0 }
        guard let minAmount = amounts.min(), let maxAmount = amounts.max() else { return nil }
        if abs(maxAmount - minAmount) < 0.01 {
            return "金额都在 \(maxAmount.formatted(.cny))"
        }
        if maxAmount <= minAmount * 1.25 {
            return "金额接近日常水平"
        }
        return nil
    }

    private func sceneTimeHint(for items: [HomeItem]) -> String? {
        let hours = items.map { calendar.component(.hour, from: $0.createdAt) }
        guard !hours.isEmpty else { return nil }
        let morning = hours.filter { (6...10).contains($0) }.count
        let noon = hours.filter { (11...14).contains($0) }.count
        let evening = hours.filter { (17...21).contains($0) }.count
        let night = hours.filter { $0 >= 22 || $0 < 5 }.count
        let ranked = [
            ("集中在早上", morning),
            ("集中在饭点", noon),
            ("集中在傍晚", evening),
            ("有夜间记录", night)
        ].sorted { $0.1 > $1.1 }
        guard let top = ranked.first, top.1 >= 2 else { return nil }
        return top.0
    }

    private func distinctSceneLabels(from rows: [TraceInsightRow], limit: Int) -> [String] {
        var labels: [String] = []
        var used = Set<LifeSceneKind>()
        for row in rows {
            let signal = row.signal
            guard !used.contains(signal.kind) else { continue }
            used.insert(signal.kind)
            labels.append(readableSceneLabel(for: signal, items: [row.item]))
            if labels.count >= limit { break }
        }
        return labels
    }

    private func readableSceneLabel(for signal: LifeSceneSignal, items: [HomeItem]) -> String {
        let joined = items.map { "\($0.title) \($0.displayEmotionTag)" }.joined(separator: " ")
        switch signal.kind {
        case .breakfast: return "早餐"
        case .quickMeal: return "饭点"
        case .coffee: return containsAny(joined, ["奶茶", "饮品"]) ? "饮品" : "咖啡"
        case .workMeal: return "工作餐"
        case .commute: return "通勤"
        case .cityRoute: return "出门办事"
        case .convenienceSupply: return "临时补给"
        case .groceries: return "买菜补货"
        case .homeSupply: return "家用补给"
        case .telecomBill: return "话费账单"
        case .shopping: return "添置"
        case .medicalVisit: return "就医检查"
        case .medicineCare: return "用药护理"
        case .fitness: return "锻炼恢复"
        case .bodyCare: return "身体护理"
        case .lodging: return "停留住宿"
        case .social: return "见面人情"
        case .leisure: return "放松安排"
        case .errand: return "临时事务"
        case .general: return signal.category.label
        }
    }

    private func sceneLifeSummary(for kind: LifeSceneKind, activeDays: Int) -> String {
        switch kind {
        case .commute:
            return activeDays > 1 ? "工作日路线" : "路上的来回"
        case .workMeal, .quickMeal, .breakfast:
            return "饭点节奏"
        case .coffee:
            return "忙里提神的小节点"
        case .groceries, .homeSupply, .convenienceSupply:
            return "生活补给"
        case .medicalVisit, .medicineCare, .fitness, .bodyCare:
            return "身体相关安排"
        case .cityRoute:
            return "外出和办事"
        case .social:
            return "见面和心意往来"
        default:
            return "反复出现的生活小事"
        }
    }

    private func personalNoteSummary(for item: HomeItem, label: String) -> String {
        let dayLabel = calendarDayLabel(for: item.createdAt)
        switch item.category {
        case .transport:
            return "\(dayLabel)这笔是一次具体的\(label)，不是默认的交通记录。回头看时，可以从上班、下班，或者为了某件事出门这几个方向想起。"
        case .dining:
            return "\(dayLabel)这笔把\(label)写得更具体，说明那顿饭或那杯饮品在当天有一点位置。"
        case .health:
            return "\(dayLabel)这笔和身体安排有关，具体备注比金额更有用，后面回看恢复、问诊或护理会更清楚。"
        default:
            return "\(dayLabel)这笔留下了更具体的生活事实，适合作为这段时间的一个回看锚点。"
        }
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
        items: [HomeItem],
        periodLabel: String
    ) -> [String] {
        let rhythm = peakLabel.map { "\($0)发生了什么？" }
            ?? "哪天最特别？"
        let relation: String
        if let top, let second {
            relation = "\(focusName(for: top, items: items))和\(focusName(for: second, items: items))同天出现了吗？"
        } else {
            relation = "什么事出现了好几次？"
        }
        return [rhythm, relation, "给\(periodLabel)起个名字"]
    }

    private func followUpQuestionChips(from signals: [TraceInsightSignal], periodLabel: String) -> [String] {
        let followUps = signals.dropFirst().map(\.question)
        var result: [String] = []

        func appendFirst(where predicate: (String) -> Bool) {
            guard let question = followUps.first(where: predicate), !result.contains(question) else { return }
            result.append(question)
        }

        // 主问题已经在卡片标题里出现，Chip 只保留不同的后续角度。
        appendFirst { $0.contains("发生了什么") || $0.contains("哪天") }
        appendFirst { $0.contains("同天") || $0.contains("同一段") || $0.contains("一起") }
        appendFirst { $0.contains("备注") || $0.contains("哪条") }
        appendFirst { $0.contains("为什么") || $0.contains("好几次") }

        for fallback in ["给\(periodLabel)起个名字", "哪天最特别？"]
            where result.count < 2 && !result.contains(fallback) {
            result.append(fallback)
        }
        return Array(result.prefix(3))
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
        let joined = categoryItems.map { "\($0.title) \($0.displayEmotionTag)" }.joined(separator: " ")
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
            return "「\(name)」通常意味着位置变了。这段时间可以回头看看有没有旅行、出差，或者一段临时停留。"
        case .other:
            return "这些记录还没归进固定分类，但它们反复出现，可以回头看备注。"
        }
    }
}
