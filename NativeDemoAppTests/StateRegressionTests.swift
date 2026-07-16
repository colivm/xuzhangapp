import Foundation
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import NativeDemoApp

final class InteractionStateRegressionTests: XCTestCase {
    private struct QueueItem: Identifiable, Equatable {
        let id: Int
        let value: String
    }

    private enum Route: Equatable {
        case member(String)
        case detail(Int)
    }

    func testPostSaveQueueIsFIFOAndRejectsDuplicateIDs() {
        var queue = UniqueFIFOQueue<QueueItem>()

        XCTAssertTrue(queue.enqueue(QueueItem(id: 1, value: "photo")))
        XCTAssertTrue(queue.enqueue(QueueItem(id: 2, value: "reward")))
        XCTAssertFalse(queue.enqueue(QueueItem(id: 1, value: "duplicate")))

        XCTAssertEqual(queue.dequeue(), QueueItem(id: 1, value: "photo"))
        XCTAssertEqual(queue.dequeue(), QueueItem(id: 2, value: "reward"))
        XCTAssertNil(queue.dequeue())
    }

    func testDeferredRouteConsumesOnceAndLatestRepeatedRequestWins() {
        var routes = DeferredRouteQueue<Route>()
        XCTAssertNil(routes.consume())

        routes.request(.detail(1))
        routes.request(.member("playbackQuota"))

        XCTAssertEqual(routes.consume(), .member("playbackQuota"))
        XCTAssertNil(routes.consume())

        routes.request(.detail(2))
        routes.cancel()
        XCTAssertNil(routes.consume())
    }

    func testLatestRequestGateRejectsStaleCompletion() {
        var gate = LatestRequestGate()
        let first = gate.begin()
        let second = gate.begin()

        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(second))

