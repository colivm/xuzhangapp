import Foundation
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import NativeDemoApp

final class OCRDateEvidencePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 27,
            hour: 14,
            minute: 30
        ))!
    }

    func testPaymentAmountCannotBecomeADateWhenTheScreenshotHasNoDateEvidence() {
        let resolved = OCRDateEvidencePolicy.resolvedDate(
            in: "支付成功\nLAWSON\n¥4.20",
            excludingLines: ["¥4.20"],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(resolved, now)
    }

    func testCurrencyAndAmountLabelsAreRejectedAsDateCandidates() {
        XCTAssertNil(OCRDateEvidencePolicy.firstDate(
            in: "￥4.20",
            now: now,
            calendar: calendar
        ))
        XCTAssertNil(OCRDateEvidencePolicy.firstDate(
            in: "支付金额 4.20",
            now: now,
            calendar: calendar
        ))
    }

    func testExplicitAndDateLabeledDatesRemainSupported() throws {
        let chinese = try XCTUnwrap(OCRDateEvidencePolicy.firstDate(
            in: "4月20日",
            now: now,
            calendar: calendar
        ))
        let full = try XCTUnwrap(OCRDateEvidencePolicy.firstDate(
            in: "交易时间 2026-04-21 08:35",
            now: now,
            calendar: calendar
        ))
        let labeledBare = try XCTUnwrap(OCRDateEvidencePolicy.firstDate(
            in: "日期\n4.22",
            now: now,
            calendar: calendar
        ))

        XCTAssertEqual(calendar.component(.month, from: chinese), 4)
        XCTAssertEqual(calendar.component(.day, from: chinese), 20)
        XCTAssertEqual(calendar.component(.day, from: full), 21)
        XCTAssertEqual(calendar.component(.hour, from: full), 8)
        XCTAssertEqual(calendar.component(.day, from: labeledBare), 22)
    }
}

final class SummaryPlaybackSceneLifecyclePolicyTests: XCTestCase {
    func testPlaybackResumesOnlyWhenTheActiveSessionWasInterrupted() {
        XCTAssertTrue(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: true,
                playbackDone: false,
                chapterCount: 5
            )
        )
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: false,
                playbackDone: false,
                chapterCount: 5
            )
        )
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: true,
                playbackDone: true,
                chapterCount: 5
            )
        )
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldResumePlayback(
                wasPlayingBeforeInterruption: true,
                playbackDone: false,
                chapterCount: 0
            )
        )
    }

    func testCoverPrewarmRequiresAnActiveSceneAndAnEnabledGeneration() {
        let active = SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
            isSceneActive: true,
            sceneAllowsCoverWork: true,
            hasSharePayload: true,
            chapterCount: 5,
            playbackDone: true,
            activeIndex: 4,
            showsSharePrivacy: false
        )
        XCTAssertTrue(active)

        for (sceneActive, generationEnabled) in [(false, true), (true, false)] {
            XCTAssertFalse(
                SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
                    isSceneActive: sceneActive,
                    sceneAllowsCoverWork: generationEnabled,
                    hasSharePayload: true,
                    chapterCount: 5,
                    playbackDone: true,
                    activeIndex: 4,
                    showsSharePrivacy: false
                )
            )
        }
    }

    func testCoverPrewarmStaysDeferredBeforeTheLastChapter() {
        XCTAssertFalse(
            SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
                isSceneActive: true,
                sceneAllowsCoverWork: true,
                hasSharePayload: true,
                chapterCount: 5,
                playbackDone: false,
                activeIndex: 2,
                showsSharePrivacy: false
            )
        )
        XCTAssertTrue(
            SummaryPlaybackSceneLifecyclePolicy.shouldPrewarmCover(
                isSceneActive: true,
                sceneAllowsCoverWork: true,
                hasSharePayload: true,
                chapterCount: 5,
                playbackDone: false,
                activeIndex: 2,
                showsSharePrivacy: true
            )
        )
    }
}

final class LifeNarrativeSignalPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func item(
        _ title: String,
        category: HomeItem.Category,
        day: Int,
        userEdited: Bool = false,
        source: HomeItem.Source = .manual,
        userEditedCategory: Bool = false,
        hasPhoto: Bool = false,
        photoRole: PhotoMemoryAssetRole? = nil
    ) -> HomeItem {
        HomeItem(
            title: title,
            amount: 12,
            category: category,
            source: source,
            createdAt: date(day),
            userEditedTitle: userEdited,
            userEditedCategory: userEditedCategory,
            memoryImageData: hasPhoto ? Data([0x01]) : nil,
            memoryAnchorRole: photoRole
        )
    }

    func testStableCoffeeRemainsAMarkWithoutRepeatingAsLead() {
        let rows = [
            item("午后咖啡", category: .dining, day: 20),
            item("一杯拿铁", category: .dining, day: 20),
            item("美式咖啡", category: .dining, day: 21),
            item("咖啡饮品", category: .dining, day: 21),
        ]
        let previous = [
            item("上周午后咖啡", category: .dining, day: 13),
            item("上周拿铁", category: .dining, day: 13),
            item("上周美式", category: .dining, day: 14),
            item("上周咖啡饮品", category: .dining, day: 14),
        ]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 4,
                items: rows,
                previousItems: previous,
                now: date(21),
                recentLeadSignalIDs: ["scene:coffee"]
            )
        )

        XCTAssertNotEqual(plan.leadSignalID, "scene:coffee")
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertTrue(plan.markLabels.contains("咖啡饮品"))
        XCTAssertTrue(plan.summary.contains("4 笔记录"))
        XCTAssertEqual(plan.headline, "本周记录")
    }

    func testCoffeeCanLeadAgainWhenTheCountReallyChanges() {
        let current = [
            item("咖啡 1", category: .dining, day: 20),
            item("咖啡 2", category: .dining, day: 20),
            item("咖啡 3", category: .dining, day: 21),
            item("咖啡 4", category: .dining, day: 21),
        ]
        let previous = [item("上周咖啡", category: .dining, day: 14)]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 5,
                items: current,
                previousItems: previous,
                now: date(21),
                recentLeadSignalIDs: ["scene:coffee"]
            )
        )

        XCTAssertEqual(plan.leadSignalID, "change:coffee:up")
        XCTAssertTrue(plan.headline.contains("多了 3 笔"))
        XCTAssertTrue(plan.summary.contains("4 笔记录"))
        XCTAssertTrue(plan.markLabels.contains("咖啡饮品"))
    }

    func testPhotoBecomesConcreteLeadWhileCoffeeStaysInTheMarkLayer() {
        let rows = [
            item("午后咖啡", category: .dining, day: 20),
            item(
                "红汤馄饨",
                category: .dining,
                day: 21,
                userEdited: true,
                hasPhoto: true,
                photoRole: .moment
            ),
        ]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: rows,
                previousItems: [item("上周咖啡", category: .dining, day: 14)],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.leadSignalID, "photo:\(rows[1].id.uuidString)")
        XCTAssertTrue(plan.headline.contains("红汤馄饨"))
        XCTAssertTrue(plan.markLabels.contains("咖啡饮品"))
    }

    func testAdministrativeBillsStayInEvidenceWithoutBecomingLeadOrMark() {
        let rows = [
            item("手机话费", category: .daily, day: 18),
            item("手机话费充值", category: .daily, day: 19),
            item("下班通勤", category: .transport, day: 20),
        ]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 3,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertFalse(plan.leadSignalID?.contains("telecomBill") == true)
        XCTAssertFalse(plan.markLabels.contains("话费账单"))
        let administrativeEvidence = plan.signalsByRole[.evidence, default: []]
            .filter(\.isAdministrative)
        XCTAssertFalse(administrativeEvidence.isEmpty)
        XCTAssertTrue(administrativeEvidence.allSatisfy { $0.narrativeValue < 55 })
    }

    func testAdministrativeChangeRemainsANeutralDataObservation() {
        let current = [
            item("手机话费", category: .daily, day: 18),
            item("电费缴费", category: .home, day: 19),
            item("停车费", category: .transport, day: 20),
        ]
        let previous = [item("上周手机话费", category: .daily, day: 10)]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 4,
                items: current,
                previousItems: previous,
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertNil(plan.leadSignalID)
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertFalse(plan.headline.contains("明显变化"))
        let observation = plan.signalsByRole[.evidence, default: []].first {
            $0.id == "administrative:change:up"
        }
        XCTAssertEqual(observation?.kind, .change)
        XCTAssertEqual(observation?.isAdministrative, true)
        XCTAssertLessThan(observation?.narrativeValue ?? Int.max, 55)
    }

    func testReceiptPhotoCannotBecomeAStoryLead() {
        let receipt = item(
            "超市小票",
            category: .daily,
            day: 21,
            hasPhoto: true,
            photoRole: .receipt
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 1,
                items: [receipt],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertFalse(plan.leadSignalID?.hasPrefix("photo:") == true)
        XCTAssertFalse(plan.signalsByRole[.lead, default: []].contains { $0.kind == .photo })
    }

    func testQualifiedMomentPhotoCanBecomeAConcreteLead() {
        let moment = item(
            "红汤馄饨",
            category: .dining,
            day: 21,
            hasPhoto: true,
            photoRole: .moment
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 1,
                items: [moment],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.leadSignalID, "photo:\(moment.id.uuidString)")
        XCTAssertTrue(plan.headline.contains("红汤馄饨"))
        XCTAssertTrue(plan.headline.contains("还留着一张照片"))
        XCTAssertTrue(plan.summary.contains("只记下一笔"))
    }

    func testPhotoWithoutAQualifiedRoleStaysOutOfTheLead() {
        let attachment = item(
            "普通附件",
            category: .other,
            day: 21,
            hasPhoto: true
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 1,
                items: [attachment],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertFalse(plan.leadSignalID?.hasPrefix("photo:") == true)
        XCTAssertEqual(plan.maturity, .factual)
    }

    func testEditedTitleMetadataDoesNotBecomeAVisibleNarrativeCount() {
        let rows = [
            item("上班通勤", category: .transport, day: 20, userEdited: true),
            item("巧婆红汤馄饨", category: .dining, day: 21, userEdited: true),
        ]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertNil(plan.leadSignalID)
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertEqual(plan.headline, "本周记录")
        XCTAssertFalse("\(plan.headline) \(plan.summary)".contains("主动记录"))
        XCTAssertFalse("\(plan.headline) \(plan.summary)".contains("用户主动写下"))
    }

    func testImportedTitlesCannotBecomeUserExpressionLeads() {
        let rows = [
            item(
                "终于到家",
                category: .transport,
                day: 20,
                userEdited: true,
                source: .ocr
            ),
            item(
                "终于回家",
                category: .transport,
                day: 21,
                userEdited: true,
                userEditedCategory: true
            ),
        ]
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 21,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertNil(plan.leadSignalID)
        XCTAssertFalse(plan.hasNarrativeLead)
        XCTAssertEqual(plan.headline, "本周记录")
    }

    func testSpecificUserExpressionCanLeadWithoutTurningIntoMetadataCopy() {
        let expression = item("终于到家", category: .transport, day: 21, userEdited: true)
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 3,
                items: [item("普通餐饮", category: .dining, day: 20), expression],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.leadSignalID, "user:\(expression.id.uuidString)")
        XCTAssertTrue(plan.headline.contains("终于到家"))
        XCTAssertTrue(plan.summary.contains("2 笔记录"))
        XCTAssertFalse("\(plan.headline) \(plan.summary)".contains("主动记录"))
    }

    func testNestedWeekAndMonthUseTheSameUniqueExpressionEvidence() {
        let expression = item("终于到家", category: .transport, day: 21, userEdited: true)
        let monthRows = [
            item("月初日用", category: .daily, day: 2),
            expression,
        ]
        let weekPlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 4,
                items: [expression],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )
        let monthPlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .month,
                sourceRevision: 4,
                items: monthRows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(weekPlan.leadSignalID, monthPlan.leadSignalID)
        XCTAssertEqual(weekPlan.signalsByRole[.lead]?.first?.evidenceItemIDs, [expression.id])
        XCTAssertEqual(monthPlan.signalsByRole[.lead]?.first?.evidenceItemIDs, [expression.id])
    }

    func testWeekLifeCardClueAndPlaybackShareTheSameLeadIdentity() {
        let previous = [
            item("上周咖啡 1", category: .dining, day: 13),
            item("上周咖啡 2", category: .dining, day: 14),
        ]
        let current = [
            item("本周咖啡", category: .dining, day: 20),
            item(
                "红汤馄饨",
                category: .dining,
                day: 21,
                hasPhoto: true,
                photoRole: .moment
            ),
        ]
        let allItems = previous + current
        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: current,
                allItems: allItems,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 42,
                now: date(21)
            )
        )
        let clue = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: current,
                allItems: allItems,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 42,
                narrativeScope: .week,
                allowsNarrativeRewrite: true,
                now: date(21)
            )
        )
        let playbackPlan = PlaybackService().buildWeeklyShareCardPayload(
            from: allItems,
            now: date(21),
            sourceRevision: 42
        )?.narrativePlan

        XCTAssertEqual(chapter.narrativePlan.leadSignalID, clue.narrativePlan?.leadSignalID)
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, playbackPlan?.leadSignalID)
        XCTAssertEqual(chapter.narrativePlan.sourceRevision, 42)
        XCTAssertTrue(chapter.narrativePlan.markLabels.contains("咖啡饮品"))
        XCTAssertTrue(clue.narrativePlan?.markLabels.contains("咖啡饮品") == true)
    }

    func testNarrativePhotoLeadIsAlsoThePrimaryVisibleAnchor() {
        let earlier = HomeItem(
            title: "月初聚餐",
            amount: 80,
            category: .dining,
            createdAt: date(2),
            memoryImageData: Data([0x01]),
            memoryAnchorRole: .moment,
            memoryAnchorSceneHint: .gathering
        )
        let later = HomeItem(
            title: "红汤馄饨",
            amount: 20,
            category: .dining,
            createdAt: date(21),
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .moment,
            memoryAnchorSceneHint: .experience
        )
        let snapshot = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .month,
                items: [earlier, later],
                allItems: [earlier, later],
                isMember: true,
                prioritizeRecurringMarks: true,
                periodKey: "2026-07",
                usesEchoAnchor: false,
                sourceRevision: 43,
                now: date(21)
            )
        )

        XCTAssertEqual(snapshot.narrativePlan.leadSignalID, "photo:\(later.id.uuidString)")
        XCTAssertEqual(snapshot.memoryAnchors.first?.itemID, later.id)
        XCTAssertEqual(snapshot.coverFacts.coverItemID, later.id)
    }

    func testWeekClueKeepsAdministrativeBillsOutOfTheLifeMarkList() {
        let rows = [
            item("手机话费", category: .daily, day: 18),
            item("电费缴费", category: .home, day: 19),
            item("上午咖啡", category: .dining, day: 20),
            item("下午拿铁", category: .dining, day: 21),
        ]
        let snapshot = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: rows,
                allItems: rows,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 5,
                narrativeScope: .week,
                allowsNarrativeRewrite: false,
                now: date(21)
            )
        )

        XCTAssertTrue(snapshot.narrativePlan?.markLabels.contains("咖啡饮品") == true)
        XCTAssertFalse(snapshot.marks.contains { mark in
            let evidence = rows.filter { mark.itemIDs.contains($0.id) }
            return !evidence.isEmpty && evidence.allSatisfy {
                LifeNarrativeSignalPolicy.isAdministrativeRecord($0)
            }
        })
    }

    func testTraceSurfacesConsumeCachedRewriteWithoutChangingTheSelectedFacts() {
        LifeNarrativeAIRewriteStore.shared.removeAllForTesting()
        defer { LifeNarrativeAIRewriteStore.shared.removeAllForTesting() }

        let rows = [
            item("一杯咖啡", category: .dining, day: 20),
            item(
                "红汤馄饨",
                category: .dining,
                day: 21,
                hasPhoto: true,
                photoRole: .moment
            ),
        ]
        let key = LifeNarrativeAIPreparationPolicy.key(
            scope: .week,
            sourceRevision: 77,
            now: date(21),
            calendar: PlaybackService.isoCalendar
        )
        let rewrite = LifeNarrativeAIRewrite(
            key: key,
            headline: "这周先说一件具体的事",
            summary: "7月21日那笔记录，还留着一张照片。",
            supportingLine: nil,
            evidenceIDs: ["F1"],
            evidenceItemIDs: [rows[1].id]
        )
        LifeNarrativeAIRewriteStore.shared.publish([rewrite], expectedSourceRevision: 77)

        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: rows,
                allItems: rows,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 77,
                now: date(21)
            )
        )
        let snapshot = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: rows,
                allItems: rows,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 77,
                narrativeScope: .week,
                allowsNarrativeRewrite: true,
                now: date(21)
            )
        )

        XCTAssertEqual(chapter.narrativeRewrite, rewrite)
        XCTAssertEqual(chapter.narrative, rewrite.headline)
        XCTAssertEqual(chapter.chapterSummary, rewrite.summary)
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, "photo:\(rows[1].id.uuidString)")
        XCTAssertEqual(snapshot.narrativeRewrite, rewrite)
        XCTAssertEqual(snapshot.narrativeHeadline, snapshot.insight.leadQuestion)
        XCTAssertEqual(snapshot.narrativeSummary, snapshot.insight.previewLine)
        XCTAssertNotEqual(snapshot.narrativeHeadline, rewrite.headline)
        XCTAssertNotEqual(snapshot.narrativeSummary, rewrite.summary)
        XCTAssertTrue(snapshot.insight.fullLines.contains { $0.contains("直接依据") })
        XCTAssertEqual(snapshot.narrativePlan?.leadSignalID, "photo:\(rows[1].id.uuidString)")
        XCTAssertEqual(snapshot.narrativeRewrite?.evidenceItemIDs, [rows[1].id])

        let newerRevision = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: rows,
                allItems: rows,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 78,
                now: date(21)
            )
        )
        XCTAssertNil(newerRevision.narrativeRewrite)
        XCTAssertNotEqual(newerRevision.narrative, rewrite.headline)
    }

    func testSensitiveRecordNeverBecomesNarrativeLeadOrMark() {
        let rows = [
            item("医院复诊", category: .health, day: 20, userEdited: true, hasPhoto: true),
            item("下班通勤", category: .transport, day: 21),
        ]

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: rows,
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        let published = plan.signalsByRole.values.flatMap { $0 }
        XCTAssertFalse(published.flatMap(\.evidenceItemIDs).contains(rows[0].id))
        XCTAssertFalse(plan.summary.contains("医院"))
    }

    func testSensitiveRecordCannotLeakThroughAMixedSceneEvidenceGroup() {
        let safe = item("午后咖啡", category: .dining, day: 20)
        let privateRow = item("医院旁买咖啡", category: .dining, day: 21, userEdited: true, hasPhoto: true)

        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 2,
                items: [safe, privateRow],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        let publishedEvidenceIDs = plan.signalsByRole.values
            .flatMap { $0 }
            .flatMap(\.evidenceItemIDs)
        XCTAssertTrue(publishedEvidenceIDs.contains(safe.id))
        XCTAssertFalse(publishedEvidenceIDs.contains(privateRow.id))
        XCTAssertFalse(plan.summary.contains("医院"))
    }

    func testOnlySensitiveRecordsUsePrivateFallbackWithoutPublishingEvidence() {
        let privateRow = item("医院复诊", category: .health, day: 21, userEdited: true, hasPhoto: true)
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .day,
                sourceRevision: 1,
                items: [privateRow],
                previousItems: [],
                now: date(21),
                recentLeadSignalIDs: []
            )
        )

        XCTAssertEqual(plan.maturity, .factual)
        XCTAssertNil(plan.leadSignalID)
        XCTAssertTrue(plan.signalsByRole.isEmpty)
        XCTAssertFalse(plan.summary.contains("医院"))
    }

    func testMaturitySeparatesWeakFactsFromContextAndEchoQualification() {
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 0, activeDays: 0, hasPhoto: false), .empty)
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 2, activeDays: 2, hasPhoto: false), .factual)
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 2, activeDays: 2, hasPhoto: true), .contextual)
        XCTAssertEqual(LifeNarrativeSignalPolicy.maturity(recordCount: 5, activeDays: 3, hasPhoto: false), .echoEligible)
    }

    func testWeeklySharePayloadPreparesNarrativeOnceAndCoolsRepeatedCoffeeLead() {
        let previous = [
            item("上周咖啡 1", category: .dining, day: 13),
            item("上周咖啡 2", category: .dining, day: 14),
        ]
        let current = [
            item("本周咖啡 1", category: .dining, day: 20),
            item("本周咖啡 2", category: .dining, day: 21),
        ]

        let payload = PlaybackService().buildWeeklyShareCardPayload(
            from: previous + current,
            now: date(21),
            sourceRevision: 42
        )

        XCTAssertEqual(payload?.narrativePlan?.sourceRevision, 42)
        XCTAssertNotEqual(payload?.narrativePlan?.leadSignalID, "scene:coffee")
        XCTAssertTrue(payload?.narrativePlan?.markLabels.contains("咖啡饮品") == true)
    }
}

