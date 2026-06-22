import Foundation

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

struct TraceDayGroup: Identifiable {
    let id: String
    let date: Date
    let items: [HomeItem]
}

struct TraceCategoryClue: Identifiable {
    let id = UUID()
    let category: HomeItem.Category
    let count: Int
    let total: Double
    let ratio: Double
}

struct TraceRhythmPoint: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let isToday: Bool
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
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
