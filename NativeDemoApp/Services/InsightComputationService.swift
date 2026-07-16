import Foundation

struct InsightComputationInput: @unchecked Sendable {
    let items: [HomeItem]
    let isMember: Bool
    let now: Date
}

struct MonthlyInsightPreparation: @unchecked Sendable {
    let blocks: (summary: String, structure: String, advice: String)
    let monthItems: [HomeItem]
    let snapshot: AISnapshot
}

enum InsightComputationService {
    private struct KeywordDraft {
        enum Source {
            case hero
            case userTitle
            case lifeMark
            case amountTitle
            case emotion
            case context
            case category
        }

        let text: String
        let score: Int
        let category: HomeItem.Category
        let priority: Int
        let source: Source
    }

    static func weeklyPageSnapshot(_ input: InsightComputationInput) -> InsightPageSnapshot {
        let blocks = weeklyBlocks(input)
        let weekItems = recentPositiveItems(input.items, days: 7, now: input.now)
        let bubbleItems = flexibleBubblePositiveItems(input.items, now: input.now)
        return InsightPageSnapshot(
            journalText: weeklyJournalText(blocks, weekItems: weekItems, now: input.now),
            journalClosing: weeklyJournalClosing(blocks),
            rhythmText: weeklyRhythmText(input.items, now: input.now),
            keywords: weeklyKeywordBubbles(
                from: bubbleItems,
                allItems: input.items,
                now: input.now
            )
        )
    }

