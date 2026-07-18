import Foundation

enum PetCompanionMessagePolicy {
    private static let rainyCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]
    private static let sensitiveKeywords = [
        "借款", "还款", "贷款", "欠款", "债务", "账号", "密码", "地址", "成人",
    ]
    private static let commuteKeywords = [
        "通勤", "上班", "下班", "早高峰", "晚高峰", "到岗", "地铁", "公交",
    ]
    private static let coffeeKeywords = [
        "咖啡", "拿铁", "美式", "卡布奇诺", "摩卡", "瑞幸", "库迪", "星巴克",
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
            return savedRecordCandidates(for: focusRecord, calendar: calendar)
        }

        let commuteItems = paidToday.filter(Self.isCommute)
        let coffeeItems = paidToday.filter(Self.isCoffee)
        let groceryItems = paidToday.filter(Self.isGrocery)
        let currentWeatherSuffix = currentWeatherLine(currentWeather)

        if !commuteItems.isEmpty, !coffeeItems.isEmpty {
            return appendCurrentWeather(
                [
                    .init(id: "day.commute_coffee.1", text: "今天记了一趟通勤，也留下一杯咖啡。"),
                    .init(id: "day.commute_coffee.2", text: "今天的通勤和咖啡都已经记下了。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if let hotCommute = commuteItems.first(where: { normalizedWeatherKind($0.memoryContext?.weatherKind) == "hot" }) {
            return appendCurrentWeatherIfNeeded(
                [
                    .init(id: "day.hot_commute.1", text: "今天有一趟通勤是在热天里记下的。"),
                    .init(id: "day.hot_commute.2", text: "今天那趟热天通勤已经留在账本里。"),
                ],
                suffix: currentWeatherSuffix,
                recordedWeatherKind: normalizedWeatherKind(hotCommute.memoryContext?.weatherKind)
            )
        }

        if commuteItems.count >= 2 {
            return appendCurrentWeather(
                [
                    .init(id: "day.two_commutes.1", text: "今天两趟通勤都记下了。"),
                    .init(id: "day.two_commutes.2", text: "今天来回的通勤记录都在。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if !groceryItems.isEmpty, paidToday.count >= 2 {
            return appendCurrentWeather(
                [
                    .init(id: "day.grocery.1", text: "今天的买菜和日常记录都留好了。"),
                    .init(id: "day.grocery.2", text: "今天有一笔生活补给，其他几笔也都在。"),
                ],
                suffix: currentWeatherSuffix
            )
        }

        if paidToday.isEmpty {
            return appendCurrentWeather(PetCompanionCopy.noRecords, suffix: currentWeatherSuffix)
        }

        if paidToday.count == 1 {
            return appendCurrentWeather(PetCompanionCopy.oneRecord, suffix: currentWeatherSuffix)
        }

        let hour = calendar.component(.hour, from: now)
        let fallback = hour >= 21 ? PetCompanionCopy.evening : PetCompanionCopy.severalRecords
        return appendCurrentWeather(fallback, suffix: currentWeatherSuffix)
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

        if isCoffee(record) {
            return [.init(id: "saved.coffee", text: "这杯咖啡已经记下了。")]
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

    private static func appendCurrentWeatherIfNeeded(
        _ messages: [PetCompanionCopy.Message],
        suffix: String?,
        recordedWeatherKind: String?
    ) -> [PetCompanionCopy.Message] {
        guard recordedWeatherKind != currentWeatherKind(from: suffix) else { return messages }
        return appendCurrentWeather(messages, suffix: suffix)
    }

    private static func appendCurrentWeather(
        _ messages: [PetCompanionCopy.Message],
        suffix: String?
    ) -> [PetCompanionCopy.Message] {
        guard let suffix else { return messages }
        return messages.map { message in
            .init(id: "\(message.id).current_weather", text: "\(message.text)\(suffix)")
        }
    }

    private static func currentWeatherLine(_ snapshot: WeatherSnapshot?) -> String? {
        guard let snapshot else { return nil }
        if let code = snapshot.weatherCode, rainyCodes.contains(code) {
            return "现在外面在下雨。"
        }
        if let temp = snapshot.temp, temp >= 30 {
            return "现在外面天气偏热。"
        }
        if let temp = snapshot.temp, temp <= 8 {
            return "现在外面天气偏冷。"
        }
        return nil
    }

    private static func currentWeatherKind(from suffix: String?) -> String? {
        guard let suffix else { return nil }
        if suffix.contains("下雨") { return "rain" }
        if suffix.contains("偏热") { return "hot" }
        if suffix.contains("偏冷") { return "cold" }
        return nil
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
