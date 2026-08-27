import Foundation

struct TraceChapterComputationInput: @unchecked Sendable {
    let range: SummaryPlaybackRange
    let items: [HomeItem]
    let allItems: [HomeItem]
    let isMember: Bool
    let prioritizeRecurringMarks: Bool
    let periodKey: String
    let usesEchoAnchor: Bool
    let sourceRevision: Int
    let now: Date
}

struct TraceClueComputationInput: @unchecked Sendable {
    let items: [HomeItem]
    let allItems: [HomeItem]
    let period: StatsPeriod
    let periodLabel: String
    let isMember: Bool
    let freeRemaining: Int
    let storedUnlock: Bool
    let sourceRevision: Int
    let narrativeScope: LifeNarrativeScope?
    let allowsNarrativeRewrite: Bool
    let now: Date
}

enum TraceSnapshotComputation {
    private struct CategoryPreviewRow {
        let name: String
        let count: Int
        let amount: Double
    }

    static func buildChapter(_ input: TraceChapterComputationInput) -> TraceChapterSnapshot {
        let periodFacts = PlaybackService().preparePeriodExperienceFacts(
            periodItems: input.items,
            allItems: input.allItems,
            range: input.range,
            now: input.now,
            sourceRevision: input.sourceRevision,
            isMember: input.isMember
        )
        let rawMarks = periodFacts.lifeMarks
        let rankedMarks = prioritizedMarks(
            rawMarks,
            items: input.items,
            prioritizeRecurring: input.prioritizeRecurringMarks
        )
        let narrativePlan = periodFacts.narrativePlan
        let selectedAnchors = MemoryAnchorSelectionPolicy.selectAnchors(
            from: input.items,
            range: input.range,
            limit: input.range == .month
                ? TraceMonthDiaryPolicy.selectionLimitIncludingCover
                : 3,
            preferredItemID: preferredNarrativeAnchorItemID(
                plan: narrativePlan,
                items: input.items
            ),
            label: memoryAnchorLabel(role:sceneHint:),
            caption: memoryAnchorCaption(role:sceneHint:)
        )
        let anchors = Array(selectedAnchors.prefix(3))
        let coverFacts = TraceChapterCoverPolicy.make(
            range: input.range,
            items: input.items,
            anchors: anchors,
            now: input.now
        )
        let monthDiaryAnchors = input.range == .month
            ? TraceMonthDiaryPolicy.anchors(
                from: selectedAnchors,
                excludingCoverItemID: coverFacts.coverItemID
            )
            : []
        let narrativeRewrite = periodFacts.narrativeRewrite
        let marks = Array(
            narrativeMarks(
                rankedMarks,
                items: input.allItems,
                plan: narrativePlan
            ).prefix(2)
        )

        return TraceChapterSnapshot(
            range: input.range,
            items: input.items,
            periodFacts: periodFacts,
            marks: marks,
            memoryAnchors: anchors,
            monthDiaryAnchors: monthDiaryAnchors,
            coverFacts: coverFacts,
            narrativePlan: narrativePlan,
            narrativeRewrite: narrativeRewrite,
            narrative: narrativeRewrite?.headline ?? narrativePlan.headline,
            chapterSummary: narrativeRewrite?.summary ?? narrativePlan.summary,
            evidenceGroups: evidenceGroups(from: input.items, marks: marks, maxItems: 3),
            preview: launchPreview(for: input.range, items: input.items)
        )
    }

