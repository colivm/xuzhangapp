import Foundation

@MainActor
extension HomeViewModel {
    struct HighConfidenceQuickRecordSuggestion: Equatable, Identifiable {
        enum Kind: String, Equatable {
            case commute
        }

        let id: String
        let kind: Kind
        let title: String
        let amount: Double
        let category: HomeItem.Category
        let recordDate: Date
        let secondaryTitle: String?
        let secondaryAmount: Double?
        let secondaryCategory: HomeItem.Category?
        let secondaryRecordDate: Date?
        let headline: String
        let detail: String
        let buttonTitle: String
        let backgroundImageName: String
        let supportCount: Int
        let confidence: Double
        let isBackfill: Bool

        var amountSummaryText: String {
            guard let secondaryTitle,
                  let secondaryAmount else {
                return "\(title) 路 \(amount.formatted(.cny))"
            }
            return "\(title) \(amount.formatted(.cny)) + \(secondaryTitle) \(secondaryAmount.formatted(.cny))"
        }
    }

    var hasMemberAccess: Bool {
        LocalStore.loadSettings().hasMemberAccess
    }

    var highConfidenceQuickRecordSuggestion: HighConfidenceQuickRecordSuggestion? {
        highConfidenceCommuteSuggestion(at: Date())
    }

    @discardableResult
    func addHighConfidenceQuickRecord(_ suggestion: HighConfidenceQuickRecordSuggestion) -> Bool {
        guard suggestion.kind == .commute else { return false }
        let firstSaved = addHighConfidenceCommuteRecord(
            title: suggestion.title,
            amount: suggestion.amount,
            category: suggestion.category,
            date: suggestion.recordDate
        )
        guard firstSaved else { return false }
        guard let secondaryTitle = suggestion.secondaryTitle,
              let secondaryAmount = suggestion.secondaryAmount,
              let secondaryCategory = suggestion.secondaryCategory,
              let secondaryRecordDate = suggestion.secondaryRecordDate else {
            return firstSaved
        }
        let secondSaved = addHighConfidenceCommuteRecord(
            title: secondaryTitle,
            amount: secondaryAmount,
            category: secondaryCategory,
            date: secondaryRecordDate
        )
        return firstSaved && secondSaved
    }

    private func addHighConfidenceCommuteRecord(
        title: String,
        amount: Double,
        category: HomeItem.Category,
        date: Date
    ) -> Bool {
        if hasMatchingHighConfidenceCommuteRecord(
            title: title,
            amount: amount,
            category: category,
            date: date
        ) {
            return true
        }
        inputTitle = title
        inputAmount = String(format: "%.2f", amount)
        selectedCategory = category
        selectedDate = date
        return addManualRecord(
            userEditedTitle: false,
            preserveEmptyTitle: false,
            categoryLockedForSave: true,
            scenePackId: "commute"
        )
    }

    private func hasMatchingHighConfidenceCommuteRecord(
        title: String,
        amount: Double,
        category: HomeItem.Category,
        date: Date
    ) -> Bool {
        let amountCents = Int((amount * 100).rounded())
        let normalizedTitle = normalizedQuickRecordTitle(title)
        return items.contains { item in
            item.category == category
                && item.scenePackId == "commute"
                && Int((item.amount * 100).rounded()) == amountCents
                && abs(item.createdAt.timeIntervalSince(date)) < 90
                && normalizedQuickRecordTitle(item.title) == normalizedTitle
        }
    }

    private func normalizedQuickRecordTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private enum CommuteHabitDirection: String {
        case morning
        case evening

        var fallbackTitle: String {
            switch self {
            case .morning: return "上班通勤"
            case .evening: return "下班通勤"
            }
        }

        var headline: String {
            switch self {
            case .morning: return "这趟上班路，可以记下"
            case .evening: return "这趟回家路，可以一键记下"
            }
        }

        var backfillHeadline: String {
            switch self {
            case .morning: return "早上的通勤，可能还没补"
            case .evening: return "回家这趟，可能还没补"
            }
        }
    }

    private struct CommuteHabitCandidate {
        let direction: CommuteHabitDirection
        let amount: Double
        let title: String
        let recordDate: Date
        let supportCount: Int
        let distinctDays: Int
        let confidence: Double
        let medianMinute: Int
        let isBackfill: Bool
    }

