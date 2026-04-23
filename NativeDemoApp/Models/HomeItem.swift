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

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: Category,
        source: Source = .manual,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.source = source
        self.createdAt = createdAt
    }
}

extension HomeItem {
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case amount
        case category
        case source
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名记录"
        amount = try container.decodeIfPresent(Double.self, forKey: .amount) ?? 0
        category = try container.decodeIfPresent(Category.self, forKey: .category) ?? .other
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}

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
