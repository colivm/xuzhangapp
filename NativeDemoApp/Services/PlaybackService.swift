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
    enum Kind: Equatable {
        case brandTop(name: String, count: Int, brandId: String?)
        case categoryTop(category: HomeItem.Category, count: Int)
        case busiestDay(label: String, count: Int)
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

enum ShareInsightCopyPool {
    static func insight(for signal: ShareInsightSignal, seed: String) -> ShareInsight {
        switch signal.kind {
        case let .brandTop(name, count, brandId):
            return brandInsight(name: name, count: count, brandId: brandId, signal: signal, seed: seed)
        case let .categoryTop(category, count):
            return categoryInsight(category: category, count: count, signal: signal, seed: seed)
        case let .busiestDay(label, count):
            return ShareInsight(
                fact: "\(label)最忙，记了 \(count) 笔",
                care: pick(["忙完那天，给自己留点空", "把最满的一天留在这里"], seed: seed + "|day"),
                footnote: footnote(for: signal),
                tags: ["#真实记录", "#节奏", "#\(shortDayLabel(label))", "#这一周"]
            )
        case let .lifeTitle(text):
            return ShareInsight(
                fact: text,
                care: pick(["是这周最想留下来的一句", "这样的周，可以存一页"], seed: seed + "|life"),
                footnote: footnote(for: signal),
                tags: ["#生活侧写", "#手写备注", "#这一周"]
            )
        case let .weakData(recordCount):
            return ShareInsight(
                fact: "这周才记了 \(recordCount) 笔，刚开头",
                care: pick(["多记几次，下次能讲更完整", "先从这几笔开始看见自己"], seed: seed + "|weak"),
                footnote: footnote(for: signal),
                tags: ["#刚开头", "#生活侧写", "#这一周"]
            )
        }
    }

    private static func brandInsight(
        name: String,
        count: Int,
        brandId: String?,
        signal: ShareInsightSignal,
        seed: String
    ) -> ShareInsight {
        let kind = brandKind(name: name, brandId: brandId)
        let fact: String
        let cares: [String]
        let semanticTag: String
        switch kind {
        case .coffee:
            fact = "\(name)买了 \(count) 次，这周靠它提神"
            cares = ["提神可以，别熬太晚", "忙归忙，记得睡够"]
            semanticTag = "#咖啡"
        case .delivery:
            fact = "外卖点了 \(count) 次，是这周最多的"
            cares = ["忙的时候靠外卖也正常", "有空做顿热的，更好"]
            semanticTag = "#吃饭"
        case .convenience:
            fact = "\(name)去了 \(count) 次，是这周最多的"
            cares = ["工作再忙，也别漏掉正经一顿", "顺路补给，也算稳住日子"]
            semanticTag = "#便利店"
        case .food:
            fact = "\(name)吃了 \(count) 次，是这周最多的"
            cares = ["忙的时候先吃上，也很要紧", "吃饭这件事，别太随便"]
            semanticTag = "#吃饭"
        case .general:
            fact = "\(name)去了 \(count) 次，是这周最多的"
            cares = ["这些反复出现的小事，也是一周的样子", "常去的地方，把这一周标了出来"]
            semanticTag = "#常去"
        }
        return ShareInsight(
            fact: fact,
            care: pick(cares, seed: seed + "|brand|\(name)"),
            footnote: footnote(for: signal),
            tags: ["#真实记录", semanticTag, "#\(sanitizedTag(name))", "#这一周"]
        )
    }

    private static func categoryInsight(
        category: HomeItem.Category,
        count: Int,
        signal: ShareInsightSignal,
        seed: String
    ) -> ShareInsight {
        let fact: String
        let cares: [String]
        let tag: String
        switch category {
        case .dining:
            fact = "吃饭占了这周大头，记了 \(count) 次"
            cares = ["忙归忙，别漏掉一顿热的", "吃饭这件事，也是在过日子"]
            tag = "#吃饭"
        case .transport:
            fact = "路上记了 \(count) 笔，总在移动"
            cares = ["移动多的一周，记得歇一歇", "跑来跑去的日子，也被记下了"]
            tag = "#路上"
        case .health:
            fact = "锻炼记了 \(count) 次，是这周最勤的事"
            cares = ["练得努力，也要顾着身体", "身体这件事，稳定一点更长久"]
            tag = "#锻炼"
        case .entertainment:
            fact = "放松安排比较多，记了 \(count) 次"
            cares = ["该玩就玩，别亏待自己", "这一周也需要一点松口气"]
            tag = "#放松"
        case .shopping:
            fact = "添置东西比较多，记了 \(count) 笔"
            cares = ["买到需要的，也算把日子补齐", "用得上的东西，会留在日常里"]
            tag = "#购物"
        case .daily:
            fact = "日常补给出现得最多，记了 \(count) 次"
            cares = ["小事补齐了，日子就顺一点", "这些小补给，把一周垫稳了"]
            tag = "#日常"
        case .home:
            fact = "家里的事记了 \(count) 笔，是这周最多的"
            cares = ["把家里整理好，也是一种进展", "日子落回家里，就有了形状"]
            tag = "#居家"
        case .lodging:
            fact = "停留和住宿记了 \(count) 笔"
            cares = ["在外的一周，也要睡踏实", "换个地方停下，也算一段生活"]
            tag = "#停留"
        case .social:
            fact = "人情往来记了 \(count) 笔"
            cares = ["关系里的来往，也会留下痕迹", "见面和心意，组成了这一周"]
            tag = "#人情"
        case .other:
            fact = "其他小事出现得最多，记了 \(count) 次"
            cares = ["说不清也没关系，先记下来", "这一周就这样，先留一页"]
            tag = "#小事"
        }
        return ShareInsight(
            fact: fact,
            care: pick(cares, seed: seed + "|category|\(category.rawValue)"),
            footnote: footnote(for: signal),
            tags: ["#真实记录", tag, "#\(category.label)", "#这一周"]
        )
    }

    private enum BrandKind {
        case coffee
        case delivery
        case convenience
        case food
        case general
    }

    private static func brandKind(name: String, brandId: String?) -> BrandKind {
        let id = brandId ?? ""
        if ["luckin", "starbucks", "manner"].contains(id) { return .coffee }
        if ["meituan", "eleme"].contains(id) { return .delivery }
        if ["familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia"].contains(id) { return .convenience }
        if ["mcdonalds", "kfc"].contains(id) { return .food }
        if name.contains("咖啡") { return .coffee }
        if name.contains("外卖") || name.contains("美团") || name.contains("饿了") { return .delivery }
        if name.contains("便利") || name.contains("全家") || name.contains("罗森") { return .convenience }
        return .general
    }

    private static func footnote(for signal: ShareInsightSignal) -> String {
        let dayText = signal.activeDays > 0 ? " · \(signal.activeDays) 天有记录" : ""
        return "\(signal.recordCount) 次 · 这一周\(dayText)"
    }

    private static func pick(_ options: [String], seed: String) -> String {
        guard !options.isEmpty else { return "" }
        return options[Int(stableHash(seed) % UInt64(options.count))]
    }

    private static func stableHash(_ text: String) -> UInt64 {
        text.unicodeScalars.reduce(UInt64(14_695_981_039_346_656_037)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* 1_099_511_628_211
        }
    }

    private static func sanitizedTag(_ text: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "#", with: "")
        return String(cleaned.prefix(8))
    }

    private static func shortDayLabel(_ label: String) -> String {
        if label.contains("星期") {
            return label.replacingOccurrences(of: "星期", with: "周")
        }
        return label
    }
}