    private func highConfidenceCommuteSuggestion(at now: Date) -> HighConfidenceQuickRecordSuggestion? {
        let calendar = Calendar.current
        guard isWorkday(now, calendar: calendar) else { return nil }
        guard items.filter({ $0.amount > 0 }).count >= 16 else { return nil }

        if isMorningCommutePromptTime(now, calendar: calendar) {
            guard !hasTodayCommuteRecord(direction: .morning, now: now, calendar: calendar),
                  let candidate = commuteHabitCandidate(
                    direction: .morning,
                    now: now,
                    isBackfill: false,
                    calendar: calendar
                  ) else {
                return nil
            }
            return quickRecordSuggestion(from: candidate, now: now)
        } else if isNoonCommuteBackfillTime(now, calendar: calendar) {
            guard !hasTodayCommuteRecord(direction: .morning, now: now, calendar: calendar),
                  let candidate = commuteHabitCandidate(
                    direction: .morning,
                    now: now,
                    isBackfill: true,
                    calendar: calendar
                  ) else {
                return nil
            }
            return quickRecordSuggestion(from: candidate, now: now)
        } else if isEveningCommutePromptTime(now, calendar: calendar) {
            let morningBackfill: CommuteHabitCandidate?
            if hasTodayCommuteRecord(direction: .morning, now: now, calendar: calendar) {
                morningBackfill = nil
            } else {
                morningBackfill = commuteHabitCandidate(
                    direction: .morning,
                    now: now,
                    isBackfill: true,
                    calendar: calendar
                )
            }

            let eveningCandidate: CommuteHabitCandidate?
            if hasTodayCommuteRecord(direction: .evening, now: now, calendar: calendar) {
                eveningCandidate = nil
            } else {
                eveningCandidate = commuteHabitCandidate(
                    direction: .evening,
                    now: now,
                    isBackfill: false,
                    calendar: calendar
                )
            }

            if let morningBackfill, let eveningCandidate {
                return combinedCommuteSuggestion(
                    morningBackfill: morningBackfill,
                    evening: eveningCandidate,
                    now: now
                )
            }
            if let eveningCandidate {
                return quickRecordSuggestion(from: eveningCandidate, now: now)
            }
            if let morningBackfill {
                return quickRecordSuggestion(from: morningBackfill, now: now)
            }
            return nil
        } else {
            return nil
        }
    }

    private func quickRecordSuggestion(
        from candidate: CommuteHabitCandidate,
        now: Date
    ) -> HighConfidenceQuickRecordSuggestion {
        let headline = candidate.isBackfill
            ? candidate.direction.backfillHeadline
            : candidate.direction.headline
        let timeText = commuteTimeText(minutesFromMidnight: candidate.medianMinute)
        let detail = candidate.isBackfill
            ? "按最近 \(candidate.distinctDays) 个工作日的记录，常在 \(timeText) 左右。"
            : "最近 \(candidate.distinctDays) 个工作日都像这笔，\(candidate.amount.formatted(.cny))。"
        let id = [
            "quick",
            candidate.direction.rawValue,
            quickRecordDayKey(for: now),
            String(Int((candidate.amount * 100).rounded())),
            String(candidate.medianMinute)
        ].joined(separator: ":")

        return HighConfidenceQuickRecordSuggestion(
            id: id,
            kind: .commute,
            title: candidate.title,
            amount: candidate.amount,
            category: .transport,
            recordDate: candidate.recordDate,
            secondaryTitle: nil,
            secondaryAmount: nil,
            secondaryCategory: nil,
            secondaryRecordDate: nil,
            headline: headline,
            detail: detail,
            buttonTitle: candidate.isBackfill ? "补记上班" : "一键记通勤",
            backgroundImageName: candidate.direction == .morning
                ? "CommuteMorningQuickCardBackground"
                : "CommuteEveningQuickCardBackground",
            supportCount: candidate.supportCount,
            confidence: candidate.confidence,
            isBackfill: candidate.isBackfill
        )
    }