    static func monthlyPreparation(_ input: InsightComputationInput) -> MonthlyInsightPreparation {
        let monthItems = items(in: .month, from: input.items, now: input.now)
        let positiveMonthItems = monthItems.filter { $0.amount > 0 }
        let blocks = monthlyBlocks(
            monthItems: monthItems,
            allItems: input.items,
            isMember: input.isMember,
            now: input.now
        )
        let grouped = Dictionary(grouping: positiveMonthItems, by: \.category)
            .map { key, value in
                (category: key, amount: value.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.amount > $1.amount }
        let todayTotal = input.items
            .filter { Calendar.current.isDate($0.createdAt, inSameDayAs: input.now) && $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
        let weekItems = items(in: .week, from: input.items, now: input.now)
        let weekAverage = weekItems.isEmpty ? 0 : weekItems.reduce(0) { $0 + $1.amount } / 7
        let monthTotal = positiveMonthItems.reduce(0) { $0 + $1.amount }
        let snapshot = AISnapshot(
            date: monthKey(for: input.now),
            todayTotal: todayTotal,
            weekAverage: weekAverage,
            monthTotal: monthTotal,
            topCategories: grouped.prefix(3).map { $0.category.rawValue }
        )
        return MonthlyInsightPreparation(blocks: blocks, monthItems: monthItems, snapshot: snapshot)
    }

    private static func weeklyBlocks(
        _ input: InsightComputationInput
    ) -> (summary: String, structure: String, advice: String) {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -6, to: input.now) else {
            return ("近 7 天暂无复盘。", "", "")
        }
        let weekItems = input.items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return ("近 7 天暂无复盘。多记几笔，就能看到更完整的消费节奏啦。", "", "")
        }
        if let memoryLine = contextualMemoryLine(from: weekItems) {
            let structure = weekItems.contains(where: { $0.hasMemoryImages })
                ? photoStructureLine(from: weekItems, fallback: "这一周的记录里，天气、城市和照片都能成为回看线索。")
                : "这一周的记录里，天气、城市和重复出现的场景已经能连起来看。"
            let advice = weekItems.count >= 8
                ? "继续按真实时间记，之后可以按时间线回看。"
                : "再多记几笔，天气和地点线索会更容易浮出来。"
            return (memoryLine, structure, advice)
        }
        if let photoLine = photoMemoryLine(from: weekItems, periodName: "近 7 天") {
            return (
                photoLine,
                photoStructureLine(from: weekItems, fallback: "这一周有照片的记录会优先成为回看线索。"),
                "照片只是补充，不用每笔都拍；遇到想记住的瞬间再留下就好。"
            )
        }
        if let mark = LifeMarkService.aggregates(
            for: weekItems,
            allItems: input.items,
            isMember: input.isMember,
            now: input.now,
            limit: 1
        ).first,
           mark.count >= 2 || mark.kind != .scene {
            let advice = mark.access == .member
                ? "继续按真实时间记，天气、城市、首次和连续性会更容易被串起来。"
                : "继续按笔记下去，后面会更容易按时间回看。"
            return (
                LifeMarkService.primaryLine(for: mark),
                "这一周「\(mark.label)」出现得更集中。",
                advice
            )
        }
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems), scene.count >= 2 {
            let copy = LifeSceneSemanticService.weeklyCopy(for: scene.signal, count: scene.count)
            return (
                LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count),
                "这一周更明显的是「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」这条线。",
                weekItems.count >= 8
                    ? "继续按笔记下去，下周的周记会更贴近真实记录。"
                    : copy.cares.dropFirst().first ?? "再多记几笔，这一周会更容易回头看。"
            )
        }
        let topCategory = topCategoryLabel(from: weekItems)
        return (
            "近 7 天里，「\(topCategory)」记得更多一些。",
            "这一周的记录已经分出几段。",
            weekItems.count >= 8
                ? "继续按笔记下去，下周的周记会更贴近真实记录。"
                : "再多记几笔，这一周会更容易回头看。"
        )
    }

    private static func monthlyBlocks(
        monthItems: [HomeItem],
        allItems: [HomeItem],
        isMember: Bool,
        now: Date
    ) -> (summary: String, structure: String, advice: String) {
        let positive = monthItems.filter { $0.amount > 0 }
        let total = positive.reduce(0) { $0 + $1.amount }
        let top = topCategoryCountLabel(from: monthItems)
        let summary: String
        if total <= 0 {
            summary = "本月还没有足够账单，多记几笔再来生成月度整理吧。"
        } else if let memoryLine = contextualMemoryLine(from: positive) {
            summary = memoryLine
        } else if let photoLine = photoMemoryLine(from: positive, periodName: "这个月") {
            summary = photoLine
        } else if let mark = LifeMarkService.aggregates(
            for: positive,
            allItems: allItems,
            isMember: isMember,
            now: now,
            limit: 1
        ).first,
                  mark.count >= 2 || mark.kind != .scene {
            summary = LifeMarkService.primaryLine(for: mark)
        } else if let scene = LifeSceneSemanticService.dominantScene(in: positive), scene.count >= 2 {
            summary = LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
        } else {
            summary = "这个月的记录里，「\(top)」出现得比较多。"
        }
        let structure: String
        if total <= 0 {
            structure = "等本月多几笔记录，再整理这段时间的变化。"
        } else if positive.contains(where: { $0.hasMemoryImages }) {
            structure = photoStructureLine(from: positive, fallback: "这个月有几笔记录带着照片，回看时会更像生活片段。")
        } else if positive.contains(where: { $0.memoryContext?.weatherKind != nil || $0.memoryContext?.cityName != nil }) {
            structure = "这个月不只看分类，也能看到天气、城市和当天场景留下的线索。"
        } else if let mark = LifeMarkService.aggregates(
            for: positive,
            allItems: allItems,
            isMember: isMember,
            now: now,
            limit: 1
        ).first,
                  mark.count >= 2 || mark.kind != .scene {
            structure = "这个月「\(mark.label)」出现得更集中。"
        } else if let scene = LifeSceneSemanticService.dominantScene(in: positive), scene.count >= 2 {
            structure = "这个月更明显的是「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」这条线。"
        } else {
            structure = "「\(top)」是这个月比较明显的一类。"
        }
        return (
            summary,
            structure,
            total <= 0 ? "先记下一周，复盘会更有内容。" : "这个月已经有一些记录，继续记几天，月度整理会更完整。"
        )
    }

    private static func weeklyJournalText(
        _ blocks: (summary: String, structure: String, advice: String),
        weekItems: [HomeItem],
        now: Date
    ) -> String {
        if blocks.summary.contains("暂无复盘") {
            return "近 7 天记录还不多。多记几笔，这里会整理成一段周记。"
        }
        let countText = weekItems.isEmpty ? "这周还没留下太多记录" : "这周记下 \(weekItems.count) 笔"
        let totalText = weekItems.isEmpty ? "" : "，合计 \(weekItems.reduce(0) { $0 + $1.amount }.formatted(.cny))"
        var text = "\(countText)\(totalText)。\(blocks.summary)\(blocks.structure)"
        if weekItems.count < 3,
           let anchor = EchoAnchorService.shared.pickEchoAnchor(
               items: weekItems,
               periodKey: EchoAnchorService.shared.periodKeyForWeek(now: now),
               now: now
           ) {
            let sentence = EchoAnchorService.shared.formatEchoAnchorSentence(anchor)
            if !sentence.isEmpty { text += sentence }
        }
        return text
    }

    private static func weeklyJournalClosing(
        _ blocks: (summary: String, structure: String, advice: String)
    ) -> String {
        blocks.summary.contains("暂无复盘")
            ? "等记录多一点，再回来读这一周。"
            : "下周有新记录，再回来对照。"
    }

    private static func weeklyRhythmText(_ items: [HomeItem], now: Date) -> String {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -6, to: now) else {
            return "这周的记录还不够完整，先继续记几笔。"
        }
        let weekItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return "这周还没有足够账单，先不用急着复盘。多记几笔后，节奏会更清楚。"
        }
        let activeDays = Set(weekItems.map { calendar.startOfDay(for: $0.createdAt) }).count
        let rhythm = activeDays >= 5 ? "这周几乎每天都有记录" : "这周的记录主要落在 \(activeDays) 天里"
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems), scene.count >= 2 {
            return "\(rhythm)，\(LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count))。"
        }
        let top = topCategoryCountLabel(from: weekItems)
        return top == "暂无"
            ? "\(rhythm)，先把这一周放在这里。"
            : "\(rhythm)，「\(top)」记得更多一点。先把这一周放在这里。"
    }

    private static func weeklyKeywordBubbles(
        from items: [HomeItem],
        allItems: [HomeItem],
        now: Date
    ) -> [KeywordBubbleData] {
        guard items.count >= 3 else { return [] }
        let targetCount = items.count >= 5 ? 6 : 3
        return diversifiedBubbleCandidates(
            weeklyBubbleCandidates(from: items, allItems: allItems, now: now),
            targetCount: targetCount
        ).map {
            KeywordBubbleData(text: $0.text, count: $0.score, category: $0.category, priority: $0.priority)
        }
    }

    private static func weeklyBubbleCandidates(
        from items: [HomeItem],
        allItems: [HomeItem],
        now: Date
    ) -> [KeywordDraft] {
        var candidates = LifeMarkService.aggregates(
            for: items,
            allItems: allItems,
            isMember: true,
            now: now,
            limit: 6
        ).compactMap { mark -> KeywordDraft? in
            guard let text = bubbleText(for: mark) else { return nil }
            return KeywordDraft(
                text: text,
                score: 9_200 + lifeMarkBubbleScoreBoost(mark) + mark.count * 180,
                category: mark.category,
                priority: lifeMarkBubblePriority(mark),
                source: .lifeMark
            )
        }
        let userTitles = items.compactMap { item -> (HomeItem, String)? in
            guard item.userEditedTitle == true,
                  let text = preferredBubbleTitle(from: item, allowsFullTitle: true) else { return nil }
            return (item, text)
        }
        let heroID = userTitles.max {
            $0.0.amount == $1.0.amount ? $0.1.count < $1.1.count : $0.0.amount < $1.0.amount
        }?.0.id
        for (item, text) in userTitles {
            let isHero = item.id == heroID
            candidates.append(
                KeywordDraft(
                    text: text,
                    score: isHero ? 10_000 + Int(item.amount.rounded()) + text.count * 8 : 7_000 + text.count * 120 + Int(item.amount.rounded()),
                    category: item.category,
                    priority: isHero ? 0 : 1,
                    source: isHero ? .hero : .userTitle
                )
            )
        }
        for item in items where item.id != heroID {
            if let text = preferredBubbleTitle(from: item, allowsFullTitle: false) {
                candidates.append(KeywordDraft(text: text, score: 4_000 + Int(item.amount.rounded()) + text.count * 10, category: item.category, priority: 2, source: .amountTitle))
            }
            let emotion = normalizedKeyword(item.displayEmotionTag, maxLength: 10)
            if !emotion.isEmpty, emotion != HomeItem.inferEmotionTag(category: item.category, amount: item.amount) {
                candidates.append(KeywordDraft(text: emotion, score: 2_000 + Int(item.amount.rounded() / 2), category: item.category, priority: 3, source: .emotion))
            }
            if let context = item.memoryContext {
                if context.weatherKind == "rain" {
                    let text: String
                    if item.category == .transport {
                        text = "雨天出行"
                    } else if let city = context.cityName, context.semanticPlace == "外地" {
                        text = "\(city)雨天"
                    } else {
                        text = "雨天生活"
                    }
                    candidates.append(KeywordDraft(text: text, score: 3_200 + Int(item.amount.rounded()) + (context.semanticPlace == "外地" ? 420 : 0), category: item.category, priority: 2, source: .context))
                }
                if let city = context.cityName, context.semanticPlace == "外地" {
                    candidates.append(KeywordDraft(text: "\(city)一日", score: 2_800 + Int(item.amount.rounded()), category: item.category, priority: 3, source: .context))
                }
            }
        }
        for rows in Dictionary(grouping: items, by: { LifeSceneSemanticService.classify($0).kind }).values {
            guard let scene = LifeSceneSemanticService.dominantScene(in: rows) else { continue }
            candidates.append(
                KeywordDraft(
                    text: LifeSceneSemanticService.displayTheme(for: scene.signal),
                    score: 1_000 + rows.count * 80 + Int(rows.reduce(0) { $0 + $1.amount }.rounded() / 10),
                    category: scene.signal.category,
                    priority: 4,
                    source: .category
                )
            )
        }
        return bestCandidatePerText(candidates)
    }

    private static func flexibleBubblePositiveItems(_ items: [HomeItem], now: Date) -> [HomeItem] {
        let currentWeek = Self.items(in: .week, from: items, now: now).filter { $0.amount > 0 }
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now
        let weekIDs = Set(currentWeek.map(\.id))
        return currentWeek + items.filter { $0.amount > 0 && $0.updatedAt >= recentCutoff && !weekIDs.contains($0.id) }
    }

    private static func recentPositiveItems(_ items: [HomeItem], days: Int, now: Date) -> [HomeItem] {
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: now) ?? now
        return items.filter { $0.createdAt >= start && $0.amount > 0 }
    }

    private static func items(in period: HomeViewModel.Period, from items: [HomeItem], now: Date) -> [HomeItem] {
        let interval = period == .week
            ? PlaybackService.isoCalendar.dateInterval(of: .weekOfYear, for: now)
            : Calendar.current.dateInterval(of: .month, for: now)
        guard let interval else { return [] }
        return items
            .filter { $0.createdAt >= interval.start && $0.createdAt < interval.end }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func contextualMemoryLine(from target: [HomeItem]) -> String? {
        let sorted = target.sorted { $0.createdAt > $1.createdAt }
        if let item = sorted.first(where: { HomeItem.isLateWorkCommute($0) }),
           let line = HomeItem.lateWorkCommuteTraceLine(for: item) { return line }
        if let item = sorted.first(where: { $0.category == .transport && $0.memoryContext?.weatherKind == "rain" }) {
            if let city = item.memoryContext?.cityName, item.memoryContext?.semanticPlace == "外地" {
                return "\(city)那次雨天出行和这笔记录有关。"
            }
            return "有一次雨天出行，天气和那笔交通记录有关。"
        }
        if let item = sorted.first(where: { $0.memoryContext?.semanticPlace == "外地" }),
           let city = item.memoryContext?.cityName {
            return "这段时间有一笔在\(city)留下的记录，位置变化也进入了回望。"
        }
        if let item = sorted.first(where: { $0.memoryContext?.weatherKind == "rain" }) {
            return "\(item.createdAt.zhBillDateTime)那天有雨，这笔记录带着当天的天气信息。"
        }
        return sorted.first {
            let text = $0.displayEmotionTag
            return text.contains("第一次") || text.contains("第10次") || text.contains("连续") || text.contains("周末出门")
        }?.displayEmotionTag ?? photoMemoryLine(from: sorted, periodName: "这段时间")
    }

    private static func photoMemoryLine(from target: [HomeItem], periodName: String) -> String? {
        let photoItems = target.filter { $0.amount > 0 && $0.hasMemoryImages }.sorted {
            $0.memoryImageCount == $1.memoryImageCount
                ? $0.createdAt > $1.createdAt
                : $0.memoryImageCount > $1.memoryImageCount
        }
        guard let first = photoItems.first else { return nil }
        if photoItems.count >= 2 {
            return "\(periodName)留下了 \(photoItems.count) 个有照片的消费时刻，照片让这些记录更像生活。"
        }
        let title = first.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = title.isEmpty || EchoAnchorService.shared.isDirtyTraceTitle(title) ? first.category.rawValue : title
        return "\(first.createdAt.zhBillDateTime)的「\(clean)」留了照片，这一笔以后会更容易想起来。"
    }

    private static func photoStructureLine(from target: [HomeItem], fallback: String) -> String {
        let positive = target.filter { $0.amount > 0 }
        let photoCount = positive.filter(\.hasMemoryImages).count
        guard photoCount > 0 else { return fallback }
        return photoCount == 1
            ? "这一段有 1 笔记录带着照片，它会成为回看时更具体的锚点。"
            : "这一段 \(positive.count) 笔记录里，有 \(photoCount) 个照片锚点，适合以后写成日记或周记。"
    }

    private static func topCategoryLabel(from target: [HomeItem]) -> String {
        Dictionary(grouping: target, by: \.category).max { lhs, rhs in
            lhs.value.reduce(0) { $0 + $1.amount } < rhs.value.reduce(0) { $0 + $1.amount }
        }?.key.label ?? "生活"
    }

    private static func topCategoryCountLabel(from target: [HomeItem]) -> String {
        Dictionary(grouping: target, by: \.category).max { $0.value.count < $1.value.count }?.key.rawValue ?? "暂无"
    }

    private static func bubbleText(for mark: LifeMarkAggregate) -> String? {
        let raw: String
        switch mark.kind {
        case .milestone: raw = mark.title
        case .context, .scene: raw = mark.label
        case .streak:
            raw = mark.label.hasPrefix("连续") ? "一段\(mark.label.replacingOccurrences(of: "连续", with: ""))节奏" : mark.label
        }
        let text = normalizedKeyword(raw, maxLength: 12)
        return text.isEmpty ? nil : text
    }

    private static func lifeMarkBubblePriority(_ mark: LifeMarkAggregate) -> Int {
        switch mark.kind { case .milestone: return 0; case .context: return 1; case .scene: return 2; case .streak: return 4 }
    }

    private static func lifeMarkBubbleScoreBoost(_ mark: LifeMarkAggregate) -> Int {
        switch mark.kind { case .milestone: return 1_400; case .context: return 900; case .scene: return 650; case .streak: return 260 }
    }

    private static func bestCandidatePerText(_ candidates: [KeywordDraft]) -> [KeywordDraft] {
        var best: [String: KeywordDraft] = [:]
        for candidate in candidates {
            if let existing = best[candidate.text] {
                if candidate.priority < existing.priority || (candidate.priority == existing.priority && candidate.score > existing.score) {
                    best[candidate.text] = candidate
                }
            } else { best[candidate.text] = candidate }
        }
        return best.values.sorted(by: bubbleCandidateSort)
    }

    private static func diversifiedBubbleCandidates(_ candidates: [KeywordDraft], targetCount: Int) -> [KeywordDraft] {
        var selected: [KeywordDraft] = []
        var categoryCounts: [HomeItem.Category: Int] = [:]
        var firstThree = Set<HomeItem.Category>()
        func canPick(_ candidate: KeywordDraft, strict: Bool) -> Bool {
            if selected.contains(where: { $0.text == candidate.text }) { return false }
            if strict {
                if categoryCounts[candidate.category, default: 0] >= 2 { return false }
                if selected.count < 3, firstThree.contains(candidate.category), candidate.source != .userTitle, candidate.source != .lifeMark { return false }
            } else if categoryCounts[candidate.category, default: 0] >= 3 { return false }
            return true
        }
        func pick(_ candidate: KeywordDraft) {
            selected.append(candidate)
            categoryCounts[candidate.category, default: 0] += 1
            if selected.count <= 3 { firstThree.insert(candidate.category) }
        }
        for candidate in candidates where selected.count < targetCount { if canPick(candidate, strict: true) { pick(candidate) } }
        for candidate in candidates where selected.count < targetCount { if canPick(candidate, strict: false) { pick(candidate) } }
        return selected.sorted(by: bubbleCandidateSort)
    }

    private static func bubbleCandidateSort(_ lhs: KeywordDraft, _ rhs: KeywordDraft) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
        if lhs.score != rhs.score { return lhs.score > rhs.score }
        return lhs.text < rhs.text
    }

    private static func preferredBubbleTitle(from item: HomeItem, allowsFullTitle: Bool) -> String? {
        guard item.hasMeaningfulTitle, let first = titleKeywords(from: item.title, allowsFullTitle: allowsFullTitle).first else { return nil }
        if !allowsFullTitle, item.userEditedTitle != true,
           !EchoAnchorService.shared.isEligibleLifeTraceTitle(item.title, item: item), first == item.category.rawValue { return nil }
        return first
    }

    private static func normalizedKeyword(_ raw: String, maxLength: Int = 12) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for word in ["记录", "记下", "记下来", "消费", "安排", "这一笔", "这笔", "一笔", "一条", "一下", "一点", "小消费", "日常记录", "临时花了"] {
            text = text.replacingOccurrences(of: word, with: "")
        }
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        if text.count < 2 || text.count > maxLength || isFillerKeyword(text) || text.rangeOfCharacter(from: .decimalDigits) != nil { return "" }
        return text
    }

    private static func titleKeywords(from title: String, allowsFullTitle: Bool) -> [String] {
        let normalized = normalizedKeyword(title)
        if allowsFullTitle, !normalized.isEmpty, normalized.count <= 12, !isGenericRecordTitle(normalized) { return [normalized] }
        let candidates = ["咖啡", "奶茶", "早餐", "午餐", "晚餐", "夜宵", "七欣天", "外卖", "食堂", "热饭", "打车", "地铁", "公交", "停车", "充电桩", "超市", "便利店", "买菜", "小象超市", "京东到家", "水果", "买药", "药店", "健身", "跑步", "瑜伽", "奶粉", "尿不湿", "狗粮", "猫粮", "宠物用品", "酒店", "民宿", "旅行", "电影", "渔具", "露营", "摄影", "手办"]
        return candidates.filter { title.contains($0) }
    }

    private static func isGenericRecordTitle(_ title: String) -> Bool {
        HomeItem.Category.allCases.contains { title == $0.rawValue || title == $0.label || title == $0.defaultRecordTitle }
    }

    private static func isFillerKeyword(_ text: String) -> Bool {
        Set(["一笔", "几笔", "这笔", "小记", "今天", "昨天", "本周", "本月", "生活", "日常", "花了", "花钱", "补一下", "临时", "简单"]).contains(text)
    }

    private static func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
