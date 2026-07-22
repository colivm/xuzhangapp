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

enum AICommandSemanticFacet: String, Equatable, Hashable {
    case weatherHot
    case weatherCold
    case weatherRain
    case weatherSnow
    case commute
    case interestGear
    case awayFromHome
}

struct LifeMarkQueryIntent: Equatable {
    let id: String
    let label: String
    let categories: [HomeItem.Category]
    let keywords: [String]
    let requiresKeywordMatch: Bool
    let semanticFacets: [AICommandSemanticFacet]
    let supportsNounPhraseQuery: Bool
    let evidenceLabel: String?

    init(
        id: String,
        label: String,
        categories: [HomeItem.Category],
        keywords: [String],
        requiresKeywordMatch: Bool,
        semanticFacets: [AICommandSemanticFacet] = [],
        supportsNounPhraseQuery: Bool = false,
        evidenceLabel: String? = nil
    ) {
        self.id = id
        self.label = label
        self.categories = categories
        self.keywords = keywords
        self.requiresKeywordMatch = requiresKeywordMatch
        self.semanticFacets = semanticFacets
        self.supportsNounPhraseQuery = supportsNounPhraseQuery
        self.evidenceLabel = evidenceLabel
    }
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
    struct PreparedAggregationContext: @unchecked Sendable {
        fileprivate let historyItems: [HomeItem]
        fileprivate let definitionIDsByItemID: [UUID: Set<String>]
        fileprivate let historyItemsByDefinitionID: [String: [HomeItem]]
    }

    private static var aggregateCache: [String: [LifeMarkAggregate]] = [:]
    private static var aggregateCacheOrder: [String] = []
    private static let aggregateCacheLimit = 48
    private static let aggregateCacheLock = NSLock()
    private static let telecomBillKeywords = ["话费", "话费券", "话费充值", "手机话费", "手机充值", "通讯费", "通信费", "中国移动", "中国移动通信集团", "中国联通", "中国电信", "移动通信", "运营商缴费"]
    private static let casualDrinkKeywords = ["可乐", "雪碧", "汽水", "水溶", "c100", "维c", "维他", "果汁", "饮料"]
    private static let intentionalDrinkKeywords = ["咖啡", "拿铁", "美式", "奶茶", "茶饮", "柠檬茶", "瑞幸", "星巴克", "manner", "蜜雪", "喜茶", "奈雪"]
    private static let broadDailySupplySpecificDefinitionIDs: Set<String> = [
        "fitness",
        "home_utilities",
        "telecom_bill",
        "household_service",
        "digital_subscription",
        "baby_supply",
        "medical_care",
        "social_care",
        "groceries",
        "interest_gear",
        "learning_growth",
        "pet_supply"
    ]
    private static let broadLeisureSpecificDefinitionIDs: Set<String> = [
        "fitness",
        "digital_subscription",
        "social_care",
        "movie_ticket",
        "travel",
        "interest_gear",
        "learning_growth"
    ]

