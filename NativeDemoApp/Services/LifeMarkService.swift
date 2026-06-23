import Foundation

enum LifeMarkAccess: String, Equatable {
    case free
    case member
}

enum LifeMarkKind: String, Equatable {
    case scene
    case context
    case milestone
    case streak
}

struct LifeMarkQueryIntent: Equatable {
    let id: String
    let label: String
    let categories: [HomeItem.Category]
    let keywords: [String]
    let requiresKeywordMatch: Bool
}

struct LifeMarkAggregate: Identifiable, Equatable {
    let id: String
    let kind: LifeMarkKind
    let access: LifeMarkAccess
    let label: String
    let title: String
    let detail: String
    let category: HomeItem.Category
    let count: Int
    let total: Double
    let latestDate: Date
    let itemIDs: [UUID]
    let queryHint: String
    let priority: Int
}

private struct LifeMarkDefinition {
    let id: String
    let label: String
    let category: HomeItem.Category
    let categories: [HomeItem.Category]
    let keywords: [String]
    let access: LifeMarkAccess
    let priority: Int
    let minimumCount: Int
    let requiresKeywordMatch: Bool
}

enum LifeMarkService {
    private static var aggregateCache: [String: [LifeMarkAggregate]] = [:]
    private static var aggregateCacheOrder: [String] = []
    private static let aggregateCacheLimit = 48