final class LifeNarrativeEchoPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 12, month: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func item(
        _ title: String,
        category: HomeItem.Category,
        month: Int = 7,
        day: Int,
        hour: Int = 12
    ) -> HomeItem {
        HomeItem(title: title, amount: 12, category: category, createdAt: date(day, hour, month: month))
    }

    func testContinuousCoffeeAloneDoesNotCreateAWeeklyEcho() {
        let rows = [6, 7, 13, 14, 20, 21].map {
            item("咖啡", category: .dining, day: $0, hour: 14)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 1,
                items: rows,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertNil(echo)
    }

    func testCoffeeCanCreateAnEchoForAComparableRealChange() {
        let previous = [13, 14].map { item("咖啡", category: .dining, day: $0, hour: 14) }
        let current = [20, 20, 21, 21].enumerated().map { index, day in
            item("咖啡 \(index)", category: .dining, day: day, hour: 9 + index)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 9,
                items: previous + current,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .comparableChange)
        XCTAssertEqual(echo?.currentCount, 4)
        XCTAssertEqual(echo?.baselineCount, 2)
        XCTAssertTrue(echo?.line.contains("多了 2 笔") == true)
    }

    func testReturnRequiresARealGapAndCanBeCooledByStableEchoID() {
        let historical = [6, 7].map { item("看电影", category: .entertainment, day: $0, hour: 19) }
        let current = [20, 21].map { item("看电影", category: .entertainment, day: $0, hour: 19) }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 4,
                items: historical + current,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .returnAfterGap)
        XCTAssertEqual(echo?.periodGap, 1)
        XCTAssertTrue(echo?.line.contains("再次出现") == true)

        let cooled = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 4,
                items: historical + current,
                now: date(21, 20),
                recentEchoIDs: [echo?.id ?? ""]
            ),
            calendar: calendar
        )
        XCTAssertNil(cooled)
    }

    func testRepeatRhythmNeedsThreeMatchingWeekdaysAndRejectsOldRevision() {
        let rows = [
            item("上班地铁", category: .transport, day: 6, hour: 8),
            item("上班地铁", category: .transport, day: 13, hour: 8),
            item("上班地铁", category: .transport, day: 20, hour: 8),
            item("下班地铁", category: .transport, day: 21, hour: 18),
        ]
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 18,
                items: rows,
                now: date(21, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .repeatRhythm)
        XCTAssertTrue(echo?.line.contains("周一") == true)
        XCTAssertTrue(LifeNarrativeEchoPublicationPolicy.accepts(echo, expectedSourceRevision: 18))
        XCTAssertFalse(LifeNarrativeEchoPublicationPolicy.accepts(echo, expectedSourceRevision: 19))
    }

    func testMonthChangeUsesTheSameElapsedMonthDays() {
        let current = [2, 4, 6].map { item("买相机配件", category: .shopping, day: $0) }
        var previous = [item("买相机配件", category: .shopping, month: 6, day: 3)]
        previous += [20, 21, 22, 23].map {
            item("买相机配件", category: .shopping, month: 6, day: $0)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .month,
                sourceRevision: 6,
                items: previous + current,
                now: date(10, 20),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .comparableChange)
        XCTAssertEqual(echo?.currentCount, 3)
        XCTAssertEqual(echo?.baselineCount, 1)
    }

    func testEchoPublishesOnlyOneDeterministicCandidateAndExcludesSensitiveEvidence() {
        let previous = [
            item("咖啡", category: .dining, day: 13),
            item("咖啡", category: .dining, day: 14),
            item("上班地铁", category: .transport, day: 13, hour: 8),
            item("下班地铁", category: .transport, day: 14, hour: 18),
        ]
        let currentCoffee = [20, 20, 21, 21].enumerated().map { index, day in
            item("咖啡 \(index)", category: .dining, day: day, hour: 9 + index)
        }
        let currentCommute = [20, 20, 21, 21].enumerated().map { index, day in
            item(index.isMultiple(of: 2) ? "上班地铁" : "下班地铁", category: .transport, day: day, hour: 8 + index)
        }
        let sensitive = item("医院旁买咖啡", category: .dining, day: 21, hour: 16)
        let input = LifeNarrativeEchoInput(
            scope: .week,
            sourceRevision: 30,
            items: previous + currentCoffee + currentCommute + [sensitive],
            now: date(21, 20),
            recentEchoIDs: []
        )

        let first = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)
        let second = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertNotNil(first)
        XCTAssertFalse(first?.currentEvidenceItemIDs.contains(sensitive.id) == true)
        XCTAssertFalse(first?.historicalEvidenceItemIDs.contains(sensitive.id) == true)
    }

    func testLateCommuteReturnsOnlyWithTwoCurrentAndHistoricalDays() {
        let historical = [1, 2].map {
            item("下班地铁", category: .transport, day: $0, hour: 22)
        }
        let current = [20, 21].map {
            item("晚高峰通勤", category: .transport, day: $0, hour: 22)
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 51,
                items: historical + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .contextReturn)
        XCTAssertEqual(echo?.periodGap, 3)
        XCTAssertEqual(echo?.currentDistinctDayCount, 2)
        XCTAssertEqual(echo?.historicalDistinctDayCount, 2)
        XCTAssertTrue(echo?.line.contains("重新出现") == true)
        XCTAssertTrue(echo?.line.contains("3 周前") == true)
    }

    func testLateCommuteReturnAbstainsWhenEitherSideHasOnlyOneDay() {
        let historicalTwoDays = [1, 2].map {
            item("下班地铁", category: .transport, day: $0, hour: 22)
        }
        let currentOneDay = [
            item("晚高峰通勤", category: .transport, day: 20, hour: 22),
            item("普通午餐", category: .dining, day: 21, hour: 12),
        ]
        let currentSparse = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 52,
                items: historicalTwoDays + currentOneDay,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(currentSparse?.kind, .contextReturn)

        let historicalOneDay = [item("下班地铁", category: .transport, day: 1, hour: 22)]
        let currentTwoDays = [20, 21].map {
            item("晚高峰通勤", category: .transport, day: $0, hour: 22)
        }
        let historySparse = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 53,
                items: historicalOneDay + currentTwoDays,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(historySparse?.kind, .contextReturn)
    }

    func testParkingAndTravelDoNotBecomeLateCommuteContext() {
        let historical = [1, 2].flatMap { day in
            [
                item("停车费", category: .transport, day: day, hour: 22),
                item("机场打车", category: .transport, day: day, hour: 23),
            ]
        }
        let current = [20, 21].flatMap { day in
            [
                item("停车费", category: .transport, day: day, hour: 22),
                item("旅行返程打车", category: .transport, day: day, hour: 23),
            ]
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 54,
                items: historical + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertNotEqual(echo?.kind, .contextReturn)
        XCTAssertFalse(echo?.label.contains("晚间通勤") == true)
    }

    func testNewCoffeeLateCommutePairNeedsTwoDaysAndFourActiveHistoryWeeks() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [20, 21].flatMap { day in
            [
                item("下班通勤", category: .transport, day: day, hour: 22),
                item("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 55,
                items: baseline + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .newContextPair)
        XCTAssertEqual(echo?.currentDistinctDayCount, 2)
        XCTAssertEqual(echo?.baselinePeriodCount, 4)
        XCTAssertTrue(echo?.line.contains("晚间通勤之后") == true)
        XCTAssertTrue(echo?.line.contains("近 4 个有记录的周里") == true)
    }

    func testNewPairAbstainsForOneDayOrWhenHistoryAlreadyContainsThePair() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let oneDayPair = [
            item("下班通勤", category: .transport, day: 20, hour: 22),
            item("夜间咖啡", category: .dining, day: 20, hour: 23),
            item("普通午餐", category: .dining, day: 21, hour: 12),
        ]
        let sparse = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 56,
                items: baseline + oneDayPair,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(sparse?.kind, .newContextPair)

        let historicalPair = [
            item("下班通勤", category: .transport, day: 13, hour: 22),
            item("夜间咖啡", category: .dining, day: 13, hour: 23),
        ]
        let currentTwoDays = [20, 21].flatMap { day in
            [
                item("下班通勤", category: .transport, day: day, hour: 22),
                item("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        let repeated = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 57,
                items: baseline + historicalPair + currentTwoDays,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        XCTAssertNotEqual(repeated?.kind, .newContextPair)
        XCTAssertFalse(repeated?.line.contains("首次") == true)
    }

    func testMixedPairOrderNeverClaimsAfter() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [
            item("下班通勤", category: .transport, day: 20, hour: 22),
            item("夜间咖啡", category: .dining, day: 20, hour: 23),
            item("夜间咖啡", category: .dining, day: 21, hour: 21),
            item("下班通勤", category: .transport, day: 21, hour: 22),
        ]
        let echo = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: 58,
                items: baseline + current,
                now: date(21, 23),
                recentEchoIDs: []
            ),
            calendar: calendar
        )

        XCTAssertEqual(echo?.kind, .newContextPair)
        XCTAssertTrue(echo?.line.contains("一起出现") == true)
        XCTAssertFalse(echo?.line.contains("之后") == true)
    }

    func testRelationshipIdentityIsSharedByLifeCardClueAndShareProjection() {
        let baseline = [22, 29].map {
            item("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            item("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [20, 21].flatMap { day in
            [
                item("下班通勤", category: .transport, day: day, hour: 22),
                item("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        let allItems = baseline + current
        let chapter = TraceSnapshotComputation.buildChapter(
            TraceChapterComputationInput(
                range: .week,
                items: current,
                allItems: allItems,
                isMember: true,
                prioritizeRecurringMarks: false,
                periodKey: "2026-W30",
                usesEchoAnchor: false,
                sourceRevision: 59,
                now: date(21, 23)
            )
        )
        let clue = TraceSnapshotComputation.buildClue(
            TraceClueComputationInput(
                items: current,
                allItems: allItems,
                period: .week,
                periodLabel: "这一周",
                isMember: true,
                freeRemaining: 5,
                storedUnlock: true,
                sourceRevision: 59,
                narrativeScope: .week,
                allowsNarrativeRewrite: false,
                now: date(21, 23)
            )
        )
        let sharePlan = PlaybackService().buildWeeklyShareCardPayload(
            from: allItems,
            now: date(21, 23),
            sourceRevision: 59
        )?.narrativePlan

        XCTAssertEqual(chapter.narrativePlan.leadSignalID, clue.narrativePlan?.leadSignalID)
        XCTAssertEqual(chapter.narrativePlan.leadSignalID, sharePlan?.leadSignalID)
        XCTAssertTrue(chapter.narrativePlan.leadSignalID?.contains(":new-pair:") == true)
        XCTAssertTrue(chapter.narrativePlan.hasNarrativeLead)
        XCTAssertTrue(chapter.narrativePlan.markLabels.contains("咖啡饮品"))
        XCTAssertTrue(chapter.chapterSummary?.contains("近 4 个有记录的周里") == true)
        XCTAssertTrue(clue.insight.fullLines.contains { $0.contains("历史基线覆盖 4 个有记录的周") })
    }
}

final class LifeNarrativeAIRewritePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 20))!
    }

    private func preparedWeekPack(sourceRevision: Int = 12) -> PreparedLifeNarrativeAIFactPack {
        let rows = [
            HomeItem(
                title: "和小王吃了红汤馄饨",
                amount: 28,
                category: .dining,
                createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 18))!,
                userEditedTitle: true,
                memoryImageData: Data([0x01]),
                memoryAnchorRole: .moment
            ),
            HomeItem(
                title: "下班地铁",
                amount: 4,
                category: .transport,
                createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 18))!
            ),
            HomeItem(
                title: "医院复诊",
                amount: 120,
                category: .health,
                createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 10))!,
                userEditedTitle: true,
                memoryImageData: Data([0x02])
            ),
        ]
        return LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: rows,
            sourceRevision: sourceRevision,
            now: now,
            calendar: calendar
        ).first { $0.key.scope == LifeNarrativeScope.week.rawValue }!
    }

    private func preparedRelationshipPack(sourceRevision: Int = 72) -> PreparedLifeNarrativeAIFactPack {
        func row(_ title: String, category: HomeItem.Category, month: Int = 7, day: Int, hour: Int) -> HomeItem {
            HomeItem(
                title: title,
                amount: 12,
                category: category,
                createdAt: calendar.date(
                    from: DateComponents(year: 2026, month: month, day: day, hour: hour)
                )!
            )
        }
        let baseline = [22, 29].map {
            row("普通午餐", category: .dining, month: 6, day: $0, hour: 12)
        } + [6, 13].map {
            row("普通午餐", category: .dining, day: $0, hour: 12)
        }
        let current = [20, 21].flatMap { day in
            [
                row("下班通勤", category: .transport, day: day, hour: 22),
                row("夜间咖啡", category: .dining, day: day, hour: 23),
            ]
        }
        return LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: baseline + current,
            sourceRevision: sourceRevision,
            now: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 23))!,
            calendar: calendar
        ).first { $0.key.scope == LifeNarrativeScope.week.rawValue }!
    }

    func testFactPackRedactsUserTextSensitiveRowsPhotosAndLedgerIDs() throws {
        let pack = preparedWeekPack()
        let data = try JSONEncoder().encode(pack.request)
        let text = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(text.contains("用户自写记录"))
        XCTAssertFalse(text.contains("主动记录"))
        XCTAssertFalse(text.contains("用户主动写下"))
        XCTAssertTrue(text.contains("有真实照片的记录"))
        XCTAssertFalse(text.contains("小王"))
        XCTAssertFalse(text.contains("红汤馄饨"))
        XCTAssertFalse(text.contains("医院"))
        XCTAssertFalse(text.contains("memoryImage"))
        XCTAssertFalse(pack.itemIDsByFactID.values.flatMap { $0 }.contains { text.contains($0.uuidString) })
    }

    func testUserExpressionLeadStaysLocalInsteadOfBecomingAnAICountFact() {
        let expression = HomeItem(
            title: "终于到家",
            amount: 4,
            category: .transport,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 19))!,
            userEditedTitle: true
        )
        let packs = LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: [expression],
            sourceRevision: 18,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.week.rawValue })
        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.month.rawValue })
    }

    func testWeakCompositionAndRhythmDoNotStartRemoteNarrativeRewrite() {
        let rows = [
            HomeItem(title: "普通午餐", amount: 18, category: .dining, createdAt: now),
            HomeItem(
                title: "普通日用",
                amount: 12,
                category: .daily,
                createdAt: calendar.date(byAdding: .hour, value: -2, to: now)!
            ),
        ]
        let packs = LifeNarrativeAIPreparationPolicy.prepareFactPacks(
            items: rows,
            sourceRevision: 70,
            now: now,
            calendar: calendar
        )

        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.week.rawValue })
        XCTAssertNil(packs.first { $0.key.scope == LifeNarrativeScope.month.rawValue })
    }

    func testRelationshipFactPackUsesCertifiedModeAndKeepsBoundedClaims() {
        let pack = preparedRelationshipPack()
        XCTAssertEqual(pack.request.mode, "relationship")
        XCTAssertEqual(pack.request.facts.first?.role, "lead")
        XCTAssertEqual(pack.request.facts.first?.kind, LifeNarrativeEchoKind.newContextPair.rawValue)
        XCTAssertEqual(pack.localPlan.leadSignalID, pack.echo?.id)

        let valid = LifeNarrativeAIRewriteCandidate(
            scope: pack.key.scope,
            periodKey: pack.key.periodKey,
            headline: "这周有一组新关联",
            summary: "咖啡连续 2 天出现在晚间通勤之后，是近 4 个有记录周里的首次。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNotNil(LifeNarrativeAIRewriteValidationPolicy.validate(valid, against: pack))

        let unbounded = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "咖啡连续 2 天出现在晚间通勤之后，这是第一次。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(unbounded, against: pack))

        let inventedReturn = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "咖啡和晚间通勤重新出现，是近 4 个有记录周里的首次。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(inventedReturn, against: pack))
    }

    func testRewriteValidationRequiresLeadEvidenceAndRejectsNewFacts() {
        let pack = preparedWeekPack()
        let valid = LifeNarrativeAIRewriteCandidate(
            scope: pack.key.scope,
            periodKey: pack.key.periodKey,
            headline: "这周有一句自己的记录",
            summary: "一条具体记录和一段出行，按发生顺序放在这里。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNotNil(LifeNarrativeAIRewriteValidationPolicy.validate(valid, against: pack))

        let unknownEvidence = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: valid.summary,
            supportingLine: nil,
            evidenceIDs: ["F9"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(unknownEvidence, against: pack))

        let inventedNumber = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "这周突然多了 99 笔新故事。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(inventedNumber, against: pack))

        let inferredEmotion = LifeNarrativeAIRewriteCandidate(
            scope: valid.scope,
            periodKey: valid.periodKey,
            headline: valid.headline,
            summary: "这些记录终于治愈了这一周。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        XCTAssertNil(LifeNarrativeAIRewriteValidationPolicy.validate(inferredEmotion, against: pack))
    }

    func testRewriteStoreRejectsOldRevisionAndPublishesCurrentResult() {
        let pack = preparedWeekPack(sourceRevision: 20)
        let candidate = LifeNarrativeAIRewriteCandidate(
            scope: pack.key.scope,
            periodKey: pack.key.periodKey,
            headline: "这周有一句自己的记录",
            summary: "一条具体记录和一段出行，按发生顺序放在这里。",
            supportingLine: nil,
            evidenceIDs: ["F1"]
        )
        let rewrite = LifeNarrativeAIRewriteValidationPolicy.validate(candidate, against: pack)!
        let store = LifeNarrativeAIRewriteStore.shared
        store.removeAllForTesting()
        defer { store.removeAllForTesting() }

        store.publish([rewrite], expectedSourceRevision: 19)
        XCTAssertNil(store.rewrite(for: pack.key))
        store.publish([rewrite], expectedSourceRevision: 20)
        XCTAssertEqual(store.rewrite(for: pack.key), rewrite)
        store.removeAll()
        XCTAssertNil(store.rewrite(for: pack.key))
    }
}

final class PlaybackLivingVoiceCopyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private func date(
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12,
        _ minute: Int = 0,
        year: Int = 2026
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func item(
        _ title: String,
        amount: Double,
        category: HomeItem.Category,
        at createdAt: Date,
        emotion: String = "系统暖标签",
        memoryContext: HomeItem.MemoryContext? = nil
    ) -> HomeItem {
        HomeItem(
            title: title,
            amount: amount,
            category: category,
            createdAt: createdAt,
            emotionTag: emotion,
            userEditedTitle: true,
            memoryContext: memoryContext
        )
    }

    private func allNarration(_ playback: SummaryPlayback) -> String {
        playback.chapters
            .flatMap { [$0.narration.warm, $0.narration.plain] }
            .joined(separator: "\n")
    }

    func testWeekKeepsZeroOneTwoAndMatureChapterCounts() {
        let now = date(7, 15, 20)
        let service = PlaybackService()
        let first = item(
            "下班地铁",
            amount: 4.75,
            category: .transport,
            at: date(7, 14, 19, 20),
            emotion: "热天路上辛苦了"
        )
        let second = item("早餐", amount: 12, category: .dining, at: date(7, 15, 8, 10))
        let third = item("午饭", amount: 28, category: .dining, at: date(7, 15, 12, 20))

        XCTAssertEqual(service.buildWeekSummary(from: [], now: now).chapters.count, 0)
        XCTAssertEqual(service.buildWeekSummary(from: [first], now: now).chapters.count, 3)
        XCTAssertEqual(service.buildWeekSummary(from: [first, second], now: now).chapters.count, 3)
        XCTAssertEqual(service.buildWeekSummary(from: [first, second, third], now: now).chapters.count, 5)

        let weak = service.buildWeekSummary(from: [first], now: now)
        XCTAssertEqual(weak.chapters.map(\.title), ["这一周", "这一笔", "这周先到这里"])
        XCTAssertTrue(weak.chapters[0].narration.plain.contains("1 笔"))
        XCTAssertTrue(weak.chapters[1].narration.plain.contains("下班地铁"))
        XCTAssertTrue(weak.chapters[1].metrics["supportLine", default: ""].contains("4.75"))
        XCTAssertFalse(allNarration(weak).contains("热天路上辛苦了"))
    }

    func testMatureWeekSeparatesDistributionRecordAndReliableRepeat() {
        let now = date(7, 16, 20)
        let rows = [
            item("上班地铁", amount: 4, category: .transport, at: date(7, 13, 8, 20)),
            item("下班地铁", amount: 4, category: .transport, at: date(7, 13, 18, 40)),
            item("早餐", amount: 10, category: .dining, at: date(7, 14, 8, 0)),
            item("午饭", amount: 26, category: .dining, at: date(7, 14, 12, 10)),
            item("买纸巾", amount: 18, category: .daily, at: date(7, 16, 19, 0))
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        XCTAssertEqual(summary.chapters.count, 5)
        XCTAssertEqual(summary.chapters[0].title, "这一周")
        XCTAssertEqual(summary.chapters[1].title, "记录较多的日子")
        XCTAssertEqual(summary.chapters[2].title, "这一笔")
        XCTAssertEqual(summary.chapters[3].title, "这周反复出现")
        XCTAssertEqual(summary.chapters[4].title, "这周先到这里")
        XCTAssertTrue(summary.chapters[0].narration.plain.contains("5 笔"))
        XCTAssertTrue(summary.chapters[1].narration.plain.contains("各记了 2 笔"))
        XCTAssertTrue(summary.chapters[3].narration.plain.contains("各出现了 2 次"))
        XCTAssertEqual(summary.chapters.map(\.durationSec), [6, 7, 7, 7, 7])
    }

    func testPlaybackNarrationDoesNotExposeAbstractOrInternalCopy() {
        let now = date(7, 18, 20)
        let rows = [
            item("晚高峰通勤", amount: 4, category: .transport, at: date(7, 13, 18), emotion: "公共交通一段"),
            item("一杯咖啡", amount: 16, category: .dining, at: date(7, 15, 14), emotion: "咖啡饮品第 30 次"),
            item("停车费", amount: 8, category: .transport, at: date(7, 18, 9), emotion: "车停稳了")
        ]
        let copy = allNarration(PlaybackService().buildWeekSummary(from: rows, now: now))
        let blocked = [
            "胶片", "气味", "有画面", "生活的开头", "这次它又回来了",
            "公共交通一段", "咖啡饮品第 30 次", "车停稳了", "小獭看到"
        ]

        for term in blocked {
            XCTAssertFalse(copy.contains(term), "unexpected playback copy: \(term)")
        }
        XCTAssertFalse(copy.contains("{"))
        XCTAssertFalse(copy.contains("}"))
    }

    func testPlaybackRestoresHighConfidenceAuxiliarySignalsWithoutPuttingThemBackIntoNarration() {
        let now = date(7, 16, 20)
        let rows = [
            item(
                "下班地铁",
                amount: 4.75,
                category: .transport,
                at: date(7, 13, 18, 40),
                emotion: "热天路上辛苦了",
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: "hot",
                    temperatureCelsius: 36,
                    cityName: nil,
                    semanticPlace: nil
                )
            ),
            item("一杯咖啡", amount: 16, category: .dining, at: date(7, 14, 14)),
            item("下午拿铁", amount: 18, category: .dining, at: date(7, 16, 15))
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        let openingSignals = LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0])

        XCTAssertEqual(
            openingSignals.map(\.label),
            ["生活线索 · 咖啡饮品", "情绪标签 · 热天路上辛苦了"]
        )
        XCTAssertTrue(summary.chapters.dropFirst().allSatisfy {
            LifeStorySignalService.playbackAuxiliarySignals(from: $0).isEmpty
        })
        XCTAssertFalse(allNarration(summary).contains("咖啡饮品"))
        XCTAssertFalse(allNarration(summary).contains("热天路上辛苦了"))
    }

    func testRepeatedCoffeeStaysInTheWeeklyRepeatLayerWithoutTakingOpeningOrClosing() {
        let now = date(7, 16, 20)
        let previous = [6, 7, 8].map { day in
            HomeItem(title: "咖啡", amount: 16, category: .dining, createdAt: date(7, day, 14))
        }
        let current = [13, 14, 15].map { day in
            HomeItem(title: "咖啡", amount: 16, category: .dining, createdAt: date(7, day, 14))
        }

        let summary = PlaybackService().buildWeekSummary(from: previous + current, now: now)
        let openingAndClosing = [summary.chapters.first, summary.chapters.last]
            .compactMap { $0 }
            .flatMap { [$0.narration.plain, $0.narration.warm] }
            .joined(separator: "\n")

        XCTAssertFalse(openingAndClosing.contains("咖啡"))
        XCTAssertEqual(
            LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0]).map(\.label),
            ["生活线索 · 咖啡饮品"]
        )
        XCTAssertEqual(summary.chapters.map(\.durationSec), [6, 7, 7, 7, 7])
    }

    func testPlaybackAuxiliarySignalsRejectWeakAndSensitiveLabels() {
        let now = date(7, 16, 20)
        let rows = [
            item("便利店可乐", amount: 8, category: .dining, at: date(7, 14, 13), emotion: "给今天一点甜"),
            item(
                "医院检查",
                amount: 120,
                category: .health,
                at: date(7, 15, 10),
                emotion: "雨天看病辛苦了",
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: "rain",
                    temperatureCelsius: 24,
                    cityName: nil,
                    semanticPlace: nil
                )
            )
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        XCTAssertTrue(LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0]).isEmpty)
    }

    func testPlaybackAuxiliarySignalsDeduplicateMainAndSupportCopy() {
        let chapter = SummaryChapter(
            id: "dedup",
            title: "这一周",
            metrics: [
                PlaybackAuxiliarySignalPolicy.lifeMarkMetricKey: "咖啡饮品",
                PlaybackAuxiliarySignalPolicy.emotionMetricKey: "热天路上辛苦了",
                "supportLine": "生活线索：咖啡饮品"
            ],
            narration: SummaryNarration(
                warm: "这周也有一笔热天路上辛苦了。",
                plain: "这周也有一笔热天路上辛苦了。"
            ),
            durationSec: 6
        )

        XCTAssertTrue(LifeStorySignalService.playbackAuxiliarySignals(from: chapter).isEmpty)
    }

    func testStrongLateWorkCommuteBecomesWeeklyRepresentativeAndUsesDedicatedCopy() throws {
        let now = date(7, 16, 20)
        let lateWorkCommute = HomeItem(
            title: "加班打车",
            amount: 50.90,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 14, 0, 8),
            emotionTag: "打车这一程",
            userEditedTitle: false,
            memoryImageData: Data([0x01])
        )
        let rows = [
            item("早餐", amount: 12, category: .dining, at: date(7, 13, 8)),
            lateWorkCommute,
            item("买纸巾", amount: 18, category: .daily, at: date(7, 15, 18))
        ]

        let summary = PlaybackService().buildWeekSummary(from: rows, now: now)
        let voice = try XCTUnwrap(summary.chapters.first(where: { $0.id == "week-voices" }))
        let dedicatedNarrationCount = summary.chapters.filter {
            $0.narration.plain.contains("凌晨零点多还在下班路上")
        }.count

        XCTAssertEqual(voice.metrics["voiceTitle1"], "晚下班路上")
        XCTAssertTrue(voice.narration.plain.contains("今天收得有点晚"))
        XCTAssertTrue(voice.metrics["supportLine", default: ""].contains("50.9"))
        XCTAssertEqual(summary.total, 80.9, accuracy: 0.001)
        XCTAssertEqual(dedicatedNarrationCount, 1)
        XCTAssertTrue(summary.memoryAnchors.contains(where: { $0.itemID == lateWorkCommute.id }))
        XCTAssertFalse(
            LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0])
                .contains(where: { $0.label.contains("晚下班") })
        )
    }

    func testHigherValueLeadKeepsItsWeeklyVoiceAndLateWorkCommuteMovesToOpeningSupport() throws {
        let now = date(7, 16, 20)
        let lead = HomeItem(
            title: "第一次带妈妈去看展",
            amount: 88,
            category: .entertainment,
            createdAt: date(7, 13, 15),
            userEditedTitle: true,
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .moment
        )
        let lateWorkCommute = HomeItem(
            title: "加班打车",
            amount: 50.90,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 14, 0, 8),
            emotionTag: "打车这一程",
            userEditedTitle: false
        )

        let summary = PlaybackService().buildWeekSummary(
            from: [lead, lateWorkCommute, item("早餐", amount: 12, category: .dining, at: date(7, 15, 8))],
            now: now
        )
        let voice = try XCTUnwrap(summary.chapters.first(where: { $0.id == "week-voices" }))

        XCTAssertEqual(voice.metrics["voiceTitle1"], lead.title)
        XCTAssertTrue(summary.chapters[0].metrics["supportLine", default: ""].contains("凌晨零点多还在下班路上"))
        XCTAssertFalse(voice.narration.plain.contains("下班路上"))
    }

    func testOrdinaryLateTransitDoesNotReceiveTheStrongWorkCommuteGuarantee() {
        let ordinaryTransit = HomeItem(
            title: "地铁",
            amount: 4,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 14, 0, 8),
            emotionTag: "日常出行",
            userEditedTitle: false
        )

        XCTAssertNil(PlaybackLateWorkCommutePolicy.preferredStrongItem(in: [ordinaryTransit]))
        XCTAssertEqual(HomeItem.lateWorkCommutePlaybackTitle(for: ordinaryTransit), "晚上通勤路上")
    }

    func testStrongLateWorkCommuteUsesTheMatchingMonthlyHalfChapter() throws {
        let now = date(7, 20, 20)
        let lateWorkCommute = HomeItem(
            title: "加班打车",
            amount: 50.90,
            category: .transport,
            source: .ocr,
            createdAt: date(7, 12, 0, 8),
            emotionTag: "打车这一程",
            userEditedTitle: false
        )
        let summary = PlaybackService().buildMonthSummary(
            from: [
                item("早餐", amount: 12, category: .dining, at: date(7, 4, 8)),
                lateWorkCommute,
                item("买纸巾", amount: 18, category: .daily, at: date(7, 18, 18))
            ],
            now: now
        )
        let lateVoice = try XCTUnwrap(summary.chapters.first(where: { $0.id == "month-late-voice" }))

        XCTAssertEqual(lateVoice.metrics["lateVoiceTitle"], "晚下班路上")
        XCTAssertTrue(lateVoice.narration.plain.contains("凌晨零点多还在下班路上"))
    }

    func testMonthPublishesAuxiliarySignalsOnlyOnOpeningChapter() {
        let now = date(7, 20, 20)
        let rows = [
            item("一杯咖啡", amount: 16, category: .dining, at: date(7, 4, 14)),
            item("下午拿铁", amount: 18, category: .dining, at: date(7, 12, 15)),
            item("早餐", amount: 12, category: .dining, at: date(7, 18, 8))
        ]

        let summary = PlaybackService().buildMonthSummary(from: rows, now: now)
        XCTAssertEqual(
            LifeStorySignalService.playbackAuxiliarySignals(from: summary.chapters[0]).map(\.label),
            ["生活线索 · 咖啡饮品"]
        )
        XCTAssertEqual(summary.chapters.count, 6)
        XCTAssertTrue(summary.chapters.dropFirst().allSatisfy {
            LifeStorySignalService.playbackAuxiliarySignals(from: $0).isEmpty
        })
    }

    func testMonthKeepsSixRolesAndUsesSameDayComparison() {
        let now = date(7, 20, 20)
        let current = [
            item("上班地铁", amount: 100, category: .transport, at: date(7, 4, 8)),
            item("和朋友吃饭", amount: 100, category: .dining, at: date(7, 15, 19)),
            item("午饭", amount: 80, category: .dining, at: date(7, 16, 12)),
            item("买纸巾", amount: 60, category: .daily, at: date(7, 18, 18))
        ]
        let previous = [
            item("交通", amount: 200, category: .transport, at: date(6, 4, 8)),
            item("早餐", amount: 50, category: .dining, at: date(6, 10, 8)),
            item("午饭", amount: 50, category: .dining, at: date(6, 18, 12)),
            item("月末大额", amount: 1_000, category: .shopping, at: date(6, 25, 12))
        ]

        let summary = PlaybackService().buildMonthSummary(from: current + previous, now: now)
        XCTAssertEqual(summary.chapters.count, 6)
        XCTAssertEqual(
            summary.chapters.map(\.title),
            ["7月回看", "月初留下的", "后来留下的", "和上月同期相比", "这个月反复出现", "这个月先到这里"]
        )
        XCTAssertEqual(summary.chapters.map(\.durationSec), [8, 8, 8, 8, 8, 7])
        XCTAssertTrue(summary.chapters[1].narration.plain.contains("7月4日"))
        XCTAssertTrue(summary.chapters[2].narration.plain.contains("7月"))
        XCTAssertTrue(summary.chapters[3].metrics["supportLine", default: ""].contains("1 日—20 日"))
        XCTAssertFalse(summary.chapters[3].narration.plain.contains("1000"))
        XCTAssertNotEqual(summary.chapters[1].narration.plain, summary.chapters[2].narration.plain)
    }

    func testMonthExplicitlyHandlesMissingEarlyLateAndComparisonEvidence() {
        let now = date(7, 20, 20)
        let rows = [
            item("晚饭", amount: 38, category: .dining, at: date(7, 14, 19)),
            item("下班地铁", amount: 4, category: .transport, at: date(7, 15, 21))
        ]
        let summary = PlaybackService().buildMonthSummary(from: rows, now: now)

        XCTAssertTrue(summary.chapters[1].narration.plain.contains("月初十天没有记录"))
        XCTAssertTrue(summary.chapters[1].narration.plain.contains("7月14日"))
        XCTAssertFalse(summary.chapters[2].narration.plain.contains("月初十天"))
        XCTAssertTrue(summary.chapters[3].narration.plain.contains("暂时不做环比"))
        XCTAssertTrue(summary.chapters[4].narration.plain.contains("没有哪一类反复出现"))
        XCTAssertEqual(summary.chapters[5].narration.warm, summary.chapters[5].narration.plain)
    }
}

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
            weekActiveDayCount: 0,
            monthRecordCount: 0,
            monthActiveDayCount: 0,
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
        snapshot.weekActiveDayCount = 2
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .weekTrace)

        snapshot.weekRecordCount = 0
        snapshot.weekActiveDayCount = 0
        snapshot.monthRecordCount = 5
        snapshot.monthActiveDayCount = 3
        snapshot.dayOfMonth = 25
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .monthChapter)

        snapshot.monthRecordCount = 0
        snapshot.monthActiveDayCount = 0
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

    func testRecordFlowShowsOCRUntilAnAmountDraftExists() {
        XCTAssertTrue(RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: false))
        XCTAssertFalse(RecordFlowVisibilityPolicy.showsOCRSideDoor(hasAmountDraft: true))
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
        XCTAssertTrue(ReviewTaskIntent.query.presetCommand.contains("最近 7 天"))
        XCTAssertTrue(ReviewTaskIntent.compare.presetCommand.contains("最近 7 天"))
        XCTAssertTrue(ReviewTaskIntent.compare.presetCommand.contains("前 7 天"))
        XCTAssertTrue(ReviewTaskIntent.backfill.presetCommand.isEmpty)
    }

    func testPlaybackMaturityAndCompletionUseOnePrimaryRule() {
        XCTAssertFalse(PlaybackMaturityPolicy.weekIsReady(recordCount: 3, activeDayCount: 1))
        XCTAssertTrue(PlaybackMaturityPolicy.weekIsReady(recordCount: 3, activeDayCount: 2))
        XCTAssertFalse(PlaybackMaturityPolicy.monthIsReady(recordCount: 5, activeDayCount: 3, dayOfMonth: 24))
        XCTAssertFalse(PlaybackMaturityPolicy.monthIsReady(recordCount: 5, activeDayCount: 2, dayOfMonth: 25))
        XCTAssertTrue(PlaybackMaturityPolicy.monthIsReady(recordCount: 5, activeDayCount: 3, dayOfMonth: 25))
        XCTAssertEqual(PlaybackCompletionPolicy.primaryAction(isMember: true), .dismiss)
        XCTAssertEqual(PlaybackCompletionPolicy.primaryAction(isMember: false), .dismiss)
        XCTAssertEqual(PlaybackCompletionPolicy.primaryTitle(isMember: true, memberTitle: nil), "完成")
        XCTAssertEqual(PlaybackCompletionPolicy.primaryTitle(isMember: false, memberTitle: "了解会员"), "完成")
        XCTAssertTrue(PlaybackCompletionPolicy.showsMemberContinuation(isMember: false, hasMemberPitch: true))
        XCTAssertFalse(PlaybackCompletionPolicy.showsMemberContinuation(isMember: false, hasMemberPitch: false))
        XCTAssertFalse(PlaybackCompletionPolicy.showsMemberContinuation(isMember: true, hasMemberPitch: true))
        XCTAssertTrue(
            PlaybackMaturityPolicy.homeRecommendationExplanation(
                weekRecordCount: 3,
                weekActiveDayCount: 1,
                monthRecordCount: 5,
                monthActiveDayCount: 3,
                dayOfMonth: 20
            ).contains("接近月底")
        )
    }

    func testWeekTraceDiscoveryUsesSharedMaturityAndSeparateSeenState() {
        var snapshot = WeekTraceDiscoverySnapshot(
            recordCount: 3,
            activeDayCount: 1,
            canPlay: true,
            hasCompletedPlayback: false,
            hasSeenTrace: false
        )
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        XCTAssertFalse(
            WeekTraceDiscoveryPolicy.shouldMarkSeen(
                recordCount: 3,
                activeDayCount: 1,
                hasVisibleCurrentWeekSnapshot: true,
                hasSeenTrace: false
            )
        )

        snapshot.activeDayCount = 2
        XCTAssertTrue(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        XCTAssertFalse(
            WeekTraceDiscoveryPolicy.shouldMarkSeen(
                recordCount: 3,
                activeDayCount: 2,
                hasVisibleCurrentWeekSnapshot: false,
                hasSeenTrace: false
            )
        )
        XCTAssertTrue(
            WeekTraceDiscoveryPolicy.shouldMarkSeen(
                recordCount: 3,
                activeDayCount: 2,
                hasVisibleCurrentWeekSnapshot: true,
                hasSeenTrace: false
            )
        )

        snapshot.hasSeenTrace = true
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        snapshot.hasSeenTrace = false
        snapshot.hasCompletedPlayback = true
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
        snapshot.hasCompletedPlayback = false
        snapshot.canPlay = false
        XCTAssertFalse(WeekTraceDiscoveryPolicy.shouldShowBadge(for: snapshot))
    }

    func testTodayPlaybackStillPrecedesAReadyWeekTrace() {
        let snapshot = NewUserProgressionSnapshot(
            totalRecordCount: 3,
            hasUnplayedTodayRecords: true,
            weekRecordCount: 3,
            weekActiveDayCount: 2,
            monthRecordCount: 3,
            monthActiveDayCount: 2,
            dayOfMonth: 20,
            canPlayWeek: true,
            canPlayMonth: true,
            hasCompletedCurrentWeekPlayback: false,
            hasCompletedCurrentMonthPlayback: false
        )
        XCTAssertEqual(NewUserProgressionPolicy.stage(for: snapshot), .todayPlayback)
        XCTAssertTrue(
            WeekTraceDiscoveryPolicy.shouldShowBadge(
                for: WeekTraceDiscoverySnapshot(
                    recordCount: 3,
                    activeDayCount: 2,
                    canPlay: true,
                    hasCompletedPlayback: false,
                    hasSeenTrace: false
                )
            )
        )
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
        session.noteEditorExpanded = true
        session.datePanelExpanded = true
        session.previewLineWasRotated = true
        session.userNoteAnchorTitle = "晚饭"

        XCTAssertEqual(session.selectedEntryMode, .ocr)
        XCTAssertTrue(session.noteEditorExpanded)

        session.resetAfterCommittedDraft()

        XCTAssertEqual(session.selectedEntryMode, .manual)
        XCTAssertFalse(session.noteEditorExpanded)
        XCTAssertFalse(session.datePanelExpanded)
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
        XCTAssertEqual(stats.scrollAnchorID, "trace-clue-board")
        XCTAssertEqual(stats.pendingLifeChapterScrollRange, .month)

        var insight = InsightTabState()
        insight.showsAdvancedInsight = true
        insight.scrollAnchorID = "insight-next-chapter"
        insight.monthlyInsightGenerated = true

        XCTAssertTrue(insight.showsAdvancedInsight)
        XCTAssertTrue(insight.monthlyInsightGenerated)
        XCTAssertEqual(insight.scrollAnchorID, "insight-next-chapter")
    }

    func testSelectingLifeNormalizesClueOnlyRangesToTheRememberedLifeRange() {
        var customRangeState = StatsTabState()
        customRangeState.viewMode = .clues
        customRangeState.lifeCardRange = .month
        customRangeState.selectedPeriod = .month
        customRangeState.useCustomRange = true
        customRangeState.showsCustomDatePanel = true
        customRangeState.selectedCategory = .dining

        customRangeState.selectViewMode(.life)

        XCTAssertEqual(customRangeState.viewMode, .life)
        XCTAssertEqual(customRangeState.lifeCardRange, .month)
        XCTAssertEqual(customRangeState.selectedPeriod, .month)
        XCTAssertFalse(customRangeState.useCustomRange)
        XCTAssertFalse(customRangeState.showsCustomDatePanel)
        XCTAssertEqual(customRangeState.selectedCategory, .dining)

        var yearState = StatsTabState()
        yearState.viewMode = .clues
        yearState.lifeCardRange = .week
        yearState.selectedPeriod = .year

        yearState.selectViewMode(.life)

        XCTAssertEqual(yearState.viewMode, .life)
        XCTAssertEqual(yearState.lifeCardRange, .week)
        XCTAssertEqual(yearState.selectedPeriod, .week)
        XCTAssertFalse(yearState.useCustomRange)
    }

    func testSelectingCluesDoesNotRewriteTheExistingRangeState() {
        var stats = StatsTabState()
        stats.lifeCardRange = .month
        stats.selectedPeriod = .year
        stats.useCustomRange = true
        stats.showsCustomDatePanel = true

        stats.selectViewMode(.clues)

        XCTAssertEqual(stats.viewMode, .clues)
        XCTAssertEqual(stats.lifeCardRange, .month)
        XCTAssertEqual(stats.selectedPeriod, .year)
        XCTAssertTrue(stats.useCustomRange)
        XCTAssertTrue(stats.showsCustomDatePanel)
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

final class SingleRecordEmotionBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 18,
            hour: hour,
            minute: minute
        ))!
    }

    func testParkingTagUsesFactCopyForNewAndStoredRecords() {
        let fresh = HomeItem(title: "停车费", amount: 69.8, category: .transport, createdAt: date(7, 47))
        let stored = HomeItem(
            title: "停车费",
            amount: 69.8,
            category: .transport,
            createdAt: date(7, 47),
            emotionTag: "车停稳了"
        )

        XCTAssertEqual(fresh.displayEmotionTag, "停车费记下")
        XCTAssertEqual(stored.displayEmotionTag, "停车费记下")
    }

    func testWeekendDiningDoesNotPersistCrossRecordTransportStory() {
        let parking = HomeItem(title: "停车费", amount: 12, category: .transport, createdAt: date(7, 47))
        let result = RecordMemoryContextService.enhancedEmotionTag(input: RecordMemoryContextInput(
            title: "巧婆红汤馄饨",
            category: .dining,
            amount: 16,
            date: date(8, 22),
            baseEmotionTag: "周末早餐",
            existingItems: [parking],
            weather: nil
        ))

        XCTAssertEqual(result, "周末早餐")
    }

    func testStoredWeekendCombinationTagFallsBackToThisRecordOnly() {
        let breakfast = HomeItem(
            title: "巧婆红汤馄饨",
            amount: 16,
            category: .dining,
            createdAt: date(8, 22),
            emotionTag: "周末路上和饭点都有了"
        )

        XCTAssertEqual(breakfast.displayEmotionTag, "周末早餐")
    }

    func testFirstRecordStoryUsesTimeAndRecordInsteadOfEmotionTemplate() {
        let parking = HomeItem(title: "停车费", amount: 69.8, category: .transport, createdAt: date(7, 47))
        let line = HomeViewModel.singleRecordTodayStoryLine(for: parking, calendar: calendar)

        XCTAssertTrue(line.contains("早上"))
        XCTAssertTrue(line.contains("停车费"))
        XCTAssertFalse(line.contains("车停稳了"))
        XCTAssertFalse(line.contains("刚翻开第一页"))
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

    func testStrongDirectionCuesOverrideNonstandardHours() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let eveningSlot = AICommuteDraftSchedule.slots[1]
        let work = HomeItem(title: "上班", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 13, 48))

        XCTAssertTrue(AICommuteDuplicatePolicy.matches(work, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
        XCTAssertFalse(AICommuteDuplicatePolicy.matches(work, slot: eveningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testDirectionlessLateCommuteOnlyBlocksEveningSlot() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let eveningSlot = AICommuteDraftSchedule.slots[1]
        let commute = HomeItem(title: "通勤路上记一笔", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 22, 55))

        XCTAssertFalse(AICommuteDuplicatePolicy.matches(commute, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
        XCTAssertTrue(AICommuteDuplicatePolicy.matches(commute, slot: eveningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testOrdinaryTransportAndTravelDoNotBlockCommuteSlots() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let taxi = HomeItem(title: "临时打车", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 8, 10))
        let train = HomeItem(title: "高铁出差", amount: 4.75, category: .transport, createdAt: date(2026, 7, 17, 8, 20))

        XCTAssertFalse(AICommuteDuplicatePolicy.matches(taxi, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
        XCTAssertFalse(AICommuteDuplicatePolicy.matches(train, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
    }

    func testAmountMismatchDoesNotBlockMatchingDirection() {
        let day = date(2026, 7, 17, 0, 0)
        let morningSlot = AICommuteDraftSchedule.slots[0]
        let work = HomeItem(title: "上班", amount: 42, category: .transport, createdAt: date(2026, 7, 17, 13, 48))

        XCTAssertFalse(AICommuteDuplicatePolicy.matches(work, slot: morningSlot, day: day, proposedAmount: 4.75, calendar: calendar))
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

    func testSwitchingToMissingMonthDoesNotExposeWeekDuringPreparation() {
        XCTAssertFalse(
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

    func testSwitchingToMissingWeekDoesNotExposeMonthDuringPreparation() {
        XCTAssertFalse(
            TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: .week,
                hasWeek: false,
                hasMonth: true
            )
        )
        XCTAssertTrue(
            TraceLifePreparationPolicy.hasVisibleSnapshot(
                selectedRange: .week,
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

final class TraceSnapshotVisibilityPolicyTests: XCTestCase {
    func testLifeRangeMustMatchTheSelectedPresetPeriod() {
        XCTAssertTrue(
            TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: .month,
                selectedPeriod: .month,
                usesCustomRange: false
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: .month,
                selectedPeriod: .week,
                usesCustomRange: false
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.representsSelectedLifeRange(
                range: .month,
                selectedPeriod: .month,
                usesCustomRange: true
            )
        )
    }

    func testChapterRequiresSelectedRangeAndExactPublicationKey() {
        XCTAssertTrue(
            TraceSnapshotVisibilityPolicy.canDisplayChapter(
                selectedRange: .month,
                snapshotRange: .month,
                publishedKey: "month-current",
                expectedKey: "month-current"
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.canDisplayChapter(
                selectedRange: .month,
                snapshotRange: .week,
                publishedKey: "month-current",
                expectedKey: "month-current"
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.canDisplayChapter(
                selectedRange: .month,
                snapshotRange: .month,
                publishedKey: "month-old",
                expectedKey: "month-current"
            )
        )
    }

    func testColdStartDisplayRequiresTheExactSelectedScope() {
        XCTAssertTrue(
            TraceSnapshotVisibilityPolicy.canDisplayColdStart(
                publishedScopeKey: "life|month",
                expectedScopeKey: "life|month"
            )
        )
        XCTAssertFalse(
            TraceSnapshotVisibilityPolicy.canDisplayColdStart(
                publishedScopeKey: "life|week",
                expectedScopeKey: "life|month"
            )
        )
    }
}

final class TraceDeferredScrollPolicyTests: XCTestCase {
    func testRepeatedTargetRequiresResetBeforeReissuingTheAnchor() {
        XCTAssertTrue(
            TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID,
                targetAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID
            )
        )
    }

    func testMissingOrDifferentTargetDoesNotNeedAnAnchorReset() {
        XCTAssertFalse(
            TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: nil,
                targetAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID
            )
        )
        XCTAssertFalse(
            TraceDeferredScrollPolicy.requiresAnchorReset(
                currentAnchorID: "trace-clue-board",
                targetAnchorID: TraceDeferredScrollPolicy.lifeChapterAnchorID
            )
        )
    }
}

final class TraceLoadingPresentationPolicyTests: XCTestCase {
    func testInitialMonthTraceShowsOneImmediateAccuratePresentation() {
        let presentation = TraceLoadingPresentationPolicy.make(
            viewMode: .life,
            selectedPeriod: .month,
            lifeRange: .month,
            usesCustomRange: false,
            hasVisibleSnapshot: false
        )

        XCTAssertEqual(presentation.message, "正在整理本月痕迹…")
        XCTAssertEqual(presentation.delayNanoseconds, 0)
        XCTAssertEqual(presentation.detail, "整理好后会一次完整呈现")
    }

    func testRefreshWithExistingSnapshotDelaysTheSingleOverlay() {
        let presentation = TraceLoadingPresentationPolicy.make(
            viewMode: .life,
            selectedPeriod: .week,
            lifeRange: .week,
            usesCustomRange: false,
            hasVisibleSnapshot: true
        )

        XCTAssertEqual(
            presentation.delayNanoseconds,
            TraceLoadingPresentationPolicy.refreshDelayNanoseconds
        )
        XCTAssertEqual(presentation.detail, "整理完成前会暂时保留当前内容")
    }

    func testClueCopyDistinguishesMonthAndCustomRange() {
        let month = TraceLoadingPresentationPolicy.make(
            viewMode: .clues,
            selectedPeriod: .month,
            lifeRange: .week,
            usesCustomRange: false,
            hasVisibleSnapshot: false
        )
        let custom = TraceLoadingPresentationPolicy.make(
            viewMode: .clues,
            selectedPeriod: .month,
            lifeRange: .week,
            usesCustomRange: true,
            hasVisibleSnapshot: false
        )

        XCTAssertEqual(month.message, "正在整理本月线索…")
        XCTAssertEqual(custom.message, "正在整理这段线索…")
    }
}

final class TraceSnapshotLifecycleTests: XCTestCase {
    func testChapterAndClueKeysReuseOnlyTheSameRealSourceState() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let end = start.addingTimeInterval(6 * 24 * 60 * 60)
        let chapter = TraceSnapshotLifecycleKeyPolicy.chapterKey(
            range: .week,
            ledgerRevision: 9,
            periodKey: "2026-W30|2026-07-23",
            isMember: false,
            contentRevision: 2
        )
        XCTAssertTrue(chapter.hasPrefix("chapter-v3|"))
        XCTAssertEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 9,
                periodKey: "2026-W30|2026-07-23",
                isMember: false,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 10,
                periodKey: "2026-W30|2026-07-23",
                isMember: false,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .month,
                ledgerRevision: 9,
                periodKey: "2026-07|2026-07-23",
                isMember: false,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 9,
                periodKey: "2026-W30|2026-07-23",
                isMember: true,
                contentRevision: 2
            )
        )
        XCTAssertNotEqual(
            chapter,
            TraceSnapshotLifecycleKeyPolicy.chapterKey(
                range: .week,
                ledgerRevision: 9,
                periodKey: "2026-W30|2026-07-23",
                isMember: false,
                contentRevision: 3
            )
        )

        let preset = TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: .month,
            ledgerRevision: 9,
            isMember: true,
            usesCustomRange: false,
            customStartDate: start,
            customEndDate: end,
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            contentRevision: 3
        )
        let presetWithIrrelevantDatesChanged = TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: .month,
            ledgerRevision: 9,
            isMember: true,
            usesCustomRange: false,
            customStartDate: start.addingTimeInterval(-90_000),
            customEndDate: end.addingTimeInterval(90_000),
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            contentRevision: 3
        )
        let custom = TraceSnapshotLifecycleKeyPolicy.clueKey(
            period: .month,
            ledgerRevision: 9,
            isMember: true,
            usesCustomRange: true,
            customStartDate: start,
            customEndDate: end,
            category: .dining,
            freeRemaining: 5,
            isUnlocked: false,
            dayKey: "2026-07-23",
            contentRevision: 3
        )

        XCTAssertEqual(preset, presetWithIrrelevantDatesChanged)
        XCTAssertNotEqual(preset, custom)
        XCTAssertNotEqual(
            custom,
            TraceSnapshotLifecycleKeyPolicy.clueKey(
                period: .month,
                ledgerRevision: 9,
                isMember: true,
                usesCustomRange: true,
                customStartDate: start.addingTimeInterval(-90_000),
                customEndDate: end,
                category: .dining,
                freeRemaining: 5,
                isUnlocked: false,
                dayKey: "2026-07-23",
                contentRevision: 3
            )
        )
    }

    func testColdStartFingerprintIsStableAcrossOrderingAndChangesWithLedgerContent() {
        let first = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!,
            title: "午餐",
            amount: 28,
            category: .dining,
            createdAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
        var second = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000082")!,
            title: "地铁",
            amount: 6,
            category: .transport,
            createdAt: Date(timeIntervalSince1970: 1_790_003_600)
        )
        let original = LedgerDisplayFingerprintPolicy.make(items: [first, second])

        XCTAssertEqual(
            original,
            LedgerDisplayFingerprintPolicy.make(items: [second, first])
        )

        second.amount = 8
        XCTAssertNotEqual(
            original,
            LedgerDisplayFingerprintPolicy.make(items: [first, second])
        )
    }

    func testColdStartDisplaySurvivesStoreRecreationButRejectsAnotherContext() {
        let suiteName = "TraceSnapshotLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "trace-test"
        let context = TraceColdStartDisplayContext(
            ledgerFingerprint: "ledger-a",
            dayKey: "2026-07-23",
            isMember: false
        )
        let entry = TraceColdStartDisplayEntry(
            scopeKey: "life|week",
            savedAt: Date(timeIntervalSince1970: 1_790_000_000),
            title: "这一周留下了几段生活",
            summary: "原内容先承接，最新快照在后台准备。",
            periodLabel: "本周痕迹",
            recordCount: 8,
            activeDayCount: 4,
            total: 188,
            topCategory: "餐饮"
        )

        TraceColdStartDisplayStore(defaults: defaults, storageKey: storageKey).store(
            entry,
            context: context
        )
        let relaunchedStore = TraceColdStartDisplayStore(
            defaults: defaults,
            storageKey: storageKey
        )

        XCTAssertEqual(
            relaunchedStore.entry(for: context, scopeKey: entry.scopeKey),
            entry
        )
        XCTAssertNil(
            relaunchedStore.entry(
                for: TraceColdStartDisplayContext(
                    ledgerFingerprint: "ledger-b",
                    dayKey: context.dayKey,
                    isMember: context.isMember
                ),
                scopeKey: entry.scopeKey
            )
        )
        XCTAssertNil(
            relaunchedStore.entry(
                for: TraceColdStartDisplayContext(
                    ledgerFingerprint: context.ledgerFingerprint,
                    dayKey: "2026-07-24",
                    isMember: context.isMember
                ),
                scopeKey: entry.scopeKey
            )
        )
        defaults.set(Data([0xFF, 0x00]), forKey: storageKey)
        XCTAssertNil(relaunchedStore.entry(for: context, scopeKey: entry.scopeKey))
        XCTAssertNil(defaults.data(forKey: storageKey))
    }
}

final class RecordInputAssistanceSnapshotTests: XCTestCase {
    func testHistoryKeyChangesOnlyForLedgerOrMeaningfulDateContext() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 10,
            minute: 15
        ))!

        let first = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base,
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let redrawOnly = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base.addingTimeInterval(30),
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let nextHabitBucket = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base.addingTimeInterval(3 * 60 * 60),
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let changedLedger = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 8,
            referenceDate: base,
            referenceDateEditedByUser: false,
            calendar: calendar
        )
        let editedMinute = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 7,
            referenceDate: base.addingTimeInterval(60),
            referenceDateEditedByUser: true,
            calendar: calendar
        )

        XCTAssertEqual(first, redrawOnly)
        XCTAssertNotEqual(first, nextHabitBucket)
        XCTAssertNotEqual(first, changedLedger)
        XCTAssertNotEqual(
            RecordInputAssistanceComputation.historyKey(
                ledgerRevision: 7,
                referenceDate: base,
                referenceDateEditedByUser: true,
                calendar: calendar
            ),
            editedMinute
        )
    }

    func testHistorySnapshotFeedsWarmupAndPrefillWithoutRescanningViewBody() {
        let calendar = Calendar.current
        let now = Date()
        let referenceDate = calendar.date(
            bySettingHour: 10,
            minute: 30,
            second: 0,
            of: now
        ) ?? now
        let amounts = [12.5, 12.5, 12.5, 21, 32, 43]
        let items = amounts.enumerated().map { index, amount in
            HomeItem(
                title: index < 3 ? "工作日早餐" : "日常记录 \(index)",
                amount: amount,
                category: index < 3 ? .dining : .other,
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-3_600 - index * 60)),
                userEditedTitle: index < 3
            )
        }
        let historyKey = RecordInputAssistanceComputation.historyKey(
            ledgerRevision: 3,
            referenceDate: referenceDate,
            referenceDateEditedByUser: false
        )
        let history = RecordInputAssistanceComputation.historySnapshot(
            RecordInputHistoryPreparationInput(
                key: historyKey,
                items: items,
                referenceDate: referenceDate,
                now: now
            )
        )

        XCTAssertEqual(history.frequentSuggestions.first?.amount, 12.5)
        XCTAssertEqual(history.frequentSuggestions.first?.category, .dining)

        let context = RecordContextSignal(referenceDate: referenceDate, weather: nil)
        let prefillKey = RecordPrefillPreparationKey(
            historyKey: historyKey,
            amount: 12.5,
            referenceDate: referenceDate,
            noteDraft: "",
            selectedCategory: .other,
            context: context
        )
        let snapshot = RecordInputAssistanceComputation.prefillSnapshot(
            RecordPrefillPreparationInput(
                key: prefillKey,
                history: history,
                amount: 12.5,
                referenceDate: referenceDate,
                now: now,
                noteDraft: "",
                selectedCategory: .other,
                context: context
            )
        )

        XCTAssertEqual(snapshot.appliedCategory, .dining)
        XCTAssertEqual(snapshot.categoryGridRecommendation, .dining)
        XCTAssertEqual(snapshot.result?.category, .dining)
    }

    func testPreviewLifeMarkSnapshotIsDeterministicForTheSameDraftAndLedgerRevision() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let draft = HomeItem(
            title: "牛肉面",
            amount: 18,
            category: .dining,
            createdAt: date,
            userEditedTitle: true
        )
        let key = RecordPreviewLifeMarkKey(
            ledgerRevision: 4,
            title: draft.title,
            amount: draft.amount,
            category: draft.category,
            createdAt: draft.createdAt,
            emotionTag: draft.emotionTag,
            merchantBrandID: nil,
            scenePackID: nil,
            isMember: true
        )
        let input = RecordPreviewLifeMarkPreparationInput(
            key: key,
            draft: draft,
            allItems: [draft],
            isMember: true
        )

        let first = RecordInputAssistanceComputation.previewLifeMarkText(input)
        let second = RecordInputAssistanceComputation.previewLifeMarkText(input)
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }
}