    private static let definitions: [LifeMarkDefinition] = [
        LifeMarkDefinition(
            id: "fitness",
            label: "健身恢复",
            category: .health,
            categories: [.health, .shopping, .entertainment, .daily],
            keywords: ["健身", "健身房", "健身训练", "锻炼", "跑步", "瑜伽", "普拉提", "游泳", "球场", "羽毛球", "网球", "篮球", "私教", "团课", "健身课程", "健身卡", "健身月卡", "健身年卡", "护具", "运动鞋", "运动服", "蛋白", "补剂", "能量胶", "恢复按摩", "理疗", "康复", "运动装备"],
            access: .free,
            priority: 10,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "coffee_drink",
            label: "咖啡饮品",
            category: .dining,
            categories: [.dining],
            keywords: ["咖啡", "拿铁", "美式", "奶茶", "茶饮", "饮品", "饮料", "喝的", "果汁", "柠檬茶", "水溶", "c100", "维C", "维他", "瑞幸", "星巴克", "manner", "蜜雪", "喜茶", "奈雪"],
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
            requiresKeywordMatch: true
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
            keywords: ["日用", "日用品", "生活用品", "生活补给", "生活补寄", "超市", "便利店", "纸巾", "抽纸", "卷纸", "湿巾", "洗衣液", "洗洁精", "垃圾袋", "清洁", "洗发水", "沐浴露", "牙刷", "毛巾", "收纳", "买菜", "生鲜", "水果", "蔬菜", "鸡蛋", "盒马", "叮咚买菜", "小象超市", "京东到家", "京东秒送", "美团闪购", "朴朴超市", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈"],
            access: .free,
            priority: 28,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "luwei_snack",
            label: "卤味小食",
            category: .dining,
            categories: [.dining],
            keywords: ["绝味", "绝味鸭脖", "鸭脖", "鸭货", "卤味", "周黑鸭", "煌上煌", "久久鸭", "紫燕百味鸡"],
            access: .free,
            priority: 27,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "everyday_meal",
            label: "日常吃饭",
            category: .dining,
            categories: [.dining],
            keywords: ["茶叶蛋", "饭团", "关东煮", "肠粉", "黄焖鸡", "冒菜", "生煎", "锅贴", "老乡鸡", "塔斯汀", "海底捞", "库迪", "袁记云饺", "萨莉亚", "牛肉面", "兰州牛肉面", "兰州拉面", "拉面", "汤面", "面馆", "面食", "面条", "粉面"],
            access: .free,
            priority: 32,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "home_utilities",
            label: "房租水电物业",
            category: .home,
            categories: [.home, .daily, .other],
            keywords: ["水电", "水费", "电费", "燃气", "煤气", "物业", "宽带", "网费", "暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司", "网上国网", "国网", "房租", "租房", "租房子", "租屋", "租赁", "租金", "押金", "房东", "停车费"],
            access: .free,
            priority: 30,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "telecom_bill",
            label: "手机话费",
            category: .daily,
            categories: [.daily],
            keywords: telecomBillKeywords,
            access: .free,
            priority: 31,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "household_service",
            label: "居家服务维护",
            category: .home,
            categories: [.home, .daily],
            keywords: ["保洁", "家政", "钟点工", "开荒保洁", "上门保洁", "深度保洁", "擦玻璃", "清洗油烟机", "空调清洗", "搬家", "搬家公司", "货拉拉搬家"],
            access: .free,
            priority: 32,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "car_care",
            label: "车主日常",
            category: .transport,
            categories: [.transport],
            keywords: ["洗车", "汽车保养", "车辆保养", "保养车", "ETC", "etc"],
            access: .free,
            priority: 32,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "digital_subscription",
            label: "数字订阅",
            category: .entertainment,
            categories: [.entertainment, .shopping],
            keywords: ["B站会员", "哔哩哔哩会员", "爱奇艺会员", "腾讯视频会员", "优酷会员", "芒果TV会员", "网易云会员", "网易云音乐会员", "QQ音乐会员", "喜马拉雅会员", "百度网盘会员", "WPS会员", "iCloud订阅", "Apple Music", "Office 365", "Microsoft 365", "Adobe订阅", "Creative Cloud", "Notion订阅", "Notion会员"],
            access: .free,
            priority: 32,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "baby_supply",
            label: "宝宝照护",
            category: .daily,
            categories: [.daily, .shopping, .health],
            keywords: ["宝宝", "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "母婴", "婴儿", "辅食", "宝宝湿巾", "婴儿湿巾", "奶瓶", "安抚奶嘴", "早教", "早教课", "托育费", "托班费", "幼儿园学费", "童装", "儿童座椅", "推车"],
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
            keywords: ["医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "拍片", "验血", "牙科", "口腔", "洗牙", "配镜", "验光", "药店", "药房", "买药", "感冒", "退烧", "消炎", "止痛", "维生素", "眼药水", "创可贴", "护理", "理疗", "康复", "医美", "医美脱毛", "光子嫩肤", "水光针"],
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
            keywords: ["红包", "礼物", "送礼", "份子", "随礼", "生日", "探望", "拜访", "请客", "聚餐", "朋友", "伴手礼", "乔迁", "婚礼", "满月", "白事", "白事随礼", "奠仪", "帛金", "花圈"],
            access: .free,
            priority: 26,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "movie_ticket",
            label: "看电影",
            category: .entertainment,
            categories: [.entertainment],
            keywords: ["电影票", "买电影票", "看电影", "观影", "票根", "电影", "影院", "电影院", "影城", "万达影城", "CGV", "IMAX", "卢米埃", "幸福蓝海", "横店影视", "金逸影城", "奥斯卡", "中影", "SFC", "上影", "博纳"],
            access: .free,
            priority: 8,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "leisure",
            label: "休闲娱乐",
            category: .entertainment,
            categories: [.entertainment],
            keywords: ["娱乐", "休闲", "电影", "影院", "网吧", "网咖", "上网费", "直播打赏", "主播打赏", "抖音打赏", "直播礼物", "动物园", "游乐场", "乐园", "主题乐园", "迪士尼", "环球影城", "海洋馆", "水族馆", "公园", "景区", "景点", "展览", "看展", "展馆", "博物馆", "美术馆", "演唱会", "音乐节", "剧场", "话剧", "脱口秀", "密室", "剧本杀", "桌游", "台球", "ktv", "唱歌", "游戏", "门票"],
            access: .free,
            priority: 24,
            minimumCount: 1,
            requiresKeywordMatch: true
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
            keywords: ["买菜", "菜场", "生鲜", "水果", "蔬菜", "鸡蛋", "盒马", "叮咚", "叮咚买菜", "小象超市", "京东到家", "京东秒送", "朴朴超市", "淘宝买菜", "美团买菜", "山姆", "山姆会员", "永辉", "永辉超市", "大润发", "钱大妈", "牛奶", "鲜奶", "纯牛奶", "酸奶", "认养一头牛", "认养牛奶", "特仑苏", "伊利", "蒙牛", "光明", "金典", "简爱", "悦鲜活", "食材", "厨房食材", "做饭食材"],
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
            keywords: ["渔具", "鱼竿", "鱼线", "鱼饵", "路亚", "钓箱", "钓椅", "露营", "帐篷", "天幕", "睡袋", "骑行", "头盔", "码表", "摄影", "相机", "镜头", "模型", "手办", "谷子", "潮玩", "吧唧", "徽章", "亚克力", "立牌", "盲盒", "泡泡玛特", "POP MART", "POPMART", "LABUBU", "棉花娃娃", "痛包", "同人本", "乙游周边", "漫展周边", "乐器", "吉他", "键盘", "茶具", "咖啡器具", "磨豆机", "滤杯"],
            access: .free,
            priority: 18,
            minimumCount: 1,
            requiresKeywordMatch: true
        ),
        LifeMarkDefinition(
            id: "learning_growth",
            label: "学习成长",
            category: .shopping,
            categories: [.shopping, .entertainment, .daily, .other],
            keywords: ["书", "书店", "教材", "文具", "本子", "笔", "课程", "培训", "考试", "报名费", "资料", "学习", "读书", "驾校", "驾校报名费", "驾考", "学车"],
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
            keywords: ["宠物", "毛孩子", "毛孩", "猫砂", "狗粮", "猫粮", "宠物粮", "宠物口粮", "猫罐头", "狗罐头", "宠物罐头", "猫冻干", "狗冻干", "宠物冻干", "尿垫", "猫驱虫", "狗驱虫", "宠物驱虫", "宠物医院", "猫狗洗护", "宠物洗护"],
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
        if let cached = cachedAggregates(for: cacheKey) {
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

    static func prepareAggregationContext(
        allItems: [HomeItem],
        periodItems: [HomeItem]? = nil
    ) -> PreparedAggregationContext {
        let historyItems = allItems.filter { $0.amount > 0 && $0.draftMeta == nil }
        let candidatePeriodItems = (periodItems ?? allItems).filter {
            $0.amount > 0 && $0.draftMeta == nil
        }
        let relevantDefinitions = definitions.filter { definition in
            candidatePeriodItems.contains { matches($0, definition: definition) }
        }
        var definitionIDsByItemID: [UUID: Set<String>] = [:]
        var historyItemsByDefinitionID: [String: [HomeItem]] = [:]
        definitionIDsByItemID.reserveCapacity(historyItems.count)
        historyItemsByDefinitionID.reserveCapacity(relevantDefinitions.count)

        for item in historyItems {
            var matchedDefinitionIDs = Set<String>()
            for definition in relevantDefinitions where matches(item, definition: definition) {
                matchedDefinitionIDs.insert(definition.id)
                historyItemsByDefinitionID[definition.id, default: []].append(item)
            }
            definitionIDsByItemID[item.id] = matchedDefinitionIDs
        }

        return PreparedAggregationContext(
            historyItems: historyItems,
            definitionIDsByItemID: definitionIDsByItemID,
            historyItemsByDefinitionID: historyItemsByDefinitionID
        )
    }

    static func aggregates(
        for items: [HomeItem],
        preparedContext: PreparedAggregationContext,
        isMember: Bool,
        limit: Int = 8
    ) -> [LifeMarkAggregate] {
        let periodItems = items.filter { $0.amount > 0 && $0.draftMeta == nil }
        guard !periodItems.isEmpty else { return [] }

        var rows = sceneAggregates(
            for: periodItems,
            historyItems: preparedContext.historyItems,
            preparedContext: preparedContext
        )
        rows += contextAggregates(for: periodItems)
        rows += milestoneAggregates(
            periodItems: periodItems,
            historyItems: preparedContext.historyItems,
            preparedContext: preparedContext
        )
        rows += streakAggregates(for: periodItems, preparedContext: preparedContext)

        return rows
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
        aggregateCacheLock.lock()
        defer { aggregateCacheLock.unlock() }
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

    private static func cachedAggregates(for key: String) -> [LifeMarkAggregate]? {
        aggregateCacheLock.lock()
        defer { aggregateCacheLock.unlock() }
        return aggregateCache[key]
    }

    static func queryIntent(from text: String) -> LifeMarkQueryIntent? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        if let weatherCommuteIntent = weatherCommuteQueryIntent(from: normalized) {
            return weatherCommuteIntent
        }
        if containsAny(normalized, ["爱好类消费", "爱好消费", "兴趣消费", "兴趣类消费", "爱好装备"]) {
            return definitionQueryIntent(
                id: "interest_gear",
                supportsNounPhraseQuery: true,
                semanticFacets: [.interestGear],
                evidenceLabel: "明确兴趣物件或活动"
            )
        }
        if containsAny(normalized, ["外地消费", "异地消费", "外地花费", "异地花费", "外地记录", "异地记录"]) {
            return LifeMarkQueryIntent(
                id: "away_spending",
                label: "外地消费",
                categories: HomeItem.Category.allCases,
                keywords: ["外地", "异地"],
                requiresKeywordMatch: false,
                semanticFacets: [.awayFromHome],
                supportsNounPhraseQuery: true,
                evidenceLabel: "记录中的外地上下文"
            )
        }
        return definitions.first { definition in
            if definition.id == "baby_supply" {
                return SemanticBoundaryGuard.matchesBabySupply(normalized) || normalized.contains(definition.label)
            }
            if definition.id == "pet_supply" {
                return SemanticBoundaryGuard.matchesPetSupply(normalized) || normalized.contains(definition.label)
            }
            return containsAny(normalized, definition.keywords) || normalized.contains(definition.label)
        }
        .map { definition in
            LifeMarkQueryIntent(
                id: definition.id,
                label: definition.label,
                categories: definition.categories,
                keywords: definition.keywords,
                requiresKeywordMatch: definition.requiresKeywordMatch,
                semanticFacets: definition.id == "interest_gear" ? [.interestGear] : [],
                supportsNounPhraseQuery: supportsTrustedNounPhraseQuery(
                    normalized,
                    definition: definition
                ),
                evidenceLabel: definition.id == "interest_gear" ? "明确兴趣物件或活动" : nil
            )
        }
    }

    static func access(for intent: LifeMarkQueryIntent) -> LifeMarkAccess {
        if intent.semanticFacets.contains(where: {
            [.weatherHot, .weatherCold, .weatherRain, .weatherSnow, .awayFromHome].contains($0)
        }) {
            return .member
        }
        return definitions.first(where: { $0.id == intent.id })?.access ?? .free
    }

    static func matches(_ item: HomeItem, intent: LifeMarkQueryIntent) -> Bool {
        if !intent.semanticFacets.isEmpty {
            return intent.semanticFacets.allSatisfy { facetMatches(item, facet: $0) }
        }
        let categoryMatched = intent.categories.contains(item.category)
        let text = querySemanticText(for: item)
        if intent.id == "baby_supply" {
            return categoryMatched && SemanticBoundaryGuard.matchesBabySupply(text)
        }
        if intent.id == "pet_supply" {
            return categoryMatched && SemanticBoundaryGuard.matchesPetSupply(text)
        }
        let keywordMatched = containsAny(text, intent.keywords)
        return intent.requiresKeywordMatch
            ? categoryMatched && keywordMatched
            : categoryMatched || keywordMatched
    }

    private static func weatherCommuteQueryIntent(from normalized: String) -> LifeMarkQueryIntent? {
        let commuteCues = ["通勤", "上班", "下班", "上下班", "早高峰", "晚高峰", "到岗", "地铁通勤", "公交通勤"]
        guard containsAny(normalized, commuteCues) else { return nil }

        let descriptor: (
            id: String,
            label: String,
            facet: AICommandSemanticFacet,
            evidence: String,
            keywords: [String]
        )?
        if containsAny(normalized, ["高温", "热天", "酷热", "炎热", "闷热"]) {
            descriptor = ("hot_commute", "高温通勤", .weatherHot, "高温天气 · 通勤", ["高温", "热天", "酷热", "炎热", "闷热"])
        } else if containsAny(normalized, ["低温", "冷天", "寒冷", "降温", "很冷"]) {
            descriptor = ("cold_commute", "冷天通勤", .weatherCold, "低温天气 · 通勤", ["低温", "冷天", "寒冷", "降温"])
        } else if containsAny(normalized, ["雨天", "下雨", "降雨", "淋雨"]) {
            descriptor = ("rainy_commute", "雨天通勤", .weatherRain, "降雨天气 · 通勤", ["雨天", "下雨", "降雨"])
        } else if containsAny(normalized, ["雪天", "下雪", "降雪"]) {
            descriptor = ("snowy_commute", "雪天通勤", .weatherSnow, "降雪天气 · 通勤", ["雪天", "下雪", "降雪"])
        } else {
            descriptor = nil
        }

        guard let descriptor else { return nil }
        return LifeMarkQueryIntent(
            id: descriptor.id,
            label: descriptor.label,
            categories: [.transport],
            keywords: descriptor.keywords + commuteCues,
            requiresKeywordMatch: false,
            semanticFacets: [descriptor.facet, .commute],
            supportsNounPhraseQuery: true,
            evidenceLabel: descriptor.evidence
        )
    }

    private static func definitionQueryIntent(
        id: String,
        supportsNounPhraseQuery: Bool,
        semanticFacets: [AICommandSemanticFacet] = [],
        evidenceLabel: String? = nil
    ) -> LifeMarkQueryIntent? {
        guard let definition = definitions.first(where: { $0.id == id }) else { return nil }
        return LifeMarkQueryIntent(
            id: definition.id,
            label: definition.label,
            categories: definition.categories,
            keywords: definition.keywords,
            requiresKeywordMatch: definition.requiresKeywordMatch,
            semanticFacets: semanticFacets,
            supportsNounPhraseQuery: supportsNounPhraseQuery,
            evidenceLabel: evidenceLabel
        )
    }

    private static func supportsTrustedNounPhraseQuery(
        _ normalized: String,
        definition: LifeMarkDefinition
    ) -> Bool {
        if normalized.contains(definition.label.lowercased()) {
            return true
        }
        let trustedIDs: Set<String> = [
            "fitness", "coffee_drink", "commute", "home_utilities", "telecom_bill",
            "household_service", "car_care", "digital_subscription", "baby_supply",
            "medical_care", "movie_ticket", "travel", "groceries", "interest_gear",
            "learning_growth", "pet_supply",
        ]
        return trustedIDs.contains(definition.id)
            && containsAny(normalized, definition.keywords)
    }

    private static func facetMatches(_ item: HomeItem, facet: AICommandSemanticFacet) -> Bool {
        switch facet {
        case .weatherHot:
            return weatherMatches(
                item,
                structuredKinds: ["hot", "heat", "high_temperature"],
                legacyFactPhrases: ["热天路上", "高温通勤", "热天通勤"]
            )
        case .weatherCold:
            return weatherMatches(
                item,
                structuredKinds: ["cold", "low_temperature"],
                legacyFactPhrases: ["冷天出门", "低温通勤", "冷天通勤"]
            )
        case .weatherRain:
            return weatherMatches(
                item,
                structuredKinds: ["rain", "rainy"],
                legacyFactPhrases: ["雨天通勤", "下雨通勤"]
            )
        case .weatherSnow:
            return weatherMatches(
                item,
                structuredKinds: ["snow", "snowy"],
                legacyFactPhrases: ["雪天通勤", "下雪通勤"]
            )
        case .commute:
            guard item.category == .transport else { return false }
            if item.scenePackId == "commute" { return true }
            if containsAny(querySemanticText(for: item), ["通勤", "上班", "下班", "早高峰", "晚高峰", "到岗", "地铁", "公交"]) {
                return true
            }
            return containsAny(item.displayEmotionTag, ["通勤路上", "雨天通勤", "雪天通勤", "冷天出门", "热天路上"])
        case .interestGear:
            guard let definition = definitions.first(where: { $0.id == "interest_gear" }),
                  definition.categories.contains(item.category) else { return false }
            return containsAny(querySemanticText(for: item), definition.keywords)
        case .awayFromHome:
            if item.memoryContext?.semanticPlace == "外地" { return true }
            guard item.memoryContext?.semanticPlace == nil else { return false }
            return containsAny(item.displayEmotionTag, ["外地记录", "异地记录", "外地停留", "异地停留"])
        }
    }

    private static func weatherMatches(
        _ item: HomeItem,
        structuredKinds: Set<String>,
        legacyFactPhrases: [String]
    ) -> Bool {
        if let kind = item.memoryContext?.weatherKind?.lowercased() {
            return structuredKinds.contains(kind)
        }
        return containsAny(item.displayEmotionTag, legacyFactPhrases)
    }

    private static func querySemanticText(for item: HomeItem) -> String {
        [
            item.title,
            item.category.rawValue,
            item.category.label,
            item.memoryContext?.cityName ?? "",
            item.memoryContext?.semanticPlace ?? "",
            item.scenePackId ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }

    static func milestoneTarget(from text: String) -> Int? {
        if containsAny(text, ["第一次", "首次", "第一回", "第一笔", "第1笔", "第一条", "第1条", "第一单", "第1单"]) { return 1 }
        if containsAny(text, ["第十次", "第10次", "10次", "十次"]) { return 10 }
        if containsAny(text, ["第三十次", "第30次", "30次", "三十次"]) { return 30 }
        if containsAny(text, ["第五十次", "第50次", "50次", "五十次"]) { return 50 }
        return nil
    }

    private static func sceneAggregates(
        for items: [HomeItem],
        historyItems: [HomeItem],
        preparedContext: PreparedAggregationContext? = nil
    ) -> [LifeMarkAggregate] {
        definitions.compactMap { definition in
            if ["weekend_gathering", "travel"].contains(definition.id) {
                return nil
            }
            let matched = matchedItems(
                in: items,
                definition: definition,
                preparedContext: preparedContext
            )
            guard matched.count >= definition.minimumCount else { return nil }
            if definition.id == "coffee_drink",
               matched.count < 2,
               let only = matched.first,
               isCasualDrinkOnly(only) {
                return nil
            }
            let historyMatched = preparedContext?.historyItemsByDefinitionID[definition.id]
                ?? historyItems.filter { matches($0, definition: definition) }
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
            let hasHoliday = weekendGathering.contains {
                RecordCalendarContext.dayKind(for: $0.createdAt) == .holiday
            }
            let label = hasHoliday ? "假期聚餐" : "周末聚餐"
            rows.append(aggregate(
                id: "weekend_gathering_context",
                kind: .context,
                access: .member,
                label: label,
                title: label,
                detail: "\(hasHoliday ? "假期" : "周末")的餐饮和见面记录连在一起，更像一次相聚，而不只是餐饮分类。",
                category: .social,
                items: weekendGathering,
                queryHint: hasHoliday ? "这次假期聚餐花了多少？" : "这周末聚餐花了多少？"
            ))
        }

        return rows
    }

    private static func milestoneAggregates(
        periodItems: [HomeItem],
        historyItems: [HomeItem],
        preparedContext: PreparedAggregationContext? = nil
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
            let periodMatched = matchedItems(
                in: periodItems,
                definition: definition,
                preparedContext: preparedContext
            )
            guard !periodMatched.isEmpty else { continue }
            let periodMatchedIDs = Set(periodMatched.map(\.id))
            let sorted = (preparedContext?.historyItemsByDefinitionID[definition.id]
                ?? historyItems.filter { matches($0, definition: definition) })
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

    private static func streakAggregates(
        for items: [HomeItem],
        preparedContext: PreparedAggregationContext? = nil
    ) -> [LifeMarkAggregate] {
        let calendar = Calendar.current
        return definitions.compactMap { definition in
            let matched = matchedItems(
                in: items,
                definition: definition,
                preparedContext: preparedContext
            )
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
        let text = semanticText(for: item)
        let categoryMatched = definition.categories.contains(item.category)
        let keywordMatched = containsAny(text, definition.keywords)
        if definition.id == "baby_supply" {
            return categoryMatched && SemanticBoundaryGuard.matchesBabySupply(text)
        }
        if definition.id == "pet_supply" {
            return categoryMatched && SemanticBoundaryGuard.matchesPetSupply(text)
        }
        if definition.id == "groceries",
           SemanticBoundaryGuard.isHouseholdCleaningSupply(text) {
            return false
        }
        if item.scenePackId == "family", definition.id == "daily_supply" {
            return false
        }
        if definition.id == "daily_supply",
           isTelecomBill(item) {
            return false
        }
        if definition.id == "daily_supply",
           matchesAnySpecificDefinition(item, ids: broadDailySupplySpecificDefinitionIDs) {
            return false
        }
        if definition.id == "leisure",
           matchesAnySpecificDefinition(item, ids: broadLeisureSpecificDefinitionIDs) {
            return false
        }
        if definition.id == "daily_supply", item.category != .daily {
            return categoryMatched && keywordMatched
        }
        return definition.requiresKeywordMatch
            ? categoryMatched && keywordMatched
            : categoryMatched || keywordMatched
    }

    private static func matchedItems(
        in items: [HomeItem],
        definition: LifeMarkDefinition,
        preparedContext: PreparedAggregationContext?
    ) -> [HomeItem] {
        items.filter { item in
            guard let preparedContext,
                  let matchedDefinitionIDs = preparedContext.definitionIDsByItemID[item.id] else {
                return matches(item, definition: definition)
            }
            return matchedDefinitionIDs.contains(definition.id)
        }
    }

    private static func matchesAnySpecificDefinition(_ item: HomeItem, ids specificIDs: Set<String>) -> Bool {
        let text = semanticText(for: item)
        return definitions.contains { definition in
            guard specificIDs.contains(definition.id),
                  definition.categories.contains(item.category) else { return false }
            if definition.id == "baby_supply" {
                return SemanticBoundaryGuard.matchesBabySupply(text)
            }
            if definition.id == "pet_supply" {
                return SemanticBoundaryGuard.matchesPetSupply(text)
            }
            return containsAny(text, definition.keywords)
        }
    }

    private static func isTelecomBill(_ item: HomeItem) -> Bool {
        containsAny(semanticText(for: item), telecomBillKeywords)
    }

    private static func isHouseholdCleaningSupply(_ item: HomeItem) -> Bool {
        SemanticBoundaryGuard.isHouseholdCleaningSupply(semanticText(for: item))
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
        case "咖啡饮品":
            if recurring {
                return "咖啡饮品又记下来了\(historyText)，以后能看出常在哪些时段会买。"
            }
            return count == 1 ? "咖啡饮品被记下来了，以后再看会知道今天从哪一杯开始。" : "咖啡饮品记了 \(count) 次，今天哪几次买了喝的会更清楚。"
        case "宝宝照护":
            if recurring {
                return "宝宝相关用品又被记下\(historyText)，奶粉、尿不湿或辅食这些细项会更清楚。"
            }
            return "宝宝相关用品出现 \(count) 次，买过什么、什么时候买过，会更清楚。"
        case "房租水电物业":
            if recurring {
                return "家账线索又出现了\(historyText)，以后按月回看会更清楚。"
            }
            return "水电、房租或物业这类家账出现 \(count) 次，适合按月回看。"
        case "休闲娱乐":
            if recurring {
                return "休闲娱乐又出现了\(historyText)，哪天去看、玩过什么，都能回头看。"
            }
            return "休闲娱乐出现 \(count) 次，说明这段时间也有留给电影、游戏或外出的记录。"
        case "出去玩订酒店买票":
            if recurring {
                return "旅行和异地线索又出现了\(historyText)，可以和城市、天气一起回看。"
            }
            return "旅行和异地线索出现 \(count) 次，可以和城市、天气一起回看。"
        case "兴趣装备":
            if recurring {
                return "兴趣装备又出现了\(historyText)，买过哪些装备、哪天买的，会更清楚。"
            }
            return "兴趣装备出现 \(count) 次，这些不是大总结，但能看出最近把钱花在哪个爱好上。"
        default:
            if recurring {
                return "\(label)又出现了\(historyText)，同类记录可以放在一起回看。"
            }
            return "\(label)记了 \(count) 次，后面可以一起回看。"
        }
    }

    private static func milestoneDetail(label: String, target: Int) -> String {
        if target == 1 {
            switch label {
            case "健身恢复":
                return "第一次健身恢复被记下来了；以后再有同类记录，就能回看上一次、连续几次和身体这条线。"
            case "咖啡饮品":
                return "第一杯咖啡饮品被记下来了；以后再买，也能看到它常出现在什么时段。"
            case "给宝宝买奶粉":
                return "第一次给宝宝买奶粉被记下来了；以后再买，可以看到上一次是什么时候。"
            case "给宝宝买尿不湿":
                return "第一次给宝宝买尿不湿被记下来了；以后再买，可以看到间隔和次数。"
            case "给宝宝买辅食":
                return "第一次给宝宝买辅食被记下来了；以后再买，会和同类记录放在一起。"
            case "给宝宝买照护用品", "宝宝照护":
                return "第一次宝宝照护用品被记下来了；之后如果还有同类记录，会一起归到宝宝用品里。"
            case "给毛孩子买狗粮":
                return "第一次给毛孩子买狗粮被记下来了；以后再买，可以看到上一次是什么时候。"
            case "给毛孩子买猫粮":
                return "第一次给毛孩子买猫粮被记下来了；以后再买，可以看到间隔和次数。"
            case "给毛孩子买猫砂":
                return "第一次给毛孩子买猫砂被记下来了；以后再买，会和同类记录放在一起。"
            case "给毛孩子买零食":
                return "第一次给毛孩子买零食被记下来了；以后再买，也能看到上一次是什么时候。"
            case "毛孩子护理", "毛孩子照护":
                return "第一次毛孩子护理被记下来了；以后同类记录会显示时间和次数。"
            case "露营":
                return "第一次露营被记下来了；帐篷、天幕和路上的花费，都可以从这里开始回看。"
            case "买渔具":
                return "第一次买渔具被记下来了；这个爱好从一件具体装备开始有了记录。"
            case "骑行装备":
                return "第一次骑行装备被记下来了；车、路和装备以后可以放在一起看。"
            case "摄影装备":
                return "第一次摄影装备被记下来了；镜头、相机和拍摄相关记录以后可以一起回看。"
            case "买乐器":
                return "第一次买乐器被记下来了；这个爱好第一次有了一件具体物件。"
            case "水电燃气", "房租", "物业费", "宽带网费", "停车费", "话费", "租房押金":
                return "这笔\(label)已经作为本月家账线索记录；有同类记录时，会继续归到这条线里。"
            default:
                return "首次\(label)被记下来了；后面再出现时，会继续归到这条线里，方便回看上一次和第几次。"
            }
        }
        switch label {
        case "健身恢复":
            return "健身恢复来到第 \(target) 次，坚持已经开始有形状了。"
        case "咖啡饮品":
            return "咖啡饮品来到第 \(target) 次，常买的时段会慢慢清楚。"
        case "给宝宝买奶粉", "给宝宝买尿不湿", "给宝宝买辅食", "给宝宝买照护用品", "宝宝照护":
            return "\(label)来到第 \(target) 次，上一次和这一次的间隔会更清楚。"
        case "给毛孩子买狗粮", "给毛孩子买猫粮", "给毛孩子买猫砂", "给毛孩子买零食", "毛孩子护理", "毛孩子照护":
            return "\(label)来到第 \(target) 次，上一次和这一次的间隔会更清楚。"
        case "露营", "买渔具", "骑行装备", "摄影装备", "买乐器", "兴趣装备":
            return "\(label)来到第 \(target) 次，这个爱好最近添了什么，会更清楚。"
        default:
            return "\(label)来到第 \(target) 次，同类记录已经能放在一起看。"
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
        case "telecom_bill":
            return "话费"
        case "household_service":
            return householdServiceLabel(for: item)
        default:
            return definition.label
        }
    }

    private static func babySupplyLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        if !SemanticBoundaryGuard.matchesBabySupply(text) || isHouseholdCleaningSupply(item) {
            return "日用补货"
        }
        if containsAny(text, ["奶粉"]) {
            return "给宝宝买奶粉"
        }
        if containsAny(text, ["尿不湿", "纸尿裤", "拉拉裤"]) {
            return "给宝宝买尿不湿"
        }
        if containsAny(text, ["辅食", "米粉"]) {
            return "给宝宝买辅食"
        }
        if containsAny(text, ["托育费", "托班费", "幼儿园学费", "早教课"]) {
            return "托育早教"
        }
        if containsAny(text, ["宝宝湿巾", "婴儿湿巾", "奶瓶", "安抚奶嘴"]) {
            return "给宝宝买照护用品"
        }
        return "宝宝照护"
    }

    private static func petSupplyLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        guard SemanticBoundaryGuard.matchesPetSupply(text) else {
            return "日用补货"
        }
        if containsAny(text, ["狗粮"]) {
            return "给毛孩子买狗粮"
        }
        if containsAny(text, ["猫粮"]) {
            return "给毛孩子买猫粮"
        }
        if containsAny(text, ["猫砂"]) {
            return "给毛孩子买猫砂"
        }
        if containsAny(text, ["猫冻干", "狗冻干", "宠物冻干", "猫罐头", "狗罐头", "宠物罐头"]) {
            return "给毛孩子买零食"
        }
        if containsAny(text, ["宠物医院", "猫驱虫", "狗驱虫", "宠物驱虫", "猫狗洗护", "宠物洗护"]) {
            return "毛孩子护理"
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
        if containsAny(text, ["模型", "手办", "谷子", "潮玩", "吧唧", "徽章", "亚克力", "立牌", "盲盒", "泡泡玛特", "POP MART", "POPMART", "LABUBU", "棉花娃娃", "痛包", "同人本", "乙游周边", "漫展周边"]) {
            return "潮玩谷子"
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
        if containsAny(text, ["暖气费", "取暖费", "供暖费", "采暖费", "热力费", "供热费", "暖气缴费", "热力公司"]) {
            return "供暖账单"
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
        return "家账"
    }

    private static func householdServiceLabel(for item: HomeItem) -> String {
        let text = semanticText(for: item)
        if containsAny(text, ["搬家", "搬家公司", "货拉拉搬家"]) {
            return "搬家安排"
        }
        return "家政保洁"
    }

    private static func queryHint(for definition: LifeMarkDefinition) -> String {
        switch definition.id {
        case "fitness": return "这个月健身恢复几次？"
        case "coffee_drink": return "这周咖啡饮品几次？"
        case "home_utilities": return "这个月房租水电物业多少？"
        case "baby_supply": return "这个月宝宝奶粉买了几次？"
        case "pet_supply": return "上一次给毛孩子买狗粮是哪天？"
        case "leisure": return "上周休闲娱乐花了多少钱？"
        case "travel": return "上一次出去玩订酒店买票是什么时候？"
        case "interest_gear": return "第一次露营或买渔具是哪天？"
        default: return "这个月\(definition.label)几次？"
        }
    }

    private static func isCasualDrinkOnly(_ item: HomeItem) -> Bool {
        let text = semanticText(for: item)
        return containsAny(text, casualDrinkKeywords)
            && !containsAny(text, intentionalDrinkKeywords)
    }

    private static func semanticText(for item: HomeItem) -> String {
        [
            item.title,
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
        RecordCalendarContext.isNonWorkday(date)
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