struct WeeklyShareCardPayload {
    let weekTotal: Double
    let topCategory: String
    let recordCount: Int
    let dailyTrend: [(String, Double)]
    let topCategoryRatio: Double
    let headline: String
    let subtitle: String
    let anchorLine: String?
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
        materials.first { material in
            guard let itemID else { return true }
            return material.item.id != itemID
        }
    }

    func voiceText(for range: SummaryPlaybackRange) -> String {
        primary?.text ?? PlaybackMomentSelector.honestNoVoiceText(for: range)
    }

    var scentText: String {
        scentWords.isEmpty ? PlaybackMomentSelector.honestNoScentText : scentWords.joined(separator: "、")
    }
}

private enum PlaybackMaterialScoring {
    static func stableScore(item: HomeItem, periodKey: String, now: Date) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in "\(item.id.uuidString)|\(periodKey)|\(Int(now.timeIntervalSince1970 / 86_400))".utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 7)
    }
}

final class PlaybackMomentSelector {
    static let honestNoScentText = "记录还少"

    func select(
        from items: [HomeItem],
        periodKey: String,
        range: SummaryPlaybackRange,
        now: Date = Date(),
        echoAnchor: EchoAnchor? = nil
    ) -> PlaybackMomentSelection {
        let materials = playbackMaterials(in: items, periodKey: periodKey, now: now)
        let primary = preferredMaterial(from: materials, echoAnchor: echoAnchor)
        let scentWords = playbackScentWords(from: items, materials: materials)
        return PlaybackMomentSelection(materials: materials, primary: primary, scentWords: scentWords)
    }