final class HomeDashboardSnapshotTests: XCTestCase {
    func testJourneyLedgerFactsReuseOneCommittedRecordSnapshot() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_784_240_000)
        let week = DateInterval(
            start: now.addingTimeInterval(-3 * 24 * 60 * 60),
            end: now.addingTimeInterval(4 * 24 * 60 * 60)
        )
        let month = DateInterval(
            start: now.addingTimeInterval(-15 * 24 * 60 * 60),
            end: now.addingTimeInterval(16 * 24 * 60 * 60)
        )
        let committed = HomeItem(
            title: "牛肉面",
            amount: 28,
            category: .dining,
            createdAt: now
        )
        let olderCommitted = HomeItem(
            title: "地铁",
            amount: 3,
            category: .transport,
            createdAt: now.addingTimeInterval(-10 * 24 * 60 * 60)
        )
        let draft = HomeItem(
            title: "待整理",
            amount: 20,
            category: .other,
            createdAt: now,
            draftMeta: .init(batchId: "qa", importedAt: now, status: .pending)
        )
        let zero = HomeItem(
            title: "零金额",
            amount: 0,
            category: .other,
            createdAt: now
        )

        let facts = HomeJourneyLedgerFacts.build(
            from: [committed, olderCommitted, draft, zero],
            currentWeekInterval: week,
            currentMonthInterval: month,
            calendar: calendar
        )

        XCTAssertEqual(facts.totalCommittedRecordCount, 2)
        XCTAssertEqual(facts.allRecordDayCount, 2)
        XCTAssertEqual(facts.currentWeekCommittedRecordCount, 1)
        XCTAssertEqual(facts.currentWeekActiveDayCount, 1)
        XCTAssertEqual(facts.currentMonthCommittedRecordCount, 2)
        XCTAssertEqual(facts.currentMonthActiveDayCount, 2)
    }

    func testVisibleLifeMarksPrepareOnceForOnlyVisibleRecordIDs() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let visible = HomeItem(
            title: "牛肉面",
            amount: 28,
            category: .dining,
            createdAt: date
        )
        let hidden = HomeItem(
            title: "上班地铁",
            amount: 3,
            category: .transport,
            createdAt: date.addingTimeInterval(-60)
        )
        let key = HomeLifeMarkSnapshotKey(
            ledgerRevision: 2,
            dayKey: "2026-07-17",
            isMember: true
        )
        let first = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [visible],
                weekItems: [visible, hidden],
                allItems: [visible, hidden],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )
        let second = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [visible],
                weekItems: [visible, hidden],
                allItems: [visible, hidden],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )

        XCTAssertNotNil(first.textsByItemID[visible.id])
        XCTAssertNil(first.textsByItemID[hidden.id])
        XCTAssertEqual(first.textsByItemID, second.textsByItemID)
        XCTAssertNotNil(first.todayPrimaryLine)
        XCTAssertEqual(first.todayPrimaryLine, second.todayPrimaryLine)
        XCTAssertEqual(first.weekLifeThemeText, second.weekLifeThemeText)
        XCTAssertEqual(first.quickRecordNudgeText, second.quickRecordNudgeText)
        XCTAssertEqual(first.weekTopCategoryText, second.weekTopCategoryText)
    }

    func testPreparedLifeMarkContextMatchesLegacyCombinedAndPerItemResults() {
        let now = Date(timeIntervalSince1970: 1_784_240_000)
        let items = [
            HomeItem(title: "咖啡", amount: 18, category: .dining, createdAt: now),
            HomeItem(
                title: "咖啡",
                amount: 16,
                category: .dining,
                createdAt: now.addingTimeInterval(-24 * 60 * 60)
            ),
            HomeItem(
                title: "上班地铁",
                amount: 4,
                category: .transport,
                createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
                scenePackId: "commute"
            ),
            HomeItem(
                title: "普通午餐",
                amount: 28,
                category: .dining,
                createdAt: now.addingTimeInterval(-3 * 24 * 60 * 60)
            )
        ]
        let context = LifeMarkService.prepareAggregationContext(
            allItems: items,
            periodItems: items
        )
        let periods = [items, [items[0]], [items[2]]]

        for period in periods {
            XCTAssertEqual(
                LifeMarkService.aggregates(
                    for: period,
                    preparedContext: context,
                    isMember: true,
                    limit: 8
                ),
                LifeMarkService.aggregates(
                    for: period,
                    allItems: items,
                    isMember: true,
                    limit: 8
                )
            )
        }
    }

    func testSceneRewardColdStartPreparedAggregationPreservesLegacyDecision() {
        let suiteName = "LifeMarkSceneRewardServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = LifeMarkSceneRewardService(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_784_240_000)
        let commute = HomeItem(
            title: "上班地铁",
            amount: 4,
            category: .transport,
            createdAt: now,
            scenePackId: "commute"
        )
        let earlierCoffee = HomeItem(
            title: "拿铁咖啡",
            amount: 18,
            category: .dining,
            createdAt: now.addingTimeInterval(-24 * 60 * 60)
        )
        let ordinary = HomeItem(
            title: "普通午餐",
            amount: 28,
            category: .dining,
            createdAt: now.addingTimeInterval(60)
        )
        let scenarios = [
            (item: commute, allItems: [commute]),
            (item: commute, allItems: [commute, earlierCoffee]),
            (item: ordinary, allItems: [ordinary])
        ]

        for scenario in scenarios {
            let previousItems = scenario.allItems.filter { $0.id != scenario.item.id }
            let expected = !LifeMarkService.aggregates(
                for: [scenario.item],
                allItems: scenario.allItems,
                isMember: true,
                limit: 1
            ).isEmpty && LifeMarkService.aggregates(
                for: previousItems,
                allItems: previousItems,
                isMember: true,
                limit: 1
            ).isEmpty

            XCTAssertEqual(
                service.shouldShowColdStartGuide(
                    after: scenario.item,
                    allItems: scenario.allItems,
                    isMember: false
                ),
                expected
            )
        }
    }

    func testItemDerivedCacheBuildsOneAtomicSnapshotAtReleaseScale() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 21,
            hour: 18,
            minute: 30
        ))!
        let items = Array((0..<5_000).map { index in
            HomeItem(
                title: "记录 \(index)",
                amount: Double((index % 200) + 1),
                category: HomeItem.Category.allCases[index % HomeItem.Category.allCases.count],
                createdAt: now.addingTimeInterval(TimeInterval(-index * 1_800))
            )
        }.reversed())
        let key = ItemDerivedCachePreparationKey(
            ledgerRevision: 42,
            dayKey: "2026-07-21"
        )

        let snapshot = ItemDerivedCacheComputation.build(
            ItemDerivedCachePreparationInput(
                key: key,
                items: items,
                now: now,
                itemsAreSortedDescending: false
            )
        )

        let expectedToday = items.filter {
            calendar.isDate($0.createdAt, inSameDayAs: now) && $0.amount > 0
        }
        XCTAssertEqual(snapshot.key, key)
        XCTAssertEqual(snapshot.todayPositiveItems.count, expectedToday.count)
        XCTAssertEqual(snapshot.recentThreeTodayItems, Array(snapshot.todayPositiveItems.prefix(3)))
        XCTAssertEqual(snapshot.todayPositiveItems, snapshot.todayPositiveItems.sorted { $0.createdAt > $1.createdAt })
        XCTAssertEqual(
            snapshot.todayPlayback,
            PlaybackService().buildTodayPlayback(from: items, now: now)
        )
        XCTAssertEqual(snapshot.homeJourneyLedgerFacts.totalCommittedRecordCount, items.count)
    }

    func testItemDerivedCachePublicationRejectsOldRevisionAndRequest() {
        let old = ItemDerivedCachePreparationKey(ledgerRevision: 8, dayKey: "2026-07-21")
        let latest = ItemDerivedCachePreparationKey(ledgerRevision: 9, dayKey: "2026-07-21")

        XCTAssertFalse(
            ItemDerivedCachePublicationPolicy.accepts(
                snapshotKey: old,
                pendingKey: latest,
                currentKey: latest,
                requestMatches: true
            )
        )
        XCTAssertFalse(
            ItemDerivedCachePublicationPolicy.accepts(
                snapshotKey: latest,
                pendingKey: latest,
                currentKey: latest,
                requestMatches: false
            )
        )
        XCTAssertTrue(
            ItemDerivedCachePublicationPolicy.accepts(
                snapshotKey: latest,
                pendingKey: latest,
                currentKey: latest,
                requestMatches: true
            )
        )
        XCTAssertLessThanOrEqual(
            ItemDerivedCachePublicationPolicy.coalescingDelayNanoseconds,
            50_000_000
        )
    }

    func testTracePrewarmWaitsUntilVisibleSnapshotHasSettled() {
        XCTAssertGreaterThanOrEqual(
            TraceLifePreparationPolicy.prewarmDelayNanoseconds,
            200_000_000
        )
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .week), .month)
        XCTAssertEqual(TraceLifePreparationPolicy.prewarmRange(after: .month), .week)
    }

    func testLifeMarkRefreshPreservesRowsOnlyForTheSameDayAndMembership() {
        let previous = HomeLifeMarkSnapshotKey(
            ledgerRevision: 2,
            dayKey: "2026-07-21",
            isMember: true
        )
        XCTAssertTrue(
            HomeLifeMarkRefreshPolicy.preservesVisibleLines(
                previousKey: previous,
                nextKey: HomeLifeMarkSnapshotKey(
                    ledgerRevision: 3,
                    dayKey: "2026-07-21",
                    isMember: true
                )
            )
        )
        XCTAssertFalse(
            HomeLifeMarkRefreshPolicy.preservesVisibleLines(
                previousKey: previous,
                nextKey: HomeLifeMarkSnapshotKey(
                    ledgerRevision: 3,
                    dayKey: "2026-07-22",
                    isMember: true
                )
            )
        )
        XCTAssertFalse(
            HomeLifeMarkRefreshPolicy.preservesVisibleLines(
                previousKey: previous,
                nextKey: HomeLifeMarkSnapshotKey(
                    ledgerRevision: 3,
                    dayKey: "2026-07-21",
                    isMember: false
                )
            )
        )
    }

    func testQuickRecordSnapshotKeyChangesOnlyWithLedgerOrMinuteBucket() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 8,
            minute: 30
        ))!
        let first = HomeQuickRecordSnapshotKey(
            ledgerRevision: 3,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(for: base, calendar: calendar)
        )
        let redrawOnly = HomeQuickRecordSnapshotKey(
            ledgerRevision: 3,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: base.addingTimeInterval(20),
                calendar: calendar
            )
        )
        let nextMinute = HomeQuickRecordSnapshotKey(
            ledgerRevision: 3,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: base.addingTimeInterval(60),
                calendar: calendar
            )
        )

        XCTAssertEqual(first, redrawOnly)
        XCTAssertNotEqual(first, nextMinute)
        XCTAssertNotEqual(first, HomeQuickRecordSnapshotKey(ledgerRevision: 4, minuteKey: first.minuteKey))
    }

    func testForegroundResumeAdvancesTheQuickRecordKeyAcrossAnOvernightBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let beforeBackground = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 19,
            hour: 23,
            minute: 48
        ))!
        let afterForeground = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 20,
            hour: 8,
            minute: 12
        ))!

        let stale = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: beforeBackground,
                calendar: calendar
            )
        )
        let refreshed = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: HomeDashboardSnapshotComputation.minuteKey(
                for: afterForeground,
                calendar: calendar
            )
        )

        XCTAssertNotEqual(stale, refreshed)
    }

    func testLifecycleRefreshClearsOnlyAStaleQuickRecordPresentation() {
        let current = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: "2026-07-20-08-12"
        )
        let nextMinute = HomeQuickRecordSnapshotKey(
            ledgerRevision: 9,
            minuteKey: "2026-07-20-08-13"
        )

        XCTAssertFalse(
            HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
                previousKey: current,
                nextKey: current,
                isLifecycleRefresh: true
            )
        )
        XCTAssertTrue(
            HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
                previousKey: current,
                nextKey: nextMinute,
                isLifecycleRefresh: true
            )
        )
        XCTAssertFalse(
            HomeQuickRecordRefreshPolicy.shouldClearVisibleSuggestion(
                previousKey: current,
                nextKey: nextMinute,
                isLifecycleRefresh: false
            )
        )
    }

    func testCommuteSuggestionKeepsExistingRulesOnImmutableLedgerInput() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 13,
            hour: 8,
            minute: 30
        ))!
        var items: [HomeItem] = (1...4).map { weekOffset in
            HomeItem(
                title: "上班地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(
                    byAdding: .day,
                    value: -7 * weekOffset,
                    to: now.addingTimeInterval(-15 * 60)
                )!,
                userEditedTitle: true
            )
        }
        items += (1...4).map { index in
            HomeItem(
                title: "日常记录 \(index)",
                amount: Double(10 + index),
                category: .other,
                createdAt: now.addingTimeInterval(TimeInterval(-index * 24 * 60 * 60))
            )
        }

        let first = HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
            items: items,
            at: now
        )
        let second = HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
            items: items,
            at: now
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first?.amount, 3)
        XCTAssertEqual(first?.category, .transport)
        XCTAssertEqual(first?.supportCount, 4)
    }

    func testForegroundRefreshDoesNotRelaxCommuteWindowOrTodayDuplicateRules() {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20,
            hour: 8,
            minute: 30
        ))!
        var history: [HomeItem] = (1...4).map { weekOffset in
            HomeItem(
                title: "上班地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(
                    byAdding: .day,
                    value: -7 * weekOffset,
                    to: now.addingTimeInterval(-15 * 60)
                )!,
                userEditedTitle: true
            )
        }
        history += (1...4).map { index in
            HomeItem(
                title: "普通记录 \(index)",
                amount: Double(20 + index),
                category: .other,
                createdAt: now.addingTimeInterval(TimeInterval(-index * 24 * 60 * 60))
            )
        }

        XCTAssertNotNil(
            HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
                items: history,
                at: now
            )
        )

        let beforePersonalWindow = calendar.date(
            bySettingHour: 7,
            minute: 0,
            second: 0,
            of: now
        )!
        XCTAssertNil(
            HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
                items: history,
                at: beforePersonalWindow
            )
        )

        let todayCommute = HomeItem(
            title: "上班地铁",
            amount: 3,
            category: .transport,
            createdAt: calendar.date(
                bySettingHour: 8,
                minute: 5,
                second: 0,
                of: now
            )!,
            scenePackId: "commute"
        )
        XCTAssertNil(
            HomeViewModel.highConfidenceQuickRecordSuggestionForSnapshot(
                items: history + [todayCommute],
                at: now
            )
        )
    }
}

final class LifeMarkFactAuthorityTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 20, minute: Int = 43) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testGeneratedDisplayCopyDoesNotCreateGroceryOrSocialFacts() {
        let generatedSupply = HomeItem(
            title: "日用记录",
            amount: 72.95,
            category: .daily,
            createdAt: date(20, hour: 12),
            emotionTag: "超市买菜和家用"
        )
        let generatedGathering = HomeItem(
            title: "餐饮记录",
            amount: 29,
            category: .dining,
            createdAt: date(21, hour: 12),
            emotionTag: "朋友小聚聚餐"
        )

        let marks = LifeMarkService.aggregates(
            for: [generatedSupply, generatedGathering],
            allItems: [generatedSupply, generatedGathering],
            isMember: true,
            limit: 12
        )

        XCTAssertFalse(marks.contains { $0.id == "daily_supply" || $0.id == "groceries" })
        XCTAssertFalse(marks.contains { $0.id == "social_care" || $0.id == "weekend_gathering" })
        XCTAssertNotEqual(LifeSceneSemanticService.classify(generatedSupply).kind, .groceries)
        XCTAssertNotEqual(LifeSceneSemanticService.classify(generatedGathering).kind, .social)
    }

    func testTrustedTitleBrandAndScenePackStillCreateFacts() {
        let groceries = HomeItem(
            title: "今天这一单",
            amount: 68,
            category: .daily,
            createdAt: date(20, hour: 18),
            merchantBrandId: "freshippo"
        )
        let social = HomeItem(
            title: "给朋友随礼",
            amount: 200,
            category: .social,
            createdAt: date(21, hour: 18)
        )
        let commute = HomeItem(
            title: "下班路上拍了张照片",
            amount: 5.70,
            category: .transport,
            createdAt: date(22)
        )

        let marks = LifeMarkService.aggregates(
            for: [groceries, social, commute],
            allItems: [groceries, social, commute],
            isMember: true,
            limit: 12
        )

        XCTAssertTrue(marks.contains { $0.id == "groceries" })
        XCTAssertTrue(marks.contains { $0.id == "social_care" })
        XCTAssertTrue(marks.contains { $0.id == "commute" })
        XCTAssertEqual(LifeSceneSemanticService.classify(commute).kind, .commute)
    }

    func testOCRTransitRouteUsesWorkdayHistoryInsteadOfExactAmount() {
        let history = [20, 21].map { day in
            HomeItem(
                title: "天隆寺1号口 > 雨山路",
                amount: day == 20 ? 4.75 : 5.20,
                category: .transport,
                createdAt: date(day),
                merchantBrandId: "metro_transit"
            )
        }

        XCTAssertEqual(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "天隆寺2号口 > 雨山路",
                rawText: "支付方式：金陵通交通卡\n地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(22),
                historyItems: history,
                calendar: calendar
            ),
            "commute"
        )
        XCTAssertNil(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "天隆寺2号口 > 雨山路",
                rawText: "地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(22),
                historyItems: Array(history.prefix(1)),
                calendar: calendar
            )
        )
    }

    func testExplicitCommuteWinsButSingleNonWorkdayTransitDoesNot() {
        XCTAssertEqual(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "下班路上坐地铁",
                rawText: "地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(22),
                historyItems: [],
                calendar: calendar
            ),
            "commute"
        )
        XCTAssertNil(
            OCRCommuteScenePolicy.inferredScenePackID(
                title: "天隆寺 > 雨山路",
                rawText: "地铁",
                merchantBrandID: "metro_transit",
                category: .transport,
                date: date(19),
                historyItems: [],
                calendar: calendar
            )
        )
    }
}

