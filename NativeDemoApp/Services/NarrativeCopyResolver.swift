import Foundation

enum NarrativeCopyResolver {
    struct Context {
        let brandId: String?
        let category: HomeItem.Category
        let amount: Double
        let date: Date
        let seed: String
    }

    static func resolveTitle(brandId: String?, fallback: String) -> String {
        let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let brand = MerchantBrandCatalog.definition(for: brandId) else {
            return trimmed.isEmpty ? fallback : trimmed
        }
        if trimmed.isEmpty || isGenericTitle(trimmed) || MerchantBrandCatalog.matchBrand(in: trimmed) != nil {
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

    private static func note(from tiers: [ScenePackTier], amount: Double, seed: String) -> String? {
        guard !tiers.isEmpty else { return nil }
        let tier = tiers.first { amount <= $0.maxAmount } ?? tiers[tiers.count - 1]
        guard !tier.notes.isEmpty else { return nil }
        return tier.notes[stableIndex(seed: seed, count: tier.notes.count)]
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
                ScenePackTier(maxAmount: 30, notes: ["顺手补点日用", "日常小物补上", "生活角落添一点", "刚好需要的小东西", "把日子补齐一点", "小补给记下来"]),
                ScenePackTier(maxAmount: 100, notes: ["日常用品补齐", "把生活小事接住", "家用小物安排好", "顺手添点方便", "这笔很有日常感", "给日子留点顺手"]),
                ScenePackTier(maxAmount: 300, notes: ["认真打理日子", "生活用品换新一点", "把常用的补上", "日常被照看到了", "这一笔让日子顺一些", "给生活添点踏实"]),
                ScenePackTier(maxAmount: 9_999, notes: ["给长期日常做安排", "把生活底子补稳", "认真添置一件常用物", "这一笔让日子更稳", "日常需要被好好接住", "生活被安顿了一点"]),
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
