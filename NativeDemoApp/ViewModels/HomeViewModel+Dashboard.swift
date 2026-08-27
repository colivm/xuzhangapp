import Foundation
import Combine

struct HomeDashboardPreparationRequest {
    let isMember: Bool
    let now: Date
    let clearsStaleQuickRecord: Bool
}

struct HomeHighConfidenceQuickRecordSuggestion: Equatable, Identifiable {
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

private enum HomeCommuteHabitDirection: String {
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

private struct HomeCommuteHabitCandidate {
    let direction: HomeCommuteHabitDirection
    let amount: Double
    let title: String
    let recordDate: Date
    let supportCount: Int
    let distinctDays: Int
    let confidence: Double
    let medianMinute: Int
    let isBackfill: Bool
}

struct HomeLifeMarkSnapshotKey: Equatable {
    let ledgerRevision: Int
    let dayKey: String
    let isMember: Bool
}

struct HomeLifeMarkPreparationInput: @unchecked Sendable {
    let key: HomeLifeMarkSnapshotKey
    let visibleItems: [HomeItem]
    let weekItems: [HomeItem]
    let allItems: [HomeItem]
    let isMember: Bool
    let frequentSuggestionLine: String?
}

struct HomeLifeMarkSemanticSignature: Equatable, @unchecked Sendable {
    let title: String
    let amount: Double
    let category: HomeItem.Category
    let createdAt: Date
    let updatedAt: Date
    let emotionTag: String
    let merchantBrandID: String?
    let scenePackID: String?
    let cityName: String?
    let semanticPlace: String?
    let weatherKind: String?
    let userEditedTitle: Bool?
    let userEditedCategory: Bool?
    let categoryCorrectionFrom: HomeItem.Category?
    let draftStatus: HomeItem.DraftMeta.Status?

    static func make(for item: HomeItem) -> HomeLifeMarkSemanticSignature {
        HomeLifeMarkSemanticSignature(
            title: item.title,
            amount: item.amount,
            category: item.category,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            emotionTag: item.emotionTag,
            merchantBrandID: item.merchantBrandId,
            scenePackID: item.scenePackId,
            cityName: item.memoryContext?.cityName,
            semanticPlace: item.memoryContext?.semanticPlace,
            weatherKind: item.memoryContext?.weatherKind,
            userEditedTitle: item.userEditedTitle,
            userEditedCategory: item.userEditedCategory,
            categoryCorrectionFrom: item.categoryCorrectionFrom,
            draftStatus: item.draftMeta?.status
        )
    }
}

struct HomeLifeMarkSnapshot: @unchecked Sendable {
    let key: HomeLifeMarkSnapshotKey
    let textsByItemID: [UUID: String]
    let semanticSignaturesByItemID: [UUID: HomeLifeMarkSemanticSignature]
    let todayPrimaryLine: String?
    let weekLifeThemeText: String
    let quickRecordNudgeText: String
    let weekTopCategoryText: String
}

struct HomeEmptyTodayCopy: Equatable {
    let title: String
    let subtitle: String
}

enum HomeEmptyTodayCopyPolicy {
    static func copy(
        frequentSuggestionLine: String?,
        dominantSceneLine: String?
    ) -> HomeEmptyTodayCopy {
        HomeEmptyTodayCopy(
            title: "今天还没有记录",
            subtitle: frequentSuggestionLine
                ?? dominantSceneLine
                ?? "今天这一页暂时还是空的。"
        )
    }
}

enum HomeLifeMarkRefreshPolicy {
    static func preservesVisibleLines(
        previousKey: HomeLifeMarkSnapshotKey?,
        nextKey: HomeLifeMarkSnapshotKey
    ) -> Bool {
        guard let previousKey else { return false }
        return previousKey.dayKey == nextKey.dayKey
            && previousKey.isMember == nextKey.isMember
    }

    static func retainedVisibleLines(
        previousTexts: [UUID: String],
        previousSignatures: [UUID: HomeLifeMarkSemanticSignature],
        nextItems: [HomeItem]
    ) -> [UUID: String] {
        let nextSignatures = semanticSignatures(for: nextItems)
        return previousTexts.filter { itemID, _ in
            guard let previousSignature = previousSignatures[itemID],
                  let nextSignature = nextSignatures[itemID] else {
                return false
            }
            return previousSignature == nextSignature
        }
    }