final class PhotoMemoryFactBindingTests: XCTestCase {
    private var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 22,
            hour: 20,
            minute: 43
        ))!
    }

    func testUnknownCoffeeAndRoutineTransitPhotosStayUnclassified() {
        let coffee = HomeItem(
            title: "可乐喝咖啡",
            amount: 18,
            category: .dining,
            createdAt: date,
            emotionTag: "体验现场",
            memoryImageData: Data([0x01])
        )
        let legacyTransit = HomeItem(
            title: "地铁刷卡",
            amount: 5.7,
            category: .transport,
            createdAt: date,
            emotionTag: "刷卡进站",
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .receipt,
            memoryAnchorSceneHint: .vehicleCare,
            memoryAnchorCaption: "这张图以后查起来更清楚。",
            memoryAnchorCreatedAt: date
        )

        XCTAssertNil(PhotoMemoryPromptPolicy.anchorReason(for: coffee))
        XCTAssertFalse(PhotoMemoryPromptPolicy.resolvedAnchorRole(for: coffee).isQualified)
        XCTAssertNil(PhotoMemoryPromptPolicy.anchorReason(for: legacyTransit))
        XCTAssertFalse(PhotoMemoryPromptPolicy.resolvedAnchorRole(for: legacyTransit).isQualified)
    }

    func testReceiptAndExperienceRolesRequireMatchingEvidence() {
        let vehiclePhoto = HomeItem(
            title: "停车费",
            amount: 20,
            category: .transport,
            createdAt: date,
            memoryImageData: Data([0x01])
        )
        let receiptPhoto = HomeItem(
            title: "停车费小票",
            amount: 20,
            category: .transport,
            createdAt: date,
            memoryImageData: Data([0x02])
        )
        let experiencePhoto = HomeItem(
            title: "看电影和展览",
            amount: 88,
            category: .entertainment,
            createdAt: date,
            memoryImageData: Data([0x03])
        )

        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: vehiclePhoto)?.assetRole, .object)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: vehiclePhoto)?.sceneHint, .vehicleCare)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: receiptPhoto)?.assetRole, .receipt)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: experiencePhoto)?.assetRole, .moment)
        XCTAssertEqual(PhotoMemoryPromptPolicy.anchorReason(for: experiencePhoto)?.sceneHint, .experience)
    }

    func testEditingReevaluatesAutomaticRoleButPreservesExplicitMetadata() {
        let automatic = HomeItem(
            title: "地铁刷卡",
            amount: 5.7,
            category: .transport,
            createdAt: date,
            memoryImageData: Data([0x01]),
            memoryAnchorRole: .receipt,
            memoryAnchorSceneHint: .vehicleCare,
            memoryAnchorCaption: "这张图以后查起来更清楚。",
            memoryAnchorCreatedAt: date
        )
        var ordinary = automatic
        ordinary.title = "可乐喝咖啡"
        ordinary.category = .dining
        let cleared = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
            original: automatic,
            updated: ordinary
        )
        XCTAssertNil(cleared.memoryAnchorRole)
        XCTAssertNil(cleared.memoryAnchorSceneHint)
        XCTAssertNil(cleared.memoryAnchorCaption)

        var movie = automatic
        movie.title = "下班后看电影"
        movie.category = .entertainment
        let reassigned = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
            original: automatic,
            updated: movie
        )
        XCTAssertEqual(reassigned.memoryAnchorRole, .moment)
        XCTAssertEqual(reassigned.memoryAnchorSceneHint, .experience)

        let explicit = HomeItem(
            title: "旅行记录",
            amount: 120,
            category: .lodging,
            createdAt: date,
            memoryImageData: Data([0x02]),
            memoryAnchorRole: .place,
            memoryAnchorSceneHint: .travel,
            memoryAnchorCaption: "我自己选的路上照片",
            memoryAnchorCreatedAt: date
        )
        var changed = explicit
        changed.title = "普通记录"
        changed.category = .other
        let preserved = PhotoMemoryPromptPolicy.refreshedAutomaticAnchorMetadata(
            original: explicit,
            updated: changed
        )
        XCTAssertEqual(preserved.memoryAnchorRole, .place)
        XCTAssertEqual(preserved.memoryAnchorSceneHint, .travel)
        XCTAssertEqual(preserved.memoryAnchorCaption, "我自己选的路上照片")
    }

    func testPrimaryPhotoCategoryAndClueEvidenceUseTheExactItemID() {
        let transport = HomeItem(
            title: "地铁",
            amount: 5,
            category: .transport,
            createdAt: date
        )
        let meal = HomeItem(
            title: "周记主图里的晚饭",
            amount: 36,
            category: .dining,
            createdAt: date,
            memoryImageData: Data([0x01])
        )
        let anchor = SummaryMemoryAnchor(
            id: meal.id,
            itemID: meal.id,
            title: meal.displayTitle,
            amount: meal.amount,
            createdAt: meal.createdAt,
            imageData: Data([0x01]),
            imageReference: nil,
            imageByteCount: 1,
            role: .moment,
            sceneHint: .gathering,
            label: "见面",
            caption: "和朋友的一次聚会。"
        )

        XCTAssertEqual(
            TracePhotoEvidenceBindingPolicy.primaryCategory(
                anchor: anchor,
                items: [transport, meal]
            ),
            .dining
        )
        XCTAssertEqual(
            TracePhotoEvidenceBindingPolicy.item(for: meal.id, in: [transport, meal])?.id,
            meal.id
        )
    }

    func testUnclassifiedPhotoInsightNamesTheRecordWithoutInventingAScene() {
        let item = HomeItem(
            title: "可乐喝咖啡",
            amount: 18,
            category: .dining,
            createdAt: date,
            emotionTag: "体验现场",
            memoryImageData: Data([0x01])
        )

        let insight = LifeInsightService().buildTraceInsight(
            items: [item],
            historyItems: [item],
            periodLabel: "本周",
            now: date
        )

        XCTAssertEqual(insight.highlightedItemID, item.id)
        XCTAssertTrue(insight.leadQuestion.contains(item.displayTitle))
        XCTAssertFalse(insight.leadQuestion.contains("现场"))
        XCTAssertTrue(insight.previewLine.contains(item.displayTitle))
    }
}

final class TrustedUserMomentNarrativeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 22,
            hour: 20,
            minute: 43
        ))!
    }

    private func commutePhoto() -> HomeItem {
        HomeItem(
            title: "下班路上拍了张照片",
            amount: 5.7,
            category: .transport,
            source: .manual,
            createdAt: now,
            emotionTag: "晚间一段路",
            userEditedTitle: true,
            scenePackId: "commute",
            memoryImageData: Data(repeating: 0x01, count: 800_000)
        )
    }

    func testDownWorkPhotoUsesTheRealMomentBeforeTheLateNightThreshold() {
        let narrative = TrustedUserMomentNarrativePolicy.narrative(for: commutePhoto())

        XCTAssertEqual(narrative?.line, "下班路上，也把这一刻留了下来。")
        XCTAssertEqual(narrative?.emotionTag, "下班路上，留住这一刻")
    }

    func testMomentProjectionRequiresManualUserTextAndAnActualPhoto() {
        var noPhoto = commutePhoto()
        noPhoto.memoryImageData = nil
        noPhoto.memoryImageDatas = []
        noPhoto.memoryImageReferences = []
        XCTAssertNil(TrustedUserMomentNarrativePolicy.line(for: noPhoto))

        var imported = commutePhoto()
        imported.source = .ocr
        imported.userEditedTitle = nil
        XCTAssertNil(TrustedUserMomentNarrativePolicy.line(for: imported))

        var defaultTitle = commutePhoto()
        defaultTitle.title = defaultTitle.category.defaultRecordTitle
        XCTAssertNil(TrustedUserMomentNarrativePolicy.line(for: defaultTitle))
    }

    func testTodayMomentOutranksStableCoffeeWithoutChangingLifeMarkPriority() {
        let moment = commutePhoto()
        let coffee = HomeItem(
            title: "瑞幸咖啡",
            amount: 18,
            category: .dining,
            createdAt: calendar.date(byAdding: .minute, value: -20, to: now)!,
            merchantBrandId: "luckin"
        )
        let key = HomeLifeMarkSnapshotKey(
            ledgerRevision: 12,
            dayKey: HomeDashboardSnapshotComputation.dayKey(for: now, calendar: calendar),
            isMember: true
        )

        let snapshot = HomeDashboardSnapshotComputation.lifeMarkSnapshot(
            HomeLifeMarkPreparationInput(
                key: key,
                visibleItems: [coffee, moment],
                weekItems: [coffee, moment],
                allItems: [coffee, moment],
                isMember: true,
                frequentSuggestionLine: nil
            )
        )

        XCTAssertEqual(snapshot.todayPrimaryLine, "下班路上，也把这一刻留了下来。")
        XCTAssertEqual(
            TrustedUserMomentNarrativePolicy.preferredNarrative(in: [coffee, moment])?.itemID,
            moment.id
        )
    }

    func testTrustedMomentBecomesTheNarrativeLeadInsteadOfRoutineCoffee() {
        let moment = commutePhoto()
        let coffee = HomeItem(
            title: "瑞幸咖啡",
            amount: 18,
            category: .dining,
            createdAt: calendar.date(byAdding: .minute, value: -20, to: now)!,
            merchantBrandId: "luckin"
        )
        let plan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: 13,
                items: [coffee, moment],
                previousItems: [coffee],
                now: now,
                recentLeadSignalIDs: ["scene:coffee"]
            )
        )

        XCTAssertEqual(plan.leadSignalID, "user:\(moment.id.uuidString)")
        XCTAssertEqual(plan.headline, "下班路上，也把这一刻留了下来")
    }

    func testPhotoAnchorUsesMomentCopyInsteadOfGenericUtilityCaption() {
        let moment = commutePhoto()
        let anchors = MemoryAnchorSelectionPolicy.selectAnchors(
            from: [moment],
            range: .week,
            limit: 1,
            label: { _, _ in "旧标签" },
            caption: { _, _ in "这张图以后查起来更清楚。" }
        )

        XCTAssertEqual(anchors.first?.itemID, moment.id)
        XCTAssertEqual(anchors.first?.label, "照片")
        XCTAssertEqual(anchors.first?.caption, "下班路上，也把这一刻留了下来。")
    }
}

@MainActor
final class TodayPlaybackContentSnapshotTests: XCTestCase {
    func testSnapshotFreezesTodayItemsMomentsAndDurationForPlayback() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 21
        ))!
        var items = [
            HomeItem(
                title: "早餐",
                amount: 12,
                category: .dining,
                createdAt: calendar.date(bySettingHour: 8, minute: 10, second: 0, of: now)!
            ),
            HomeItem(
                title: "午餐",
                amount: 28,
                category: .dining,
                createdAt: calendar.date(bySettingHour: 12, minute: 20, second: 0, of: now)!
            ),
            HomeItem(
                title: "下班地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: now)!
            ),
            HomeItem(
                title: "昨天",
                amount: 20,
                category: .other,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now)!
            )
        ]

        let first = BillPlaybackSheet.makeContentSnapshot(
            allItems: items,
            sourceRevision: 7,
            now: now,
            calendar: calendar
        )
        let second = BillPlaybackSheet.makeContentSnapshot(
            allItems: items,
            sourceRevision: 7,
            now: now,
            calendar: calendar
        )
        items.append(
            HomeItem(
                title: "夜宵",
                amount: 16,
                category: .dining,
                createdAt: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now)!
            )
        )

        XCTAssertEqual(first.sourceRevision, 7)
        XCTAssertEqual(first.todayItems.map(\.title), ["早餐", "午餐", "下班地铁"])
        XCTAssertEqual(first.playbackMoments, second.playbackMoments)
        XCTAssertEqual(first.playbackMoments.count, 4)
        XCTAssertEqual(first.playbackDuration, 10.4, accuracy: 0.001)
        XCTAssertEqual(first.todayItems.count, 3)
        XCTAssertEqual(first.narrativePlan?.sourceRevision, 7)
    }

    func testRepeatedCoffeeDoesNotSurroundTodayPlaybackButRemainsInItemCards() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 22
        ))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let previous = [8, 11, 14, 17].map { hour in
            HomeItem(
                title: "咖啡",
                amount: 16,
                category: .dining,
                createdAt: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: yesterday)!
            )
        }
        let current = [8, 11, 14, 17].map { hour in
            HomeItem(
                title: "咖啡",
                amount: 16,
                category: .dining,
                createdAt: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now)!
            )
        }

        let snapshot = BillPlaybackSheet.makeContentSnapshot(
            allItems: previous + current,
            sourceRevision: 21,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.playbackMoments.first?.id, "summary-opening")
        XCTAssertEqual(snapshot.playbackMoments.last?.id, "summary-close")
        XCTAssertFalse(snapshot.playbackMoments.first?.body.contains("咖啡") == true)
        XCTAssertFalse(snapshot.playbackMoments.last?.title.contains("咖啡") == true)
        XCTAssertFalse(snapshot.playbackMoments.last?.body.contains("咖啡") == true)
        XCTAssertTrue(snapshot.playbackMoments.dropFirst().dropLast().contains { $0.title.contains("咖啡") })
        XCTAssertTrue(snapshot.narrativePlan?.markLabels.contains("咖啡饮品") == true)
    }

    func testDenseSnapshotBuildsTimeBlocksOnceFromImmutableInput() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 22
        ))!
        let hours = [8, 9, 10, 12, 13, 14, 18, 19, 20]
        let items = hours.enumerated().map { index, hour in
            HomeItem(
                title: "记录 \(index)",
                amount: Double(index + 1),
                category: index.isMultiple(of: 2) ? .dining : .transport,
                createdAt: calendar.date(bySettingHour: hour, minute: index, second: 0, of: now)!
            )
        }

        let snapshot = BillPlaybackSheet.makeContentSnapshot(
            allItems: items,
            sourceRevision: 9,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.todayItems.count, 9)
        XCTAssertEqual(snapshot.playbackMoments.map(\.id), [
            "summary-opening",
            "time-morning",
            "time-afternoon",
            "time-evening",
            "summary-close"
        ])
        XCTAssertEqual(snapshot.playbackDuration, 13, accuracy: 0.001)
    }

    func testPresentationRequiresPreparedSnapshotAndOnlyAcceptsOneActivePayload() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 22
        ))!
        let item = HomeItem(title: "晚餐", amount: 28, category: .dining, createdAt: now)
        let prepared = TodayPlaybackPresentationPayload(contentSnapshot: BillPlaybackSheet.makeContentSnapshot(
            allItems: [item],
            sourceRevision: 11,
            now: now,
            calendar: calendar
        ))
        let unprepared = TodayPlaybackPresentationPayload(contentSnapshot: .empty)

        XCTAssertTrue(TodayPlaybackPresentationPolicy.accepts(prepared, while: nil))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.accepts(prepared, while: prepared))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.accepts(unprepared, while: nil))
        XCTAssertTrue(TodayPlaybackPresentationPolicy.consumesQuota(prepared))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.consumesQuota(unprepared))
    }

    func testValidEmptyDayCanPresentWithoutConsumingQuota() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 8
        ))!
        let payload = TodayPlaybackPresentationPayload(contentSnapshot: BillPlaybackSheet.makeContentSnapshot(
            allItems: [],
            sourceRevision: 12,
            now: now,
            calendar: calendar
        ))

        XCTAssertTrue(payload.contentSnapshot.isPrepared)
        XCTAssertTrue(TodayPlaybackPresentationPolicy.accepts(payload, while: nil))
        XCTAssertFalse(TodayPlaybackPresentationPolicy.consumesQuota(payload))
    }
}

final class LifetimeArchiveSnapshotComputationTests: XCTestCase {
    func testArchiveSnapshotUsesCommittedRecordsAndPreservesExistingCopyRules() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 12
        ))!
        let items = [
            HomeItem(
                title: "今天午餐",
                amount: 28,
                category: .dining,
                createdAt: now
            ),
            HomeItem(
                title: "昨天午餐",
                amount: 26,
                category: .dining,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now)!
            ),
            HomeItem(
                title: "上月地铁",
                amount: 3,
                category: .transport,
                createdAt: calendar.date(byAdding: .month, value: -1, to: now)!
            ),
            HomeItem(
                title: "待整理草稿",
                amount: 88,
                category: .other,
                createdAt: now,
                draftMeta: .init(batchId: "archive-qa", importedAt: now, status: .pending)
            )
        ]
        let input = LifetimeArchivePreparationInput(
            revision: 12,
            items: items,
            now: now,
            calendar: calendar
        )

        let first = LifetimeArchiveSnapshotComputation.make(input)
        let second = LifetimeArchiveSnapshotComputation.make(input)

        XCTAssertEqual(first.sourceRevision, 12)
        XCTAssertTrue(first.proofLine.contains("3 笔记录"))
        XCTAssertTrue(first.proofLine.contains("2 个月"))
        XCTAssertEqual(first.metrics[1].value, "3条")
        XCTAssertEqual(first.metrics[3].value, "2个月")
        XCTAssertEqual(first.title, second.title)
        XCTAssertEqual(first.subtitle, second.subtitle)
        XCTAssertEqual(first.metrics.map(\.value), second.metrics.map(\.value))
        XCTAssertEqual(first.stages.map(\.value), second.stages.map(\.value))
        XCTAssertEqual(first.primaryLine, second.primaryLine)
        XCTAssertEqual(first.closingLine, second.closingLine)
    }

    func testArchiveEmptySnapshotDoesNotRequireLedgerScanningInViewBody() {
        let snapshot = LifetimeArchiveSnapshotComputation.make(
            LifetimeArchivePreparationInput(
                revision: 2,
                items: [],
                now: Date(timeIntervalSince1970: 1_784_240_000),
                calendar: Calendar(identifier: .gregorian)
            )
        )

        XCTAssertEqual(snapshot.sourceRevision, 2)
        XCTAssertEqual(snapshot.metrics[1].value, "0条")
        XCTAssertEqual(snapshot.proofLine, "先从第一笔开始，后面会自动整理出周记和月章。")
    }

    func testArchiveDiskCacheSurvivesRecreationAndRejectsAnotherLedgerOrDay() {
        let suiteName = "LifetimeArchiveSnapshotComputationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "archive-test"
        let context = LifetimeArchiveCacheContext(
            ledgerFingerprint: "ledger-a",
            dayKey: "2026-07-23"
        )
        let snapshot = LifetimeArchiveSnapshot.preparedEmpty(sourceRevision: 3)
        LifetimeArchiveCacheStore(defaults: defaults, storageKey: storageKey).store(
            snapshot,
            context: context
        )

        let relaunched = LifetimeArchiveCacheStore(
            defaults: defaults,
            storageKey: storageKey
        )
        XCTAssertEqual(relaunched.snapshot(for: context), snapshot)
        XCTAssertNil(
            relaunched.snapshot(
                for: LifetimeArchiveCacheContext(
                    ledgerFingerprint: "ledger-b",
                    dayKey: context.dayKey
                )
            )
        )
        XCTAssertNil(
            relaunched.snapshot(
                for: LifetimeArchiveCacheContext(
                    ledgerFingerprint: context.ledgerFingerprint,
                    dayKey: "2026-07-24"
                )
            )
        )

        defaults.set(Data([0xFF]), forKey: storageKey)
        XCTAssertNil(relaunched.snapshot(for: context))
        XCTAssertNil(defaults.data(forKey: storageKey))
    }

    @MainActor
    func testSharedArchiveStorePublishesARealPreparedEmptySnapshot() async {
        let suiteName = "LifetimeArchiveSnapshotStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LifetimeArchiveSnapshotStore(
            cacheStore: LifetimeArchiveCacheStore(
                defaults: defaults,
                storageKey: "archive-store-test"
            )
        )
        store.prepareIfNeeded(
            revision: 7,
            items: [],
            now: Date(timeIntervalSince1970: 1_790_000_000),
            calendar: Calendar(identifier: .gregorian)
        )
        for _ in 0..<50 where store.snapshot == nil {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        XCTAssertEqual(store.snapshot?.sourceRevision, 7)
        XCTAssertEqual(store.snapshot?.metrics[1].value, "0条")
        XCTAssertFalse(store.isPreparing)
    }
}

