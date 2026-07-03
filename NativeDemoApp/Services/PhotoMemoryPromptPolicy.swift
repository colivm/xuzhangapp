import Foundation

enum PhotoMemorySceneHint: String, Codable, Equatable {
    case gathering
    case travel
    case vehicleCare
    case travelTransport
    case homeLife
    case careRecord
    case healthRecord
    case experience
    case giftMoment
    case importantPurchase
}

enum PhotoMemoryAssetRole: String, Codable, Equatable {
    case moment
    case receipt
    case place
    case object
    case careRecord
}

struct PhotoMemoryPromptReason: Equatable {
    let sceneHint: PhotoMemorySceneHint
    let assetRole: PhotoMemoryAssetRole
    let sceneLabel: String
    let title: String
    let detail: String
    let actionTitle: String

    var memoryAnchorCaption: String {
        switch assetRole {
        case .moment:
            switch sceneHint {
            case .gathering:
                return "这张图把那次见面留住了。"
            case .giftMoment:
                return "这张图把那份心意留住了。"
            case .experience:
                return "这张图把当时留了下来。"
            default:
                return "这张图把当时留了下来。"
            }
        case .receipt:
            return "这张图以后查起来更清楚。"
        case .place:
            return "这张图把那段出门的路留住了。"
        case .object:
            return "这件东西代表这笔添置。"
        case .careRecord:
            return "这张图把当时的照护记录留清楚。"
        }
    }
}

enum PhotoMemoryPromptPolicy {
    static func reason(for item: HomeItem, existingItems: [HomeItem] = []) -> PhotoMemoryPromptReason? {
        guard !item.hasMemoryImages else { return nil }

        let signal = LifeSceneSemanticService.classify(item)
        let text = semanticText(for: item)

        guard !containsAny(text, transferLikeKeywords) else { return nil }
        guard !containsAny(text, fixedBillKeywords) else { return nil }
        if isRoutineCommute(item: item, signal: signal, text: text) {
            return nil
        }
        if alreadyHasSceneImageToday(for: item, scene: signal.kind, in: existingItems) {
            return nil
        }

        if containsAny(text, travelKeywords) || item.category == .lodging || signal.kind == .lodging {
            return PhotoMemoryPromptReason(
                sceneHint: .travel,
                assetRole: .place,
                sceneLabel: "出行停留",
                title: "这笔以后适合回看",
                detail: "如果有酒店、车站、门票或路上的照片，可以放进这笔。",
                actionTitle: "留张路上的图"
            )
        }

        if containsAny(text, vehicleEvidenceKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .vehicleCare,
                assetRole: .receipt,
                sceneLabel: "车辆补能",
                title: "要补一张凭证吗",
                detail: "加油、充电、停车和过路费留图，后面查车相关支出会更清楚。",
                actionTitle: "补张凭证图"
            )
        }

        if isGathering(item: item, text: text) {
            return PhotoMemoryPromptReason(
                sceneHint: .gathering,
                assetRole: .moment,
                sceneLabel: "见面聚餐",
                title: "这顿饭可以留个画面",
                detail: "聚餐、请客或见面吃饭有照片的话，回看时更容易想起那次见面。",
                actionTitle: "留张现场图"
            )
        }