        gate.invalidate()
        XCTAssertFalse(gate.accepts(second))
    }

    func testPostSavePromptBudgetLimitsFrequencyAndResetsNextDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 9
        ))!
        var state = PostSavePromptBudgetState()

        var result = PostSavePromptBudgetPolicy.reserving(
            .firstPlayback,
            state: state,
            now: start,
            calendar: calendar
        )
        XCTAssertTrue(result.allowed)
        state = result.state

        result = PostSavePromptBudgetPolicy.reserving(
            .sceneReward,
            state: state,
            now: start.addingTimeInterval(5 * 60),
            calendar: calendar
        )
        XCTAssertFalse(result.allowed)

        result = PostSavePromptBudgetPolicy.reserving(
            .sceneReward,
            state: state,
            now: start.addingTimeInterval(21 * 60),
            calendar: calendar
        )
        XCTAssertTrue(result.allowed)
        state = result.state

        result = PostSavePromptBudgetPolicy.reserving(
            .memoryPhoto,
            state: state,
            now: start.addingTimeInterval(60 * 60),
            calendar: calendar
        )
        XCTAssertFalse(result.allowed)

        result = PostSavePromptBudgetPolicy.reserving(
            .memoryPhoto,
            state: state,
            now: start.addingTimeInterval(24 * 60 * 60),
            calendar: calendar
        )
        XCTAssertTrue(result.allowed)
        XCTAssertEqual(result.state.strongPromptCount, 1)
    }

    func testHomeJourneyActionPrioritizesUnfinishedWorkThenPlaybackAndTrace() {
        var snapshot = HomeJourneySnapshot(
            hasOCRDrafts: true,
            hasManualDraft: true,
            todayRecordCount: 2,
            hasUnplayedTodayRecords: true,
            weekTraceReady: true,
            monthTraceReady: true
        )
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .resumeOCR)

        snapshot.hasOCRDrafts = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .continueManualDraft)

        snapshot.hasManualDraft = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .todayPlayback)

        snapshot.hasUnplayedTodayRecords = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .weekTrace)

        snapshot.weekTraceReady = false
        XCTAssertEqual(HomeJourneyActionPolicy.primaryAction(for: snapshot), .monthTrace)
    }

    func testHomeJourneyActionKeepsRecordingAvailableAsSecondaryAction() {
        XCTAssertEqual(
            HomeJourneyActionPolicy.secondaryAction(for: .todayPlayback, hasTodayRecords: true),
            .continueRecording
        )
        XCTAssertEqual(
            HomeJourneyActionPolicy.secondaryAction(for: .record, hasTodayRecords: false),
            .resumeOCR
        )
    }

    func testNewUserProgressionUnlocksOneNextStageWithoutEmptyReviewSelling() {
        var snapshot = NewUserProgressionSnapshot(
            totalRecordCount: 0,
            hasUnplayedTodayRecords: false,
            weekRecordCount: 0,
            monthRecordCount: 0,
            dayOfMonth: 16,
            canPlayWeek: true,
            canPlayMonth: true,
            hasCompletedCurrentWeekPlayback: false,
            hasCompletedCurrentMonthPlayback: false
        )
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .recordFirstEntry)
        XCTAssertFalse(NewUserProgressionPolicy.allowsReviewTasks(totalRecordCount: 0))

        snapshot.totalRecordCount = 1
        snapshot.hasUnplayedTodayRecords = true
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .todayPlayback)

        snapshot.hasUnplayedTodayRecords = false
        snapshot.totalRecordCount = 3
        snapshot.weekRecordCount = 3
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .weekTrace)

        snapshot.weekRecordCount = 0
        snapshot.monthRecordCount = 3
        snapshot.dayOfMonth = 25
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .monthChapter)

        snapshot.monthRecordCount = 0
        snapshot.hasCompletedCurrentWeekPlayback = true
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .reviewTasks)
        XCTAssertEqual(
            HomeJourneyActionPolicy.primaryAction(
                for: HomeJourneySnapshot(
                    hasOCRDrafts: false,
                    hasManualDraft: false,
                    todayRecordCount: 0,
                    hasUnplayedTodayRecords: false,
                    weekTraceReady: false,
                    monthTraceReady: false
                ),
                progressionStage: .reviewTasks
            ),
            .review
        )
    }

    func testRecordFlowKeepsOCRAndOptionalDetailsOutOfThePrimarySavePath() {
        XCTAssertTrue(RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: false))
        XCTAssertFalse(RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: true))
        XCTAssertFalse(RecordFlowVisibilityPolicy.showsOptionalDetails(hasValidAmount: false))
        XCTAssertTrue(RecordFlowVisibilityPolicy.showsOptionalDetails(hasValidAmount: true))
    }

    func testTraceRangeContextUsesOneWeekMonthSource() {
        XCTAssertEqual(TraceRangeContextPolicy.period(for: .week), .week)
        XCTAssertEqual(TraceRangeContextPolicy.period(for: .month), .month)
        XCTAssertEqual(TraceRangeContextPolicy.lifeRange(for: .week), .week)
        XCTAssertEqual(TraceRangeContextPolicy.lifeRange(for: .month), .month)
        XCTAssertNil(TraceRangeContextPolicy.lifeRange(for: .year))
    }

    func testReviewTaskIntentsMapToSupportedExplicitCommands() {
        XCTAssertEqual(ReviewTaskIntent.allCases.count, 3)
        XCTAssertTrue(ReviewTaskIntent.query.presetCommand.contains("过去三天"))
        XCTAssertTrue(ReviewTaskIntent.compare.presetCommand.contains("本周和上周"))
        XCTAssertTrue(ReviewTaskIntent.backfill.presetCommand.contains("补记"))
    }

    func testPlaybackMaturityAndCompletionUseOnePrimaryRule() {
        XCTAssertFalse(PlaybackMaturityPolicy.weekIsReady(recordCount: 2))
        XCTAssertTrue(PlaybackMaturityPolicy.weekIsReady(recordCount: 3))
        XCTAssertFalse(PlaybackMaturityPolicy.monthIsReady(recordCount: 8, dayOfMonth: 24))
        XCTAssertTrue(PlaybackMaturityPolicy.monthIsReady(recordCount: 3, dayOfMonth: 25))
        XCTAssertEqual(PlaybackCompletionPolicy.primaryAction(isMember: true), .dismiss)
        XCTAssertEqual(PlaybackCompletionPolicy.primaryAction(isMember: false), .showMemberPricing)
        XCTAssertEqual(PlaybackCompletionPolicy.primaryTitle(isMember: true, memberTitle: nil), "完成")
    }

    func testAutomaticMemberNudgesRespectBudgetWhileExplicitEntriesStayImmediate() throws {
        let now = Date(timeIntervalSince1970: 1_752_643_200)
        let policy = MemberNudgePolicy(prodDailyLimit: 1, prodSceneCooldownDays: 7)
        let dailyLimitedState = MemberNudgeState(
            lastShownAt: now,
            dailyDayKey: MemberNudgePolicyService.dayKey(for: now),
            dailyCount: 1,
            sceneCooldownUntil: [:],
            automaticCooldownUntil: nil
        )

        XCTAssertFalse(MemberNudgeEligibilityPolicy.canPresent(
            source: .automatic,
            scene: "share_success",
            policy: policy,
            state: dailyLimitedState,
            now: now
        ))
        XCTAssertTrue(MemberNudgeEligibilityPolicy.canPresent(
            source: .explicitUserAction,
            scene: "locked_month_chapter",
            policy: policy,
            state: dailyLimitedState,
            now: now
        ))

        var dismissedState = MemberNudgeState.empty
        dismissedState.automaticCooldownUntil = now.addingTimeInterval(7 * 24 * 60 * 60)
        XCTAssertFalse(MemberNudgeEligibilityPolicy.canPresent(
            source: .automatic,
            scene: "ai_monthly",
            policy: policy,
            state: dismissedState,
            now: now
        ))

        struct LegacyState: Encodable {
            let lastShownAt: Date?
            let dailyDayKey: String
            let dailyCount: Int
            let sceneCooldownUntil: [String: Date]
        }
        let legacyData = try JSONEncoder().encode(LegacyState(
            lastShownAt: nil,
            dailyDayKey: "",
            dailyCount: 0,
            sceneCooldownUntil: [:]
        ))
        XCTAssertNil(try JSONDecoder().decode(MemberNudgeState.self, from: legacyData).automaticCooldownUntil)
    }

    func testMemberLoginContinuationResumesSelectedPlanExactlyOnce() {
        var state = MemberLoginContinuationState()

        state.beginLogin(for: .purchase(planID: "lifetime"))
        XCTAssertEqual(state.pendingLoginIntent, .purchase(planID: "lifetime"))
        XCTAssertNil(state.resumedIntent)

        state.loginSucceeded()
        state.loginSucceeded()

        XCTAssertNil(state.pendingLoginIntent)
        XCTAssertEqual(state.takeResumedIntent(), .purchase(planID: "lifetime"))
        XCTAssertNil(state.takeResumedIntent())
    }

    func testMemberLoginCancellationClearsIntentWithoutResumingPurchaseOrRestore() {
        var state = MemberLoginContinuationState()
        state.beginLogin(for: .restorePurchases)
        state.loginCancelled()

        XCTAssertNil(state.pendingLoginIntent)
        XCTAssertNil(state.takeResumedIntent())

        state.beginLogin(for: .purchase(planID: "monthly"))
        state.loginSucceeded()
        state.clearResumedIntent()
        XCTAssertNil(state.takeResumedIntent())
    }

    @MainActor
    func testRecordSessionPersistsDraftUIUntilCommittedReset() {
        let session = RecordTabSession()
        session.selectedEntryMode = .ocr
        session.recordDetailsExpanded = true
        session.noteEditorExpanded = true
        session.previewLineWasRotated = true
        session.userNoteAnchorTitle = "晚饭"

        XCTAssertEqual(session.selectedEntryMode, .ocr)
        XCTAssertTrue(session.noteEditorExpanded)

        session.resetAfterCommittedDraft()

        XCTAssertEqual(session.selectedEntryMode, .manual)
        XCTAssertFalse(session.recordDetailsExpanded)
        XCTAssertFalse(session.noteEditorExpanded)
        XCTAssertFalse(session.previewLineWasRotated)
        XCTAssertNil(session.userNoteAnchorTitle)
    }

    func testTabStateRetainsTraceAndInsightContext() {
        var stats = StatsTabState()
        stats.selectedPeriod = .month
        stats.selectedCategory = .dining
        stats.useCustomRange = true
        stats.viewMode = .clues
        stats.scrollAnchorID = "trace-clue-board"

        XCTAssertEqual(stats.selectedPeriod, .month)
        XCTAssertEqual(stats.selectedCategory, .dining)
        XCTAssertTrue(stats.useCustomRange)
        XCTAssertEqual(stats.viewMode, .clues)
        XCTAssertEqual(stats.scrollAnchorID, "trace-clue-board")

        stats.openLifeChapter(.month)
        XCTAssertEqual(stats.viewMode, .life)
        XCTAssertEqual(stats.lifeCardRange, .month)
        XCTAssertEqual(stats.selectedPeriod, .month)
        XCTAssertFalse(stats.useCustomRange)
        XCTAssertEqual(stats.scrollAnchorID, "trace-life-card")

        var insight = InsightTabState()
        insight.showsAdvancedInsight = true
        insight.scrollAnchorID = "insight-next-chapter"
        insight.monthlyInsightGenerated = true

        XCTAssertTrue(insight.showsAdvancedInsight)
        XCTAssertTrue(insight.monthlyInsightGenerated)
        XCTAssertEqual(insight.scrollAnchorID, "insight-next-chapter")
    }
}

