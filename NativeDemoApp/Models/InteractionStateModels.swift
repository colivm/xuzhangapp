import Foundation

struct UniqueFIFOQueue<Element: Identifiable> where Element.ID: Hashable {
    private(set) var elements: [Element] = []

    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }

    func contains(id: Element.ID) -> Bool {
        elements.contains { $0.id == id }
    }

    @discardableResult
    mutating func enqueue(_ element: Element) -> Bool {
        guard !contains(id: element.id) else { return false }
        elements.append(element)
        return true
    }

    mutating func dequeue() -> Element? {
        guard !elements.isEmpty else { return nil }
        return elements.removeFirst()
    }

    mutating func removeAll() {
        elements.removeAll()
    }
}

struct DeferredRouteQueue<Route> {
    private(set) var pending: Route?

    var hasPendingRoute: Bool { pending != nil }

    mutating func request(_ route: Route) {
        pending = route
    }

    mutating func cancel() {
        pending = nil
    }

    mutating func consume() -> Route? {
        let route = pending
        pending = nil
        return route
    }
}

struct LatestRequestGate {
    private(set) var currentID = UUID()

    mutating func begin() -> UUID {
        let requestID = UUID()
        currentID = requestID
        return requestID
    }

    func accepts(_ requestID: UUID) -> Bool {
        currentID == requestID
    }

    mutating func invalidate() {
        currentID = UUID()
    }
}

enum PostSavePromptKind: String, Codable, Equatable {
    case firstPlayback
    case memoryPhoto
    case sceneReward
}

struct PostSavePromptBudgetState: Codable, Equatable {
    var dayKey: String = ""
    var strongPromptCount = 0
    var lastStrongPromptAt: Date?
}

enum PostSavePromptBudgetPolicy {
    static let dailyStrongPromptLimit = 2
    static let strongPromptCooldown: TimeInterval = 20 * 60

    static func reserving(
        _ kind: PostSavePromptKind,
        state source: PostSavePromptBudgetState,
        now: Date,
        calendar: Calendar = .current
    ) -> (allowed: Bool, state: PostSavePromptBudgetState) {
        let key = dayKey(for: now, calendar: calendar)
        var state = source.dayKey == key
            ? source
            : PostSavePromptBudgetState(dayKey: key)

        if kind == .firstPlayback {
            state.strongPromptCount = min(dailyStrongPromptLimit, state.strongPromptCount + 1)
            state.lastStrongPromptAt = now
            return (true, state)
        }

        guard state.strongPromptCount < dailyStrongPromptLimit else {
            return (false, state)
        }
        if let lastStrongPromptAt = state.lastStrongPromptAt,
           now.timeIntervalSince(lastStrongPromptAt) < strongPromptCooldown {
            return (false, state)
        }
        state.strongPromptCount += 1
        state.lastStrongPromptAt = now
        return (true, state)
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

final class PostSavePromptBudgetStore {
    private static let storageKey = "post_save_prompt_budget_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func reserve(_ kind: PostSavePromptKind, now: Date = .now) -> Bool {
        let current = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(PostSavePromptBudgetState.self, from: $0) }
            ?? PostSavePromptBudgetState()
        let result = PostSavePromptBudgetPolicy.reserving(kind, state: current, now: now)
        if let data = try? JSONEncoder().encode(result.state) {
            defaults.set(data, forKey: Self.storageKey)
        }
        return result.allowed
    }
}

enum HomeJourneyAction: Equatable {
    case resumeOCR
    case continueManualDraft
    case record
    case todayPlayback
    case weekTrace
    case monthTrace
    case review
    case continueRecording
}

enum NewUserProgressionStage: Equatable {
    case recordFirstEntry
    case todayPlayback
    case continueRecording
    case weekTrace
    case monthChapter
    case reviewTasks
}

struct NewUserProgressionSnapshot: Equatable {
    var totalRecordCount: Int
    var hasUnplayedTodayRecords: Bool
    var weekRecordCount: Int
    var monthRecordCount: Int
    var dayOfMonth: Int
    var canPlayWeek: Bool
    var canPlayMonth: Bool
    var hasCompletedCurrentWeekPlayback: Bool
    var hasCompletedCurrentMonthPlayback: Bool
}

