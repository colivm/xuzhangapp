import Foundation

struct TraceChapterComputationInput {
    let range: SummaryPlaybackRange
    let items: [HomeItem]
    let allItems: [HomeItem]
    let isMember: Bool
    let prioritizeRecurringMarks: Bool
    let periodKey: String
    let usesEchoAnchor: Bool
    let now: Date
}

struct TraceClueComputationInput {
    let items: [HomeItem]
    let allItems: [HomeItem]
    let period: StatsPeriod
    let periodLabel: String
    let isMember: Bool
    let freeRemaining: Int
    let storedUnlock: Bool
    let now: Date
}

enum TraceSnapshotComputation {
    static func buildChapter(_ input: TraceChapterComputationInput) -> TraceChapterSnapshot {
        let rawMarks = LifeMarkService.aggregates(
            for: input.items,
            allItems: input.allItems,
            isMember: input.isMember,
            limit: 8
        )
        let marks = prioritizedMarks(
            rawMarks,
            items: input.items,
            prioritizeRecurring: input.prioritizeRecurringMarks
        )
        .prefix(2)
        .map { $0 }
        let anchors = MemoryAnchorSelectionPolicy.selectAnchors(
            from: input.items,
            range: input.range,
            limit: 3,
            label: memoryAnchorLabel(role:sceneHint:),
            caption: memoryAnchorCaption(role:sceneHint:)
        )
        let echoAnchor = input.usesEchoAnchor
            ? EchoAnchorService.shared.pickEchoAnchor(items: input.items, periodKey: input.periodKey, now: input.now)
            : nil
        let voice = PlaybackMomentSelector().select(
            from: input.items,
            periodKey: input.periodKey,
            range: input.range,
            now: input.now,
            echoAnchor: echoAnchor
        ).primary?.text

        return TraceChapterSnapshot(
            range: input.range,
            items: input.items,
            marks: marks,
            memoryAnchors: anchors,
            narrative: chapterNarrative(range: input.range, items: input.items, marks: marks, voice: voice),
            chapterSummary: marks.first.map { LifeMarkService.primaryLine(for: $0) },
            evidenceGroups: evidenceGroups(from: input.items, marks: marks, maxItems: 3),
            preview: launchPreview(for: input.range, items: input.items)
        )
    }

    static func buildClue(_ input: TraceClueComputationInput) -> TraceClueSnapshot {
        let clues = categoryClues(from: input.items)
        let rhythmPoints = rhythmPoints(from: input.items, period: input.period, now: input.now)
        let insight = LifeInsightService().buildTraceInsight(
            items: input.items,
            historyItems: input.allItems,
            periodLabel: input.periodLabel,
            now: input.now
        )
        let rawMarks = LifeMarkService.aggregates(
            for: input.items,
            allItems: input.allItems,
            isMember: input.isMember,
            limit: 8
        )
        let marks = prioritizedMarks(
            rawMarks,
            items: input.items,
            prioritizeRecurring: input.period == .month
        )
        .prefix(6)
        .map { $0 }
        let lockedMark = input.isMember
            ? nil
            : LifeMarkService.lockedPreview(for: input.items, allItems: input.allItems)
        let isUnlocked = !insight.isMeaningful || input.storedUnlock
        let canUse = insight.isMeaningful
            && !input.items.isEmpty
            && (input.storedUnlock || input.freeRemaining > 0)

        return TraceClueSnapshot(
            items: input.items,
            clues: clues,
            rhythmPoints: rhythmPoints,
            insight: insight,
            marks: marks,
            lockedMark: lockedMark,
            isDeepInsightUnlocked: isUnlocked,
            canUseDeepInsight: canUse,
            freeInsightRemaining: input.freeRemaining
        )
    }

    private static func prioritizedMarks(
        _ marks: [LifeMarkAggregate],
        items: [HomeItem],
        prioritizeRecurring: Bool
    ) -> [LifeMarkAggregate] {
        guard prioritizeRecurring, items.count >= 8 else { return marks }
        let recurring = marks.filter { $0.count >= 2 && $0.kind != .milestone }
        let oneOff = marks.filter { $0.count < 2 || $0.kind == .milestone }
        let ordered = recurring + oneOff
        return ordered.isEmpty ? marks : ordered
    }