final class AccountMemoryStatsComputationTests: XCTestCase {
    func testAccountStatsReuseOneLedgerRevisionSnapshot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let base = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 1,
            hour: 12
        ))!
        var items = [0, 1, 2, 9].map { dayOffset in
            HomeItem(
                title: "记录 \(dayOffset)",
                amount: Double(dayOffset + 1),
                category: .other,
                createdAt: calendar.date(byAdding: .day, value: dayOffset, to: base)!
            )
        }
        items.append(
            HomeItem(
                title: "上月记录",
                amount: 20,
                category: .dining,
                createdAt: calendar.date(byAdding: .month, value: -1, to: base)!
            )
        )
        items.append(
            HomeItem(
                title: "零金额",
                amount: 0,
                category: .other,
                createdAt: base
            )
        )

        let input = AccountMemoryStatsPreparationInput(
            items: items,
            sourceRevision: 18,
            calendar: calendar
        )
        let first = AccountMemoryStatsComputation.make(input)
        let second = AccountMemoryStatsComputation.make(input)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.sourceRevision, 18)
        XCTAssertEqual(first.traceCount, 5)
        XCTAssertEqual(first.recordStreakDays, 3)
        XCTAssertEqual(first.weeklyStoryCount, 3)
        XCTAssertEqual(first.monthlyStoryCount, 2)
    }

    func testAccountStatsEmptySnapshotKeepsZeroValues() {
        let stats = AccountMemoryStatsComputation.make(
            items: [],
            sourceRevision: 3,
            calendar: Calendar(identifier: .gregorian)
        )

        XCTAssertEqual(stats.sourceRevision, 3)
        XCTAssertEqual(stats.traceCount, 0)
        XCTAssertEqual(stats.recordStreakDays, 0)
        XCTAssertEqual(stats.weeklyStoryCount, 0)
        XCTAssertEqual(stats.monthlyStoryCount, 0)
    }
}

final class TraceDetailListSnapshotComputationTests: XCTestCase {
    func testDetailSnapshotSharesItemsIDsTotalAndDayGroupsFromOneFilterPass() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        let start = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 1
        ))!
        let end = calendar.date(byAdding: .day, value: 3, to: start)!
        let diningMorning = HomeItem(
            title: "早餐",
            amount: 12,
            category: .dining,
            createdAt: calendar.date(byAdding: .hour, value: 8, to: start)!
        )
        let diningNextDay = HomeItem(
            title: "午餐",
            amount: 28,
            category: .dining,
            createdAt: calendar.date(byAdding: .hour, value: 36, to: start)!
        )
        let zeroDining = HomeItem(
            title: "零金额",
            amount: 0,
            category: .dining,
            createdAt: calendar.date(byAdding: .hour, value: 37, to: start)!
        )
        let transport = HomeItem(
            title: "地铁",
            amount: 3,
            category: .transport,
            createdAt: calendar.date(byAdding: .hour, value: 12, to: start)!
        )
        let outside = HomeItem(
            title: "范围外",
            amount: 50,
            category: .dining,
            createdAt: calendar.date(byAdding: .day, value: 5, to: start)!
        )
        let key = TraceDetailListSnapshotKey(
            ledgerRevision: 4,
            periodKey: "本月",
            categoryKey: HomeItem.Category.dining.rawValue,
            usesCustomRange: true,
            customStartDate: start,
            customEndDate: calendar.date(byAdding: .day, value: 2, to: start)!
        )
        let input = TraceDetailListPreparationInput(
            key: key,
            sourceItems: [outside, diningMorning, transport, zeroDining, diningNextDay],
            dateInterval: DateInterval(start: start, end: end),
            category: .dining,
            calendar: calendar
        )

        let first = TraceDetailListSnapshotComputation.make(input)
        let second = TraceDetailListSnapshotComputation.make(input)

        XCTAssertEqual(first.key, key)
        XCTAssertEqual(first.items.map(\.title), ["零金额", "午餐", "早餐"])
        XCTAssertEqual(first.itemIDs, first.items.map(\.id))
        XCTAssertEqual(first.totalExpense, 40, accuracy: 0.001)
        XCTAssertEqual(first.dayGroups.count, 2)
        XCTAssertEqual(first.dayGroups.first?.items.map(\.title) ?? [], ["零金额", "午餐"])
        XCTAssertEqual(first.items.map(\.id), second.items.map(\.id))
        XCTAssertEqual(first.dayGroups.map(\.id), second.dayGroups.map(\.id))
    }

    func testDetailSnapshotKeyChangesOnlyForLedgerOrFilterInput() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let first = TraceDetailListSnapshotKey(
            ledgerRevision: 2,
            periodKey: "本周",
            categoryKey: nil,
            usesCustomRange: false,
            customStartDate: date,
            customEndDate: date
        )

        XCTAssertEqual(first, first)
        XCTAssertNotEqual(first, TraceDetailListSnapshotKey(
            ledgerRevision: 3,
            periodKey: first.periodKey,
            categoryKey: first.categoryKey,
            usesCustomRange: first.usesCustomRange,
            customStartDate: first.customStartDate,
            customEndDate: first.customEndDate
        ))
        XCTAssertNotEqual(first, TraceDetailListSnapshotKey(
            ledgerRevision: first.ledgerRevision,
            periodKey: first.periodKey,
            categoryKey: HomeItem.Category.dining.rawValue,
            usesCustomRange: first.usesCustomRange,
            customStartDate: first.customStartDate,
            customEndDate: first.customEndDate
        ))
    }

    func testPresentationCarriesInitialSnapshotAndRejectsDuplicateSheetRequest() {
        let date = Date(timeIntervalSince1970: 1_784_240_000)
        let key = TraceDetailListSnapshotKey(
            ledgerRevision: 2,
            periodKey: "本周",
            categoryKey: nil,
            usesCustomRange: false,
            customStartDate: date,
            customEndDate: date
        )
        let item = HomeItem(title: "午餐", amount: 28, category: .dining, createdAt: date)
        let snapshot = TraceDetailListSnapshot(
            key: key,
            items: [item],
            itemIDs: [item.id],
            totalExpense: 28,
            dayGroups: [TraceDayGroup(id: "day", date: date, items: [item])]
        )
        let payload = TraceDetailPresentationPayload(initialSnapshot: snapshot)

        XCTAssertTrue(TraceDetailPresentationPolicy.accepts(payload, while: nil))
        XCTAssertFalse(TraceDetailPresentationPolicy.accepts(payload, while: payload))
        XCTAssertEqual(payload.initialSnapshot.items.map(\.id), [item.id])
        XCTAssertEqual(payload.initialSnapshot.totalExpense, 28, accuracy: 0.001)
    }
}

final class TraceChapterCoverPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        ))!
    }

    private func anchor(for item: HomeItem, id: UUID = UUID()) -> SummaryMemoryAnchor {
        SummaryMemoryAnchor(
            id: id,
            itemID: item.id,
            title: item.title,
            amount: item.amount,
            createdAt: item.createdAt,
            imageData: Data([1, 2, 3]),
            imageReference: "images/\(item.id.uuidString).jpg",
            imageByteCount: 3,
            role: .moment,
            sceneHint: .experience,
            label: "现场",
            caption: "这条记录的照片。"
        )
    }

    func testWeekCoverUsesRepresentativePhotoRecordAndFactualSupport() {
        let dining = HomeItem(
            title: "巧婆红汤馄饨（云密城店）",
            amount: 18,
            category: .dining,
            createdAt: date(day: 15, hour: 19)
        )
        let morningCommute = HomeItem(
            title: "上班地铁",
            amount: 4.75,
            category: .transport,
            createdAt: date(day: 16, hour: 8)
        )
        let eveningCommute = HomeItem(
            title: "下班地铁",
            amount: 4.75,
            category: .transport,
            createdAt: date(day: 16, hour: 19)
        )
        let photoAnchor = anchor(for: dining)

        let facts = TraceChapterCoverPolicy.make(
            range: .week,
            items: [eveningCommute, morningCommute, dining],
            anchors: [photoAnchor],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.title, "7月15日，巧婆红汤馄饨")
        XCTAssertEqual(facts.supportLine, "3笔记录分布在2天，交通最多，共2笔。")
        XCTAssertEqual(facts.representativeItemID, dining.id)
        XCTAssertEqual(facts.coverCaption, "7/15 · 巧婆红汤馄饨")
        XCTAssertNil(facts.coverAnchorID)
        XCTAssertFalse(facts.title.contains("被留下"))
    }

    func testMonthCoverExplainsCountShareAndBuildsRecordRhythm() {
        let commute1 = HomeItem(title: "上班地铁", amount: 4, category: .transport, createdAt: date(day: 1, hour: 8))
        let commute2 = HomeItem(title: "下班地铁", amount: 4, category: .transport, createdAt: date(day: 2, hour: 18))
        let commute3 = HomeItem(title: "上班公交", amount: 3, category: .transport, createdAt: date(day: 3, hour: 8))
        let breakfast = HomeItem(title: "早餐", amount: 12, category: .dining, createdAt: date(day: 10, hour: 8))
        let dinner = HomeItem(title: "晚饭", amount: 28, category: .dining, createdAt: date(day: 10, hour: 19))
        let coverAnchor = anchor(for: breakfast)

        let facts = TraceChapterCoverPolicy.make(
            range: .month,
            items: [dinner, breakfast, commute3, commute2, commute1],
            anchors: [coverAnchor],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.title, "7月，交通出现得最多")
        XCTAssertEqual(facts.supportLine, "5笔记录分布在4天，交通共3笔，占本月记录60%。")
        XCTAssertEqual(facts.activeDays, 4)
        XCTAssertEqual(facts.longestStreak, 3)
        XCTAssertEqual(facts.topCategory, .transport)
        XCTAssertEqual(facts.topCategoryRecordSharePercent, 60)
        XCTAssertEqual(facts.coverAnchorID, coverAnchor.id)
        XCTAssertEqual(facts.coverItemID, breakfast.id)
        XCTAssertEqual(facts.monthDayCounts.count, 31)
        XCTAssertEqual(facts.monthDayCounts[9], 2)
        XCTAssertEqual(facts.currentMonthDay, 18)
    }

    func testMonthWithoutPhotoUsesValidEmptyRhythmInsteadOfPhotoPlaceholder() {
        let facts = TraceChapterCoverPolicy.make(
            range: .month,
            items: [],
            anchors: [],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.title, "7月还没有记录")
        XCTAssertEqual(facts.supportLine, "记下第一笔后，这里会按日期和分类整理。")
        XCTAssertNil(facts.coverAnchorID)
        XCTAssertNil(facts.coverCaption)
        XCTAssertEqual(facts.monthDayCounts, Array(repeating: 0, count: 31))
        XCTAssertEqual(facts.activeDays, 0)
        XCTAssertEqual(facts.longestStreak, 0)
    }

    func testTopCategoryTieUsesAmountThenStableCategoryOrder() {
        let items = [
            HomeItem(title: "早餐", amount: 8, category: .dining, createdAt: date(day: 1, hour: 8)),
            HomeItem(title: "晚饭", amount: 12, category: .dining, createdAt: date(day: 2, hour: 19)),
            HomeItem(title: "上班地铁", amount: 18, category: .transport, createdAt: date(day: 3, hour: 8)),
            HomeItem(title: "下班地铁", amount: 18, category: .transport, createdAt: date(day: 4, hour: 19))
        ]

        let facts = TraceChapterCoverPolicy.make(
            range: .month,
            items: items,
            anchors: [],
            now: date(day: 18),
            calendar: calendar
        )

        XCTAssertEqual(facts.topCategory, .transport)
        XCTAssertEqual(facts.title, "7月，交通出现得最多")
        XCTAssertEqual(facts.topCategoryCount, 2)
        XCTAssertEqual(facts.topCategoryRecordSharePercent, 50)
    }

    func testMonthDiaryExcludesEveryAnchorFromTheCoverRecord() {
        let coverItem = HomeItem(title: "早餐", amount: 12, category: .dining, createdAt: date(day: 10))
        let otherItem = HomeItem(title: "地铁", amount: 4, category: .transport, createdAt: date(day: 11))
        let cover = anchor(for: coverItem)
        let duplicateCover = anchor(for: coverItem)
        let other = anchor(for: otherItem)

        let diaryAnchors = TraceMonthDiaryPolicy.anchors(
            from: [cover, duplicateCover, other],
            excludingCoverItemID: coverItem.id
        )

        XCTAssertEqual(diaryAnchors.map(\.id), [other.id])
    }
}

final class WeeklyShareCardPhotoPreparationPolicyTests: XCTestCase {
    func testResolutionKeepsSourceOrderAndCountsOnlyDecodedPhotos() {
        let first = UUID()
        let missing = UUID()
        let third = UUID()
        let ignoredFourth = UUID()

        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: [first, missing, third, ignoredFourth],
            loadedAnchorIDs: [third, first, ignoredFourth]
        )

        XCTAssertEqual(resolution.availableAnchorIDs, [first, third])
        XCTAssertEqual(resolution.unavailablePhotoCount, 1)
    }

    func testResolutionDowngradesAllMissingPhotosWithoutInventingAvailability() {
        let requested = [UUID(), UUID(), UUID()]

        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: requested,
            loadedAnchorIDs: []
        )

        XCTAssertTrue(resolution.availableAnchorIDs.isEmpty)
        XCTAssertEqual(resolution.unavailablePhotoCount, 3)
    }

    func testResolutionIgnoresLoadedIDsOutsideTheLockedRequest() {
        let requested = UUID()

        let resolution = WeeklyShareCardPhotoPreparationPolicy.resolve(
            requestedAnchorIDs: [requested],
            loadedAnchorIDs: [UUID()]
        )

        XCTAssertTrue(resolution.availableAnchorIDs.isEmpty)
        XCTAssertEqual(resolution.unavailablePhotoCount, 1)
    }
}

final class WeeklyShareCardTemplateCapabilityPolicyTests: XCTestCase {
    func testAutomaticTemplateFollowsTheNumberOfActuallyAvailablePhotos() {
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 0),
            .recordSummary
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 1),
            .singleMemory
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 2),
            .weeklyCollage
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.recommended(photoCount: 8),
            .weeklyCollage
        )
    }

    func testEveryAvailablePhotoCountGetsThreeSafeBuiltInLayouts() {
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 0),
            [.recordSummary, .recordJournal, .recordMagazine]
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 1),
            [.singleMemory, .recordJournal, .recordSummary]
        )
        XCTAssertEqual(
            WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 3),
            [.weeklyCollage, .recordMagazine, .recordSummary]
        )
        XCTAssertEqual(WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 2).count, 3)
        XCTAssertEqual(WeeklyShareCardTemplateCapabilityPolicy.allowed(photoCount: 8).count, 3)
    }

    func testSensitivePhotoCaptionsStayCategoryNeutralInTheShareCard() {
        let healthAnchor = SummaryMemoryAnchor(
            id: UUID(),
            itemID: UUID(),
            title: "某医院复诊",
            amount: 100,
            createdAt: Date(),
            imageData: Data(),
            imageReference: nil,
            imageByteCount: nil,
            role: .careRecord,
            sceneHint: .healthRecord,
            label: "健康",
            caption: "具体检查结果"
        )
        let careAnchor = SummaryMemoryAnchor(
            id: UUID(),
            itemID: UUID(),
            title: "家人用药",
            amount: 30,
            createdAt: Date(),
            imageData: Data(),
            imageReference: nil,
            imageByteCount: nil,
            role: .careRecord,
            sceneHint: .careRecord,
            label: "照护",
            caption: "具体用药内容"
        )

        XCTAssertEqual(
            lifeSliceSafeSharePhotoCaption(for: healthAnchor, fallback: "记录"),
            "一条健康记录"
        )
        XCTAssertEqual(
            lifeSliceSafeSharePhotoCaption(for: careAnchor, fallback: "记录"),
            "一条照护记录"
        )
    }
}