enum NewUserProgressionPolicy {
    static func stage(for snapshot: NewUserProgressionSnapshot) -> NewUserProgressionStage {
        if snapshot.totalRecordCount == 0 { return .recordFirstEntry }
        if snapshot.hasUnplayedTodayRecords { return .todayPlayback }
        if PlaybackMaturityPolicy.weekIsReady(recordCount: snapshot.weekRecordCount),
           snapshot.canPlayWeek,
           !snapshot.hasCompletedCurrentWeekPlayback {
            return .weekTrace
        }
        if PlaybackMaturityPolicy.monthIsReady(
            recordCount: snapshot.monthRecordCount,
            dayOfMonth: snapshot.dayOfMonth
        ), snapshot.canPlayMonth, !snapshot.hasCompletedCurrentMonthPlayback {
            return .monthChapter
        }
        if snapshot.hasCompletedCurrentWeekPlayback || snapshot.hasCompletedCurrentMonthPlayback {
            return .reviewTasks
        }
        return .continueRecording
    }

    static func allowsReviewTasks(totalRecordCount: Int) -> Bool {
        totalRecordCount > 0
    }
}

struct HomeJourneySnapshot: Equatable {
    var hasOCRDrafts: Bool
    var hasManualDraft: Bool
    var todayRecordCount: Int
    var hasUnplayedTodayRecords: Bool
    var weekTraceReady: Bool
    var monthTraceReady: Bool
}

enum HomeJourneyActionPolicy {
    static func primaryAction(
        for snapshot: HomeJourneySnapshot,
        progressionStage: NewUserProgressionStage? = nil
    ) -> HomeJourneyAction {
        if snapshot.hasOCRDrafts { return .resumeOCR }
        if snapshot.hasManualDraft { return .continueManualDraft }
        if let progressionStage {
            switch progressionStage {
            case .recordFirstEntry: return .record
            case .todayPlayback: return .todayPlayback
            case .continueRecording: return .continueRecording
            case .weekTrace: return .weekTrace
            case .monthChapter: return .monthTrace
            case .reviewTasks: return .review
            }
        }
        if snapshot.todayRecordCount == 0 { return .record }
        if snapshot.hasUnplayedTodayRecords { return .todayPlayback }
        if snapshot.weekTraceReady { return .weekTrace }
        if snapshot.monthTraceReady { return .monthTrace }
        return .continueRecording
    }

    static func secondaryAction(
        for primary: HomeJourneyAction,
        hasTodayRecords: Bool
    ) -> HomeJourneyAction? {
        switch primary {
        case .resumeOCR, .continueManualDraft:
            return hasTodayRecords ? .todayPlayback : .record
        case .record:
            return .resumeOCR
        case .todayPlayback, .weekTrace, .monthTrace, .review:
            return .continueRecording
        case .continueRecording:
            return hasTodayRecords ? .todayPlayback : nil
        }
    }
}

enum RecordFlowVisibilityPolicy {
    static func showsOCRSideDoor(hasAmountDraft: Bool) -> Bool {
        !hasAmountDraft
    }

    static func showsOptionalDetails(hasValidAmount: Bool) -> Bool {
        hasValidAmount
    }
}

enum TraceRangeContextPolicy {
    static func period(for range: SummaryPlaybackRange) -> StatsPeriod {
        range == .week ? .week : .month
    }

    static func lifeRange(for period: StatsPeriod) -> SummaryPlaybackRange? {
        switch period {
        case .week: return .week
        case .month: return .month
        case .year: return nil
        }
    }
}

enum ReviewTaskIntent: String, CaseIterable, Hashable {
    case query
    case compare
    case backfill

    var title: String {
        switch self {
        case .query: return "查记录"
        case .compare: return "做对比"
        case .backfill: return "补遗漏"
        }
    }