final class OCRImportSubmissionGateTests: XCTestCase {
    func testOnlyOneOCRImportCanSubmitUntilReset() {
        var gate = OCRImportSubmissionGate()

        XCTAssertTrue(gate.begin(.review))
        XCTAssertFalse(gate.begin(.direct))
        XCTAssertEqual(gate.action, .review)

        gate.reset()
        XCTAssertTrue(gate.begin(.direct))
        XCTAssertEqual(gate.action, .direct)
    }
}

final class AICommuteBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testTodayCommuteSlotsNeverIncludeFutureTime() {
        let day = date(2026, 7, 15, 0, 0)

        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 8, 29), calendar: calendar).map(\.title),
            []
        )
        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 8, 30), calendar: calendar).map(\.title),
            ["早高峰通勤"]
        )
        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 18, 29), calendar: calendar).map(\.title),
            ["早高峰通勤"]
        )
        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: day, now: date(2026, 7, 15, 18, 30), calendar: calendar).map(\.title),
            ["早高峰通勤", "晚高峰通勤"]
        )
    }

    func testHistoricalDayKeepsBothCommuteSlots() {
        let historicalDay = date(2026, 7, 14, 0, 0)
        let now = date(2026, 7, 15, 7, 0)

        XCTAssertEqual(
            AICommuteDraftSchedule.eligibleSlots(for: historicalDay, now: now, calendar: calendar).map(\.title),
            ["早高峰通勤", "晚高峰通勤"]
        )
    }
}

final class PlaybackQuotaRegressionTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PlaybackQuotaRegressionTests")!
        defaults.removePersistentDomain(forName: "PlaybackQuotaRegressionTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "PlaybackQuotaRegressionTests")
        defaults = nil
        super.tearDown()
    }

    func testPlaybackQuotaChangesOnlyAfterExplicitStart() {
        let store = DailyFeatureQuotaStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_768_000_000)

        XCTAssertEqual(store.todayPlaybackRemaining(isMember: false, now: now), 3)
        XCTAssertTrue(store.canPlayTodayPlayback(isMember: false, now: now))
        XCTAssertEqual(store.todayPlaybackRemaining(isMember: false, now: now), 3)

        store.markTodayPlaybackStarted(isMember: false, now: now)
        XCTAssertEqual(store.todayPlaybackRemaining(isMember: false, now: now), 2)
    }
}