    static func semanticSignatures(
        for items: [HomeItem]
    ) -> [UUID: HomeLifeMarkSemanticSignature] {
        Dictionary(
            items.map { ($0.id, HomeLifeMarkSemanticSignature.make(for: $0)) },
            uniquingKeysWith: { _, latest in latest }
        )
    }
}

struct HomeQuickRecordSnapshotKey: Equatable {
    let ledgerRevision: Int
    let minuteKey: String
}

struct HomeQuickRecordPreparationInput: @unchecked Sendable {
    let key: HomeQuickRecordSnapshotKey
    let items: [HomeItem]
    let now: Date
}

struct HomeQuickRecordSnapshot: @unchecked Sendable {
    let key: HomeQuickRecordSnapshotKey
    let suggestion: HomeHighConfidenceQuickRecordSuggestion?
}

enum HomeQuickRecordRefreshPolicy {
    static func shouldClearVisibleSuggestion(
        previousKey: HomeQuickRecordSnapshotKey?,
        nextKey: HomeQuickRecordSnapshotKey,
        isLifecycleRefresh: Bool
    ) -> Bool {
        guard isLifecycleRefresh, let previousKey else { return false }
        return previousKey != nextKey
    }
}

enum HomeDashboardSnapshotComputation {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func minuteKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04d-%02d-%02d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0
        )
    }

    static func lifeMarkSnapshot(_ input: HomeLifeMarkPreparationInput) -> HomeLifeMarkSnapshot {
        let semanticSignatures = HomeLifeMarkRefreshPolicy.semanticSignatures(
            for: input.visibleItems
        )
        let preparedContext = LifeMarkService.prepareAggregationContext(
            allItems: input.allItems,
            periodItems: input.weekItems + input.visibleItems
        )
        let texts = input.visibleItems.reduce(into: [UUID: String]()) { result, item in
            guard item.amount > 0,
                  let mark = LifeMarkService.aggregates(
                    for: [item],
                    preparedContext: preparedContext,
                    isMember: input.isMember,
                    limit: 1
                  ).first else {
                return
            }
            switch mark.kind {
            case .scene:
                result[item.id] = "生活线索 · \(mark.label)"
            case .context, .milestone, .streak:
                result[item.id] = "生活线索 · \(mark.title)"
            }
        }
        let positiveVisibleItems = input.visibleItems.filter { $0.amount > 0 }
        let todayAggregates = LifeMarkService.aggregates(
            for: positiveVisibleItems,
            preparedContext: preparedContext,
            isMember: input.isMember,
            limit: 1
        )
        let positiveWeekItems = input.weekItems.filter { $0.amount > 0 }
        let weekAggregates = LifeMarkService.aggregates(
            for: positiveWeekItems,
            preparedContext: preparedContext,
            isMember: input.isMember,
            limit: 1
        )
        let trustedUserMoment = TrustedUserMomentNarrativePolicy.preferredNarrative(
            in: positiveVisibleItems
        )
        let todayPrimaryLine = trustedUserMoment?.line
            ?? todayAggregates.first.map { LifeMarkService.primaryLine(for: $0) }
        let qualifyingTodayMark = todayAggregates.first.flatMap { mark in
            mark.count >= 2 || mark.kind != .scene ? mark : nil
        }
        let qualifyingWeekMark = weekAggregates.first.flatMap { mark in
            mark.count >= 2 || mark.kind != .scene ? mark : nil
        }
        let weekScene = LifeSceneSemanticService.dominantScene(in: positiveWeekItems)
        let todayScene = LifeSceneSemanticService.dominantScene(in: positiveVisibleItems)
        let weekLifeThemeText = qualifyingWeekMark.map { LifeMarkService.primaryLine(for: $0) }
            ?? weekScene.flatMap { scene in
                scene.count >= 2
                    ? LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
                    : nil
            }
            ?? ""
        let quickRecordNudgeText: String
        if positiveVisibleItems.isEmpty {
            quickRecordNudgeText = input.frequentSuggestionLine
                ?? qualifyingWeekMark.map { "接着留下「\($0.label)」" }
                ?? weekScene.flatMap { scene in
                    scene.count >= 2
                        ? "接着留下「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」"
                        : nil
                }
                ?? "只输金额也可以"
        } else {
            quickRecordNudgeText = qualifyingTodayMark.map {
                "今天已有 \(positiveVisibleItems.count) 笔 · \($0.label)"
            }
                ?? todayScene.flatMap { scene in
                    scene.count >= 2
                        ? "今天已有 \(positiveVisibleItems.count) 笔 · \(LifeSceneSemanticService.displayTheme(for: scene.signal))"
                        : nil
                }
                ?? "今天已记 \(positiveVisibleItems.count) 笔"
        }
        return HomeLifeMarkSnapshot(
            key: input.key,
            textsByItemID: texts,
            semanticSignaturesByItemID: semanticSignatures,
            todayPrimaryLine: todayPrimaryLine,
            weekLifeThemeText: weekLifeThemeText,
            quickRecordNudgeText: quickRecordNudgeText,
            weekTopCategoryText: topCategoryCountLabel(from: input.weekItems)
        )
    }

