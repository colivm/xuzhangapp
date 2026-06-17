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

        if let note = HomeItem.refinedEmotionTag(title: context.note, category: context.category, amount: context.amount, date: context.date) {
            return note
        }

        if let note = noteAwareEmotionTag(context: context) {
            return note
        }

        if let pack = scenePack(for: context) {
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
        let semanticCategories = RecordSemanticLexicon.matchingCategories(in: lower)
        let emotionRuleIDs = RecordSemanticLexicon.matchingEmotionRuleIDs(in: lower)
        let hasIncompatibleSemanticCue = !semanticCategories.isEmpty && !RecordSemanticLexicon.isTitle(lower, compatibleWith: context.category)

        if let note = HomeItem.refinedEmotionTag(title: lower, category: context.category, amount: context.amount, date: context.date) {
            return note
        }

        if !hasIncompatibleSemanticCue,
           [.health, .daily, .shopping].contains(context.category),
           emotionRuleIDs.contains("fitness") {
            return pick(
                [
                    "运动后补给",
                    "训练恢复补给",
                    "运动小补给",
                    "给锻炼添点装备",
                    "运动习惯继续保持",
                    "身体恢复安排",
                ],
                seed: context.seed + "|fitness"
            )
        }

        if !hasIncompatibleSemanticCue,
           [.dining, .daily].contains(context.category),
           emotionRuleIDs.contains("drink") {
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

        if context.category == .transport,
           emotionRuleIDs.contains("transport") {
            if isWeekend(context.date), !containsWorkCue(lower) {
                return pick(
                    weekendRouteNotes(for: context.date),
                    seed: context.seed + "|weekendRoute"
                )
            }

            if containsAny(lower, ["上班", "早班", "到岗", "早高峰"]) {
                return pick(
                    ["早间一段路", "早上的路费", "这程先记下", "路费记一笔", "路上这一段", "今天的出行"],
                    seed: context.seed + "|morningRoute"
                )
            }

            if containsAny(lower, ["下班", "晚高峰", "回家", "返程"]) {
                return pick(
                    ["回家路上", "晚间一段路", "回程记一笔", "路费记一下", "这程到家", "晚上出行"],
                    seed: context.seed + "|eveningRoute"
                )
            }

            return pick(
                ["日常出行", "这程记下", "路费一笔", "一段路程", "今天的一段路", "出行记录"],
                seed: context.seed + "|route"
            )
        }

        if !hasIncompatibleSemanticCue,
           context.category == .dining,
           emotionRuleIDs.contains("meal") {
            if isWeekend(context.date), !containsWeekendWorkMealCue(lower) {
                return pick(
                    weekendMealNotes(for: context.date, note: lower),
                    seed: context.seed + "|weekendMeal"
                )
            }

            if containsAny(lower, ["夜宵", "夜里饿了", "深夜", "夜里", "凌晨"]) {
                return pick(
                    [
                        "夜里补一点",
                        "深夜这顿记下",
                        "晚点吃上了",
                        "夜里一口热的",
                        "这顿先垫一下",
                        "夜里吃点东西",
                    ],
                    seed: context.seed + "|nightMeal"
                )
            }

            return pick(
                [
                    "中午一顿饭",
                    "饭点记一笔",
                    "热饭到了手边",
                    "今天吃上饭",
                    "这一顿先记下",
                    "简单吃一顿",
                ],
                seed: context.seed + "|meal"
            )
        }

        if !hasIncompatibleSemanticCue,
           context.category == .daily,
           emotionRuleIDs.contains("convenience") {
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

    private static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private static func containsWeekendWorkMealCue(_ text: String) -> Bool {
        if text.contains("周末食堂") { return true }
        let mealCue = ["食堂", "午餐", "饭", "餐", "外卖", "热饭"].contains { text.contains($0) }
        let workCue = ["加班", "公司", "单位", "工位", "工作餐"].contains { text.contains($0) }
        return mealCue && workCue
    }

    private static func containsWorkCue(_ text: String) -> Bool {
        ["加班", "公司", "单位", "工位", "工作餐", "到岗"].contains { text.contains($0) }
    }

    private static func weekendRouteNotes(for date: Date) -> [String] {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return ["早间一段路", "这程先记下", "路费记一笔", "短途出行", "早上的路", "路上这一段"]
        case 17..<22:
            return ["傍晚一段路", "回程记一笔", "晚上出行", "这程到家", "路费记一下", "晚间一段路"]
        default:
            return ["日常出行", "这程记下", "一段路程", "今天的一段路", "路费一笔", "出行记录"]
        }
    }

    private static func weekendMealNotes(for date: Date, note: String) -> [String] {
        if containsAny(note, ["夜宵", "夜里饿了", "深夜", "夜里", "凌晨"]) {
            return ["周末夜里补一点", "夜里吃点东西", "深夜这顿记下", "晚点吃上了", "这口先垫一下", "夜里一口热的"]
        }
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10:
            return ["周末早餐", "早上简单吃点", "早餐先记下", "早间小食", "今天早餐有着落", "早上补点能量"]
        case 11..<14:
            return ["周末午餐", "午间吃点热乎的", "这顿午饭记下", "周末饭点留一笔", "中午简单吃一顿", "午间一顿饭"]
        case 17..<21:
            return ["周末晚饭", "晚餐吃点热乎的", "今晚这顿记下", "晚饭时间坐一会儿", "这顿晚饭有着落", "周末晚餐"]
        default:
            return ["周末吃一顿", "简单吃点东西", "这顿先记下", "饭点留一笔", "吃点热乎的", "今天这顿记下"]
        }
    }

    private static func scenePack(for context: Context) -> ScenePackDefinition? {
        let packId: String?
        switch context.category {
        case .dining: packId = "food"
        case .transport: packId = "commute"
        case .shopping: packId = "shopping"
        case .lodging: packId = "travel"
        case .entertainment, .other:
            packId = containsTravelKeyword(context.note) ? "travel" : nil
        case .health: packId = "care"
        case .home: packId = "home"
        case .social: packId = "social"
        case .daily: packId = nil
        }
        guard let packId else { return nil }
        return ScenePackCopyPool.definitions.first { $0.id == packId }
    }

    private static func containsTravelKeyword(_ text: String) -> Bool {
        let keywords = ["旅行", "旅途", "景区", "景点", "行程", "酒店", "民宿", "住宿", "机票", "高铁", "机场", "返程", "摆渡"]
        return keywords.contains { text.contains($0) }
    }

    private static func genericTiers(for category: HomeItem.Category) -> [ScenePackTier] {
        switch category {
        case .daily:
            return [
                ScenePackTier(maxAmount: 30, notes: ["补点日用", "日常小物补上", "刚好需要的小东西", "小东西补齐一点", "小补给记下来", "便利袋里的一点日常"]),
                ScenePackTier(maxAmount: 100, notes: ["日常用品补齐", "家用小物安排好", "添点方便", "买了一袋日用品", "常用的先补上", "超市补给记一笔"]),
                ScenePackTier(maxAmount: 300, notes: ["日用品换新一点", "把常用的补上", "日常用品补到位", "家里缺的补齐", "这一笔给日常用品", "常用物件买回来了"]),
                ScenePackTier(maxAmount: 9_999, notes: ["长期日常安排", "添置一件常用物", "日常大项记下", "日用品大笔支出", "家里要用的大件", "这笔给长期会用的东西"]),
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