final class TraceLifePreparationPolicyTests: XCTestCase {
    func testInitialEntryBuildsOnlyVisibleRangeThenPrewarmsTheOther() {
        XCTAssertTrue(
            TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: .week,
                weekNeedsRefresh: true,
                monthNeedsRefresh: true,
                hasWeek: false,
                hasMonth: false
            )
        )
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .week), .month)
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .month), .week)
    }

    func testSwitchingToMissingMonthKeepsWeekVisibleDuringPreparation() {
        XCTAssertTrue(
            TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: .month,
                hasWeek: true,
                hasMonth: false
            )
        )
        XCTAssertTrue(
            TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: .month,
                weekNeedsRefresh: false,
                monthNeedsRefresh: true,
                hasWeek: true,
                hasMonth: false
            )
        )
    }

    func testPreparedVisibleRangeDoesNotRebuildWhileOtherRangeWarms() {
        XCTAssertFalse(
            TraceLifePreparationPolicy.needsPrimaryPreparation(
                selectedRange: .week,
                weekNeedsRefresh: false,
                monthNeedsRefresh: true,
                hasWeek: true,
                hasMonth: false
            )
        )
    }
}

final class InsightBackgroundComputationTests: XCTestCase {
    private func makeItems(count: Int, now: Date) -> [HomeItem] {
        let categories = HomeItem.Category.allCases
        return (0..<count).map { index in
            let idText = String(format: "00000000-0000-0000-0000-%012X", index + 1)
            let category = categories[index % categories.count]
            return HomeItem(
                id: UUID(uuidString: idText)!,
                title: index % 4 == 0 ? "工作日午餐" : category.defaultRecordTitle,
                amount: Double((index % 97) + 1) + Double(index % 3) * 0.5,
                category: category,
                createdAt: now.addingTimeInterval(TimeInterval(-index * 3 * 60 * 60)),
                updatedAt: now.addingTimeInterval(TimeInterval(-index * 2 * 60 * 60)),
                userEditedTitle: index % 4 == 0
            )
        }
    }

    func testThousandRecordReviewAndAIComputationAreDeterministic() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = makeItems(count: 1_000, now: now)
        let input = InsightComputationInput(items: items, isMember: true, now: now)

        let firstSnapshot = InsightComputationService.weeklyPageSnapshot(input)
        let secondSnapshot = InsightComputationService.weeklyPageSnapshot(input)
        XCTAssertEqual(firstSnapshot.journalText, secondSnapshot.journalText)
        XCTAssertEqual(firstSnapshot.journalClosing, secondSnapshot.journalClosing)
        XCTAssertEqual(firstSnapshot.rhythmText, secondSnapshot.rhythmText)
        XCTAssertEqual(firstSnapshot.keywords, secondSnapshot.keywords)
        XCTAssertEqual(firstSnapshot.reviewOverview, secondSnapshot.reviewOverview)

        let firstDigest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "最近 90 天餐饮花了多少",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        let secondDigest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "最近 90 天餐饮花了多少",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        XCTAssertEqual(firstDigest, secondDigest)
        XCTAssertFalse(firstDigest.isEmpty)
    }

    func testLatestAIRequestGateNeverAcceptsOlderCompletion() {
        var gate = LatestRequestGate()
        let earlier = gate.begin()
        let latest = gate.begin()

        XCTAssertFalse(gate.accepts(earlier))
        XCTAssertTrue(gate.accepts(latest))

        gate.invalidate()
        XCTAssertFalse(gate.accepts(latest))
    }

    func testReviewOverviewMakesCurrentAndPreviousSevenDaysDirectlyComparable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let items = [
            HomeItem(title: "午餐", amount: 10, category: .dining, createdAt: date(13, 12)),
            HomeItem(title: "今天地铁", amount: 20, category: .transport, createdAt: date(16, 8)),
            HomeItem(title: "前七天地铁", amount: 40, category: .transport, createdAt: date(9, 8)),
        ]

        let overview = InsightComputationService.weeklyPageSnapshot(
            InsightComputationInput(items: items, isMember: true, now: now)
        ).reviewOverview

        XCTAssertEqual(overview.currentTotal, 30, accuracy: 0.001)
        XCTAssertEqual(overview.currentCount, 2)
        XCTAssertEqual(overview.previousTotal, 40, accuracy: 0.001)
        XCTAssertEqual(overview.previousCount, 1)
        XCTAssertEqual(overview.amountDelta, -10, accuracy: 0.001)
        XCTAssertEqual(overview.countDelta, 1)
        XCTAssertEqual(overview.activeDayCount, 2)
        XCTAssertEqual(overview.todayCount, 1)
        XCTAssertEqual(overview.topCategoryLabel, HomeItem.Category.transport.rawValue)
        XCTAssertEqual(overview.topCategoryAmount, 20, accuracy: 0.001)
        XCTAssertEqual(overview.days.count, 7)
        XCTAssertEqual(overview.days.last?.label, "今天")
        XCTAssertEqual(overview.days.last?.count, 1)
    }

    func testAICommandComparisonKeepsBothPeriodsAndCategoryChanges() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        func date(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 7,
                day: day,
                hour: hour
            ))!
        }
        let items = [
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                title: "本周午餐",
                amount: 10,
                category: .dining,
                createdAt: date(13, 12)
            ),
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                title: "本周地铁",
                amount: 20,
                category: .transport,
                createdAt: date(14, 8)
            ),
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                title: "上周午餐",
                amount: 30,
                category: .dining,
                createdAt: date(6, 12)
            ),
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
                title: "上周日用",
                amount: 20,
                category: .shopping,
                createdAt: date(7, 18)
            ),
        ]

        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "对比本周和上周的消费",
            items: items,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("compare#本周 对比 上周同期#"))
        XCTAssertTrue(digest.contains("本周:30.0:2"))
        XCTAssertTrue(digest.contains("上周同期:50.0:2"))
        XCTAssertTrue(digest.contains("餐饮:10.0:30.0:1:1"))
        XCTAssertTrue(digest.contains("00000000-0000-0000-0000-000000000201"))
    }

    func testUnsupportedAICommandDoesNotInventFactsOutsideTheLedger() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            HomeItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "午餐",
                amount: 28,
                category: .dining,
                createdAt: now
            )
        ]
        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "告诉我老板今天心情怎么样",
            items: items,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("unsupported#"))
        XCTAssertFalse(digest.contains("老板今天"))
        XCTAssertFalse(digest.contains("心情很好"))
    }
}