    private static func topCategoryCountLabel(from items: [HomeItem]) -> String {
        let grouped = Dictionary(grouping: items, by: \.category)
        return grouped.max(by: { $0.value.count < $1.value.count })?.key.rawValue ?? "暂无"
    }
}

@MainActor
extension HomeViewModel {
    typealias HighConfidenceQuickRecordSuggestion = HomeHighConfidenceQuickRecordSuggestion

    var hasMemberAccess: Bool {
        LocalStore.loadSettings().hasMemberAccess
    }

    var highConfidenceQuickRecordSuggestion: HighConfidenceQuickRecordSuggestion? {
        highConfidenceQuickRecordSuggestionSnapshot
    }

    func prepareHomeDashboardSnapshots(
        isMember: Bool,
        now: Date = Date(),
        clearsStaleQuickRecord: Bool = false
    ) {
        prepareItemDerivedCacheIfNeeded(now: now)
        guard isItemDerivedCacheCurrent(now: now) else {
            pendingHomeDashboardPreparationRequest = HomeDashboardPreparationRequest(
                isMember: isMember,
                now: now,
                clearsStaleQuickRecord: clearsStaleQuickRecord
            )
            return
        }
        pendingHomeDashboardPreparationRequest = nil
        prepareHomeLifeMarkSnapshot(isMember: isMember, now: now)
        prepareHighConfidenceQuickRecordSnapshot(
            now: now,
            clearsStaleQuickRecord: clearsStaleQuickRecord
        )
    }

    func resumePendingHomeDashboardPreparationIfNeeded() {
        guard let request = pendingHomeDashboardPreparationRequest else { return }
        pendingHomeDashboardPreparationRequest = nil
        prepareHomeDashboardSnapshots(
            isMember: request.isMember,
            now: request.now,
            clearsStaleQuickRecord: request.clearsStaleQuickRecord
        )
    }

    func cancelHomeDashboardSnapshotPreparation() {
        pendingHomeDashboardPreparationRequest = nil
        homeLifeMarkPreparationTask?.cancel()
        homeLifeMarkPreparationTask = nil
        homeLifeMarkRequestID = UUID()
        homeQuickRecordPreparationTask?.cancel()
        homeQuickRecordPreparationTask = nil
        homeQuickRecordRequestID = UUID()
    }

    func invalidateHomeDashboardSnapshots() {
        cancelHomeDashboardSnapshotPreparation()
        homeQuickRecordSnapshotKey = nil
        highConfidenceQuickRecordSuggestionSnapshot = nil
    }