    private func combinedCommuteSuggestion(
        morningBackfill: CommuteHabitCandidate,
        evening: CommuteHabitCandidate,
        now: Date
    ) -> HighConfidenceQuickRecordSuggestion {
        let morningTime = commuteTimeText(minutesFromMidnight: morningBackfill.medianMinute)
        let eveningTime = commuteTimeText(minutesFromMidnight: evening.medianMinute)
        let id = [
            "quick",
            "morning_evening",
            quickRecordDayKey(for: now),
            String(Int((morningBackfill.amount * 100).rounded())),
            String(Int((evening.amount * 100).rounded())),
            String(morningBackfill.medianMinute),
            String(evening.medianMinute)
        ].joined(separator: ":")

        return HighConfidenceQuickRecordSuggestion(
            id: id,
            kind: .commute,
            title: morningBackfill.title,
            amount: morningBackfill.amount,
            category: .transport,
            recordDate: morningBackfill.recordDate,
            secondaryTitle: evening.title,
            secondaryAmount: evening.amount,
            secondaryCategory: .transport,
            secondaryRecordDate: evening.recordDate,
            headline: "上班还没补，下班也一起记下",
            detail: "早上常在 \(morningTime) 左右，下班这趟也符合你 \(eveningTime) 附近的记录。",
            buttonTitle: "一起记两笔",
            backgroundImageName: "CommuteEveningQuickCardBackground",
            supportCount: min(morningBackfill.supportCount, evening.supportCount),
            confidence: min(morningBackfill.confidence, evening.confidence),
            isBackfill: true
        )
    }

    private func commuteHabitCandidate(
        direction: CommuteHabitDirection,
        now: Date,
        isBackfill: Bool,
        calendar: Calendar
    ) -> CommuteHabitCandidate? {
        let recentStart = calendar.date(byAdding: .day, value: -120, to: now) ?? .distantPast
        let weekdayGroup = commuteWeekdayGroup(for: now, direction: direction, calendar: calendar)
        let candidates = items.filter { item in
            item.amount > 0
                && item.createdAt >= recentStart
                && item.createdAt < now
                && isWorkday(item.createdAt, calendar: calendar)
                && commuteWeekdayGroup(for: item.createdAt, direction: direction, calendar: calendar) == weekdayGroup
                && commuteDirection(for: item.createdAt, calendar: calendar) == direction
                && isCommuteRecord(item)
        }
        guard candidates.count >= 5 else { return nil }

        let distinctDays = Set(candidates.map { quickRecordDayKey(for: $0.createdAt) }).count
        guard distinctDays >= 4 else { return nil }

        let minuteSamples = candidates.map { minutesFromMidnight($0.createdAt, calendar: calendar) }.sorted()
        guard let medianMinute = medianMinute(in: minuteSamples) else { return nil }
        let currentMinute = minutesFromMidnight(now, calendar: calendar)
        guard isBackfill || isNearPersonalCommutePromptTime(
            currentMinute: currentMinute,
            medianMinute: medianMinute,
            direction: direction,
            weekdayGroup: weekdayGroup
        ) else { return nil }

        guard let amountCluster = stableAmountCluster(in: candidates) else { return nil }
        let amount = Double(amountCluster.cents) / 100
        let supportRatio = Double(amountCluster.count) / Double(max(candidates.count, 1))
        guard amountCluster.count >= 5, supportRatio >= 0.72 else { return nil }

        let title = stableCommuteTitle(in: candidates, direction: direction)
        let confidence = min(0.98, 0.72 + min(supportRatio, 0.22) + min(Double(distinctDays) * 0.01, 0.04))
        guard confidence >= 0.90 else { return nil }

        let recordDate = isBackfill
            ? date(onSameDayAs: now, minutesFromMidnight: medianMinute, calendar: calendar)
            : now
        return CommuteHabitCandidate(
            direction: direction,
            amount: amount,
            title: title,
            recordDate: recordDate,
            supportCount: amountCluster.count,
            distinctDays: distinctDays,
            confidence: confidence,
            medianMinute: medianMinute,
            isBackfill: isBackfill
        )
    }

    private func stableAmountCluster(in items: [HomeItem]) -> (cents: Int, count: Int)? {
        let grouped = Dictionary(grouping: items) { item in
            Int((item.amount * 100).rounded())
        }
        return grouped
            .map { (cents: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.cents < rhs.cents }
                return lhs.count > rhs.count
            }
            .first
    }