final class AICommandRecognitionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func digest(_ command: String) -> String {
        InsightWebView.aiCommandRecognitionDigestForTesting(command: command, now: now)
    }

    func testNaturalQueryExpressionsShareTheSameSupportedIntent() {
        let weekDining = digest("这礼拜吃饭用了多少")
        let recentTransport = digest("最近坐车花销")
        let recentCoffee = digest("前仨月咖啡花费")

        XCTAssertTrue(weekDining.hasPrefix("query#"))
        XCTAssertTrue(weekDining.contains("#餐饮#"))
        XCTAssertTrue(recentTransport.hasPrefix("query#"))
        XCTAssertTrue(recentTransport.contains("#交通#"))
        XCTAssertTrue(recentCoffee.hasPrefix("query#"))
        XCTAssertTrue(recentCoffee.contains("前三个月咖啡花费"))
        XCTAssertTrue(recentCoffee.contains("#咖啡#"))
    }

    func testTraditionalChineseAndColloquialTimeAreNormalizedBeforeRecognition() {
        let traditionalQuery = digest("這週吃飯花了多少錢？")
        let traditionalCompare = digest("這個月跟上個月差在哪？")

        XCTAssertTrue(traditionalQuery.hasPrefix("query#"))
        XCTAssertTrue(traditionalQuery.contains("这周吃饭花了多少钱"))
        XCTAssertTrue(traditionalQuery.contains("#餐饮#"))
        XCTAssertTrue(traditionalCompare.hasPrefix("compare#"))
        XCTAssertTrue(traditionalCompare.contains("这个月跟上个月差在哪"))
    }

    func testComparisonCanBeImplicitButStillRequiresComparableEvidence() {
        XCTAssertTrue(digest("本月比上月多多少").hasPrefix("compare#"))
        XCTAssertTrue(digest("这个月跟上个月差在哪").hasPrefix("compare#"))
        XCTAssertTrue(digest("今天怎么样").hasPrefix("unsupported#"))
    }

    func testBackfillRequiresStrongAffirmativeWriteLanguage() {
        XCTAssertTrue(digest("补上昨天上下班通勤").hasPrefix("commuteDraft#"))
        XCTAssertTrue(digest("昨天通勤花了多少").hasPrefix("query#"))

        let negated = digest("不要补记今天通勤")
        XCTAssertTrue(negated.hasPrefix("unsupported#"))
        XCTAssertTrue(negated.contains("guard:negatedWrite"))
        let negatedResult = InsightWebView.aiCommandComputationDigestForTesting(
            command: "不要补记今天通勤",
            items: [],
            hasMemberAccess: true,
            amountText: "10",
            now: now
        )
        XCTAssertTrue(negatedResult.hasPrefix("unsupported#"))
        XCTAssertFalse(negatedResult.contains("早高峰"))
        XCTAssertFalse(negatedResult.contains("晚高峰"))

        let genericGeneration = digest("生成今天通勤")
        XCTAssertTrue(genericGeneration.hasPrefix("unsupported#"))
        XCTAssertTrue(genericGeneration.contains("guard:unsupportedWrite"))

        XCTAssertTrue(digest("生成一份今天通勤统计").hasPrefix("query#"))
        XCTAssertTrue(digest("不要补记，查一下今天通勤花了多少").hasPrefix("query#"))
        XCTAssertTrue(digest("减少这周餐饮记录").hasPrefix("unsupported#"))
        XCTAssertTrue(digest("这周餐饮减少了多少").hasPrefix("compare#"))
    }

    func testSubjectiveAndOutsideLedgerQuestionsDoNotBorrowWeakLedgerWords() {
        let transportOpinion = digest("交通不错吗")
        let bossState = digest("老板今天怎么样")
        let causalGuess = digest("为什么这个月比上个月多")

        XCTAssertTrue(transportOpinion.hasPrefix("unsupported#"))
        XCTAssertTrue(transportOpinion.contains("guard:subjective"))
        XCTAssertTrue(bossState.hasPrefix("unsupported#"))
        XCTAssertTrue(bossState.contains("guard:outsideSubject"))
        XCTAssertTrue(causalGuess.hasPrefix("unsupported#"))
        XCTAssertTrue(causalGuess.contains("guard:subjective"))
    }

    func testIntentPriorityKeepsReadOnlyTasksDistinct() {
        XCTAssertTrue(digest("查一下本周有没有重复账单").hasPrefix("duplicateCheck#"))
        XCTAssertTrue(digest("这月最贵的一笔").hasPrefix("largestRecord#"))
        XCTAssertTrue(digest("本月比上月多多少").hasPrefix("compare#"))
        XCTAssertTrue(digest("上次买可乐是哪天").hasPrefix("lastRecordLookup#"))
        XCTAssertTrue(digest("这周打车是哪天").hasPrefix("query#"))
        XCTAssertTrue(digest("这个月消费怎么样").hasPrefix("lifestyleSummary#"))
    }
}

