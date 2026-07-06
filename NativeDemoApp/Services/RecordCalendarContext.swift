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