    private func prepareHomeLifeMarkSnapshot(isMember: Bool, now: Date) {
        let key = HomeLifeMarkSnapshotKey(
            ledgerRevision: homeDashboardRevision,
            dayKey: HomeDashboardSnapshotComputation.dayKey(for: now),
            isMember: isMember
        )
        guard homeLifeMarkSnapshotKey != key else { return }

        if !HomeLifeMarkRefreshPolicy.preservesVisibleLines(
            previousKey: homeLifeMarkSnapshotKey,
            nextKey: key
        ) {
            let needsVisibleClear = !homeLifeMarkTextsByItemID.isEmpty
                || homeTodayLifeMarkLine != nil
                || !homeWeekLifeThemeText.isEmpty
                || homeQuickRecordNudgeText != nil
                || homeWeekTopCategoryText != "暂无"
            if needsVisibleClear {
                objectWillChange.send()
            }
            homeLifeMarkTextsByItemID = [:]
            homeLifeMarkSemanticSignaturesByItemID = [:]
            homeTodayLifeMarkLine = nil
            homeWeekLifeThemeText = ""
            homeQuickRecordNudgeText = nil
            homeWeekTopCategoryText = "暂无"
        } else {
            let currentVisibleItems = todayItems
            let retainedTexts = HomeLifeMarkRefreshPolicy.retainedVisibleLines(
                previousTexts: homeLifeMarkTextsByItemID,
                previousSignatures: homeLifeMarkSemanticSignaturesByItemID,
                nextItems: currentVisibleItems
            )
            if retainedTexts != homeLifeMarkTextsByItemID {
                objectWillChange.send()
                homeLifeMarkTextsByItemID = retainedTexts
            }
            homeLifeMarkSemanticSignaturesByItemID = HomeLifeMarkRefreshPolicy.semanticSignatures(
                for: currentVisibleItems
            )
        }
        homeLifeMarkPreparationTask?.cancel()
        homeLifeMarkRequestID = UUID()
        let requestID = homeLifeMarkRequestID
        homeLifeMarkSnapshotKey = key
        let input = HomeLifeMarkPreparationInput(
            key: key,
            visibleItems: todayItems,
            weekItems: filteredItems(in: .week),
            allItems: items,
            isMember: isMember,
            frequentSuggestionLine: frequentRecordAmountSuggestions(at: now).first.map { suggestion in
                "常记 \(shortAmountText(suggestion.amount)) · \(suggestion.category.label)"
            }
        )
        homeLifeMarkPreparationTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: LedgerRapidInteractionPolicy.homeSnapshotCoalescingDelayNanoseconds
            )
            guard !Task.isCancelled, homeLifeMarkRequestID == requestID else { return }
            let snapshot = await LedgerBackgroundComputationLane.shared.buildHomeLifeMark(input)
            guard let snapshot,
                  !Task.isCancelled,
                  homeLifeMarkRequestID == requestID,
                  homeLifeMarkSnapshotKey == key else {
                return
            }
            let visibleSnapshotChanged = homeLifeMarkTextsByItemID != snapshot.textsByItemID
                || homeLifeMarkSemanticSignaturesByItemID != snapshot.semanticSignaturesByItemID
                || homeTodayLifeMarkLine != snapshot.todayPrimaryLine
                || homeWeekLifeThemeText != snapshot.weekLifeThemeText
                || homeQuickRecordNudgeText != snapshot.quickRecordNudgeText
                || homeWeekTopCategoryText != snapshot.weekTopCategoryText
            if visibleSnapshotChanged {
                objectWillChange.send()
                homeLifeMarkTextsByItemID = snapshot.textsByItemID
                homeLifeMarkSemanticSignaturesByItemID = snapshot.semanticSignaturesByItemID
                homeTodayLifeMarkLine = snapshot.todayPrimaryLine
                homeWeekLifeThemeText = snapshot.weekLifeThemeText
                homeQuickRecordNudgeText = snapshot.quickRecordNudgeText
                homeWeekTopCategoryText = snapshot.weekTopCategoryText
            }
            homeLifeMarkPreparationTask = nil
        }
    }

    private func prepareHighConfidenceQuickRecordSnapshot(
        now: Date,
        clearsStaleQuickRecord: Bool
    ) {
        let key = HomeQuickRecordSnapshotKey(
            ledgerRevision: homeDashboardRevision,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(for: now)
        )
        guard homeQuickRecordSnapshotKey != key else { return }

        if HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
            previousKey: homeQuickRecordSnapshotKey,
            nextKey: key,
            isLifecycleRefresh: clearsStaleQuickRecord
        ), highConfidenceQuickRecordSuggestionSnapshot != nil {
            objectWillChange.send()
            highConfidenceQuickRecordSuggestionSnapshot = nil
        }
        homeQuickRecordPreparationTask?.cancel()
        homeQuickRecordRequestID = UUID()
        let requestID = homeQuickRecordRequestID
        homeQuickRecordSnapshotKey = key
        let input = HomeQuickRecordPreparationInput(
            key: key,
            items: items,
            now: now
        )
        homeQuickRecordPreparationTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: LedgerRapidInteractionPolicy.homeSnapshotCoalescingDelayNanoseconds
            )
            guard !Task.isCancelled, homeQuickRecordRequestID == requestID else { return }
            let snapshot = await LedgerBackgroundComputationLane.shared.buildHomeQuickRecord(input)
            guard let snapshot,
                  !Task.isCancelled,
                  homeQuickRecordRequestID == requestID,
                  homeQuickRecordSnapshotKey == key else {
                return
            }
            if highConfidenceQuickRecordSuggestionSnapshot != snapshot.suggestion {
                objectWillChange.send()
                highConfidenceQuickRecordSuggestionSnapshot = snapshot.suggestion
            }
            homeQuickRecordPreparationTask = nil
        }
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

    nonisolated static func highConfidenceQuickRecordSuggestionForSnapshot(
        items: [HomeItem],
        at now: Date
    ) -> HomeHighConfidenceQuickRecordSuggestion? {
        let calendar = Calendar.current
        guard isWorkday(now, calendar: calendar) else { return nil }
        guard items.filter({ $0.amount > 0 }).count >= 8 else { return nil }

        if isMorningCommutePromptTime(now, calendar: calendar) {
            guard !hasTodayCommuteRecord(items: items, direction: .morning, now: now, calendar: calendar) else {
                return nil
            }
            if let candidate = commuteHabitCandidate(
                    items: items,
                    direction: .morning,
                    now: now,
                    isBackfill: false,
                    calendar: calendar
            ) {
                return quickRecordSuggestion(from: candidate, now: now)
            }
            if isNoonCommuteBackfillTime(now, calendar: calendar),
               let backfillCandidate = commuteHabitCandidate(
                    items: items,
                    direction: .morning,
                    now: now,
                    isBackfill: true,
                    calendar: calendar
               ) {
                return quickRecordSuggestion(from: backfillCandidate, now: now)
            }
            return nil
        } else if isNoonCommuteBackfillTime(now, calendar: calendar) {
            guard !hasTodayCommuteRecord(items: items, direction: .morning, now: now, calendar: calendar),
                  let candidate = commuteHabitCandidate(
                    items: items,
                    direction: .morning,
                    now: now,
                    isBackfill: true,
                    calendar: calendar
                  ) else {
                return nil
            }
            return quickRecordSuggestion(from: candidate, now: now)
        } else if isEveningCommutePromptTime(now, calendar: calendar) ||
                    isEveningCommuteBackfillTime(now, calendar: calendar) {
            let morningBackfill: HomeCommuteHabitCandidate?
            if hasTodayCommuteRecord(items: items, direction: .morning, now: now, calendar: calendar) {
                morningBackfill = nil
            } else {
                morningBackfill = commuteHabitCandidate(
                    items: items,
                    direction: .morning,
                    now: now,
                    isBackfill: true,
                    calendar: calendar
                )
            }

            let eveningPromptCandidate: HomeCommuteHabitCandidate?
            if hasTodayCommuteRecord(items: items, direction: .evening, now: now, calendar: calendar) {
                eveningPromptCandidate = nil
            } else {
                eveningPromptCandidate = commuteHabitCandidate(
                    items: items,
                    direction: .evening,
                    now: now,
                    isBackfill: false,
                    calendar: calendar
                )
            }
            let eveningBackfillCandidate: HomeCommuteHabitCandidate?
            if hasTodayCommuteRecord(items: items, direction: .evening, now: now, calendar: calendar) ||
                eveningPromptCandidate != nil {
                eveningBackfillCandidate = nil
            } else {
                eveningBackfillCandidate = commuteHabitCandidate(
                    items: items,
                    direction: .evening,
                    now: now,
                    isBackfill: true,
                    calendar: calendar
                )
            }
            let eveningCandidate = eveningPromptCandidate ?? eveningBackfillCandidate

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

    private nonisolated static func quickRecordSuggestion(
        from candidate: HomeCommuteHabitCandidate,
        now: Date
    ) -> HomeHighConfidenceQuickRecordSuggestion {
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

        return HomeHighConfidenceQuickRecordSuggestion(
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
            buttonTitle: candidate.isBackfill ? commuteBackfillButtonTitle(for: candidate.direction) : "一键记通勤",
            backgroundImageName: candidate.direction == .morning
                ? "CommuteMorningQuickCardBackground"
                : "CommuteEveningQuickCardBackground",
            supportCount: candidate.supportCount,
            confidence: candidate.confidence,
            isBackfill: candidate.isBackfill
        )
    }

    private nonisolated static func commuteBackfillButtonTitle(for direction: HomeCommuteHabitDirection) -> String {
        switch direction {
        case .morning: return "补记上班"
        case .evening: return "补记下班"
        }
    }

    private nonisolated static func combinedCommuteSuggestion(
        morningBackfill: HomeCommuteHabitCandidate,
        evening: HomeCommuteHabitCandidate,
        now: Date
    ) -> HomeHighConfidenceQuickRecordSuggestion {
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

        return HomeHighConfidenceQuickRecordSuggestion(
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

    private nonisolated static func commuteHabitCandidate(
        items: [HomeItem],
        direction: HomeCommuteHabitDirection,
        now: Date,
        isBackfill: Bool,
        calendar: Calendar
    ) -> HomeCommuteHabitCandidate? {
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
        let minimumSupport = minimumCommuteSupport(isBackfill: isBackfill)
        guard candidates.count >= minimumSupport.totalSamples else { return nil }

        let distinctDays = Set(candidates.map { quickRecordDayKey(for: $0.createdAt) }).count
        guard distinctDays >= minimumSupport.distinctDays else { return nil }

        let minuteSamples = candidates.map { minutesFromMidnight($0.createdAt, calendar: calendar) }.sorted()
        guard let medianMinute = medianMinute(in: minuteSamples) else { return nil }
        let currentMinute = minutesFromMidnight(now, calendar: calendar)
        if isBackfill {
            guard isPastPersonalCommuteBackfillTime(
                currentMinute: currentMinute,
                medianMinute: medianMinute,
                direction: direction,
                weekdayGroup: weekdayGroup
            ) else { return nil }
        } else {
            guard isNearPersonalCommutePromptTime(
                currentMinute: currentMinute,
                medianMinute: medianMinute,
                direction: direction,
                weekdayGroup: weekdayGroup
            ) else { return nil }
        }

        guard let amountCluster = stableAmountCluster(in: candidates) else { return nil }
        let amount = Double(amountCluster.cents) / 100
        let supportRatio = Double(amountCluster.count) / Double(max(candidates.count, 1))
        guard amountCluster.count >= minimumSupport.amountCluster,
              supportRatio >= minimumSupport.amountRatio else { return nil }

        let title = stableCommuteTitle(in: candidates, direction: direction)
        let confidence = min(0.98, 0.72 + min(supportRatio, 0.22) + min(Double(distinctDays) * 0.01, 0.04))
        guard confidence >= minimumSupport.confidence else { return nil }

        let recordDate = isBackfill
            ? date(onSameDayAs: now, minutesFromMidnight: medianMinute, calendar: calendar)
            : now
        return HomeCommuteHabitCandidate(
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

    private nonisolated static func minimumCommuteSupport(isBackfill: Bool) -> (
        totalSamples: Int,
        distinctDays: Int,
        amountCluster: Int,
        amountRatio: Double,
        confidence: Double
    ) {
        if isBackfill {
            return (totalSamples: 4, distinctDays: 3, amountCluster: 3, amountRatio: 0.64, confidence: 0.86)
        }
        return (totalSamples: 4, distinctDays: 3, amountCluster: 3, amountRatio: 0.58, confidence: 0.82)
    }

    private nonisolated static func stableAmountCluster(in items: [HomeItem]) -> (cents: Int, count: Int)? {
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

    private nonisolated static func stableCommuteTitle(
        in items: [HomeItem],
        direction: HomeCommuteHabitDirection
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

    private nonisolated static func isNearPersonalCommutePromptTime(
        currentMinute: Int,
        medianMinute: Int,
        direction: HomeCommuteHabitDirection,
        weekdayGroup: String
    ) -> Bool {
        let window: (before: Int, after: Int)
        switch direction {
        case .morning:
            window = (before: 35, after: 90)
        case .evening:
            if weekdayGroup == "fri" {
                window = (before: 35, after: 75)
            } else {
                window = (before: 25, after: 65)
            }
        }

        return ((medianMinute - window.before)...(medianMinute + window.after)).contains(currentMinute)
    }

    private nonisolated static func isPastPersonalCommuteBackfillTime(
        currentMinute: Int,
        medianMinute: Int,
        direction: HomeCommuteHabitDirection,
        weekdayGroup: String
    ) -> Bool {
        let graceMinutes: Int
        switch direction {
        case .morning:
            graceMinutes = 35
        case .evening:
            graceMinutes = weekdayGroup == "fri" ? 75 : 65
        }
        return currentMinute >= medianMinute + graceMinutes
    }

    private nonisolated static func hasTodayCommuteRecord(
        items: [HomeItem],
        direction: HomeCommuteHabitDirection,
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

    private nonisolated static func isCommuteRecord(_ item: HomeItem) -> Bool {
        guard item.category == .transport else { return false }
        if item.scenePackId == "commute" { return true }
        let text = "\(item.title) \(item.displayEmotionTag) \(item.memoryContext?.semanticPlace ?? "")".lowercased()
        return containsAny(
            text,
            [
                "通勤", "上班", "下班", "早高峰", "晚高峰", "到岗", "到站",
                "地铁", "公交", "轨道交通", "打车", "滴滴", "花小猪",
                "网约车", "回家", "到家", "路费"
            ]
        )
    }

    private nonisolated static func isMorningCommutePromptTime(_ date: Date, calendar: Calendar) -> Bool {
        (360...630).contains(minutesFromMidnight(date, calendar: calendar))
    }

    private nonisolated static func isNoonCommuteBackfillTime(_ date: Date, calendar: Calendar) -> Bool {
        (570...840).contains(minutesFromMidnight(date, calendar: calendar))
    }

    private nonisolated static func isEveningCommutePromptTime(_ date: Date, calendar: Calendar) -> Bool {
        let minute = minutesFromMidnight(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 6 {
            return (960...1230).contains(minute)
        }
        return (1050...1350).contains(minute)
    }

    private nonisolated static func isEveningCommuteBackfillTime(_ date: Date, calendar: Calendar) -> Bool {
        let minute = minutesFromMidnight(date, calendar: calendar)
        return (1140...1439).contains(minute)
    }

    private nonisolated static func isWorkday(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return (2...6).contains(weekday)
    }

    private nonisolated static func commuteDirection(
        for date: Date,
        calendar: Calendar
    ) -> HomeCommuteHabitDirection? {
        let minute = minutesFromMidnight(date, calendar: calendar)
        if (330...660).contains(minute) { return .morning }
        if (900...1440).contains(minute) { return .evening }
        return nil
    }

    private nonisolated static func commuteWeekdayGroup(
        for date: Date,
        direction: HomeCommuteHabitDirection,
        calendar: Calendar
    ) -> String {
        guard direction == .evening else { return "weekday_morning" }
        return calendar.component(.weekday, from: date) == 6 ? "fri" : "mon_thu"
    }

    private nonisolated static func minutesFromMidnight(_ date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private nonisolated static func medianMinute(in minutes: [Int]) -> Int? {
        guard !minutes.isEmpty else { return nil }
        return minutes[minutes.count / 2]
    }

    private nonisolated static func date(
        onSameDayAs date: Date,
        minutesFromMidnight minute: Int,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .minute, value: minute, to: start) ?? date
    }

    private nonisolated static func commuteTimeText(minutesFromMidnight minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private nonisolated static func quickRecordDayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private nonisolated static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
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
            return "今天还没有支出记录。"
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
        let todayLifeMarkLine = homeTodayLifeMarkLine
        let todayUserMomentLine = TrustedUserMomentNarrativePolicy.preferredNarrative(
            in: records
        )?.line
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
            subtitle = todayUserMomentLine
                ?? todayLateCommuteLine
                ?? Self.singleRecordTodayStoryLine(for: records[0])
        case 2:
            title = "今天已记下 2 笔"
            subtitle = todayUserMomentLine
                ?? todayLateCommuteLine
                ?? todayLifeMarkLine
                ?? todaySceneLine
                ?? "主要在「\(topCategory)」上，记录变得具体。"
        case 3:
            title = "今天记下了 3 笔"
            subtitle = todayUserMomentLine
                ?? todayLateCommuteLine
                ?? todayLifeMarkLine
                ?? todaySceneLine
                ?? "合计 \(totalText)，今天的记录已经成形。"
        default:
            title = "今天记下了 \(count) 笔"
            subtitle = todayUserMomentLine
                ?? todayLateCommuteLine
                ?? todayLifeMarkLine
                ?? todaySceneLine
                ?? "「\(topCategory)」居多，今天的记录已经清楚。"
        }

        return TodayStoryNarrative(
            title: title,
            subtitle: subtitle,
            todayTotalText: count == 0 ? "今日还没记录" : "今日合计 \(totalText)",
            weekTotalText: "本周累计 \(weekText)"
        )
    }

    static func singleRecordTodayStoryLine(for item: HomeItem, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: item.createdAt)
        let period: String
        switch hour {
        case 5..<11: period = "早上"
        case 11..<14: period = "中午"
        case 14..<18: period = "下午"
        case 18..<24: period = "晚上"
        default: period = "夜里"
        }
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = title.isEmpty ? "一笔\(item.category.rawValue)记录" : "一笔「\(title)」"
        return "\(period) \(item.createdAt.zhBillTime)，先记下了\(subject)。"
    }

    private func emptyTodayStoryCopy(now: Date = Date()) -> HomeEmptyTodayCopy {
        let frequentSuggestionLine = frequentRecordAmountSuggestions(at: now).first.map { suggestion in
            "往常这个时间，你常记的是 \(shortAmountText(suggestion.amount)) · \(suggestion.category.label)。"
        }
        let weekItems = filteredItems(in: .week).filter { $0.amount > 0 }
        let dominantSceneLine: String?
        if let scene = LifeSceneSemanticService.dominantScene(in: weekItems),
           scene.count >= 2 {
            dominantSceneLine = "这周「\(LifeSceneSemanticService.displayTheme(for: scene.signal))」出现得比较多。"
        } else {
            dominantSceneLine = nil
        }
        return HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: frequentSuggestionLine,
            dominantSceneLine: dominantSceneLine
        )
    }

    var monthTopCategoryText: String {
        topCategoryLabel(in: .month)
    }

    var weekTopCategoryText: String {
        homeWeekTopCategoryText
    }

    var weekLifeThemeText: String {
        homeWeekLifeThemeText
    }

    var quickRecordNudgeText: String {
        homeQuickRecordNudgeText
            ?? (todayItems.isEmpty ? "只输金额也可以" : "今天已记 \(todayItems.count) 笔")
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
            let structure = weekItems.contains(where: { $0.hasMemoryImages })
                ? photoStructureLine(from: weekItems, fallback: "这一周的记录里，天气、城市和照片都能成为回看线索。")
                : "这一周的记录里，天气、城市和重复出现的场景已经能连起来看。"
            let advice = weekItems.count >= 8
                ? "继续按真实时间记，之后可以按时间线回看。"
                : "再多记几笔，天气和地点线索会更容易浮出来。"
            return (memoryLine, structure, advice)
        }
        if let photoLine = photoMemoryLine(from: weekItems, periodName: "近 7 天") {
            let structure = photoStructureLine(from: weekItems, fallback: "这一周有照片的记录会优先成为回看线索。")
            let advice = "照片只是补充，不用每笔都拍；遇到想记住的瞬间再留下就好。"
            return (photoLine, structure, advice)
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
                ? "继续按笔记下去，下周的周记会更贴近真实记录。"
                : copy.cares.dropFirst().first ?? "再多记几笔，这一周会更容易回头看。"
            return (summary, structure, advice)
        }

        let topCategory = topCategoryLabel(from: weekItems)
        let summary = "近 7 天里，「\(topCategory)」记得更多一些。"
        let structure = "这一周的记录已经分出几段。"
        let advice = weekItems.count >= 8
            ? "继续按笔记下去，下周的周记会更贴近真实记录。"
            : "再多记几笔，这一周会更容易回头看。"
        return (summary, structure, advice)
    }

    /// 本地月度小结文案（三段结构：摘要 / 结构 / 建议）。
    func localMonthlyInsightBlocks() -> (summary: String, structure: String, advice: String) {
        let monthItems = filteredItems(in: .month)
        let positiveMonthItems = monthItems.filter { $0.amount > 0 }
        let total = positiveMonthItems.reduce(0) { $0 + $1.amount }
        let top = topCategoryCountLabel(from: monthItems)
        let summary: String
        if total <= 0 {
            summary = "本月还没有足够账单，多记几笔再来生成月度整理吧。"
        } else if let memoryLine = contextualMemoryLine(from: positiveMonthItems) {
            summary = memoryLine
        } else if let photoLine = photoMemoryLine(from: positiveMonthItems, periodName: "这个月") {
            summary = photoLine
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
            : "这个月已经有一些记录，继续记几天，月度整理会更完整。"
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
        if monthItems.contains(where: { $0.hasMemoryImages }) {
            return photoStructureLine(from: monthItems, fallback: "这个月有几笔记录带着照片，回看时会更像生活片段。")
        }
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
        }?.displayEmotionTag ?? photoMemoryLine(from: sorted, periodName: "这段时间")
    }

    private func photoMemoryLine(from target: [HomeItem], periodName: String) -> String? {
        let photoItems = target
            .filter { $0.amount > 0 && $0.hasMemoryImages }
            .sorted { lhs, rhs in
                if lhs.memoryImageCount == rhs.memoryImageCount {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.memoryImageCount > rhs.memoryImageCount
            }
        guard let first = photoItems.first else { return nil }
        if photoItems.count >= 2 {
            return "\(periodName)留下了 \(photoItems.count) 个有照片的消费时刻，照片让这些记录更像生活。"
        }
        let title = first.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.isEmpty || EchoAnchorService.shared.isDirtyTraceTitle(title)
            ? first.category.rawValue
            : title
        return "\(first.createdAt.zhBillDateTime)的「\(cleanTitle)」留了照片，这一笔以后会更容易想起来。"
    }

    private func photoStructureLine(from target: [HomeItem], fallback: String) -> String {
        let photoCount = target.filter { $0.amount > 0 && $0.hasMemoryImages }.count
        guard photoCount > 0 else { return fallback }
        let total = target.filter { $0.amount > 0 }.count
        if photoCount == 1 {
            return "这一段有 1 笔记录带着照片，它会成为回看时更具体的锚点。"
        }
        return "这一段 \(total) 笔记录里，有 \(photoCount) 个照片锚点，适合以后写成日记或周记。"
    }
}