final class MembershipQuotaBoundaryTests: XCTestCase {
    func testDisplaySimplificationDoesNotChangeExistingQuotaConstants() {
        XCTAssertEqual(MembershipQuotaBaseline.todayPlaybackDaily, 3)
        XCTAssertEqual(MembershipQuotaBaseline.ocrDaily, 3)
        XCTAssertEqual(MembershipQuotaBaseline.weeklyJournal, 3)
        XCTAssertEqual(MembershipQuotaBaseline.lifetimeMonthChapter, 10)
        XCTAssertEqual(MembershipQuotaBaseline.monthlyLifeClue, 5)
        XCTAssertEqual(MembershipQuotaBaseline.monthlyInsightTrialTotal, 5)
    }
}

final class AccessibilityLayoutPolicyTests: XCTestCase {
    func testCoreTapTargetNeverDropsBelowFortyFourPoints() {
        XCTAssertGreaterThanOrEqual(AccessibilityLayoutPolicy.minimumTapTarget, 44)
    }

    func testPrimaryActionsStackForAccessibilityTextOrNarrowWidths() {
        XCTAssertTrue(
            AccessibilityLayoutPolicy.shouldStackPrimaryActions(
                isAccessibilityTextSize: true,
                availableWidth: 390,
                actionCount: 2
            )
        )
        XCTAssertTrue(
            AccessibilityLayoutPolicy.shouldStackPrimaryActions(
                isAccessibilityTextSize: false,
                availableWidth: 240,
                actionCount: 2
            )
        )
        XCTAssertFalse(
            AccessibilityLayoutPolicy.shouldStackPrimaryActions(
                isAccessibilityTextSize: false,
                availableWidth: 390,
                actionCount: 2
            )
        )
    }

    func testReduceMotionDisablesDecorativeMotion() {
        XCTAssertFalse(AccessibilityLayoutPolicy.allowsDecorativeMotion(reduceMotion: true))
        XCTAssertTrue(AccessibilityLayoutPolicy.allowsDecorativeMotion(reduceMotion: false))
    }

    func testReadableTextOpacityFloorRemainsLegible() {
        XCTAssertGreaterThanOrEqual(AccessibilityLayoutPolicy.minimumReadableTextOpacity, 0.72)
    }
}

final class AnalyticsPrivacyBoundaryTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AnalyticsPrivacyBoundaryTests")!
        defaults.removePersistentDomain(forName: "AnalyticsPrivacyBoundaryTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AnalyticsPrivacyBoundaryTests")
        defaults = nil
        super.tearDown()
    }

    @MainActor
    func testLegacyEventsWithSensitivePropertiesAreRemoved() {
        defaults.set(Data("legacy-sensitive-event".utf8), forKey: "ios_analytics_events_v1")
        _ = AnalyticsService(defaults: defaults)
        XCTAssertNil(defaults.data(forKey: "ios_analytics_events_v1"))
    }

    @MainActor
    func testOnlyAllowlistedAnonymousPropertiesArePersisted() {
        let service = AnalyticsService(defaults: defaults)
        service.track(
            .recordSaved,
            props: [
                .source: "manual",
                .ledgerSizeBucket: "10_49",
                .countBucket: "42",
                .scene: "用户备注",
            ]
        )

        let event = try! XCTUnwrap(service.loadEvents().first)
        XCTAssertEqual(event.name, .recordSaved)
        XCTAssertEqual(event.props["source"], "manual")
        XCTAssertEqual(event.props["ledger_size_bucket"], "10_49")
        XCTAssertNil(event.props["count_bucket"])
        XCTAssertNil(event.props["scene"])
        XCTAssertNil(event.props["amount"])
        XCTAssertNil(event.props["title"])
        XCTAssertNil(event.props["merchant"])
    }

    @MainActor
    func testCountsAndDurationsUseCoarseBuckets() {
        XCTAssertEqual(AnalyticsService.countBucket(for: 0), "0")
        XCTAssertEqual(AnalyticsService.countBucket(for: 37), "10_49")
        XCTAssertEqual(AnalyticsService.countBucket(for: 1_000), "1000_4999")
        XCTAssertEqual(AnalyticsService.countBucket(for: 5_000), "5000_plus")
        XCTAssertEqual(AnalyticsService.durationBucket(for: 49), "under_50ms")
        XCTAssertEqual(AnalyticsService.durationBucket(for: 150), "150_399ms")
        XCTAssertEqual(AnalyticsService.durationBucket(for: 3_000), "3s_plus")
    }

    @MainActor
    func testEventsExpireAfterThirtyDaysAndHaveNoStableUserIdentifier() {
        let service = AnalyticsService(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        service.track(.appOpened, props: [.ledgerSizeBucket: "100_999"], at: now.addingTimeInterval(-31 * 86_400))
        service.track(.appOpened, props: [.ledgerSizeBucket: "100_999"], at: now)

        let events = service.loadEvents(referenceDate: now)
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0].props.keys.contains("user_id"))
        XCTAssertFalse(events[0].props.keys.contains("device_id"))
    }
}

