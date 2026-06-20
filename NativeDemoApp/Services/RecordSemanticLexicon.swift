import Foundation
import os.log

// Central semantic lexicon for record titles, category hints, and OCR keyword cues.
struct RecordSemanticKeywordRule: Decodable {
    let category: HomeItem.Category
    let score: Double
    let keywords: [String]
}

struct RecordSemanticComboRule: Decodable {
    let keywords: [String]
    let scores: [HomeItem.Category: Double]

    init(keywords: [String], scores: [HomeItem.Category: Double]) {
        self.keywords = keywords
        self.scores = scores
    }

    private enum CodingKeys: String, CodingKey {
        case keywords
        case scores
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keywords = try container.decode([String].self, forKey: .keywords)
        let rawScores = try container.decode([String: Double].self, forKey: .scores)
        scores = rawScores.reduce(into: [HomeItem.Category: Double]()) { result, entry in
            guard let category = HomeItem.Category(rawValue: entry.key) else { return }
            result[category] = entry.value
        }
    }
}

struct RecordSemanticEmotionRule: Decodable {
    let id: String
    let category: HomeItem.Category
    let keywords: [String]
}

private struct RecordSceneLexiconPayload: Decodable {
    let version: Int
    let keywordRules: [RecordSemanticKeywordRule]
    let ocrKeywordRules: [RecordSemanticKeywordRule]
    let comboRules: [RecordSemanticComboRule]
    let emotionKeywordRules: [RecordSemanticEmotionRule]
}

enum RecordSemanticLexicon {
    static let emptyNoteTitle = "未填写备注"
    static let keywordRules: [RecordSemanticKeywordRule] = payload.keywordRules
    static let ocrKeywordRules: [RecordSemanticKeywordRule] = payload.ocrKeywordRules
    static let comboRules: [RecordSemanticComboRule] = payload.comboRules
    static let emotionKeywordRules: [RecordSemanticEmotionRule] = payload.emotionKeywordRules

    private static let payload: RecordSceneLexiconPayload = {
        guard let url = Bundle.main.url(forResource: "RecordSceneLexicon", withExtension: "json") else {
            return fallbackPayload(reason: "missing_bundle_resource")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(RecordSceneLexiconPayload.self, from: data)
            guard !decoded.keywordRules.isEmpty else {
                return fallbackPayload(reason: "empty_keyword_rules")
            }
            return decoded
        } catch {
            return fallbackPayload(reason: "decode_failed:\(error)")
        }
    }()

    private static func fallbackPayload(reason: String) -> RecordSceneLexiconPayload {
        os_log("lexicon_load_failed: %{public}@", log: .default, type: .error, reason)
        #if DEBUG
        assertionFailure("RecordSceneLexicon fallback used: \(reason)")
        #endif
        let fallback = minimalFallbackPayload
        #if DEBUG
        assert(!fallback.keywordRules.isEmpty)
        assert(Set(fallback.keywordRules.compactMap { rule in
            rule.keywords.contains("地铁") ? rule.category : nil
        }).contains(.transport))
        #endif
        return fallback
    }

