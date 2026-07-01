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

struct ShareInsightSignal: Equatable {
    enum CategoryContext: Equatable {
        case dining
        case breakfast
        case coffee
        case commute
        case travel
        case medical
        case medicine
        case fitness
        case care
        case groceries
        case homeSupply
        case shopping
        case lodging
        case social
        case general
    }

    enum Kind: Equatable {
        case sceneTop(signal: LifeSceneSignal, count: Int)
        case brandTop(name: String, count: Int, brandId: String?)
        case categoryTop(category: HomeItem.Category, count: Int, context: CategoryContext)
        case busiestDay(label: String, count: Int)
        case lifeMark(kind: LifeMarkKind, title: String, line: String, label: String, count: Int)
        case lifeTitle(text: String)
        case weakData(recordCount: Int)
    }

    let kind: Kind
    let recordCount: Int
    let activeDays: Int
}

struct ShareInsight: Equatable {
    let fact: String
    let care: String
    let footnote: String
    let tags: [String]
}

struct WeeklyShareCategorySlice: Equatable {
    let label: String
    let count: Int
    let ratio: Double
}

struct WeeklyShareCardPayload {
    let weekTotal: Double
    let topCategory: String
    let recordCount: Int
    let primaryMetricCount: Int
    let primaryMetricEmoji: String
    let dailyTrend: [(String, Double)]
    let dailyCountTrend: [(String, Int)]
    let categorySlices: [WeeklyShareCategorySlice]
    let topCategoryRatio: Double
    let headline: String
    let subtitle: String
    let anchorLine: String?
    let lifeMarkLine: String?
    let contextLine: String?
    let emotionLine: String?
    let periodText: String
    let insight: ShareInsight
}

struct PlaybackMoment: Equatable {
    enum Source: String, Equatable {
        case title
        case emotionTag
    }

    let item: HomeItem
    let text: String
    let source: Source
    let score: Int
}

struct PlaybackMomentSelection: Equatable {
    let materials: [PlaybackMoment]
    let primary: PlaybackMoment?
    let scentWords: [String]

    func first(excluding itemID: UUID?) -> PlaybackMoment? {
        first(excluding: Set([itemID].compactMap { $0 }))
    }

    func first(excluding itemIDs: Set<UUID>) -> PlaybackMoment? {
        materials.first { material in
            !itemIDs.contains(material.item.id)
        }
    }

    func voiceText(for range: SummaryPlaybackRange) -> String {
        primary?.text ?? PlaybackMomentSelector.honestNoVoiceText(for: range)
    }

    var scentText: String {
        scentWords.isEmpty ? PlaybackMomentSelector.honestNoScentText : scentWords.joined(separator: "、")
    }
}


final class PlaybackService {
    private let momentSelector = PlaybackMomentSelector()

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