    private static let definitions: [LifeMarkDefinition] = [
        LifeMarkDefinition(
            id: "fitness",
            label: "健身恢复",
            category: .health,
            categories: [.health, .shopping, .entertainment, .daily],
            keywords: ["运动", "健身", "健身房", "训练", "锻炼", "跑步", "瑜伽", "普拉提", "游泳", "球场", "羽毛球", "网球", "篮球", "私教", "团课", "课程", "健身卡", "月卡", "年卡", "护具", "运动鞋", "运动服", "蛋白", "补剂", "能量胶", "恢复", "按摩", "理疗", "康复", "运动装备"],
            access: .free,
            priority: 10,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "coffee_drink",
            label: "咖啡奶茶",
            category: .dining,
            categories: [.dining],
            keywords: ["咖啡", "拿铁", "美式", "奶茶", "茶饮", "饮品", "瑞幸", "星巴克", "manner", "蜜雪", "喜茶", "奈雪"],
            access: .free,
            priority: 18,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "commute",
            label: "通勤出行",
            category: .transport,
            categories: [.transport],
            keywords: ["通勤", "上班", "下班", "地铁", "公交", "早高峰", "晚高峰", "轨道交通"],
            access: .free,
            priority: 20,
            minimumCount: 1,
            requiresKeywordMatch: false
        ),
        LifeMarkDefinition(
            id: "weekend_gathering",
            label: "周末聚餐",
            category: .social,
            categories: [.dining, .social],
            keywords: ["聚餐", "朋友", "请客", "约饭", "火锅", "烤肉", "生日", "家庭聚餐", "周末", "见面"],
            access: .member,
            priority: 22,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "daily_supply",
            label: "超市买菜和家用",
            category: .daily,
            categories: [.daily, .shopping, .home],
            keywords: ["日用", "日用品", "生活用品", "生活补给", "生活补寄", "超市", "便利店", "纸巾", "抽纸", "卷纸", "湿巾", "洗衣液", "洗洁精", "垃圾袋", "清洁", "洗发水", "沐浴露", "牙刷", "毛巾", "收纳", "买菜", "生鲜", "水果", "蔬菜", "盒马", "叮咚买菜", "小象超市", "京东到家", "京东秒送", "美团闪购", "朴朴超市", "即时零售"],
            access: .free,
            priority: 28,
            minimumCount: 1,
            requiresKeywordMatch: false
        ),
        LifeMarkDefinition(
            id: "home_utilities",
            label: "房租水电物业",
            category: .home,
            categories: [.home, .daily, .other],
            keywords: ["水电", "水费", "电费", "燃气", "煤气", "物业", "宽带", "网费", "房租", "租房", "租房子", "租屋", "租赁", "租金", "押金", "房东", "停车费", "话费"],
            access: .free,
            priority: 30,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "baby_supply",
            label: "宝宝照护",
            category: .daily,
            categories: [.daily, .shopping, .health],
            keywords: ["宝宝", "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "母婴", "婴儿", "辅食", "湿巾", "奶瓶", "安抚奶嘴", "早教", "童装", "儿童座椅", "推车"],
            access: .free,
            priority: 12,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "medical_care",
            label: "看病买药",
            category: .health,
            categories: [.health, .daily],
            keywords: ["医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "拍片", "验血", "牙科", "口腔", "药店", "药房", "买药", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴", "护理", "理疗", "康复"],
            access: .free,
            priority: 16,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "social_care",
            label: "人情往来",
            category: .social,
            categories: [.social, .dining, .shopping],
            keywords: ["红包", "礼物", "送礼", "份子", "随礼", "生日", "探望", "拜访", "请客", "聚餐", "朋友", "伴手礼", "乔迁", "婚礼", "满月"],
            access: .free,
            priority: 26,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "leisure",
            label: "休闲娱乐",
            category: .entertainment,
            categories: [.entertainment],
            keywords: ["娱乐", "休闲", "电影", "影院", "动物园", "游乐场", "乐园", "主题乐园", "迪士尼", "环球影城", "海洋馆", "水族馆", "公园", "景区", "景点", "展览", "看展", "展馆", "博物馆", "美术馆", "演唱会", "音乐节", "剧场", "话剧", "脱口秀", "密室", "剧本杀", "桌游", "台球", "ktv", "唱歌", "游戏", "门票"],
            access: .free,
            priority: 24,
            minimumCount: 1,
            requiresKeywordMatch: false
        ),
        LifeMarkDefinition(
            id: "travel",
            label: "出去玩订酒店买票",
            category: .transport,
            categories: [.transport, .lodging, .entertainment, .dining, .shopping],
            keywords: ["旅行", "旅游", "异地", "外地", "出差", "酒店", "民宿", "住宿", "机票", "机场", "高铁", "火车", "车站", "景区", "景点", "门票", "返程", "行程", "伴手礼"],
            access: .member,
            priority: 14,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "groceries",
            label: "超市买菜",
            category: .daily,
            categories: [.daily, .dining, .shopping],
            keywords: ["买菜", "菜场", "生鲜", "水果", "蔬菜", "盒马", "叮咚", "叮咚买菜", "小象超市", "京东到家", "京东秒送", "朴朴超市", "淘宝买菜", "美团买菜", "食材", "厨房", "做饭"],
            access: .free,
            priority: 34,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "interest_gear",
            label: "兴趣装备",
            category: .shopping,
            categories: [.shopping, .daily, .health, .entertainment],
            keywords: ["渔具", "鱼竿", "鱼线", "鱼饵", "路亚", "钓箱", "钓椅", "露营", "帐篷", "天幕", "睡袋", "骑行", "头盔", "码表", "摄影", "相机", "镜头", "模型", "手办", "乐器", "吉他", "键盘", "茶具", "咖啡器具", "磨豆机", "滤杯"],
            access: .free,
            priority: 18,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "learning_growth",
            label: "学习成长",
            category: .shopping,
            categories: [.shopping, .entertainment, .daily],
            keywords: ["书", "书店", "教材", "文具", "本子", "笔", "课程", "培训", "考试", "报名费", "资料", "学习", "读书"],
            access: .free,
            priority: 36,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "pet_supply",
            label: "宠物照护",
            category: .daily,
            categories: [.daily, .health, .shopping],
            keywords: ["宠物", "猫", "狗", "猫砂", "狗粮", "猫粮", "罐头", "冻干", "尿垫", "驱虫", "宠物医院", "洗护"],
            access: .free,
            priority: 38,
            minimumCount: 1,
            requiresKeywordMatch: true
        )
    ]

    static func aggregates(
        for items: [HomeItem],
        allItems: [HomeItem]? = nil,
        isMember: Bool,
        now: Date = Date(),
        limit: Int = 8
    ) -> [LifeMarkAggregate] {
        let periodItems = items.filter { $0.amount > 0 && $0.draftMeta == nil }
        guard !periodItems.isEmpty else { return [] }

        let history = (allItems ?? items).filter { $0.amount > 0 && $0.draftMeta == nil }
        let cacheKey = aggregateCacheKey(
            periodItems: periodItems,
            historyItems: history,
            isMember: isMember,
            limit: limit
        )
        if let cached = aggregateCache[cacheKey] {
            return cached
        }

        var rows = sceneAggregates(for: periodItems, historyItems: history)
        rows += contextAggregates(for: periodItems)
        rows += milestoneAggregates(periodItems: periodItems, historyItems: history)
        rows += streakAggregates(for: periodItems)

        let result = rows
            .filter { isMember || $0.access == .free }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    if lhs.count == rhs.count { return lhs.latestDate > rhs.latestDate }
                    return lhs.count > rhs.count
                }
                return lhs.priority < rhs.priority
            }
            .prefix(limit)
            .map { $0 }
        storeAggregateCache(result, for: cacheKey)
        return result
    }

    static func lockedPreview(
        for items: [HomeItem],
        allItems: [HomeItem]? = nil
    ) -> LifeMarkAggregate? {
        aggregates(for: items, allItems: allItems, isMember: true, limit: 12)
            .first { $0.access == .member }
    }

    static func primaryLine(for aggregate: LifeMarkAggregate) -> String {
        switch aggregate.kind {
        case .scene:
            return aggregate.detail
        case .context, .milestone, .streak:
            return aggregate.detail
        }
    }

    private static func aggregateCacheKey(
        periodItems: [HomeItem],
        historyItems: [HomeItem],
        isMember: Bool,
        limit: Int
    ) -> String {
        [
            isMember ? "member" : "free",
            "limit:\(limit)",
            "period:\(itemsSignature(periodItems))",
            "history:\(itemsSignature(historyItems))"
        ].joined(separator: "|")
    }

    private static func itemsSignature(_ items: [HomeItem]) -> String {
        var hasher = Hasher()
        hasher.combine(items.count)
        for item in items {
            hasher.combine(item.id)
            hasher.combine(item.createdAt.timeIntervalSince1970)
            hasher.combine(item.updatedAt.timeIntervalSince1970)
            hasher.combine(item.amount)
            hasher.combine(item.category.rawValue)
            hasher.combine(item.title)
            hasher.combine(item.emotionTag)
            hasher.combine(item.source.rawValue)
            hasher.combine(item.draftMeta?.status.rawValue)
            hasher.combine(item.memoryContext?.weatherKind)
            hasher.combine(item.memoryContext?.cityName)
            hasher.combine(item.memoryContext?.semanticPlace)
            hasher.combine(item.scenePackId)
        }
        return "\(hasher.finalize())"
    }

    private static func storeAggregateCache(_ result: [LifeMarkAggregate], for key: String) {
        guard aggregateCache[key] == nil else {
            return
        }
        aggregateCache[key] = result
        aggregateCacheOrder.append(key)
        while aggregateCacheOrder.count > aggregateCacheLimit {
            let staleKey = aggregateCacheOrder.removeFirst()
            aggregateCache.removeValue(forKey: staleKey)
        }
    }

    static func queryIntent(from text: String) -> LifeMarkQueryIntent? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        if containsAny(normalized, ["雨天通勤", "下雨通勤", "雨天上班", "下雨上班"]) {
            return LifeMarkQueryIntent(
                id: "rainy_commute",
                label: "雨天通勤",
                categories: [.transport],
                keywords: ["雨天", "下雨", "雨", "通勤", "上班", "下班", "地铁", "公交"],
                requiresKeywordMatch: false
            )
        }
        return definitions.first { definition in
            containsAny(normalized, definition.keywords) || normalized.contains(definition.label)
        }
        .map { definition in
            LifeMarkQueryIntent(
                id: definition.id,
                label: definition.label,
                categories: definition.categories,
                keywords: definition.keywords,
                requiresKeywordMatch: definition.requiresKeywordMatch
            )
        }
    }

    static func access(for intent: LifeMarkQueryIntent) -> LifeMarkAccess {
        if intent.id == "rainy_commute" {
            return .member
        }
        return definitions.first(where: { $0.id == intent.id })?.access ?? .free
    }

    static func matches(_ item: HomeItem, intent: LifeMarkQueryIntent) -> Bool {
        if intent.id == "rainy_commute" {
            return item.category == .transport
                && isRainy(item)
                && (containsAny(semanticText(for: item), ["通勤", "上班", "下班", "地铁", "公交"]) || item.amount <= 80)
        }
        let categoryMatched = intent.categories.contains(item.category)
        let keywordMatched = containsAny(semanticText(for: item), intent.keywords)
        return intent.requiresKeywordMatch
            ? categoryMatched && keywordMatched
            : categoryMatched || keywordMatched
    }

    static func milestoneTarget(from text: String) -> Int? {
        if containsAny(text, ["第一次", "首次", "第一回", "第一笔", "第1笔", "第一条", "第1条", "第一单", "第1单"]) { return 1 }
        if containsAny(text, ["第十次", "第10次", "10次", "十次"]) { return 10 }
        if containsAny(text, ["第三十次", "第30次", "30次", "三十次"]) { return 30 }
        if containsAny(text, ["第五十次", "第50次", "50次", "五十次"]) { return 50 }
        return nil
    }

    private static func sceneAggregates(for items: [HomeItem], historyItems: [HomeItem]) -> [LifeMarkAggregate] {
        definitions.compactMap { definition in
            if ["weekend_gathering", "travel"].contains(definition.id) {
                return nil
            }
            let matched = items.filter { matches($0, definition: definition) }
            guard matched.count >= definition.minimumCount else { return nil }
            let historyMatched = historyItems.filter { matches($0, definition: definition) }
            return aggregate(
                id: definition.id,
                kind: .scene,
                access: definition.access,
                label: definition.label,
                title: definition.label,
                detail: sceneDetail(
                    label: definition.label,
                    periodCount: matched.count,
                    historyCount: historyMatched.count
                ),
                category: definition.category,
                items: matched,
                queryHint: queryHint(for: definition)
            )
        }
    }

    private static func contextAggregates(for items: [HomeItem]) -> [LifeMarkAggregate] {
        var rows: [LifeMarkAggregate] = []
        let rainyCommutes = items.filter { item in
            item.category == .transport
                && isRainy(item)
                && (containsAny(semanticText(for: item), ["通勤", "上班", "下班", "地铁", "公交"]) || item.amount <= 80)
        }
        if !rainyCommutes.isEmpty {
            rows.append(aggregate(
                id: "rainy_commute",
                kind: .context,
                access: .member,
                label: "雨天通勤",
                title: "雨天通勤",
                detail: rainyCommutes.count == 1 ? "这段里有一次雨天通勤，回看时能知道那天路上有雨。" : "这段里有 \(rainyCommutes.count) 次雨天通勤，天气也成了这段生活的背景。",
                category: .transport,
                items: rainyCommutes,
                queryHint: "上一次雨天通勤是什么时候？"
            ))
        }

        let away = items.filter { item in
            item.memoryContext?.semanticPlace == "外地" || matches(item, definitionID: "travel")
        }
        if !away.isEmpty {
            let city = away.compactMap { $0.memoryContext?.cityName }.first
            let label = city.map { "\($0)异地记录" } ?? "出去玩订酒店买票"
            rows.append(aggregate(
                id: "away_travel",
                kind: .context,
                access: .member,
                label: label,
                title: label,
                detail: city.map { "这段里有记录留在\($0)，以后再看会知道那几笔发生在外地。" } ?? "这段里有外地/旅行线索，交通、住宿和门票可以被串成同一段行程。",
                category: .transport,
                items: away,
                queryHint: "上一次出去玩订酒店买票花了多少？"
            ))
        }

        let weekendGathering = items.filter { item in
            isWeekend(item.createdAt)
                && [.dining, .social].contains(item.category)
                && (containsAny(semanticText(for: item), ["聚餐", "朋友", "请客", "约饭", "火锅", "烤肉", "生日", "家庭", "见面"]) || item.amount >= 60)
        }
        if !weekendGathering.isEmpty {
            rows.append(aggregate(
                id: "weekend_gathering_context",
                kind: .context,
                access: .member,
                label: "周末聚餐",
                title: "周末聚餐",
                detail: "周末的餐饮和见面记录连在一起，更像一次相聚，而不只是餐饮分类。",
                category: .social,
                items: weekendGathering,
                queryHint: "这周末聚餐花了多少？"
            ))
        }

        return rows
    }

    private static func milestoneAggregates(
        periodItems: [HomeItem],
        historyItems: [HomeItem]
    ) -> [LifeMarkAggregate] {
        let periodIDs = Set(periodItems.map(\.id))
        let trackedDefinitionIDs = [
            "fitness",
            "coffee_drink",
            "baby_supply",
            "pet_supply",
            "interest_gear",
            "leisure",
            "home_utilities"
        ]
        var rows: [LifeMarkAggregate] = []
        for id in trackedDefinitionIDs {
            guard let definition = definitions.first(where: { $0.id == id }) else { continue }
            let periodMatched = periodItems.filter { matches($0, definition: definition) }
            guard !periodMatched.isEmpty else { continue }
            let periodMatchedIDs = Set(periodMatched.map(\.id))
            let sorted = historyItems
                .filter { matches($0, definition: definition) }
                .sorted { $0.createdAt < $1.createdAt }
            let grouped = Dictionary(grouping: sorted) { item in
                milestoneLabel(for: definition, item: item)
            }
            for (label, labelItems) in grouped {
                let labelSorted = labelItems.sorted { $0.createdAt < $1.createdAt }
                for target in [1, 10, 30, 50] where labelSorted.count >= target {
                    let item = labelSorted[target - 1]
                    guard periodIDs.contains(item.id), periodMatchedIDs.contains(item.id) else { continue }
                    let title = target == 1 ? "第一次\(label)" : "\(label)第 \(target) 次"
                    let detail = milestoneDetail(label: label, target: target)
                    rows.append(aggregate(
                        id: "\(definition.id)_\(label)_milestone_\(target)",
                        kind: .milestone,
                        access: .member,
                        label: title,
                        title: title,
                        detail: detail,
                        category: definition.category,
                        items: [item],
                        queryHint: target == 1 ? "第一次\(label)是哪天？" : "\(label)第 \(target) 次是哪天？",
                        priorityOverride: target == 1 ? 4 : 6
                    ))
                }
            }
        }
        return rows
    }

    private static func streakAggregates(for items: [HomeItem]) -> [LifeMarkAggregate] {
        let calendar = Calendar.current
        return definitions.compactMap { definition in
            let matched = items.filter { matches($0, definition: definition) }
            let days = Set(matched.map { calendar.startOfDay(for: $0.createdAt) }).sorted()
            guard let streak = longestStreak(in: days), streak.count >= 3 else { return nil }
            let streakItems = matched.filter { item in
                streak.days.contains(calendar.startOfDay(for: item.createdAt))
            }
            return aggregate(
                id: "\(definition.id)_streak",
                kind: .streak,
                access: .member,
                label: "连续\(definition.label)",
                title: "连续\(definition.label)",
                detail: "\(definition.label)连续出现 \(streak.count) 天，这已经不是单笔消费，而是一段生活节奏。",
                category: definition.category,
                items: streakItems,
                queryHint: "最近连续\(definition.label)是哪几天？",
                priorityOverride: 8
            )
        }
    }

    private static func aggregate(
        id: String,
        kind: LifeMarkKind,
        access: LifeMarkAccess,
        label: String,
        title: String,
        detail: String,
        category: HomeItem.Category,
        items: [HomeItem],
        queryHint: String,
        priorityOverride: Int? = nil
    ) -> LifeMarkAggregate {
        let sorted = items.sorted { $0.createdAt > $1.createdAt }
        let total = items.reduce(0) { $0 + $1.amount }
        return LifeMarkAggregate(
            id: id,
            kind: kind,
            access: access,
            label: label,
            title: title,
            detail: detail,
            category: category,
            count: items.count,
            total: total,
            latestDate: sorted.first?.createdAt ?? .distantPast,
            itemIDs: sorted.map(\.id),
            queryHint: queryHint,
            priority: priorityOverride ?? (definitions.first(where: { $0.id == id })?.priority ?? 50)
        )
    }

    private static func matches(_ item: HomeItem, definition: LifeMarkDefinition) -> Bool {
        if definition.id == "weekend_gathering", !isWeekend(item.createdAt) {
            return false
        }
        if definition.id == "travel", item.memoryContext?.semanticPlace == "外地" {
            return true
        }
        let categoryMatched = definition.categories.contains(item.category)
        let keywordMatched = containsAny(semanticText(for: item), definition.keywords)
        if item.scenePackId == "family", definition.id == "daily_supply" {
            return false
        }
        if item.scenePackId == "family",
           ["baby_supply", "pet_supply"].contains(definition.id) {
            return categoryMatched && keywordMatched
        }
        if definition.id == "daily_supply",
           matchesAnySpecificDailyCareDefinition(item) {
            return false
        }
        if definition.id == "daily_supply", item.category != .daily {
            return categoryMatched && keywordMatched
        }
        return definition.requiresKeywordMatch
            ? categoryMatched && keywordMatched
            : categoryMatched || keywordMatched
    }

    private static func matchesAnySpecificDailyCareDefinition(_ item: HomeItem) -> Bool {
        let specificIDs = ["baby_supply", "pet_supply"]
        let text = semanticText(for: item)
        return definitions.contains { definition in
            specificIDs.contains(definition.id)
                && definition.categories.contains(item.category)
                && containsAny(text, definition.keywords)
        }
    }

    private static func matches(_ item: HomeItem, definitionID: String) -> Bool {
        guard let definition = definitions.first(where: { $0.id == definitionID }) else { return false }
        return matches(item, definition: definition)
    }

    private static func sceneDetail(label: String, periodCount: Int, historyCount: Int) -> String {
        let recurring = historyCount > periodCount
        let count = periodCount
        let historyText = historyCount > count ? "，账本里已经累计 \(historyCount) 次" : ""
        switch label {
        case "健身恢复":
            if recurring {
                return "健身恢复又出现了\(historyText)，身体这条线正在变得有节奏。"
            }
            return count == 1 ? "健身恢复被记下来了，这是身体这条线的开头。" : "健身恢复出现 \(count) 次，身体这条线正在变清楚。"
        case "咖啡奶茶":
            if recurring {
                return "咖啡奶茶又落进这段记录\(historyText)，这类小补给已经是生活里的固定节点。"
            }
            return count == 1 ? "咖啡奶茶被记下来了，以后再看会知道今天从哪一杯开始。" : "咖啡奶茶出现 \(count) 次，这些小补给正在连成一天里的节奏。"
        case "宝宝照护":
            if recurring {
                return "宝宝照护又被记下\(historyText)，这些不是零散采购，是照护节奏的一部分。"
            }
            return "宝宝相关用品出现 \(count) 次，这类记录会慢慢变成照护节奏。"
        case "房租水电物业":
            if recurring {
                return "家账线索又出现了\(historyText)，以后按月回看会更清楚。"
            }
            return "水电、房租或物业这类家账出现 \(count) 次，适合按月回看。"
        case "休闲娱乐":
            if recurring {
                return "休闲娱乐又出现了\(historyText)，能看出你把松弛留给了哪里。"
            }
            return "休闲娱乐出现 \(count) 次，能看出这段时间把松弛留给了哪里。"
        case "出去玩订酒店买票":
            if recurring {
                return "旅行和异地线索又出现了\(historyText)，可以和城市、天气一起回看。"
            }
            return "旅行和异地线索出现 \(count) 次，可以和城市、天气一起回看。"
        case "兴趣装备":
            if recurring {
                return "兴趣装备又出现了\(historyText)，这条爱好线值得被长期记住。"
            }
            return "兴趣装备出现 \(count) 次，这类小众爱好不用单独成包，也值得被记住。"
        default:
            if recurring {
                return "\(label)又出现了\(historyText)，这条生活线索正在延续。"
            }
            return "\(label)出现 \(count) 次，已经可以作为一条生活线索。"
        }
    }

    private static func milestoneDetail(label: String, target: Int) -> String {
        if target == 1 {
            switch label {
            case "健身恢复":
                return "第一次健身恢复被记下来了；以后再有同类记录，就能回看上一次、连续几次和身体这条线。"
            case "咖啡奶茶":
                return "第一杯咖啡奶茶被记下来了；以后它会继续累计成小补给习惯，而不只是一笔餐饮。"
            case "给宝宝买奶粉":
                return "第一次给宝宝买奶粉被记下来了；这不是普通日用品，是照护生活真正开始留下痕迹。"
            case "给宝宝买尿不湿":
                return "第一次给宝宝买尿不湿被记下来了；以后这些小小消耗，会连成照顾一个小生命的节奏。"
            case "给宝宝买辅食":
                return "第一次给宝宝买辅食被记下来了；从这一笔开始，成长也会在账本里慢慢有线索。"
            case "给宝宝买照护用品", "宝宝照护":
                return "第一次宝宝照护用品被记下来了；之后如果还有同类记录，会一起形成照护节奏。"
            case "给毛孩子买狗粮":
                return "第一次给毛孩子买狗粮被记下来了；它不是一笔普通购物，是家里多了一个需要照顾的日常。"
            case "给毛孩子买猫粮":
                return "第一次给毛孩子买猫粮被记下来了；以后这些补给，会慢慢连成陪伴它生活的节奏。"
            case "给毛孩子买猫砂":
                return "第一次给毛孩子买猫砂被记下来了；这些细碎开销，其实都是一起生活的证据。"
            case "给毛孩子买零食":
                return "第一次给毛孩子买零食被记下来了；以后再看，会知道那些宠爱是从哪一笔开始的。"
            case "照顾毛孩子", "毛孩子照护":
                return "第一次毛孩子照护被记下来了；以后就能回看它在生活里留下的长期陪伴。"
            case "露营":
                return "第一次露营被记下来了；以后再看到帐篷、天幕和路上的花费，会知道这条户外生活线从哪里开始。"
            case "买渔具":
                return "第一次买渔具被记下来了；这不是普通装备，是一个爱好开始有了自己的痕迹。"
            case "骑行装备":
                return "第一次骑行装备被记下来了；以后路线、装备和出发的日子会慢慢连起来。"
            case "摄影装备":
                return "第一次摄影装备被记下来了；以后再回看，会知道你是从哪一笔开始认真留住画面。"
            case "买乐器":
                return "第一次买乐器被记下来了；一个爱好开始有声音，也开始在账本里留下形状。"
            case "水电燃气", "房租", "物业费", "宽带网费", "停车费", "话费", "租房押金":
                return "这笔\(label)已经作为本月家账线索记录；有同类记录时，会继续归到这条线里。"
            default:
                return "第一次\(label)被记下来了；后面再出现时，会继续归到这条线里，方便回看上一次和第几次。"
            }
        }
        switch label {
        case "健身恢复":
            return "健身恢复来到第 \(target) 次，坚持已经开始有形状了。"
        case "咖啡奶茶":
            return "咖啡奶茶来到第 \(target) 次，这类小补给已经成为生活里的固定节点。"
        case "给宝宝买奶粉", "给宝宝买尿不湿", "给宝宝买辅食", "给宝宝买照护用品", "宝宝照护":
            return "\(label)来到第 \(target) 次，这些重复出现的小事，正在变成照顾宝宝的生活节奏。"
        case "给毛孩子买狗粮", "给毛孩子买猫粮", "给毛孩子买猫砂", "给毛孩子买零食", "照顾毛孩子", "毛孩子照护":
            return "\(label)来到第 \(target) 次，陪伴不是一句话，是这些反复出现的日常。"
        case "露营", "买渔具", "骑行装备", "摄影装备", "买乐器", "兴趣装备":
            return "\(label)来到第 \(target) 次，这个爱好已经不只是偶然想起，而是在生活里有了位置。"
        default:
            return "\(label)来到第 \(target) 次，这不是孤立的一笔，是反复出现的生活痕迹。"
        }
    }

    private static func milestoneLabel(for definition: LifeMarkDefinition, item: HomeItem) -> String {
        switch definition.id {
        case "baby_supply":
            return babySupplyLabel(for: item)
        case "pet_supply":
            return petSupplyLabel(for: item)
        case "interest_gear":
            return interestGearLabel(for: item)
        case "home_utilities":
            return homeUtilityLabel(for: item)
        default:
            return definition.label
        }
    }

    private static func babySupplyLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        if containsAny(text, ["奶粉"]) {
            return "给宝宝买奶粉"
        }
        if containsAny(text, ["尿不湿", "纸尿裤", "拉拉裤"]) {
            return "给宝宝买尿不湿"
        }
        if containsAny(text, ["辅食", "米粉"]) {
            return "给宝宝买辅食"
        }
        if containsAny(text, ["湿巾", "奶瓶", "安抚奶嘴"]) {
            return "给宝宝买照护用品"
        }
        return "宝宝照护"
    }

    private static func petSupplyLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        if containsAny(text, ["狗粮"]) {
            return "给毛孩子买狗粮"
        }
        if containsAny(text, ["猫粮"]) {
            return "给毛孩子买猫粮"
        }
        if containsAny(text, ["猫砂"]) {
            return "给毛孩子买猫砂"
        }
        if containsAny(text, ["冻干", "罐头"]) {
            return "给毛孩子买零食"
        }
        if containsAny(text, ["宠物医院", "驱虫", "洗护"]) {
            return "照顾毛孩子"
        }
        return "毛孩子照护"
    }

    private static func interestGearLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        if containsAny(text, ["露营", "帐篷", "天幕", "睡袋"]) {
            return "露营"
        }
        if containsAny(text, ["渔具", "鱼竿", "鱼线", "鱼饵", "路亚", "钓箱", "钓椅"]) {
            return "买渔具"
        }
        if containsAny(text, ["骑行", "头盔", "码表"]) {
            return "骑行装备"
        }
        if containsAny(text, ["摄影", "相机", "镜头"]) {
            return "摄影装备"
        }
        if containsAny(text, ["乐器", "吉他", "键盘"]) {
            return "买乐器"
        }
        return "兴趣装备"
    }

    private static func homeUtilityLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        if containsAny(text, ["押金"]) {
            return "租房押金"
        }
        if containsAny(text, ["房租", "租金", "租房", "租房子", "租屋", "租赁", "房东"]) {
            return "房租"
        }
        if containsAny(text, ["水电", "水费", "电费", "燃气", "煤气"]) {
            return "水电燃气"
        }
        if containsAny(text, ["物业"]) {
            return "物业费"
        }
        if containsAny(text, ["宽带", "网费"]) {
            return "宽带网费"
        }
        if containsAny(text, ["停车费"]) {
            return "停车费"
        }
        if containsAny(text, ["话费"]) {
            return "话费"
        }
        return "家账"
    }

    private static func queryHint(for definition: LifeMarkDefinition) -> String {
        switch definition.id {
        case "fitness": return "这个月健身恢复几次？"
        case "coffee_drink": return "这周咖啡奶茶几次？"
        case "home_utilities": return "这个月房租水电物业多少？"
        case "baby_supply": return "这个月宝宝奶粉买了几次？"
        case "pet_supply": return "上一次给毛孩子买狗粮是哪天？"
        case "leisure": return "上周休闲娱乐花了多少钱？"
        case "travel": return "上一次出去玩订酒店买票是什么时候？"
        case "interest_gear": return "第一次露营或买渔具是哪天？"
        default: return "这个月\(definition.label)几次？"
        }
    }

    private static func semanticText(for item: HomeItem) -> String {
        [
            item.title,
            item.emotionTag,
            item.displayEmotionTag,
            item.category.rawValue,
            item.category.label,
            item.memoryContext?.cityName ?? "",
            item.memoryContext?.semanticPlace ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func isRainy(_ item: HomeItem) -> Bool {
        item.memoryContext?.weatherKind == "rain" || containsAny(semanticText(for: item), ["雨天", "下雨"])
    }

    private static func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private static func longestStreak(in days: [Date]) -> (count: Int, days: Set<Date>)? {
        guard !days.isEmpty else { return nil }
        let calendar = Calendar.current
        var best: [Date] = []
        var current: [Date] = []
        for day in days {
            if let previous = current.last,
               let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current.append(day)
            } else {
                current = [day]
            }
            if current.count > best.count {
                best = current
            }
        }
        return best.isEmpty ? nil : (best.count, Set(best))
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
