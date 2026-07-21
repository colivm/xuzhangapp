import Foundation

struct PlaybackEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let category: String
    let amount: Double
    let createdAt: Date
}

struct PlaybackSnapshot: Codable, Equatable {
    let durationMs: Int
    let entries: [PlaybackEntry]
}

enum SummaryPlaybackRange: String, Codable, Equatable {
    case week
    case month
}

struct SummaryNarration: Codable, Equatable {
    let warm: String
    let plain: String
}

struct SummaryChapter: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let metrics: [String: String]
    let narration: SummaryNarration
    let durationSec: Double
}

struct SummaryMemoryAnchor: Identifiable, Codable, Equatable {
    let id: UUID
    let itemID: UUID
    let title: String
    let amount: Double
    let createdAt: Date
    let imageData: Data
    let imageReference: String?
    let imageByteCount: Int?
    let role: PhotoMemoryAssetRole
    let sceneHint: PhotoMemorySceneHint
    let label: String
    let caption: String
}

struct SummaryPlayback: Identifiable, Codable, Equatable {
    let id: String
    let range: SummaryPlaybackRange
    let title: String
    let rangeLabel: String
    let teaserLine: String
    let count: Int
    let total: Double
    let topCategory: String?
    let topCategoryRatio: Int
    let chapters: [SummaryChapter]
    let memoryAnchors: [SummaryMemoryAnchor]
}

struct ShareInsightSignal: Equatable {
    enum CategoryContext: Equatable {
        case dining
        case breakfast
        case coffee
        case commute
        case travel
        case medical
        case medicine
        case fitness
        case care
        case groceries
        case homeSupply
        case shopping
        case lodging
        case social
        case general
    }

    enum Kind: Equatable {
        case sceneTop(signal: LifeSceneSignal, count: Int)
        case brandTop(name: String, count: Int, brandId: String?)
        case categoryTop(category: HomeItem.Category, count: Int, context: CategoryContext)
        case busiestDay(label: String, count: Int)
        case lifeMark(kind: LifeMarkKind, title: String, line: String, label: String, count: Int)
        case lifeTitle(text: String)
        case weakData(recordCount: Int)
    }

    let kind: Kind
    let recordCount: Int
    let activeDays: Int
}

struct ShareInsight: Equatable {
    let fact: String
    let care: String
    let footnote: String
    let tags: [String]
}

struct WeeklyShareCategorySlice: Equatable {
    let label: String
    let count: Int
    let ratio: Double
}

struct WeeklyShareCardPayload {
    let weekTotal: Double
    let topCategory: String
    let recordCount: Int
    let primaryMetricCount: Int
    let primaryMetricEmoji: String
    let dailyTrend: [(String, Double)]
    let dailyCountTrend: [(String, Int)]
    let categorySlices: [WeeklyShareCategorySlice]
    let topCategoryRatio: Double
    let headline: String
    let subtitle: String
    let anchorLine: String?
    let lifeMarkLine: String?
    let contextLine: String?
    let emotionLine: String?
    let periodText: String
    let insight: ShareInsight
    let narrativePlan: LifeNarrativePlan?
    let narrativeEcho: LifeNarrativeEcho?
    let narrativeRewrite: LifeNarrativeAIRewrite?
}

struct MemoryAnchorSelectionPolicy {
    struct Candidate {
        let item: HomeItem
        let imageData: Data
        let imageReference: String?
        let imageByteCount: Int
        let imageIndex: Int
        let role: PhotoMemoryAssetRole
        let sceneHint: PhotoMemorySceneHint
        let label: String
        let caption: String
        let score: Int
        let sceneDayKey: String
        let merchantKey: String?
    }