    private func stableCommuteTitle(
        in items: [HomeItem],
        direction: CommuteHabitDirection
    ) -> String {
        let counts = items.reduce(into: [String: Int]()) { result, item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard RecordPrefillService.isHabitTitle(title, category: .transport),
                  RecordSemanticLexicon.canReuseHabitTitle(
                    title,
                    category: .transport,
                    userEditedTitle: item.userEditedTitle == true
                  ) else {
                return
            }
            result[title, default: 0] += item.userEditedTitle == true ? 2 : 1
        }
        if let best = counts.sorted(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }).first,
           best.value >= 3 {
            return best.key
        }
        return direction.fallbackTitle
    }

    private func isNearPersonalCommutePromptTime(
        currentMinute: Int,
        medianMinute: Int,
        direction: CommuteHabitDirection,
        weekdayGroup: String
    ) -> Bool {
        let window: (before: Int, after: Int)
        switch direction {
        case .morning:
            window = (before: 20, after: 55)
        case .evening:
            if weekdayGroup == "fri" {
                window = (before: 35, after: 75)
            } else {
                window = (before: 25, after: 65)
            }
        }

        return ((medianMinute - window.before)...(medianMinute + window.after)).contains(currentMinute)
    }

    private func hasTodayCommuteRecord(
        direction: CommuteHabitDirection,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        items.contains { item in
            calendar.isDate(item.createdAt, inSameDayAs: now)
                && item.amount > 0
                && commuteDirection(for: item.createdAt, calendar: calendar) == direction
                && isCommuteRecord(item)
        }
    }

    private func isCommuteRecord(_ item: HomeItem) -> Bool {
        guard item.category == .transport else { return false }
        let text = "\(item.title) \(item.emotionTag) \(item.memoryContext?.semanticPlace ?? "")".lowercased()
        return containsAny(
            text,
            [
                "通勤", "上班", "下班", "早高峰", "晚高峰", "到岗", "到站",
                "地铁", "公交", "轨道交通", "打车", "滴滴", "花小猪",
                "网约车", "回家", "到家", "路费"
            ]
        )
    }

    private func isMorningCommutePromptTime(_ date: Date, calendar: Calendar) -> Bool {
        (390...585).contains(minutesFromMidnight(date, calendar: calendar))
    }

    private func isNoonCommuteBackfillTime(_ date: Date, calendar: Calendar) -> Bool {
        (600...810).contains(minutesFromMidnight(date, calendar: calendar))
    }

    private func isEveningCommutePromptTime(_ date: Date, calendar: Calendar) -> Bool {
        let minute = minutesFromMidnight(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 6 {
            return (960...1230).contains(minute)
        }
        return (1050...1350).contains(minute)
    }

    private func isWorkday(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return (2...6).contains(weekday)
    }

    private func commuteDirection(
        for date: Date,
        calendar: Calendar
    ) -> CommuteHabitDirection? {
        let minute = minutesFromMidnight(date, calendar: calendar)
        if (330...660).contains(minute) { return .morning }
        if (900...1440).contains(minute) { return .evening }
        return nil
    }

    private func commuteWeekdayGroup(
        for date: Date,
        direction: CommuteHabitDirection,
        calendar: Calendar
    ) -> String {
        guard direction == .evening else { return "weekday_morning" }
        return calendar.component(.weekday, from: date) == 6 ? "fri" : "mon_thu"
    }

    private func minutesFromMidnight(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func medianMinute(in minutes: [Int]) -> Int? {
        guard !minutes.isEmpty else { return nil }
        return minutes[minutes.count / 2]
    }

    private func date(
        onSameDayAs date: Date,
        minutesFromMidnight minute: Int,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: minute, to: start) ?? date
    }

    private func commuteTimeText(minutesFromMidnight minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func quickRecordDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    var monthExpenseTotal: Double {
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        return monthItems.reduce(0) { $0 + $1.amount }
    }

    var todayExpenseTotal: Double {
        return todayItems.reduce(0) { $0 + $1.amount }
    }

    var todayHeroSubtitle: String {
        let records = todayItems
        let total = records.reduce(0) { $0 + $1.amount }
        let topCategory = records
            .reduce(into: [HomeItem.Category: Double]()) { result, item in
                result[item.category, default: 0] += item.amount
            }
            .max(by: { $0.value < $1.value })?.key.rawValue ?? "无"
        guard total > 0 else {
            return "今天还没记支出，先从一笔小额开始就很好。"
        }
        return "今天的记录里，「\(topCategory)」最常出现，日子又多了一点细节。"
    }

    var weekExpenseTotal: Double {
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        return weekItems.reduce(0) { $0 + $1.amount }
    }

    var todayStoryNarrative: TodayStoryNarrative {
        let records = todayItems
        let count = records.count
        let todayTotal = records.reduce(0) { $0 + $1.amount }
        let weekTotal = filteredItems(in: .week)
            .filter { $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
        let totalText = todayTotal.formatted(.cny)
        let weekText = weekTotal.formatted(.cny)
        let topCategory = topCategoryLabel(from: records)
        let todaySceneLine = lifeSceneMemoryLine(from: records, minimumCount: 2)
        let todayLifeMarkLine = lifeMarkMemoryLine(from: records, minimumCount: 1)
        let todayLateCommuteLine = records
            .sorted { $0.createdAt > $1.createdAt }
            .first(where: { HomeItem.isLateWorkCommute($0) })
            .flatMap { HomeItem.lateWorkCommuteTraceLine(for: $0) }

        let title: String
        let subtitle: String
        switch count {
        case 0:
            let emptyCopy = emptyTodayStoryCopy()
            title = emptyCopy.title
            subtitle = emptyCopy.subtitle
        case 1:
            title = "今天的第一笔记录"
            let emotion = records.first?.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            subtitle = todayLateCommuteLine ?? todayLifeMarkLine ?? "\(!emotion.isEmpty ? emotion : "今天已经有一笔记录")，这一天刚翻开第一页。"
        case 2:
            title = "今天已记下 2 笔"
            subtitle = todayLateCommuteLine ?? todayLifeMarkLine ?? todaySceneLine ?? "主要在「\(topCategory)」上，记录变得具体。"
        case 3:
            title = "今天记下了 3 笔"
            subtitle = todayLateCommuteLine ?? todayLifeMarkLine ?? todaySceneLine ?? "合计 \(totalText)，今天的记录已经成形。"
        default:
            title = "今天记下了 \(count) 笔"
            subtitle = todayLateCommuteLine ?? todayLifeMarkLine ?? todaySceneLine ?? "「\(topCategory)」居多，今天的记录已经清楚。"
        }

        return TodayStoryNarrative(
            title: title,
            subtitle: subtitle,
            todayTotalText: count == 0 ? "今日还没记录" : "今日合计 \(totalText)",
            weekTotalText: "本周累计 \(weekText)"
        )
    }

    private func emptyTodayStoryCopy(now: Date = Date()) -> (title: String, subtitle: String) {
        if let suggestion = frequentRecordAmountSuggestions(at: now).first {
            return (
                "今天可以从这里开始",
                "这个时间你常记 \(shortAmountText(suggestion.amount)) · \(suggestion.category.label)，不确定也可以只输金额。"
            )
        }

        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            return (
                "今天也先留一笔",
                "这周「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」出现得多，今天想到哪笔就先放进来。"
            )
        }

        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<10:
            return ("早上先留个开头", "早餐、通勤、路上的小花费，有一笔就先记一笔。")
        case 10..<14:
            return ("午间先记一下", "饭点和路上的小支出最容易忘，先放一笔也好。")
        case 17..<21:
            return ("晚上回头补一笔", "晚饭、回家路上、临时买的东西，都可以先记下来。")
        case 21...23, 0..<5:
            return ("今天还有哪笔没放进来？", "睡前补一笔，明天再看今天会清楚一点。")
        default:
            return ("今天先记下来", "不用整理得很完整，有一笔就先放进账本。")
        }
    }

    var monthTopCategoryText: String {
        topCategoryLabel(in: .month)
    }

    var weekTopCategoryText: String {
        topCategoryLabel(in: .week)
    }

    var weekLifeThemeText: String {
        lifeMarkMemoryLine(from: filteredItems(in: .week), minimumCount: 2)
            ?? lifeSceneMemoryLine(from: filteredItems(in: .week), minimumCount: 2)
            ?? ""
    }

    var quickRecordNudgeText: String {
        let records = todayItems
        if records.isEmpty {
            if let suggestion = frequentRecordAmountSuggestions(at: Date()).first {
                return "常记 \(shortAmountText(suggestion.amount)) · \(suggestion.category.label)"
            }
            if let mark = LifeMarkService.aggregates(
                for: filteredItems(in: .week),
                allItems: items,
                isMember: hasMemberAccess,
                limit: 1
            ).first,
               mark.count >= 2 || mark.kind != .scene {
                return "接着留下「\(mark.label)」"
            }
            if let scene = LifeSceneSemanticService.dominantScene(in: filteredItems(in: .week).filter({ $0.amount > 0 })),
               scene.count >= 2 {
                return "接着留下「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」"
            }
            return "只输金额也可以"
        }
        if let mark = LifeMarkService.aggregates(
            for: records,
            allItems: items,
            isMember: hasMemberAccess,
            limit: 1
        ).first,
           mark.count >= 2 || mark.kind != .scene {
            return "今天已有 \(records.count) 笔 · \(mark.label)"
        }
        if let scene = LifeSceneSemanticService.dominantScene(in: records),
           scene.count >= 2 {
            return "今天已有 \(records.count) 笔 · \(LifeSceneSemanticService.displayTheme(for: scene.signal))"
        }
        return "今天已记 \(records.count) 笔"
    }

    /// 近 7 日内生成的复盘记录（按时间新到旧）。
    var insightsLast7Days: [DailyInsight] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return insights
            .filter { $0.createdAt >= start }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 本地 7 天聚合复盘（与 web rangeInsightPayload(7) 对齐：一条总结而非逐日）。
    func localWeeklyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: Date()) else {
            return ("近 7 天暂无复盘。", "", "")
        }
        let weekItems = items.filter { $0.createdAt >= start && $0.amount > 0 }
        guard !weekItems.isEmpty else {
            return ("近 7 天暂无复盘。多记几笔，就能看到更完整的消费节奏啦。", "", "")
        }
        if let memoryLine = contextualMemoryLine(from: weekItems) {
            let structure = "这一周的记录里，天气、城市和重复出现的场景已经能连起来看。"
            let advice = weekItems.count >= 8
                ? "继续按真实时间记，之后可以按时间线回看。"
                : "再多记几笔，天气和地点线索会更容易浮出来。"
            return (memoryLine, structure, advice)
        }
        if let mark = LifeMarkService.aggregates(
            for: weekItems,
            allItems: items,
            isMember: hasMemberAccess,
            limit: 1
        ).first,
           mark.count >= 2 || mark.kind != .scene {
            let summary = LifeMarkService.primaryLine(for: mark)
            let structure = "这一周「\(mark.label)」出现得更集中。"
            let advice = mark.access == .member
                ? "继续按真实时间记，天气、城市、首次和连续性会更容易被串起来。"
                : "继续按笔记下去，后面会更容易按时间回看。"
            return (summary, structure, advice)
        }
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            let copy = LifeSceneSemanticService.weeklyCopy(for: scene.signal, count: scene.count)
            let summary = LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
            let structure = "这一周更明显的是「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」这条线。"
            let advice = weekItems.count >= 8
                ? "继续按笔记下去，下周回放会更贴近真实记录。"
                : copy.cares.dropFirst().first ?? "再多记几笔，这一周会更容易回头看。"
            return (summary, structure, advice)
        }

        let topCategory = topCategoryLabel(from: weekItems)
        let summary = "近 7 天里，「\(topCategory)」这类记录多一些。"
        let structure = "这一周的记录已经分出几段。"
        let advice = weekItems.count >= 8
            ? "继续按笔记下去，下周回放会更贴近真实记录。"
            : "再多记几笔，这一周会更容易回头看。"
        return (summary, structure, advice)
    }

    /// 本地月度小结文案（与 web 预览结构对齐：摘要 / 结构 / 建议）。
    func localMonthlyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let monthItems = filteredItems(in: .month)
        let positiveMonthItems = monthItems.filter { $0.amount > 0 }
        let total = positiveMonthItems.reduce(0) { $0 + $1.amount }
        let top = topCategoryCountLabel(from: monthItems)
        let summary: String
        if total <= 0 {
            summary = "本月还没有足够账单，多记几笔再来生成月度复盘吧。"
        } else if let memoryLine = contextualMemoryLine(from: positiveMonthItems) {
            summary = memoryLine
        } else if let markLine = lifeMarkMemoryLine(from: positiveMonthItems, minimumCount: 2) {
            summary = markLine
        } else if let scene = LifeSceneSemanticService.dominantScene(in: positiveMonthItems),
                  scene.count >= 2 {
            summary = LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
        } else {
            summary = "这个月的记录里，「\(top)」出现得比较多。"
        }
        let structure = total <= 0
            ? "等本月多几笔记录，再整理这段时间的变化。"
            : monthlyStructureText(fallbackTop: top, monthItems: positiveMonthItems)
        let advice = total <= 0
            ? "先记下一周，复盘会更有内容。"
            : "这个月已经有一些记录，继续记几天，月记会更完整。"
        return (summary, structure, advice)
    }

    private func topCategoryLabel(in period: Period) -> String {
        let target = filteredItems(in: period)
        return topCategoryCountLabel(from: target)
    }

    private func topCategoryCountLabel(from target: [HomeItem]) -> String {
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { $0.value.count < $1.value.count })?.key else {
            return "暂无"
        }
        return top.rawValue
    }

    private func topCategoryLabel(from target: [HomeItem]) -> String {
        let grouped = Dictionary(grouping: target, by: \.category)
        guard let top = grouped.max(by: { lhs, rhs in
            let left = lhs.value.reduce(0) { $0 + $1.amount }
            let right = rhs.value.reduce(0) { $0 + $1.amount }
            return left < right
        })?.key else {
            return "生活"
        }
        return top.label
    }

    func lifeSceneMemoryLine(from target: [HomeItem], minimumCount: Int) -> String? {
        let positive = target.filter { $0.amount > 0 }
        guard let scene = LifeSceneSemanticService.dominantScene(in: positive),
              scene.count >= minimumCount else {
            return nil
        }
        return LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
    }

    func lifeMarkMemoryLine(from target: [HomeItem], minimumCount: Int) -> String? {
        let positive = target.filter { $0.amount > 0 }
        guard let mark = LifeMarkService.aggregates(
            for: positive,
            allItems: items,
            isMember: hasMemberAccess,
            limit: 1
        ).first else {
            return nil
        }
        guard mark.count >= minimumCount || mark.kind != .scene else {
            return nil
        }
        return LifeMarkService.primaryLine(for: mark)
    }

    private func monthlyStructureText(fallbackTop: String) -> String {
        let monthItems = filteredItems(in: .month).filter { $0.amount > 0 }
        return monthlyStructureText(fallbackTop: fallbackTop, monthItems: monthItems)
    }

    private func monthlyStructureText(fallbackTop: String, monthItems: [HomeItem]) -> String {
        if monthItems.contains(where: { $0.memoryContext?.weatherKind != nil || $0.memoryContext?.cityName != nil }) {
            return "这个月不只看分类，也能看到天气、城市和当天场景留下的线索。"
        }
        if let mark = LifeMarkService.aggregates(
            for: monthItems,
            allItems: items,
            isMember: hasMemberAccess,
            limit: 1
        ).first,
           mark.count >= 2 || mark.kind != .scene {
            return "这个月「\(mark.label)」出现得更集中。"
        }
        if let scene = LifeSceneSemanticService.dominantScene(in: monthItems),
           scene.count >= 2 {
            return "这个月更明显的是「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」这条线。"
        }
        return "「\(fallbackTop)」是这个月比较明显的一类。"
    }

    private func contextualMemoryLine(from target: [HomeItem]) -> String? {
        let sorted = target.sorted { $0.createdAt > $1.createdAt }
        if let item = sorted.first(where: { HomeItem.isLateWorkCommute($0) }),
           let line = HomeItem.lateWorkCommuteTraceLine(for: item) {
            return line
        }
        if let item = sorted.first(where: { item in
            item.category == .transport
                && item.memoryContext?.weatherKind == "rain"
        }) {
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
        return sorted.first { item in
            let text = item.displayEmotionTag
            return text.contains("第一次")
                || text.contains("第10次")
                || text.contains("连续")
                || text.contains("周末出门")
        }?.displayEmotionTag
    }
}