    var subtitle: String {
        switch self {
        case .query: return "按时间、分类或备注查账"
        case .compare: return "比较两段时间的变化"
        case .backfill: return "先生成预览，确认后保存"
        }
    }

    var systemImage: String {
        switch self {
        case .query: return "magnifyingglass"
        case .compare: return "arrow.left.arrow.right"
        case .backfill: return "plus.rectangle.on.rectangle"
        }
    }

    var presetCommand: String {
        switch self {
        case .query: return "帮我看一下过去三天餐饮类的消费"
        case .compare: return "对比本周和上周的消费"
        case .backfill: return "补记今天通勤"
        }
    }
}

enum PlaybackMaturityPolicy {
    static let minimumWeekRecordCount = 3
    static let minimumMonthRecordCount = 3
    static let monthSurfaceStartDay = 25

    static func weekIsReady(recordCount: Int) -> Bool {
        recordCount >= minimumWeekRecordCount
    }

    static func monthIsReady(recordCount: Int, dayOfMonth: Int) -> Bool {
        recordCount >= minimumMonthRecordCount && dayOfMonth >= monthSurfaceStartDay
    }
}

enum PlaybackCompletionPrimaryAction: Equatable {
    case dismiss
    case showMemberPricing
}

enum PlaybackCompletionPolicy {
    static func primaryAction(isMember: Bool) -> PlaybackCompletionPrimaryAction {
        isMember ? .dismiss : .showMemberPricing
    }

    static func primaryTitle(isMember: Bool, memberTitle: String?) -> String {
        isMember ? "完成" : (memberTitle ?? "了解会员")
    }
}

enum MembershipQuotaBaseline {
    static let monthlyInsightTrialTotal = 5

    static var todayPlaybackDaily: Int { DailyFeatureQuotaStore.todayPlaybackFreeLimit }
    static var ocrDaily: Int { DailyFeatureQuotaStore.ocrDailyFreeLimit }
    static var weeklyJournal: Int { SummaryPlaybackQuotaStore.weeklyFreeLimit }
    static var lifetimeMonthChapter: Int { SummaryPlaybackQuotaStore.lifetimeMonthFreeLimit }
    static var monthlyLifeClue: Int { LifeInsightService.freeMonthlyLimit }
}

enum AccessibilityLayoutPolicy {
    static let minimumTapTarget: Double = 44
    static let minimumReadableTextOpacity: Double = 0.72

    static func shouldStackPrimaryActions(
        isAccessibilityTextSize: Bool,
        availableWidth: Double,
        actionCount: Int
    ) -> Bool {
        guard actionCount > 1 else { return false }
        return isAccessibilityTextSize || availableWidth < Double(actionCount) * 132
    }