    static func selectAnchors(
        from rows: [HomeItem],
        range: SummaryPlaybackRange,
        limit: Int,
        label: (PhotoMemoryAssetRole, PhotoMemorySceneHint) -> String,
        caption: (PhotoMemoryAssetRole, PhotoMemorySceneHint) -> String
    ) -> [SummaryMemoryAnchor] {
        var usedItemIDs = Set<UUID>()
        var usedSceneDayKeys = Set<String>()
        var usedMerchantKeys = Set<String>()
        var receiptCount = 0
        let anchorCandidates: [Candidate] = rows.flatMap { item -> [Candidate] in
            Self.candidates(for: item, range: range, label: label, caption: caption)
        }
        let sortedCandidates: [Candidate] = anchorCandidates.sorted(by: { (lhs: Candidate, rhs: Candidate) -> Bool in
            if lhs.score == rhs.score {
                return lhs.item.createdAt > rhs.item.createdAt
            }
            return lhs.score > rhs.score
        })

        return sortedCandidates
            .compactMap { candidate -> SummaryMemoryAnchor? in
                guard candidate.score >= selectedScoreThreshold(for: range) else { return nil }
                guard usedItemIDs.insert(candidate.item.id).inserted else { return nil }
                guard usedSceneDayKeys.insert(candidate.sceneDayKey).inserted else { return nil }
                if let merchantKey = candidate.merchantKey,
                   !usedMerchantKeys.insert(merchantKey).inserted {
                    return nil
                }
                if candidate.role == .receipt {
                    guard receiptCount == 0, candidate.score >= receiptScoreThreshold(for: range) else { return nil }
                    receiptCount += 1
                }
                return anchor(from: candidate)
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func candidates(
        for item: HomeItem,
        range: SummaryPlaybackRange,
        label: (PhotoMemoryAssetRole, PhotoMemorySceneHint) -> String,
        caption: (PhotoMemoryAssetRole, PhotoMemorySceneHint) -> String
    ) -> [Candidate] {
        guard item.hasMemoryImages else { return [] }
        let reason = PhotoMemoryPromptPolicy.anchorReason(for: item)
        let role = item.memoryAnchorRole ?? reason.assetRole
        let sceneHint = item.memoryAnchorSceneHint ?? reason.sceneHint
        let anchorCaption = item.memoryAnchorCaption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCoverIndex = item.normalizedCoverMemoryImageIndex ?? 0
        return (0..<item.memoryImageCount).map { index in
            let imageData = item.memoryImageData(at: index) ?? Data()
            return Candidate(
                item: item,
                imageData: imageData,
                imageReference: item.memoryImageReference(at: index),
                imageByteCount: item.memoryImageByteCount(at: index),
                imageIndex: index,
                role: role,
                sceneHint: sceneHint,
                label: label(role, sceneHint),
                caption: anchorCaption?.isEmpty == false ? anchorCaption! : caption(role, sceneHint),
                score: score(
                    item: item,
                    imageByteCount: item.memoryImageByteCount(at: index),
                    imageIndex: index,
                    coverIndex: normalizedCoverIndex,
                    role: role,
                    sceneHint: sceneHint,
                    range: range
                ),
                sceneDayKey: sceneDayKey(item: item, sceneHint: sceneHint),
                merchantKey: merchantKey(item: item)
            )
        }
    }

    private static func anchor(from candidate: Candidate) -> SummaryMemoryAnchor {
        SummaryMemoryAnchor(
            id: candidate.item.id,
            itemID: candidate.item.id,
            title: candidate.item.displayTitle,
            amount: candidate.item.amount,
            createdAt: candidate.item.createdAt,
            imageData: candidate.imageData,
            imageReference: candidate.imageReference,
            imageByteCount: candidate.imageByteCount,
            role: candidate.role,
            sceneHint: candidate.sceneHint,
            label: candidate.label,
            caption: candidate.caption
        )
    }

    private static func score(
        item: HomeItem,
        imageByteCount: Int,
        imageIndex: Int,
        coverIndex: Int,
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint,
        range: SummaryPlaybackRange
    ) -> Int {
        var value = 24
        value += imageIndex == coverIndex ? 12 : 3
        value += imageQualityScore(byteCount: imageByteCount)
        switch sceneHint {
        case .gathering, .travel:
            value += 24
        case .careRecord:
            value += 22
        case .homeLife, .importantPurchase, .experience, .giftMoment:
            value += 17
        case .healthRecord:
            value += 12
        case .vehicleCare, .travelTransport:
            value += 8
        }
        switch role {
        case .moment, .place:
            value += 10
        case .object, .careRecord:
            value += 6
        case .receipt:
            value -= range == .week ? 18 : 14
        }
        if item.amount >= 300, role != .receipt { value += 4 }
        if item.amount >= 1000, role != .receipt { value += 3 }
        if item.merchantBrandId?.isEmpty == false { value += 3 }
        if item.userEditedTitle == true { value += 10 }
        if item.memoryContext?.weatherKind != nil { value += 5 }
        if item.memoryContext?.semanticPlace != nil { value += 7 }
        if isHighValueExperience(item: item, sceneHint: sceneHint) { value += 8 }
        value -= routineVisualPenalty(item: item, role: role, sceneHint: sceneHint)
        if RecordSemanticLexicon.isSystemGeneratedTitle(item.title) { value -= 8 }
        if Calendar.current.isDateInToday(item.createdAt) { value += 2 }
        return value
    }

    private static func isHighValueExperience(item: HomeItem, sceneHint: PhotoMemorySceneHint) -> Bool {
        guard sceneHint == .experience else { return false }
        let text = "\(item.displayTitle) \(item.displayEmotionTag)".lowercased()
        return ["演出", "展览", "音乐节", "电影", "游乐", "体验", "旅行", "聚会", "生日", "live"]
            .contains { text.contains($0) }
    }

    private static func routineVisualPenalty(
        item: HomeItem,
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint
    ) -> Int {
        guard role == .moment,
              sceneHint == .experience,
              item.category == .dining else {
            return 0
        }
        let text = "\(item.displayTitle) \(item.displayEmotionTag)".lowercased()
        let isRoutine = ["咖啡", "美式", "拿铁", "奶茶", "饮品", "早餐", "午餐", "晚餐", "外卖", "便利店"]
            .contains { text.contains($0) }
        guard isRoutine else { return 0 }
        return item.userEditedTitle == true ? 14 : 20
    }

    private static func imageQualityScore(byteCount: Int) -> Int {
        switch byteCount {
        case 700_000...: return 10
        case 350_000..<700_000: return 7
        case 140_000..<350_000: return 4
        case 60_000..<140_000: return 1
        default: return -6
        }
    }

    private static func selectedScoreThreshold(for range: SummaryPlaybackRange) -> Int {
        range == .week ? 42 : 40
    }

    private static func receiptScoreThreshold(for range: SummaryPlaybackRange) -> Int {
        range == .week ? 48 : 46
    }

    private static func sceneDayKey(item: HomeItem, sceneHint: PhotoMemorySceneHint) -> String {
        "\(dayFormatter.string(from: item.createdAt))-\(sceneHint.rawValue)"
    }

    private static func merchantKey(item: HomeItem) -> String? {
        if let merchantBrandId = item.merchantBrandId, !merchantBrandId.isEmpty {
            return merchantBrandId
        }
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 2 else { return nil }
        return title.lowercased()
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct PlaybackMoment: Equatable {
    enum Source: String, Equatable {
        case title
        case emotionTag
    }

    let item: HomeItem
    let text: String
    let source: Source
    let score: Int
}

struct PlaybackMomentSelection: Equatable {
    let materials: [PlaybackMoment]
    let primary: PlaybackMoment?
    let scentWords: [String]

    func first(excluding itemID: UUID?) -> PlaybackMoment? {
        first(excluding: Set([itemID].compactMap { $0 }))
    }

    func first(excluding itemIDs: Set<UUID>) -> PlaybackMoment? {
        materials.first { material in
            !itemIDs.contains(material.item.id)
        }
    }

    func voiceText(for range: SummaryPlaybackRange) -> String {
        primary?.text ?? PlaybackMomentSelector.honestNoVoiceText(for: range)
    }

    var scentText: String {
        scentWords.isEmpty ? PlaybackMomentSelector.honestNoScentText : scentWords.joined(separator: "、")
    }
}

private final class MemoryAnchorSelectionService {
    func selectAnchors(
        from rows: [HomeItem],
        range: SummaryPlaybackRange,
        limit: Int
    ) -> [SummaryMemoryAnchor] {
        MemoryAnchorSelectionPolicy.selectAnchors(
            from: rows,
            range: range,
            limit: limit,
            label: label(for:sceneHint:),
            caption: playbackCaption(for:sceneHint:)
        )
    }

    private struct ScoredAnchor {
        let item: HomeItem
        let anchor: SummaryMemoryAnchor
        let score: Int
        let sceneDayKey: String
        let merchantKey: String?
        let role: PhotoMemoryAssetRole
    }

    private func candidate(for item: HomeItem, range: SummaryPlaybackRange) -> ScoredAnchor? {
        guard item.hasMemoryImages else { return nil }
        let coverIndex = item.normalizedCoverMemoryImageIndex ?? 0
        let imageData = item.memoryImageData(at: coverIndex) ?? Data()
        let reason = PhotoMemoryPromptPolicy.anchorReason(for: item)
        let role = item.memoryAnchorRole ?? reason.assetRole
        let sceneHint = item.memoryAnchorSceneHint ?? reason.sceneHint
        let caption = item.memoryAnchorCaption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = label(for: role, sceneHint: sceneHint)
        let anchor = SummaryMemoryAnchor(
            id: item.id,
            itemID: item.id,
            title: item.displayTitle,
            amount: item.amount,
            createdAt: item.createdAt,
            imageData: imageData,
            imageReference: item.memoryImageReference(at: coverIndex),
            imageByteCount: item.memoryImageByteCount(at: coverIndex),
            role: role,
            sceneHint: sceneHint,
            label: label,
            caption: caption?.isEmpty == false ? caption! : playbackCaption(for: role, sceneHint: sceneHint)
        )
        return ScoredAnchor(
            item: item,
            anchor: anchor,
            score: score(item: item, role: role, sceneHint: sceneHint, range: range),
            sceneDayKey: sceneDayKey(item: item, sceneHint: sceneHint),
            merchantKey: merchantKey(item: item),
            role: role
        )
    }

    private func score(
        item: HomeItem,
        role: PhotoMemoryAssetRole,
        sceneHint: PhotoMemorySceneHint,
        range: SummaryPlaybackRange
    ) -> Int {
        var value = item.coverMemoryImageIndex == nil ? 18 : 30
        switch sceneHint {
        case .gathering, .travel:
            value += 25
        case .careRecord:
            value += 22
        case .homeLife, .importantPurchase, .experience, .giftMoment:
            value += 18
        case .healthRecord:
            value += 12
        case .vehicleCare, .travelTransport:
            value += 8
        }
        if role == .receipt { value -= range == .week ? 10 : 6 }
        if item.amount >= 300, role != .receipt { value += 4 }
        if Calendar.current.isDateInToday(item.createdAt) { value += 2 }
        return value
    }

    private func sceneDayKey(item: HomeItem, sceneHint: PhotoMemorySceneHint) -> String {
        let day = Self.dayFormatter.string(from: item.createdAt)
        return "\(day)-\(sceneHint.rawValue)"
    }

    private func merchantKey(item: HomeItem) -> String? {
        if let merchantBrandId = item.merchantBrandId, !merchantBrandId.isEmpty {
            return merchantBrandId
        }
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 2 else { return nil }
        return title.lowercased()
    }

    private func label(for role: PhotoMemoryAssetRole, sceneHint: PhotoMemorySceneHint) -> String {
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

    private func playbackCaption(for role: PhotoMemoryAssetRole, sceneHint: PhotoMemorySceneHint) -> String {
        switch role {
        case .moment:
            return sceneHint == .gathering ? "和朋友的一次聚会。" : "当时拍下的一张图。"
        case .receipt:
            return "这类图不用好看，但以后查起来很有用。"
        case .place:
            return "路上拍下的一张图。"
        case .object:
            return "这次买的东西。"
        case .careRecord:
            return "照护相关的一张记录。"
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}


final class PlaybackService {
    private let momentSelector = PlaybackMomentSelector()
    private let memoryAnchorSelector = MemoryAnchorSelectionService()

    func buildTodayPlayback(from items: [HomeItem], now: Date = Date()) -> PlaybackSnapshot {
        let calendar = Calendar.current
        let rows = items
            .filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            .sorted { $0.createdAt < $1.createdAt }
            .prefix(16)
            .map {
                PlaybackEntry(
                    id: $0.id,
                    title: $0.title,
                    category: $0.category.rawValue,
                    amount: $0.amount,
                    createdAt: $0.createdAt
                )
            }
        return PlaybackSnapshot(durationMs: 10_000, entries: Array(rows))
    }

    func buildWeekSummary(
        from items: [HomeItem],
        now: Date = Date(),
        copySeed: String = "",
        sourceRevision: Int? = nil
    ) -> SummaryPlayback {
        let calendar = Self.isoCalendar
        let interval = calendar.dateInterval(of: .weekOfYear, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? now
        let rows = positiveItems(items, from: start, to: end)
        let rangeLabel = "\(Self.shortDateFormatter.string(from: start))-\(Self.shortDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: end) ?? now))"
        let total = rows.reduce(0) { $0 + $1.amount }
        let top = topCategoryStats(rows).first
        let ratio = total > 0 ? Int(round(((top?.amount ?? 0) / total) * 100)) : 0
        let active = dailyActivity(rows, start: start, days: 7)
        let title = "周记"
        let weekKey = SummaryPlaybackQuotaStore().currentWeekKey(now: now)
        let weekSeed = playbackCopySeed(base: "week-\(weekKey)", suffix: copySeed)
        let resolvedSourceRevision = sourceRevision ?? items.count

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "week-\(weekKey)",
                range: .week,
                title: title,
                rangeLabel: rangeLabel,
                teaserLine: "这周还没有记录，先记一笔再回来。",
                count: 0,
                total: 0,
                topCategory: nil,
                topCategoryRatio: 0,
                chapters: [],
                memoryAnchors: []
            )
        }

        let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        let previousWeekRows = positiveItems(items, from: previousWeekStart, to: start)
        let narrativePlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: resolvedSourceRevision,
                items: rows,
                previousItems: previousWeekRows,
                now: now,
                recentLeadSignalIDs: LifeNarrativeSignalPolicy.recentStableSignalIDs(from: previousWeekRows)
            )
        )
        let narrativeEcho = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: resolvedSourceRevision,
                items: items,
                now: now,
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        let narrativeRewrite = LifeNarrativeAIRewriteStore.shared.rewrite(
            for: LifeNarrativeAIPreparationPolicy.key(
                scope: .week,
                sourceRevision: resolvedSourceRevision,
                now: now,
                calendar: calendar
            )
        )

        let echoAnchor = EchoAnchorService.shared.pickEchoAnchor(items: rows, periodKey: weekKey, now: now)
        let selection = momentSelector.select(from: rows, periodKey: weekKey, range: .week, now: now, echoAnchor: echoAnchor)
        let narrativeRepresentative = narrativeLeadItem(
            from: narrativePlan,
            rows: rows,
            allowedKinds: [.userText, .photo, .change]
        )
        let representative = narrativeRepresentative ?? selection.primary?.item ?? rows.last!
        let recordCopy = playbackRecordCopy(for: representative, range: .week)
        let presenceLine = weeklyPresenceLine(rows: rows, activity: active)
        let rhythmCopy = weeklyRhythmCopy(rows: rows, activity: active, calendar: calendar)
        let repeatedCopy = repeatedTraceCopy(
            rows: rows,
            range: .week,
            excludingTitles: Set([recordCopy.safeTitle].compactMap { $0 })
        )
        let auxiliaryMetrics = PlaybackAuxiliarySignalPolicy.preparedMetrics(
            periodItems: rows,
            allItems: items,
            now: now
        )
        let teaserLine = rows.count < 3
            ? presenceLine
            : "这周记了 \(rows.count) 笔，分布在 \(activeDayCount(rows)) 天里。"

        var presenceMetrics: [String: String] = [
            "count": "\(rows.count)",
            "total": Self.money(total),
            "activeDays": "\(activeDayCount(rows))",
            "range": rangeLabel,
            "supportLine": ""
        ]
        presenceMetrics.merge(auxiliaryMetrics) { current, _ in current }

        var chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "week-presence",
                title: "这一周",
                metrics: presenceMetrics,
                narration: PlaybackCopyPool.narration(
                    chapterId: rows.count < 3 ? "week-weak-presence" : "week-presence",
                    seed: weekSeed,
                    values: ["mainLine": presenceLine]
                ),
                durationSec: 6
            )
        ]

        if rows.count >= 3 {
            chapters.append(
                SummaryChapter(
                    id: "week-rhythm",
                    title: rhythmCopy.title,
                    metrics: [
                        "busiestDay": rhythmCopy.signalLabel,
                        "count": "\(rhythmCopy.count)",
                        "supportLine": rhythmCopy.supportLine
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-rhythm",
                        seed: weekSeed,
                        values: ["mainLine": rhythmCopy.mainLine]
                    ),
                    durationSec: 7
                )
            )
            chapters.append(
                SummaryChapter(
                    id: "week-voices",
                    title: "这一笔",
                    metrics: [
                        "voiceTitle1": recordCopy.safeTitle ?? representative.category.rawValue,
                        "amount": Self.money(representative.amount),
                        "day": Self.weekdayFormatter.string(from: representative.createdAt),
                        "supportLine": recordCopy.supportLine
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-voices",
                        seed: weekSeed,
                        values: ["mainLine": recordCopy.mainLine]
                    ),
                    durationSec: 7
                )
            )
            chapters.append(
                SummaryChapter(
                    id: "week-scent",
                    title: "这周反复出现",
                    metrics: [
                        "topCategory": top?.category ?? "日常",
                        "ratio": "\(ratio)",
                        "supportLine": repeatedCopy.supportLine
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-scent",
                        seed: weekSeed,
                        values: ["mainLine": repeatedCopy.mainLine]
                    ),
                    durationSec: 7
                )
            )
        } else {
            chapters.append(
                SummaryChapter(
                    id: "week-voices",
                    title: "这一笔",
                    metrics: [
                        "voiceTitle1": recordCopy.safeTitle ?? representative.category.rawValue,
                        "amount": Self.money(representative.amount),
                        "day": Self.weekdayFormatter.string(from: representative.createdAt),
                        "supportLine": recordCopy.supportLine
                    ],
                    narration: PlaybackCopyPool.narration(
                        chapterId: "week-weak-voices",
                        seed: weekSeed,
                        values: ["mainLine": recordCopy.mainLine]
                    ),
                    durationSec: 6
                )
            )
        }

        let weak = rows.count < 3
        chapters.append(
            SummaryChapter(
                id: "week-outro",
                title: "这周先到这里",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "topCategory": top?.category ?? "日常",
                    "supportLine": narrativeEcho?.line ?? narrativeRewrite?.summary ?? ""
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: weak ? "week-weak-outro" : "week-outro",
                    seed: weekSeed,
                    values: [
                        "mainLine": rolePlannedClosingLine(
                            scope: .week,
                            recordCount: rows.count
                        )
                    ]
                ),
                durationSec: weak ? 6 : 7
            )
        )

        return SummaryPlayback(
            id: "week-\(weekKey)",
            range: .week,
            title: title,
            rangeLabel: rangeLabel,
            teaserLine: PlaybackCopyPool.weekTeaser(
                seed: weekSeed,
                values: ["teaserLine": teaserLine]
            ),
            count: rows.count,
            total: total,
            topCategory: top?.category,
            topCategoryRatio: ratio,
            chapters: chapters,
            memoryAnchors: memoryAnchorSelector.selectAnchors(from: rows, range: .week, limit: 3)
        )
    }

    func buildWeeklyShareCardPayload(
        from items: [HomeItem],
        summary: SummaryPlayback? = nil,
        now: Date = Date(),
        sourceRevision: Int? = nil
    ) -> WeeklyShareCardPayload? {
        let calendar = Self.isoCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return nil }
        let rows = positiveItems(items, from: interval.start, to: interval.end)
        guard !rows.isEmpty else { return nil }
        let previousStart = calendar.date(
            byAdding: .weekOfYear,
            value: -1,
            to: interval.start
        ) ?? interval.start
        let previousRows = positiveItems(items, from: previousStart, to: interval.start)
        let previousStableSignalIDs = LifeNarrativeSignalPolicy.recentStableSignalIDs(from: previousRows)
        let narrativePlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .week,
                sourceRevision: sourceRevision ?? items.count,
                items: rows,
                previousItems: previousRows,
                now: now,
                recentLeadSignalIDs: previousStableSignalIDs
            )
        )
        let narrativeEcho = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .week,
                sourceRevision: sourceRevision ?? items.count,
                items: items,
                now: now,
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        let narrativeRewrite = LifeNarrativeAIRewriteStore.shared.rewrite(
            for: LifeNarrativeAIPreparationPolicy.key(
                scope: .week,
                sourceRevision: sourceRevision ?? items.count,
                now: now,
                calendar: calendar
            )
        )

        let total = rows.reduce(0) { $0 + $1.amount }
        let top = topCategoryStats(rows).first
        let topAmount = top?.amount ?? 0
        let ratio = total > 0 ? topAmount / total : 0
        let builtSummary = summary ?? buildWeekSummary(
            from: items,
            now: now,
            sourceRevision: sourceRevision
        )
        let activity = dailyActivity(rows, start: interval.start, days: 7)
        let trend = activity.map { activity in
            (Self.shortWeekdayFormatter.string(from: activity.date), activity.amount)
        }
        let countTrend = activity.map { activity in
            (Self.shortWeekdayFormatter.string(from: activity.date), activity.count)
        }
        let categorySlices = weeklyShareCategorySlices(from: rows)
        let period = "\(Self.dotDateFormatter.string(from: interval.start)) ~ \(Self.dotDateFormatter.string(from: calendar.date(byAdding: .day, value: -1, to: interval.end) ?? now))"
        let closing = builtSummary.chapters.last?.narration.plain ?? "这一周已经留下了可以回看的记录。"
        let weeklyLifeMark = weeklyShareLifeMarkAggregate(rows: rows, allItems: items, now: now)
        let lifeMarkSubtitle = weeklyShareLifeMarkLine(from: weeklyLifeMark)
            ?? weeklyShareLifeMarkLine(from: builtSummary)
        let contextLine = weeklySceneMemoryLine(rows)
        let emotionLine = weeklyEmotionSignalLine(rows)
        let signal = weeklyShareInsightSignal(
            rows: rows,
            activity: activity,
            now: now,
            lifeMark: weeklyLifeMark
        )
        let insight = ShareInsightCopyPool.insight(
            for: signal,
            seed: "\(builtSummary.id)|\(period)|\(rows.count)"
        )
        let primaryMetric = weeklySharePrimaryMetric(from: signal)

        return WeeklyShareCardPayload(
            weekTotal: total,
            topCategory: top?.category ?? "日常",
            recordCount: rows.count,
            primaryMetricCount: primaryMetric.count,
            primaryMetricEmoji: primaryMetric.emoji,
            dailyTrend: trend,
            dailyCountTrend: countTrend,
            categorySlices: categorySlices,
            topCategoryRatio: ratio,
            headline: builtSummary.teaserLine,
            subtitle: lifeMarkSubtitle ?? closing,
            anchorLine: contextLine ?? weeklyShareAnchorLine(from: builtSummary),
            lifeMarkLine: lifeMarkSubtitle,
            contextLine: contextLine,
            emotionLine: emotionLine,
            periodText: period,
            insight: insight,
            narrativePlan: narrativePlan,
            narrativeEcho: narrativeEcho,
            narrativeRewrite: narrativeRewrite
        )
    }

    private func weeklyShareCategorySlices(from rows: [HomeItem]) -> [WeeklyShareCategorySlice] {
        let totalCount = max(rows.count, 1)
        let grouped = Dictionary(grouping: rows) { item in
            weeklyShareCompositionLabel(for: item)
        }
            .map { entry in
                (
                    label: entry.key,
                    count: entry.value.count,
                    latest: entry.value.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.latest > rhs.latest }
                return lhs.count > rhs.count
            }

        let visible = Array(grouped.prefix(3))
        let remaining = grouped.dropFirst(3).reduce(0) { $0 + $1.count }
        let slices = visible.map { item in
            WeeklyShareCategorySlice(
                label: item.label,
                count: item.count,
                ratio: Double(item.count) / Double(totalCount)
            )
        }
        guard remaining > 0 else { return slices }
        return slices + [
            WeeklyShareCategorySlice(
                label: "其他",
                count: remaining,
                ratio: Double(remaining) / Double(totalCount)
            )
        ]
    }

    private func weeklyShareCompositionLabel(for item: HomeItem) -> String {
        let scene = LifeSceneSemanticService.classify(item)
        switch scene.kind {
        case .breakfast:
            return "早餐"
        case .coffee:
            return "咖啡"
        case .quickMeal, .workMeal:
            return "吃饭"
        case .commute:
            return "通勤"
        case .cityRoute:
            return "出行"
        case .convenienceSupply:
            return "小补给"
        case .groceries:
            return "食材"
        case .homeSupply, .telecomBill:
            return "家用"
        case .shopping:
            return "购物"
        case .medicalVisit:
            return "就医"
        case .medicineCare:
            return "用药"
        case .fitness:
            return "锻炼"
        case .bodyCare:
            return "护理"
        case .lodging:
            return "住宿"
        case .social:
            return "人情"
        case .leisure:
            return "放松"
        case .errand:
            return "办事"
        case .general:
            return item.category.label
        }
    }

    private func weeklySharePrimaryMetric(from signal: ShareInsightSignal) -> (count: Int, emoji: String) {
        switch signal.kind {
        case let .sceneTop(scene, count):
            return (count, weeklyShareEmoji(for: scene.kind))
        case let .brandTop(name, count, brandId):
            return (count, weeklyShareBrandEmoji(name: name, brandId: brandId))
        case let .categoryTop(category, count, context):
            return (count, weeklyShareEmoji(for: category, context: context))
        case let .busiestDay(_, count):
            return (count, "📌")
        case let .lifeMark(_, _, _, _, count):
            return (count, "✨")
        case .lifeTitle:
            return (signal.recordCount, "📝")
        case let .weakData(recordCount):
            return (recordCount, "📝")
        }
    }

    private func weeklyShareEmoji(for kind: LifeSceneKind) -> String {
        switch kind {
        case .breakfast:
            return "🥣"
        case .quickMeal, .workMeal:
            return "🍜"
        case .coffee:
            return "☕"
        case .commute, .cityRoute:
            return "🚌"
        case .convenienceSupply, .groceries, .homeSupply, .telecomBill:
            return "🛒"
        case .shopping:
            return "🛍️"
        case .medicalVisit:
            return "🏥"
        case .medicineCare, .bodyCare:
            return "💊"
        case .fitness:
            return "🏃"
        case .lodging:
            return "🧳"
        case .social:
            return "🎁"
        case .leisure:
            return "🎮"
        case .errand, .general:
            return "📝"
        }
    }

    private func weeklyShareEmoji(
        for category: HomeItem.Category,
        context: ShareInsightSignal.CategoryContext
    ) -> String {
        switch context {
        case .breakfast:
            return "🥣"
        case .coffee:
            return "☕"
        case .dining:
            return "🍜"
        case .commute, .travel:
            return "🚌"
        case .medical:
            return "🏥"
        case .medicine, .care:
            return "💊"
        case .fitness:
            return "🏃"
        case .groceries, .homeSupply:
            return "🛒"
        case .shopping:
            return "🛍️"
        case .lodging:
            return "🧳"
        case .social:
            return "🎁"
        case .general:
            return weeklyShareEmoji(for: category)
        }
    }

    private func weeklyShareEmoji(for category: HomeItem.Category) -> String {
        switch category {
        case .transport:
            return "🚌"
        case .dining:
            return "🍜"
        case .health:
            return "🏃"
        case .shopping:
            return "🛍️"
        case .daily, .home:
            return "🛒"
        case .lodging:
            return "🧳"
        case .social:
            return "🎁"
        case .entertainment:
            return "🎮"
        case .other:
            return "📝"
        }
    }

    private func weeklyShareBrandEmoji(name: String, brandId: String?) -> String {
        let id = brandId ?? ""
        if ["luckin", "starbucks", "manner"].contains(id) { return "☕" }
        if ["metro_transit", "didi", "alipay_ride"].contains(id) { return "🚌" }
        if ["meituan", "eleme", "mcdonalds", "kfc"].contains(id) { return "🍜" }
        if ["familymart", "lawson", "bianlifeng", "seveneleven", "meiyijia"].contains(id) { return "🛒" }
        if name.contains("咖啡") { return "☕" }
        if name.contains("地铁") || name.contains("公交") || name.contains("滴滴") || name.contains("打车") { return "🚌" }
        if name.contains("医院") || name.contains("门诊") || name.contains("体检") { return "🏥" }
        if name.contains("药店") || name.contains("药房") || name.contains("买药") { return "💊" }
        if name.contains("外卖") || name.contains("美团") || name.contains("饿了") { return "🍜" }
        if name.contains("便利") || name.contains("全家") || name.contains("罗森") { return "🛒" }
        return "📝"
    }

    private func weeklyShareInsightSignal(
        rows: [HomeItem],
        activity: [DayActivity],
        now: Date,
        lifeMark: LifeMarkAggregate?
    ) -> ShareInsightSignal {
        let activeDays = activeDayCount(rows)
        let base = (recordCount: rows.count, activeDays: activeDays)

        if let lifeMark,
           let lifeMarkLine = weeklyShareLifeMarkLine(from: lifeMark) {
            return ShareInsightSignal(
                kind: .lifeMark(
                    kind: lifeMark.kind,
                    title: lifeMark.title,
                    line: lifeMarkLine,
                    label: lifeMark.label,
                    count: lifeMark.count
                ),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if rows.count <= 2 {
            return ShareInsightSignal(
                kind: .weakData(recordCount: rows.count),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let scene = LifeSceneSemanticService.dominantScene(in: rows),
           scene.count >= 3 || Double(scene.count) / Double(max(rows.count, 1)) >= 0.40 {
            return ShareInsightSignal(
                kind: .sceneTop(signal: scene.signal, count: scene.count),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let brand = weeklyBrandTop(rows), brand.count >= 3 {
            return ShareInsightSignal(
                kind: .brandTop(name: brand.name, count: brand.count, brandId: brand.id),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let category = weeklyCategoryTop(rows),
           category.count >= 2 || Double(category.count) / Double(max(rows.count, 1)) >= 0.40 {
            let categoryRows = rows.filter { $0.category == category.category }
            return ShareInsightSignal(
                kind: .categoryTop(
                    category: category.category,
                    count: category.count,
                    context: weeklyCategoryContext(category: category.category, rows: categoryRows)
                ),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let busiest = activity.max(by: { lhs, rhs in
            lhs.count == rhs.count ? lhs.amount < rhs.amount : lhs.count < rhs.count
        }), busiest.count >= 3 {
            return ShareInsightSignal(
                kind: .busiestDay(label: Self.shortWeekdayFormatter.string(from: busiest.date), count: busiest.count),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        if let lifeTitle = weeklyLifeTitle(rows, now: now) {
            return ShareInsightSignal(
                kind: .lifeTitle(text: lifeTitle),
                recordCount: base.recordCount,
                activeDays: base.activeDays
            )
        }

        return ShareInsightSignal(
            kind: .weakData(recordCount: rows.count),
            recordCount: base.recordCount,
            activeDays: base.activeDays
        )
    }

    private func weeklyBrandTop(_ rows: [HomeItem]) -> (id: String, name: String, count: Int, latest: Date)? {
        let grouped = rows.reduce(into: [String: (brand: MerchantBrandDefinition, count: Int, latest: Date)]()) { result, item in
            let brand = MerchantBrandCatalog.definition(for: item.merchantBrandId)
                ?? MerchantBrandCatalog.matchBrand(in: item.title)
            guard let brand else { return }
            let current = result[brand.id]
            result[brand.id] = (
                brand: brand,
                count: (current?.count ?? 0) + 1,
                latest: max(current?.latest ?? .distantPast, item.createdAt)
            )
        }
        return grouped
            .map { entry in
                (id: entry.key, name: entry.value.brand.displayName, count: entry.value.count, latest: entry.value.latest)
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.latest > rhs.latest }
                return lhs.count > rhs.count
            }
            .first
    }

    private func weeklyCategoryTop(_ rows: [HomeItem]) -> (category: HomeItem.Category, count: Int, latest: Date)? {
        Dictionary(grouping: rows, by: \.category)
            .map { entry in
                (
                    category: entry.key,
                    count: entry.value.count,
                    latest: entry.value.map(\.createdAt).max() ?? .distantPast
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.latest > rhs.latest }
                return lhs.count > rhs.count
            }
            .first
    }

    private func weeklyCategoryContext(
        category: HomeItem.Category,
        rows: [HomeItem]
    ) -> ShareInsightSignal.CategoryContext {
        if let scene = LifeSceneSemanticService.dominantScene(in: rows) {
            switch scene.signal.kind {
            case .breakfast:
                return .breakfast
            case .coffee:
                return .coffee
            case .quickMeal, .workMeal:
                return .dining
            case .commute:
                return .commute
            case .cityRoute:
                return .travel
            case .medicalVisit:
                return .medical
            case .medicineCare:
                return .medicine
            case .fitness:
                return .fitness
            case .bodyCare:
                return .care
            case .groceries:
                return .groceries
            case .convenienceSupply, .homeSupply, .telecomBill:
                return .homeSupply
            case .shopping:
                return .shopping
            case .lodging:
                return .lodging
            case .social:
                return .social
            case .leisure, .errand, .general:
                break
            }
        }
        let text = rows
            .map { "\($0.title) \($0.displayEmotionTag) \($0.category.rawValue)" }
            .joined(separator: " ")
        switch category {
        case .dining:
            if containsAny(text, ["早餐", "早饭", "豆浆", "包子", "饭团", "早班", "上班前"]) { return .breakfast }
            if containsAny(text, ["咖啡", "瑞幸", "星巴克", "Manner", "奶茶", "饮品", "饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "柠檬茶", "水溶", "c100", "维C", "维c", "维他", "提神"]) { return .coffee }
            return .dining
        case .transport:
            if containsAny(text, ["上班", "下班", "到岗", "通勤", "早高峰", "晚高峰", "地铁", "公交", "轨道交通"]) { return .commute }
            return .travel
        case .health:
            if containsAny(text, ["医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "拍片", "验血", "口腔", "牙科"]) { return .medical }
            if containsAny(text, ["药店", "药房", "买药", "用药", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴"]) { return .medicine }
            if containsAny(text, ["健身", "跑步", "瑜伽", "运动", "训练", "球场", "游泳", "课程"]) { return .fitness }
            return .care
        case .daily:
            if !SemanticBoundaryGuard.isHouseholdCleaningSupply(text),
               containsAny(text, ["买菜", "食材", "盒马", "叮咚", "水果", "蔬菜", "鸡蛋", "菜场", "厨房食材", "饭桌"]) { return .groceries }
            return .homeSupply
        case .shopping:
            return .shopping
        case .lodging:
            return .lodging
        case .social:
            return .social
        case .home, .entertainment, .other:
            return .general
        }
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func weeklyLifeTitle(_ rows: [HomeItem], now: Date) -> String? {
        let periodKey = SummaryPlaybackQuotaStore().currentWeekKey(now: now)
        return rows
            .filter { $0.userEditedTitle == true }
            .compactMap { item -> (text: String, score: Int, date: Date)? in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard EchoAnchorService.shared.isEligibleLifeTraceTitle(title, item: item) else { return nil }
                return (title, PlaybackMaterialScoring.stableScore(item: item, periodKey: periodKey, now: now), item.createdAt)
            }
            .sorted {
                if $0.score == $1.score { return $0.date > $1.date }
                return $0.score > $1.score
            }
            .first?.text
    }

    private func activeDayCount(_ rows: [HomeItem]) -> Int {
        let calendar = Self.isoCalendar
        return Set(rows.map { item in
            let components = calendar.dateComponents([.year, .month, .day], from: item.createdAt)
            return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        }).count
    }

    private func narrativeLeadItem(
        from plan: LifeNarrativePlan,
        rows: [HomeItem],
        allowedKinds: [LifeNarrativeSignalKind]
    ) -> HomeItem? {
        guard let lead = plan.signalsByRole[.lead]?.first,
              allowedKinds.contains(lead.kind) else { return nil }
        let evidenceIDs = Set(lead.evidenceItemIDs)
        return rows.reversed().first { evidenceIDs.contains($0.id) }
    }

    private func rolePlannedClosingLine(
        scope: LifeNarrativeScope,
        recordCount: Int
    ) -> String {
        switch scope {
        case .day:
            return "今天的 \(recordCount) 笔都看过了，先停在这里。"
        case .week:
            return "这周的 \(recordCount) 笔都看过了，先停在这里。"
        case .month:
            return "这个月的 \(recordCount) 笔都看过了，先停在这里。"
        }
    }

    func buildMonthSummary(
        from items: [HomeItem],
        now: Date = Date(),
        copySeed: String = "",
        sourceRevision: Int? = nil
    ) -> SummaryPlayback {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: now)
        let start = interval?.start ?? calendar.startOfDay(for: now)
        let end = interval?.end ?? now
        let rows = positiveItems(items, from: start, to: end)
        let total = rows.reduce(0) { $0 + $1.amount }
        let title = "月章"
        let rangeLabel = Self.monthFormatter.string(from: now)
        let top = topCategoryStats(rows).first
        let ratio = total > 0 ? Int(round(((top?.amount ?? 0) / total) * 100)) : 0
        let resolvedSourceRevision = sourceRevision ?? items.count

        guard !rows.isEmpty else {
            return SummaryPlayback(
                id: "month-\(Self.monthKeyFormatter.string(from: now))",
                range: .month,
                title: title,
                rangeLabel: rangeLabel,
                teaserLine: "这个月还没有记录，先记一笔再回来。",
                count: 0,
                total: 0,
                topCategory: nil,
                topCategoryRatio: 0,
                chapters: [],
                memoryAnchors: []
            )
        }

        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        let previousMonthRows = positiveItems(items, from: previousMonthStart, to: start)
        let narrativePlan = LifeNarrativeSignalPolicy.makePlan(
            LifeNarrativePlanningInput(
                scope: .month,
                sourceRevision: resolvedSourceRevision,
                items: rows,
                previousItems: previousMonthRows,
                now: now,
                recentLeadSignalIDs: LifeNarrativeSignalPolicy.recentStableSignalIDs(from: previousMonthRows)
            )
        )
        let narrativeEcho = LifeNarrativeEchoPolicy.makeEcho(
            LifeNarrativeEchoInput(
                scope: .month,
                sourceRevision: resolvedSourceRevision,
                items: items,
                now: now,
                recentEchoIDs: []
            ),
            calendar: calendar
        )
        let narrativeRewrite = LifeNarrativeAIRewriteStore.shared.rewrite(
            for: LifeNarrativeAIPreparationPolicy.key(
                scope: .month,
                sourceRevision: resolvedSourceRevision,
                now: now,
                calendar: calendar
            )
        )

        let activeDays = Set(rows.map { calendar.startOfDay(for: $0.createdAt) }).count
        let monthKey = Self.monthKeyFormatter.string(from: now)
        let monthSeed = playbackCopySeed(base: "month-\(monthKey)", suffix: copySeed)
        let earlyRows = rows.filter { calendar.component(.day, from: $0.createdAt) <= 10 }
        let lateRows = rows.filter { calendar.component(.day, from: $0.createdAt) >= 11 }
        let earlySelection = momentSelector.select(from: earlyRows, periodKey: monthKey, range: .month, now: now)
        let lateSelection = momentSelector.select(from: lateRows, periodKey: monthKey, range: .month, now: now)
        let narrativeRepresentative = narrativeLeadItem(
            from: narrativePlan,
            rows: rows,
            allowedKinds: [.userText, .photo]
        )
        let earlyNarrativeItem = narrativeRepresentative.flatMap { item in
            calendar.component(.day, from: item.createdAt) <= 10 ? item : nil
        }
        let lateNarrativeItem = narrativeRepresentative.flatMap { item in
            calendar.component(.day, from: item.createdAt) >= 11 ? item : nil
        }
        let earlyItem = earlyNarrativeItem ?? earlySelection.primary?.item ?? earlyRows.first
        let lateItem = lateNarrativeItem ?? lateSelection.primary?.item ?? lateRows.first
        let earlyCopy = earlyItem.map { playbackRecordCopy(for: $0, range: .month) }
        let lateCopy = lateItem.map { playbackRecordCopy(for: $0, range: .month) }
        let openingLine = "\(rangeLabel)目前记了 \(rows.count) 笔，分布在 \(activeDays) 天里。"
        let earlyLine: String
        let earlySupport: String
        if let earlyCopy {
            earlyLine = earlyCopy.mainLine
            earlySupport = earlyCopy.supportLine
        } else if let first = rows.first {
            earlyLine = "月初十天没有记录，这个月第一笔出现在 \(Self.shortDateFormatter.string(from: first.createdAt))。"
            earlySupport = ""
        } else {
            earlyLine = "月初十天没有记录。"
            earlySupport = ""
        }

        let lateLine: String
        let lateSupport: String
        if calendar.component(.day, from: now) < 11 {
            lateLine = "这个月还没走到后半段，先不替后面的日子下结论。"
            lateSupport = ""
        } else if let lateCopy {
            lateLine = lateCopy.mainLine
            lateSupport = lateCopy.supportLine
        } else {
            lateLine = "11 日以后还没有新的记录。"
            lateSupport = ""
        }

        let comparisonCopy = monthlyComparisonCopy(allItems: items, currentRows: rows, now: now)
        var usedRecordTitles = Set<String>()
        if let title = earlyCopy?.safeTitle { usedRecordTitles.insert(title) }
        if let title = lateCopy?.safeTitle { usedRecordTitles.insert(title) }
        let repeatedCopy = repeatedTraceCopy(
            rows: rows,
            range: .month,
            excludingTitles: usedRecordTitles
        )
        let auxiliaryMetrics = PlaybackAuxiliarySignalPolicy.preparedMetrics(
            periodItems: rows,
            allItems: items,
            now: now
        )
        var openingMetrics: [String: String] = [
            "count": "\(rows.count)",
            "total": Self.money(total),
            "activeDays": "\(activeDays)",
            "range": rangeLabel,
            "supportLine": ""
        ]
        openingMetrics.merge(auxiliaryMetrics) { current, _ in current }

        let chapters: [SummaryChapter] = [
            SummaryChapter(
                id: "month-opening",
                title: "\(rangeLabel)回看",
                metrics: openingMetrics,
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-opening",
                    seed: monthSeed,
                    values: ["mainLine": openingLine]
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-early-voice",
                title: "月初留下的",
                metrics: [
                    "earlyVoiceTitle": earlyCopy?.safeTitle ?? earlyItem?.category.rawValue ?? "",
                    "amount": earlyItem.map { Self.money($0.amount) } ?? "",
                    "day": earlyItem.map { Self.weekdayFormatter.string(from: $0.createdAt) } ?? "",
                    "supportLine": earlySupport
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-early-voice",
                    seed: monthSeed,
                    values: ["mainLine": earlyLine]
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-late-voice",
                title: "后来留下的",
                metrics: [
                    "lateVoiceTitle": lateCopy?.safeTitle ?? lateItem?.category.rawValue ?? "",
                    "amount": lateItem.map { Self.money($0.amount) } ?? "",
                    "day": lateItem.map { Self.weekdayFormatter.string(from: $0.createdAt) } ?? "",
                    "supportLine": lateSupport
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-late-voice",
                    seed: monthSeed,
                    values: ["mainLine": lateLine]
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-change",
                title: comparisonCopy.title,
                metrics: [
                    "change": comparisonCopy.mainLine,
                    "supportLine": comparisonCopy.supportLine
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-change",
                    seed: monthSeed,
                    values: ["mainLine": comparisonCopy.mainLine]
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-scent",
                title: "这个月反复出现",
                metrics: [
                    "topCategory": top?.category ?? "日常",
                    "ratio": "\(ratio)",
                    "supportLine": repeatedCopy.supportLine
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-scent",
                    seed: monthSeed,
                    values: ["mainLine": repeatedCopy.mainLine]
                ),
                durationSec: 8
            ),
            SummaryChapter(
                id: "month-outro",
                title: "这个月先到这里",
                metrics: [
                    "count": "\(rows.count)",
                    "total": Self.money(total),
                    "supportLine": narrativeEcho?.line ?? narrativeRewrite?.summary ?? ""
                ],
                narration: PlaybackCopyPool.narration(
                    chapterId: "month-outro",
                    seed: monthSeed,
                    values: [
                        "mainLine": rolePlannedClosingLine(
                            scope: .month,
                            recordCount: rows.count
                        )
                    ]
                ),
                durationSec: 7
            )
        ]

        return SummaryPlayback(
            id: "month-\(monthKey)",
            range: .month,
            title: title,
            rangeLabel: rangeLabel,
            teaserLine: PlaybackCopyPool.monthTeaser(
                seed: monthSeed,
                values: ["teaserLine": openingLine]
            ),
            count: rows.count,
            total: total,
            topCategory: top?.category,
            topCategoryRatio: ratio,
            chapters: chapters,
            memoryAnchors: memoryAnchorSelector.selectAnchors(from: rows, range: .month, limit: 6)
        )
    }

    private struct CategoryAmount {
        let category: String
        let amount: Double
    }

    private struct CategoryMonthlyStat {
        let category: String
        let count: Int
        let amount: Double
    }

    private struct DayActivity {
        let date: Date
        let label: String
        let count: Int
        let amount: Double
    }

    private struct PlaybackRecordCopy {
        let safeTitle: String?
        let mainLine: String
        let supportLine: String
    }

    private struct PlaybackRhythmCopy {
        let title: String
        let mainLine: String
        let supportLine: String
        let signalLabel: String
        let count: Int
    }

    private struct PlaybackRepeatedCopy {
        let mainLine: String
        let supportLine: String
    }

    private struct PlaybackMonthComparisonCopy {
        let title: String
        let mainLine: String
        let supportLine: String
    }

    private struct PlaybackMonthComparisonFact {
        let line: String
        let score: Double
    }

    private func playbackRecordCopy(
        for item: HomeItem,
        range: SummaryPlaybackRange
    ) -> PlaybackRecordCopy {
        let day = range == .week
            ? Self.shortWeekdayFormatter.string(from: item.createdAt)
            : Self.shortDateFormatter.string(from: item.createdAt)
        let time = Self.shortTimeFormatter.string(from: item.createdAt)
        let prefix = "\(day) \(time)"
        let safeTitle = safePlaybackTitle(for: item)
        if let safeTitle {
            return PlaybackRecordCopy(
                safeTitle: safeTitle,
                mainLine: "\(prefix)，账本里记着「\(safeTitle)」。",
                supportLine: "\(item.category.rawValue) · \(Self.evidenceMoney(item.amount))"
            )
        }
        return PlaybackRecordCopy(
            safeTitle: nil,
            mainLine: "\(prefix) 记了一笔\(item.category.rawValue)，\(Self.evidenceMoney(item.amount))。",
            supportLine: ""
        )
    }

    private func safePlaybackTitle(for item: HomeItem) -> String? {
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...36).contains(title.count),
              !EchoAnchorService.shared.isDirtyTraceTitle(title),
              (item.userEditedTitle == true
                || EchoAnchorService.shared.isEligibleLifeTraceTitle(title, item: item)) else {
            return nil
        }
        return title
    }

    private func weeklyPresenceLine(rows: [HomeItem], activity: [DayActivity]) -> String {
        let recordedDays = activity.filter { $0.count > 0 }
        guard rows.count > 1 else {
            let day = recordedDays.first.map { Self.shortWeekdayFormatter.string(from: $0.date) } ?? "这周"
            return "这周目前记了 1 笔，在\(day)。"
        }
        if rows.count == 2 {
            let labels = recordedDays.map { Self.shortWeekdayFormatter.string(from: $0.date) }
            if labels.count == 1, let day = labels.first {
                return "这周记了 2 笔，都在\(day)。"
            }
            return "这周记了 2 笔，分别在\(joinedChinese(labels))。"
        }
        return "这周记了 \(rows.count) 笔，分布在 \(recordedDays.count) 天里。"
    }

    private func weeklyRhythmCopy(
        rows: [HomeItem],
        activity: [DayActivity],
        calendar: Calendar
    ) -> PlaybackRhythmCopy {
        let recordedDays = activity.filter { $0.count > 0 }
        let maximum = recordedDays.map(\.count).max() ?? 0
        let leadingDays = recordedDays.filter { $0.count == maximum }
        let labels = leadingDays.map { Self.shortWeekdayFormatter.string(from: $0.date) }

        if maximum <= 1 {
            return PlaybackRhythmCopy(
                title: "记录怎么分布",
                mainLine: "这周的 \(rows.count) 笔分在 \(recordedDays.count) 天里，没有特别集中的一天。",
                supportLine: "",
                signalLabel: "分布在 \(recordedDays.count) 天",
                count: maximum
            )
        }

        if leadingDays.count == 1, let leading = leadingDays.first {
            let scopedRows = rows.filter { calendar.isDate($0.createdAt, inSameDayAs: leading.date) }
            let label = labels.first ?? "这天"
            return PlaybackRhythmCopy(
                title: "记录最多的一天",
                mainLine: "\(label)记了 \(maximum) 笔，是这周记录最多的一天。",
                supportLine: categoryCountSupport(scopedRows),
                signalLabel: label,
                count: maximum
            )
        }

        return PlaybackRhythmCopy(
            title: "记录较多的日子",
            mainLine: "\(joinedChinese(labels))各记了 \(maximum) 笔，是这周记录较集中的日子。",
            supportLine: "",
            signalLabel: joinedChinese(labels),
            count: maximum
        )
    }

    private func repeatedTraceCopy(
        rows: [HomeItem],
        range: SummaryPlaybackRange,
        excludingTitles: Set<String>
    ) -> PlaybackRepeatedCopy {
        let period = range == .week ? "这周" : "这个月"

        var titleBuckets: [String: [HomeItem]] = [:]
        for item in rows {
            guard let title = safePlaybackTitle(for: item),
                  !excludingTitles.contains(title) else { continue }
            titleBuckets[title, default: []].append(item)
        }
        if let repeatedTitle = titleBuckets
            .filter({ $0.value.count >= 2 })
            .sorted(by: {
                if $0.value.count == $1.value.count { return $0.key < $1.key }
                return $0.value.count > $1.value.count
            })
            .first {
            let amount = repeatedTitle.value.reduce(0) { $0 + $1.amount }
            return PlaybackRepeatedCopy(
                mainLine: "\(period)「\(repeatedTitle.key)」出现了 \(repeatedTitle.value.count) 次。",
                supportLine: "合计 \(Self.evidenceMoney(amount))"
            )
        }

        let categoryBuckets = Dictionary(grouping: rows, by: \.category)
        let sortedCategories = categoryBuckets.sorted {
            if $0.value.count == $1.value.count { return $0.key.rawValue < $1.key.rawValue }
            return $0.value.count > $1.value.count
        }
        guard let top = sortedCategories.first, top.value.count >= 2 else {
            return PlaybackRepeatedCopy(
                mainLine: "\(period)几笔记录分得比较开，没有哪一类反复出现。",
                supportLine: ""
            )
        }

        let tied = sortedCategories.filter { $0.value.count == top.value.count }
        if top.value.count == rows.count {
            return PlaybackRepeatedCopy(
                mainLine: "\(period) \(rows.count) 笔都归在\(top.key.rawValue)。",
                supportLine: "合计 \(Self.evidenceMoney(top.value.reduce(0) { $0 + $1.amount }))"
            )
        }
        if tied.count > 1 {
            let labels = tied.prefix(3).map { $0.key.rawValue }
            return PlaybackRepeatedCopy(
                mainLine: "\(joinedChinese(labels))各出现了 \(top.value.count) 次，是\(period)反复出现的分类。",
                supportLine: ""
            )
        }
        return PlaybackRepeatedCopy(
            mainLine: "\(top.key.rawValue)出现了 \(top.value.count) 次，是\(period)重复最多的分类。",
            supportLine: "合计 \(Self.evidenceMoney(top.value.reduce(0) { $0 + $1.amount }))"
        )
    }

    private func categoryCountSupport(_ rows: [HomeItem]) -> String {
        let groups = Dictionary(grouping: rows, by: \.category)
            .map {
                (
                    category: $0.key.rawValue,
                    count: $0.value.count,
                    amount: $0.value.reduce(0) { $0 + $1.amount }
                )
            }
            .sorted {
                if $0.count == $1.count { return $0.category < $1.category }
                return $0.count > $1.count
            }
        if groups.count == 1, let group = groups.first {
            return "\(group.category) · 合计 \(Self.evidenceMoney(group.amount))"
        }
        return groups.prefix(3)
            .map { "\($0.category) \($0.count) 笔" }
            .joined(separator: " · ")
    }

    private func monthlyComparisonCopy(
        allItems: [HomeItem],
        currentRows: [HomeItem],
        now: Date
    ) -> PlaybackMonthComparisonCopy {
        let calendar = Calendar.current
        guard let currentMonth = calendar.dateInterval(of: .month, for: now),
              let previousStart = calendar.date(byAdding: .month, value: -1, to: currentMonth.start),
              let previousMonth = calendar.dateInterval(of: .month, for: previousStart) else {
            return PlaybackMonthComparisonCopy(
                title: "和上月同期相比",
                mainLine: "暂时没有可用的上月同期数据。",
                supportLine: ""
            )
        }

        let day = calendar.component(.day, from: now)
        let currentEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? currentMonth.end
        let previousEndCandidate = calendar.date(
            byAdding: .day,
            value: day,
            to: previousMonth.start
        ) ?? previousMonth.end
        let previousEnd = min(previousEndCandidate, previousMonth.end)
        let comparableCurrent = currentRows.filter { $0.createdAt < currentEnd }
        let comparablePrevious = positiveItems(allItems, from: previousMonth.start, to: previousEnd)
        let previousLabel = Self.monthFormatter.string(from: previousMonth.start)
        let currentLabel = Self.monthFormatter.string(from: currentMonth.start)
        let previousTotal = comparablePrevious.reduce(0) { $0 + $1.amount }
        let currentTotal = comparableCurrent.reduce(0) { $0 + $1.amount }

        guard comparablePrevious.count >= 3, previousTotal > 0 else {
            return PlaybackMonthComparisonCopy(
                title: "和上月同期相比",
                mainLine: "\(previousLabel)同期只有 \(comparablePrevious.count) 笔，暂时不做环比。",
                supportLine: comparablePrevious.isEmpty
                    ? "统计范围：1 日—\(day) 日"
                    : "\(previousLabel)同期 · \(comparablePrevious.count) 笔 · \(Self.evidenceMoney(previousTotal))"
            )
        }

        let facts = monthlyComparisonFacts(
            current: comparableCurrent,
            previous: comparablePrevious
        )
        if !facts.isEmpty {
            let line = facts.prefix(2).map(\.line).joined(separator: "；")
            return PlaybackMonthComparisonCopy(
                title: "和上月同期相比",
                mainLine: "和 \(previousLabel)同期相比，\(line)。",
                supportLine: "统计范围：1 日—\(day) 日"
            )
        }

        let amountClose = abs(currentTotal - previousTotal) < max(50, previousTotal * 0.25)
        let countClose = abs(comparableCurrent.count - comparablePrevious.count) < 2
        let mainLine: String
        if amountClose && countClose {
            mainLine = "和 \(previousLabel)同期相比，金额和笔数都接近，没有明显变化。"
        } else {
            mainLine = "和 \(previousLabel)同期相比，总额从 \(Self.evidenceMoney(previousTotal)) 变为 \(Self.evidenceMoney(currentTotal))，记录从 \(comparablePrevious.count) 笔变为 \(comparableCurrent.count) 笔。"
        }
        return PlaybackMonthComparisonCopy(
            title: "和上月同期相比",
            mainLine: mainLine,
            supportLine: "\(currentLabel)同期 \(Self.evidenceMoney(currentTotal)) · \(comparableCurrent.count) 笔 / \(previousLabel)同期 \(Self.evidenceMoney(previousTotal)) · \(comparablePrevious.count) 笔"
        )
    }

    private func monthlyComparisonFacts(
        current: [HomeItem],
        previous: [HomeItem]
    ) -> [PlaybackMonthComparisonFact] {
        let currentStats = monthlyCategoryStats(current)
        let previousStats = monthlyCategoryStats(previous)
        let currentTotal = max(current.reduce(0) { $0 + $1.amount }, 1)
        let previousTotal = max(previous.reduce(0) { $0 + $1.amount }, 1)

        return Set(currentStats.keys).union(previousStats.keys)
            .compactMap { category -> PlaybackMonthComparisonFact? in
                let currentStat = currentStats[category]
                let previousStat = previousStats[category]

                if let currentStat, previousStat == nil {
                    guard currentStat.count >= 2
                            || currentStat.amount >= max(50, currentTotal * 0.08) else { return nil }
                    return PlaybackMonthComparisonFact(
                        line: "\(category)新增了 \(currentStat.count) 笔，合计 \(Self.evidenceMoney(currentStat.amount))",
                        score: currentStat.amount / currentTotal * 100 + Double(currentStat.count)
                    )
                }

                if currentStat == nil, let previousStat {
                    guard previousStat.count >= 2
                            || previousStat.amount >= max(50, previousTotal * 0.08) else { return nil }
                    return PlaybackMonthComparisonFact(
                        line: "\(category)从 \(Self.evidenceMoney(previousStat.amount)) 变为本期没有记录",
                        score: previousStat.amount / previousTotal * 100 + Double(previousStat.count)
                    )
                }

                guard let currentStat, let previousStat else { return nil }
                let amountDelta = currentStat.amount - previousStat.amount
                let countDelta = currentStat.count - previousStat.count
                let shareDelta = currentStat.amount / currentTotal - previousStat.amount / previousTotal
                let amountSignificant = abs(amountDelta) >= max(50, previousStat.amount * 0.25)
                let countSignificant = abs(countDelta) >= 2
                let shareSignificant = abs(shareDelta) >= 0.12
                guard amountSignificant || countSignificant || shareSignificant else { return nil }

                let direction = amountDelta >= 0 ? "增到" : "降到"
                let difference = amountDelta >= 0 ? "多了" : "少了"
                return PlaybackMonthComparisonFact(
                    line: "\(category)从 \(Self.evidenceMoney(previousStat.amount)) \(direction) \(Self.evidenceMoney(currentStat.amount))，\(difference) \(Self.evidenceMoney(abs(amountDelta)))",
                    score: abs(shareDelta) * 100
                        + min(abs(amountDelta) / 50, 8)
                        + Double(abs(countDelta)) * 0.8
                )
            }
            .sorted {
                if $0.score == $1.score { return $0.line < $1.line }
                return $0.score > $1.score
            }
    }

    private func joinedChinese(_ values: [String]) -> String {
        switch values.count {
        case 0: return ""
        case 1: return values[0]
        case 2: return "\(values[0])和\(values[1])"
        default: return values.dropLast().joined(separator: "、") + "和" + (values.last ?? "")
        }
    }

    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let dotDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter
    }()

    private static let evidenceMoneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    static var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        return calendar
    }

    private func positiveItems(_ items: [HomeItem], from start: Date, to end: Date) -> [HomeItem] {
        items
            .filter { $0.amount > 0 && $0.createdAt >= start && $0.createdAt < end }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func topCategoryStats(_ items: [HomeItem]) -> [CategoryAmount] {
        let bucket = Dictionary(grouping: items, by: { $0.category.rawValue })
            .mapValues { rows in rows.reduce(0) { $0 + max($1.amount, 0) } }
        return bucket
            .map { CategoryAmount(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private func dailyActivity(_ items: [HomeItem], start: Date, days: Int) -> [DayActivity] {
        let calendar = Self.isoCalendar
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayItems = items.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            return DayActivity(
                date: date,
                label: Self.weekdayFormatter.string(from: date),
                count: dayItems.count,
                amount: dayItems.reduce(0) { $0 + $1.amount }
            )
        }
    }

    private func weeklyShareAnchorLine(from summary: SummaryPlayback) -> String? {
        if let lifeMarkLine = weeklyShareLifeMarkLine(from: summary) {
            return lifeMarkLine
        }
        if let sceneLine = summary.chapters
            .compactMap({ $0.metrics["sceneMemoryLine"]?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return sceneLine
        }
        if let voices = summary.chapters.first(where: { $0.id == "week-voices" }) {
            if let title = voices.metrics["voiceTitle1"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !title.isEmpty {
                return title
            }
            let narration = voices.narration.plain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !narration.isEmpty {
                return narration
            }
        }
        return nil
    }

    private func weeklyShareLifeMarkLine(from summary: SummaryPlayback) -> String? {
        summary.chapters
            .compactMap { $0.metrics["lifeMarkLine"]?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !EchoAnchorService.shared.isDirtyTraceTitle($0) }
    }

    private func weeklyShareLifeMarkAggregate(
        rows: [HomeItem],
        allItems: [HomeItem],
        now: Date
    ) -> LifeMarkAggregate? {
        let marks = LifeMarkService.aggregates(
            for: rows,
            allItems: allItems,
            isMember: true,
            now: now,
            limit: 4
        )
        return marks.sorted { lhs, rhs in
            let lhsRank = weeklyShareLifeMarkRank(lhs)
            let rhsRank = weeklyShareLifeMarkRank(rhs)
            if lhsRank == rhsRank {
                if lhs.priority == rhs.priority {
                    if lhs.count == rhs.count { return lhs.latestDate > rhs.latestDate }
                    return lhs.count > rhs.count
                }
                return lhs.priority < rhs.priority
            }
            return lhsRank < rhsRank
        }.first
    }

    private func weeklyShareLifeMarkRank(_ mark: LifeMarkAggregate) -> Int {
        switch mark.kind {
        case .milestone:
            return 0
        case .context:
            return 1
        case .scene:
            return 2
        case .streak:
            return 3
        }
    }

    private func weeklyShareLifeMarkLine(from aggregate: LifeMarkAggregate?) -> String? {
        guard let aggregate else { return nil }
        let line = playbackLifeMarkLine(aggregate, fallback: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty,
              !EchoAnchorService.shared.isDirtyTraceTitle(line) else {
            return nil
        }
        return line
    }

    private func weeklySceneMemoryLine(_ rows: [HomeItem]) -> String? {
        if let contextLine = contextualMemoryLine(in: rows) {
            return contextLine
        }
        guard let scene = LifeSceneSemanticService.dominantScene(in: rows),
              scene.count >= 2 else {
            return nil
        }
        return LifeSceneSemanticService.memoryLine(for: scene.signal, count: scene.count)
    }

    private func photoMemoryLine(in rows: [HomeItem], excluding excludedID: UUID? = nil, range: SummaryPlaybackRange) -> String? {
        let photoRows = rows
            .filter { item in
                if let excludedID, item.id == excludedID { return false }
                return item.hasMemoryImages
            }
            .sorted { lhs, rhs in
                if lhs.memoryImageCount == rhs.memoryImageCount {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.memoryImageCount > rhs.memoryImageCount
            }
        guard let first = photoRows.first else { return nil }
        if photoRows.count >= 2 {
            let unit = range == .week ? "这周" : "这个月"
            return "\(unit)有 \(photoRows.count) 个带照片的时刻，照片让这些消费不只是数字。"
        }
        return photoMemoryLine(for: first)
    }

    private func photoMemoryLine(for item: HomeItem?) -> String? {
        guard let item, item.hasMemoryImages else { return nil }
        let title = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.isEmpty || EchoAnchorService.shared.isDirtyTraceTitle(title)
            ? item.category.rawValue
            : title
        let day = Self.shortWeekdayFormatter.string(from: item.createdAt)
        return "\(day)的「\(cleanTitle)」留了照片，以后回看会更像一段生活。"
    }

    private func weeklyEmotionSignalLine(_ rows: [HomeItem]) -> String? {
        let ranked = rows.compactMap { item -> (text: String, score: Int, date: Date)? in
            let emotion = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !emotion.isEmpty,
                  emotion != HomeItem.inferEmotionTag(category: item.category, amount: item.amount),
                  !EchoAnchorService.shared.isDirtyTraceTitle(emotion) else {
                return nil
            }

            var score = 1
            if emotion.contains("第一次") { score += 5 }
            if emotion.contains("连续") { score += 4 }
            if emotion.contains("雨天") || emotion.contains("出行") { score += 3 }
            if emotion.contains("健身") || emotion.contains("恢复") { score += 3 }
            if emotion.contains("聚餐") || emotion.contains("朋友") { score += 3 }
            return (emotion, score, item.createdAt)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.date > rhs.date }
            return lhs.score > rhs.score
        }

        guard let best = ranked.first else { return nil }
        return "这周也写下了「\(best.text)」"
    }

    private func playbackLifeMarkLine(_ aggregate: LifeMarkAggregate?, fallback: String) -> String {
        guard let aggregate else { return fallback }
        let detail = LifeMarkService.primaryLine(for: aggregate)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return fallback }

        switch aggregate.kind {
        case .context:
            return detail
        case .milestone:
            return "\(aggregate.title) 被放进这一段里，\(detail)"
        case .streak:
            return detail
        case .scene:
            return "\(aggregate.title) 这条线露了出来，\(detail)"
        }
    }

    private func playbackCopySeed(base: String, suffix: String) -> String {
        let trimmed = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? base : "\(base)|\(trimmed)"
    }

    private func contextualMemoryLine(in rows: [HomeItem], range: SummaryPlaybackRange = .week) -> String? {
        if let item = rows.sorted(by: { $0.createdAt > $1.createdAt }).first(where: { HomeItem.isLateWorkCommute($0) }),
           let line = HomeItem.lateWorkCommuteTraceLine(for: item) {
            return line
        }
        let candidates = rows.compactMap { item -> (item: HomeItem, tag: String, score: Int)? in
            let tag = item.displayEmotionTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty else { return nil }
            let text = "\(item.title) \(tag)"
            var score = 0
            if text.contains("雨天") || text.contains("下雨") || text.contains("雪天") { score += 50 }
            if text.contains("第一次") { score += 45 }
            if text.contains("第10次") || text.contains("第 10 次") { score += 42 }
            if text.contains("连续") { score += 36 }
            if text.contains("周末出门") || text.contains("周末路上") { score += 32 }
            guard score > 0 else { return nil }
            return (item, tag, score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.item.createdAt > rhs.item.createdAt }
            return lhs.score > rhs.score
        }

        if let best = candidates.first {
            let day = Self.shortWeekdayFormatter.string(from: best.item.createdAt)
            return "\(day)这笔写着「\(best.tag)」，以后再看会知道当时发生了什么。"
        }

        return photoMemoryLine(in: rows, range: range)
    }

    private func monthlyCategoryStats(_ items: [HomeItem]) -> [String: CategoryMonthlyStat] {
        var buckets: [String: (count: Int, amount: Double)] = [:]
        for item in items {
            let category = item.category.rawValue
            let current = buckets[category] ?? (count: 0, amount: 0)
            buckets[category] = (count: current.count + 1, amount: current.amount + item.amount)
        }
        return buckets.reduce(into: [:]) { result, entry in
            result[entry.key] = CategoryMonthlyStat(
                category: entry.key,
                count: entry.value.count,
                amount: entry.value.amount
            )
        }
    }

    private static func money(_ value: Double) -> String {
        moneyFormatter.string(from: NSNumber(value: value)) ?? "¥\(Int(value.rounded()))"
    }

    private static func evidenceMoney(_ value: Double) -> String {
        evidenceMoneyFormatter.string(from: NSNumber(value: value))
            ?? String(format: "¥%.2f", value)
    }
}
