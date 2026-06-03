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
    let count: Int
    let total: Double
    let topCategory: String?
    let topCategoryRatio: Int
    let chapters: [SummaryChapter]
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

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "week-\(SummaryPlaybackQuotaStore().currentWeekKey(now: now))",
                range: .week,
                title: title,
                rangeLabel: rangeLabel,
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
                narration: SummaryNarration(
                    warm: "小窝陪你看了 \(rangeLabel)，\(rows.count) 笔小记录，一共 \(Self.money(total))。",
                    plain: "\(rangeLabel)：\(rows.count) 笔，支出 \(Self.money(total))。"
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
                        "amount": Self.money(busiest?.amount ?? 0)
                    ],
                    narration: SummaryNarration(
                        warm: "最忙的是 \(busiest?.label ?? "本周")；\(quietest?.label ?? "某一天") 几乎没花钱，节奏很分明。",
                        plain: "支出集中在 \(busiest?.label ?? "本周")，\(quietest?.label ?? "某一天") 最低。"
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
                narration: SummaryNarration(
                    warm: "大约 \(ratio)% 花在「\(top?.category ?? "日常")」上，像这周日常的主料。",
                    plain: "「\(top?.category ?? "日常")」约占 \(ratio)% 。"
                ),
                durationSec: 7
            )
        )

        if rows.count >= 3, let highlight {
            let day = Self.weekdayFormatter.string(from: highlight.createdAt)
            chapters.append(
                SummaryChapter(
                    id: "week-highlight",
                    title: "印象一笔",
                    metrics: [
                        "title": highlight.title,
                        "amount": Self.money(highlight.amount),
                        "day": day
                    ],
                    narration: SummaryNarration(
                        warm: "印象最深的一笔：\(day) · \(highlight.title)，\(Self.money(highlight.amount))。",
                        plain: "单笔最高：\(highlight.title)，\(Self.money(highlight.amount))（\(day)）。"
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
                narration: SummaryNarration(
                    warm: weak ? "还只有 \(rows.count) 笔，再多记几天，小窝能讲得更完整。" : "这周有在认真记录生活，小窝下周再陪你叙。",
                    plain: weak ? "记录较少（\(rows.count) 笔），补充后切片会更准确。" : "本周记录完整，下周可再看切片。"
                ),
                durationSec: weak ? 6 : 7
            )
        )

        return SummaryPlayback(
            id: "week-\(SummaryPlaybackQuotaStore().currentWeekKey(now: now))",
            range: .week,
            title: title,
            rangeLabel: rangeLabel,
            count: rows.count,
            total: total,
            topCategory: top?.category,
            topCategoryRatio: ratio,
            chapters: chapters
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
        let changeText = monthlyChangeText(rows)

        let chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "month-intro",
                title: "\(rangeLabel) 总览",
                metrics: ["count": "\(rows.count)", "total": Self.money(total), "activeDays": "\(activeDays)"],
                narration: SummaryNarration(
                    warm: "这个月小窝陪你收下 \(rows.count) 笔记录，\(activeDays) 天有生活痕迹，一共 \(Self.money(total))。",
                    plain: "\(rangeLabel)：\(rows.count) 笔，\(activeDays) 个记录日，支出 \(Self.money(total))。"
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-early",
                title: "上旬",
                metrics: ["label": segments[0].label, "amount": Self.money(segments[0].amount), "count": "\(segments[0].count)"],
                narration: SummaryNarration(
                    warm: "上旬记录 \(segments[0].count) 笔，花了 \(Self.money(segments[0].amount))，像月初慢慢铺开的底色。",
                    plain: "上旬 \(segments[0].count) 笔，支出 \(Self.money(segments[0].amount))。"
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
                narration: SummaryNarration(
                    warm: "中旬 \(Self.money(segments[1].amount))，下旬 \(Self.money(segments[2].amount))；\(leadingSegment?.label ?? "其中一段")更热闹一点。",
                    plain: "中旬支出 \(Self.money(segments[1].amount))，下旬支出 \(Self.money(segments[2].amount))。"
                ),
                durationSec: 9
            ),
            SummaryChapter(
                id: "month-composition",
                title: "生活构成",
                metrics: ["category": top?.category ?? "日常", "ratio": "\(ratio)", "amount": Self.money(top?.amount ?? 0)],
                narration: SummaryNarration(
                    warm: "「\(top?.category ?? "日常")」约占 \(ratio)% ，是这个月最明显的一块生活拼图。",
                    plain: "「\(top?.category ?? "日常")」占比约 \(ratio)% 。"
                ),
                durationSec: 9
            ),
            SummaryChapter(
                id: "month-change",
                title: "变化点",
                metrics: ["change": changeText],
                narration: SummaryNarration(
                    warm: changeText,
                    plain: changeText
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-action",
                title: "月末小结",
                metrics: ["total": Self.money(total), "topCategory": top?.category ?? "日常"],
                narration: SummaryNarration(
                    warm: "这个月的节奏已经有轮廓了，可以再看一次月度复盘，把下个月安排得轻一点。",
                    plain: "本月生活章已生成，可继续查看月度复盘。"
                ),
                durationSec: 8
            )
        ]

        return SummaryPlayback(
            id: "month-\(Self.monthKeyFormatter.string(from: now))",
            range: .month,
            title: title,
            rangeLabel: rangeLabel,
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

    private func monthlyChangeText(_ items: [HomeItem]) -> String {
        let categories = Array(Set(items.map(\.category.rawValue))).sorted()
        if categories.count >= 2 {
            return "这个月出现了「\(categories[0])」和「\(categories[1])」等 \(categories.count) 类生活记录。"
        }
        if let first = items.first, let last = items.last {
            let days = max(1, Calendar.current.dateComponents([.day], from: first.createdAt, to: last.createdAt).day ?? 1)
            return "记录从 \(Self.shortDateFormatter.string(from: first.createdAt)) 延续到 \(Self.shortDateFormatter.string(from: last.createdAt))，跨度 \(days) 天。"
        }
        return "这个月已经留下了可以回看的生活痕迹。"
    }

    private static func money(_ value: Double) -> String {
        moneyFormatter.string(from: NSNumber(value: value)) ?? "¥\(Int(value.rounded()))"
    }
}