    static func allowsDecorativeMotion(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

enum MemberLoginContinuationIntent: Equatable {
    case purchase(planID: String)
    case restorePurchases
}

struct MemberLoginContinuationState: Equatable {
    private(set) var pendingLoginIntent: MemberLoginContinuationIntent?
    private(set) var resumedIntent: MemberLoginContinuationIntent?

    mutating func beginLogin(for intent: MemberLoginContinuationIntent) {
        pendingLoginIntent = intent
        resumedIntent = nil
    }

    mutating func loginSucceeded() {
        guard let pendingLoginIntent else { return }
        self.pendingLoginIntent = nil
        resumedIntent = pendingLoginIntent
    }

    mutating func loginCancelled() {
        pendingLoginIntent = nil
    }

    mutating func takeResumedIntent() -> MemberLoginContinuationIntent? {
        let intent = resumedIntent
        resumedIntent = nil
        return intent
    }

    mutating func clearResumedIntent() {
        resumedIntent = nil
    }
}

#if DEBUG
enum ReleaseFixturePhotoProfile: String, Equatable {
    case tiny
    case realistic
}

struct ReleaseFixtureLaunchConfiguration: Equatable {
    let count: Int
    let reset: Bool
    let photoProfile: ReleaseFixturePhotoProfile

    init(
        count: Int,
        reset: Bool,
        photoProfile: ReleaseFixturePhotoProfile = .tiny
    ) {
        self.count = count
        self.reset = reset
        self.photoProfile = photoProfile
    }

    static func resolve(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> ReleaseFixtureLaunchConfiguration? {
        let argumentValue: String? = {
            guard let keyIndex = arguments.firstIndex(of: "-QAReleaseFixtureCount"),
                  arguments.indices.contains(keyIndex + 1) else { return nil }
            return arguments[keyIndex + 1]
        }()
        guard let rawCount = environment["QA_RELEASE_FIXTURE_COUNT"] ?? argumentValue,
              let count = Int(rawCount),
              ReleaseFixtureFactory.supportedCounts.contains(count) else { return nil }
        let environmentReset = ["1", "true", "yes"].contains(
            environment["QA_RELEASE_FIXTURE_RESET", default: ""].lowercased()
        )
        let profileArgument: String? = {
            guard let keyIndex = arguments.firstIndex(of: "-QAReleasePhotoProfile"),
                  arguments.indices.contains(keyIndex + 1) else { return nil }
            return arguments[keyIndex + 1]
        }()
        let photoProfile = ReleaseFixturePhotoProfile(
            rawValue: (environment["QA_RELEASE_PHOTO_PROFILE"] ?? profileArgument ?? "tiny").lowercased()
        ) ?? .tiny
        guard photoProfile != .realistic
                || ReleaseFixtureFactory.realisticSupportedCounts.contains(count) else {
            return nil
        }
        return ReleaseFixtureLaunchConfiguration(
            count: count,
            reset: environmentReset || arguments.contains("-QAReleaseFixtureReset"),
            photoProfile: photoProfile
        )
    }
}

enum ReleaseFixtureFactory {
    static let supportedCounts: Set<Int> = [100, 1_000, 5_000]
    static let realisticSupportedCounts: Set<Int> = [1_000]

    private static let categories: [HomeItem.Category] = [
        .dining, .transport, .shopping, .daily, .entertainment,
        .lodging, .health, .home, .social, .other,
    ]

    private static let titlePrefixes = [
        "餐饮记录", "交通记录", "购物记录", "日用记录", "娱乐记录",
        "住宿记录", "健康记录", "居家记录", "人情记录", "其他记录",
    ]

    private static let emotionTags = [
        "日常餐饮", "日常出行", "日常添置", "日用记录", "轻量娱乐",
        "短暂停留", "健康记录", "居家补给", "见面记录", "日常记录",
    ]

    private static let imageVariants: [Data] = [
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mN4l+MLAAPzAajtSvbZAAAAAElFTkSuQmCC",
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mPwbX8HAALnAcN4NVQmAAAAAElFTkSuQmCC",
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mNw21IBAAK2AXPQ1ccDAAAAAElFTkSuQmCC",
    ].compactMap { Data(base64Encoded: $0) }

    static func makeItems(
        count: Int,
        photoProfile: ReleaseFixturePhotoProfile = .tiny,
        bundle: Bundle = .main
    ) -> [HomeItem] {
        precondition(supportedCounts.contains(count), "Unsupported release fixture size")
        precondition(
            photoProfile != .realistic || realisticSupportedCounts.contains(count),
            "Realistic photo fixture only supports 1,000 records"
        )
        let variants = imageVariants(for: photoProfile, bundle: bundle)
        return (0..<count).map { makeItem(index: $0, imageVariants: variants) }
    }

    static func stableID(index: Int) -> UUID {
        let value = String(format: "10000000-0000-4000-8000-%012llx", Int64(index + 1))
        return UUID(uuidString: value)!
    }

    static func amountMinorUnits(index: Int) -> Int {
        100 + ((index * 7_919 + 37) % 50_000)
    }

    static func createdAt(index: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            timeZone: calendar.timeZone,
            year: 2024 + (index % 3),
            month: 1 + ((index * 7) % 12),
            day: 1 + ((index * 11) % 28),
            hour: 6 + (index % 16),
            minute: (index * 13) % 60
        )
        return calendar.date(from: components)!
    }

    private static func makeItem(index: Int, imageVariants: [Data]) -> HomeItem {
        let categoryIndex = index % categories.count
        let category = categories[categoryIndex]
        let createdAt = createdAt(index: index)
        let source: HomeItem.Source = index % 11 == 0 ? .ocr : .manual
        let draftMeta: HomeItem.DraftMeta? = {
            guard source == .ocr else { return nil }
            let ocrSlot = index / 11
            return HomeItem.DraftMeta(
                batchId: String(format: "release-ocr-%04d", ocrSlot / 4),
                importedAt: createdAt.addingTimeInterval(30),
                status: ocrSlot % 2 == 0 ? .pending : .resolved
            )
        }()
        let memoryContext: HomeItem.MemoryContext? = {
            guard index % 17 == 0 else { return nil }
            let contextIndex = (index / 17) % 3
            return HomeItem.MemoryContext(
                weatherKind: ["sunny", "rain", "cloudy"][contextIndex],
                temperatureCelsius: 18.5 + Double(index % 15),
                cityName: ["杭州", "上海", "成都"][contextIndex],
                semanticPlace: ["公司附近", "家附近", "路上"][contextIndex]
            )
        }()
        let photoSlot = index / 13
        let imageCount = index % 13 == 0 ? 1 + (photoSlot % 3) : 0
        let images = (0..<imageCount).map { ordinal in
            imageVariants[(index + ordinal) % imageVariants.count]
        }
        let usesLegacySingleImage = images.count == 1 && photoSlot % 2 == 0
        let role: PhotoMemoryAssetRole? = images.isEmpty ? nil : [.moment, .place, .object][photoSlot % 3]
        let sceneHint: PhotoMemorySceneHint? = images.isEmpty ? nil : [.experience, .travel, .importantPurchase][photoSlot % 3]

        return HomeItem(
            id: stableID(index: index),
            title: "\(titlePrefixes[categoryIndex]) · 发布夹具 \(String(format: "%04d", index + 1))",
            amount: Double(amountMinorUnits(index: index)) / 100,
            category: category,
            source: source,
            createdAt: createdAt,
            updatedAt: createdAt.addingTimeInterval(TimeInterval((index % 5) * 60)),
            emotionTag: emotionTags[categoryIndex],
            merchantBrandId: index % 23 == 0 ? "qa-brand-\((index / 23) % 5)" : nil,
            draftMeta: draftMeta,
            userEditedTitle: index % 4 == 0 ? true : nil,
            userEditedCategory: index % 7 == 0 ? true : nil,
            categoryCorrectionFrom: index % 29 == 0 ? categories[(categoryIndex - 1 + categories.count) % categories.count] : nil,
            memoryContext: memoryContext,
            scenePackId: index % 19 == 0 ? ["commute", "family", "travel"][(index / 19) % 3] : nil,
            memoryImageData: usesLegacySingleImage ? images.first : nil,
            memoryImageDatas: usesLegacySingleImage ? [] : images,
            coverMemoryImageIndex: images.isEmpty ? nil : photoSlot % images.count,
            memoryAnchorRole: role,
            memoryAnchorSceneHint: sceneHint,
            memoryAnchorCaption: images.isEmpty ? nil : "发布夹具照片顺序 \(photoSlot + 1)。",
            memoryAnchorCreatedAt: images.isEmpty ? nil : createdAt.addingTimeInterval(120)
        )
    }

    private static func imageVariants(
        for profile: ReleaseFixturePhotoProfile,
        bundle: Bundle
    ) -> [Data] {
        guard profile == .realistic else { return imageVariants }
        let loaded = (1...3).compactMap { index -> Data? in
            let name = String(format: "qa_real_%02d", index)
            guard let url = bundle.url(
                forResource: name,
                withExtension: "jpg",
                subdirectory: "QARealPhotos"
            ) else { return nil }
            return try? Data(contentsOf: url, options: [.mappedIfSafe])
        }
        precondition(loaded.count == 3, "PERF-04 realistic photo resources are missing")
        return loaded
    }
}
#endif