    private static func chapterNarrative(
        range: SummaryPlaybackRange,
        items: [HomeItem],
        marks: [LifeMarkAggregate],
        voice: String?
    ) -> String {
        guard !items.isEmpty else {
            return range == .week
                ? "这一周还没有记录。先留下几笔，之后会整理成一段场记。"
                : "这个月还没有记录。先留下几笔，之后会整理成一段场记。"
        }
        if let primary = marks.first {
            return range == .week
                ? "\(markDisplayLabel(primary))，是这周的主线"
                : "这个月 · \(markDisplayLabel(primary))"
        }
        if let voice, !voice.isEmpty {
            return range == .week
                ? "这一周先记住「\(voice)」"
                : "这个月先记住「\(voice)」"
        }
        return "这一段还散，多记几笔会收成一章。"
    }

    private static func markDisplayLabel(_ mark: LifeMarkAggregate) -> String {
        mark.kind == .scene ? mark.label : mark.title
    }

    private static func evidenceGroups(
        from items: [HomeItem],
        marks: [LifeMarkAggregate],
        maxItems: Int
    ) -> [TraceMarkEvidenceGroup] {
        guard maxItems > 0 else { return [] }
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        var groups: [TraceMarkEvidenceGroup] = []
        var usedItemIDs = Set<UUID>()
        var remainingSlots = maxItems

        for (index, mark) in marks.enumerated() where remainingSlots > 0 {
            if index == 1, mark.count < 2 { continue }
            let markItemIDs = Set(mark.itemIDs)
            let matchingItems = sortedItems.filter { markItemIDs.contains($0.id) }
            guard !matchingItems.isEmpty else { continue }
            let groupLimit = index == 0 ? min(2, remainingSlots) : remainingSlots
            let visibleItems = matchingItems
                .filter { !usedItemIDs.contains($0.id) }
                .prefix(groupLimit)
            guard !visibleItems.isEmpty else { continue }

            let visibleArray = Array(visibleItems)
            visibleArray.forEach { usedItemIDs.insert($0.id) }
            remainingSlots -= visibleArray.count
            groups.append(
                TraceMarkEvidenceGroup(
                    id: mark.id,
                    markLabel: markDisplayLabel(mark),
                    items: visibleArray,
                    overflowCount: max(matchingItems.count - visibleArray.count, 0)
                )
            )
        }

        if !groups.isEmpty { return groups }
        let fallback = TraceRepresentative.items(from: sortedItems, maxItems: maxItems, maxPerCategory: 2)
        guard !fallback.isEmpty else { return [] }
        return [
            TraceMarkEvidenceGroup(
                id: "fallback",
                markLabel: "这一段里的笔笔",
                items: fallback,
                overflowCount: max(sortedItems.count - fallback.count, 0)
            )
        ]
    }