    static func buildClue(_ input: TraceClueComputationInput) -> TraceClueSnapshot {
        let clues = categoryClues(from: input.items)
        let rhythmPoints = rhythmPoints(from: input.items, period: input.period, now: input.now)
        let journeyFact = input.narrativeScope.flatMap { scope in
            LifeJourneyFactService.primaryFact(
                in: input.items,
                calendar: scope == .week ? PlaybackService.isoCalendar : Calendar.current
            )
        }
        let narrativePlan = input.narrativeScope.map { scope in
            makeNarrativePlan(
                scope: scope,
                sourceRevision: input.sourceRevision,
                items: input.items,
                allItems: input.allItems,
                journeyFact: journeyFact,
                now: input.now
            )
        }
        let narrativeRewrite = input.allowsNarrativeRewrite
            && narrativePlan?.leadSignalID != journeyFact?.id
            ? input.narrativeScope.flatMap { scope in
                LifeNarrativeAIRewriteStore.shared.rewrite(
                    for: LifeNarrativeAIPreparationPolicy.key(
                        scope: scope,
                        sourceRevision: input.sourceRevision,
                        now: input.now,
                        calendar: scope == .week ? PlaybackService.isoCalendar : Calendar.current
                    )
                )
            }
            : nil
        let insight = narrativePlan.map {
            narrativeInsight(
                plan: $0,
                rewrite: narrativeRewrite,
                items: input.items,
                allItems: input.allItems,
                journeyFact: journeyFact
            )
        } ?? LifeInsightService().buildTraceInsight(
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
        let rankedMarks = prioritizedMarks(
            rawMarks,
            items: input.items,
            prioritizeRecurring: input.period == .month
        )
        let marks = Array(
            narrativeMarks(
                rankedMarks,
                items: input.allItems,
                plan: narrativePlan
            ).prefix(6)
        )
        let rawLockedMark = input.isMember
            ? nil
            : LifeMarkService.lockedPreview(for: input.items, allItems: input.allItems)
        let itemByID = Dictionary(
            input.allItems.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        let lockedMark = rawLockedMark.flatMap { mark in
            isAdministrativeMark(mark, itemByID: itemByID) ? nil : mark
        }
        let isUnlocked = !insight.isMeaningful || input.storedUnlock
        let canUse = insight.isMeaningful
            && !input.items.isEmpty
            && (input.storedUnlock || input.freeRemaining > 0)

        return TraceClueSnapshot(
            items: input.items,
            clues: clues,
            rhythmPoints: rhythmPoints,
            journeyFact: journeyFact,
            insight: insight,
            narrativePlan: narrativePlan,
            narrativeRewrite: narrativeRewrite,
            marks: marks,
            lockedMark: lockedMark,
            isDeepInsightUnlocked: isUnlocked,
            canUseDeepInsight: canUse,
            freeInsightRemaining: input.freeRemaining
        )
    }

    private static func makeNarrativePlan(
        scope: LifeNarrativeScope,
        sourceRevision: Int,
        items: [HomeItem],
        allItems: [HomeItem],
        journeyFact: LifeJourneyFact?,
        now: Date
    ) -> LifeNarrativePlan {
        let calendar = scope == .week ? PlaybackService.isoCalendar : Calendar.current
        let previousItems = previousPeriodItems(scope: scope, allItems: allItems, now: now)
        let relationshipEcho = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: scope,
                sourceRevision: sourceRevision,
                items: allItems,
                now: now,
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        return LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: scope,
                sourceRevision: sourceRevision,
                items: items,
                previousItems: previousItems,
                now: now,
                recentLeadSignalIDs: LifeNarrativeSignalPolicy.recentStableSignalIDs(from: previousItems),
                relationshipEcho: relationshipEcho,
                journeyFact: journeyFact
            )
        )
    }

    private static func preferredNarrativeAnchorItemID(
        plan: LifeNarrativePlan,
        items: [HomeItem]
    ) -> UUID? {
        guard let lead = plan.signalsByRole[.lead]?.first,
              lead.kind == .photo || lead.kind == .userText || lead.kind == .change else {
            return nil
        }
        let evidenceIDs = Set(lead.evidenceItemIDs)
        return items.first { item in
            evidenceIDs.contains(item.id) && item.hasMemoryImages
        }?.id
    }

    private static func previousPeriodItems(
        scope: LifeNarrativeScope,
        allItems: [HomeItem],
        now: Date
    ) -> [HomeItem] {
        let calendar = scope == .week ? PlaybackService.isoCalendar : Calendar.current
        let component: Calendar.Component = scope == .week ? .weekOfYear : .month
        guard let current = calendar.dateInterval(of: component, for: now),
              let previousStart = calendar.date(byAdding: component, value: -1, to: current.start) else {
            return []
        }
        return allItems.filter {
            $0.createdAt >= previousStart && $0.createdAt < current.start
        }
    }