        if containsAny(text, giftMomentKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .giftMoment,
                assetRole: .moment,
                sceneLabel: "心意时刻",
                title: "这份心意可以留一下",
                detail: "礼物、蛋糕、鲜花这类记录，适合以后和人情回看连起来。",
                actionTitle: "留张心意图"
            )
        }

        if containsAny(text, experienceKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .experience,
                assetRole: .moment,
                sceneLabel: "体验现场",
                title: "这次体验适合留图",
                detail: "电影、展览、演出或一起玩的场景，加一张图会更容易被复盘记起。",
                actionTitle: "留张现场图"
            )
        }

        if containsAny(text, careRecordKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .careRecord,
                assetRole: .careRecord,
                sceneLabel: "照护补给",
                title: "这笔照护可以留个记录",
                detail: "宝宝、宠物或家人照护相关的照片，以后回看家庭生活会更完整。",
                actionTitle: "留张照护图"
            )
        }

        if containsAny(text, healthRecordKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .healthRecord,
                assetRole: .receipt,
                sceneLabel: "健康事项",
                title: "要补一张健康凭证吗",
                detail: "检查、问诊、药房票据留一张，后面整理身体相关支出会更省心。",
                actionTitle: "补张凭证图"
            )
        }

        if containsAny(text, homeLifeKeywords) || isMeaningfulHomePurchase(item: item, text: text) {
            return PhotoMemoryPromptReason(
                sceneHint: .homeLife,
                assetRole: .object,
                sceneLabel: "家里添置",
                title: "这件家里的事可以留图",
                detail: "家电、家具、搬家或家政这类记录，以后看家里变化会更有参照。",
                actionTitle: "拍下这一件"
            )
        }

        if containsAny(text, hobbyOrImportantPurchaseKeywords) || isImportantPurchase(item: item, text: text) {
            return PhotoMemoryPromptReason(
                sceneHint: .importantPurchase,
                assetRole: .object,
                sceneLabel: "重要添置",
                title: "这笔添置可以留个样子",
                detail: "装备、数码或比较贵的物件有图，之后回看会更容易想起为什么买。",
                actionTitle: "拍下这件东西"
            )
        }

        if isHighValueNonCommuteTransport(item: item, text: text) {
            return PhotoMemoryPromptReason(
                sceneHint: .travelTransport,
                assetRole: .receipt,
                sceneLabel: "非通勤出行",
                title: "这段路可以留个凭证",
                detail: "金额偏高的非通勤出行，留一张票据或路上的图，后面会更好查。",
                actionTitle: "补张出行图"
            )
        }

        return nil
    }

    static func anchorReason(for item: HomeItem) -> PhotoMemoryPromptReason {
        if let reason = reason(for: item) {
            return reason
        }

        let signal = LifeSceneSemanticService.classify(item)
        let text = semanticText(for: item)
        if containsAny(text, travelKeywords) || item.category == .lodging || signal.kind == .lodging {
            return PhotoMemoryPromptReason(
                sceneHint: .travel,
                assetRole: .place,
                sceneLabel: "出门",
                title: "留下一张路上的图",
                detail: "这张图以后会帮你想起那段出门。",
                actionTitle: "留下这张"
            )
        }
        if containsAny(text, vehicleEvidenceKeywords) || item.category == .transport {
            return PhotoMemoryPromptReason(
                sceneHint: .vehicleCare,
                assetRole: .receipt,
                sceneLabel: "票据",
                title: "留下一张票据图",
                detail: "这张图以后查起来更清楚。",
                actionTitle: "保存这张"
            )
        }
        if isGathering(item: item, text: text) || item.category == .social {
            return PhotoMemoryPromptReason(
                sceneHint: .gathering,
                assetRole: .moment,
                sceneLabel: "见面",
                title: "留下一张现场图",
                detail: "这张图会让这笔以后更容易被想起。",
                actionTitle: "留下这张"
            )
        }
        if containsAny(text, careRecordKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .careRecord,
                assetRole: .careRecord,
                sceneLabel: "照护",
                title: "留下一张照护图",
                detail: "这张图会把当时的照护记录留清楚。",
                actionTitle: "留下这张"
            )
        }
        if containsAny(text, healthRecordKeywords) || item.category == .health {
            return PhotoMemoryPromptReason(
                sceneHint: .healthRecord,
                assetRole: .receipt,
                sceneLabel: "健康",
                title: "留下一张记录图",
                detail: "这张图以后能帮你回看身体相关的事。",
                actionTitle: "保存这张"
            )
        }
        if containsAny(text, homeLifeKeywords) || item.category == .home {
            return PhotoMemoryPromptReason(
                sceneHint: .homeLife,
                assetRole: .object,
                sceneLabel: "家里",
                title: "用这张代表这笔",
                detail: "这张图会帮你想起家里添的这一件。",
                actionTitle: "用这张代表它"
            )
        }
        if item.category == .shopping || containsAny(text, hobbyOrImportantPurchaseKeywords) {
            return PhotoMemoryPromptReason(
                sceneHint: .importantPurchase,
                assetRole: .object,
                sceneLabel: "添置",
                title: "用这张代表这笔",
                detail: "这张图会帮你想起为什么买下它。",
                actionTitle: "用这张代表它"
            )
        }
        return PhotoMemoryPromptReason(
            sceneHint: .experience,
            assetRole: .moment,
            sceneLabel: "记忆",
            title: "留下这张图",
            detail: "这张图会让这笔以后更容易被想起。",
            actionTitle: "留下这张"
        )
    }

    private static func semanticText(for item: HomeItem) -> String {
        [
            item.title,
            item.displayTitle,
            item.displayEmotionTag,
            item.category.rawValue,
            item.category.label,
            item.merchantBrandId ?? "",
            item.memoryContext?.semanticPlace ?? ""
        ]
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isRoutineCommute(item: HomeItem, signal: LifeSceneSignal, text: String) -> Bool {
        if containsAny(text, vehicleEvidenceKeywords) || containsAny(text, travelKeywords) {
            return false
        }
        if signal.kind == .commute { return true }
        if item.category == .transport, item.amount <= 80, containsAny(text, commuteKeywords) {
            return true
        }
        return false
    }

    private static func isGathering(item: HomeItem, text: String) -> Bool {
        guard item.category == .dining || item.category == .social || item.category == .entertainment else {
            return false
        }
        if containsAny(text, workMealKeywords) { return false }
        if containsAny(text, gatheringKeywords) { return true }
        return item.category == .dining && item.amount >= 120 && !containsAny(text, routineMealKeywords)
    }

    private static func isMeaningfulHomePurchase(item: HomeItem, text: String) -> Bool {
        guard [.home, .daily, .shopping].contains(item.category) else { return false }
        return item.amount >= 220 && containsAny(text, homeObjectKeywords)
    }

    private static func isImportantPurchase(item: HomeItem, text: String) -> Bool {
        guard item.category == .shopping || item.category == .daily || item.category == .entertainment else {
            return false
        }
        if containsAny(text, routineSupplyKeywords) { return false }
        return item.amount >= 300 && containsAny(text, concretePurchaseKeywords)
    }

    private static func isHighValueNonCommuteTransport(item: HomeItem, text: String) -> Bool {
        guard item.category == .transport, item.amount >= 120 else { return false }
        return !containsAny(text, commuteKeywords)
    }

    private static func alreadyHasSceneImageToday(
        for item: HomeItem,
        scene: LifeSceneKind,
        in existingItems: [HomeItem]
    ) -> Bool {
        existingItems.contains { other in
            other.id != item.id
                && other.hasMemoryImages
                && Calendar.current.isDate(other.createdAt, inSameDayAs: item.createdAt)
                && LifeSceneSemanticService.classify(other).kind == scene
        }
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static let transferLikeKeywords = [
        "红包", "转账", "收款", "礼金", "礼钱", "随礼", "份子", "份子钱", "人情红包",
        "还款", "借款", "借钱", "代付", "代垫", "AA", "aa", "提现", "保证金", "押金"
    ]

    private static let fixedBillKeywords = [
        "话费", "手机充值", "手机话费", "通讯费", "通信费", "中国移动", "中国联通", "中国电信",
        "水费", "电费", "燃气", "煤气", "暖气费", "物业", "宽带", "网费", "房租", "租金",
        "会员", "订阅", "自动续费", "iCloud", "Apple Music", "网盘会员"
    ]

    private static let commuteKeywords = [
        "通勤", "上班", "下班", "到岗", "公司", "单位", "工位", "早高峰", "晚高峰",
        "地铁", "公交", "轨道交通", "单车", "共享单车", "回家"
    ]

    private static let vehicleEvidenceKeywords = [
        "加油", "油费", "中石化", "中石油", "充电桩", "特来电", "星星充电", "电车充电",
        "汽车充电", "新能源充电", "补能", "停车", "停车费", "高速", "过路费", "路费",
        "ETC", "etc", "洗车", "汽车保养", "车辆保养", "保养车"
    ]

    private static let travelKeywords = [
        "旅行", "旅游", "出差", "外地", "机场", "航班", "机票", "高铁", "火车", "动车",
        "车票", "酒店", "宾馆", "民宿", "住宿", "客栈", "景区", "门票", "租车"
    ]

    private static let gatheringKeywords = [
        "聚餐", "请客", "约饭", "朋友", "同学", "家庭聚餐", "饭局", "火锅", "烤肉",
        "烧烤", "日料", "餐厅", "生日", "KTV", "ktv", "唱歌", "见面"
    ]

    private static let giftMomentKeywords = [
        "礼物", "送礼", "伴手礼", "纪念日", "鲜花", "花束", "蛋糕", "探望", "拜访"
    ]

    private static let experienceKeywords = [
        "电影", "影院", "演唱会", "音乐节", "live", "剧场", "话剧", "展览", "美术馆",
        "博物馆", "密室", "剧本杀", "桌游", "游乐园", "景区", "门票", "露营"
    ]

    private static let careRecordKeywords = [
        "宝宝", "孩子", "婴儿", "奶粉", "尿不湿", "纸尿裤", "拉拉裤", "辅食", "奶瓶",
        "托育", "幼儿园", "早教", "宠物", "狗粮", "猫粮", "猫砂", "宠物医院", "驱虫"
    ]

    private static let healthRecordKeywords = [
        "医院", "门诊", "诊所", "挂号", "问诊", "体检", "检查", "拍片", "验血",
        "口腔", "牙科", "洗牙", "配镜", "验光", "药店", "药房", "买药", "用药"
    ]

    private static let homeLifeKeywords = [
        "搬家", "搬家公司", "家政", "保洁", "维修", "修理", "换锁", "疏通", "安装",
        "家具", "家电", "冰箱", "洗衣机", "空调", "床", "桌", "椅", "沙发", "收纳", "宜家"
    ]

    private static let homeObjectKeywords = [
        "锅", "碗", "厨房", "床品", "收纳", "灯", "家具", "家电", "冰箱", "洗衣机",
        "空调", "床", "桌", "椅", "沙发", "宜家", "山姆"
    ]

    private static let hobbyOrImportantPurchaseKeywords = [
        "相机", "镜头", "摄影", "手机", "电脑", "耳机", "键盘", "运动鞋", "露营", "帐篷",
        "天幕", "骑行", "渔具", "鱼竿", "乐器", "吉他", "模型", "手办", "潮玩", "盲盒"
    ]

    private static let concretePurchaseKeywords = [
        "衣服", "鞋", "包", "护肤", "手机", "电脑", "耳机", "键盘", "相机", "镜头",
        "家具", "家电", "运动", "露营", "摄影", "乐器", "模型", "手办"
    ]

    private static let routineSupplyKeywords = [
        "纸巾", "抽纸", "卷纸", "湿巾", "洗衣液", "洗洁精", "垃圾袋", "牙刷", "毛巾",
        "买菜", "水果", "蔬菜", "牛奶", "鸡蛋"
    ]

    private static let routineMealKeywords = [
        "早餐", "早饭", "午餐", "午饭", "外卖", "便当", "食堂", "工作餐", "加班餐",
        "咖啡", "奶茶", "饮品", "便利店"
    ]

    private static let workMealKeywords = [
        "食堂", "工位", "工作餐", "加班餐", "公司楼下", "单位食堂"
    ]
}