    private static let minimalFallbackPayload = RecordSceneLexiconPayload(
        version: 0,
        keywordRules: [
            .init(category: .transport, score: 4.0, keywords: ["地铁", "公交", "打车", "滴滴", "充电", "充电桩", "高铁", "机票", "机场", "路费", "到站", "早高峰", "晚高峰", "顺利到达", "准时出门", "车程", "通勤"]),
            .init(category: .dining, score: 4.8, keywords: ["咖啡", "奶茶", "早餐", "早饭", "午餐", "晚餐", "夜宵", "宵夜", "外卖", "饭", "餐", "一顿", "这顿", "吃", "垫一下", "垫一口", "夜里补", "热食", "热乎", "轻食", "小食", "点心", "补点能量", "吃一口", "饮品", "拿铁", "美式"]),
            .init(category: .shopping, score: 4.0, keywords: ["淘宝", "京东", "购物", "下单", "快递", "衣服", "鞋", "数码"]),
            .init(category: .daily, score: 3.0, keywords: ["超市", "日用品", "纸巾", "洗衣", "打印", "理发", "宠物"]),
            .init(category: .entertainment, score: 3.0, keywords: ["电影", "影院", "游戏", "会员", "演唱会", "门票"]),
            .init(category: .lodging, score: 4.0, keywords: ["酒店", "民宿", "住宿", "宾馆"]),
            .init(category: .health, score: 4.0, keywords: ["药店", "医院", "挂号", "体检", "健身", "跑步"]),
            .init(category: .home, score: 4.0, keywords: ["房租", "水电", "电费", "燃气", "物业", "宽带"]),
            .init(category: .social, score: 4.0, keywords: ["红包", "礼物", "请客", "份子钱", "探望"]),
            .init(category: .other, score: 1.0, keywords: ["手续费", "服务费"]),
        ],
        ocrKeywordRules: [],
        comboRules: [
            .init(keywords: ["高铁", "机票", "机场", "车站", "返程", "出发"], scores: [.transport: 3.2, .lodging: 1.2, .entertainment: 1.0])
        ],
        emotionKeywordRules: [
            .init(id: "fitness", category: .health, keywords: ["运动", "健身", "训练", "跑步", "瑜伽", "补给", "能量", "护具", "恢复", "锻炼"]),
            .init(id: "drink", category: .dining, keywords: ["饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "茶饮", "奶茶", "咖啡", "拿铁", "美式", "冰饮"]),
            .init(id: "transport", category: .transport, keywords: ["地铁", "公交", "打车", "出租", "网约车", "路费", "车程", "通勤", "上班", "下班", "到站", "早高峰", "晚高峰", "顺利到达", "准时出门", "返程", "回家"]),
            .init(id: "meal", category: .dining, keywords: ["食堂", "午餐", "简餐", "轻食", "小食", "点心", "热饭", "外卖", "饭点", "吃一口", "夜宵", "晚饭", "早餐", "早饭"]),
            .init(id: "convenience", category: .daily, keywords: ["便利蜂", "便利店", "全家", "罗森", "711", "7-11"]),
        ]
    )

    static func matchingCategories(in text: String) -> Set<HomeItem.Category> {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }
        return Set(keywordRules.compactMap { rule in
            rule.keywords.contains(where: { normalized.contains($0.lowercased()) }) ? rule.category : nil
        })
    }

    static func bestMatchingCategory(in text: String) -> HomeItem.Category? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        var scores: [HomeItem.Category: Double] = [:]
        for rule in keywordRules where rule.keywords.contains(where: { normalized.contains($0.lowercased()) }) {
            scores[rule.category, default: 0] += rule.score
        }
        guard !scores.isEmpty else { return nil }
        return HomeItem.Category.allCases
            .compactMap { category -> (category: HomeItem.Category, score: Double)? in
                guard let score = scores[category], score > 0 else { return nil }
                return (category, score)
            }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) < 0.001 {
                    return semanticTiePriority(lhs.category) < semanticTiePriority(rhs.category)
                }
                return lhs.score > rhs.score
            }
            .first?.category
    }

    static func isTitle(_ title: String, compatibleWith category: HomeItem.Category) -> Bool {
        let matches = matchingCategories(in: title)
        guard !matches.isEmpty else { return true }
        if matches.contains(category) { return true }
        if category == .daily, matches.contains(.shopping) { return true }
        if category == .shopping, matches.contains(.daily) { return true }
        if category == .home, matches.contains(.daily) { return true }
        return false
    }

    private static func semanticTiePriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .transport: return 0
        case .dining: return 1
        case .shopping: return 2
        case .daily: return 3
        case .health: return 4
        case .home: return 5
        case .lodging: return 6
        case .social: return 7
        case .entertainment: return 8
        case .other: return 9
        }
    }

    static func semanticCategory(of title: String, fallback: HomeItem.Category? = nil) -> HomeItem.Category? {
        guard let best = bestMatchingCategory(in: title) else { return nil }
        if let fallback, best == fallback { return nil }
        return best
    }

    static func isSystemGeneratedTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return generatedSystemTitles.contains(trimmed)
    }

    // Historical habit titles are stricter than current preview copy: generated copy
    // should not silently become the next remark candidate unless the user wrote it.
    static func canReuseHabitTitle(
        _ title: String,
        category: HomeItem.Category,
        userEditedTitle: Bool
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSystemGeneratedTitle(trimmed) else { return false }
        if let brand = MerchantBrandCatalog.matchBrand(in: trimmed) {
            return brand.category == category
        }
        guard userEditedTitle else { return false }
        if let bestCategory = bestMatchingCategory(in: trimmed) {
            return bestCategory == category
        }
        return true
    }

    // Prefill copy may be displayed only when its own semantics agree with the
    // selected category; amount habits alone are not evidence for remark text.
    static func canDisplayPrefillTitle(
        _ title: String,
        category: HomeItem.Category,
        source: String?
    ) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSystemGeneratedTitle(trimmed) else { return false }
        if let brand = MerchantBrandCatalog.matchBrand(in: trimmed) {
            return brand.category == category
        }
        if let bestCategory = bestMatchingCategory(in: trimmed) {
            return bestCategory == category
        }
        return false
    }

    private static let generatedSystemTitles: Set<String> = [
        emptyNoteTitle,
        "早间一段路",
        "公共交通一段",
        "日常出行",
        "早餐先记下",
        "中午一顿饭",
        "晚饭记一笔",
        "认真吃一顿",
        "日常餐饮",
        "添置一件东西",
        "日常添置",
        "日用补齐",
        "日用记录",
        "一次娱乐安排",
        "轻量娱乐",
        "住宿安排",
        "短暂停留",
        "健康安排",
        "健康记录",
        "居家安排",
        "居家补给",
        "心意往来",
        "见面记录",
        "单独记录",
        "日常记录",
    ]

    static func matchingEmotionRuleIDs(in text: String) -> Set<String> {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }
        return Set(emotionKeywordRules.compactMap { rule in
            rule.keywords.contains(where: { normalized.contains($0.lowercased()) }) ? rule.id : nil
        })
    }

    static func matchesEmotionRule(_ id: String, in text: String) -> Bool {
        matchingEmotionRuleIDs(in: text).contains(id)
    }

    static func repairedTitle(
        for title: String,
        category: HomeItem.Category,
        amount: Double,
        date: Date,
        userEditedTitle: Bool
    ) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if userEditedTitle, isTitle(trimmed, compatibleWith: category) {
            return trimmed
        }
        if trimmed.isEmpty || trimmed == category.defaultRecordTitle {
            return fallbackTitle(for: category, amount: amount, date: date)
        }
        if isTitle(trimmed, compatibleWith: category) { return trimmed }
        return fallbackTitle(for: category, amount: amount, date: date)
    }

    static func fallbackTitle(for category: HomeItem.Category, amount: Double, date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch category {
        case .transport:
            if amount <= 20, (7..<10).contains(hour) { return "早间一段路" }
            if amount <= 20 { return "公共交通一段" }
            return "日常出行"
        case .dining:
            if (5..<10).contains(hour) { return "早餐先记下" }
            if (11..<14).contains(hour) { return "中午一顿饭" }
            if (17..<21).contains(hour) { return "晚饭记一笔" }
            if (21...23).contains(hour) || (0..<5).contains(hour) { return "夜里吃点东西" }
            return amount >= 40 ? "认真吃一顿" : "日常餐饮"
        case .shopping:
            return amount >= 100 ? "添置一件东西" : "日常添置"
        case .daily:
            return amount >= 50 ? "日用补齐" : "日用记录"
        case .entertainment:
            return amount >= 150 ? "一次娱乐安排" : "轻量娱乐"
        case .lodging:
            return amount >= 300 ? "住宿安排" : "短暂停留"
        case .health:
            return amount >= 100 ? "健康安排" : "健康记录"
        case .home:
            return amount >= 300 ? "居家安排" : "居家补给"
        case .social:
            return amount >= 100 ? "心意往来" : "见面记录"
        case .other:
            return amount >= 80 ? "单独记录" : "日常记录"
        }
    }
}