    private static func launchPreview(
        for range: SummaryPlaybackRange,
        items: [HomeItem]
    ) -> SummaryLaunchPreview {
        let rows = items.filter { $0.amount > 0 && $0.draftMeta == nil }
        let total = rows.reduce(0) { $0 + $1.amount }
        let categories: [(category: String, count: Int, amount: Double)] = Dictionary(grouping: rows, by: \.category)
            .map { category, grouped in
                (category.rawValue, grouped.count, grouped.reduce(0) { $0 + $1.amount })
            }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.amount > rhs.amount : lhs.count > rhs.count
            }
        let chapterCount: Int
        if rows.isEmpty {
            chapterCount = 0
        } else if range == .week {
            chapterCount = rows.count >= 3 ? 4 : 3
        } else {
            chapterCount = 6
        }
        return SummaryLaunchPreview(
            count: rows.count,
            total: total,
            chapterCount: chapterCount,
            topCategory: categories.first?.category
        )
    }

    private static func categoryClues(from items: [HomeItem]) -> [TraceCategoryClue] {
        guard !items.isEmpty else { return [] }
        let totalCount = Double(items.count)
        let clues: [TraceCategoryClue] = Dictionary(grouping: items, by: \.category)
            .map { category, grouped in
                TraceCategoryClue(
                    category: category,
                    count: grouped.count,
                    total: grouped.reduce(0) { $0 + $1.amount },
                    ratio: Double(grouped.count) / totalCount
                )
            }
        return clues.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.total > rhs.total : lhs.count > rhs.count
        }
    }

    private static func rhythmPoints(
        from items: [HomeItem],
        period: StatsPeriod,
        now: Date
    ) -> [TraceRhythmPoint] {
        guard !items.isEmpty else { return [] }
        let calendar = Calendar.current
        let countsByDay = Dictionary(grouping: items) { calendar.startOfDay(for: $0.createdAt) }
            .mapValues { $0.count }

        if period == .month, let interval = calendar.dateInterval(of: .month, for: now) {
            let end = min(interval.end, now)
            let labels = ["第1周", "第2周", "第3周", "第4周", "末段"]
            return labels.indices.compactMap { index in
                guard let start = calendar.date(byAdding: .day, value: index * 7, to: interval.start) else { return nil }
                let rawEnd = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                let pointEnd = min(rawEnd, end)
                guard start < pointEnd else { return nil }
                let count = countsByDay.reduce(0) { partial, entry in
                    partial + ((entry.key >= start && entry.key < pointEnd) ? entry.value : 0)
                }
                return TraceRhythmPoint(
                    label: labels[index],
                    count: count,
                    isToday: now >= start && now < pointEnd
                )
            }
        }

        guard let interval = PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return labels.indices.compactMap { index in
            guard let day = calendar.date(byAdding: .day, value: index, to: interval.start) else { return nil }
            let count = countsByDay[calendar.startOfDay(for: day)] ?? 0
            return TraceRhythmPoint(
                label: labels[index],
                count: count,
                isToday: calendar.isDate(day, inSameDayAs: now)
            )
        }
    }

    private static func memoryAnchorLabel(
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint
    ) -> String {
        switch sceneHint {
        case .gathering: return "见面"
        case .travel, .travelTransport: return "出门"
        case .vehicleCare, .healthRecord: return role == .receipt ? "票据" : "记录"
        case .homeLife: return "家里"
        case .careRecord: return "照护"
        case .experience: return "现场"
        case .giftMoment: return "心意"
        case .importantPurchase: return "添置"
        }
    }

    private static func memoryAnchorCaption(
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint
    ) -> String {
        switch role {
        case .moment:
            return sceneHint == .gathering ? "和朋友的一次聚会。" : "当时拍下的一张图。"
        case .receipt: return "这张图以后查起来更清楚。"
        case .place: return "路上拍下的一张图。"
        case .object: return "这次买的东西。"
        case .careRecord: return "照护相关的一张记录。"
        }
    }
}

final class TraceSnapshotStore {
    private var chapterCache: [String: TraceChapterSnapshot] = [:]
    private var chapterCacheOrder: [String] = []
    private let chapterCacheLimit = 8

    private var clueCache: [String: TraceClueSnapshot] = [:]
    private var clueCacheOrder: [String] = []
    private let clueCacheLimit = 24

    func chapterSnapshot(for key: String) -> TraceChapterSnapshot? {
        chapterCache[key]
    }

    func storeChapterSnapshot(_ snapshot: TraceChapterSnapshot, for key: String) {
        guard chapterCache[key] == nil else { return }
        chapterCache[key] = snapshot
        chapterCacheOrder.append(key)
        while chapterCacheOrder.count > chapterCacheLimit {
            let staleKey = chapterCacheOrder.removeFirst()
            chapterCache.removeValue(forKey: staleKey)
        }
    }

    func clueSnapshot(for key: String) -> TraceClueSnapshot? {
        clueCache[key]
    }

    func storeClueSnapshot(_ snapshot: TraceClueSnapshot, for key: String) {
        guard clueCache[key] == nil else { return }
        clueCache[key] = snapshot
        clueCacheOrder.append(key)
        while clueCacheOrder.count > clueCacheLimit {
            let staleKey = clueCacheOrder.removeFirst()
            clueCache.removeValue(forKey: staleKey)
        }
    }

    func invalidateAll() {
        chapterCache.removeAll()
        chapterCacheOrder.removeAll()
        invalidateClueCache()
    }

    func invalidateClueCache() {
        clueCache.removeAll()
        clueCacheOrder.removeAll()
    }
}