    static func honestNoVoiceText(for range: SummaryPlaybackRange) -> String {
        switch range {
        case .week:
            return "这周的几笔记录"
        case .month:
            return "这个月的几笔记录"
        }
    }

    private func playbackMaterials(in items: [HomeItem], periodKey: String, now: Date) -> [PlaybackMoment] {
        items.compactMap { item -> PlaybackMoment? in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
            let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            var score = PlaybackMaterialScoring.stableScore(item: item, periodKey: periodKey, now: now)

            if EchoAnchorService.shared.isEligibleLifeTraceTitle(title, item: item) {
                score += 70
                if item.userEditedTitle == true { score += 24 }
                if item.source == .manual { score += 8 }
                if emotion != defaultEmotion { score += 8 }
                return PlaybackMoment(item: item, text: title, source: .title, score: score)
            }

            guard (2...18).contains(emotion.count),
                  emotion != defaultEmotion,
                  !EchoAnchorService.shared.isDirtyTraceTitle(emotion) else {
                return nil
            }
            score += 48
            if item.userEditedTitle == true { score += 8 }
            return PlaybackMoment(item: item, text: emotion, source: .emotionTag, score: score)
        }
        .sorted {
            if $0.score == $1.score {
                return $0.item.createdAt > $1.item.createdAt
            }
            return $0.score > $1.score
        }
    }

    private func preferredMaterial(from materials: [PlaybackMoment], echoAnchor: EchoAnchor?) -> PlaybackMoment? {
        if let echoAnchor,
           let matched = materials.first(where: { $0.item.id == echoAnchor.itemId }) {
            return matched
        }
        return materials.first
    }

    private func playbackScentWords(from items: [HomeItem], materials: [PlaybackMoment]) -> [String] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: Int] = [:]

        func add(_ raw: String) {
            let text = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "「」『』“”\"'，,。.!！?？、：:；;（）()[]【】"))
            guard (2...18).contains(text.count),
                  !EchoAnchorService.shared.isDirtyTraceTitle(text) else {
                return
            }
            if firstSeen[text] == nil { firstSeen[text] = firstSeen.count }
            counts[text, default: 0] += 1
        }

        materials.forEach { add($0.text) }
        for item in items {
            let defaultEmotion = HomeItem.inferEmotionTag(category: item.category, amount: item.amount)
            let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            if !emotion.isEmpty, emotion != defaultEmotion { add(emotion) }
            if EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item) { add(item.title) }
            add(item.category.rawValue)
        }

        return counts
            .sorted {
                if $0.value == $1.value {
                    return (firstSeen[$0.key] ?? 0) < (firstSeen[$1.key] ?? 0)
                }
                return $0.value > $1.value
            }
            .prefix(5)
            .map(\.key)
    }

}

final class SummaryPlaybackQuotaStore {
    private enum Keys {
        static let playbackWeekKey = "playbackWeekKey"
        static let playbackWeekUsed = "playbackWeekUsed"
        static let playbackWeekUsedCount = "playbackWeekUsedCount"
        static let lifetimeMonthChapterRemaining = "lifetimeMonthChapterRemaining"
        static let lifetimeWeekPlaybackCompleted = "lifetimeWeekPlaybackCompleted"
        static let quotaSchemaVersion = "summaryPlaybackQuotaSchemaVersion"
        static let lastLoginQuotaSyncUserId = "summaryPlaybackLastLoginQuotaSyncUserId"
    }