#if DEBUG && canImport(UIKit)
final class ReleaseScaleFixtureTests: XCTestCase {
    private struct Manifest: Decodable {
        let fixtureSetDigestSha256: String
        let fixtures: [FixtureEntry]
    }

    private struct FixtureEntry: Decodable {
        let file: String
        let recordCount: Int
        let amountMinorUnitTotal: Int
        let imageCount: Int
        let photoRecordCount: Int
        let recordDigestSha256: String
        let ocrDraftCounts: OCRDraftCounts
    }

    private struct OCRDraftCounts: Decodable {
        let pending: Int
        let resolved: Int
        let total: Int
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadManifest() throws -> Manifest {
        let url = repositoryRoot.appendingPathComponent("qa/release_fixtures/manifest.json")
        return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    private func loadFixture(file: String) throws -> [HomeItem] {
        let url = repositoryRoot.appendingPathComponent("qa/release_fixtures/\(file)")
        return try JSONDecoder().decode([HomeItem].self, from: Data(contentsOf: url))
    }

    private func minorUnitTotal(_ items: [HomeItem]) -> Int {
        items.reduce(0) { $0 + Int(($1.amount * 100).rounded()) }
    }

    func testReleaseFixtureLaunchConfigurationRejectsUnsupportedOrMissingCounts() {
        XCTAssertNil(ReleaseFixtureLaunchConfiguration.resolve(arguments: [], environment: [:]))
        XCTAssertNil(
            ReleaseFixtureLaunchConfiguration.resolve(
                arguments: ["app", "-QAReleaseFixtureCount", "999"],
                environment: [:]
            )
        )
        XCTAssertEqual(
            ReleaseFixtureLaunchConfiguration.resolve(
                arguments: ["app", "-QAReleaseFixtureCount", "1000", "-QAReleaseFixtureReset"],
                environment: [:]
            ),
            ReleaseFixtureLaunchConfiguration(count: 1_000, reset: true)
        )
        XCTAssertEqual(
            ReleaseFixtureLaunchConfiguration.resolve(
                arguments: [
                    "app", "-QAReleaseFixtureCount", "1000",
                    "-QAReleasePhotoProfile", "realistic",
                ],
                environment: [:]
            ),
            ReleaseFixtureLaunchConfiguration(
                count: 1_000,
                reset: false,
                photoProfile: .realistic
            )
        )
    }

    func testRealisticPhotoFixtureUsesPhoneSizedJPEGResources() throws {
        let items = ReleaseFixtureFactory.makeItems(count: 1_000, photoProfile: .realistic)
        let photos = items.flatMap(\.memoryImages)
        XCTAssertFalse(photos.isEmpty)
        var uniquePhotos: [Data] = []
        for data in photos where !uniquePhotos.contains(data) {
            uniquePhotos.append(data)
            if uniquePhotos.count == 3 { break }
        }
        XCTAssertEqual(uniquePhotos.count, 3)
        for data in uniquePhotos {
            let image = try XCTUnwrap(UIImage(data: data))
            XCTAssertGreaterThanOrEqual(Int(image.size.width * image.scale) * Int(image.size.height * image.scale), 12_000_000)
            XCTAssertGreaterThanOrEqual(data.count, 2_000_000)
        }
    }

    func testGeneratedReleaseFixturesMatchSwiftFactoryAndDecodeValidImages() throws {
        let manifest = try loadManifest()
        XCTAssertEqual(manifest.fixtures.map(\.recordCount), [100, 1_000, 5_000])
        XCTAssertEqual(manifest.fixtureSetDigestSha256.count, 64)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        for entry in manifest.fixtures {
            let actual = try loadFixture(file: entry.file)
            let expected = ReleaseFixtureFactory.makeItems(count: entry.recordCount)
            XCTAssertEqual(actual.count, entry.recordCount)
            XCTAssertEqual(actual.count, expected.count)
            XCTAssertEqual(minorUnitTotal(actual), entry.amountMinorUnitTotal)
            XCTAssertEqual(Set(actual.map(\.category)), Set(HomeItem.Category.allCases))
            XCTAssertEqual(
                Set(actual.map { calendar.component(.year, from: $0.createdAt) }),
                Set([2024, 2025, 2026])
            )

            var imageCount = 0
            var photoRecordCount = 0
            var pendingCount = 0
            var resolvedCount = 0
            for (index, pair) in zip(actual, expected).enumerated() {
                XCTAssertEqual(pair.0, pair.1, "release fixture mismatch at \(entry.recordCount)#\(index)")
                if !pair.0.memoryImages.isEmpty {
                    photoRecordCount += 1
                }
                imageCount += pair.0.memoryImages.count
                for imageData in pair.0.memoryImages {
                    XCTAssertNotNil(UIImage(data: imageData), "invalid image at \(entry.recordCount)#\(index)")
                }
                if let coverIndex = pair.0.normalizedCoverMemoryImageIndex {
                    XCTAssertTrue(pair.0.memoryImages.indices.contains(coverIndex))
                    XCTAssertEqual(pair.0.coverMemoryImageData, pair.0.memoryImages[coverIndex])
                }
                switch pair.0.draftMeta?.status {
                case .pending: pendingCount += 1
                case .resolved: resolvedCount += 1
                case nil: break
                }
            }

            XCTAssertEqual(imageCount, entry.imageCount)
            XCTAssertEqual(photoRecordCount, entry.photoRecordCount)
            XCTAssertEqual(pendingCount, entry.ocrDraftCounts.pending)
            XCTAssertEqual(resolvedCount, entry.ocrDraftCounts.resolved)
            XCTAssertEqual(pendingCount + resolvedCount, entry.ocrDraftCounts.total)
            XCTAssertEqual(entry.recordDigestSha256.count, 64)
        }
    }

    func testReleaseScaleMigrationPreservesCountAmountImagesOrderAndCover() throws {
        for count in [100, 1_000, 5_000] {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReleaseScaleFixtureTests-\(count)-\(UUID().uuidString)", isDirectory: true)
            let suiteName = "ReleaseScaleFixtureTests.\(count).\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer {
                defaults.removePersistentDomain(forName: suiteName)
                try? FileManager.default.removeItem(at: root)
            }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

            let sourceItems = ReleaseFixtureFactory.makeItems(count: count)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let legacyData = try encoder.encode(sourceItems)
            try legacyData.write(to: root.appendingPathComponent("home_items_v1.json"), options: .atomic)
            defaults.set(legacyData, forKey: "home_items_v1_backup")

            let repository = LedgerHomeItemsRepository(documentsURL: root, defaults: defaults)
            let result = repository.load()
            XCTAssertFalse(result.writesBlocked)
            XCTAssertEqual(result.items.count, count)
            XCTAssertEqual(minorUnitTotal(result.items), minorUnitTotal(sourceItems))
            XCTAssertTrue(
                FileManager.default.fileExists(
                    atPath: root.appendingPathComponent("home_items_v1.pre_image_migration.json").path
                )
            )

            let sourceByID = Dictionary(uniqueKeysWithValues: sourceItems.map { ($0.id, $0) })
            let loadedByID = Dictionary(uniqueKeysWithValues: result.items.map { ($0.id, $0) })
            XCTAssertEqual(Set(sourceByID.keys), Set(loadedByID.keys))
            for id in sourceByID.keys {
                let source = try XCTUnwrap(sourceByID[id])
                let loaded = try XCTUnwrap(loadedByID[id])
                XCTAssertEqual(loaded.amount, source.amount)
                XCTAssertEqual(loaded.category, source.category)
                XCTAssertEqual(loaded.draftMeta, source.draftMeta)
                XCTAssertEqual(loaded.memoryImageCount, source.memoryImageCount)
                XCTAssertTrue(loaded.memoryImages.allSatisfy(\.isEmpty))
                XCTAssertEqual(loaded.normalizedCoverMemoryImageIndex, source.normalizedCoverMemoryImageIndex)
                XCTAssertEqual(loaded.memoryImageReferences.count, source.memoryImages.count)
                for index in 0..<loaded.memoryImageCount {
                    let reference = try XCTUnwrap(loaded.memoryImageReference(at: index))
                    XCTAssertEqual(
                        repository.loadImageData(reference: reference, variant: .original),
                        source.memoryImageData(at: index)
                    )
                }
            }
        }
    }