#if canImport(UIKit)
final class ShareBackgroundDecodedImageTests: XCTestCase {
    func testNormalizedShareBackgroundReturnsDataAndReusableDecodedImage() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40), format: format)
        let source = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        }
        let sourceData = source.pngData()!

        guard let normalized = normalizedShareBackground(sourceData) else {
            XCTFail("Expected normalized background")
            return
        }

        XCTAssertFalse(normalized.data.isEmpty)
        XCTAssertEqual(normalized.image.size.width, 80, accuracy: 0.5)
        XCTAssertEqual(normalized.image.size.height, 40, accuracy: 0.5)
    }

    func testNormalizedShareBackgroundDownsamplesLargeImageOnce() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000), format: format)
        let source = renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1000))
        }
        let sourceData = source.jpegData(compressionQuality: 0.9)!

        guard let normalized = normalizedShareBackground(sourceData) else {
            XCTFail("Expected downsampled background")
            return
        }

        XCTAssertEqual(normalized.image.size.width, 1600, accuracy: 1)
        XCTAssertEqual(normalized.image.size.height, 800, accuracy: 1)
        XCTAssertNotNil(UIImage(data: normalized.data))
    }
}
#endif

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

    func testAICommandSuggestionsPrepareAllTasksFromOneImmutableSnapshot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
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
            HomeItem(title: "今天午餐", amount: 28, category: .dining, createdAt: date(16, 12)),
            HomeItem(title: "昨天晚餐", amount: 32, category: .dining, createdAt: date(15, 18)),
            HomeItem(title: "前七天早餐", amount: 18, category: .dining, createdAt: date(9, 8)),
            HomeItem(
                title: "早高峰地铁",
                amount: 6,
                category: .transport,
                createdAt: date(15, 8),
                memoryContext: HomeItem.MemoryContext(
                    weatherKind: "rain",
                    temperatureCelsius: 25,
                    cityName: nil,
                    semanticPlace: nil
                )
            ),
            HomeItem(title: "晚高峰公交", amount: 4, category: .transport, createdAt: date(14, 18)),
        ]
        let input = AICommandSuggestionPreparationInput(
            items: items,
            isMember: true,
            now: now,
            weatherKind: "rain"
        )

        let first = InsightComputationService.aiCommandSuggestions(input)
        let second = InsightComputationService.aiCommandSuggestions(input)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.query.contains("上一次雨天通勤是什么时候？"))
        XCTAssertTrue(first.compare.contains("最近 7 天餐饮和前 7 天比呢？"))
        XCTAssertTrue(first.backfill.contains("补记过去一周工作日通勤，早晚各一次"))
        XCTAssertLessThanOrEqual(first.query.count, 3)
        XCTAssertLessThanOrEqual(first.compare.count, 3)
        XCTAssertLessThanOrEqual(first.backfill.count, 3)
    }

    func testAICommandSuggestionFallbacksStayNeutralAndAllowNoBackfill() {
        let forbiddenAssumptions = ["通勤", "上班", "交通", "餐饮", "兴趣", "爱好"]
        for task in [ReviewTaskIntent.query, ReviewTaskIntent.compare] {
            let fallbacks = AICommandSuggestionSnapshot.fallbacks(for: task)
            XCTAssertFalse(fallbacks.isEmpty)
            XCTAssertLessThanOrEqual(fallbacks.count, 3)
            for fallback in fallbacks {
                XCTAssertFalse(
                    forbiddenAssumptions.contains(where: { fallback.contains($0) }),
                    "Unexpected lifestyle assumption in fallback: \(fallback)"
                )
            }
        }
        XCTAssertTrue(AICommandSuggestionSnapshot.fallbacks(for: .backfill).isEmpty)
    }

    func testEmptyAndParkingOnlyLedgersDoNotInventCommuteRecommendations() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        let inputs = [
            AICommandSuggestionPreparationInput(
                items: [],
                isMember: true,
                now: now,
                weatherKind: "rain"
            ),
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(
                        title: "停车费",
                        amount: 6,
                        category: .transport,
                        createdAt: now.addingTimeInterval(-3_600)
                    )
                ],
                isMember: true,
                now: now,
                weatherKind: "rain"
            )
        ]

        for input in inputs {
            let snapshot = InsightComputationService.aiCommandSuggestions(input)
            XCTAssertTrue(snapshot.backfill.isEmpty)
            XCTAssertFalse(snapshot.query.contains(where: { $0.contains("雨天通勤") }))
            XCTAssertFalse(snapshot.compare.contains(where: {
                $0.contains("交通") || $0.contains("通勤")
            }))
        }
    }

    func testRepeatedRealCategoryEvidenceProducesFocusedSuggestionsOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
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
        let snapshot = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(title: "午餐", amount: 30, category: .dining, createdAt: date(16, 12)),
                    HomeItem(title: "晚餐", amount: 24, category: .dining, createdAt: date(15, 18)),
                    HomeItem(title: "前七天早餐", amount: 16, category: .dining, createdAt: date(9, 8)),
                ],
                isMember: true,
                now: now,
                weatherKind: nil
            )
        )

        XCTAssertTrue(snapshot.query.contains("看看最近 7 天餐饮记录"))
        XCTAssertTrue(snapshot.compare.contains("最近 7 天餐饮和前 7 天比呢？"))
        XCTAssertFalse(snapshot.compare.contains(where: {
            $0.contains("交通") || $0.contains("通勤")
        }))
        XCTAssertTrue(snapshot.backfill.isEmpty)
    }

    func testStrongCommuteEvidenceNeedsTwoDatesBeforeSuggestingBackfill() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
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
        let sameDay = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(title: "上班地铁", amount: 6, category: .transport, createdAt: date(15, 8)),
                    HomeItem(title: "下班公交", amount: 5, category: .transport, createdAt: date(15, 18)),
                ],
                isMember: true,
                now: now,
                weatherKind: nil
            )
        )
        let twoDates = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [
                    HomeItem(title: "上班地铁", amount: 6, category: .transport, createdAt: date(15, 8)),
                    HomeItem(title: "晚高峰公交", amount: 5, category: .transport, createdAt: date(14, 18)),
                ],
                isMember: true,
                now: now,
                weatherKind: nil
            )
        )

        XCTAssertTrue(sameDay.backfill.isEmpty)
        XCTAssertEqual(twoDates.backfill, ["补记过去一周工作日通勤，早晚各一次"])
    }

    func testCurrentRainNeedsAnActualHistoricalRainyCommuteForLookup() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 16,
            hour: 19
        ))!
        let dryCommute = HomeItem(
            title: "上班地铁",
            amount: 6,
            category: .transport,
            createdAt: now.addingTimeInterval(-86_400)
        )
        let snapshot = InsightComputationService.aiCommandSuggestions(
            AICommandSuggestionPreparationInput(
                items: [dryCommute],
                isMember: true,
                now: now,
                weatherKind: "rain"
            )
        )

        XCTAssertFalse(snapshot.query.contains("上一次雨天通勤是什么时候？"))
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

    func testOmittedComparisonSubjectDefaultsToTheCurrentWeekOrMonth() {
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

        func digest(_ command: String) -> String {
            InsightWebView.aiCommandComputationDigestForTesting(
                command: command,
                items: [],
                hasMemberAccess: true,
                now: now,
                reviewTaskIntent: .compare
            )
        }

        for command in ["对比上周", "和上周比", "比比上周", "这周对比上周"] {
            XCTAssertTrue(digest(command).hasPrefix("compare#本周 对比 上周同期#"), command)
        }
        XCTAssertTrue(digest("对比上月").hasPrefix("compare#本月 对比 上月同期#"))
        XCTAssertTrue(digest("本月对比上月").hasPrefix("compare#本月 对比 上月同期#"))
    }

    func testExplicitHistoricalComparisonAndHistoricalQueryKeepTheirLiteralPeriods() {
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

        func digest(_ command: String, task: ReviewTaskIntent = .compare) -> String {
            InsightWebView.aiCommandComputationDigestForTesting(
                command: command,
                items: [],
                hasMemberAccess: true,
                now: now,
                reviewTaskIntent: task
            )
        }

        XCTAssertTrue(digest("上周对比前一周").hasPrefix("compare#上周 对比 前一周#"))
        XCTAssertTrue(digest("比较上周和前一周").hasPrefix("compare#上周 对比 前一周#"))
        XCTAssertTrue(digest("上月对比前一个月").hasPrefix("compare#上个月 对比 前一个月#"))
        XCTAssertTrue(digest("查上周记录", task: .query).hasPrefix("query#"))
        XCTAssertTrue(digest("查上月记录", task: .query).hasPrefix("query#"))
    }

    func testRollingSevenDayComparisonCommandUsesThePreviousSevenDays() {
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
        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "对比最近 7 天和前 7 天的消费",
            items: [
                HomeItem(title: "最近午餐", amount: 20, category: .dining, createdAt: date(16, 12)),
                HomeItem(title: "前段午餐", amount: 10, category: .dining, createdAt: date(9, 12)),
            ],
            hasMemberAccess: true,
            now: now,
            reviewTaskIntent: .compare
        )

        XCTAssertTrue(digest.hasPrefix("compare#最近 7 天 对比 前 7 天#"))
        XCTAssertTrue(digest.contains("最近 7 天:20.0:1"))
        XCTAssertTrue(digest.contains("前 7 天:10.0:1"))
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

    func testMatchedRollingDayPeriodsResolveCompareFromAQueryTask() {
        let arabic = digest("最近 7 天餐饮和前 7 天比呢")
        let chinese = digest("最近七天餐饮跟前七天相比")

        XCTAssertTrue(arabic.hasPrefix("compare#"))
        XCTAssertTrue(arabic.contains("action:compare"))
        XCTAssertTrue(chinese.hasPrefix("compare#"))
        XCTAssertEqual(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "最近 7 天餐饮和前 7 天比呢",
                now: now,
                reviewTaskIntent: .query
            ),
            .compare
        )
    }

    func testFinalRecognitionOwnsTaskStateInsteadOfThePreviousSelection() {
        XCTAssertEqual(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "最近 7 天餐饮和前 7 天比呢",
                now: now,
                reviewTaskIntent: .query
            ),
            .compare
        )
        XCTAssertEqual(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "查一下最近 7 天餐饮记录",
                now: now,
                reviewTaskIntent: .compare
            ),
            .query
        )
        XCTAssertNil(
            InsightWebView.aiCommandResolvedReviewTaskForTesting(
                command: "老板今天心情怎么样",
                now: now,
                reviewTaskIntent: .compare
            )
        )
        XCTAssertEqual(ReviewTaskIntent.compare.presetCommand, "对比最近 7 天和前 7 天的消费")
    }

    func testRollingDayComparisonUsesCurrentAndImmediatelyPreviousWindows() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let current = HomeItem(
            title: "午餐",
            amount: 20,
            category: .dining,
            createdAt: calendar.date(byAdding: .day, value: -1, to: today)!
        )
        let previous = HomeItem(
            title: "晚餐",
            amount: 10,
            category: .dining,
            createdAt: calendar.date(byAdding: .day, value: -8, to: today)!
        )

        let computation = InsightWebView.aiCommandComputationDigestForTesting(
            command: "最近 7 天餐饮和前 7 天比呢",
            items: [current, previous],
            hasMemberAccess: true,
            now: now,
            reviewTaskIntent: .query
        )

        XCTAssertTrue(computation.hasPrefix("compare#"))
        XCTAssertTrue(computation.contains("最近 7 天"))
        XCTAssertTrue(computation.contains("前 7 天"))
    }

    func testYearPhrasesResolveAsExplicitQueryRanges() {
        XCTAssertTrue(digest("过去一年餐饮花了多少").hasPrefix("query#"))
        XCTAssertTrue(digest("近一年交通记录").hasPrefix("query#"))
        XCTAssertTrue(digest("最近一年购物记录").hasPrefix("query#"))
        XCTAssertTrue(digest("今年餐饮花了多少").hasPrefix("query#"))
        XCTAssertTrue(digest("去年交通花了多少").hasPrefix("query#"))
    }

    func testRollingAndNaturalYearRangesUseTheirOwnCalendarBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            ))!
        }

        let now = date(2026, 7, 23)
        let rollingBoundary = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!,
            title: "滚动年边界内",
            amount: 71,
            category: .dining,
            createdAt: date(2025, 7, 24, 0)
        )
        let beforeRollingBoundary = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!,
            title: "滚动年边界外",
            amount: 72,
            category: .dining,
            createdAt: date(2025, 7, 23, 23)
        )
        let currentYear = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!,
            title: "今年第一天",
            amount: 73,
            category: .dining,
            createdAt: date(2026, 1, 1, 0)
        )
        let previousYear = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000074")!,
            title: "去年最后一天",
            amount: 74,
            category: .dining,
            createdAt: date(2025, 12, 31, 23)
        )

        let items = [rollingBoundary, beforeRollingBoundary, currentYear, previousYear]
        let rolling = InsightWebView.aiCommandComputationDigestForTesting(
            command: "过去一年餐饮记录",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        let thisYear = InsightWebView.aiCommandComputationDigestForTesting(
            command: "今年餐饮记录",
            items: items,
            hasMemberAccess: true,
            now: now
        )
        let lastYear = InsightWebView.aiCommandComputationDigestForTesting(
            command: "去年餐饮记录",
            items: items,
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(rolling.hasPrefix("query#最近一年的餐饮记录#"))
        XCTAssertTrue(rolling.contains(rollingBoundary.id.uuidString))
        XCTAssertFalse(rolling.contains(beforeRollingBoundary.id.uuidString))
        XCTAssertTrue(thisYear.hasPrefix("query#今年的餐饮记录#"))
        XCTAssertTrue(thisYear.contains(currentYear.id.uuidString))
        XCTAssertFalse(thisYear.contains(previousYear.id.uuidString))
        XCTAssertTrue(lastYear.hasPrefix("query#去年的餐饮记录#"))
        XCTAssertTrue(lastYear.contains(previousYear.id.uuidString))
        XCTAssertFalse(lastYear.contains(currentYear.id.uuidString))
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

final class AICommandTrustedSemanticFacetTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 20
        ))!
    }

    private func date(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: hour
        ))!
    }

    private func recognition(_ command: String, task: ReviewTaskIntent = .query) -> String {
        InsightWebView.aiCommandRecognitionDigestForTesting(
            command: command,
            now: now,
            reviewTaskIntent: task
        )
    }

    func testQueryTaskAcceptsTrustedWeatherCommuteNounPhrases() {
        for command in ["高温通勤", "热天通勤", "酷热天上班"] {
            let digest = recognition(command)
            XCTAssertTrue(digest.hasPrefix("query#"), command)
            XCTAssertTrue(digest.contains("#hot_commute#"), command)
            XCTAssertTrue(digest.contains("action:nounQuery"), command)
        }

        XCTAssertTrue(recognition("冷天通勤").contains("#cold_commute#"))
        XCTAssertTrue(recognition("雨天通勤").contains("#rainy_commute#"))
        XCTAssertTrue(recognition("雪天通勤").contains("#snowy_commute#"))
    }

    func testBackfillTaskDoesNotTurnTheSameNounPhraseIntoAWrite() {
        XCTAssertTrue(recognition("高温通勤", task: .backfill).hasPrefix("unsupported#"))
        XCTAssertTrue(recognition("爱好类消费", task: .backfill).hasPrefix("unsupported#"))
        XCTAssertTrue(recognition("补记高温通勤", task: .backfill).hasPrefix("commuteDraft#"))
    }

    func testHotCommuteRequiresBothStructuredWeatherAndCommuteEvidence() {
        let hotCommute = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000401")!,
            title: "上班",
            amount: 4.75,
            category: .transport,
            createdAt: date(13),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )
        let hotDining = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000402")!,
            title: "午饭",
            amount: 28,
            category: .dining,
            createdAt: date(12),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil)
        )
        let normalCommute = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000403")!,
            title: "下班",
            amount: 4.75,
            category: .transport,
            createdAt: date(18),
            memoryContext: .init(weatherKind: "clear", temperatureCelsius: 25, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )
        let hotTaxi = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000404")!,
            title: "机场打车",
            amount: 58,
            category: .transport,
            createdAt: date(15),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil)
        )

        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "高温通勤",
            items: [hotCommute, hotDining, normalCommute, hotTaxi],
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("query#"))
        XCTAssertTrue(digest.contains(hotCommute.id.uuidString))
        XCTAssertFalse(digest.contains(hotDining.id.uuidString))
        XCTAssertFalse(digest.contains(normalCommute.id.uuidString))
        XCTAssertFalse(digest.contains(hotTaxi.id.uuidString))
        XCTAssertTrue(digest.contains("匹配维度：高温天气 · 通勤"))
    }

    func testInterestConsumptionRequiresAConcreteInterestObjectOrActivity() {
        let fishing = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000411")!,
            title: "路亚鱼竿",
            amount: 268,
            category: .shopping,
            createdAt: date(10)
        )
        let ordinaryShopping = HomeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000412")!,
            title: "日常外套",
            amount: 268,
            category: .shopping,
            createdAt: date(11),
            emotionTag: "爱好里的小投入"
        )

        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "爱好类消费",
            items: [fishing, ordinaryShopping],
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("query#"))
        XCTAssertTrue(digest.contains(fishing.id.uuidString))
        XCTAssertFalse(digest.contains(ordinaryShopping.id.uuidString))
        XCTAssertTrue(digest.contains("明确兴趣物件或活动"))
    }

    func testWeakEmotionAndValuePhrasesRemainOutsideLedgerFactQueries() {
        for command in ["辛苦了", "热天辛苦", "今天很热吗", "小投入", "爱好值得吗", "买这个划算吗"] {
            XCTAssertTrue(recognition(command).hasPrefix("unsupported#"), command)
        }
    }

    func testRecognizedFacetWithoutRowsIsNotReportedAsUnrecognized() {
        let digest = InsightWebView.aiCommandComputationDigestForTesting(
            command: "高温通勤",
            items: [],
            hasMemberAccess: true,
            now: now
        )

        XCTAssertTrue(digest.hasPrefix("query#"))
        XCTAssertTrue(digest.contains("已识别为高温天气 · 通勤"))
        XCTAssertTrue(digest.contains("不会用当前天气或暖文案补写历史事实"))
    }

    func testWeatherAndAwayFacetsKeepTheExistingMemberBoundary() {
        let locked = InsightWebView.aiCommandComputationDigestForTesting(
            command: "高温通勤",
            items: [],
            hasMemberAccess: false,
            now: now
        )
        let away = recognition("外地消费")

        XCTAssertTrue(locked.hasPrefix("unsupported#会员可看「高温通勤」"))
        XCTAssertTrue(away.hasPrefix("query#"))
        XCTAssertTrue(away.contains("#away_spending#"))
    }
}

final class AICommandQueryMetricScopeTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: 17,
            hour: 23
        ))!
    }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        ))!
    }

    func testExplicitSingleCategoryUsesAverageAndHighestRecordMetrics() {
        let items = [
            HomeItem(title: "午餐", amount: 12, category: .dining, createdAt: date(day: 16, hour: 12)),
            HomeItem(title: "晚餐", amount: 30, category: .dining, createdAt: date(day: 17, hour: 19)),
            HomeItem(title: "地铁", amount: 8, category: .transport, createdAt: date(day: 17, hour: 8)),
        ]

        let digest = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天餐饮记录",
            items: items,
            now: now
        )

        XCTAssertEqual(digest, "single:餐饮#2#21.0#30.0#餐饮#42.0")
    }

    func testUnfilteredQueryKeepsCrossCategoryMetricsEvenWhenResultsContainOneCategory() {
        let items = [
            HomeItem(title: "午餐", amount: 12, category: .dining, createdAt: date(day: 16, hour: 12)),
            HomeItem(title: "晚餐", amount: 30, category: .dining, createdAt: date(day: 17, hour: 19)),
        ]

        let digest = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天记录",
            items: items,
            now: now
        )

        XCTAssertEqual(digest, "cross#2#21.0#30.0#餐饮#42.0")
    }

    func testSingleCategoryEmptyAndOneRecordBoundariesStayExplicit() {
        let empty = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天餐饮记录",
            items: [],
            now: now
        )
        let one = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "最近 7 天餐饮记录",
            items: [
                HomeItem(title: "午餐", amount: 18, category: .dining, createdAt: date(day: 17, hour: 12))
            ],
            now: now
        )

        XCTAssertEqual(empty, "single:餐饮#0#none#none#none#0.0")
        XCTAssertEqual(one, "single:餐饮#1#18.0#18.0#餐饮#18.0")
    }

    func testSingleCategoryLifeMarkUsesFocusedMetricsWithoutRepeatingBaseCategory() {
        let items = [
            HomeItem(title: "瑞幸咖啡", amount: 9.9, category: .dining, createdAt: date(day: 16, hour: 17)),
            HomeItem(title: "冰美式", amount: 9.9, category: .dining, createdAt: date(day: 17, hour: 9)),
            HomeItem(title: "午餐", amount: 28, category: .dining, createdAt: date(day: 17, hour: 12)),
        ]

        let digest = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "这周咖啡饮品几次？",
            items: items,
            now: now
        )

        XCTAssertEqual(digest, "single:餐饮#2#9.9#9.9#餐饮#19.8")
    }

    func testMultiCategoryLifeMarkAndExplicitBreakdownKeepCrossCategoryMetrics() {
        let items = [
            HomeItem(title: "运动鞋", amount: 399, category: .shopping, createdAt: date(day: 16, hour: 17)),
            HomeItem(title: "健身房月卡", amount: 299, category: .health, createdAt: date(day: 17, hour: 9)),
            HomeItem(title: "瑞幸咖啡", amount: 9.9, category: .dining, createdAt: date(day: 17, hour: 12)),
        ]

        let multi = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "这周健身恢复花了多少？",
            items: items,
            now: now
        )
        let breakdown = InsightWebView.aiCommandQueryMetricDigestForTesting(
            command: "这周咖啡饮品按分类看",
            items: items,
            now: now
        )

        XCTAssertTrue(multi.hasPrefix("cross#"))
        XCTAssertTrue(breakdown.hasPrefix("cross#"))
    }
}

final class AICommandComparisonPresentationPolicyTests: XCTestCase {
    func testChangeKindsUseExistingAmountsAndCountsWithoutFuzzyPairing() {
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 0,
                previousAmount: 96,
                currentCount: 0,
                previousCount: 3
            ),
            .disappeared
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 32,
                previousAmount: 0,
                currentCount: 2,
                previousCount: 0
            ),
            .appeared
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 40,
                previousAmount: 20,
                currentCount: 4,
                previousCount: 2
            ),
            .increased
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 20,
                previousAmount: 40,
                currentCount: 2,
                previousCount: 4
            ),
            .decreased
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeKind(
                currentAmount: 33.25,
                previousAmount: 33.25,
                currentCount: 7,
                previousCount: 7
            ),
            .steady
        )
    }

    func testChangeShareUsesAbsoluteCategoryMovementInsteadOfNetDifference() {
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeSharePercent(
                delta: -96,
                categoryDeltas: [-96, -18.82, 0]
            ),
            84
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeSharePercent(
                delta: 100,
                categoryDeltas: [100, -100]
            ),
            50
        )
        XCTAssertEqual(
            AICommandComparisonPresentationPolicy.changeSharePercent(
                delta: 0,
                categoryDeltas: [0, 0]
            ),
            0
        )
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

final class PixelPetAnimationPolicyTests: XCTestCase {
    func testEachSequenceKeepsEightValidatedFrameDurations() {
        XCTAssertEqual(
            PixelPetAnimationPolicy.durationsMilliseconds(for: .idle),
            [800, 120, 90, 90, 100, 120, 180, 800]
        )
        XCTAssertEqual(
            PixelPetAnimationPolicy.durationsMilliseconds(for: .tap),
            [120, 80, 80, 80, 140, 100, 80, 180]
        )
        XCTAssertEqual(
            PixelPetAnimationPolicy.durationsMilliseconds(for: .speak),
            [160, 90, 90, 90, 110, 90, 100, 240]
        )
    }

    func testNewTapTakesPriorityOverVisibleSpeakingBubble() {
        let plan = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: true,
            sceneIsActive: true,
            reduceMotion: false,
            lowPowerMode: false
        )

        XCTAssertEqual(plan.sequence, .tap)
        XCTAssertTrue(plan.animates)
    }

    func testConsumedTapFollowsBubbleState() {
        XCTAssertEqual(
            PixelPetAnimationPolicy.followUpSequence(bubbleVisible: true),
            .speak
        )
        XCTAssertEqual(
            PixelPetAnimationPolicy.followUpSequence(bubbleVisible: false),
            .idle
        )
    }

    func testMotionPowerAndSceneBoundariesReturnStaticPlans() {
        let reducedMotion = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: true,
            sceneIsActive: true,
            reduceMotion: true,
            lowPowerMode: false
        )
        let lowPower = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: false,
            sceneIsActive: true,
            reduceMotion: false,
            lowPowerMode: true
        )
        let inactive = PixelPetAnimationPolicy.plan(
            tapPending: true,
            bubbleVisible: true,
            sceneIsActive: false,
            reduceMotion: false,
            lowPowerMode: false
        )

        XCTAssertFalse(reducedMotion.animates)
        XCTAssertEqual(reducedMotion.sequence, .speak)
        XCTAssertFalse(lowPower.animates)
        XCTAssertEqual(lowPower.sequence, .idle)
        XCTAssertFalse(inactive.animates)
        XCTAssertEqual(inactive.stableFrameIndex, 0)
    }
}

final class HomePetOverlayPositionPolicyTests: XCTestCase {
    func testDefaultPlacementMatchesTheLegacyLowerRightAnchor() {
        let viewport = CGSize(width: 390, height: 700)

        XCTAssertEqual(HomePetOverlayPlacement.defaultPlacement.side, .right)
        XCTAssertEqual(HomePetOverlayPlacement.defaultPlacement.verticalFraction, 0)
        XCTAssertEqual(
            HomePetOverlayPositionPolicy.bottomInset(
                for: .defaultPlacement,
                viewportHeight: viewport.height
            ),
            102,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            HomePetOverlayPositionPolicy.committedPlacement(
                from: .defaultPlacement,
                translation: .zero,
                viewport: viewport
            ),
            .defaultPlacement
        )
    }

    func testTapJitterDoesNotQualifyAsADrag() {
        XCTAssertFalse(
            HomePetOverlayPositionPolicy.isMeaningfulDrag(CGSize(width: 5, height: 5))
        )
        XCTAssertTrue(
            HomePetOverlayPositionPolicy.isMeaningfulDrag(CGSize(width: 8, height: 1))
        )
    }

    func testDragTranslationTracksViewportSamplesWithoutFeedbackOscillation() {
        let viewport = CGSize(width: 390, height: 700)
        let proposedSamples: [CGSize] = [
            .zero,
            CGSize(width: -24, height: -18),
            CGSize(width: -72, height: -54),
            CGSize(width: -140, height: -110)
        ]
        let resolved = proposedSamples.map {
            HomePetOverlayPositionPolicy.clampedDragTranslation(
                placement: .defaultPlacement,
                proposed: $0,
                viewport: viewport
            )
        }

        XCTAssertEqual(resolved, proposedSamples)
        XCTAssertTrue(zip(resolved, resolved.dropFirst()).allSatisfy { pair in
            let (previous, current) = pair
            return current.width <= previous.width && current.height <= previous.height
        })
    }

    func testDragCommitsToNearestEdgeAndKeepsVerticalPositionInBounds() {
        let viewport = CGSize(width: 390, height: 700)
        let movedLeft = HomePetOverlayPositionPolicy.committedPlacement(
            from: .defaultPlacement,
            translation: CGSize(width: -330, height: -220),
            viewport: viewport
        )
        XCTAssertEqual(movedLeft.side, .left)
        XCTAssertGreaterThan(movedLeft.verticalFraction, 0)
        XCTAssertLessThanOrEqual(movedLeft.verticalFraction, 1)

        let movedRight = HomePetOverlayPositionPolicy.committedPlacement(
            from: movedLeft,
            translation: CGSize(width: 500, height: 900),
            viewport: viewport
        )
        XCTAssertEqual(movedRight.side, .right)
        XCTAssertEqual(movedRight.verticalFraction, 0, accuracy: 0.0001)
    }

    func testStoredPlacementNormalizesCorruptFractionsAndRestoresTheSide() {
        let suiteName = "HomePetOverlayPositionPolicyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        HomePetOverlayPositionStore.save(
            HomePetOverlayPlacement(side: .left, verticalFraction: 4.2),
            defaults: defaults
        )
        let restored = HomePetOverlayPositionStore.load(defaults: defaults)
        XCTAssertEqual(restored.side, .left)
        XCTAssertEqual(restored.verticalFraction, 1, accuracy: 0.0001)
    }

    func testSmallViewportFallsBackWithoutProducingAnInvalidPlacement() {
        let original = HomePetOverlayPlacement(side: .right, verticalFraction: 0.4)
        let result = HomePetOverlayPositionPolicy.committedPlacement(
            from: original,
            translation: CGSize(width: -500, height: -500),
            viewport: CGSize(width: 60, height: 100)
        )
        XCTAssertEqual(result, original)
    }
}

