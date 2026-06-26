import Foundation

struct RecordMemoryContextInput {
    let title: String
    let category: HomeItem.Category
    let amount: Double
    let date: Date
    let baseEmotionTag: String
    let existingItems: [HomeItem]
    let weather: WeatherSnapshot?
}

enum RecordMemoryContextService {
    static func weatherKindCode(from snapshot: WeatherSnapshot?) -> String? {
        guard let snapshot else { return nil }
        switch weatherKind(from: snapshot) {
        case .rain:
            return "rain"
        case .snow:
            return "snow"
        case .hot:
            return "hot"
        case .cold:
            return "cold"
        case .normal:
            return "normal"
        }
    }

    static func commuteCardWeatherKindCode(from snapshot: WeatherSnapshot?) -> String? {
        guard let snapshot,
              Date().timeIntervalSince(snapshot.ts) < 10 * 60,
              let code = snapshot.weatherCode else {
            return nil
        }
        if (61...67).contains(code) || (80...82).contains(code) {
            return "rain"
        }
        if (71...77).contains(code) || (85...86).contains(code) {
            return "snow"
        }
        return nil
    }

    static func enhancedEmotionTag(input: RecordMemoryContextInput) -> String {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = "\(title) \(input.baseEmotionTag) \(input.category.rawValue)".lowercased()
        let scene = sceneKind(for: input.category, text: text)
        if let lateCommuteLine = lateWorkCommuteLine(
            date: input.date,
            weather: input.weather,
            scene: scene,
            text: text
        ) {
            return lateCommuteLine
        }

        if let weatherLine = weatherLine(
            weather: input.weather,
            scene: scene,
            category: input.category,
            text: text,
            amount: input.amount
        ) {
            return weatherLine
        }

        if let weekendLine = weekendOutingLine(
            itemCategory: input.category,
            title: title,
            date: input.date,
            existingItems: input.existingItems
        ) {
            return weekendLine
        }

        return input.baseEmotionTag
    }

    private enum MemoryScene: Equatable {
        case commute
        case charging
        case fitness
        case dining
        case coffee
        case groceries
        case medicine
        case social
        case shopping
        case home
        case other(HomeItem.Category)
    }

    private static func sceneKind(for category: HomeItem.Category, text: String) -> MemoryScene {
        if category == .transport, containsAny(text, ["充车", "充电桩", "电车充电", "汽车充电", "车辆充电", "新能源充电", "补能"]) {
            return .charging
        }
        if category == .transport, containsAny(text, ["通勤", "上班", "下班", "地铁", "公交", "早高峰", "晚高峰", "到岗", "到站"]) {
            return .commute
        }
        if category == .health, containsAny(text, ["健身", "锻炼", "运动", "训练", "跑步", "瑜伽", "游泳", "球场"]) {
            return .fitness
        }
        if category == .dining, containsAny(text, ["咖啡", "拿铁", "美式", "奶茶", "饮品", "饮料", "喝的", "茶饮", "果汁", "柠檬茶", "水溶", "c100", "维C", "维他", "瑞幸", "星巴克", "manner", "蜜雪", "喜茶", "奈雪"]) {
            return .coffee
        }
        if category == .dining {
            return .dining
        }
        if category == .daily, containsAny(text, ["买菜", "食材", "生鲜", "水果", "厨房"]) {
            return .groceries
        }
        if category == .health, containsAny(text, ["药", "药店", "医院", "挂号", "问诊", "护理"]) {
            return .medicine
        }
        if category == .social {
            return .social
        }
        if category == .shopping {
            return .shopping
        }
        if category == .home || category == .daily {
            return .home
        }
        return .other(category)
    }

    private static func weatherLine(
        weather: WeatherSnapshot?,
        scene: MemoryScene,
        category: HomeItem.Category,
        text: String,
        amount: Double
    ) -> String? {
        guard let weather else { return nil }
        let weatherKind = weatherKind(from: weather)

        switch (weatherKind, scene) {
        case (.rain, .commute):
            return "雨天通勤，路上慢一点"
        case (.rain, .charging):
            return "雨天给车补能量"
        case (.rain, .dining) where containsAny(text, ["外卖", "热", "饭", "面", "吃"]):
            return "雨天吃口热的"
        case (.rain, .shopping), (.rain, .home):
            if containsAny(text, ["雨伞", "伞", "雨衣", "雨鞋", "防水", "烘干", "除湿"]) {
                return "雨天用品补上"
            }
        case (.snow, .commute):
            return "雪天通勤，慢慢到"
        case (.cold, .commute):
            return "冷天出门也记下"
        case (.cold, .dining):
            return "冷天吃点热乎的"
        case (.hot, .commute):
            return "热天路上辛苦了"
        case (.hot, .coffee):
            return "热天补点清爽"
        default:
            break
        }

        guard weatherKind == .rain, category == .transport, amount <= 40 else { return nil }
        return "雨天出行，路上留痕"
    }

    private static func lateWorkCommuteLine(
        date: Date,
        weather: WeatherSnapshot?,
        scene: MemoryScene,
        text: String
    ) -> String? {
        guard scene == .commute else { return nil }
        let hour = Calendar.current.component(.hour, from: date)
        guard (21...23).contains(hour) || (0..<5).contains(hour) else { return nil }
        guard containsAny(text, ["下班", "通勤", "晚高峰", "加班", "工作", "公司", "单位", "工位", "地铁", "公交", "轨道交通", "打车", "滴滴", "网约车", "回家", "到家"]) else {
            return nil
        }
        let isWorkRoute = containsAny(text, ["下班", "加班", "工作", "公司", "单位", "工位"])
        let rainy = weather.map { weatherKind(from: $0) == .rain } ?? false
        if rainy, isWorkRoute {
            return "晚下班遇上雨，慢点到家"
        }
        if isWorkRoute {
            return "晚下班路上辛苦了"
        }
        if rainy {
            return "晚上通勤遇上雨"
        }
        return "晚上这段通勤"
    }

    private enum MemoryWeather {
        case rain
        case snow
        case hot
        case cold
        case normal
    }

    private static func weatherKind(from snapshot: WeatherSnapshot) -> MemoryWeather {
        if let code = snapshot.weatherCode {
            if (61...67).contains(code) || (80...82).contains(code) {
                return .rain
            }
            if (71...77).contains(code) || (85...86).contains(code) {
                return .snow
            }
        }
        if let temp = snapshot.temp {
            if temp >= 30 { return .hot }
            if temp <= 5 { return .cold }
        }
        return .normal
    }

    private static func weekendOutingLine(
        itemCategory: HomeItem.Category,
        title: String,
        date: Date,
        existingItems: [HomeItem]
    ) -> String? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        guard isWeekend else { return nil }

        let dayItems = existingItems.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
        let dayText = (dayItems.map { "\($0.title) \($0.emotionTag) \($0.category.rawValue)" } + [title]).joined(separator: " ")
        let hasTransport = dayItems.contains { $0.category == .transport } || itemCategory == .transport
        let hasDining = dayItems.contains { $0.category == .dining } || itemCategory == .dining
        let hasLeisureCue = containsAny(dayText, ["景区", "景点", "电影", "展", "公园", "旅行", "酒店", "民宿", "朋友", "聚"])

        if hasTransport, hasDining, dayItems.count >= 1 {
            return hasLeisureCue ? "周末出门玩了一趟" : "周末路上和饭点都有了"
        }
        if hasTransport, hasLeisureCue {
            return "周末出门的路线"
        }
        return nil
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
