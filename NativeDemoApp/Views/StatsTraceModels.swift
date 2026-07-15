import Foundation
import CoreGraphics

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week = "本周"
    case month = "本月"
    case year = "本年"
    var id: String { rawValue }
}

enum CustomDateEndpoint {
    case start
    case end
}

enum TraceCustomRangePreset {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case last7Days
    case last30Days
}

enum TraceViewMode: String, CaseIterable, Identifiable {
    case life = "生活"
    case clues = "线索"

    var id: String { rawValue }
}

enum TraceLifePreparationPolicy {
    static func prewarmRange(after visibleRange: SummaryPlaybackRange) -> SummaryPlaybackRange {
        visibleRange == .week ? .month : .week
    }

    static func hasVisibleSnapshot(
        selectedRange: SummaryPlaybackRange,
        hasWeek: Bool,
        hasMonth: Bool
    ) -> Bool {
        switch selectedRange {
        case .week:
            return hasWeek || hasMonth
        case .month:
            return hasMonth || hasWeek
        }
    }

    static func needsPrimaryPreparation(
        selectedRange: SummaryPlaybackRange,
        weekNeedsRefresh: Bool,
        monthNeedsRefresh: Bool,
        hasWeek: Bool,
        hasMonth: Bool
    ) -> Bool {
        switch selectedRange {
        case .week:
            return weekNeedsRefresh || !hasWeek
        case .month:
            return monthNeedsRefresh || !hasMonth
        }
    }
}

struct StatsTabState {
    var selectedPeriod: StatsPeriod = .week
    var selectedCategory: HomeItem.Category?
    var customStartDate = Date()
    var customEndDate = Date()
    var customDateFocus: CustomDateEndpoint = .start
    var useCustomRange = false
    var showsCustomDatePanel = false
    var viewMode: TraceViewMode = .life
    var lifeCardRange: SummaryPlaybackRange = .week
    var deepInsightExpanded = false
    var focusedInsightQuestion: String?
    var scrollAnchorID: String?
    var snapshotStore = TraceSnapshotStore()
    var preparedWeekSnapshot: TraceChapterSnapshot?
    var preparedMonthSnapshot: TraceChapterSnapshot?
    var preparedClueSnapshot: TraceClueSnapshot?

    mutating func openLifeChapter(_ range: SummaryPlaybackRange) {
        viewMode = .life
        lifeCardRange = range
        selectedPeriod = range == .week ? .week : .month
        useCustomRange = false
        scrollAnchorID = "trace-life-card"
    }
}

struct TraceDayGroup: Identifiable {
    let id: String
    let date: Date
    let items: [HomeItem]
}

struct TraceSwipeDragState: Equatable {
    let itemID: UUID
    let translation: CGFloat
}

struct TraceMarkEvidenceGroup: Identifiable {
    let id: String
    let markLabel: String
    let items: [HomeItem]
    let overflowCount: Int
}

struct TraceChapterSnapshot {
    let range: SummaryPlaybackRange
    let items: [HomeItem]
    let marks: [LifeMarkAggregate]
    let memoryAnchors: [SummaryMemoryAnchor]
    let narrative: String
    let chapterSummary: String?
    let evidenceGroups: [TraceMarkEvidenceGroup]
    let preview: SummaryLaunchPreview
}

struct TraceCategoryClue: Identifiable {
    let category: HomeItem.Category
    let count: Int
    let total: Double
    let ratio: Double

    var id: String { category.rawValue }
}

struct TraceRhythmPoint: Identifiable {
    let label: String
    let count: Int
    let isToday: Bool

    var id: String { label }
}

struct TraceClueSnapshot {
    let items: [HomeItem]
    let clues: [TraceCategoryClue]
    let rhythmPoints: [TraceRhythmPoint]
    let insight: LifeInsightResult
    let marks: [LifeMarkAggregate]
    let lockedMark: LifeMarkAggregate?
    let isDeepInsightUnlocked: Bool
    let canUseDeepInsight: Bool
    let freeInsightRemaining: Int
}

struct SummaryLaunchPreview {
    let count: Int
    let total: Double
    let chapterCount: Int
    let topCategory: String?
}
