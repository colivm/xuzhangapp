import Foundation

enum LifeInsightTheme: String {
    case forming
    case steady
    case change
    case effort
    case memory
    case relation
}

struct LifeInsightResult {
    let leadQuestion: String
    let teaser: String
    let previewLine: String
    let fullLines: [String]
    let questionChips: [String]
    let periodName: String
    let theme: LifeInsightTheme
    let highlightedDate: Date?
    let isMeaningful: Bool

    init(
        leadQuestion: String,
        teaser: String,
        previewLine: String,
        fullLines: [String],
        questionChips: [String],
        periodName: String,
        theme: LifeInsightTheme = .change,
        highlightedDate: Date? = nil,
        isMeaningful: Bool = true
    ) {
        self.leadQuestion = leadQuestion
        self.teaser = teaser
        self.previewLine = previewLine
        self.fullLines = fullLines
        self.questionChips = questionChips
        self.periodName = periodName
        self.theme = theme
        self.highlightedDate = highlightedDate
        self.isMeaningful = isMeaningful
    }
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
        let theme: LifeInsightTheme

        init(
            kind: LifeSceneKind,
            category: HomeItem.Category,
            title: String,
            teaser: String,
            detail: String,
            supportLine: String,
            question: String,
            periodName: String,
            score: Double,
            anchorDate: Date?,
            theme: LifeInsightTheme = .change
        ) {
            self.kind = kind
            self.category = category
            self.title = title
            self.teaser = teaser
            self.detail = detail
            self.supportLine = supportLine
            self.question = question
            self.periodName = periodName
            self.score = score
            self.anchorDate = anchorDate
            self.theme = theme
        }
    }

    private struct TraceInsightRow {
        let item: HomeItem
        let signal: LifeSceneSignal
    }

    private struct TraceRelationBucket {
        let first: LifeSceneSignal
        let second: LifeSceneSignal
        var dates: [Date]
        var items: [HomeItem]
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

    func buildTraceInsight(
        items: [HomeItem],
        historyItems: [HomeItem] = [],
        periodLabel: String,
        now: Date = Date()
    ) -> LifeInsightResult {
        let validItems = items
            .filter { $0.amount > 0 && $0.draftMeta == nil }
            .sorted { $0.createdAt < $1.createdAt }
        let comparisonItems = previousPeriodItems(
            from: historyItems,
            excluding: Set(validItems.map(\.id)),
            periodLabel: periodLabel,
            now: now
        )

        guard !validItems.isEmpty else {
            return LifeInsightResult(
                leadQuestion: "这里还在等生活留下第一笔",
                teaser: "不用急着总结。等有了日期、场景，或者一条你愿意写具体的备注，再回来看看这一段。",
                previewLine: "现在没有需要解释的变化，先把真实发生的事记下来就好。",
                fullLines: [
                    "这里不会为了有结论而硬找规律。",
                    "有照片、具体备注或和往常不同的节奏时，线索会自然出现。"
                ],
                questionChips: [],
                periodName: "\(periodLabel)还在开始",
                theme: .forming,
                isMeaningful: false
            )
        }

        let signals = rankedTraceSignals(
            from: validItems,
            comparisonItems: comparisonItems,
            periodLabel: periodLabel
        )
        if let primary = signals.first {
            let secondary = signals.dropFirst().first { $0.theme != primary.theme }
            var fullLines = [primary.detail, primary.supportLine]
            if let secondary {
                fullLines.append(secondary.detail)
            }
            let chips = followUpQuestionChips(from: signals)
            return LifeInsightResult(
                leadQuestion: primary.title,
                teaser: primary.teaser,
                previewLine: primary.detail,
                fullLines: Array(fullLines.prefix(3)),
                questionChips: chips,
                periodName: primary.periodName,
                theme: primary.theme,
                highlightedDate: primary.anchorDate,
                isMeaningful: true
            )
        }

        let peak = peakDay(from: validItems)
        let activeDays = Set(validItems.map { calendar.startOfDay(for: $0.createdAt) }).count
        let hasComparison = comparisonItems.count >= 3
        let steadyLine = hasComparison
            ? "通勤、饭点和普通日常没有出现足够明显的变化。没有异常，也不用硬找原因。"
            : "目前还没有足够的历史记录用来判断变化，所以不会只凭出现次数下结论。"
        let supportLine = peak.map { "\($0.label)留下 \($0.count) 笔，是这段时间记录最完整的一天。" }
            ?? "这段记录分布在 \(activeDays) 天里，整体没有特别突出的异常。"

        return LifeInsightResult(
            leadQuestion: "\(periodLabel)没有必须解释的变化",
            teaser: "日子大体按原来的节奏往前走。平稳本身，也是这一段生活的样子。",
            previewLine: steadyLine,
            fullLines: [steadyLine, supportLine],
            questionChips: [],
            periodName: "平稳走过的\(periodLabel)",
            theme: validItems.count < 3 ? .forming : .steady,
            highlightedDate: nil,
            isMeaningful: false
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

    private func previousPeriodItems(
        from historyItems: [HomeItem],
        excluding currentIDs: Set<UUID>,
        periodLabel: String,
        now: Date
    ) -> [HomeItem] {
        var analysisCalendar = calendar
        analysisCalendar.firstWeekday = 2
        let isWeek = periodLabel.contains("周")
        let component: Calendar.Component = isWeek ? .weekOfYear : .month
        guard let currentInterval = analysisCalendar.dateInterval(of: component, for: now),
              let previousStart = analysisCalendar.date(byAdding: component, value: -1, to: currentInterval.start) else {
            return []
        }
        let previousInterval = DateInterval(start: previousStart, end: currentInterval.start)
        return historyItems
            .filter {
                $0.amount > 0
                    && $0.draftMeta == nil
                    && !currentIDs.contains($0.id)
                    && previousInterval.contains($0.createdAt)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func rankedTraceSignals(
        from items: [HomeItem],
        comparisonItems: [HomeItem],
        periodLabel: String
    ) -> [TraceInsightSignal] {
        guard !items.isEmpty else { return [] }
        let rows = items.map { TraceInsightRow(item: $0, signal: LifeSceneSemanticService.classify($0)) }
        let comparisonRows = comparisonItems.map { TraceInsightRow(item: $0, signal: LifeSceneSemanticService.classify($0)) }
        var signals: [TraceInsightSignal] = []
        if let early = earlyStartChangeSignal(from: rows, comparisonRows: comparisonRows, periodLabel: periodLabel) {
            signals.append(early)
        }
        if let late = lateReturnChangeSignal(from: rows, comparisonRows: comparisonRows, periodLabel: periodLabel) {
            signals.append(late)
        }
        signals += repeatedSceneSignals(from: rows, comparisonRows: comparisonRows, periodLabel: periodLabel)
        if let relation = repeatedRelationSignal(from: rows, comparisonRows: comparisonRows, periodLabel: periodLabel) {
            signals.append(relation)
        }
        if let peak = denseDaySignal(from: rows, periodLabel: periodLabel) {
            signals.append(peak)
        }
        if let photo = photoMemorySignal(from: rows, periodLabel: periodLabel) {
            signals.append(photo)
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
                let key = "\(signal.theme.rawValue)|\(signal.kind.rawValue)|\(signal.category.rawValue)"
                guard !usedKeys.contains(key) else { return false }
                usedKeys.insert(key)
                return true
            }
    }

    private func earlyStartChangeSignal(
        from rows: [TraceInsightRow],
        comparisonRows: [TraceInsightRow],
        periodLabel: String
    ) -> TraceInsightSignal? {
        guard comparisonRows.count >= 3 else { return nil }
        let current = earlyStartRows(from: rows)
        let previous = earlyStartRows(from: comparisonRows)
        let currentDays = Set(current.map { calendar.startOfDay(for: $0.item.createdAt) })
        let previousDays = Set(previous.map { calendar.startOfDay(for: $0.item.createdAt) })
        guard currentDays.count >= 3,
              currentDays.count >= previousDays.count + 2 else { return nil }
        let anchor = current.min { $0.item.createdAt < $1.item.createdAt }?.item
        let comparisonText = previousDays.isEmpty
            ? "上一个周期没有留下同样的早间节奏"
            : "比上一个周期多了 \(currentDays.count - previousDays.count) 天"
        return TraceInsightSignal(
            kind: .commute,
            category: .transport,
            title: "\(periodLabel)的早晨，比往常更早启动",
            teaser: "有 \(currentDays.count) 天在 9 点前留下通勤、早餐或咖啡记录。像是这段时间，每天都开始得很快。",
            detail: "\(comparisonText)。这不是某一笔花了多少，而是你一次次把一天撑起来的时间更早了。",
            supportLine: sceneSupportLine(items: current.map(\.item), label: "早间记录"),
            question: "看看这些早晨",
            periodName: "更早开始的\(periodLabel)",
            score: 92 + Double(currentDays.count - previousDays.count) * 5,
            anchorDate: anchor?.createdAt,
            theme: .effort
        )
    }

    private func lateReturnChangeSignal(
        from rows: [TraceInsightRow],
        comparisonRows: [TraceInsightRow],
        periodLabel: String
    ) -> TraceInsightSignal? {
        guard comparisonRows.count >= 3 else { return nil }
        let current = lateDayRows(from: rows)
        let previous = lateDayRows(from: comparisonRows)
        let currentDays = Set(current.map { calendar.startOfDay(for: $0.item.createdAt) })
        let previousDays = Set(previous.map { calendar.startOfDay(for: $0.item.createdAt) })
        guard currentDays.count >= 2,
              currentDays.count > previousDays.count else { return nil }
        let anchor = current.max { $0.item.createdAt < $1.item.createdAt }?.item
        return TraceInsightSignal(
            kind: .commute,
            category: .transport,
            title: "有几天，你结束一天的时间比往常晚",
            teaser: "\(periodLabel)有 \(currentDays.count) 天在 21 点后留下出行或饭点记录。它们更像是被安排得很满的日子。",
            detail: "比上一个周期多了 \(currentDays.count - previousDays.count) 天。这里不判断好坏，只是把那些晚归或晚些吃饭的日子替你留住。",
            supportLine: sceneSupportLine(items: current.map(\.item), label: "较晚的记录"),
            question: "回到那些晚一些的日子",
            periodName: "有几天结束得更晚的\(periodLabel)",
            score: 88 + Double(currentDays.count - previousDays.count) * 6,
            anchorDate: anchor?.createdAt,
            theme: .effort
        )
    }

    private func earlyStartRows(from rows: [TraceInsightRow]) -> [TraceInsightRow] {
        let kinds: Set<LifeSceneKind> = [.commute, .breakfast, .coffee, .workMeal, .quickMeal]
        return rows.filter {
            let hour = calendar.component(.hour, from: $0.item.createdAt)
            return (5..<9).contains(hour) && kinds.contains($0.signal.kind)
        }
    }

    private func lateDayRows(from rows: [TraceInsightRow]) -> [TraceInsightRow] {
        let kinds: Set<LifeSceneKind> = [.commute, .cityRoute, .workMeal, .quickMeal, .coffee]
        return rows.filter {
            let hour = calendar.component(.hour, from: $0.item.createdAt)
            return (hour >= 21 || hour < 3) && kinds.contains($0.signal.kind)
        }
    }

    private func repeatedRelationSignal(
        from rows: [TraceInsightRow],
        comparisonRows: [TraceInsightRow],
        periodLabel: String
    ) -> TraceInsightSignal? {
        let currentBuckets = relationBuckets(from: rows)
        let previousBuckets = relationBuckets(from: comparisonRows)
        let candidates: [(key: String, bucket: TraceRelationBucket)] = currentBuckets.compactMap { key, bucket in
            let currentDays = Set(bucket.dates.map { calendar.startOfDay(for: $0) }).count
            guard currentDays >= 2 else { return nil }
            let previousDays = Set((previousBuckets[key]?.dates ?? []).map { calendar.startOfDay(for: $0) }).count
            let bothRoutine = isRoutineScene(bucket.first.kind) && isRoutineScene(bucket.second.kind)
            if bothRoutine {
                guard comparisonRows.count >= 3, currentDays > previousDays else { return nil }
            }
            return (key: key, bucket: bucket)
        }
        guard let best = candidates.max(by: { (lhs: (key: String, bucket: TraceRelationBucket), rhs: (key: String, bucket: TraceRelationBucket)) in
            let leftDays = Set(lhs.bucket.dates.map { calendar.startOfDay(for: $0) }).count
            let rightDays = Set(rhs.bucket.dates.map { calendar.startOfDay(for: $0) }).count
            return leftDays < rightDays
        }) else { return nil }

        let key = best.key
        let bucket = best.bucket
        let dayCount = Set(bucket.dates.map { calendar.startOfDay(for: $0) }).count
        let previousDayCount = Set((previousBuckets[key]?.dates ?? []).map { calendar.startOfDay(for: $0) }).count
        let firstLabel = readableSceneLabel(for: bucket.first, items: bucket.items)
        let secondLabel = readableSceneLabel(for: bucket.second, items: bucket.items)
        let pairKinds: Set<LifeSceneKind> = [bucket.first.kind, bucket.second.kind]
        let isMorningPair = pairKinds.contains(.commute) && pairKinds.contains(.coffee)
        let title = isMorningPair
            ? "\(periodLabel)的早晨，常常这样开始"
            : "两件小事，几次落在了同一天"
        let teaser = isMorningPair
            ? "有 \(dayCount) 天，通勤和咖啡出现在同一天。比起咖啡本身，更像是忙碌开始前的一段缓冲。"
            : "\(firstLabel)和\(secondLabel)在 \(dayCount) 天里一起出现，可以把它们放回同一天的生活里看。"
        let comparison = comparisonRows.count >= 3
            ? "上一个周期有 \(previousDayCount) 天，这次有 \(dayCount) 天。"
            : "目前先把这 \(dayCount) 天留作同一条生活线。"
        return TraceInsightSignal(
            kind: bucket.first.kind,
            category: bucket.first.category,
            title: title,
            teaser: teaser,
            detail: "\(comparison)它们不一定互为原因，但确实几次共享了同一天。",
            supportLine: sceneSupportLine(items: bucket.items, label: "同天记录"),
            question: "看看它们一起出现的日子",
            periodName: "\(firstLabel)和\(secondLabel)交叠的\(periodLabel)",
            score: 70 + Double(dayCount) * 8 + Double(max(0, dayCount - previousDayCount)) * 6,
            anchorDate: bucket.dates.max(),
            theme: .relation
        )
    }

    private func relationBuckets(from rows: [TraceInsightRow]) -> [String: TraceRelationBucket] {
        let grouped = Dictionary(grouping: rows) { calendar.startOfDay(for: $0.item.createdAt) }
        var result: [String: TraceRelationBucket] = [:]
        for (day, dayRows) in grouped {
            let unique = Dictionary(grouping: dayRows, by: { $0.signal.kind }).values.compactMap { entries in
                entries.max { $0.signal.score < $1.signal.score }
            }
            .filter { $0.signal.kind != .general && $0.signal.kind != .telecomBill }
            .sorted { $0.signal.kind.rawValue < $1.signal.kind.rawValue }
            guard unique.count >= 2 else { continue }
            for firstIndex in 0..<(unique.count - 1) {
                for secondIndex in (firstIndex + 1)..<unique.count {
                    let first = unique[firstIndex]
                    let second = unique[secondIndex]
                    let key = "\(first.signal.kind.rawValue)|\(second.signal.kind.rawValue)"
                    if var bucket = result[key] {
                        bucket.dates.append(day)
                        bucket.items.append(contentsOf: [first.item, second.item])
                        result[key] = bucket
                    } else {
                        result[key] = TraceRelationBucket(
                            first: first.signal,
                            second: second.signal,
                            dates: [day],
                            items: [first.item, second.item]
                        )
                    }
                }
            }
        }
        return result
    }

    private func photoMemorySignal(from rows: [TraceInsightRow], periodLabel: String) -> TraceInsightSignal? {
        let candidates = rows
            .filter { $0.item.hasMemoryImages }
            .sorted { personalSignalScore($0.item) > personalSignalScore($1.item) }
        guard let row = candidates.first else { return nil }
        let item = row.item
        let dayLabel = calendarDayLabel(for: item.createdAt)
        let label = readableSceneLabel(for: row.signal, items: [item])
        let title = candidates.count == 1
            ? "你留下的这张照片，成了\(periodLabel)最清楚的现场"
            : "被你拍下来的那一刻，比分类更容易被记住"
        return TraceInsightSignal(
            kind: row.signal.kind,
            category: item.category,
            title: title,
            teaser: "\(dayLabel)的\(label)被你留成了画面。它不需要代表某种规律，本身就是这段时间的一部分。",
            detail: "照片和具体记录落在同一天，之后再看时，你更可能先想起当时发生了什么，而不是花了多少。",
            supportLine: "\(dayLabel) \(item.createdAt.zhBillTime)，\(item.displayTitle)，\(item.amount.formatted(.cny))。",
            question: "找回这个现场",
            periodName: "照片留在账本里的\(periodLabel)",
            score: 66 + personalSignalScore(item) * 0.45,
            anchorDate: item.createdAt,
            theme: .memory
        )
    }

    private func isRoutineScene(_ kind: LifeSceneKind) -> Bool {
        switch kind {
        case .breakfast, .quickMeal, .coffee, .workMeal, .commute,
             .convenienceSupply, .groceries, .homeSupply, .telecomBill, .general:
            return true
        default:
            return false
        }
    }

    private func isInherentlyMeaningfulScene(_ kind: LifeSceneKind) -> Bool {
        switch kind {
        case .medicalVisit, .medicineCare, .fitness, .bodyCare, .lodging, .social, .leisure:
            return true
        default:
            return false
        }
    }

    private func meaningfulSceneCopy(
        kind: LifeSceneKind,
        label: String,
        count: Int,
        activeDays: Int,
        previousCount: Int,
        periodLabel: String
    ) -> (title: String, teaser: String, detail: String, periodName: String, theme: LifeInsightTheme) {
        let comparison = previousCount > 0 && count > previousCount
            ? "比上一个周期多了 \(count - previousCount) 次。"
            : "它分布在 \(activeDays) 天里。"
        switch kind {
        case .medicalVisit, .medicineCare, .bodyCare:
            return (
                "你为身体留出的这些安排，被认真记了下来",
                "\(label)出现了 \(count) 次。它们不是普通消费，更像是你在处理和照顾身体。",
                "\(comparison)这里不替你判断状态，只把这些需要被照顾的日子放在一起。",
                "照顾身体的\(periodLabel)",
                .effort
            )
        case .fitness:
            return (
                "身体相关的安排，正在成为这段时间的一部分",
                "\(label)落在 \(activeDays) 天里。比起一次做了多少，更重要的是它几次回到了日程中。",
                "\(comparison)这是被你实际留在生活里的行动，不需要再被包装成目标。",
                "身体有被安排进去的\(periodLabel)",
                .effort
            )
        case .social:
            return (
                "\(periodLabel)，有几次见面被留了下来",
                "\(label)出现了 \(count) 次。账本留下的不只是支出，也有你为一些人和时刻腾出的位置。",
                "\(comparison)这些记录适合和当天的备注、照片放在一起回看。",
                "有人出现过的\(periodLabel)",
                .memory
            )
        case .lodging, .leisure:
            return (
                "日常之外，有几段时间被单独留了下来",
                "\(label)分布在 \(activeDays) 天里，像是从原来的节奏里暂时走出去了一点。",
                "\(comparison)地点、照片或具体备注，会比金额更接近当时的感受。",
                "日常之外的\(periodLabel)",
                .memory
            )
        default:
            return (
                "有一件事，在这段时间里变得更清楚",
                "\(label)出现了 \(count) 次，并且留下了具体备注、照片或上下文。",
                "\(comparison)它之所以被选中，不是因为次数多，而是因为你留下了更多现场。",
                "有具体现场的\(periodLabel)",
                .change
            )
        }
    }

    private func repeatedSceneSignals(
        from rows: [TraceInsightRow],
        comparisonRows: [TraceInsightRow],
        periodLabel: String
    ) -> [TraceInsightSignal] {
        let grouped = Dictionary(grouping: rows, by: { $0.signal.kind })
        let comparisonGrouped = Dictionary(grouping: comparisonRows, by: { $0.signal.kind })
        return grouped.compactMap { _, entries -> TraceInsightSignal? in
            guard entries.count >= 2,
                  let strongest = entries.map({ $0.signal }).max(by: { $0.score < $1.score }) else {
                return nil
            }
            guard !isRoutineScene(strongest.kind) else { return nil }
            let sceneItems = entries.map({ $0.item }).sorted { $0.createdAt < $1.createdAt }
            let activeDays = Set(sceneItems.map { calendar.startOfDay(for: $0.createdAt) }).count
            guard activeDays >= 2 else { return nil }
            let userEditedCount = sceneItems.filter { $0.userEditedTitle == true }.count
            let imageCount = sceneItems.filter { $0.hasMemoryImages }.count
            let contextCount = sceneItems.filter {
                $0.memoryContext?.weatherKind != nil || $0.memoryContext?.semanticPlace != nil
            }.count
            let previousCount = comparisonGrouped[strongest.kind]?.count ?? 0
            let changedFromBaseline = previousCount > 0 && sceneItems.count >= previousCount + 2
            let hasRichContext = userEditedCount + imageCount + contextCount > 0
            guard isInherentlyMeaningfulScene(strongest.kind) || changedFromBaseline || hasRichContext else {
                return nil
            }
            let label = readableSceneLabel(for: strongest, items: sceneItems)
            let count = sceneItems.count
            let copy = meaningfulSceneCopy(
                kind: strongest.kind,
                label: label,
                count: count,
                activeDays: activeDays,
                previousCount: previousCount,
                periodLabel: periodLabel
            )
            let score = 46
                + Double(activeDays) * 5
                + Double(userEditedCount) * 10
                + Double(imageCount) * 12
                + Double(contextCount) * 8
                + (changedFromBaseline ? 16 : 0)

            return TraceInsightSignal(
                kind: strongest.kind,
                category: strongest.category,
                title: copy.title,
                teaser: copy.teaser,
                detail: copy.detail,
                supportLine: sceneSupportLine(items: sceneItems, label: label),
                question: "回到\(label)出现的那些天",
                periodName: copy.periodName,
                score: score,
                anchorDate: sceneItems.last?.createdAt,
                theme: copy.theme
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
        let hasRichContext = dayItems.contains {
            $0.userEditedTitle == true
                || $0.hasMemoryImages
                || $0.memoryContext?.weatherKind != nil
                || $0.memoryContext?.semanticPlace != nil
        }
        guard dayItems.count >= 3 || (dayItems.count >= 2 && hasRichContext && sceneLabels.count >= 2) else {
            return nil
        }
        let label = calendarDayLabel(for: entry.key)
        let sceneText = sceneLabels.isEmpty ? "几笔记录" : sceneLabels.joined(separator: "、")
        let score = Double(dayItems.count) * 14 + Double(sceneLabels.count) * 9
        return TraceInsightSignal(
            kind: .general,
            category: dayItems.first?.category ?? .other,
            title: "\(label)，生活留下的细节最多",
            teaser: "那一天不只是记录多，\(sceneText)也一起被留下。它更像一段完整的小现场。",
            detail: "\(label)共有 \(dayItems.count) 笔。回到那天的安排、地点或见过的人，可能比分类和金额更容易唤起记忆。",
            supportLine: sceneSupportLine(items: dayItems, label: label),
            question: "回到\(label)",
            periodName: "有一天被记得更完整的\(periodLabel)",
            score: score + (hasRichContext ? 18 : 0),
            anchorDate: entry.key,
            theme: .memory
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
            title: "你特意写下的这一笔，成了这段时间的锚点",
            teaser: "\(dayLabel)这笔写得比默认记录更具体，像是当时确实有一件事想被留下。",
            detail: summary,
            supportLine: "\(dayLabel) \(item.createdAt.zhBillTime)，\(item.amount.formatted(.cny))。具体备注让这笔记录有了自己的现场。",
            question: "找回这笔记录",
            periodName: "有具体备注的\(periodLabel)",
            score: personalSignalScore(item),
            anchorDate: item.createdAt,
            theme: .memory
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

    private func followUpQuestionChips(from signals: [TraceInsightSignal]) -> [String] {
        var result: [String] = []
        for signal in signals where !signal.question.isEmpty && !result.contains(signal.question) {
            result.append(signal.question)
            if result.count >= 3 { break }
        }
        return result
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

}
