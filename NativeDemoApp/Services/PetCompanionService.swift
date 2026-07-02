import Foundation

@MainActor
final class PetCompanionService {
    static let shared = PetCompanionService()

    private let weatherService = WeatherCompanionService.shared
    private let weatherHintCooldownKey = "qingzhang_weather_hint_cooldown_v1"
    private let hotWeatherThreshold = 30.0
    private let monthEndStartDay = 26
    private let monthExpenseSoftThreshold = 3500.0
    private let coolingKeywords = [
        "奶茶", "咖啡", "饮料", "果茶", "柠檬茶", "西瓜", "冰淇淋", "雪糕",
        "冰棍", "冰粉", "甜品", "气泡水", "冷饮", "冰美式", "冰拿铁", "水果",
    ]
    private let rainyCodes: Set<Int> = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]

    private init() {}

    func buildContextualMessage(
        record: HomeItem,
        weather: WeatherSnapshot?,
        settings: AppSettings,
        todayItems: [HomeItem]
    ) async -> String? {
        guard settings.petCompanionEnabled else { return nil }

        if !settings.weatherCompanionEnabled {
            if isDrinkOrSnack(record), shouldNudgeWeather() {
                return PetCompanionCopy.random(PetCompanionCopy.weatherHint, settings: settings)
            }
            if todayExpenseTotal(todayItems) <= 0, Double.random(in: 0..<1) < 0.4 {
                return PetCompanionCopy.weatherContextMessage("noExpenseCalm", settings: settings)
            }
            return PetCompanionCopy.random(PetCompanionCopy.recordSaved, settings: settings)
        }

        if !weatherService.hasLocationPermissionReady {
            weatherService.requestWhenInUseAndRefresh()
            if shouldNudgeWeather() {
                return "还没拿到定位权限，先按普通记录来。"
            }
            return PetCompanionCopy.random(PetCompanionCopy.recordSaved, settings: settings)
        }

        let snapshot = weather ?? weatherService.cachedSnapshot
        if let sceneText = pickSceneLocalPetMessage(recordLike: record, weather: snapshot, settings: settings, todayItems: todayItems) {
            return sceneText
        }
        if let temp = snapshot?.temp, temp <= 12, isDrinkOrSnack(record) {
            return PetCompanionCopy.weatherContextMessage("coldDrink", settings: settings)
        }
        if isWeekend(record.createdAt), (record.category == .entertainment || record.category == .dining) {
            return PetCompanionCopy.weatherContextMessage("weekendRelax", settings: settings)
        }
        if isLateNight(record.createdAt), isDrinkOrSnack(record) {
            return PetCompanionCopy.weatherContextMessage("lateNightSnack", settings: settings)
        }
        return PetCompanionCopy.random(PetCompanionCopy.recordSaved, settings: settings)
    }

    func petClickMessage(settings: AppSettings, todayItems: [HomeItem]) async -> String? {
        guard settings.petCompanionEnabled else { return nil }

        if settings.weatherCompanionEnabled, !weatherService.hasLocationPermissionReady {
            weatherService.requestWhenInUseAndRefresh()
            if shouldNudgeWeather() {
                return "定位权限还没准备好，先按普通记录来。"
            }
            return companionMessage(settings: settings)
        }

        if settings.weatherCompanionEnabled {
            let recordLike = HomeItem(title: "", amount: 0, category: .other, createdAt: Date())
            let snapshot = weatherService.cachedSnapshot
            if let sceneText = pickSceneLocalPetMessage(recordLike: recordLike, weather: snapshot, settings: settings, todayItems: todayItems) {
                return sceneText
            }
            weatherService.refreshWeatherInBackground(refreshGeo: false)
        }

        var pool = PetCompanionCopy.companion + PetCompanionCopy.lightScene
        if !settings.weatherCompanionEnabled, Double.random(in: 0..<1) < 0.22 {
            pool += PetCompanionCopy.weatherHint
        }
        return PetCompanionCopy.random(pool, settings: settings)
    }

    func companionMessage(settings: AppSettings) -> String {
        PetCompanionCopy.random(PetCompanionCopy.companion + PetCompanionCopy.lightScene, settings: settings)
    }

    func lightSceneMessage(settings: AppSettings) -> String {
        PetCompanionCopy.random(PetCompanionCopy.lightScene, settings: settings)
    }

    private func pickSceneLocalPetMessage(
        recordLike: HomeItem,
        weather: WeatherSnapshot?,
        settings: AppSettings,
        todayItems: [HomeItem]
    ) -> String? {
        if let temp = weather?.temp, temp >= hotWeatherThreshold, !hasCoolingExpenseToday(todayItems) {
            return PetCompanionCopy.weatherContextMessage("hotNoCool", settings: settings)
        }
        if isRainyWeatherCode(weather?.weatherCode) {
            return PetCompanionCopy.weatherContextMessage("rainyHome", settings: settings)
        }
        if hasMonthExpensePressure(recordLike: recordLike, items: todayItems) {
            return PetCompanionCopy.weatherContextMessage("monthEndSoft", settings: settings)
        }
        if isWeekend(recordLike.createdAt) {
            return PetCompanionCopy.weatherContextMessage("weekendHealing", settings: settings)
        }
        if commuteExpenseCountToday(todayItems) >= 2 {
            return PetCompanionCopy.weatherContextMessage("commuteSteady", settings: settings)
        }
        if hasGroceryExpenseToday(todayItems) {
            return PetCompanionCopy.weatherContextMessage("groceryWarm", settings: settings)
        }
        if todayExpenseTotal(todayItems) >= 300 {
            return PetCompanionCopy.weatherContextMessage("highSpendComfort", settings: settings)
        }
        if todayExpenseTotal(todayItems) <= 0 {
            return PetCompanionCopy.weatherContextMessage("noExpenseCalm", settings: settings)
        }
        return nil
    }

    private func shouldNudgeWeather() -> Bool {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: weatherHintCooldownKey) as? Date ?? .distantPast
        guard now.timeIntervalSince(last) >= 20 * 60 * 60 else { return false }
        UserDefaults.standard.set(now, forKey: weatherHintCooldownKey)
        return true
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func isMonthEnd(_ date: Date) -> Bool {
        Calendar.current.component(.day, from: date) >= monthEndStartDay
    }

    private func isLateNight(_ date: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 22 || hour <= 3
    }

    private func isDrinkOrSnack(_ item: HomeItem) -> Bool {
        let text = "\(item.title) \(item.category.rawValue)"
        return ["奶茶", "咖啡", "饮品", "热饮", "宵夜", "零食", "甜品"].contains { text.localizedCaseInsensitiveContains($0) }
    }

    private func todayPaidItems(_ items: [HomeItem]) -> [HomeItem] {
        items.filter { Calendar.current.isDateInToday($0.createdAt) && $0.amount > 0 }
    }

    private func todayExpenseTotal(_ items: [HomeItem]) -> Double {
        todayPaidItems(items).reduce(0) { $0 + $1.amount }
    }

    private func commuteExpenseCountToday(_ items: [HomeItem]) -> Int {
        todayPaidItems(items).filter { $0.category == .transport }.count
    }

    private func hasGroceryExpenseToday(_ items: [HomeItem]) -> Bool {
        todayPaidItems(items).contains { item in
            let text = "\(item.title) \(item.category.rawValue)"
            return ["超市", "买菜", "菜市场", "日用", "杂货", "水果", "餐饮"].contains { text.localizedCaseInsensitiveContains($0) }
        }
    }

    private func hasCoolingExpenseToday(_ items: [HomeItem]) -> Bool {
        todayPaidItems(items).contains { item in
            let text = "\(item.title) \(item.category.rawValue)"
            return coolingKeywords.contains { text.localizedCaseInsensitiveContains($0) }
        }
    }

    private func isRainyWeatherCode(_ code: Int?) -> Bool {
        guard let code else { return false }
        return rainyCodes.contains(code)
    }

    private func hasMonthExpensePressure(recordLike: HomeItem, items: [HomeItem]) -> Bool {
        guard isMonthEnd(recordLike.createdAt) else { return false }
        let monthItems = items.filter {
            Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month) && $0.amount > 0
        }
        let total = monthItems.reduce(0) { $0 + $1.amount }
        return total >= monthExpenseSoftThreshold
    }
}
