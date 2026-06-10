import Foundation

enum NarrativeCopyResolver {
    struct Context {
        let brandId: String?
        let category: HomeItem.Category
        let amount: Double
        let date: Date
        let seed: String
        let note: String

        init(
            brandId: String?,
            category: HomeItem.Category,
            amount: Double,
            date: Date,
            seed: String,
            note: String = ""
        ) {
            self.brandId = brandId
            self.category = category
            self.amount = amount
            self.date = date
            self.seed = seed
            self.note = note
        }
    }

    static func resolveTitle(brandId: String?, fallback: String) -> String {
        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let brand = MerchantBrandCatalog.definition(for: brandId) else {
            return trimmed.isEmpty ? fallback : trimmed
        }
        if trimmed.isEmpty || isGenericTitle(trimmed) {
            return brand.displayName
        }
        if MerchantBrandCatalog.isExactBrandAlias(trimmed, for: brand.id) {
            return brand.displayName
        }
        return trimmed
    }

    static func resolveCategory(brandId: String?, fallback: HomeItem.Category) -> HomeItem.Category {
        MerchantBrandCatalog.definition(for: brandId)?.category ?? fallback
    }

    static func resolveEmotionTag(context: Context) -> String {
        if let brand = MerchantBrandCatalog.definition(for: context.brandId),
           let note = note(from: brand.tiers, amount: context.amount, seed: context.seed) {
            return note
        }

        if let note = noteAwareEmotionTag(context: context) {
            return note
        }

        if let pack = scenePack(for: context.category) {
            return ScenePackCopyPool.note(
                for: pack,
                amount: context.amount,
                date: context.date,
                categoryContext: context.category,
                petName: "小窝",
                historyItems: [],
                allowPetCopy: false,
                variant: stableIndex(seed: context.seed + "|scene", count: 7)
            )
        }

        if let note = note(from: genericTiers(for: context.category), amount: context.amount, seed: context.seed) {
            return note
        }

        return HomeItem.inferEmotionTag(category: context.category, amount: context.amount)
    }

    private static func noteAwareEmotionTag(context: Context) -> String? {
        let noteText = context.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !noteText.isEmpty else { return nil }
        let lower = noteText.lowercased()

        if containsAny(lower, ["饮料", "喝的", "可乐", "雪碧", "汽水", "果汁", "茶饮", "奶茶", "咖啡", "拿铁", "美式", "冰饮"]) {
            return pick(
                [
                    "买杯喝的",
                    "小饮料记一笔",
                    "路上添点清爽",
                    "一口喝的记下来",
                    "便利店饮料在手边",
                    "今天补点小清爽",
                ],
                seed: context.seed + "|drink"
            )
        }

        if containsAny(lower, ["便利蜂", "便利店", "全家", "罗森", "711", "7-11"]) {
            return pick(
                [
                    "便利店补给",
                    "这一站很方便",
                    "小补给刚好带上",
                    "日常一站完成",
                    "路过买一点",
                    "便利店小袋子",
                ],
                seed: context.seed + "|convenience"
            )
        }

        return nil
    }

    private static func note(from tiers: [ScenePackTier], amount: Double, seed: String) -> String? {
        guard !tiers.isEmpty else { return nil }
        let tier = tiers.first { amount <= $0.maxAmount } ?? tiers[tiers.count - 1]
        guard !tier.notes.isEmpty else { return nil }
        return tier.notes[stableIndex(seed: seed, count: tier.notes.count)]
    }

    private static func pick(_ notes: [String], seed: String) -> String {
        notes[stableIndex(seed: seed, count: notes.count)]
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private static func scenePack(for category: HomeItem.Category) -> ScenePackDefinition? {
        let packId: String?
        switch category {
        case .dining: packId = "food"
        case .transport: packId = "commute"
        case .shopping: packId = "shopping"
        case .lodging, .entertainment, .other: packId = "travel"
        case .health: packId = "care"
        case .home: packId = "home"
        case .social: packId = "social"
        case .daily: packId = nil
        }
        guard let packId else { return nil }
        return ScenePackCopyPool.definitions.first { $0.id == packId }
    }

    private static func genericTiers(for category: HomeItem.Category) -> [ScenePackTier] {
        switch category {
        case .daily:
            return [
                ScenePackTier(maxAmount: 30, notes: ["补点日用", "日常小物补上", "生活角落添一点", "刚好需要的小东西", "小东西补齐一点", "小补给记下来"]),
                ScenePackTier(maxAmount: 100, notes: ["日常用品补齐", "生活小事记一笔", "家用小物安排好", "添点方便", "这笔很有日常感", "日常用品一袋"]),
                ScenePackTier(maxAmount: 300, notes: ["打理日子的一笔", "生活用品换新一点", "把常用的补上", "日常用品补到位", "这一笔让日子顺一些", "给日常添点踏实"]),
                ScenePackTier(maxAmount: 9_999, notes: ["长期日常安排", "把生活底子补稳", "添置一件常用物", "这一笔让日子更稳", "日常大项记下", "生活用品大笔支出"]),
            ]
        default:
            return []
        }
    }

    private static func isGenericTitle(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isNoisyTimeTitle(trimmed) {
            return true
        }
        if trimmed.range(of: #"^-?\s*[¥￥]?\s*[0-9]+(?:\.[0-9]{1,2})?\s*$"#, options: .regularExpression) != nil {
            return true
        }
        return ["账单记录", "微信消费", "未命名记录"].contains(trimmed) || trimmed.hasSuffix("记录")
    }

    static func isNoisyTimeTitle(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let month = String(UnicodeScalar(0x6708)!)
        let day = String(UnicodeScalar(0x65E5)!)
        let monthDayPattern = "^\\d{1,2}" + month + "\\d{1,2}" + day + "(?:\\s*\\d{1,2}:?\\d{0,2})?$"
        let patterns = [
            #"^\d{1,2}:\d{2}(?::\d{2})?$"#,
            #"^\d{1,2}:\s*$"#,
            #"^\d{1,2}[-/.]\d{1,2}(?:\s+\d{1,2}:?\d{0,2})?$"#,
            #"^20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}(?:\s+\d{1,2}:?\d{0,2})?$"#,
            monthDayPattern,
        ]
        return patterns.contains { trimmed.range(of: $0, options: .regularExpression) != nil }
    }

    private static func stableIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}
