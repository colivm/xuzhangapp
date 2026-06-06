import Foundation

struct PlaybackEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let category: String
    let amount: Double
    let createdAt: Date
}

struct PlaybackSnapshot: Codable, Equatable {
    let durationMs: Int
    let entries: [PlaybackEntry]
}

enum SummaryPlaybackRange: String, Codable, Equatable {
    case week
    case month
}

struct SummaryNarration: Codable, Equatable {
    let warm: String
    let plain: String
}

struct SummaryChapter: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let metrics: [String: String]
    let narration: SummaryNarration
    let durationSec: Double
}

struct SummaryPlayback: Identifiable, Codable, Equatable {
    let id: String
    let range: SummaryPlaybackRange
    let title: String
    let rangeLabel: String
    let teaserLine: String
    let count: Int
    let total: Double
    let topCategory: String?
    let topCategoryRatio: Int
    let chapters: [SummaryChapter]
}

struct WeeklyShareCardPayload {
    let weekTotal: Double
    let topCategory: String
    let recordCount: Int
    let dailyTrend: [(String, Double)]
    let topCategoryRatio: Double
    let headline: String
    let subtitle: String
    let periodText: String
}

final class SummaryPlaybackQuotaStore {
    private enum Keys {
        static let playbackWeekKey = "playbackWeekKey"
        static let playbackWeekUsed = "playbackWeekUsed"
        static let lifetimeMonthChapterRemaining = "lifetimeMonthChapterRemaining"
        static let lifetimeWeekPlaybackCompleted = "lifetimeWeekPlaybackCompleted"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.lifetimeMonthChapterRemaining) == nil {
            defaults.set(3, forKey: Keys.lifetimeMonthChapterRemaining)
        }
    }

    func currentWeekKey(now: Date = Date()) -> String {
        let calendar = PlaybackService.isoCalendar
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", comps.weekOfYear ?? 0))"
    }

    func weekRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncWeekIfNeeded(now: now)
        return defaults.bool(forKey: Keys.playbackWeekUsed) ? 0 : 1
    }

    func monthRemaining(isMember: Bool) -> Int {
        guard !isMember else { return Int.max }
        return max(0, defaults.integer(forKey: Keys.lifetimeMonthChapterRemaining))
    }

    func canPlay(_ range: SummaryPlaybackRange, isMember: Bool, now: Date = Date()) -> Bool {
        guard !isMember else { return true }
        switch range {
        case .week:
            return weekRemaining(isMember: false, now: now) > 0
        case .month:
            return monthRemaining(isMember: false) > 0
        }
    }

    func markCompleted(_ range: SummaryPlaybackRange, isMember: Bool, progress: Double, now: Date = Date()) {
        guard progress >= 0.8 else { return }
        if range == .week {
            defaults.set(true, forKey: Keys.lifetimeWeekPlaybackCompleted)
        }
        guard !isMember else { return }
        switch range {
        case .week:
            syncWeekIfNeeded(now: now)
            defaults.set(true, forKey: Keys.playbackWeekUsed)
        case .month:
            let remaining = monthRemaining(isMember: false)
            if remaining > 0 {
                defaults.set(remaining - 1, forKey: Keys.lifetimeMonthChapterRemaining)
            }
        }
    }

    func hasCompletedWeekPlaybackEver() -> Bool {
        defaults.bool(forKey: Keys.lifetimeWeekPlaybackCompleted)
    }

    private func syncWeekIfNeeded(now: Date) {
        let key = currentWeekKey(now: now)
        if defaults.string(forKey: Keys.playbackWeekKey) != key {
            defaults.set(key, forKey: Keys.playbackWeekKey)
            defaults.set(false, forKey: Keys.playbackWeekUsed)
        }
    }
}

final class DailyFeatureQuotaStore {
    private enum Keys {
        static let ocrImportDayKey = "ocrImportDayKey"
        static let ocrImportUsedCount = "ocrImportUsedCount"
        static let todayPlaybackDayKey = "todayPlaybackDayKey"
        static let todayPlaybackUsedCount = "todayPlaybackUsedCount"
    }

