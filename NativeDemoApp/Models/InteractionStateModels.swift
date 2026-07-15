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

#if DEBUG
struct ReleaseFixtureLaunchConfiguration: Equatable {
    let count: Int
    let reset: Bool

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
        return ReleaseFixtureLaunchConfiguration(
            count: count,
            reset: environmentReset || arguments.contains("-QAReleaseFixtureReset")
        )
    }
}

enum ReleaseFixtureFactory {
    static let supportedCounts: Set<Int> = [100, 1_000, 5_000]

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

    static func makeItems(count: Int) -> [HomeItem] {
        precondition(supportedCounts.contains(count), "Unsupported release fixture size")
        return (0..<count).map(makeItem)
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

    private static func makeItem(index: Int) -> HomeItem {
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
}
#endif
