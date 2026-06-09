import Foundation

struct HomeItem: Identifiable, Codable, Equatable {
    struct DraftMeta: Codable, Equatable {
        enum Status: String, Codable {
            case pending
            case resolved
        }

        var batchId: String
        var importedAt: Date
        var status: Status
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case dining = "餐饮"
        case transport = "交通"
        case shopping = "购物"
        case daily = "日用"
        case entertainment = "娱乐"
        case lodging = "住宿"
        case health = "健康"
        case home = "居家"
        case social = "人情"
        case other = "其他"

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .dining: return "🍜"
            case .transport: return "🚌"
            case .shopping: return "🛍️"
            case .daily: return "🧸"
            case .entertainment: return "🎡"
            case .lodging: return "🏨"
            case .health: return "💊"
            case .home: return "🏠"
            case .social: return "🎁"
            case .other: return "🌟"
            }
        }

        var label: String {
            switch self {
            case .dining: return "吃饭"
            case .transport: return "出行"
            case .shopping: return "购物"
            case .daily: return "日用"
            case .entertainment: return "娱乐"
            case .lodging: return "住宿"
            case .health: return "健康"
            case .home: return "居家"
            case .social: return "人情"
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
    var merchantBrandId: String?
    var draftMeta: DraftMeta?
    var userEditedTitle: Bool?

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        category: Category,
        source: Source = .manual,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        emotionTag: String? = nil,
        merchantBrandId: String? = nil,
        draftMeta: DraftMeta? = nil,
        userEditedTitle: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.category = category
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.emotionTag = emotionTag ?? HomeItem.inferEmotionTag(category: category, amount: amount)
        self.merchantBrandId = merchantBrandId
        self.draftMeta = draftMeta
        self.userEditedTitle = userEditedTitle
    }

    static func inferEmotionTag(category: Category, amount: Double) -> String {
        switch category {
        case .dining: return amount >= 40 ? "小确幸时刻" : "日常一口"
        case .transport: return amount >= 20 ? "去远一点" : "日常出行"
        case .shopping: return amount >= 100 ? "给自己添好心情" : "顺手添置"
        case .daily: return amount >= 50 ? "认真打理日子" : "细水长流"
        case .entertainment: return amount >= 150 ? "难得放松" : "忙里偷闲"
        case .lodging: return amount >= 300 ? "好好停一晚" : "短暂停留"
        case .health: return amount >= 100 ? "认真照顾自己" : "健康小照顾"
        case .home: return amount >= 300 ? "把家安顿好" : "居家小补给"
        case .social: return amount >= 100 ? "心意往来" : "人情小记"
        case .other: return amount >= 80 ? "特别时刻" : "日常碎片"
        }
    }
}

extension HomeItem {
    enum CodingKeys: String, CodingKey {
        case id, title, amount, category, source, createdAt, updatedAt, emotionTag, merchantBrandId, draftMeta, userEditedTitle
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
        merchantBrandId = try container.decodeIfPresent(String.self, forKey: .merchantBrandId)
        draftMeta = try container.decodeIfPresent(DraftMeta.self, forKey: .draftMeta)
        userEditedTitle = try container.decodeIfPresent(Bool.self, forKey: .userEditedTitle)
    }
}

extension HomeItem.Category {
    var defaultRecordTitle: String {
        "\(rawValue)记录"
    }
}

extension HomeItem.Source {
    var displayName: String {
        switch self {
        case .manual: return "手动记录"
        case .ocr: return "智能导入"
        }
    }
}

extension Date {
    var zhBillDateTime: String {
        if !Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year) {
            return Date.zhBillDateTimeWithYearFormatter.string(from: self)
        }
        return Date.zhBillDateTimeFormatter.string(from: self)
    }

    var zhBillTime: String {
        Date.zhBillTimeFormatter.string(from: self)
    }

    private static let zhBillDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    private static let zhBillDateTimeWithYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy\u{5E74}M\u{6708}d\u{65E5} HH:mm"
        return formatter
    }()

    private static let zhBillTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
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