    static let weeklyFreeLimit = 3
    static let lifetimeMonthFreeLimit = 10

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateQuotaIfNeeded()
    }

    func currentWeekKey(now: Date = Date()) -> String {
        let calendar = PlaybackService.isoCalendar
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", comps.weekOfYear ?? 0))"
    }

    func weekRemaining(isMember: Bool, now: Date = Date()) -> Int {
        guard !isMember else { return Int.max }
        syncWeekIfNeeded(now: now)
        return max(0, Self.weeklyFreeLimit - defaults.integer(forKey: Keys.playbackWeekUsedCount))
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
            let used = defaults.integer(forKey: Keys.playbackWeekUsedCount)
            defaults.set(min(Self.weeklyFreeLimit, used + 1), forKey: Keys.playbackWeekUsedCount)
            defaults.set(defaults.integer(forKey: Keys.playbackWeekUsedCount) >= Self.weeklyFreeLimit, forKey: Keys.playbackWeekUsed)
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

    func syncLocalUsageAfterLogin(userId: String, now: Date = Date()) {
        migrateQuotaIfNeeded()
        syncWeekIfNeeded(now: now)
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            defaults.set(trimmed, forKey: Keys.lastLoginQuotaSyncUserId)
        }
    }

    private func syncWeekIfNeeded(now: Date) {
        let key = currentWeekKey(now: now)
        if defaults.string(forKey: Keys.playbackWeekKey) != key {
            defaults.set(key, forKey: Keys.playbackWeekKey)
            defaults.set(false, forKey: Keys.playbackWeekUsed)
            defaults.set(0, forKey: Keys.playbackWeekUsedCount)
        }
    }

    private func migrateQuotaIfNeeded() {
        let version = defaults.integer(forKey: Keys.quotaSchemaVersion)
        guard version < 2 else { return }

        if defaults.object(forKey: Keys.playbackWeekUsedCount) == nil {
            defaults.set(defaults.bool(forKey: Keys.playbackWeekUsed) ? 1 : 0, forKey: Keys.playbackWeekUsedCount)
        } else {
            let used = defaults.integer(forKey: Keys.playbackWeekUsedCount)
            defaults.set(min(max(used, 0), Self.weeklyFreeLimit), forKey: Keys.playbackWeekUsedCount)
        }

        if defaults.object(forKey: Keys.lifetimeMonthChapterRemaining) == nil {
            defaults.set(Self.lifetimeMonthFreeLimit, forKey: Keys.lifetimeMonthChapterRemaining)
        } else {
            let legacyRemaining = defaults.integer(forKey: Keys.lifetimeMonthChapterRemaining)
            let migratedRemaining = min(Self.lifetimeMonthFreeLimit, max(0, legacyRemaining) + 7)
            defaults.set(migratedRemaining, forKey: Keys.lifetimeMonthChapterRemaining)
        }

        defaults.set(2, forKey: Keys.quotaSchemaVersion)
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
        let secondaryVoice = selection.first(excluding: primaryVoiceID)
        let busiestRows = busiest.map { day in rows.filter { calendar.isDate($0.createdAt, inSameDayAs: day.date) } } ?? []
        let busiestSelection = momentSelector.select(from: busiestRows, periodKey: weekKey, range: .week, now: now)
        let busiestMaterial = busiestSelection.primary ?? primaryVoice
        let recurringLine = recurringTraceLine(
            current: rows,
            previous: previousWeekItems(from: items, now: now),
            rangeName: "上周"
        )
        let scentText = copyWithRecurringLine(selection.scentText, recurringLine)
        let scentWords = selection.scentWords
        let voiceTitle1 = selection.voiceText(for: .week)
        let voiceTitle2 = secondaryVoice?.text ?? voiceTitle1
        let busiestTitle = busiestMaterial?.text ?? voiceTitle1
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
            "scentWord1": scentWords.indices.contains(0) ? scentWords[0] : PlaybackMomentSelector.honestNoScentText,
            "scentWord2": scentWords.indices.contains(1) ? scentWords[1] : "",
            "scentWord3": scentWords.indices.contains(2) ? scentWords[2] : "",
            "scentWords": scentText,
            "topCategory": top?.category ?? "日常",
            "ratio": "\(ratio)",
            "echoLine": echoSentence ?? ""
        ]

        var chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "week-presence",
                title: "这一周",
                metrics: ["count": "\(rows.count)", "total": Self.money(total), "range": rangeLabel],
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
            chapters.append(
                SummaryChapter(
                    id: "week-voices",
                    title: "留下的话",
                    metrics: [
                        "voiceTitle1": voiceTitle1,
                        "voiceTitle2": voiceTitle2,
                        "amount": primaryVoice.map { Self.money($0.item.amount) } ?? "",
                        "day": primaryVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? ""
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
                        "ratio": "\(ratio)"
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
                        "day": primaryVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? ""
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
                metrics: ["count": "\(rows.count)", "total": Self.money(total), "topCategory": top?.category ?? "日常"],
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
                copySeed: weekSeed
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
        let period = "\(Self.dotDateFormatter.string(from: interval.start)) ~ \(Self.dotDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? now))"
        let closing = builtSummary.chapters.last?.narration.plain ?? "这一周已经留下了可以回看的记录。"
        let signal = weeklyShareInsightSignal(
            rows: rows,
            activity: activity,
            now: now
        )
        let insight = ShareInsightCopyPool.insight(
            for: signal,
            seed: "\(builtSummary.id)|\(period)|\(rows.count)"
        )

        return WeeklyShareCardPayload(
            weekTotal: total,
            topCategory: top?.category ?? "日常",
            recordCount: rows.count,
            dailyTrend: trend,
            topCategoryRatio: ratio,
            headline: builtSummary.teaserLine,
            subtitle: closing,
            anchorLine: weeklyShareAnchorLine(from: builtSummary),
            periodText: period,
            insight: insight
        )
    }

    private func weeklyShareInsightSignal(
        rows: [HomeItem],
        activity: [DayActivity],
        now: Date
    ) -> ShareInsightSignal {
        let activeDays = activeDayCount(rows)
        let base = (recordCount: rows.count, activeDays: activeDays)

        if rows.count <= 2 {
            return ShareInsightSignal(
                kind: .weakData(recordCount: rows.count),
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
            return ShareInsightSignal(
                kind: .categoryTop(category: category.category, count: category.count),
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
            "scentWords": scentText
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
                    "voiceTitle1": voiceTitle1
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
                    "day": earlyVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? ""
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
                    "day": lateVoice.map { Self.weekdayFormatter.string(from: $0.item.createdAt) } ?? ""
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
                metrics: ["change": changeText],
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
                    "ratio": "\(ratio)"
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
                metrics: ["count": "\(rows.count)", "total": Self.money(total)],
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
                rangeLabel: rangeLabel
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

    private func weekTeaserLine(busiest: DayActivity?, rows: [HomeItem], voiceTitle: String, scentWords: String, copySeed: String) -> String {
        if rows.count < 3 {
            return "这周已有 \(rows.count) 笔记录，再多一点就能讲得更完整。"
        }
        let values = [
            "busiestDayShort": busiest?.label ?? "本周",
            "count": "\(rows.count)",
            "rangeLabel": "这一周",
            "voiceTitle1": voiceTitle,
            "scentWords": scentWords
        ]
        return PlaybackCopyPool.weekTeaser(seed: copySeed, values: values)
    }

    private func weeklyShareAnchorLine(from summary: SummaryPlayback) -> String? {
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

    private func monthTeaserLine(
        voiceTitle: String,
        scentWords: String,
        changeText: String,
        copySeed: String,
        rangeLabel: String
    ) -> String {
        let values = [
            "voiceTitle1": voiceTitle,
            "scentWords": scentWords,
            "changeHint": changeText,
            "rangeLabel": rangeLabel
        ]
        return PlaybackCopyPool.monthTeaser(seed: copySeed, values: values)
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
        if let change = meaningfulMonthlyCategoryChange(current: current, previous: previous) {
            let amountText = Self.money(abs(change.amountDelta))
            if change.previous == nil {
                return "这个月「\(change.category)」开始变得明显，记录了 \(change.current.count) 笔、\(Self.money(change.current.amount))。"
            }
            if change.amountDelta >= 0 {
                let countText = change.countDelta > 0 ? "，多了 \(change.countDelta) 笔" : ""
                return "这个月「\(change.category)」比上月更显眼\(countText)，多出约 \(amountText)。"
            } else {
                let countText = change.countDelta < 0 ? "，少了 \(abs(change.countDelta)) 笔" : ""
                return "这个月「\(change.category)」比上月轻了一些\(countText)，少了约 \(amountText)。"
            }
        }
        let streak = longestRecordStreak(in: current)
        if streak >= 3 {
            return "这个月最长连续 \(streak) 天有记录，节奏比较清楚。"
        }
        if let leading = segments.max(by: { $0.amount < $1.amount }), leading.amount > 0 {
            return "\(leading.label)最热闹，记录了 \(leading.count) 笔、\(Self.money(leading.amount))。"
        }
        if let first = current.first, let last = current.last {
            let days = max(1, Calendar.current.dateComponents([.day], from: first.createdAt, to: last.createdAt).day ?? 1)
            return "记录从 \(Self.shortDateFormatter.string(from: first.createdAt)) 延续到 \(Self.shortDateFormatter.string(from: last.createdAt))，跨度 \(days) 天。"
        }
        return "这个月已经有几笔可以回看的记录。"
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
