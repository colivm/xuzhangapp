import Foundation

enum PlaybackMaterialScoring {
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
            if HomeItem.isLateWorkCommute(item) {
                score += 30
            }

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
            add(LifeSceneSemanticService.displayTheme(for: LifeSceneSemanticService.classify(item)))
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

    static let todayPlaybackFreeLimit = 3

    private let defaults: UserDefaults
    private let ocrDailyLimit = 3

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
        return max(0, Self.todayPlaybackFreeLimit - defaults.integer(forKey: Keys.todayPlaybackUsedCount))
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
        defaults.set(min(Self.todayPlaybackFreeLimit, used + 1), forKey: Keys.todayPlaybackUsedCount)
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
