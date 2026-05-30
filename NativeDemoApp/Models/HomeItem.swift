import Foundation

struct HomeItem: Identifiable, Codable, Equatable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case dining = "餐饮"
        case shopping = "购物"
        case transport = "交通"
        case entertainment = "娱乐"
        case daily = "日用"
        case lodging = "住宿"
        case other = "其他"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .dining: return "🍜"
            case .shopping: return "🛍️"
            case .transport: return "🚌"
            case .entertainment: return "🎡"
            case .daily: return "🧸"
            case .lodging: return "🏨"
            case .other: return "🌟"
            }
        }

        var label: String {
            switch self {
            case .dining: return "吃饭"
            case .shopping: return "购物"
            case .transport: return "出行"
            case .entertainment: return "娱乐"
            case .daily: return "日用"
            case .lodging: return "住宿"
            case .other: return "其他"
            }
        }

        var displayName: String { "\(emoji) \(label)" }
    }

    enum Source: String, Codable {
        case manual
        case ocr
    }

    let id: UUID
    var title: String
    var amount: Double
    var category: Category
    var source: Source
    var createdAt: Date
    var updatedAt: Date
    var emotionTag: String

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: Category,
        source: Source = .manual,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        emotionTag: String? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.emotionTag = emotionTag ?? HomeItem.inferEmotionTag(category: category, amount: amount)
    }

    static func inferEmotionTag(category: Category, amount: Double) -> String {
        switch category {
        case .dining: return amount >= 40 ? "小确幸时刻" : "日常补给"
        case .shopping: return amount >= 100 ? "给自己加点好心情" : "生活补给"
        case .transport: return amount >= 20 ? "远途奔波" : "日常通勤"
        case .entertainment: return amount >= 150 ? "难得放松" : "忙里偷闲"
        case .daily: return amount >= 50 ? "用心生活" : "细水长流"
        case .lodging: return amount >= 300 ? "旅途休憩" : "短暂停留"
        case .other: return amount >= 80 ? "特别时刻" : "日常碎片"
        }
    }
}

extension HomeItem {
    enum CodingKeys: String, CodingKey {
        case id, title, amount, category, source, createdAt, updatedAt, emotionTag
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名记录"
        amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .other
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        emotionTag = try container.decodeIfPresent(String.self, forKey: .emotionTag)
            ?? HomeItem.inferEmotionTag(category: category, amount: amount)
    }
}

// MARK: - Shared CNY Format

extension FormatStyle where Self == FloatingPointFormatStyle<Double>.Currency {
    static var cny: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: "CNY").locale(Locale(identifier: "zh_CN"))
    }
}

// MARK: - Daily Insight

struct DailyInsight: Identifiable, Codable, Equatable {
    let id: UUID
    let dayKey: String
    var summary: String
    var action: String
    var encourage: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dayKey: String,
        summary: String,
        action: String,
        encourage: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.summary = summary
        self.action = action
        self.encourage = encourage
        self.createdAt = createdAt
    }
}