    private static func narrativeInsight(
        plan: LifeNarrativePlan,
        rewrite: LifeNarrativeAIRewrite?,
        items: [HomeItem],
        allItems: [HomeItem],
        journeyFact: LifeJourneyFact?
    ) -> LifeInsightResult {
        let lead = plan.signalsByRole[.lead]?.first
        let support = plan.signalsByRole[.support]?.first
        let displayedSummary = rewrite?.summary ?? plan.summary
        var fullLines: [String] = []
        let isJourneyLead = lead?.id == journeyFact?.id
        let isRelationshipLead = lead?.id.hasPrefix("echo:") == true || isJourneyLead
        if isJourneyLead, let journeyFact {
            fullLines.append(journeyFact.line)
            fullLines.append(
                "依据来自 \(journeyFact.roadEvidenceItemIDs.count) 笔道路记录和 \(journeyFact.activityEvidenceItemIDs.count) 笔异地活动记录。"
            )
        } else if !isRelationshipLead {
            if let supportingLine = rewrite?.supportingLine, !supportingLine.isEmpty {
                fullLines.append(supportingLine)
            } else if let support, support.fact != displayedSummary {
                fullLines.append(support.fact)
            }
        }
        if let lead, isRelationshipLead, !isJourneyLead {
            fullLines.append(contentsOf: relationshipEvidenceLines(
                lead: lead,
                currentItems: items,
                allItems: allItems
            ))
        } else if let lead,
           let item = items.first(where: { lead.evidenceItemIDs.contains($0.id) }),
           lead.kind == .userText || lead.kind == .photo {
            if lead.kind == .photo {
                fullLines.append("\(item.createdAt.zhBillDateOnly)的照片，是这条线索的直接依据。")
            } else {
                fullLines.append("\(item.createdAt.zhBillDateOnly)的「\(lead.label)」，是这条线索的直接依据。")
            }
        }
        if fullLines.isEmpty {
            fullLines.append(narrativeEvidenceLine(lead: lead, items: items))
        }
        let theme: LifeInsightTheme
        if lead?.id.hasPrefix("echo:") == true || isJourneyLead {
            theme = .relation
        } else {
            switch lead?.kind {
            case .userText, .photo: theme = .memory
            case .change: theme = .change
            case .structuredScene: theme = .relation
            case .rhythm, .stableMark, nil:
                theme = plan.maturity == .factual ? .forming : .steady
            }
        }
        let highlightedDate = lead?.evidenceItemIDs.compactMap { id in
            items.first(where: { $0.id == id })?.createdAt
        }.first
        let highlightedItemID = lead?.evidenceItemIDs.first { id in
            guard let item = items.first(where: { $0.id == id }) else { return false }
            return lead?.kind == .photo ? item.hasMemoryImages : true
        }
        let isMeaningful = lead.map {
            $0.kind != .rhythm && $0.narrativeValue >= 55 && !$0.isAdministrative
        } ?? false
        let teaser: String
        if items.isEmpty {
            teaser = "这一段暂时没有可以核对的记录。"
        } else if isMeaningful {
            teaser = "展开后可以核对这条主线对应的日期和记录。"
        } else {
            teaser = "先看记录落在哪些日子，再决定要不要继续问。"
        }
        return LifeInsightResult(
            leadQuestion: narrativeInsightTitle(
                lead: lead,
                maturity: plan.maturity,
                items: items
            ),
            teaser: teaser,
            previewLine: fullLines[0],
            fullLines: Array(fullLines.prefix(2)),
            questionChips: [],
            periodName: "\(plan.scope.periodLead)的线索依据",
            theme: theme,
            highlightedDate: highlightedDate,
            highlightedItemID: highlightedItemID,
            isMeaningful: isMeaningful
        )
    }

