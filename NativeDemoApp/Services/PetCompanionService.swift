import Foundation

enum PetCompanionMessagePolicy {
    private static let rainyCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
    private static let snowyCodes: Set<Int> = [71, 73, 75, 77, 85, 86]
    private static let sensitiveKeywords = [
        "借款", "还款", "贷款", "欠款", "债务", "账号", "密码", "地址", "成人",
    ]
    private static let commuteKeywords = [
        "通勤", "上班", "下班", "早高峰", "晚高峰", "到岗", "地铁", "公交",
    ]
    private static let coffeeKeywords = [
        "咖啡", "拿铁", "美式", "卡布奇诺", "摩卡", "瑞幸", "库迪", "星巴克",
    ]
    private static let beverageKeywords = [
        "奶茶", "饮料", "饮品", "果茶", "柠檬茶", "可乐", "雪碧", "汽水", "果汁",
        "气泡水", "矿泉水", "苏打水", "茶饮", "咖啡", "拿铁", "美式",
    ]
    private static let coolingKeywords = [
        "冷饮", "冰饮", "冰美式", "冰拿铁", "冰咖啡", "冰奶茶", "冰茶", "冰沙",
        "雪糕", "冰淇淋", "冰棍", "冰粉",
    ]
    private static let hotDrinkKeywords = [
        "热饮", "热咖啡", "热拿铁", "热美式", "热奶茶", "热可可",
    ]
    private static let groceryKeywords = [
        "买菜", "菜市场", "生鲜", "超市", "山姆", "永辉", "大润发", "钱大妈",
    ]