    func buildWeekSummary(from items: [HomeItem], now: Date = Date(), copySeed: String = "") -> SummaryPlayback {
        let calendar = Self.isoCalendar
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? now
        let rows = positiveItems(items, from: start, to: end)
        let rangeLabel = "\(Self.shortDateFormatter.string(from: start))-\(Self.shortDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: end) ?? now))"
        let total = rows.reduce(0) { $0 + $1.amount }
        let top = topCategoryStats(rows).first
        let ratio = total > 0 ? Int(round(((top?.amount ?? 0) / total) * 100)) : 0
        let active = dailyActivity(rows, start: start, days: 7)
        let busiest = active.max { lhs, rhs in
            lhs.count == rhs.count ? lhs.amount < rhs.amount : lhs.count < rhs.count
        }
        let title = "本周回放"
        let weekKey = SummaryPlaybackQuotaStore().currentWeekKey(now: now)
        let weekSeed = playbackCopySeed(base: "week-\(weekKey)", suffix: copySeed)

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "week-\(weekKey)",
                range: .week,
                title: title,
                rangeLabel: rangeLabel,
                teaserLine: "这周还没有记录，先记几笔再回来听。",
                count: 0,
                total: 0,
                topCategory: nil,
                topCategoryRatio: 0,
                chapters: []
            )
        }

        let echoAnchor = EchoAnchorService.shared.pickEchoAnchor(items: rows, periodKey: weekKey, now: now)
        let selection = momentSelector.select(from: rows, periodKey: weekKey, range: .week, now: now, echoAnchor: echoAnchor)
        let primaryVoice = selection.primary
        let primaryVoiceID = primaryVoice?.item.id
        let primaryVoiceIDs = Set([primaryVoiceID].compactMap { $0 })
        let secondaryVoice = selection.first(excluding: primaryVoiceIDs)
        let busiestRows = busiest.map { day in rows.filter { calendar.isDate($0.createdAt, inSameDayAs: day.date) } } ?? []
        let busiestSelection = momentSelector.select(from: busiestRows, periodKey: weekKey, range: .week, now: now)
        let busiestMaterial = busiestSelection.first(excluding: primaryVoiceIDs)
        let recurringLine = recurringTraceLine(
            current: rows,
            previous: previousWeekItems(from: items, now: now),
            rangeName: "上周"
        )
        let scentText = selection.scentText
        let scentWords = selection.scentWords
        let voiceTitle1 = selection.voiceText(for: .week)
        let voiceTitle2 = secondaryVoice?.text ?? voiceTitle1
        let busiestTitle = busiestMaterial?.text
            ?? busiestFallbackTitle(from: busiestRows, excluding: primaryVoiceID)
            ?? "这天的几笔记录"
        let photoMemoryLine = photoMemoryLine(in: rows, range: .week)
        let sceneMemoryLine = weeklySceneMemoryLine(rows) ?? photoMemoryLine
        let emotionSignal = primaryVoice?.item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lifeMark = LifeMarkService
            .aggregates(for: rows, allItems: items, isMember: true, now: now, limit: 1)
            .first
        let lifeMarkTitle = lifeMark?.title ?? sceneMemoryTitle(from: sceneMemoryLine, fallback: voiceTitle1)
        let lifeMarkLine = playbackLifeMarkLine(
            lifeMark,
            fallback: sceneMemoryLine ?? "这一周最清楚的一格，是「\(voiceTitle1)」。"
        )
        let presenceSupportLine = lifeMark == nil ? (sceneMemoryLine ?? "") : (photoMemoryLine ?? "")
        let rhythmSupportLine = sceneMemoryLineForItem(busiestMaterial?.item)
            ?? sceneMemoryLineForRows(busiestRows, excluding: primaryVoiceID)
            ?? photoMemoryLine(in: busiestRows, excluding: primaryVoiceID, range: .week)
            ?? busiestFallbackSupportLine(from: busiestRows, excluding: primaryVoiceID)
            ?? ""
        let voiceSupportLine = sceneMemoryLineForItem(primaryVoice?.item)
            ?? photoMemoryLine(for: primaryVoice?.item)
            ?? ""
        let scentSupportLine = weeklyScentSupportLine(
            sceneLine: sceneMemoryLine,
            recurringLine: recurringLine
        )
        let echoSentence = echoAnchor
            .map { EchoAnchorService.shared.formatEchoAnchorSentence($0) }
            .flatMap { $0.isEmpty ? nil : $0 }
        let weekValues: [String: String] = [
            "rangeLabel": rangeLabel,
            "count": "\(rows.count)",
            "total": Self.money(total),
            "busiestDay": busiest?.label ?? "本周",
            "busiestDayShort": busiest.map { Self.shortWeekdayFormatter.string(from: $0.date) } ?? "本周",
            "busiestCount": "\(busiest?.count ?? 0)",
            "busiestTitle": busiestTitle,
            "voiceTitle1": voiceTitle1,
            "voiceTitle2": voiceTitle2,
            "emotionTag": emotionSignal,
            "scentWord1": scentWords.indices.contains(0) ? scentWords[0] : PlaybackMomentSelector.honestNoScentText,
            "scentWord2": scentWords.indices.contains(1) ? scentWords[1] : "",
            "scentWord3": scentWords.indices.contains(2) ? scentWords[2] : "",
            "scentWords": scentText,
            "topCategory": top?.category ?? "日常",
            "ratio": "\(ratio)",
            "echoLine": echoSentence ?? "",
            "sceneMemoryLine": sceneMemoryLine ?? lifeMarkLine,
            "contextLine": sceneMemoryLine ?? "",
            "lifeMarkTitle": lifeMarkTitle,
            "lifeMarkLine": lifeMarkLine
        ]

        var chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "week-presence",
                title: "这一周",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "range": rangeLabel,
                    "lifeMarkLine": lifeMarkLine,
                    "sceneMemoryLine": presenceSupportLine,
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: rows.count < 3 ? "week-weak-presence" : "week-presence",
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
                    title: "哪天最热",
                    metrics: [
                        "busiestDay": busiest?.label ?? "本周",
                        "busiestTitle": busiestTitle,
                        "count": "\(busiest?.count ?? 0)",
                        "sceneMemoryLine": rhythmSupportLine,
                        "emotionTag": emotionSignal
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-rhythm",
                        seed: weekSeed,
                        values: weekValues
                    ),
                    durationSec: 7
                )
            )
            chapters.append(
                SummaryChapter(
                    id: "week-voices",
                    title: "留下的话",
                    metrics: [
                        "voiceTitle1": voiceTitle1,
                        "voiceTitle2": voiceTitle2,
                        "amount": primaryVoice.map { Self.money($0.item.amount) } ?? "",
                        "day": primaryVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? "",
                        "sceneMemoryLine": voiceSupportLine,
                        "emotionTag": emotionSignal
                    ],
                    narration: echoSentence.map { SummaryNarration(warm: $0, plain: $0) }
                        ?? PlaybackCopyPool.narration(
                            chapterId: "week-voices",
                            seed: weekSeed,
                            values: weekValues
                        ),
                    durationSec: 7
                )
            )
            chapters.append(
                SummaryChapter(
                    id: "week-scent",
                    title: "常冒头的词",
                    metrics: [
                        "scentWords": scentText,
                        "topCategory": top?.category ?? "日常",
                        "ratio": "\(ratio)",
                        "lifeMarkLine": lifeMarkLine,
                        "sceneMemoryLine": scentSupportLine,
                        "emotionTag": emotionSignal
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-scent",
                        seed: weekSeed,
                        values: weekValues
                    ),
                    durationSec: 7
                )
            )
        } else {
            chapters.append(
                SummaryChapter(
                    id: "week-voices",
                    title: "留下的话",
                    metrics: [
                        "voiceTitle1": voiceTitle1,
                        "amount": primaryVoice.map { Self.money($0.item.amount) } ?? "",
                        "day": primaryVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? "",
                        "sceneMemoryLine": voiceSupportLine,
                        "emotionTag": emotionSignal
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-weak-voices",
                        seed: weekSeed,
                        values: weekValues
                    ),
                    durationSec: 6
                )
            )
        }

        let weak = rows.count < 3
        chapters.append(
            SummaryChapter(
                id: "week-outro",
                title: weak ? "再多一点" : "先记到这里",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "topCategory": top?.category ?? "日常",
                    "lifeMarkLine": lifeMarkLine,
                    "sceneMemoryLine": sceneMemoryLine ?? "",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: weak ? "week-weak-outro" : "week-outro",
                    seed: weekSeed,
                    values: weekValues
                ),
                durationSec: weak ? 6 : 7
            )
        )

        return SummaryPlayback(
            id: "week-\(weekKey)",
            range: .week,
            title: title,
            rangeLabel: rangeLabel,
            teaserLine: weekTeaserLine(
                busiest: busiest,
                rows: rows,
                voiceTitle: voiceTitle1,
                scentWords: scentText,
                copySeed: weekSeed,
                lifeMarkLine: lifeMarkLine
            ),
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
        let activity = dailyActivity(rows, start: interval.start, days: 7)
        let trend = activity.map { activity in
            (Self.shortWeekdayFormatter.string(from: activity.date), activity.amount)
        }
        let countTrend = activity.map { activity in
            (Self.shortWeekdayFormatter.string(from: activity.date), activity.count)
        }
        let categorySlices = weeklyShareCategorySlices(from: rows)
        let period = "\(Self.dotDateFormatter.string(from: interval.start)) ~ \(Self.dotDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? now))"
        let closing = builtSummary.chapters.last?.narration.plain ?? "这一周已经留下了可以回看的记录。"
        let weeklyLifeMark = weeklyShareLifeMarkAggregate(rows: rows, allItems: items, now: now)
        let lifeMarkSubtitle = weeklyShareLifeMarkLine(from: weeklyLifeMark)
            ?? weeklyShareLifeMarkLine(from: builtSummary)
        let contextLine = weeklySceneMemoryLine(rows)
        let emotionLine = weeklyEmotionSignalLine(rows)
        let signal = weeklyShareInsightSignal(
            rows: rows,
            activity: activity,
            now: now,
            lifeMark: weeklyLifeMark
        )
        let insight = ShareInsightCopyPool.insight(
            for: signal,
            seed: "\(builtSummary.id)|\(period)|\(rows.count)"
        )
        let primaryMetric = weeklySharePrimaryMetric(from: signal)

        return WeeklyShareCardPayload(
            weekTotal: total,
            topCategory: top?.category ?? "日常",
            recordCount: rows.count,
            primaryMetricCount: primaryMetric.count,
            primaryMetricEmoji: primaryMetric.emoji,
            dailyTrend: trend,
            dailyCountTrend: countTrend,
            categorySlices: categorySlices,
            topCategoryRatio: ratio,
            headline: builtSummary.teaserLine,
            subtitle: lifeMarkSubtitle ?? closing,
            anchorLine: contextLine ?? weeklyShareAnchorLine(from: builtSummary),
            lifeMarkLine: lifeMarkSubtitle,
            contextLine: contextLine,
            emotionLine: emotionLine,
            periodText: period,
            insight: insight
        )
    }

    private func weeklyShareCategorySlices(from rows: [HomeItem]) -> [WeeklyShareCategorySlice] {
        let totalCount = max(rows.count, 1)
        let grouped = Dictionary(grouping: rows) { item in
            weeklyShareCompositionLabel(for: item)
        }
            .map { entry in
                (
                    label: entry.key,
                    count: entry.value.count,
                    latest: entry.value.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.latest > rhs.latest }
                return lhs.count > rhs.count
            }

        let visible = Array(grouped.prefix(3))
        let remaining = grouped.dropFirst(3).reduce(0) { $0 + $1.count }
        let slices = visible.map { item in
            WeeklyShareCategorySlice(
                label: item.label,
                count: item.count,
                ratio: Double(item.count) / Double(totalCount)
            )
        }
        guard remaining > 0 else { return slices }
        return slices + [
            WeeklyShareCategorySlice(
                label: "其他",
                count: remaining,
                ratio: Double(remaining) / Double(totalCount)
            )
        ]
    }

    private func weeklyShareCompositionLabel(for item: HomeItem) -> String {
        let scene = LifeSceneSemanticService.classify(item)
        switch scene.kind {
        case .breakfast:
            return "早餐"
        case .coffee:
            return "咖啡"
        case .quickMeal, .workMeal:
            return "吃饭"
        case .commute:
            return "通勤"
        case .cityRoute:
            return "出行"
        case .convenienceSupply:
            return "小补给"
        case .groceries:
            return "食材"
        case .homeSupply, .telecomBill:
            return "家用"
        case .shopping:
            return "购物"
        case .medicalVisit:
            return "就医"
        case .medicineCare:
            return "用药"
        case .fitness:
            return "锻炼"
        case .bodyCare:
            return "护理"
        case .lodging:
            return "住宿"
        case .social:
            return "人情"
        case .leisure:
            return "放松"
        case .errand:
            return "办事"
        case .general:
            return item.category.label
        }
    }

    private func weeklySharePrimaryMetric(from signal: ShareInsightSignal) -> (count: Int, emoji: String) {
        switch signal.kind {
        case let .sceneTop(scene, count):
            return (count, weeklyShareEmoji(for: scene.kind))
        case let .brandTop(name, count, brandId):
            return (count, weeklyShareBrandEmoji(name: name, brandId: brandId))
        case let .categoryTop(category, count, context):
            return (count, weeklyShareEmoji(for: category, context: context))
        case let .busiestDay(_, count):
            return (count, "📌")
        case let .lifeMark(_, _, _, _, count):
            return (count, "✨")
        case .lifeTitle:
            return (signal.recordCount, "📝")
        case let .weakData(recordCount):
            return (recordCount, "📝")
        }
    }

    private func weeklyShareEmoji(for kind: LifeSceneKind) -> String {
        switch kind {
        case .breakfast:
            return "🥣"
        case .quickMeal, .workMeal:
            return "🍜"
        case .coffee:
            return "☕"
        case .commute, .cityRoute:
            return "🚌"
        case .convenienceSupply, .groceries, .homeSupply, .telecomBill:
            return "🛒"
        case .shopping:
            return "🛍️"
        case .medicalVisit:
            return "🏥"
        case .medicineCare, .bodyCare:
            return "💊"
        case .fitness:
            return "🏃"
        case .lodging:
            return "🧳"
        case .social:
            return "🎁"
        case .leisure:
            return "🎮"
        case .errand, .general:
            return "📝"
        }
    }

    private func weeklyShareEmoji(
        for category: HomeItem.Category,
        context: ShareInsightSignal.CategoryContext
    ) -> String {
        switch context {
        case .breakfast:
            return "🥣"
        case .coffee:
            return "☕"
        case .dining:
            return "🍜"
        case .commute, .travel:
            return "🚌"
        case .medical:
            return "🏥"
        case .medicine, .care:
            return "💊"
        case .fitness:
            return "🏃"
        case .groceries, .homeSupply:
            return "🛒"
        case .shopping:
            return "🛍️"
        case .lodging:
            return "🧳"
        case .social:
            return "🎁"
        case .general:
            return weeklyShareEmoji(for: category)
        }
    }

    private func weeklyShareEmoji(for category: HomeItem.Category) -> String {
        switch category {
        case .transport:
            return "🚌"
        case .dining:
            return "🍜"
        case .health:
            return "🏃"
        case .shopping:
            return "🛍️"
        case .daily, .home:
            return "🛒"
        case .lodging:
            return "🧳"
        case .social:
            return "🎁"
        case .entertainment:
            return "🎮"
        case .other:
            return "📝"
        }
    }

    private func weeklyShareBrandEmoji(name: String, brandId: String?) -> String {
        let id = brandId ?? ""
        if ["luckin", "starbucks", "manner"].contains(id) { return "☕" }
        if ["metro_transit", "didi", "alipay_ride"].contains(id) { return "🚌" }
        if ["meituan", "eleme", "mcdonalds", "kfc"].contains(id) { return "🍜" }
        if ["familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia"].contains(id) { return "🛒" }
        if name.contains("咖啡") { return "☕" }
        if name.contains("地铁") || name.contains("公交") || name.contains("滴滴") || name.contains("打车") { return "🚌" }
        if name.contains("医院") || name.contains("门诊") || name.contains("体检") { return "🏥" }
        if name.contains("药店") || name.contains("药房") || name.contains("买药") { return "💊" }
        if name.contains("外卖") || name.contains("美团") || name.contains("饿了") { return "🍜" }
        if name.contains("便利") || name.contains("全家") || name.contains("罗森") { return "🛒" }
        return "📝"
    }

    private func weeklyShareInsightSignal(
        rows: [HomeItem],
        activity: [DayActivity],
        now: Date,
        lifeMark: LifeMarkAggregate?
    ) -> ShareInsightSignal {
        let activeDays = activeDayCount(rows)
        let base = (recordCount: rows.count, activeDays: activeDays)

        if let lifeMark,
           let lifeMarkLine = weeklyShareLifeMarkLine(from: lifeMark) {
            return ShareInsightSignal(
                kind: .lifeMark(
                    kind: lifeMark.kind,
                    title: lifeMark.title,
                    line: lifeMarkLine,
                    label: lifeMark.label,
                    count: lifeMark.count
                ),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if rows.count <= 2 {
            return ShareInsightSignal(
                kind: .weakData(recordCount: rows.count),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let scene = LifeSceneSemanticService.dominantScene(in: rows),
           scene.count >= 3 || Double(scene.count) / Double(max(rows.count, 1)) >= 0.40 {
            return ShareInsightSignal(
                kind: .sceneTop(signal: scene.signal, count: scene.count),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let brand = weeklyBrandTop(rows), brand.count >= 3 {
            return ShareInsightSignal(
                kind: .brandTop(name: brand.name, count: brand.count, brandId: brand.id),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let category = weeklyCategoryTop(rows),
           category.count >= 2 || Double(category.count) / Double(max(rows.count, 1)) >= 0.40 {
            let categoryRows = rows.filter { $0.category == category.category }
            return ShareInsightSignal(
                kind: .categoryTop(
                    category: category.category,
                    count: category.count,
                    context: weeklyCategoryContext(category: category.category, rows: categoryRows)
                ),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let busiest = activity.max(by: { lhs, rhs in
            lhs.count == rhs.count ? lhs.amount < rhs.amount : lhs.count < rhs.count
        }), busiest.count >= 3 {
            return ShareInsightSignal(
                kind: .busiestDay(label: Self.shortWeekdayFormatter.string(from: busiest.date), count: busiest.count),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let lifeTitle = weeklyLifeTitle(rows, now: now) {
            return ShareInsightSignal(
                kind: .lifeTitle(text: lifeTitle),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        return ShareInsightSignal(
            kind: .weakData(recordCount: rows.count),
            recordCount: base.recordCount,
            activeDays: base.activeDays
        )
    }

    private func weeklyBrandTop(_ rows: [HomeItem]) -> (id: String, name: String, count: Int, latest: Date)? {
        let grouped = rows.reduce(into: [String: (brand: MerchantBrandDefinition, count: Int, latest: Date)]()) { result, item in
            let brand = MerchantBrandCatalog.definition(for: item.merchantBrandId)
                ?? MerchantBrandCatalog.matchBrand(in: item.title)
            guard let brand else { return }
            let current = result[brand.id]
            result[brand.id] = (
                brand: brand,
                count: (current?.count ?? 0) + 1,
                latest: max(current?.latest ?? .distantPast, item.createdAt)
            )
        }
        return grouped
            .map { entry in
                (id: entry.key, name: entry.value.brand.displayName, count: entry.value.count, latest: entry.value.latest)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.latest > rhs.latest }
                return lhs.count > rhs.count
            }
            .first
    }

    private func weeklyCategoryTop(_ rows: [HomeItem]) -> (category: HomeItem.Category, count: Int, latest: Date)? {
        Dictionary(grouping: rows, by: \.category)
            .map { entry in
                (
                    category: entry.key,
                    count: entry.value.count,
                    latest: entry.value.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.latest > rhs.latest }
                return lhs.count > rhs.count
            }
            .first
    }

    private func weeklyCategoryContext(
        category: HomeItem.Category,
        rows: [HomeItem]
    ) -> ShareInsightSignal.CategoryContext {
        if let scene = LifeSceneSemanticService.dominantScene(in: rows) {
            switch scene.signal.kind {
            case .breakfast:
                return .breakfast
            case .coffee:
                return .coffee
            case .quickMeal, .workMeal:
                return .dining
            case .commute:
                return .commute
            case .cityRoute:
                return .travel
            case .medicalVisit:
                return .medical
            case .medicineCare:
                return .medicine
            case .fitness:
                return .fitness
            case .bodyCare:
                return .care
            case .groceries:
                return .groceries
            case .convenienceSupply, .homeSupply, .telecomBill:
                return .homeSupply
            case .shopping:
                return .shopping
            case .lodging:
                return .lodging
            case .social:
                return .social
            case .leisure, .errand, .general:
                break
            }
        }
        let text = rows
            .map { "\($0.title) \($0.displayEmotionTag) \($0.category.rawValue)" }
            .joined(separator: " ")
        switch category {
        case .dining:
            if containsAny(text, ["早餐", "早饭", "豆浆", "包子", "饭团", "早班", "上班前"]) { return .breakfast }
            if containsAny(text, ["咖啡", "瑞幸", "星巴克", "Manner", "奶茶", "饮品", "饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "柠檬茶", "水溶", "c100", "维C", "维c", "维他", "提神"]) { return .coffee }
            return .dining
        case .transport:
            if containsAny(text, ["上班", "下班", "到岗", "通勤", "早高峰", "晚高峰", "地铁", "公交", "轨道交通"]) { return .commute }
            return .travel
        case .health:
            if containsAny(text, ["医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "拍片", "验血", "口腔", "牙科"]) { return .medical }
            if containsAny(text, ["药店", "药房", "买药", "用药", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴"]) { return .medicine }
            if containsAny(text, ["健身", "跑步", "瑜伽", "运动", "训练", "球场", "游泳", "课程"]) { return .fitness }
            return .care
        case .daily:
            if containsAny(text, ["买菜", "食材", "盒马", "叮咚", "菜", "水果", "厨房", "饭桌"]) { return .groceries }
            return .homeSupply
        case .shopping:
            return .shopping
        case .lodging:
            return .lodging
        case .social:
            return .social
        case .home, .entertainment, .other:
            return .general
        }
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func weeklyLifeTitle(_ rows: [HomeItem], now: Date) -> String? {
        let periodKey = SummaryPlaybackQuotaStore().currentWeekKey(now: now)
        return rows
            .filter { $0.userEditedTitle == true }
            .compactMap { item -> (text: String, score: Int, date: Date)? in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard EchoAnchorService.shared.isEligibleLifeTraceTitle(title, item: item) else { return nil }
                return (title, PlaybackMaterialScoring.stableScore(item: item, periodKey: periodKey, now: now), item.createdAt)
            }
            .sorted {
                if $0.score == $1.score { return $0.date > $1.date }
                return $0.score > $1.score
            }
            .first?.text
    }

    private func activeDayCount(_ rows: [HomeItem]) -> Int {
        let calendar = Self.isoCalendar
        return Set(rows.map { item in
            let components = calendar.dateComponents([.year, .month, .day], from: item.createdAt)
            return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        }).count
    }

    func buildMonthSummary(from items: [HomeItem], now: Date = Date(), copySeed: String = "") -> SummaryPlayback {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? now
        let rows = positiveItems(items, from: start, to: end)
        let total = rows.reduce(0) { $0 + $1.amount }
        let title = "本月回放"
        let rangeLabel = Self.monthFormatter.string(from: now)
        let top = topCategoryStats(rows).first
        let ratio = total > 0 ? Int(round(((top?.amount ?? 0) / total) * 100)) : 0

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "month-\(Self.monthKeyFormatter.string(from: now))",
                range: .month,
                title: title,
                rangeLabel: rangeLabel,
                teaserLine: "这个月还没有记录，先记几笔再回来听。",
                count: 0,
                total: 0,
                topCategory: nil,
                topCategoryRatio: 0,
                chapters: []
            )
        }

        let activeDays = Set(rows.map { calendar.startOfDay(for: $0.createdAt) }).count
        let segments = monthSegments(rows, in: start, calendar: calendar)
        let previousRows = previousMonthItems(from: items, now: now)
        let previousTotal = previousRows.reduce(0) { $0 + $1.amount }
        let momPercent = monthOverMonthText(current: total, previous: previousTotal)
        let recurringLine = recurringTraceLine(current: rows, previous: previousRows, rangeName: "上个月")
        let changeText = copyWithRecurringLine(
            monthlyChangeText(current: rows, previous: previousRows, segments: segments),
            recurringLine
        )
        let monthKey = Self.monthKeyFormatter.string(from: now)
        let monthSeed = playbackCopySeed(base: "month-\(monthKey)", suffix: copySeed)
        let echoAnchor = EchoAnchorService.shared.pickEchoAnchor(items: rows, periodKey: monthKey, now: now)
        let selection = momentSelector.select(from: rows, periodKey: monthKey, range: .month, now: now, echoAnchor: echoAnchor)
        let primaryVoice = selection.primary
        let earlyRows = rows.filter { calendar.component(.day, from: $0.createdAt) <= 10 }
        let lateRows = rows.filter { calendar.component(.day, from: $0.createdAt) >= 11 }
        let earlySelection = momentSelector.select(from: earlyRows, periodKey: monthKey, range: .month, now: now)
        let lateSelection = momentSelector.select(from: lateRows, periodKey: monthKey, range: .month, now: now)
        let earlyVoice = earlySelection.primary ?? primaryVoice
        let earlyVoiceID = earlyVoice?.item.id
        let lateVoice = lateSelection.first(excluding: earlyVoiceID)
            ?? selection.first(excluding: earlyVoiceID)
            ?? primaryVoice
        let scentText = selection.scentText
        let voiceTitle1 = selection.voiceText(for: .month)
        let earlyVoiceTitle = earlyVoice?.text ?? PlaybackMomentSelector.honestNoVoiceText(for: .month)
        let lateVoiceTitle = lateVoice?.text ?? PlaybackMomentSelector.honestNoVoiceText(for: .month)
        let photoMemoryLine = photoMemoryLine(in: rows, range: .month)
        let monthContextLine = contextualMemoryLine(in: rows, range: .month) ?? weeklySceneMemoryLine(rows) ?? photoMemoryLine
        let emotionSignal = primaryVoice?.item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lifeMark = LifeMarkService
            .aggregates(for: rows, allItems: items, isMember: true, now: now, limit: 1)
            .first
        let lifeMarkTitle = lifeMark?.title ?? sceneMemoryTitle(from: nil, fallback: voiceTitle1)
        let lifeMarkLine = playbackLifeMarkLine(
            lifeMark,
            fallback: "这个月先从「\(voiceTitle1)」这一格想起。"
        )
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
            "topCategory": top?.category ?? "日常",
            "ratio": "\(ratio)",
            "changeHint": changeText,
            "voiceTitle1": voiceTitle1,
            "earlyVoiceTitle": earlyVoiceTitle,
            "lateVoiceTitle": lateVoiceTitle,
            "emotionTag": emotionSignal,
            "contextLine": monthContextLine ?? "",
            "scentWords": scentText,
            "lifeMarkTitle": lifeMarkTitle,
            "lifeMarkLine": lifeMarkLine
        ]

        let chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "month-opening",
                title: "\(rangeLabel) 开场",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "activeDays": "\(activeDays)",
                    "momPercent": momPercent ?? "",
                    "range": rangeLabel,
                    "voiceTitle1": voiceTitle1,
                    "lifeMarkLine": lifeMarkLine,
                    "sceneMemoryLine": monthContextLine ?? "",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-opening",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-early-voice",
                title: "月初的一句",
                metrics: [
                    "earlyVoiceTitle": earlyVoiceTitle,
                    "label": segments[0].label,
                    "amount": Self.money(segments[0].amount),
                    "count": "\(segments[0].count)",
                    "day": earlyVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? "",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-early-voice",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-late-voice",
                title: "后半月的一句",
                metrics: [
                    "lateVoiceTitle": lateVoiceTitle,
                    "middle": Self.money(segments[1].amount),
                    "late": Self.money(segments[2].amount),
                    "day": lateVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? "",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-late-voice",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-change",
                title: "变化点",
                metrics: [
                    "change": changeText,
                    "sceneMemoryLine": monthContextLine ?? "",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-change",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-scent",
                title: "常冒头的词",
                metrics: [
                    "scentWords": scentText,
                    "topCategory": top?.category ?? "日常",
                    "ratio": "\(ratio)",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-scent",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-outro",
                title: "下月再叙",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "lifeMarkLine": lifeMarkLine,
                    "sceneMemoryLine": monthContextLine ?? "",
                    "emotionTag": emotionSignal
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-outro",
                    seed: monthSeed,
                    values: monthValues
                ),
                durationSec: 7
            )
        ]

        return SummaryPlayback(
            id: "month-\(monthKey)",
            range: .month,
            title: title,
            rangeLabel: rangeLabel,
            teaserLine: monthTeaserLine(
                voiceTitle: voiceTitle1,
                scentWords: scentText,
                changeText: changeText,
                copySeed: monthSeed,
                rangeLabel: rangeLabel,
                lifeMarkLine: lifeMarkLine
            ),
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

    private struct CategoryMonthlyStat {
        let category: String
        let count: Int
        let amount: Double
    }

    private struct MonthlyCategoryChange {
        let category: String
        let current: CategoryMonthlyStat
        let previous: CategoryMonthlyStat?
        let amountDelta: Double
        let countDelta: Int
        let score: Double
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

    private func weekTeaserLine(
        busiest: DayActivity?,
        rows: [HomeItem],
        voiceTitle: String,
        scentWords: String,
        copySeed: String,
        lifeMarkLine: String
    ) -> String {
        if rows.count < 3 {
            return rows.count == 1
                ? "这周先留下「\(voiceTitle)」这一格。"
                : "这周先留下这几格，已经能听出一点生活的开头。"
        }
        let values = [
            "busiestDayShort": busiest?.label ?? "本周",
            "count": "\(rows.count)",
            "rangeLabel": "这一周",
            "voiceTitle1": voiceTitle,
            "scentWords": scentWords,
            "lifeMarkLine": lifeMarkLine
        ]
        return PlaybackCopyPool.weekTeaser(seed: copySeed, values: values)
    }

    private func weeklyShareAnchorLine(from summary: SummaryPlayback) -> String? {
        if let lifeMarkLine = weeklyShareLifeMarkLine(from: summary) {
            return lifeMarkLine
        }
        if let sceneLine = summary.chapters
            .compactMap({ $0.metrics["sceneMemoryLine"]?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return sceneLine
        }
        if let voices = summary.chapters.first(where: { $0.id == "week-voices" }) {
            if let title = voices.metrics["voiceTitle1"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                return title
            }
            let narration = voices.narration.plain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !narration.isEmpty {
                return narration
            }
        }
        return nil
    }

    private func weeklyShareLifeMarkLine(from summary: SummaryPlayback) -> String? {
        summary.chapters
            .compactMap { $0.metrics["lifeMarkLine"]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !EchoAnchorService.shared.isDirtyTraceTitle($0) }
    }

    private func weeklyShareLifeMarkAggregate(
        rows: [HomeItem],
        allItems: [HomeItem],
        now: Date
    ) -> LifeMarkAggregate? {
        let marks = LifeMarkService.aggregates(
            for: rows,
            allItems: allItems,
            isMember: true,
            now: now,
            limit: 4
        )
        return marks.sorted { lhs, rhs in
            let lhsRank = weeklyShareLifeMarkRank(lhs)
            let rhsRank = weeklyShareLifeMarkRank(rhs)
            if lhsRank == rhsRank {
                if lhs.priority == rhs.priority {
                    if lhs.count == rhs.count { return lhs.latestDate > rhs.latestDate }
                    return lhs.count > rhs.count
                }
                return lhs.priority < rhs.priority
            }
            return lhsRank < rhsRank
        }.first
    }

    private func weeklyShareLifeMarkRank(_ mark: LifeMarkAggregate) -> Int {
        switch mark.kind {
        case .milestone:
            return 0
        case .context:
            return 1
        case .scene:
            return 2
        case .streak:
            return 3
        }
    }

    private func weeklyShareLifeMarkLine(from aggregate: LifeMarkAggregate?) -> String? {
        guard let aggregate else { return nil }
        let line = playbackLifeMarkLine(aggregate, fallback: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty,
              !EchoAnchorService.shared.isDirtyTraceTitle(line) else {
            return nil
        }
        return line
    }

    private func weeklySceneMemoryLine(_ rows: [HomeItem]) -> String? {
        if let contextLine = contextualMemoryLine(in: rows) {
            return contextLine
        }
        guard let scene = LifeSceneSemanticService.dominantScene(in: rows),
              scene.count >= 2 else {
            return nil
        }
        return LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
    }

    private func photoMemoryLine(in rows: [HomeItem], excluding excludedID: UUID? = nil, range: SummaryPlaybackRange) -> String? {
        let photoRows = rows
            .filter { item in
                if let excludedID, item.id == excludedID { return false }
                return item.hasMemoryImages
            }
            .sorted { lhs, rhs in
                if lhs.memoryImages.count == rhs.memoryImages.count {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.memoryImages.count > rhs.memoryImages.count
            }
        guard let first = photoRows.first else { return nil }
        if photoRows.count >= 2 {
            let unit = range == .week ? "这周" : "这个月"
            return "\(unit)有 \(photoRows.count) 个带照片的时刻，照片让这些消费不只是数字。"
        }
        return photoMemoryLine(for: first)
    }

    private func photoMemoryLine(for item: HomeItem?) -> String? {
        guard let item, item.hasMemoryImages else { return nil }
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.isEmpty || EchoAnchorService.shared.isDirtyTraceTitle(title)
            ? item.category.rawValue
            : title
        let day = Self.shortWeekdayFormatter.string(from: item.createdAt)
        return "\(day)的「\(cleanTitle)」留了照片，以后回看会更像一段生活。"
    }

    private func sceneMemoryLineForItem(_ item: HomeItem?) -> String? {
        guard let item else { return nil }
        if let photoLine = photoMemoryLine(for: item) {
            return photoLine
        }
        if HomeItem.isLateWorkCommute(item),
           let line = HomeItem.lateWorkCommuteTraceLine(for: item) {
            return line
        }
        let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty,
              !EchoAnchorService.shared.isDirtyTraceTitle(tag) else {
            return nil
        }
        let text = "\(item.title) \(tag)"
        guard text.contains("雨天")
            || text.contains("下雨")
            || text.contains("雪天")
            || text.contains("第一次")
            || text.contains("第10次")
            || text.contains("第 10 次")
            || text.contains("连续")
            || text.contains("周末出门")
            || text.contains("周末路上") else {
            return nil
        }
        let day = Self.shortWeekdayFormatter.string(from: item.createdAt)
        return "\(day)这笔写着「\(tag)」，以后再看会知道当时发生了什么。"
    }

    private func sceneMemoryLineForRows(_ rows: [HomeItem], excluding excludedID: UUID?) -> String? {
        let scoped = rows.filter { item in
            if let excludedID, item.id == excludedID { return false }
            return true
        }
        return contextualMemoryLine(in: scoped)
            ?? photoMemoryLine(in: scoped, range: .week)
    }

    private func busiestFallbackTitle(from rows: [HomeItem], excluding excludedID: UUID?) -> String? {
        rows
            .filter { item in
                if let excludedID, item.id == excludedID { return false }
                return true
            }
            .sorted { lhs, rhs in
                if abs(lhs.amount - rhs.amount) < 0.001 {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.amount > rhs.amount
            }
            .first
            .map { item in
                let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                return title.isEmpty ? item.category.rawValue : title
            }
    }

    private func busiestFallbackSupportLine(from rows: [HomeItem], excluding excludedID: UUID?) -> String? {
        let scoped = rows.filter { item in
            if let excludedID, item.id == excludedID { return false }
            return true
        }
        guard scoped.count >= 2 else { return nil }
        let day = scoped.first.map { Self.shortWeekdayFormatter.string(from: $0.createdAt) } ?? "这天"
        return "\(day)不只留下一笔，几件小事叠在一起，才让这一天更明显。"
    }

    private func weeklyScentSupportLine(
        sceneLine: String?,
        recurringLine: String?
    ) -> String {
        if let recurring = recurringLine?.trimmingCharacters(in: .whitespacesAndNewlines),
           !recurring.isEmpty {
            return recurring
        }
        let scene = sceneLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !scene.isEmpty,
           !scene.contains("雨天通勤") {
            return scene
        }
        return ""
    }

    private func weeklyEmotionSignalLine(_ rows: [HomeItem]) -> String? {
        let ranked = rows.compactMap { item -> (text: String, score: Int, date: Date)? in
            let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !emotion.isEmpty,
                  emotion != HomeItem.inferEmotionTag(category: item.category, amount: item.amount),
                  !EchoAnchorService.shared.isDirtyTraceTitle(emotion) else {
                return nil
            }

            var score = 1
            if emotion.contains("第一次") { score += 5 }
            if emotion.contains("连续") { score += 4 }
            if emotion.contains("雨天") || emotion.contains("出行") { score += 3 }
            if emotion.contains("健身") || emotion.contains("恢复") { score += 3 }
            if emotion.contains("聚餐") || emotion.contains("朋友") { score += 3 }
            return (emotion, score, item.createdAt)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.date > rhs.date }
            return lhs.score > rhs.score
        }

        guard let best = ranked.first else { return nil }
        return "这周也写下了「\(best.text)」"
    }

    private func monthTeaserLine(
        voiceTitle: String,
        scentWords: String,
        changeText: String,
        copySeed: String,
        rangeLabel: String,
        lifeMarkLine: String
    ) -> String {
        let values = [
            "voiceTitle1": voiceTitle,
            "scentWords": scentWords,
            "changeHint": changeText,
            "rangeLabel": rangeLabel,
            "lifeMarkLine": lifeMarkLine
        ]
        return PlaybackCopyPool.monthTeaser(seed: copySeed, values: values)
    }

    private func playbackLifeMarkLine(_ aggregate: LifeMarkAggregate?, fallback: String) -> String {
        guard let aggregate else { return fallback }
        let detail = LifeMarkService.primaryLine(for: aggregate)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return fallback }

        switch aggregate.kind {
        case .context:
            return detail
        case .milestone:
            return "\(aggregate.title) 被放进这一段里，\(detail)"
        case .streak:
            return detail
        case .scene:
            return "\(aggregate.title) 这条线露了出来，\(detail)"
        }
    }

    private func sceneMemoryTitle(from line: String?, fallback: String) -> String {
        let trimmed = line?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.contains("雨") { return "天气里的生活线" }
        if trimmed.contains("第一次") { return "第一次的开始" }
        if trimmed.contains("连续") { return "连续出现的节奏" }
        if trimmed.contains("周末") { return "周末留下的片段" }
        return fallback
    }

    private func playbackCopySeed(base: String, suffix: String) -> String {
        let trimmed = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? base : "\(base)|\(trimmed)"
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

    private func previousWeekItems(from items: [HomeItem], now: Date) -> [HomeItem] {
        let calendar = Self.isoCalendar
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let previousStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start),
              let previous = calendar.dateInterval(of: .weekOfYear, for: previousStart) else {
            return []
        }
        return positiveItems(items, from: previous.start, to: previous.end)
    }

    private func copyWithRecurringLine(_ base: String, _ recurringLine: String?) -> String {
        guard let recurringLine,
              !recurringLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }
        return "\(base) \(recurringLine)"
    }

    private func recurringTraceLine(current: [HomeItem], previous: [HomeItem], rangeName: String) -> String? {
        guard current.count >= 2, previous.count >= 2 else { return nil }

        let currentTitles = traceTokenCounts(current, source: .title)
        let previousTitles = traceTokenCounts(previous, source: .title)
        if let title = strongestSharedToken(current: currentTitles, previous: previousTitles) {
            return "\(rangeName)也写过「\(title)」，这次它又回来了。"
        }

        let currentEmotions = traceTokenCounts(current, source: .emotionTag)
        let previousEmotions = traceTokenCounts(previous, source: .emotionTag)
        if let emotion = strongestSharedToken(current: currentEmotions, previous: previousEmotions) {
            return "\(rangeName)也标过「\(emotion)」，这次还能看见。"
        }

        let currentCategories = categoryCounts(current)
        let previousCategories = categoryCounts(previous)
        if let category = strongestSharedToken(current: currentCategories, previous: previousCategories, minimumCount: 2) {
            return "「\(category)」这条线延续到了这次记录里。"
        }

        return nil
    }

    private enum TraceTokenSource {
        case title
        case emotionTag
    }

    private func traceTokenCounts(_ items: [HomeItem], source: TraceTokenSource) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            let token: String?
            switch source {
            case .title:
                token = EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item)
                    ? item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    : nil
            case .emotionTag:
                let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
                token = (2...18).contains(emotion.count)
                    && emotion != HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
                    && !EchoAnchorService.shared.isDirtyTraceTitle(emotion)
                    ? emotion
                    : nil
            }
            if let token, !token.isEmpty {
                counts[token, default: 0] += 1
            }
        }
        return counts
    }

    private func categoryCounts(_ items: [HomeItem]) -> [String: Int] {
        items.reduce(into: [:]) { result, item in
            result[item.category.rawValue, default: 0] += 1
        }
    }

    private func strongestSharedToken(current: [String: Int], previous: [String: Int], minimumCount: Int = 1) -> String? {
        current.keys
            .filter { token in
                (current[token] ?? 0) >= minimumCount && (previous[token] ?? 0) >= minimumCount
            }
            .sorted {
                let leftScore = (current[$0] ?? 0) + (previous[$0] ?? 0)
                let rightScore = (current[$1] ?? 0) + (previous[$1] ?? 0)
                if leftScore == rightScore { return $0 < $1 }
                return leftScore > rightScore
            }
            .first
    }

    private func monthOverMonthText(current: Double, previous: Double) -> String? {
        guard current > 0, previous > 0 else { return nil }
        let diff = (current - previous) / previous * 100
        let sign = diff >= 0 ? "+" : "-"
        return "\(sign)\(Int(abs(diff).rounded()))%"
    }

    private func monthlyChangeText(current: [HomeItem], previous: [HomeItem], segments: [MonthSegment]) -> String {
        if let contextLine = contextualMemoryLine(in: current, range: .month) {
            return contextLine
        }
        if let photoLine = photoMemoryLine(in: current, range: .month) {
            return photoLine
        }
        if let change = meaningfulMonthlyCategoryChange(current: current, previous: previous) {
            if change.previous == nil {
                return "这个月「\(change.category)」开始露面，像是新添了一段生活侧面。"
            }
            if change.amountDelta >= 0 {
                return "这个月「\(change.category)」比上月更常回来，像一条更清楚的生活线。"
            } else {
                return "这个月「\(change.category)」比上月轻了一些，日子的重心也换了位置。"
            }
        }
        let streak = longestRecordStreak(in: current)
        if streak >= 3 {
            return "这个月有一段连续 \(streak) 天都有记录，回看时能看到那几天怎么接上。"
        }
        if let leading = segments.max(by: { $0.amount < $1.amount }), leading.amount > 0 {
            return "\(leading.label) 这一段更具体，是这个月中间更明显的一格。"
        }
        if let first = current.first, let last = current.last {
            let days = max(1, Calendar.current.dateComponents([.day], from: first.createdAt, to: last.createdAt).day ?? 1)
            return "这段从 \(Self.shortDateFormatter.string(from: first.createdAt)) 留到 \(Self.shortDateFormatter.string(from: last.createdAt))，中间隔着 \(days) 天真实日子。"
        }
        return "这个月已经有几格可以回看的生活。"
    }

    private func contextualMemoryLine(in rows: [HomeItem], range: SummaryPlaybackRange = .week) -> String? {
        if let item = rows.sorted(by: { $0.createdAt > $1.createdAt }).first(where: { HomeItem.isLateWorkCommute($0) }),
           let line = HomeItem.lateWorkCommuteTraceLine(for: item) {
            return line
        }
        let candidates = rows.compactMap { item -> (item: HomeItem, tag: String, score: Int)? in
            let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else { return nil }
            let text = "\(item.title) \(tag)"
            var score = 0
            if text.contains("雨天") || text.contains("下雨") || text.contains("雪天") { score += 50 }
            if text.contains("第一次") { score += 45 }
            if text.contains("第10次") || text.contains("第 10 次") { score += 42 }
            if text.contains("连续") { score += 36 }
            if text.contains("周末出门") || text.contains("周末路上") { score += 32 }
            guard score > 0 else { return nil }
            return (item, tag, score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.item.createdAt > rhs.item.createdAt }
            return lhs.score > rhs.score
        }

        if let best = candidates.first {
            let day = Self.shortWeekdayFormatter.string(from: best.item.createdAt)
            return "\(day)这笔写着「\(best.tag)」，以后再看会知道当时发生了什么。"
        }

        return photoMemoryLine(in: rows, range: range)
    }

    private func meaningfulMonthlyCategoryChange(current: [HomeItem], previous: [HomeItem]) -> MonthlyCategoryChange? {
        let previousTotal = previous.reduce(0) { $0 + $1.amount }
        guard previous.count >= 3, previousTotal > 0 else { return nil }

        let currentStats = monthlyCategoryStats(current)
        let previousStats = monthlyCategoryStats(previous)
        let currentTotal = max(current.reduce(0) { $0 + $1.amount }, 1)
        let categoryNames = Set(currentStats.keys).union(previousStats.keys)

        let candidates = categoryNames.compactMap { category -> MonthlyCategoryChange? in
            guard let current = currentStats[category], current.count > 0 else { return nil }
            let previous = previousStats[category]
            let previousAmount = previous?.amount ?? 0
            let previousCount = previous?.count ?? 0
            let amountDelta = current.amount - previousAmount
            let countDelta = current.count - previousCount
            let shareDelta = current.amount / currentTotal - previousAmount / previousTotal

            if previous == nil {
                guard current.count >= 2 || current.amount >= max(50, currentTotal * 0.08) else { return nil }
            } else {
                let amountSignificant = abs(amountDelta) >= max(50, previousAmount * 0.25)
                let countSignificant = abs(countDelta) >= 2
                let shareSignificant = abs(shareDelta) >= 0.12
                guard amountSignificant || countSignificant || shareSignificant else { return nil }
            }

            let score = abs(shareDelta) * 100
                + min(abs(amountDelta) / 50, 8)
                + Double(abs(countDelta)) * 0.8
                + (previous == nil ? 1.5 : 0)
            return MonthlyCategoryChange(
                category: category,
                current: current,
                previous: previous,
                amountDelta: amountDelta,
                countDelta: countDelta,
                score: score
            )
        }

        return candidates.max {
            if $0.score == $1.score {
                return $0.current.amount < $1.current.amount
            }
            return $0.score < $1.score
        }
    }

    private func monthlyCategoryStats(_ items: [HomeItem]) -> [String: CategoryMonthlyStat] {
        var buckets: [String: (count: Int, amount: Double)] = [:]
        for item in items {
            let category = item.category.rawValue
            let current = buckets[category] ?? (count: 0, amount: 0)
            buckets[category] = (count: current.count + 1, amount: current.amount + item.amount)
        }
        return buckets.reduce(into: [:]) { result, entry in
            result[entry.key] = CategoryMonthlyStat(
                category: entry.key,
                count: entry.value.count,
                amount: entry.value.amount
            )
        }
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
