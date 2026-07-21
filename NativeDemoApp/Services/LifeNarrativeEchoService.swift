import Foundation

enum LifeNarrativeEchoKind: String, Equatable {
    case repeatRhythm
    case returnAfterGap
    case comparableChange
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

    static func makeEcho(
        _ input: LifeNarrativeEchoInput,
        calendar baseCalendar: Calendar = .current
    ) -> LifeNarrativeEcho? {
        let calendar = periodCalendar(scope: input.scope, base: baseCalendar)
        let safeItems = LifeNarrativeSignalPolicy.publishableItems(from: input.items)
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
                signalID: signalID,
                label: scene.label,
                currentRows: rows,
                historyByDistance: historyByDistance
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
                )
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
        signalID: String,
        label: String,
        currentRows: [HomeItem],
        historyByDistance: [Int: [HomeItem]]
    ) -> Candidate? {
        guard historyByDistance[1, default: []].isEmpty,
              let distance = (2...12).first(where: { !historyByDistance[$0, default: []].isEmpty }) else {
            return nil
        }
        let historicalRows = historyByDistance[distance, default: []]
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
                periodGap: gap
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
        previousRows: [HomeItem]
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
                periodGap: 0
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
                periodGap: nil
            ),
            score: 220 + min(periodCount, 8) * 3
        )
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
