import Foundation

enum SemanticBoundaryGuard {
    enum FamilyCareKind {
        case baby
        case pet
    }

    struct CategoryMatch: Equatable {
        let category: HomeItem.Category
        let strength: Double
        let keyword: String
    }

    static let babyStrongKeywords = [
        "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "辅食", "米粉",
        "奶瓶", "安抚奶嘴", "宝宝湿巾", "婴儿湿巾", "童装",
        "儿童座椅", "推车", "托育费", "托班费", "幼儿园学费", "早教课"
    ]

    static let babyContextKeywords = ["宝宝", "婴儿", "母婴", "儿童", "幼儿"]

    static let petStrongKeywords = [
        "狗粮", "猫粮", "猫砂", "宠物粮", "宠物口粮", "尿垫",
        "猫冻干", "狗冻干", "宠物冻干", "宠物罐头", "猫罐头", "狗罐头",
        "猫驱虫", "狗驱虫", "宠物驱虫", "宠物医院", "猫狗洗护", "宠物洗护"
    ]

    static let petContextKeywords = ["宠物", "毛孩子", "毛孩"]

    private static let householdCleaningKeywords = [
        "厨房", "厨", "清洁", "家用", "日用", "日用品", "纸巾",
        "卷纸", "抽纸", "湿巾", "厨房湿巾", "洗洁精", "洗衣液", "垃圾袋"
    ]

    private static let babyContextObjectKeywords = [
        "用品", "照护", "换洗", "衣服", "鞋", "玩具", "零食", "口粮", "护理"
    ]

    private static let petContextObjectKeywords = [
        "用品", "口粮", "洗护", "驱虫", "医院", "窝", "牵引绳", "罐头", "冻干", "零食", "护理"
    ]

    private static var strongCategoryKeywords: [(HomeItem.Category, [String])] { [
        (.transport, [
            "地铁", "公交", "打车", "出租", "网约车", "滴滴", "花小猪", "停车费",
            "充电桩", "电车充电", "汽车充电", "高铁", "火车票", "机票", "机场",
            "通勤", "早高峰", "晚高峰", "洗车", "汽车保养", "车辆保养"
        ]),
        (.dining, [
            "早餐", "早饭", "午餐", "午饭", "晚餐", "晚饭", "夜宵", "宵夜",
            "外卖", "咖啡", "奶茶", "饮品", "饮料", "茶叶蛋", "饭团", "关东煮",
            "海底捞", "七欣天", "老乡鸡", "塔斯汀", "绝味", "袁记云饺",
            "火锅", "烤肉", "烧烤", "便当", "盖饭"
        ]),
        (.shopping, [
            "淘宝", "京东", "拼多多", "快递", "下单", "充电器", "数据线", "充电宝",
            "耳机", "手机", "电脑", "衣服", "外套", "裤子", "裙", "护肤", "化妆",
            "渔具", "鱼竿", "路亚", "露营", "帐篷", "摄影", "相机", "镜头",
            "模型", "手办", "谷子", "潮玩", "盲盒", "泡泡玛特", "乐器"
        ]),
        (.daily, [
            "纸巾", "抽纸", "卷纸", "厨房湿巾", "洗衣液", "洗洁精", "垃圾袋",
            "清洁用品", "日用品", "买菜", "生鲜", "水果", "蔬菜", "鸡蛋",
            "山姆会员", "话费", "手机话费", "手机充值"
        ] + babyStrongKeywords + petStrongKeywords),
        (.health, [
            "医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "验血",
            "牙科", "口腔", "洗牙", "配镜", "验光", "药店", "药房", "买药",
            "用药", "健身房", "健身卡", "私教", "跑步", "瑜伽", "游泳",
            "理疗", "康复", "按摩", "护具", "医美", "光子嫩肤", "水光针"
        ]),
        (.home, [
            "房租", "租金", "租房", "水电", "水费", "电费", "燃气", "煤气",
            "物业", "宽带", "暖气费", "取暖费", "供暖费", "热力费", "保洁",
            "家政", "搬家", "维修", "家电", "家具", "床品", "收纳"
        ]),
        (.social, [
            "红包", "随礼", "份子", "份子钱", "礼物", "送礼", "伴手礼", "请客",
            "聚餐", "约饭", "朋友", "生日", "探望", "拜访", "白事", "奠仪", "帛金"
        ]),
        (.entertainment, [
            "电影票", "看电影", "影院", "网吧", "网咖", "上网费", "演唱会",
            "音乐节", "剧本杀", "密室", "桌游", "游戏充值", "直播打赏", "直播礼物"
        ]),
        (.lodging, [
            "酒店", "民宿", "住宿", "宾馆", "客栈", "电竞酒店", "房费", "续住"
        ]),
        (.other, [
            "驾校", "驾校报名费", "驾考", "学车", "彩票", "福彩", "体彩", "刮刮乐"
        ])
    ] }