    private let defaults: UserDefaults
    private let ocrDailyLimit = 3
    private let todayPlaybackDailyLimit = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func ocrRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncDayIfNeeded(dayKey: Keys.ocrImportDayKey, usedKey: Keys.ocrImportUsedCount, now: now)
        return max(0, ocrDailyLimit - defaults.integer(forKey: Keys.ocrImportUsedCount))
    }

    func todayPlaybackRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncDayIfNeeded(dayKey: Keys.todayPlaybackDayKey, usedKey: Keys.todayPlaybackUsedCount, now: now)
        return max(0, todayPlaybackDailyLimit - defaults.integer(forKey: Keys.todayPlaybackUsedCount))
    }

    func canUseOCR(isMember: Bool, now: Date = Date()) -> Bool {
        ocrRemaining(isMember: isMember, now: now) > 0
    }

    func canPlayTodayPlayback(isMember: Bool, now: Date = Date()) -> Bool {
        todayPlaybackRemaining(isMember: isMember, now: now) > 0
    }

    func markOCRImported(isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncDayIfNeeded(dayKey: Keys.ocrImportDayKey, usedKey: Keys.ocrImportUsedCount, now: now)
        let used = defaults.integer(forKey: Keys.ocrImportUsedCount)
        defaults.set(min(ocrDailyLimit, used + 1), forKey: Keys.ocrImportUsedCount)
    }

    func markTodayPlaybackStarted(isMember: Bool, now: Date = Date()) {
        guard !isMember else { return }
        syncDayIfNeeded(dayKey: Keys.todayPlaybackDayKey, usedKey: Keys.todayPlaybackUsedCount, now: now)
        let used = defaults.integer(forKey: Keys.todayPlaybackUsedCount)
        defaults.set(min(todayPlaybackDailyLimit, used + 1), forKey: Keys.todayPlaybackUsedCount)
    }

    private func syncDayIfNeeded(dayKey: String, usedKey: String, now: Date) {
        let key = Self.localDayKey(for: now)
        if defaults.string(forKey: dayKey) != key {
            defaults.set(key, forKey: dayKey)
            defaults.set(0, forKey: usedKey)
        }
    }

    private static func localDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

final class PlaybackService {
    func buildTodayPlayback(from items: [HomeItem], now: Date = Date()) -> PlaybackSnapshot {
        let calendar = Calendar.current
        let rows = items
            .filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(16)
            .map {
                PlaybackEntry(
                    id: $0.id,
                    title: $0.title,
                    category: $0.category.rawValue,
                    amount: $0.amount,
                    createdAt: $0.createdAt
                )
            }
        return PlaybackSnapshot(durationMs: 10_000, entries: Array(rows))
    }

