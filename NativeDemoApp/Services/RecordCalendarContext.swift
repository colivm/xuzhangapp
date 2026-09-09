import Foundation

enum RecordCalendarContext {
    enum DayKind: Equatable {
        case workday
        case weekend
        case holiday
    }

    enum TimeBand: Equatable {
        case earlyMorning
        case morningCommute
        case lunch
        case afternoon
        case eveningCommute
        case lateEvening
        case lateNight
        case other
    }

    private static let knownMainlandChinaHolidayOverrides: Set<String> = [
        "2026-06-19"
    ]

    private static let knownMainlandChinaAdjustedWorkdays: Set<String> = []

    static func dayKind(for date: Date, calendar: Calendar = .current) -> DayKind {
        if isKnownMainlandChinaAdjustedWorkday(date, calendar: calendar) {
            return .workday
        }
        if isKnownMainlandChinaHoliday(date, calendar: calendar) {
            return .holiday
        }
        return isWeekend(date, calendar: calendar) ? .weekend : .workday
    }

    static func isWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        dayKind(for: date, calendar: calendar) == .workday
    }

    static func isNonWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        !isWorkday(date, calendar: calendar)
    }

    static func isWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    static func isKnownMainlandChinaHoliday(_ date: Date, calendar: Calendar = .current) -> Bool {
        if knownMainlandChinaHolidayOverrides.contains(dayKey(for: date, calendar: calendar)) {
            return true
        }
        let components = calendar.dateComponents([.month, .day], from: date)
        if components.month == 1 && components.day == 1 {
            return true
        }
        if components.month == 5 && components.day == 1 {
            return true
        }
        if components.month == 10 && (1...3).contains(components.day ?? 0) {
            return true
        }
        return isTraditionalMainlandChinaPublicFestival(date, calendar: calendar)
    }

    static func isKnownMainlandChinaAdjustedWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        knownMainlandChinaAdjustedWorkdays.contains(dayKey(for: date, calendar: calendar))
    }

    static func timeBand(for date: Date, calendar: Calendar = .current) -> TimeBand {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 0..<5: return .lateNight
        case 5..<7: return .earlyMorning
        case 7..<10: return .morningCommute
        case 11..<14: return .lunch
        case 14..<17: return .afternoon
        case 17..<21: return .eveningCommute
        case 21..<24: return .lateEvening
        default: return .other
        }
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func isTraditionalMainlandChinaPublicFestival(
        _ date: Date,
        calendar: Calendar
    ) -> Bool {
        var lunarCalendar = Calendar(identifier: .chinese)
        lunarCalendar.timeZone = calendar.timeZone
        let components = lunarCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
        guard components.isLeapMonth != true else { return false }
        if components.month == 1 && (1...3).contains(components.day ?? 0) {
            return true
        }
        if components.month == 5 && components.day == 5 {
            return true
        }
        if components.month == 8 && components.day == 15 {
            return true
        }
        return false
    }
}

/// Shared, conservative evidence policy for recognizing commute records.
///
/// A transport category or a low amount is not sufficient on its own. When a
/// record has no explicit commute wording, it can only be promoted by a
/// repeated, same-direction historical pattern (same amount in cents, same
/// time band, and at least two distinct prior workdays). This keeps the rule
/// useful for late-entered records while avoiding guesses for one-off trips.
enum CommuteEvidencePolicy {
    enum Direction: Equatable {
        case morning
        case evening
    }

    private static let explicitCues = [
        "通勤", "上班", "下班", "上下班", "到岗", "早高峰", "晚高峰",
        "地铁", "公交", "轨道交通", "去公司", "去单位", "回家", "到家"
    ]
    private static let travelCues = ["高铁", "动车", "火车", "机票", "机场", "酒店", "旅行", "旅游", "出差", "返乡", "长途"]

    struct EvidenceIndex {
        private struct Pattern: Hashable {
            let cents: Int
            let direction: Direction
        }

        private let historicalDaysByPattern: [Pattern: Set<String>]

        init(historyItems: [HomeItem], calendar: Calendar = .current) {
            var grouped: [Pattern: Set<String>] = [:]
            for candidate in historyItems where candidate.amount > 0 && candidate.category == .transport {
                guard hasExplicitCue(candidate),
                      let direction = CommuteEvidencePolicy.direction(for: candidate.createdAt, calendar: calendar),
                      RecordCalendarContext.isWorkday(candidate.createdAt, calendar: calendar) else { continue }
                let pattern = Pattern(cents: cents(candidate.amount), direction: direction)
                grouped[pattern, default: []].insert(
                    RecordCalendarContext.dayKey(for: candidate.createdAt, calendar: calendar)
                )
            }
            historicalDaysByPattern = grouped
        }

        fileprivate func supports(_ item: HomeItem, calendar: Calendar) -> Bool {
            guard let direction = CommuteEvidencePolicy.direction(for: item.createdAt, calendar: calendar) else {
                return false
            }
            let pattern = Pattern(cents: cents(item.amount), direction: direction)
            return historicalDaysByPattern[pattern, default: []].count >= 2
        }
    }

    static func matches(
        _ item: HomeItem,
        historyItems: [HomeItem] = [],
        evidenceIndex: EvidenceIndex? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        matches(
            item,
            evidenceIndex: evidenceIndex ?? EvidenceIndex(historyItems: historyItems, calendar: calendar),
            calendar: calendar
        )
    }

    static func matches(
        _ item: HomeItem,
        evidenceIndex: EvidenceIndex,
        calendar: Calendar = .current
    ) -> Bool {
        guard item.amount > 0, item.category == .transport else { return false }
        if item.scenePackId == "commute" || hasExplicitCue(item) { return true }
        let normalizedTitle = item.title.lowercased()
        if travelCues.contains(where: { normalizedTitle.contains($0) }) { return false }
        if item.memoryContext?.semanticPlace == "外地" { return false }
        guard direction(for: item.createdAt, calendar: calendar) != nil,
              RecordCalendarContext.isWorkday(item.createdAt, calendar: calendar) else {
            return false
        }

        return evidenceIndex.supports(item, calendar: calendar)
    }

    static func hasExplicitCue(_ item: HomeItem) -> Bool {
        let text = [item.title, item.memoryContext?.semanticPlace ?? "", item.scenePackId ?? ""]
            .joined(separator: " ")
            .lowercased()
        return explicitCues.contains { text.localizedCaseInsensitiveContains($0) }
    }

    static func direction(for date: Date, calendar: Calendar = .current) -> Direction? {
        switch calendar.component(.hour, from: date) {
        case 7...10: return .morning
        case 16...21: return .evening
        default: return nil
        }
    }

    private static func cents(_ amount: Double) -> Int {
        Int((amount * 100).rounded())
    }
}