final class PetCompanionMessagePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: hour,
            minute: minute
        ))!
    }

    func testClickUsesCommuteAndCoffeeFactsBeforeCurrentRain() {
        let commute = HomeItem(
            title: "上班",
            amount: 4.75,
            category: .transport,
            createdAt: date(13, 48),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )
        let coffee = HomeItem(
            title: "冰美式",
            amount: 9.9,
            category: .dining,
            createdAt: date(17, 32)
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [commute, coffee],
            currentWeather: WeatherSnapshot(temp: 24, weatherCode: 61, ts: date(20)),
            now: date(20),
            calendar: calendar
        )

        XCTAssertTrue(messages.allSatisfy { $0.text.contains("通勤") })
        XCTAssertTrue(messages.allSatisfy { $0.text.contains("现在外面在下雨") })
        XCTAssertFalse(messages.contains { $0.text.contains("家里") || $0.text.contains("居家") })
    }

    func testSavedRecordUsesItsOwnWeatherInsteadOfCurrentWeather() {
        let commute = HomeItem(
            title: "上班",
            amount: 4.75,
            category: .transport,
            createdAt: date(15),
            memoryContext: .init(weatherKind: "hot", temperatureCelsius: 34, cityName: nil, semanticPlace: nil),
            scenePackId: "commute"
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: commute,
            todayItems: [commute],
            currentWeather: WeatherSnapshot(temp: 24, weatherCode: 61, ts: date(20)),
            now: date(20),
            calendar: calendar
        )

        XCTAssertEqual(messages.map(\.text), ["下午这趟通勤是在热天里记下的。"])
    }

    func testSystemWarmTagDoesNotBecomeAClaimAboutTheUser() {
        let item = HomeItem(
            title: "普通记录",
            amount: 12,
            category: .other,
            createdAt: date(12),
            emotionTag: "辛苦了，今天很治愈"
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: item,
            todayItems: [item],
            currentWeather: nil,
            now: date(20),
            calendar: calendar
        )

        XCTAssertFalse(messages.contains { $0.text.contains("辛苦") || $0.text.contains("治愈") })
    }

    func testExplicitSafeUserLineRequiresUserEditedTitleAndSensitiveRecordsStayNeutral() {
        let safe = HomeItem(
            title: "终于到家",
            amount: 8,
            category: .transport,
            createdAt: date(22),
            userEditedTitle: true
        )
        let sensitive = HomeItem(
            title: "今天好累",
            amount: 50,
            category: .health,
            createdAt: date(22),
            userEditedTitle: true
        )

        let safeMessage = PetCompanionMessagePolicy.candidates(
            focusRecord: safe,
            todayItems: [safe],
            currentWeather: nil,
            now: date(22),
            calendar: calendar
        )
        let sensitiveMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: sensitive,
            todayItems: [sensitive],
            currentWeather: nil,
            now: date(22),
            calendar: calendar
        )

        XCTAssertEqual(safeMessage.first?.id, "saved.user.arrived_home")
        XCTAssertFalse(sensitiveMessages.contains { $0.text.contains("今天好累") })
    }

    func testZeroOneAndSeveralRecordFallbacksAreDeterministic() {
        let first = HomeItem(title: "午饭", amount: 20, category: .dining, createdAt: date(12))
        let second = HomeItem(title: "纸巾", amount: 12, category: .daily, createdAt: date(18))

        let empty = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [],
            currentWeather: nil,
            now: date(12),
            calendar: calendar
        )
        let one = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [first],
            currentWeather: nil,
            now: date(12),
            calendar: calendar
        )
        let several = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [first, second],
            currentWeather: nil,
            now: date(18),
            calendar: calendar
        )

        XCTAssertTrue(empty.allSatisfy { $0.id.hasPrefix("day.empty") })
        XCTAssertTrue(one.allSatisfy { $0.id.hasPrefix("day.one") })
        XCTAssertTrue(several.allSatisfy { $0.id.hasPrefix("day.several") })
    }

    func testHotWeatherCoffeeAddsCareWithoutCallingCoffeeAColdDrink() {
        let coffee = HomeItem(
            title: "拿铁",
            amount: 18,
            category: .dining,
            createdAt: date(15)
        )

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [coffee],
            currentWeather: WeatherSnapshot(temp: 34, weatherCode: 1, ts: date(16)),
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(messages.allSatisfy { $0.text.contains("咖啡") })
        XCTAssertTrue(messages.allSatisfy { $0.text.contains("防晒") && $0.text.contains("补水") })
        XCTAssertFalse(messages.contains { $0.text.contains("冷饮") || $0.text.contains("清凉") })
    }

    func testHotWeatherOnlyUsesColdDrinkCopyForExplicitDiningEvidence() {
        let coldDrink = HomeItem(
            title: "冰美式",
            amount: 12,
            category: .dining,
            createdAt: date(15)
        )
        let merchandise = HomeItem(
            title: "冰美式随行杯",
            amount: 68,
            category: .shopping,
            createdAt: date(15)
        )
        let weather = WeatherSnapshot(temp: 35, weatherCode: 1, ts: date(16))

        let coldDrinkMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [coldDrink],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )
        let merchandiseMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [merchandise],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(coldDrinkMessages.allSatisfy { $0.text.contains("冷饮") })
        XCTAssertFalse(merchandiseMessages.contains { $0.text.contains("冷饮") || $0.text.contains("咖啡") })
    }

    func testSavedSameDayCoffeeCanAddCurrentCareButHistoricalRecordCannot() {
        let todayCoffee = HomeItem(
            title: "咖啡",
            amount: 16,
            category: .dining,
            createdAt: date(15)
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayCoffee.createdAt)!
        let historicalCoffee = HomeItem(
            title: "咖啡",
            amount: 16,
            category: .dining,
            createdAt: yesterday
        )
        let weather = WeatherSnapshot(temp: 34, weatherCode: 1, ts: date(16))

        let todayMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: todayCoffee,
            todayItems: [todayCoffee],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )
        let historicalMessages = PetCompanionMessagePolicy.candidates(
            focusRecord: historicalCoffee,
            todayItems: [],
            currentWeather: weather,
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(todayMessages.allSatisfy { $0.text.contains("防晒") && $0.text.contains("补水") })
        XCTAssertTrue(historicalMessages.allSatisfy { !$0.text.contains("防晒") && !$0.text.contains("补水") })
    }

    func testStaleWeatherDoesNotBecomeCurrentCare() {
        let coffee = HomeItem(
            title: "咖啡",
            amount: 16,
            category: .dining,
            createdAt: date(15)
        )
        let staleTimestamp = calendar.date(byAdding: .hour, value: -2, to: date(16))!

        let messages = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: [coffee],
            currentWeather: WeatherSnapshot(temp: 34, weatherCode: 1, ts: staleTimestamp),
            now: date(16),
            calendar: calendar
        )

        XCTAssertTrue(messages.allSatisfy { $0.id.hasPrefix("day.one") })
        XCTAssertFalse(messages.contains { $0.text.contains("防晒") || $0.text.contains("补水") })
    }

    func testInteractionHintOnlyPresentsBeforeItHasBeenSeen() {
        XCTAssertTrue(PetCompanionInteractionHintPolicy.shouldPresent(hasPresented: false))
        XCTAssertFalse(PetCompanionInteractionHintPolicy.shouldPresent(hasPresented: true))
    }

    func testAutomaticSpeechRequiresAnUnblockedVisibleActiveHome() {
        XCTAssertTrue(PetCompanionAutomaticSpeechPolicy.shouldSchedule(
            isHomeVisible: true,
            isSceneActive: true,
            isPetEnabled: true,
            isPresentationBlocked: false,
            hasBubble: false,
            hasMessageRequest: false,
            hasPendingSavedMessage: false
        ))

        let blockedStates: [(Bool, Bool, Bool, Bool, Bool, Bool, Bool)] = [
            (false, true, true, false, false, false, false),
            (true, false, true, false, false, false, false),
            (true, true, false, false, false, false, false),
            (true, true, true, true, false, false, false),
            (true, true, true, false, true, false, false),
            (true, true, true, false, false, true, false),
            (true, true, true, false, false, false, true),
        ]
        for state in blockedStates {
            XCTAssertFalse(PetCompanionAutomaticSpeechPolicy.shouldSchedule(
                isHomeVisible: state.0,
                isSceneActive: state.1,
                isPetEnabled: state.2,
                isPresentationBlocked: state.3,
                hasBubble: state.4,
                hasMessageRequest: state.5,
                hasPendingSavedMessage: state.6
            ))
        }
    }

    func testAutomaticSpeechStartsWithTheInteractionHintThenUsesBoundedIdleCadence() {
        XCTAssertEqual(
            PetCompanionAutomaticSpeechPolicy.nextStep(
                hasPresentedInteractionHint: false,
                automaticPresentationCount: 0,
                hasPresentedIdleMessageInSession: false,
                voiceOverEnabled: false
            ),
            .init(kind: .interactionHint, delayNanoseconds: 5_000_000_000)
        )
        XCTAssertEqual(
            PetCompanionAutomaticSpeechPolicy.nextStep(
                hasPresentedInteractionHint: true,
                automaticPresentationCount: 1,
                hasPresentedIdleMessageInSession: false,
                voiceOverEnabled: false
            ),
            .init(kind: .idle, delayNanoseconds: 25_000_000_000)
        )
        XCTAssertEqual(
            PetCompanionAutomaticSpeechPolicy.nextStep(
                hasPresentedInteractionHint: true,
                automaticPresentationCount: 2,
                hasPresentedIdleMessageInSession: true,
                voiceOverEnabled: false
            ),
            .init(kind: .idle, delayNanoseconds: 150_000_000_000)
        )
        XCTAssertNil(PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: true,
            automaticPresentationCount: PetCompanionAutomaticSpeechPolicy.maximumPresentationsPerSession,
            hasPresentedIdleMessageInSession: true,
            voiceOverEnabled: false
        ))
    }

    func testVoiceOverAutomaticSpeechUsesLongerDelays() {
        let hint = PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: false,
            automaticPresentationCount: 0,
            hasPresentedIdleMessageInSession: false,
            voiceOverEnabled: true
        )
        let firstIdle = PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: true,
            automaticPresentationCount: 1,
            hasPresentedIdleMessageInSession: false,
            voiceOverEnabled: true
        )
        let repeatedIdle = PetCompanionAutomaticSpeechPolicy.nextStep(
            hasPresentedInteractionHint: true,
            automaticPresentationCount: 2,
            hasPresentedIdleMessageInSession: true,
            voiceOverEnabled: true
        )

        XCTAssertEqual(hint?.delayNanoseconds, 9_000_000_000)
        XCTAssertEqual(firstIdle?.delayNanoseconds, 45_000_000_000)
        XCTAssertEqual(repeatedIdle?.delayNanoseconds, 240_000_000_000)
    }

    func testEmptyPetCopyOffersCompanyWithoutRepeatingRecordingInstructions() {
        XCTAssertTrue(PetCompanionCopy.noRecords.allSatisfy { $0.text.contains("我") })
        XCTAssertFalse(PetCompanionCopy.noRecords.contains {
            $0.text.contains("硬凑") || $0.text.contains("先记") || $0.text.contains("想起一笔")
        })
    }
}

final class HomeEmptyTodayCopyPolicyTests: XCTestCase {
    func testSuggestionAndSceneRemainObservationsInsteadOfRecordingCommands() {
        let suggestion = HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: "往常这个时间，你常记的是 ¥12 · 餐饮。",
            dominantSceneLine: "这周「通勤」出现得比较多。"
        )
        let scene = HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: nil,
            dominantSceneLine: "这周「通勤」出现得比较多。"
        )
        let plain = HomeEmptyTodayCopyPolicy.copy(
            frequentSuggestionLine: nil,
            dominantSceneLine: nil
        )

        XCTAssertEqual(suggestion.title, "今天还没有记录")
        XCTAssertEqual(suggestion.subtitle, "往常这个时间，你常记的是 ¥12 · 餐饮。")
        XCTAssertEqual(scene.subtitle, "这周「通勤」出现得比较多。")
        XCTAssertEqual(plain.subtitle, "今天这一页暂时还是空的。")
        for copy in [suggestion, scene, plain] {
            XCTAssertFalse(copy.title.contains("从这里开始"))
            XCTAssertFalse(copy.subtitle.contains("只输金额"))
            XCTAssertFalse(copy.subtitle.contains("先放进账本"))
        }
    }
}

final class RecordTimeSelectionPolicyTests: XCTestCase {
    private func calendar(timeZone: TimeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func date(
        year: Int = 2026,
        month: Int = 7,
        day: Int = 18,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 37
        ))!
    }

    func testLargeTimeChangeCommitsOneNormalizedDateWithoutChangingDay() {
        let calendar = calendar()
        let source = date(hour: 22, minute: 55, calendar: calendar)
        let result = RecordTimeSelectionPolicy.applyingTime(
            hour: 8,
            minute: 5,
            to: source,
            calendar: calendar
        )
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: result)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 8)
        XCTAssertEqual(components.minute, 5)
        XCTAssertEqual(components.second, 0)
    }

    func testMidnightAndEndOfDayRemainOnTheSelectedDate() {
        let calendar = calendar()
        let source = date(year: 2028, month: 2, day: 29, hour: 12, minute: 30, calendar: calendar)
        let midnight = RecordTimeSelectionPolicy.applyingTime(hour: 0, minute: 0, to: source, calendar: calendar)
        let endOfDay = RecordTimeSelectionPolicy.applyingTime(hour: 23, minute: 59, to: source, calendar: calendar)

        XCTAssertTrue(calendar.isDate(midnight, inSameDayAs: source))
        XCTAssertTrue(calendar.isDate(endOfDay, inSameDayAs: source))
        XCTAssertEqual(calendar.component(.hour, from: midnight), 0)
        XCTAssertEqual(calendar.component(.minute, from: midnight), 0)
        XCTAssertEqual(calendar.component(.hour, from: endOfDay), 23)
        XCTAssertEqual(calendar.component(.minute, from: endOfDay), 59)
    }

    func testOutOfRangeValuesAreClampedInsteadOfRollingTheDate() {
        let calendar = calendar()
        let source = date(hour: 12, minute: 30, calendar: calendar)
        let result = RecordTimeSelectionPolicy.applyingTime(
            hour: 99,
            minute: -8,
            to: source,
            calendar: calendar
        )

        XCTAssertTrue(calendar.isDate(result, inSameDayAs: source))
        XCTAssertEqual(calendar.component(.hour, from: result), 23)
        XCTAssertEqual(calendar.component(.minute, from: result), 0)
    }

    func testDSTGapUsesAValidTimeOnTheSameLocalDay() {
        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        let calendar = calendar(timeZone: losAngeles)
        let source = date(year: 2026, month: 3, day: 8, hour: 1, minute: 30, calendar: calendar)
        let result = RecordTimeSelectionPolicy.applyingTime(
            hour: 2,
            minute: 30,
            to: source,
            calendar: calendar
        )

        XCTAssertTrue(calendar.isDate(result, inSameDayAs: source))
        XCTAssertEqual(calendar.component(.minute, from: result), 30)
        XCTAssertGreaterThanOrEqual(calendar.component(.hour, from: result), 3)
    }
}

final class MembershipDetailPresentationPolicyTests: XCTestCase {
    func testProspectSeesOneSalesComparisonAndPricing() {
        let policy = MembershipDetailPresentationPolicy.resolve(
            isMember: false,
            isLifetimeMember: false
        )

        XCTAssertEqual(policy.state, .prospect)
        XCTAssertTrue(policy.showsSalesHero)
        XCTAssertTrue(policy.showsPricing)
        XCTAssertTrue(policy.showsValueComparison)
        XCTAssertFalse(policy.showsMemberStatus)
        XCTAssertFalse(policy.showsUnlockedSummary)
        XCTAssertFalse(policy.showsSubscriptionActions)
        XCTAssertFalse(policy.showsMemberDataBoundary)
    }

    func testSubscriptionSeesStatusUnlockedSummaryAndManagementWithoutSalesComparison() {
        let policy = MembershipDetailPresentationPolicy.resolve(
            isMember: true,
            isLifetimeMember: false
        )

        XCTAssertEqual(policy.state, .subscription)
        XCTAssertFalse(policy.showsSalesHero)
        XCTAssertFalse(policy.showsPricing)
        XCTAssertFalse(policy.showsValueComparison)
        XCTAssertTrue(policy.showsMemberStatus)
        XCTAssertTrue(policy.showsUnlockedSummary)
        XCTAssertTrue(policy.showsSubscriptionActions)
        XCTAssertTrue(policy.showsMemberDataBoundary)
    }

    func testLifetimeMemberGoesFromStatusToArchiveWithoutRepeatedValueCards() {
        let policy = MembershipDetailPresentationPolicy.resolve(
            isMember: true,
            isLifetimeMember: true
        )

        XCTAssertEqual(policy.state, .lifetime)
        XCTAssertFalse(policy.showsSalesHero)
        XCTAssertFalse(policy.showsPricing)
        XCTAssertFalse(policy.showsValueComparison)
        XCTAssertTrue(policy.showsMemberStatus)
        XCTAssertFalse(policy.showsUnlockedSummary)
        XCTAssertFalse(policy.showsSubscriptionActions)
        XCTAssertTrue(policy.showsMemberDataBoundary)
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

    func testRelationshipDiscoveryStaysDeterministicAtAllReleaseScales() {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
        let anchor = calendar.date(from: DateComponents(year: 2030, month: 7, day: 23, hour: 12))!
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: anchor)!.start
        let now = calendar.date(byAdding: .hour, value: 71, to: weekStart)!

        func row(_ title: String, category: HomeItem.Category, week: Int, day: Int, hour: Int) -> HomeItem {
            let periodStart = calendar.date(byAdding: .weekOfYear, value: -week, to: weekStart)!
            let date = calendar.date(byAdding: .day, value: day, to: periodStart)!
            return HomeItem(
                title: title,
                amount: 12,
                category: category,
                createdAt: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
            )
        }

        let baseline = (1...4).map {
            row("普通午餐", category: .dining, week: $0, day: 1, hour: 12)
        }
        let current = [0, 1].flatMap { day in
            [
                row("下班通勤", category: .transport, week: 0, day: day, hour: 22),
                row("夜间咖啡", category: .dining, week: 0, day: day, hour: 23),
            ]
        }

        for count in [100, 1_000, 5_000] {
            let items = ReleaseFixtureFactory.makeItems(count: count) + baseline + current
            let input = LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: count,
                items: items,
                now: now,
                recentEchoIDs: []
            )
            let first = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)
            let second = LifeNarrativeEchoPolicy.makeEcho(input, calendar: calendar)

            XCTAssertEqual(first, second)
            XCTAssertEqual(first?.kind, .newContextPair)
            XCTAssertEqual(first?.baselinePeriodCount, 4)
        }
    }
}

final class CloudSessionExpirationPolicyTests: XCTestCase {
    func testOnlyUnauthorizedHTTPResponsesInvalidateTheCloudSession() {
        XCTAssertTrue(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: AuthServiceError.badStatus(401, #"{"ok":false,"error":"INVALID_TOKEN"}"#)
            )
        )
        XCTAssertTrue(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: LedgerSyncError.badStatus(401, #"{"ok":false,"error":"INVALID_TOKEN"}"#)
            )
        )
        XCTAssertFalse(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: AuthServiceError.badStatus(400, #"{"ok":false,"error":"INVALID_LEDGER_ITEM"}"#)
            )
        )
        XCTAssertFalse(
            CloudSessionFailurePolicy.shouldInvalidateSession(
                for: LedgerSyncError.badStatus(500, "database unavailable")
            )
        )
        XCTAssertFalse(
            CloudSessionFailurePolicy.shouldInvalidateSession(for: URLError(.notConnectedToInternet))
        )
    }

    func testSessionInvalidationPreservesLocalPreferencesAndClearsOnlyAccountState() {
        var current = AppSettings.default
        current.displayName = "保留的昵称"
        current.syncEnabled = true
        current.cloudUserId = "cloud-user-1"
        current.memberTier = "yearly"
        current.memberExpiresAt = "2026-12-31T00:00:00Z"
        current.petCompanionEnabled = false
        current.weatherCompanionEnabled = false
        current.colorThemeId = "xuzhang_default"

        let invalidated = CloudSessionInvalidationPolicy.invalidatedSettings(from: current)

        XCTAssertFalse(invalidated.syncEnabled)
        XCTAssertEqual(invalidated.cloudUserId, "")
        XCTAssertEqual(invalidated.memberTier, "free")
        XCTAssertNil(invalidated.memberExpiresAt)
        XCTAssertEqual(invalidated.displayName, current.displayName)
        XCTAssertEqual(invalidated.petCompanionEnabled, current.petCompanionEnabled)
        XCTAssertEqual(invalidated.weatherCompanionEnabled, current.weatherCompanionEnabled)
        XCTAssertEqual(invalidated.colorThemeId, current.colorThemeId)
        XCTAssertEqual(invalidated.backendBaseURL, AppSettings.productionBackendBaseURL)
    }
}

final class DiningCopyEvidencePolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 60 * 60)!
        return calendar
    }

    private func date(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 7,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    func testBrandOnlyLawsonUsesNeutralStableVarietyWithoutInventingFood() {
        let outputs = (0..<8).map { index in
            let input = RecordDraftResolutionInput(
                rawTitle: "罗森",
                fallbackCategory: .dining,
                amount: 4.2 + Double(index),
                date: date(day: 20 + index, minute: index),
                merchantBrandId: "lawson",
                categoryLockedByUser: false,
                userEditedTitle: false,
                source: "test"
            )
            let first = RecordDraftResolutionService.resolve(input)
            let relaunched = RecordDraftResolutionService.resolve(input)
            XCTAssertEqual(first.emotionTag, relaunched.emotionTag)
            return first.emotionTag
        }

        XCTAssertGreaterThan(Set(outputs).count, 1)
        let unsupportedClaims = ["热食", "热乎", "一口热的", "饭团", "便当", "关东煮", "咖啡", "饮料", "小食", "拿点吃的"]
        XCTAssertTrue(outputs.allSatisfy { output in
            unsupportedClaims.allSatisfy { !output.contains($0) }
        })
        XCTAssertTrue(outputs.allSatisfy { $0.contains("罗森") || $0 == "便利店这一笔" })
    }

    func testExplicitConvenienceFoodEvidenceKeepsTheSpecificNeutralLabel() {
        let cases = [
            (title: "罗森关东煮", expected: "关东煮"),
            (title: "罗森便当", expected: "便当"),
            (title: "罗森饭团", expected: "饭团"),
            (title: "罗森咖啡", expected: "咖啡"),
        ]

        for (index, sample) in cases.enumerated() {
            let output = NarrativeCopyResolver.resolveEmotionTag(
                context: NarrativeCopyResolver.Context(
                    brandId: "lawson",
                    category: .dining,
                    amount: 12 + Double(index),
                    date: date(day: 20 + index),
                    seed: sample.title,
                    note: sample.title
                )
            )
            XCTAssertTrue(output.contains(sample.expected), "\(sample.title) should retain \(sample.expected): \(output)")
            XCTAssertFalse(output.contains("热食"))
            XCTAssertFalse(output.contains("热乎"))
            XCTAssertFalse(output.contains("一口热的"))
        }
    }

    func testLegacyUnsupportedHeatTagIsCorrectedFromTheRecordEvidence() {
        let item = HomeItem(
            id: UUID(uuidString: "F1000000-0000-0000-0000-000000000001")!,
            title: "罗森",
            amount: 4.2,
            category: .dining,
            createdAt: date(day: 27, hour: 18),
            emotionTag: "一口热食很及时",
            merchantBrandId: "lawson"
        )

        let first = item.displayEmotionTag
        let afterRelaunch = item.displayEmotionTag
        XCTAssertEqual(first, afterRelaunch)
        XCTAssertTrue(first.contains("罗森") || first == "便利店这一笔")
        XCTAssertFalse(first.contains("热食"))
        XCTAssertFalse(first.contains("热乎"))
        XCTAssertFalse(first.contains("饭团"))
        XCTAssertFalse(first.contains("便当"))
    }

    func testConvenienceBrandFallbackPoolsContainOnlyMerchantLevelFacts() {
        let forbiddenClaims = ["热食", "热乎", "一口热的", "饭团", "便当", "关东煮", "咖啡", "饮料", "小食", "拿点吃的"]
        for brandID in ["familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia"] {
            let notes = MerchantBrandCatalog.definition(for: brandID)?.tiers.flatMap { $0.notes } ?? []
            XCTAssertFalse(notes.isEmpty)
            XCTAssertTrue(notes.allSatisfy { note in
                forbiddenClaims.allSatisfy { !note.contains($0) }
            }, "\(brandID) fallback tiers must not invent a product")
        }
    }

    func testDiningBrandFallbackPoolsDoNotAddUnsupportedTemperatureClaims() {
        let unsupportedTemperature = ["热食", "热乎", "口热的", "热餐", "热饭", "顿热的"]
        let diningNotes = MerchantBrandCatalog.definitions
            .filter { $0.category == .dining }
            .flatMap { $0.tiers }
            .flatMap { $0.notes }

        XCTAssertFalse(diningNotes.isEmpty)
        XCTAssertTrue(diningNotes.allSatisfy { note in
            unsupportedTemperature.allSatisfy { !note.contains($0) }
        })
    }
}
#endif