    static func matchesBabySupply(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return false }
        if containsAny(normalized, babyStrongKeywords) { return true }
        if isHouseholdCleaningSupply(normalized) { return false }
        return containsAny(normalized, babyContextKeywords)
            && containsAny(normalized, babyContextObjectKeywords)
    }

    static func matchesPetSupply(_ text: String, petName: String? = nil) -> Bool {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return false }
        if containsAny(normalized, petStrongKeywords) { return true }
        if let petName {
            let normalizedPetName = normalize(petName)
            if !normalizedPetName.isEmpty, normalized.contains(normalizedPetName) {
                return true
            }
        }
        return containsAny(normalized, petContextKeywords)
            && containsAny(normalized, petContextObjectKeywords)
    }

    static func familyCareKind(in text: String, petName: String? = nil) -> FamilyCareKind? {
        if matchesBabySupply(text) { return .baby }
        if matchesPetSupply(text, petName: petName) { return .pet }
        return nil
    }

    static func strongestCategory(in text: String) -> CategoryMatch? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }
        var matches: [CategoryMatch] = []
        for (category, keywords) in strongCategoryKeywords {
            guard let keyword = keywords.first(where: { normalized.localizedCaseInsensitiveContains($0.lowercased()) }) else {
                continue
            }
            let strength = categoryStrength(for: category, keyword: keyword)
            matches.append(CategoryMatch(category: category, strength: strength, keyword: keyword))
        }
        guard !matches.isEmpty else { return nil }
        let sorted = matches.sorted {
            if abs($0.strength - $1.strength) < 0.001 {
                return categoryPriority($0.category) < categoryPriority($1.category)
            }
            return $0.strength > $1.strength
        }
        guard let best = sorted.first else { return nil }
        if let second = sorted.dropFirst().first,
           abs(best.strength - second.strength) < 0.35 {
            return nil
        }
        return best
    }

    static func isHouseholdCleaningSupply(_ text: String) -> Bool {
        let normalized = normalize(text)
        guard containsAny(normalized, householdCleaningKeywords) else { return false }
        return !containsAny(normalized, babyStrongKeywords)
    }

    static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        let normalized = normalize(text)
        return keywords.contains { normalized.localizedCaseInsensitiveContains($0.lowercased()) }
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func categoryStrength(for category: HomeItem.Category, keyword: String) -> Double {
        var strength = Double(keyword.count) / 2.0
        switch category {
        case .transport, .health, .home, .lodging, .social:
            strength += 2.0
        case .daily:
            strength += 1.7
        case .dining, .shopping, .entertainment:
            strength += 1.4
        case .other:
            strength += 1.2
        }
        if babyStrongKeywords.contains(keyword) || petStrongKeywords.contains(keyword) {
            strength += 1.5
        }
        return strength
    }

    private static func categoryPriority(_ category: HomeItem.Category) -> Int {
        switch category {
        case .transport: return 0
        case .health: return 1
        case .home: return 2
        case .lodging: return 3
        case .social: return 4
        case .daily: return 5
        case .dining: return 6
        case .shopping: return 7
        case .entertainment: return 8
        case .other: return 9
        }
    }
}
