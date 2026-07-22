import Foundation

enum LifeNarrativeEchoKind: String, Equatable {
    case repeatRhythm
    case returnAfterGap
    case comparableChange
    case contextReturn
    case newContextPair
}

struct LifeNarrativeEcho: Equatable {
    let sourceRevision: Int
    let id: String
    let kind: LifeNarrativeEchoKind
    let signalID: String
    let label: String
    let line: String
    let currentEvidenceItemIDs: [UUID]
    let historicalEvidenceItemIDs: [UUID]
    let currentCount: Int
    let baselineCount: Int?
    let periodGap: Int?
    let currentDistinctDayCount: Int
    let historicalDistinctDayCount: Int?
    let baselinePeriodCount: Int?
}

struct LifeNarrativeEchoInput {
    let scope: LifeNarrativeScope
    let sourceRevision: Int
    let items: [HomeItem]
    let now: Date
    let recentEchoIDs: Set<String>
}

enum LifeNarrativeEchoPublicationPolicy {
    static func accepts(_ echo: LifeNarrativeEcho?, expectedSourceRevision: Int) -> Bool {
        echo?.sourceRevision == expectedSourceRevision
    }
}

enum LifeNarrativeEchoPolicy {
    private struct Candidate {
        let echo: LifeNarrativeEcho
        let score: Int
    }

    private struct PairDayEvidence {
        let day: Date
        let lateCommutes: [HomeItem]
        let coffees: [HomeItem]
    }

    private enum PairOrder {
        case coffeeAfterCommute
        case commuteAfterCoffee
        case mixed
    }

    static func makeEcho(
        _ input: LifeNarrativeEchoInput,
        calendar baseCalendar: Calendar = .current
    ) -> LifeNarrativeEcho? {
        let calendar = periodCalendar(scope: input.scope, base: baseCalendar)
        let safeItems = LifeNarrativeSignalPolicy.publishableItems(from: input.items)
            .filter { !LifeNarrativeSignalPolicy.isAdministrativeRecord($0) }
            .filter { $0.createdAt <= input.now }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                return lhs.createdAt < rhs.createdAt
            }
        let bucketed = Dictionary(grouping: safeItems) { item in
            periodDistance(
                from: item.createdAt,
                to: input.now,
                scope: input.scope,
                calendar: calendar
            )
        }
        let currentRows = bucketed[0, default: []]
        guard currentRows.count >= 2 else { return nil }

        let currentGroups = Dictionary(grouping: currentRows) {
            LifeSceneSemanticService.classify($0).kind
        }
        var candidates: [Candidate] = []

        if let candidate = contextReturnCandidate(
            scope: input.scope,
            sourceRevision: input.sourceRevision,
            currentRows: currentRows,
            bucketed: bucketed,
            calendar: calendar
        ) {
            candidates.append(candidate)
        }
        if let candidate = newContextPairCandidate(
            scope: input.scope,
            sourceRevision: input.sourceRevision,
            currentRows: currentRows,
            bucketed: bucketed,
            calendar: calendar
        ) {
            candidates.append(candidate)
        }

        for (kind, rows) in currentGroups where kind != .general {
            let scene = LifeSceneSemanticService.classify(rows.last!)
            let signalID = "scene:\(kind.rawValue)"
            let historyByDistance = Dictionary(uniqueKeysWithValues: (1...12).map { distance in
                let matching = bucketed[distance, default: []].filter {
                    LifeSceneSemanticService.classify($0).kind == kind
                }
                return (distance, matching)
            })

            if let candidate = returnCandidate(
                scope: input.scope,
                sourceRevision: input.sourceRevision,
                signalKind: kind,
                signalID: signalID,
                label: scene.label,
                currentRows: rows,
                historyByDistance: historyByDistance,
                calendar: calendar
            ) {
                candidates.append(candidate)
            }
            if let candidate = changeCandidate(
                scope: input.scope,
                sourceRevision: input.sourceRevision,
                signalID: signalID,
                label: scene.label,
                currentRows: rows,
                previousRows: comparableRows(
                    historyByDistance[1, default: []],
                    scope: input.scope,
                    now: input.now,
                    calendar: calendar
                ),
                calendar: calendar
            ) {
                candidates.append(candidate)
            }
            if let candidate = repeatCandidate(
                scope: input.scope,
                sourceRevision: input.sourceRevision,
                signalKind: kind,
                signalID: signalID,
                label: scene.label,
                currentRows: rows,
                historyByDistance: historyByDistance,
                calendar: calendar
            ) {
                candidates.append(candidate)
            }
        }