    static func candidates(
        focusRecord: HomeItem?,
        todayItems: [HomeItem],
        currentWeather: WeatherSnapshot?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PetCompanionCopy.Message] {
        let paidToday = todayItems
            .filter { calendar.isDate($0.createdAt, inSameDayAs: now) && $0.amount > 0 }
            .sorted { $0.createdAt < $1.createdAt }

        if let focusRecord {
            let saved = savedRecordCandidates(for: focusRecord, calendar: calendar)
            guard calendar.isDate(focusRecord.createdAt, inSameDayAs: now),
                  let careSuffix = currentWeatherCareSuffix(currentWeather, now: now) else {
                return saved
            }
            return saved.map { message in
                .init(
                    id: "\(message.id).current_weather_care",
                    text: "\(message.text)\(careSuffix)"
                )
            }
        }

        let safeToday = paidToday.filter { !isSensitive($0) }
        let commuteItems = safeToday.filter(Self.isCommute)
        let coffeeItems = safeToday.filter(Self.isCoffee)
        let beverageItems = safeToday.filter(Self.isBeverage)
        let coolingItems = safeToday.filter(Self.isCoolingItem)
        let hotDrinkItems = safeToday.filter(Self.isHotDrink)
        let groceryItems = paidToday.filter(Self.isGrocery)
        let currentWeatherSuffix = currentWeatherCareSuffix(currentWeather, now: now)

        if !commuteItems.isEmpty, !coffeeItems.isEmpty {
            return appendCurrentWeatherCare(
                [
                    .init(id: "day.commute_coffee.1", text: "今天记了一趟通勤，也留下一杯咖啡。"),
                    .init(id: "day.commute_coffee.2", text: "今天的通勤和咖啡都已经记下了。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if commuteItems.contains(where: { normalizedWeatherKind($0.memoryContext?.weatherKind) == "hot" }) {
            return appendCurrentWeatherCare(
                [
                    .init(id: "day.hot_commute.1", text: "今天有一趟通勤是在热天里记下的。"),
                    .init(id: "day.hot_commute.2", text: "今天那趟热天通勤已经留在账本里。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if let weatherKind = currentWeatherKind(currentWeather, now: now) {
            switch weatherKind {
            case .hot:
                if !coolingItems.isEmpty {
                    return appendCurrentWeatherCare(
                        [
                            .init(id: "day.hot.cooling.1", text: "今天记下了一笔冷饮。"),
                            .init(id: "day.hot.cooling.2", text: "今天有一笔冷饮记录。"),
                        ],
                        suffix: currentWeatherSuffix
                    )
                }
                if !beverageItems.isEmpty {
                    let noun = coffeeItems.isEmpty ? "饮品" : "咖啡"
                    return appendCurrentWeatherCare(
                        [
                            .init(id: "day.hot.beverage.1", text: "今天记了一杯\(noun)。"),
                            .init(id: "day.hot.beverage.2", text: "今天这笔\(noun)已经记下了。"),
                        ],
                        suffix: currentWeatherSuffix
                    )
                }
                if !commuteItems.isEmpty {
                    return appendCurrentWeatherCare(
                        [
                            .init(id: "day.hot.commute.1", text: "今天记过一趟通勤。"),
                            .init(id: "day.hot.commute.2", text: "今天有一笔通勤记录。"),
                        ],
                        suffix: currentWeatherSuffix
                    )
                }
            case .cold:
                if !hotDrinkItems.isEmpty {
                    return appendCurrentWeatherCare(
                        [
                            .init(id: "day.cold.hot_drink.1", text: "天气偏冷，这笔热饮已经记下了。"),
                            .init(id: "day.cold.hot_drink.2", text: "今天有一笔热饮记录。"),
                        ],
                        suffix: currentWeatherSuffix
                    )
                }
                if !coffeeItems.isEmpty {
                    return appendCurrentWeatherCare(
                        [.init(id: "day.cold.coffee", text: "今天记了一杯咖啡。")],
                        suffix: currentWeatherSuffix
                    )
                }
            case .rain, .snow:
                if !commuteItems.isEmpty {
                    return appendCurrentWeatherCare(
                        [
                            .init(id: "day.weather.commute.1", text: "今天记过一趟通勤。"),
                            .init(id: "day.weather.commute.2", text: "今天有一笔通勤记录。"),
                        ],
                        suffix: currentWeatherSuffix
                    )
                }
            }

            return weatherCareMessages(for: weatherKind)
        }

        if commuteItems.count >= 2 {
            return appendCurrentWeatherCare(
                [
                    .init(id: "day.two_commutes.1", text: "今天两趟通勤都记下了。"),
                    .init(id: "day.two_commutes.2", text: "今天来回的通勤记录都在。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if !groceryItems.isEmpty, paidToday.count >= 2 {
            return appendCurrentWeatherCare(
                [
                    .init(id: "day.grocery.1", text: "今天的买菜和日常记录都留好了。"),
                    .init(id: "day.grocery.2", text: "今天有一笔生活补给，其他几笔也都在。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if paidToday.isEmpty {
            return PetCompanionCopy.noRecords
        }

        if paidToday.count == 1 {
            return PetCompanionCopy.oneRecord
        }

        let hour = calendar.component(.hour, from: now)
        let fallback = hour >= 21 ? PetCompanionCopy.evening : PetCompanionCopy.severalRecords
        return fallback
    }

    private static func savedRecordCandidates(
        for record: HomeItem,
        calendar: Calendar
    ) -> [PetCompanionCopy.Message] {
        guard !isSensitive(record) else { return PetCompanionCopy.recordSaved }

        if record.userEditedTitle == true,
           let explicitMessage = safeExplicitUserMessage(record.title) {
            return [explicitMessage]
        }

        let weatherKind = normalizedWeatherKind(record.memoryContext?.weatherKind)
        if isCommute(record) {
            let timeWord = periodWord(for: record.createdAt, calendar: calendar)
            switch weatherKind {
            case "hot":
                return [.init(id: "saved.commute.hot", text: "\(timeWord)这趟通勤是在热天里记下的。")]
            case "rain":
                return [.init(id: "saved.commute.rain", text: "\(timeWord)这趟雨天通勤已经记下了。")]
            case "snow":
                return [.init(id: "saved.commute.snow", text: "\(timeWord)这趟雪天通勤已经记下了。")]
            case "cold":
                return [.init(id: "saved.commute.cold", text: "\(timeWord)这趟冷天通勤已经记下了。")]
            default:
                if isLateNight(record.createdAt, calendar: calendar) {
                    return [.init(id: "saved.commute.late", text: "这趟深夜通勤已经记下了。")]
                }
                return [.init(id: "saved.commute", text: "这趟通勤已经记下了。")]
            }
        }

        if isCoolingItem(record) {
            return [.init(id: "saved.cooling", text: "这笔冷饮已经记下了。")]
        }

        if isCoffee(record) {
            return [.init(id: "saved.coffee", text: "这杯咖啡已经记下了。")]
        }

        if isBeverage(record) {
            return [.init(id: "saved.beverage", text: "这笔饮品已经记下了。")]
        }

        if isParking(record) {
            return [.init(id: "saved.parking", text: "这笔停车费已经记下了。")]
        }

        if isGrocery(record) {
            return [.init(id: "saved.grocery", text: "这笔生活补给已经记下了。")]
        }

        return PetCompanionCopy.recordSaved
    }

    private static func safeExplicitUserMessage(_ title: String) -> PetCompanionCopy.Message? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.localizedCaseInsensitiveContains("终于到家") {
            return .init(id: "saved.user.arrived_home", text: "你写了“终于到家”，这笔我替你留好了。")
        }
        if trimmed.localizedCaseInsensitiveContains("今天好累") {
            return .init(id: "saved.user.tired", text: "你写了“今天好累”，这笔已经留好了。")
        }
        return nil
    }

    private static func appendCurrentWeatherCare(
        _ messages: [PetCompanionCopy.Message],
        suffix: String?
    ) -> [PetCompanionCopy.Message] {
        guard let suffix else { return messages }
        return messages.map { message in
            .init(id: "\(message.id).current_weather_care", text: "\(message.text)\(suffix)")
        }
    }

    private enum CurrentWeatherKind {
        case hot
        case cold
        case rain
        case snow
    }

    private static func currentWeatherKind(
        _ snapshot: WeatherSnapshot?,
        now: Date
    ) -> CurrentWeatherKind? {
        guard let snapshot,
              now.timeIntervalSince(snapshot.ts) >= 0,
              now.timeIntervalSince(snapshot.ts) <= 60 * 60 else { return nil }
        if let code = snapshot.weatherCode, snowyCodes.contains(code) { return .snow }
        if let code = snapshot.weatherCode, rainyCodes.contains(code) { return .rain }
        if let temp = snapshot.temp, temp >= 30 { return .hot }
        if let temp = snapshot.temp, temp <= 8 { return .cold }
        return nil
    }

    private static func currentWeatherCareSuffix(
        _ snapshot: WeatherSnapshot?,
        now: Date
    ) -> String? {
        guard let kind = currentWeatherKind(snapshot, now: now) else { return nil }
        return weatherCareMessages(for: kind).first?.text
    }

    private static func weatherCareMessages(for kind: CurrentWeatherKind) -> [PetCompanionCopy.Message] {
        switch kind {
        case .hot: return PetCompanionCopy.hotWeatherCare
        case .cold: return PetCompanionCopy.coldWeatherCare
        case .rain: return PetCompanionCopy.rainyWeatherCare
        case .snow: return PetCompanionCopy.snowyWeatherCare
        }
    }

    private static func normalizedWeatherKind(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue.lowercased()
        if ["hot", "heat", "high_temperature"].contains(normalized) { return "hot" }
        if ["rain", "rainy"].contains(normalized) { return "rain" }
        if ["snow", "snowy"].contains(normalized) { return "snow" }
        if ["cold", "low_temperature"].contains(normalized) { return "cold" }
        return nil
    }

    private static func isSensitive(_ item: HomeItem) -> Bool {
        if item.category == .health || item.category == .social { return true }
        return containsAny(item.title, sensitiveKeywords)
    }

    private static func isCommute(_ item: HomeItem) -> Bool {
        guard item.category == .transport else { return false }
        return item.scenePackId == "commute" || containsAny(item.title, commuteKeywords)
    }

    private static func isCoffee(_ item: HomeItem) -> Bool {
        item.category == .dining && containsAny(item.title, coffeeKeywords)
    }

    private static func isBeverage(_ item: HomeItem) -> Bool {
        item.category == .dining && containsAny(item.title, beverageKeywords)
    }

    private static func isCoolingItem(_ item: HomeItem) -> Bool {
        item.category == .dining && containsAny(item.title, coolingKeywords)
    }

    private static func isHotDrink(_ item: HomeItem) -> Bool {
        item.category == .dining && containsAny(item.title, hotDrinkKeywords)
    }

    private static func isGrocery(_ item: HomeItem) -> Bool {
        guard item.category == .daily || item.category == .dining || item.category == .shopping else { return false }
        return containsAny(item.title, groceryKeywords)
    }

    private static func isParking(_ item: HomeItem) -> Bool {
        item.category == .transport && containsAny(item.title, ["停车", "停车费", "车位"])
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func isLateNight(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 22 || hour <= 3
    }

    private static func periodWord(for date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 0..<11: return "早上"
        case 11..<14: return "中午"
        case 14..<18: return "下午"
        default: return "晚上"
        }
    }
}

@MainActor
final class PetCompanionService {
    static let shared = PetCompanionService()

    private let weatherService = WeatherCompanionService.shared
    private var recentMessageIDs: [String] = []
    private let interactionHintDefaultsKey = "pet_interaction_hint_seen_v1"

    private init() {}

    func buildContextualMessage(
        record: HomeItem,
        weather: WeatherSnapshot?,
        settings: AppSettings,
        todayItems: [HomeItem]
    ) async -> String? {
        guard settings.petCompanionEnabled else { return nil }

        let snapshot: WeatherSnapshot?
        if settings.weatherCompanionEnabled {
            if !weatherService.hasLocationPermissionReady {
                weatherService.requestWhenInUseAndRefresh()
            }
            snapshot = weather ?? weatherService.cachedSnapshot
            weatherService.refreshWeatherInBackground(refreshGeo: false)
        } else {
            snapshot = nil
        }

        let candidates = PetCompanionMessagePolicy.candidates(
            focusRecord: record,
            todayItems: todayItems,
            currentWeather: snapshot
        )
        return selectMessage(from: candidates, settings: settings)
    }

    func petClickMessage(settings: AppSettings, todayItems: [HomeItem]) async -> String? {
        guard settings.petCompanionEnabled else { return nil }

        if PetCompanionInteractionHintPolicy.shouldPresent(
            hasPresented: UserDefaults.standard.bool(forKey: interactionHintDefaultsKey)
        ) {
            UserDefaults.standard.set(true, forKey: interactionHintDefaultsKey)
            return selectMessage(from: PetCompanionCopy.interactionHints, settings: settings)
        }

        let snapshot: WeatherSnapshot?
        if settings.weatherCompanionEnabled {
            if !weatherService.hasLocationPermissionReady {
                weatherService.requestWhenInUseAndRefresh()
            }
            snapshot = weatherService.cachedSnapshot
            weatherService.refreshWeatherInBackground(refreshGeo: false)
        } else {
            snapshot = nil
        }

        let candidates = PetCompanionMessagePolicy.candidates(
            focusRecord: nil,
            todayItems: todayItems,
            currentWeather: snapshot
        )
        return selectMessage(from: candidates, settings: settings)
    }

    func companionMessage(settings: AppSettings) -> String {
        selectMessage(from: PetCompanionCopy.companion, settings: settings)
            ?? PetCompanionCopy.personalized(PetCompanionCopy.companion[0], settings: settings).text
    }

    func lightSceneMessage(settings: AppSettings) -> String {
        selectMessage(from: PetCompanionCopy.oneRecord, settings: settings)
            ?? PetCompanionCopy.oneRecord[0].text
    }

    private func selectMessage(
        from candidates: [PetCompanionCopy.Message],
        settings: AppSettings
    ) -> String? {
        guard !candidates.isEmpty else { return nil }
        let recent = Set(recentMessageIDs.suffix(3))
        let selected = candidates.first(where: { !recent.contains($0.id) }) ?? candidates[0]
        recentMessageIDs.append(selected.id)
        if recentMessageIDs.count > 6 {
            recentMessageIDs.removeFirst(recentMessageIDs.count - 6)
        }
        return PetCompanionCopy.personalized(selected, settings: settings).text
    }
}

enum PetCompanionInteractionHintPolicy {
    static func shouldPresent(hasPresented: Bool) -> Bool {
        !hasPresented
    }
}