    func buildWeekSummary(from items: [HomeItem], now: Date = Date()) -> SummaryPlayback {
        let calendar = Self.isoCalendar
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? now
        let rows = positiveItems(items, from: start, to: end)
        let rangeLabel = "\(Self.shortDateFormatter.string(from: start))-\(Self.shortDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: end) ?? now))"
        let total = rows.reduce(0) { $0 + $1.amount }
        let top = topCategoryStats(rows).first
        let ratio = total > 0 ? Int(round(((top?.amount ?? 0) / total) * 100)) : 0
        let highlight = highlightItem(in: rows)
        let active = dailyActivity(rows, start: start, days: 7)
        let busiest = active.max { lhs, rhs in
            lhs.count == rhs.count ? lhs.amount < rhs.amount : lhs.count < rhs.count
        }
        let quietest = active.min { lhs, rhs in
            lhs.amount == rhs.amount ? lhs.count < rhs.count : lhs.amount < rhs.amount
        }
        let title = "本周生活切片"
        let weekSeed = "week-\(SummaryPlaybackQuotaStore().currentWeekKey(now: now))"
        let weekValues: [String: String] = [
            "rangeLabel": rangeLabel,
            "count": "\(rows.count)",
            "total": Self.money(total),
            "busiestDay": busiest?.label ?? "本周",
            "quietestDay": quietest?.label ?? "某一天",
            "topCategory": top?.category ?? "日常",
            "ratio": "\(ratio)"
        ]

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "week-\(SummaryPlaybackQuotaStore().currentWeekKey(now: now))",
                range: .week,
                title: title,
                rangeLabel: rangeLabel,
                teaserLine: "这周还没有记录，先记几笔再来看切片。",
                count: 0,
                total: 0,
                topCategory: nil,
                topCategoryRatio: 0,
                chapters: []
            )
        }

        var chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "week-intro",
                title: "这一周",
                metrics: ["count": "\(rows.count)", "total": Self.money(total), "range": rangeLabel],
                narration: PlaybackCopyPool.narration(
                    chapterId: rows.count < 3 ? "week-weak-intro" : "week-intro",
                    seed: weekSeed,
                    values: weekValues
                ),
                durationSec: 6
            )
        ]

        if rows.count >= 3 {
            chapters.append(
                SummaryChapter(
                    id: "week-rhythm",
                    title: "节奏起伏",
                    metrics: [
                        "busiestDay": busiest?.label ?? "本周",
                        "quietestDay": quietest?.label ?? "本周",
                        "count": "\(busiest?.count ?? 0)"
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-rhythm",
                        seed: weekSeed,
                        values: weekValues
                    ),
                    durationSec: 7
                )
            )
        }

        chapters.append(
            SummaryChapter(
                id: "week-top-category",
                title: "生活主料",
                metrics: [
                    "category": top?.category ?? "日常",
                    "ratio": "\(ratio)",
                    "amount": Self.money(top?.amount ?? 0)
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "week-top-category",
                    seed: weekSeed,
                    values: weekValues
                ),
                durationSec: 7
            )
        )

        if rows.count >= 3, let highlight {
            let day = Self.weekdayFormatter.string(from: highlight.createdAt)
            let highlightValues = weekValues.merging([
                "highlightTitle": highlight.title,
                "highlightAmount": Self.money(highlight.amount),
                "highlightDayLabel": day
            ]) { current, _ in current }
            chapters.append(
                SummaryChapter(
                    id: "week-highlight",
                    title: "印象一笔",
                    metrics: [
                        "title": highlight.title,
                        "amount": Self.money(highlight.amount),
                        "day": day
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-highlight",
                        seed: weekSeed,
                        values: highlightValues
                    ),
                    durationSec: 7
                )
            )
        }

        let weak = rows.count < 3
        chapters.append(
            SummaryChapter(
                id: "week-outro",
                title: weak ? "再多一点" : "下周再叙",
                metrics: ["count": "\(rows.count)", "total": Self.money(total)],
                narration: PlaybackCopyPool.narration(
                    chapterId: weak ? "week-weak-outro" : "week-outro",
                    seed: weekSeed,
                    values: weekValues
                ),
                durationSec: weak ? 6 : 7
            )
        )

        return SummaryPlayback(
            id: "week-\(SummaryPlaybackQuotaStore().currentWeekKey(now: now))",
            range: .week,
            title: title,
            rangeLabel: rangeLabel,
            teaserLine: weekTeaserLine(busiest: busiest, top: top, ratio: ratio, rows: rows),
            count: rows.count,
            total: total,
            topCategory: top?.category,
            topCategoryRatio: ratio,
            chapters: chapters
        )
    }

    func buildWeeklyShareCardPayload(from items: [HomeItem], summary: SummaryPlayback? = nil, now: Date = Date()) -> WeeklyShareCardPayload? {
        let calendar = Self.isoCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let rows = positiveItems(items, from: interval.start, to: interval.end)
        guard !rows.isEmpty else { return nil }

        let total = rows.reduce(0) { $0 + $1.amount }
        let top = topCategoryStats(rows).first
        let topAmount = top?.amount ?? 0
        let ratio = total > 0 ? topAmount / total : 0
        let builtSummary = summary ?? buildWeekSummary(from: items, now: now)
        let trend = dailyActivity(rows, start: interval.start, days: 7).map { activity in
            (Self.shortWeekdayFormatter.string(from: activity.date), activity.amount)
        }
        let period = "\(Self.dotDateFormatter.string(from: interval.start)) ~ \(Self.dotDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? now))"
        let closing = builtSummary.chapters.last?.narration.plain ?? "这一周已经留下了可以回看的生活痕迹。"

        return WeeklyShareCardPayload(
            weekTotal: total,
            topCategory: top?.category ?? "日常",
            recordCount: rows.count,
            dailyTrend: trend,
            topCategoryRatio: ratio,
            headline: builtSummary.teaserLine,
            subtitle: closing,
            periodText: period
        )
    }

    func buildMonthSummary(from items: [HomeItem], now: Date = Date()) -> SummaryPlayback {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? now
        let rows = positiveItems(items, from: start, to: end)
        let total = rows.reduce(0) { $0 + $1.amount }
        let title = "本月生活章"
        let rangeLabel = Self.monthFormatter.string(from: now)
        let top = topCategoryStats(rows).first
        let ratio = total > 0 ? Int(round(((top?.amount ?? 0) / total) * 100)) : 0

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "month-\(Self.monthKeyFormatter.string(from: now))",
                range: .month,
                title: title,
                rangeLabel: rangeLabel,
                teaserLine: "这个月还没有记录，先记几笔再来看生活章。",
                count: 0,
                total: 0,
                topCategory: nil,
                topCategoryRatio: 0,
                chapters: []
            )
        }

        let activeDays = Set(rows.map { calendar.startOfDay(for: $0.createdAt) }).count
        let segments = monthSegments(rows, in: start, calendar: calendar)
        let leadingSegment = segments.max { $0.amount < $1.amount }
        let previousRows = previousMonthItems(from: items, now: now)
        let previousTotal = previousRows.reduce(0) { $0 + $1.amount }
        let momPercent = monthOverMonthText(current: total, previous: previousTotal)
        let changeText = monthlyChangeText(current: rows, previous: previousRows, segments: segments)
        let monthSeed = "month-\(Self.monthKeyFormatter.string(from: now))"
        let monthValues: [String: String] = [
            "rangeLabel": rangeLabel,
            "count": "\(rows.count)",
            "total": Self.money(total),
            "activeDays": "\(activeDays)",
            "momPercent": momPercent ?? "",
            "earlyCount": "\(segments[0].count)",
            "earlyAmount": Self.money(segments[0].amount),
            "midAmount": Self.money(segments[1].amount),
            "lateAmount": Self.money(segments[2].amount),
            "leadingSegment": leadingSegment?.label ?? "其中一段",
            "topCategory": top?.category ?? "日常",
            "ratio": "\(ratio)",
            "changeHint": changeText
        ]

        let chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "month-intro",
                title: "\(rangeLabel) 总览",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "activeDays": "\(activeDays)",
                    "momPercent": momPercent ?? ""
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-intro",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-early",
                title: "上旬",
                metrics: ["label": segments[0].label, "amount": Self.money(segments[0].amount), "count": "\(segments[0].count)"],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-early",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-middle-late",
                title: "中下旬",
                metrics: [
                    "middle": Self.money(segments[1].amount),
                    "late": Self.money(segments[2].amount),
                    "leading": leadingSegment?.label ?? "本月"
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-middle-late",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 9
            ),
            SummaryChapter(
                id: "month-composition",
                title: "生活构成",
                metrics: ["category": top?.category ?? "日常", "ratio": "\(ratio)", "amount": Self.money(top?.amount ?? 0)],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-composition",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 9
            ),
            SummaryChapter(
                id: "month-change",
                title: "变化点",
                metrics: ["change": changeText],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-change",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-action",
                title: "月末小结",
                metrics: ["total": Self.money(total), "topCategory": top?.category ?? "日常"],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-action",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            )
        ]

        return SummaryPlayback(
            id: "month-\(Self.monthKeyFormatter.string(from: now))",
            range: .month,
            title: title,
            rangeLabel: rangeLabel,
            teaserLine: monthTeaserLine(segments: segments, top: top, ratio: ratio, changeText: changeText),
            count: rows.count,
            total: total,
            topCategory: top?.category,
            topCategoryRatio: ratio,
            chapters: chapters
        )
    }

    private struct CategoryAmount {
        let category: String
        let amount: Double
    }

    private struct DayActivity {
        let date: Date
        let label: String
        let count: Int
        let amount: Double
    }

    private struct MonthSegment {
        let label: String
        let count: Int
        let amount: Double
    }

    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let dotDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter
    }()

    static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        return calendar
    }

    private func positiveItems(_ items: [HomeItem], from start: Date, to end: Date) -> [HomeItem] {
        items
            .filter { $0.amount > 0 && $0.createdAt >= start && $0.createdAt < end }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func topCategoryStats(_ items: [HomeItem]) -> [CategoryAmount] {
        let bucket = Dictionary(grouping: items, by: { $0.category.rawValue })
            .mapValues { rows in rows.reduce(0) { $0 + max($1.amount, 0) } }
        return bucket
            .map { CategoryAmount(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private func highlightItem(in items: [HomeItem]) -> HomeItem? {
        let candidates = items.filter { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return false }
            let genericTitles = [
                item.category.rawValue,
                item.category.label,
                item.category.displayName,
                "\(item.category.rawValue)消费",
                "未命名记录"
            ]
            return !genericTitles.contains(title)
        }
        if let titled = candidates.max(by: { lhs, rhs in
            lhs.amount == rhs.amount ? lhs.title.count < rhs.title.count : lhs.amount < rhs.amount
        }) {
            return titled
        }
        return items.max { $0.amount < $1.amount }
    }

    private func dailyActivity(_ items: [HomeItem], start: Date, days: Int) -> [DayActivity] {
        let calendar = Self.isoCalendar
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayItems = items.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            return DayActivity(
                date: date,
                label: Self.weekdayFormatter.string(from: date),
                count: dayItems.count,
                amount: dayItems.reduce(0) { $0 + $1.amount }
            )
        }
    }

    private func monthSegments(_ items: [HomeItem], in start: Date, calendar: Calendar) -> [MonthSegment] {
        let labels = ["上旬", "中旬", "下旬"]
        return labels.enumerated().map { index, label in
            let rows = items.filter { item in
                let day = calendar.component(.day, from: item.createdAt)
                switch index {
                case 0: return day <= 10
                case 1: return day >= 11 && day <= 20
                default: return day >= 21
                }
            }
            return MonthSegment(label: label, count: rows.count, amount: rows.reduce(0) { $0 + $1.amount })
        }
    }

    private func weekTeaserLine(busiest: DayActivity?, top: CategoryAmount?, ratio: Int, rows: [HomeItem]) -> String {
        if rows.count < 3 {
            return "这周已有 \(rows.count) 笔记录，再多一点就能讲得更完整。"
        }
        let topText = top.map { "\($0.category)约占\(ratio)%" } ?? "日常开始有了轮廓"
        return "\(busiest?.label ?? "本周")最忙，\(topText)。"
    }

    private func monthTeaserLine(segments: [MonthSegment], top: CategoryAmount?, ratio: Int, changeText: String) -> String {
        let leading = segments.max { $0.amount < $1.amount }?.label ?? "这个月"
        if let top {
            return "\(leading)更热闹，\(top.category)约占\(ratio)%。"
        }
        return changeText
    }

    private func previousMonthItems(from items: [HomeItem], now: Date) -> [HomeItem] {
        let calendar = Calendar.current
        guard let currentMonth = calendar.dateInterval(of: .month, for: now),
              let previousStart = calendar.date(byAdding: .month, value: -1, to: currentMonth.start),
              let previous = calendar.dateInterval(of: .month, for: previousStart) else {
            return []
        }
        return positiveItems(items, from: previous.start, to: previous.end)
    }

    private func monthOverMonthText(current: Double, previous: Double) -> String? {
        guard current > 0, previous > 0 else { return nil }
        let diff = (current - previous) / previous * 100
        let sign = diff >= 0 ? "+" : "-"
        return "\(sign)\(Int(abs(diff).rounded()))%"
    }

    private func monthlyChangeText(current: [HomeItem], previous: [HomeItem], segments: [MonthSegment]) -> String {
        let currentCategories = Set(current.map(\.category.rawValue))
        let previousCategories = Set(previous.map(\.category.rawValue))
        if let fresh = currentCategories.subtracting(previousCategories).sorted().first {
            return "这个月新出现了「\(fresh)」分类，是一处新的生活记忆点。"
        }
        let streak = longestRecordStreak(in: current)
        if streak >= 3 {
            return "这个月最长连续 \(streak) 天有记录，生活节奏被接住了。"
        }
        if let leading = segments.max(by: { $0.amount < $1.amount }), leading.amount > 0 {
            return "\(leading.label)最热闹，留下 \(leading.count) 笔、\(Self.money(leading.amount)) 的生活痕迹。"
        }
        if let first = current.first, let last = current.last {
            let days = max(1, Calendar.current.dateComponents([.day], from: first.createdAt, to: last.createdAt).day ?? 1)
            return "记录从 \(Self.shortDateFormatter.string(from: first.createdAt)) 延续到 \(Self.shortDateFormatter.string(from: last.createdAt))，跨度 \(days) 天。"
        }
        return "这个月已经留下了可以回看的生活痕迹。"
    }

    private func longestRecordStreak(in items: [HomeItem]) -> Int {
        let calendar = Calendar.current
        let days = Array(Set(items.map { calendar.startOfDay(for: $0.createdAt) })).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<days.count {
            let delta = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if delta == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    private static func money(_ value: Double) -> String {
        moneyFormatter.string(from: NSNumber(value: value)) ?? "¥\(Int(value.rounded()))"
    }
}