        return candidates
            .filter { !input.recentEchoIDs.contains($0.echo.id) }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score { return lhs.echo.id < rhs.echo.id }
                return lhs.score > rhs.score
            }
            .first?
            .echo
    }

    private static func returnCandidate(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        signalKind: LifeSceneKind,
        signalID: String,
        label: String,
        currentRows: [HomeItem],
        historyByDistance: [Int: [HomeItem]],
        calendar: Calendar
    ) -> Candidate? {
        guard signalKind != .coffee,
              distinctDayCount(currentRows, calendar: calendar) >= 2,
              historyByDistance[1, default: []].isEmpty,
              let distance = (2...12).first(where: { !historyByDistance[$0, default: []].isEmpty }) else {
            return nil
        }
        let historicalRows = historyByDistance[distance, default: []]
        guard distinctDayCount(historicalRows, calendar: calendar) >= 2 else { return nil }
        let gap = distance - 1
        let unit = periodUnit(scope, count: gap)
        let line = "\(label)隔了 \(gap) \(unit)再次出现：这次 \(currentRows.count) 笔，上一次在 \(historicalRows.last?.createdAt.zhBillDateOnly ?? "更早以前")。"
        return Candidate(
            echo: LifeNarrativeEcho(
                sourceRevision: sourceRevision,
                id: "echo:\(scope.rawValue):return:\(signalID)",
                kind: .returnAfterGap,
                signalID: signalID,
                label: label,
                line: line,
                currentEvidenceItemIDs: currentRows.map(\.id),
                historicalEvidenceItemIDs: historicalRows.map(\.id),
                currentCount: currentRows.count,
                baselineCount: historicalRows.count,
                periodGap: gap,
                currentDistinctDayCount: distinctDayCount(currentRows, calendar: calendar),
                historicalDistinctDayCount: distinctDayCount(historicalRows, calendar: calendar),
                baselinePeriodCount: nil
            ),
            score: 320 + min(gap, 8) * 4 + min(currentRows.count, 6)
        )
    }

    private static func changeCandidate(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        signalID: String,
        label: String,
        currentRows: [HomeItem],
        previousRows: [HomeItem],
        calendar: Calendar
    ) -> Candidate? {
        guard !previousRows.isEmpty else { return nil }
        let delta = currentRows.count - previousRows.count
        let relativeChange = Double(abs(delta)) / Double(max(previousRows.count, 1))
        guard abs(delta) >= 2, relativeChange >= 0.5 else { return nil }
        let direction = delta > 0 ? "多了 \(delta) 笔" : "少了 \(-delta) 笔"
        let line = "\(label)和\(previousPeriodName(scope))比\(direction)：这次 \(currentRows.count) 笔，上次 \(previousRows.count) 笔。"
        return Candidate(
            echo: LifeNarrativeEcho(
                sourceRevision: sourceRevision,
                id: "echo:\(scope.rawValue):change:\(signalID):\(delta > 0 ? "up" : "down")",
                kind: .comparableChange,
                signalID: signalID,
                label: label,
                line: line,
                currentEvidenceItemIDs: currentRows.map(\.id),
                historicalEvidenceItemIDs: previousRows.map(\.id),
                currentCount: currentRows.count,
                baselineCount: previousRows.count,
                periodGap: 0,
                currentDistinctDayCount: distinctDayCount(currentRows, calendar: calendar),
                historicalDistinctDayCount: distinctDayCount(previousRows, calendar: calendar),
                baselinePeriodCount: 1
            ),
            score: 270 + min(abs(delta), 10) * 3
        )
    }

    private static func repeatCandidate(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        signalKind: LifeSceneKind,
        signalID: String,
        label: String,
        currentRows: [HomeItem],
        historyByDistance: [Int: [HomeItem]],
        calendar: Calendar
    ) -> Candidate? {
        guard scope == .week, signalKind != .coffee else { return nil }
        let currentWeekdays = Set(currentRows.map { calendar.component(.weekday, from: $0.createdAt) })
        let weekdayEvidence = currentWeekdays.compactMap { weekday -> (weekday: Int, distances: [Int])? in
            let distances = (1...8).filter { distance in
                historyByDistance[distance, default: []].contains {
                    calendar.component(.weekday, from: $0.createdAt) == weekday
                }
            }
            return distances.count >= 2 ? (weekday, distances) : nil
        }
        .sorted { lhs, rhs in
            if lhs.distances.count == rhs.distances.count { return lhs.weekday < rhs.weekday }
            return lhs.distances.count > rhs.distances.count
        }
        guard let rhythm = weekdayEvidence.first else { return nil }
        let historicalRows = rhythm.distances.flatMap { distance in
            historyByDistance[distance, default: []].filter {
                calendar.component(.weekday, from: $0.createdAt) == rhythm.weekday
            }
        }
        let periodCount = rhythm.distances.count + 1
        let line = "\(label)近 \(periodCount) 个有记录的周里，都在\(weekdayName(rhythm.weekday))出现。"
        return Candidate(
            echo: LifeNarrativeEcho(
                sourceRevision: sourceRevision,
                id: "echo:\(scope.rawValue):repeat:\(signalID):weekday-\(rhythm.weekday)",
                kind: .repeatRhythm,
                signalID: signalID,
                label: label,
                line: line,
                currentEvidenceItemIDs: currentRows.filter {
                    calendar.component(.weekday, from: $0.createdAt) == rhythm.weekday
                }.map(\.id),
                historicalEvidenceItemIDs: historicalRows.map(\.id),
                currentCount: currentRows.count,
                baselineCount: historicalRows.count,
                periodGap: nil,
                currentDistinctDayCount: distinctDayCount(currentRows, calendar: calendar),
                historicalDistinctDayCount: distinctDayCount(historicalRows, calendar: calendar),
                baselinePeriodCount: rhythm.distances.count
            ),
            score: 220 + min(periodCount, 8) * 3
        )
    }

    private static func contextReturnCandidate(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        currentRows: [HomeItem],
        bucketed: [Int: [HomeItem]],
        calendar: Calendar
    ) -> Candidate? {
        guard scope == .week else { return nil }
        let currentCommutes = currentRows.filter { isHighConfidenceLateCommute($0, calendar: calendar) }
        let currentDays = narrativeDays(for: currentCommutes, calendar: calendar)
        guard currentDays.count >= 2 else { return nil }

        let previousCommutes = bucketed[1, default: []].filter {
            isHighConfidenceLateCommute($0, calendar: calendar)
        }
        guard previousCommutes.isEmpty else { return nil }

        let historicalMatch = (2...12).compactMap { distance -> (Int, [HomeItem])? in
            let rows = bucketed[distance, default: []].filter {
                isHighConfidenceLateCommute($0, calendar: calendar)
            }
            return narrativeDays(for: rows, calendar: calendar).count >= 2
                ? (distance, rows)
                : nil
        }.first
        guard let (distance, historicalRows) = historicalMatch else { return nil }

        let historicalDays = narrativeDays(for: historicalRows, calendar: calendar)
        let historicalRun = longestConsecutiveDayRun(historicalDays, calendar: calendar)
        let historicalLine = historicalRun >= 2
            ? "上一次连续 \(historicalRun) 天记下晚归，是 \(distance) 周前。"
            : "上一次一周里有 \(historicalDays.count) 天留下晚间通勤，是 \(distance) 周前。"
        let line = "这周晚间通勤重新出现了。\(historicalLine)"

        return Candidate(
            echo: LifeNarrativeEcho(
                sourceRevision: sourceRevision,
                id: "echo:week:context-return:late-commute",
                kind: .contextReturn,
                signalID: "context:late-commute",
                label: "晚间通勤",
                line: line,
                currentEvidenceItemIDs: currentCommutes.map(\.id),
                historicalEvidenceItemIDs: historicalRows.map(\.id),
                currentCount: currentCommutes.count,
                baselineCount: historicalRows.count,
                periodGap: distance,
                currentDistinctDayCount: currentDays.count,
                historicalDistinctDayCount: historicalDays.count,
                baselinePeriodCount: distance
            ),
            score: 480 + min(distance, 8) * 4 + min(currentDays.count, 4) * 5
        )
    }

    private static func newContextPairCandidate(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        currentRows: [HomeItem],
        bucketed: [Int: [HomeItem]],
        calendar: Calendar
    ) -> Candidate? {
        guard scope == .week else { return nil }
        let currentPairs = pairDayEvidence(in: currentRows, calendar: calendar)
        guard currentPairs.count >= 2 else { return nil }

        let activeHistory = (1...8).compactMap { distance -> (distance: Int, rows: [HomeItem])? in
            let rows = bucketed[distance, default: []]
            return rows.isEmpty ? nil : (distance, rows)
        }
        guard activeHistory.count >= 4,
              !activeHistory.contains(where: {
                  !pairDayEvidence(in: $0.rows, calendar: calendar).isEmpty
              }) else {
            return nil
        }

        let order = pairOrder(for: currentPairs)
        let days = currentPairs.map(\.day).sorted()
        let consecutiveCount = longestConsecutiveDayRun(days, calendar: calendar)
        let dayPhrase = consecutiveCount == days.count
            ? "连续 \(days.count) 天"
            : "\(days.count) 天"
        let relationLine: String
        switch order {
        case .coffeeAfterCommute:
            relationLine = "它在\(dayPhrase)的晚间通勤之后又出现了"
        case .commuteAfterCoffee:
            relationLine = "有咖啡的\(dayPhrase)都留下了晚间通勤"
        case .mixed:
            relationLine = "它和晚间通勤在\(dayPhrase)里一起出现"
        }
        let line = "咖啡还是生活线索，但这周真正不同的是，\(relationLine)。这种组合在近 \(activeHistory.count) 个有记录的周里首次出现。"
        let currentEvidence = currentPairs.flatMap { $0.lateCommutes + $0.coffees }
        let baselineEvidence = activeHistory.compactMap { $0.rows.last }
        let orderID: String
        switch order {
        case .coffeeAfterCommute: orderID = "coffee-after-commute"
        case .commuteAfterCoffee: orderID = "commute-after-coffee"
        case .mixed: orderID = "same-day"
        }

        return Candidate(
            echo: LifeNarrativeEcho(
                sourceRevision: sourceRevision,
                id: "echo:week:new-pair:late-commute+coffee:\(orderID)",
                kind: .newContextPair,
                signalID: "pair:late-commute+coffee",
                label: "咖啡与晚间通勤",
                line: line,
                currentEvidenceItemIDs: currentEvidence.map(\.id),
                historicalEvidenceItemIDs: baselineEvidence.map(\.id),
                currentCount: currentEvidence.count,
                baselineCount: 0,
                periodGap: nil,
                currentDistinctDayCount: days.count,
                historicalDistinctDayCount: nil,
                baselinePeriodCount: activeHistory.count
            ),
            score: 520 + min(days.count, 4) * 8 + min(activeHistory.count, 8) * 3
        )
    }

    private static func pairDayEvidence(
        in rows: [HomeItem],
        calendar: Calendar
    ) -> [PairDayEvidence] {
        let grouped = Dictionary(grouping: rows) { narrativeDay(for: $0.createdAt, calendar: calendar) }
        return grouped.compactMap { day, dayRows -> PairDayEvidence? in
            let lateCommutes = dayRows.filter { isHighConfidenceLateCommute($0, calendar: calendar) }
            let coffees = dayRows.filter { LifeSceneSemanticService.classify($0).kind == .coffee }
            guard !lateCommutes.isEmpty, !coffees.isEmpty else { return nil }
            return PairDayEvidence(
                day: day,
                lateCommutes: lateCommutes.sorted { $0.createdAt < $1.createdAt },
                coffees: coffees.sorted { $0.createdAt < $1.createdAt }
            )
        }
        .sorted { $0.day < $1.day }
    }

    private static func pairOrder(for pairs: [PairDayEvidence]) -> PairOrder {
        let coffeeAlwaysAfter = pairs.allSatisfy { pair in
            guard let firstCoffee = pair.coffees.first?.createdAt,
                  let lastCommute = pair.lateCommutes.last?.createdAt else { return false }
            return firstCoffee > lastCommute
        }
        if coffeeAlwaysAfter { return .coffeeAfterCommute }

        let commuteAlwaysAfter = pairs.allSatisfy { pair in
            guard let firstCommute = pair.lateCommutes.first?.createdAt,
                  let lastCoffee = pair.coffees.last?.createdAt else { return false }
            return firstCommute > lastCoffee
        }
        return commuteAlwaysAfter ? .commuteAfterCoffee : .mixed
    }

    private static func isHighConfidenceLateCommute(
        _ item: HomeItem,
        calendar: Calendar
    ) -> Bool {
        guard item.category == .transport else { return false }
        let hour = calendar.component(.hour, from: item.createdAt)
        guard (21...23).contains(hour) || (0..<5).contains(hour) else { return false }
        let kind = LifeSceneSemanticService.classify(item).kind
        if kind == .commute { return true }
        let text = "\(item.title) \(item.emotionTag)".lowercased()
        let strongCues = ["通勤", "上班", "下班", "晚高峰", "加班", "晚归", "公司", "单位", "工位"]
        return strongCues.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func narrativeDays(
        for rows: [HomeItem],
        calendar: Calendar
    ) -> [Date] {
        Array(Set(rows.map { narrativeDay(for: $0.createdAt, calendar: calendar) })).sorted()
    }

    private static func narrativeDay(for date: Date, calendar: Calendar) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -5, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    private static func longestConsecutiveDayRun(
        _ days: [Date],
        calendar: Calendar
    ) -> Int {
        let sortedDays = Array(Set(days)).sorted()
        guard !sortedDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<sortedDays.count {
            let distance = calendar.dateComponents(
                [.day],
                from: sortedDays[index - 1],
                to: sortedDays[index]
            ).day
            if distance == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private static func distinctDayCount(_ rows: [HomeItem], calendar: Calendar) -> Int {
        Set(rows.map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    private static func periodCalendar(scope: LifeNarrativeScope, base: Calendar) -> Calendar {
        guard scope == .week else { return base }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = base.timeZone
        calendar.firstWeekday = 2
        return calendar
    }

    private static func periodDistance(
        from date: Date,
        to now: Date,
        scope: LifeNarrativeScope,
        calendar: Calendar
    ) -> Int {
        switch scope {
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.startOfDay(for: now)
            return calendar.dateComponents([.day], from: start, to: end).day ?? Int.max
        case .week:
            guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
                  let end = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return Int.max }
            return (calendar.dateComponents([.day], from: start, to: end).day ?? Int.max) / 7
        case .month:
            let start = calendar.dateComponents([.year, .month], from: date)
            let end = calendar.dateComponents([.year, .month], from: now)
            guard let startYear = start.year, let startMonth = start.month,
                  let endYear = end.year, let endMonth = end.month else { return Int.max }
            return (endYear - startYear) * 12 + endMonth - startMonth
        }
    }

    private static func previousPeriodName(_ scope: LifeNarrativeScope) -> String {
        switch scope {
        case .day: return "昨天"
        case .week: return "上周"
        case .month: return "上个月同期"
        }
    }

    private static func comparableRows(
        _ rows: [HomeItem],
        scope: LifeNarrativeScope,
        now: Date,
        calendar: Calendar
    ) -> [HomeItem] {
        guard scope != .day,
              let currentStart = periodStart(for: now, scope: scope, calendar: calendar) else {
            return rows
        }
        let elapsedDays = calendar.dateComponents(
            [.day],
            from: currentStart,
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return rows.filter { row in
            guard let rowStart = periodStart(for: row.createdAt, scope: scope, calendar: calendar) else {
                return false
            }
            let rowOffset = calendar.dateComponents(
                [.day],
                from: rowStart,
                to: calendar.startOfDay(for: row.createdAt)
            ).day ?? Int.max
            return rowOffset <= elapsedDays
        }
    }

    private static func periodStart(
        for date: Date,
        scope: LifeNarrativeScope,
        calendar: Calendar
    ) -> Date? {
        switch scope {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
        case .month:
            return calendar.dateInterval(of: .month, for: date)?.start
        }
    }

    private static func periodUnit(_ scope: LifeNarrativeScope, count: Int) -> String {
        switch scope {
        case .day: return count == 1 ? "天" : "天"
        case .week: return count == 1 ? "周" : "周"
        case .month: return count == 1 ? "个月" : "个月"
        }
    }

    private static func weekdayName(_ weekday: Int) -> String {
        let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        guard names.indices.contains(weekday) else { return "同一天" }
        return names[weekday]
    }
}