    private static func narrativeInsightTitle(
        lead: LifeNarrativeSignal?,
        maturity: LifeNarrativeMaturity,
        items: [HomeItem]
    ) -> String {
        if let lead, lead.id.hasPrefix("journey:") {
            return "这次\(lead.label)是怎么串起来的"
        }
        if lead?.id.contains(":context-return:") == true {
            return "晚间通勤上一次出现在哪一周"
        }
        if lead?.id.contains(":new-pair:") == true {
            return "咖啡和晚间通勤这次有什么不同"
        }
        if let lead,
           lead.kind == .userText || lead.kind == .photo,
           let item = items.first(where: { lead.evidenceItemIDs.contains($0.id) }),
           let trustedMomentLine = TrustedUserMomentNarrativePolicy.line(for: item) {
            return trustedMomentLine
        }
        switch lead?.kind {
        case .userText: return "先看「\(lead?.label ?? "这笔记录")」"
        case .photo: return "这张照片对应哪一笔"
        case .change: return "\(lead?.label ?? "这处")的变化来自哪些记录"
        case .structuredScene: return "\(lead?.label ?? "这条生活线")出现在哪些日子"
        case .rhythm, .stableMark, nil:
            if maturity == .empty { return "这段还没有记录" }
            return maturity == .factual ? "这段线索还在形成" : "记录主要落在这些日子"
        }
    }

    private static func relationshipEvidenceLines(
        lead: LifeNarrativeSignal,
        currentItems: [HomeItem],
        allItems: [HomeItem]
    ) -> [String] {
        let evidenceIDs = Set(lead.evidenceItemIDs)
        let currentIDs = Set(currentItems.map(\.id))
        let currentEvidence = currentItems.filter { evidenceIDs.contains($0.id) }
        let historicalEvidence = allItems.filter {
            evidenceIDs.contains($0.id) && !currentIDs.contains($0.id)
        }
        let currentDays = distinctEvidenceDays(currentEvidence)
        let historicalDays = distinctEvidenceDays(historicalEvidence)

        if lead.id.contains(":new-pair:") {
            var lines = ["本周有 \(currentDays.count) 个记录日同时留下了这两个场景。"]
            if !historicalEvidence.isEmpty {
                lines.append("历史基线覆盖 \(historicalEvidence.count) 个有记录的周，没有发现同类组合。")
            }
            return lines
        }
        if lead.id.contains(":context-return:") {
            var lines = ["本周依据来自 \(currentDays.count) 个不同日期的晚间通勤。"]
            if let first = historicalDays.first, let last = historicalDays.last {
                let range = first == last
                    ? first.zhBillDateOnly
                    : "\(first.zhBillDateOnly)至\(last.zhBillDateOnly)"
                lines.append("上一组可核对记录在 \(range)。")
            }
            return lines
        }
        return [narrativeEvidenceLine(lead: lead, items: currentItems)]
    }

    private static func distinctEvidenceDays(_ items: [HomeItem]) -> [Date] {
        Array(Set(items.map { Calendar.current.startOfDay(for: $0.createdAt) })).sorted()
    }

