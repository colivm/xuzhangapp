import Foundation

enum NarrativeCopyResolver {
    struct Context {
        let brandId: String?
        let category: HomeItem.Category
        let amount: Double
        let date: Date
        let seed: String
        let note: String
        let scenePackId: String?

        init(
            brandId: String?,
            category: HomeItem.Category,
            amount: Double,
            date: Date,
            seed: String,
            note: String = "",
            scenePackId: String? = nil
        ) {
            self.brandId = brandId
            self.category = category
            self.amount = amount
            self.date = date
            self.seed = seed
            self.note = note
            self.scenePackId = scenePackId
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
        if context.category == .dining,
           let lateNightTag = HomeItem.lateNightDiningEmotionTag(title: context.note, date: context.date) {
            return lateNightTag
        }

        if let brand = MerchantBrandCatalog.definition(for: context.brandId) {
            if let note = drinkBrandEmotionTag(brand: brand, context: context) {
                return note
            }
            if let note = note(from: brand.tiers, amount: context.amount, seed: context.seed) {
                return note
            }
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
           [.shopping, .daily].contains(context.category),
           emotionRuleIDs.contains("baby_supply") {
            if containsAny(lower, ["奶粉"]) {
                return pick(
                    ["宝宝口粮补上", "今天的奶粉安排好", "照护宝宝这一笔", "宝宝日常不断档"],
                    seed: context.seed + "|babySupplyMilk"
                )
            }
            if containsAny(lower, ["尿不湿", "纸尿裤", "拉拉裤"]) {
                return pick(
                    ["照护用品补齐", "宝宝换洗用品到位", "日常照护补上", "宝宝日常更安心"],
                    seed: context.seed + "|babySupplyDiaper"
                )
            }
            return pick(
                ["宝宝照护用品到位", "照护宝宝这一笔", "宝宝日常补给", "家里的小照护记下"],
                seed: context.seed + "|babySupply"
            )
        }

        if !hasIncompatibleSemanticCue,
           [.shopping, .daily].contains(context.category),
           emotionRuleIDs.contains("pet_supply") {
            if containsAny(lower, ["狗粮", "猫粮", "宠物粮", "宠物口粮"]) {
                return pick(
                    ["毛孩子口粮补上", "毛孩子饭碗续上", "宠物口粮记下", "照护毛孩子这一笔"],
                    seed: context.seed + "|petSupplyFood"
                )
            }
            if containsAny(lower, ["猫砂", "尿垫"]) {
                return pick(
                    ["毛孩子日常补给", "照护用品补齐", "家里的清爽补上", "毛孩子日常更安心"],
                    seed: context.seed + "|petSupplyDaily"
                )
            }
            return pick(
                ["毛孩子日常补给", "照护毛孩子这一笔", "宠物用品补上", "家里的小照护记下"],
                seed: context.seed + "|petSupply"
            )
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
            if containsAny(lower, ["可乐", "雪碧", "汽水", "水溶", "c100", "维c", "维他", "果汁", "饮料"]) {
                return pick(
                    [
                        "买瓶喝的",
                        "饮料记一笔",
                        "这瓶喝的记下",
                        "路上买点喝的",
                        "今天买了瓶饮料",
                        "小饮料记下来",
                    ],
                    seed: context.seed + "|bottledDrink"
                )
            }
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

        if !hasIncompatibleSemanticCue,
           [.dining, .daily].contains(context.category),
           emotionRuleIDs.contains("convenience") {
            if containsAny(lower, ["茶叶蛋", "饭团", "便当", "关东煮", "包子", "三明治", "热食", "小食"]) {
                return pick(
                    [
                        "便利店小食记下",
                        "路过买点吃的",
                        "便利店热食在手边",
                        "小食先垫一下",
                        "便利店这一口",
                        "午间小补给",
                    ],
                    seed: context.seed + "|convenienceFood"
                )
            }
            return pick(
                [
                    "便利店补给",
                    "路过买点需要的",
                    "小补给刚好带上",
                    "便利店这一笔",
                    "路过买一点",
                    "小东西顺路带上",
                ],
                seed: context.seed + "|convenience"
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
            if let lateNightTag = HomeItem.lateNightDiningEmotionTag(title: lower, date: context.date) {
                return lateNightTag
            }

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

        return nil
    }

    private static func note(from tiers: [ScenePackTier], amount: Double, seed: String) -> String? {
        guard !tiers.isEmpty else { return nil }
        let tier = tiers.first { amount <= $0.maxAmount } ?? tiers[tiers.count - 1]
        guard !tier.notes.isEmpty else { return nil }
        return tier.notes[stableIndex(seed: seed, count: tier.notes.count)]
    }

    private static func drinkBrandEmotionTag(
        brand: MerchantBrandDefinition,
        context: Context
    ) -> String? {
        guard context.category == .dining,
              ["luckin", "starbucks", "manner", "mixue", "heytea", "naixue"].contains(brand.id) else {
            return nil
        }

        let lower = "\(context.seed) \(context.note)".lowercased()
        let isCoffee = ["luckin", "starbucks", "manner"].contains(brand.id)
            || containsAny(lower, ["咖啡", "拿铁", "美式", "蓝杯", "coffee"])
        let hasRushOrTravelCue = containsAny(lower, ["赶路", "赶车", "赶时间", "来不及", "机场", "高铁", "火车", "车站", "登机", "出发去"])
        let hour = Calendar.current.component(.hour, from: context.date)

        if hasRushOrTravelCue {
            return pick(
                isCoffee
                ? ["路上续一杯清醒", "出发前补点精神", "这杯陪着走一段", "路上买杯提神", "移动前补一口"]
                : ["路上买杯喝的", "出发前带杯清爽", "这杯陪着走一段", "路上补点清爽", "移动前喝一口"],
                seed: context.seed + "|drinkRoute"
            )
        }

        switch hour {
        case 5..<10:
            return pick(
                isCoffee
                ? ["早上提个神", "早晨续一杯清醒", "把清晨叫醒一点", "今天也先醒过来", "咖啡香落进早上"]
                : ["早上喝点清爽", "清晨的一杯", "今天先喝一口", "早上补点甜", "把早晨提亮一点"],
                seed: context.seed + "|drinkMorning"
            )
        case 10..<14:
            return pick(
                isCoffee
                ? ["午间补一杯清醒", "午饭旁边的一杯", "给下午先续一点", "中午这杯提个神", "午间咖啡记下", "忙里补一点清醒"]
                : ["午间喝点清爽", "饭点旁边的一杯", "中午补点甜", "午间饮品记下", "给下午添点清爽", "忙里喝一口"],
                seed: context.seed + "|drinkNoon"
            )
        case 14..<18:
            return pick(
                isCoffee
                ? ["午后补一点精神", "给下午一点支撑", "忙里补一点清醒", "午后一杯咖啡", "把节奏续上一点", "下午续一杯"]
                : ["午后喝点清爽", "给下午添点甜", "忙里喝一口", "下午饮品记下", "茶歇时刻记一下", "把下午接上"],
                seed: context.seed + "|drinkAfternoon"
            )
        case 18..<23:
            return pick(
                isCoffee
                ? ["晚点续一杯清醒", "这杯陪着把事做完", "忙完前补点精神", "夜里先提个神", "这杯把节奏稳住"]
                : ["晚上喝点喜欢的", "晚点补一杯", "夜里喝口清爽", "这杯留在晚上", "给晚上添一点味道"],
                seed: context.seed + "|drinkEvening"
            )
        default:
            return pick(
                isCoffee
                ? ["这杯咖啡记下", "认真续一杯清醒", "今天一杯咖啡", "今天添了一杯咖啡", "买杯咖啡记下"]
                : ["这杯饮品记下", "喝一口喜欢的", "给今天添一杯", "一口清爽记下来", "今天喝点好的"],
                seed: context.seed + "|drinkAnytime"
            )
        }
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
        if let scenePackId = context.scenePackId,
           let pack = ScenePackCopyPool.definitions.first(where: { $0.id == scenePackId }) {
            return pack
        }
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
        case .daily: packId = containsFamilyCareKeyword(context.note) ? "family" : "supply"
        }
        guard let packId else { return nil }
        return ScenePackCopyPool.definitions.first { $0.id == packId }
    }

    private static func containsFamilyCareKeyword(_ text: String) -> Bool {
        let keywords = ["宝宝", "孩子", "婴儿", "奶粉", "尿不湿", "纸尿裤", "辅食", "童装", "儿童座椅", "推车", "宠物", "猫粮", "狗粮", "猫砂", "尿垫", "罐头", "冻干", "宠物医院", "毛孩", "毛孩子"]
        return keywords.contains { text.contains($0) }
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