    func testReviewAndAIStayDeterministicAtAllReleaseScales() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        for count in [100, 1_000, 5_000] {
            let items = ReleaseFixtureFactory.makeItems(count: count)
            let input = InsightComputationInput(items: items, isMember: true, now: now)
            let firstSnapshot = InsightComputationService.weeklyPageSnapshot(input)
            let secondSnapshot = InsightComputationService.weeklyPageSnapshot(input)
            XCTAssertEqual(firstSnapshot.journalText, secondSnapshot.journalText)
            XCTAssertEqual(firstSnapshot.journalClosing, secondSnapshot.journalClosing)
            XCTAssertEqual(firstSnapshot.rhythmText, secondSnapshot.rhythmText)
            XCTAssertEqual(firstSnapshot.keywords, secondSnapshot.keywords)
            XCTAssertEqual(firstSnapshot.reviewOverview, secondSnapshot.reviewOverview)

            let firstDigest = InsightWebView.aiCommandComputationDigestForTesting(
                command: "最近 90 天餐饮花了多少",
                items: items,
                hasMemberAccess: true,
                now: now
            )
            let secondDigest = InsightWebView.aiCommandComputationDigestForTesting(
                command: "最近 90 天餐饮花了多少",
                items: items,
                hasMemberAccess: true,
                now: now
            )
            XCTAssertFalse(firstDigest.isEmpty)
            XCTAssertEqual(firstDigest, secondDigest)
        }
    }
}
#endif