    private static func narrativeEvidenceLine(
        lead: LifeNarrativeSignal?,
        items: [HomeItem]
    ) -> String {
        guard !items.isEmpty else { return "这一段暂时没有可以核对的记录。" }
        let currentEvidenceCount = lead.map { signal in
            let evidenceIDs = Set(signal.evidenceItemIDs)
            return items.filter { evidenceIDs.contains($0.id) }.count
        } ?? 0
        if currentEvidenceCount > 0 {
            return "当前页有 \(currentEvidenceCount) 笔记录直接支持这条判断。"
        }
        let activeDays = Set(items.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
        return "当前页有 \(items.count) 笔记录，分布在 \(activeDays) 个记录日。"
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

    private static func narrativeMarks(
        _ marks: [LifeMarkAggregate],
        items: [HomeItem],
        plan: LifeNarrativePlan?
    ) -> [LifeMarkAggregate] {
        let itemByID = Dictionary(
            items.map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        let safeMarks = marks.filter { !isAdministrativeMark($0, itemByID: itemByID) }
        guard let plan else { return safeMarks }
        let planMarks = plan.signalsByRole[.mark, default: []]
        let preferredLabels = Set(planMarks.map { normalizedMarkLabel($0.label) })
        let preferredItemIDs = Set(planMarks.flatMap(\.evidenceItemIDs))
        return safeMarks.enumerated()
            .sorted { lhs, rhs in
                let leftPreferred = isPreferredMark(
                    lhs.element,
                    labels: preferredLabels,
                    itemIDs: preferredItemIDs
                )
                let rightPreferred = isPreferredMark(
                    rhs.element,
                    labels: preferredLabels,
                    itemIDs: preferredItemIDs
                )
                if leftPreferred != rightPreferred { return leftPreferred }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    private static func isPreferredMark(
        _ mark: LifeMarkAggregate,
        labels: Set<String>,
        itemIDs: Set<UUID>
    ) -> Bool {
        if labels.contains(normalizedMarkLabel(markDisplayLabel(mark))) { return true }
        guard mark.kind == .scene else { return false }
        return !itemIDs.isDisjoint(with: Set(mark.itemIDs))
    }

    private static func isAdministrativeMark(
        _ mark: LifeMarkAggregate,
        itemByID: [UUID: HomeItem]
    ) -> Bool {
        let evidence = mark.itemIDs.compactMap { itemByID[$0] }
        return !evidence.isEmpty && evidence.allSatisfy {
            LifeNarrativeSignalPolicy.isAdministrativeRecord($0)
        }
    }

    private static func normalizedMarkLabel(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && !"，。！？；：,.!?;:·".contains($0) }
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
        let groupedRows: [HomeItem.Category: [HomeItem]] = Dictionary(grouping: rows, by: { $0.category })
        var categories: [CategoryPreviewRow] = []
        categories.reserveCapacity(groupedRows.count)
        for (category, groupedItems) in groupedRows {
            let categoryTotal = groupedItems.reduce(0.0) { partial, item in
                partial + item.amount
            }
            categories.append(
                CategoryPreviewRow(
                    name: category.rawValue,
                    count: groupedItems.count,
                    amount: categoryTotal
                )
            )
        }
        categories.sort { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.amount > rhs.amount
            }
            return lhs.count > rhs.count
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
            topCategory: categories.first?.name
        )
    }

    private static func categoryClues(from items: [HomeItem]) -> [TraceCategoryClue] {
        guard !items.isEmpty else { return [] }
        let totalCount = Double(items.count)
        let groupedItems: [HomeItem.Category: [HomeItem]] = Dictionary(grouping: items, by: { $0.category })
        var clues: [TraceCategoryClue] = []
        clues.reserveCapacity(groupedItems.count)
        for (category, categoryItems) in groupedItems {
            let categoryTotal = categoryItems.reduce(0.0) { partial, item in
                partial + item.amount
            }
            clues.append(
                TraceCategoryClue(
                    category: category,
                    count: categoryItems.count,
                    total: categoryTotal,
                    ratio: Double(categoryItems.count) / totalCount
                )
            )
        }
        clues.sort { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.total > rhs.total
            }
            return lhs.count > rhs.count
        }
        return clues
    }

    private static func rhythmPoints(
        from items: [HomeItem],
        period: StatsPeriod,
        now: Date
    ) -> [TraceRhythmPoint] {
        guard !items.isEmpty else { return [] }
        let calendar = Calendar.current
        let groupedByDay: [Date: [HomeItem]] = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.createdAt)
        }
        let countsByDay: [Date: Int] = groupedByDay.mapValues { dayItems in
            dayItems.count
        }

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
        case .experience: return role == .receipt ? "票据" : "现场"
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

enum TraceSnapshotMemoryPolicy {
    static let chapterCacheLimit = 2
    static let clueCacheLimit = 4
}

final class TraceSnapshotStore {
    private var chapterCache: [String: TraceChapterSnapshot] = [:]
    private var chapterCacheOrder: [String] = []
    private let chapterCacheLimit = TraceSnapshotMemoryPolicy.chapterCacheLimit

    private var clueCache: [String: TraceClueSnapshot] = [:]
    private var clueCacheOrder: [String] = []
    private let clueCacheLimit = TraceSnapshotMemoryPolicy.clueCacheLimit

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

enum LedgerDisplayFingerprintPolicy {
    static func make(items: [HomeItem]) -> String {
        var xor: UInt64 = 0
        var sum: UInt64 = 14_695_981_039_346_656_037
        for item in items {
            let hash = itemHash(item)
            xor ^= hash
            sum &+= hash &* 1_099_511_628_211
        }
        return [
            "trace-cold-start-v2",
            String(items.count),
            String(xor, radix: 16),
            String(sum, radix: 16),
        ].joined(separator: "|")
    }

    private static func itemHash(_ item: HomeItem) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        func combine(_ value: String) {
            for byte in value.utf8 {
                hash ^= UInt64(byte)
                hash &*= prime
            }
            hash ^= 0xFF
            hash &*= prime
        }

        combine(item.id.uuidString)
        combine(String(Int64((item.createdAt.timeIntervalSince1970 * 1_000).rounded())))
        combine(String(Int64((item.updatedAt.timeIntervalSince1970 * 1_000).rounded())))
        combine(String(Int64((item.amount * 100).rounded())))
        combine(item.category.rawValue)
        combine(item.title)
        combine(item.emotionTag)
        combine(item.source.rawValue)
        combine(item.merchantBrandId ?? "")
        combine(item.draftMeta?.status.rawValue ?? "")
        combine(item.userEditedTitle == true ? "1" : "0")
        combine(item.userEditedCategory == true ? "1" : "0")
        combine(item.memoryContext?.weatherKind ?? "")
        combine(item.memoryContext?.cityName ?? "")
        combine(item.memoryContext?.semanticPlace ?? "")
        combine(item.scenePackId ?? "")
        combine(String(item.memoryImageCount))
        combine(item.memoryImageReferences.joined(separator: "|"))
        combine(String(item.coverMemoryImageIndex ?? -1))
        combine(item.memoryAnchorRole?.rawValue ?? "")
        combine(item.memoryAnchorSceneHint?.rawValue ?? "")
        combine(item.memoryAnchorCaption ?? "")
        return hash
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

final class TraceColdStartDisplayStore {
    static let shared = TraceColdStartDisplayStore()

    private let defaults: UserDefaults
    private let storageKey: String
    private let entryLimit = 12

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "trace.cold-start-display.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func entry(
        for context: TraceColdStartDisplayContext,
        scopeKey: String
    ) -> TraceColdStartDisplayEntry? {
        guard let cache = loadCache(),
              cache.schemaVersion == TraceColdStartDisplayCache.schemaVersion,
              cache.context == context else {
            return nil
        }
        return cache.entries[scopeKey]
    }

    func store(
        _ entry: TraceColdStartDisplayEntry,
        context: TraceColdStartDisplayContext
    ) {
        var cache = loadCache()
        if cache?.schemaVersion != TraceColdStartDisplayCache.schemaVersion || cache?.context != context {
            cache = TraceColdStartDisplayCache(
                schemaVersion: TraceColdStartDisplayCache.schemaVersion,
                context: context,
                entries: [:]
            )
        }
        guard var cache else { return }
        cache.entries[entry.scopeKey] = entry
        while cache.entries.count > entryLimit,
              let staleKey = cache.entries.min(by: { $0.value.savedAt < $1.value.savedAt })?.key {
            cache.entries.removeValue(forKey: staleKey)
        }
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func removeAllForTesting() {
        defaults.removeObject(forKey: storageKey)
    }

    private func loadCache() -> TraceColdStartDisplayCache? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        guard let cache = try? JSONDecoder().decode(TraceColdStartDisplayCache.self, from: data) else {
            defaults.removeObject(forKey: storageKey)
            return nil
        }
        return cache
    }
}
